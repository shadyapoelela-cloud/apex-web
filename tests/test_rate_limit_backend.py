"""
Tests for app/core/rate_limit_backend.py (Wave 1 PR#5).

Covers:
- InMemoryBackend: first N hits are allowed, (N+1)th returns 429, window
  resets after expiry, keys are isolated, and the max-keys eviction
  prevents unbounded growth.
- RedisBackend: same semantics using a mocked Redis pipeline.
- pick_backend(): honours REDIS_URL; falls back on connection errors.
"""

import os
import time
from unittest.mock import MagicMock, patch

import pytest

from app.core import rate_limit_backend as rlb


class TestInMemoryBackend:
    def test_first_hits_allowed_then_blocked(self):
        b = rlb.InMemoryBackend()
        for _ in range(3):
            allowed, remaining, _ = b.hit("k", window=60, limit=3)
            assert allowed is True
        allowed, remaining, reset = b.hit("k", window=60, limit=3)
        assert allowed is False
        assert remaining == 0
        assert reset >= 1

    def test_remaining_counts_down(self):
        b = rlb.InMemoryBackend()
        _, r1, _ = b.hit("k", window=60, limit=5)
        _, r2, _ = b.hit("k", window=60, limit=5)
        _, r3, _ = b.hit("k", window=60, limit=5)
        assert (r1, r2, r3) == (4, 3, 2)

    def test_keys_are_isolated(self):
        b = rlb.InMemoryBackend()
        for _ in range(3):
            assert b.hit("a", 60, 3)[0] is True
        # "b" still has fresh budget.
        assert b.hit("b", 60, 3)[0] is True

    def test_window_expiry(self, monkeypatch):
        b = rlb.InMemoryBackend()
        fake_now = [1000.0]
        monkeypatch.setattr(time, "time", lambda: fake_now[0])
        assert b.hit("k", window=10, limit=1)[0] is True
        assert b.hit("k", window=10, limit=1)[0] is False
        fake_now[0] += 11  # skip past the window
        assert b.hit("k", window=10, limit=1)[0] is True

    def test_eviction_when_key_count_exceeds_cap(self, monkeypatch):
        b = rlb.InMemoryBackend()
        monkeypatch.setattr(rlb, "_MAX_IN_MEMORY_KEYS", 10)
        for i in range(15):
            b.hit(f"k{i}", 60, 5)
        # After eviction we keep at most 10 buckets.
        assert len(b._hits) <= 10


class TestRedisBackend:
    def _mk_client(self, count_after_prune: int, oldest_ts_ms: int | None = None):
        """Return a mock redis client that emulates pipeline + zrange."""
        client = MagicMock()
        # First pipe: zremrangebyscore + zcard → returns (0, count_after_prune)
        pipe_execute_outputs = [[0, count_after_prune], [1, True]]
        pipe = MagicMock()
        pipe.execute.side_effect = pipe_execute_outputs
        client.pipeline.return_value = pipe
        # zrange used only when over-limit
        if oldest_ts_ms is None:
            client.zrange.return_value = []
        else:
            client.zrange.return_value = [(b"m", float(oldest_ts_ms))]
        return client, pipe

    def test_allowed_when_under_limit(self):
        client, pipe = self._mk_client(count_after_prune=2)
        backend = rlb.RedisBackend(client)
        allowed, remaining, reset = backend.hit("k", window=60, limit=5)
        assert allowed is True
        assert remaining == 2  # 5 - 2 - 1 (the new hit)
        # pipeline called twice: prune+count, then add+expire
        assert pipe.execute.call_count == 2

    def test_blocked_when_at_or_above_limit(self):
        now_ms = int(time.time() * 1000)
        oldest = now_ms - 20_000  # 20s ago, in a 60s window
        client, _ = self._mk_client(count_after_prune=5, oldest_ts_ms=oldest)
        backend = rlb.RedisBackend(client)
        allowed, remaining, reset = backend.hit("k", window=60, limit=5)
        assert allowed is False
        assert remaining == 0
        # reset ≈ 60 - 20 = 40s. Allow +/- 2s tolerance for clock jitter.
        assert 35 <= reset <= 45


class TestPickBackend:
    def test_no_redis_url_returns_memory(self, monkeypatch):
        monkeypatch.delenv("REDIS_URL", raising=False)
        assert isinstance(rlb.pick_backend(), rlb.InMemoryBackend)

    def test_redis_url_set_but_unreachable_falls_back(self, monkeypatch, caplog):
        monkeypatch.setenv("REDIS_URL", "redis://127.0.0.1:1/0")
        # Make from_url raise — simulates a connection failure.
        with patch.object(
            rlb.RedisBackend, "from_url", side_effect=RuntimeError("down")
        ):
            backend = rlb.pick_backend()
        assert isinstance(backend, rlb.InMemoryBackend)
        assert any("falling back" in r.message for r in caplog.records)

    def test_redis_url_reachable_returns_redis(self, monkeypatch):
        monkeypatch.setenv("REDIS_URL", "redis://fake/0")
        fake_backend = MagicMock(spec=rlb.RedisBackend)
        with patch.object(rlb.RedisBackend, "from_url", return_value=fake_backend):
            backend = rlb.pick_backend()
        assert backend is fake_backend
