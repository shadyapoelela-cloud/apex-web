"""
APEX — API Keys HTTP routes
============================
Admin endpoints to issue + manage API keys, plus a tiny self-test.

Endpoints (all admin-secret-gated except /me which uses the key itself):
    GET    /admin/api-keys                      — list (filter by tenant/user)
    POST   /admin/api-keys                      — create (returns raw_secret ONCE)
    GET    /admin/api-keys/{id}                 — get one (no secret)
    PATCH  /admin/api-keys/{id}                 — update meta (name, scopes…)
    POST   /admin/api-keys/{id}/revoke          — revoke
    GET    /admin/api-keys/stats                — global stats
    GET    /api/v1/api-keys/me                  — introspect current key
                                                  (use header X-API-Key)
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.api_keys import (
    create_key,
    get_key,
    list_keys,
    revoke_key,
    stats,
    update_key_meta,
    verify_key,
)

router = APIRouter(tags=["api-keys"])

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


def _serialize(k) -> dict:
    return {
        "id": k.id,
        "name": k.name,
        "prefix": k.prefix,
        "scopes": k.scopes,
        "tenant_id": k.tenant_id,
        "owner_user_id": k.owner_user_id,
        "description": k.description,
        "enabled": k.enabled,
        "expires_at": k.expires_at,
        "allowed_ips": k.allowed_ips,
        "rate_limit_per_minute": k.rate_limit_per_minute,
        "created_at": k.created_at,
        "last_used_at": k.last_used_at,
        "use_count": k.use_count,
        "revoked_at": k.revoked_at,
        "revoked_reason": k.revoked_reason,
    }


class CreateKeyRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    scopes: list[str] = Field(default_factory=list)
    tenant_id: Optional[str] = None
    owner_user_id: Optional[str] = None
    description: Optional[str] = None
    expires_at: Optional[str] = None  # ISO datetime
    allowed_ips: list[str] = Field(default_factory=list)
    rate_limit_per_minute: int = 60


class UpdateKeyRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    scopes: Optional[list[str]] = None
    enabled: Optional[bool] = None
    expires_at: Optional[str] = None
    allowed_ips: Optional[list[str]] = None
    rate_limit_per_minute: Optional[int] = None


class RevokeRequest(BaseModel):
    reason: Optional[str] = None


@router.get("/admin/api-keys")
def list_route(
    tenant_id: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    include_revoked: bool = False,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_keys(
        tenant_id=tenant_id,
        owner_user_id=owner_user_id,
        include_revoked=include_revoked,
    )
    return {"success": True, "keys": [_serialize(k) for k in rows], "count": len(rows)}


@router.post("/admin/api-keys", status_code=201)
def create_route(
    payload: CreateKeyRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    try:
        key, raw = create_key(
            name=payload.name,
            scopes=payload.scopes,
            tenant_id=payload.tenant_id,
            owner_user_id=payload.owner_user_id,
            description=payload.description,
            expires_at=payload.expires_at,
            allowed_ips=payload.allowed_ips,
            rate_limit_per_minute=payload.rate_limit_per_minute,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))

    return {
        "success": True,
        "key": _serialize(key),
        "raw_secret": raw,  # ⚠️ shown ONLY at creation; never returned again
        "warning": "Store this secret securely. It will not be shown again.",
    }


@router.get("/admin/api-keys/stats")
def stats_route(x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret")):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/admin/api-keys/{key_id}")
def get_route(
    key_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    k = get_key(key_id)
    if not k:
        raise HTTPException(404, "API key not found")
    return {"success": True, "key": _serialize(k)}


@router.patch("/admin/api-keys/{key_id}")
def update_route(
    key_id: str,
    payload: UpdateKeyRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    k = update_key_meta(
        key_id,
        **{kk: vv for kk, vv in payload.model_dump(exclude_unset=True).items()},
    )
    if not k:
        raise HTTPException(404, "API key not found")
    return {"success": True, "key": _serialize(k)}


@router.post("/admin/api-keys/{key_id}/revoke")
def revoke_route(
    key_id: str,
    payload: RevokeRequest,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    if not revoke_key(key_id, reason=payload.reason):
        raise HTTPException(404, "API key not found or already revoked")
    return {"success": True}


@router.get("/api/v1/api-keys/me")
def whoami(
    request: Request,
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    """Introspection: returns the calling key's record (or 401)."""
    if not x_api_key:
        raise HTTPException(401, "X-API-Key header required")
    ip = request.client.host if request.client else None
    key, reason = verify_key(x_api_key, request_ip=ip)
    if not key:
        raise HTTPException(401, f"Key invalid: {reason}")
    return {"success": True, "key": _serialize(key)}
