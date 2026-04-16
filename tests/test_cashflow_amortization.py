"""Cash Flow + Amortization tests."""

from decimal import Decimal

import pytest

from app.core.cashflow_service import CashFlowInput, compute_cashflow
from app.core.amortization_service import AmortizationInput, compute_amortization


# ══════════════════════════════════════════════════════════════
# Cash Flow
# ══════════════════════════════════════════════════════════════


class TestCashFlow:
    def test_simple_profitable_no_changes(self):
        # NI 100k, no other items → operating = 100k
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("100000"),
            beginning_cash=Decimal("50000"),
        ))
        assert r.operating.subtotal == Decimal("100000.00")
        assert r.investing.subtotal == Decimal("0.00")
        assert r.financing.subtotal == Decimal("0.00")
        assert r.net_change == Decimal("100000.00")
        assert r.ending_cash_computed == Decimal("150000.00")

    def test_working_capital_adjustments(self):
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("100000"),
            depreciation_amortization=Decimal("20000"),
            increase_receivables=Decimal("15000"),
            increase_payables=Decimal("5000"),
        ))
        # 100k + 20k - 15k + 5k = 110k
        assert r.operating.subtotal == Decimal("110000.00")

    def test_full_three_sections(self):
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("200000"),
            depreciation_amortization=Decimal("30000"),
            capex=Decimal("50000"),
            loan_proceeds=Decimal("100000"),
            loan_repayments=Decimal("20000"),
            dividends_paid=Decimal("10000"),
            beginning_cash=Decimal("100000"),
        ))
        assert r.operating.subtotal == Decimal("230000.00")
        assert r.investing.subtotal == Decimal("-50000.00")
        assert r.financing.subtotal == Decimal("70000.00")  # +100 -20 -10
        assert r.net_change == Decimal("250000.00")
        assert r.ending_cash_computed == Decimal("350000.00")

    def test_reconciliation_match(self):
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("100"),
            beginning_cash=Decimal("50"),
            ending_cash_reported=Decimal("150"),
        ))
        assert r.reconciles is True
        assert r.reconciliation_diff == Decimal("0.00")

    def test_reconciliation_mismatch_warning(self):
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("100"),
            beginning_cash=Decimal("50"),
            ending_cash_reported=Decimal("200"),   # wrong
        ))
        assert r.reconciles is False
        assert r.reconciliation_diff == Decimal("-50.00")
        assert any("عدم تطابق" in w for w in r.warnings)

    def test_negative_operating_warning(self):
        r = compute_cashflow(CashFlowInput(
            net_income=Decimal("-50000"),
            increase_receivables=Decimal("10000"),
        ))
        assert r.operating.subtotal < 0
        assert any("سالب" in w for w in r.warnings)

    def test_empty_sections_have_only_required_lines(self):
        r = compute_cashflow(CashFlowInput())
        # Operating always has NI line (even if zero)
        assert len(r.operating.lines) == 1
        assert r.investing.lines == []
        assert r.financing.lines == []


# ══════════════════════════════════════════════════════════════
# Amortization
# ══════════════════════════════════════════════════════════════


