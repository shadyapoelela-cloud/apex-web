"""4-layer matching engine for bank-reconciliation.

Layers (higher score = better match):
  L1  Exact match     amount + date ± 0 + reference match           (score 100)
  L2  Amount+date     amount equal, date ± 3 days                   (score 75)
  L3  Fuzzy payee     amount equal + Arabic-aware payee similarity   (score 50)
  L4  ML suggestion   vector similarity against historical coding    (score 25)

For Phase 1 we implement L1-L3. L4 is stubbed and wired behind a flag.

Arabic normalization: reuses the normalize_arabic helper logic (strip
diacritics, unify hamza, ta marbuta). Payee similarity uses Levenshtein
ratio on the normalized strings.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal
from enum import Enum
from typing import Optional

from app.integrations.bank_ocr.parsers import BankTransaction


class MatchScore(int, Enum):
    EXACT = 100
    AMOUNT_DATE = 75
    FUZZY_PAYEE = 50
    ML_SUGGESTED = 25


@dataclass
class MatchCandidate:
    """One possible match between a bank transaction and a ledger entry."""

    bank_txn: BankTransaction
    ledger_entry_id: str
    ledger_amount: Decimal
    ledger_date: date
    ledger_payee: str
    score: int
    layer: str
    reasons: list[str] = field(default_factory=list)


def normalize_arabic(s: str) -> str:
    """Arabic-aware normalization. Same rules as the Flutter command palette."""
    if not s:
        return ""
    out = s.lower()
    import re as _re

    # Strip diacritics (Tashkeel)
    out = _re.sub(r"[\u064B-\u065F\u0670]", "", out)
    # Unify alif forms
    out = _re.sub(r"[\u0622\u0623\u0625]", "\u0627", out)
    # Unify ya
    out = out.replace("\u0649", "\u064A")
    # Unify ta marbuta
    out = out.replace("\u0629", "\u0647")
    # Collapse whitespace
    out = _re.sub(r"\s+", " ", out).strip()
    return out


def _levenshtein_ratio(a: str, b: str) -> float:
    """Return 0..1 similarity. Dynamic programming; fine for short payee strings."""
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0
    m, n = len(a), len(b)
    # Classic DP table
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost,
            )
    dist = dp[m][n]
    max_len = max(m, n)
    return 1.0 - (dist / max_len)


@dataclass
class LedgerEntry:
    """Minimal ledger entry representation used by the matcher.

    Real integration reads these from the journal_entries table; this
    struct decouples the matcher from SQLAlchemy so it's trivially
    unit-testable.
    """

    id: str
    amount: Decimal
    entry_date: date
    payee: str
    reference: Optional[str] = None


class MatchEngine:
    """Applies L1-L3 matching layers to a batch of bank transactions."""

    def __init__(
        self,
        *,
        date_window_days: int = 3,
        fuzzy_threshold: float = 0.70,
    ):
        self.date_window_days = date_window_days
        self.fuzzy_threshold = fuzzy_threshold

    def match(
        self,
        bank_txn: BankTransaction,
        ledger: list[LedgerEntry],
    ) -> list[MatchCandidate]:
        """Return candidates sorted by score desc."""
        candidates: list[MatchCandidate] = []

        # L1: Exact amount + exact date + reference match
        for le in ledger:
            if le.amount != bank_txn.amount:
                continue
            if le.entry_date != bank_txn.txn_date:
                continue
            if bank_txn.reference and le.reference and bank_txn.reference == le.reference:
                candidates.append(
                    MatchCandidate(
                        bank_txn=bank_txn,
                        ledger_entry_id=le.id,
                        ledger_amount=le.amount,
                        ledger_date=le.entry_date,
                        ledger_payee=le.payee,
                        score=int(MatchScore.EXACT),
                        layer="L1_exact",
                        reasons=["same amount", "same date", "matching reference"],
                    )
                )

        if candidates:
            return sorted(candidates, key=lambda c: c.score, reverse=True)

        # L2: Amount equal, date within window
        window = timedelta(days=self.date_window_days)
        for le in ledger:
            if le.amount != bank_txn.amount:
                continue
            if abs((le.entry_date - bank_txn.txn_date).days) > self.date_window_days:
                continue
            candidates.append(
                MatchCandidate(
                    bank_txn=bank_txn,
                    ledger_entry_id=le.id,
                    ledger_amount=le.amount,
                    ledger_date=le.entry_date,
                    ledger_payee=le.payee,
                    score=int(MatchScore.AMOUNT_DATE),
                    layer="L2_amount_date",
                    reasons=[
                        "same amount",
                        f"date within ±{self.date_window_days} days",
                    ],
                )
            )

        if candidates:
            return sorted(candidates, key=lambda c: c.score, reverse=True)

        # L3: Fuzzy payee (Arabic-aware) + amount equal
        bank_payee_norm = normalize_arabic(bank_txn.description)
        for le in ledger:
            if le.amount != bank_txn.amount:
                continue
            le_payee_norm = normalize_arabic(le.payee)
            sim = _levenshtein_ratio(bank_payee_norm, le_payee_norm)
            if sim < self.fuzzy_threshold:
                continue
            score = int(MatchScore.FUZZY_PAYEE) + int((sim - self.fuzzy_threshold) * 25)
            candidates.append(
                MatchCandidate(
                    bank_txn=bank_txn,
                    ledger_entry_id=le.id,
                    ledger_amount=le.amount,
                    ledger_date=le.entry_date,
                    ledger_payee=le.payee,
                    score=min(score, int(MatchScore.FUZZY_PAYEE) + 24),
                    layer="L3_fuzzy_payee",
                    reasons=[
                        "same amount",
                        f"payee similarity {sim:.2f} (Arabic-normalized)",
                    ],
                )
            )

        return sorted(candidates, key=lambda c: c.score, reverse=True)

    def best_match(
        self,
        bank_txn: BankTransaction,
        ledger: list[LedgerEntry],
    ) -> Optional[MatchCandidate]:
        """Convenience: return only the top candidate, or None if no match."""
        candidates = self.match(bank_txn, ledger)
        return candidates[0] if candidates else None
