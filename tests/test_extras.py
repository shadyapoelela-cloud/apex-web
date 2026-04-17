"""Tests for IFRS 2/40/41, RETT, Pillar Two, VAT Group, Job Costing."""

from decimal import Decimal

import pytest

from app.core.advanced_ifrs_service import (
    SbpInput, compute_sbp,
    InvPropertyInput, compute_investment_property,
    AgricultureInput, compute_agriculture,
)
from app.core.advanced_tax_service import (
    RettInput, compute_rett,
    PillarTwoInput, PillarTwoJurisdiction, compute_pillar_two,
    VatGroupInput, VatGroupMember, compute_vat_group,
)
from app.core.job_costing_service import (
    JobInput, CostEntry, analyse_job,
)


class TestSbp:
    def test_cliff_vesting_straight_line(self):
        # 1000 options × 100 FV × 95% vesting = 95000
        # 4-year cliff: 23750/year
        r = compute_sbp(SbpInput(
            plan_name="Plan A",
            instrument_type="stock_option",
            grant_date="2026-01-01",
            grant_date_fair_value_per_unit=Decimal("100"),
            units_granted=1000,
            vesting_period_years=4,
            vesting_pattern="cliff",
            forfeiture_rate_pct=Decimal("5"),
            years_elapsed=2,
        ))
        assert r.expected_vesting_units == 950
        assert r.total_grant_date_fair_value == Decimal("95000.00")
        # After 2 years: 47500 cumulative
        assert r.expense_to_date == Decimal("47500.00")

    def test_completed_vesting(self):
        r = compute_sbp(SbpInput(
            plan_name="P", instrument_type="rsu",
            grant_date="2026-01-01",
            grant_date_fair_value_per_unit=Decimal("100"),
            units_granted=100,
            vesting_period_years=3,
            years_elapsed=3,
            forfeiture_rate_pct=Decimal("0"),
        ))
        assert r.remaining_expense == Decimal("0.00")
        assert any("اكتملت" in w for w in r.warnings)

    def test_bad_instrument_rejected(self):
        with pytest.raises(ValueError, match="instrument_type"):
            compute_sbp(SbpInput(
                plan_name="x", instrument_type="nft",
                grant_date="d",
                grant_date_fair_value_per_unit=Decimal("1"),
                units_granted=1, vesting_period_years=1,
            ))


class TestInvestmentProperty:
    def test_cost_model(self):
        r = compute_investment_property(InvPropertyInput(
            property_name="Office A",
            acquisition_cost=Decimal("10000000"),
            useful_life_years=40,
            model="cost",
            years_elapsed=5,
            rental_income_annual=Decimal("500000"),
            operating_costs_annual=Decimal("100000"),
        ))
        # Annual dep: 10M/40 = 250k; 5 years = 1.25M
        assert r.accumulated_depreciation == Decimal("1250000.00")
        # CA = 10M - 1.25M = 8.75M
        assert r.current_carrying_amount == Decimal("8750000.00")
        # Gross yield = 500k/10M = 5%
        assert r.gross_rental_yield_pct == Decimal("5.00")
        assert r.net_rental_income == Decimal("400000.00")

    def test_fair_value_model_gain(self):
        r = compute_investment_property(InvPropertyInput(
            property_name="B",
            acquisition_cost=Decimal("1000000"),
            model="fair_value",
            current_fair_value=Decimal("1200000"),
        ))
        assert r.fair_value_adjustment == Decimal("200000.00")
        assert any("ربح" in w for w in r.warnings)


class TestAgriculture:
    def test_livestock_growth(self):
        # 100 heads: FV 500→600 per head, 3% CtS
        # FV begin = 100 × 500 × 0.97 = 48500
        # FV end = 100 × 600 × 0.97 = 58200
        # Change price = 100 × 100 × 0.97 = 9700
        r = compute_agriculture(AgricultureInput(
            asset_name="Cattle",
            biological_type="livestock",
            units=Decimal("100"),
            fair_value_per_unit_beginning=Decimal("500"),
            fair_value_per_unit_end=Decimal("600"),
            costs_to_sell_pct=Decimal("3"),
        ))
        assert r.fair_value_beginning == Decimal("48500.00")
        assert r.fair_value_end == Decimal("58200.00")
        assert r.change_from_price == Decimal("9700.00")

    def test_bad_biological_type(self):
        with pytest.raises(ValueError, match="biological_type"):
            compute_agriculture(AgricultureInput(
                asset_name="x", biological_type="robots",
                units=Decimal("1"),
                fair_value_per_unit_beginning=Decimal("1"),
                fair_value_per_unit_end=Decimal("1"),
            ))


