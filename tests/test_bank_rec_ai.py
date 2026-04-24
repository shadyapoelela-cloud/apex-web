"""Tests for AI-assisted bank reconciliation suggestion scoring."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


def test_suggest_matches_returns_empty_for_missing_txn():
    from app.core.bank_reconciliation_ai import suggest_matches_for_transaction
    # Nonexistent txn id → [] (no raise)
    assert suggest_matches_for_transaction("tx-does-not-exist") == []


def test_suggest_matches_endpoint_shape(client):
    r = client.get("/api/v1/ai/bank-rec/suggestions/nonexistent-id")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "data" in body
    assert isinstance(body["data"], list)


def test_auto_match_endpoint_shape(client):
    r = client.post("/api/v1/ai/bank-rec/auto-match?limit=1")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "considered" in body["data"]
    assert "matched" in body["data"]
    assert "skipped" in body["data"]


def test_auto_match_confidence_floor_bounded(client):
    """confidence_floor must be >= 0.7."""
    r = client.post("/api/v1/ai/bank-rec/auto-match?confidence_floor=0.5")
    assert r.status_code == 422


# ── Keyword overlap helper ────────────────────────────────


def test_keyword_overlap_arabic():
    from app.core.bank_reconciliation_ai import _keyword_overlap
    assert _keyword_overlap("تحويل إيجار شهر مارس", "إيجار المكتب شهر مارس") >= 2
    assert _keyword_overlap("AWS cloud charges", "aws cloud billing") >= 1
    assert _keyword_overlap(None, "anything") == 0
    assert _keyword_overlap("a b c", "d e f") == 0  # all tokens < 4 chars
