"""APEX — Activity Feed.

Per-user "what's happening in my world" stream. Reads the event bus
and converts each system event into a human-readable activity entry
scoped to the relevant user(s).

The feed is the user-facing analog of the admin Events Browser:
admins debug raw events; users see "اقترح copilot قاعدة جديدة" or
"تم منحك دور Reviewer" without seeing the JSON.

Storage: JSON-as-DB ring buffer at $APEX_DATA_DIR/activity_feed.json
(cap _MAX_ENTRIES = 10K, configurable via env). Newest-first deque.

Resolution rules: each event maps to zero or more activity entries
based on which fields its payload exposes. Examples:
  - `comment.added` with `mentioned_user_ids: [u1, u2]` → 2 entries
    (one per mentioned user) + 1 entry for the comment author
  - `approval.requested` with `approver_user_ids` → 1 entry per
    approver + 1 entry for `requested_by`
  - `role.assigned` with `user_id` → 1 entry for the recipient
  - `module.enabled` (system-wide) → no per-user entry

Read-state: a per-(user_id, tenant_id) "last_read_at" cursor lets the
client highlight unread items without per-entry mutations.

Wave 1P Phase WW. Layer 10 (Collaboration) of FUTURE_ROADMAP.md.
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

from app.core.event_bus import register_listener

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "ACTIVITY_FEED_PATH",
    os.path.join(_DATA_DIR, "activity_feed.json"),
)
_MAX_ENTRIES = int(os.environ.get("ACTIVITY_FEED_MAX", "10000"))
_LOCK = threading.RLock()


@dataclass
class ActivityEntry:
    id: str
    user_id: str
    tenant_id: Optional[str]
    event_name: str
    title_ar: str
    body_ar: Optional[str] = None
    icon: str = "info"
    severity: str = "info"  # info | success | warning | error
    action_url: Optional[str] = None
    object_type: Optional[str] = None
    object_id: Optional[str] = None
    actor_user_id: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class ReadCursor:
    user_id: str
    tenant_id: Optional[str]
    last_read_at: str  # ISO


_ENTRIES: deque[ActivityEntry] = deque(maxlen=_MAX_ENTRIES)
_CURSORS: dict[str, ReadCursor] = {}  # key = f"{user_id}|{tenant_id or '_'}"


# ── Persistence ─────────────────────────────────────────────────


def _cursor_key(user_id: str, tenant_id: Optional[str]) -> str:
    return f"{user_id}|{tenant_id or '_'}"


def _load() -> None:
    global _ENTRIES, _CURSORS
    with _LOCK:
        if not os.path.exists(_PATH):
            _ENTRIES = deque(maxlen=_MAX_ENTRIES)
            _CURSORS = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            new_entries = deque(maxlen=_MAX_ENTRIES)
            for e in raw.get("entries", []):
                new_entries.append(ActivityEntry(**e))
            _ENTRIES = new_entries
            _CURSORS = {
                _cursor_key(c["user_id"], c.get("tenant_id")): ReadCursor(**c)
                for c in raw.get("cursors", [])
            }
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load activity feed: %s", e)
            _ENTRIES = deque(maxlen=_MAX_ENTRIES)
            _CURSORS = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "entries": [asdict(e) for e in _ENTRIES],
            "cursors": [asdict(c) for c in _CURSORS.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to save activity feed: %s", e)


_load()


# ── Recorder ────────────────────────────────────────────────────


def _record(
    user_id: str,
    *,
    event_name: str,
    title_ar: str,
    body_ar: Optional[str] = None,
    icon: str = "info",
    severity: str = "info",
    action_url: Optional[str] = None,
    object_type: Optional[str] = None,
    object_id: Optional[str] = None,
    actor_user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    metadata: Optional[dict] = None,
) -> str:
    entry = ActivityEntry(
        id=str(uuid.uuid4()),
        user_id=user_id,
        tenant_id=tenant_id,
        event_name=event_name,
        title_ar=title_ar,
        body_ar=body_ar,
        icon=icon,
        severity=severity,
        action_url=action_url,
        object_type=object_type,
        object_id=object_id,
        actor_user_id=actor_user_id,
        metadata=metadata or {},
    )
    with _LOCK:
        _ENTRIES.appendleft(entry)
        _save()
    return entry.id


# ── Event → Activity mappers ────────────────────────────────────


def _on_comment_added(payload: dict) -> None:
    """One entry for each mentioned user (excluding the author)."""
    object_type = payload.get("object_type")
    object_id = payload.get("object_id")
    author = payload.get("author_user_id")
    tenant_id = payload.get("tenant_id")
    body_preview = (payload.get("body") or "")[:120]
    for uid in (payload.get("mentioned_user_ids") or []):
        if uid == author:
            continue
        _record(
            user_id=uid,
            event_name="comment.added",
            title_ar="ذُكرت في تعليق",
            body_ar=body_preview or None,
            icon="alternate_email",
            severity="info",
            action_url=f"/{object_type}/{object_id}" if object_type and object_id else None,
            object_type=object_type,
            object_id=str(object_id) if object_id else None,
            actor_user_id=author,
            tenant_id=tenant_id,
            metadata={"comment_id": payload.get("comment_id")},
        )


def _on_approval_requested(payload: dict) -> None:
    title = payload.get("title_ar") or payload.get("title_en") or "موافقة مطلوبة"
    requested_by = payload.get("requested_by")
    object_type = payload.get("object_type")
    object_id = payload.get("object_id")
    tenant_id = payload.get("tenant_id")
    approval_id = payload.get("approval_id")
    for uid in (payload.get("approver_user_ids") or []):
        _record(
            user_id=uid,
            event_name="approval.requested",
            title_ar=f"موافقة مطلوبة: {title}",
            body_ar=payload.get("body"),
            icon="task_alt",
            severity="warning",
            action_url="/workflow/approvals",
            object_type=object_type,
            object_id=str(object_id) if object_id else None,
            actor_user_id=requested_by,
            tenant_id=tenant_id,
            metadata={"approval_id": approval_id},
        )


def _on_approval_decided(payload: dict, *, approved: bool) -> None:
    requested_by = payload.get("requested_by")
    if not requested_by:
        return
    decided_by = payload.get("decided_by") or payload.get("approver_user_id")
    title_obj = payload.get("title_ar") or payload.get("title_en") or ""
    _record(
        user_id=requested_by,
        event_name="approval.approved" if approved else "approval.rejected",
        title_ar=f"تمت الموافقة على: {title_obj}" if approved else f"رُفِض طلبك: {title_obj}",
        body_ar=payload.get("reason"),
        icon="check_circle" if approved else "cancel",
        severity="success" if approved else "error",
        action_url="/workflow/approvals",
        object_type=payload.get("object_type"),
        object_id=str(payload.get("object_id") or "") or None,
        actor_user_id=decided_by,
        tenant_id=payload.get("tenant_id"),
        metadata={"approval_id": payload.get("approval_id")},
    )


def _on_role_change(event_name: str, payload: dict) -> None:
    user_id = payload.get("user_id")
    if not user_id:
        return
    role_name = payload.get("role_name") or payload.get("role_id") or "دور"
    actor = payload.get("actor_user_id")
    if event_name == "role.assigned":
        title = f"تم منحك دور {role_name}"
        icon = "shield"
        sev = "success"
    elif event_name == "role.revoked":
        title = f"تم سحب دور {role_name}"
        icon = "remove_circle"
        sev = "warning"
    else:
        return
    _record(
        user_id=user_id,
        event_name=event_name,
        title_ar=title,
        icon=icon,
        severity=sev,
        action_url="/admin/roles",
        actor_user_id=actor,
        tenant_id=payload.get("tenant_id"),
        metadata={"role_id": payload.get("role_id")},
    )


def _on_suggestion_proposed(payload: dict) -> None:
    """Notify admins of a new platform suggestion. Skipped here since
    we don't have a per-user 'admin role' resolver wired in cleanly —
    the Suggestions Inbox screen surfaces these. Kept as a placeholder
    for when Wave 2+ adds an "admins of tenant_id" resolver.
    """
    return


def _on_mention_received(payload: dict) -> None:
    """Direct mention pipeline (separate event kept for compatibility
    with Phase 1A wiring)."""
    uid = payload.get("user_id") or payload.get("mentioned_user_id")
    if not uid:
        return
    _record(
        user_id=uid,
        event_name="mention.received",
        title_ar=payload.get("title_ar") or "ذُكرت في تعليق",
        body_ar=payload.get("body"),
        icon="alternate_email",
        severity="info",
        action_url=payload.get("action_url"),
        actor_user_id=payload.get("actor_user_id") or payload.get("author_user_id"),
        tenant_id=payload.get("tenant_id"),
        object_type=payload.get("object_type"),
        object_id=str(payload.get("object_id") or "") or None,
    )


# ── Bus listeners ──────────────────────────────────────────────


@register_listener("comment.added")
def _comment_listener(event_name: str, payload: dict) -> None:
    try:
        _on_comment_added(payload)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed comment listener failed")


@register_listener("mention.received")
def _mention_listener(event_name: str, payload: dict) -> None:
    try:
        _on_mention_received(payload)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed mention listener failed")


@register_listener("approval.requested")
def _approval_req_listener(event_name: str, payload: dict) -> None:
    try:
        _on_approval_requested(payload)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed approval.requested listener failed")


@register_listener("approval.approved")
def _approval_ok_listener(event_name: str, payload: dict) -> None:
    try:
        _on_approval_decided(payload, approved=True)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed approval.approved listener failed")


@register_listener("approval.rejected")
def _approval_rej_listener(event_name: str, payload: dict) -> None:
    try:
        _on_approval_decided(payload, approved=False)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed approval.rejected listener failed")


@register_listener("role.assigned")
@register_listener("role.revoked")
def _role_listener(event_name: str, payload: dict) -> None:
    try:
        _on_role_change(event_name, payload)
    except Exception:  # noqa: BLE001
        logger.exception("activity_feed role listener failed")


# ── Query API ──────────────────────────────────────────────────


def list_for_user(
    user_id: str,
    *,
    tenant_id: Optional[str] = None,
    only_unread: bool = False,
    limit: int = 50,
    offset: int = 0,
) -> dict:
    """Return entries scoped to user, optional tenant, optional unread-only."""
    with _LOCK:
        rows = [
            asdict(e)
            for e in _ENTRIES
            if e.user_id == user_id and (tenant_id is None or e.tenant_id == tenant_id)
        ]
        cur = _CURSORS.get(_cursor_key(user_id, tenant_id))
    last_read = cur.last_read_at if cur else None
    if only_unread and last_read:
        rows = [r for r in rows if r["created_at"] > last_read]
    total = len(rows)
    rows = rows[offset : offset + limit]
    unread_count = (
        sum(1 for r in rows if not last_read or r["created_at"] > last_read)
    )
    return {
        "entries": rows,
        "count": total,
        "unread_count": unread_count,
        "last_read_at": last_read,
    }


def mark_read(user_id: str, *, tenant_id: Optional[str] = None) -> str:
    now = datetime.now(timezone.utc).isoformat()
    with _LOCK:
        _CURSORS[_cursor_key(user_id, tenant_id)] = ReadCursor(
            user_id=user_id, tenant_id=tenant_id, last_read_at=now
        )
        _save()
    return now


def stats() -> dict:
    with _LOCK:
        rows = list(_ENTRIES)
    by_severity: dict[str, int] = {}
    by_event: dict[str, int] = {}
    users = set()
    tenants = set()
    for r in rows:
        by_severity[r.severity] = by_severity.get(r.severity, 0) + 1
        by_event[r.event_name] = by_event.get(r.event_name, 0) + 1
        users.add(r.user_id)
        if r.tenant_id:
            tenants.add(r.tenant_id)
    return {
        "total": len(rows),
        "cap": _MAX_ENTRIES,
        "users_with_activity": len(users),
        "tenants_with_activity": len(tenants),
        "by_severity": by_severity,
        "top_events": dict(
            sorted(by_event.items(), key=lambda x: x[1], reverse=True)[:10]
        ),
    }


def clear(*, user_id: Optional[str] = None) -> int:
    """Hard-delete entries (all, or just one user)."""
    removed = 0
    with _LOCK:
        if user_id:
            keep = [e for e in _ENTRIES if e.user_id != user_id]
            removed = len(_ENTRIES) - len(keep)
            _ENTRIES.clear()
            _ENTRIES.extend(keep)
        else:
            removed = len(_ENTRIES)
            _ENTRIES.clear()
        _save()
    return removed


# Public test helper (used by smoke tests + the Suggestions/Activity
# wiring tests).
def _record_for_test(**kw) -> str:
    return _record(**kw)
