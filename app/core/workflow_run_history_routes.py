"""APEX — Workflow Run History admin routes.

All endpoints admin-secret-gated.

    GET    /admin/workflow/runs                — list w/ filters
    GET    /admin/workflow/runs/{run_id}       — single run detail
    GET    /admin/workflow/runs/stats          — counts + top rules/events
    DELETE /admin/workflow/runs                — clear all (or one rule)

Wave 1O Phase VV.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

from pydantic import BaseModel, Field
from app.core.workflow_run_history import clear, get_run, list_runs, stats

router = APIRouter(prefix="/admin/workflow/runs", tags=["admin", "workflow-runs"])

_ADMIN_SECRET = os.environ.get("ADMIN_SECRET")
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _verify_admin(x: Optional[str]) -> None:
    import secrets

    if not _ADMIN_SECRET:
        if _IS_PRODUCTION:
            raise HTTPException(500, "ADMIN_SECRET not configured on server")
        return
    if not x or not secrets.compare_digest(x, _ADMIN_SECRET):
        raise HTTPException(403, "Invalid admin secret")


@router.get("")
def list_route(
    rule_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    event_name: Optional[str] = None,
    status: Optional[str] = Query(None, pattern="^(success|partial|failed)$"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    rows = list_runs(
        rule_id=rule_id,
        tenant_id=tenant_id,
        event_name=event_name,
        status=status,
        limit=limit,
        offset=offset,
    )
    return {"success": True, "runs": rows, "count": len(rows)}


@router.get("/stats")
def stats_route(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    return {"success": True, **stats()}


@router.get("/{run_id}")
def get_route(
    run_id: str,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    r = get_run(run_id)
    if not r:
        raise HTTPException(404, "run not found")
    return {"success": True, "run": r}


@router.delete("")
def clear_route(
    rule_id: Optional[str] = Query(None),
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    _verify_admin(x_admin_secret)
    n = clear(rule_id=rule_id)
    return {"success": True, "removed": n}


class ReplayRequest(BaseModel):
    payload_override: Optional[dict] = None
    only_this_rule: bool = Field(
        default=True,
        description=(
            "If True, replay only the original rule (not all rules listening "
            "for the event). Set False to re-trigger every matching rule."
        ),
    )


@router.post("/{run_id}/replay")
def replay_run(
    run_id: str,
    payload: Optional[ReplayRequest] = None,
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
):
    """Re-execute a past run.

    Wave 1S Phase ZZ. Two replay modes:
      • only_this_rule=True (default) — re-runs ONLY the rule that
        originally fired, with the captured (or overridden) payload.
        Most useful for debugging a specific rule without side-effects
        on other listeners.
      • only_this_rule=False — emits the event on the bus, so every
        rule listening for it fires (same as live event arrival).
        Useful for end-to-end replay of an incident.

    Returns the new run_id (when only_this_rule=True) or the count of
    matched rules (when only_this_rule=False).
    """
    _verify_admin(x_admin_secret)
    body = payload or ReplayRequest()
    original = get_run(run_id)
    if not original:
        raise HTTPException(404, "run not found")
    effective_payload = body.payload_override or original.get("payload") or {}
    event_name = original.get("event_name") or ""
    if not event_name:
        raise HTTPException(400, "original run has no event_name")
    if body.only_this_rule:
        # Targeted replay: load the rule, run it directly without going
        # through the bus, recording a new run.
        try:
            from app.core.workflow_engine import (
                evaluate_conditions,
                execute_action,
                get_rule,
            )
            from app.core.workflow_run_history import record_run
        except Exception as e:
            raise HTTPException(500, f"workflow engine unavailable: {e}")
        rule = get_rule(original["rule_id"])
        if not rule:
            raise HTTPException(404, "original rule no longer exists; use only_this_rule=false")
        # Evaluate conditions against the (possibly new) payload.
        conds_ok = evaluate_conditions(rule, effective_payload)
        if not conds_ok:
            return {
                "success": True,
                "mode": "targeted",
                "ran": False,
                "reason": "conditions_did_not_match_with_new_payload",
            }
        import time as _t
        t0 = _t.perf_counter()
        action_results = [execute_action(a, effective_payload, rule) for a in rule.actions]
        duration_ms = int((_t.perf_counter() - t0) * 1000)
        new_id = record_run(
            rule_id=rule.id,
            rule_name=f"[REPLAY of {run_id[:8]}] {rule.name}",
            event_name=event_name,
            payload=effective_payload,
            action_results=action_results,
            tenant_id=rule.tenant_id,
            duration_ms=duration_ms,
        )
        return {
            "success": True,
            "mode": "targeted",
            "ran": True,
            "new_run_id": new_id,
            "actions_executed": len(action_results),
        }
    # Bus-replay: emit on the bus, all listeners fire.
    try:
        from app.core.event_bus import emit
    except Exception as e:
        raise HTTPException(500, f"event bus unavailable: {e}")
    emit(event_name, effective_payload, source=f"replay:{run_id[:8]}")
    return {
        "success": True,
        "mode": "bus_replay",
        "event": event_name,
    }
