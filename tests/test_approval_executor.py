"""Tests for app/ai/approval_executor.py — execution layer for the
human-approved AiSuggestion queue."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


def _make_suggestion(action_type: str, after: dict) -> str:
    """Create a NEEDS_APPROVAL row through the guardrail and return its id."""
    from app.core.ai_guardrails import guard, Suggestion
    decision = guard(Suggestion(
        source="test",
        action_type=action_type,
        target_type="test_target",
        target_id=f"t-{action_type}",
        after=after,
        confidence=0.5,    # below floor → needs_approval
        reasoning=f"test fixture for {action_type}",
    ))
    return decision.row_id


def _approve(sid: str) -> None:
    from app.core.ai_guardrails import approve
    approve(sid, user_id="u-test")


def test_executor_rejects_non_approved_rows():
    from app.ai.approval_executor import execute_suggestion
    sid = _make_suggestion("create_invoice", {"client_name": "x", "draft_id": "d1"})
    # Not approved → executor refuses.
    result = execute_suggestion(sid)
    assert result.ok is False
    assert "approved" in result.detail.lower()


def test_executor_happy_path_create_invoice():
    from app.ai.approval_executor import execute_suggestion
    sid = _make_suggestion("create_invoice", {"client_name": "شركة X", "draft_id": "d2"})
    _approve(sid)
    result = execute_suggestion(sid)
    assert result.ok is True
    assert result.status == "executed"


def test_executor_send_reminder_requires_target():
    from app.ai.approval_executor import execute_suggestion
    sid = _make_suggestion("send_reminder", {})     # no invoice_id nor client
    _approve(sid)
    result = execute_suggestion(sid)
    assert result.ok is False
    assert result.status == "failed"


def test_executor_returns_error_on_unknown_action():
    from app.ai.approval_executor import execute_suggestion
    sid = _make_suggestion("unknown_action_xyz", {"foo": "bar"})
    _approve(sid)
    result = execute_suggestion(sid)
    assert result.ok is False
    assert "no handler" in result.detail.lower()


def test_executor_is_idempotent_on_terminal_state():
    """Running the executor twice on the same row should not double-execute."""
    from app.ai.approval_executor import execute_suggestion
    sid = _make_suggestion("create_invoice", {"client_name": "Y", "draft_id": "d3"})
    _approve(sid)
    first = execute_suggestion(sid)
    second = execute_suggestion(sid)
    assert first.ok is True
    assert first.status == "executed"
    # Second call sees a non-approved terminal state → fails with clear reason.
    assert second.ok is False
    assert "executed" in second.detail or "terminal" in second.detail.lower() or "approved" in second.detail.lower()


def test_execute_all_approved_returns_counters():
    from app.ai.approval_executor import execute_all_approved
    # Seed two approved rows.
    s1 = _make_suggestion("create_invoice", {"client_name": "A", "draft_id": "d-a"})
    s2 = _make_suggestion("create_invoice", {"client_name": "B", "draft_id": "d-b"})
    _approve(s1)
    _approve(s2)

    out = execute_all_approved(limit=10)
    assert out["considered"] >= 2
    assert out["executed"] + out["failed"] == out["considered"]


# ── HTTP endpoints ───────────────────────────────────────


def test_execute_endpoint_404_on_missing(client):
    r = client.post("/api/v1/ai/suggestions/bogus-id/execute")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is False
    assert "not found" in body["data"]["detail"].lower()


def test_drain_endpoint_returns_counters(client):
    r = client.post("/api/v1/ai/suggestions/execute-approved?limit=5")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "considered" in body["data"]
    assert "executed" in body["data"]
    assert "failed" in body["data"]
