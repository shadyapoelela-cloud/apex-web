"""Governed AI — every AI action is logged, reversible, and gated by confidence.

Mirrors the "CFO-grade trust" pattern from Puzzle.io: no AI-generated
entry ever hits the ledger without an audit trail AND a way to undo it.

Three layers:

  1. AiActionLog — immutable record of every AI action:
       action_type, prompt snapshot, model, output, confidence,
       entity_ref (table + id), user_reviewer (if any), timestamp.

  2. Confidence gate — routes actions to:
       confidence < threshold_review         → HUMAN_REVIEW
       threshold_review <= c < threshold_silent → AUTO + USER NOTIFY
       c >= threshold_silent                 → AUTO SILENT
     Thresholds are tenant-configurable. Defaults: 70% / 90%.

  3. Undo stack — every auto-applied AI action records the "reverse"
     operation so a user can roll it back within N days (default 30).

Public API:
  log_action(action_type, prompt, output, confidence, entity_ref=None,
             model=..., reverse_callback_name=..., reverse_args=...) -> AiActionLog
  route_confidence(confidence, thresholds=None) -> 'review' | 'auto_notify' | 'auto_silent'
  undo_action(action_id, user_id) -> dict
  query_actions(tenant_id=..., since=..., until=..., confidence_max=..., limit=100)

This is infrastructure — specific AI modules (AP coding, Copilot NL→SQL,
bank reconciliation suggestions) call log_action() + route_confidence()
so all AI actions share one audit trail + undo UX.
"""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from enum import Enum
from typing import Any, Callable, Optional

from sqlalchemy import Boolean, Column, DateTime, Integer, Numeric, String, Text

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


class AiGateDecision(str, Enum):
    REVIEW = "review"
    AUTO_NOTIFY = "auto_notify"
    AUTO_SILENT = "auto_silent"


@dataclass(frozen=True)
class ConfidenceThresholds:
    review_below: Decimal = Decimal("0.70")
    notify_below: Decimal = Decimal("0.90")


def route_confidence(
    confidence: Decimal | float,
    thresholds: Optional[ConfidenceThresholds] = None,
) -> AiGateDecision:
    """Map a confidence score to one of three decisions."""
    c = Decimal(str(confidence))
    t = thresholds or ConfidenceThresholds()
    if c < t.review_below:
        return AiGateDecision.REVIEW
    if c < t.notify_below:
        return AiGateDecision.AUTO_NOTIFY
    return AiGateDecision.AUTO_SILENT


# ── Model ──────────────────────────────────────────────────


