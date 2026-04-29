"""
APEX — Approval Chains MVP
============================
Multi-stage approvals for high-value or sensitive actions, integrated
with the Workflow Rules Engine via a new "approval" action type.

Why this exists:
- Big invoices, large payments, payroll runs, JE reversals all benefit
  from a structured "two pairs of eyes" sign-off chain
- The Workflow Engine fires actions; this module turns one of those
  actions into an approval request that gates downstream behavior
- Approvers act through admin/UI endpoints; on approve/reject the
  chain emits an event back into the Event Bus → rules can react

Storage: JSON file at $APPROVALS_PATH (default approvals.json), same
pattern as workflow_engine.py. Replace with a SQLAlchemy model + Alembic
migration when the approval-inbox UI lands.

Events emitted:
    approval.requested  — new approval created
    approval.approved   — last required approver said yes
    approval.rejected   — any approver said no (chain stops)
    approval.partial    — one stage complete, awaiting next

Reference: Layer 3.4 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)

# Storage
_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get("APPROVALS_PATH", os.path.join(_DATA_DIR, "approvals.json"))

_LOCK = threading.RLock()


# ── Models ───────────────────────────────────────────────────────


@dataclass
class ApprovalDecision:
    """One stage's decision in a multi-level approval chain."""

    stage: int
    user_id: str
    decision: str  # "pending" | "approved" | "rejected"
    decided_at: Optional[str] = None
    comment: Optional[str] = None


@dataclass
class Approval:
    """A multi-stage approval workflow instance.

    `stages`: ordered list of approver user IDs. Approval moves through
    stages one at a time. Any rejection short-circuits the chain.
    `meta`: arbitrary payload (e.g. {invoice_id, amount}) that the
    triggering rule wants the approvers to see.
    """

    id: str
    title_ar: str
    title_en: Optional[str]
    body: Optional[str]
    object_type: Optional[str]  # e.g. "invoice" | "bill" | "payroll_run" | "je"
    object_id: Optional[str]
    stages: list[ApprovalDecision]
    current_stage: int = 0
    state: str = "pending"  # pending | approved | rejected | cancelled
    requested_by: Optional[str] = None  # user_id who triggered
    rule_id: Optional[str] = None  # workflow rule that fired this
    tenant_id: Optional[str] = None
    meta: dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


# ── Persistence ──────────────────────────────────────────────────


_STORE: dict[str, Approval] = {}


def _serialize(a: Approval) -> dict:
    return asdict(a)


def _deserialize(d: dict) -> Approval:
    stages = [ApprovalDecision(**s) for s in d.get("stages", [])]
    a = Approval(
        id=d["id"],
        title_ar=d["title_ar"],
        title_en=d.get("title_en"),
        body=d.get("body"),
        object_type=d.get("object_type"),
        object_id=d.get("object_id"),
        stages=stages,
    )
    a.current_stage = d.get("current_stage", 0)
    a.state = d.get("state", "pending")
    a.requested_by = d.get("requested_by")
    a.rule_id = d.get("rule_id")
    a.tenant_id = d.get("tenant_id")
    a.meta = d.get("meta", {})
    a.created_at = d.get("created_at", a.created_at)
    a.updated_at = d.get("updated_at", a.updated_at)
    return a


