"""APEX Platform — Depreciation calculator tests."""

from decimal import Decimal

import pytest

from app.core.depreciation_service import (
    DepreciationInput,
    compute_depreciation,
    result_to_dict,
)


class TestStraightLine:
    def test_simple_sl(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("100000"),
            salvage_value=Decimal("10000"),
            useful_life_years=5,
        ))
        # (100k - 10k) / 5 = 18,000 per year
        assert len(r.schedule) == 5
        for y in r.schedule:
            assert y.depreciation == Decimal("18000.00")
        # Last year book value should be salvage
        assert r.schedule[-1].closing_book_value == Decimal("10000.00")
        assert r.total_depreciation == Decimal("90000.00")

    def test_sl_annual_rate(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("1000"),
            useful_life_years=4,
        ))
        assert r.annual_rate_pct == Decimal("25.00")  # 1/4 = 25%

    def test_sl_partial_first_year(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("12000"),
            useful_life_years=3,
            first_year_months=6,   # bought mid-year
        ))
        # First year: 4000 * 6/12 = 2000
        assert r.schedule[0].depreciation == Decimal("2000.00")
        assert r.schedule[1].depreciation == Decimal("4000.00")


class TestDecliningBalance:
    def test_ddb_rate(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("10000"),
            salvage_value=Decimal("1000"),
            useful_life_years=5,
            method="declining_balance",
        ))
        # DDB rate = 2 * 1/5 = 40%
        assert r.annual_rate_pct == Decimal("40.00")
        # Year 1: 10000 * 40% = 4000
        assert r.schedule[0].depreciation == Decimal("4000.00")
        # Year 2: 6000 * 40% = 2400
        assert r.schedule[1].depreciation == Decimal("2400.00")
        # Closing stays >= salvage
        for y in r.schedule:
            assert y.closing_book_value >= Decimal("1000.00")

    def test_ddb_stops_at_salvage(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("1000"),
            salvage_value=Decimal("500"),
            useful_life_years=10,
            method="declining_balance",
        ))
        # Would hit salvage quickly
        zero_years = [y for y in r.schedule if y.depreciation == Decimal("0.00")]
        assert len(zero_years) > 0
        assert any("الخردة" in w for w in r.warnings)


class TestSumOfYearsDigits:
    def test_syd_sum(self):
        # Life 5 → SYD = 5+4+3+2+1 = 15
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("15000"),
            salvage_value=Decimal("0"),
            useful_life_years=5,
            method="sum_of_years_digits",
        ))
        # Base = 15000, SYD = 15
        # Year 1: 15000 * 5/15 = 5000
        # Year 2: 15000 * 4/15 = 4000
        # Year 3: 15000 * 3/15 = 3000
        # Year 4: 15000 * 2/15 = 2000
        # Year 5: 15000 * 1/15 = 1000
        expected = [
            Decimal("5000.00"), Decimal("4000.00"), Decimal("3000.00"),
            Decimal("2000.00"), Decimal("1000.00"),
        ]
        for i, exp in enumerate(expected):
            assert r.schedule[i].depreciation == exp
        assert r.total_depreciation == Decimal("15000.00")

    def test_syd_book_reaches_salvage(self):
        r = compute_depreciation(DepreciationInput(
            cost=Decimal("21000"),
            salvage_value=Decimal("1000"),
            useful_life_years=6,
            method="sum_of_years_digits",
        ))
        assert r.schedule[-1].closing_book_value == Decimal("1000.00")


class TestValidation:
    def test_unknown_method_rejected(self):
        with pytest.raises(ValueError, match="Unknown method"):
            compute_depreciation(DepreciationInput(
                cost=Decimal("1000"),
                method="macrs",
            ))

    def test_zero_cost_rejected(self):
        with pytest.raises(ValueError, match="cost must be positive"):
            compute_depreciation(DepreciationInput(cost=Decimal("0")))

    def test_salvage_exceeds_cost(self):
        with pytest.raises(ValueError, match="salvage_value must be less than cost"):
            compute_depreciation(DepreciationInput(
                cost=Decimal("1000"), salvage_value=Decimal("2000"),
            ))

    def test_zero_life_rejected(self):
        with pytest.raises(ValueError, match="useful_life_years must be positive"):
            compute_depreciation(DepreciationInput(
                cost=Decimal("1000"), useful_life_years=0,
            ))

    def test_invalid_first_year_months(self):
        with pytest.raises(ValueError):
            compute_depreciation(DepreciationInput(
                cost=Decimal("1000"), first_year_months=13,
            ))


class TestRoutes:
    def test_compute_requires_auth(self, client):
        r = client.post("/depreciation/compute", json={})
        assert r.status_code == 401

    def test_compute_sl_http(self, client, auth_header):
        r = client.post(
            "/depreciation/compute",
            json={
                "cost": "100000", "salvage_value": "10000",
                "useful_life_years": 5,
                "method": "straight_line", "asset_name": "آلة إنتاج",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["method"] == "straight_line"
        assert len(d["schedule"]) == 5
        assert d["total_depreciation"] == "90000.00"
        assert d["asset_name"] == "آلة إنتاج"

    def test_compute_ddb_http(self, client, auth_header):
        r = client.post(
            "/depreciation/compute",
            json={"cost": "10000", "useful_life_years": 5, "method": "declining_balance"},
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["method"] == "declining_balance"
        assert d["annual_rate_pct"] == "40.00"

    def test_invalid_method_http(self, client, auth_header):
        r = client.post(
            "/depreciation/compute",
            json={"cost": "1000", "useful_life_years": 5, "method": "invalid"},
            headers=auth_header,
        )
        assert r.status_code == 422

    def test_serialization_roundtrip(self, client, auth_header):
        r = client.post(
            "/depreciation/compute",
            json={"cost": "10000", "useful_life_years": 4, "method": "sum_of_years_digits"},
            headers=auth_header,
        )
        d = r.json()["data"]
        # Verify every field is a string (Decimals not leaked as Decimal objects)
        for y in d["schedule"]:
            assert isinstance(y["depreciation"], str)
            assert isinstance(y["closing_book_value"], str)
