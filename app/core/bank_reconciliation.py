"""
APEX — AI bank reconciliation scoring + guardrail-gated auto-match (Wave 15).

Wave 13 ingested bank feed transactions; Wave 14 let a human reconcile
them one-by-one in the UI. Wave 15 closes the loop: score every
(bank_transaction, candidate_entry) pair against a weighted feature
vector, and push the top proposal through the Wave 7 AI guardrail so
high-confidence matches auto-post while weak ones land in the review
queue.

Scoring weights (sum to 1.0) — chosen so amount dominates (two
transactions that differ in SAR are almost certainly not the same
payment) and description is a tiebreaker, not a driver:

    _W_AMOUNT = 0.50   # exact-amount match is the strongest signal
    _W_DATE   = 0.25   # same-day / within-window
    _W_VENDOR = 0.20   # fuzzy-equal on normalized vendor/counterparty
    _W_DESC   = 0.05   # token overlap on descriptions

Feature functions are pure and operate on plain dicts so the same code
runs against BankFeedTransaction rows, OCR output, CSV uploads, or
in-memory fixtures with zero adaptation — same pattern as Wave 3
anomaly_detector.

Contract:

    bank_tx   = {"id", "amount", "date", "vendor", "description"}
    candidate = {"id", "amount", "date", "vendor", "description"}

    proposals = propose_matches(bank_tx, candidates, date_window_days=7)
    # [{"candidate_id", "score", "amount_score", "date_score",
    #   "vendor_score", "desc_score"}, ...] ranked desc.

    result = auto_match_via_guardrail(
        bank_tx, candidates,
        bank_tx_id="BT-1", entity_type="journal_entry",
        tenant_id="t1",
    )
    # {"verdict", "row_id", "score", "best_candidate_id", "matched"}
    # verdict comes from app.core.ai_guardrails — AUTO_APPLIED posts
    # the reconciliation via bank_feeds.mark_reconciled; NEEDS_APPROVAL
    # waits for a human to approve via /ai/guardrails/{id}/approve.
"""

from __future__ import annotations

import logging
import re
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, Iterable, List, Optional

from app.core.ai_guardrails import GuardedDecision, Suggestion, Verdict, guard

logger = logging.getLogger(__name__)


# ── Scoring weights ────────────────────────────────────────────────────
#
# Tuned so amount dominates (50%), date is the second signal (25%),
# vendor is meaningful but noisier (20%), and description is a 5%
# tiebreaker. Sum = 1.0.

_W_AMOUNT = 0.50
_W_DATE = 0.25
_W_VENDOR = 0.20
_W_DESC = 0.05


# Sanity check so a future edit can't silently drift the weights.
assert abs(_W_AMOUNT + _W_DATE + _W_VENDOR + _W_DESC - 1.0) < 1e-9, (
    "bank_reconciliation scoring weights must sum to 1.0"
)


_DEFAULT_DATE_WINDOW_DAYS = 7
_DEFAULT_TOP_K = 5
_DEFAULT_MIN_SCORE_FOR_PROPOSE = 0.3

# Guardrail floor: below this, AUTO_APPLIED cannot fire. The guardrail
# itself enforces its own min_confidence (default 0.95 from Wave 7).
_AUTO_MATCH_CONFIDENCE = 0.95


# ── Normalization helpers (shared idiom with anomaly_detector) ────────


_ARABIC_FOLD = {
    "\u0622": "\u0627",  # آ -> ا
    "\u0623": "\u0627",  # أ -> ا
    "\u0625": "\u0627",  # إ -> ا
    "\u0649": "\u064A",  # ى -> ي
    "\u0629": "\u0647",  # ة -> ه
    "\u0640": "",  # tatweel
}

_WS_RE = re.compile(r"\s+")


def _fold(s: Optional[str]) -> str:
    """Fold Arabic + Latin text for fuzzy comparison: NFKD + strip
    diacritics + normalize alef/yeh/teh-marbuta + lower + collapse
    whitespace."""
    if not s:
        return ""
    t = unicodedata.normalize("NFKD", s)
    t = "".join(c for c in t if not unicodedata.combining(c))
    for src, dst in _ARABIC_FOLD.items():
        t = t.replace(src, dst)
    t = t.lower().strip()
    t = _WS_RE.sub(" ", t)
    return t


def _tokens(s: Optional[str]) -> set:
    folded = _fold(s)
    if not folded:
        return set()
    return {tok for tok in folded.split(" ") if tok}


def _to_decimal(v: Any) -> Optional[Decimal]:
    if v is None:
        return None
    if isinstance(v, Decimal):
        return v
    try:
        return Decimal(str(v))
    except (InvalidOperation, ValueError):
        return None


def _to_date(v: Any) -> Optional[date]:
    if v is None:
        return None
    if isinstance(v, datetime):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, str):
        # Accept either YYYY-MM-DD or full ISO timestamp.
        try:
            return datetime.fromisoformat(v.replace("Z", "+00:00")).date()
        except ValueError:
            pass
        try:
            return datetime.strptime(v[:10], "%Y-%m-%d").date()
        except ValueError:
            return None
    return None


