"""
APEX Platform — Loan Amortization Schedule
═══════════════════════════════════════════════════════════════
Computes a period-by-period amortization table for:

  • Fixed-payment (French amortization) — constant PMT per period,
    interest portion decreases, principal portion increases.
    PMT = P × r / (1 − (1 + r)^−n)

  • Constant-principal (German amortization) — equal principal
    portion, interest decreases, total payment decreases.

Both methods accept any compounding frequency (monthly, quarterly,
annual) via `periods_per_year`.

All math is Decimal. Rates are accepted as annual percentages
(e.g. "6.5" = 6.5%).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP, getcontext
from typing import List


getcontext().prec = 28
_TWO = Decimal("0.01")


def _q(value: Decimal | int | float | str) -> Decimal:
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    return value.quantize(_TWO, rounding=ROUND_HALF_UP)


METHODS = ("fixed_payment", "constant_principal")


@dataclass
class AmortizationInput:
    principal: Decimal                     # loan amount
    annual_rate_pct: Decimal               # e.g. 6.5 for 6.5%
    years: int                             # loan term
    periods_per_year: int = 12             # 12=monthly, 4=quarterly, 1=annual
    method: str = "fixed_payment"


@dataclass
class AmortizationPeriod:
    period: int
    opening_balance: Decimal
    payment: Decimal
    interest: Decimal
    principal: Decimal
    closing_balance: Decimal


@dataclass
class AmortizationResult:
    method: str
    principal: Decimal
    annual_rate_pct: Decimal
    periods_per_year: int
    total_periods: int
    periodic_rate_pct: Decimal        # the periodic rate applied each period
    fixed_payment: Decimal            # constant PMT (fixed-payment only; else 0)
    total_payments: Decimal
    total_interest: Decimal
    schedule: List[AmortizationPeriod] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Math helpers
# ═══════════════════════════════════════════════════════════════


def _pmt(principal: Decimal, periodic_rate: Decimal, n_periods: int) -> Decimal:
    """PMT formula. periodic_rate is a decimal (0.005 = 0.5%)."""
    if periodic_rate == 0:
        return principal / Decimal(n_periods)
    one_plus_r = Decimal("1") + periodic_rate
    factor = one_plus_r ** -n_periods
    return principal * periodic_rate / (Decimal("1") - factor)


def _pow(base: Decimal, exp: int) -> Decimal:
    # Integer exponent — Decimal's ** supports this natively.
    return base ** exp


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════


def compute_amortization(inp: AmortizationInput) -> AmortizationResult:
    method = (inp.method or "fixed_payment").lower()
    if method not in METHODS:
        raise ValueError(f"Unknown method {inp.method!r}. Expected {METHODS}")

    principal = Decimal(str(inp.principal))
    rate_pct = Decimal(str(inp.annual_rate_pct))
    years = int(inp.years)
    ppy = int(inp.periods_per_year)

    if principal <= 0:
        raise ValueError("principal must be positive")
    if rate_pct < 0:
        raise ValueError("annual_rate_pct cannot be negative")
    if years <= 0:
        raise ValueError("years must be positive")
    if ppy not in (1, 2, 4, 6, 12, 52, 365):
        raise ValueError(f"periods_per_year must be one of 1, 2, 4, 6, 12, 52, 365 (got {ppy})")

    total_periods = years * ppy
    periodic_rate = rate_pct / Decimal("100") / Decimal(ppy)
    periodic_rate_pct = _q(periodic_rate * Decimal("100"))

    warnings: list[str] = []

    schedule: List[AmortizationPeriod] = []
    balance = principal
    total_interest = Decimal("0")
    total_payments = Decimal("0")
    fixed_pmt = Decimal("0")

    if method == "fixed_payment":
        fixed_pmt = _q(_pmt(principal, periodic_rate, total_periods))
        for p in range(1, total_periods + 1):
            interest = _q(balance * periodic_rate)
            principal_portion = _q(fixed_pmt - interest)
            # Final period: absorb any rounding residue into last principal
            if p == total_periods:
                principal_portion = _q(balance)
                payment = _q(interest + principal_portion)
            else:
                payment = fixed_pmt
            new_balance = _q(balance - principal_portion)
            schedule.append(AmortizationPeriod(
                period=p,
                opening_balance=_q(balance),
                payment=payment,
                interest=interest,
                principal=principal_portion,
                closing_balance=new_balance,
            ))
            total_interest = _q(total_interest + interest)
            total_payments = _q(total_payments + payment)
            balance = new_balance

    else:  # constant_principal
        principal_per_period = _q(principal / Decimal(total_periods))
        for p in range(1, total_periods + 1):
            interest = _q(balance * periodic_rate)
            principal_portion = principal_per_period
            if p == total_periods:
                # absorb residue
                principal_portion = _q(balance)
            payment = _q(principal_portion + interest)
            new_balance = _q(balance - principal_portion)
            schedule.append(AmortizationPeriod(
                period=p,
                opening_balance=_q(balance),
                payment=payment,
                interest=interest,
                principal=principal_portion,
                closing_balance=new_balance,
            ))
            total_interest = _q(total_interest + interest)
            total_payments = _q(total_payments + payment)
            balance = new_balance

    # Sanity
    if balance != 0:
        if abs(balance) < Decimal("0.05"):
            # rounding artefact — fold into last row
            last = schedule[-1]
            schedule[-1] = AmortizationPeriod(
                period=last.period,
                opening_balance=last.opening_balance,
                payment=_q(last.payment + balance),
                interest=last.interest,
                principal=_q(last.principal + balance),
                closing_balance=Decimal("0.00"),
            )
            total_payments = _q(total_payments + balance)
        else:
            warnings.append(
                f"الرصيد المتبقي بعد جدول السداد = {balance} — تحقق من المدخلات."
            )

    return AmortizationResult(
        method=method,
        principal=_q(principal),
        annual_rate_pct=_q(rate_pct),
        periods_per_year=ppy,
        total_periods=total_periods,
        periodic_rate_pct=periodic_rate_pct,
        fixed_payment=_q(fixed_pmt),
        total_payments=total_payments,
        total_interest=total_interest,
        schedule=schedule,
        warnings=warnings,
    )


def result_to_dict(r: AmortizationResult) -> dict:
    return {
        "method": r.method,
        "principal": f"{r.principal}",
        "annual_rate_pct": f"{r.annual_rate_pct}",
        "periods_per_year": r.periods_per_year,
        "total_periods": r.total_periods,
        "periodic_rate_pct": f"{r.periodic_rate_pct}",
        "fixed_payment": f"{r.fixed_payment}",
        "total_payments": f"{r.total_payments}",
        "total_interest": f"{r.total_interest}",
        "schedule": [
            {
                "period": p.period,
                "opening_balance": f"{p.opening_balance}",
                "payment": f"{p.payment}",
                "interest": f"{p.interest}",
                "principal": f"{p.principal}",
                "closing_balance": f"{p.closing_balance}",
            }
            for p in r.schedule
        ],
        "warnings": r.warnings,
    }
