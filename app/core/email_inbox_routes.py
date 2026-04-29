"""
APEX — Email Inbox admin routes.
=================================
Admin endpoints to:
- Trigger a manual poll (or hook from cron)
- Check whether the inbox is configured

Endpoints:
    POST /admin/email-inbox/poll     — fetch unread, emit events
    GET  /admin/email-inbox/status   — whether env vars are set
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.email_inbox import is_configured, poll_inbox

router = APIRouter(prefix="/admin/email-inbox", tags=["admin", "email-inbox"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


@router.post("/poll")
def poll(
    max_messages: Optional[int] = Query(None, ge=1, le=200),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Fetch unread messages, save attachments, emit `email.received`."""
    _verify(x_admin_secret)
    return poll_inbox(max_messages=max_messages)


@router.get("/status")
def status(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    return {
        "success": True,
        "configured": is_configured(),
        "host": os.environ.get("EMAIL_INBOX_HOST"),
        "user": os.environ.get("EMAIL_INBOX_USER"),
        "folder": os.environ.get("EMAIL_INBOX_FOLDER", "INBOX"),
        "use_ssl": (os.environ.get("EMAIL_INBOX_USE_SSL", "1") in ("1", "true", "yes", "on")),
        "max_per_run": int(os.environ.get("EMAIL_INBOX_MAX_PER_RUN", "25") or "25"),
    }
