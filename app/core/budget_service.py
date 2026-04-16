"""
APEX Platform — Budget vs Actual Variance Analysis
═══════════════════════════════════════════════════════════════
Compares budgeted amounts to actuals at line-item level and
reports variances with sign conventions that match management
accounting:

  Revenue  — favourable if actual > budget  (positive variance = good)
  Expense  — favourable if actual < budget  (negative variance = good)

Each line has a `kind` field ("revenue" / "expense") that drives
the favourability logic. Totals are computed per kind and for
net income (revenue − expense).

Variance % = (actual − budget) / |budget|  × 100
If |budget| is zero, the % is reported as None + warning.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")


def _q(value: Decimal | int | float | str) -> Decimal:
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class BudgetLineInput:
    name: str
    kind: str            # "revenue" | "expense"
    budget: Decimal
    actual: Decimal


@dataclass
class BudgetInput:
    period_label: str = "FY"
    lines: List[BudgetLineInput] = field(default_factory=list)


@dataclass
class BudgetLine:
    name: str
    kind: str
    budget: Decimal
    actual: Decimal
    variance_amount: Decimal             # actual − budget
    variance_pct: Optional[Decimal]      # % relative to |budget|
    favourable: bool                     # direction-aware
    severity: str                        # 'ok' | 'watch' | 'risk'


@dataclass
class BudgetResult:
    period_label: str
    # Totals
    total_revenue_budget: Decimal
    total_revenue_actual: Decimal
    total_revenue_variance: Decimal
    total_expense_budget: Decimal
    total_expense_actual: Decimal
    total_expense_variance: Decimal
    net_budget: Decimal
    net_actual: Decimal
    net_variance: Decimal
    net_variance_pct: Optional[Decimal]
    lines: List[BudgetLine] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


_VALID_KINDS = ("revenue", "expense")


def _severity(pct: Optional[Decimal], favourable: bool) -> str:
    """Severity is based on absolute variance %. Favourable always 'ok'
    regardless of magnitude; unfavourable escalates with size."""
    if favourable or pct is None:
        return "ok"
    p = abs(pct)
    if p <= Decimal("5"):
        return "watch"   # small miss
    if p <= Decimal("15"):
        return "watch"
    return "risk"


def compute_budget(inp: BudgetInput) -> BudgetResult:
    warnings: list[str] = []
    lines: List[BudgetLine] = []

    if not inp.lines:
        raise ValueError("At least one budget line is required")

    rev_b = rev_a = Decimal("0")
    exp_b = exp_a = Decimal("0")

    for ln in inp.lines:
        kind = (ln.kind or "").lower()
        if kind not in _VALID_KINDS:
            raise ValueError(
                f"Line {ln.name!r}: invalid kind {ln.kind!r}, "
                f"expected one of {_VALID_KINDS}"
            )
        budget = _q(ln.budget)
        actual = _q(ln.actual)
        variance = _q(actual - budget)

        # Pct relative to |budget|
        pct: Optional[Decimal] = None
        if budget != 0:
            pct = (variance / abs(budget) * Decimal("100")).quantize(
                _TWO, rounding=ROUND_HALF_UP
            )
        else:
            warnings.append(f"بند {ln.name!r}: الميزانية صفر — لا يمكن حساب نسبة الانحراف.")

        # Favourability
        if kind == "revenue":
            favourable = variance >= 0
        else:
            favourable = variance <= 0

        severity = _severity(pct, favourable)

        lines.append(BudgetLine(
            name=ln.name, kind=kind,
            budget=budget, actual=actual,
            variance_amount=variance,
            variance_pct=pct,
            favourable=favourable,
            severity=severity,
        ))

        if kind == "revenue":
            rev_b += budget
            rev_a += actual
        else:
            exp_b += budget
            exp_a += actual

    net_b = _q(rev_b - exp_b)
    net_a = _q(rev_a - exp_a)
    net_v = _q(net_a - net_b)
    net_pct = None
    if net_b != 0:
        net_pct = (net_v / abs(net_b) * Decimal("100")).quantize(
            _TWO, rounding=ROUND_HALF_UP
        )

    # Global warnings
    risk_lines = [ln for ln in lines if ln.severity == "risk"]
    if risk_lines:
        warnings.append(
            f"{len(risk_lines)} بند تجاوز نسبة الانحراف المقبولة (>15%)."
        )

    return BudgetResult(
        period_label=inp.period_label,
        total_revenue_budget=_q(rev_b),
        total_revenue_actual=_q(rev_a),
        total_revenue_variance=_q(rev_a - rev_b),
        total_expense_budget=_q(exp_b),
        total_expense_actual=_q(exp_a),
        total_expense_variance=_q(exp_a - exp_b),
        net_budget=net_b,
        net_actual=net_a,
        net_variance=net_v,
        net_variance_pct=net_pct,
        lines=lines,
        warnings=warnings,
    )


def result_to_dict(r: BudgetResult) -> dict:
    def _s(v):
        return None if v is None else f"{v}"
    return {
        "period_label": r.period_label,
        "totals": {
            "revenue_budget": f"{r.total_revenue_budget}",
            "revenue_actual": f"{r.total_revenue_actual}",
            "revenue_variance": f"{r.total_revenue_variance}",
            "expense_budget": f"{r.total_expense_budget}",
            "expense_actual": f"{r.total_expense_actual}",
            "expense_variance": f"{r.total_expense_variance}",
            "net_budget": f"{r.net_budget}",
            "net_actual": f"{r.net_actual}",
            "net_variance": f"{r.net_variance}",
            "net_variance_pct": _s(r.net_variance_pct),
        },
        "lines": [
            {
                "name": ln.name,
                "kind": ln.kind,
                "budget": f"{ln.budget}",
                "actual": f"{ln.actual}",
                "variance_amount": f"{ln.variance_amount}",
                "variance_pct": _s(ln.variance_pct),
                "favourable": ln.favourable,
                "severity": ln.severity,
            }
            for ln in r.lines
        ],
        "warnings": r.warnings,
    }
