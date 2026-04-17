"""Cost Accounting / Variance Analysis tests."""

from decimal import Decimal

import pytest

from app.core.cost_accounting_service import (
    MaterialVarianceInput, LabourVarianceInput, OverheadVarianceInput,
    ComprehensiveVarianceInput,
    analyse_material, analyse_labour, analyse_overhead, analyse_comprehensive,
)


class TestMaterial:
    def test_favourable_price_unfavourable_qty(self):
        # Standard: 2 units @ 10 each per output → 20 std cost per unit
        # Output 100 units → std 200 qty × 10 = 2000
        # Actual: 210 qty × 9 = 1890
        # Price var = (10 - 9) × 210 = 210 fav
        # Qty var = (200 - 210) × 10 = -100 unfav
        # Total = 110 fav
        r = analyse_material(MaterialVarianceInput(
            item_name="حديد",
            std_price=Decimal("10"), std_qty_per_output=Decimal("2"),
            actual_price=Decimal("9"), actual_qty_used=Decimal("210"),
            output_units=Decimal("100"),
        ))
        assert r.std_qty_allowed == Decimal("200.00")
        assert r.price_variance == Decimal("210.00")
        assert r.quantity_variance == Decimal("-100.00")
        assert r.total_variance == Decimal("110.00")
        assert r.price_label == "favourable"
        assert r.quantity_label == "unfavourable"
        assert r.total_label == "favourable"

    def test_no_output_rejected(self):
        with pytest.raises(ValueError, match="output_units must be positive"):
            analyse_material(MaterialVarianceInput(
                item_name="x",
                std_price=Decimal("1"), std_qty_per_output=Decimal("1"),
                actual_price=Decimal("1"), actual_qty_used=Decimal("1"),
                output_units=Decimal("0"),
            ))

    def test_negative_price_rejected(self):
        with pytest.raises(ValueError):
            analyse_material(MaterialVarianceInput(
                item_name="x",
                std_price=Decimal("-1"), std_qty_per_output=Decimal("1"),
                actual_price=Decimal("1"), actual_qty_used=Decimal("1"),
                output_units=Decimal("1"),
            ))

    def test_std_cost_correct(self):
        r = analyse_material(MaterialVarianceInput(
            item_name="x",
            std_price=Decimal("5"), std_qty_per_output=Decimal("3"),
            actual_price=Decimal("5"), actual_qty_used=Decimal("30"),
            output_units=Decimal("10"),
        ))
        # std_cost = 30 × 5 = 150
        # actual_cost = 30 × 5 = 150
        assert r.std_cost == Decimal("150.00")
        assert r.actual_cost == Decimal("150.00")
        assert r.total_variance == Decimal("0.00")
        assert r.total_label == "none"


class TestLabour:
    def test_rate_and_efficiency(self):
        # Std: 2 hrs/unit @ 20/hr
        # Output 100 → 200 std hrs × 20 = 4000 std cost
        # Actual: 220 hrs × 22
        # Rate var = (20 - 22) × 220 = -440 unfav
        # Eff var = (200 - 220) × 20 = -400 unfav
        # Total = -840 unfav
        r = analyse_labour(LabourVarianceInput(
            cost_center="مصنع 1",
            std_rate_per_hour=Decimal("20"), std_hours_per_output=Decimal("2"),
            actual_rate_per_hour=Decimal("22"), actual_hours=Decimal("220"),
            output_units=Decimal("100"),
        ))
        assert r.std_hours_allowed == Decimal("200.00")
        assert r.rate_variance == Decimal("-440.00")
        assert r.efficiency_variance == Decimal("-400.00")
        assert r.total_variance == Decimal("-840.00")
        assert r.total_label == "unfavourable"

    def test_perfect_match(self):
        r = analyse_labour(LabourVarianceInput(
            cost_center="x",
            std_rate_per_hour=Decimal("30"), std_hours_per_output=Decimal("1"),
            actual_rate_per_hour=Decimal("30"), actual_hours=Decimal("50"),
            output_units=Decimal("50"),
        ))
        assert r.total_variance == Decimal("0.00")
        assert r.total_label == "none"


class TestOverhead:
    def test_favourable_spending(self):
        # Budget 10000, actual 9500 → spending = 500 fav
        # Std 2 hr/unit × 100 = 200 hrs @ 50/hr = applied 10000
        # Actual hrs 190 → volume = (200 - 190) × 50 = 500 fav
        # Total = 1000 fav
        r = analyse_overhead(OverheadVarianceInput(
            cost_center="مصنع 1",
            budgeted_overhead=Decimal("10000"),
            actual_overhead=Decimal("9500"),
            std_rate_per_hour=Decimal("50"),
            std_hours_per_output=Decimal("2"),
            actual_hours=Decimal("190"),
            output_units=Decimal("100"),
        ))
        assert r.applied_overhead == Decimal("10000.00")
        assert r.spending_variance == Decimal("500.00")
        assert r.volume_variance == Decimal("500.00")
        assert r.total_variance == Decimal("1000.00")
        assert r.total_label == "favourable"


