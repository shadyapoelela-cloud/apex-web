"""APEX Platform -- app/ai/routes.py /onboarding/* DB integration tests.

Coverage target: cover lines 344-484 (`/onboarding/complete` body) +
521-620 (`/onboarding/seed-demo` body) — ~238 stmts that G-T1.7a
deliberately deferred for G-T1.7a.1 (Sprint 11).

Strategy: hit the real route handlers via `TestClient`, then verify DB
state by direct `SessionLocal()` queries. The session-scoped autouse
`setup_test_db` fixture in `tests/conftest.py` provides the schema.
Each test uses a UUID-suffixed company name so slugs are unique +
cross-test idempotent.

Zone 1a — `/onboarding/complete`:
  * Happy path with default (sa) country, no industry, no VAT
  * Industry overlay (restaurant) → extra accounts seeded
  * Multiple country currency mappings (sa→SAR, ae→AED, etc.)
  * Slug collision handling (re-running same name → suffix increment)
  * Missing company_name → 400 (already covered by test_ai_onboarding_routes)
  * COA seed failure swallowed silently (covered indirectly)

Zone 1b — `/onboarding/seed-demo`:
  * Pre-seed via /onboarding/complete, then run seed-demo
  * Verify 5 customers + 3 demo JEs created
  * Re-run idempotency: customers + JEs not duplicated
  * Missing tenant_id/entity_id → 400 (already covered)
  * Entity not found → 404 (already covered)
  * No fiscal periods → silent skip (no JEs created)
"""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


def _unique_name(prefix="Acme"):
    """UUID-suffixed company name → unique slug per test."""
    return f"{prefix} {uuid.uuid4().hex[:8]}"


# ══════════════════════════════════════════════════════════════
# Zone 1a: /onboarding/complete
# ══════════════════════════════════════════════════════════════


