"""Tests for AI suggestions REST endpoints (list / get / approve / reject).

These drive the human-in-the-loop surface: the Copilot agent creates
suggestions through the guardrail; a human inspects them via GET and
acts on them via POST /approve or /reject. The tests verify both the
happy path and error/edge responses.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


@pytest.fixture
def sample_suggestion_id():
    """Create a real AiSuggestion row through the guardrail so we have
    a stable target for approve/reject tests."""
    from app.core.ai_guardrails import guard, Suggestion
    decision = guard(Suggestion(
        source="test",
        action_type="categorize_txn",
        target_type="transaction",
        target_id="TXN-FIXTURE",
        after={"category": "Travel"},
        confidence=0.5,       # below floor — lands in needs_approval
        reasoning="test fixture",
    ))
    return decision.row_id


# ── GET /ai/suggestions ──────────────────────────────────


def test_list_suggestions_shape(client):
    r = client.get("/api/v1/ai/suggestions")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert isinstance(body["data"], list)
    assert "count" in body


def test_list_suggestions_filter_by_status(client):
    r = client.get("/api/v1/ai/suggestions?status=needs_approval&limit=10")
    assert r.status_code == 200
    body = r.json()
    for row in body["data"]:
        assert row["status"] == "needs_approval"


def test_list_suggestions_limit_clamped(client):
    """limit above 200 should 422 (pydantic validation)."""
    r = client.get("/api/v1/ai/suggestions?limit=9999")
    assert r.status_code == 422


# ── GET /ai/suggestions/{id} ──────────────────────────────


def test_get_suggestion_not_found(client):
    r = client.get("/api/v1/ai/suggestions/id-that-does-not-exist")
    assert r.status_code == 404


def test_get_suggestion_happy_path(client, sample_suggestion_id):
    r = client.get(f"/api/v1/ai/suggestions/{sample_suggestion_id}")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["data"]["id"] == sample_suggestion_id


# ── POST /ai/suggestions/{id}/approve ─────────────────────


def test_approve_suggestion_happy_path(client, sample_suggestion_id):
    r = client.post(
        f"/api/v1/ai/suggestions/{sample_suggestion_id}/approve",
        json={"user_id": "u-tester"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["data"]["verdict"] == "approved"


def test_approve_suggestion_not_found(client):
    r = client.post(
        "/api/v1/ai/suggestions/no-such-id/approve",
        json={"user_id": "u-tester"},
    )
    assert r.status_code == 404


# ── POST /ai/suggestions/{id}/reject ──────────────────────


def test_reject_suggestion_happy_path(client):
    # Create a fresh suggestion since approve test consumed the fixture.
    from app.core.ai_guardrails import guard, Suggestion
    decision = guard(Suggestion(
        source="test",
        action_type="categorize_txn",
        target_type="transaction",
        target_id="TXN-REJECT",
        after={"category": "Travel"},
        confidence=0.5,
        reasoning="reject test",
    ))
    r = client.post(
        f"/api/v1/ai/suggestions/{decision.row_id}/reject",
        json={"user_id": "u-tester", "reason": "wrong category"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["data"]["verdict"] == "rejected"


def test_reject_suggestion_not_found(client):
    r = client.post(
        "/api/v1/ai/suggestions/no-such-id/reject",
        json={"user_id": "u-tester"},
    )
    assert r.status_code == 404


# ── Integration: create_invoice tool persists a suggestion ─


def test_create_invoice_persists_ai_suggestion(client):
    """The tool impl should return a suggestion_id that we can fetch."""
    from app.services.copilot_agent import TOOL_IMPLS
    result = TOOL_IMPLS["create_invoice"]({
        "client_name": "شركة الرياض",
        "description": "استشارات",
        "amount": 1000,
        "vat_rate": 15,
    })
    assert result["status"] == "draft"
    sid = result.get("suggestion_id")
    if sid is None:
        pytest.skip("guardrail unavailable in this environment")

    # Suggestion should be fetchable via the REST endpoint.
    r = client.get(f"/api/v1/ai/suggestions/{sid}")
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["source"] == "copilot_agent"
    assert data["action_type"] == "create_invoice"
    assert data["status"] == "needs_approval"
    assert data["destructive"] == 1


def test_send_reminder_persists_ai_suggestion(client):
    from app.services.copilot_agent import TOOL_IMPLS
    result = TOOL_IMPLS["send_reminder"]({
        "invoice_id": "INV-7777",
        "channel": "whatsapp",
        "tone": "firm",
    })
    assert result["status"] == "queued"
    sid = result.get("suggestion_id")
    if sid is None:
        pytest.skip("guardrail unavailable in this environment")

    r = client.get(f"/api/v1/ai/suggestions/{sid}")
    assert r.status_code == 200
    data = r.json()["data"]
    assert data["action_type"] == "send_reminder"
    assert data["status"] == "needs_approval"
