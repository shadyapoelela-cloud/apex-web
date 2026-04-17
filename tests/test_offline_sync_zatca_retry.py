"""Tests for offline sync queue + ZATCA retry queue."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest


# ── Offline sync: core push flow ──────────────────────────


def test_sync_idempotency_returns_cached_result(client):
    """Same op_id sent twice → server returns the cached response both
    times. No duplicate DB work happens."""
    # Register a simple handler so the op can apply.
    from app.core.offline_sync import (
        SyncOpStatus,
        register_sync_handler,
    )

    apply_count = {"n": 0}

    def _handler(op, db):
        apply_count["n"] += 1
        return SyncOpStatus.APPLIED, {"echoed": op.payload.get("key")}

    register_sync_handler("test_entity_idem", _handler)

    op_id = f"op_{uuid.uuid4().hex[:16]}"
    body = {
        "operations": [
            {
                "op_id": op_id,
                "entity_type": "test_entity_idem",
                "verb": "create",
                "payload": {"key": "v1"},
                "client_timestamp": datetime.now(timezone.utc).isoformat(),
            }
        ]
    }
    first = client.post("/api/v1/sync/push", json=body)
    assert first.status_code == 200
    assert first.json()["data"][0]["status"] == "applied"

    second = client.post("/api/v1/sync/push", json=body)
    assert second.status_code == 200
    assert second.json()["data"][0]["status"] == "applied"
    # Handler ran exactly once
    assert apply_count["n"] == 1


def test_sync_unknown_entity_type_is_rejected(client):
    op_id = f"op_{uuid.uuid4().hex[:16]}"
    body = {
        "operations": [
            {
                "op_id": op_id,
                "entity_type": "no_such_entity_xyz",
                "verb": "create",
                "payload": {},
                "client_timestamp": datetime.now(timezone.utc).isoformat(),
            }
        ]
    }
    resp = client.post("/api/v1/sync/push", json=body)
    assert resp.status_code == 200
    r = resp.json()["data"][0]
    assert r["status"] == "rejected"


def test_sync_status_endpoint(client):
    """/status/{op_id} returns the stored op — 404 for unknown."""
    resp = client.get("/api/v1/sync/status/does-not-exist")
    assert resp.status_code == 404


def test_sync_batch_processes_multiple_ops(client):
    from app.core.offline_sync import SyncOpStatus, register_sync_handler

    def _h(op, db):
        return SyncOpStatus.APPLIED, {"echo": op.payload.get("i")}

    register_sync_handler("test_batch_entity", _h)
    body = {
        "operations": [
            {
                "op_id": f"batch_{i}_{uuid.uuid4().hex[:8]}",
                "entity_type": "test_batch_entity",
                "verb": "create",
                "payload": {"i": i},
                "client_timestamp": datetime.now(timezone.utc).isoformat(),
            }
            for i in range(5)
        ]
    }
    resp = client.post("/api/v1/sync/push", json=body)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data) == 5
    assert all(r["status"] == "applied" for r in data)


def test_sync_mark_superseded_clears_older_pending():
    """Older pending ops on the same entity become SUPERSEDED."""
    from app.core.offline_sync import (
        SyncOperation,
        SyncOpStatus,
        mark_superseded,
    )
    from app.phase1.models.platform_models import SessionLocal

    db = SessionLocal()
    entity_id = f"ent_{uuid.uuid4().hex[:8]}"
    now = datetime.now(timezone.utc)

    # Older pending ops
    for i, ts in enumerate([now - timedelta(hours=2), now - timedelta(hours=1)]):
        db.add(SyncOperation(
            id=str(uuid.uuid4()),
            op_id=f"old_{i}_{uuid.uuid4().hex[:6]}",
            entity_type="test_supersede",
            entity_id=entity_id,
            verb="update",
            payload={"v": i},
            client_timestamp=ts,
            status=SyncOpStatus.PENDING.value,
        ))
    db.commit()

    count = mark_superseded("test_supersede", entity_id, up_to=now, db=db)
    db.commit()
    assert count == 2
    rows = db.query(SyncOperation).filter(
        SyncOperation.entity_id == entity_id
    ).all()
    assert all(r.status == SyncOpStatus.SUPERSEDED.value for r in rows)
    db.close()


# ── ZATCA retry queue ─────────────────────────────────────


def test_zatca_enqueue_creates_pending_submission():
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        enqueue_submission,
    )
    from app.phase1.models.platform_models import SessionLocal

    sid = enqueue_submission(
        invoice_uuid="uuid-" + uuid.uuid4().hex[:8],
        invoice_number="INV-TEST-1",
        invoice_hash_b64="AAAA",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    db = SessionLocal()
    try:
        row = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert row is not None
        assert row.status == ZatcaSubmissionStatus.PENDING.value
        assert row.attempts == 0
    finally:
        db.close()


def test_zatca_attempt_on_rejected_is_terminal():
    """4xx from ZATCA → rejected; retry is a no-op."""
    from app.integrations.zatca import fatoora_client
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmissionStatus,
        attempt_next,
        enqueue_submission,
    )

    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number="INV-REJ",
        invoice_hash_b64="BBBB",
        invoice_type="reporting",
        signed_xml="<x/>",
    )

    fake = type("R", (), {
        "status": "rejected",
        "http_status": 400,
        "errors": [{"code": "BAD", "message": "validation failed"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()
    with patch.object(fatoora_client, "submit_reporting", return_value=fake):
        result = attempt_next(sid)
    assert result["status"] == ZatcaSubmissionStatus.REJECTED.value

    # A second attempt on a terminal state is safe
    with patch.object(fatoora_client, "submit_reporting") as mocked:
        result2 = attempt_next(sid)
    assert result2.get("terminal") is True
    assert mocked.call_count == 0  # didn't hit the API again


def test_zatca_transient_error_schedules_retry():
    """status='error' from Fatoora → schedule retry, not dead."""
    from app.integrations.zatca import fatoora_client
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        attempt_next,
        enqueue_submission,
    )
    from app.phase1.models.platform_models import SessionLocal

    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number="INV-ERR",
        invoice_hash_b64="CCCC",
        invoice_type="reporting",
        signed_xml="<x/>",
    )

    fake = type("R", (), {
        "status": "error",
        "http_status": 500,
        "errors": [{"code": "HTTP_500", "message": "server down"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()
    with patch.object(fatoora_client, "submit_reporting", return_value=fake):
        attempt_next(sid)

    db = SessionLocal()
    try:
        row = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert row.status == ZatcaSubmissionStatus.ERROR.value
        assert row.attempts == 1
        assert row.next_attempt_at is not None
    finally:
        db.close()


def test_zatca_exhausted_retries_become_dead():
    """After MAX_ATTEMPTS consecutive errors, submission becomes DEAD."""
    from app.integrations.zatca import fatoora_client
    from app.integrations.zatca.retry_queue import (
        MAX_ATTEMPTS,
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        attempt_next,
        enqueue_submission,
        retry_now,
    )
    from app.phase1.models.platform_models import SessionLocal

    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number="INV-DEAD",
        invoice_hash_b64="DDDD",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    fake_err = type("R", (), {
        "status": "error",
        "http_status": 503,
        "errors": [{"code": "HTTP_503", "message": "down"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()
    with patch.object(fatoora_client, "submit_reporting", return_value=fake_err):
        for _ in range(MAX_ATTEMPTS):
            retry_now(sid)

    db = SessionLocal()
    try:
        row = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert row.status == ZatcaSubmissionStatus.DEAD.value
        assert row.attempts == MAX_ATTEMPTS
    finally:
        db.close()


def test_zatca_success_clears_submission():
    from app.integrations.zatca import fatoora_client
    from app.integrations.zatca.retry_queue import (
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        attempt_next,
        enqueue_submission,
    )
    from app.phase1.models.platform_models import SessionLocal

    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number="INV-OK",
        invoice_hash_b64="EEEE",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    fake_ok = type("R", (), {
        "status": "reported",
        "http_status": 200,
        "errors": [],
        "warnings": [],
        "cleared_invoice_b64": "<x/>",
    })()
    with patch.object(fatoora_client, "submit_reporting", return_value=fake_ok):
        attempt_next(sid)

    db = SessionLocal()
    try:
        row = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert row.status == ZatcaSubmissionStatus.REPORTED.value
        assert row.completed_at is not None
    finally:
        db.close()


def test_compliance_stats_returns_counts():
    from app.integrations.zatca.retry_queue import (
        compliance_stats,
        enqueue_submission,
    )

    enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number="INV-STATS-1",
        invoice_hash_b64="FFFF",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    stats = compliance_stats()
    assert "total" in stats and stats["total"] >= 1
    assert "success_rate_pct" in stats
    assert "dead_queue_size" in stats
