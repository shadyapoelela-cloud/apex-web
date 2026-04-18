"""
APEX — AI guardrails: confidence-gated autopilot (Wave 7 PR#1).

Pattern #102 from APEX_GLOBAL_RESEARCH_210:
"Confidence-gated Autopilot (≥95% فقط يُنشر تلقائياً) — يمنع posting
سيئ صامت".

The guardrail stands between any AI module (Copilot, COA classifier,
receipt OCR, vendor matcher) and the real write. Every suggestion is
evaluated against:

1. Confidence floor. Suggestions with confidence < min_confidence
   (default 0.95) never auto-apply — they land in needs_approval.
2. Destructive flag. Anything that deletes, reverses, or posts a
   journal entry requires human approval regardless of confidence.
3. Sanity floor. Confidence ≤ 0 or > 1 is rejected outright to guard
   against model bugs.

Contract for callers:

    from app.core.ai_guardrails import guard, Suggestion, Verdict

    sug = Suggestion(
        source="copilot",
        action_type="categorize_txn",
        target_type="transaction",
        target_id="TXN-42",
        after={"category": "Travel"},
        confidence=0.97,
        reasoning="Model matched vendor 'Marriott' against Travel bucket.",
    )
    result = guard(sug)
    if result.verdict == Verdict.AUTO_APPLIED:
        apply_to_db(sug)  # caller's responsibility — guardrail is advisory

Every decision is persisted as an AiSuggestion row and emits an audit
event via the Wave 1 tamper-evident chain.
"""

from __future__ import annotations

import enum
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.core.compliance_models import AiSuggestion
from app.core.compliance_service import write_audit_event
from app.phase1.models.platform_models import SessionLocal, gen_uuid

logger = logging.getLogger(__name__)


# ── Public types ──────────────────────────────────────────────────────


class Verdict(str, enum.Enum):
    AUTO_APPLIED = "auto_applied"
    NEEDS_APPROVAL = "needs_approval"
    REJECTED = "rejected"
    APPROVED = "approved"


# Terminal statuses for transitions.
_TERMINAL = {Verdict.AUTO_APPLIED.value, Verdict.APPROVED.value, Verdict.REJECTED.value}


@dataclass
class Suggestion:
    """Input to the guardrail. `confidence` is a float in [0.0, 1.0]."""

    source: str
    action_type: str
    after: Dict[str, Any]
    confidence: float
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    before: Optional[Dict[str, Any]] = None
    reasoning: Optional[str] = None
    destructive: bool = False
    tenant_id: Optional[str] = None
    # Optional hook for callers that want to override the global floor.
    min_confidence: Optional[float] = None


@dataclass
class GuardedDecision:
    """Result returned by guard(). row_id + verdict are the essentials;
    `reason` explains which branch of the gate fired so logs + UI can
    show it without a second round-trip."""

    row_id: str
    verdict: Verdict
    reason: str
    persisted: bool = True


# ── Constants ─────────────────────────────────────────────────────────


_DEFAULT_MIN_CONFIDENCE = 0.95


# ── Core evaluator (pure, no DB) ──────────────────────────────────────


def _evaluate(sug: Suggestion, min_confidence: float) -> (Verdict, str):
    """Return the verdict + human-readable Arabic reason. Pure function
    so the decision can be unit-tested without touching the DB."""
    if sug.confidence is None or not (0.0 <= sug.confidence <= 1.0):
        return Verdict.REJECTED, "الثقة خارج المدى المسموح [0, 1]."

    if sug.destructive:
        return Verdict.NEEDS_APPROVAL, "إجراء تدميري — يتطلب موافقة بشرية دائمًا."

    if sug.confidence >= min_confidence:
        pct = round(sug.confidence * 100, 1)
        return (
            Verdict.AUTO_APPLIED,
            f"ثقة {pct}% فوق الحد الأدنى ({round(min_confidence * 100, 1)}%).",
        )

    pct = round(sug.confidence * 100, 1)
    floor = round(min_confidence * 100, 1)
    return (
        Verdict.NEEDS_APPROVAL,
        f"ثقة {pct}% دون الحد ({floor}%) — يلزم مراجعة.",
    )


# ── Public API ────────────────────────────────────────────────────────


def guard(sug: Suggestion) -> GuardedDecision:
    """Evaluate the suggestion, persist it, and emit an audit event.

    Returns the GuardedDecision. The caller inspects .verdict and, when
    it's AUTO_APPLIED, writes the underlying domain change — the
    guardrail does not touch domain tables.
    """
    min_confidence = (
        sug.min_confidence
        if sug.min_confidence is not None
        else _DEFAULT_MIN_CONFIDENCE
    )
    verdict, reason = _evaluate(sug, min_confidence)

    db = SessionLocal()
    try:
        row = AiSuggestion(
            id=gen_uuid(),
            tenant_id=sug.tenant_id,
            source=sug.source,
            action_type=sug.action_type,
            target_type=sug.target_type,
            target_id=sug.target_id,
            before_json=sug.before,
            after_json=sug.after,
            reasoning=sug.reasoning,
            confidence=int(round(max(0.0, min(1.0, sug.confidence)) * 1000)),
            destructive=1 if sug.destructive else 0,
            status=verdict.value,
            gate_reason=reason[:120],
        )
        db.add(row)
        db.commit()
        row_id = row.id
    finally:
        db.close()

    write_audit_event(
        action=f"ai.gate.{verdict.value}",
        entity_type="ai_suggestion",
        entity_id=row_id,
        metadata={
            "source": sug.source,
            "action_type": sug.action_type,
            "confidence": sug.confidence,
            "destructive": sug.destructive,
        },
    )
    return GuardedDecision(row_id=row_id, verdict=verdict, reason=reason)


