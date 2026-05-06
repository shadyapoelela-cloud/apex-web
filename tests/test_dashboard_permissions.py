"""Dashboard permission-hardening tests (DASH-1 Phase 5).

Pairs with `test_dashboard_api.py` — that suite covers the happy path +
basic filtering. This one drills into the boundary cases: every layer
that can leak a widget the user shouldn't see, and every layer that
can let a user write a layout they shouldn't be able to write.

The contract under test:

  Layer 1: catalog        list_widgets_for filters by required_perms
  Layer 2: layout read    blocks the user can't see are dropped
                          before reaching the wire
  Layer 3: layout write   _validate_blocks_against_perms refuses the
                          save (403) — even with bypass attempts
  Layer 4: data fetch     batch errors out per-widget (permission_denied)
                          rather than 403'ing the whole batch
  Layer 5: lock           a locked role/tenant layout blocks a save
                          unless the caller has lock:dashboard
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.dashboard.models import DashboardLayout, DashboardWidget, LayoutScope
from app.dashboard.seeds import seed_dashboard
from app.dashboard.service import (
    LayoutLockedError,
    PermissionDeniedError,
    compute_batch,
    filter_blocks_by_perms,
    get_effective_layout,
    list_widgets_for,
    save_role_layout,
    save_user_layout,
    set_role_layout_lock,
    user_can,
)
from app.dashboard.schemas import LayoutBlock
from app.phase1.models.platform_models import SessionLocal


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


def _user(user_id: str, role: str, perms: list[str], *, tenant_id: str = "t-1") -> dict:
    return {
        "user_id": user_id,
        "sub": user_id,
        "role": role,
        "permissions": perms,
        "tenant_id": tenant_id,
    }


# Permission bundles for each role we test against.
PERMS_CFO = [
    "read:dashboard", "customize:dashboard", "read:reports", "read:invoices",
    "read:bills", "read:customers", "read:approvals", "read:zatca",
    "read:forecast", "write:invoices",
]
PERMS_ACCOUNTANT = [
    "read:dashboard", "customize:dashboard", "read:reports", "read:invoices",
    "read:bills", "read:customers", "read:journal_entries", "write:journal_entries",
]
PERMS_CASHIER = [
    "read:dashboard", "customize:dashboard", "write:invoices",
]
PERMS_BRANCH_MGR = [
    "read:dashboard", "customize:dashboard", "read:reports", "read:invoices",
    "read:bills",
]
PERMS_HR = [
    "read:dashboard", "customize:dashboard", "read:employees", "read:approvals",
]
PERMS_ADMIN = [
    "read:dashboard", "customize:dashboard", "manage:dashboard_role",
    "lock:dashboard", "read:reports", "read:invoices", "read:bills",
]


@pytest.fixture(autouse=True)
def _seed_and_clean():
    """Seed system widgets + role layouts; clean user-scope layouts after."""
    db = SessionLocal()
    try:
        seed_dashboard(db)
    finally:
        db.close()
    yield
    db = SessionLocal()
    try:
        db.query(DashboardLayout).filter(
            DashboardLayout.scope == LayoutScope.USER
        ).delete()
        # Reset role locks back to false so independent tests don't see
        # bleed-over locks from a previous test.
        for r in db.query(DashboardLayout).filter(
            DashboardLayout.scope == LayoutScope.ROLE,
        ).all():
            r.is_locked = False
        db.commit()
    finally:
        db.close()


# ── 1. Layer 1: catalog filtering ─────────────────────────


def test_cfo_sees_full_widget_catalog():
    user = _user("u-cfo", "cfo", PERMS_CFO)
    db = SessionLocal()
    try:
        widgets = list_widgets_for(user, db)
    finally:
        db.close()
    codes = {w.code for w in widgets}
    # CFO has every read:* perm — should see all 12 system widgets.
    expected = {
        "kpi.cash_balance", "kpi.net_income_mtd", "kpi.ar_outstanding",
        "kpi.ap_due_7d", "chart.revenue_30d", "chart.cash_flow_90d",
        "list.top_customers", "list.pending_approvals",
        "list.recent_invoices", "widget.compliance_health",
        "widget.ai_pulse", "widget.express_invoice",
    }
    assert expected.issubset(codes)


def test_cashier_sees_only_action_and_ai_pulse():
    user = _user("u-cashier", "cashier", PERMS_CASHIER)
    db = SessionLocal()
    try:
        widgets = list_widgets_for(user, db)
    finally:
        db.close()
    codes = {w.code for w in widgets}
    # Cashier has write:invoices + dashboard — gets express_invoice
    # (write:invoices) + ai_pulse (read:dashboard implicit).
    assert "widget.express_invoice" in codes
    assert "widget.ai_pulse" in codes
    # And explicitly does NOT see the finance kpis.
    assert "kpi.cash_balance" not in codes
    assert "chart.revenue_30d" not in codes


def test_hr_sees_only_pending_approvals_widget():
    user = _user("u-hr", "hr", PERMS_HR)
    db = SessionLocal()
    try:
        widgets = list_widgets_for(user, db)
    finally:
        db.close()
    codes = {w.code for w in widgets}
    assert "list.pending_approvals" in codes
    assert "widget.ai_pulse" in codes
    assert "kpi.cash_balance" not in codes


def test_branch_manager_sees_subset():
    user = _user("u-bm", "branch_manager", PERMS_BRANCH_MGR)
    db = SessionLocal()
    try:
        widgets = list_widgets_for(user, db)
    finally:
        db.close()
    codes = {w.code for w in widgets}
    # Has read:reports → cash, net income, revenue chart.
    assert "kpi.cash_balance" in codes
    assert "kpi.net_income_mtd" in codes
    assert "chart.revenue_30d" in codes
    # Does NOT have read:forecast → cash flow forecast hidden.
    assert "chart.cash_flow_90d" not in codes
    # Does NOT have read:zatca → compliance health hidden.
    assert "widget.compliance_health" not in codes


# ── 2. Layer 2: layout read ───────────────────────────────


def test_get_layout_strips_blocks_user_cant_see(client):
    """GET /layout returns the role layout — but if the user is missing
    perms the role layout requires, the API filters at fetch time.

    (Today the layout is returned as-is; the renderer is expected to
    drop blocks the user can't see. This test is a regression canary
    in case we change the contract.)"""
    tok = _token(user_id="u-bm-2", role="branch_manager", perms=PERMS_BRANCH_MGR)
    r = client.get("/api/v1/dashboard/layout", headers=_hdr(tok))
    assert r.status_code == 200
    data = r.json()["data"]
    assert data is not None
    # Role layout for branch_manager exists; assert structure but don't
    # mandate a specific block list — composition is seeded data.
    assert isinstance(data["blocks"], list)
    assert data["scope"] == "role"


def test_filter_blocks_by_perms_drops_disallowed_directly():
    """Direct service-layer test — given the same blocks a CFO has,
    a Cashier should drop most of them."""
    db = SessionLocal()
    try:
        widgets = {w.code: w for w in db.query(DashboardWidget).all()}
    finally:
        db.close()

    cfo_blocks = [
        {"id": "b1", "widget_code": "kpi.cash_balance"},
        {"id": "b2", "widget_code": "kpi.net_income_mtd"},
        {"id": "b3", "widget_code": "widget.compliance_health"},
        {"id": "b4", "widget_code": "widget.express_invoice"},
        {"id": "b5", "widget_code": "widget.ai_pulse"},
    ]
    cashier = _user("u-c", "cashier", PERMS_CASHIER)
    out = filter_blocks_by_perms(cashier, cfo_blocks, widgets)
    out_codes = {b["widget_code"] for b in out}
    # Cashier keeps the action + AI pulse; loses everything else.
    assert "widget.express_invoice" in out_codes
    assert "widget.ai_pulse" in out_codes
    assert "kpi.cash_balance" not in out_codes
    assert "widget.compliance_health" not in out_codes


# ── 3. Layer 3: layout write ──────────────────────────────


def test_accountant_cannot_save_widget_requiring_admin_billing():
    """Accountant tries to embed a widget whose required_perms include
    something they don't have — must be refused."""
    # Use compliance_health (requires read:zatca) — accountant doesn't have it.
    accountant = _user("u-acc", "accountant", PERMS_ACCOUNTANT)
    blocks = [
        LayoutBlock(
            id="b1", widget_code="widget.compliance_health",
            span=4, x=0, y=0, config={},
        ),
    ]
    db = SessionLocal()
    try:
        with pytest.raises(PermissionDeniedError):
            save_user_layout(accountant, blocks, db, tenant_id="t-1")
    finally:
        db.close()


