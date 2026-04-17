"""Caching layer — Redis-backed with safe in-memory fallback.

Design:
  • Decorator @cached(ttl=60) for pure function results.
  • Key helpers for tenant-scoped cache (auto-prefixes current_tenant()).
  • Graceful degradation: if Redis unavailable, falls back to per-process
    dict so dev/tests work without Redis.

Use for:
  • Dashboard KPIs (60s TTL)
  • User permissions (300s TTL)
  • Plan feature flags (3600s TTL)
  • COA engine expensive lookups

Don't use for:
  • Anything tenant-crossing writes — use DB.
  • Anything whose staleness would be a correctness bug.

Env:
  CACHE_BACKEND  'redis' | 'memory' (default: auto-detect)
  REDIS_URL      redis://... (reused from rate_limit_backend)
"""

from __future__ import annotations

import functools
import hashlib
import json
import logging
import os
import threading
import time
from typing import Any, Callable, Optional, Protocol

from app.core.tenant_context import current_tenant

logger = logging.getLogger(__name__)

CACHE_BACKEND = os.environ.get("CACHE_BACKEND", "auto").lower()
REDIS_URL = os.environ.get("REDIS_URL", "")
CACHE_KEY_PREFIX = "apex:cache:"


class CacheBackend(Protocol):
    def get(self, key: str) -> Any: ...
    def set(self, key: str, value: Any, ttl_seconds: int) -> None: ...
    def delete(self, key: str) -> None: ...
    def clear(self) -> None: ...


# ── Memory backend (per-process) ───────────────────────────


class MemoryCache:
    """Thread-safe in-memory cache with TTL + LRU-ish eviction."""

    MAX_ENTRIES = 5000

    def __init__(self):
        self._data: dict[str, tuple[float, Any]] = {}  # key -> (expires_at, value)
        self._lock = threading.Lock()

    def get(self, key: str) -> Any:
        now = time.time()
        with self._lock:
            entry = self._data.get(key)
            if entry is None:
                return None
            expires_at, value = entry
            if expires_at < now:
                self._data.pop(key, None)
                return None
            return value

    def set(self, key: str, value: Any, ttl_seconds: int) -> None:
        expires_at = time.time() + max(1, ttl_seconds)
        with self._lock:
            if len(self._data) >= self.MAX_ENTRIES:
                # Drop 10% of oldest entries.
                ordered = sorted(self._data.items(), key=lambda kv: kv[1][0])
                for k, _ in ordered[: self.MAX_ENTRIES // 10]:
                    self._data.pop(k, None)
            self._data[key] = (expires_at, value)

    def delete(self, key: str) -> None:
        with self._lock:
            self._data.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()


# ── Redis backend ─────────────────────────────────────────


class RedisCache:
    def __init__(self, client):
        self._r = client

    def get(self, key: str) -> Any:
        try:
            raw = self._r.get(key)
            return json.loads(raw) if raw else None
        except Exception as e:
            logger.warning("redis cache get failed: %s", e)
            return None

    def set(self, key: str, value: Any, ttl_seconds: int) -> None:
        try:
            self._r.setex(
                key,
                max(1, ttl_seconds),
                json.dumps(value, default=str, ensure_ascii=False),
            )
        except Exception as e:
            logger.warning("redis cache set failed: %s", e)

    def delete(self, key: str) -> None:
        try:
            self._r.delete(key)
        except Exception as e:
            logger.warning("redis cache delete failed: %s", e)

    def clear(self) -> None:
        """Clear only our prefix — never the whole Redis DB."""
        try:
            for k in self._r.scan_iter(match=f"{CACHE_KEY_PREFIX}*"):
                self._r.delete(k)
        except Exception as e:
            logger.warning("redis cache clear failed: %s", e)


# ── Factory ───────────────────────────────────────────────


def _make_redis_backend() -> Optional[RedisCache]:
    if not REDIS_URL:
        return None
    try:
        import redis  # type: ignore

        client = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2)
        client.ping()
        logger.info("Cache: Redis backend connected")
        return RedisCache(client)
    except ImportError:
        logger.info("redis package not installed — using memory cache")
        return None
    except Exception as e:
        logger.warning("Cache: Redis unreachable (%s) — using memory", e)
        return None


_backend: Optional[CacheBackend] = None


def get_cache() -> CacheBackend:
    """Return the active cache backend (singleton)."""
    global _backend
    if _backend is not None:
        return _backend
    if CACHE_BACKEND in ("auto", "redis"):
        redis_backend = _make_redis_backend()
        if redis_backend is not None:
            _backend = redis_backend
            return _backend
    _backend = MemoryCache()
    return _backend


def _reset_for_tests() -> None:
    """Test helper — drop the singleton so tests can inject a fresh backend."""
    global _backend
    _backend = None


# ── Key helpers ───────────────────────────────────────────


def _hash_args(*args, **kwargs) -> str:
    payload = json.dumps({"a": args, "kw": kwargs}, default=str, sort_keys=True)
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def tenant_key(name: str, *args, **kwargs) -> str:
    """Build a tenant-scoped cache key.

    `name` is the logical key (e.g. 'dashboard:kpis'). Tenant comes from
    current_tenant(); if None, uses 'system' — so cross-tenant writes are
    impossible by construction.
    """
    tid = current_tenant() or "system"
    arg_hash = _hash_args(*args, **kwargs) if (args or kwargs) else ""
    suffix = f":{arg_hash}" if arg_hash else ""
    return f"{CACHE_KEY_PREFIX}{tid}:{name}{suffix}"


# ── @cached decorator ────────────────────────────────────


def cached(
    *,
    name: str,
    ttl: int = 60,
    tenant_scoped: bool = True,
):
    """Cache the decorated function's result.

    Args:
      name: logical cache key (unique per function).
      ttl: seconds to live.
      tenant_scoped: when True (default), the cache key includes
        current_tenant() so tenants never see each other's cached values.

    Usage:
      @cached(name='dashboard:kpis', ttl=60)
      def get_dashboard_kpis(): ...
    """

    def decorator(fn: Callable) -> Callable:
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            if tenant_scoped:
                key = tenant_key(name, *args, **kwargs)
            else:
                key = f"{CACHE_KEY_PREFIX}global:{name}:{_hash_args(*args, **kwargs)}"
            cache = get_cache()
            hit = cache.get(key)
            if hit is not None:
                return hit
            value = fn(*args, **kwargs)
            cache.set(key, value, ttl)
            return value

        wrapper.__wrapped__ = fn  # type: ignore[attr-defined]
        wrapper._cache_key_prefix = name
        return wrapper

    return decorator


def invalidate(name: str, tenant_scoped: bool = True, *args, **kwargs) -> None:
    """Drop a specific cached entry."""
    if tenant_scoped:
        key = tenant_key(name, *args, **kwargs)
    else:
        key = f"{CACHE_KEY_PREFIX}global:{name}:{_hash_args(*args, **kwargs)}"
    get_cache().delete(key)
