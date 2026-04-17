"""Financial Statements tests (TB / IS / BS / Closing)."""

from decimal import Decimal

import pytest

from app.core.fin_statements_service import (
    TBLine, TBInput,
    build_trial_balance, build_income_statement, build_balance_sheet,
    generate_closing_entries,
)


def _sample_tb(opening_re: str = "0") -> TBInput:
    """A balanced TB covering all classifications."""
    return TBInput(
        entity_name="شركة تجريبية",
        period_label="Q1 2026",
        currency="SAR",
        opening_retained_earnings=Decimal(opening_re),
        lines=[
            # Assets (debit)
            TBLine("1100", "النقد", "asset", debit=Decimal("5000")),
            TBLine("1200", "الذمم المدينة", "asset", debit=Decimal("3000")),
            TBLine("1500", "الأصول الثابتة", "asset", debit=Decimal("10000")),
            TBLine("1510", "مجمع الإهلاك", "contra_asset", credit=Decimal("2000")),
            # Liabilities (credit)
            TBLine("2100", "الذمم الدائنة", "liability", credit=Decimal("2500")),
            TBLine("2500", "قروض", "liability", credit=Decimal("4000")),
            # Equity (credit)
            TBLine("3100", "رأس المال", "equity", credit=Decimal("5000")),
            # Revenue (credit)
            TBLine("4000", "المبيعات", "revenue", credit=Decimal("8000")),
            # Expense (debit)
            TBLine("5000", "المشتريات", "expense", debit=Decimal("3000")),
            TBLine("6100", "الرواتب", "expense", debit=Decimal("500")),
        ],
    )


class TestTrialBalance:
    def test_balanced(self):
        r = build_trial_balance(_sample_tb())
        assert r.is_balanced is True
        # Dr: 5000+3000+10000+3000+500 = 21500
        # Cr: 2000+2500+4000+5000+8000 = 21500
        assert r.total_debits == Decimal("21500.00")
        assert r.total_credits == Decimal("21500.00")
        assert r.difference == Decimal("0.00")

    def test_unbalanced_flagged(self):
        inp = TBInput(
            entity_name="x", period_label="p",
            lines=[
                TBLine("1", "a", "asset", debit=Decimal("100")),
                TBLine("2", "b", "liability", credit=Decimal("90")),  # off by 10
            ],
        )
        r = build_trial_balance(inp)
        assert r.is_balanced is False
        assert r.difference == Decimal("10.00")
        assert any("غير متوازن" in w for w in r.warnings)

    def test_invalid_classification_rejected(self):
        with pytest.raises(ValueError, match="classification"):
            build_trial_balance(TBInput(
                entity_name="x", period_label="p",
                lines=[TBLine("1", "a", "nonsense", debit=Decimal("10"))],
            ))

    def test_empty_rejected(self):
        with pytest.raises(ValueError, match="at least one"):
            build_trial_balance(TBInput(entity_name="x", period_label="p", lines=[]))

    def test_duplicate_code_rejected(self):
        with pytest.raises(ValueError, match="duplicate"):
            build_trial_balance(TBInput(
                entity_name="x", period_label="p",
                lines=[
                    TBLine("1", "a", "asset", debit=Decimal("1")),
                    TBLine("1", "b", "liability", credit=Decimal("1")),
                ],
            ))

    def test_negative_amounts_rejected(self):
        with pytest.raises(ValueError, match="cannot be negative"):
            build_trial_balance(TBInput(
                entity_name="x", period_label="p",
                lines=[
                    TBLine("1", "a", "asset", debit=Decimal("-1")),
                    TBLine("2", "b", "liability", credit=Decimal("1")),
                ],
            ))


class TestIncomeStatement:
    def test_basic(self):
        r = build_income_statement(_sample_tb())
        assert r.total_revenue == Decimal("8000.00")
        assert r.total_expenses == Decimal("3500.00")
        assert r.net_income == Decimal("4500.00")
        # margin = 4500 / 8000 × 100 = 56.25
        assert r.margin_pct == Decimal("56.25")
        assert len(r.revenue_lines) == 1
        assert len(r.expense_lines) == 2

    def test_no_revenue_zero_margin(self):
        inp = TBInput(
            entity_name="x", period_label="p",
            lines=[
                TBLine("5000", "exp", "expense", debit=Decimal("100")),
                TBLine("3100", "cap", "equity", credit=Decimal("100")),
            ],
        )
        r = build_income_statement(inp)
        assert r.total_revenue == Decimal("0.00")
        assert r.net_income == Decimal("-100.00")
        assert r.margin_pct == Decimal("0")


