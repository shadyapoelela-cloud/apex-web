"""DSCR + WACC + DCF tests."""

from decimal import Decimal

import pytest

from app.core.dscr_service import DscrInput, compute_dscr
from app.core.valuation_service import WaccInput, DcfInput, compute_wacc, compute_dcf


class TestDscr:
    def test_strong_dscr(self):
        # EBITDA 300k, interest 30k, principal 60k → DS 90k → DSCR 3.33
        r = compute_dscr(DscrInput(
            ebitda=Decimal("300000"),
            interest_expense=Decimal("30000"),
            current_principal_payments=Decimal("60000"),
        ))
        assert r.dscr is not None
        assert Decimal("3.3") < r.dscr < Decimal("3.4")
        assert r.dscr_benchmark == "excellent"
        assert r.dscr_decision == "approve"

    def test_weak_dscr_declined(self):
        r = compute_dscr(DscrInput(
            ebitda=Decimal("100000"),
            interest_expense=Decimal("60000"),
            current_principal_payments=Decimal("50000"),
        ))
        # DSCR = 100 / 110 = 0.91 → risk/decline
        assert r.dscr < Decimal("1.0")
        assert r.dscr_decision == "decline"

    def test_conditional_approval(self):
        r = compute_dscr(DscrInput(
            ebitda=Decimal("115000"),
            interest_expense=Decimal("60000"),
            current_principal_payments=Decimal("40000"),
        ))
        # DSCR = 115/100 = 1.15 → watch/conditional
        assert r.dscr_decision == "conditional"

    def test_max_loan_calculation(self):
        # Strong DSCR → has room for more loan
        r = compute_dscr(DscrInput(
            ebitda=Decimal("500000"),
            interest_expense=Decimal("0"),
            current_principal_payments=Decimal("0"),
            target_dscr=Decimal("1.25"),
            proposed_rate_pct=Decimal("6"),
            proposed_term_years=5,
        ))
        # Available annual DS = 500k / 1.25 = 400k
        # At 6% / 5y, annuity factor = (1 - 1.06^-5) / 0.06 = 4.2124
        # Max loan = 400k × 4.2124 ≈ 1,684,960
        assert r.max_additional_annual_ds == Decimal("400000.00")
        assert r.max_loan_amount is not None
        assert Decimal("1600000") < r.max_loan_amount < Decimal("1800000")

    def test_leverage_warning(self):
        r = compute_dscr(DscrInput(
            ebitda=Decimal("100000"),
            total_debt=Decimal("500000"),          # 5× leverage
            interest_expense=Decimal("25000"),
            current_principal_payments=Decimal("20000"),
        ))
        assert r.leverage_ratio is not None
        assert r.leverage_ratio >= Decimal("4.0")
        assert any("الرفع" in rec for rec in r.recommendations)

    def test_negative_ebitda_warning(self):
        r = compute_dscr(DscrInput(
            ebitda=Decimal("-50000"),
            interest_expense=Decimal("10000"),
        ))
        assert any("EBITDA" in w for w in r.warnings)


class TestWacc:
    def test_simple_wacc(self):
        # E=60M, D=40M, Re=12%, Rd=6%, T=20%
        # WACC = 0.6×0.12 + 0.4×0.06×0.8 = 0.072 + 0.0192 = 0.0912 = 9.12%
        r = compute_wacc(WaccInput(
            equity_value=Decimal("60000000"),
            debt_value=Decimal("40000000"),
            cost_of_equity_override=Decimal("0.12"),
            cost_of_debt=Decimal("0.06"),
            tax_rate=Decimal("0.20"),
        ))
        assert r.wacc_pct == Decimal("9.12")
        assert r.weight_equity_pct == Decimal("60.00")
        assert r.weight_debt_pct == Decimal("40.00")

    def test_capm_cost_of_equity(self):
        # Rf=4%, β=1.5, ERP=6% → Re = 4 + 1.5×6 = 13%
        r = compute_wacc(WaccInput(
            equity_value=Decimal("100"),
            debt_value=Decimal("0"),
            risk_free_rate=Decimal("0.04"),
            beta=Decimal("1.5"),
            equity_risk_premium=Decimal("0.06"),
        ))
        assert r.cost_of_equity_pct == Decimal("13.00")
        # All equity → WACC = Re
        assert r.wacc_pct == Decimal("13.00")

    def test_all_debt_wacc(self):
        # All debt: WACC = Rd × (1-T) = 0.06 × 0.8 = 0.048 = 4.8%
        r = compute_wacc(WaccInput(
            equity_value=Decimal("0"),
            debt_value=Decimal("100"),
            cost_of_debt=Decimal("0.06"),
            tax_rate=Decimal("0.20"),
        ))
        assert r.wacc_pct == Decimal("4.80")

    def test_zero_capital_rejected(self):
        with pytest.raises(ValueError):
            compute_wacc(WaccInput(
                equity_value=Decimal("0"),
                debt_value=Decimal("0"),
            ))

    def test_invalid_tax_rejected(self):
        with pytest.raises(ValueError):
            compute_wacc(WaccInput(
                equity_value=Decimal("100"),
                debt_value=Decimal("100"),
                tax_rate=Decimal("1.5"),
            ))


