"""End of Service Benefit (EOSB) calculator.

Saudi Labor Law (نظام العمل السعودي), Articles 84-88:
  • Under 5 years of service: 0.5 month per year  (50% of last monthly wage)
  • 5 years and above:         1 month per year  for the period beyond 5 years
                                (full month), plus the first 5 years at 50%.
  • Based on "last wage": basic + housing + any fixed allowances that are
    earned every month.
  • If the worker resigns: entitlement is reduced per Article 85:
     - <2 years service: none
     - 2 to <5 years:    1/3 of the full EOSB
     - 5 to <10 years:   2/3
     - ≥10 years:        full EOSB

UAE Labor Law (Federal Decree-Law No. 33 of 2021), Articles 51-52:
  • For unlimited contracts / any termination:
     - First 5 years:   21 days basic wage per year
     - Above 5 years:   30 days basic wage per year
  • Cap: total EOSB ≤ 2 years of basic wage.
  • Resignation with limited contract: entitlement follows contract clauses,
    minimum subject to above tiers.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

_TWO = Decimal("0.01")


def _round2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class EosbResult:
    full_eosb: Decimal                    # Full statutory entitlement
    payable: Decimal                      # After resignation reduction
    years_first_tier: Decimal
    years_second_tier: Decimal
    first_tier_amount: Decimal
    second_tier_amount: Decimal
    reduction_factor: Decimal             # 1.0 if termination, 0/1/3/2/3/1 if resignation
    notes: list[str]


def calculate_ksa_eosb(
    monthly_wage: Decimal,                # basic + fixed allowances
    years_of_service: Decimal,
    resigned: bool = False,
) -> EosbResult:
    """KSA EOSB per Saudi Labor Law Articles 84-85."""
    notes: list[str] = []
    years = max(years_of_service, Decimal("0"))

    # First 5 years at 0.5 month per year
    first_tier_years = min(years, Decimal("5"))
    first_tier = monthly_wage * first_tier_years * Decimal("0.5")

    # Additional years at 1 month per year
    second_tier_years = max(years - Decimal("5"), Decimal("0"))
    second_tier = monthly_wage * second_tier_years

    full = first_tier + second_tier

    if not resigned:
        reduction = Decimal("1.0")
        notes.append("Termination / end of contract — full EOSB applies.")
    else:
        if years < Decimal("2"):
            reduction = Decimal("0")
            notes.append("Resignation with <2 years — no EOSB (Art. 85).")
        elif years < Decimal("5"):
            reduction = Decimal("1") / Decimal("3")
            notes.append("Resignation 2-5 years — 1/3 of EOSB (Art. 85).")
        elif years < Decimal("10"):
            reduction = Decimal("2") / Decimal("3")
            notes.append("Resignation 5-10 years — 2/3 of EOSB (Art. 85).")
        else:
            reduction = Decimal("1.0")
            notes.append("Resignation ≥10 years — full EOSB (Art. 85).")

    return EosbResult(
        full_eosb=_round2(full),
        payable=_round2(full * reduction),
        years_first_tier=first_tier_years,
        years_second_tier=second_tier_years,
        first_tier_amount=_round2(first_tier),
        second_tier_amount=_round2(second_tier),
        reduction_factor=reduction,
        notes=notes,
    )


def calculate_uae_eosb(
    basic_monthly_wage: Decimal,
    years_of_service: Decimal,
) -> EosbResult:
    """UAE EOSB per Federal Decree-Law No. 33 of 2021, Articles 51-52."""
    notes: list[str] = []
    years = max(years_of_service, Decimal("0"))

    # First 5 years: 21 days = 21/30 months
    first_tier_years = min(years, Decimal("5"))
    first_tier = basic_monthly_wage * first_tier_years * (Decimal("21") / Decimal("30"))

    # Additional years: 30 days = 1 month
    second_tier_years = max(years - Decimal("5"), Decimal("0"))
    second_tier = basic_monthly_wage * second_tier_years

    full = first_tier + second_tier

    # Cap at 2 years of basic wage (24 months)
    cap = basic_monthly_wage * Decimal("24")
    if full > cap:
        notes.append("EOSB capped at 2 years of basic wage (Art. 51).")
        full = cap

    return EosbResult(
        full_eosb=_round2(full),
        payable=_round2(full),
        years_first_tier=first_tier_years,
        years_second_tier=second_tier_years,
        first_tier_amount=_round2(first_tier),
        second_tier_amount=_round2(second_tier),
        reduction_factor=Decimal("1.0"),
        notes=notes,
    )
