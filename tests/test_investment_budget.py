"""Investment (NPV/IRR) + Budget variance tests."""

from decimal import Decimal

import pytest

from app.core.investment_service import InvestmentInput, compute_investment
from app.core.budget_service import BudgetInput, BudgetLineInput, compute_budget


# ══════════════════════════════════════════════════════════════
# Investment (NPV / IRR / Payback)
# ══════════════════════════════════════════════════════════════


class TestInvestment:
    def test_simple_npv_positive(self):
        # Classic: -100k initial, 5 × 30k returns at 10%
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000"), Decimal("30000"), Decimal("30000"),
                        Decimal("30000"), Decimal("30000"), Decimal("30000")],
            discount_rate=Decimal("0.10"),
        ))
        # PV of 30k × 5 at 10% ≈ 113,723.60 → NPV ≈ 13,723.60
        assert r.npv > Decimal("13000")
        assert r.npv < Decimal("14000")
        assert r.decision == "accept"

    def test_npv_negative_reject(self):
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000"), Decimal("20000"), Decimal("20000"),
                        Decimal("20000"), Decimal("20000")],
            discount_rate=Decimal("0.15"),
        ))
        # PV of 20k × 4 at 15% ≈ 57,100 → NPV ≈ -42,900
        assert r.npv < 0
        assert r.decision == "reject"

    def test_irr_reasonable(self):
        # Investment with known IRR ≈ 15% (5-year $30k from $100k)
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000")] + [Decimal("30000")] * 5,
            discount_rate=Decimal("0.10"),
        ))
        assert r.irr_pct is not None
        # IRR should be ≈ 15.24%
        assert Decimal("15") < r.irr_pct < Decimal("16")

    def test_irr_no_sign_change(self):
        # All negative — no IRR
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100"), Decimal("-50"), Decimal("-50")],
            discount_rate=Decimal("0.10"),
        ))
        assert r.irr_pct is None

    def test_profitability_index(self):
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000")] + [Decimal("30000")] * 5,
            discount_rate=Decimal("0.10"),
        ))
        # PI = PV future / |initial| = ~113k / 100k ≈ 1.14
        assert r.profitability_index is not None
        assert Decimal("1.1") < r.profitability_index < Decimal("1.2")

    def test_simple_payback(self):
        # -100k, 4×25k → full payback at end of year 4
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000"), Decimal("25000"), Decimal("25000"),
                        Decimal("25000"), Decimal("25000")],
            discount_rate=Decimal("0.10"),
        ))
        # Cumulative: -100, -75, -50, -25, 0 → payback at end of period 4
        assert r.simple_payback == Decimal("4.0000")

    def test_partial_payback_period(self):
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100"), Decimal("40"), Decimal("40"), Decimal("40")],
            discount_rate=Decimal("0.10"),
        ))
        # Cum: -100, -60, -20, 20 → payback = 2 + 20/40 = 2.5
        assert r.simple_payback == Decimal("2.5000")

    def test_discounted_payback(self):
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("-100000")] + [Decimal("30000")] * 5,
            discount_rate=Decimal("0.10"),
        ))
        # Discounted payback is longer than simple
        assert r.discounted_payback is not None
        assert r.simple_payback is not None
        assert r.discounted_payback > r.simple_payback

    def test_initial_not_negative_warns(self):
        r = compute_investment(InvestmentInput(
            cash_flows=[Decimal("100000"), Decimal("30000")],
            discount_rate=Decimal("0.10"),
        ))
        assert any("investment" in w.lower() or "استثمار" in w for w in r.warnings)

    def test_empty_cashflows_rejected(self):
        with pytest.raises(ValueError):
            compute_investment(InvestmentInput(cash_flows=[]))

    def test_single_period_rejected(self):
        with pytest.raises(ValueError):
            compute_investment(InvestmentInput(cash_flows=[Decimal("100")]))


# ══════════════════════════════════════════════════════════════
# Budget vs Actual
# ══════════════════════════════════════════════════════════════


