"""End-to-end tests for the multi-tenant query guard.

These tests are the REGRESSION GUARDS for cross-tenant data leaks —
the highest-severity security issue we can have. If any of these tests
fail, tenant isolation is broken.

Each test follows the same pattern:
  1. Set tenant A, create rows.
  2. Set tenant B, create different rows.
  3. Switch between tenants, confirm queries only see their own data.
  4. Confirm NULL-tenant rows (legacy / system) are shared.
  5. Confirm system bypass sees everything.
"""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal

import pytest


@pytest.fixture(autouse=True)
def _ensure_guard_attached():
    """Make sure the guard is live for this test session."""
    # Import app.main to wire up the guard at module-load time
    from app import main  # noqa: F401
    from app.core import tenant_context

    # Always start with no tenant bound
    tenant_context.set_tenant(None)
    yield
    tenant_context.set_tenant(None)


def _make_employee(session, tenant: str | None, name: str):
    """Create an employee without going through the tenant auto-populate."""
    from app.hr.models import Employee

    emp = Employee(
        id=str(uuid.uuid4()),
        tenant_id=tenant,
        employee_number=f"EMP-{uuid.uuid4().hex[:6]}",
        name_ar=name,
        hire_date=date(2026, 1, 1),
        basic_salary=Decimal("5000"),
        housing_allowance=Decimal("1000"),
        transport_allowance=Decimal("500"),
        other_allowances=Decimal("0"),
        gosi_applicable=True,
        gosi_employee_rate=Decimal("0.10"),
        gosi_employer_rate=Decimal("0.12"),
        status="active",
    )
    session.add(emp)
    session.commit()
    return emp


def _new_session():
    from app.phase1.models.platform_models import SessionLocal

    return SessionLocal()


# ── Core isolation ───────────────────────────────────────────


def test_tenant_a_cannot_see_tenant_b_rows():
    """The headline test: setting tenant A must not expose tenant B rows."""
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.hr.models import Employee

    db = _new_session()
    try:
        with with_system_context():
            _make_employee(db, "tenant-A", "موظف أ")
            _make_employee(db, "tenant-B", "موظف ب")

        set_tenant("tenant-A")
        rows_a = db.query(Employee).all()
        names_a = sorted(r.name_ar for r in rows_a)

        set_tenant("tenant-B")
        rows_b = db.query(Employee).all()
        names_b = sorted(r.name_ar for r in rows_b)
    finally:
        db.close()

    # A must see its employee but NOT B's
    assert "موظف أ" in names_a
    assert "موظف ب" not in names_a

    # B must see its employee but NOT A's
    assert "موظف ب" in names_b
    assert "موظف أ" not in names_b


def test_insert_auto_populates_tenant_from_context():
    """Inserting without explicit tenant_id uses current_tenant()."""
    from app.core.tenant_context import set_tenant
    from app.hr.models import Employee

    db = _new_session()
    set_tenant("tenant-auto-pop")
    try:
        emp = Employee(
            id=str(uuid.uuid4()),
            employee_number=f"AUTO-{uuid.uuid4().hex[:6]}",
            name_ar="auto",
            hire_date=date(2026, 1, 1),
            basic_salary=Decimal("5000"),
            housing_allowance=Decimal("0"),
            transport_allowance=Decimal("0"),
            other_allowances=Decimal("0"),
            gosi_applicable=True,
            gosi_employee_rate=Decimal("0.10"),
            gosi_employer_rate=Decimal("0.12"),
            status="active",
            # tenant_id omitted on purpose
        )
        db.add(emp)
        db.commit()
        db.refresh(emp)
        assert emp.tenant_id == "tenant-auto-pop"
    finally:
        db.close()


def test_null_tenant_rows_visible_to_any_tenant():
    """Rows with tenant_id IS NULL (legacy / system) are shared across
    tenants — important for backwards compatibility with existing data."""
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.hr.models import Employee

    db = _new_session()
    try:
        with with_system_context():
            _make_employee(db, None, "legacy-shared")
            _make_employee(db, "tenant-X", "x-only")

        set_tenant("tenant-X")
        rows = db.query(Employee).all()
        names = [r.name_ar for r in rows]
        assert "legacy-shared" in names
        assert "x-only" in names

        set_tenant("tenant-Y")
        rows = db.query(Employee).all()
        names = [r.name_ar for r in rows]
        assert "legacy-shared" in names  # null-tenant still visible
        assert "x-only" not in names
    finally:
        db.close()


# ── System bypass ───────────────────────────────────────────


