"""APEX — Industry Pack public + admin routes.

Public endpoints (any caller, no auth needed):
    GET  /api/v1/industry-packs           — summaries (id/name/counts)
    GET  /api/v1/industry-packs/{pack_id} — full COA + widgets

Tenant-scoped (caller passes tenant_id):
    GET  /api/v1/industry-packs/applied?tenant_id=X
                                          — what pack the tenant has

Admin (X-Admin-Secret required):
    POST   /admin/industry-packs/{pack_id}/apply?tenant_id=X
                                          — assign pack to tenant
    DELETE /admin/industry-packs/applied/{tenant_id}
                                          — clear assignment
    GET    /admin/industry-packs/assignments
                                          — every assignment
    GET    /admin/industry-packs/stats    — counts (by_pack, totals)
    POST   /admin/industry-packs/{pack_id}/mark-provisioned?tenant_id=X&coa=&widgets=
                                          — flag downstream provisioning done

Wave 1K Phase PP. Layer 4.4 of FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.industry_packs_service import (
    apply_pack,
    get_assignment,
    get_pack_detail,
    list_assignments,
    list_pack_summaries,
    mark_provisioned,
    remove_assignment,
    stats,
)

router = APIRouter(tags=["industry-packs"])

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


@router.get("/api/v1/industry-packs")
def public_list():
    return {"success": True, "packs": list_pack_summaries()}


@router.get("/api/v1/industry-packs/applied")
def public_applied(tenant_id: str = Query(..., min_length=1)):
    a = get_assignment(tenant_id)
    if not a:
        return {"success": True, "applied": False, "assignment": None}
    return {"success": True, "applied": True, "assignment": a}


@router.get("/api/v1/industry-packs/template-map")
def public_pack_template_map():
    """Public introspection: which templates each pack auto-installs.

    Useful for the UI to show admins what will happen on apply.
    Defined BEFORE the `{pack_id}` route because FastAPI matches in
    declaration order and `template-map` would otherwise be treated as
    a pack_id and return 404.
    """
    try:
        from app.core.industry_pack_provisioner import get_pack_template_map
    except Exception:
        return {"success": True, "template_map": {}}
    return {"success": True, "template_map": get_pack_template_map()}


@router.get("/api/v1/industry-packs/{pack_id}")
def public_detail(pack_id: str):
    d = get_pack_detail(pack_id)
    if d is None:
        raise HTTPException(404, "pack not found")
    return {"success": True, "pack": d}


# ── Admin ──────────────────────────────────────────────────────


class ApplyPackRequest(BaseModel):
    applied_by: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)


@router.post("/admin/industry-packs/{pack_id}/apply", status_code=201)
def admin_apply(
    pack_id: str,
    tenant_id: str = Query(..., min_length=1),
    payload: Optional[ApplyPackRequest] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    body = payload or ApplyPackRequest()
    try:
        a = apply_pack(
            tenant_id,
            pack_id,
            applied_by=body.applied_by,
            notes=body.notes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "assignment": _serialize_assignment(a)}


@router.delete("/admin/industry-packs/applied/{tenant_id}")
def admin_remove(
    tenant_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not remove_assignment(tenant_id):
        raise HTTPException(404, "no assignment for tenant")
    return {"success": True}


@router.get("/admin/industry-packs/assignments")
def admin_list(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_assignments()
    return {"success": True, "assignments": rows, "count": len(rows)}


@router.get("/admin/industry-packs/stats")
def admin_stats(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.post("/admin/industry-packs/{pack_id}/mark-provisioned")
def admin_mark_provisioned(
    pack_id: str,  # accepted for symmetry; the (tenant_id) is the actual key
    tenant_id: str = Query(..., min_length=1),
    coa: bool = Query(False),
    widgets: bool = Query(False),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not mark_provisioned(tenant_id, coa=coa, widgets=widgets):
        raise HTTPException(404, "no assignment for tenant")
    return {"success": True}


@router.post("/admin/industry-packs/{pack_id}/provision")
def admin_run_provisioner(
    pack_id: str,
    tenant_id: str = Query(..., min_length=1),
    seed_coa: bool = Query(True),
    install_workflows: bool = Query(True),
    provision_widgets: bool = Query(True),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Re-run the auto-provisioner manually (e.g. after a partial failure).

    Wave 1M Phase SS — same logic as the listener that fires on
    `industry_pack.applied`, exposed as an admin button.
    """
    _verify_admin(x_admin_secret)
    try:
        from app.core.industry_pack_provisioner import manual_provision
    except Exception as e:  # noqa: BLE001
        raise HTTPException(500, f"provisioner_unavailable:{e}")
    summary = manual_provision(
        tenant_id,
        pack_id,
        seed_coa=seed_coa,
        install_workflows=install_workflows,
        provision_widgets=provision_widgets,
    )
    return {"success": True, "summary": summary}


def _serialize_assignment(a) -> dict:
    from dataclasses import asdict

    return asdict(a)
