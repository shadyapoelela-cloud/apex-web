"""APEX — Conversational Onboarding routes.

Public:
    POST /api/v1/onboarding-chat/start
    POST /api/v1/onboarding-chat/{session_id}/reply
    GET  /api/v1/onboarding-chat/{session_id}

Admin (X-Admin-Secret):
    GET  /admin/onboarding-chat/sessions
    GET  /admin/onboarding-chat/stats

Wave 1R Phase YY.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.onboarding_chat import (
    get_session,
    list_sessions,
    reply,
    start_session,
    stats,
)

router = APIRouter(tags=["onboarding-chat"])

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


# ── Public ──────────────────────────────────────────────────────


@router.post("/api/v1/onboarding-chat/start", status_code=201)
def public_start():
    """Begin a new conversational onboarding session."""
    return {"success": True, "session": start_session()}


class ReplyRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)


@router.post("/api/v1/onboarding-chat/{session_id}/reply")
def public_reply(session_id: str, payload: ReplyRequest):
    try:
        session = reply(session_id, payload.text)
    except ValueError as e:
        if str(e) == "session_not_found":
            raise HTTPException(404, "session not found")
        raise HTTPException(400, str(e))
    return {"success": True, "session": session}


@router.get("/api/v1/onboarding-chat/{session_id}")
def public_get(session_id: str):
    sess = get_session(session_id)
    if not sess:
        raise HTTPException(404, "session not found")
    return {"success": True, "session": sess}


# ── Admin ──────────────────────────────────────────────────────


@router.get("/admin/onboarding-chat/sessions")
def admin_list(
    limit: int = Query(50, ge=1, le=500),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_sessions(limit=limit)
    return {"success": True, "sessions": rows, "count": len(rows)}


@router.get("/admin/onboarding-chat/stats")
def admin_stats(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}
