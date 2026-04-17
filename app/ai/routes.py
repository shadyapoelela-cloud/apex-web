"""AI proactive route — POST /api/v1/ai/scan triggers all proactive
scans and returns the summary. Intended to be wired to a scheduler
(APScheduler / Celery / external cron) every 6 hours in production.

Admin-triggered manual invocation is also supported for debugging.
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Query

from app.ai.proactive import run_all_scans
from app.core.api_version import v1_prefix

router = APIRouter(prefix=v1_prefix("/ai"), tags=["AI Proactive"])


@router.post("/scan")
def trigger_scan(
    tenant_id: Optional[str] = Query(None, description="Filter to one tenant"),
    emit_activity: bool = Query(
        True, description="Emit activity_log rows for each finding"
    ),
):
    """Run every registered proactive scan and return the summary.

    Returns
    -------
    {
      "success": True,
      "data": {
        "scans_run": int,
        "total_findings": int,
        "by_severity": { "info": 0, "warning": 0, "error": 0 },
        "by_scan":     { "<scan_name>": N, ... },
        "findings":    [ { scan, entity_type, entity_id, severity, summary, details }, ... ]
      }
    }
    """
    summary = run_all_scans(tenant_id=tenant_id, emit_activity=emit_activity)
    return {"success": True, "data": summary}
