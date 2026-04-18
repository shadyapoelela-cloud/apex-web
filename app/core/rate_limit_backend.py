"""
APEX — Rate-limit backends (Wave 1 PR#5).

Replaces the in-memory `defaultdict(list)` in app/main.py with a backend
abstraction that supports a distributed Redis implementation for
multi-instance deployments. The in-memory backend is kept as the fallback
so local development and the test suite do not require a running Redis.

Design:
- Both backends implement the same `hit(key, window, limit)` contract,
  returning (allowed, remaining, reset_in_seconds).
- Redis uses a sorted-set per (ip, bucket): scores are timestamps and
  members are unique tokens, giving a true sliding window.
- Pick_backend() chooses based on REDIS_URL. If Redis is requested but
  unreachable at import time, we log a warning and fall back to memory
  rather than crashing the worker.
"""

from __future__ import annotations

import logging
import os
import secrets as _secrets
import time
from collections import defaultdict
from typing import Tuple

logger = logging.getLogger(__name__)

_MAX_IN_MEMORY_KEYS = 20_000  # prevent runaway memory if an IP floods with many buckets


class RateLimitBackend:
    """Minimal interface. hit() is the only hot-path call."""

    name = "abstract"

    def hit(self, key: str, window: int, limit: int) -> Tuple[bool, int, int]:
        """Record a request and return (allowed, remaining, reset_in_seconds).

        `allowed` is False iff the request is over-limit. `remaining` is the
        count left in the current window *after* this request when allowed,
        or 0 when rejected. `reset_in_seconds` is the integer seconds until
        the oldest tracked hit expires from the window.
        """
        raise NotImplementedError


class InMemoryBackend(RateLimitBackend):
    """Single-process fallback. Not safe across workers."""

    name = "memory"

    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = defaultdict(list)

    def hit(self, key: str, window: int, limit: int) -> Tuple[bool, int, int]:
        now = time.time()
        # Evict oldest keys if tracking balloons — bounds worst-case memory.
        if len(self._hits) > _MAX_IN_MEMORY_KEYS:
            ordered = sorted(
                self._hits.keys(),
                key=lambda k: self._hits[k][-1] if self._hits[k] else 0,
            )
            for k in ordered[: _MAX_IN_MEMORY_KEYS // 2]:
                del self._hits[k]

        bucket = [t for t in self._hits[key] if now - t < window]
        self._hits[key] = bucket

        if len(bucket) >= limit:
            reset_in = int(window - (now - bucket[0])) if bucket else window
            return False, 0, max(reset_in, 1)

        bucket.append(now)
        remaining = max(0, limit - len(bucket))
        return True, remaining, window


class RedisBackend(RateLimitBackend):
    """Sorted-set sliding-window limiter backed by Redis.

    Key layout: ``ratelimit:{namespaced_key}`` — one ZSET per (ip, bucket).
    Scores are unix timestamps; members are random tokens so hits never
    collide even at the same microsecond. ZREMRANGEBYSCORE prunes expired
    entries before each count.
    """

    name = "redis"

    def __init__(self, redis_client, *, key_prefix: str = "apex:ratelimit:") -> None:
        self._r = redis_client
        self._prefix = key_prefix

    @classmethod
    def from_url(cls, url: str) -> "RedisBackend":
        import redis  # lazy import — requirements.txt pins the package

        client = redis.from_url(url, socket_timeout=0.5, socket_connect_timeout=0.5)
        # Force a round-trip so a misconfigured URL surfaces here rather than
        # later under load. PING is cheap and never rate-limited server-side.
        client.ping()
        return cls(client)

    def hit(self, key: str, window: int, limit: int) -> Tuple[bool, int, int]:
        now_ms = int(time.time() * 1000)
        window_ms = window * 1000
        cutoff = now_ms - window_ms
        redis_key = f"{self._prefix}{key}"

        pipe = self._r.pipeline()
        # Prune old entries before counting.
        pipe.zremrangebyscore(redis_key, 0, cutoff)
        pipe.zcard(redis_key)
        _, count = pipe.execute()

        if count >= limit:
            # Get the oldest entry so we can report an accurate reset time.
            oldest = self._r.zrange(redis_key, 0, 0, withscores=True)
            if oldest:
                oldest_ts_ms = int(oldest[0][1])
                reset_in = max(1, int((oldest_ts_ms + window_ms - now_ms) / 1000))
            else:
                reset_in = window
            return False, 0, reset_in

        # Accept the hit: add this request + refresh TTL so idle keys expire.
        member = f"{now_ms}:{_secrets.token_hex(4)}"
        pipe = self._r.pipeline()
        pipe.zadd(redis_key, {member: now_ms})
        pipe.expire(redis_key, window + 5)  # small grace so ZADD after prune still covers
        pipe.execute()
        remaining = max(0, limit - count - 1)
        return True, remaining, window


def pick_backend() -> RateLimitBackend:
    """Select the backend based on REDIS_URL. Falls back to in-memory on
    any connection error with a loud warning — we never want a Redis
    outage to take the whole service down."""

    url = os.environ.get("REDIS_URL")
    if not url:
        return InMemoryBackend()

    try:
        backend = RedisBackend.from_url(url)
        logger.info("Rate limiter: using Redis backend at %s", url)
        return backend
    except Exception as e:
        logger.warning(
            "Rate limiter: Redis unreachable (%s) — falling back to in-memory. "
            "This is NOT safe across multiple workers.",
            e,
        )
        return InMemoryBackend()
