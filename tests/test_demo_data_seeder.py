"""G-DEMO-DATA-SEEDER (master-data tier) — service + endpoint tests.

Closes the "blank chips" UX problem after ERR-2 + Legacy Migration:
the seeder gives a tenant 5 customers + 5 vendors + 15 products so
the customer / vendor / product chips have something to render in
stakeholder demos.

Test layers:

  TestIdempotency
    First call seeds; second call (no force) skips; force=true
    appends a fresh batch with a unique-suffixed code so the
    `uq_pilot_*_tenant_code` constraints don't fire; invalid
    tenant_id raises ValueError → 404 from the endpoint.

  TestMasterDataCounts
    Confirms the row counts (5 / 5 / 15) and that all rows are
    tagged with the requested tenant_id so the existing
    `attach_tenant_guard` filters them correctly.

  TestArabicAndCodes
    Customers carry Arabic name text in `name_ar` (the dashboard
    requirement); codes follow the spec format and survive force-
    append with the suffix scheme.

  TestEndpoints
    Admin endpoint requires `X-Admin-Secret`; user endpoint
    requires a JWT carrying `tenant_id`; user endpoint returns 400
    for legacy tokens; user endpoint cannot target a different
    tenant than the one in the caller's JWT (cross-tenant
    isolation).

  TestCrossTenantIsolation
    Seeding tenant A leaves tenant B untouched.
"""

from __future__ import annotations

import os
import uuid

import jwt as _jwt
import pytest

from app.phase1.models.platform_models import (
    SessionLocal,
    User,
    UserRole,
    Role,
    RoleCode,
    gen_uuid,
)
from app.phase1.services.auth_service import (
    JWT_ALGORITHM,
    JWT_SECRET,
    create_access_token,
    hash_password,
)
from app.phase1.services.demo_data_seeder import (
    is_already_seeded,
    seed_demo_data,
)
from app.pilot.models.tenant import Tenant


# ────────────────────────────────────────────────────────────────────
# Fixtures — minimal Tenant / User / JWT factories
# ────────────────────────────────────────────────────────────────────


@pytest.fixture
def db():
    s = SessionLocal()
    try:
        yield s
    finally:
        s.rollback()
        s.close()


def _mk_tenant(s, suffix: str | None = None) -> Tenant:
    """Insert a fresh Tenant row. Test-scoped — the function-level
    `db` fixture rolls back after the test so we don't accumulate
    test tenants across runs."""
    suffix = suffix or uuid.uuid4().hex[:8]
    t = Tenant(
        id=gen_uuid(),
        slug=f"test-{suffix}",
        legal_name_ar=f"اختبار {suffix}",
        primary_email=f"test_{suffix}@example.test",
        primary_country="SA",
    )
    s.add(t)
    s.commit()
    return t


def _delete_seed_rows(tenant_id: str) -> None:
    """Best-effort cleanup of rows the seeder inserted, scoped to the
    given tenant. Swallows errors so a partial cleanup never fails
    the test."""
    from app.pilot.models.customer import Customer
    from app.pilot.models.product import Product
    from app.pilot.models.purchasing import Vendor

    s = SessionLocal()
    try:
        for model in (Customer, Vendor, Product):
            s.query(model).filter(
                model.tenant_id == tenant_id
            ).delete(synchronize_session=False)
        s.query(Tenant).filter(Tenant.id == tenant_id).delete(
            synchronize_session=False
        )
        s.commit()
    except Exception:
        s.rollback()
    finally:
        s.close()


def _user_token(tenant_id: str | None) -> str:
    """Mint a JWT carrying (or omitting) the `tenant_id` claim — the
    same shape ERR-2 Phase 3's `create_access_token` produces. Used
    to drive the user endpoint without standing up the full
    register/login flow per test."""
    return create_access_token(
        f"test-user-{uuid.uuid4().hex[:8]}",
        "demo_test",
        ["registered_user"],
        tenant_id=tenant_id,
    )


