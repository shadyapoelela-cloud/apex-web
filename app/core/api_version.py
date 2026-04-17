"""API versioning — `/api/v1/*` prefix + X-API-Version header.

Strategy:
  • Existing phase routes stay mounted at their current paths for
    backwards compatibility — don't break active clients.
  • NEW public endpoints mount under `/api/v1/` from day one.
  • Middleware stamps every response with `X-API-Version: v1`.
  • When v2 ships, we keep v1 alive for a 6-month deprecation window.

Usage for new routers:

    from app.core.api_version import v1_prefix

    router = APIRouter(prefix=v1_prefix("/employees"), tags=["HR"])

    ... or wrap an existing router when mounting:

    app.include_router(hr_router, prefix="/api/v1")
"""

from __future__ import annotations

import logging

from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

API_VERSION = "v1"
API_PREFIX = f"/api/{API_VERSION}"


def v1_prefix(path: str = "") -> str:
    """Build a `/api/v1/<path>` string. Handles leading slash properly."""
    if not path:
        return API_PREFIX
    if not path.startswith("/"):
        path = "/" + path
    return f"{API_PREFIX}{path}"


class ApiVersionHeaderMiddleware(BaseHTTPMiddleware):
    """Stamp X-API-Version on every response so clients can assert compat."""

    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers.setdefault("X-API-Version", API_VERSION)
        return response
