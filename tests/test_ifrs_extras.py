"""Tests for IFRS 15/9/IAS 19/36/37 (revenue, eosb, impairment, ecl, provisions)."""

from decimal import Decimal

import pytest

from app.core.revenue_service import (
    PerformanceObligation, ContractInput, recognise_revenue,
)
from app.core.eosb_service import EosbInput, compute_eosb
from app.core.impairment_service import ImpairmentInput, test_impairment as _do_impairment_test
from app.core.ecl_service import ReceivableBucket, EclInput, compute_ecl
from app.core.provisions_service import (
    ProvisionItem, ProvisionsInput, classify_provisions,
)


# ═══════════════════════════════════════════════════════════════
# IFRS 15 — Revenue
# ═══════════════════════════════════════════════════════════════


class TestRevenue:
    def test_single_point_in_time_recognises_full(self):
        r = recognise_revenue(ContractInput(
            contract_id="C1", customer="Alpha", contract_date="2026-01-01",
            transaction_price=Decimal("1000"),
            obligations=[
                PerformanceObligation(description="Widget",
                    standalone_selling_price=Decimal("1000"),
                    recognition_pattern="point_in_time", satisfied=True),
            ],
        ))
        assert r.total_revenue_recognised == Decimal("1000.00")
        assert r.total_deferred_revenue == Decimal("0.00")

    def test_over_time_prorata(self):
        r = recognise_revenue(ContractInput(
            contract_id="C2", customer="Beta", contract_date="2026-01-01",
            transaction_price=Decimal("1200"),
            months_elapsed=6,
            obligations=[
                PerformanceObligation(description="Service 12mo",
                    standalone_selling_price=Decimal("1200"),
                    recognition_pattern="over_time", period_months=12),
            ],
        ))
        # 6/12 = 50% → 600
        assert r.total_revenue_recognised == Decimal("600.00")
        assert r.total_deferred_revenue == Decimal("600.00")

    def test_allocation_with_discount(self):
        # Contract 900, SSP 1000 → 10% discount; two POs 600 and 400
        r = recognise_revenue(ContractInput(
            contract_id="C3", customer="Gamma", contract_date="2026-01-01",
            transaction_price=Decimal("900"),
            obligations=[
                PerformanceObligation(description="A",
                    standalone_selling_price=Decimal("600"),
                    recognition_pattern="point_in_time", satisfied=True),
                PerformanceObligation(description="B",
                    standalone_selling_price=Decimal("400"),
                    recognition_pattern="point_in_time", satisfied=True),
            ],
        ))
        # A gets 900 × 600/1000 = 540; B gets 900 × 400/1000 = 360
        assert r.obligations[0].allocated_price == Decimal("540.00")
        assert r.obligations[1].allocated_price == Decimal("360.00")

    def test_variable_consideration_subtracted(self):
        r = recognise_revenue(ContractInput(
            contract_id="C4", customer="Delta", contract_date="2026-01-01",
            transaction_price=Decimal("1000"),
            variable_consideration=Decimal("100"),
            obligations=[
                PerformanceObligation(description="X",
                    standalone_selling_price=Decimal("1000"),
                    recognition_pattern="point_in_time", satisfied=True),
            ],
        ))
        assert r.net_price == Decimal("900.00")
        assert r.total_revenue_recognised == Decimal("900.00")

    def test_empty_rejected(self):
        with pytest.raises(ValueError):
            recognise_revenue(ContractInput(
                contract_id="x", customer="y", contract_date="d",
                transaction_price=Decimal("100"), obligations=[]))


# ═══════════════════════════════════════════════════════════════
# IAS 19 — EOSB
# ═══════════════════════════════════════════════════════════════


class TestEosb:
    def test_less_than_5yrs(self):
        # 3 years, 10000 wage → 3 × 10000/2 = 15000 raw
        # employer_terminated → 100% → 15000 net
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("10000"),
            years_of_service=Decimal("3"),
        ))
        assert r.raw_gratuity == Decimal("15000.00")
        assert r.net_gratuity == Decimal("15000.00")

    def test_more_than_5yrs(self):
        # 10 yrs: first 5 @ ½mo = 2.5 months + 5 more @ 1mo = 5 months = 7.5 months
        # × 10000 = 75000
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("10000"),
            years_of_service=Decimal("10"),
        ))
        assert r.raw_gratuity == Decimal("75000.00")
        assert r.first_5_years_portion == Decimal("25000.00")
        assert r.after_5_years_portion == Decimal("50000.00")

    def test_resignation_under_2yrs_gets_nothing(self):
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("10000"),
            years_of_service=Decimal("1.5"),
            termination_reason="resignation",
        ))
        assert r.net_gratuity == Decimal("0.00")
        assert any("سنتين" in w for w in r.warnings)

    def test_resignation_5_10yrs_gets_two_thirds(self):
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("10000"),
            years_of_service=Decimal("7"),
            termination_reason="resignation",
        ))
        # Raw: 2.5mo + 2mo = 4.5mo × 10000 = 45000
        # × 66.67% ≈ 30001.5
        assert r.raw_gratuity == Decimal("45000.00")
        assert Decimal("29999") < r.net_gratuity < Decimal("30002")

    def test_allowances_added(self):
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("8000"),
            monthly_allowances=Decimal("2000"),
            years_of_service=Decimal("3"),
        ))
        assert r.monthly_wage_for_calc == Decimal("10000.00")

    def test_dbo_with_future_years(self):
        r = compute_eosb(EosbInput(
            employee_name="Ali", employee_id="E1",
            monthly_basic_salary=Decimal("10000"),
            years_of_service=Decimal("5"),
            expected_future_years=Decimal("10"),
            discount_rate_pct=Decimal("4"),
            wage_growth_pct=Decimal("3"),
        ))
        assert r.expected_future_gratuity > Decimal("0")
        assert r.dbo_present_value > Decimal("0")
        assert r.dbo_present_value < r.expected_future_gratuity


