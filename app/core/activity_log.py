"""Activity Log — Odoo-style timeline of events on every business record.

Every client / invoice / PO / employee gets a chronological log:
  • System-generated: "created", "updated", "status changed", "emailed"
  • Human-generated: "commented", "logged note"

The log is pulled by the Flutter `ApexChatter` widget and rendered as
an activity feed + comment input on the record's detail screen.

This module provides:
  • ActivityLog + ActivityComment SQLAlchemy models
  • Four routes under /api/v1/activity
  • log_activity() helper for other modules to call
  • auto_log_crud() helper for routes that don't want to call manually

All tables tenant-scoped via TenantMixin.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import JSON, Column, DateTime, Index, String, Text

from app.core.api_version import v1_prefix
from app.core.tenant_guard import TenantMixin, current_tenant
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


# ── Models ────────────────────────────────────────────────


class ActivityLog(Base, TenantMixin):
    """One activity on one business record.

    The (entity_type, entity_id) pair keys into whatever table actually
    owns the record — we deliberately don't foreign-key so this table
    can log events about anything without circular imports.
    """

    __tablename__ = "activity_log"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    entity_type = Column(String(40), nullable=False)  # 'client' | 'invoice' | 'po' ...
    entity_id = Column(String(36), nullable=False)
    action = Column(String(40), nullable=False)
    # Kinds we use: 'created' | 'updated' | 'status_changed' | 'emailed'
    # | 'commented' | 'note' | 'attachment_added' | 'paid' | 'deleted'
    user_id = Column(String(36), nullable=True)
    user_name = Column(String(120), nullable=True)
    summary = Column(Text, nullable=True)       # human-readable one-liner
    details = Column(JSON, nullable=True)       # old/new values, etc.
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    __table_args__ = (
        Index("idx_activity_entity", "entity_type", "entity_id"),
        Index("idx_activity_created", "created_at"),
    )


# ── Helpers for other modules ─────────────────────────────


def log_activity(
    *,
    entity_type: str,
    entity_id: str,
    action: str,
    summary: Optional[str] = None,
    details: Optional[dict[str, Any]] = None,
    user_id: Optional[str] = None,
    user_name: Optional[str] = None,
    db=None,
) -> str:
    """Insert one activity row. Caller may pass a db session (useful
    inside an existing transaction); otherwise we open+commit our own.

    Returns the new activity row's id.
    """
    own_session = db is None
    if own_session:
        db = SessionLocal()
    try:
        row = ActivityLog(
            id=str(uuid.uuid4()),
            entity_type=entity_type,
            entity_id=entity_id,
            action=action,
            summary=summary,
            details=details or None,
            user_id=user_id,
            user_name=user_name,
        )
        db.add(row)
        if own_session:
            db.commit()
        # Fire-and-forget WebSocket push so any connected clients
        # (Chatter panels, Notification Bell, dashboards) see the new
        # event instantly without polling. Never fails the caller.
        _publish_activity_event(row)
        return row.id
    finally:
        if own_session:
            db.close()


def _publish_activity_event(row: "ActivityLog") -> None:
    """Best-effort push to the entity channel + the author's user channel.

    Runs asynchronously when there's a live event loop (FastAPI request
    context). Swallows every error — we never want the HTTP handler or
    the SQLAlchemy flush to fail because WebSocket delivery did.
    """
    try:
        import asyncio
        from app.core.websocket_hub import (
            publish_to_entity,
            publish_to_user,
        )

        payload = {
            "type": f"activity.{row.action}",
            "activity_id": row.id,
            "entity_type": row.entity_type,
            "entity_id": row.entity_id,
            "action": row.action,
            "summary": row.summary,
            "user_name": row.user_name,
            "timestamp": row.created_at.isoformat() if row.created_at else None,
        }

        async def _push() -> None:
            await publish_to_entity(row.entity_type, row.entity_id, payload)
            if row.user_id:
                await publish_to_user(row.user_id, payload)

        try:
            loop = asyncio.get_running_loop()
            loop.create_task(_push())
        except RuntimeError:
            # No running loop (e.g. invoked from a sync script) — skip.
            # The row is still persisted; only the push is skipped.
            pass
    except Exception as e:  # pragma: no cover
        logger.debug("activity ws-push skipped: %s", e)


def log_status_change(
    *,
    entity_type: str,
    entity_id: str,
    from_status: str,
    to_status: str,
    user_id: Optional[str] = None,
    user_name: Optional[str] = None,
    db=None,
) -> str:
    """Convenience wrapper for status transitions."""
    return log_activity(
        entity_type=entity_type,
        entity_id=entity_id,
        action="status_changed",
        summary=f"{from_status} → {to_status}",
        details={"from": from_status, "to": to_status},
        user_id=user_id,
        user_name=user_name,
        db=db,
    )


# ── Pydantic schemas ──────────────────────────────────────


class ActivityOut(BaseModel):
    id: str
    entity_type: str
    entity_id: str
    action: str
    summary: Optional[str] = None
    details: Optional[dict[str, Any]] = None
    user_id: Optional[str] = None
    user_name: Optional[str] = None
    created_at: str


class CommentIn(BaseModel):
    body: str = Field(..., min_length=1, max_length=4000)
    internal: bool = False  # Odoo: "Log Note" (internal) vs "Send Message"
    user_id: Optional[str] = None
    user_name: Optional[str] = None


# ── Routes ────────────────────────────────────────────────


router = APIRouter(prefix=v1_prefix("/activity"), tags=["Activity Log"])


def _to_out(row: ActivityLog) -> ActivityOut:
    return ActivityOut(
        id=row.id,
        entity_type=row.entity_type,
        entity_id=row.entity_id,
        action=row.action,
        summary=row.summary,
        details=row.details,
        user_id=row.user_id,
        user_name=row.user_name,
        created_at=row.created_at.isoformat(),
    )


# NOTE: Route declaration order matters. FastAPI matches in the order
# routes are registered, so we declare the more specific `/recent/...`
# path BEFORE the generic `/{entity_type}/{entity_id}` pattern —
# otherwise the latter would steal `/recent/<type>` into
# list_activity(entity_type='recent', entity_id=<type>).


@router.get("/recent/{entity_type}")
def list_recent_across(entity_type: str, limit: int = 50):
    """Dashboard feed: latest activity across all records of a type."""
    limit = max(1, min(limit, 200))
    db = SessionLocal()
    try:
        rows = (
            db.query(ActivityLog)
            .filter(ActivityLog.entity_type == entity_type)
            .order_by(ActivityLog.created_at.desc())
            .limit(limit)
            .all()
        )
        return {
            "success": True,
            "data": [_to_out(r).model_dump() for r in rows],
        }
    finally:
        db.close()


@router.post("/{entity_type}/{entity_id}/comment", status_code=201)
async def add_comment(entity_type: str, entity_id: str, payload: CommentIn):
    """Add a human comment / internal note to the activity stream.

    Declared async so the WebSocket push (scheduled inside
    log_activity via loop.create_task) runs on the same event loop
    that serves this request. Sync handlers land in a threadpool where
    there's no running loop — the push would then silently skip.
    """
    tenant = current_tenant()
    if not entity_type or not entity_id:
        raise HTTPException(status_code=400, detail="entity_type and entity_id required")
    new_id = log_activity(
        entity_type=entity_type,
        entity_id=entity_id,
        action="note" if payload.internal else "commented",
        summary=payload.body[:200],
        details={"body": payload.body, "internal": payload.internal, "tenant": tenant},
        user_id=payload.user_id,
        user_name=payload.user_name,
    )
    # Yield once so the create_task'd push gets a chance to run before
    # we return to the caller (makes the behaviour predictable in tests
    # without blocking on actual network sockets).
    import asyncio as _aio
    await _aio.sleep(0)

    db = SessionLocal()
    try:
        row = db.query(ActivityLog).filter(ActivityLog.id == new_id).first()
        if row is None:
            raise HTTPException(status_code=500, detail="insert failed")
        return {"success": True, "data": _to_out(row).model_dump()}
    finally:
        db.close()


@router.get("/{entity_type}/{entity_id}")
def list_activity(
    entity_type: str,
    entity_id: str,
    limit: int = 100,
    offset: int = 0,
):
    """Return newest-first activity for one record."""
    limit = max(1, min(limit, 500))
    offset = max(0, offset)
    db = SessionLocal()
    try:
        q = (
            db.query(ActivityLog)
            .filter(
                ActivityLog.entity_type == entity_type,
                ActivityLog.entity_id == entity_id,
            )
            .order_by(ActivityLog.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        rows = q.all()
        return {
            "success": True,
            "data": [_to_out(r).model_dump() for r in rows],
            "limit": limit,
            "offset": offset,
        }
    finally:
        db.close()


@router.delete("/{activity_id}")
def delete_activity(activity_id: str):
    """Remove one activity (admin cleanup / retraction).

    Soft-delete would be nicer but keeping simple for now. Comments can
    still be retracted by the original author; system events (created,
    status_changed) should generally NOT be deleted — they're audit
    evidence.
    """
    db = SessionLocal()
    try:
        row = db.query(ActivityLog).filter(ActivityLog.id == activity_id).first()
        if row is None:
            raise HTTPException(status_code=404, detail="not found")
        if row.action in ("created", "status_changed", "paid", "deleted"):
            raise HTTPException(
                status_code=403,
                detail="system events cannot be deleted",
            )
        db.delete(row)
        db.commit()
        return {"success": True}
    finally:
        db.close()
