"""
APEX — ZATCA offline retry queue (Wave 5 PR#1).

Pattern #123 + #174 from APEX_GLOBAL_RESEARCH_210:
- Offline invoice queue with crypto stamp (resume when gateway back up)
- Exponential backoff retry queue (Postgres-backed: 1m/5m/30m/2h/12h/24h)

Design:
- Every invoice submission is enqueued via enqueue() — successful
  synchronous attempts immediately promote the row to "cleared", so
  the queue doubles as a full submission ledger.
- Failures record the error + schedule next_retry_at on an exponential
  ladder (1m → 5m → 30m → 2h → 12h → 24h → 48h). Seventh failure
  marks the row "giveup" — a human must intervene.
- process_due() pulls rows whose next_retry_at <= now and yields them
  to a caller-supplied submit_fn. This lets the module stay free of
  any HTTP client so tests can run fully offline.
- Every state transition emits an audit-trail event via
  app.core.compliance_service.write_audit_event so the tamper-evident
  chain covers the queue lifecycle.

No side effects outside the DB and the audit trail.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, Iterable, List, Optional, Tuple

from app.core.compliance_models import ZatcaSubmissionQueue
from app.core.compliance_service import write_audit_event
from app.phase1.models.platform_models import SessionLocal, gen_uuid

logger = logging.getLogger(__name__)

# Exponential backoff ladder in minutes. Length determines default
# max_attempts; each row can override via enqueue(max_attempts=...)
# for domains that want stricter or looser limits.
_BACKOFF_MINUTES: Tuple[int, ...] = (1, 5, 30, 120, 720, 1440, 2880)

# Public status constants — use these instead of bare strings so the
# caller can refactor if we later move to an Enum column.
STATUS_DRAFT = "draft"
STATUS_PENDING = "pending"
STATUS_CLEARED = "cleared"
STATUS_GIVEUP = "giveup"


@dataclass
class SubmissionResult:
    """Return value callers pass back from their submit_fn.

    `ok=True` promotes the row to "cleared" and stamps the uuid.
    `ok=False` records the error + schedules the next retry; on the
    final attempt the row transitions to "giveup".
    """

    ok: bool
    cleared_uuid: Optional[str] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _next_retry_delay(attempts: int) -> Optional[timedelta]:
    """Return the wait before the next attempt, or None if exhausted.

    `attempts` is the post-increment failure count: 1 means "we just
    recorded the first failure, schedule delay #1". So we index the
    ladder at attempts-1 to pick up the 1m/5m/30m/... values in order.
    """
    if attempts < 1:
        return timedelta(0)
    idx = attempts - 1
    if idx >= len(_BACKOFF_MINUTES):
        return None
    return timedelta(minutes=_BACKOFF_MINUTES[idx])


# ── Public API ────────────────────────────────────────────────────────


def enqueue(
    invoice_id: str,
    payload: Dict[str, Any],
    *,
    tenant_id: Optional[str] = None,
    max_attempts: Optional[int] = None,
    start_as: str = STATUS_PENDING,
) -> str:
    """Persist a submission to the queue. Returns the queue-row id.

    `start_as` defaults to "pending" — caller is ready to try now. Use
    "draft" when the row is being staged but shouldn't be processed by
    the worker yet (e.g. awaiting approval).
    """
    if start_as not in (STATUS_DRAFT, STATUS_PENDING):
        raise ValueError(f"invalid start_as: {start_as!r}")

    db = SessionLocal()
    try:
        row = ZatcaSubmissionQueue(
            id=gen_uuid(),
            tenant_id=tenant_id,
            invoice_id=invoice_id,
            payload=payload,
            status=start_as,
            attempts=0,
            max_attempts=max_attempts or len(_BACKOFF_MINUTES),
            next_retry_at=_now() if start_as == STATUS_PENDING else None,
        )
        db.add(row)
        db.commit()
        row_id = row.id
    finally:
        db.close()

    write_audit_event(
        action="zatca.queue.enqueue",
        entity_type="zatca_submission",
        entity_id=row_id,
        metadata={"invoice_id": invoice_id, "status": start_as},
    )
    return row_id


def due_for_retry(limit: int = 100) -> List[Dict[str, Any]]:
    """Return up to `limit` pending rows whose next_retry_at ≤ now.

    Returns plain dicts (not ORM objects) so callers can close their
    own DB sessions without detached-instance errors. Each dict has
    id, invoice_id, payload, attempts — enough to reconstruct a retry.
    """
    db = SessionLocal()
    try:
        rows = (
            db.query(ZatcaSubmissionQueue)
            .filter(ZatcaSubmissionQueue.status == STATUS_PENDING)
            .filter(ZatcaSubmissionQueue.next_retry_at <= _now())
            .order_by(ZatcaSubmissionQueue.next_retry_at.asc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": r.id,
                "tenant_id": r.tenant_id,
                "invoice_id": r.invoice_id,
                "payload": r.payload,
                "attempts": r.attempts,
                "max_attempts": r.max_attempts,
            }
            for r in rows
        ]
    finally:
        db.close()


def record_success(row_id: str, cleared_uuid: Optional[str] = None) -> None:
    """Mark a submission as cleared. Idempotent — re-calling on an
    already-cleared row is a no-op aside from updating updated_at."""
    db = SessionLocal()
    try:
        row = (
            db.query(ZatcaSubmissionQueue)
            .filter(ZatcaSubmissionQueue.id == row_id)
            .first()
        )
        if row is None:
            raise LookupError(f"zatca queue row {row_id} not found")
        row.status = STATUS_CLEARED
        row.cleared_uuid = cleared_uuid
        row.cleared_at = _now()
        row.last_attempt_at = _now()
        db.commit()
        invoice_id = row.invoice_id
    finally:
        db.close()

    write_audit_event(
        action="zatca.queue.cleared",
        entity_type="zatca_submission",
        entity_id=row_id,
        metadata={"invoice_id": invoice_id, "cleared_uuid": cleared_uuid},
    )


def record_failure(
    row_id: str,
    *,
    error_code: Optional[str],
    error_message: Optional[str],
) -> str:
    """Record a failed attempt and schedule the next retry.

    Returns the new status ("pending" if more attempts remain, else
    "giveup"). The caller doesn't have to think about the backoff —
    this module owns the ladder.
    """
    db = SessionLocal()
    try:
        row = (
            db.query(ZatcaSubmissionQueue)
            .filter(ZatcaSubmissionQueue.id == row_id)
            .first()
        )
        if row is None:
            raise LookupError(f"zatca queue row {row_id} not found")

        row.attempts += 1
        row.last_attempt_at = _now()
        row.last_error_code = (error_code or "")[:80]
        row.last_error_message = error_message

        # Schedule next retry or give up.
        if row.attempts >= row.max_attempts:
            row.status = STATUS_GIVEUP
            row.next_retry_at = None
            new_status = STATUS_GIVEUP
        else:
            delay = _next_retry_delay(row.attempts)
            if delay is None:
                row.status = STATUS_GIVEUP
                row.next_retry_at = None
                new_status = STATUS_GIVEUP
            else:
                row.status = STATUS_PENDING
                row.next_retry_at = _now() + delay
                new_status = STATUS_PENDING

        db.commit()
        invoice_id = row.invoice_id
        attempts = row.attempts
    finally:
        db.close()

    write_audit_event(
        action=f"zatca.queue.{new_status}",
        entity_type="zatca_submission",
        entity_id=row_id,
        metadata={
            "invoice_id": invoice_id,
            "attempts": attempts,
            "error_code": error_code,
        },
    )
    return new_status


def process_due(
    submit_fn: Callable[[Dict[str, Any]], SubmissionResult],
    *,
    limit: int = 50,
) -> Dict[str, int]:
    """Drain the due queue by calling submit_fn on each pending row.

    submit_fn receives the row dict (from due_for_retry) and returns a
    SubmissionResult. This module handles the state transitions so the
    caller never has to think about retry scheduling.

    Returns a summary: {"processed", "cleared", "pending", "giveup"}.
    """
    rows = due_for_retry(limit)
    summary = {"processed": 0, "cleared": 0, "pending": 0, "giveup": 0}
    for row in rows:
        summary["processed"] += 1
        try:
            result = submit_fn(row)
        except Exception as e:
            logger.exception("submit_fn raised for row %s", row["id"])
            result = SubmissionResult(
                ok=False,
                error_code="SUBMIT_EXCEPTION",
                error_message=str(e)[:2000],
            )

        if result.ok:
            record_success(row["id"], cleared_uuid=result.cleared_uuid)
            summary["cleared"] += 1
        else:
            new_status = record_failure(
                row["id"],
                error_code=result.error_code,
                error_message=result.error_message,
            )
            summary[new_status] += 1
    return summary


def get_row(row_id: str) -> Optional[Dict[str, Any]]:
    """Inspect a single queue row (for the admin detail drawer)."""
    db = SessionLocal()
    try:
        row = (
            db.query(ZatcaSubmissionQueue)
            .filter(ZatcaSubmissionQueue.id == row_id)
            .first()
        )
        if row is None:
            return None
        return {
            "id": row.id,
            "tenant_id": row.tenant_id,
            "invoice_id": row.invoice_id,
            "status": row.status,
            "attempts": row.attempts,
            "max_attempts": row.max_attempts,
            "next_retry_at": row.next_retry_at.isoformat() if row.next_retry_at else None,
            "last_attempt_at": row.last_attempt_at.isoformat() if row.last_attempt_at else None,
            "last_error_code": row.last_error_code,
            "last_error_message": row.last_error_message,
            "cleared_uuid": row.cleared_uuid,
            "cleared_at": row.cleared_at.isoformat() if row.cleared_at else None,
            "created_at": row.created_at.isoformat(),
            "updated_at": row.updated_at.isoformat() if row.updated_at else None,
        }
    finally:
        db.close()


def stats(tenant_id: Optional[str] = None) -> Dict[str, int]:
    """Return counts per status — feeds the ZATCA dashboard KPIs."""
    db = SessionLocal()
    try:
        q = db.query(ZatcaSubmissionQueue)
        if tenant_id is not None:
            q = q.filter(ZatcaSubmissionQueue.tenant_id == tenant_id)
        rows = q.all()
        out = {
            STATUS_DRAFT: 0,
            STATUS_PENDING: 0,
            STATUS_CLEARED: 0,
            STATUS_GIVEUP: 0,
        }
        for r in rows:
            out[r.status] = out.get(r.status, 0) + 1
        out["total"] = len(rows)
        return out
    finally:
        db.close()


def list_rows(
    status: Optional[str] = None,
    tenant_id: Optional[str] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    """List queue rows with optional status/tenant filter."""
    db = SessionLocal()
    try:
        q = db.query(ZatcaSubmissionQueue)
        if status is not None:
            q = q.filter(ZatcaSubmissionQueue.status == status)
        if tenant_id is not None:
            q = q.filter(ZatcaSubmissionQueue.tenant_id == tenant_id)
        rows = (
            q.order_by(ZatcaSubmissionQueue.updated_at.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": r.id,
                "invoice_id": r.invoice_id,
                "status": r.status,
                "attempts": r.attempts,
                "next_retry_at": r.next_retry_at.isoformat() if r.next_retry_at else None,
                "last_error_code": r.last_error_code,
                "updated_at": r.updated_at.isoformat() if r.updated_at else None,
            }
            for r in rows
        ]
    finally:
        db.close()