def approve(row_id: str, user_id: str) -> Verdict:
    """Human approves a pending suggestion. Idempotent when already
    approved — re-runs are a no-op. Raises if the row is terminal in
    a non-approved state (auto_applied, rejected)."""
    db = SessionLocal()
    try:
        row = db.query(AiSuggestion).filter(AiSuggestion.id == row_id).first()
        if row is None:
            raise LookupError(f"suggestion {row_id} not found")
        if row.status == Verdict.APPROVED.value:
            return Verdict.APPROVED
        if row.status in _TERMINAL and row.status != Verdict.APPROVED.value:
            raise ValueError(
                f"cannot approve suggestion in terminal state {row.status!r}"
            )
        row.status = Verdict.APPROVED.value
        row.approved_by = user_id
        row.approved_at = datetime.now(timezone.utc)
        db.commit()
    finally:
        db.close()

    write_audit_event(
        action="ai.gate.approved",
        actor_user_id=user_id,
        entity_type="ai_suggestion",
        entity_id=row_id,
    )
    return Verdict.APPROVED


def reject(row_id: str, user_id: str, reason: Optional[str] = None) -> Verdict:
    """Human rejects a suggestion. Allowed from needs_approval *or*
    auto_applied (treated as a retroactive takedown). Not allowed once
    already rejected (idempotent no-op)."""
    db = SessionLocal()
    try:
        row = db.query(AiSuggestion).filter(AiSuggestion.id == row_id).first()
        if row is None:
            raise LookupError(f"suggestion {row_id} not found")
        if row.status == Verdict.REJECTED.value:
            return Verdict.REJECTED
        row.status = Verdict.REJECTED.value
        row.rejected_by = user_id
        row.rejected_at = datetime.now(timezone.utc)
        if reason:
            row.rejection_reason = reason
        db.commit()
    finally:
        db.close()

    write_audit_event(
        action="ai.gate.rejected_by_human",
        actor_user_id=user_id,
        entity_type="ai_suggestion",
        entity_id=row_id,
        metadata={"reason": reason},
    )
    return Verdict.REJECTED


# ── Read-side helpers (for the UI) ────────────────────────────────────


def get_row(row_id: str) -> Optional[Dict[str, Any]]:
    db = SessionLocal()
    try:
        row = db.query(AiSuggestion).filter(AiSuggestion.id == row_id).first()
        if row is None:
            return None
        return _row_to_dict(row)
    finally:
        db.close()


def list_rows(
    status: Optional[str] = None,
    source: Optional[str] = None,
    tenant_id: Optional[str] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        q = db.query(AiSuggestion)
        if status is not None:
            q = q.filter(AiSuggestion.status == status)
        if source is not None:
            q = q.filter(AiSuggestion.source == source)
        if tenant_id is not None:
            q = q.filter(AiSuggestion.tenant_id == tenant_id)
        rows = (
            q.order_by(AiSuggestion.created_at.desc()).limit(limit).all()
        )
        return [_row_to_dict(r) for r in rows]
    finally:
        db.close()


def stats(tenant_id: Optional[str] = None) -> Dict[str, int]:
    db = SessionLocal()
    try:
        q = db.query(AiSuggestion)
        if tenant_id is not None:
            q = q.filter(AiSuggestion.tenant_id == tenant_id)
        rows = q.all()
        out = {v.value: 0 for v in Verdict}
        for r in rows:
            out[r.status] = out.get(r.status, 0) + 1
        out["total"] = len(rows)
        return out
    finally:
        db.close()


def _row_to_dict(r: AiSuggestion) -> Dict[str, Any]:
    return {
        "id": r.id,
        "tenant_id": r.tenant_id,
        "source": r.source,
        "action_type": r.action_type,
        "target_type": r.target_type,
        "target_id": r.target_id,
        "before": r.before_json,
        "after": r.after_json,
        "reasoning": r.reasoning,
        "confidence": r.confidence / 1000.0 if r.confidence is not None else None,
        "destructive": bool(r.destructive),
        "status": r.status,
        "gate_reason": r.gate_reason,
        "approved_by": r.approved_by,
        "approved_at": r.approved_at.isoformat() if r.approved_at else None,
        "rejected_by": r.rejected_by,
        "rejected_at": r.rejected_at.isoformat() if r.rejected_at else None,
        "rejection_reason": r.rejection_reason,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }
