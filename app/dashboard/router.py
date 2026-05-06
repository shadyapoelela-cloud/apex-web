"""FastAPI surface for the dashboard.

Mounted by app/main.py via the HAS_DASHBOARD try/except guard at:

    /api/v1/dashboard/widgets
    /api/v1/dashboard/layout
    /api/v1/dashboard/layout/reset
    /api/v1/dashboard/role-layouts
    /api/v1/dashboard/role-layouts/{role_id}
    /api/v1/dashboard/role-layouts/{role_id}/lock
    /api/v1/dashboard/data/batch
    /api/v1/dashboard/data/{widget_code}
    /api/v1/dashboard/stream    (SSE)

Auth is via the existing `get_current_user` Depends imported from
phase1; no new auth surface here.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any, AsyncIterator, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse

from app.core.api_version import v1_prefix
from app.dashboard.events import hub, register_dashboard_listeners
from app.dashboard.models import DashboardLayout, DashboardWidget, LayoutScope
from app.dashboard.schemas import (
    BatchDataRequest,
    BatchDataResponse,
    LayoutBlock,
    LayoutOut,
    LayoutSaveIn,
    LockToggleIn,
    RoleLayoutSaveIn,
    WidgetOut,
)
from app.dashboard.service import (
    LayoutLockedError,
    PermissionDeniedError,
    compute_batch,
    compute_widget_data,
    get_effective_layout,
    list_widgets_for,
    reset_user_layout,
    save_role_layout,
    save_user_layout,
    set_role_layout_lock,
    user_can,
)
from app.phase1.models.platform_models import SessionLocal

# Reuse the canonical get_current_user from phase1 — same JWT cookie/header
# handling as every other route.
from app.phase1.routes.phase1_routes import get_current_user

logger = logging.getLogger(__name__)

# Side-effect: register event_bus listeners exactly once. Idempotent.
register_dashboard_listeners()

# Side-effect: register the 12 default widget resolvers.
from app.dashboard import resolvers  # noqa: F401,E402  (imports for the side-effect)

router = APIRouter(prefix=v1_prefix("/dashboard"), tags=["Dashboard"])


# ── Helpers ────────────────────────────────────────────────


def _require(user: dict, perm: str) -> None:
    if not user_can(user, perm):
        raise HTTPException(status_code=403, detail=f"missing permission: {perm}")


def _layout_to_out(row: DashboardLayout) -> LayoutOut:
    return LayoutOut(
        id=row.id,
        scope=row.scope,
        owner_id=row.owner_id,
        name=row.name,
        blocks=[LayoutBlock.model_validate(b) for b in (row.blocks or [])],
        is_default=bool(row.is_default),
        is_locked=bool(row.is_locked),
        version=int(row.version or 1),
        updated_at=row.updated_at,
    )


def _widget_to_out(w: DashboardWidget) -> WidgetOut:
    return WidgetOut(
        code=w.code,
        title_ar=w.title_ar,
        title_en=w.title_en,
        description_ar=w.description_ar,
        description_en=w.description_en,
        category=w.category,
        widget_type=w.widget_type,
        data_source=w.data_source,
        default_span=w.default_span,
        min_span=w.min_span,
        max_span=w.max_span,
        required_perms=list(w.required_perms or []),
        config_schema=w.config_schema,
        refresh_secs=w.refresh_secs,
        is_system=bool(w.is_system),
    )


# ── Catalog ────────────────────────────────────────────────


@router.get("/widgets")
def get_widgets(user: dict = Depends(get_current_user)):
    _require(user, "read:dashboard")
    db = SessionLocal()
    try:
        widgets = list_widgets_for(user, db, tenant_id=user.get("tenant_id"))
        return {
            "success": True,
            "data": [_widget_to_out(w).model_dump() for w in widgets],
        }
    finally:
        db.close()


# ── Layout ─────────────────────────────────────────────────


@router.get("/layout")
def get_layout(user: dict = Depends(get_current_user)):
    _require(user, "read:dashboard")
    db = SessionLocal()
    try:
        row = get_effective_layout(user, db, tenant_id=user.get("tenant_id"))
        if row is None:
            return {"success": True, "data": None}
        return {"success": True, "data": _layout_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.put("/layout")
def put_layout(payload: LayoutSaveIn, user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        try:
            row = save_user_layout(
                user,
                payload.blocks,
                db,
                tenant_id=user.get("tenant_id"),
                name=payload.name,
            )
        except PermissionDeniedError as e:
            raise HTTPException(status_code=403, detail=str(e))
        except LayoutLockedError as e:
            raise HTTPException(status_code=423, detail=str(e))
        return {"success": True, "data": _layout_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/layout/reset")
def reset_layout(user: dict = Depends(get_current_user)):
    db = SessionLocal()
    try:
        try:
            row = reset_user_layout(user, db)
        except PermissionDeniedError as e:
            raise HTTPException(status_code=403, detail=str(e))
        return {
            "success": True,
            "data": _layout_to_out(row).model_dump(mode="json") if row else None,
        }
    finally:
        db.close()


# ── Role layouts (admin) ──────────────────────────────────


@router.get("/role-layouts")
def list_role_layouts(user: dict = Depends(get_current_user)):
    _require(user, "manage:dashboard_role")
    db = SessionLocal()
    try:
        rows = (
            db.query(DashboardLayout)
            .filter(DashboardLayout.scope == LayoutScope.ROLE)
            .all()
        )
        return {
            "success": True,
            "data": [_layout_to_out(r).model_dump(mode="json") for r in rows],
        }
    finally:
        db.close()


@router.put("/role-layouts/{role_id}")
def put_role_layout(
    role_id: str,
    payload: RoleLayoutSaveIn,
    user: dict = Depends(get_current_user),
):
    db = SessionLocal()
    try:
        try:
            row = save_role_layout(
                user,
                role_id,
                payload.blocks,
                db,
                tenant_id=user.get("tenant_id"),
                name=payload.name,
            )
        except PermissionDeniedError as e:
            raise HTTPException(status_code=403, detail=str(e))
        return {"success": True, "data": _layout_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


@router.post("/role-layouts/{role_id}/lock")
def lock_role_layout(
    role_id: str,
    payload: LockToggleIn,
    user: dict = Depends(get_current_user),
):
    db = SessionLocal()
    try:
        try:
            row = set_role_layout_lock(user, role_id, payload.is_locked, db)
        except PermissionDeniedError as e:
            raise HTTPException(status_code=403, detail=str(e))
        return {"success": True, "data": _layout_to_out(row).model_dump(mode="json")}
    finally:
        db.close()


# ── Data ───────────────────────────────────────────────────


@router.post("/data/batch")
def post_data_batch(
    payload: BatchDataRequest,
    user: dict = Depends(get_current_user),
):
    _require(user, "read:dashboard")
    ctx = {
        "tenant_id": user.get("tenant_id"),
        "user_id": user.get("user_id") or user.get("sub"),
        "entity_id": payload.entity_id,
        "as_of_date": payload.as_of_date,
    }
    db = SessionLocal()
    try:
        result = compute_batch(payload.widgets, ctx, db=db, user=user)
        return {"success": True, "data": result.model_dump(mode="json")}
    finally:
        db.close()


@router.get("/data/{widget_code}")
def get_widget_data(
    widget_code: str,
    entity_id: Optional[str] = Query(None),
    as_of_date: Optional[str] = Query(None),
    user: dict = Depends(get_current_user),
):
    _require(user, "read:dashboard")
    db = SessionLocal()
    try:
        widget = (
            db.query(DashboardWidget)
            .filter(DashboardWidget.code == widget_code)
            .first()
        )
        if widget is None:
            raise HTTPException(status_code=404, detail="widget not found")
        for p in widget.required_perms or []:
            if not user_can(user, p):
                raise HTTPException(status_code=403, detail=f"missing permission: {p}")
        ctx = {
            "tenant_id": user.get("tenant_id"),
            "user_id": user.get("user_id") or user.get("sub"),
            "entity_id": entity_id,
            "as_of_date": as_of_date,
        }
        try:
            payload = compute_widget_data(widget_code, ctx, db=db)
        except KeyError:
            raise HTTPException(status_code=501, detail="resolver not registered")
        return {"success": True, "data": payload}
    finally:
        db.close()


# ── SSE stream ─────────────────────────────────────────────


async def _sse_iter(user: dict) -> AsyncIterator[bytes]:
    """Yield SSE-framed updates from the hub for one client.

    Sends:
      event: ping            every 25s, keeps proxies from killing the conn
      event: invalidate      when a widget cache was dropped (client refreshes)
      event: update          when a widget got a fresh payload pushed
    """
    q = hub.subscribe()
    try:
        # initial hello
        yield b"event: hello\n"
        yield f"data: {json.dumps({'ok': True, 'ts': datetime.now(timezone.utc).isoformat()})}\n\n".encode("utf-8")
        while True:
            try:
                record = await asyncio.get_event_loop().run_in_executor(
                    None, q.get, True, 25
                )
            except Exception:
                # timeout — emit ping and keep going
                yield b"event: ping\n"
                yield f"data: {json.dumps({'ts': datetime.now(timezone.utc).isoformat()})}\n\n".encode("utf-8")
                continue
            event_name = record.get("type", "update")
            yield f"event: {event_name}\n".encode("utf-8")
            yield f"data: {json.dumps(record, default=str, ensure_ascii=False)}\n\n".encode("utf-8")
    finally:
        hub.unsubscribe(q)


@router.get("/stream")
async def stream(user: dict = Depends(get_current_user)):
    _require(user, "read:dashboard")
    return StreamingResponse(
        _sse_iter(user),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


__all__ = ["router"]
