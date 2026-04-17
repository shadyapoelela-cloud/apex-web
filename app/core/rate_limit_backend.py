"""
APEX Platform -- Rate limit storage backend.

Two implementations:
  1. MemoryBackend — thread-safe in-memory counter. Fine for single-instance
     deploys (Render free tier, local dev). Resets on restart.
  2. RedisBackend — shared counters across instances via Redis INCR + EXPIRE.
     Activated by RATE_LIMIT_BACKEND=redis. Falls back to memory if Redis
     is unreachable at startup (logged warning, no crash).

The backend exposes a single method: hit(key, window_seconds) -> (count, reset_in)
which increments the counter for (key, current_window) and returns the current
count plus seconds until the window rolls over.

This is intentionally minimal — not a drop-in slowapi replacement, but a
production-grade fix for the 'in-memory only' limitation while keeping the
tiered-path logic in main.py untouched.
"""

import logging
import os
import threading
import time
from typing import Protocol

logger = logging.getLogger(__name__)

RATE_LIMIT_BACKEND = os.environ.get("RATE_LIMIT_BACKEND", "memory").lower()
REDIS_URL = os.environ.get("REDIS_URL", "")
RATE_LIMIT_KEY_PREFIX = "apex:rl:"


class RateLimitBackend(Protocol):
    """Any backend must implement hit(key, window_seconds) -> (count, reset_in_seconds)."""

    def hit(self, key: str, window_seconds: int) -> tuple[int, int]: ...

    def reset(self, key: str) -> None: ...


class MemoryBackend:
    """Sliding-window counter stored in a process-local dict.

    Each entry: key -> list[float timestamps within current window].
    Thread-safe via a single lock; fine for gunicorn workers on one machine
    because each worker has its own process memory (shared-nothing) — limits
    will be per-worker, not global. For global limits across workers or
    instances, use RedisBackend.
    """

    MAX_KEYS = 20000

    def __init__(self):
        self._store: dict[str, list[float]] = {}
        self._lock = threading.Lock()

    def hit(self, key: str, window_seconds: int) -> tuple[int, int]:
        now = time.time()
        with self._lock:
            if len(self._store) > self.MAX_KEYS:
                # Evict half the entries (oldest last-seen first)
                ordered = sorted(
                    self._store.items(), key=lambda kv: kv[1][-1] if kv[1] else 0
                )
                for k, _ in ordered[: self.MAX_KEYS // 2]:
                    self._store.pop(k, None)
            bucket = self._store.setdefault(key, [])
            bucket[:] = [t for t in bucket if now - t < window_seconds]
            bucket.append(now)
            reset_in = int(window_seconds - (now - bucket[0])) if bucket else window_seconds
            return len(bucket), max(reset_in, 1)

    def reset(self, key: str) -> None:
        with self._lock:
            self._store.pop(key, None)


class RedisBackend:
    """Fixed-window counter stored in Redis.

    Strategy: bucket key = f"{prefix}{key}:{window_start}". INCR + EXPIRE.
    Simpler than sliding-window but atomic and fast. For most brute-force
    defense this is sufficient; if strict sliding-window is needed later,
    swap to a Lua script with ZADD/ZREMRANGEBYSCORE.
    """

    def __init__(self, client):
        self._r = client

    def hit(self, key: str, window_seconds: int) -> tuple[int, int]:
        now = int(time.time())
        window_start = now - (now % window_seconds)
        reset_in = window_seconds - (now - window_start)
        bucket_key = f"{RATE_LIMIT_KEY_PREFIX}{key}:{window_start}"
        try:
            pipe = self._r.pipeline()
            pipe.incr(bucket_key, 1)
            pipe.expire(bucket_key, window_seconds + 5)  # tiny buffer
            count, _ = pipe.execute()
            return int(count), max(int(reset_in), 1)
        except Exception as e:
            logger.warning("Redis rate-limit hit failed (%s); allowing request", e)
            # Fail open: a Redis blip must never 500 user traffic.
            return 1, window_seconds

    def reset(self, key: str) -> None:
        try:
            # Without scanning, we don't know which window keys exist.
            # Keys expire on their own — reset is a no-op in practice.
            pass
        except Exception:
            pass


def _make_redis_client():
    """Build a redis client from REDIS_URL. Returns None if unavailable."""
    if not REDIS_URL:
        logger.warning("RATE_LIMIT_BACKEND=redis but REDIS_URL not set; using memory")
        return None
    try:
        import redis  # type: ignore
    except ImportError:
        logger.warning("redis package not installed; using memory backend")
        return None
    try:
        client = redis.Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=2)
        client.ping()
        logger.info("Rate limiter: Redis backend connected")
        return client
    except Exception as e:
        logger.warning("Redis ping failed (%s); falling back to memory backend", e)
        return None


_backend: RateLimitBackend | None = None


def get_backend() -> RateLimitBackend:
    """Return the active rate-limit backend (singleton)."""
    global _backend
    if _backend is not None:
        return _backend
    if RATE_LIMIT_BACKEND == "redis":
        client = _make_redis_client()
        if client is not None:
            _backend = RedisBackend(client)
            return _backend
    _backend = MemoryBackend()
    return _backend


def _reset_for_tests() -> None:
    """Test helper — clear singleton so tests can inject a fresh backend."""
    global _backend
    _backend = None
