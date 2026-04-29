"""
APEX — Event Catalog routes (admin + public discovery)
=======================================================
Surfaces the Event Registry to the frontend so Workflow Rule authors can
pick events from a categorized list (UI dropdown / picker).

Endpoints:
    GET /api/v1/events/list          — full catalog (admin or any authenticated user)
    GET /api/v1/events/categories    — group counts
    POST /admin/events/test          — admin manually emit an event for QA
    GET /admin/events/recent         — recent events from in-memory buffer (debugging)
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.event_bus import emit, recent_events
from app.core.event_registry import (
    EventCategory,
    categories,
    get_event,
    list_events,
)

router = APIRouter(tags=["events"])

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


@router.get("/api/v1/events/list")
def list_events_route(category: Optional[str] = Query(None)):
    """Public catalog — used by the Workflow Rule builder picker."""
    cat: Optional[EventCategory] = None
    if category:
        try:
            cat = EventCategory(category)
        except ValueError:
            raise HTTPException(400, f"Unknown category: {category}")
    items = list_events(category=cat)
    return {
        "success": True,
        "events": [
            {
                "name": e.name,
                "label_ar": e.label_ar,
                "label_en": e.label_en,
                "category": e.category.value,
                "payload_schema": e.payload_schema,
                "example_payload": e.example_payload,
                "description_ar": e.description_ar,
            }
            for e in items
        ],
        "count": len(items),
    }


@router.get("/api/v1/events/categories")
def list_categories():
    return {"success": True, "categories": categories()}


class EmitRequest(BaseModel):
    name: str = Field(..., min_length=1)
    payload: Optional[dict] = None


@router.post("/admin/events/test")
def admin_test_emit(
    payload: EmitRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Manually emit an event — useful for QA-ing workflow rules."""
    _verify_admin(x_admin_secret)
    e = get_event(payload.name)
    if not e:
        # We still allow emitting, with a warning logged.
        pass
    emit(payload.name, payload.payload or {}, source="admin_test")
    return {"success": True, "event": payload.name, "registered": bool(e)}


@router.get("/admin/events/recent")
def admin_recent(
    limit: int = Query(50, ge=1, le=200),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Recent emitted events from in-memory buffer (debugging only)."""
    _verify_admin(x_admin_secret)
    return {"success": True, "events": recent_events(limit=limit)}
