"""
APEX — CSRF Middleware (Double-Submit Cookie Pattern)
═════════════════════════════════════════════════════════════════════

Implements the OWASP-recommended "double-submit cookie" defense for
browser clients authenticated via session cookies.

Why this matters:
  • JWT-in-Authorization-header clients (mobile, server-to-server) are
    already immune to CSRF — the browser never auto-attaches custom
    headers cross-origin.
  • Cookie-authenticated browser sessions ARE vulnerable because the
    browser auto-sends cookies on cross-origin form posts.

Strategy:
  1. On any request, if no `apex_csrf` cookie exists, issue one
     containing a cryptographically-random token (64 hex chars).
  2. On state-changing requests (POST/PUT/PATCH/DELETE) to non-exempt
     paths, require BOTH:
       – the `apex_csrf` cookie (sent automatically by browser)
       – an `X-CSRF-Token` header (must be set by JS, proving same-origin)
     And both must match exactly.
  3. Bearer-token (Authorization header) clients bypass the check.

Enable via env: `CSRF_ENABLED=true`. Defaults to off so that existing
bearer-token deployments continue to work unchanged.

Exempt paths (safe-read or public): /health, /auth/login, /auth/register,
/auth/forgot-password, /docs, /openapi.json, /ws/*.
"""
from __future__ import annotations

import secrets
from typing import Iterable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

_EXEMPT_PREFIXES: tuple[str, ...] = (
    "/health",
    "/auth/login",
    "/auth/register",
    "/auth/forgot-password",
    "/auth/social",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/ws",
)

_SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}
_COOKIE_NAME = "apex_csrf"
_HEADER_NAME = "X-CSRF-Token"
_TOKEN_BYTES = 32  # 64 hex chars


def _mint_token() -> str:
    return secrets.token_hex(_TOKEN_BYTES)


def _is_exempt(path: str) -> bool:
    for p in _EXEMPT_PREFIXES:
        if path == p or path.startswith(p + "/") or path.startswith(p + "?"):
            return True
    return False


class CSRFMiddleware(BaseHTTPMiddleware):
    """Double-submit cookie CSRF protection.

    Opt-in via env `CSRF_ENABLED=true` at the main.py mount site.
    """

    def __init__(self, app, exempt_prefixes: Iterable[str] | None = None) -> None:
        super().__init__(app)
        self._exempt = tuple(exempt_prefixes or _EXEMPT_PREFIXES)

    async def dispatch(self, request: Request, call_next):
        method = request.method.upper()
        path = request.url.path

        # Bearer-token clients bypass the CSRF check entirely.
        auth = request.headers.get("authorization", "")
        is_bearer = auth.lower().startswith("bearer ")

        cookie_token = request.cookies.get(_COOKIE_NAME)

        if method in _SAFE_METHODS or _is_exempt(path) or is_bearer:
            # Safe / exempt / bearer — no validation. Still issue token
            # if cookie is missing so the JS client has it available.
            response: Response = await call_next(request)
            if cookie_token is None:
                new_token = _mint_token()
                response.set_cookie(
                    _COOKIE_NAME,
                    new_token,
                    max_age=60 * 60 * 24 * 7,  # 7 days
                    httponly=False,            # JS must read it to echo in header
                    secure=True,
                    samesite="lax",
                    path="/",
                )
            return response

        # State-changing, non-exempt, cookie-auth → validate.
        header_token = request.headers.get(_HEADER_NAME, "")
        if not cookie_token or not header_token or not secrets.compare_digest(
            cookie_token, header_token
        ):
            return JSONResponse(
                status_code=403,
                content={
                    "success": False,
                    "error": {
                        "code": "CSRF_TOKEN_INVALID",
                        "message_ar": "رمز الحماية غير صالح — أعد تحميل الصفحة",
                        "message_en": "CSRF token invalid or missing",
                    },
                },
            )

        return await call_next(request)
