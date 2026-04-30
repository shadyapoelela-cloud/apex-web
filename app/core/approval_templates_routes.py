"""APEX — Approval Templates routes.

Public:
    GET /api/v1/approval-templates              — list
    GET /api/v1/approval-templates/{id}         — detail
    GET /api/v1/approval-templates/categories   — distinct list

Admin (X-Admin-Secret):
    POST   /admin/approval-templates            — create
    DELETE /admin/approval-templates/{id}       — delete (custom only)
    POST   /admin/approval-templates/{id}/apply — instantiate as approval
    GET    /admin/approval-templates/stats

Wave 1V Phase CCC.
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.approval_templates import (
    apply_template,
    create_template,
    delete_template,
    get_template,
    list_templates,
    stats,
)

router = APIRouter(tags=["approval-templates"])

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


@router.get("/api/v1/approval-templates")
def public_list(category: Optional[str] = Query(None)):
    rows = list_templates(category=category)
    return {"success": True, "templates": rows, "count": len(rows)}


@router.get("/api/v1/approval-templates/categories")
def public_categories():
    rows = list_templates()
    cats = sorted({r["category"] for r in rows})
    return {"success": True, "categories": cats}


@router.get("/api/v1/approval-templates/{template_id}")
def public_detail(template_id: str):
    t = get_template(template_id)
    if not t:
        raise HTTPException(404, "template not found")
    return {"success": True, "template": t}


# ── Admin ──────────────────────────────────────────────────────


class StagePayload(BaseModel):
    sequence: int = Field(..., ge=1)
    kind: str = Field(..., pattern="^(all_required|any_one|majority)$")
    title_ar: str = Field(..., min_length=1, max_length=200)
    approver_user_ids: list[str] = Field(..., min_length=1)
    notes_ar: Optional[str] = None


class CreateTemplateRequest(BaseModel):
    name_ar: str = Field(..., min_length=1, max_length=200)
    name_en: str = Field(..., min_length=1, max_length=200)
    category: str = Field(
        ..., pattern="^(finance|procurement|hr|compliance|ops)$"
    )
    description_ar: str = Field(..., min_length=1, max_length=500)
    icon: str = Field(default="task_alt", max_length=40)
    object_type: Optional[str] = Field(None, max_length=40)
    auto_trigger: Optional[dict[str, Any]] = None
    stages: list[StagePayload] = Field(..., min_length=1)


@router.post("/admin/approval-templates", status_code=201)
def admin_create(
    payload: CreateTemplateRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        t = create_template(
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            category=payload.category,
            description_ar=payload.description_ar,
            stages=[s.model_dump() for s in payload.stages],
            object_type=payload.object_type,
            icon=payload.icon,
            auto_trigger=payload.auto_trigger,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "template": t}


@router.delete("/admin/approval-templates/{template_id}")
def admin_delete(
    template_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        ok = delete_template(template_id)
    except ValueError as e:
        raise HTTPException(400, str(e))
    if not ok:
        raise HTTPException(404, "template not found")
    return {"success": True}


class ApplyTemplateRequest(BaseModel):
    title_ar: str = Field(..., min_length=1, max_length=300)
    body: Optional[str] = Field(None, max_length=2000)
    object_id: Optional[str] = None
    parameters: dict[str, str] = Field(default_factory=dict)
    requested_by: Optional[str] = None
    tenant_id: Optional[str] = None


@router.post("/admin/approval-templates/{template_id}/apply", status_code=201)
def admin_apply(
    template_id: str,
    payload: ApplyTemplateRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        result = apply_template(
            template_id,
            title_ar=payload.title_ar,
            body=payload.body,
            object_id=payload.object_id,
            parameters=payload.parameters,
            requested_by=payload.requested_by,
            tenant_id=payload.tenant_id,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    except RuntimeError as e:
        raise HTTPException(500, str(e))
    return {"success": True, **result}


@router.get("/admin/approval-templates/stats")
def admin_stats(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}
