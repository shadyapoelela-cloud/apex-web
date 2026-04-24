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

Scans:
  • overdue_receivables      invoices > N days past due
  • dead_zatca_submissions   ZATCA retries that exhausted backoff
  • stale_sync_ops           PWA sync ops queued > 24h
  • cash_runway_warning      projected cash runway below threshold

More scans can be added as (name, fn) pairs in SCANS; each fn takes
an optional tenant_id filter and returns List[Finding].
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
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


def cash_runway_warning(
    *,
    min_runway_days: int = 30,
    tenant_id: Optional[str] = None,
) -> list[Finding]:
    """Project cash balance forward. Warn if runway drops below the threshold.

    Uses the moving-average forecaster we wired into the Copilot tools —
    same model, same numbers, so the sidebar Q&A and the proactive
    warning agree. The agent will later produce a natural-language
    explanation; here we only emit the structured finding.

    The warning fires once per scan per tenant — log-deduping is the
    responsibility of activity_log. Severity climbs as runway tightens:

      runway <= 7 days  → error    (آخر فرصة للتصرف)
      runway <= 30 days → warning
      otherwise         → no finding emitted
    """
    try:
        from app.services.copilot_tools_ledger import forecast_metric, aggregate_metric
    except Exception as e:
        logger.debug("cash_runway_warning: ledger helpers unavailable (%s)", e)
        return []

    # Forecast 6 months ahead so we can detect mid-horizon runway breaches,
    # not just next month.
    try:
        current = aggregate_metric("cash_balance", "this_month", tenant_id=tenant_id)
        fc = forecast_metric("cash_balance", horizon_months=6, tenant_id=tenant_id)
    except Exception as e:
        logger.debug("cash_runway_warning: forecast failed (%s)", e)
        return []

    current_balance = float(current.get("value") or 0)
    projected = fc.get("projected_values") or []

    # If we have no signal (all zeros, empty series), stay silent — we'd
    # rather under-alert than cry wolf on a fresh tenant.
    if current_balance <= 0 or not projected or all(v == 0 for v in projected):
        return []

    # Estimate burn from the forecast delta over the horizon.
    horizon_months = len(projected)
    ending = float(projected[-1])
    total_burn = current_balance - ending
    if total_burn <= 0:
        # Cash is growing or flat — nothing to warn about.
        return []

    monthly_burn = total_burn / horizon_months
    if monthly_burn <= 0:
        return []

    runway_days = int((current_balance / monthly_burn) * 30)

    # Build a deterministic entity id so re-running the scan within the
    # same day doesn't generate a dupe row in activity_log.
    entity_id = f"cash-runway-{date.today().isoformat()}"

    if runway_days <= 7:
        severity = "error"
    elif runway_days <= min_runway_days:
        severity = "warning"
    else:
        return []

    summary = (
        f"مدى السيولة المتوقع: ~{runway_days} يوم "
        f"(برصيد حالي {current_balance:,.0f} ريال "
        f"ومتوسط حرق {monthly_burn:,.0f} ريال/شهر)"
    )

    # Push a notification to the tenant's admin channel so the warning
    # surfaces in the UI bell + WebSocket feed — not just in activity_log.
    # Failures are swallowed (notify() is best-effort by design).
    try:
        import asyncio as _asyncio
        from app.core.notifications_bridge import notify as _notify

        async def _push() -> None:
            await _notify(
                user_id=tenant_id or "system",  # when tenant_id is set, this
                                                # fans out to owners in notify()
                kind="cash_runway",
                title="تحذير: انخفاض متوقع في السيولة",
                body=summary + "\nراجع قائمة المقبوضات والمدفوعات الكبيرة القادمة.",
                tenant_id=tenant_id,
                entity_type="cash_forecast",
                entity_id=entity_id,
                severity=severity,
            )

        _asyncio.new_event_loop().run_until_complete(_push())
    except Exception as _e:
        logger.debug("cash_runway notification skipped: %s", _e)

    return [
        Finding(
            scan="cash_runway_warning",
            entity_type="cash_forecast",
            entity_id=entity_id,
            severity=severity,
            summary=summary,
            details={
                "current_balance": round(current_balance, 2),
                "monthly_burn": round(monthly_burn, 2),
                "runway_days": runway_days,
                "horizon_months": horizon_months,
                "projected_values": projected,
                "confidence_interval": fc.get("confidence_interval", {}),
                "method": fc.get("method", "moving_average"),
            },
        )
    ]


# ── Runner ────────────────────────────────────────────────


SCANS: list[tuple[str, Callable[..., list[Finding]]]] = [
    ("overdue_receivables", overdue_receivables),
    ("dead_zatca_submissions", dead_zatca_submissions),
    ("stale_sync_ops", stale_sync_ops),
    ("cash_runway_warning", cash_runway_warning),
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
