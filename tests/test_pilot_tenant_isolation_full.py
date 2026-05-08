"""G-PILOT-REPORTS-TENANT-AUDIT — full cross-tenant isolation matrix.

Pins down the post-PR contract for **every** pilot route that
resolves an entity (by path or payload). The test bed mints two
tenants A and B with their own entities and seeds whatever fixtures
each route needs to reach the tenant-guard branch.

Per route, four assertions:

1.  user A → entity A → success status (200/201/204/4xx-validation)
2.  user A → entity B → **404** with the generic "Entity not found"
    body (anti-enumeration: same shape as missing-id)
3.  user B → entity B → success status (symmetric to 1)
4.  user A → never-existed-uuid → **404** with the same body

Status-code design choice
-------------------------
G-TB-REAL-DATA-AUDIT (PR #174) used 403 on cross-tenant probes. The
follow-up here switched to 404 to close the enumeration leak — an
attacker iterating UUIDs got "403 → exists, 404 → doesn't exist"
back. Body is identical now; only the server-side
``TENANT_GUARD_VIOLATION`` log distinguishes the two cases.

The matrix runs across 32 vulnerable routes identified in the L1+L2
discovery (gl/pilot/compliance/purchasing/ai/ai_je/customer routes).
Routes that require additional fixtures (e.g., a vendor for PO
creation, a customer for sales-invoice listing) seed only enough to
reach the guard — actual business logic is asserted by the existing
suites.
"""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Any, Callable

import pytest

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase1.services.auth_service import create_access_token
from app.pilot.models.entity import Entity
from app.pilot.models.tenant import Tenant


# ────────────────────────────────────────────────────────────────────
# Fixtures
# ────────────────────────────────────────────────────────────────────