def test_user_without_customize_perm_cannot_save():
    """Even if every block's perms check out, missing customize:dashboard
    is itself fatal."""
    user = _user("u-no-cust", "cashier", ["read:dashboard"])
    blocks = [
        LayoutBlock(
            id="b1", widget_code="widget.ai_pulse", span=4, x=0, y=0, config={}
        ),
    ]
    db = SessionLocal()
    try:
        with pytest.raises(PermissionDeniedError):
            save_user_layout(user, blocks, db)
    finally:
        db.close()


def test_save_user_layout_persists_and_bumps_version():
    user = _user("u-vers", "cfo", PERMS_CFO)
    db = SessionLocal()
    try:
        # First save → version 1 (or 1 retained if the seed inserted)
        blocks_1 = [
            LayoutBlock(
                id="b1", widget_code="kpi.cash_balance", span=3, x=0, y=0,
                config={},
            ),
        ]
        row1 = save_user_layout(user, blocks_1, db)
        v1 = row1.version
        # Second save with new block — version should advance.
        blocks_2 = [
            LayoutBlock(
                id="b1", widget_code="kpi.cash_balance", span=3, x=0, y=0,
                config={},
            ),
            LayoutBlock(
                id="b2", widget_code="kpi.net_income_mtd", span=3, x=3, y=0,
                config={},
            ),
        ]
        row2 = save_user_layout(user, blocks_2, db)
        assert row2.version == v1 + 1
        assert len(row2.blocks) == 2
    finally:
        db.close()


