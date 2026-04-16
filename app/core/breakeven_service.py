"""
APEX Platform — Break-Even Analysis
═══════════════════════════════════════════════════════════════
Computes the break-even point in units AND revenue, margin of
safety, and target-profit analysis.

Formulas:
  contribution_margin_per_unit  = price − variable_cost_per_unit
  contribution_margin_ratio     = contribution_margin_per_unit / price
  break_even_units              = fixed_costs / contribution_margin_per_unit
  break_even_revenue            = fixed_costs / contribution_margin_ratio
  target_units(target_profit)   = (fixed_costs + target_profit) / CM_per_unit

A partial-data calculation works too: if we only have contribution
margin in SAR (not per-unit), we can still return break-even revenue.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from math import ceil
from typing import Optional


_TWO = Decimal("0.01")


def _q(value: Optional[Decimal | int | float | str]) -> Decimal:
    if value is None:
        return Decimal("0")
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class BreakevenInput:
    fixed_costs: Decimal = Decimal("0")
    unit_price: Decimal = Decimal("0")
    variable_cost_per_unit: Decimal = Decimal("0")
    target_profit: Decimal = Decimal("0")
    # Optional: actual sales for margin-of-safety
    actual_units_sold: Optional[Decimal] = None
    period_label: str = "FY"


@dataclass
class BreakevenResult:
    period_label: str
    fixed_costs: Decimal
    unit_price: Decimal
    variable_cost_per_unit: Decimal
    contribution_margin_per_unit: Decimal
    contribution_margin_ratio_pct: Decimal   # e.g. 40.00 for 40%
    break_even_units: Optional[int]           # ceiling of units
    break_even_revenue: Optional[Decimal]
    target_profit: Decimal
    target_units: Optional[int]               # units needed to hit target
    target_revenue: Optional[Decimal]
    # Margin of safety (only if actual_units_sold given)
    margin_of_safety_units: Optional[int]
    margin_of_safety_pct: Optional[Decimal]
    warnings: list[str] = field(default_factory=list)


def compute_breakeven(inp: BreakevenInput) -> BreakevenResult:
    warnings: list[str] = []

    fc = _q(inp.fixed_costs)
    price = _q(inp.unit_price)
    vcu = _q(inp.variable_cost_per_unit)
    target = _q(inp.target_profit)

    if fc < 0:
        raise ValueError("fixed_costs cannot be negative")
    if price < 0 or vcu < 0:
        raise ValueError("prices cannot be negative")
    if price > 0 and vcu >= price:
        warnings.append(
            f"التكلفة المتغيرة ({vcu}) ≥ سعر البيع ({price}) — "
            f"الهامش سالب، لا يوجد نقطة تعادل."
        )

    cm_per_unit = _q(price - vcu)
    cm_ratio = Decimal("0")
    if price > 0:
        cm_ratio = (cm_per_unit / price)

    cm_ratio_pct = (cm_ratio * Decimal("100")).quantize(_TWO, rounding=ROUND_HALF_UP)

    # Break-even
    be_units: Optional[int] = None
    be_revenue: Optional[Decimal] = None
    if cm_per_unit > 0:
        raw_units = fc / cm_per_unit
        # Can't break even on a fraction of a unit; round up
        be_units = int(ceil(float(raw_units)))
        be_revenue = _q(Decimal(be_units) * price)
    elif price == 0 and vcu == 0:
        warnings.append("لا توجد أسعار — لا يمكن حساب نقطة التعادل.")

    # Target profit
    target_units: Optional[int] = None
    target_revenue: Optional[Decimal] = None
    if cm_per_unit > 0:
        raw_t = (fc + target) / cm_per_unit
        target_units = int(ceil(float(raw_t)))
        target_revenue = _q(Decimal(target_units) * price)

    # Margin of safety
    mos_units: Optional[int] = None
    mos_pct: Optional[Decimal] = None
    if inp.actual_units_sold is not None and be_units is not None:
        actual = _q(inp.actual_units_sold)
        mos_units = max(0, int(actual) - be_units)
        if actual > 0:
            mos_pct = ((actual - Decimal(be_units)) / actual * Decimal("100")).quantize(
                _TWO, rounding=ROUND_HALF_UP
            )

    return BreakevenResult(
        period_label=inp.period_label,
        fixed_costs=fc,
        unit_price=price,
        variable_cost_per_unit=vcu,
        contribution_margin_per_unit=cm_per_unit,
        contribution_margin_ratio_pct=cm_ratio_pct,
        break_even_units=be_units,
        break_even_revenue=be_revenue,
        target_profit=target,
        target_units=target_units,
        target_revenue=target_revenue,
        margin_of_safety_units=mos_units,
        margin_of_safety_pct=mos_pct,
        warnings=warnings,
    )


def result_to_dict(r: BreakevenResult) -> dict:
    def _s(v):
        return None if v is None else f"{v}"
    return {
        "period_label": r.period_label,
        "fixed_costs": f"{r.fixed_costs}",
        "unit_price": f"{r.unit_price}",
        "variable_cost_per_unit": f"{r.variable_cost_per_unit}",
        "contribution_margin_per_unit": f"{r.contribution_margin_per_unit}",
        "contribution_margin_ratio_pct": f"{r.contribution_margin_ratio_pct}",
        "break_even_units": r.break_even_units,
        "break_even_revenue": _s(r.break_even_revenue),
        "target_profit": f"{r.target_profit}",
        "target_units": r.target_units,
        "target_revenue": _s(r.target_revenue),
        "margin_of_safety_units": r.margin_of_safety_units,
        "margin_of_safety_pct": _s(r.margin_of_safety_pct),
        "warnings": r.warnings,
    }