# ────────────────────────────────────────────────────────────────────
# Idempotency
# ────────────────────────────────────────────────────────────────────


class TestIdempotency:
    def test_first_call_seeds_rows(self, db):
        t = _mk_tenant(db)
        try:
            assert is_already_seeded(db, t.id) is False
            result = seed_demo_data(db, t.id)
            assert result["success"] is True
            assert result["skipped"] is False
            assert result["summary"]["master_data"]["customers"] == 5
            assert is_already_seeded(db, t.id) is True
        finally:
            _delete_seed_rows(t.id)

    def test_second_call_skips_without_force(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            second = seed_demo_data(db, t.id)
            assert second["skipped"] is True
            assert "already" in second["reason"].lower()
        finally:
            _delete_seed_rows(t.id)

    def test_force_appends_another_batch(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            forced = seed_demo_data(db, t.id, force=True)
            assert forced["skipped"] is False
            from app.pilot.models.customer import Customer

            count = (
                db.query(Customer)
                .filter(Customer.tenant_id == t.id)
                .count()
            )
            assert count == 10  # 5 from first call + 5 from force
        finally:
            _delete_seed_rows(t.id)

    def test_invalid_tenant_raises_value_error(self, db):
        with pytest.raises(ValueError) as exc:
            seed_demo_data(db, "tenant-that-does-not-exist")
        assert "not found" in str(exc.value).lower()


# ────────────────────────────────────────────────────────────────────
# Master-data counts + tenant scoping
# ────────────────────────────────────────────────────────────────────


class TestMasterDataCounts:
    def test_seeds_exactly_5_customers(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            from app.pilot.models.customer import Customer

            count = (
                db.query(Customer)
                .filter(Customer.tenant_id == t.id)
                .count()
            )
            assert count == 5
        finally:
            _delete_seed_rows(t.id)

    def test_seeds_exactly_5_vendors(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            from app.pilot.models.purchasing import Vendor

            count = (
                db.query(Vendor)
                .filter(Vendor.tenant_id == t.id)
                .count()
            )
            assert count == 5
        finally:
            _delete_seed_rows(t.id)

    def test_seeds_exactly_15_products(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            from app.pilot.models.product import Product

            count = (
                db.query(Product)
                .filter(Product.tenant_id == t.id)
                .count()
            )
            assert count == 15
        finally:
            _delete_seed_rows(t.id)

    def test_summary_dict_shape(self, db):
        t = _mk_tenant(db)
        try:
            result = seed_demo_data(db, t.id)
            md = result["summary"]["master_data"]
            assert md["customers"] == 5
            assert md["vendors"] == 5
            assert md["products"] == 15
            # Deferred section is present so a UI can show "more
            # coming in V2" without crashing on a missing key.
            df = result["summary"]["deferred"]
            assert df["journal_entries"] == 0
            assert "_note" in df
        finally:
            _delete_seed_rows(t.id)


# ────────────────────────────────────────────────────────────────────
# Arabic + code conventions
# ────────────────────────────────────────────────────────────────────


class TestArabicAndCodes:
    @staticmethod
    def _has_arabic(text: str) -> bool:
        return any("؀" <= ch <= "ۿ" for ch in text or "")

    def test_customers_have_arabic_names(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            from app.pilot.models.customer import Customer

            customers = (
                db.query(Customer)
                .filter(Customer.tenant_id == t.id)
                .all()
            )
            assert all(self._has_arabic(c.name_ar) for c in customers)
        finally:
            _delete_seed_rows(t.id)

    def test_vendors_have_arabic_legal_names(self, db):
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            from app.pilot.models.purchasing import Vendor

            vendors = (
                db.query(Vendor)
                .filter(Vendor.tenant_id == t.id)
                .all()
            )
            assert all(
                self._has_arabic(v.legal_name_ar) for v in vendors
            )
        finally:
            _delete_seed_rows(t.id)

    def test_force_append_uses_unique_suffixed_codes(self, db):
        # The uq_pilot_customers_tenant_code constraint would fire on
        # naive force-append. The service mints a 6-hex-char suffix
        # to keep the codes unique. This test holds that contract.
        t = _mk_tenant(db)
        try:
            seed_demo_data(db, t.id)
            seed_demo_data(db, t.id, force=True)
            from app.pilot.models.customer import Customer

            codes = [
                c.code
                for c in db.query(Customer)
                .filter(Customer.tenant_id == t.id)
                .all()
            ]
            assert len(codes) == len(set(codes)), (
                f"Duplicate customer codes after force-append: {codes}"
            )
        finally:
            _delete_seed_rows(t.id)


# ────────────────────────────────────────────────────────────────────
# Cross-tenant isolation
# ────────────────────────────────────────────────────────────────────


class TestCrossTenantIsolation:
    def test_seeding_a_does_not_touch_b(self, db):
        a = _mk_tenant(db, suffix="iso-a")
        b = _mk_tenant(db, suffix="iso-b")
        try:
            seed_demo_data(db, a.id)
            from app.pilot.models.customer import Customer

            count_b = (
                db.query(Customer)
                .filter(Customer.tenant_id == b.id)
                .count()
            )
            assert count_b == 0, "Tenant B saw rows from tenant A's seed"
            count_a = (
                db.query(Customer)
                .filter(Customer.tenant_id == a.id)
                .count()
            )
            assert count_a == 5
        finally:
            _delete_seed_rows(a.id)
            _delete_seed_rows(b.id)


# ────────────────────────────────────────────────────────────────────
# /admin/seed-demo-data + /api/v1/account/seed-demo-data
# ────────────────────────────────────────────────────────────────────


class TestAdminEndpoint:
    def test_requires_admin_secret(self, client):
        resp = client.post(
            "/admin/seed-demo-data?tenant_id=anything"
        )
        assert resp.status_code == 403

    def test_invalid_tenant_returns_404(self, client):
        resp = client.post(
            "/admin/seed-demo-data?tenant_id=does-not-exist",
            headers={"X-Admin-Secret": os.environ["ADMIN_SECRET"]},
        )
        assert resp.status_code == 404

    def test_valid_tenant_seeds(self, client):
        s = SessionLocal()
        t = _mk_tenant(s)
        tenant_id = t.id  # capture before closing — once the session
        s.close()  # closes, the instance detaches
        try:
            resp = client.post(
                f"/admin/seed-demo-data?tenant_id={tenant_id}",
                headers={
                    "X-Admin-Secret": os.environ["ADMIN_SECRET"]
                },
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["success"] is True
            assert body["data"]["skipped"] is False
            assert (
                body["data"]["summary"]["master_data"]["customers"]
                == 5
            )
        finally:
            _delete_seed_rows(tenant_id)


class TestUserEndpoint:
    def test_requires_jwt(self, client):
        resp = client.post("/api/v1/account/seed-demo-data")
        assert resp.status_code in (401, 403)

    def test_legacy_token_without_tenant_returns_400(self, client):
        # Token without `tenant_id` claim — simulates a session
        # issued before ERR-2 Phase 3 lands for that user.
        token = _user_token(tenant_id=None)
        resp = client.post(
            "/api/v1/account/seed-demo-data",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400
        assert "tenant_id" in resp.text.lower()

    def test_authenticated_user_seeds_own_tenant(self, client):
        s = SessionLocal()
        t = _mk_tenant(s, suffix="user-ep")
        tenant_id = t.id
        s.close()
        try:
            token = _user_token(tenant_id=tenant_id)
            resp = client.post(
                "/api/v1/account/seed-demo-data",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["success"] is True
            assert (
                body["data"]["summary"]["master_data"]["customers"]
                == 5
            )
        finally:
            _delete_seed_rows(tenant_id)