class AiActionLog(Base, TenantMixin):
    """One AI action with its full context for audit + undo."""

    __tablename__ = "ai_action_log"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    # What happened
    action_type = Column(String(64), nullable=False, index=True)
    # examples: 'ap.gl_coding', 'copilot.nl_to_sql', 'bank_rec.auto_match'

    model = Column(String(64), nullable=True)   # claude-sonnet-4-5, claude-opus-4-6, etc.
    prompt_snapshot = Column(Text, nullable=True)  # redacted input
    output = Column(Text, nullable=True)          # JSON-encoded result
    confidence = Column(Numeric(5, 4), nullable=True)
    gate_decision = Column(String(16), nullable=False, index=True)

    # What record this affected (if any)
    entity_type = Column(String(64), nullable=True, index=True)
    entity_id = Column(String(36), nullable=True, index=True)

    # Who, if anyone, reviewed
    actor_user_id = Column(String(36), nullable=True, index=True)
    reviewer_user_id = Column(String(36), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    # Undo
    reverse_callback_name = Column(String(120), nullable=True)
    reverse_args_json = Column(Text, nullable=True)
    undone = Column(Boolean, nullable=False, default=False)
    undone_at = Column(DateTime(timezone=True), nullable=True)
    undone_by_user_id = Column(String(36), nullable=True)

    # Free notes (e.g., "blocked by policy; human review required")
    notes = Column(Text, nullable=True)


# ── Reverse-callback registry ──────────────────────────────

# Modules register their "undo" implementations here. The callable takes
# (reverse_args_dict, db_session) and performs the reverse operation.

_REVERSE_CALLBACKS: dict[str, Callable[[dict, Any], dict]] = {}


def register_reverse_callback(name: str, fn: Callable[[dict, Any], dict]) -> None:
    _REVERSE_CALLBACKS[name] = fn


# ── Public API ─────────────────────────────────────────────


def log_action(
    *,
    action_type: str,
    output: Any,
    confidence: Decimal | float,
    prompt_snapshot: Optional[str] = None,
    model: Optional[str] = None,
    entity_type: Optional[str] = None,
    entity_id: Optional[str] = None,
    actor_user_id: Optional[str] = None,
    reverse_callback_name: Optional[str] = None,
    reverse_args: Optional[dict] = None,
    thresholds: Optional[ConfidenceThresholds] = None,
    notes: Optional[str] = None,
) -> AiActionLog:
    """Record an AI action and return the persisted log row."""
    decision = route_confidence(confidence, thresholds)
    db = SessionLocal()
    try:
        entry = AiActionLog(
            id=str(uuid.uuid4()),
            action_type=action_type,
            model=model,
            prompt_snapshot=(prompt_snapshot or "")[:5000],
            output=json.dumps(output, default=str, ensure_ascii=False)[:10000],
            confidence=Decimal(str(confidence)),
            gate_decision=decision.value,
            entity_type=entity_type,
            entity_id=entity_id,
            actor_user_id=actor_user_id,
            reverse_callback_name=reverse_callback_name,
            reverse_args_json=(
                json.dumps(reverse_args, default=str, ensure_ascii=False)
                if reverse_args
                else None
            ),
            notes=notes,
        )
        db.add(entry)
        db.commit()
        db.refresh(entry)
        return entry
    finally:
        db.close()


def approve_action(action_id: str, reviewer_user_id: str, notes: Optional[str] = None) -> dict:
    """Mark a REVIEW-gated action as approved after human sign-off."""
    db = SessionLocal()
    try:
        entry = db.query(AiActionLog).filter(AiActionLog.id == action_id).first()
        if not entry:
            return {"success": False, "error": "not_found"}
        entry.reviewer_user_id = reviewer_user_id
        entry.reviewed_at = datetime.now(timezone.utc)
        if notes:
            entry.notes = ((entry.notes or "") + "\n" + notes).strip()
        db.commit()
        return {"success": True, "data": {"id": action_id, "reviewed_at": entry.reviewed_at.isoformat()}}
    finally:
        db.close()


def undo_action(action_id: str, user_id: str, max_age_days: int = 30) -> dict:
    """Reverse an AI action by invoking its registered reverse callback."""
    db = SessionLocal()
    try:
        entry = db.query(AiActionLog).filter(AiActionLog.id == action_id).first()
        if not entry:
            return {"success": False, "error": "not_found"}
        if entry.undone:
            return {"success": False, "error": "already_undone"}
        # SQLite may return naive datetimes even with DateTime(timezone=True);
        # coerce to UTC before subtraction.
        ts = entry.timestamp
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        age = datetime.now(timezone.utc) - ts
        if age > timedelta(days=max_age_days):
            return {
                "success": False,
                "error": f"too_old (> {max_age_days} days)",
            }
        if not entry.reverse_callback_name:
            return {"success": False, "error": "no_reverse_callback_registered"}
        fn = _REVERSE_CALLBACKS.get(entry.reverse_callback_name)
        if fn is None:
            return {
                "success": False,
                "error": f"reverse_callback_unknown: {entry.reverse_callback_name}",
            }
        args = json.loads(entry.reverse_args_json) if entry.reverse_args_json else {}
        try:
            result = fn(args, db)
        except Exception as e:
            logger.error("Reverse callback failed: %s", e, exc_info=True)
            return {"success": False, "error": f"reverse_failed: {e}"}

        entry.undone = True
        entry.undone_at = datetime.now(timezone.utc)
        entry.undone_by_user_id = user_id
        db.commit()
        return {"success": True, "data": {"id": action_id, "reverse_result": result}}
    finally:
        db.close()


def query_actions(
    *,
    action_type: Optional[str] = None,
    entity_type: Optional[str] = None,
    entity_id: Optional[str] = None,
    since: Optional[datetime] = None,
    until: Optional[datetime] = None,
    gate_decision: Optional[AiGateDecision | str] = None,
    undone: Optional[bool] = None,
    limit: int = 100,
) -> list[AiActionLog]:
    db = SessionLocal()
    try:
        q = db.query(AiActionLog).order_by(AiActionLog.timestamp.desc())
        if action_type:
            q = q.filter(AiActionLog.action_type == action_type)
        if entity_type:
            q = q.filter(AiActionLog.entity_type == entity_type)
        if entity_id:
            q = q.filter(AiActionLog.entity_id == entity_id)
        if since:
            q = q.filter(AiActionLog.timestamp >= since)
        if until:
            q = q.filter(AiActionLog.timestamp <= until)
        if gate_decision is not None:
            val = (
                gate_decision.value
                if isinstance(gate_decision, AiGateDecision)
                else gate_decision
            )
            q = q.filter(AiActionLog.gate_decision == val)
        if undone is not None:
            q = q.filter(AiActionLog.undone == undone)
        return q.limit(max(1, min(limit, 1000))).all()
    finally:
        db.close()
