"""Multi-Entity Consolidation — intercompany elimination + FX translation.

Extends the existing consolidation service (app/core/consolidation_service.py)
with the two features required for IFRS-compliant group reporting:

  1. Intercompany elimination — when Entity A sells to Entity B, the
     consolidated view must remove both the revenue and the receivable so
     external users see the group as one economic unit.

  2. FX translation — subsidiary books are in local currency (e.g. AED).
     Group reports in presentation currency (e.g. SAR). We apply rates:
       • Current rate for balance sheet items
       • Average rate for income statement
       • Historical rate for equity
     Translation differences accumulate in CTA (Cumulative Translation
     Adjustment) in equity.

This module intentionally stays calculator-shaped (pure functions) so the
host routes/screens can compose multiple entities + periods without
touching the DB.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

logger = logging.getLogger(__name__)

_TWO = Decimal("0.01")


def _r2(v: Decimal) -> Decimal:
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


# ── Data types ────────────────────────────────────────────


@dataclass
class IntercompanyLine:
    """One leg of an intercompany transaction.

    Example: Entity A sells 100 SAR of software to Entity B.
      Entity A books: DR Receivable 100 / CR Revenue 100
      Entity B books: DR Expense 100    / CR Payable 100

    When consolidating A+B, we eliminate:
      • Revenue (A) + Expense (B) — both flow through
      • Receivable (A) + Payable (B) — both on balance sheet
    """

    entity_id: str
    counterparty_entity_id: str
    account_code: str
    amount: Decimal                 # signed: +debit / -credit
    currency: str
    reference: Optional[str] = None


@dataclass
class IntercompanyPair:
    left: IntercompanyLine
    right: IntercompanyLine
    elimination_amount: Decimal
    matched: bool
    variance: Decimal                # difference if not fully matching
    notes: list[str] = field(default_factory=list)


def match_intercompany_lines(
    lines: list[IntercompanyLine],
    tolerance: Decimal = Decimal("0.01"),
) -> tuple[list[IntercompanyPair], list[IntercompanyLine]]:
    """Pair up intercompany legs so we can eliminate them.

    Matching rule: same (reference, currency), opposite signs, within
    `tolerance`. Unmatched lines are flagged for human review.

    Returns (pairs, unmatched).
    """
    pairs: list[IntercompanyPair] = []
    unmatched: list[IntercompanyLine] = []
    # Naive O(n²) matcher — acceptable for typical monthly IC volumes
    # (tens of lines). Swap for index if needed later.
    consumed: set[int] = set()
    for i, a in enumerate(lines):
        if i in consumed:
            continue
        partner_idx = None
        for j, b in enumerate(lines):
            if j == i or j in consumed:
                continue
            if (
                a.counterparty_entity_id == b.entity_id
                and a.entity_id == b.counterparty_entity_id
                and a.currency == b.currency
                and a.reference == b.reference
                and ((a.amount > 0) != (b.amount > 0))  # opposite signs
                and abs(a.amount + b.amount) <= tolerance
            ):
                partner_idx = j
                break
        if partner_idx is not None:
            b = lines[partner_idx]
            variance = _r2(a.amount + b.amount)
            pairs.append(IntercompanyPair(
                left=a, right=b,
                elimination_amount=_r2(abs(a.amount)),
                matched=abs(variance) <= tolerance,
                variance=variance,
            ))
            consumed.update({i, partner_idx})
        else:
            unmatched.append(a)
    return pairs, unmatched


# ── FX translation ────────────────────────────────────────


@dataclass
class FxRate:
    currency_from: str
    currency_to: str
    rate_current: Decimal           # balance sheet items (end of period)
    rate_average: Decimal           # income statement items
    rate_historical: Optional[Decimal] = None  # equity components


@dataclass
class TranslatedLine:
    """One line translated to the presentation currency."""

    account_code: str
    account_type: str               # 'asset', 'liability', 'equity', 'revenue', 'expense'
    original_amount: Decimal
    original_currency: str
    translated_amount: Decimal
    translated_currency: str
    rate_used: Decimal
    rate_basis: str                 # 'current', 'average', 'historical'


def _pick_rate(account_type: str, rate: FxRate) -> tuple[Decimal, str]:
    """Choose which rate to use based on the IFRS rules."""
    if account_type in ("revenue", "expense"):
        return rate.rate_average, "average"
    if account_type == "equity" and rate.rate_historical is not None:
        return rate.rate_historical, "historical"
    # Default — current rate for assets / liabilities / equity without history
    return rate.rate_current, "current"


def translate_trial_balance(
    tb_lines: list[dict],
    rate: FxRate,
) -> tuple[list[TranslatedLine], Decimal]:
    """Translate a trial balance into a presentation currency.

    `tb_lines` is a list of {account_code, account_type, amount, currency}.
    Returns (translated_lines, cta).
    CTA (Cumulative Translation Adjustment) = residual so
    sum(translated_assets - translated_liabilities - translated_equity) = 0.
    """
    translated: list[TranslatedLine] = []
    total_assets = Decimal("0")
    total_liab = Decimal("0")
    total_equity = Decimal("0")
    total_ie = Decimal("0")  # net income contribution

    for line in tb_lines:
        amt = Decimal(str(line["amount"]))
        acct_type = line["account_type"]
        ccy = line.get("currency", rate.currency_from)
        if ccy != rate.currency_from:
            # Skip anything in a different source currency — out of scope here.
            continue
        r, basis = _pick_rate(acct_type, rate)
        translated_amt = _r2(amt * r)
        translated.append(TranslatedLine(
            account_code=line["account_code"],
            account_type=acct_type,
            original_amount=amt,
            original_currency=ccy,
            translated_amount=translated_amt,
            translated_currency=rate.currency_to,
            rate_used=r,
            rate_basis=basis,
        ))
        if acct_type == "asset":
            total_assets += translated_amt
        elif acct_type == "liability":
            total_liab += translated_amt
        elif acct_type == "equity":
            total_equity += translated_amt
        else:
            total_ie += translated_amt

    # CTA balances the equation. Assets = Liabilities + Equity + Net Income + CTA
    cta = _r2(total_assets - total_liab - total_equity - total_ie)
    return translated, cta


# ── Minority interest ────────────────────────────────────


@dataclass
class MinorityInterestResult:
    subsidiary_net_income: Decimal
    ownership_pct: Decimal          # 0..100
    majority_share: Decimal
    minority_share: Decimal         # goes to "non-controlling interest" in equity


def compute_minority_interest(
    subsidiary_net_income: Decimal,
    ownership_pct: Decimal,
) -> MinorityInterestResult:
    """Split a subsidiary's net income between majority + minority owners."""
    pct = max(Decimal("0"), min(Decimal("100"), ownership_pct))
    majority = _r2(subsidiary_net_income * pct / Decimal("100"))
    minority = _r2(subsidiary_net_income - majority)
    return MinorityInterestResult(
        subsidiary_net_income=_r2(subsidiary_net_income),
        ownership_pct=pct,
        majority_share=majority,
        minority_share=minority,
    )
