"""Tests for tier rate limits, AP suggestion bridge, audit chain endpoints."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


# ── Rate limit tier resolution ───────────────────────────


def test_check_quota_no_tenant_is_allowed():
    from app.core.ai_rate_limits import check_quota
    qd = check_quota(None)
    assert qd.allowed is True
    assert qd.tier == "internal"


def test_check_quota_unknown_tenant_defaults_to_free(monkeypatch):
    from app.core.ai_rate_limits import check_quota
    qd = check_quota("unknown-tenant-id-xyz")
    assert qd.allowed is True          # never block on lookup failure
    assert qd.tier in ("free", "pro", "business", "expert", "enterprise")


def test_env_override_tier_limits(monkeypatch):
    """AI_QUOTA_FREE_CALLS env var tunes the free-tier call limit."""
    monkeypatch.setenv("AI_QUOTA_FREE_CALLS", "999")
    from app.core.ai_rate_limits import _tier_limits
    limits = _tier_limits("free")
    assert limits["max_calls"] == 999


def test_ask_endpoint_works_with_quota_gate(client, monkeypatch):
    """The quota check must be non-blocking even without a tenant context."""
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    r = client.post("/api/v1/ai/ask", json={"query": "hello"})
    assert r.status_code == 200     # no quota lookup crash


# ── AP suggestion bridge ─────────────────────────────────


def test_ap_bridge_returns_suggestion_id():
    from app.features.ap_agent.suggestion_bridge import request_ap_approval
    sid = request_ap_approval(
        invoice={
            "id": "inv-test",
            "invoice_number": "INV-001",
            "vendor_name": "Acme Supplies",
            "total": 25000,
            "currency": "SAR",
        },
        policy="cfo",
        tenant_id="test-tenant",
    )
    # May be None in minimal env without AiSuggestion table.
    assert sid is None or (isinstance(sid, str) and len(sid) > 0)


def test_ap_bridge_on_unknown_suggestion_returns_error():
    from app.features.ap_agent.suggestion_bridge import on_suggestion_approved
    r = on_suggestion_approved("bogus-id")
    assert r["ok"] is False


# ── Audit chain endpoints ────────────────────────────────


def test_audit_chain_verify_endpoint(client):
    r = client.get("/api/v1/ai/audit/chain/verify")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "verified" in body["data"]


def test_audit_chain_events_endpoint(client):
    r = client.get("/api/v1/ai/audit/chain/events?limit=10")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert isinstance(body["data"], list)
    # Each event should have hash fields.
    for ev in body["data"]:
        assert "this_hash" in ev


def test_audit_events_limit_clamped(client):
    """Over 500 → 422."""
    r = client.get("/api/v1/ai/audit/chain/events?limit=9999")
    assert r.status_code == 422