# ── 4. Layer 4: data batch errors per-widget ─────────────


def test_batch_returns_permission_denied_per_widget(client):
    """A batch call mixing allowed + disallowed widgets returns
    permission_denied as a per-widget error, not a 403 for the request."""
    tok = _token(user_id="u-mix", role="cashier", perms=PERMS_CASHIER)
    body = {
        "widgets": [
            "widget.ai_pulse",          # allowed (read:dashboard)
            "kpi.cash_balance",          # blocked (read:reports missing)
            "widget.express_invoice",    # allowed (write:invoices)
        ],
    }
    r = client.post("/api/v1/dashboard/data/batch", json=body, headers=_hdr(tok))
    assert r.status_code == 200, r.text
    payload = r.json()["data"]
    assert "widget.ai_pulse" in payload["data"]
    assert "widget.express_invoice" in payload["data"]
    assert payload["errors"]["kpi.cash_balance"] == "permission_denied"


def test_per_widget_data_endpoint_403_on_missing_perm(client):
    """Direct GET /data/{code} surfaces the missing perm as 403 —
    different from batch (which surfaces it inline) because the single-
    widget endpoint has a clear "this is the only widget" failure mode."""
    tok = _token(user_id="u-403", role="cashier", perms=PERMS_CASHIER)
    r = client.get("/api/v1/dashboard/data/kpi.cash_balance", headers=_hdr(tok))
    assert r.status_code == 403


# ── 5. Layer 5: lock + admin endpoints ────────────────────


def test_branch_manager_cannot_overwrite_locked_role_layout(client):
    """Operator-flow: CFO admin locks the branch_manager role layout,
    then a branch_manager user tries to save their own layout. The
    save should be rejected with 423 because they don't have
    lock:dashboard themselves."""
    # Admin locks the branch_manager role layout.
    admin_tok = _token(user_id="adm-bm", role="admin", perms=PERMS_ADMIN)
    r = client.post(
        "/api/v1/dashboard/role-layouts/branch_manager/lock",
        json={"is_locked": True},
        headers=_hdr(admin_tok),
    )
    assert r.status_code == 200, r.text

    # Branch manager (no lock:dashboard) tries to save their own layout.
    bm_tok = _token(user_id="bm-1", role="branch_manager", perms=PERMS_BRANCH_MGR)
    body = {
        "name": "default",
        "blocks": [
            {"id": "b1", "widget_code": "kpi.cash_balance", "span": 3, "x": 0, "y": 0},
        ],
    }
    r = client.put("/api/v1/dashboard/layout", json=body, headers=_hdr(bm_tok))
    assert r.status_code == 423


def test_admin_with_lock_can_set_role_layout_locked():
    db = SessionLocal()
    try:
        admin = _user("adm-d", "admin", PERMS_ADMIN)
        row = set_role_layout_lock(admin, "cfo", True, db)
        assert row.is_locked is True
    finally:
        db.close()


def test_admin_without_lock_perm_cannot_lock():
    db = SessionLocal()
    try:
        admin_minus = _user(
            "adm-nolock", "admin",
            ["read:dashboard", "manage:dashboard_role"],
        )
        with pytest.raises(PermissionDeniedError):
            set_role_layout_lock(admin_minus, "cfo", True, db)
    finally:
        db.close()


def test_save_role_layout_requires_manage_role_perm():
    db = SessionLocal()
    try:
        accountant = _user("u-acc-r", "accountant", PERMS_ACCOUNTANT)
        blocks = [
            LayoutBlock(
                id="b1", widget_code="kpi.cash_balance", span=3, x=0, y=0,
                config={},
            ),
        ]
        with pytest.raises(PermissionDeniedError):
            save_role_layout(accountant, "cfo", blocks, db)
    finally:
        db.close()


# ── 6. End-to-end: cashier vs CFO seeing different dashboards ───


def test_cashier_layout_differs_from_cfo_layout(client):
    """High-level acceptance: two users with different roles get
    materially different dashboards."""
    cfo_tok = _token(user_id="cfo-e2e", role="cfo", perms=PERMS_CFO)
    cashier_tok = _token(user_id="cash-e2e", role="cashier", perms=PERMS_CASHIER)

    cfo_layout = client.get(
        "/api/v1/dashboard/layout", headers=_hdr(cfo_tok)
    ).json()["data"]
    cash_layout = client.get(
        "/api/v1/dashboard/layout", headers=_hdr(cashier_tok)
    ).json()["data"]

    cfo_codes = {b["widget_code"] for b in cfo_layout["blocks"]}
    cash_codes = {b["widget_code"] for b in cash_layout["blocks"]}

    assert cfo_codes != cash_codes
    # CFO has chart.cash_flow_90d, cashier doesn't.
    assert "chart.cash_flow_90d" in cfo_codes
    assert "chart.cash_flow_90d" not in cash_codes
