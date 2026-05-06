"""Cross-cutting event hooks for the dashboard.

Wires the existing event_bus events into:
  1. Per-widget cache invalidation.
  2. SSE push notifications (handled by router.py via a queue).

Importing this module has the side-effect of registering the listeners,
so it should be imported once at app startup (done by app.dashboard.router
on first request).
"""

from __future__ import annotations

import asyncio
import logging
import queue as _queue
import threading
from typing import Any

from app.core.event_bus import register_listener
from app.dashboard.service import invalidate_codes

logger = logging.getLogger(__name__)


# ── Event → widget code map ───────────────────────────────


# Each event clears the widgets whose cached payload becomes stale.
EVENT_INVALIDATIONS: dict[str, list[str]] = {
    "invoice.posted": [
        "kpi.cash_balance",
        "kpi.ar_outstanding",
        "kpi.net_income_mtd",
        "chart.revenue_30d",
        "list.recent_invoices",
        "list.top_customers",
    ],
    "invoice.created": [
        "list.recent_invoices",
        "kpi.ar_outstanding",
    ],
    "payment.received": [
        "kpi.cash_balance",
        "kpi.ar_outstanding",
        "chart.cash_flow_90d",
    ],
    "payment.posted": [
        "kpi.cash_balance",
        "kpi.ap_due_7d",
        "chart.cash_flow_90d",
    ],
    "bill.posted": [
        "kpi.ap_due_7d",
        "kpi.cash_balance",
    ],
    "je.posted": [
        "kpi.cash_balance",
        "kpi.net_income_mtd",
    ],
    "approval.created": [
        "list.pending_approvals",
    ],
    "approval.decided": [
        "list.pending_approvals",
    ],
    "compliance.health.changed": [
        "widget.compliance_health",
    ],
}


# ── SSE bridge ────────────────────────────────────────────


class _StreamHub:
    """In-memory pub/sub for the SSE endpoint.

    Each connected client registers a `queue.Queue`; emit() fan-outs
    a small JSON record to every queue. SSE handler drains its own
    queue and writes to the wire.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._subscribers: list[_queue.Queue[dict[str, Any]]] = []

    def subscribe(self) -> _queue.Queue[dict[str, Any]]:
        q: _queue.Queue[dict[str, Any]] = _queue.Queue(maxsize=256)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q: _queue.Queue[dict[str, Any]]) -> None:
        with self._lock:
            try:
                self._subscribers.remove(q)
            except ValueError:
                pass

    def publish(self, record: dict[str, Any]) -> None:
        with self._lock:
            subs = list(self._subscribers)
        for q in subs:
            try:
                q.put_nowait(record)
            except _queue.Full:
                # Drop the slowest subscriber's oldest message.
                try:
                    q.get_nowait()
                    q.put_nowait(record)
                except Exception:  # noqa: BLE001
                    pass


hub = _StreamHub()


# ── Wiring ────────────────────────────────────────────────


_REGISTERED = False
_REG_LOCK = threading.Lock()


def register_dashboard_listeners() -> None:
    """Idempotent — registers each event listener exactly once.

    Called from app.dashboard.router at module import time so the side
    effect happens regardless of which test pulls in what.
    """
    global _REGISTERED
    with _REG_LOCK:
        if _REGISTERED:
            return
        _REGISTERED = True

    @register_listener("*")
    def _on_event(name: str, payload: dict[str, Any]) -> None:
        codes = EVENT_INVALIDATIONS.get(name)
        if not codes:
            return
        try:
            invalidate_codes(codes, ctx=payload or {})
        except Exception as e:  # noqa: BLE001
            logger.warning("dashboard invalidate failed for %s: %s", name, e)
        # Push an SSE record so connected clients can refresh.
        hub.publish({
            "type": "invalidate",
            "event": name,
            "widget_codes": codes,
            "payload": payload or {},
        })


def push_widget_update(widget_code: str, payload: dict[str, Any]) -> None:
    """Manually pump a widget update onto the SSE stream — for code that
    knows it has new data without going through event_bus."""
    hub.publish({
        "type": "update",
        "widget_code": widget_code,
        "payload": payload,
    })


__all__ = ["EVENT_INVALIDATIONS", "hub", "register_dashboard_listeners", "push_widget_update"]