class TestRett:
    def test_basic_commercial_sale(self):
        # 10M commercial sale → 5% RETT = 500k + 15% VAT = 1.5M
        r = compute_rett(RettInput(
            property_type="commercial",
            transaction_mode="sale",
            sale_value=Decimal("10000000"),
            sale_date="2026-01-01",
        ))
        assert r.rett_amount == Decimal("500000.00")
        assert r.vat_applicable is True
        assert r.vat_amount == Decimal("1500000.00")

    def test_first_home_exempt(self):
        r = compute_rett(RettInput(
            property_type="residential",
            transaction_mode="sale",
            sale_value=Decimal("800000"),
            sale_date="2026-01-01",
            is_first_home=True,
            buyer_is_saudi_citizen=True,
        ))
        assert r.rett_amount == Decimal("0.00")
        assert r.exemption_applied == "first_home_full"

    def test_first_home_partial(self):
        # 1.5M → exempt first 1M → 500k taxable × 5% = 25k
        r = compute_rett(RettInput(
            property_type="residential",
            transaction_mode="sale",
            sale_value=Decimal("1500000"),
            sale_date="2026-01-01",
            is_first_home=True,
            buyer_is_saudi_citizen=True,
        ))
        assert r.rett_amount == Decimal("25000.00")
        assert r.exemption_applied == "first_home_partial"

    def test_family_transfer_exempt(self):
        r = compute_rett(RettInput(
            property_type="residential",
            transaction_mode="sale",
            sale_value=Decimal("5000000"),
            sale_date="2026-01-01",
            is_family_transfer=True,
        ))
        assert r.rett_amount == Decimal("0.00")


class TestPillarTwo:
    def test_below_minimum_triggers_top_up(self):
        # KSA 20% > 15% → no top-up
        # UAE 0% → top up
        r = compute_pillar_two(PillarTwoInput(
            group_name="G",
            fiscal_year="2026",
            group_consolidated_revenue=Decimal("5000000000"),
            jurisdictions=[
                PillarTwoJurisdiction("KSA", Decimal("10000000"),
                    Decimal("2000000"), Decimal("0"), Decimal("0")),
                PillarTwoJurisdiction("UAE", Decimal("5000000"),
                    Decimal("0"), Decimal("0"), Decimal("0")),
            ],
        ))
        ksa = next(j for j in r.jurisdictions if j.jurisdiction == "KSA")
        uae = next(j for j in r.jurisdictions if j.jurisdiction == "UAE")
        assert ksa.status == "above_minimum"
        assert uae.status == "top_up_required"
        assert uae.top_up_tax == Decimal("750000.00")  # 5M × 15%

    def test_below_threshold_no_top_up(self):
        r = compute_pillar_two(PillarTwoInput(
            group_name="SmallGroup",
            fiscal_year="2026",
            group_consolidated_revenue=Decimal("1000000000"),  # < 3.2B
            jurisdictions=[
                PillarTwoJurisdiction("UAE", Decimal("1000000"),
                    Decimal("0"), Decimal("0"), Decimal("0")),
            ],
        ))
        assert r.threshold_met is False
        assert r.total_top_up_tax == Decimal("0.00")


class TestVatGroup:
    def test_basic_group(self):
        r = compute_vat_group(VatGroupInput(
            group_name="G",
            fiscal_period="Q1",
            representative_member="A",
            members=[
                VatGroupMember("A", "300000001", Decimal("5000000"),
                    Decimal("750000"), Decimal("300000")),
                VatGroupMember("B", "300000002", Decimal("2000000"),
                    Decimal("300000"), Decimal("150000")),
            ],
        ))
        assert r.total_taxable_supplies == Decimal("7000000.00")
        assert r.net_vat_payable == Decimal("600000.00")
        assert r.is_above_threshold is True
        assert r.members_count == 2

    def test_empty_rejected(self):
        with pytest.raises(ValueError):
            compute_vat_group(VatGroupInput(
                group_name="g", fiscal_period="p",
                representative_member="r", members=[]))