def test_system_context_sees_all_tenants():
    """Admin tools / migrations use with_system_context() to see everything."""
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.hr.models import Employee

    db = _new_session()
    try:
        with with_system_context():
            _make_employee(db, "sys-a", "sys employee a")
            _make_employee(db, "sys-b", "sys employee b")

        set_tenant("sys-a")
        filtered = db.query(Employee).all()
        filtered_names = {r.name_ar for r in filtered}
        assert "sys employee a" in filtered_names
        assert "sys employee b" not in filtered_names

        with with_system_context():
            all_rows = db.query(Employee).all()
            all_names = {r.name_ar for r in all_rows}
        assert {"sys employee a", "sys employee b"} <= all_names
    finally:
        db.close()


# ── Strict mode ──────────────────────────────────────────────


def test_strict_mode_raises_on_unbound_tenant(monkeypatch):
    """With TENANT_STRICT=true, a query on a tenant-aware table without a
    bound tenant must raise CrossTenantLeakError — never silently scan all."""
    from app.core import tenant_guard
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import CrossTenantLeakError
    from app.hr.models import Employee

    monkeypatch.setattr(tenant_guard, "TENANT_STRICT", True)

    set_tenant(None)
    db = _new_session()
    try:
        with pytest.raises(CrossTenantLeakError):
            db.query(Employee).all()
    finally:
        db.close()


def test_non_strict_mode_permits_null_only_query():
    """In dev (non-strict), unbound queries return only NULL-tenant rows."""
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.hr.models import Employee

    db = _new_session()
    try:
        with with_system_context():
            _make_employee(db, None, "null-only-row")
            _make_employee(db, "tenant-Z", "z-row")

        set_tenant(None)
        rows = db.query(Employee).all()
        names = {r.name_ar for r in rows}
        assert "null-only-row" in names
        # In non-strict mode, z-row must NOT be visible when no tenant is bound
        assert "z-row" not in names
    finally:
        db.close()


# ── Non-tenant-aware tables are untouched ───────────────────


def test_non_tenant_table_is_not_filtered():
    """User doesn't use TenantMixin — queries must behave normally."""
    from app.core.tenant_context import set_tenant
    from app.phase1.models.platform_models import User

    db = _new_session()
    set_tenant("tenant-ignored")
    try:
        # This query should not raise, should not filter, and should not crash.
        count = db.query(User).count()
        assert count >= 0  # any number is fine — we just want no exception
    finally:
        db.close()


# ── Cross-tenant reference guard ───────────────────────────


def test_assert_same_tenant_catches_mismatch():
    from app.core.tenant_guard import CrossTenantLeakError, assert_same_tenant
    from app.hr.models import Employee

    e1 = Employee(
        id="1", tenant_id="tenant-A", employee_number="1", name_ar="a",
        hire_date=date.today(), basic_salary=Decimal("1"),
        housing_allowance=Decimal("0"), transport_allowance=Decimal("0"),
        other_allowances=Decimal("0"), gosi_applicable=True,
        gosi_employee_rate=Decimal("0.1"), gosi_employer_rate=Decimal("0.12"),
        status="active",
    )
    e2 = Employee(
        id="2", tenant_id="tenant-B", employee_number="2", name_ar="b",
        hire_date=date.today(), basic_salary=Decimal("1"),
        housing_allowance=Decimal("0"), transport_allowance=Decimal("0"),
        other_allowances=Decimal("0"), gosi_applicable=True,
        gosi_employee_rate=Decimal("0.1"), gosi_employer_rate=Decimal("0.12"),
        status="active",
    )
    with pytest.raises(CrossTenantLeakError):
        assert_same_tenant(e1, e2)


def test_assert_same_tenant_allows_null_mix():
    """NULL tenant is considered shared — assert_same_tenant does not raise."""
    from app.core.tenant_guard import assert_same_tenant
    from app.hr.models import Employee

    e1 = Employee(
        id="x1", tenant_id="tenant-A", employee_number="x1", name_ar="a",
        hire_date=date.today(), basic_salary=Decimal("1"),
        housing_allowance=Decimal("0"), transport_allowance=Decimal("0"),
        other_allowances=Decimal("0"), gosi_applicable=True,
        gosi_employee_rate=Decimal("0.1"), gosi_employer_rate=Decimal("0.12"),
        status="active",
    )
    e2 = Employee(
        id="x2", tenant_id=None, employee_number="x2", name_ar="b",
        hire_date=date.today(), basic_salary=Decimal("1"),
        housing_allowance=Decimal("0"), transport_allowance=Decimal("0"),
        other_allowances=Decimal("0"), gosi_applicable=True,
        gosi_employee_rate=Decimal("0.1"), gosi_employer_rate=Decimal("0.12"),
        status="active",
    )
    # No exception
    assert_same_tenant(e1, e2)