# ═══════════════════════════════════════════════════════════════
# IAS 36 — Impairment
# ═══════════════════════════════════════════════════════════════


class TestImpairment:
    def test_no_impairment_when_recoverable_exceeds_ca(self):
        r = _do_impairment_test(ImpairmentInput(
            asset_name="PP&E", asset_class="ppe",
            carrying_amount=Decimal("800"),
            fair_value_less_costs_to_sell=Decimal("900"),
        ))
        assert r.is_impaired is False
        assert r.impairment_loss == Decimal("0.00")

    def test_impaired_when_ca_exceeds_recoverable(self):
        r = _do_impairment_test(ImpairmentInput(
            asset_name="PP&E", asset_class="ppe",
            carrying_amount=Decimal("1000"),
            fair_value_less_costs_to_sell=Decimal("700"),
        ))
        assert r.is_impaired is True
        assert r.impairment_loss == Decimal("300.00")
        assert r.post_impairment_ca == Decimal("700.00")

    def test_viu_higher_than_fv(self):
        # CF 100 for 5 years @ 10% ≈ 379
        r = _do_impairment_test(ImpairmentInput(
            asset_name="Plant", asset_class="ppe",
            carrying_amount=Decimal("500"),
            fair_value_less_costs_to_sell=Decimal("300"),
            future_cash_flows=[Decimal("100")] * 5,
            discount_rate_pct=Decimal("10"),
        ))
        assert r.value_in_use > Decimal("350")
        assert r.recoverable_method == "value_in_use"

    def test_goodwill_warning(self):
        r = _do_impairment_test(ImpairmentInput(
            asset_name="Goodwill", asset_class="goodwill",
            carrying_amount=Decimal("1000"),
            fair_value_less_costs_to_sell=Decimal("600"),
        ))
        assert r.is_impaired is True
        assert any("الشهرة" in w or "Goodwill" in w for w in r.warnings)

    def test_missing_inputs_rejected(self):
        with pytest.raises(ValueError, match="must supply"):
            _do_impairment_test(ImpairmentInput(
                asset_name="x", asset_class="ppe",
                carrying_amount=Decimal("100"),
            ))


# ═══════════════════════════════════════════════════════════════
# IFRS 9 — ECL
# ═══════════════════════════════════════════════════════════════


class TestEcl:
    def test_provision_matrix_defaults(self):
        # Current 100k @ 0.5% PD × 50% LGD = 250
        r = compute_ecl(EclInput(
            entity_name="Co", period_label="Q1",
            buckets=[
                ReceivableBucket("current", Decimal("100000")),
            ],
        ))
        # 100000 × 0.5% × 50% = 250
        assert r.total_ecl == Decimal("250.00")

    def test_multi_bucket(self):
        r = compute_ecl(EclInput(
            entity_name="Co", period_label="Q1",
            buckets=[
                ReceivableBucket("current", Decimal("100000")),      # 250
                ReceivableBucket("30_60", Decimal("50000")),         # 500
                ReceivableBucket("over_365", Decimal("10000")),      # 4000
            ],
        ))
        assert r.total_ecl == Decimal("4750.00")
        assert r.total_exposure == Decimal("160000.00")

    def test_overrides_applied(self):
        r = compute_ecl(EclInput(
            entity_name="x", period_label="p",
            buckets=[ReceivableBucket("current", Decimal("1000"),
                pd_override_pct=Decimal("10"),
                lgd_pct=Decimal("100"))],
        ))
        # 1000 × 10% × 100% = 100
        assert r.total_ecl == Decimal("100.00")

    def test_aged_portfolio_warning(self):
        r = compute_ecl(EclInput(
            entity_name="x", period_label="p",
            buckets=[
                ReceivableBucket("current", Decimal("1000")),
                ReceivableBucket("over_365", Decimal("5000")),
            ],
        ))
        assert any("أقدم من 180" in w for w in r.warnings)

    def test_unknown_bucket_rejected(self):
        with pytest.raises(ValueError, match="unknown"):
            compute_ecl(EclInput(
                entity_name="x", period_label="p",
                buckets=[ReceivableBucket("mystery", Decimal("100"))],
            ))


# ═══════════════════════════════════════════════════════════════
# IAS 37 — Provisions
# ═══════════════════════════════════════════════════════════════


