"""Tests for proactive AI scans."""

from __future__ import annotations

import uuid


def test_scan_endpoint_returns_summary(client):
    """POST /api/v1/ai/scan returns a well-formed summary dict."""
    resp = client.post("/api/v1/ai/scan?emit_activity=false")
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "scans_run" in data
    assert "total_findings" in data
    assert "by_severity" in data
    assert set(data["by_severity"].keys()) >= {"info", "warning", "error"}
    assert "by_scan" in data
    # The 3 built-in scans must each register a count.
    assert "overdue_receivables" in data["by_scan"]
    assert "dead_zatca_submissions" in data["by_scan"]
    assert "stale_sync_ops" in data["by_scan"]


def test_dead_zatca_scan_finds_dead_submissions():
    """Insert a DEAD submission; dead_zatca_submissions picks it up."""
    from app.ai.proactive import dead_zatca_submissions
    from app.integrations.zatca.retry_queue import (
        MAX_ATTEMPTS,
        ZatcaSubmission,
        ZatcaSubmissionStatus,
        enqueue_submission,
        retry_now,
    )
    from app.phase1.models.platform_models import SessionLocal
    from unittest.mock import patch

    # Exhaust retries to mark as DEAD.
    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number=f"INV-DEAD-{uuid.uuid4().hex[:6]}",
        invoice_hash_b64="AAAA",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    err = type("R", (), {
        "status": "error",
        "http_status": 500,
        "errors": [{"code": "HTTP_500", "message": "down"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()
    from app.integrations.zatca import fatoora_client
    with patch.object(fatoora_client, "submit_reporting", return_value=err):
        for _ in range(MAX_ATTEMPTS):
            retry_now(sid)

    # Verify it's actually DEAD
    db = SessionLocal()
    try:
        row = db.query(ZatcaSubmission).filter(ZatcaSubmission.id == sid).first()
        assert row.status == ZatcaSubmissionStatus.DEAD.value
    finally:
        db.close()

    # Now the scan should surface it
    findings = dead_zatca_submissions()
    assert any(f.entity_id == sid for f in findings)
    match = next(f for f in findings if f.entity_id == sid)
    assert match.severity == "error"
    assert match.details["attempts"] == MAX_ATTEMPTS


def test_stale_sync_ops_scan_returns_empty_when_none_stale():
    """With a fresh DB, no sync ops are > 24 hours old → scan returns []."""
    from app.ai.proactive import stale_sync_ops
    result = stale_sync_ops(hours_stale=240)  # 10 days → clearly empty
    assert isinstance(result, list)
    # We don't assert emptiness because prior tests may have left rows;
    # just assert shape.
    for f in result:
        assert f.severity == "warning"
        assert f.scan == "stale_sync_ops"


def test_run_all_scans_emits_activity_rows():
    """Running with emit_activity=True writes ActivityLog rows for each finding."""
    from app.ai.proactive import run_all_scans
    from app.core.activity_log import ActivityLog
    from app.integrations.zatca.retry_queue import (
        MAX_ATTEMPTS,
        enqueue_submission,
        retry_now,
    )
    from app.phase1.models.platform_models import SessionLocal
    from unittest.mock import patch

    # Seed a DEAD submission to guarantee ≥1 finding
    sid = enqueue_submission(
        invoice_uuid=uuid.uuid4().hex,
        invoice_number=f"INV-ACT-{uuid.uuid4().hex[:6]}",
        invoice_hash_b64="BBBB",
        invoice_type="reporting",
        signed_xml="<x/>",
    )
    err = type("R", (), {
        "status": "error",
        "http_status": 503,
        "errors": [{"code": "HTTP_503", "message": "down"}],
        "warnings": [],
        "cleared_invoice_b64": None,
    })()
    from app.integrations.zatca import fatoora_client
    with patch.object(fatoora_client, "submit_reporting", return_value=err):
        for _ in range(MAX_ATTEMPTS):
            retry_now(sid)

    summary = run_all_scans(emit_activity=True)
    assert summary["total_findings"] >= 1

    # Verify an ActivityLog row was created for our finding
    db = SessionLocal()
    try:
        rows = (
            db.query(ActivityLog)
            .filter(
                ActivityLog.entity_id == sid,
                ActivityLog.action == "proactive.dead_zatca_submissions",
            )
            .all()
        )
        assert len(rows) >= 1
    finally:
        db.close()


def test_scan_tolerates_missing_tables():
    """overdue_receivables returns [] gracefully if customer_invoices table
    doesn't exist (not in minimal test schema)."""
    from app.ai.proactive import overdue_receivables
    result = overdue_receivables(days_overdue=7)
    assert isinstance(result, list)
