"""APEX — Workflow Run History.

Per-execution audit trail for the workflow engine. Until this module
the engine only kept `run_count`, `last_run_at`, `last_error` per rule
— enough to know "is this rule firing" but not enough to debug "why
did action #2 fail at 14:32 yesterday with this specific payload".

Records every rule match with:
    - rule_id + rule_name (denormalized for tombstone safety)
    - event_name (what fired)
    - payload snapshot
    - action_results: per-action ok/error/duration_ms/result_summary
    - status: success | partial | failed
    - duration_ms: total
    - started_at + ended_at (ISO UTC)

Storage: $APEX_DATA_DIR/workflow_runs.json — same JSON-as-DB pattern.
Bounded ring buffer with cap _MAX_RUNS (default 5000) to keep disk
under control. Newest-first ordering. Older runs drop silently.

Hook: workflow_engine.process_event calls `record_run()` after every
match (best-effort, swallows errors so audit logging never breaks live
event processing).

Wave 1O Phase VV. Layer 11 (Observability) of FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from collections import deque
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "WORKFLOW_RUNS_PATH",
    os.path.join(_DATA_DIR, "workflow_runs.json"),
)
_MAX_RUNS = int(os.environ.get("WORKFLOW_RUNS_MAX", "5000"))
_LOCK = threading.RLock()


@dataclass
class WorkflowRun:
    id: str
    rule_id: str
    rule_name: str
    event_name: str
    tenant_id: Optional[str] = None
    status: str = "success"  # success | partial | failed
    duration_ms: int = 0
    started_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    ended_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    payload: dict[str, Any] = field(default_factory=dict)
    action_results: list[dict] = field(default_factory=list)
    error_summary: Optional[str] = None


# Newest-first deque so list_runs() returns latest without sorting.
_RUNS: deque[WorkflowRun] = deque(maxlen=_MAX_RUNS)


def _load() -> None:
    global _RUNS
    with _LOCK:
        if not os.path.exists(_PATH):
            _RUNS = deque(maxlen=_MAX_RUNS)
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            entries = raw.get("runs", [])
            new = deque(maxlen=_MAX_RUNS)
            for e in entries:
                new.append(WorkflowRun(**e))
            _RUNS = new
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load workflow run history: %s", e)
            _RUNS = deque(maxlen=_MAX_RUNS)


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "runs": [asdict(r) for r in _RUNS],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to save workflow runs: %s", e)


_load()


# ── Truncation helpers (keep payloads small) ─────────────────────


def _truncate_payload(payload: dict, max_chars: int = 4000) -> dict:
    """Best-effort: drop large nested values + truncate the JSON repr."""
    try:
        s = json.dumps(payload, ensure_ascii=False, default=str)
        if len(s) <= max_chars:
            return payload
        # Drop only the top-level fields whose serialized value exceeds the budget.
        out: dict[str, Any] = {}
        for k, v in payload.items():
            vs = json.dumps(v, ensure_ascii=False, default=str)
            if len(vs) > 1000:
                out[k] = f"<truncated:{type(v).__name__}:{len(vs)}b>"
            else:
                out[k] = v
        return out
    except Exception:  # noqa: BLE001
        return {"_unserializable": True}


def _summarize_action_result(r: dict) -> dict:
    """Compact a per-action result dict for storage."""
    out = {
        "action": r.get("action"),
        "ok": bool(r.get("ok") or r.get("success")),
    }
    if r.get("error"):
        out["error"] = str(r["error"])[:300]
    if r.get("status"):
        out["status"] = r["status"]
    if r.get("rule_id"):
        out["rule_id"] = r["rule_id"]
    if r.get("approval_id"):
        out["approval_id"] = r["approval_id"]
    if r.get("comment_id"):
        out["comment_id"] = r["comment_id"]
    if r.get("notification_id"):
        out["notification_id"] = r["notification_id"]
    return out


# ── Recorder (hooked from workflow_engine.process_event) ─────────


def record_run(
    rule_id: str,
    rule_name: str,
    event_name: str,
    payload: dict,
    action_results: list[dict],
    *,
    tenant_id: Optional[str] = None,
    started_at: Optional[str] = None,
    duration_ms: int = 0,
) -> str:
    """Persist a single rule execution. Returns the run id.

    Best-effort: any exception is logged + swallowed. The recorder
    must NEVER break live event processing.
    """
    try:
        ok_count = sum(
            1 for r in action_results if r.get("ok") or r.get("success")
        )
        total = len(action_results)
        if total == 0:
            status = "success"  # no actions to fail
        elif ok_count == total:
            status = "success"
        elif ok_count == 0:
            status = "failed"
        else:
            status = "partial"
        errors = [
            str(r.get("error") or "unknown")
            for r in action_results
            if not (r.get("ok") or r.get("success"))
        ]
        run = WorkflowRun(
            id=str(uuid.uuid4()),
            rule_id=rule_id,
            rule_name=rule_name,
            event_name=event_name,
            tenant_id=tenant_id or payload.get("tenant_id"),
            status=status,
            duration_ms=duration_ms,
            started_at=started_at or datetime.now(timezone.utc).isoformat(),
            ended_at=datetime.now(timezone.utc).isoformat(),
            payload=_truncate_payload(payload or {}),
            action_results=[_summarize_action_result(r) for r in action_results],
            error_summary="; ".join(errors[:3]) if errors else None,
        )
        with _LOCK:
            _RUNS.appendleft(run)
            _save()
        return run.id
    except Exception as e:  # noqa: BLE001
        logger.error("workflow_run_history.record_run failed: %s", e)
        return ""


# ── Query API ──────────────────────────────────────────────────


def list_runs(
    *,
    rule_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    event_name: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
) -> list[dict]:
    """Newest-first list with optional filters."""
    with _LOCK:
        rows = list(_RUNS)
    if rule_id:
        rows = [r for r in rows if r.rule_id == rule_id]
    if tenant_id:
        rows = [r for r in rows if r.tenant_id == tenant_id]
    if event_name:
        rows = [r for r in rows if r.event_name == event_name]
    if status:
        rows = [r for r in rows if r.status == status]
    rows = rows[offset : offset + limit]
    return [asdict(r) for r in rows]


def get_run(run_id: str) -> Optional[dict]:
    with _LOCK:
        for r in _RUNS:
            if r.id == run_id:
                return asdict(r)
    return None


def stats() -> dict:
    with _LOCK:
        rows = list(_RUNS)
    by_status: dict[str, int] = {}
    by_rule: dict[str, int] = {}
    by_event: dict[str, int] = {}
    total_duration_ms = 0
    for r in rows:
        by_status[r.status] = by_status.get(r.status, 0) + 1
        by_rule[r.rule_name] = by_rule.get(r.rule_name, 0) + 1
        by_event[r.event_name] = by_event.get(r.event_name, 0) + 1
        total_duration_ms += r.duration_ms
    avg_ms = (total_duration_ms / len(rows)) if rows else 0
    return {
        "total": len(rows),
        "cap": _MAX_RUNS,
        "by_status": by_status,
        "top_rules": dict(
            sorted(by_rule.items(), key=lambda x: x[1], reverse=True)[:10]
        ),
        "top_events": dict(
            sorted(by_event.items(), key=lambda x: x[1], reverse=True)[:10]
        ),
        "avg_duration_ms": round(avg_ms, 1),
    }


def clear(*, rule_id: Optional[str] = None) -> int:
    """Drop all runs (or just for one rule). Returns the number removed."""
    removed = 0
    with _LOCK:
        if rule_id:
            keep = [r for r in _RUNS if r.rule_id != rule_id]
            removed = len(_RUNS) - len(keep)
            _RUNS.clear()
            _RUNS.extend(keep)
        else:
            removed = len(_RUNS)
            _RUNS.clear()
        _save()
    return removed
