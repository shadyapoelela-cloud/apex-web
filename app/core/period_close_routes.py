"""APEX — Period Close Checklist routes.

The model + service in `app/core/period_close.py` exist but had no
HTTP surface. Wave 1T Phase AAA wires them up so the Flutter
checklist UI can drive close cycles end-to-end.

Endpoints (all admin-secret-gated for now — production-grade would
key off accountant role):

    POST   /admin/period-close/start          — start a new close cycle
    POST   /admin/period-close/tasks/{id}/complete — mark task done
    GET    /admin/period-close/{close_id}     — full close + tasks
    GET    /admin/period-close                — list closes
    GET    /admin/period-close/templates      — the 12 default tasks

Wave 1T Phase AAA.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.period_close import (
    DEFAULT_CLOSE_TASKS,
    complete_task,
    get_close,
    list_closes,
    start_close,
)

router = APIRouter(prefix="/admin/period-close", tags=["admin", "period-close"])

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


class StartCloseRequest(BaseModel):
    tenant_id: str = Field(..., min_length=1)
    entity_id: str = Field(..., min_length=1)
    fiscal_period_id: str = Field(..., min_length=1)
    period_code: str = Field(..., min_length=1, max_length=20)


@router.post("/start", status_code=201)
def start_route(
    payload: StartCloseRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        close_id = start_close(
            tenant_id=payload.tenant_id,
            entity_id=payload.entity_id,
            fiscal_period_id=payload.fiscal_period_id,
            period_code=payload.period_code,
        )
    except Exception as e:  # noqa: BLE001
        raise HTTPException(500, f"failed to start close: {e}")
    return {"success": True, "close_id": close_id}


class CompleteTaskRequest(BaseModel):
    user_id: str = Field(..., min_length=1)
    notes: Optional[str] = Field(None, max_length=1000)


@router.post("/tasks/{task_id}/complete")
def complete_task_route(
    task_id: str,
    payload: CompleteTaskRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        result = complete_task(
            task_id=task_id, user_id=payload.user_id, notes=payload.notes
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:  # noqa: BLE001
        raise HTTPException(500, f"failed to complete task: {e}")
    return {"success": True, **result}


@router.get("/{close_id}")
def get_route(
    close_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    c = get_close(close_id)
    if not c:
        raise HTTPException(404, "close not found")
    return {"success": True, "close": c}


@router.get("")
def list_route(
    tenant_id: Optional[str] = Query(None),
    entity_id: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_closes(tenant_id=tenant_id, entity_id=entity_id)
    return {"success": True, "closes": rows, "count": len(rows)}


@router.get("/templates/default")
def default_tasks_route(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Returns the 12 default close tasks — useful for wizard preview."""
    _verify_admin(x_admin_secret)
    return {"success": True, "tasks": DEFAULT_CLOSE_TASKS}
