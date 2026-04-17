"""Startup / SaaS metrics — Burn, Runway, MRR/ARR, CAC/LTV, Rule of 40.

For founders who want a 'Startup CFO View' without building custom reports.
Source inspirations: Puzzle.io, Digits, Brex Insights.
"""

from app.features.startup_metrics.calculators import (  # noqa: F401
    ArrResult,
    BurnResult,
    CohortResult,
    LtvCacResult,
    MrrResult,
    RuleOf40Result,
    RunwayResult,
    arr_from_mrr,
    compute_burn,
    compute_ltv_cac,
    compute_mrr,
    compute_rule_of_40,
    compute_runway,
)

__all__ = [
    "ArrResult",
    "BurnResult",
    "CohortResult",
    "LtvCacResult",
    "MrrResult",
    "RuleOf40Result",
    "RunwayResult",
    "arr_from_mrr",
    "compute_burn",
    "compute_ltv_cac",
    "compute_mrr",
    "compute_rule_of_40",
    "compute_runway",
]
