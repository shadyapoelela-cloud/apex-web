"""Tests for app.core.rate_limit_backend.

Covers:
  - MemoryBackend counter increments, resets per window
  - Memory eviction under load (MAX_KEYS)
  - get_backend falls back to memory if Redis isn't available
  - Redis fail-open: backend returns (1, window) on Redis exception
"""

import time
from unittest.mock import MagicMock, patch

import pytest


def _fresh_backend_module():
    from app.core import rate_limit_backend

    rate_limit_backend._reset_for_tests()
    return rate_limit_backend


def test_memory_backend_increments():
    mod = _fresh_backend_module()
    b = mod.MemoryBackend()
    count1, reset1 = b.hit("ip:default", 60)
    count2, reset2 = b.hit("ip:default", 60)
    count3, reset3 = b.hit("ip:default", 60)
    assert count1 == 1
    assert count2 == 2
    assert count3 == 3
    # reset_in should be positive and bounded by window
    assert 0 < reset1 <= 60


def test_memory_backend_isolates_keys():
    mod = _fresh_backend_module()
    b = mod.MemoryBackend()
    b.hit("ip_a:default", 60)
    b.hit("ip_a:default", 60)
    count_b, _ = b.hit("ip_b:default", 60)
    assert count_b == 1  # ip_b has its own bucket


def test_memory_backend_window_rollover(monkeypatch):
    """Entries older than window_seconds should be purged on next hit."""
    mod = _fresh_backend_module()
    b = mod.MemoryBackend()

    now_val = 1000.0
    monkeypatch.setattr("time.time", lambda: now_val)
    b.hit("ip:bucket", window_seconds=10)
    b.hit("ip:bucket", window_seconds=10)

    # Jump forward past the window
    now_val = 1020.0
    count, _ = b.hit("ip:bucket", window_seconds=10)
    assert count == 1  # old entries purged


def test_memory_backend_eviction_limit():
    mod = _fresh_backend_module()
    b = mod.MemoryBackend()
    # Populate over MAX_KEYS — use small limit for test speed
    b.MAX_KEYS = 100
    for i in range(150):
        b.hit(f"ip{i}:default", 60)
    # After eviction, store size must be <= MAX_KEYS
    assert len(b._store) <= b.MAX_KEYS


def test_get_backend_defaults_to_memory(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_BACKEND", "memory")
    mod = _fresh_backend_module()
    # Reload module-level config
    mod.RATE_LIMIT_BACKEND = "memory"
    backend = mod.get_backend()
    assert isinstance(backend, mod.MemoryBackend)


def test_get_backend_redis_falls_back_when_url_missing(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_BACKEND", "redis")
    monkeypatch.delenv("REDIS_URL", raising=False)
    mod = _fresh_backend_module()
    mod.RATE_LIMIT_BACKEND = "redis"
    mod.REDIS_URL = ""
    backend = mod.get_backend()
    # No REDIS_URL → should fall back to memory
    assert isinstance(backend, mod.MemoryBackend)


def test_redis_backend_fail_open_on_exception():
    """If Redis throws, we must allow the request (fail open)."""
    mod = _fresh_backend_module()
    fake_client = MagicMock()
    fake_client.pipeline.side_effect = Exception("redis down")
    b = mod.RedisBackend(fake_client)
    count, reset_in = b.hit("ip:default", 60)
    assert count == 1  # Treated as first hit → allowed
    assert reset_in == 60


def test_redis_backend_increments_via_pipeline():
    mod = _fresh_backend_module()
    fake_client = MagicMock()
    fake_pipe = MagicMock()
    fake_pipe.execute.return_value = [3, True]
    fake_client.pipeline.return_value = fake_pipe

    b = mod.RedisBackend(fake_client)
    count, reset_in = b.hit("ip:default", 60)
    assert count == 3
    assert 0 < reset_in <= 60
    fake_pipe.incr.assert_called_once()
    fake_pipe.expire.assert_called_once()
