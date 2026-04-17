"""Notifications list API — bootstraps the bell with recent history.

The WebSocket channel `user:{uid}` delivers new activity in realtime,
but when the user opens their first screen the bell is empty until
something new arrives. This endpoint fills that gap: GET returns the
most recent N activity rows the user cares about, derived directly
from the activity_log table (no separate "notifications" table — the
same rows back both the Chatter timeline and the bell).

Routes:
  GET  /api/v1/notifications
         → paginated list for the current user
  POST /api/v1/notifications/{activity_id}/read
         → optimistic marker; client tracks read state locally anyway

Read state is kept local to the Flutter client for now (no DB column)
to stay simple. When a user-specific read-state column is added to
activity_log, wire the POST handler to flip it.
"""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import or_

from app.core.activity_log import ActivityLog
from app.core.api_version import v1_prefix
from app.core.tenant_context import current_tenant
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)

router = APIRouter(prefix=v1_prefix("/notifications"), tags=["Notifications"])


def _severity_for(action: str) -> str:
    """Same mapping the Flutter NotificationBellLive uses — keep in sync."""
    a = (action or "").lower()
    if any(k in a for k in ("dead", "rejected", "error", "overdue")):
        return "error"
    if any(k in a for k in ("warning", "stale", "overdue")):
        return "warning"
    if any(k in a for k in ("reported", "cleared", "paid", "reviewed")):
        return "success"
    return "info"


def _title_for(action: str) -> str:
    """Arabic human-friendly titles."""
    return {
        "commented": "تعليق جديد",
        "note": "ملاحظة جديدة",
        "status_changed": "تغيّر الحالة",
        "attachment_added": "مرفق جديد",
        "created": "تم الإنشاء",
        "paid": "تم الدفع",
        "deleted": "تم الحذف",
    }.get(action, "نشاط جديد" if not (action or "").startswith("proactive.")
          else "تنبيه AI")


@router.get("")
def list_notifications(
    user_id: Optional[str] = Query(
        None, description="User scope; defaults to current tenant's user stream"
    ),
    limit: int = Query(50, ge=1, le=200),
    since: Optional[str] = Query(
        None, description="ISO-8601 timestamp; only rows strictly after this"
    ),
):
    """Return the most recent activity entries for the bell, newest-first.

    Derived from activity_log — filters to rows authored by, or directly
    addressed to, the current user. If no user_id passed, returns
    tenant-wide newest activity so the demo/admin view always has
    something to show.
    """
    db = SessionLocal()
    try:
        q = db.query(ActivityLog)

        # Tenant isolation — honoured by the tenant_guard even without
        # an explicit filter here, but we pin it for clarity.
        tenant = current_tenant()
        if tenant:
            q = q.filter(
                or_(
                    ActivityLog.tenant_id == tenant,
                    ActivityLog.tenant_id.is_(None),
                )
            )

        if user_id:
            q = q.filter(ActivityLog.user_id == user_id)

        if since:
            from datetime import datetime, timezone
            try:
                since_dt = datetime.fromisoformat(since.replace("Z", "+00:00"))
                if since_dt.tzinfo is None:
                    since_dt = since_dt.replace(tzinfo=timezone.utc)
                q = q.filter(ActivityLog.created_at > since_dt)
            except ValueError:
                raise HTTPException(
                    status_code=422,
                    detail="`since` must be a valid ISO-8601 datetime",
                )

        rows = (
            q.order_by(ActivityLog.created_at.desc())
            .limit(limit)
            .all()
        )

        out = []
        for r in rows:
            out.append({
                "id": r.id,
                "title": _title_for(r.action),
                "body": r.summary or "",
                "action": r.action,
                "entity_type": r.entity_type,
                "entity_id": r.entity_id,
                "severity": _severity_for(r.action),
                "user_name": r.user_name,
                "timestamp": r.created_at.isoformat() if r.created_at else None,
            })

        return {
            "success": True,
            "data": out,
            "limit": limit,
            "count": len(out),
        }
    finally:
        db.close()


@router.post("/{activity_id}/read")
def mark_read(activity_id: str):
    """Client-side read tracking acknowledgement.

    We don't persist a per-user read flag yet — the Flutter bell keeps
    its own local 'read' set in memory + (later) localStorage. This
    route is here so the client has a stable endpoint to call and
    analytics/telemetry can count reads server-side.
    """
    db = SessionLocal()
    try:
        row = (
            db.query(ActivityLog)
            .filter(ActivityLog.id == activity_id)
            .first()
        )
        if row is None:
            raise HTTPException(status_code=404, detail="activity not found")
        return {"success": True, "data": {"id": row.id, "acknowledged": True}}
    finally:
        db.close()


@router.post("/read-all")
def mark_all_read(user_id: Optional[str] = Query(None)):
    """Acknowledgement for 'mark everything read' button.

    Same caveat as mark_read — local state in Flutter is the source of
    truth today. Returns the count of notifications that were visible
    for observability."""
    db = SessionLocal()
    try:
        q = db.query(ActivityLog)
        tenant = current_tenant()
        if tenant:
            q = q.filter(
                or_(
                    ActivityLog.tenant_id == tenant,
                    ActivityLog.tenant_id.is_(None),
                )
            )
        if user_id:
            q = q.filter(ActivityLog.user_id == user_id)
        count = q.count()
        return {"success": True, "data": {"count": count, "acknowledged": True}}
    finally:
        db.close()
