"""AI-assisted bank reconciliation.

Given an unreconciled bank-feed row, propose the top-N journal entries
(or invoices) that are likely matches. Each candidate comes back with a
0–1 confidence score and a short Arabic rationale. The UI renders these
as cards; one tap by the accountant locks in the match via
`mark_reconciled()`.

Scoring heuristics (deterministic, fast, local — no LLM call):
  • Amount match (absolute): ±0.01 SAR         → +0.50
  • Amount match (within 1%)                   → +0.30
  • Date proximity (same day)                  → +0.20
  • Date proximity (within 3 days)             → +0.10
  • Date proximity (within 7 days)             → +0.05
  • Description / counterparty keyword overlap → +0.15 per match (cap 0.30)

Threshold for surfacing a suggestion: score >= 0.30 (tunable).
Auto-apply threshold (hands-off): score >= 0.95 (matches product guardrail).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Any, Optional

logger = logging.getLogger(__name__)


@dataclass
class ReconciliationSuggestion:
    txn_id: str
    candidate_type: str             # "journal_entry" | "invoice"
    candidate_id: str
    candidate_label: str
    candidate_amount: float
    confidence: float               # 0.0–1.0
    reasons: list[str]              # human-readable Arabic rationale
    auto_apply_recommended: bool    # true when confidence >= 0.95

    def to_dict(self) -> dict[str, Any]:
        return {
            "txn_id": self.txn_id,
            "candidate_type": self.candidate_type,
            "candidate_id": self.candidate_id,
            "candidate_label": self.candidate_label,
            "candidate_amount": self.candidate_amount,
            "confidence": self.confidence,
            "reasons": self.reasons,
            "auto_apply_recommended": self.auto_apply_recommended,
        }


def _keyword_overlap(a: Optional[str], b: Optional[str]) -> int:
    """Count shared >=4-char tokens (case-insensitive). Works on mixed-
    language strings (Arabic + Latin) since tokenization is by whitespace.
    """
    if not a or not b:
        return 0
    wa = {w.lower() for w in a.split() if len(w) >= 4}
    wb = {w.lower() for w in b.split() if len(w) >= 4}
    return len(wa & wb)


def suggest_matches_for_transaction(
    txn_id: str,
    *,
    limit: int = 5,
    min_confidence: float = 0.30,
    tenant_id: Optional[str] = None,
) -> list[dict[str, Any]]:
    """Return the top-`limit` candidate matches for one bank-feed row.

    Defensive: returns [] if the tables aren't loaded or the txn is
    already reconciled. Never raises.
    """
    try:
        from sqlalchemy import and_
        from app.phase1.models.platform_models import SessionLocal
        from app.core.compliance_models import BankFeedTransaction
    except Exception as e:
        logger.debug("suggest_matches: core layer unavailable (%s)", e)
        return []

    db = SessionLocal()
    try:
        txn = db.query(BankFeedTransaction).filter(BankFeedTransaction.id == txn_id).first()
        if txn is None or txn.matched_entity_id is not None:
            return []

        try:
            txn_amount = Decimal(str(txn.amount))
        except Exception:
            return []
        txn_date = txn.txn_date
        if isinstance(txn_date, datetime):
            txn_date = txn_date.date()
        tid = tenant_id or txn.tenant_id

        # Candidate pool: journal entries within ±7 days and matching
        # amount within 5%. Keeps the scan cheap even at 10K postings.
        try:
            from app.pilot.models import JournalEntry, JournalLine
        except Exception:
            return []

        low = txn_amount * Decimal("0.95")
        high = txn_amount * Decimal("1.05")
        day_lo = txn_date - timedelta(days=7)
        day_hi = txn_date + timedelta(days=7)

        je_candidates = (
            db.query(JournalEntry)
            .filter(
                and_(
                    JournalEntry.je_date >= day_lo,
                    JournalEntry.je_date <= day_hi,
                    JournalEntry.total_debit >= low,
                    JournalEntry.total_debit <= high,
                )
            )
        )
        if tid:
            je_candidates = je_candidates.filter(JournalEntry.tenant_id == tid)
        je_rows = je_candidates.limit(50).all()

        suggestions: list[ReconciliationSuggestion] = []
        for je in je_rows:
            score = 0.0
            reasons: list[str] = []
            je_amt = Decimal(str(je.total_debit or 0))
            # Amount scoring
            diff = abs(je_amt - txn_amount)
            if diff < Decimal("0.01"):
                score += 0.50
                reasons.append("المبلغ مطابق تماماً")
            elif txn_amount > 0 and (diff / txn_amount) <= Decimal("0.01"):
                score += 0.30
                reasons.append("المبلغ يتطابق بفارق أقل من 1%")
            # Date scoring
            je_d = je.je_date
            if isinstance(je_d, datetime):
                je_d = je_d.date()
            day_diff = abs((je_d - txn_date).days)
            if day_diff == 0:
                score += 0.20
                reasons.append("نفس يوم الحركة")
            elif day_diff <= 3:
                score += 0.10
                reasons.append(f"خلال {day_diff} أيام من الحركة")
            elif day_diff <= 7:
                score += 0.05
                reasons.append(f"خلال {day_diff} أيام من الحركة")

            # Description overlap — memo vs txn.description / counterparty
            overlap_memo = _keyword_overlap(je.memo_ar, txn.description)
            overlap_cp = _keyword_overlap(je.memo_ar, txn.counterparty)
            if overlap_memo or overlap_cp:
                bonus = min(0.30, 0.15 * (overlap_memo + overlap_cp))
                score += bonus
                reasons.append(f"تشابه في الوصف ({overlap_memo + overlap_cp} كلمات)")

            if score >= min_confidence:
                suggestions.append(ReconciliationSuggestion(
                    txn_id=txn.id,
                    candidate_type="journal_entry",
                    candidate_id=je.id,
                    candidate_label=f"{je.je_number} — {je.memo_ar}",
                    candidate_amount=float(je_amt),
                    confidence=round(min(score, 1.0), 3),
                    reasons=reasons,
                    auto_apply_recommended=score >= 0.95,
                ))

        # Highest-confidence first.
        suggestions.sort(key=lambda s: s.confidence, reverse=True)
        return [s.to_dict() for s in suggestions[:limit]]
    except Exception as e:
        logger.warning("suggest_matches_for_transaction failed: %s", e)
        return []
    finally:
        try:
            db.close()
        except Exception:
            pass


def auto_match_all(
    *,
    tenant_id: Optional[str] = None,
    confidence_floor: float = 0.95,
    limit: int = 100,
) -> dict[str, Any]:
    """Find every unreconciled row whose top suggestion clears the
    auto-apply floor and mark it reconciled. Run nightly or on demand
    from the UI. Returns counters."""
    try:
        from app.core.bank_feeds import list_transactions, mark_reconciled
    except Exception:
        return {"considered": 0, "matched": 0, "skipped": 0}

    txns = list_transactions(tenant_id=tenant_id, unreconciled_only=True, limit=limit)
    matched = 0
    skipped = 0
    for t in txns:
        sugs = suggest_matches_for_transaction(t["id"], limit=1, tenant_id=tenant_id)
        if sugs and sugs[0]["confidence"] >= confidence_floor:
            try:
                mark_reconciled(
                    t["id"],
                    entity_type=sugs[0]["candidate_type"],
                    entity_id=sugs[0]["candidate_id"],
                    user_id="ai:auto_match",
                )
                matched += 1
            except Exception:
                skipped += 1
        else:
            skipped += 1
    return {"considered": len(txns), "matched": matched, "skipped": skipped}
