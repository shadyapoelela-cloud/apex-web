"""APEX — Tenant Directory routes.

Public:
    GET  /api/v1/tenants                   — list active tenants
    GET  /api/v1/tenants/{tenant_id}       — fetch one

Admin (X-Admin-Secret):
    POST   /admin/tenants                  — register or update
    PATCH  /admin/tenants/{tenant_id}      — partial update
    DELETE /admin/tenants/{tenant_id}      — hard delete
    POST   /admin/tenants/{tenant_id}/deactivate
    POST   /admin/tenants/{tenant_id}/activate
    GET    /admin/tenants/stats

Wave 1N Phase TT.
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.tenant_directory import (
    deactivate,
    delete,
    get,
    list_tenants,
    reactivate,
    register,
    stats,
)

router = APIRouter(tags=["tenants"])

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


@router.get("/api/v1/tenants")
def public_list(
    status: Optional[str] = Query(None, pattern="^(active|inactive)$"),
):
    rows = list_tenants(status=status)
    return {"success": True, "tenants": rows, "count": len(rows)}


@router.get("/api/v1/tenants/{tenant_id}")
def public_get(tenant_id: str):
    rec = get(tenant_id)
    if not rec:
        raise HTTPException(404, "tenant not found")
    return {"success": True, "tenant": rec}


# ── Admin ──────────────────────────────────────────────────────


class RegisterTenantRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1, max_length=100)
    display_name: str = Field(..., min_length=1, max_length=200)
    industry_pack_id: Optional[str] = None
    created_by: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)


@router.post("/admin/tenants", status_code=201)
def admin_register(
    payload: RegisterTenantRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        rec = register(
            payload.tenant_id,
            payload.display_name,
            industry_pack_id=payload.industry_pack_id,
            created_by=payload.created_by,
            notes=payload.notes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "tenant": rec}


class UpdateTenantRequest(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=200)
    industry_pack_id: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)


@router.patch("/admin/tenants/{tenant_id}")
def admin_update(
    tenant_id: str,
    payload: UpdateTenantRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rec = get(tenant_id)
    if not rec:
        raise HTTPException(404, "tenant not found")
    # Update via register (idempotent path) — only fields provided.
    new_display = payload.display_name or rec["display_name"]
    new_pack = payload.industry_pack_id if payload.industry_pack_id is not None else rec.get("industry_pack_id")
    new_notes = payload.notes if payload.notes is not None else rec.get("notes")
    rec2 = register(
        tenant_id,
        new_display,
        industry_pack_id=new_pack,
        notes=new_notes,
    )
    return {"success": True, "tenant": rec2}


@router.delete("/admin/tenants/{tenant_id}")
def admin_delete(
    tenant_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not delete(tenant_id):
        raise HTTPException(404, "tenant not found")
    return {"success": True}


@router.post("/admin/tenants/{tenant_id}/deactivate")
def admin_deactivate(
    tenant_id: str,
    reason: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not deactivate(tenant_id, reason=reason):
        raise HTTPException(404, "tenant not found or already inactive")
    return {"success": True}


@router.post("/admin/tenants/{tenant_id}/activate")
def admin_activate(
    tenant_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not reactivate(tenant_id):
        raise HTTPException(404, "tenant not found or already active")
    return {"success": True}


@router.get("/admin/tenants/stats")
def admin_stats(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


class OnboardRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1, max_length=100)
    display_name: str = Field(..., min_length=1, max_length=200)
    industry_pack_id: str = Field(..., min_length=1)
    created_by: Optional[str] = None
    notes: Optional[str] = None
    skip_provisioning: bool = False


@router.get("/admin/tenants/{tenant_id}/overview")
def admin_overview(
    tenant_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """One-shot aggregator: pulls counts from every per-tenant subsystem
    so the Wave 1Y Tenant Detail page can render the full picture in
    a single round-trip.

    Best-effort: each subsystem is wrapped in try/except so a single
    missing module doesn't break the whole overview.
    """
    _verify_admin(x_admin_secret)
    rec = get(tenant_id)
    if not rec:
        raise HTTPException(404, "tenant not found")
    overview: dict[str, Any] = {"tenant": rec}

    # Industry pack assignment
    try:
        from app.core.industry_packs_service import get_assignment
        overview["industry_pack"] = get_assignment(tenant_id)
    except Exception as e:  # noqa: BLE001
        overview["industry_pack_error"] = str(e)

    # Workflow rules + recent runs
    try:
        from app.core.workflow_engine import list_rules
        rules = list_rules(tenant_id=tenant_id)
        overview["workflow"] = {
            "rules_total": len(rules),
            "rules_enabled": sum(1 for r in rules if r.enabled),
            "rules_disabled": sum(1 for r in rules if not r.enabled),
            "total_runs": sum(getattr(r, "run_count", 0) for r in rules),
            "rules_with_errors": sum(1 for r in rules if getattr(r, "last_error", None)),
        }
    except Exception as e:  # noqa: BLE001
        overview["workflow_error"] = str(e)

    # Recent run history
    try:
        from app.core.workflow_run_history import list_runs as _list_runs
        recent_runs = _list_runs(tenant_id=tenant_id, limit=10)
        overview["recent_runs"] = recent_runs
    except Exception as e:  # noqa: BLE001
        overview["recent_runs_error"] = str(e)

    # Approvals breakdown
    try:
        from app.core.approvals import list_approvals
        from dataclasses import asdict as _ad
        rows = [_ad(a) for a in list_approvals(tenant_id=tenant_id)]
        overview["approvals"] = {
            "total": len(rows),
            "by_state": {
                state: sum(1 for r in rows if r.get("state") == state)
                for state in ["pending", "approved", "rejected", "cancelled"]
            },
        }
    except Exception as e:  # noqa: BLE001
        overview["approvals_error"] = str(e)

    # Period locks
    try:
        from app.core.period_lock import list_locks
        locks = list_locks(tenant_id=tenant_id, only_active=False)
        overview["period_locks"] = {
            "total": len(locks),
            "active": sum(1 for r in locks if r.get("unlocked_at") is None),
            "history": sum(1 for r in locks if r.get("unlocked_at")),
        }
    except Exception as e:  # noqa: BLE001
        overview["period_locks_error"] = str(e)

    # Period close cycles
    try:
        from app.core.period_close import list_closes
        closes = list_closes(tenant_id=tenant_id)
        overview["period_close"] = {
            "total": len(closes),
            "by_status": {
                "in_progress": sum(1 for c in closes if c.get("status") == "in_progress"),
                "completed": sum(1 for c in closes if c.get("status") == "completed"),
                "cancelled": sum(1 for c in closes if c.get("status") == "cancelled"),
            },
        }
    except Exception as e:  # noqa: BLE001
        overview["period_close_error"] = str(e)

    # Bank feeds
    try:
        from app.core.bank_feeds import list_connections, list_transactions
        conns = list_connections(tenant_id=tenant_id)
        txns = list_transactions(tenant_id=tenant_id, limit=1000)
        overview["bank_feeds"] = {
            "connections": len(conns),
            "transactions": len(txns),
            "reconciled": sum(1 for t in txns if t.get("matched_entity_id")),
        }
    except Exception as e:  # noqa: BLE001
        overview["bank_feeds_error"] = str(e)

    # Anomaly buffer
    try:
        from app.core.anomaly_live import buffer_size
        overview["anomaly_buffer_size"] = buffer_size(tenant_id)
    except Exception as e:  # noqa: BLE001
        overview["anomaly_error"] = str(e)

    # Custom roles
    try:
        from app.core.custom_roles import list_roles
        roles = list_roles(tenant_id=tenant_id)
        overview["custom_roles"] = {
            "total": len(roles),
        }
    except Exception as e:  # noqa: BLE001
        overview["custom_roles_error"] = str(e)

    # Recent events from event bus filtered to this tenant
    try:
        from app.core.event_bus import recent_events
        all_recent = recent_events(limit=200)
        tenant_events = [
            e for e in all_recent
            if (e.get("payload") or {}).get("tenant_id") == tenant_id
        ]
        overview["recent_events"] = tenant_events[:30]
    except Exception as e:  # noqa: BLE001
        overview["recent_events_error"] = str(e)

    return {"success": True, **overview}


@router.post("/admin/tenants/onboard", status_code=201)
def admin_onboard(
    payload: OnboardRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """One-shot endpoint that the wizard calls.

    Steps:
      1. Register tenant in directory
      2. Apply industry pack (triggers auto-provisioner listener which
         installs workflow templates + flips coa/widgets flags)

    Returns the directory record + the pack assignment summary.
    """
    _verify_admin(x_admin_secret)
    # Step 1
    try:
        rec = register(
            payload.tenant_id,
            payload.display_name,
            industry_pack_id=payload.industry_pack_id,
            created_by=payload.created_by,
            notes=payload.notes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    # Step 2
    assignment: Any = None
    if not payload.skip_provisioning:
        try:
            from app.core.industry_packs_service import apply_pack
            a = apply_pack(
                payload.tenant_id,
                payload.industry_pack_id,
                applied_by=payload.created_by,
                notes=payload.notes,
            )
            from dataclasses import asdict as _asdict
            assignment = _asdict(a)
        except Exception as e:  # noqa: BLE001
            return {
                "success": True,
                "tenant": rec,
                "assignment": None,
                "warning": f"directory_registered_but_pack_apply_failed:{e}",
            }
    return {"success": True, "tenant": rec, "assignment": assignment}