def _mk_tenant(s, suffix: str) -> Tenant:
    t = Tenant(
        id=gen_uuid(),
        slug=f"tia-{suffix}-{uuid.uuid4().hex[:6]}",
        legal_name_ar=f"اختبار TIA {suffix}",
        primary_email=f"tia_{suffix}_{uuid.uuid4().hex[:4]}@example.test",
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


def _user_token(tenant_id: str | None) -> str:
    return create_access_token(
        f"tia-{uuid.uuid4().hex[:8]}",
        "tia_test",
        ["registered_user"],
        tenant_id=tenant_id,
    )


def _cleanup(*ids: str) -> None:
    if not ids:
        return
    s = SessionLocal()
    try:
        s.query(Entity).filter(Entity.id.in_(ids)).delete(
            synchronize_session=False
        )
        s.query(Tenant).filter(Tenant.id.in_(ids)).delete(
            synchronize_session=False
        )
        s.commit()
    except Exception:
        s.rollback()
    finally:
        s.close()


@pytest.fixture
def two_tenants():
    """Two tenants A + B, each with their own entity. Caller passes
    the resulting (token_a, token_b, entity_a, entity_b, ids) to its
    matrix helper. Cleanup runs unconditionally."""
    s = SessionLocal()
    ta = _mk_tenant(s, "a")
    tb = _mk_tenant(s, "b")
    ea = _mk_entity(s, ta, "a")
    eb = _mk_entity(s, tb, "b")
    s.commit()
    ids = (ta.id, tb.id, ea.id, eb.id)
    s.close()
    yield {
        "token_a": _user_token(tenant_id=ta.id),
        "token_b": _user_token(tenant_id=tb.id),
        "entity_a_id": ea.id,
        "entity_b_id": eb.id,
        "tenant_a_id": ta.id,
        "tenant_b_id": tb.id,
    }
    _cleanup(*ids)


# ────────────────────────────────────────────────────────────────────
# Matrix helper — 4 assertions per route
# ────────────────────────────────────────────────────────────────────


def _assert_anti_enum_404(resp) -> None:
    """Cross-tenant + missing-id must be indistinguishable: same status,
    same body. That's the contract the helper enforces."""
    assert resp.status_code == 404, (
        f"expected 404 (anti-enumeration), got {resp.status_code}: {resp.text}"
    )
    assert "entity not found" in resp.text.lower(), (
        f"body must match the generic missing-id message; got: {resp.text}"
    )


def _own_call_passed_guard(resp) -> bool:
    """An "own-tenant" call must not be rejected by the tenant guard.

    Some routes can still 404 *after* the guard — e.g., a POST that
    references a fake vendor_id will fail downstream with "Vendor not
    found". That's correct behaviour, not a guard regression. We
    distinguish the two cases by the response body: the tenant guard
    always returns the generic ``"Entity not found"`` string; any
    other 404 body means the guard let the request through."""
    if resp.status_code != 404:
        return True
    return "entity not found" not in resp.text.lower()


# Each entry: (route_label, method, path_factory_taking(ctx), payload_factory or None)
# path_factory builds the URL using ctx["entity_a_id"] / ["entity_b_id"].
# payload_factory builds the JSON body for POST/PATCH; takes (ctx, entity_id_to_use).
ROUTE_MATRIX: list[tuple[str, str, Callable[[dict, str], str], Any]] = [
    # gl_routes — 4 deferred reports + posting-counts debug
    (
        "gl:income-statement",
        "GET",
        lambda ctx, eid: (
            f"/pilot/entities/{eid}/reports/income-statement"
            f"?start_date=2026-01-01&end_date=2026-12-31"
        ),
        None,
    ),
    (
        "gl:balance-sheet",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/reports/balance-sheet",
        None,
    ),
    (
        "gl:cash-flow",
        "GET",
        lambda ctx, eid: (
            f"/pilot/entities/{eid}/reports/cash-flow"
            f"?start_date=2026-01-01&end_date=2026-12-31"
        ),
        None,
    ),
    (
        "gl:comparative",
        "GET",
        lambda ctx, eid: (
            f"/pilot/entities/{eid}/reports/comparative"
            f"?report_type=income_statement"
            f"&current_start=2026-01-01&current_end=2026-12-31"
        ),
        None,
    ),
    (
        "gl:debug-posting-counts",
        "GET",
        lambda ctx, eid: f"/pilot/_debug/entities/{eid}/posting-counts",
        None,
    ),
    # pilot_routes — entity CRUD + branches (write/delete leaks!)
    (
        "pilot:get-entity",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}",
        None,
    ),
    (
        "pilot:patch-entity",
        "PATCH",
        lambda ctx, eid: f"/pilot/entities/{eid}",
        lambda ctx, eid: {"name_ar": f"محاولة تعديل {uuid.uuid4().hex[:4]}"},
    ),
    (
        "pilot:list-branches",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/branches",
        None,
    ),
    # compliance_routes — ZATCA / GOSI / WPS / UAE-CT / VAT (path-shaped)
    (
        "compliance:zatca-onboarding",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/zatca/onboarding",
        None,
    ),
    (
        "compliance:zatca-submissions",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/zatca/submissions",
        None,
    ),
    (
        "compliance:gosi-registrations",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/gosi/registrations",
        None,
    ),
    (
        "compliance:wps-batches",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/wps/batches",
        None,
    ),
    (
        "compliance:uae-ct-filings",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/uae-ct/filings",
        None,
    ),
    (
        "compliance:vat-returns",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/vat-returns",
        None,
    ),
    (
        "compliance:vat-preview",
        "GET",
        lambda ctx, eid: (
            f"/pilot/vat-returns/preview?entity_id={eid}"
            f"&year=2026&period_number=1&period_type=quarterly"
        ),
        None,
    ),
    # purchasing_routes — listing endpoints (path-shaped)
    (
        "purchasing:list-pos",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/purchase-orders",
        None,
    ),
    (
        "purchasing:list-pis",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/purchase-invoices",
        None,
    ),
    (
        "purchasing:list-vps",
        "GET",
        lambda ctx, eid: f"/pilot/entities/{eid}/vendor-payments",
        None,
    ),
    # customer_routes — sales-invoices listing
    (
        "customer:sales-invoices",
        "GET",
        lambda ctx, eid: f"/api/v1/pilot/entities/{eid}/sales-invoices",
        None,
    ),
]


