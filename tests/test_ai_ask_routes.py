"""Tests for POST /api/v1/ai/ask and GET /api/v1/ai/usage."""

from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    # Import inside the fixture so a prior test that clears env vars
    # can't leak into this module.
    from app.main import app
    return TestClient(app)


# ── POST /ai/ask ──────────────────────────────────────────


def test_ask_requires_query(client):
    r = client.post("/api/v1/ai/ask", json={})
    assert r.status_code == 400


def test_ask_empty_query_rejected(client):
    r = client.post("/api/v1/ai/ask", json={"query": "   "})
    assert r.status_code == 400


def test_ask_without_api_key_returns_degraded_not_error(client, monkeypatch):
    """No API key → success=False with a clear message, not 500."""
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    r = client.post("/api/v1/ai/ask", json={"query": "ما صافي الدخل هذا الشهر؟"})
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is False
    assert "ANTHROPIC_API_KEY" in body["error"]
    assert body["data"]["answer"] == ""


def test_ask_caps_max_turns(client, monkeypatch):
    """Client-supplied max_turns is clamped to [1, 10]."""
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    r = client.post(
        "/api/v1/ai/ask",
        json={"query": "test", "max_turns": 9999},
    )
    # Still 200 with degraded — just verifying the handler doesn't choke
    # on an aggressive max_turns value.
    assert r.status_code == 200


# ── GET /ai/usage ─────────────────────────────────────────


def test_usage_requires_tenant(client):
    r = client.get("/api/v1/ai/usage")
    assert r.status_code == 400


def test_usage_explicit_tenant_returns_zero_on_empty(client):
    r = client.get("/api/v1/ai/usage?tenant_id=tenant-nonexistent")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["data"]["tenant_id"] == "tenant-nonexistent"
    assert body["data"]["cost_usd"] == 0.0
    assert body["data"]["calls"] == 0


def test_usage_since_parameter_iso(client):
    r = client.get("/api/v1/ai/usage?tenant_id=t1&since=2026-04-01T00:00:00")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True


def test_usage_since_invalid_returns_400(client):
    r = client.get("/api/v1/ai/usage?tenant_id=t1&since=not-a-date")
    assert r.status_code == 400
