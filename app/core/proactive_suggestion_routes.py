"""
APEX — Proactive Suggestions HTTP routes
=========================================
End-user inbox + admin management endpoints.

    GET  /api/v1/suggestions?tenant_id=...&status=proposed  — user inbox
    POST /api/v1/suggestions/{id}/dismiss                   — user dismisses
    POST /api/v1/suggestions/{id}/apply                     — user marks applied
    GET  /admin/suggestions/stats                           — counts
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.proactive_suggestions import (
    get_suggestion,
    list_suggestions,
    stats,
    update_status,
)

router = APIRouter(tags=["suggestions"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


def _serialize(s) -> dict:
    return {
        "id": s.id,
        "code": s.code,
        "severity": s.severity,
        "title_ar": s.title_ar,
        "body_ar": s.body_ar,
        "action": s.action,
        "action_target": s.action_target,
        "tenant_id": s.tenant_id,
        "status": s.status,
        "detected_count": s.detected_count,
        "created_at": s.created_at,
        "updated_at": s.updated_at,
    }


@router.get("/api/v1/suggestions")
def list_route(
    tenant_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None, pattern="^(proposed|dismissed|applied)$"),
):
    rows = list_suggestions(tenant_id=tenant_id, status=status)
    return {
        "success": True,
        "suggestions": [_serialize(s) for s in rows],
        "count": len(rows),
    }


@router.get("/api/v1/suggestions/{suggestion_id}")
def get_route(suggestion_id: str):
    s = get_suggestion(suggestion_id)
    if not s:
        raise HTTPException(404, "Suggestion not found")
    return {"success": True, "suggestion": _serialize(s)}


@router.post("/api/v1/suggestions/{suggestion_id}/dismiss")
def dismiss_route(suggestion_id: str):
    s = update_status(suggestion_id, "dismissed")
    if not s:
        raise HTTPException(404, "Suggestion not found")
    return {"success": True, "suggestion": _serialize(s)}


@router.post("/api/v1/suggestions/{suggestion_id}/apply")
def apply_route(suggestion_id: str):
    s = update_status(suggestion_id, "applied")
    if not s:
        raise HTTPException(404, "Suggestion not found")
    return {"success": True, "suggestion": _serialize(s)}


@router.get("/admin/suggestions/stats")
def stats_route(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}
