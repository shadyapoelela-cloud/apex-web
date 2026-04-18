"""Tests for activity_log endpoints + auto_log SQLAlchemy listener."""

from __future__ import annotations

import uuid


def test_comment_on_new_entity_creates_row(client):
    """POST comment on an entity with no prior activity creates row 1."""
    eid = f"c-{uuid.uuid4().hex[:8]}"
    resp = client.post(
        f"/api/v1/activity/client/{eid}/comment",
        json={"body": "تعليق اختباري", "internal": False, "user_name": "tester"},
    )
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["action"] == "commented"
    assert data["summary"] == "تعليق اختباري"

    listing = client.get(f"/api/v1/activity/client/{eid}")
    assert listing.status_code == 200
    assert len(listing.json()["data"]) == 1


def test_internal_note_has_note_action(client):
    eid = f"c-{uuid.uuid4().hex[:8]}"
    client.post(
        f"/api/v1/activity/client/{eid}/comment",
        json={"body": "ملاحظة داخلية", "internal": True},
    )
    rows = client.get(f"/api/v1/activity/client/{eid}").json()["data"]
    assert rows[0]["action"] == "note"


def test_recent_across_an_entity_type(client):
    # Seed 2 different entities
    for _ in range(2):
        eid = f"c-{uuid.uuid4().hex[:8]}"
        client.post(
            f"/api/v1/activity/client/{eid}/comment",
            json={"body": "s"},
        )
    recent = client.get("/api/v1/activity/recent/client").json()
    assert recent["success"] is True
    assert len(recent["data"]) >= 2


def test_cannot_delete_system_event(client):
    """Try to insert + delete a system 'created' event — should be 403."""
    from app.core.activity_log import log_activity
    aid = log_activity(
        entity_type="invoice",
        entity_id=f"i-{uuid.uuid4().hex[:8]}",
        action="created",
        summary="seed",
    )
    resp = client.delete(f"/api/v1/activity/{aid}")
    assert resp.status_code == 403


def test_autolog_fires_on_status_change():
    """Changing status on a registered model auto-inserts an ActivityLog row."""
    from app.core.activity_log import ActivityLog
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        enqueue_submission,
    )
    from app.phase1.models.platform_models import SessionLocal

    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number=f"INV-AL-{uuid.uuid4().hex[:6]}",
        invoice_hash_b64="A" * 4,
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    # Mutate status
    db = SessionLocal()
    try:
        sub = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert sub is not None
        sub.status = ZatcaSubmissionStatus.CLEARED.value
        db.commit()
    finally:
        db.close()

    # Verify activity_log has the transition
    db = SessionLocal()
    try:
        logs = (
            db.query(ActivityLog)
            .filter(
                ActivityLog.entity_type == "zatca_submission",
                ActivityLog.entity_id == sid,
            )
            .all()
        )
    finally:
        db.close()

    assert any(r.action == "status_changed" for r in logs)
    transition = next(r for r in logs if r.action == "status_changed")
    assert transition.details["from"] == "pending"
    assert transition.details["to"] == "cleared"
