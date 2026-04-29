"""
APEX — Webhook Subscriptions HTTP routes
=========================================
CRUD for webhook subscriptions + manual delivery test.

Endpoints:
    GET    /admin/webhooks                       — list all (admin only)
    POST   /admin/webhooks                       — create
    GET    /admin/webhooks/{id}                  — get one
    PATCH  /admin/webhooks/{id}                  — update (enable/disable etc.)
    DELETE /admin/webhooks/{id}                  — delete
    POST   /admin/webhooks/{id}/reset            — clear failure state, re-enable
    GET    /admin/webhooks/stats                 — global stats
    POST   /admin/webhooks/{id}/test             — manual delivery with sample
"""

from __future__ import annotations

import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.webhook_subscriptions import (
    create_subscription,
    delete_subscription,
    get_subscription,
    list_subscriptions,
    reset_failure_state,
    stats,
    update_subscription,
)
from app.core.webhook_subscriptions import _deliver as _internal_deliver

router = APIRouter(prefix="/admin/webhooks", tags=["admin", "webhooks"])

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


def _serialize(s, *, redact_secret: bool = True) -> dict:
    d = {
        "id": s.id,
        "event_pattern": s.event_pattern,
        "target_url": s.target_url,
        "has_secret": bool(s.secret),
        "enabled": s.enabled,
        "owner_user_id": s.owner_user_id,
        "tenant_id": s.tenant_id,
        "description": s.description,
        "tags": s.tags,
        "timeout_seconds": s.timeout_seconds,
        "max_retries": s.max_retries,
        "max_consecutive_fails": s.max_consecutive_fails,
        "created_at": s.created_at,
        "updated_at": s.updated_at,
        "last_delivered_at": s.last_delivered_at,
        "last_status": s.last_status,
        "last_error": s.last_error,
        "deliveries_total": s.deliveries_total,
        "deliveries_failed": s.deliveries_failed,
        "consecutive_failures": s.consecutive_failures,
    }
    if not redact_secret:
        d["secret"] = s.secret
    return d


class CreateSubRequest(BaseModel):
    event_pattern: str = Field(..., min_length=1, max_length=120)
    target_url: str = Field(..., min_length=8, max_length=500)
    secret: Optional[str] = Field(None, min_length=8, max_length=200)
    description: Optional[str] = None
    tenant_id: Optional[str] = None
    owner_user_id: Optional[str] = None
    tags: list[str] = Field(default_factory=list)
    timeout_seconds: int = 10
    max_retries: int = 3
    enabled: bool = True


class UpdateSubRequest(BaseModel):
    event_pattern: Optional[str] = Field(None, min_length=1, max_length=120)
    target_url: Optional[str] = Field(None, min_length=8, max_length=500)
    secret: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = None
    tags: Optional[list[str]] = None
    timeout_seconds: Optional[int] = None
    max_retries: Optional[int] = None
    enabled: Optional[bool] = None


@router.get("")
def list_route(
    tenant_id: Optional[str] = None,
    enabled: Optional[bool] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    rows = list_subscriptions(tenant_id=tenant_id, enabled=enabled)
    return {
        "success": True,
        "subscriptions": [_serialize(s) for s in rows],
        "count": len(rows),
    }


@router.post("", status_code=201)
def create_route(
    payload: CreateSubRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    try:
        s = create_subscription(
            event_pattern=payload.event_pattern,
            target_url=payload.target_url,
            secret=payload.secret,
            description=payload.description,
            tenant_id=payload.tenant_id,
            owner_user_id=payload.owner_user_id,
            tags=payload.tags,
            timeout_seconds=payload.timeout_seconds,
            max_retries=payload.max_retries,
            enabled=payload.enabled,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"success": True, "subscription": _serialize(s)}


@router.get("/stats")
def stats_route(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/{sub_id}")
def get_route(
    sub_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    s = get_subscription(sub_id)
    if not s:
        raise HTTPException(404, "Subscription not found")
    return {"success": True, "subscription": _serialize(s)}


@router.patch("/{sub_id}")
def update_route(
    sub_id: str,
    payload: UpdateSubRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    s = update_subscription(
        sub_id,
        **{k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None},
    )
    if not s:
        raise HTTPException(404, "Subscription not found")
    return {"success": True, "subscription": _serialize(s)}


@router.delete("/{sub_id}")
def delete_route(
    sub_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    ok = delete_subscription(sub_id)
    if not ok:
        raise HTTPException(404, "Subscription not found")
    return {"success": True}


@router.post("/{sub_id}/reset")
def reset_route(
    sub_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify(x_admin_secret)
    if not reset_failure_state(sub_id):
        raise HTTPException(404, "Subscription not found")
    return {"success": True}


class TestDeliveryRequest(BaseModel):
    event: str = Field("webhook.test", min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)


@router.post("/{sub_id}/test")
def test_route(
    sub_id: str,
    payload: TestDeliveryRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Manually deliver a synthetic event to a single subscription."""
    _verify(x_admin_secret)
    s = get_subscription(sub_id)
    if not s:
        raise HTTPException(404, "Subscription not found")
    # Fire through the same delivery path the event_bus uses.
    _internal_deliver(s, payload.event, payload.payload)
    s2 = get_subscription(sub_id)  # reload to get updated stats
    return {"success": True, "subscription": _serialize(s2)}