class TestComprehensive:
    def test_all_three_combined(self):
        r = analyse_comprehensive(ComprehensiveVarianceInput(
            period_label="Q1 2026",
            output_units=Decimal("100"),
            material=MaterialVarianceInput(
                item_name="حديد",
                std_price=Decimal("10"), std_qty_per_output=Decimal("2"),
                actual_price=Decimal("9"), actual_qty_used=Decimal("210"),
                output_units=Decimal("100"),
            ),
            labour=LabourVarianceInput(
                cost_center="c1",
                std_rate_per_hour=Decimal("20"), std_hours_per_output=Decimal("2"),
                actual_rate_per_hour=Decimal("22"), actual_hours=Decimal("220"),
                output_units=Decimal("100"),
            ),
            overhead=OverheadVarianceInput(
                cost_center="c1",
                budgeted_overhead=Decimal("10000"),
                actual_overhead=Decimal("9500"),
                std_rate_per_hour=Decimal("50"),
                std_hours_per_output=Decimal("2"),
                actual_hours=Decimal("190"),
                output_units=Decimal("100"),
            ),
        ))
        # Grand = 110 (mat fav) + -840 (lab unfav) + 1000 (oh fav) = 270 fav
        assert r.grand_total_variance == Decimal("270.00")
        assert r.grand_label == "favourable"
        assert r.material is not None
        assert r.labour is not None
        assert r.overhead is not None

    def test_empty_all_rejected(self):
        with pytest.raises(ValueError, match="at least one"):
            analyse_comprehensive(ComprehensiveVarianceInput(
                period_label="x", output_units=Decimal("10"),
            ))


class TestRoutes:
    def test_material_requires_auth(self, client):
        r = client.post("/cost/variance/material", json={})
        assert r.status_code == 401

    def test_material_http(self, client, auth_header):
        r = client.post("/cost/variance/material", json={
            "item_name": "iron",
            "std_price": "10", "std_qty_per_output": "2",
            "actual_price": "9", "actual_qty_used": "210",
            "output_units": "100",
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_variance"] == "110.00"
        assert d["total_label"] == "favourable"

    def test_labour_http(self, client, auth_header):
        r = client.post("/cost/variance/labour", json={
            "cost_center": "cc1",
            "std_rate_per_hour": "20", "std_hours_per_output": "2",
            "actual_rate_per_hour": "22", "actual_hours": "220",
            "output_units": "100",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["total_label"] == "unfavourable"

    def test_overhead_http(self, client, auth_header):
        r = client.post("/cost/variance/overhead", json={
            "cost_center": "cc1",
            "budgeted_overhead": "10000", "actual_overhead": "9500",
            "std_rate_per_hour": "50", "std_hours_per_output": "2",
            "actual_hours": "190", "output_units": "100",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["total_variance"] == "1000.00"

    def test_comprehensive_http(self, client, auth_header):
        r = client.post("/cost/variance/comprehensive", json={
            "period_label": "Q1 2026",
            "output_units": "100",
            "material": {
                "item_name": "iron",
                "std_price": "10", "std_qty_per_output": "2",
                "actual_price": "9", "actual_qty_used": "210",
                "output_units": "100",
            },
            "labour": {
                "cost_center": "cc1",
                "std_rate_per_hour": "20", "std_hours_per_output": "2",
                "actual_rate_per_hour": "22", "actual_hours": "220",
                "output_units": "100",
            },
            "overhead": {
                "cost_center": "cc1",
                "budgeted_overhead": "10000", "actual_overhead": "9500",
                "std_rate_per_hour": "50", "std_hours_per_output": "2",
                "actual_hours": "190", "output_units": "100",
            },
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["grand_total_variance"] == "270.00"

    def test_unauthenticated_rejected(self, client):
        assert client.post("/cost/variance/labour", json={}).status_code == 401
        assert client.post("/cost/variance/overhead", json={}).status_code == 401

    def test_bad_output_units_http(self, client, auth_header):
        r = client.post("/cost/variance/material", json={
            "item_name": "x",
            "std_price": "1", "std_qty_per_output": "1",
            "actual_price": "1", "actual_qty_used": "1",
            "output_units": "0",
        }, headers=auth_header)
        assert r.status_code == 422
