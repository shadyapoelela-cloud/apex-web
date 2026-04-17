"""Tests for Governed AI + Webhooks (P3 infra)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest


# ── Governed AI — confidence routing ──────────────────────


def test_route_confidence_below_review_threshold():
    from app.core.governed_ai import AiGateDecision, route_confidence

    assert route_confidence(0.5) == AiGateDecision.REVIEW
    assert route_confidence(0.69) == AiGateDecision.REVIEW


def test_route_confidence_notify_range():
    from app.core.governed_ai import AiGateDecision, route_confidence

    assert route_confidence(0.7) == AiGateDecision.AUTO_NOTIFY
    assert route_confidence(0.89) == AiGateDecision.AUTO_NOTIFY


def test_route_confidence_silent_auto():
    from app.core.governed_ai import AiGateDecision, route_confidence

    assert route_confidence(0.9) == AiGateDecision.AUTO_SILENT
    assert route_confidence(0.99) == AiGateDecision.AUTO_SILENT


def test_route_confidence_custom_thresholds():
    from app.core.governed_ai import (
        AiGateDecision,
        ConfidenceThresholds,
        route_confidence,
    )

    strict = ConfidenceThresholds(
        review_below=Decimal("0.95"),
        notify_below=Decimal("0.99"),
    )
    # At 0.90 with strict thresholds it's now REVIEW
    assert route_confidence(0.90, strict) == AiGateDecision.REVIEW


# ── Governed AI — log + undo ───────────────────────────────


def test_log_action_persists_row():
    from app.core.governed_ai import log_action, query_actions

    entry = log_action(
        action_type="ap.gl_coding",
        output={"account": "5200-Telecom"},
        confidence=0.85,
        entity_type="ap_invoice",
        entity_id="inv-unit-1",
        model="claude-sonnet-4-5",
    )
    assert entry.id
    assert entry.gate_decision == "auto_notify"

    # Read back
    rows = query_actions(action_type="ap.gl_coding", entity_id="inv-unit-1")
    assert any(r.id == entry.id for r in rows)


def test_undo_action_requires_reverse_callback():
    from app.core.governed_ai import log_action, undo_action

    entry = log_action(
        action_type="test.no_reverse",
        output={"x": 1},
        confidence=0.95,
    )
    result = undo_action(entry.id, user_id="u-1")
    assert result["success"] is False
    assert "no_reverse_callback" in result["error"]


def test_undo_action_invokes_registered_callback():
    from app.core.governed_ai import (
        log_action,
        register_reverse_callback,
        undo_action,
    )

    invocations: list[dict] = []

    def _my_reverse(args, db):
        invocations.append(args)
        return {"reversed": True}

    register_reverse_callback("test.reverse_add_entry", _my_reverse)

    entry = log_action(
        action_type="test.auto_je_creation",
        output={"je_id": "je-123"},
        confidence=0.95,
        reverse_callback_name="test.reverse_add_entry",
        reverse_args={"je_id": "je-123"},
    )
    result = undo_action(entry.id, user_id="u-1")
    assert result["success"] is True
    assert invocations == [{"je_id": "je-123"}]
    assert result["data"]["reverse_result"] == {"reversed": True}

    # Second undo must fail — already_undone
    result2 = undo_action(entry.id, user_id="u-1")
    assert result2["success"] is False
    assert "already_undone" in result2["error"]


def test_undo_action_refuses_old_entries():
    from app.core.governed_ai import (
        AiActionLog,
        log_action,
        register_reverse_callback,
        undo_action,
    )
    from app.phase1.models.platform_models import SessionLocal

    register_reverse_callback("test.old", lambda args, db: {"ok": True})
    entry = log_action(
        action_type="test.old_action",
        output={},
        confidence=0.95,
        reverse_callback_name="test.old",
        reverse_args={},
    )
    # Manually age the entry.
    db = SessionLocal()
    try:
        row = db.query(AiActionLog).filter(AiActionLog.id == entry.id).first()
        row.timestamp = datetime.now(timezone.utc) - timedelta(days=60)
        db.commit()
    finally:
        db.close()

    result = undo_action(entry.id, user_id="u-1", max_age_days=30)
    assert result["success"] is False
    assert "too_old" in result["error"]


# ── Governed AI — query filters ────────────────────────────


def test_query_actions_filters_by_gate_decision():
    from app.core.governed_ai import (
        AiGateDecision,
        log_action,
        query_actions,
    )

    log_action(action_type="test.review_q", output={}, confidence=0.5)
    log_action(action_type="test.review_q", output={}, confidence=0.95)
    reviews = query_actions(action_type="test.review_q", gate_decision=AiGateDecision.REVIEW)
    silents = query_actions(action_type="test.review_q", gate_decision=AiGateDecision.AUTO_SILENT)

    assert len(reviews) >= 1
    assert all(r.gate_decision == "review" for r in reviews)
    assert all(r.gate_decision == "auto_silent" for r in silents)


# ── Webhooks — sign + verify ──────────────────────────────


def test_webhook_sign_then_verify_roundtrip():
    from app.core.webhooks import sign_payload, verify_signature

    body = b'{"type":"invoice.created","id":"i-1"}'
    sig = sign_payload("whsec_test", body)
    assert verify_signature("whsec_test", body, sig) is True


def test_webhook_verify_rejects_wrong_secret():
    from app.core.webhooks import sign_payload, verify_signature

    body = b"x"
    sig = sign_payload("right", body)
    assert verify_signature("wrong", body, sig) is False


def test_webhook_verify_rejects_missing_header():
    from app.core.webhooks import verify_signature

    assert verify_signature("s", b"x", None) is False
    assert verify_signature("s", b"x", "") is False
    assert verify_signature("s", b"x", "bogus") is False


# ── Webhooks — subscribe + publish ────────────────────────


def test_webhook_create_subscription(client):
    resp = client.post(
        "/api/v1/webhooks/subscriptions",
        json={
            "name": "Test sub",
            "url": "https://example.com/hook",
            "events": ["invoice.created", "invoice.paid"],
        },
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]
    assert data["secret"].startswith("whsec_")
    assert "invoice.created" in data["events"]


def test_webhook_publish_creates_deliveries(client):
    # Create a subscription first
    create = client.post(
        "/api/v1/webhooks/subscriptions",
        json={
            "url": "https://example.com/hook-pub",
            "events": ["payment.received"],
        },
    )
    sub_id = create.json()["data"]["id"]

    # Publish an event
    from app.core.webhooks import publish

    delivery_ids = publish(
        "payment.received",
        {"amount": 1500, "currency": "SAR"},
    )
    assert len(delivery_ids) >= 1

    # List deliveries
    listing = client.get("/api/v1/webhooks/deliveries")
    assert listing.status_code == 200
    bodies = listing.json()["data"]
    assert any(d["subscription_id"] == sub_id for d in bodies)

    # Cleanup
    client.delete(f"/api/v1/webhooks/subscriptions/{sub_id}")


def test_webhook_publish_respects_event_filter():
    from app.core.webhooks import publish

    # Publishing an event nobody subscribed to: 0 deliveries (or just existing subs)
    before_ids = publish("never.subscribed.event.x", {})
    assert before_ids == []


def test_webhook_delivery_retry_unknown_returns_error(client):
    resp = client.post("/api/v1/webhooks/deliveries/does-not-exist/retry")
    assert resp.status_code == 400


def test_webhook_delete_subscription(client):
    create = client.post(
        "/api/v1/webhooks/subscriptions",
        json={"url": "https://example.com/hook-del", "events": ["x"]},
    )
    sub_id = create.json()["data"]["id"]
    delete = client.delete(f"/api/v1/webhooks/subscriptions/{sub_id}")
    assert delete.status_code == 200
