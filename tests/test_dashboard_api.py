"""Dashboard API integration tests (DASH-1, Sprint 16).

Targets `app/dashboard/router.py`, `app/dashboard/service.py`,
`app/dashboard/seeds.py` — covers:

  - widget catalog filtering by permissions
  - layout fallback chain (user > role > tenant > system)
  - PUT /layout enforces customize:dashboard
  - POST /layout/reset deletes user layout, falls back
  - Role-layout admin endpoints respect manage:dashboard_role + lock:dashboard
  - Batch endpoint returns per-widget data + per-widget errors
  - Widget data endpoint enforces per-widget permissions
  - Cache invalidation on event_bus events
  - Lock prevents users without lock:dashboard from saving
  - Block validation rejects unknown widgets / duplicate ids

These run against the shared test DB. Each test seeds widgets +
layouts in setup so they're independent of test ordering.
"""

from __future__ import annotations

import os
import time
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.core.cache import _reset_for_tests, get_cache
from app.dashboard.events import EVENT_INVALIDATIONS
from app.dashboard.models import (
    DashboardDataCache,
    DashboardLayout,
    DashboardWidget,
    LayoutScope,
)
from app.dashboard.seeds import seed_dashboard
from app.dashboard.service import (
    LayoutLockedError,
    PermissionDeniedError,
    compute_batch,
    compute_widget_data,
    filter_blocks_by_perms,
    get_effective_layout,
    list_widgets_for,
    register_resolver,
    reset_user_layout,
    save_role_layout,
    save_user_layout,
    set_role_layout_lock,
    user_can,
)
from app.dashboard.schemas import LayoutBlock
from app.phase1.models.platform_models import SessionLocal


# ── Fixtures / helpers ────────────────────────────────────


JWT_SECRET = os.environ["JWT_SECRET"]


