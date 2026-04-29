"""
APEX — Custom Roles HTTP routes
================================
Admin endpoints for tenant-level custom-role management + permission audit.

    GET    /api/v1/permissions/catalog               — list permissions (public)
    GET    /api/v1/permissions/categories            — group counts (public)
    GET    /admin/roles?tenant_id=...                — list custom roles
    POST   /admin/roles                              — create
    GET    /admin/roles/{id}                         — get one
    PATCH  /admin/roles/{id}                         — update
    DELETE /admin/roles/{id}                         — delete
    POST   /admin/roles/{id}/assign                  — assign to user
    POST   /admin/roles/{id}/revoke                  — revoke from user
    GET    /admin/roles/effective                    — what perms does user X have in tenant Y?
    GET    /admin/roles/stats                        — counts
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.custom_roles import (
    assign_role,
    create_role,
    delete_role,
    effective_permissions,
    get_role,
    list_permissions,
    list_roles,
    revoke_role,
    stats,
    update_role,
)

router = APIRouter(tags=["roles", "permissions"])

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


def _serialize_role(r) -> dict:
    return {
        "id": r.id,
        "tenant_id": r.tenant_id,
        "name_ar": r.name_ar,
        "name_en": r.name_en,
        "description": r.description,
        "permissions": r.permissions,
        "enabled": r.enabled,
        "created_by": r.created_by,
        "created_at": r.created_at,
        "updated_at": r.updated_at,
    }


# ── Permission catalog (public) ──────────────────────────────


@router.get("/api/v1/permissions/catalog")
def perms_catalog(category: Optional[str] = Query(None)):
    items = list_permissions(category=category)
    return {
        "success": True,
        "permissions": [
            {
                "id": p.id,
                "label_ar": p.label_ar,
                "label_en": p.label_en,
                "category": p.category,
            }
            for p in items
        ],
        "count": len(items),
    }


@router.get("/api/v1/permissions/categories")
def perms_categories():
    by_cat: dict[str, int] = {}
    for p in list_permissions():
        by_cat[p.category] = by_cat.get(p.category, 0) + 1
    labels_ar = {
        "finance": "المالية",
        "hr": "الموارد البشرية",
        "compliance": "الامتثال",
        "analytics": "التحليلات",
        "platform": "المنصة",
        "admin": "الإدارة",
    }
    return {
        "success": True,
        "categories": [
            {
                "value": c,
                "label_ar": labels_ar.get(c, c.title()),
                "label_en": c.title(),
                "count": by_cat[c],
            }
            for c in sorted(by_cat.keys())
        ],
    }


# ── Roles CRUD (admin) ──────────────────────────────────────


class CreateRoleRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    name_ar: str = Field(..., min_length=1, max_length=120)
    name_en: Optional[str] = None
    description: Optional[str] = None
    permissions: list[str] = Field(default_factory=list)
    created_by: Optional[str] = None


class UpdateRoleRequest(BaseModel):
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    description: Optional[str] = None
    permissions: Optional[list[str]] = None
    enabled: Optional[bool] = None


class AssignRequest(BaseModel):
    user_id: str = Field(..., min_length=1)
    assigned_by: Optional[str] = None


@router.get("/admin/roles")
def list_route(
    tenant_id: str = Query(..., min_length=1),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    rows = list_roles(tenant_id)
    return {"success": True, "roles": [_serialize_role(r) for r in rows], "count": len(rows)}


@router.post("/admin/roles", status_code=201)
def create_route(
    payload: CreateRoleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    try:
        r = create_role(
            tenant_id=payload.tenant_id,
            name_ar=payload.name_ar,
            name_en=payload.name_en,
            description=payload.description,
            permissions=payload.permissions,
            created_by=payload.created_by,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "role": _serialize_role(r)}


@router.get("/admin/roles/stats")
def stats_route(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/admin/roles/effective")
def effective_route(
    user_id: str = Query(..., min_length=1),
    tenant_id: str = Query(..., min_length=1),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Resolves all permissions a user has via custom roles in a tenant."""
    _verify(x_admin_secret)
    perms = sorted(effective_permissions(user_id, tenant_id))
    return {
        "success": True,
        "user_id": user_id,
        "tenant_id": tenant_id,
        "permissions": perms,
        "count": len(perms),
    }


@router.get("/admin/roles/{role_id}")
def get_route(
    role_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    r = get_role(role_id)
    if not r:
        raise HTTPException(404, "Role not found")
    return {"success": True, "role": _serialize_role(r)}


@router.patch("/admin/roles/{role_id}")
def update_route(
    role_id: str,
    payload: UpdateRoleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    try:
        r = update_role(
            role_id,
            **{k: v for k, v in payload.model_dump(exclude_unset=True).items()},
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    if not r:
        raise HTTPException(404, "Role not found")
    return {"success": True, "role": _serialize_role(r)}


@router.delete("/admin/roles/{role_id}")
def delete_route(
    role_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    if not delete_role(role_id):
        raise HTTPException(404, "Role not found")
    return {"success": True}


@router.post("/admin/roles/{role_id}/assign")
def assign_route(
    role_id: str,
    payload: AssignRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    if not assign_role(payload.user_id, role_id, assigned_by=payload.assigned_by):
        raise HTTPException(404, "Role not found")
    return {"success": True}


@router.post("/admin/roles/{role_id}/revoke")
def revoke_route(
    role_id: str,
    payload: AssignRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    if not revoke_role(payload.user_id, role_id):
        raise HTTPException(404, "Assignment not found")
    return {"success": True}
