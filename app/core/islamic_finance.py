"""Islamic (AAOIFI-aligned) finance calculators.

Blue-ocean module — no Arabic accounting SaaS currently ships
AAOIFI-compliant calculators for Murabaha/Ijarah/Sukuk. APEX's angle:
cover the math and account templates, leave Shariah scholars to
approve the product structure.

Modules:
  • Murabaha schedule generator — deferred-markup recognition
    following AAOIFI FAS 28 (effective yield method).
  • Ijarah (Islamic operating lease) period allocation.
  • Zakah base calculator — 2.5% on net zakatable assets with
    the standard KSA deductions.
  • Sukuk profit distribution helper (not investor accounting —
    just the cashflow schedule).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, asdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

logger = logging.getLogger(__name__)

_Q = Decimal("0.01")


def _q(v: Decimal | float | int) -> Decimal:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_Q, rounding=ROUND_HALF_UP)


# ── Murabaha (cost-plus) ─────────────────────────────────


@dataclass
class MurabahaInstallment:
    seq: int
    due_date: str                # ISO yyyy-mm-dd
    opening_balance: float
    payment: float
    profit_recognized: float     # markup portion of this installment
    principal_reduction: float
    closing_balance: float


def murabaha_schedule(
    *,
    cost_price: float,
    selling_price: float,
    start_date: str,
    installments: int,
    period_days: int = 30,
) -> dict[str, Any]:
    """Generate an AAOIFI-style Murabaha schedule.

    Recognizes the markup (selling - cost) across installments using
    the effective-yield method: each period's profit is proportional
    to the outstanding principal, not straight-line (which
    over-recognizes early income and violates FAS 28).

    Returns a dict with the full schedule + totals.
    """
    cost = _q(cost_price)
    sell = _q(selling_price)
    markup = sell - cost
    if cost <= 0 or sell <= cost or installments <= 0:
        return {"error": "cost_price and installments must be > 0 and selling_price > cost"}

    try:
        start = date.fromisoformat(start_date)
    except Exception:
        return {"error": f"invalid start_date: {start_date}"}

    # Installment amount = selling / N (equal payments for simplicity —
    # sculpted / balloon can be added via a payments[] override later).
    installment_amount = _q(sell / installments)

    # Effective-yield rate per period (approximate IRR against equal
    # installments). Newton-Raphson would be more accurate; for clarity
    # we approximate by solving cost = Σ installment / (1+r)^t for r.
    # Binary search:
    lo, hi = Decimal("0"), Decimal("1")
    for _ in range(50):
        mid = (lo + hi) / 2
        pv = sum(
            installment_amount / ((1 + mid) ** i)
            for i in range(1, installments + 1)
        )
        if pv > cost:
            lo = mid
        else:
            hi = mid
    rate_per_period = (lo + hi) / 2

    schedule: list[MurabahaInstallment] = []
    balance = cost
    cumulative_profit = Decimal("0")
    for i in range(1, installments + 1):
        profit = _q(balance * rate_per_period)
        principal = installment_amount - profit
        closing = balance - principal
        # Tidy rounding drift on the last row.
        if i == installments:
            profit = markup - cumulative_profit
            principal = installment_amount - profit
            closing = Decimal("0")
        cumulative_profit += profit
        due = (start + timedelta(days=period_days * i)).isoformat()
        schedule.append(MurabahaInstallment(
            seq=i,
            due_date=due,
            opening_balance=float(balance),
            payment=float(installment_amount),
            profit_recognized=float(profit),
            principal_reduction=float(principal),
            closing_balance=float(closing if closing > 0 else Decimal("0")),
        ))
        balance = closing

    return {
        "cost_price": float(cost),
        "selling_price": float(sell),
        "total_markup": float(markup),
        "installment_amount": float(installment_amount),
        "installments": installments,
        "period_days": period_days,
        "effective_yield_per_period": round(float(rate_per_period) * 100, 4),
        "schedule": [asdict(r) for r in schedule],
        "method": "effective_yield (AAOIFI FAS 28)",
    }


# ── Ijarah (Islamic operating lease) ─────────────────────


@dataclass
class IjarahPeriod:
    seq: int
    period_end: str
    rental_expense: float        # recognized straight-line
    asset_depreciation: float    # on underlying asset


def ijarah_schedule(
    *,
    rental_per_period: float,
    periods: int,
    start_date: str,
    period_days: int = 30,
    asset_value: float = 0,
    useful_life_periods: int = 0,
) -> dict[str, Any]:
    """Straight-line Ijarah rental recognition + optional asset
    depreciation schedule for lessor accounting (AAOIFI FAS 32 operating
    Ijarah). Lessee side expenses the rental on a straight-line basis
    when the operating-lease criterion is met."""
    try:
        start = date.fromisoformat(start_date)
    except Exception:
        return {"error": f"invalid start_date: {start_date}"}
    rental = _q(rental_per_period)
    dep = (
        _q(asset_value) / useful_life_periods
        if asset_value and useful_life_periods
        else Decimal("0")
    )

    out: list[IjarahPeriod] = []
    for i in range(1, periods + 1):
        out.append(IjarahPeriod(
            seq=i,
            period_end=(start + timedelta(days=period_days * i)).isoformat(),
            rental_expense=float(rental),
            asset_depreciation=float(dep),
        ))

    return {
        "rental_per_period": float(rental),
        "periods": periods,
        "total_rental": float(rental * periods),
        "asset_depreciation_per_period": float(dep),
        "total_depreciation": float(dep * periods),
        "schedule": [asdict(r) for r in out],
    }


# ── Zakah base calculator ────────────────────────────────


@dataclass
class ZakahLine:
    label_ar: str
    amount: float


def zakah_base(
    *,
    current_assets: float,
    investments_for_trade: float,
    fixed_assets_net: float,       # not zakatable (used in operations)
    intangibles: float,            # not zakatable
    current_liabilities: float,
    long_term_liabilities_due_within_year: float,
    tax_rate_pct: float = 2.5,
) -> dict[str, Any]:
    """Compute the ZATCA-style Zakah base.

    Simplified formula (SOCPA-aligned):
      base = (current_assets + investments_for_trade)
             - (current_liabilities + LT_liabilities_due_within_year)

    Does NOT subtract fixed assets or intangibles — those are captured
    in the inputs separately so the UI can display them as non-zakatable.
    """
    ca = _q(current_assets)
    inv = _q(investments_for_trade)
    cl = _q(current_liabilities)
    ltd = _q(long_term_liabilities_due_within_year)
    base = ca + inv - cl - ltd
    if base < 0:
        base = Decimal("0")
    rate = Decimal(str(tax_rate_pct)) / Decimal("100")
    zakah = _q(base * rate)

    additions = [
        ZakahLine("أصول متداولة", float(ca)),
        ZakahLine("استثمارات للمتاجرة", float(inv)),
    ]
    deductions = [
        ZakahLine("التزامات متداولة", float(cl)),
        ZakahLine("الجزء المتداول من الالتزامات طويلة الأجل", float(ltd)),
    ]
    non_zakatable = [
        ZakahLine("أصول ثابتة صافية (غير زكوية)", float(fixed_assets_net)),
        ZakahLine("أصول غير ملموسة (غير زكوية)", float(intangibles)),
    ]

    return {
        "base": float(base),
        "rate_pct": float(tax_rate_pct),
        "zakah_payable": float(zakah),
        "additions": [asdict(r) for r in additions],
        "deductions": [asdict(r) for r in deductions],
        "non_zakatable": [asdict(r) for r in non_zakatable],
        "method": "SOCPA-aligned simplified base — verify with licensed Zakat advisor before filing",
    }