class TestBalanceSheet:
    def test_balanced_with_ni(self):
        r = build_balance_sheet(_sample_tb(opening_re="0"))
        # Assets: 5000 + 3000 + 10000 - 2000 = 16000
        assert r.total_assets == Decimal("16000.00")
        # Liab: 2500 + 4000 = 6500
        assert r.total_liabilities == Decimal("6500.00")
        # Equity: 5000 + RE_end (0 + NI 4500) = 9500
        assert r.total_equity == Decimal("9500.00")
        # Check the accounting identity
        assert r.total_assets == r.total_liabilities + r.total_equity
        assert r.is_balanced is True
        assert r.retained_earnings_end == Decimal("4500.00")

    def test_balanced_with_opening_re(self):
        r = build_balance_sheet(_sample_tb(opening_re="1000"))
        # If opening RE was 1000, but our TB doesn't include it as a line,
        # the equity total will still show RE_end = 1000 + 4500 = 5500
        assert r.retained_earnings_end == Decimal("5500.00")
        # And the BS will become unbalanced (because 1000 opening RE
        # is not recorded in the TB) — this tests that the service flags it
        assert r.is_balanced is False
        assert r.difference != Decimal("0")

    def test_ni_line_appears(self):
        r = build_balance_sheet(_sample_tb())
        codes = {e.account_code for e in r.equity}
        assert "RE-END" in codes


class TestClosingEntries:
    def test_net_income_closing(self):
        r = generate_closing_entries(_sample_tb())
        assert r.total_revenue_closed == Decimal("8000.00")
        assert r.total_expense_closed == Decimal("3500.00")
        assert r.net_income == Decimal("4500.00")
        # Revenue closing: Dr Sales 8000, Cr Income Summary 8000
        assert len(r.close_revenue_entry) == 2
        assert r.close_revenue_entry[0].debit == Decimal("8000.00")
        # Income summary to RE: Dr IS 4500, Cr RE 4500
        assert len(r.close_income_summary) == 2
        assert r.close_income_summary[0].debit == Decimal("4500.00")
        assert r.close_income_summary[1].credit == Decimal("4500.00")

    def test_net_loss_closing(self):
        # Reverse: high expenses, low revenue
        inp = TBInput(
            entity_name="x", period_label="p",
            lines=[
                TBLine("4000", "rev", "revenue", credit=Decimal("1000")),
                TBLine("5000", "exp", "expense", debit=Decimal("1500")),
                TBLine("3100", "cap", "equity", credit=Decimal("500")),
                TBLine("1100", "cash", "asset", debit=Decimal("0")),
            ],
        )
        r = generate_closing_entries(inp)
        assert r.net_income == Decimal("-500.00")
        # Loss → Dr RE, Cr IS
        assert r.close_income_summary[0].account_code == "3200"
        assert r.close_income_summary[0].debit == Decimal("500.00")

    def test_opening_re_rolled_forward(self):
        r = generate_closing_entries(_sample_tb(opening_re="1000"))
        assert r.retained_earnings_end == Decimal("5500.00")


class TestRoutes:
    def test_tb_requires_auth(self, client):
        r = client.post("/fs/trial-balance", json={})
        assert r.status_code == 401

    def _payload(self, opening_re: str = "0") -> dict:
        return {
            "entity_name": "Co",
            "period_label": "Q1 2026",
            "currency": "SAR",
            "opening_retained_earnings": opening_re,
            "lines": [
                {"account_code": "1100", "account_name": "Cash",
                 "classification": "asset", "debit": "5000"},
                {"account_code": "3100", "account_name": "Capital",
                 "classification": "equity", "credit": "2000"},
                {"account_code": "4000", "account_name": "Sales",
                 "classification": "revenue", "credit": "8000"},
                {"account_code": "5000", "account_name": "Purchases",
                 "classification": "expense", "debit": "5000"},
            ],
        }

    def test_tb_http(self, client, auth_header):
        r = client.post("/fs/trial-balance", json=self._payload(), headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["is_balanced"] is True
        assert d["total_debits"] == "10000.00"

    def test_is_http(self, client, auth_header):
        r = client.post("/fs/income-statement", json=self._payload(), headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["net_income"] == "3000.00"

    def test_bs_http(self, client, auth_header):
        r = client.post("/fs/balance-sheet", json=self._payload(), headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        # Assets 5000 vs Equity 2000 + RE_end 3000 = 5000 — balanced
        assert d["is_balanced"] is True

    def test_closing_http(self, client, auth_header):
        r = client.post("/fs/closing-entries", json=self._payload(), headers=auth_header)
        assert r.status_code == 200
        d = r.json()["data"]
        assert d["net_income"] == "3000.00"

    def test_classifications_endpoint(self, client, auth_header):
        r = client.get("/fs/classifications", headers=auth_header)
        assert r.status_code == 200
        lst = r.json()["data"]
        assert "asset" in lst
        assert "revenue" in lst
        assert "contra_asset" in lst

    def test_invalid_class_rejected_http(self, client, auth_header):
        payload = self._payload()
        payload["lines"][0]["classification"] = "garbage"
        r = client.post("/fs/trial-balance", json=payload, headers=auth_header)
        assert r.status_code == 422

    def test_empty_lines_rejected_http(self, client, auth_header):
        payload = self._payload()
        payload["lines"] = []
        r = client.post("/fs/trial-balance", json=payload, headers=auth_header)
        # Pydantic rejects at 422 level due to min_length=1
        assert r.status_code == 422
