"""APEX — Activity Feed routes.

Public (per-user, no admin secret):
    GET  /api/v1/activity?user_id=&tenant_id=&only_unread=&limit=&offset=
    POST /api/v1/activity/mark-read?user_id=&tenant_id=

Admin (X-Admin-Secret):
    GET    /admin/activity/stats
    DELETE /admin/activity?user_id=

Wave 1P Phase WW.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.activity_feed import clear, list_for_user, mark_read, stats

router = APIRouter(tags=["activity"])

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


@router.get("/api/v1/activity")
def public_list(
    user_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = None,
    only_unread: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    out = list_for_user(
        user_id,
        tenant_id=tenant_id,
        only_unread=only_unread,
        limit=limit,
        offset=offset,
    )
    return {"success": True, **out}


@router.post("/api/v1/activity/mark-read")
def public_mark_read(
    user_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = None,
):
    last_read_at = mark_read(user_id, tenant_id=tenant_id)
    return {"success": True, "last_read_at": last_read_at}


@router.get("/admin/activity/stats")
def admin_stats(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.delete("/admin/activity")
def admin_clear(
    user_id: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    n = clear(user_id=user_id)
    return {"success": True, "removed": n}
