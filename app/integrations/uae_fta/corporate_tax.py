"""UAE Corporate Tax calculator.

Implements the headline rules introduced by Federal Decree-Law No. 47 of 2022
(effective 1 June 2023 for qualifying periods):

  • 0% on taxable income up to AED 375,000.
  • 9% on taxable income above AED 375,000.
  • Small Business Relief (SBR): election available if revenue ≤ AED 3M for
    the relevant and prior periods → 0% CT (through the end of 2026).
  • Qualifying Free Zone Person (QFZP): Qualifying Income taxed at 0%,
    non-qualifying income at 9% (no AED 375K exemption applies to the 9%
    portion).
  • Losses carried forward: capped at 75% of current-year taxable income.

This module is intentionally a calculator — it does NOT file returns. It's
the numeric kernel used by CT preview screens and the VAT/CT dashboard.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

_TWO = Decimal("0.01")
_EXEMPT_THRESHOLD = Decimal("375000")
_CT_RATE = Decimal("0.09")
_SBR_MAX_REVENUE = Decimal("3000000")  # Small Business Relief revenue cap
_LOSS_CAP_RATIO = Decimal("0.75")


def _round2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


@dataclass
class CorporateTaxInput:
    revenue: Decimal                 # Total revenue (used for SBR eligibility)
    taxable_income: Decimal          # After deductions, before loss offset
    prior_period_revenue: Decimal = Decimal("0")
    loss_brought_forward: Decimal = Decimal("0")
    elect_small_business_relief: bool = False
    qfzp_qualifying_income: Decimal = Decimal("0")
    qfzp_non_qualifying_income: Decimal = Decimal("0")
    is_qfzp: bool = False


@dataclass
class CorporateTaxResult:
    taxable_income_after_losses: Decimal
    losses_utilized: Decimal
    losses_carried_forward: Decimal
    exempt_slab_used: Decimal
    taxable_above_exempt: Decimal
    ct_due: Decimal
    effective_rate: Decimal
    rule_applied: str                # 'sbr', 'qfzp', 'standard'
    notes: list[str] = field(default_factory=list)


def _sbr_eligible(inp: CorporateTaxInput) -> bool:
    return (
        inp.elect_small_business_relief
        and inp.revenue <= _SBR_MAX_REVENUE
        and inp.prior_period_revenue <= _SBR_MAX_REVENUE
    )


def calculate_corporate_tax(inp: CorporateTaxInput) -> CorporateTaxResult:
    notes: list[str] = []

    # Small Business Relief — 0% CT if elected and eligible.
    if _sbr_eligible(inp):
        notes.append("Small Business Relief applied — 0% CT through 31 Dec 2026.")
        return CorporateTaxResult(
            taxable_income_after_losses=_round2(inp.taxable_income),
            losses_utilized=Decimal("0"),
            losses_carried_forward=_round2(inp.loss_brought_forward),
            exempt_slab_used=_round2(min(inp.taxable_income, _EXEMPT_THRESHOLD)),
            taxable_above_exempt=Decimal("0"),
            ct_due=Decimal("0"),
            effective_rate=Decimal("0"),
            rule_applied="sbr",
            notes=notes,
        )

    # Qualifying Free Zone Person — 0% on qualifying income, 9% on rest,
    # AED 375K exemption does NOT apply to non-qualifying income.
    if inp.is_qfzp:
        non_q = max(inp.qfzp_non_qualifying_income, Decimal("0"))
        ct = _round2(non_q * _CT_RATE)
        notes.append(
            "QFZP applied — 0% on qualifying income; 9% on non-qualifying "
            "without AED 375K exemption."
        )
        total_income = inp.qfzp_qualifying_income + non_q
        effective = _round2(ct / total_income * 100) if total_income > 0 else Decimal("0")
        return CorporateTaxResult(
            taxable_income_after_losses=_round2(total_income),
            losses_utilized=Decimal("0"),
            losses_carried_forward=_round2(inp.loss_brought_forward),
            exempt_slab_used=Decimal("0"),
            taxable_above_exempt=_round2(non_q),
            ct_due=ct,
            effective_rate=effective,
            rule_applied="qfzp",
            notes=notes,
        )

    # Standard: apply 75% loss cap, then 0% up to 375K, 9% above.
    loss_cap = _round2(inp.taxable_income * _LOSS_CAP_RATIO)
    losses_utilized = min(inp.loss_brought_forward, loss_cap)
    if losses_utilized < inp.loss_brought_forward:
        notes.append(
            "Loss utilization capped at 75% of current-year taxable income."
        )
    taxable_after = _round2(inp.taxable_income - losses_utilized)
    exempt_used = min(taxable_after, _EXEMPT_THRESHOLD)
    above = max(taxable_after - _EXEMPT_THRESHOLD, Decimal("0"))
    ct = _round2(above * _CT_RATE)
    effective = _round2(ct / taxable_after * 100) if taxable_after > 0 else Decimal("0")
    return CorporateTaxResult(
        taxable_income_after_losses=taxable_after,
        losses_utilized=_round2(losses_utilized),
        losses_carried_forward=_round2(inp.loss_brought_forward - losses_utilized),
        exempt_slab_used=_round2(exempt_used),
        taxable_above_exempt=_round2(above),
        ct_due=ct,
        effective_rate=effective,
        rule_applied="standard",
        notes=notes,
    )
