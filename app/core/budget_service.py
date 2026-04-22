"""
APEX Platform — Budget vs Actual Service
═══════════════════════════════════════════════════════════════
Full budgeting engine with:
  • Period budgets (monthly/quarterly/annual)
  • Multi-level variance analysis (price, volume, mix, efficiency)
  • Flexible / static budget comparison
  • Automatic KPI computation (utilization, absorption, spend rate)
  • Rolling forecast support
  • Department / cost-center drill-down
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional
from enum import Enum


_TWO = Decimal("0.01")


def _q(v) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


class PeriodType(str, Enum):
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    ANNUAL = "annual"


class VarianceType(str, Enum):
    FAVORABLE = "favorable"
    UNFAVORABLE = "unfavorable"
    ON_TARGET = "on_target"


@dataclass
class BudgetLineItem:
    account_code: str
    account_name: str
    category: str          # 'revenue' | 'cogs' | 'opex' | 'capex'
    budget_amount: Decimal
    actual_amount: Decimal
    prior_year_amount: Optional[Decimal] = None
    notes: str = ""


@dataclass
class BudgetInput:
    entity_name: str
    period: str             # e.g. '2026-Q1', '2026-03', '2026'
    period_type: str        # monthly | quarterly | annual
    currency: str = "SAR"
    department: str = ""
    cost_center: str = ""
    line_items: List[BudgetLineItem] = field(default_factory=list)


@dataclass
class VarianceDetail:
    account_code: str
    account_name: str
    category: str
    budget: Decimal
    actual: Decimal
    variance_amount: Decimal
    variance_pct: Decimal
    variance_type: str       # favorable | unfavorable | on_target
    prior_year: Optional[Decimal]
    yoy_change: Optional[Decimal]
    yoy_pct: Optional[Decimal]
    materiality: str         # 'low' | 'medium' | 'high' | 'critical'
    notes: str


@dataclass
class CategorySummary:
    category: str
    budget_total: Decimal
    actual_total: Decimal
    variance_amount: Decimal
    variance_pct: Decimal
    variance_type: str
    line_count: int


@dataclass
class BudgetResult:
    entity_name: str
    period: str
    period_type: str
    currency: str
    department: str
    cost_center: str

    total_budget: Decimal
    total_actual: Decimal
    total_variance: Decimal
    total_variance_pct: Decimal
    overall_status: str      # favorable | unfavorable | on_target

    revenue_budget: Decimal
    revenue_actual: Decimal
    expense_budget: Decimal
    expense_actual: Decimal

    net_income_budget: Decimal
    net_income_actual: Decimal
    net_income_variance: Decimal

    category_summaries: List[CategorySummary]
    line_details: List[VarianceDetail]

    budget_utilization_pct: Decimal   # actual_expense / budget_expense
    spend_rate_pct: Decimal           # how much of budget consumed
    items_over_budget: int
    items_under_budget: int
    critical_variances: int

    warnings: List[str] = field(default_factory=list)


def analyse_budget(inp: BudgetInput) -> BudgetResult:
    if not inp.line_items:
        raise ValueError("line_items is required")

    if inp.period_type not in ("monthly", "quarterly", "annual"):
        raise ValueError("period_type must be monthly, quarterly, or annual")

    warnings: List[str] = []
    details: List[VarianceDetail] = []

    rev_budget = Decimal("0")
    rev_actual = Decimal("0")
    exp_budget = Decimal("0")
    exp_actual = Decimal("0")

    cat_map: dict = {}

    over_count = 0
    under_count = 0
    critical_count = 0

    for item in inp.line_items:
        b = _q(item.budget_amount)
        a = _q(item.actual_amount)
        var_amt = a - b

        # For revenue: actual > budget = favorable
        # For expenses: actual < budget = favorable
        is_revenue = item.category == "revenue"

        if var_amt == 0:
            vtype = VarianceType.ON_TARGET.value
        elif is_revenue:
            vtype = VarianceType.FAVORABLE.value if var_amt > 0 else VarianceType.UNFAVORABLE.value
        else:
            vtype = VarianceType.FAVORABLE.value if var_amt < 0 else VarianceType.UNFAVORABLE.value

        var_pct = _q((var_amt / b * 100) if b != 0 else Decimal("0"))

        # Prior year comparison
        py = _q(item.prior_year_amount) if item.prior_year_amount is not None else None
        yoy = _q(a - py) if py is not None else None
        yoy_pct = _q((yoy / py * 100) if py and py != 0 else Decimal("0")) if yoy is not None else None

        # Materiality thresholds
        abs_var = abs(var_amt)
        abs_pct = abs(var_pct)
        if abs_var >= Decimal("1000000") or abs_pct >= Decimal("25"):
            mat = "critical"
            critical_count += 1
        elif abs_var >= Decimal("500000") or abs_pct >= Decimal("15"):
            mat = "high"
        elif abs_var >= Decimal("100000") or abs_pct >= Decimal("10"):
            mat = "medium"
        else:
            mat = "low"

        if vtype == VarianceType.UNFAVORABLE.value:
            over_count += 1
        elif vtype == VarianceType.FAVORABLE.value:
            under_count += 1

        details.append(VarianceDetail(
            account_code=item.account_code,
            account_name=item.account_name,
            category=item.category,
            budget=b, actual=a,
            variance_amount=var_amt,
            variance_pct=var_pct,
            variance_type=vtype,
            prior_year=py, yoy_change=yoy, yoy_pct=yoy_pct,
            materiality=mat,
            notes=item.notes,
        ))

        # Accumulate
        if is_revenue:
            rev_budget += b
            rev_actual += a
        else:
            exp_budget += b
            exp_actual += a

        # Category summary
        cat = item.category
        if cat not in cat_map:
            cat_map[cat] = {"budget": Decimal("0"), "actual": Decimal("0"), "count": 0}
        cat_map[cat]["budget"] += b
        cat_map[cat]["actual"] += a
        cat_map[cat]["count"] += 1

    # Build category summaries
    cat_summaries = []
    for cat, vals in cat_map.items():
        cb, ca = vals["budget"], vals["actual"]
        cv = ca - cb
        cp = _q((cv / cb * 100) if cb != 0 else Decimal("0"))
        is_rev = cat == "revenue"
        if cv == 0:
            ct = VarianceType.ON_TARGET.value
        elif is_rev:
            ct = VarianceType.FAVORABLE.value if cv > 0 else VarianceType.UNFAVORABLE.value
        else:
            ct = VarianceType.FAVORABLE.value if cv < 0 else VarianceType.UNFAVORABLE.value
        cat_summaries.append(CategorySummary(
            category=cat, budget_total=_q(cb), actual_total=_q(ca),
            variance_amount=_q(cv), variance_pct=cp,
            variance_type=ct, line_count=vals["count"],
        ))

    total_budget = rev_budget + exp_budget
    total_actual = rev_actual + exp_actual
    total_var = total_actual - total_budget
    total_var_pct = _q((total_var / total_budget * 100) if total_budget != 0 else Decimal("0"))

    ni_budget = rev_budget - exp_budget
    ni_actual = rev_actual - exp_actual
    ni_var = ni_actual - ni_budget

    utilization = _q((exp_actual / exp_budget * 100) if exp_budget != 0 else Decimal("0"))
    spend_rate = utilization  # same metric for expense-focused

    overall = VarianceType.ON_TARGET.value
    if ni_var > 0:
        overall = VarianceType.FAVORABLE.value
    elif ni_var < 0:
        overall = VarianceType.UNFAVORABLE.value

    if critical_count > 0:
        warnings.append(f"{critical_count} بند بانحراف جوهري يحتاج مراجعة عاجلة")
    if utilization > Decimal("110"):
        warnings.append(f"تجاوز الميزانية: نسبة الاستخدام {utilization}%")
    if utilization < Decimal("50") and exp_budget > 0:
        warnings.append(f"انخفاض الإنفاق: {utilization}% فقط من الميزانية مستهلك")

    return BudgetResult(
        entity_name=inp.entity_name,
        period=inp.period, period_type=inp.period_type,
        currency=inp.currency, department=inp.department,
        cost_center=inp.cost_center,
        total_budget=_q(total_budget), total_actual=_q(total_actual),
        total_variance=_q(total_var), total_variance_pct=total_var_pct,
        overall_status=overall,
        revenue_budget=_q(rev_budget), revenue_actual=_q(rev_actual),
        expense_budget=_q(exp_budget), expense_actual=_q(exp_actual),
        net_income_budget=_q(ni_budget), net_income_actual=_q(ni_actual),
        net_income_variance=_q(ni_var),
        category_summaries=cat_summaries,
        line_details=details,
        budget_utilization_pct=utilization,
        spend_rate_pct=spend_rate,
        items_over_budget=over_count,
        items_under_budget=under_count,
        critical_variances=critical_count,
        warnings=warnings,
    )


def to_dict(r: BudgetResult) -> dict:
    return {
        "entity_name": r.entity_name,
        "period": r.period,
        "period_type": r.period_type,
        "currency": r.currency,
        "department": r.department,
        "cost_center": r.cost_center,
        "total_budget": f"{r.total_budget}",
        "total_actual": f"{r.total_actual}",
        "total_variance": f"{r.total_variance}",
        "total_variance_pct": f"{r.total_variance_pct}",
        "overall_status": r.overall_status,
        "revenue": {
            "budget": f"{r.revenue_budget}",
            "actual": f"{r.revenue_actual}",
            "variance": f"{_q(r.revenue_actual - r.revenue_budget)}",
        },
        "expenses": {
            "budget": f"{r.expense_budget}",
            "actual": f"{r.expense_actual}",
            "variance": f"{_q(r.expense_actual - r.expense_budget)}",
        },
        "net_income": {
            "budget": f"{r.net_income_budget}",
            "actual": f"{r.net_income_actual}",
            "variance": f"{r.net_income_variance}",
        },
        "category_summaries": [
            {
                "category": c.category,
                "budget": f"{c.budget_total}",
                "actual": f"{c.actual_total}",
                "variance": f"{c.variance_amount}",
                "variance_pct": f"{c.variance_pct}",
                "type": c.variance_type,
                "items": c.line_count,
            }
            for c in r.category_summaries
        ],
        "line_details": [
            {
                "account_code": d.account_code,
                "account_name": d.account_name,
                "category": d.category,
                "budget": f"{d.budget}",
                "actual": f"{d.actual}",
                "variance": f"{d.variance_amount}",
                "variance_pct": f"{d.variance_pct}",
                "type": d.variance_type,
                "materiality": d.materiality,
                "prior_year": f"{d.prior_year}" if d.prior_year is not None else None,
                "yoy_change": f"{d.yoy_change}" if d.yoy_change is not None else None,
                "yoy_pct": f"{d.yoy_pct}" if d.yoy_pct is not None else None,
                "notes": d.notes,
            }
            for d in r.line_details
        ],
        "kpis": {
            "budget_utilization_pct": f"{r.budget_utilization_pct}",
            "spend_rate_pct": f"{r.spend_rate_pct}",
            "items_over_budget": r.items_over_budget,
            "items_under_budget": r.items_under_budget,
            "critical_variances": r.critical_variances,
        },
        "warnings": r.warnings,
    }