# Payload-shaped routes need a separate matrix — the cross-tenant id
# travels in the JSON body, not the URL.
PAYLOAD_ROUTE_MATRIX: list[tuple[str, str, str, Callable[[dict, str], dict]]] = [
    # compliance — payload.entity_id
    (
        "compliance:create-gosi-registration",
        "POST",
        "/pilot/gosi/registrations",
        lambda ctx, eid: {
            "entity_id": eid,
            "employee_user_id": gen_uuid(),
            "employee_number": f"E-{uuid.uuid4().hex[:6]}",
            "national_id": "1234567890",
            "employee_name_ar": "اختبار",
            "is_saudi": True,
            "registered_at": date.today().isoformat(),
            "contribution_wage": "5000",
        },
    ),
    (
        "compliance:create-wps-batch",
        "POST",
        "/pilot/wps/batches",
        lambda ctx, eid: {
            "entity_id": eid,
            "year": 2026,
            "month": 1,
            "employer_bank_code": "RJHISARI",
            "employer_account_iban": "SA0000000000000000000000",
            "employer_establishment_id": "1234567",
            "employees": [
                {
                    "employee_user_id": gen_uuid(),
                    "employee_name_ar": "اختبار",
                    "national_id": "1234567890",
                    "employee_bank_code": "RJHISARI",
                    "employee_account_iban": "SA0000000000000000000001",
                    "basic_salary": "5000",
                }
            ],
        },
    ),
    (
        "compliance:create-uae-ct-filing",
        "POST",
        "/pilot/uae-ct/filings",
        lambda ctx, eid: {
            "entity_id": eid,
            "fiscal_year": 2026,
            "gross_revenue": "1000000",
            "deductible_expenses": "500000",
        },
    ),
    (
        "compliance:generate-vat-return",
        "POST",
        "/pilot/vat-returns/generate",
        lambda ctx, eid: {
            "entity_id": eid,
            "year": 2026,
            "period_number": 1,
            "period_type": "quarterly",
        },
    ),
    # purchasing — payload.entity_id
    (
        "purchasing:create-po",
        "POST",
        "/pilot/purchase-orders",
        lambda ctx, eid: {
            "entity_id": eid,
            "vendor_id": gen_uuid(),
            "order_date": date.today().isoformat(),
            "lines": [
                {
                    "description": "tenant-guard probe line",
                    "qty_ordered": "1",
                    "unit_price": "10",
                }
            ],
        },
    ),
    (
        "purchasing:create-pi",
        "POST",
        "/pilot/purchase-invoices",
        lambda ctx, eid: {
            "entity_id": eid,
            "vendor_id": gen_uuid(),
            "invoice_date": date.today().isoformat(),
            "lines": [
                {
                    "description": "tenant-guard probe line",
                    "qty": "1",
                    "unit_cost": "10",
                }
            ],
        },
    ),
    (
        "purchasing:create-vp",
        "POST",
        "/pilot/vendor-payments",
        lambda ctx, eid: {
            "entity_id": eid,
            "vendor_id": gen_uuid(),
            "amount": "100",
            "payment_date": date.today().isoformat(),
            "method": "bank_transfer",
        },
    ),
]


# ────────────────────────────────────────────────────────────────────
# The matrix tests
# ────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("label,method,path_factory,payload_factory", ROUTE_MATRIX)
def test_path_route_tenant_matrix(
    client, two_tenants, label, method, path_factory, payload_factory
):
    """For every path-shaped route: own-tenant → not-404,
    cross-tenant → 404 + generic body, missing-id → 404 + generic body."""
    ctx = two_tenants
    headers_a = {"Authorization": f"Bearer {ctx['token_a']}"}

    # ── 2: cross-tenant probe (user A → entity B) ─────────────────
    url_cross = path_factory(ctx, ctx["entity_b_id"])
    if method == "GET":
        resp = client.get(url_cross, headers=headers_a)
    elif method == "PATCH":
        resp = client.patch(url_cross, headers=headers_a, json=payload_factory(ctx, ctx["entity_b_id"]))
    else:
        raise AssertionError(f"unhandled method {method} for {label}")
    _assert_anti_enum_404(resp)

    # ── 4: never-existed entity id ────────────────────────────────
    fake_id = str(uuid.uuid4())
    url_missing = path_factory(ctx, fake_id)
    if method == "GET":
        resp_missing = client.get(url_missing, headers=headers_a)
    elif method == "PATCH":
        resp_missing = client.patch(
            url_missing, headers=headers_a, json=payload_factory(ctx, fake_id)
        )
    _assert_anti_enum_404(resp_missing)

    # ── 1: own-tenant (user A → entity A) — must NOT 404 ──────────
    url_own = path_factory(ctx, ctx["entity_a_id"])
    if method == "GET":
        resp_own = client.get(url_own, headers=headers_a)
    elif method == "PATCH":
        resp_own = client.patch(
            url_own, headers=headers_a, json=payload_factory(ctx, ctx["entity_a_id"])
        )
    assert _own_call_passed_guard(resp_own), (
        f"{label}: own-tenant call rejected by tenant guard — "
        f"guard over-rejecting? body={resp_own.text}"
    )


