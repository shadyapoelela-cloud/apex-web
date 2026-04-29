"""
APEX — Notification Digest admin routes.
=========================================
Cron-friendly endpoint to trigger digest runs. Hook from your scheduler:

    # Daily 09:00 server-time
    0 9 * * *  curl -X POST -H "X-Admin-Secret: $SECRET" \\
                    https://apex-api.example/admin/digest/run?frequency=daily

    # Weekly Monday 09:00
    0 9 * * 1  curl -X POST -H "X-Admin-Secret: $SECRET" \\
                    https://apex-api.example/admin/digest/run?frequency=weekly

Endpoints:
    POST /admin/digest/run          — process all due digests for a frequency
    POST /admin/digest/preview      — admin previews the digest for a single user
                                      (no actual send) — useful for QA
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel

from app.core.notification_digest import (
    build_digest_for_user,
    process_all_due_digests,
    send_digest_for_user,
)

router = APIRouter(prefix="/admin/digest", tags=["admin", "notifications", "digest"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x_admin_secret: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return  # dev-only fallback
    if not x_admin_secret or not secrets.compare_digest(x_admin_secret, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


@router.post("/run")
def run_digest(
    frequency: str = Query("daily", pattern="^(daily|weekly)$"),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Process all due digests for the given frequency. Cron entry point."""
    _verify_admin(x_admin_secret)
    return process_all_due_digests(frequency=frequency)


class PreviewRequest(BaseModel):
    user_id: str
    frequency: str = "daily"
    send: bool = False  # if True, actually send; if False, return preview only


@router.post("/preview")
def preview_digest(
    payload: PreviewRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Preview (or send) a digest for a single user. Useful for QA + previews."""
    _verify_admin(x_admin_secret)
    if payload.send:
        return send_digest_for_user(payload.user_id, frequency=payload.frequency)
    return build_digest_for_user(payload.user_id, frequency=payload.frequency)
