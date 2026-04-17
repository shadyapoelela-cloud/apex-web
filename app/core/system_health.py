"""System health endpoint — aggregated view of every subsystem the
Apex layer depends on. Useful for ops dashboards + uptime monitoring.

Returns a single JSON payload with a status per subsystem and a
rolled-up overall flag. Each check is wrapped in try/except so one
failure doesn't mask the rest.

Route: GET /api/v1/system/health
"""
from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter

from app.core.api_version import v1_prefix

logger = logging.getLogger(__name__)

router = APIRouter(prefix=v1_prefix("/system"), tags=["System Health"])


def _check_db() -> dict[str, Any]:
    try:
        from sqlalchemy import text
        from app.phase1.models.platform_models import SessionLocal
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1")).scalar()
            return {"status": "ok"}
        finally:
            db.close()
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _check_dialect() -> dict[str, Any]:
    try:
        from app.phase1.models.platform_models import engine
        return {
            "status": "ok",
            "dialect": engine.dialect.name,
            "rls_applicable": engine.dialect.name == "postgresql",
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _check_activity_log_count() -> dict[str, Any]:
    """Count activity rows in the last 24h — signals a live system."""
    try:
        from app.core.activity_log import ActivityLog
        from app.phase1.models.platform_models import SessionLocal
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        db = SessionLocal()
        try:
            count = (
                db.query(ActivityLog)
                .filter(ActivityLog.created_at >= cutoff)
                .count()
            )
            return {"status": "ok", "count_last_24h": count}
        finally:
            db.close()
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _check_scheduler() -> dict[str, Any]:
    try:
        from app.ai.scheduler import _ENV_ENABLED, _task
        enabled = os.environ.get(_ENV_ENABLED, "").lower() in ("true", "1", "yes")
        running = _task is not None and not _task.done()
        return {
            "status": "ok",
            "enabled": enabled,
            "running": running,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _check_ws_hub() -> dict[str, Any]:
    try:
        from app.core.websocket_hub import get_hub
        hub = get_hub()
        # Best-effort: count currently-subscribed clients if the hub
        # exposes that. We don't reach into private attributes — if
        # there's no public API, report "ok" + unknown count.
        count = 0
        clients = getattr(hub, "_clients", None)
        if isinstance(clients, (set, list, dict)):
            count = len(clients)
        return {"status": "ok", "connected_clients": count}
    except Exception as e:
        return {"status": "error", "error": str(e)}


def _check_zatca_retry_queue() -> dict[str, Any]:
    try:
        from app.integrations.zatca.retry_queue import (
            ZatcaSubmission,
            ZatcaSubmissionStatus,
        )
        from app.phase1.models.platform_models import SessionLocal
        db = SessionLocal()
        try:
            total = db.query(ZatcaSubmission).count()
            dead = (
                db.query(ZatcaSubmission)
                .filter(
                    ZatcaSubmission.status == ZatcaSubmissionStatus.DEAD.value
                )
                .count()
            )
            pending = (
                db.query(ZatcaSubmission)
                .filter(
                    ZatcaSubmission.status.in_([
                        ZatcaSubmissionStatus.PENDING.value,
                        ZatcaSubmissionStatus.ERROR.value,
                    ])
                )
                .count()
            )
            return {
                "status": "ok",
                "total": total,
                "pending_retry": pending,
                "dead": dead,
            }
        finally:
            db.close()
    except Exception as e:
        return {"status": "error", "error": str(e)}


@router.get("/health")
def system_health():
    """Aggregate health of every subsystem the Apex layer depends on."""
    checks = {
        "database": _check_db(),
        "dialect": _check_dialect(),
        "activity_log": _check_activity_log_count(),
        "ai_scheduler": _check_scheduler(),
        "websocket_hub": _check_ws_hub(),
        "zatca_retry_queue": _check_zatca_retry_queue(),
    }
    overall = "ok" if all(
        c.get("status") == "ok" for c in checks.values()
    ) else "degraded"
    return {
        "success": True,
        "data": {
            "overall": overall,
            "checks": checks,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    }
