"""Idempotency middleware — dedupe retries on mutating requests.

Stripe-style idempotency: a client retries a POST/PUT/PATCH with an
`Idempotency-Key` header; the server stores the first response against
that key and replays it for any retry within a TTL window. Prevents
recurring-invoice jobs, network-flake retries, and double-taps on a
"pay" button from creating duplicate writes.

Contract:
  • Only scoped to mutating methods (POST / PUT / PATCH / DELETE).
  • Key storage scope: (tenant_id or anon, key) → cached response for 24h.
  • A mismatched key with a different body for the same tenant is a
    user error (409 Conflict) — same key must always map to same body.
  • Storage is in-memory by default (for dev / tests / single-pod prod);
    a Redis backend trivially drops in via the REDIS_URL path elsewhere
    in the project.

Register once in main.py *before* the CORS middleware:

    from app.core.idempotency import IdempotencyMiddleware
    app.add_middleware(IdempotencyMiddleware)
"""

from __future__ import annotations

import hashlib
import json
import logging
import threading
import time
from typing import Any, Optional

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)


# ── In-memory store with TTL ──────────────────────────────


_DEFAULT_TTL_SECONDS = 24 * 60 * 60
_MAX_ENTRIES = 10_000   # keeps memory bounded; LRU-ish via insertion order


class _IdempotencyStore:
    """Thread-safe dict with per-key expiration. Simple, sufficient for
    single-pod deployments. Swap for Redis when horizontally scaled."""

    def __init__(self, ttl_seconds: int = _DEFAULT_TTL_SECONDS,
                 max_entries: int = _MAX_ENTRIES) -> None:
        self._ttl = ttl_seconds
        self._max = max_entries
        self._data: dict[str, dict[str, Any]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> Optional[dict[str, Any]]:
        with self._lock:
            row = self._data.get(key)
            if row is None:
                return None
            if row["expires_at"] < time.time():
                self._data.pop(key, None)
                return None
            return row

    def put(self, key: str, value: dict[str, Any]) -> None:
        with self._lock:
            if len(self._data) >= self._max:
                # Drop ~10% of oldest entries.
                to_drop = max(1, self._max // 10)
                for k in list(self._data.keys())[:to_drop]:
                    self._data.pop(k, None)
            value["expires_at"] = time.time() + self._ttl
            self._data[key] = value


# One shared store per process.
_store = _IdempotencyStore()


def _reset_store_for_tests() -> None:
    """Test helper — wipe the store so one test's key doesn't pollute the next."""
    global _store
    _store = _IdempotencyStore()


# ── Body hashing ──────────────────────────────────────────


def _hash_body(body: bytes) -> str:
    """Digest the request body so mismatched retries are detectable."""
    return hashlib.sha256(body or b"").hexdigest()


# ── Middleware ────────────────────────────────────────────


_SCOPED_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


class IdempotencyMiddleware(BaseHTTPMiddleware):
    """Replay the cached response for duplicate Idempotency-Key headers.

    Silently passes through requests that don't carry the header so
    existing endpoints are unaffected until a client opts in.
    """

    async def dispatch(self, request: Request, call_next):  # type: ignore[override]
        if request.method not in _SCOPED_METHODS:
            return await call_next(request)

        key = request.headers.get("Idempotency-Key") or request.headers.get("idempotency-key")
        if not key:
            return await call_next(request)

        tenant_id: Optional[str] = None
        try:
            from app.core.tenant_guard import current_tenant
            tenant_id = current_tenant() or None
        except Exception:
            pass
        scope = tenant_id or "anon"
        storage_key = f"{scope}:{key}:{request.method}:{request.url.path}"

        # Read the body so we can re-inject it into the downstream handler.
        body_bytes = await request.body()
        body_hash = _hash_body(body_bytes)

        cached = _store.get(storage_key)
        if cached is not None:
            if cached["body_hash"] != body_hash:
                # Same key, different body → user bug.
                return JSONResponse(
                    status_code=409,
                    content={
                        "success": False,
                        "error": "Idempotency-Key reused with different request body",
                        "code": "IDEMPOTENCY_KEY_MISMATCH",
                    },
                )
            return JSONResponse(
                status_code=cached["status_code"],
                content=cached["payload"],
                headers={"Idempotent-Replay": "true"},
            )

        # Reinject body — once a Request body is consumed, downstream
        # handlers can't re-read it without this trick.
        async def _receive() -> dict[str, Any]:
            return {"type": "http.request", "body": body_bytes, "more_body": False}

        request = Request(request.scope, receive=_receive)
        response = await call_next(request)

        # Only cache successful writes. A 5xx retry should be allowed
        # to actually go through.
        if 200 <= response.status_code < 300:
            payload_bytes = b""
            async for chunk in response.body_iterator:
                payload_bytes += chunk
            try:
                payload = json.loads(payload_bytes.decode("utf-8")) if payload_bytes else None
            except Exception:
                payload = None
            _store.put(storage_key, {
                "status_code": response.status_code,
                "payload": payload,
                "body_hash": body_hash,
            })
            # Rebuild the response since we consumed the iterator.
            return Response(
                content=payload_bytes,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.media_type,
            )
        return response
