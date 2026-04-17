"""IFRS 16 Lease accounting tests."""

from decimal import Decimal

import pytest

from app.core.lease_service import LeaseInput, build_lease


class TestBasic:
    def test_5yr_monthly_1000(self):
        # 5-year monthly lease, 1000 per month, 5% IBR
        r = build_lease(LeaseInput(
            lease_name="Office A",
            start_date="2026-01-01",
            term_months=60,
            payment_amount=Decimal("1000"),
            payment_frequency="monthly",
            annual_ibr_pct=Decimal("5"),
        ))
        # Total undiscounted: 60 × 1000 ≈ 60000 (last payment may trim
        # a cent or two to zero the balance)
        assert abs(r.total_payments - Decimal("60000.00")) < Decimal("1")
        # PV should be less than 60000 due to discounting
        assert r.lease_liability_initial < Decimal("60000")
        assert r.lease_liability_initial > Decimal("50000")
        # Periods match
        assert r.periods == 60
        # ROU = liability + 0 + 0 - 0
        assert r.rou_asset_initial == r.lease_liability_initial
        # Schedule length
        assert len(r.schedule) == 60
        # Final balance ≈ 0
        assert r.schedule[-1].closing_liability < Decimal("1")

    def test_zero_rate_pv_equals_total(self):
        # At 0% rate, PV == total undiscounted
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=12,
            payment_amount=Decimal("100"),
            annual_ibr_pct=Decimal("0"),
        ))
        assert r.lease_liability_initial == Decimal("1200.00")
        assert r.total_interest == Decimal("0.00")

    def test_initial_costs_and_incentives(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=24,
            payment_amount=Decimal("500"),
            annual_ibr_pct=Decimal("5"),
            initial_direct_costs=Decimal("300"),
            prepaid_lease_payments=Decimal("200"),
            lease_incentives=Decimal("100"),
        ))
        # ROU = liab + 300 + 200 - 100 = liab + 400
        assert r.rou_asset_initial == r.lease_liability_initial + Decimal("400.00")


class TestFlags:
    def test_short_term_flagged(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=6,
            payment_amount=Decimal("500"),
        ))
        assert r.is_short_term is True
        assert any("قصير" in w for w in r.warnings)

    def test_low_value_flagged(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=24,
            payment_amount=Decimal("500"),  # < 2000 threshold
        ))
        assert r.is_low_value is True


class TestDepreciation:
    def test_straight_line(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=12,
            payment_amount=Decimal("100"),
            annual_ibr_pct=Decimal("0"),
        ))
        # ROU = 1200, depreciable = 1200 - 0 = 1200
        # / 12 periods = 100/period
        assert r.periodic_depreciation == Decimal("100.00")
        assert r.total_depreciation == Decimal("1200.00")

    def test_with_residual(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=10,
            payment_amount=Decimal("100"),
            annual_ibr_pct=Decimal("0"),
            residual_value=Decimal("200"),
        ))
        # ROU = 1000, depreciable = 1000 - 200 = 800
        # / 10 = 80/period
        assert r.periodic_depreciation == Decimal("80.00")


class TestFrequencies:
    def test_quarterly_lease(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=60,
            payment_amount=Decimal("3000"),
            payment_frequency="quarterly",
            annual_ibr_pct=Decimal("4"),
        ))
        # 60 months / (12/4) = 20 quarters
        assert r.periods == 20
        # Periodic rate = 4% / 4 = 1%
        assert r.periodic_rate == Decimal("0.010000")

    def test_annual_lease(self):
        r = build_lease(LeaseInput(
            lease_name="x",
            start_date="2026-01-01",
            term_months=60,
            payment_amount=Decimal("12000"),
            payment_frequency="annual",
            annual_ibr_pct=Decimal("6"),
        ))
        assert r.periods == 5
        assert r.periodic_rate == Decimal("0.060000")


class TestValidation:
    def test_zero_term_rejected(self):
        with pytest.raises(ValueError, match="term_months"):
            build_lease(LeaseInput(
                lease_name="x", start_date="2026-01-01",
                term_months=0, payment_amount=Decimal("100"),
            ))

    def test_negative_payment_rejected(self):
        with pytest.raises(ValueError, match="payment_amount"):
            build_lease(LeaseInput(
                lease_name="x", start_date="2026-01-01",
                term_months=12, payment_amount=Decimal("-100"),
            ))

    def test_bad_frequency_rejected(self):
        with pytest.raises(ValueError, match="payment_frequency"):
            build_lease(LeaseInput(
                lease_name="x", start_date="2026-01-01",
                term_months=12, payment_amount=Decimal("100"),
                payment_frequency="biweekly",
            ))

    def test_bad_rate_rejected(self):
        with pytest.raises(ValueError, match="annual_ibr_pct"):
            build_lease(LeaseInput(
                lease_name="x", start_date="2026-01-01",
                term_months=12, payment_amount=Decimal("100"),
                annual_ibr_pct=Decimal("60"),
            ))


class TestRoutes:
    def test_requires_auth(self, client):
        r = client.post("/lease/build", json={})
        assert r.status_code == 401

    def test_build_http(self, client, auth_header):
        r = client.post("/lease/build", json={
            "lease_name": "Office",
            "start_date": "2026-01-01",
            "term_months": 60,
            "payment_amount": "3000",
            "payment_frequency": "monthly",
            "annual_ibr_pct": "5",
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["periods"] == 60
        assert len(d["schedule"]) == 60

    def test_bad_input_http(self, client, auth_header):
        r = client.post("/lease/build", json={
            "lease_name": "x", "start_date": "2026-01-01",
            "term_months": 12, "payment_amount": "100",
            "payment_frequency": "weekly",
        }, headers=auth_header)
        assert r.status_code == 422