class TestDcf:
    def test_simple_dcf(self):
        # 5 years of FCF = 10M, WACC 10%, g 2%
        r = compute_dcf(DcfInput(
            free_cash_flows=[Decimal("10000000")] * 5,
            wacc_pct=Decimal("10"),
            terminal_growth_pct=Decimal("2"),
        ))
        # PV of 10M × 5 at 10% = 37.908M
        # TV = 10M × 1.02 / (0.10 - 0.02) = 127.5M at year 5
        # TV_PV = 127.5M / 1.10^5 = 79.17M
        # EV ≈ 37.9 + 79.2 = 117.1M
        assert Decimal("115000000") < r.enterprise_value < Decimal("120000000")
        assert len(r.years) == 5

    def test_growing_fcf(self):
        r = compute_dcf(DcfInput(
            free_cash_flows=[
                Decimal("10000000"),
                Decimal("11000000"),
                Decimal("12000000"),
                Decimal("13000000"),
                Decimal("14000000"),
            ],
            wacc_pct=Decimal("12"),
            terminal_growth_pct=Decimal("3"),
        ))
        # PVs should be increasing then discounted more heavily
        assert all(y.present_value > 0 for y in r.years)
        assert r.enterprise_value > 0

    def test_equity_per_share(self):
        r = compute_dcf(DcfInput(
            free_cash_flows=[Decimal("5000000")] * 3,
            wacc_pct=Decimal("10"),
            terminal_growth_pct=Decimal("2"),
            net_debt=Decimal("5000000"),
            shares_outstanding=Decimal("1000000"),
        ))
        assert r.value_per_share is not None
        assert r.value_per_share > 0
        # Equity = EV − Net debt
        assert r.equity_value == r.enterprise_value - Decimal("5000000")

    def test_growth_exceeds_wacc_rejected(self):
        with pytest.raises(ValueError, match="terminal_growth"):
            compute_dcf(DcfInput(
                free_cash_flows=[Decimal("100")],
                wacc_pct=Decimal("5"),
                terminal_growth_pct=Decimal("10"),   # g > WACC
            ))

    def test_empty_fcf_rejected(self):
        with pytest.raises(ValueError):
            compute_dcf(DcfInput(free_cash_flows=[], wacc_pct=Decimal("10")))

    def test_terminal_dominance_warning(self):
        # Short projection with high terminal growth → TV dominates
        r = compute_dcf(DcfInput(
            free_cash_flows=[Decimal("1000")],  # only 1 year
            wacc_pct=Decimal("10"),
            terminal_growth_pct=Decimal("5"),
        ))
        # Terminal value will be >> 75% of EV
        assert any("النهائية" in w for w in r.warnings)


class TestRoutes:
    def test_dscr_requires_auth(self, client):
        r = client.post("/dscr/analyze", json={})
        assert r.status_code == 401

    def test_dscr_http(self, client, auth_header):
        r = client.post(
            "/dscr/analyze",
            json={
                "ebitda": "500000",
                "interest_expense": "50000",
                "current_principal_payments": "100000",
                "target_dscr": "1.25",
                "proposed_rate_pct": "6",
                "proposed_term_years": 5,
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        # DSCR = 500k / 150k = 3.33 → excellent
        assert d["dscr_decision"] == "approve"

    def test_wacc_http(self, client, auth_header):
        r = client.post(
            "/wacc/compute",
            json={
                "equity_value": "100000",
                "debt_value": "50000",
                "cost_of_equity_override": "0.12",
                "cost_of_debt": "0.06",
                "tax_rate": "0.20",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        # WACC = (100/150)×12 + (50/150)×6×0.8 = 8.0 + 1.6 = 9.6%
        assert d["wacc_pct"] == "9.60"

    def test_dcf_http(self, client, auth_header):
        r = client.post(
            "/dcf/analyze",
            json={
                "free_cash_flows": ["10000000", "11000000", "12000000"],
                "wacc_pct": "10",
                "terminal_growth_pct": "2.5",
                "net_debt": "0",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert len(d["years"]) == 3
        assert float(d["enterprise_value"]) > 0

    def test_endpoints_require_auth(self, client):
        assert client.post("/wacc/compute", json={}).status_code == 401
        assert client.post("/dcf/analyze", json={}).status_code == 401
