"""APEX — Workflow Run History admin routes.

All endpoints admin-secret-gated.

    GET    /admin/workflow/runs                — list w/ filters
    GET    /admin/workflow/runs/{run_id}       — single run detail
    GET    /admin/workflow/runs/stats          — counts + top rules/events
    DELETE /admin/workflow/runs                — clear all (or one rule)

Wave 1O Phase VV.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from app.core.workflow_run_history import clear, get_run, list_runs, stats

router = APIRouter(prefix="/admin/workflow/runs", tags=["admin", "workflow-runs"])

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


@router.get("")
def list_route(
    rule_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    event_name: Optional[str] = None,
    status: Optional[str] = Query(None, pattern="^(success|partial|failed)$"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_runs(
        rule_id=rule_id,
        tenant_id=tenant_id,
        event_name=event_name,
        status=status,
        limit=limit,
        offset=offset,
    )
    return {"success": True, "runs": rows, "count": len(rows)}


@router.get("/stats")
def stats_route(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/{run_id}")
def get_route(
    run_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    r = get_run(run_id)
    if not r:
        raise HTTPException(404, "run not found")
    return {"success": True, "run": r}


@router.delete("")
def clear_route(
    rule_id: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    n = clear(rule_id=rule_id)
    return {"success": True, "removed": n}
