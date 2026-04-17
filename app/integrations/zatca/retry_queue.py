"""ZATCA submission retry queue — handle Fatoora API failures gracefully.

When a ZATCA submission fails (network blip, 5xx, timeout), we don't lose
the invoice. It's queued with exponential backoff and retried until:
  • It succeeds → status=cleared or status=reported
  • It's rejected with a 4xx that a retry won't fix → status=rejected
  • It exceeds max attempts → status=dead (ops intervention required)

Retry schedule (seconds from last attempt):
  1st: 30s, 2nd: 2m, 3rd: 10m, 4th: 1h, 5th: 6h → then dead

The dispatcher (Celery/APScheduler) polls `due_for_retry()` and calls
`attempt_next()` for each. For testing / manual review, the admin can
`retry_now(submission_id)` to skip the wait.

All tables tenant-scoped via TenantMixin.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional

from sqlalchemy import Column, DateTime, Integer, JSON, String, Text

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


class ZatcaSubmissionStatus(str, Enum):
    PENDING = "pending"
    IN_FLIGHT = "in_flight"
    CLEARED = "cleared"          # B2B clearance success
    REPORTED = "reported"        # B2C reporting success
    WARNINGS = "warnings"        # accepted with warnings
    REJECTED = "rejected"        # 4xx from ZATCA — retry won't help
    DEAD = "dead"                # max retries exhausted
    ERROR = "error"              # transient; will retry


# Retry delays in seconds by attempt count (after attempt 1).
_RETRY_DELAYS = [30, 120, 600, 3600, 21600]
MAX_ATTEMPTS = len(_RETRY_DELAYS) + 1  # 1 initial + 5 retries = 6 total


class ZatcaSubmission(Base, TenantMixin):
    """One attempted submission to the ZATCA Fatoora platform."""

    __tablename__ = "zatca_submissions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    # Invoice being submitted
    invoice_uuid = Column(String(36), nullable=False, index=True)
    invoice_number = Column(String(64), nullable=False, index=True)
    invoice_hash_b64 = Column(String(128), nullable=False)
    invoice_type = Column(String(16), nullable=False)   # 'clearance' | 'reporting'
    signed_xml = Column(Text, nullable=False)

    status = Column(String(16), nullable=False,
                    default=ZatcaSubmissionStatus.PENDING.value, index=True)
    attempts = Column(Integer, nullable=False, default=0)
    next_attempt_at = Column(DateTime(timezone=True), nullable=True, index=True)
    last_attempt_at = Column(DateTime(timezone=True), nullable=True)
    last_http_status = Column(Integer, nullable=True)
    last_error = Column(Text, nullable=True)

    # On success:
    cleared_invoice_b64 = Column(Text, nullable=True)
    warnings = Column(JSON, nullable=True)
    errors = Column(JSON, nullable=True)

    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    completed_at = Column(DateTime(timezone=True), nullable=True)


# ── Queue API ─────────────────────────────────────────────


def enqueue_submission(
    *,
    invoice_uuid: str,
    invoice_number: str,
    invoice_hash_b64: str,
    invoice_type: str,            # 'clearance' or 'reporting'
    signed_xml: str,
) -> str:
    """Queue an invoice for submission. Returns the submission ID."""
    assert invoice_type in ("clearance", "reporting")
    db = SessionLocal()
    try:
        sub = ZatcaSubmission(
            id=str(uuid.uuid4()),
            invoice_uuid=invoice_uuid,
            invoice_number=invoice_number,
            invoice_hash_b64=invoice_hash_b64,
            invoice_type=invoice_type,
            signed_xml=signed_xml,
            status=ZatcaSubmissionStatus.PENDING.value,
            next_attempt_at=datetime.now(timezone.utc),
        )
        db.add(sub)
        db.commit()
        return sub.id
    finally:
        db.close()


def due_for_retry(*, limit: int = 50) -> list[ZatcaSubmission]:
    """Return submissions whose next_attempt_at <= now and status is
    pending or error. Caller invokes attempt_next() on each."""
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        return (
            db.query(ZatcaSubmission)
            .filter(ZatcaSubmission.status.in_([
                ZatcaSubmissionStatus.PENDING.value,
                ZatcaSubmissionStatus.ERROR.value,
            ]))
            .filter(ZatcaSubmission.next_attempt_at <= now)
            .order_by(ZatcaSubmission.next_attempt_at)
            .limit(max(1, min(limit, 500)))
            .all()
        )
    finally:
        db.close()


def attempt_next(submission_id: str) -> dict:
    """Try a submission now. Updates status + schedules next retry if needed."""
    db = SessionLocal()
    try:
        sub = db.query(ZatcaSubmission).filter(
            ZatcaSubmission.id == submission_id
        ).first()
        if not sub:
            return {"success": False, "error": "not_found"}
        if sub.status in (
            ZatcaSubmissionStatus.CLEARED.value,
            ZatcaSubmissionStatus.REPORTED.value,
            ZatcaSubmissionStatus.REJECTED.value,
            ZatcaSubmissionStatus.DEAD.value,
        ):
            return {"success": True, "status": sub.status, "terminal": True}

        sub.status = ZatcaSubmissionStatus.IN_FLIGHT.value
        sub.attempts += 1
        sub.last_attempt_at = datetime.now(timezone.utc)
        db.commit()

        # Lazy import — avoids pulling requests at module load.
        from app.integrations.zatca.fatoora_client import (
            submit_clearance,
            submit_reporting,
        )

        try:
            submit_fn = (
                submit_clearance
                if sub.invoice_type == "clearance"
                else submit_reporting
            )
            resp = submit_fn(
                signed_xml=sub.signed_xml,
                invoice_hash_b64=sub.invoice_hash_b64,
                invoice_uuid=sub.invoice_uuid,
            )
        except Exception as e:
            logger.error("ZATCA submit raised: %s", e, exc_info=True)
            resp = None

        now = datetime.now(timezone.utc)
        # Refresh from DB (we already committed the in_flight state)
        sub = db.query(ZatcaSubmission).filter(
            ZatcaSubmission.id == submission_id
        ).first()

        if resp is None:
            # Hard exception → treat as error, schedule retry
            sub.status = ZatcaSubmissionStatus.ERROR.value
            sub.last_error = "submit raised unexpected exception"
            _schedule_retry(sub, now)
        elif resp.status in ("cleared", "reported", "warnings"):
            sub.status = {
                "cleared": ZatcaSubmissionStatus.CLEARED.value,
                "reported": ZatcaSubmissionStatus.REPORTED.value,
                "warnings": ZatcaSubmissionStatus.WARNINGS.value,
            }[resp.status]
            sub.cleared_invoice_b64 = resp.cleared_invoice_b64
            sub.warnings = resp.warnings or None
            sub.errors = resp.errors or None
            sub.completed_at = now
            sub.last_http_status = resp.http_status
        elif resp.status == "rejected":
            sub.status = ZatcaSubmissionStatus.REJECTED.value
            sub.errors = resp.errors or None
            sub.last_http_status = resp.http_status
            sub.last_error = "ZATCA rejected; retry won't help"
            sub.completed_at = now
        else:
            # 'error' — transient
            sub.status = ZatcaSubmissionStatus.ERROR.value
            sub.errors = resp.errors or None
            sub.last_http_status = resp.http_status
            sub.last_error = (resp.errors or [{}])[0].get("message", "")
            _schedule_retry(sub, now)

        db.commit()
        return {
            "success": True,
            "status": sub.status,
            "attempts": sub.attempts,
        }
    finally:
        db.close()


def _schedule_retry(sub: ZatcaSubmission, now: datetime) -> None:
    """Compute next_attempt_at based on attempt count. Mark DEAD on exhaustion."""
    idx = sub.attempts - 1   # 0-indexed into _RETRY_DELAYS
    if idx >= len(_RETRY_DELAYS):
        sub.status = ZatcaSubmissionStatus.DEAD.value
        sub.completed_at = now
        sub.next_attempt_at = None
        return
    delay = _RETRY_DELAYS[idx]
    sub.next_attempt_at = now + timedelta(seconds=delay)


def retry_now(submission_id: str) -> dict:
    """Admin-triggered immediate retry, bypassing the schedule."""
    db = SessionLocal()
    try:
        sub = db.query(ZatcaSubmission).filter(
            ZatcaSubmission.id == submission_id
        ).first()
        if not sub:
            return {"success": False, "error": "not_found"}
        sub.next_attempt_at = datetime.now(timezone.utc)
        db.commit()
    finally:
        db.close()
    return attempt_next(submission_id)


# ── Compliance stats ──────────────────────────────────────


def compliance_stats(*, since: Optional[datetime] = None) -> dict:
    """Aggregate submission stats for the compliance dashboard.

    Returns:
      {
        total, cleared, reported, warnings, rejected, dead, error, in_flight,
        success_rate_pct, avg_latency_seconds, dead_queue_size
      }
    """
    from sqlalchemy import func

    db = SessionLocal()
    try:
        q = db.query(ZatcaSubmission)
        if since:
            q = q.filter(ZatcaSubmission.created_at >= since)

        rows = q.all()
        total = len(rows)
        by_status: dict[str, int] = {}
        latencies: list[float] = []
        for r in rows:
            by_status[r.status] = by_status.get(r.status, 0) + 1
            if r.completed_at and r.created_at:
                latencies.append(
                    (r.completed_at - r.created_at).total_seconds()
                )
        successful = sum(
            by_status.get(s, 0)
            for s in ("cleared", "reported", "warnings")
        )
        success_rate = (successful / total * 100) if total > 0 else 0.0
        avg_latency = sum(latencies) / len(latencies) if latencies else 0.0
        return {
            "total": total,
            "cleared": by_status.get("cleared", 0),
            "reported": by_status.get("reported", 0),
            "warnings": by_status.get("warnings", 0),
            "rejected": by_status.get("rejected", 0),
            "dead": by_status.get("dead", 0),
            "error": by_status.get("error", 0),
            "in_flight": by_status.get("in_flight", 0),
            "pending": by_status.get("pending", 0),
            "success_rate_pct": round(success_rate, 2),
            "avg_latency_seconds": round(avg_latency, 2),
            "dead_queue_size": by_status.get("dead", 0),
        }
    finally:
        db.close()
