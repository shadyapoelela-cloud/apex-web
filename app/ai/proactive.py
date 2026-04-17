"""Proactive AI scans — background jobs that surface anomalies without
waiting for the user to ask.

Each scan is pure: run it, get back a list of Findings, let the
caller decide what to do (log to activity_log, email, WhatsApp, etc).
The default dispatch writes an ActivityLog row per finding so the
Chatter panels + WebSocket push pick them up for free.

Intended cadence: once every 6 hours from APScheduler or a cron job.
Idempotent by design — re-running within the same window won't
double-log the same finding because log_activity is append-only and
dashboards de-dupe on (entity_type, entity_id, severity, day) anyway.

Scans (2026-04-17):
  • overdue_receivables      invoices > N days past due
  • dead_zatca_submissions   ZATCA retries that exhausted backoff
  • stale_sync_ops           PWA sync ops queued > 24h

More scans can be added as (name, fn) pairs in SCANS; each fn takes
an optional tenant_id filter and returns List[Finding].
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional

from app.core.activity_log import log_activity

logger = logging.getLogger(__name__)


# ── Finding value type ────────────────────────────────────


@dataclass
class Finding:
    """One anomaly the scanner found. Emits as an activity_log row."""
    scan: str
    entity_type: str
    entity_id: str
    severity: str = "info"     # 'info' | 'warning' | 'error'
    summary: str = ""
    details: dict = field(default_factory=dict)


# ── Scans ────────────────────────────────────────────────


def overdue_receivables(
    *,
    days_overdue: int = 7,
    tenant_id: Optional[str] = None,
) -> list[Finding]:
    """Invoices past due_date by more than [days_overdue].

    Joins the Phase 1 customer_invoices table if available; silently
    returns [] when the module isn't registered (tests / minimal env).
    """
    try:
        # Lazy import keeps this module light in test runners that
        # stub out the DB.
        from app.phase1.models.platform_models import SessionLocal
        from sqlalchemy import text
    except Exception:
        return []

    threshold = datetime.now(timezone.utc) - timedelta(days=days_overdue)
    results: list[Finding] = []
    db = SessionLocal()
    try:
        # Use a raw query — we don't want to hard-depend on a specific
        # Invoice model shape. Any table with an id + due_date +
        # status column named 'sent' | 'overdue' works.
        try:
            rows = db.execute(
                text(
                    "SELECT id, invoice_number, due_date, total, status "
                    "FROM customer_invoices "
                    "WHERE status IN ('sent','overdue') "
                    "  AND due_date < :threshold "
                    + ("AND tenant_id = :tenant " if tenant_id else "")
                    + " LIMIT 500"
                ),
                {"threshold": threshold, **({"tenant": tenant_id} if tenant_id else {})},
            ).fetchall()
        except Exception as e:
            logger.debug("overdue_receivables: table not present (%s)", e)
            return []
        for r in rows:
            results.append(Finding(
                scan="overdue_receivables",
                entity_type="invoice",
                entity_id=str(r[0]),
                severity="warning",
                summary=f"فاتورة {r[1]} متأخرة — استحقت {r[2]}",
                details={
                    "invoice_number": r[1],
                    "due_date": str(r[2]),
                    "total": float(r[3]) if r[3] is not None else None,
                    "status": r[4],
                },
            ))
    finally:
        db.close()
    return results


def dead_zatca_submissions(tenant_id: Optional[str] = None) -> list[Finding]:
    """ZATCA retry queue entries that exhausted all retries — need
    manual attention from an accountant or ops.
    """
    try:
        from app.integrations.zatca.retry_queue import (
            ZatcaSubmission,
            ZatcaSubmissionStatus,
        )
        from app.phase1.models.platform_models import SessionLocal
    except Exception:
        return []

    db = SessionLocal()
    try:
        q = db.query(ZatcaSubmission).filter(
            ZatcaSubmission.status == ZatcaSubmissionStatus.DEAD.value
        )
        if tenant_id:
            q = q.filter(ZatcaSubmission.tenant_id == tenant_id)
        rows = q.limit(200).all()
        return [
            Finding(
                scan="dead_zatca_submissions",
                entity_type="zatca_submission",
                entity_id=r.id,
                severity="error",
                summary=(
                    f"فاتورة {r.invoice_number} استنفدت محاولات ZATCA — "
                    f"{r.attempts} محاولات"
                ),
                details={
                    "invoice_number": r.invoice_number,
                    "attempts": r.attempts,
                    "last_http_status": r.last_http_status,
                    "last_error": r.last_error,
                },
            )
            for r in rows
        ]
    finally:
        db.close()


def stale_sync_ops(
    *,
    hours_stale: int = 24,
    tenant_id: Optional[str] = None,
) -> list[Finding]:
    """PWA sync operations still PENDING after [hours_stale]."""
    try:
        from app.core.offline_sync import SyncOperation, SyncOpStatus
        from app.phase1.models.platform_models import SessionLocal
    except Exception:
        return []

    threshold = datetime.now(timezone.utc) - timedelta(hours=hours_stale)
    db = SessionLocal()
    try:
        q = db.query(SyncOperation).filter(
            SyncOperation.status == SyncOpStatus.PENDING.value,
            SyncOperation.received_at < threshold,
        )
        if tenant_id:
            q = q.filter(SyncOperation.tenant_id == tenant_id)
        rows = q.limit(200).all()
        return [
            Finding(
                scan="stale_sync_ops",
                entity_type="sync_op",
                entity_id=r.op_id,
                severity="warning",
                summary=(
                    f"عملية مزامنة {r.entity_type} علّقت "
                    f"{hours_stale}+ ساعة"
                ),
                details={
                    "entity_type": r.entity_type,
                    "verb": r.verb,
                    "received_at": (
                        r.received_at.isoformat() if r.received_at else None
                    ),
                },
            )
            for r in rows
        ]
    finally:
        db.close()


# ── Runner ────────────────────────────────────────────────


SCANS: list[tuple[str, Callable[..., list[Finding]]]] = [
    ("overdue_receivables", overdue_receivables),
    ("dead_zatca_submissions", dead_zatca_submissions),
    ("stale_sync_ops", stale_sync_ops),
]


def run_all_scans(
    *,
    tenant_id: Optional[str] = None,
    emit_activity: bool = True,
) -> dict:
    """Run every registered scan. Returns a summary dict and (by
    default) logs each finding to activity_log so downstream Chatter
    + WebSocket consumers pick them up.
    """
    summary = {
        "scans_run": 0,
        "total_findings": 0,
        "by_severity": {"info": 0, "warning": 0, "error": 0},
        "by_scan": {},
        "findings": [],
    }
    for name, fn in SCANS:
        try:
            findings = fn(tenant_id=tenant_id) if tenant_id else fn()
        except TypeError:
            # Scan doesn't accept tenant_id kwarg
            findings = fn()
        except Exception as e:
            logger.warning("scan %s failed: %s", name, e)
            findings = []
        summary["scans_run"] += 1
        summary["by_scan"][name] = len(findings)
        for f in findings:
            summary["total_findings"] += 1
            summary["by_severity"][f.severity] = (
                summary["by_severity"].get(f.severity, 0) + 1
            )
            summary["findings"].append({
                "scan": f.scan,
                "entity_type": f.entity_type,
                "entity_id": f.entity_id,
                "severity": f.severity,
                "summary": f.summary,
                "details": f.details,
            })
            if emit_activity:
                try:
                    log_activity(
                        entity_type=f.entity_type,
                        entity_id=f.entity_id,
                        action=f"proactive.{f.scan}",
                        summary=f.summary,
                        details={**f.details, "severity": f.severity},
                    )
                except Exception as e:  # pragma: no cover
                    logger.debug("could not log finding: %s", e)
    return summary
