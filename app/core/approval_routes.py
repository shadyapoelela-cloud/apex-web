"""
APEX — Approval Chains HTTP routes.
====================================
Endpoints for the approval inbox + decisions + admin management.

Public/auth (X-User-Id header for v1; production should derive from JWT):
    GET  /api/v1/approvals/inbox?user_id=...     — pending approvals for me
    GET  /api/v1/approvals/{id}                  — read a single approval
    POST /api/v1/approvals/{id}/approve          — approve current stage
    POST /api/v1/approvals/{id}/reject           — reject current stage

Admin (X-Admin-Secret):
    GET    /admin/approvals                      — list/filter all approvals
    POST   /admin/approvals                      — manually create one (testing)
    DELETE /admin/approvals/{id}                 — cancel
    GET    /admin/approvals/stats                — counts
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.approvals import (
    cancel_approval,
    create_approval,
    decide,
    get_approval,
    list_approvals,
    stats,
)

router = APIRouter(tags=["approvals"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x_admin_secret: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x_admin_secret or not secrets.compare_digest(x_admin_secret, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


def _serialize(a) -> dict:
    return {
        "id": a.id,
        "title_ar": a.title_ar,
        "title_en": a.title_en,
        "body": a.body,
        "object_type": a.object_type,
        "object_id": a.object_id,
        "stages": [
            {
                "stage": s.stage,
                "user_id": s.user_id,
                "decision": s.decision,
                "decided_at": s.decided_at,
                "comment": s.comment,
            }
            for s in a.stages
        ],
        "current_stage": a.current_stage,
        "state": a.state,
        "requested_by": a.requested_by,
        "rule_id": a.rule_id,
        "tenant_id": a.tenant_id,
        "meta": a.meta,
        "created_at": a.created_at,
        "updated_at": a.updated_at,
    }


# ── Public / authed routes ────────────────────────────────────────


@router.get("/api/v1/approvals/inbox")
def inbox(
    user_id: str = Query(..., min_length=1),
    tenant_id: Optional[str] = Query(None),
):
    """Approvals waiting on a specific user (their inbox)."""
    rows = list_approvals(
        tenant_id=tenant_id, user_id=user_id, pending_for_user_only=True
    )
    return {
        "success": True,
        "approvals": [_serialize(a) for a in rows],
        "count": len(rows),
    }


@router.get("/api/v1/approvals/{approval_id}")
def get_one(approval_id: str):
    a = get_approval(approval_id)
    if not a:
        raise HTTPException(404, "Approval not found")
    return {"success": True, "approval": _serialize(a)}


class DecideRequest(BaseModel):
    user_id: str
    comment: Optional[str] = None


@router.post("/api/v1/approvals/{approval_id}/approve")
def approve(approval_id: str, payload: DecideRequest):
    try:
        return decide(
            approval_id, user_id=payload.user_id, decision="approved", comment=payload.comment
        )
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.post("/api/v1/approvals/{approval_id}/reject")
def reject(approval_id: str, payload: DecideRequest):
    try:
        return decide(
            approval_id, user_id=payload.user_id, decision="rejected", comment=payload.comment
        )
    except ValueError as e:
        raise HTTPException(400, str(e))


# ── Admin routes ─────────────────────────────────────────────────


@router.get("/admin/approvals")
def admin_list(
    tenant_id: Optional[str] = None,
    user_id: Optional[str] = None,
    state: Optional[str] = Query(None, pattern="^(pending|approved|rejected|cancelled)$"),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_approvals(tenant_id=tenant_id, user_id=user_id, state=state)
    return {"success": True, "approvals": [_serialize(a) for a in rows], "count": len(rows)}


class CreateApprovalRequest(BaseModel):
    title_ar: str = Field(..., min_length=1, max_length=300)
    title_en: Optional[str] = None
    body: Optional[str] = None
    object_type: Optional[str] = None
    object_id: Optional[str] = None
    approver_user_ids: list[str] = Field(..., min_length=1)
    requested_by: Optional[str] = None
    tenant_id: Optional[str] = None
    meta: dict[str, Any] = Field(default_factory=dict)


@router.post("/admin/approvals", status_code=201)
def admin_create(
    payload: CreateApprovalRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Manually create an approval (smoke-test path)."""
    _verify_admin(x_admin_secret)
    a = create_approval(
        title_ar=payload.title_ar,
        title_en=payload.title_en,
        body=payload.body,
        object_type=payload.object_type,
        object_id=payload.object_id,
        approver_user_ids=payload.approver_user_ids,
        requested_by=payload.requested_by,
        tenant_id=payload.tenant_id,
        meta=payload.meta,
    )
    return {"success": True, "approval": _serialize(a)}


@router.delete("/admin/approvals/{approval_id}")
def admin_cancel(
    approval_id: str,
    reason: Optional[str] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    ok = cancel_approval(approval_id, reason=reason)
    if not ok:
        raise HTTPException(404, "Approval not found or not pending")
    return {"success": True}


@router.get("/admin/approvals/stats")
def admin_stats(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}
