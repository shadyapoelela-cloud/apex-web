"""
Tests for app/core/zatca_retry_queue.py and app/core/zatca_queue_routes.py
(Wave 5 PR#1 + PR#2).

Covers:
- enqueue stores + audit-trail event fires
- record_success / record_failure transitions with exponential backoff
- process_due drains only rows whose next_retry_at has passed
- giveup after max_attempts
- HTTP routes: enqueue, list, stats, detail, process dry-run
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.core import zatca_retry_queue as q
from app.core.compliance_models import ZatcaSubmissionQueue
from app.core.compliance_service import verify_audit_chain
from app.core.zatca_retry_queue import (
    STATUS_CLEARED,
    STATUS_DRAFT,
    STATUS_GIVEUP,
    STATUS_PENDING,
    SubmissionResult,
)
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset_queue():
    """Clear the queue + audit trail between tests."""
    from app.core.compliance_models import AuditTrail

    db = SessionLocal()
    try:
        db.query(ZatcaSubmissionQueue).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    yield


def _insert_pending(row_id: str = None, *, next_retry_at=None, attempts: int = 0) -> str:
    """Helper: shove a row directly in with a given state."""
    from app.phase1.models.platform_models import gen_uuid

    db = SessionLocal()
    try:
        row = ZatcaSubmissionQueue(
            id=row_id or gen_uuid(),
            invoice_id=f"INV-{(row_id or gen_uuid())[:6]}",
            payload={"xml": "<Invoice/>"},
            status=STATUS_PENDING,
            attempts=attempts,
            max_attempts=7,
            next_retry_at=next_retry_at
            or datetime.now(timezone.utc) - timedelta(minutes=1),
        )
        db.add(row)
        db.commit()
        return row.id
    finally:
        db.close()


class TestEnqueue:
    def test_enqueue_creates_pending_by_default(self):
        row_id = q.enqueue("INV-001", {"xml": "<x/>"})
        row = q.get_row(row_id)
        assert row is not None
        assert row["status"] == STATUS_PENDING
        assert row["attempts"] == 0
        assert row["next_retry_at"] is not None

    def test_enqueue_as_draft_has_no_next_retry(self):
        row_id = q.enqueue("INV-002", {"x": 1}, start_as=STATUS_DRAFT)
        row = q.get_row(row_id)
        assert row["status"] == STATUS_DRAFT
        assert row["next_retry_at"] is None

    def test_enqueue_emits_audit_event(self):
        q.enqueue("INV-003", {})
        assert verify_audit_chain()["ok"] is True
        # There should be at least one zatca.queue.enqueue event.
        from app.core.compliance_models import AuditTrail

        db = SessionLocal()
        try:
            actions = [r.action for r in db.query(AuditTrail).all()]
        finally:
            db.close()
        assert "zatca.queue.enqueue" in actions

    def test_invalid_start_as_rejected(self):
        with pytest.raises(ValueError):
            q.enqueue("INV-004", {}, start_as="bogus")


class TestBackoffLadder:
    def test_first_failure_schedules_1_minute(self):
        row_id = q.enqueue("INV-010", {})
        new_status = q.record_failure(row_id, error_code="X", error_message="boom")
        assert new_status == STATUS_PENDING
        row = q.get_row(row_id)
        assert row["attempts"] == 1
        # next_retry_at should be ~1 minute from now.
        next_at = datetime.fromisoformat(row["next_retry_at"])
        # SQLite drops tz info on round-trip, so compare naively.
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        next_at_naive = next_at.replace(tzinfo=None) if next_at.tzinfo else next_at
        delta = next_at_naive - now_naive
        assert timedelta(seconds=50) < delta < timedelta(seconds=75)

    def test_second_failure_schedules_5_minutes(self):
        row_id = q.enqueue("INV-011", {})
        q.record_failure(row_id, error_code="X", error_message=None)
        q.record_failure(row_id, error_code="Y", error_message=None)
        row = q.get_row(row_id)
        assert row["attempts"] == 2
        next_at = datetime.fromisoformat(row["next_retry_at"])
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        next_at_naive = next_at.replace(tzinfo=None) if next_at.tzinfo else next_at
        delta = next_at_naive - now_naive
        # Ladder index 1 = 5 minutes (1m → 5m → 30m → 2h → 12h → 24h → 48h).
        assert timedelta(minutes=4) < delta < timedelta(minutes=6)

    def test_giveup_after_max_attempts(self):
        row_id = q.enqueue("INV-012", {}, max_attempts=3)
        for _ in range(3):
            q.record_failure(row_id, error_code="X", error_message=None)
        row = q.get_row(row_id)
        assert row["status"] == STATUS_GIVEUP
        assert row["next_retry_at"] is None
        assert row["attempts"] == 3


class TestSuccessPath:
    def test_record_success_marks_cleared(self):
        row_id = q.enqueue("INV-020", {})
        q.record_success(row_id, cleared_uuid="CLR-1")
        row = q.get_row(row_id)
        assert row["status"] == STATUS_CLEARED
        assert row["cleared_uuid"] == "CLR-1"
        assert row["cleared_at"] is not None

    def test_success_is_idempotent(self):
        row_id = q.enqueue("INV-021", {})
        q.record_success(row_id, cleared_uuid="CLR-2")
        q.record_success(row_id, cleared_uuid="CLR-2")  # should not raise
        row = q.get_row(row_id)
        assert row["status"] == STATUS_CLEARED


class TestDueQuery:
    def test_only_pending_with_due_next_retry_returned(self):
        # Row A: due now.
        a = _insert_pending()
        # Row B: not yet due.
        b = _insert_pending(next_retry_at=datetime.now(timezone.utc) + timedelta(hours=1))
        due = q.due_for_retry()
        ids = {r["id"] for r in due}
        assert a in ids
        assert b not in ids

    def test_cleared_rows_excluded(self):
        row_id = q.enqueue("INV-030", {})
        q.record_success(row_id)
        assert q.due_for_retry() == []


class TestProcessDue:
    def test_submit_ok_clears_row(self):
        row_id = q.enqueue("INV-040", {})

        def submit(_row):
            return SubmissionResult(ok=True, cleared_uuid="UUID-OK")

        summary = q.process_due(submit)
        assert summary == {"processed": 1, "cleared": 1, "pending": 0, "giveup": 0}
        assert q.get_row(row_id)["status"] == STATUS_CLEARED

    def test_submit_fail_schedules_retry(self):
        row_id = q.enqueue("INV-041", {})

        def submit(_row):
            return SubmissionResult(ok=False, error_code="TIMEOUT", error_message="x")

        summary = q.process_due(submit)
        assert summary["pending"] == 1
        row = q.get_row(row_id)
        assert row["status"] == STATUS_PENDING
        assert row["attempts"] == 1
        assert row["last_error_code"] == "TIMEOUT"

    def test_exception_in_submit_fn_counts_as_failure(self):
        row_id = q.enqueue("INV-042", {})

        def submit(_row):
            raise RuntimeError("network dead")

        summary = q.process_due(submit)
        assert summary["pending"] + summary["giveup"] == 1
        row = q.get_row(row_id)
        assert row["last_error_code"] == "SUBMIT_EXCEPTION"


class TestStats:
    def test_counts_by_status(self):
        q.enqueue("A", {})
        q.enqueue("B", {}, start_as=STATUS_DRAFT)
        cleared_id = q.enqueue("C", {})
        q.record_success(cleared_id)
        s = q.stats()
        assert s["pending"] == 1
        assert s["draft"] == 1
        assert s["cleared"] == 1
        assert s["total"] == 3


# ── Routes ────────────────────────────────────────────────────────────


class TestRoutes:
    def test_enqueue_requires_auth(self, client: TestClient):
        r = client.post(
            "/zatca/queue/enqueue",
            json={"invoice_id": "X", "payload": {}},
        )
        assert r.status_code == 401

    def test_enqueue_returns_id(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/queue/enqueue",
            headers=auth_header,
            json={"invoice_id": "ROUTE-1", "payload": {"xml": "<x/>"}},
        )
        assert r.status_code == 200
        assert r.json()["data"]["id"]

    def test_enqueue_invalid_start_as_rejected(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/queue/enqueue",
            headers=auth_header,
            json={"invoice_id": "X", "payload": {}, "start_as": "bogus"},
        )
        assert r.status_code == 400

    def test_list_with_status_filter(self, client: TestClient, auth_header):
        q.enqueue("LIST-1", {})
        q.enqueue("LIST-2", {}, start_as=STATUS_DRAFT)
        r = client.get("/zatca/queue?status=pending", headers=auth_header)
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["count"] == 1

    def test_list_invalid_status_rejected(self, client: TestClient, auth_header):
        r = client.get("/zatca/queue?status=bogus", headers=auth_header)
        assert r.status_code == 400

    def test_stats_route(self, client: TestClient, auth_header):
        q.enqueue("STAT-1", {})
        r = client.get("/zatca/queue/stats", headers=auth_header)
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["pending"] >= 1

    def test_detail_404_when_unknown(self, client: TestClient, auth_header):
        r = client.get("/zatca/queue/nope", headers=auth_header)
        assert r.status_code == 404

    def test_process_dry_run_returns_pending(self, client: TestClient, auth_header):
        q.enqueue("PROC-1", {})
        r = client.post(
            "/zatca/queue/process",
            headers=auth_header,
            json={"dry_run": True, "limit": 10},
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["dry_run"] is True
        assert data["pending_count"] >= 1

    def test_process_real_run_returns_501(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/queue/process",
            headers=auth_header,
            json={"dry_run": False, "limit": 10},
        )
        assert r.status_code == 501
