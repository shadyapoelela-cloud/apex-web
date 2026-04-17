"""
APEX Platform — Project / Job Costing
═══════════════════════════════════════════════════════════════
Tracks costs accumulated against a specific project/job and
compares to budget. Produces:
  • Cost breakdown by category (labour / material / overhead / subcontract)
  • Actual vs budget variance per category
  • Percent complete (cost-to-cost method)
  • Estimated cost to complete (EAC)
  • Projected profit/loss on contract
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


COST_CATEGORIES = {"labour", "material", "overhead", "subcontract", "other"}


@dataclass
class CostEntry:
    category: str                              # one of COST_CATEGORIES
    description: str
    budgeted: Decimal
    actual: Decimal = Decimal("0")


@dataclass
class JobInput:
    project_name: str
    project_code: str
    contract_value: Decimal                    # total revenue
    contract_start_date: str
    estimated_end_date: str
    costs: List[CostEntry] = field(default_factory=list)
    additional_eac: Decimal = Decimal("0")     # extra costs expected beyond current actual
    currency: str = "SAR"


@dataclass
class CostCategoryResult:
    category: str
    description: str
    budgeted: Decimal
    actual: Decimal
    variance: Decimal                          # budget - actual
    variance_pct: Decimal


@dataclass
class JobResult:
    project_name: str
    project_code: str
    contract_value: Decimal
    total_budgeted: Decimal
    total_actual: Decimal
    total_variance: Decimal
    budgeted_profit: Decimal                   # contract - budget
    current_profit_if_finished: Decimal         # contract - actual
    estimated_at_completion_cost: Decimal        # actual + additional EAC
    estimated_profit_at_completion: Decimal
    percent_complete_cost_basis: Decimal
    categories: List[CostCategoryResult]
    status: str                                 # 'on_budget' | 'over_budget' | 'under_budget'
    currency: str
    warnings: list[str] = field(default_factory=list)


def analyse_job(inp: JobInput) -> JobResult:
    if not inp.costs:
        raise ValueError("costs is required")
    if Decimal(str(inp.contract_value)) < 0:
        raise ValueError("contract_value cannot be negative")

    warnings: list[str] = []
    contract = Decimal(str(inp.contract_value))
    total_budget = Decimal("0")
    total_actual = Decimal("0")
    categories: List[CostCategoryResult] = []

    for i, c in enumerate(inp.costs, start=1):
        if c.category not in COST_CATEGORIES:
            raise ValueError(
                f"cost {i}: category must be one of {sorted(COST_CATEGORIES)}"
            )
        b = Decimal(str(c.budgeted))
        a = Decimal(str(c.actual))
        if b < 0 or a < 0:
            raise ValueError(f"cost {i}: amounts cannot be negative")
        var = b - a
        var_pct = Decimal("0") if b == 0 else (var / b * Decimal("100"))
        categories.append(CostCategoryResult(
            category=c.category,
            description=c.description,
            budgeted=_q(b),
            actual=_q(a),
            variance=_q(var),
            variance_pct=_q(var_pct),
        ))
        total_budget += b
        total_actual += a

    total_variance = total_budget - total_actual

    budgeted_profit = contract - total_budget
    current_profit = contract - total_actual

    # % complete = actual / (actual + EAC remaining)
    eac_add = Decimal(str(inp.additional_eac))
    eac = total_actual + eac_add
    pct_complete = Decimal("0") if eac == 0 else (total_actual / eac * Decimal("100"))
    est_profit_at_completion = contract - eac

    if total_actual > total_budget:
        status = "over_budget"
        warnings.append(
            f"تجاوز في التكلفة: {_q(total_actual - total_budget)} {inp.currency} — "
            "راجع الرقابة على المشروع."
        )
    elif total_actual < total_budget * Decimal("0.9"):
        status = "under_budget"
    else:
        status = "on_budget"

    if est_profit_at_completion < 0:
        warnings.append(
            f"خسارة متوقعة عند الإنجاز: {_q(-est_profit_at_completion)} — "
            "يجب إثبات المخصص وفق IAS 37.66."
        )

    return JobResult(
        project_name=inp.project_name,
        project_code=inp.project_code,
        contract_value=_q(contract),
        total_budgeted=_q(total_budget),
        total_actual=_q(total_actual),
        total_variance=_q(total_variance),
        budgeted_profit=_q(budgeted_profit),
        current_profit_if_finished=_q(current_profit),
        estimated_at_completion_cost=_q(eac),
        estimated_profit_at_completion=_q(est_profit_at_completion),
        percent_complete_cost_basis=_q(pct_complete),
        categories=categories,
        status=status,
        currency=inp.currency,
        warnings=warnings,
    )


def to_dict(r: JobResult) -> dict:
    return {
        "project_name": r.project_name,
        "project_code": r.project_code,
        "contract_value": f"{r.contract_value}",
        "total_budgeted": f"{r.total_budgeted}",
        "total_actual": f"{r.total_actual}",
        "total_variance": f"{r.total_variance}",
        "budgeted_profit": f"{r.budgeted_profit}",
        "current_profit_if_finished": f"{r.current_profit_if_finished}",
        "estimated_at_completion_cost": f"{r.estimated_at_completion_cost}",
        "estimated_profit_at_completion": f"{r.estimated_profit_at_completion}",
        "percent_complete_cost_basis": f"{r.percent_complete_cost_basis}",
        "categories": [
            {
                "category": c.category,
                "description": c.description,
                "budgeted": f"{c.budgeted}",
                "actual": f"{c.actual}",
                "variance": f"{c.variance}",
                "variance_pct": f"{c.variance_pct}",
            }
            for c in r.categories
        ],
        "status": r.status,
        "currency": r.currency,
        "warnings": r.warnings,
    }
