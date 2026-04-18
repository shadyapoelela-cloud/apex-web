"""Notification bridge — publish to both DB (Phase 10) AND WebSocket.

Phase 10 persists notifications. WebSocket hub (app.core.websocket_hub)
delivers them in real-time. This module ties them together so feature
code doesn't have to know about both.

Usage:
    from app.core.notifications_bridge import notify

    await notify(
        user_id="u-123",
        kind="invoice_paid",
        title="تم استلام الدفعة",
        body="فاتورة INV-001 دُفعت بالكامل.",
        entity_type="invoice", entity_id="i-1",
    )

One call →
  1. Writes a row to Phase 10's notifications table (best-effort).
  2. Pushes a WebSocket event to user:{user_id}.
  3. (Optional) triggers WhatsApp / email delivery via handlers.

All failures are swallowed — notifying a user never blocks the caller.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


async def notify(
    *,
    user_id: str,
    kind: str,
    title: str,
    body: str,
    tenant_id: Optional[str] = None,
    entity_type: Optional[str] = None,
    entity_id: Optional[str] = None,
    severity: str = "info",
) -> dict:
    """Fire a notification to a user via all configured channels.

    Returns a dict with {persisted, websocket_delivered}.
    """
    result = {"persisted": False, "websocket_delivered": 0}

    # 1. Persist to Phase 10 if available.
    try:
        from app.phase10.models.phase10_models import Notification, SessionLocal as _NSL

        db = _NSL()
        try:
            notif = Notification(
                id=str(uuid.uuid4()),
                user_id=user_id,
                type=kind,
                title=title,
                body=body,
                severity=severity,
                created_at=datetime.now(timezone.utc),
            )
            db.add(notif)
            db.commit()
            result["persisted"] = True
        except Exception as e:
            logger.warning("notifications persist failed: %s", e)
            db.rollback()
        finally:
            db.close()
    except ImportError:
        pass
    except Exception as e:
        logger.warning("Phase 10 notifications unavailable: %s", e)

    # 2. Push over WebSocket.
    try:
        from app.core.websocket_hub import publish_to_user

        delivered = await publish_to_user(user_id, {
            "type": "notification",
            "kind": kind,
            "title": title,
            "body": body,
            "severity": severity,
            "entity_type": entity_type,
            "entity_id": entity_id,
        })
        result["websocket_delivered"] = delivered
    except Exception as e:
        logger.warning("ws push failed: %s", e)

    return result


def notify_sync(**kwargs) -> dict:
    """Synchronous wrapper — use from non-async code paths.

    Best-effort: if no running loop is available, runs the coroutine
    to completion synchronously.
    """
    import asyncio

    coro = notify(**kwargs)
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        # No running loop → synchronous run
        return asyncio.run(coro)
    # A loop exists — schedule on it (fire-and-forget) and return partial
    task = loop.create_task(coro)
    return {"persisted": False, "websocket_delivered": 0, "_task_scheduled": True}