class TestJobCosting:
    def test_on_budget(self):
        r = analyse_job(JobInput(
            project_name="P1", project_code="PRJ-001",
            contract_value=Decimal("1000000"),
            contract_start_date="2026-01-01",
            estimated_end_date="2026-12-31",
            costs=[
                CostEntry(category="labour", description="Staff",
                    budgeted=Decimal("400000"), actual=Decimal("380000")),
                CostEntry(category="material", description="Inputs",
                    budgeted=Decimal("300000"), actual=Decimal("290000")),
                CostEntry(category="overhead", description="Overhead",
                    budgeted=Decimal("100000"), actual=Decimal("95000")),
            ],
        ))
        # total budget 800k, actual 765k, variance 35k favourable
        assert r.total_budgeted == Decimal("800000.00")
        assert r.total_actual == Decimal("765000.00")
        assert r.total_variance == Decimal("35000.00")
        assert r.status in ("on_budget", "under_budget")

    def test_over_budget_warning(self):
        r = analyse_job(JobInput(
            project_name="P", project_code="P",
            contract_value=Decimal("100000"),
            contract_start_date="d", estimated_end_date="d",
            costs=[CostEntry(category="labour", description="L",
                budgeted=Decimal("50000"), actual=Decimal("80000"))],
        ))
        assert r.status == "over_budget"
        assert any("تجاوز" in w for w in r.warnings)

    def test_loss_on_contract_flagged(self):
        r = analyse_job(JobInput(
            project_name="P", project_code="P",
            contract_value=Decimal("100000"),
            contract_start_date="d", estimated_end_date="d",
            costs=[CostEntry(category="labour", description="L",
                budgeted=Decimal("150000"), actual=Decimal("80000"))],
            additional_eac=Decimal("40000"),
        ))
        # EAC = 80k + 40k = 120k > contract 100k → loss
        assert r.estimated_profit_at_completion < Decimal("0")
        assert any("خسارة" in w for w in r.warnings)

    def test_bad_category_rejected(self):
        with pytest.raises(ValueError, match="category"):
            analyse_job(JobInput(
                project_name="P", project_code="P",
                contract_value=Decimal("100"),
                contract_start_date="d", estimated_end_date="d",
                costs=[CostEntry(category="magic", description="x",
                    budgeted=Decimal("10"))],
            ))


class TestRoutes:
    def test_requires_auth(self, client):
        for ep in ["/sbp/compute", "/investment-property/compute",
                   "/agriculture/compute", "/rett/compute",
                   "/pillar-two/compute", "/vat-group/compute",
                   "/job/analyse"]:
            assert client.post(ep, json={}).status_code == 401

    def test_sbp_http(self, client, auth_header):
        r = client.post("/sbp/compute", json={
            "plan_name": "P", "instrument_type": "stock_option",
            "grant_date": "2026-01-01",
            "grant_date_fair_value_per_unit": "100",
            "units_granted": 1000,
            "vesting_period_years": 4,
            "years_elapsed": 2,
        }, headers=auth_header)
        assert r.status_code == 200

    def test_rett_http(self, client, auth_header):
        r = client.post("/rett/compute", json={
            "property_type": "commercial",
            "transaction_mode": "sale",
            "sale_value": "10000000",
            "sale_date": "2026-01-01",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["rett_amount"] == "500000.00"

    def test_enums_endpoint(self, client, auth_header):
        r = client.get("/extras/enums", headers=auth_header)
        assert r.status_code == 200
        data = r.json()["data"]
        assert "stock_option" in data["sbp_instruments"]
        assert "livestock" in data["biological_types"]

    def test_p2_http(self, client, auth_header):
        r = client.post("/pillar-two/compute", json={
            "group_name": "G", "fiscal_year": "2026",
            "group_consolidated_revenue": "5000000000",
            "jurisdictions": [{
                "jurisdiction": "UAE",
                "gloBE_income": "10000000",
                "covered_taxes": "0",
            }],
        }, headers=auth_header)
        assert r.status_code == 200

    def test_job_http(self, client, auth_header):
        r = client.post("/job/analyse", json={
            "project_name": "P", "project_code": "P",
            "contract_value": "1000000",
            "costs": [{"category": "labour", "description": "L",
                "budgeted": "500000", "actual": "450000"}],
        }, headers=auth_header)
        assert r.status_code == 200