class TestBudget:
    def test_revenue_over_budget_favourable(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Sales", "revenue", Decimal("100000"), Decimal("110000")),
        ]))
        ln = r.lines[0]
        assert ln.variance_amount == Decimal("10000.00")
        assert ln.variance_pct == Decimal("10.00")
        assert ln.favourable is True
        assert ln.severity == "ok"

    def test_revenue_below_budget_unfavourable(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Sales", "revenue", Decimal("100000"), Decimal("85000")),
        ]))
        ln = r.lines[0]
        assert ln.favourable is False
        # -15% variance → watch (between 5% and 15%)
        assert ln.severity in ("watch", "risk")

    def test_expense_over_budget_unfavourable(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Rent", "expense", Decimal("10000"), Decimal("12000")),
        ]))
        ln = r.lines[0]
        assert ln.variance_amount == Decimal("2000.00")
        assert ln.variance_pct == Decimal("20.00")
        assert ln.favourable is False
        assert ln.severity == "risk"   # > 15%

    def test_expense_under_budget_favourable(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Rent", "expense", Decimal("10000"), Decimal("8000")),
        ]))
        ln = r.lines[0]
        assert ln.favourable is True
        assert ln.severity == "ok"

    def test_net_variance_correct(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Sales",   "revenue", Decimal("100000"), Decimal("110000")),
            BudgetLineInput("Rent",    "expense", Decimal("10000"),  Decimal("11000")),
            BudgetLineInput("Salary",  "expense", Decimal("40000"),  Decimal("40000")),
        ]))
        # Budget net: 100 - 50 = 50k
        # Actual net: 110 - 51 = 59k
        # Variance: +9k
        assert r.net_budget == Decimal("50000.00")
        assert r.net_actual == Decimal("59000.00")
        assert r.net_variance == Decimal("9000.00")

    def test_zero_budget_no_pct(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("New Item", "revenue", Decimal("0"), Decimal("1000")),
        ]))
        assert r.lines[0].variance_pct is None
        assert any("صفر" in w for w in r.warnings)

    def test_risk_lines_warning(self):
        r = compute_budget(BudgetInput(lines=[
            BudgetLineInput("Overrun1", "expense", Decimal("100"), Decimal("200")),
            BudgetLineInput("Overrun2", "expense", Decimal("100"), Decimal("300")),
        ]))
        assert any("تجاوز" in w for w in r.warnings)

    def test_invalid_kind_rejected(self):
        with pytest.raises(ValueError):
            compute_budget(BudgetInput(lines=[
                BudgetLineInput("Bad", "asset", Decimal("100"), Decimal("200")),
            ]))

    def test_empty_lines_rejected(self):
        with pytest.raises(ValueError):
            compute_budget(BudgetInput(lines=[]))


# ══════════════════════════════════════════════════════════════
# HTTP
# ══════════════════════════════════════════════════════════════


class TestRoutes:
    def test_investment_requires_auth(self, client):
        r = client.post("/investment/analyze", json={"cash_flows": ["-100", "50", "60"]})
        assert r.status_code == 401

    def test_investment_http(self, client, auth_header):
        r = client.post(
            "/investment/analyze",
            json={
                "cash_flows": ["-100000", "30000", "30000", "30000", "30000", "30000"],
                "discount_rate": "0.10",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["decision"] == "accept"
        assert float(d["npv"]) > 13000
        assert d["irr_pct"] is not None

    def test_budget_requires_auth(self, client):
        r = client.post("/budget/variance", json={"lines": []})
        assert r.status_code == 401

    def test_budget_http(self, client, auth_header):
        r = client.post(
            "/budget/variance",
            json={
                "period_label": "2026-Q1",
                "lines": [
                    {"name": "Sales",  "kind": "revenue", "budget": "100000", "actual": "110000"},
                    {"name": "Rent",   "kind": "expense", "budget": "10000",  "actual": "11000"},
                ],
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["totals"]["net_variance"] == "9000.00"
        assert len(d["lines"]) == 2

    def test_budget_empty_lines_rejected(self, client, auth_header):
        r = client.post(
            "/budget/variance",
            json={"lines": []},
            headers=auth_header,
        )
        assert r.status_code == 422