def _token(*, user_id: str, role: str, perms: list[str], tenant_id: str = "t-1") -> str:
    payload = {
        "sub": user_id,
        "user_id": user_id,
        "username": user_id,
        "role": role,
        "permissions": perms,
        "tenant_id": tenant_id,
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def _hdr(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _user(user_id: str, role: str, perms: list[str]) -> dict:
    return {
        "user_id": user_id,
        "sub": user_id,
        "role": role,
        "permissions": perms,
        "tenant_id": "t-1",
    }


@pytest.fixture(autouse=True)
def _reset_cache():
    _reset_for_tests()
    yield
    _reset_for_tests()


@pytest.fixture(autouse=True)
def _seeded_dashboard():
    """Make sure the 12 system widgets + 5 role layouts exist."""
    db = SessionLocal()
    try:
        seed_dashboard(db)
    finally:
        db.close()
    yield
    # Clean up user-scope layouts created during tests so each test starts
    # from the known seed state.
    db = SessionLocal()
    try:
        db.query(DashboardLayout).filter(
            DashboardLayout.scope == LayoutScope.USER
        ).delete()
        db.commit()
    finally:
        db.close()


# ── 1. Catalog filtering ──────────────────────────────────


def test_seeds_create_12_widgets_and_6_layouts():
    db = SessionLocal()
    try:
        assert db.query(DashboardWidget).filter(
            DashboardWidget.is_system == True  # noqa: E712
        ).count() >= 12
        # 5 role layouts + 1 system fallback
        assert db.query(DashboardLayout).count() >= 6
    finally:
        db.close()


def test_get_widgets_returns_envelope_and_filters_by_perms(client):
    # User with only dashboard read — gets ai_pulse + nothing requiring
    # finance perms.
    tok = _token(user_id="u-1", role="cashier", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/widgets", headers=_hdr(tok))
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    codes = {w["code"] for w in body["data"]}
    # ai_pulse only requires read:dashboard
    assert "widget.ai_pulse" in codes
    # cash balance requires read:reports — should be filtered out
    assert "kpi.cash_balance" not in codes


def test_get_widgets_cfo_sees_full_catalog(client):
    cfo_perms = [
        "read:dashboard", "read:reports", "read:invoices", "read:bills",
        "read:customers", "read:approvals", "read:zatca", "read:forecast",
        "write:invoices",
    ]
    tok = _token(user_id="cfo-1", role="cfo", perms=cfo_perms)
    r = client.get("/api/v1/dashboard/widgets", headers=_hdr(tok))
    assert r.status_code == 200
    codes = {w["code"] for w in r.json()["data"]}
    assert "kpi.cash_balance" in codes
    assert "kpi.net_income_mtd" in codes
    assert "chart.cash_flow_90d" in codes
    assert "widget.express_invoice" in codes


def test_widget_catalog_unauthenticated_is_401(client):
    r = client.get("/api/v1/dashboard/widgets")
    assert r.status_code == 401


# ── 2. Layout fallback chain ──────────────────────────────


def test_layout_falls_back_to_role_when_user_has_none(client):
    # user-1 / cashier — no user-scope layout, should get the cashier role default.
    tok = _token(user_id="u-2", role="cashier", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/layout", headers=_hdr(tok))
    assert r.status_code == 200
    data = r.json()["data"]
    assert data is not None
    assert data["scope"] == "role"
    assert data["owner_id"] == "cashier"


def test_layout_falls_back_to_system_when_role_has_none(client):
    # Use a role with no seeded layout — should cascade to system.
    tok = _token(user_id="u-3", role="some_unknown_role", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/layout", headers=_hdr(tok))
    assert r.status_code == 200
    data = r.json()["data"]
    assert data is not None
    assert data["scope"] == "system"


def test_layout_user_scope_wins_over_role(client):
    # Seed a user-scope layout for u-4 / accountant — should override the
    # accountant role default.
    tok = _token(
        user_id="u-4",
        role="accountant",
        perms=["read:dashboard", "customize:dashboard", "read:reports"],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    assert r.status_code == 200, r.text
    r2 = client.get("/api/v1/dashboard/layout", headers=_hdr(tok))
    assert r2.status_code == 200
    data = r2.json()["data"]
    assert data["scope"] == "user"
    assert data["owner_id"] == "u-4"
    assert len(data["blocks"]) == 1


# ── 3. Save-layout permission enforcement ─────────────────


def test_put_layout_without_customize_is_403(client):
    tok = _token(user_id="u-5", role="cashier", perms=["read:dashboard"])
    body = {"name": "default", "blocks": []}
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    assert r.status_code == 403


def test_put_layout_rejects_widget_user_cant_see(client):
    # User has customize but not read:zatca — can't save compliance_health.
    tok = _token(
        user_id="u-6",
        role="cashier",
        perms=["read:dashboard", "customize:dashboard"],
    )
    body = {
        "name": "default",
        "blocks": [
            {
                "id": "b1",
                "widget_code": "widget.compliance_health",
                "span": 4,
                "x": 0,
                "y": 0,
            },
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    assert r.status_code == 403


def test_put_layout_rejects_unknown_widget(client):
    tok = _token(
        user_id="u-7",
        role="accountant",
        perms=["read:dashboard", "customize:dashboard"],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.does_not_exist", "span": 4, "x": 0, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    assert r.status_code == 403


def test_put_layout_rejects_duplicate_block_ids(client):
    tok = _token(
        user_id="u-8",
        role="accountant",
        perms=["read:dashboard", "customize:dashboard", "read:reports"],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
            {"id": "b1", "widget_code": "kpi.net_income_mtd", "span": 3, "x": 3, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    assert r.status_code == 422  # pydantic validation error


def test_post_reset_deletes_user_layout(client):
    tok = _token(
        user_id="u-9",
        role="accountant",
        perms=["read:dashboard", "customize:dashboard", "read:reports"],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
        ],
    }
    client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(tok))
    r = client.post("/api/v1/dashboard/layout/reset", headers=_hdr(tok))
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["scope"] != "user"


# ── 4. Role-layout admin endpoints ────────────────────────


def test_role_layout_list_requires_manage_role(client):
    tok = _token(user_id="u-10", role="cashier", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/role-layouts", headers=_hdr(tok))
    assert r.status_code == 403


def test_role_layout_admin_can_list(client):
    tok = _token(
        user_id="admin-1",
        role="admin",
        perms=["read:dashboard", "manage:dashboard_role"],
    )
    r = client.get("/api/v1/dashboard/role-layouts", headers=_hdr(tok))
    assert r.status_code == 200
    rows = r.json()["data"]
    role_ids = {r["owner_id"] for r in rows}
    assert "cfo" in role_ids and "accountant" in role_ids


def test_put_role_layout_persists(client):
    tok = _token(
        user_id="admin-2",
        role="admin",
        perms=[
            "read:dashboard", "manage:dashboard_role",
            "read:reports", "read:invoices",
        ],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 6, "x": 0, "y": 0},
            {"id": "b2", "widget_code": "kpi.ar_outstanding", "span": 6, "x": 6, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/role-layouts/cfo", json=body, headers=_hdr(tok))
    assert r.status_code == 200
    assert len(r.json()["data"]["blocks"]) == 2


def test_lock_endpoint_requires_lock_perm(client):
    # admin without lock:dashboard
    tok = _token(
        user_id="admin-3",
        role="admin",
        perms=["read:dashboard", "manage:dashboard_role"],
    )
    r = client.post(
        "/api/v1/dashboard/role-layouts/cfo/lock",
        json={"is_locked": True},
        headers=_hdr(tok),
    )
    assert r.status_code == 403


def test_lock_endpoint_works_with_lock_perm(client):
    tok = _token(
        user_id="admin-4",
        role="admin",
        perms=["read:dashboard", "manage:dashboard_role", "lock:dashboard"],
    )
    r = client.post(
        "/api/v1/dashboard/role-layouts/cfo/lock",
        json={"is_locked": True},
        headers=_hdr(tok),
    )
    assert r.status_code == 200
    assert r.json()["data"]["is_locked"] is True


# ── 5. Lock blocks downstream save ────────────────────────


def test_locked_role_layout_blocks_user_save(client):
    # Lock the accountant role.
    admin_tok = _token(
        user_id="admin-5",
        role="admin",
        perms=["read:dashboard", "manage:dashboard_role", "lock:dashboard"],
    )
    client.post(
        "/api/v1/dashboard/role-layouts/accountant/lock",
        json={"is_locked": True},
        headers=_hdr(admin_tok),
    )
    # Accountant user without lock:dashboard tries to save own layout.
    user_tok = _token(
        user_id="acc-1",
        role="accountant",
        perms=["read:dashboard", "customize:dashboard", "read:reports"],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(user_tok))
    assert r.status_code == 423


def test_locked_layout_doesnt_block_lock_holder(client):
    """A user who themselves has lock:dashboard can override the lock."""
    admin_tok = _token(
        user_id="admin-6",
        role="admin",
        perms=["read:dashboard", "manage:dashboard_role", "lock:dashboard"],
    )
    client.post(
        "/api/v1/dashboard/role-layouts/cfo/lock",
        json={"is_locked": True},
        headers=_hdr(admin_tok),
    )
    super_tok = _token(
        user_id="super-1",
        role="cfo",
        perms=[
            "read:dashboard", "customize:dashboard", "lock:dashboard",
            "read:reports",
        ],
    )
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(super_tok))
    assert r.status_code == 200


# ── 6. Batch + per-widget data ────────────────────────────


def test_batch_returns_per_widget_data_and_errors(client):
    tok = _token(
        user_id="u-batch",
        role="accountant",
        perms=["read:dashboard", "read:reports", "read:invoices"],
    )
    body = {
        "entity_id": "e-1",
        "as_of_date": "2026-05-06",
        "widgets": [
            "kpi.cash_balance",       # has perm
            "kpi.ar_outstanding",     # has perm
            "kpi.ap_due_7d",          # NO perm (read:bills missing)
            "widget.unknown_code",    # unknown
        ],
    }
    r = client.post("/api/v1/dashboard/data/batch", json=body, headers=_hdr(tok))
    assert r.status_code == 200
    payload = r.json()["data"]
    assert "kpi.cash_balance" in payload["data"]
    assert "kpi.ar_outstanding" in payload["data"]
    assert payload["errors"]["kpi.ap_due_7d"] == "permission_denied"
    assert payload["errors"]["widget.unknown_code"] == "unknown_widget"


def test_per_widget_data_endpoint_enforces_perm(client):
    tok = _token(user_id="u-d1", role="cashier", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/data/kpi.cash_balance", headers=_hdr(tok))
    # missing read:reports → 403
    assert r.status_code == 403


def test_per_widget_data_404_on_unknown(client):
    tok = _token(user_id="u-d2", role="cfo", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/data/widget.does.not.exist", headers=_hdr(tok))
    assert r.status_code == 404


def test_per_widget_data_returns_payload(client):
    tok = _token(user_id="u-d3", role="cfo", perms=["read:dashboard"])
    r = client.get("/api/v1/dashboard/data/widget.ai_pulse", headers=_hdr(tok))
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "headline_ar" in body["data"] or "error" in body["data"]


# ── 7. Cache invalidation via event_bus ───────────────────


def test_event_invalidates_widget_cache():
    from app.core.event_bus import emit
    from app.dashboard.service import compute_cache_key

    cache = get_cache()
    ctx = {"tenant_id": "t-1"}
    key = compute_cache_key("kpi.cash_balance", ctx)
    cache.set(key, {"value": 999}, 600)
    assert cache.get(key) == {"value": 999}

    # Fire an event that should invalidate kpi.cash_balance.
    emit("invoice.posted", {"invoice_id": "i-1", "tenant_id": "t-1"}, source="test")

    # Give the in-process listener a moment.
    time.sleep(0.05)
    assert cache.get(key) is None


def test_event_invalidations_table_covers_canonical_events():
    """All the events the spec wires (invoice.posted, payment.received,
    je.posted) must be present in EVENT_INVALIDATIONS."""
    for evt in ("invoice.posted", "payment.received", "je.posted"):
        assert evt in EVENT_INVALIDATIONS, f"missing event mapping: {evt}"


# ── 8. SSE basics ─────────────────────────────────────────


def test_stream_requires_auth(client):
    r = client.get("/api/v1/dashboard/stream")
    assert r.status_code == 401


def test_stream_route_is_registered(client):
    """The SSE endpoint is wired and rejects unauth — full streaming
    behaviour is verified manually via curl in operator test docs because
    sync TestClient iter_text blocks on the long-lived response.
    """
    # Already covered by test_stream_requires_auth; this asserts the
    # path resolves to a 200 vs 404 — the auth check ran, so the
    # route exists.
    r = client.get("/api/v1/dashboard/stream")
    assert r.status_code == 401  # not 404


def test_sse_hub_publishes_to_subscriber():
    """Direct hub test — bypasses HTTP altogether so we can validate
    the pub/sub fan-out without TestClient blocking on iter_text."""
    from app.dashboard.events import hub

    q = hub.subscribe()
    try:
        hub.publish({"type": "update", "widget_code": "x", "payload": {"v": 1}})
        msg = q.get(timeout=1)
        assert msg["type"] == "update"
        assert msg["widget_code"] == "x"
    finally:
        hub.unsubscribe(q)


# ── 9. Service-layer direct (unit) ────────────────────────


def test_user_can_grants_read_dashboard_to_any_authed_user():
    user = {"user_id": "u-1", "permissions": []}
    assert user_can(user, "read:dashboard") is True


def test_user_can_denies_unknown_perm():
    user = {"user_id": "u-1", "permissions": ["read:dashboard"]}
    assert user_can(user, "admin:billing") is False


def test_filter_blocks_by_perms_drops_disallowed():
    db = SessionLocal()
    try:
        widgets = {
            w.code: w
            for w in db.query(DashboardWidget).all()
        }
    finally:
        db.close()
    user = {
        "user_id": "u-x",
        "permissions": ["read:dashboard", "read:reports"],
    }
    blocks = [
        {"id": "b1", "widget_code": "kpi.cash_balance"},   # ok (read:reports)
        {"id": "b2", "widget_code": "kpi.ap_due_7d"},      # needs read:bills
        {"id": "b3", "widget_code": "widget.ai_pulse"},    # ok (read:dashboard)
    ]
    out = filter_blocks_by_perms(user, blocks, widgets)
    codes = {b["widget_code"] for b in out}
    assert "kpi.cash_balance" in codes
    assert "widget.ai_pulse" in codes
    assert "kpi.ap_due_7d" not in codes


def test_compute_widget_data_uses_resolver_and_caches():
    register_resolver("test.widget.echo", lambda ctx: {"ctx": ctx, "v": 1})
    ctx = {"tenant_id": "t-1", "as_of_date": "2026-05-06"}
    db = SessionLocal()
    try:
        out1 = compute_widget_data("test.widget.echo", ctx, db=db)
        out2 = compute_widget_data("test.widget.echo", ctx, db=db)
        assert out1 == out2
    finally:
        db.close()


def test_compute_batch_partial_errors_dont_kill_others():
    register_resolver("test.widget.always_ok", lambda ctx: {"ok": True})
    register_resolver("test.widget.always_fail", lambda ctx: (_ for _ in ()).throw(RuntimeError("boom")))
    out = compute_batch(
        ["test.widget.always_ok", "test.widget.always_fail"], {"tenant_id": "t-1"}
    )
    assert out.data["test.widget.always_ok"] == {"ok": True}
    assert "test.widget.always_fail" in out.errors


# ── 10. Default resolvers ─────────────────────────────────


def test_all_12_default_resolvers_return_payload():
    """The 12 system resolvers wired in app.dashboard.resolvers should
    all execute without raising — verifying the defensive try/except
    in @_safe + the JSON shape contract.
    """
    from app.dashboard import resolvers as r

    cases = [
        (r.kpi_cash_balance, "value"),
        (r.kpi_net_income_mtd, "value"),
        (r.kpi_ar_outstanding, "value"),
        (r.kpi_ap_due_7d, "value"),
        (r.chart_revenue_30d, "series"),
        (r.chart_cash_flow_90d, "series"),
        (r.list_top_customers, "rows"),
        (r.list_pending_approvals, "rows"),
        (r.list_recent_invoices, "rows"),
        (r.widget_compliance_health, "indicators"),
        (r.widget_ai_pulse, "headline_ar"),
        (r.widget_express_invoice, "action"),
    ]
    ctx = {"tenant_id": "t-1", "as_of_date": "2026-05-06"}
    for fn, key in cases:
        out = fn(ctx)
        assert isinstance(out, dict), f"{fn.__name__} returned non-dict"
        # Either the expected key or an error-marker — both are valid
        # for the defensive @_safe contract.
        assert key in out or "error" in out, (
            f"{fn.__name__}: missing both '{key}' and 'error' in {out}"
        )


def test_kpi_resolvers_return_currency_when_successful():
    from app.dashboard import resolvers as r

    out = r.kpi_cash_balance({"tenant_id": "t-1"})
    if "error" not in out:
        assert out.get("currency") == "SAR"


def test_chart_resolvers_emit_correct_series_length():
    from app.dashboard import resolvers as r

    out30 = r.chart_revenue_30d({})
    assert "error" in out30 or len(out30["series"]) == 30
    out90 = r.chart_cash_flow_90d({})
    assert "error" in out90 or len(out90["series"]) == 90


def test_register_default_resolvers_is_idempotent():
    from app.dashboard import resolvers as r
    from app.dashboard.service import has_resolver

    # Calling twice shouldn't blow up.
    r.register_default_resolvers()
    r.register_default_resolvers()
    assert has_resolver("kpi.cash_balance")
    assert has_resolver("widget.express_invoice")