# ── Feature scores (each returns a float in [0.0, 1.0]) ───────────────


def _amount_score(a: Optional[Decimal], b: Optional[Decimal]) -> float:
    """1.0 when identical. Decays linearly with relative difference so
    a 10 SAR vs 10.02 SAR pair still scores ~0.998, while 10 SAR vs
    1000 SAR scores near zero. Returns 0.0 when either side is missing
    or either is zero with the other non-zero."""
    if a is None or b is None:
        return 0.0
    if a == 0 and b == 0:
        return 1.0
    if a == 0 or b == 0:
        return 0.0
    # Compare magnitudes; sign mismatch (credit vs debit) drops to 0
    # because a bank credit cannot reconcile a book debit.
    if (a > 0) != (b > 0):
        return 0.0
    diff = abs(a - b)
    denom = max(abs(a), abs(b))
    if denom == 0:
        return 0.0
    ratio = float(diff / denom)
    return max(0.0, 1.0 - ratio)


def _date_score(a: Optional[date], b: Optional[date], window_days: int) -> float:
    """1.0 when same day. Decays linearly across the window. 0.0 once
    |diff| ≥ window_days. Missing either side → 0.0."""
    if a is None or b is None:
        return 0.0
    if window_days <= 0:
        return 1.0 if a == b else 0.0
    days = abs((a - b).days)
    if days >= window_days:
        return 0.0
    return 1.0 - (days / window_days)


def _vendor_score(a: Optional[str], b: Optional[str]) -> float:
    """1.0 on normalized equality. Token-Jaccard otherwise. Either
    side empty → 0.0 (no evidence either way shouldn't boost the
    overall score)."""
    fa, fb = _fold(a), _fold(b)
    if not fa or not fb:
        return 0.0
    if fa == fb:
        return 1.0
    ta, tb = _tokens(fa), _tokens(fb)
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    union = len(ta | tb)
    return inter / union if union else 0.0


def _desc_score(a: Optional[str], b: Optional[str]) -> float:
    """Token-Jaccard over descriptions. Description is the lowest-
    weight feature so noisy matches don't dominate."""
    ta, tb = _tokens(a), _tokens(b)
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    union = len(ta | tb)
    return inter / union if union else 0.0


# ── Public scoring API ────────────────────────────────────────────────


@dataclass
class ScoreBreakdown:
    """Per-feature scores plus the weighted total. Returned alongside
    the candidate_id so UI can render a tooltip explaining *why* the
    system thinks it matches."""

    amount: float
    date: float
    vendor: float
    desc: float
    total: float

    def to_dict(self) -> Dict[str, float]:
        return {
            "amount_score": round(self.amount, 4),
            "date_score": round(self.date, 4),
            "vendor_score": round(self.vendor, 4),
            "desc_score": round(self.desc, 4),
            "score": round(self.total, 4),
        }


def score_pair(
    bank_tx: Dict[str, Any],
    candidate: Dict[str, Any],
    *,
    date_window_days: int = _DEFAULT_DATE_WINDOW_DAYS,
) -> ScoreBreakdown:
    """Compute the weighted score for one (bank_tx, candidate) pair."""
    s_amt = _amount_score(
        _to_decimal(bank_tx.get("amount")),
        _to_decimal(candidate.get("amount")),
    )
    s_date = _date_score(
        _to_date(bank_tx.get("date")),
        _to_date(candidate.get("date")),
        date_window_days,
    )
    s_vendor = _vendor_score(
        bank_tx.get("vendor") or bank_tx.get("counterparty"),
        candidate.get("vendor") or candidate.get("counterparty"),
    )
    s_desc = _desc_score(
        bank_tx.get("description"),
        candidate.get("description"),
    )
    total = (
        _W_AMOUNT * s_amt
        + _W_DATE * s_date
        + _W_VENDOR * s_vendor
        + _W_DESC * s_desc
    )
    return ScoreBreakdown(
        amount=s_amt, date=s_date, vendor=s_vendor, desc=s_desc, total=total
    )


def propose_matches(
    bank_tx: Dict[str, Any],
    candidates: Iterable[Dict[str, Any]],
    *,
    date_window_days: int = _DEFAULT_DATE_WINDOW_DAYS,
    min_score: float = _DEFAULT_MIN_SCORE_FOR_PROPOSE,
    top_k: int = _DEFAULT_TOP_K,
) -> List[Dict[str, Any]]:
    """Score `bank_tx` against each candidate and return the top_k
    whose score ≥ min_score, ranked descending.

    Each row:
        {"candidate_id", "score", "amount_score", "date_score",
         "vendor_score", "desc_score"}

    `min_score` defaults to 0.3 so the API surface returns only
    plausible pairs. Callers that want every proposal (e.g. the
    guardrail pipeline, which does its own gating) should pass
    min_score=0.0.
    """
    scored: List[Dict[str, Any]] = []
    for cand in candidates:
        breakdown = score_pair(
            bank_tx, cand, date_window_days=date_window_days
        )
        if breakdown.total < min_score:
            continue
        row = {"candidate_id": cand.get("id")}
        row.update(breakdown.to_dict())
        scored.append(row)

    scored.sort(key=lambda r: r["score"], reverse=True)
    if top_k and top_k > 0:
        scored = scored[:top_k]
    return scored


