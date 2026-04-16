"""
APEX Platform — Investment Appraisal (NPV / IRR / Payback)
═══════════════════════════════════════════════════════════════
Discounted cash-flow metrics used by every CFO for capital
budgeting decisions.

  NPV  = Σ  CF_t  /  (1 + r)^t
  IRR  = r  such that NPV(r) = 0          (Newton-Raphson, fallback bisection)
  PI   = PV_of_future_cashflows  /  |initial_investment|   (profitability index)
  Payback (simple)    — year in which cumulative CF turns positive
  Payback (discounted) — same but using discounted CFs

All math is Decimal. IRR root-finder uses Decimal for the
iteration + bracket, so no Float drift creeps in.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")
_FOUR = Decimal("0.0001")


def _q(value: Decimal | int | float | str) -> Decimal:
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


def _q4(value: Decimal) -> Decimal:
    return value.quantize(_FOUR, rounding=ROUND_HALF_UP)


@dataclass
class InvestmentInput:
    # Cash flows by period, period 0 = initial investment (typically negative).
    # e.g. [-100000, 30000, 30000, 30000, 30000, 30000]
    cash_flows: List[Decimal] = field(default_factory=list)
    # Discount rate as decimal (0.10 for 10%)
    discount_rate: Decimal = Decimal("0.10")
    period_label: str = "Project"
    # Optional: label the periods (Year 1, Q1, etc.)
    period_unit: str = "year"


@dataclass
class CashFlowRow:
    period: int
    cash_flow: Decimal
    discount_factor: Decimal
    present_value: Decimal
    cumulative_pv: Decimal
    cumulative_cf: Decimal


@dataclass
class InvestmentResult:
    period_label: str
    period_unit: str
    initial_investment: Decimal
    discount_rate_pct: Decimal          # informational
    npv: Decimal
    irr_pct: Optional[Decimal]          # None if no root found
    profitability_index: Optional[Decimal]
    simple_payback: Optional[Decimal]   # in periods (fractional)
    discounted_payback: Optional[Decimal]
    total_cash_in: Decimal
    total_cash_out: Decimal
    decision: str                       # "accept" | "reject" | "marginal"
    rows: List[CashFlowRow] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Math helpers
# ═══════════════════════════════════════════════════════════════


def _npv_at(rate: Decimal, cfs: List[Decimal]) -> Decimal:
    total = Decimal("0")
    one_plus_r = Decimal("1") + rate
    factor = Decimal("1")
    for cf in cfs:
        total += cf / factor
        factor *= one_plus_r
    return total


def _irr(cfs: List[Decimal]) -> Optional[Decimal]:
    """IRR via bisection — reliable even for irregular cash flows.
    Returns None if no sign change (no root) or convergence failure."""
    # Must have sign change
    has_pos = any(cf > 0 for cf in cfs)
    has_neg = any(cf < 0 for cf in cfs)
    if not (has_pos and has_neg):
        return None
    # Bracket: [−0.99, 10.0] = −99%..1000%
    lo = Decimal("-0.9999")
    hi = Decimal("10.0")
    f_lo = _npv_at(lo, cfs)
    f_hi = _npv_at(hi, cfs)
    if f_lo * f_hi > 0:
        # Same sign at both ends — root outside bracket.
        return None
    # 80 iterations of bisection on Decimal → ~1e-24 precision
    for _ in range(80):
        mid = (lo + hi) / Decimal("2")
        f_mid = _npv_at(mid, cfs)
        if abs(f_mid) < Decimal("0.0001"):
            return mid
        if f_lo * f_mid < 0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid
    return (lo + hi) / Decimal("2")


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════


def compute_investment(inp: InvestmentInput) -> InvestmentResult:
    warnings: list[str] = []

    if not inp.cash_flows:
        raise ValueError("cash_flows cannot be empty")
    if len(inp.cash_flows) < 2:
        raise ValueError("Provide at least 2 periods (investment + 1 return)")
    if inp.discount_rate <= -1:
        raise ValueError("discount_rate must be > -1")

    cfs = [Decimal(str(v)) if not isinstance(v, Decimal) else v for v in inp.cash_flows]
    initial = cfs[0]
    rate = inp.discount_rate

    if initial >= 0:
        warnings.append(
            "Period 0 cash flow is non-negative — usually this is the "
            "initial investment and should be negative."
        )

    # Per-period table
    rows: List[CashFlowRow] = []
    cum_pv = Decimal("0")
    cum_cf = Decimal("0")
    one_plus_r = Decimal("1") + rate
    factor = Decimal("1")
    for i, cf in enumerate(cfs):
        df = Decimal("1") / factor
        pv = cf * df
        cum_pv += pv
        cum_cf += cf
        rows.append(CashFlowRow(
            period=i, cash_flow=_q(cf),
            discount_factor=_q4(df),
            present_value=_q(pv),
            cumulative_pv=_q(cum_pv),
            cumulative_cf=_q(cum_cf),
        ))
        factor *= one_plus_r

    # NPV
    npv = _q(cum_pv)

    # IRR
    irr = _irr(cfs)
    irr_pct = None if irr is None else (irr * Decimal("100")).quantize(_TWO, rounding=ROUND_HALF_UP)

    # Profitability Index = PV of future CFs / |initial|
    pi = None
    if initial < 0:
        pv_future = Decimal("0")
        factor2 = one_plus_r
        for cf in cfs[1:]:
            pv_future += cf / factor2
            factor2 *= one_plus_r
        pi = (pv_future / abs(initial)).quantize(_FOUR, rounding=ROUND_HALF_UP)

    # Simple payback — find the period where cumulative CF crosses 0
    simple_pb = None
    for i in range(1, len(rows)):
        if rows[i - 1].cumulative_cf < 0 and rows[i].cumulative_cf >= 0:
            prev_cum = rows[i - 1].cumulative_cf
            this_cf = rows[i].cash_flow
            if this_cf > 0:
                fraction = -prev_cum / this_cf
                simple_pb = (Decimal(i - 1) + fraction).quantize(_FOUR, rounding=ROUND_HALF_UP)
                break

    # Discounted payback
    disc_pb = None
    for i in range(1, len(rows)):
        if rows[i - 1].cumulative_pv < 0 and rows[i].cumulative_pv >= 0:
            prev_cum = rows[i - 1].cumulative_pv
            this_pv = rows[i].present_value
            if this_pv > 0:
                fraction = -prev_cum / this_pv
                disc_pb = (Decimal(i - 1) + fraction).quantize(_FOUR, rounding=ROUND_HALF_UP)
                break

    # Decision
    if npv > 0 and (pi is None or pi > 1):
        decision = "accept"
    elif npv < 0 or (pi is not None and pi < 1):
        decision = "reject"
    else:
        decision = "marginal"

    # Totals
    cash_in = _q(sum((cf for cf in cfs if cf > 0), Decimal("0")))
    cash_out = _q(sum((-cf for cf in cfs if cf < 0), Decimal("0")))

    # Warnings
    if irr is not None and rate >= irr:
        warnings.append(
            "معدل الخصم ≥ IRR — المشروع غير مجدٍ عند هذا المعدل."
        )
    if initial >= 0 and not any(cf < 0 for cf in cfs):
        warnings.append(
            "لا توجد تدفقات سالبة — تأكد أن الاستثمار الأولي مسجّل بقيمة سالبة."
        )

    return InvestmentResult(
        period_label=inp.period_label,
        period_unit=inp.period_unit,
        initial_investment=_q(initial),
        discount_rate_pct=(rate * Decimal("100")).quantize(_TWO, rounding=ROUND_HALF_UP),
        npv=npv,
        irr_pct=irr_pct,
        profitability_index=pi,
        simple_payback=simple_pb,
        discounted_payback=disc_pb,
        total_cash_in=cash_in,
        total_cash_out=cash_out,
        decision=decision,
        rows=rows,
        warnings=warnings,
    )


def result_to_dict(r: InvestmentResult) -> dict:
    def _s(v):
        return None if v is None else f"{v}"
    return {
        "period_label": r.period_label,
        "period_unit": r.period_unit,
        "initial_investment": f"{r.initial_investment}",
        "discount_rate_pct": f"{r.discount_rate_pct}",
        "npv": f"{r.npv}",
        "irr_pct": _s(r.irr_pct),
        "profitability_index": _s(r.profitability_index),
        "simple_payback": _s(r.simple_payback),
        "discounted_payback": _s(r.discounted_payback),
        "total_cash_in": f"{r.total_cash_in}",
        "total_cash_out": f"{r.total_cash_out}",
        "decision": r.decision,
        "rows": [
            {
                "period": row.period,
                "cash_flow": f"{row.cash_flow}",
                "discount_factor": f"{row.discount_factor}",
                "present_value": f"{row.present_value}",
                "cumulative_pv": f"{row.cumulative_pv}",
                "cumulative_cf": f"{row.cumulative_cf}",
            }
            for row in r.rows
        ],
        "warnings": r.warnings,
    }
