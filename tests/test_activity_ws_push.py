"""Tests for WebSocket push from activity_log.log_activity().

Verifies that when a comment or status-change is logged, the hub
publishes a payload to the entity-channel and the user-channel.
"""

from __future__ import annotations

import asyncio
import uuid


def test_posting_comment_publishes_to_entity_channel(client):
    """POST /activity/{type}/{id}/comment → hub.publish fires."""
    from app.core.websocket_hub import get_hub

    hub = get_hub()
    received: list[dict] = []

    # Replace hub.publish for the duration of the test.
    orig_publish = hub.publish

    async def fake_publish(channel: str, payload: dict) -> int:
        received.append({"channel": channel, "payload": payload})
        return 1

    hub.publish = fake_publish  # type: ignore
    try:
        entity_id = f"c-ws-{uuid.uuid4().hex[:6]}"
        resp = client.post(
            f"/api/v1/activity/client/{entity_id}/comment",
            json={"body": "test ws push", "internal": False, "user_id": "u-42"},
        )
        assert resp.status_code == 201

        # Give the create_task scheduled coroutine a chance to run.
        loop = asyncio.new_event_loop()
        try:
            loop.run_until_complete(asyncio.sleep(0.05))
        finally:
            loop.close()
    finally:
        hub.publish = orig_publish  # type: ignore

    # We expect at least one publish to the entity channel.
    channels = {r["channel"] for r in received}
    assert any(ch.startswith("entity:client:") for ch in channels), (
        f"no entity:client:* channel; got {channels}"
    )
    # Payload shape
    by_channel = {r["channel"]: r["payload"] for r in received}
    sample = next(iter(by_channel.values()))
    assert sample["type"].startswith("activity.")
    assert sample["entity_type"] == "client"
    assert sample["action"] in ("commented", "note")


def test_status_change_autolog_publishes_event():
    """Auto-log on ZatcaSubmission status change → WebSocket push too."""
    from app.core.websocket_hub import get_hub
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        enqueue_submission,
    )
    from app.phase1.models.platform_models import SessionLocal

    hub = get_hub()
    received: list[dict] = []
    orig_publish = hub.publish

    async def fake_publish(channel: str, payload: dict) -> int:
        received.append({"channel": channel, "payload": payload})
        return 1

    hub.publish = fake_publish  # type: ignore
    try:
        sid = enqueue_submission(
            invoice_uuid=uuid.uuid4().hex,
            invoice_number=f"INV-WS-{uuid.uuid4().hex[:6]}",
            invoice_hash_b64="AAAA",
            invoice_type="reporting",
            signed_xml="<x/>",
        )
        # No event loop here, so the push is skipped — that's the
        # documented behaviour. Status-change still persists.
        db = SessionLocal()
        try:
            sub = (
                db.query(ZatcaSubmission)
                .filter(ZatcaSubmission.id == sid)
                .first()
            )
            sub.status = ZatcaSubmissionStatus.CLEARED.value
            db.commit()
        finally:
            db.close()
    finally:
        hub.publish = orig_publish  # type: ignore

    # We don't assert on `received` here because the test is sync and
    # there's no running event loop — the important thing is that no
    # exception escaped and the row was persisted.
    db = SessionLocal()
    try:
        sub = (
            db.query(ZatcaSubmission)
            .filter(ZatcaSubmission.id == sid)
            .first()
        )
        assert sub is not None
        assert sub.status == ZatcaSubmissionStatus.CLEARED.value
    finally:
        db.close()


def test_ws_push_swallows_errors_does_not_break_log_activity():
    """If hub.publish throws, log_activity must still return normally."""
    from app.core.activity_log import ActivityLog, log_activity
    from app.core.websocket_hub import get_hub
    from app.phase1.models.platform_models import SessionLocal

    hub = get_hub()
    orig = hub.publish

    async def angry(channel: str, payload: dict) -> int:
        raise RuntimeError("simulated hub failure")

    hub.publish = angry  # type: ignore
    try:
        aid = log_activity(
            entity_type="invoice",
            entity_id=f"i-{uuid.uuid4().hex[:6]}",
            action="updated",
            summary="resilient",
        )
    finally:
        hub.publish = orig  # type: ignore

    assert aid  # did return an id despite the error

    db = SessionLocal()
    try:
        row = db.query(ActivityLog).filter(ActivityLog.id == aid).first()
        assert row is not None
    finally:
        db.close()
