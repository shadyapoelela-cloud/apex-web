"""
APEX — External Notification Channels (Slack + Teams) admin routes.
====================================================================
Provides admin smoke-test + broadcast endpoints for the new external
notification backends defined in `slack_backend.py` and `teams_backend.py`.

Endpoints (all require X-Admin-Secret header):
    POST /admin/notify/test
        Sends a "Hello from APEX" message to whichever of Slack/Teams is
        configured. Useful to verify webhook URLs are wired correctly.
    POST /admin/notify/broadcast
        Sends a custom title+body to all configured external channels.
        Body: {"title": "...", "body": "...", "url": "...", "severity": "info"}

Both endpoints are env-gated: missing webhook URL = silent no-op in prod
or console-log in dev. See architecture/diagrams/02-target-state.md §7
(Multi-Channel Notifications).
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.slack_backend import is_configured as slack_configured
from app.core.slack_backend import send_slack_notification
from app.core.teams_backend import is_configured as teams_configured
from app.core.teams_backend import send_teams_notification

router = APIRouter(prefix="/admin/notify", tags=["admin", "notifications"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")) -> None:
    """Constant-time admin-secret check. Mirrors `_verify_admin` in main.py."""
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        # Dev fallback: accept any value when ADMIN_SECRET is unset (warned at startup).
        return
    if not x_admin_secret or not secrets.compare_digest(x_admin_secret, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


class BroadcastRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    body: Optional[str] = Field(None, max_length=2000)
    url: Optional[str] = Field(None, max_length=500)
    severity: str = Field("info", pattern="^(info|success|warning|error)$")
    fields: Optional[dict] = None


@router.post("/test")
def smoke_test(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    """Send a hello message to every configured external channel."""
    _verify_admin(x_admin_secret)
    results: dict = {
        "slack": {"configured": slack_configured(), "sent": False},
        "teams": {"configured": teams_configured(), "sent": False},
    }
    if slack_configured():
        r = send_slack_notification(
            title="✅ APEX Slack webhook is live",
            body="If you can read this, your APEX Slack integration is working.",
            severity="success",
        )
        results["slack"]["sent"] = bool(r.get("success"))
        results["slack"]["detail"] = r
    if teams_configured():
        r = send_teams_notification(
            title="✅ APEX Teams webhook is live",
            body="If you can read this, your APEX Teams integration is working.",
            severity="success",
        )
        results["teams"]["sent"] = bool(r.get("success"))
        results["teams"]["detail"] = r
    return {"success": True, "results": results}


@router.post("/broadcast")
def broadcast(
    payload: BroadcastRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Broadcast a custom message to every configured external channel."""
    _verify_admin(x_admin_secret)
    results: dict = {}
    if slack_configured():
        results["slack"] = send_slack_notification(
            title=payload.title,
            body=payload.body,
            url=payload.url,
            severity=payload.severity,
            fields=payload.fields,
        )
    if teams_configured():
        results["teams"] = send_teams_notification(
            title=payload.title,
            body=payload.body,
            url=payload.url,
            severity=payload.severity,
            fields=payload.fields,
        )
    if not results:
        return {
            "success": False,
            "error": "no_external_channels_configured",
            "hint": "Set SLACK_WEBHOOK_URL and/or TEAMS_WEBHOOK_URL env vars.",
        }
    return {"success": True, "results": results}
