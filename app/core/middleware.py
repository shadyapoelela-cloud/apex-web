"""
APEX Platform — Production Middleware
═══════════════════════════════════════════════════════════════
  • Request ID injection (X-Request-ID)
  • Structured request logging
  • Global exception handler (no traceback leak)
  • Response timing header (X-Process-Time)
  • Security headers (CSP, X-Frame, HSTS)
  • Rate limiting (in-memory, per IP)
"""

from __future__ import annotations

import logging
import time
import uuid
from collections import defaultdict
from typing import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response, JSONResponse

logger = logging.getLogger("apex.middleware")


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Inject X-Request-ID into every request/response."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:12])
        request.state.request_id = request_id

        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


class TimingMiddleware(BaseHTTPMiddleware):
    """Add X-Process-Time header."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        elapsed = time.perf_counter() - start
        response.headers["X-Process-Time"] = f"{elapsed:.4f}s"
        return response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add security headers to all responses."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        # HSTS only in production
        if request.url.scheme == "https":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log request method, path, status, and timing."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        elapsed = time.perf_counter() - start
        rid = getattr(request.state, "request_id", "?")

        # Skip health checks from logs
        if request.url.path in ("/", "/health"):
            return response

        logger.info(
            "%s %s → %d (%.3fs) [%s]",
            request.method, request.url.path,
            response.status_code, elapsed, rid,
        )
        return response


class GlobalExceptionMiddleware(BaseHTTPMiddleware):
    """Catch unhandled exceptions — return generic 500, log full trace."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        try:
            return await call_next(request)
        except Exception as exc:
            rid = getattr(request.state, "request_id", "?")
            logger.exception("Unhandled error [%s] %s %s: %s",
                             rid, request.method, request.url.path, exc)
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "error": "Internal server error",
                    "request_id": rid,
                },
            )


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple in-memory rate limiter per client IP.

    Defaults: 60 requests per 60-second window.
    For production scale, replace with Redis-backed limiter.
    """

    def __init__(self, app, max_requests: int = 60, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)

    def _client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Skip rate limiting for health checks
        if request.url.path in ("/", "/health"):
            return await call_next(request)

        ip = self._client_ip(request)
        now = time.time()
        cutoff = now - self.window_seconds

        # Prune old entries
        self._hits[ip] = [t for t in self._hits[ip] if t > cutoff]

        if len(self._hits[ip]) >= self.max_requests:
            retry_after = int(self._hits[ip][0] + self.window_seconds - now) + 1
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "error": "Too many requests",
                    "retry_after": retry_after,
                },
                headers={"Retry-After": str(retry_after)},
            )

        self._hits[ip].append(now)
        return await call_next(request)
