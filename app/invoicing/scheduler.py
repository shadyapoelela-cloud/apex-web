"""Recurring-invoice scheduler (INV-1, Sprint 18 — Phase 5).

Deliberately minimal: no apscheduler dependency, no background
threads. The recommended deployment pattern is a Render-side cron
job that hits `POST /api/v1/invoicing/admin/run-due-now` daily at
02:00. We provide:

    schedule_daily_runner()    — placeholder hook called from
                                  app.main._run_startup. Currently
                                  a no-op + log line. When we adopt
                                  apscheduler (INV-1.3), this is the
                                  one function to grow.

    run_due_recurring(db)      — programmatic single-shot runner. Used
                                  by tests + the admin endpoint.
                                  Reentrant — safe to call from
                                  multiple workers; each due template
                                  is processed once because
                                  run_recurring_template advances
                                  next_run_date inside the same
                                  transaction.

The admin endpoint at `POST /api/v1/invoicing/admin/run-due-now`
already exposes this — see `app/invoicing/router.py`. This module
adds the function exactly once so future scheduler bindings have a
canonical entry point.
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.invoicing import service as inv_service
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)


def run_due_recurring(
    db: Optional[Session] = None,
    *,
    as_of: Optional[date] = None,
    user_id: Optional[str] = "scheduler",
) -> dict[str, Any]:
    """Run every active template whose `next_run_date <= as_of`.

    Returns a summary dict — caller can log it or expose it via the
    admin endpoint.
    """
    own_db = False
    if db is None:
        db = SessionLocal()
        own_db = True
    try:
        templates = inv_service.list_due_recurring(db, as_of=as_of)
        results: list[dict[str, Any]] = []
        for t in templates:
            try:
                result = inv_service.run_recurring_template(
                    db, t.id, user_id=user_id, force_today=True
                )
                results.append({"template_id": t.id, **result})
            except Exception as e:  # noqa: BLE001
                logger.exception("run_due_recurring failed for %s", t.id)
                results.append({"template_id": t.id, "error": str(e)})
        return {"ran": len(results), "results": results}
    finally:
        if own_db:
            db.close()


def schedule_daily_runner() -> None:
    """Placeholder hook for app.main._run_startup.

    The Render-side cron pattern is preferred — see app/invoicing/README.md.
    When we adopt apscheduler (INV-1.3), grow this function to register
    a `cron(hour=2, minute=0)` job that calls `run_due_recurring()`.

    For now: log that the scheduler is in cron-driven mode + return.
    """
    logger.info(
        "Invoicing scheduler: cron-driven mode active. "
        "Trigger via POST /api/v1/invoicing/admin/run-due-now."
    )


__all__ = ["run_due_recurring", "schedule_daily_runner"]
