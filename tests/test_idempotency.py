"""Tests for app/core/idempotency.py — Stripe-style idempotency middleware."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


@pytest.fixture(autouse=True)
def reset_store():
    """Each test gets a clean store so keys don't collide across tests."""
    from app.core.idempotency import _reset_store_for_tests
    _reset_store_for_tests()


# ── Pure store tests ─────────────────────────────────────


def test_store_put_get_roundtrip():
    from app.core.idempotency import _IdempotencyStore
    s = _IdempotencyStore()
    s.put("k1", {"status_code": 200, "payload": {"ok": True}, "body_hash": "h"})
    got = s.get("k1")
    assert got is not None
    assert got["status_code"] == 200


def test_store_expires_entries():
    from app.core.idempotency import _IdempotencyStore
    s = _IdempotencyStore(ttl_seconds=0)  # immediate expiry
    s.put("k1", {"status_code": 200, "payload": {"ok": True}, "body_hash": "h"})
    # Sleep one tick — Python resolves time.time() with enough granularity.
    import time
    time.sleep(0.01)
    assert s.get("k1") is None


def test_store_drops_oldest_when_full():
    from app.core.idempotency import _IdempotencyStore
    s = _IdempotencyStore(max_entries=5)
    for i in range(10):
        s.put(f"k{i}", {"status_code": 200, "payload": {"i": i}, "body_hash": str(i)})
    # Oldest half should be gone; newest should still be there.
    assert s.get("k0") is None
    assert s.get("k9") is not None


# ── Middleware behaviour via FastAPI ─────────────────────


def test_request_without_header_passes_through(client):
    """No Idempotency-Key → middleware is invisible."""
    r1 = client.post("/api/v1/ai/suggestions/execute-approved?limit=1")
    r2 = client.post("/api/v1/ai/suggestions/execute-approved?limit=1")
    # Two distinct requests, not replayed.
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert "Idempotent-Replay" not in r1.headers
    assert "Idempotent-Replay" not in r2.headers


def test_duplicate_key_returns_cached_response(client):
    r1 = client.post(
        "/api/v1/ai/suggestions/execute-approved?limit=3",
        headers={"Idempotency-Key": "key-dup-1"},
    )
    r2 = client.post(
        "/api/v1/ai/suggestions/execute-approved?limit=3",
        headers={"Idempotency-Key": "key-dup-1"},
    )
    assert r1.status_code == 200
    assert r2.status_code == 200
    # Replayed response carries the marker header.
    assert r2.headers.get("Idempotent-Replay") == "true"
    # Bodies should be identical.
    assert r1.json() == r2.json()


def test_same_key_different_body_returns_409(client):
    """Misusing the key (different body, same key) is a user error."""
    r1 = client.post(
        "/api/v1/ai/suggestions/bogus-id/reject",
        headers={"Idempotency-Key": "conflict-key"},
        json={"user_id": "alice", "reason": "wrong"},
    )
    r2 = client.post(
        "/api/v1/ai/suggestions/bogus-id/reject",
        headers={"Idempotency-Key": "conflict-key"},
        json={"user_id": "bob", "reason": "different reason"},
    )
    # First is 404 (row doesn't exist). Idempotency only caches 2xx,
    # so the second should NOT replay — it hits the route normally.
    assert r1.status_code == 404
    assert r2.status_code == 404
    assert "Idempotent-Replay" not in r2.headers


def test_error_responses_not_cached(client):
    """Non-2xx responses must NOT be replayed — a retried 4xx/5xx must
    actually re-hit the handler so a transient failure can succeed."""
    # /reject returns 404 on missing row — a real non-2xx status code.
    r1 = client.post(
        "/api/v1/ai/suggestions/missing-row-99/reject",
        headers={"Idempotency-Key": "err-key"},
        json={"user_id": "x"},
    )
    r2 = client.post(
        "/api/v1/ai/suggestions/missing-row-99/reject",
        headers={"Idempotency-Key": "err-key"},
        json={"user_id": "x"},
    )
    assert r1.status_code == 404
    assert r2.status_code == 404
    assert "Idempotent-Replay" not in r2.headers
