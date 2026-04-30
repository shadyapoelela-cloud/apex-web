"""APEX — Notification Center routes.

Public:
    GET  /api/v1/inbox?user_id=&tenant_id=&sources=&only_unread=&limit=
    POST /api/v1/inbox/mark-all-read?user_id=&tenant_id=

Admin (X-Admin-Secret):
    GET  /admin/inbox/stats

Wave 1X Phase EEE.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.notification_center import list_inbox, mark_all_read, stats

router = APIRouter(tags=["inbox"])

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


@router.get("/api/v1/inbox")
def public_list(
    user_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = None,
    sources: Optional[str] = Query(
        None,
        description='Comma-separated subset of {"activity","approval","suggestion","system"}',
    ),
    only_unread: bool = Query(False),
    limit: int = Query(200, ge=1, le=500),
    user_roles: Optional[str] = Query(
        None,
        description="Comma-separated role names — needed for suggestion gating",
    ),
):
    src_list: Optional[list[str]] = None
    if sources:
        src_list = [s.strip() for s in sources.split(",") if s.strip()]
    roles_list: Optional[list[str]] = None
    if user_roles:
        roles_list = [r.strip() for r in user_roles.split(",") if r.strip()]
    out = list_inbox(
        user_id,
        tenant_id=tenant_id,
        sources=src_list,
        only_unread=only_unread,
        limit=limit,
        user_roles=roles_list,
    )
    return {"success": True, **out}


@router.post("/api/v1/inbox/mark-all-read")
def public_mark_all_read(
    user_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = None,
):
    cursor = mark_all_read(user_id, tenant_id=tenant_id)
    return {"success": True, "last_read_at": cursor}


@router.get("/admin/inbox/stats")
def admin_stats(
    user_id: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats(user_id=user_id)}
