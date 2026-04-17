"""
APEX Platform — Lease Accounting (IFRS 16)
═══════════════════════════════════════════════════════════════
Computes the lessee's accounting entries for a lease per IFRS 16:

  1. Lease liability = PV of future lease payments discounted at
     the incremental borrowing rate (IBR)
  2. Right-of-use (ROU) asset = lease liability + initial direct
     costs + prepaid lease payments − lease incentives
  3. Amortisation schedule:
     • Each period: interest expense = opening liab × periodic rate
       principal = payment − interest
       closing liab = opening − principal
  4. ROU depreciation = (ROU cost − residual) / lease_term (straight-line)

Short-term (≤12 months) and low-value leases are exempt — reported
as regular operating expense.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")
_SIX = Decimal("0.000001")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


def _q6(v: Decimal) -> Decimal:
    return v.quantize(_SIX, rounding=ROUND_HALF_UP)


@dataclass
class LeaseInput:
    lease_name: str
    start_date: str                     # YYYY-MM-DD (for display)
    term_months: int
    payment_amount: Decimal             # per period
    payment_frequency: str = "monthly"  # 'monthly' | 'quarterly' | 'annual'
    annual_ibr_pct: Decimal = Decimal("5")
    payment_timing: str = "end"         # 'end' (arrears) | 'begin' (advance)
    initial_direct_costs: Decimal = Decimal("0")
    prepaid_lease_payments: Decimal = Decimal("0")
    lease_incentives: Decimal = Decimal("0")
    residual_value: Decimal = Decimal("0")
    currency: str = "SAR"


@dataclass
class AmortRow:
    period: int
    date_note: str                       # e.g. "Month 1", "Q1"
    opening_liability: Decimal
    payment: Decimal
    interest: Decimal
    principal: Decimal
    closing_liability: Decimal


@dataclass
class LeaseResult:
    lease_name: str
    currency: str
    term_months: int
    payment_frequency: str
    periods: int
    periodic_rate: Decimal
    annual_ibr_pct: Decimal
    total_payments: Decimal               # undiscounted
    lease_liability_initial: Decimal
    rou_asset_initial: Decimal
    total_interest: Decimal
    periodic_depreciation: Decimal
    total_depreciation: Decimal
    schedule: List[AmortRow]
    is_short_term: bool
    is_low_value: bool
    warnings: list[str] = field(default_factory=list)


_FREQ_PERIODS = {"monthly": 12, "quarterly": 4, "annual": 1}


def _pv(rate: Decimal, nper: int, pmt: Decimal, timing: str) -> Decimal:
    """Present value of an ordinary annuity (or annuity-due)."""
    if rate == 0:
        pv = pmt * Decimal(nper)
    else:
        factor = (Decimal(1) - (Decimal(1) + rate) ** (-nper)) / rate
        pv = pmt * factor
    if timing == "begin":
        pv = pv * (Decimal(1) + rate)
    return pv


def build_lease(inp: LeaseInput) -> LeaseResult:
    if inp.term_months <= 0:
        raise ValueError("term_months must be positive")
    if inp.term_months > 600:
        raise ValueError("term_months exceeds reasonable limit (50 years)")
    if inp.payment_amount < 0:
        raise ValueError("payment_amount cannot be negative")
    if inp.annual_ibr_pct < 0 or inp.annual_ibr_pct > 50:
        raise ValueError("annual_ibr_pct must be 0-50")
    if inp.payment_frequency not in _FREQ_PERIODS:
        raise ValueError(f"payment_frequency must be one of {list(_FREQ_PERIODS)}")
    if inp.payment_timing not in ("end", "begin"):
        raise ValueError("payment_timing must be 'end' or 'begin'")

    warnings: list[str] = []

    freq_per_year = _FREQ_PERIODS[inp.payment_frequency]
    periods_per_month = freq_per_year / 12
    periods = max(1, int(round(inp.term_months * periods_per_month)))
    periodic_rate = _q6(
        Decimal(str(inp.annual_ibr_pct)) / Decimal("100") / Decimal(freq_per_year)
    )

    short_term = inp.term_months <= 12
    low_value = Decimal(str(inp.payment_amount)) < Decimal("2000")
    if short_term:
        warnings.append(
            "إيجار قصير الأجل (≤ 12 شهراً) — يمكن إثباته كمصروف مباشر وفق IFRS 16.5."
        )
    if low_value:
        warnings.append(
            "قيمة الدفعة منخفضة — قد يستثنى من إثبات ROU وفق IFRS 16.5(b)."
        )

    pmt = Decimal(str(inp.payment_amount))
    liability_initial = _q(_pv(periodic_rate, periods, pmt, inp.payment_timing))

    # ROU asset = liability + IDC + prepaid − incentives
    rou_initial = _q(
        liability_initial
        + Decimal(str(inp.initial_direct_costs))
        + Decimal(str(inp.prepaid_lease_payments))
        - Decimal(str(inp.lease_incentives))
    )

    # Build amortisation schedule
    schedule: List[AmortRow] = []
    bal = liability_initial
    total_interest = Decimal("0")
    total_payments = Decimal("0")

    for p in range(1, periods + 1):
        opening = bal
        if inp.payment_timing == "begin":
            # Payment made at start of period → no interest on that portion
            principal_part = min(pmt, opening)
            after_payment = opening - principal_part
            interest = _q(after_payment * periodic_rate)
            bal = after_payment + interest
            total_payments += pmt
            schedule.append(AmortRow(
                period=p,
                date_note=_period_note(p, inp.payment_frequency),
                opening_liability=_q(opening),
                payment=_q(pmt),
                interest=_q(interest),
                principal=_q(principal_part),
                closing_liability=_q(bal),
            ))
        else:
            # end-of-period payment
            interest = _q(opening * periodic_rate)
            principal = pmt - interest
            if principal > opening:
                principal = opening
                pmt_actual = interest + principal
            else:
                pmt_actual = pmt
            bal = opening - principal
            total_interest += interest
            total_payments += pmt_actual
            schedule.append(AmortRow(
                period=p,
                date_note=_period_note(p, inp.payment_frequency),
                opening_liability=_q(opening),
                payment=_q(pmt_actual),
                interest=_q(interest),
                principal=_q(principal),
                closing_liability=_q(bal),
            ))

    # Recompute total_interest for begin-timing case (sum from schedule)
    if inp.payment_timing == "begin":
        total_interest = sum((r.interest for r in schedule), Decimal("0"))

    # Straight-line depreciation
    depreciable = rou_initial - Decimal(str(inp.residual_value))
    periodic_depreciation = _q(depreciable / Decimal(periods)) if periods else Decimal("0")
    total_depreciation = _q(periodic_depreciation * Decimal(periods))

    return LeaseResult(
        lease_name=inp.lease_name,
        currency=inp.currency,
        term_months=inp.term_months,
        payment_frequency=inp.payment_frequency,
        periods=periods,
        periodic_rate=periodic_rate,
        annual_ibr_pct=Decimal(str(inp.annual_ibr_pct)),
        total_payments=_q(total_payments),
        lease_liability_initial=liability_initial,
        rou_asset_initial=rou_initial,
        total_interest=_q(total_interest),
        periodic_depreciation=periodic_depreciation,
        total_depreciation=total_depreciation,
        schedule=schedule,
        is_short_term=short_term,
        is_low_value=low_value,
        warnings=warnings,
    )


def _period_note(p: int, freq: str) -> str:
    if freq == "monthly":
        return f"شهر {p}"
    if freq == "quarterly":
        return f"ربع {p}"
    return f"سنة {p}"


def lease_to_dict(r: LeaseResult) -> dict:
    return {
        "lease_name": r.lease_name,
        "currency": r.currency,
        "term_months": r.term_months,
        "payment_frequency": r.payment_frequency,
        "periods": r.periods,
        "periodic_rate": f"{r.periodic_rate}",
        "annual_ibr_pct": f"{r.annual_ibr_pct}",
        "total_payments": f"{r.total_payments}",
        "lease_liability_initial": f"{r.lease_liability_initial}",
        "rou_asset_initial": f"{r.rou_asset_initial}",
        "total_interest": f"{r.total_interest}",
        "periodic_depreciation": f"{r.periodic_depreciation}",
        "total_depreciation": f"{r.total_depreciation}",
        "is_short_term": r.is_short_term,
        "is_low_value": r.is_low_value,
        "schedule": [
            {
                "period": row.period,
                "date_note": row.date_note,
                "opening_liability": f"{row.opening_liability}",
                "payment": f"{row.payment}",
                "interest": f"{row.interest}",
                "principal": f"{row.principal}",
                "closing_liability": f"{row.closing_liability}",
            }
            for row in r.schedule
        ],
        "warnings": r.warnings,
    }
