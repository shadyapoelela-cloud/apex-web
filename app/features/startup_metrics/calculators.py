"""SaaS / Startup metric calculators — pure functions.

All money as Decimal to avoid float drift. All functions are side-effect-free
and take plain data structures so they're trivially unit-tested.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

_TWO = Decimal("0.01")


def _r2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


# ── Burn & Runway ───────────────────────────────────────────


@dataclass
class BurnResult:
    gross_burn: Decimal
    net_burn: Decimal
    months_analyzed: int


def compute_burn(
    monthly_expenses: list[Decimal],
    monthly_revenues: list[Decimal] | None = None,
) -> BurnResult:
    """Compute gross (total spend) and net (spend − revenue) burn rates."""
    if not monthly_expenses:
        return BurnResult(Decimal("0"), Decimal("0"), 0)
    months = len(monthly_expenses)
    gross = sum(monthly_expenses, Decimal("0")) / months
    if monthly_revenues:
        m = min(len(monthly_revenues), months)
        rev_avg = sum(monthly_revenues[-m:], Decimal("0")) / m
    else:
        rev_avg = Decimal("0")
    return BurnResult(
        gross_burn=_r2(gross),
        net_burn=_r2(max(gross - rev_avg, Decimal("0"))),
        months_analyzed=months,
    )


@dataclass
class RunwayResult:
    months_remaining: Decimal
    cash_out_date_iso: str | None
    danger: bool             # < 6 months


def compute_runway(cash_balance: Decimal, net_burn: Decimal) -> RunwayResult:
    """Months of cash remaining at current net-burn rate."""
    if net_burn <= 0:
        return RunwayResult(Decimal("9999"), None, False)
    months = cash_balance / net_burn
    from datetime import date
    from dateutil.relativedelta import relativedelta  # type: ignore

    try:
        cash_out = date.today() + relativedelta(months=int(months))
        iso = cash_out.isoformat()
    except Exception:
        iso = None
    return RunwayResult(
        months_remaining=_r2(months),
        cash_out_date_iso=iso,
        danger=months < Decimal("6"),
    )


# ── MRR / ARR ───────────────────────────────────────────────


@dataclass
class MrrResult:
    mrr: Decimal
    customers: int
    arpa: Decimal            # Average Revenue Per Account


def compute_mrr(subscriptions: list[Decimal]) -> MrrResult:
    """Recurring revenue = sum of active subscription monthly values."""
    if not subscriptions:
        return MrrResult(Decimal("0"), 0, Decimal("0"))
    total = sum(subscriptions, Decimal("0"))
    return MrrResult(
        mrr=_r2(total),
        customers=len(subscriptions),
        arpa=_r2(total / len(subscriptions)),
    )


@dataclass
class ArrResult:
    arr: Decimal


def arr_from_mrr(mrr: Decimal) -> ArrResult:
    return ArrResult(arr=_r2(mrr * 12))


# ── LTV / CAC ───────────────────────────────────────────────


@dataclass
class LtvCacResult:
    cac: Decimal
    ltv: Decimal
    ltv_to_cac: Decimal
    payback_months: Decimal


def compute_ltv_cac(
    acquisition_cost: Decimal,
    new_customers: int,
    gross_margin_pct: Decimal,              # 0..100
    arpa: Decimal,
    monthly_churn_pct: Decimal,             # 0..100
) -> LtvCacResult:
    """Compute CAC, LTV, LTV:CAC ratio and payback period."""
    if new_customers <= 0:
        cac = Decimal("0")
    else:
        cac = acquisition_cost / new_customers

    if monthly_churn_pct <= 0:
        lifetime_months = Decimal("9999")  # Effectively infinite
    else:
        lifetime_months = Decimal("100") / monthly_churn_pct

    gross_margin = gross_margin_pct / Decimal("100")
    ltv = arpa * gross_margin * lifetime_months

    ratio = (ltv / cac) if cac > 0 else Decimal("0")
    payback = (cac / (arpa * gross_margin)) if (arpa * gross_margin) > 0 else Decimal("9999")

    return LtvCacResult(
        cac=_r2(cac),
        ltv=_r2(ltv),
        ltv_to_cac=_r2(ratio),
        payback_months=_r2(payback),
    )


# ── Rule of 40 ─────────────────────────────────────────────


@dataclass
class RuleOf40Result:
    growth_rate_pct: Decimal
    ebitda_margin_pct: Decimal
    score: Decimal              # growth + margin
    passes_rule: bool           # ≥ 40


def compute_rule_of_40(
    growth_rate_pct: Decimal,
    ebitda_margin_pct: Decimal,
) -> RuleOf40Result:
    """Investor sanity check — healthy SaaS companies score ≥ 40."""
    score = growth_rate_pct + ebitda_margin_pct
    return RuleOf40Result(
        growth_rate_pct=_r2(growth_rate_pct),
        ebitda_margin_pct=_r2(ebitda_margin_pct),
        score=_r2(score),
        passes_rule=score >= Decimal("40"),
    )


# ── Cohort retention ───────────────────────────────────────


@dataclass
class CohortResult:
    cohort_month: str           # 'YYYY-MM'
    initial_size: int
    retention_by_month: list[Decimal]  # [m0=1.00, m1=0.95, m2=0.92, ...]


def compute_cohort(cohort_label: str, sizes_over_time: list[int]) -> CohortResult:
    """Given a series of cohort sizes (index 0 = start), return retention."""
    if not sizes_over_time:
        return CohortResult(cohort_label, 0, [])
    initial = sizes_over_time[0]
    if initial == 0:
        return CohortResult(cohort_label, 0, [Decimal("0") for _ in sizes_over_time])
    ratios = [(Decimal(s) / Decimal(initial)).quantize(Decimal("0.0001")) for s in sizes_over_time]
    return CohortResult(cohort_label, initial, ratios)
