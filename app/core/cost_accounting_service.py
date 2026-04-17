"""
APEX Platform — Cost Accounting / Variance Analysis
═══════════════════════════════════════════════════════════════
Standard costing vs Actual — the core management-accounting tool
for manufacturing, retail-with-production, and service firms
with billable hours.

Variances computed (all positive = favourable, negative = unfavourable
from the enterprise's perspective):

  MATERIAL:
    • Price variance   = (std_price - actual_price) × actual_qty
    • Quantity variance = (std_qty - actual_qty) × std_price
    • Total material   = price + quantity

  LABOUR:
    • Rate variance      = (std_rate - actual_rate) × actual_hours
    • Efficiency variance = (std_hours - actual_hours) × std_rate
    • Total labour       = rate + efficiency

  OVERHEAD (two-way analysis):
    • Spending variance = budgeted_oh - actual_oh
    • Volume variance   = (actual_hours - std_hours_for_output) × std_rate
    • Total overhead    = spending + volume

Sign convention: positive = saving (favourable), negative = overspend.
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


# ═══════════════════════════════════════════════════════════════
# Material variance
# ═══════════════════════════════════════════════════════════════


@dataclass
class MaterialVarianceInput:
    item_name: str
    std_price: Decimal                 # standard cost per unit
    std_qty_per_output: Decimal        # standard units of material per 1 unit of output
    actual_price: Decimal
    actual_qty_used: Decimal
    output_units: Decimal              # actual units of finished product
    currency: str = "SAR"


@dataclass
class MaterialVarianceResult:
    item_name: str
    std_qty_allowed: Decimal           # std_qty_per_output × output_units
    price_variance: Decimal
    quantity_variance: Decimal
    total_variance: Decimal
    price_label: str                   # 'favourable' | 'unfavourable' | 'none'
    quantity_label: str
    total_label: str
    std_cost: Decimal
    actual_cost: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def _label(v: Decimal) -> str:
    if v > 0:
        return "favourable"
    if v < 0:
        return "unfavourable"
    return "none"


def analyse_material(inp: MaterialVarianceInput) -> MaterialVarianceResult:
    if inp.output_units <= 0:
        raise ValueError("output_units must be positive")
    if inp.std_price < 0 or inp.actual_price < 0:
        raise ValueError("prices cannot be negative")
    if inp.std_qty_per_output < 0 or inp.actual_qty_used < 0:
        raise ValueError("quantities cannot be negative")

    std_qty_allowed = Decimal(str(inp.std_qty_per_output)) * Decimal(str(inp.output_units))

    # Price variance = (std_price - actual_price) × actual_qty_used
    price_var = (Decimal(str(inp.std_price)) - Decimal(str(inp.actual_price))) \
                * Decimal(str(inp.actual_qty_used))
    # Quantity variance = (std_qty_allowed - actual_qty) × std_price
    qty_var = (std_qty_allowed - Decimal(str(inp.actual_qty_used))) \
              * Decimal(str(inp.std_price))

    total = price_var + qty_var

    std_cost = std_qty_allowed * Decimal(str(inp.std_price))
    actual_cost = Decimal(str(inp.actual_qty_used)) * Decimal(str(inp.actual_price))

    warnings: list[str] = []
    if total < 0:
        warnings.append("انحراف إجمالي غير ملائم — راجع خطة الشراء أو الاستهلاك.")
    if abs(price_var) > abs(qty_var) * Decimal("2"):
        warnings.append("انحراف السعر هو المحرّك الأساسي — فاوض مع الموردين.")
    elif abs(qty_var) > abs(price_var) * Decimal("2"):
        warnings.append("انحراف الكمية هو المحرّك الأساسي — راجع الفاقد والهدر.")

    return MaterialVarianceResult(
        item_name=inp.item_name,
        std_qty_allowed=_q(std_qty_allowed),
        price_variance=_q(price_var),
        quantity_variance=_q(qty_var),
        total_variance=_q(total),
        price_label=_label(price_var),
        quantity_label=_label(qty_var),
        total_label=_label(total),
        std_cost=_q(std_cost),
        actual_cost=_q(actual_cost),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Labour variance
# ═══════════════════════════════════════════════════════════════


@dataclass
class LabourVarianceInput:
    cost_center: str
    std_rate_per_hour: Decimal
    std_hours_per_output: Decimal
    actual_rate_per_hour: Decimal
    actual_hours: Decimal
    output_units: Decimal
    currency: str = "SAR"


@dataclass
class LabourVarianceResult:
    cost_center: str
    std_hours_allowed: Decimal
    rate_variance: Decimal
    efficiency_variance: Decimal
    total_variance: Decimal
    rate_label: str
    efficiency_label: str
    total_label: str
    std_cost: Decimal
    actual_cost: Decimal
    currency: str
    warnings: list[str] = field(default_factory=list)


def analyse_labour(inp: LabourVarianceInput) -> LabourVarianceResult:
    if inp.output_units <= 0:
        raise ValueError("output_units must be positive")
    if inp.std_rate_per_hour < 0 or inp.actual_rate_per_hour < 0:
        raise ValueError("rates cannot be negative")
    if inp.std_hours_per_output < 0 or inp.actual_hours < 0:
        raise ValueError("hours cannot be negative")

    std_hours_allowed = Decimal(str(inp.std_hours_per_output)) * Decimal(str(inp.output_units))

    rate_var = (Decimal(str(inp.std_rate_per_hour)) - Decimal(str(inp.actual_rate_per_hour))) \
               * Decimal(str(inp.actual_hours))
    eff_var = (std_hours_allowed - Decimal(str(inp.actual_hours))) \
              * Decimal(str(inp.std_rate_per_hour))

    total = rate_var + eff_var
    std_cost = std_hours_allowed * Decimal(str(inp.std_rate_per_hour))
    actual_cost = Decimal(str(inp.actual_hours)) * Decimal(str(inp.actual_rate_per_hour))

    warnings: list[str] = []
    if total < 0:
        warnings.append("انحراف عمالة غير ملائم — راجع سياسة التعيين والإنتاجية.")
    if eff_var < 0 and abs(eff_var) > std_cost * Decimal("0.05"):
        warnings.append("كفاءة منخفضة — حلّل وقت التعطل والتدريب.")
    if rate_var < 0 and abs(rate_var) > std_cost * Decimal("0.05"):
        warnings.append("معدّل أجور مرتفع — راجع الترقيات أو الاستعانة بالعمالة المؤقتة.")

    return LabourVarianceResult(
        cost_center=inp.cost_center,
        std_hours_allowed=_q(std_hours_allowed),
        rate_variance=_q(rate_var),
        efficiency_variance=_q(eff_var),
        total_variance=_q(total),
        rate_label=_label(rate_var),
        efficiency_label=_label(eff_var),
        total_label=_label(total),
        std_cost=_q(std_cost),
        actual_cost=_q(actual_cost),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Overhead variance (two-way)
# ═══════════════════════════════════════════════════════════════


@dataclass
class OverheadVarianceInput:
    cost_center: str
    budgeted_overhead: Decimal              # pre-planned OH spend
    actual_overhead: Decimal                # actual OH incurred
    std_rate_per_hour: Decimal              # std OH rate (for volume var)
    std_hours_per_output: Decimal
    actual_hours: Decimal
    output_units: Decimal
    currency: str = "SAR"


@dataclass
class OverheadVarianceResult:
    cost_center: str
    std_hours_allowed: Decimal
    applied_overhead: Decimal              # std_hours_allowed × std_rate
    spending_variance: Decimal
    volume_variance: Decimal
    total_variance: Decimal
    spending_label: str
    volume_label: str
    total_label: str
    currency: str
    warnings: list[str] = field(default_factory=list)


def analyse_overhead(inp: OverheadVarianceInput) -> OverheadVarianceResult:
    if inp.output_units <= 0:
        raise ValueError("output_units must be positive")
    if inp.budgeted_overhead < 0 or inp.actual_overhead < 0:
        raise ValueError("overheads cannot be negative")

    std_hours_allowed = Decimal(str(inp.std_hours_per_output)) * Decimal(str(inp.output_units))
    applied = std_hours_allowed * Decimal(str(inp.std_rate_per_hour))

    # Spending = budgeted - actual (positive = saved)
    spending = Decimal(str(inp.budgeted_overhead)) - Decimal(str(inp.actual_overhead))
    # Volume = (actual_hours - std_hours_allowed) × std_rate — measures
    # under/over absorption. Positive = absorbed more than standard.
    # But we treat the "favourable" side as output > standard, so flip:
    volume = (std_hours_allowed - Decimal(str(inp.actual_hours))) \
             * Decimal(str(inp.std_rate_per_hour))

    total = spending + volume

    warnings: list[str] = []
    if total < 0:
        warnings.append("انحراف صناعي غير ملائم — راجع ميزانية التشغيل الثابت.")
    if spending < 0:
        warnings.append("تجاوز في الإنفاق الفعلي على الميزانية — حلّل بنود المصروفات.")

    return OverheadVarianceResult(
        cost_center=inp.cost_center,
        std_hours_allowed=_q(std_hours_allowed),
        applied_overhead=_q(applied),
        spending_variance=_q(spending),
        volume_variance=_q(volume),
        total_variance=_q(total),
        spending_label=_label(spending),
        volume_label=_label(volume),
        total_label=_label(total),
        currency=inp.currency,
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Comprehensive variance (all three at once)
# ═══════════════════════════════════════════════════════════════


@dataclass
class ComprehensiveVarianceInput:
    period_label: str                      # "Q1 2026" etc.
    output_units: Decimal
    material: Optional[MaterialVarianceInput] = None
    labour: Optional[LabourVarianceInput] = None
    overhead: Optional[OverheadVarianceInput] = None


@dataclass
class ComprehensiveVarianceResult:
    period_label: str
    output_units: Decimal
    material: Optional[MaterialVarianceResult]
    labour: Optional[LabourVarianceResult]
    overhead: Optional[OverheadVarianceResult]
    grand_total_variance: Decimal
    grand_label: str
    std_total_cost: Decimal
    actual_total_cost: Decimal
    cost_per_unit_std: Decimal
    cost_per_unit_actual: Decimal
    warnings: list[str] = field(default_factory=list)


def analyse_comprehensive(inp: ComprehensiveVarianceInput) -> ComprehensiveVarianceResult:
    if inp.output_units <= 0:
        raise ValueError("output_units must be positive")
    if not (inp.material or inp.labour or inp.overhead):
        raise ValueError("at least one of material/labour/overhead is required")

    mat_r = analyse_material(inp.material) if inp.material else None
    lab_r = analyse_labour(inp.labour) if inp.labour else None
    oh_r = analyse_overhead(inp.overhead) if inp.overhead else None

    grand = Decimal("0")
    std_total = Decimal("0")
    act_total = Decimal("0")
    warnings: list[str] = []

    if mat_r:
        grand += mat_r.total_variance
        std_total += mat_r.std_cost
        act_total += mat_r.actual_cost
        warnings.extend(mat_r.warnings)
    if lab_r:
        grand += lab_r.total_variance
        std_total += lab_r.std_cost
        act_total += lab_r.actual_cost
        warnings.extend(lab_r.warnings)
    if oh_r:
        grand += oh_r.total_variance
        std_total += oh_r.applied_overhead
        act_total += Decimal(str(inp.overhead.actual_overhead))  # type: ignore[union-attr]
        warnings.extend(oh_r.warnings)

    cpu_std = std_total / Decimal(str(inp.output_units)) if inp.output_units else Decimal("0")
    cpu_act = act_total / Decimal(str(inp.output_units)) if inp.output_units else Decimal("0")

    return ComprehensiveVarianceResult(
        period_label=inp.period_label,
        output_units=_q(inp.output_units),
        material=mat_r,
        labour=lab_r,
        overhead=oh_r,
        grand_total_variance=_q(grand),
        grand_label=_label(grand),
        std_total_cost=_q(std_total),
        actual_total_cost=_q(act_total),
        cost_per_unit_std=_q(cpu_std),
        cost_per_unit_actual=_q(cpu_act),
        warnings=warnings,
    )


# ═══════════════════════════════════════════════════════════════
# Dict serialisers
# ═══════════════════════════════════════════════════════════════


def material_to_dict(r: MaterialVarianceResult) -> dict:
    return {
        "item_name": r.item_name,
        "std_qty_allowed": f"{r.std_qty_allowed}",
        "price_variance": f"{r.price_variance}",
        "quantity_variance": f"{r.quantity_variance}",
        "total_variance": f"{r.total_variance}",
        "price_label": r.price_label,
        "quantity_label": r.quantity_label,
        "total_label": r.total_label,
        "std_cost": f"{r.std_cost}",
        "actual_cost": f"{r.actual_cost}",
        "currency": r.currency,
        "warnings": r.warnings,
    }


def labour_to_dict(r: LabourVarianceResult) -> dict:
    return {
        "cost_center": r.cost_center,
        "std_hours_allowed": f"{r.std_hours_allowed}",
        "rate_variance": f"{r.rate_variance}",
        "efficiency_variance": f"{r.efficiency_variance}",
        "total_variance": f"{r.total_variance}",
        "rate_label": r.rate_label,
        "efficiency_label": r.efficiency_label,
        "total_label": r.total_label,
        "std_cost": f"{r.std_cost}",
        "actual_cost": f"{r.actual_cost}",
        "currency": r.currency,
        "warnings": r.warnings,
    }


def overhead_to_dict(r: OverheadVarianceResult) -> dict:
    return {
        "cost_center": r.cost_center,
        "std_hours_allowed": f"{r.std_hours_allowed}",
        "applied_overhead": f"{r.applied_overhead}",
        "spending_variance": f"{r.spending_variance}",
        "volume_variance": f"{r.volume_variance}",
        "total_variance": f"{r.total_variance}",
        "spending_label": r.spending_label,
        "volume_label": r.volume_label,
        "total_label": r.total_label,
        "currency": r.currency,
        "warnings": r.warnings,
    }


def comprehensive_to_dict(r: ComprehensiveVarianceResult) -> dict:
    return {
        "period_label": r.period_label,
        "output_units": f"{r.output_units}",
        "material": material_to_dict(r.material) if r.material else None,
        "labour": labour_to_dict(r.labour) if r.labour else None,
        "overhead": overhead_to_dict(r.overhead) if r.overhead else None,
        "grand_total_variance": f"{r.grand_total_variance}",
        "grand_label": r.grand_label,
        "std_total_cost": f"{r.std_total_cost}",
        "actual_total_cost": f"{r.actual_total_cost}",
        "cost_per_unit_std": f"{r.cost_per_unit_std}",
        "cost_per_unit_actual": f"{r.cost_per_unit_actual}",
        "warnings": r.warnings,
    }