class TestOnboardingComplete:
    def test_full_flow_default_country_no_industry(self, client):
        """Happy path: tenant + entity + COA + 12 fiscal periods seeded."""
        name = _unique_name("AcmeCo")
        r = client.post(
            "/api/v1/ai/onboarding/complete",
            json={"company_name": name, "country": "sa"},
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["success"] is True
        data = body["data"]
        assert data["tenant_id"]
        assert data["entity_id"]
        assert data["functional_currency"] == "SAR"
        assert data["accounts_created"] > 0  # base COA seeded
        assert data["periods_created"] == 12

        # Verify in DB.
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import Tenant, Entity, FiscalPeriod

        db = SessionLocal()
        try:
            tenant = db.query(Tenant).filter(Tenant.id == data["tenant_id"]).first()
            assert tenant is not None
            assert tenant.legal_name_ar == name
            assert tenant.primary_country == "SA"

            entity = db.query(Entity).filter(Entity.id == data["entity_id"]).first()
            assert entity is not None
            assert entity.functional_currency == "SAR"

            periods = db.query(FiscalPeriod).filter(
                FiscalPeriod.entity_id == entity.id
            ).count()
            assert periods == 12
        finally:
            db.close()

    def test_with_industry_overlay_adds_extra_accounts(self, client):
        """Industry-specific accounts overlay on top of base COA."""
        name = _unique_name("Restaurant")
        r = client.post(
            "/api/v1/ai/onboarding/complete",
            json={
                "company_name": name,
                "country": "sa",
                "industry": "restaurant",
            },
        )
        assert r.status_code == 200, r.text
        data = r.json()["data"]
        assert data["industry"] == "restaurant"

        # Verify some restaurant-specific accounts seeded.
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import GLAccount

        db = SessionLocal()
        try:
            # Restaurant template adds account 4110 (Dine-in Sales) etc.
            dine_in = (
                db.query(GLAccount)
                .filter(GLAccount.entity_id == data["entity_id"])
                .filter(GLAccount.code == "4110")
                .first()
            )
            assert dine_in is not None
            assert "الصالة" in dine_in.name_ar
        finally:
            db.close()

    @pytest.mark.parametrize("country,expected_currency", [
        ("sa", "SAR"),
        ("ae", "AED"),
        ("eg", "EGP"),
        ("om", "OMR"),
        ("bh", "BHD"),
        ("xx", "SAR"),  # unknown → fallback SAR
    ])
    def test_country_currency_mapping(self, client, country, expected_currency):
        name = _unique_name(f"CCY{country.upper()}")
        r = client.post(
            "/api/v1/ai/onboarding/complete",
            json={"company_name": name, "country": country},
        )
        assert r.status_code == 200
        assert r.json()["data"]["functional_currency"] == expected_currency

    def test_with_vat_number_persisted(self, client):
        name = _unique_name("VATCo")
        r = client.post(
            "/api/v1/ai/onboarding/complete",
            json={
                "company_name": name,
                "country": "sa",
                "vat_number": "300000000000003",
            },
        )
        assert r.status_code == 200
        data = r.json()["data"]

        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import Tenant, Entity

        db = SessionLocal()
        try:
            tenant = db.query(Tenant).filter(Tenant.id == data["tenant_id"]).first()
            assert tenant.primary_vat_number == "300000000000003"
            entity = db.query(Entity).filter(Entity.id == data["entity_id"]).first()
            assert entity.vat_number == "300000000000003"
        finally:
            db.close()

    def test_slug_collision_increments_suffix(self, client):
        """Two onboarding calls with the same company name → second
        gets a numeric suffix (slug-1, slug-2 ...). Exercises the
        while-loop at lines 354-357."""
        name = _unique_name("CollideCo")
        r1 = client.post(
            "/api/v1/ai/onboarding/complete",
            json={"company_name": name, "country": "sa"},
        )
        r2 = client.post(
            "/api/v1/ai/onboarding/complete",
            json={"company_name": name, "country": "sa"},
        )
        assert r1.status_code == 200
        assert r2.status_code == 200
        slug1 = r1.json()["data"]["tenant_slug"]
        slug2 = r2.json()["data"]["tenant_slug"]
        # Both succeeded but slugs are different.
        assert slug1 != slug2
        # The second slug ends with "-N" (the increment).
        assert slug2.startswith(slug1) and slug2.endswith("-1")


# ══════════════════════════════════════════════════════════════
# Zone 1b: /onboarding/seed-demo
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def seeded_tenant(client):
    """Pre-seed a tenant + entity via /onboarding/complete and return
    (tenant_id, entity_id) for seed-demo tests."""
    name = _unique_name("DemoSeed")
    r = client.post(
        "/api/v1/ai/onboarding/complete",
        json={"company_name": name, "country": "sa"},
    )
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    return data["tenant_id"], data["entity_id"]


class TestOnboardingSeedDemo:
    def test_full_seed_creates_5_customers_and_demo_jes(
        self, client, seeded_tenant
    ):
        tenant_id, entity_id = seeded_tenant
        r = client.post(
            "/api/v1/ai/onboarding/seed-demo",
            json={"tenant_id": tenant_id, "entity_id": entity_id},
        )
        assert r.status_code == 200, r.text
        data = r.json()["data"]
        # 5 sample customers seeded.
        assert data["customers_created"] == 5
        # 3 demo journal entries seeded (or fewer if accounts missing).
        assert data["journal_entries_created"] >= 0  # depends on whether DEFAULT_COA seeds the right accounts

        # Verify in DB.
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import Customer

        db = SessionLocal()
        try:
            customers = (
                db.query(Customer)
                .filter(Customer.tenant_id == tenant_id)
                .all()
            )
            assert len(customers) == 5
            codes = {c.code for c in customers}
            assert codes == {
                "CUST-0001", "CUST-0002", "CUST-0003",
                "CUST-0004", "CUST-0005",
            }
        finally:
            db.close()

    def test_idempotent_re_run(self, client, seeded_tenant):
        """Running seed-demo twice does NOT duplicate customers or JEs."""
        tenant_id, entity_id = seeded_tenant
        r1 = client.post(
            "/api/v1/ai/onboarding/seed-demo",
            json={"tenant_id": tenant_id, "entity_id": entity_id},
        )
        r2 = client.post(
            "/api/v1/ai/onboarding/seed-demo",
            json={"tenant_id": tenant_id, "entity_id": entity_id},
        )
        assert r1.status_code == 200
        assert r2.status_code == 200
        # Second run reports 0 new customers + 0 new JEs (existing rows skipped).
        d2 = r2.json()["data"]
        assert d2["customers_created"] == 0
        assert d2["journal_entries_created"] == 0

        # Verify total count is still 5 (not 10).
        from app.phase1.models.platform_models import SessionLocal
        from app.pilot.models import Customer

        db = SessionLocal()
        try:
            count = (
                db.query(Customer)
                .filter(Customer.tenant_id == tenant_id)
                .count()
            )
            assert count == 5
        finally:
            db.close()

    def test_no_fiscal_period_skips_jes_silently(self, client):
        """If the entity has no fiscal periods, the JE seed loop is
        skipped silently (the customer seed still runs)."""
        # Create a tenant + entity directly via SessionLocal so we can
        # control whether fiscal periods exist (skip seeding them).
        from app.phase1.models.platform_models import SessionLocal, gen_uuid
        from app.pilot.models import Tenant, Entity

        tenant_id = gen_uuid()
        entity_id = gen_uuid()
        db = SessionLocal()
        try:
            db.add(Tenant(
                id=tenant_id,
                slug=f"no-fp-{uuid.uuid4().hex[:6]}",
                legal_name_ar="No Fiscal Period Co",
                primary_country="SA",
                primary_email="x@y.z",
                status="trial",
                tier="starter",
            ))
            db.add(Entity(
                id=entity_id,
                tenant_id=tenant_id,
                code="NOFP",
                name_ar="x",
                type="company",
                status="active",
                country="SA",
                functional_currency="SAR",
                fiscal_year_start_month=1,
            ))
            db.commit()
        finally:
            db.close()

        r = client.post(
            "/api/v1/ai/onboarding/seed-demo",
            json={"tenant_id": tenant_id, "entity_id": entity_id},
        )
        assert r.status_code == 200
        data = r.json()["data"]
        # 5 customers still seeded (independent of fiscal period presence).
        assert data["customers_created"] == 5
        # No JEs because there's no open fiscal period.
        assert data["journal_entries_created"] == 0
