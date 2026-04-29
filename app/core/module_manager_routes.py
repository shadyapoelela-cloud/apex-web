"""
APEX — Module Manager HTTP routes
==================================
Browse the module catalog + view/toggle per-tenant module state.

Public:
    GET /api/v1/modules/catalog                              — full catalog
    GET /api/v1/modules/categories                           — group counts
    GET /api/v1/modules/effective?tenant_id=...              — per-tenant resolution

Admin:
    POST /admin/modules/set                                   — enable/disable
        body: {"tenant_id":"...", "module_id":"...", "enabled":true}
    POST /admin/modules/reset                                — drop all overrides
        body: {"tenant_id":"..."}
    GET  /admin/modules/stats                                — adoption stats
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.module_manager import (
    effective_modules,
    list_modules,
    reset_tenant,
    set_module,
    stats,
)

router = APIRouter(tags=["modules"])

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


def _serialize(m) -> dict:
    return {
        "id": m.id,
        "name_ar": m.name_ar,
        "name_en": m.name_en,
        "category": m.category,
        "description_ar": m.description_ar,
        "icon": m.icon,
        "default_enabled": m.default_enabled,
        "requires": list(m.requires),
        "min_plan": m.min_plan,
    }


@router.get("/api/v1/modules/catalog")
def catalog_route(category: Optional[str] = Query(None)):
    items = list_modules(category=category)
    return {
        "success": True,
        "modules": [_serialize(m) for m in items],
        "count": len(items),
    }


@router.get("/api/v1/modules/categories")
def categories_route():
    by_cat: dict[str, int] = {}
    for m in list_modules():
        by_cat[m.category] = by_cat.get(m.category, 0) + 1
    labels_ar = {
        "core": "الأساسية",
        "finance": "المالية",
        "ops": "العمليات",
        "hr": "الموارد البشرية",
        "compliance": "الامتثال",
        "analytics": "التحليلات",
        "ai": "الذكاء الاصطناعي",
        "platform": "المنصة",
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


@router.get("/api/v1/modules/effective")
def effective_route(tenant_id: str = Query(..., min_length=1)):
    eff = effective_modules(tenant_id)
    return {
        "success": True,
        "tenant_id": tenant_id,
        "modules": eff,
        "enabled_count": sum(1 for v in eff.values() if v),
        "total_count": len(eff),
    }


class SetModuleRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    module_id: str = Field(..., min_length=1)
    enabled: bool


@router.post("/admin/modules/set")
def set_route(
    payload: SetModuleRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    try:
        return set_module(payload.tenant_id, payload.module_id, payload.enabled)
    except ValueError as e:
        raise HTTPException(400, str(e))


class ResetTenantRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)


@router.post("/admin/modules/reset")
def reset_route(
    payload: ResetTenantRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    return reset_tenant(payload.tenant_id)


@router.get("/admin/modules/stats")
def stats_route(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    return {"success": True, **stats()}
