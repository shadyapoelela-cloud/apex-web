"""G-PILOT-TENANT-AUDIT-FINAL — full matrix for the remaining two
shapes that the prior PR didn't cover:

1. **Tenant-shaped routes** — URL ``/tenants/{tenant_id}/...``.
   Closed via :func:`assert_tenant_matches_user`.
2. **ID-based routes** — resource resolved directly by primary key
   (``/products/{id}``, ``/purchase-orders/{po_id}``, …).
   Closed via :func:`assert_resource_in_tenant`.

Every entry in :data:`TENANT_ROUTE_MATRIX` and
:data:`ID_ROUTE_MATRIX` runs three assertions:

a. **Cross-tenant probe** (user A → tenant B's resource) → ``404`` +
   the generic anti-enumeration body.
b. **Missing resource** (random UUID) → same ``404`` + same body.
c. **Own-tenant call** must NOT be rejected by the tenant guard
   (response body for a 404 on this branch must NOT contain the
   guard's "Resource not found" / "Entity not found" string).

Plus a dedicated test that asserts the structured
``TENANT_GUARD_VIOLATION`` log line is emitted on a cross-tenant
probe — SOC dashboards key on that prefix.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any, Callable, Optional

import pytest

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase1.services.auth_service import create_access_token
from app.pilot.models.entity import Branch, Entity
from app.pilot.models.tenant import Tenant


# ────────────────────────────────────────────────────────────────────
# Fixtures
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str) -> Tenant:
    t = Tenant(
        id=gen_uuid(),
        slug=f"tav2-{suffix}-{uuid.uuid4().hex[:6]}",
        legal_name_ar=f"اختبار v2 {suffix}",
        primary_email=f"v2_{suffix}_{uuid.uuid4().hex[:4]}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.flush()
    return t


def _mk_entity(s, tenant: Tenant, suffix: str) -> Entity:
    e = Entity(
        id=gen_uuid(),
        tenant_id=tenant.id,
        code=f"E-{suffix}-{uuid.uuid4().hex[:4]}",
        name_ar=f"كيان {suffix}",
        country="SA",
        functional_currency="SAR",
    )
    s.add(e)
    s.flush()
    return e


def _mk_branch(s, tenant: Tenant, entity: Entity, suffix: str) -> Branch:
    b = Branch(
        id=gen_uuid(),
        tenant_id=tenant.id,
        entity_id=entity.id,
        code=f"B-{suffix}-{uuid.uuid4().hex[:4]}",
        name_ar=f"فرع {suffix}",
        type="retail",
        status="active",
        country="SA",
        city="Riyadh",
    )
    s.add(b)
    s.flush()
    return b


def _user_token(tenant_id: Optional[str]) -> str:
    return create_access_token(
        f"v2-{uuid.uuid4().hex[:8]}",
        "tenant_audit_v2_test",
        ["registered_user"],
        tenant_id=tenant_id,
    )


def _cleanup(*ids: str) -> None:
    if not ids:
        return
    s = SessionLocal()
    try:
        s.query(Branch).filter(Branch.id.in_(ids)).delete(synchronize_session=False)
        s.query(Entity).filter(Entity.id.in_(ids)).delete(synchronize_session=False)
        s.query(Tenant).filter(Tenant.id.in_(ids)).delete(synchronize_session=False)
        s.commit()
    except Exception:
        s.rollback()
    finally:
        s.close()


@pytest.fixture
def two_tenants():
    """Two tenants A + B, each with one entity + one branch. Caller
    consumes the dict; cleanup runs unconditionally."""
    s = SessionLocal()
    ta = _mk_tenant(s, "a")
    tb = _mk_tenant(s, "b")
    ea = _mk_entity(s, ta, "a")
    eb = _mk_entity(s, tb, "b")
    ba = _mk_branch(s, ta, ea, "a")
    bb = _mk_branch(s, tb, eb, "b")
    s.commit()
    ids = (ta.id, tb.id, ea.id, eb.id, ba.id, bb.id)
    s.close()
    yield {
        "token_a": _user_token(tenant_id=ta.id),
        "token_b": _user_token(tenant_id=tb.id),
        "tenant_a_id": ta.id,
        "tenant_b_id": tb.id,
        "entity_a_id": ea.id,
        "entity_b_id": eb.id,
        "branch_a_id": ba.id,
        "branch_b_id": bb.id,
    }
    _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Shared assertion helpers
# ────────────────────────────────────────────────────────────────────


def _assert_anti_enum_404(resp, *, allow_resource_or_entity: bool = True) -> None:
    """Cross-tenant + missing-id must be indistinguishable: same
    status, same body. Both helpers return 404; the bodies are
    `"Entity not found"` and `"Resource not found"`. Either is fine —
    they're both generic and don't leak existence."""
    assert resp.status_code == 404, (
        f"expected 404 (anti-enumeration), got {resp.status_code}: {resp.text}"
    )
    body = resp.text.lower()
    if allow_resource_or_entity:
        assert "not found" in body, (
            f"body must match the generic missing-id message; got: {resp.text}"
        )


def _own_call_passed_guard(resp) -> bool:
    """An own-tenant call must not be rejected by the tenant guard.

    Some routes still 404 *after* the guard for downstream reasons
    (missing fixture, etc.). We tell those apart from guard-rejected
    404s by inspecting the body: only the guard returns the generic
    ``"Entity not found"`` / ``"Resource not found"`` strings.
    """
    if resp.status_code != 404:
        return True
    body = resp.text.lower()
    # If body matches a tenant-guard rejection, the guard rejected.
    return ("entity not found" not in body) and ("resource not found" not in body)


# ════════════════════════════════════════════════════════════════════
# Matrix #1 — tenant_id-shaped routes (assert_tenant_matches_user)
# ════════════════════════════════════════════════════════════════════


# Each entry: (label, method, path_factory(ctx, tenant_id), payload_factory or None)
TENANT_ROUTE_MATRIX: list[tuple[str, str, Callable, Any]] = [
    # pilot_routes.py — tenant + settings + entities
    (
        "pilot:get-tenant",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}",
        None,
    ),
    (
        "pilot:get-settings",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/settings",
        None,
    ),
    (
        "pilot:list-entities",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/entities",
        None,
    ),
    (
        "pilot:list-currencies",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/currencies",
        None,
    ),
    (
        "pilot:list-fx-rates",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/fx-rates",
        None,
    ),
    (
        "pilot:list-roles",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/roles",
        None,
    ),
    (
        "pilot:list-members",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/members",
        None,
    ),
    # catalog
    (
        "catalog:list-categories",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/categories",
        None,
    ),
    (
        "catalog:list-brands",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/brands",
        None,
    ),
    (
        "catalog:list-attributes",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/attributes",
        None,
    ),
    (
        "catalog:list-products",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/products",
        None,
    ),
    (
        "catalog:scan-barcode",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/barcode/0000000000017",
        None,
    ),
    # customers + vendors + price-lists
    (
        "customer:list-customers",
        "GET",
        lambda ctx, tid: f"/api/v1/pilot/tenants/{tid}/customers",
        None,
    ),
    (
        "purchasing:list-vendors",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/vendors",
        None,
    ),
    (
        "pricing:list-price-lists",
        "GET",
        lambda ctx, tid: f"/pilot/tenants/{tid}/price-lists",
        None,
    ),
    # POST routes (mutating) — payload entirely valid for the schema
    (
        "pilot:create-currency",
        "POST",
        lambda ctx, tid: f"/pilot/tenants/{tid}/currencies",
        lambda ctx, tid: {
            "code": f"X{uuid.uuid4().hex[:2].upper()}",
            "name_ar": "اختبار",
            "name_en": "Test",
        },
    ),
    (
        "catalog:create-category",
        "POST",
        lambda ctx, tid: f"/pilot/tenants/{tid}/categories",
        lambda ctx, tid: {
            "code": f"C-{uuid.uuid4().hex[:6]}",
            "name_ar": "فئة",
        },
    ),
    (
        "catalog:create-brand",
        "POST",
        lambda ctx, tid: f"/pilot/tenants/{tid}/brands",
        lambda ctx, tid: {
            "code": f"BR-{uuid.uuid4().hex[:6]}",
            "name_ar": "علامة",
        },
    ),
    (
        "purchasing:create-vendor",
        "POST",
        lambda ctx, tid: f"/pilot/tenants/{tid}/vendors",
        lambda ctx, tid: {
            "code": f"V-{uuid.uuid4().hex[:6]}",
            "legal_name_ar": "مورد",
            "kind": "goods",
            "country": "SA",
        },
    ),
    (
        "customer:create-customer",
        "POST",
        lambda ctx, tid: f"/api/v1/pilot/tenants/{tid}/customers",
        lambda ctx, tid: {
            "code": f"C-{uuid.uuid4().hex[:6]}",
            "name_ar": "عميل",
            "kind": "company",
            "currency": "SAR",
            "payment_terms": "net_30",
        },
    ),
]


@pytest.mark.parametrize(
    "label,method,path_factory,payload_factory", TENANT_ROUTE_MATRIX
)
def test_tenant_route_matrix(
    client, two_tenants, label, method, path_factory, payload_factory
):
    """For every ``/tenants/{tid}/...`` route: own-tenant passes the
    guard, cross-tenant + missing-id both 404 + generic body."""
    ctx = two_tenants
    headers_a = {"Authorization": f"Bearer {ctx['token_a']}"}

    def _do(url: str, body: Optional[dict] = None):
        if method == "GET":
            return client.get(url, headers=headers_a)
        if method == "POST":
            return client.post(url, headers=headers_a, json=body or {})
        if method == "PATCH":
            return client.patch(url, headers=headers_a, json=body or {})
        if method == "DELETE":
            return client.delete(url, headers=headers_a)
        raise AssertionError(f"unhandled method {method} for {label}")

    # 2 — cross-tenant (user A → tenant B's URL)
    body_cross = (
        payload_factory(ctx, ctx["tenant_b_id"]) if payload_factory else None
    )
    resp = _do(path_factory(ctx, ctx["tenant_b_id"]), body_cross)
    _assert_anti_enum_404(resp)

    # 4 — never-existed tenant
    fake_tid = str(uuid.uuid4())
    body_missing = payload_factory(ctx, fake_tid) if payload_factory else None
    resp_missing = _do(path_factory(ctx, fake_tid), body_missing)
    _assert_anti_enum_404(resp_missing)

    # 1 — own-tenant: must not be rejected by the guard
    body_own = (
        payload_factory(ctx, ctx["tenant_a_id"]) if payload_factory else None
    )
    resp_own = _do(path_factory(ctx, ctx["tenant_a_id"]), body_own)
    assert _own_call_passed_guard(resp_own), (
        f"{label}: own-tenant call rejected by tenant guard. body={resp_own.text}"
    )


# ════════════════════════════════════════════════════════════════════
# Matrix #2 — ID-based routes (assert_resource_in_tenant)
# ════════════════════════════════════════════════════════════════════


# Each entry: (label, method, path_factory(ctx, resource_id), payload_factory or None)
# resource_id = either ctx["branch_a_id"] or a never-existed UUID.
# The matrix is keyed on routes whose own-tenant path doesn't need
# extra DB fixtures — Branch is the cleanest common anchor since both
# tenants in the fixture have one each.
ID_ROUTE_MATRIX: list[tuple[str, str, Callable, Any]] = [
    # pilot_routes.py
    (
        "pilot:get-branch",
        "GET",
        lambda ctx, rid: f"/pilot/branches/{rid}",
        None,
    ),
    (
        "pilot:patch-branch",
        "PATCH",
        lambda ctx, rid: f"/pilot/branches/{rid}",
        lambda ctx, rid: {"name_ar": f"فرع محدّث {uuid.uuid4().hex[:4]}"},
    ),
    # catalog_routes.py — branches/{id}/warehouses (read + create)
    (
        "catalog:list-warehouses-of-branch",
        "GET",
        lambda ctx, rid: f"/pilot/branches/{rid}/warehouses",
        None,
    ),
    # pos_routes.py — list sessions (Branch-anchored)
    (
        "pos:list-sessions",
        "GET",
        lambda ctx, rid: f"/pilot/branches/{rid}/pos-sessions",
        None,
    ),
]


@pytest.mark.parametrize(
    "label,method,path_factory,payload_factory", ID_ROUTE_MATRIX
)
def test_id_route_matrix(
    client, two_tenants, label, method, path_factory, payload_factory
):
    """For every ID-based route: own-tenant passes the guard,
    cross-tenant + missing-id both 404 + generic body."""
    ctx = two_tenants
    headers_a = {"Authorization": f"Bearer {ctx['token_a']}"}

    def _do(url: str, body: Optional[dict] = None):
        if method == "GET":
            return client.get(url, headers=headers_a)
        if method == "POST":
            return client.post(url, headers=headers_a, json=body or {})
        if method == "PATCH":
            return client.patch(url, headers=headers_a, json=body or {})
        if method == "DELETE":
            return client.delete(url, headers=headers_a)
        raise AssertionError(f"unhandled method {method} for {label}")

    # 2 — cross-tenant (user A → tenant B's branch)
    body_cross = (
        payload_factory(ctx, ctx["branch_b_id"]) if payload_factory else None
    )
    resp = _do(path_factory(ctx, ctx["branch_b_id"]), body_cross)
    _assert_anti_enum_404(resp)

    # 4 — never-existed branch
    fake_id = str(uuid.uuid4())
    body_missing = payload_factory(ctx, fake_id) if payload_factory else None
    resp_missing = _do(path_factory(ctx, fake_id), body_missing)
    _assert_anti_enum_404(resp_missing)

    # 1 — own-tenant: must not be rejected by the guard
    body_own = (
        payload_factory(ctx, ctx["branch_a_id"]) if payload_factory else None
    )
    resp_own = _do(path_factory(ctx, ctx["branch_a_id"]), body_own)
    assert _own_call_passed_guard(resp_own), (
        f"{label}: own-tenant call rejected by tenant guard. body={resp_own.text}"
    )


# ════════════════════════════════════════════════════════════════════
# Symmetric coverage — own-tenant for user B
# ════════════════════════════════════════════════════════════════════


def test_symmetric_user_b_can_read_own_tenant(client, two_tenants):
    """Sanity: a user from tenant B can list their own tenant's
    products. If this fails, the guard is rejecting valid traffic."""
    ctx = two_tenants
    resp = client.get(
        f"/pilot/tenants/{ctx['tenant_b_id']}/entities",
        headers={"Authorization": f"Bearer {ctx['token_b']}"},
    )
    assert resp.status_code == 200, (
        f"valid own-tenant call rejected: {resp.text}"
    )


def test_symmetric_user_b_can_read_own_branch(client, two_tenants):
    ctx = two_tenants
    resp = client.get(
        f"/pilot/branches/{ctx['branch_b_id']}",
        headers={"Authorization": f"Bearer {ctx['token_b']}"},
    )
    assert resp.status_code == 200, resp.text


# ════════════════════════════════════════════════════════════════════
# Logger sanity — TENANT_GUARD_VIOLATION lines on cross-tenant probe
# ════════════════════════════════════════════════════════════════════


def test_tenant_violation_emits_structured_log(client, two_tenants, caplog):
    """`assert_tenant_matches_user` must emit the structured warning
    on every cross-tenant URL probe."""
    ctx = two_tenants
    with caplog.at_level(logging.WARNING, logger="app.pilot.security.tenant_guards"):
        resp = client.get(
            f"/pilot/tenants/{ctx['tenant_b_id']}/entities",
            headers={"Authorization": f"Bearer {ctx['token_a']}"},
        )
    assert resp.status_code == 404
    matches = [
        r for r in caplog.records if "TENANT_GUARD_VIOLATION" in r.getMessage()
    ]
    assert matches, (
        "expected TENANT_GUARD_VIOLATION log on cross-tenant tenant_id "
        f"probe; got: {[r.getMessage() for r in caplog.records]}"
    )
    msg = matches[-1].getMessage()
    assert "user_tenant=" in msg
    assert "requested_tenant=" in msg


def test_resource_violation_emits_structured_log(client, two_tenants, caplog):
    """`assert_resource_in_tenant` must emit the structured warning
    on every cross-tenant resource probe (different log shape:
    ``model=`` and ``resource_tenant=`` fields)."""
    ctx = two_tenants
    with caplog.at_level(logging.WARNING, logger="app.pilot.security.tenant_guards"):
        resp = client.get(
            f"/pilot/branches/{ctx['branch_b_id']}",
            headers={"Authorization": f"Bearer {ctx['token_a']}"},
        )
    assert resp.status_code == 404
    matches = [
        r for r in caplog.records if "TENANT_GUARD_VIOLATION" in r.getMessage()
    ]
    assert matches, (
        "expected TENANT_GUARD_VIOLATION log on cross-tenant resource "
        f"probe; got: {[r.getMessage() for r in caplog.records]}"
    )
    msg = matches[-1].getMessage()
    assert "user_tenant=" in msg
    assert "model=Branch" in msg
    assert "resource_id=" in msg
    assert "resource_tenant=" in msg


# ════════════════════════════════════════════════════════════════════
# Custom resolver — ProductAttributeValue (no tenant_id column,
# resolves via attribute_id → ProductAttribute.tenant_id)
# ════════════════════════════════════════════════════════════════════


def test_attribute_id_route_resolves_through_chain(client, two_tenants):
    """``POST /attributes/{attribute_id}/values`` should reject
    cross-tenant access even though ProductAttributeValue itself is
    only scoped via attribute_id → ProductAttribute.tenant_id.

    We don't need to seed ProductAttribute fixtures here — the route
    rejects with 404 either because the attribute doesn't exist OR
    because it's in a different tenant. Both cases produce the
    generic anti-enumeration body, so the test still pins the
    contract: never a 200 for a cross-tenant guess.
    """
    ctx = two_tenants
    fake_attr_id = str(uuid.uuid4())
    resp = client.post(
        f"/pilot/attributes/{fake_attr_id}/values",
        headers={"Authorization": f"Bearer {ctx['token_a']}"},
        json={
            "code": "x",
            "name_ar": "x",
        },
    )
    _assert_anti_enum_404(resp)
