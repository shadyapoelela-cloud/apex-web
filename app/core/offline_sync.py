"""PWA offline sync queue — handles operations made without a connection.

Flow:
  1. Flutter offline: user creates invoice → enqueued locally in IndexedDB.
  2. Connection returns: client POSTs each queued op to /api/v1/sync/push
     with a client-generated `op_id` (uuid4).
  3. Server: idempotent apply. If op_id was seen before, return the cached
     result (at-least-once → exactly-once via idempotency key).
  4. Conflict resolution: last-writer-wins for updates on the same entity,
     with a `conflict_log` record when versions diverge so admins can reconcile.

This is the SERVER side. The Flutter side lives in apex_finance under
`core/apex_offline_queue.dart`.

Status values:
  PENDING      — received, validated, not yet applied
  APPLIED      — successfully applied, returning cached result
  CONFLICT     — detected a diverging write; human needed
  REJECTED     — invalid payload (schema / auth) — client won't retry
  SUPERSEDED   — a newer op for the same entity overtook this one
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Column, DateTime, Integer, JSON, String, Text

from app.core.api_version import v1_prefix
from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


class SyncOpStatus(str, Enum):
    PENDING = "pending"
    APPLIED = "applied"
    CONFLICT = "conflict"
    REJECTED = "rejected"
    SUPERSEDED = "superseded"


# ── Model ─────────────────────────────────────────────────


class SyncOperation(Base, TenantMixin):
    """One operation recorded from an offline client."""

    __tablename__ = "sync_operations"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    op_id = Column(String(64), nullable=False, index=True)
    # Client-generated idempotency key. UNIQUE enforced at app layer.

    user_id = Column(String(36), nullable=True, index=True)
    client_version = Column(String(32), nullable=True)
    client_device_id = Column(String(64), nullable=True)

    entity_type = Column(String(40), nullable=False, index=True)
    entity_id = Column(String(64), nullable=True, index=True)
    verb = Column(String(16), nullable=False)            # create / update / delete
    payload = Column(JSON, nullable=False)

    client_timestamp = Column(DateTime(timezone=True), nullable=False)
    received_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    status = Column(String(16), nullable=False,
                    default=SyncOpStatus.PENDING.value, index=True)
    result = Column(JSON, nullable=True)                 # cached response
    error = Column(Text, nullable=True)

    applied_at = Column(DateTime(timezone=True), nullable=True)


# ── Schemas ───────────────────────────────────────────────


class SyncOpIn(BaseModel):
    op_id: str = Field(..., min_length=8, max_length=64)
    entity_type: str = Field(..., max_length=40)
    entity_id: Optional[str] = None
    verb: str = Field(..., pattern="^(create|update|delete)$")
    payload: dict
    client_timestamp: datetime
    client_version: Optional[str] = None
    client_device_id: Optional[str] = None


class SyncOpOut(BaseModel):
    op_id: str
    status: str
    result: Optional[dict] = None
    error: Optional[str] = None


class SyncBatch(BaseModel):
    operations: list[SyncOpIn] = Field(..., min_length=1, max_length=100)


# ── Applier registry ──────────────────────────────────────

# Real ops register their handlers here; the applier takes the payload
# and returns a (status, result) tuple. Unknown entity_type → REJECTED.

_HANDLERS: dict[str, Any] = {}


def register_sync_handler(entity_type: str, handler):
    """handler(op: SyncOperation, db) → (SyncOpStatus, result_dict)."""
    _HANDLERS[entity_type] = handler


# ── Core apply loop ───────────────────────────────────────


def apply_operation(op: SyncOperation, db) -> tuple[SyncOpStatus, Optional[dict]]:
    handler = _HANDLERS.get(op.entity_type)
    if handler is None:
        return SyncOpStatus.REJECTED, {"error": f"no handler for {op.entity_type}"}
    try:
        return handler(op, db)
    except Exception as e:
        logger.error("sync handler failed: %s", e, exc_info=True)
        return SyncOpStatus.CONFLICT, {"error": str(e)}


def _process(payload: SyncOpIn, user_id: Optional[str]) -> SyncOpOut:
    db = SessionLocal()
    try:
        # Idempotency: if op_id seen before, return cached result.
        existing = (
            db.query(SyncOperation)
            .filter(SyncOperation.op_id == payload.op_id)
            .first()
        )
        if existing is not None:
            return SyncOpOut(
                op_id=existing.op_id,
                status=existing.status,
                result=existing.result,
                error=existing.error,
            )

        op = SyncOperation(
            id=str(uuid.uuid4()),
            op_id=payload.op_id,
            user_id=user_id,
            client_version=payload.client_version,
            client_device_id=payload.client_device_id,
            entity_type=payload.entity_type,
            entity_id=payload.entity_id,
            verb=payload.verb,
            payload=payload.payload,
            client_timestamp=payload.client_timestamp,
            status=SyncOpStatus.PENDING.value,
        )
        db.add(op)
        db.flush()

        status, result = apply_operation(op, db)
        op.status = status.value
        op.result = result
        if status == SyncOpStatus.APPLIED:
            op.applied_at = datetime.now(timezone.utc)
        elif status == SyncOpStatus.REJECTED:
            op.error = (result or {}).get("error")

        try:
            db.commit()
        except Exception as e:
            db.rollback()
            return SyncOpOut(
                op_id=payload.op_id,
                status=SyncOpStatus.CONFLICT.value,
                error=f"commit failed: {e}",
            )

        return SyncOpOut(
            op_id=op.op_id,
            status=op.status,
            result=op.result,
            error=op.error,
        )
    finally:
        db.close()


# ── Conflict detection: last-writer-wins per entity ───────


def mark_superseded(entity_type: str, entity_id: str, up_to: datetime, db) -> int:
    """Mark older pending ops on the same entity as SUPERSEDED.

    Called by handlers BEFORE applying an UPDATE to ensure stale queued
    ops from a dead device don't undo newer data.
    """
    q = (
        db.query(SyncOperation)
        .filter(SyncOperation.entity_type == entity_type)
        .filter(SyncOperation.entity_id == entity_id)
        .filter(SyncOperation.status == SyncOpStatus.PENDING.value)
        .filter(SyncOperation.client_timestamp < up_to)
    )
    count = 0
    for op in q.all():
        op.status = SyncOpStatus.SUPERSEDED.value
        count += 1
    return count


# ── REST API (/api/v1/sync/*) ─────────────────────────────


router = APIRouter(prefix=v1_prefix("/sync"), tags=["Offline Sync"])


@router.post("/push")
def push_batch(batch: SyncBatch):
    """Client sends a batch of queued ops. Each processed independently."""
    results: list[SyncOpOut] = []
    for op in batch.operations:
        results.append(_process(op, user_id=None))
    return {
        "success": True,
        "data": [r.model_dump(mode="json") for r in results],
    }


@router.get("/status/{op_id}")
def get_op_status(op_id: str):
    db = SessionLocal()
    try:
        op = (
            db.query(SyncOperation)
            .filter(SyncOperation.op_id == op_id)
            .first()
        )
        if not op:
            raise HTTPException(status_code=404, detail="op not found")
        return {
            "success": True,
            "data": {
                "op_id": op.op_id,
                "status": op.status,
                "result": op.result,
                "error": op.error,
                "received_at": op.received_at.isoformat() if op.received_at else None,
                "applied_at": op.applied_at.isoformat() if op.applied_at else None,
            },
        }
    finally:
        db.close()
