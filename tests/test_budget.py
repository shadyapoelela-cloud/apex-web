"""Tests for Budget vs Actual service."""

import pytest
from decimal import Decimal
from app.core.budget_service import (
    BudgetLineItem, BudgetInput, analyse_budget, to_dict, _q,
)


def _item(code, name, cat, budget, actual, prior=None, notes=""):
    return BudgetLineItem(
        account_code=code, account_name=name, category=cat,
        budget_amount=Decimal(str(budget)),
        actual_amount=Decimal(str(actual)),
        prior_year_amount=Decimal(str(prior)) if prior is not None else None,
        notes=notes,
    )


def _inp(items, period="2026-Q1", period_type="quarterly"):
    return BudgetInput(
        entity_name="APEX KSA", period=period, period_type=period_type,
        line_items=items,
    )


class TestBudgetBasic:
    def test_single_revenue_on_target(self):
        items = [_item("4000", "إيرادات مبيعات", "revenue", 1000000, 1000000)]
        r = analyse_budget(_inp(items))
        assert r.overall_status == "on_target"
        assert r.total_variance == Decimal("0.00")

    def test_single_revenue_favorable(self):
        items = [_item("4000", "إيرادات", "revenue", 1000000, 1200000)]
        r = analyse_budget(_inp(items))
        assert r.overall_status == "favorable"
        assert r.net_income_variance == Decimal("200000.00")

    def test_single_expense_over_budget(self):
        items = [_item("5100", "رواتب", "opex", 500000, 600000)]
        r = analyse_budget(_inp(items))
        assert r.overall_status == "unfavorable"
        assert r.items_over_budget == 1

    def test_empty_items_raises(self):
        with pytest.raises(ValueError, match="line_items is required"):
            analyse_budget(_inp([]))

    def test_invalid_period_type(self):
        with pytest.raises(ValueError, match="period_type"):
            analyse_budget(BudgetInput(
                entity_name="X", period="2026", period_type="biweekly",
                line_items=[_item("4000", "Rev", "revenue", 100, 100)],
            ))


class TestVarianceAnalysis:
    def test_revenue_above_favorable(self):
        items = [_item("4000", "مبيعات", "revenue", 5000000, 5500000)]
        r = analyse_budget(_inp(items))
        d = r.line_details[0]
        assert d.variance_type == "favorable"
        assert d.variance_amount == Decimal("500000.00")
        assert d.variance_pct == Decimal("10.00")

    def test_expense_below_favorable(self):
        items = [_item("5200", "إيجار", "opex", 200000, 180000)]
        r = analyse_budget(_inp(items))
        d = r.line_details[0]
        assert d.variance_type == "favorable"
        assert d.variance_amount == Decimal("-20000.00")

    def test_expense_above_unfavorable(self):
        items = [_item("5100", "رواتب", "opex", 300000, 400000)]
        r = analyse_budget(_inp(items))
        d = r.line_details[0]
        assert d.variance_type == "unfavorable"
        assert d.variance_amount == Decimal("100000.00")

    def test_revenue_below_unfavorable(self):
        items = [_item("4000", "إيرادات", "revenue", 2000000, 1500000)]
        r = analyse_budget(_inp(items))
        d = r.line_details[0]
        assert d.variance_type == "unfavorable"

    def test_yoy_comparison(self):
        items = [_item("4000", "مبيعات", "revenue", 1000000, 1100000, prior=900000)]
        r = analyse_budget(_inp(items))
        d = r.line_details[0]
        assert d.prior_year == Decimal("900000.00")
        assert d.yoy_change == Decimal("200000.00")


class TestMateriality:
    def test_low_materiality(self):
        items = [_item("5300", "قرطاسية", "opex", 50000, 52000)]  # 4% variance
        r = analyse_budget(_inp(items))
        assert r.line_details[0].materiality == "low"

    def test_medium_materiality(self):
        items = [_item("5100", "رواتب", "opex", 1000000, 1120000)]
        r = analyse_budget(_inp(items))
        assert r.line_details[0].materiality == "medium"

    def test_critical_materiality_by_amount(self):
        items = [_item("5100", "مشتريات", "cogs", 5000000, 6500000)]
        r = analyse_budget(_inp(items))
        assert r.line_details[0].materiality == "critical"
        assert r.critical_variances == 1

    def test_high_materiality_by_pct(self):
        items = [_item("5900", "استشارات", "opex", 200000, 235000)]  # 17.5%
        r = analyse_budget(_inp(items))
        assert r.line_details[0].materiality == "high"


class TestCategorySummary:
    def test_multi_category(self):
        items = [
            _item("4000", "مبيعات", "revenue", 10000000, 11000000),
            _item("5000", "تكلفة بضاعة", "cogs", 6000000, 5800000),
            _item("5100", "رواتب", "opex", 2000000, 2100000),
            _item("5200", "إيجار", "opex", 500000, 490000),
            _item("6000", "أصول ثابتة", "capex", 1000000, 800000),
        ]
        r = analyse_budget(_inp(items))
        cats = {c.category: c for c in r.category_summaries}
        assert "revenue" in cats
        assert "cogs" in cats
        assert "opex" in cats
        assert "capex" in cats
        assert cats["opex"].line_count == 2
        assert r.revenue_budget == Decimal("10000000.00")
        assert r.revenue_actual == Decimal("11000000.00")


class TestKPIs:
    def test_utilization_over_100(self):
        items = [
            _item("4000", "إيرادات", "revenue", 5000000, 5000000),
            _item("5100", "رواتب", "opex", 2000000, 2400000),
        ]
        r = analyse_budget(_inp(items))
        assert r.budget_utilization_pct == Decimal("120.00")
        assert len(r.warnings) >= 1  # over budget warning

    def test_utilization_under_50(self):
        items = [
            _item("4000", "إيرادات", "revenue", 1000000, 1000000),
            _item("5100", "رواتب", "opex", 2000000, 800000),
        ]
        r = analyse_budget(_inp(items))
        assert r.budget_utilization_pct == Decimal("40.00")

    def test_net_income_computation(self):
        items = [
            _item("4000", "إيرادات", "revenue", 10000000, 10500000),
            _item("5000", "تكلفة", "cogs", 6000000, 5900000),
            _item("5100", "مصروفات", "opex", 2000000, 2100000),
        ]
        r = analyse_budget(_inp(items))
        assert r.net_income_budget == Decimal("2000000.00")  # 10M - 8M
        assert r.net_income_actual == Decimal("2500000.00")  # 10.5M - 8M
        assert r.net_income_variance == Decimal("500000.00")


class TestToDict:
    def test_dict_structure(self):
        items = [
            _item("4000", "مبيعات", "revenue", 5000000, 5200000, prior=4800000),
            _item("5100", "رواتب", "opex", 2000000, 2050000),
        ]
        r = analyse_budget(_inp(items))
        d = to_dict(r)
        assert d["entity_name"] == "APEX KSA"
        assert d["period"] == "2026-Q1"
        assert "revenue" in d
        assert "expenses" in d
        assert "net_income" in d
        assert "kpis" in d
        assert len(d["line_details"]) == 2
        assert len(d["category_summaries"]) == 2
        assert d["kpis"]["items_over_budget"] >= 0

    def test_dict_decimal_strings(self):
        items = [_item("4000", "إيرادات", "revenue", 1000000, 1100000)]
        d = to_dict(analyse_budget(_inp(items)))
        assert isinstance(d["total_budget"], str)
        assert "." in d["total_budget"]