class TestAmortization:
    def test_fixed_payment_monthly(self):
        # 100,000 loan, 6% APR, 10 years, monthly
        r = compute_amortization(AmortizationInput(
            principal=Decimal("100000"),
            annual_rate_pct=Decimal("6"),
            years=10,
            periods_per_year=12,
            method="fixed_payment",
        ))
        assert r.total_periods == 120
        # PMT ≈ 1,110.21 per month for 10y at 6% APR
        assert Decimal("1100") < r.fixed_payment < Decimal("1120")
        # Ending balance must be zero
        assert r.schedule[-1].closing_balance == Decimal("0.00")
        # Total interest ≈ 33,225 for this loan
        assert Decimal("33000") < r.total_interest < Decimal("33500")

    def test_constant_principal_monthly(self):
        r = compute_amortization(AmortizationInput(
            principal=Decimal("120000"),
            annual_rate_pct=Decimal("6"),
            years=10,
            periods_per_year=12,
            method="constant_principal",
        ))
        # Principal per period = 120000 / 120 = 1000
        assert r.schedule[0].principal == Decimal("1000.00")
        # Later periods have same principal but less interest
        assert r.schedule[0].interest > r.schedule[-1].interest
        # Total payments = P + total interest
        assert r.total_payments == Decimal("120000.00") + r.total_interest

    def test_zero_interest_fixed(self):
        r = compute_amortization(AmortizationInput(
            principal=Decimal("12000"),
            annual_rate_pct=Decimal("0"),
            years=1,
            periods_per_year=12,
        ))
        # Payment should be exactly 1000 × 12 months
        assert r.fixed_payment == Decimal("1000.00")
        assert r.total_interest == Decimal("0.00")

    def test_annual_compounding(self):
        r = compute_amortization(AmortizationInput(
            principal=Decimal("100000"),
            annual_rate_pct=Decimal("10"),
            years=5,
            periods_per_year=1,
        ))
        assert r.total_periods == 5
        # 10% × 100000 = 10000 interest year 1
        assert r.schedule[0].interest == Decimal("10000.00")

    def test_balance_zero_at_end(self):
        for method in ("fixed_payment", "constant_principal"):
            r = compute_amortization(AmortizationInput(
                principal=Decimal("50000"),
                annual_rate_pct=Decimal("5.5"),
                years=7,
                periods_per_year=12,
                method=method,
            ))
            assert r.schedule[-1].closing_balance == Decimal("0.00"), f"{method} failed"

    def test_invalid_method(self):
        with pytest.raises(ValueError):
            compute_amortization(AmortizationInput(
                principal=Decimal("1000"), annual_rate_pct=Decimal("5"),
                years=1, method="balloon",
            ))

    def test_zero_principal(self):
        with pytest.raises(ValueError):
            compute_amortization(AmortizationInput(
                principal=Decimal("0"), annual_rate_pct=Decimal("5"), years=1,
            ))

    def test_negative_rate(self):
        with pytest.raises(ValueError):
            compute_amortization(AmortizationInput(
                principal=Decimal("1000"), annual_rate_pct=Decimal("-1"), years=1,
            ))

    def test_bad_periods_per_year(self):
        with pytest.raises(ValueError):
            compute_amortization(AmortizationInput(
                principal=Decimal("1000"), annual_rate_pct=Decimal("5"),
                years=1, periods_per_year=3,
            ))


# ══════════════════════════════════════════════════════════════
# HTTP
# ══════════════════════════════════════════════════════════════


class TestRoutes:
    def test_cashflow_requires_auth(self, client):
        r = client.post("/cashflow/compute", json={})
        assert r.status_code == 401

    def test_cashflow_full_http(self, client, auth_header):
        r = client.post(
            "/cashflow/compute",
            json={
                "period_label": "2026-Q1",
                "net_income": "200000",
                "depreciation_amortization": "30000",
                "capex": "50000",
                "loan_proceeds": "100000",
                "beginning_cash": "100000",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["operating"]["subtotal"] == "230000.00"
        assert d["investing"]["subtotal"] == "-50000.00"
        assert d["financing"]["subtotal"] == "100000.00"
        assert d["ending_cash_computed"] == "380000.00"

    def test_amortization_requires_auth(self, client):
        r = client.post("/amortization/compute", json={})
        assert r.status_code == 401

    def test_amortization_http(self, client, auth_header):
        r = client.post(
            "/amortization/compute",
            json={
                "principal": "100000", "annual_rate_pct": "6",
                "years": 10, "periods_per_year": 12,
                "method": "fixed_payment",
            },
            headers=auth_header,
        )
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["total_periods"] == 120
        assert d["schedule"][-1]["closing_balance"] == "0.00"

    def test_amortization_bad_method(self, client, auth_header):
        r = client.post(
            "/amortization/compute",
            json={
                "principal": "1000", "annual_rate_pct": "5",
                "years": 1, "method": "macrs",
            },
            headers=auth_header,
        )
        assert r.status_code == 422