# ── Guardrail-gated auto-match ────────────────────────────────────────


@dataclass
class AutoMatchResult:
    """Outcome of auto_match_via_guardrail. `row_id` is the
    AiSuggestion id — callers can show it in the UI and poll for
    approval. `matched` is True only when the guardrail auto-applied
    AND the downstream reconcile succeeded."""

    verdict: str
    row_id: Optional[str]
    score: float
    best_candidate_id: Optional[str]
    reason: str
    matched: bool

    def to_dict(self) -> Dict[str, Any]:
        return {
            "verdict": self.verdict,
            "row_id": self.row_id,
            "score": round(self.score, 4),
            "best_candidate_id": self.best_candidate_id,
            "reason": self.reason,
            "matched": self.matched,
        }


def auto_match_via_guardrail(
    bank_tx: Dict[str, Any],
    candidates: Iterable[Dict[str, Any]],
    *,
    bank_tx_id: Optional[str] = None,
    entity_type: str = "journal_entry",
    tenant_id: Optional[str] = None,
    user_id: Optional[str] = None,
    min_confidence: float = _AUTO_MATCH_CONFIDENCE,
    destructive: bool = False,
    **score_kwargs: Any,
) -> AutoMatchResult:
    """Score → pick top candidate → gate through ai_guardrails.guard().

    On AUTO_APPLIED, this function attempts to post the reconciliation
    via bank_feeds.mark_reconciled() when `bank_tx_id` is supplied.
    The import is local so the module can be unit-tested without the
    bank_feeds DB dependency (matches the Wave 7 guardrail pattern).

    Extra score_kwargs (date_window_days, top_k) flow through to
    propose_matches. We pin `min_score=0.0` for the gating pipeline so
    the guardrail is the only filter — otherwise a borderline score
    like 0.28 would be silently dropped instead of being routed to
    needs_approval.
    """
    score_kwargs.setdefault("min_score", 0.0)
    proposals = propose_matches(bank_tx, candidates, **score_kwargs)

    if not proposals:
        return AutoMatchResult(
            verdict=Verdict.REJECTED.value,
            row_id=None,
            score=0.0,
            best_candidate_id=None,
            reason="لا يوجد مرشحون للمطابقة.",
            matched=False,
        )

    top = proposals[0]
    top_score = float(top["score"])
    top_candidate_id = top["candidate_id"]

    sug = Suggestion(
        source="bank_reconciliation",
        action_type="match_bank_transaction",
        target_type="bank_feed_transaction",
        target_id=bank_tx_id or str(bank_tx.get("id") or ""),
        after={
            "bank_tx_id": bank_tx_id or bank_tx.get("id"),
            "candidate_id": top_candidate_id,
            "entity_type": entity_type,
            "score_breakdown": {
                k: top[k]
                for k in ("amount_score", "date_score", "vendor_score", "desc_score")
                if k in top
            },
        },
        confidence=top_score,
        reasoning=(
            f"أعلى نتيجة {round(top_score * 100, 1)}% — "
            f"amount={round(top.get('amount_score', 0), 3)} "
            f"date={round(top.get('date_score', 0), 3)} "
            f"vendor={round(top.get('vendor_score', 0), 3)} "
            f"desc={round(top.get('desc_score', 0), 3)}"
        ),
        destructive=destructive,
        tenant_id=tenant_id,
        min_confidence=min_confidence,
    )

    decision: GuardedDecision = guard(sug)
    matched = False

    if decision.verdict == Verdict.AUTO_APPLIED and bank_tx_id:
        try:
            # Local import: keeps the unit-test surface of the scoring
            # math free of the bank_feeds DB dependency, and sidesteps
            # any circular import if bank_feeds later wants to import
            # from this module.
            from app.core.bank_feeds import mark_reconciled

            mark_reconciled(
                bank_tx_id,
                entity_type=entity_type,
                entity_id=str(top_candidate_id),
                user_id=user_id or "ai:bank_reconciliation",
            )
            matched = True
        except LookupError:
            # bank_tx_id points at a row that doesn't exist — the
            # guardrail decision still stands; the caller sees
            # matched=False and can investigate. Don't swallow silently.
            logger.warning(
                "auto_match_via_guardrail: bank_tx_id %r not found in "
                "bank_feed_transaction; guardrail auto-applied but "
                "reconciliation was skipped.",
                bank_tx_id,
            )
        except Exception:  # pragma: no cover — defensive
            logger.exception(
                "auto_match_via_guardrail: mark_reconciled failed for %r",
                bank_tx_id,
            )

    return AutoMatchResult(
        verdict=decision.verdict.value,
        row_id=decision.row_id,
        score=top_score,
        best_candidate_id=top_candidate_id,
        reason=decision.reason,
        matched=matched,
    )
