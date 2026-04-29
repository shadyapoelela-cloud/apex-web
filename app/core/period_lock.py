"""APEX — Period Lock service.

Enforces accounting period closure with auditable overrides.

Until this module APEX had a `period_close` checklist (the to-do list
of things to do during close) but no actual *enforcement* — anyone
could post a journal entry to any date. In production accounting,
once a period is closed the books are *locked*: no postings, no edits,
no deletes. Overrides exist for legitimate corrections (subsequent
events, audit adjustments) but every override must be logged with a
reason + the user who authorized it.

Storage: $APEX_DATA_DIR/period_locks.json — same JSON-as-DB pattern.
A LockRecord per (tenant_id, period_code) and an append-only
OverrideRecord log per (tenant_id, period_code, ts).

Period code format: free-form string but conventionally `YYYY-MM`
(monthly close) or `YYYY-Q1` (quarterly) or `YYYY` (annual).

Events:
    period.locked            — admin closes a period
    period.unlocked          — admin re-opens (rare; needs reason)
    period.lock.overridden   — a posting hit a locked period; audit
                               trail captured

Wave 1Q Phase XX. Closes "Period Lock partial" gap from
architecture/diagrams/02-target-state.md section 10.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "PERIOD_LOCKS_PATH",
    os.path.join(_DATA_DIR, "period_locks.json"),
)
_LOCK = threading.RLock()


@dataclass
class LockRecord:
    id: str
    tenant_id: str
    period_code: str  # e.g. "2026-03"
    locked_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    locked_by: Optional[str] = None
    notes: Optional[str] = None
    # Soft-unlock metadata when admin re-opens.
    unlocked_at: Optional[str] = None
    unlocked_by: Optional[str] = None
    unlock_reason: Optional[str] = None


@dataclass
class OverrideRecord:
    """An append-only audit entry: someone tried to post to a locked
    period and either (a) was blocked or (b) was allowed because they
    supplied an override reason + had the requisite permission."""

    id: str
    tenant_id: str
    period_code: str
    actor_user_id: Optional[str]
    object_type: Optional[str]
    object_id: Optional[str]
    action: str  # "blocked" | "allowed_with_override"
    reason: Optional[str] = None
    occurred_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


# (tenant_id, period_code) → LockRecord.
# We key by the combo so re-locking the same period replaces (idempotent).
_LOCKS: dict[tuple[str, str], LockRecord] = {}
# Append-only override log.
_OVERRIDES: list[OverrideRecord] = []
# Soft cap on the override log to keep disk bounded (oldest dropped).
_MAX_OVERRIDES = int(os.environ.get("PERIOD_LOCK_OVERRIDE_MAX", "10000"))


# ── Persistence ─────────────────────────────────────────────────


def _load() -> None:
    global _LOCKS, _OVERRIDES
    with _LOCK:
        if not os.path.exists(_PATH):
            _LOCKS = {}
            _OVERRIDES = []
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _LOCKS = {
                (r["tenant_id"], r["period_code"]): LockRecord(**r)
                for r in raw.get("locks", [])
            }
            _OVERRIDES = [OverrideRecord(**o) for o in raw.get("overrides", [])]
            # Trim if cap shrunk.
            if len(_OVERRIDES) > _MAX_OVERRIDES:
                _OVERRIDES = _OVERRIDES[-_MAX_OVERRIDES:]
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load period locks: %s", e)
            _LOCKS = {}
            _OVERRIDES = []


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "locks": [asdict(r) for r in _LOCKS.values()],
            "overrides": [asdict(o) for o in _OVERRIDES],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to save period locks: %s", e)


_load()


# ── Lock state API ──────────────────────────────────────────────


def is_locked(tenant_id: str, period_code: str) -> bool:
    """True iff the period is currently locked (not yet unlocked)."""
    with _LOCK:
        rec = _LOCKS.get((tenant_id, period_code))
        return rec is not None and rec.unlocked_at is None


def get_lock(tenant_id: str, period_code: str) -> Optional[dict]:
    with _LOCK:
        rec = _LOCKS.get((tenant_id, period_code))
        return asdict(rec) if rec else None


def list_locks(*, tenant_id: Optional[str] = None, only_active: bool = False) -> list[dict]:
    with _LOCK:
        rows = list(_LOCKS.values())
    if tenant_id:
        rows = [r for r in rows if r.tenant_id == tenant_id]
    if only_active:
        rows = [r for r in rows if r.unlocked_at is None]
    rows.sort(key=lambda r: r.locked_at, reverse=True)
    return [asdict(r) for r in rows]


def lock_period(
    tenant_id: str,
    period_code: str,
    *,
    locked_by: Optional[str] = None,
    notes: Optional[str] = None,
) -> dict:
    """Idempotent: re-locking an already-locked period refreshes
    locked_at + locked_by but keeps the same id."""
    if not tenant_id or not period_code:
        raise ValueError("tenant_id and period_code required")
    key = (tenant_id, period_code)
    is_new = False
    with _LOCK:
        existing = _LOCKS.get(key)
        if existing and existing.unlocked_at is None:
            existing.locked_at = datetime.now(timezone.utc).isoformat()
            if locked_by is not None:
                existing.locked_by = locked_by
            if notes is not None:
                existing.notes = notes
            rec = existing
        else:
            rec = LockRecord(
                id=str(uuid.uuid4()),
                tenant_id=tenant_id,
                period_code=period_code,
                locked_by=locked_by,
                notes=notes,
            )
            _LOCKS[key] = rec
            is_new = True
        _save()
    if is_new:
        emit(
            "period.locked",
            {
                "tenant_id": tenant_id,
                "period_code": period_code,
                "locked_by": locked_by,
            },
            source="period_lock",
        )
    return asdict(rec)


def unlock_period(
    tenant_id: str,
    period_code: str,
    *,
    unlocked_by: Optional[str] = None,
    reason: Optional[str] = None,
) -> Optional[dict]:
    """Re-open a locked period. Reason is required (audit signal).

    Returns None if no lock exists.
    """
    if not reason or not reason.strip():
        raise ValueError("unlock reason is required")
    key = (tenant_id, period_code)
    with _LOCK:
        rec = _LOCKS.get(key)
        if not rec or rec.unlocked_at is not None:
            return None
        rec.unlocked_at = datetime.now(timezone.utc).isoformat()
        rec.unlocked_by = unlocked_by
        rec.unlock_reason = reason
        _save()
    emit(
        "period.unlocked",
        {
            "tenant_id": tenant_id,
            "period_code": period_code,
            "unlocked_by": unlocked_by,
            "reason": reason,
        },
        source="period_lock",
    )
    return asdict(rec)


# ── Enforcement check (the heart of the feature) ────────────────


def check_posting(
    tenant_id: str,
    period_code: str,
    *,
    actor_user_id: Optional[str] = None,
    object_type: Optional[str] = None,
    object_id: Optional[str] = None,
    override_reason: Optional[str] = None,
    has_override_permission: bool = False,
) -> dict:
    """The function callers use to decide if a posting should proceed.

    Returns a dict:
        { "allowed": bool, "reason": str, "override_logged": bool }

    Logic:
      * Period not locked → always allowed (allowed=True, override_logged=False).
      * Locked + no override_reason → blocked. Audit "blocked".
      * Locked + override_reason + has_override_permission=False → blocked.
        Audit "blocked".
      * Locked + override_reason + has_override_permission=True → allowed.
        Audit "allowed_with_override". Emit period.lock.overridden.
    """
    if not is_locked(tenant_id, period_code):
        return {"allowed": True, "reason": "not_locked", "override_logged": False}

    # Period IS locked.
    if not override_reason or not override_reason.strip():
        _record_override(
            tenant_id, period_code, actor_user_id, object_type, object_id,
            action="blocked", reason="no_override_reason_supplied",
        )
        return {
            "allowed": False,
            "reason": "period_locked_no_override",
            "override_logged": True,
        }

    if not has_override_permission:
        _record_override(
            tenant_id, period_code, actor_user_id, object_type, object_id,
            action="blocked", reason="missing_override_permission",
        )
        return {
            "allowed": False,
            "reason": "period_locked_missing_permission",
            "override_logged": True,
        }

    # Override is valid.
    _record_override(
        tenant_id, period_code, actor_user_id, object_type, object_id,
        action="allowed_with_override", reason=override_reason,
    )
    emit(
        "period.lock.overridden",
        {
            "tenant_id": tenant_id,
            "period_code": period_code,
            "actor_user_id": actor_user_id,
            "object_type": object_type,
            "object_id": object_id,
            "reason": override_reason,
        },
        source="period_lock",
    )
    return {
        "allowed": True,
        "reason": "override_authorized",
        "override_logged": True,
    }


def _record_override(
    tenant_id: str,
    period_code: str,
    actor_user_id: Optional[str],
    object_type: Optional[str],
    object_id: Optional[str],
    *,
    action: str,
    reason: Optional[str] = None,
) -> None:
    rec = OverrideRecord(
        id=str(uuid.uuid4()),
        tenant_id=tenant_id,
        period_code=period_code,
        actor_user_id=actor_user_id,
        object_type=object_type,
        object_id=object_id,
        action=action,
        reason=reason,
    )
    with _LOCK:
        _OVERRIDES.append(rec)
        # Cap append-only log.
        if len(_OVERRIDES) > _MAX_OVERRIDES:
            _OVERRIDES.pop(0)
        _save()


def list_overrides(
    *,
    tenant_id: Optional[str] = None,
    period_code: Optional[str] = None,
    action: Optional[str] = None,
    limit: int = 100,
) -> list[dict]:
    with _LOCK:
        rows = list(_OVERRIDES)
    if tenant_id:
        rows = [r for r in rows if r.tenant_id == tenant_id]
    if period_code:
        rows = [r for r in rows if r.period_code == period_code]
    if action:
        rows = [r for r in rows if r.action == action]
    rows.sort(key=lambda r: r.occurred_at, reverse=True)
    return [asdict(r) for r in rows[:limit]]


def stats() -> dict:
    with _LOCK:
        active = [r for r in _LOCKS.values() if r.unlocked_at is None]
        unlocked = [r for r in _LOCKS.values() if r.unlocked_at is not None]
        all_overrides = list(_OVERRIDES)
    by_action: dict[str, int] = {}
    for o in all_overrides:
        by_action[o.action] = by_action.get(o.action, 0) + 1
    by_tenant_active: dict[str, int] = {}
    for r in active:
        by_tenant_active[r.tenant_id] = by_tenant_active.get(r.tenant_id, 0) + 1
    return {
        "active_locks": len(active),
        "unlocked_history": len(unlocked),
        "overrides_total": len(all_overrides),
        "overrides_by_action": by_action,
        "active_locks_by_tenant": by_tenant_active,
    }
