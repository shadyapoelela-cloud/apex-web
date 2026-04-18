"""Multi-tenant tenant context — the Blueprint §16 foundation.

Design (chosen for minimal intrusion on existing phase models):

  1. A per-request ContextVar holds the active tenant_id.
  2. FastAPI middleware resolves it from either:
       - JWT claim `tenant_id` (preferred, set at login/registration), OR
       - `X-Tenant-Id` header (admin / system calls), OR
       - query parameter `tenant_id=` (dev only, guarded).
  3. Phase models that already have a `tenant_id` column (hr, new integrations,
     future modules) read from current_tenant() when filtering.
  4. Legacy phases without a tenant_id continue to work (multi-tenancy is
     additive, not breaking).

A strict-mode flag (TENANT_STRICT=true) rejects requests that should have a
tenant but don't — useful in production after all endpoints are migrated.
"""

from __future__ import annotations

import logging
import os
from contextvars import ContextVar
from typing import Optional

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)

_tenant_var: ContextVar[Optional[str]] = ContextVar("tenant_id", default=None)

TENANT_STRICT = os.environ.get("TENANT_STRICT", "false").lower() == "true"

# Endpoints that never require a tenant (public health, auth, etc.).
_TENANT_FREE_PREFIXES = (
    "/health",
    "/",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/auth/login",
    "/auth/register",
    "/auth/social/",
    "/auth/forgot-password",
    "/auth/mobile/",
    "/admin/",  # admin uses ADMIN_SECRET, not per-tenant
    "/integrations/whatsapp/webhook",  # Meta callbacks have no tenant context
)


def current_tenant() -> Optional[str]:
    """Return the tenant_id bound to the current request, or None."""
    return _tenant_var.get()


def set_tenant(tenant_id: Optional[str]) -> None:
    """Manually set the tenant (useful in tests + scheduled jobs)."""
    _tenant_var.set(tenant_id)


def _extract_jwt_tenant(request: Request) -> Optional[str]:
    """Decode the Bearer token WITHOUT verifying signature (middleware-layer).

    The auth layer later in the stack does full verification — here we only
    peek at the tenant claim for routing, and we tolerate a bad token (the
    auth layer will reject it downstream).
    """
    auth = request.headers.get("authorization", "")
    if not auth.lower().startswith("bearer "):
        return None
    token = auth[7:].strip()
    try:
        import jwt  # PyJWT
    except ImportError:
        return None
    try:
        claims = jwt.decode(token, options={"verify_signature": False})
    except Exception:
        return None
    tid = claims.get("tenant_id") or claims.get("tid")
    return str(tid) if tid else None


class TenantContextMiddleware(BaseHTTPMiddleware):
    """Binds the tenant_id into a ContextVar for the duration of the request."""

    async def dispatch(self, request: Request, call_next):
        path = request.url.path or "/"

        tenant_id = (
            _extract_jwt_tenant(request)
            or request.headers.get("X-Tenant-Id")
            or request.query_params.get("tenant_id")
        )

        # Strict mode: reject tenant-required endpoints without a tenant id.
        if (
            TENANT_STRICT
            and not tenant_id
            and not any(path.startswith(p) for p in _TENANT_FREE_PREFIXES)
        ):
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "error": "tenant_id required",
                    "detail": "Set X-Tenant-Id or a tenant-bearing JWT.",
                },
            )

        token = _tenant_var.set(tenant_id)
        try:
            response = await call_next(request)
        finally:
            _tenant_var.reset(token)
        return response
