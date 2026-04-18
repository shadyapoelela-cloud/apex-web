"""Saudi/UAE GOSI (General Organization for Social Insurance) calculator.

KSA rules (2026):
  • Applies to Saudi nationals only by default (expats covered by EOSB only).
  • Salary base = basic_salary + housing_allowance (capped at 45,000 SAR).
  • Employee contribution: 10% of base.
  • Employer contribution: 12% of base (9% old-age + 2% SANED + 1% occupational hazards).

UAE rules (GPSSA) — for UAE/GCC nationals only:
  • Salary base = basic_salary + housing + any fixed allowances, capped at
    AED 50,000.
  • Employee: 5%  |  Employer: 12.5%  |  Government subsidy: 2.5%

For non-nationals, both systems typically exempt GOSI and instead accrue EOSB.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

_TWO = Decimal("0.01")
_KSA_CAP = Decimal("45000")
_UAE_CAP = Decimal("50000")

KSA_EMPLOYEE_RATE = Decimal("0.10")
KSA_EMPLOYER_RATE = Decimal("0.12")
UAE_EMPLOYEE_RATE = Decimal("0.05")
UAE_EMPLOYER_RATE = Decimal("0.125")


def _round2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class GosiResult:
    salary_base: Decimal
    employee_contribution: Decimal
    employer_contribution: Decimal
    applicable: bool
    reason: str = ""


def calculate_ksa_gosi(
    basic_salary: Decimal,
    housing_allowance: Decimal = Decimal("0"),
    is_saudi: bool = True,
) -> GosiResult:
    """Compute KSA GOSI contributions. Non-Saudis → applicable=False."""
    if not is_saudi:
        return GosiResult(
            salary_base=Decimal("0"),
            employee_contribution=Decimal("0"),
            employer_contribution=Decimal("0"),
            applicable=False,
            reason="Non-Saudi employees are EOSB-based, not GOSI",
        )
    base = min(basic_salary + housing_allowance, _KSA_CAP)
    return GosiResult(
        salary_base=_round2(base),
        employee_contribution=_round2(base * KSA_EMPLOYEE_RATE),
        employer_contribution=_round2(base * KSA_EMPLOYER_RATE),
        applicable=True,
    )


def calculate_uae_gpssa(
    basic_salary: Decimal,
    housing_allowance: Decimal = Decimal("0"),
    other_fixed: Decimal = Decimal("0"),
    is_gcc_national: bool = True,
) -> GosiResult:
    """Compute UAE GPSSA contributions for UAE/GCC nationals."""
    if not is_gcc_national:
        return GosiResult(
            salary_base=Decimal("0"),
            employee_contribution=Decimal("0"),
            employer_contribution=Decimal("0"),
            applicable=False,
            reason="Only UAE/GCC nationals contribute to GPSSA",
        )
    base = min(basic_salary + housing_allowance + other_fixed, _UAE_CAP)
    return GosiResult(
        salary_base=_round2(base),
        employee_contribution=_round2(base * UAE_EMPLOYEE_RATE),
        employer_contribution=_round2(base * UAE_EMPLOYER_RATE),
        applicable=True,
    )
