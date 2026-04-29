"""APEX — Period Lock routes.

Public read endpoint:
    GET /api/v1/period-locks?tenant_id=X&only_active=true

Admin (X-Admin-Secret):
    POST   /admin/period-locks                 — lock a period
    POST   /admin/period-locks/unlock          — unlock (reason required)
    GET    /admin/period-locks                 — list (filter by tenant)
    GET    /admin/period-locks/stats           — counts
    GET    /admin/period-locks/overrides       — audit log
    POST   /admin/period-locks/check           — simulate posting check
                                                  (returns allowed/blocked
                                                  + audit emission)

Wave 1Q Phase XX.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.period_lock import (
    check_posting,
    get_lock,
    list_locks,
    list_overrides,
    lock_period,
    stats,
    unlock_period,
)

router = APIRouter(tags=["period-locks"])

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


@router.get("/api/v1/period-locks")
def public_list(
    tenant_id: Optional[str] = None,
    only_active: bool = Query(False),
):
    rows = list_locks(tenant_id=tenant_id, only_active=only_active)
    return {"success": True, "locks": rows, "count": len(rows)}


# ── Admin ──────────────────────────────────────────────────────


class LockRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    period_code: str = Field(..., min_length=1, max_length=20)
    locked_by: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)


@router.post("/admin/period-locks", status_code=201)
def admin_lock(
    payload: LockRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        rec = lock_period(
            payload.tenant_id,
            payload.period_code,
            locked_by=payload.locked_by,
            notes=payload.notes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "lock": rec}


class UnlockRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    period_code: str = Field(..., min_length=1, max_length=20)
    unlocked_by: Optional[str] = None
    reason: str = Field(..., min_length=3, max_length=500)


@router.post("/admin/period-locks/unlock")
def admin_unlock(
    payload: UnlockRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        rec = unlock_period(
            payload.tenant_id,
            payload.period_code,
            unlocked_by=payload.unlocked_by,
            reason=payload.reason,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    if rec is None:
        raise HTTPException(404, "no active lock for that period")
    return {"success": True, "lock": rec}


@router.get("/admin/period-locks")
def admin_list(
    tenant_id: Optional[str] = None,
    only_active: bool = Query(False),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_locks(tenant_id=tenant_id, only_active=only_active)
    return {"success": True, "locks": rows, "count": len(rows)}


@router.get("/admin/period-locks/stats")
def admin_stats(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/admin/period-locks/overrides")
def admin_overrides(
    tenant_id: Optional[str] = None,
    period_code: Optional[str] = None,
    action: Optional[str] = Query(None, pattern="^(blocked|allowed_with_override)$"),
    limit: int = Query(100, ge=1, le=500),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_overrides(
        tenant_id=tenant_id, period_code=period_code, action=action, limit=limit
    )
    return {"success": True, "overrides": rows, "count": len(rows)}


@router.get("/admin/period-locks/get")
def admin_get(
    tenant_id: str = Query(..., min_length=1),
    period_code: str = Query(..., min_length=1),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rec = get_lock(tenant_id, period_code)
    if not rec:
        raise HTTPException(404, "no lock for that period")
    return {"success": True, "lock": rec}


class CheckRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    period_code: str = Field(..., min_length=1)
    actor_user_id: Optional[str] = None
    object_type: Optional[str] = None
    object_id: Optional[str] = None
    override_reason: Optional[str] = None
    has_override_permission: bool = False


@router.post("/admin/period-locks/check")
def admin_check(
    payload: CheckRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Simulate a posting check. Useful for QA + the UI's "test" button.

    Note: this also writes to the override audit log. Use sparingly.
    """
    _verify_admin(x_admin_secret)
    res = check_posting(
        payload.tenant_id,
        payload.period_code,
        actor_user_id=payload.actor_user_id,
        object_type=payload.object_type,
        object_id=payload.object_id,
        override_reason=payload.override_reason,
        has_override_permission=payload.has_override_permission,
    )
    return {"success": True, **res}
