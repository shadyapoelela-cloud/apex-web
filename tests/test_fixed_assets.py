"""Fixed Assets Register tests."""

from decimal import Decimal

import pytest

from app.core.fixed_assets_service import AssetInput, build_asset


class TestDepreciation:
    def test_straight_line(self):
        r = build_asset(AssetInput(
            asset_code="FA-001", asset_name="Laptop",
            asset_class="it_equipment",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("5000"),
            useful_life_years=5,
            residual_value=Decimal("500"),
        ))
        # 4500 / 5 = 900 per year
        assert r.annual_depreciation == Decimal("900.00")
        assert r.total_depreciation == Decimal("4500.00")
        assert r.current_book_value == Decimal("500.00")

    def test_double_declining(self):
        r = build_asset(AssetInput(
            asset_code="FA-002", asset_name="Machine",
            asset_class="ppe",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("10000"),
            useful_life_years=5,
            residual_value=Decimal("1000"),
            depreciation_method="double_declining",
        ))
        # Year 1: 2/5 × 10000 = 4000; BV = 6000
        # Year 2: 2/5 × 6000 = 2400; BV = 3600
        assert r.schedule[0].depreciation_expense == Decimal("4000.00")
        assert r.schedule[1].depreciation_expense == Decimal("2400.00")
        # Should not go below residual
        assert r.current_book_value >= Decimal("1000.00")

    def test_sum_of_years(self):
        r = build_asset(AssetInput(
            asset_code="FA-003", asset_name="Vehicle",
            asset_class="vehicle",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("50000"),
            useful_life_years=5,
            residual_value=Decimal("5000"),
            depreciation_method="sum_of_years",
        ))
        # SYD = 15; Y1 factor = 5/15 = 33.33%
        # Y1 dep = 45000 × 5/15 = 15000
        assert r.schedule[0].depreciation_expense == Decimal("15000.00")
        # Y5 = 45000 × 1/15 = 3000
        assert r.schedule[4].depreciation_expense == Decimal("3000.00")


class TestIDC:
    def test_idc_included_in_base(self):
        r = build_asset(AssetInput(
            asset_code="FA-004", asset_name="Plant",
            asset_class="ppe",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("100000"),
            initial_direct_costs=Decimal("5000"),
            useful_life_years=10,
            residual_value=Decimal("5000"),
        ))
        assert r.capitalised_cost == Decimal("105000.00")
        assert r.depreciable_base == Decimal("100000.00")


class TestDisposal:
    def test_disposal_gain(self):
        r = build_asset(AssetInput(
            asset_code="FA-005", asset_name="Truck",
            asset_class="vehicle",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("50000"),
            useful_life_years=5,
            residual_value=Decimal("0"),
            disposal_method="sale",
            disposal_proceeds=Decimal("25000"),
            years_elapsed_at_disposal=2,
        ))
        # After 2 years SL: 50000 × 3/5 = 30000 BV
        # Proceeds 25000 - 30000 = -5000 loss
        assert r.is_disposed is True
        assert r.current_book_value == Decimal("30000.00")
        assert r.gain_loss_on_disposal == Decimal("-5000.00")
        assert any("خسارة" in w for w in r.warnings)

    def test_disposal_loss(self):
        r = build_asset(AssetInput(
            asset_code="FA-006", asset_name="Machine",
            asset_class="ppe",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("100000"),
            useful_life_years=10,
            residual_value=Decimal("0"),
            disposal_method="sale",
            disposal_proceeds=Decimal("60000"),
            years_elapsed_at_disposal=3,
        ))
        # 3 years SL: 100k × 7/10 = 70000 BV
        # Proceeds 60k - 70k = -10k loss
        assert r.gain_loss_on_disposal == Decimal("-10000.00")

    def test_disposal_break_early(self):
        r = build_asset(AssetInput(
            asset_code="FA-007", asset_name="X",
            asset_class="ppe",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("10000"),
            useful_life_years=10,
            residual_value=Decimal("0"),
            disposal_method="scrap",
            disposal_proceeds=Decimal("0"),
            years_elapsed_at_disposal=3,
        ))
        assert len(r.schedule) == 3


class TestRevaluation:
    def test_revaluation_adjusts_bv(self):
        r = build_asset(AssetInput(
            asset_code="FA-008", asset_name="Building",
            asset_class="ppe",
            acquisition_date="2026-01-01",
            acquisition_cost=Decimal("1000000"),
            useful_life_years=20,
            residual_value=Decimal("0"),
            revaluation_amount=Decimal("1500000"),
            revaluation_years_elapsed=5,
        ))
        # After 5 years SL: 1M - 250k = 750k BV
        # After revaluation: 1.5M
        assert r.schedule[4].closing_book_value == Decimal("1500000.00")
        assert any("إعادة تقييم" in w for w in r.warnings)


class TestValidation:
    def test_zero_cost_rejected(self):
        with pytest.raises(ValueError, match="acquisition_cost"):
            build_asset(AssetInput(
                asset_code="x", asset_name="x",
                asset_class="ppe",
                acquisition_date="2026-01-01",
                acquisition_cost=Decimal("0"),
            ))

    def test_bad_method_rejected(self):
        with pytest.raises(ValueError, match="depreciation_method"):
            build_asset(AssetInput(
                asset_code="x", asset_name="x",
                asset_class="ppe",
                acquisition_date="2026-01-01",
                acquisition_cost=Decimal("100"),
                depreciation_method="magic",
            ))

    def test_residual_exceeds_cost_rejected(self):
        with pytest.raises(ValueError, match="residual"):
            build_asset(AssetInput(
                asset_code="x", asset_name="x",
                asset_class="ppe",
                acquisition_date="2026-01-01",
                acquisition_cost=Decimal("100"),
                residual_value=Decimal("200"),
            ))


class TestRoutes:
    def test_requires_auth(self, client):
        r = client.post("/fa/build", json={})
        assert r.status_code == 401

    def test_build_http(self, client, auth_header):
        r = client.post("/fa/build", json={
            "asset_code": "FA-001",
            "asset_name": "Laptop",
            "asset_class": "it_equipment",
            "acquisition_date": "2026-01-01",
            "acquisition_cost": "5000",
            "useful_life_years": 5,
            "residual_value": "500",
            "depreciation_method": "straight_line",
        }, headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["annual_depreciation"] == "900.00"

    def test_methods_endpoint(self, client, auth_header):
        r = client.get("/fa/methods", headers=auth_header)
        assert r.status_code == 200
        assert "straight_line" in r.json()["data"]["depreciation_methods"]
        assert "sale" in r.json()["data"]["disposal_methods"]

    def test_bad_method_http(self, client, auth_header):
        r = client.post("/fa/build", json={
            "asset_code": "x", "asset_name": "x",
            "asset_class": "ppe",
            "acquisition_date": "d",
            "acquisition_cost": "100",
            "depreciation_method": "nonsense",
        }, headers=auth_header)
        assert r.status_code == 422