class TestProvisions:
    def test_probable_liability_becomes_provision(self):
        r = classify_provisions(ProvisionsInput(
            entity_name="x", period_label="p",
            items=[ProvisionItem("Lawsuit loss", "liability",
                probability="probable",
                best_estimate=Decimal("500000"))],
        ))
        assert r.items[0].classification == "provision"
        assert r.items[0].recognise is True

    def test_possible_liability_becomes_contingent(self):
        r = classify_provisions(ProvisionsInput(
            entity_name="x", period_label="p",
            items=[ProvisionItem("Tax dispute", "liability",
                probability="possible",
                best_estimate=Decimal("100000"))],
        ))
        assert r.items[0].classification == "contingent_liability"
        assert r.items[0].recognise is False
        assert r.items[0].disclose is True

    def test_remote_ignored(self):
        r = classify_provisions(ProvisionsInput(
            entity_name="x", period_label="p",
            items=[ProvisionItem("Act of god", "liability",
                probability="remote",
                best_estimate=Decimal("1000000"))],
        ))
        assert r.items[0].classification == "ignore"
        assert r.items[0].recognise is False
        assert r.items[0].disclose is False

    def test_virtually_certain_asset_recognised(self):
        r = classify_provisions(ProvisionsInput(
            entity_name="x", period_label="p",
            items=[ProvisionItem("Insurance claim", "asset",
                probability="virtually_certain",
                best_estimate=Decimal("200000"))],
        ))
        assert r.items[0].classification == "asset"
        assert r.items[0].recognise is True

    def test_discounting_if_multi_year(self):
        r = classify_provisions(ProvisionsInput(
            entity_name="x", period_label="p",
            items=[ProvisionItem("Decommissioning", "liability",
                probability="probable",
                best_estimate=Decimal("1000000"),
                years_to_settlement=Decimal("5"),
                discount_rate_pct=Decimal("5"))],
        ))
        # PV @ 5% for 5 yrs = 1M / 1.05^5 ≈ 783526
        assert r.items[0].discounted_estimate < Decimal("800000")
        assert r.items[0].discounted_estimate > Decimal("750000")


# ═══════════════════════════════════════════════════════════════
# HTTP routes
# ═══════════════════════════════════════════════════════════════


class TestRoutes:
    def test_revenue_requires_auth(self, client):
        assert client.post("/revenue/recognise", json={}).status_code == 401

    def test_eosb_requires_auth(self, client):
        assert client.post("/eosb/compute", json={}).status_code == 401

    def test_revenue_http(self, client, auth_header):
        r = client.post("/revenue/recognise", json={
            "contract_id": "C1", "customer": "Alpha", "contract_date": "2026-01-01",
            "transaction_price": "1000",
            "obligations": [
                {"description": "X", "standalone_selling_price": "1000",
                 "recognition_pattern": "point_in_time", "satisfied": True},
            ],
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["total_revenue_recognised"] == "1000.00"

    def test_eosb_http(self, client, auth_header):
        r = client.post("/eosb/compute", json={
            "employee_name": "Ali", "employee_id": "E1",
            "monthly_basic_salary": "10000",
            "years_of_service": "10",
            "termination_reason": "employer_terminated",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["net_gratuity"] == "75000.00"

    def test_eosb_reasons(self, client, auth_header):
        r = client.get("/eosb/reasons", headers=auth_header)
        assert r.status_code == 200
        assert "resignation" in r.json()["data"]

    def test_impairment_http(self, client, auth_header):
        r = client.post("/impairment/test", json={
            "asset_name": "Plant", "asset_class": "ppe",
            "carrying_amount": "1000",
            "fair_value_less_costs_to_sell": "700",
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["is_impaired"] is True
        assert r.json()["data"]["impairment_loss"] == "300.00"

    def test_ecl_http(self, client, auth_header):
        r = client.post("/ecl/compute", json={
            "entity_name": "Co", "period_label": "Q1",
            "buckets": [{"bucket": "current", "exposure": "100000"}],
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["total_ecl"] == "250.00"

    def test_ecl_defaults(self, client, auth_header):
        r = client.get("/ecl/defaults", headers=auth_header)
        assert r.status_code == 200
        assert "current" in r.json()["data"]["buckets"]

    def test_provisions_http(self, client, auth_header):
        r = client.post("/provisions/classify", json={
            "entity_name": "Co", "period_label": "Q1",
            "items": [{
                "description": "Lawsuit", "item_type": "liability",
                "probability": "probable", "best_estimate": "500000",
            }],
        }, headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["items"][0]["classification"] == "provision"

    def test_provisions_levels(self, client, auth_header):
        r = client.get("/provisions/levels", headers=auth_header)
        assert r.status_code == 200
        assert "probable" in r.json()["data"]["probabilities"]

    def test_bad_recognition_pattern_rejected(self, client, auth_header):
        r = client.post("/revenue/recognise", json={
            "contract_id": "x", "customer": "y", "contract_date": "d",
            "transaction_price": "100",
            "obligations": [{"description": "o",
                "standalone_selling_price": "100",
                "recognition_pattern": "junk"}],
        }, headers=auth_header)
        assert r.status_code == 422