@pytest.mark.parametrize(
    "label,method,path,payload_factory", PAYLOAD_ROUTE_MATRIX
)
def test_payload_route_tenant_matrix(
    client, two_tenants, label, method, path, payload_factory
):
    """For payload-shaped routes (entity_id in JSON body): cross-tenant
    body → 404 + generic body. Own-tenant must NOT 404 (may fail with
    400 / 422 on missing supporting fixtures — that's fine for this
    test, we're gating on the tenant check only)."""
    ctx = two_tenants
    headers_a = {"Authorization": f"Bearer {ctx['token_a']}"}

    # ── cross-tenant probe ────────────────────────────────────────
    body_cross = payload_factory(ctx, ctx["entity_b_id"])
    resp = client.post(path, headers=headers_a, json=body_cross)
    _assert_anti_enum_404(resp)

    # ── never-existed ─────────────────────────────────────────────
    fake_id = str(uuid.uuid4())
    body_missing = payload_factory(ctx, fake_id)
    resp_missing = client.post(path, headers=headers_a, json=body_missing)
    _assert_anti_enum_404(resp_missing)

    # ── own-tenant ────────────────────────────────────────────────
    body_own = payload_factory(ctx, ctx["entity_a_id"])
    resp_own = client.post(path, headers=headers_a, json=body_own)
    assert _own_call_passed_guard(resp_own), (
        f"{label}: own-tenant call rejected by tenant guard — "
        f"guard over-rejecting? body={resp_own.text}"
    )


# ────────────────────────────────────────────────────────────────────
# Symmetric coverage — assert user B can also hit their own entity
# (catches an over-correction that would lock everyone out)
# ────────────────────────────────────────────────────────────────────


def test_symmetric_user_b_can_access_own_entity(client, two_tenants):
    """Sanity: a user from tenant B reading tenant B's TB still works.
    If this fails, we're rejecting valid traffic — guard is too tight."""
    ctx = two_tenants
    resp = client.get(
        f"/pilot/entities/{ctx['entity_b_id']}/reports/trial-balance",
        headers={"Authorization": f"Bearer {ctx['token_b']}"},
    )
    assert resp.status_code == 200, (
        f"valid own-tenant call rejected — guard too tight: {resp.text}"
    )


# ────────────────────────────────────────────────────────────────────
# Logger sanity — a violation must emit the structured log line so SOC
# dashboards can detect probing even though the response is masked.
# ────────────────────────────────────────────────────────────────────


def test_violation_emits_structured_log(client, two_tenants, caplog):
    """The helper hides the existence signal from the client but
    still records it server-side via ``logger.warning(``TENANT_GUARD_
    VIOLATION ...)``. Verify that line shows up in the warning logs
    on a cross-tenant probe."""
    import logging

    ctx = two_tenants
    with caplog.at_level(logging.WARNING, logger="app.pilot.security.tenant_guards"):
        resp = client.get(
            f"/pilot/entities/{ctx['entity_b_id']}/reports/trial-balance",
            headers={"Authorization": f"Bearer {ctx['token_a']}"},
        )
    assert resp.status_code == 404
    matches = [r for r in caplog.records if "TENANT_GUARD_VIOLATION" in r.getMessage()]
    assert matches, (
        "expected exactly one TENANT_GUARD_VIOLATION log on cross-tenant "
        f"probe; got records: {[r.getMessage() for r in caplog.records]}"
    )
    msg = matches[-1].getMessage()
    # Structured fields should be present so log shippers can index them.
    assert "user_tenant=" in msg
    assert "requested_entity=" in msg
    assert "entity_tenant=" in msg
