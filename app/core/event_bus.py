"""
APEX — In-Process Event Bus
============================
Lightweight synchronous pub/sub. Code emits events; the Workflow Rules
Engine + ad-hoc listeners receive them and react.

Why in-process (not Kafka/RabbitMQ for v1):
- 10x simpler, no infra
- All consumers are within the same process today
- Can swap to a real broker later by changing this module's emit() impl

Usage:
    from app.core.event_bus import emit
    emit("invoice.created", {"invoice_id": "...", "tenant_id": "...", "total": 100})

Listeners register at startup:
    from app.core.event_bus import register_listener
    @register_listener("invoice.*")  # wildcard suffix supported
    def my_handler(event_name: str, payload: dict): ...

Errors in one listener never block others — they're logged and swallowed.

Reference: foundation for Wave 3 Workflow Engine
(architecture/diagrams/02-target-state.md §6).
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timezone
from threading import RLock
from typing import Any

from app.core.event_registry import is_known_event

logger = logging.getLogger(__name__)

EventHandler = Callable[[str, dict[str, Any]], None]

# pattern -> list of handlers
_LISTENERS: dict[str, list[EventHandler]] = {}
_LOCK = RLock()

# Optional: in-memory buffer of recent events for /admin/events/recent
_RECENT_BUFFER: list[dict[str, Any]] = []
_RECENT_CAP = 200


def register_listener(pattern: str) -> Callable[[EventHandler], EventHandler]:
    """Decorator: register a handler for events matching `pattern`.

    Patterns:
        "invoice.created"     — exact match
        "invoice.*"            — any event in the invoice namespace
        "*"                    — every event (use sparingly)
    """

    def decorator(fn: EventHandler) -> EventHandler:
        with _LOCK:
            _LISTENERS.setdefault(pattern, []).append(fn)
        logger.debug("Registered listener %s for pattern %s", fn.__name__, pattern)
        return fn

    return decorator


def _matches(pattern: str, name: str) -> bool:
    if pattern == "*":
        return True
    if pattern == name:
        return True
    if pattern.endswith(".*"):
        return name.startswith(pattern[:-2] + ".")
    return False


def emit(name: str, payload: dict[str, Any] | None = None, *, source: str = "app") -> None:
    """Emit an event by name. Calls every matching listener synchronously.

    Unknown event names are logged as a warning but still delivered (callers
    might be using a custom event during development).
    """
    payload = dict(payload or {})
    if not is_known_event(name):
        logger.warning("Emitting UNREGISTERED event: %s — consider adding to event_registry.py", name)

    record = {
        "name": name,
        "payload": payload,
        "source": source,
        "ts": datetime.now(timezone.utc).isoformat(),
    }

    # Buffer for /admin/events/recent.
    with _LOCK:
        _RECENT_BUFFER.append(record)
        if len(_RECENT_BUFFER) > _RECENT_CAP:
            del _RECENT_BUFFER[: len(_RECENT_BUFFER) - _RECENT_CAP]

        # Snapshot listeners under the lock so we can iterate without holding it.
        handlers: list[EventHandler] = []
        for pat, fns in _LISTENERS.items():
            if _matches(pat, name):
                handlers.extend(fns)

    for h in handlers:
        try:
            h(name, payload)
        except Exception as e:  # noqa: BLE001 — never let one handler kill the pipeline
            logger.exception(
                "Event handler %s failed for event %s: %s", h.__name__, name, e
            )


def recent_events(limit: int = 50) -> list[dict[str, Any]]:
    """Return up to `limit` most-recent emitted events (newest last)."""
    with _LOCK:
        return list(_RECENT_BUFFER[-limit:])


def clear_listeners() -> None:
    """Test helper — reset all registered handlers."""
    with _LOCK:
        _LISTENERS.clear()


def listener_count() -> int:
    with _LOCK:
        return sum(len(fns) for fns in _LISTENERS.values())
