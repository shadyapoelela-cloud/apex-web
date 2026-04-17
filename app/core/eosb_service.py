"""
APEX Platform — End-of-Service Benefits (IAS 19 + Saudi Labour Law)
═══════════════════════════════════════════════════════════════
KSA rules (Article 84 نظام العمل):

  • First 5 years:   ½ month's wage per year
  • After 5 years:   1 full month's wage per year beyond
  • Cap per year:    no cap (but gratuity counts on full basic + allowances)

Termination scenarios:
  • resignation_full   — < 2 yrs: 0%, 2-5 yrs: 1/3, 5-10 yrs: 2/3, >10 yrs: 100%
  • employer_terminated — always 100% of computed EOSB
  • retirement         — 100%
  • death_disability   — 100%

Present-Value adjustment for IAS 19:
  DBO (Defined Benefit Obligation) = PV of future EOSB payments
  using the discount rate (usually KSA government bond yield ~4%)
  and the expected wage-growth rate.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


_TWO = Decimal("0.01")


def _q(v: Optional[Decimal | int | float | str]) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


TERMINATION_REASONS = {
    "resignation", "employer_terminated", "retirement",
    "death_disability", "contract_end",
}


@dataclass
class EosbInput:
    employee_name: str
    employee_id: str
    monthly_basic_salary: Decimal
    monthly_allowances: Decimal = Decimal("0")  # housing, transport, etc.
    years_of_service: Decimal = Decimal("0")    # can be fractional
    termination_reason: str = "employer_terminated"
    currency: str = "SAR"
    # For DBO / actuarial valuation
    discount_rate_pct: Decimal = Decimal("4")
    wage_growth_pct: Decimal = Decimal("3")
    expected_future_years: Decimal = Decimal("0")  # for DBO calc
    retirement_age: int = 60
    current_age: Optional[int] = None


@dataclass
class EosbResult:
    employee_name: str
    employee_id: str
    monthly_wage_for_calc: Decimal       # basic + allowances
    years_of_service: Decimal
    raw_gratuity: Decimal                # before termination adjustment
    termination_factor_pct: Decimal      # % of raw the employee gets
    net_gratuity: Decimal                # raw × factor
    first_5_years_portion: Decimal
    after_5_years_portion: Decimal
    currency: str
    termination_reason: str
    # Actuarial / DBO
    dbo_present_value: Decimal           # PV of future EOSB if expected_future_years > 0
    expected_future_gratuity: Decimal    # projected at retirement
    warnings: list[str] = field(default_factory=list)


def compute_eosb(inp: EosbInput) -> EosbResult:
    if inp.monthly_basic_salary < 0 or inp.monthly_allowances < 0:
        raise ValueError("salary components cannot be negative")
    if inp.years_of_service < 0:
        raise ValueError("years_of_service cannot be negative")
    if inp.termination_reason not in TERMINATION_REASONS:
        raise ValueError(
            f"termination_reason must be one of {sorted(TERMINATION_REASONS)}"
        )
    if inp.discount_rate_pct < 0 or inp.wage_growth_pct < 0:
        raise ValueError("rates cannot be negative")

    warnings: list[str] = []

    wage = Decimal(str(inp.monthly_basic_salary)) + Decimal(str(inp.monthly_allowances))
    yrs = Decimal(str(inp.years_of_service))

    # Article 84: 1/2 month per year for first 5, 1 month per year thereafter
    first_5 = min(yrs, Decimal("5")) * wage / Decimal("2")
    after_5 = max(Decimal("0"), yrs - Decimal("5")) * wage
    raw = first_5 + after_5

    # Termination factor per Article 85 (simplified)
    factor = Decimal("100")
    if inp.termination_reason == "resignation":
        if yrs < Decimal("2"):
            factor = Decimal("0")
            warnings.append("استقالة قبل سنتين — لا يستحق مكافأة وفق المادة 85.")
        elif yrs < Decimal("5"):
            factor = Decimal("33.33")
        elif yrs < Decimal("10"):
            factor = Decimal("66.67")
        else:
            factor = Decimal("100")
    elif inp.termination_reason in ("employer_terminated", "retirement",
                                     "death_disability", "contract_end"):
        factor = Decimal("100")

    net = _q(raw * factor / Decimal("100"))

    # Actuarial DBO calculation
    dbo_pv = Decimal("0")
    expected_future = Decimal("0")
    future_years = Decimal(str(inp.expected_future_years))
    if future_years > 0:
        # Project wage at retirement
        growth = Decimal("1") + Decimal(str(inp.wage_growth_pct)) / Decimal("100")
        future_wage = wage * (growth ** int(future_years))
        # Projected years of service at retirement
        total_yrs = yrs + future_years
        f5 = min(total_yrs, Decimal("5")) * future_wage / Decimal("2")
        a5 = max(Decimal("0"), total_yrs - Decimal("5")) * future_wage
        expected_future = _q(f5 + a5)
        # Discount back to present
        discount = Decimal("1") + Decimal(str(inp.discount_rate_pct)) / Decimal("100")
        dbo_pv = _q(expected_future / (discount ** int(future_years)))

    if net > Decimal("100000"):
        warnings.append(
            "مكافأة كبيرة — يُستحسن تقديم إقرار GOSI + ZATCA للامتثال الضريبي."
        )

    return EosbResult(
        employee_name=inp.employee_name,
        employee_id=inp.employee_id,
        monthly_wage_for_calc=_q(wage),
        years_of_service=_q(yrs),
        raw_gratuity=_q(raw),
        termination_factor_pct=_q(factor),
        net_gratuity=net,
        first_5_years_portion=_q(first_5),
        after_5_years_portion=_q(after_5),
        currency=inp.currency,
        termination_reason=inp.termination_reason,
        dbo_present_value=dbo_pv,
        expected_future_gratuity=expected_future,
        warnings=warnings,
    )


def to_dict(r: EosbResult) -> dict:
    return {
        "employee_name": r.employee_name,
        "employee_id": r.employee_id,
        "monthly_wage_for_calc": f"{r.monthly_wage_for_calc}",
        "years_of_service": f"{r.years_of_service}",
        "raw_gratuity": f"{r.raw_gratuity}",
        "termination_factor_pct": f"{r.termination_factor_pct}",
        "net_gratuity": f"{r.net_gratuity}",
        "first_5_years_portion": f"{r.first_5_years_portion}",
        "after_5_years_portion": f"{r.after_5_years_portion}",
        "currency": r.currency,
        "termination_reason": r.termination_reason,
        "dbo_present_value": f"{r.dbo_present_value}",
        "expected_future_gratuity": f"{r.expected_future_gratuity}",
        "warnings": r.warnings,
    }
