"""
APEX — Live Anomaly Detection Service
======================================
Bridges the existing pure-function anomaly detector
(app/core/anomaly_detector.py) to the live event stream + Workflow
Rules Engine.

How it works:
- Listener registers on event_bus for `je.posted`, `payment.received`,
  `bill.approved` (configurable). Each fired event records the
  transaction in an in-memory tenant-scoped ring buffer.
- A scheduled scan (via /admin/anomaly/scan or cron) walks each tenant's
  buffer + DB-recent transactions, runs `scan_all()`, and for each
  finding above MIN_SEVERITY emits `anomaly.detected` on the bus.
- Workflow rules can listen for anomaly.detected and react:
    e.g. "if anomaly.severity >= 'high', notify CFO via Slack".

Why we don't run scan_all on every single event:
- It's O(N²) on the buffer (duplicate detection compares pairs)
- Most useful anomalies are pattern-based (cluster of duplicates, spike
  vs. category baseline) — the buffer needs to be populated first
- Hourly/daily batch is the standard pattern for fraud-style detection

Reference: Layer 7.7 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import logging
import threading
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import emit, register_listener

try:
    from app.core.anomaly_detector import (
        AnomalyFinding,
        scan_all,
    )
except Exception as e:  # noqa: BLE001
    logging.getLogger(__name__).warning(
        "Anomaly detector module unavailable: %s — anomaly_live runs in no-op mode",
        e,
    )
    AnomalyFinding = None  # type: ignore[misc]
    scan_all = None  # type: ignore[assignment]

logger = logging.getLogger(__name__)


# ── In-memory rolling buffer per tenant ──────────────────────────


_BUFFER_CAP = 500  # transactions per tenant
_buffers: dict[str, deque[dict[str, Any]]] = defaultdict(lambda: deque(maxlen=_BUFFER_CAP))
_lock = threading.RLock()


# Events we monitor for transactions worth scanning.
_MONITORED = {"je.posted", "payment.received", "bill.approved", "invoice.posted"}

# Severity threshold below which anomalies are NOT emitted as events
# (still returned in the scan result for audit). Values: low | medium | high | critical
_MIN_EMIT_SEVERITY = "medium"
_SEVERITY_RANK = {"low": 0, "medium": 1, "high": 2, "critical": 3}


def _txn_from_payload(event_name: str, payload: dict) -> Optional[dict]:
    """Map various event payloads to the {id, vendor, amount, date} shape."""
    # Best-effort field extraction; missing fields just drop the row.
    txn_id = (
        payload.get("je_id")
        or payload.get("payment_id")
        or payload.get("bill_id")
        or payload.get("invoice_id")
    )
    if not txn_id:
        return None

    amount = (
        payload.get("total_amount")
        or payload.get("amount")
        or payload.get("total")
    )
    if amount is None:
        return None

    return {
        "id": str(txn_id),
        "vendor": payload.get("vendor_name") or payload.get("payee") or payload.get("customer_name"),
        "vendor_id": payload.get("vendor_id") or payload.get("customer_id"),
        "amount": amount,
        "date": (
            payload.get("posting_date")
            or payload.get("issued_at")
            or payload.get("date")
            or datetime.now(timezone.utc).date().isoformat()
        ),
        "created_at": datetime.now(timezone.utc),
        "description": payload.get("description"),
        "category": payload.get("category"),
        "_event": event_name,
    }


@register_listener("je.posted")
@register_listener("payment.received")
@register_listener("bill.approved")
@register_listener("invoice.posted")
def _bus_listener(event_name: str, payload: dict) -> None:
    """Capture transactions into the tenant buffer for later batch scan."""
    if event_name not in _MONITORED:
        return
    tenant_id = payload.get("tenant_id") or "_unknown"
    txn = _txn_from_payload(event_name, payload)
    if not txn:
        return
    with _lock:
        _buffers[tenant_id].append(txn)


# ── Scan API ────────────────────────────────────────────────────


def buffer_size(tenant_id: Optional[str] = None) -> int:
    with _lock:
        if tenant_id:
            return len(_buffers.get(tenant_id, []))
        return sum(len(b) for b in _buffers.values())


def get_buffer(tenant_id: str) -> list[dict]:
    with _lock:
        return list(_buffers.get(tenant_id, []))


def clear_buffer(tenant_id: Optional[str] = None) -> None:
    with _lock:
        if tenant_id:
            _buffers.pop(tenant_id, None)
        else:
            _buffers.clear()


def scan_tenant(tenant_id: str, *, emit_events: bool = True) -> dict:
    """Run anomaly detection across the tenant's recent buffer.

    Returns the raw findings list (dicts) and a count by severity.
    Emits `anomaly.detected` for findings >= MIN_EMIT_SEVERITY when
    `emit_events=True`.
    """
    if scan_all is None:
        return {"ok": False, "error": "anomaly_detector_unavailable"}

    txns = get_buffer(tenant_id)
    if not txns:
        return {"ok": True, "tenant_id": tenant_id, "findings": [], "by_severity": {}, "txn_count": 0}

    try:
        findings: list[AnomalyFinding] = scan_all(txns)
    except Exception as e:  # noqa: BLE001
        logger.exception("scan_all failed for tenant %s: %s", tenant_id, e)
        return {"ok": False, "error": str(e)}

    by_severity: dict[str, int] = defaultdict(int)
    serialized: list[dict] = []
    min_rank = _SEVERITY_RANK.get(_MIN_EMIT_SEVERITY, 1)

    for f in findings:
        sev = getattr(f, "severity", "low")
        by_severity[sev] += 1
        d = {
            "type": getattr(f, "type", ""),
            "severity": sev,
            "message_ar": getattr(f, "message_ar", ""),
            "transaction_ids": list(getattr(f, "transaction_ids", []) or []),
            "metadata": getattr(f, "metadata", {}) or {},
        }
        serialized.append(d)
        if emit_events and _SEVERITY_RANK.get(sev, 0) >= min_rank:
            emit(
                "anomaly.detected",
                {
                    "tenant_id": tenant_id,
                    "type": d["type"],
                    "severity": sev,
                    "message_ar": d["message_ar"],
                    "transaction_ids": d["transaction_ids"],
                    "metadata": d["metadata"],
                },
                source="anomaly_live",
            )

    return {
        "ok": True,
        "tenant_id": tenant_id,
        "txn_count": len(txns),
        "findings": serialized,
        "by_severity": dict(by_severity),
        "scanned_at": datetime.now(timezone.utc).isoformat(),
    }


def scan_all_tenants(*, emit_events: bool = True) -> dict:
    """Scan every tenant whose buffer is non-empty. Cron entry point."""
    results: list[dict] = []
    with _lock:
        tenants = list(_buffers.keys())
    for t in tenants:
        results.append(scan_tenant(t, emit_events=emit_events))
    total = sum(r.get("txn_count", 0) for r in results if r.get("ok"))
    total_findings = sum(len(r.get("findings", [])) for r in results if r.get("ok"))
    return {
        "ok": True,
        "tenants_scanned": len(results),
        "total_txns": total,
        "total_findings": total_findings,
        "results": results,
    }