def _load() -> None:
    global _STORE
    with _LOCK:
        if not os.path.exists(_PATH):
            _STORE = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _STORE = {a["id"]: _deserialize(a) for a in raw.get("approvals", [])}
            logger.info("Loaded %d approvals from %s", len(_STORE), _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load approvals: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "approvals": [_serialize(a) for a in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── CRUD ─────────────────────────────────────────────────────────


def create_approval(
    title_ar: str,
    approver_user_ids: list[str],
    *,
    title_en: Optional[str] = None,
    body: Optional[str] = None,
    object_type: Optional[str] = None,
    object_id: Optional[str] = None,
    requested_by: Optional[str] = None,
    rule_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    meta: Optional[dict] = None,
) -> Approval:
    """Create a new pending approval. Emits `approval.requested`."""
    if not approver_user_ids:
        raise ValueError("approver_user_ids must have at least one entry")
    stages = [
        ApprovalDecision(stage=i, user_id=uid, decision="pending")
        for i, uid in enumerate(approver_user_ids)
    ]
    a = Approval(
        id=str(uuid.uuid4()),
        title_ar=title_ar,
        title_en=title_en,
        body=body,
        object_type=object_type,
        object_id=object_id,
        stages=stages,
        requested_by=requested_by,
        rule_id=rule_id,
        tenant_id=tenant_id,
        meta=meta or {},
    )
    with _LOCK:
        _STORE[a.id] = a
        _save()

    emit(
        "approval.requested",
        {
            "approval_id": a.id,
            "title_ar": a.title_ar,
            "object_type": a.object_type,
            "object_id": a.object_id,
            "tenant_id": a.tenant_id,
            "current_approver": a.stages[0].user_id,
            "total_stages": len(a.stages),
            "meta": a.meta,
        },
        source="approvals",
    )
    return a


def get_approval(approval_id: str) -> Optional[Approval]:
    with _LOCK:
        return _STORE.get(approval_id)


def list_approvals(
    *,
    tenant_id: Optional[str] = None,
    user_id: Optional[str] = None,
    state: Optional[str] = None,
    pending_for_user_only: bool = False,
) -> list[Approval]:
    """Filter approvals.

    `pending_for_user_only`: when True + user_id, returns only approvals
    where the current stage's approver matches user_id (i.e., what's in
    the user's inbox right now).
    """
    with _LOCK:
        out = list(_STORE.values())
    if tenant_id:
        out = [a for a in out if a.tenant_id == tenant_id]
    if state:
        out = [a for a in out if a.state == state]
    if user_id:
        if pending_for_user_only:
            out = [
                a
                for a in out
                if a.state == "pending"
                and 0 <= a.current_stage < len(a.stages)
                and a.stages[a.current_stage].user_id == user_id
            ]
        else:
            out = [a for a in out if any(s.user_id == user_id for s in a.stages)]
    return sorted(out, key=lambda a: a.created_at, reverse=True)


def decide(
    approval_id: str,
    user_id: str,
    decision: str,
    *,
    comment: Optional[str] = None,
) -> dict:
    """Record `user_id`'s decision on the current stage of `approval_id`.

    Decisions:
      "approved"  → move to next stage; if last, mark whole approval approved.
      "rejected"  → short-circuit; mark approval rejected.

    Returns: {success, approval (dict), state_change (str)}.
    Raises: ValueError on permission/state errors.
    """
    if decision not in ("approved", "rejected"):
        raise ValueError("decision must be 'approved' or 'rejected'")
    with _LOCK:
        a = _STORE.get(approval_id)
        if not a:
            raise ValueError("Approval not found")
        if a.state != "pending":
            raise ValueError(f"Approval already {a.state}")
        if a.current_stage >= len(a.stages):
            raise ValueError("No active stage")

        stage = a.stages[a.current_stage]
        if stage.user_id != user_id:
            raise ValueError(
                f"User {user_id} is not the current approver "
                f"(stage {stage.stage}, expected {stage.user_id})"
            )

        stage.decision = decision
        stage.decided_at = datetime.now(timezone.utc).isoformat()
        stage.comment = comment
        a.updated_at = stage.decided_at

        if decision == "rejected":
            a.state = "rejected"
            change = "rejected"
        else:
            a.current_stage += 1
            if a.current_stage >= len(a.stages):
                a.state = "approved"
                change = "approved"
            else:
                change = "partial"
        _save()

    # Emit event for the rules engine to potentially react.
    if change == "rejected":
        emit_name = "approval.rejected"
    elif change == "approved":
        emit_name = "approval.approved"
    else:
        emit_name = "approval.partial"
    emit(
        emit_name,
        {
            "approval_id": a.id,
            "object_type": a.object_type,
            "object_id": a.object_id,
            "tenant_id": a.tenant_id,
            "decided_by": user_id,
            "comment": comment,
            "stage": a.current_stage - (1 if decision == "approved" else 0),
            "next_approver": (
                a.stages[a.current_stage].user_id
                if change == "partial" and a.current_stage < len(a.stages)
                else None
            ),
            "meta": a.meta,
        },
        source="approvals",
    )

    return {
        "success": True,
        "approval": _serialize(a),
        "state_change": change,
    }


def cancel_approval(approval_id: str, *, reason: Optional[str] = None) -> bool:
    """Admin-cancel an in-flight approval (e.g., source object was deleted)."""
    with _LOCK:
        a = _STORE.get(approval_id)
        if not a or a.state != "pending":
            return False
        a.state = "cancelled"
        a.updated_at = datetime.now(timezone.utc).isoformat()
        a.meta["cancellation_reason"] = reason
        _save()
    return True


# Initial load on import.
_load()


# ── Helpers exposed for routes ─────────────────────────────────────


def stats() -> dict:
    with _LOCK:
        by_state: dict[str, int] = {}
        for a in _STORE.values():
            by_state[a.state] = by_state.get(a.state, 0) + 1
        return {
            "approvals_total": len(_STORE),
            "by_state": by_state,
            "storage_path": _PATH,
        }
