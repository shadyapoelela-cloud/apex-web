"""APEX — Unified Notification Center.

Aggregates the 4 user-facing notification sources into a single inbox:

  1. Activity Feed (Wave 1P) — mentions, role changes, approvals
     where the user is requested_by, etc.
  2. Pending Approvals (Wave 1B) — approvals where the user is in
     `approver_user_ids` and the approval is still pending.
  3. Proactive Suggestions (Wave 1G) — admin-only; surfaced for users
     with platform_admin / super_admin in their roles list.
  4. Tenant system notifications (Phase 10 ai_notifications.py if
     available) — best-effort import, skipped if unavailable.

Each aggregated item has a uniform shape:
    {
        "id": str,           # unique within source
        "source": "activity"|"approval"|"suggestion"|"system",
        "title_ar": str,
        "body_ar": str?,
        "icon": str,
        "severity": "info"|"success"|"warning"|"error",
        "action_url": str?,  # Flutter route to navigate to
        "ts": str,            # ISO timestamp
        "actor_user_id": str?,
        "tenant_id": str?,
        "is_unread": bool,
    }

Read state is tracked per (user_id, tenant_id) — the activity_feed
read cursor + a NEW per-user inbox cursor for the other 3 sources.

No new persistence file — the inbox is purely a query layer over
existing stores.

Wave 1X Phase EEE.
"""

from __future__ import annotations

import json
import logging
import os
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "INBOX_CURSORS_PATH",
    os.path.join(_DATA_DIR, "inbox_cursors.json"),
)
_LOCK = threading.RLock()


@dataclass
class InboxCursor:
    user_id: str
    tenant_id: Optional[str]
    last_read_at: str  # ISO


# (user_id|tenant_id) → InboxCursor
_CURSORS: dict[str, InboxCursor] = {}


def _key(user_id: str, tenant_id: Optional[str]) -> str:
    return f"{user_id}|{tenant_id or '_'}"


def _load() -> None:
    global _CURSORS
    with _LOCK:
        if not os.path.exists(_PATH):
            _CURSORS = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _CURSORS = {
                _key(c["user_id"], c.get("tenant_id")): InboxCursor(**c)
                for c in raw.get("cursors", [])
            }
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load inbox cursors: %s", e)
            _CURSORS = {}


def _save() -> None:
    with _LOCK:
        from dataclasses import asdict
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "cursors": [asdict(c) for c in _CURSORS.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to save inbox cursors: %s", e)


_load()


# ── Source aggregators ─────────────────────────────────────────


def _activity_items(user_id: str, tenant_id: Optional[str], limit: int = 100) -> list[dict]:
    try:
        from app.core.activity_feed import list_for_user
    except Exception:
        return []
    try:
        result = list_for_user(user_id, tenant_id=tenant_id, limit=limit)
    except Exception:  # noqa: BLE001
        return []
    last_read = result.get("last_read_at")
    out: list[dict] = []
    for e in result.get("entries", []):
        out.append({
            "id": f"activity:{e.get('id')}",
            "source": "activity",
            "title_ar": e.get("title_ar") or "نشاط",
            "body_ar": e.get("body_ar"),
            "icon": e.get("icon") or "info",
            "severity": e.get("severity") or "info",
            "action_url": e.get("action_url"),
            "ts": e.get("created_at") or "",
            "actor_user_id": e.get("actor_user_id"),
            "tenant_id": e.get("tenant_id"),
            "object_type": e.get("object_type"),
            "object_id": e.get("object_id"),
            "is_unread": (last_read is None) or (e.get("created_at", "") > last_read),
        })
    return out


def _approval_items(user_id: str, tenant_id: Optional[str], cursor_iso: Optional[str]) -> list[dict]:
    try:
        from app.core.approvals import list_approvals
    except Exception:
        return []
    try:
        rows = list_approvals(tenant_id=tenant_id, user_id=user_id, state="pending")
    except Exception:  # noqa: BLE001
        return []
    out: list[dict] = []
    from dataclasses import asdict
    for a in rows:
        d = asdict(a) if hasattr(a, "__dataclass_fields__") else a
        ts = d.get("created_at") or d.get("updated_at") or ""
        out.append({
            "id": f"approval:{d.get('id')}",
            "source": "approval",
            "title_ar": f"موافقة مطلوبة: {d.get('title_ar') or d.get('title_en') or ''}",
            "body_ar": d.get("body"),
            "icon": "task_alt",
            "severity": "warning",
            "action_url": "/admin/approvals",
            "ts": ts,
            "actor_user_id": d.get("requested_by"),
            "tenant_id": d.get("tenant_id"),
            "object_type": d.get("object_type"),
            "object_id": d.get("object_id"),
            "is_unread": (cursor_iso is None) or (ts > cursor_iso),
        })
    return out


def _suggestion_items(
    user_id: str,
    tenant_id: Optional[str],
    user_roles: list[str],
    cursor_iso: Optional[str],
) -> list[dict]:
    # Suggestions are platform-admin-only.
    if not (set(user_roles) & {"platform_admin", "super_admin"}):
        return []
    try:
        from app.core.proactive_suggestions import list_suggestions
    except Exception:
        return []
    try:
        rows = list_suggestions(tenant_id=tenant_id, status="proposed")
    except Exception:  # noqa: BLE001
        return []
    out: list[dict] = []
    for s in rows:
        d = s if isinstance(s, dict) else {
            k: getattr(s, k, None) for k in [
                "id", "code", "severity", "title_ar", "body_ar",
                "action", "action_target", "tenant_id", "created_at",
            ]
        }
        sev_map = {
            "info": "info",
            "warning": "warning",
            "high": "error",
        }
        ts = d.get("created_at") or ""
        action_url: Optional[str] = "/admin/suggestions"
        if d.get("action") == "install_template" and d.get("action_target"):
            action_url = f"/admin/workflow/templates?focus={d['action_target']}"
        out.append({
            "id": f"suggestion:{d.get('id')}",
            "source": "suggestion",
            "title_ar": d.get("title_ar") or "اقتراح جديد",
            "body_ar": d.get("body_ar"),
            "icon": "lightbulb",
            "severity": sev_map.get(d.get("severity", "info"), "info"),
            "action_url": action_url,
            "ts": ts,
            "actor_user_id": None,
            "tenant_id": d.get("tenant_id"),
            "object_type": "suggestion",
            "object_id": d.get("code"),
            "is_unread": (cursor_iso is None) or (ts > cursor_iso),
        })
    return out


def _system_notifications_items(
    user_id: str,
    tenant_id: Optional[str],
    cursor_iso: Optional[str],
) -> list[dict]:
    """Best-effort: pull from any module exposing a per-user notification list.

    Tries common module names in order. Skipped silently if none are
    available — the other 3 sources still drive the inbox.
    """
    tried_modules = [
        ("app.phase10.services.notification_service", "list_for_user"),
        ("app.phase10.services.ai_notifications", "list_for_user"),
        ("app.core.notifications", "list_for_user"),
    ]
    for mod_name, fn_name in tried_modules:
        try:
            mod = __import__(mod_name, fromlist=[fn_name])
            fn = getattr(mod, fn_name, None)
            if fn is None:
                continue
            rows = fn(user_id=user_id, tenant_id=tenant_id, limit=100)
            if not isinstance(rows, list):
                continue
            out: list[dict] = []
            for r in rows:
                d = r if isinstance(r, dict) else {
                    k: getattr(r, k, None) for k in [
                        "id", "title_ar", "body_ar", "icon", "severity",
                        "action_url", "created_at", "tenant_id",
                    ]
                }
                ts = d.get("created_at") or ""
                out.append({
                    "id": f"system:{d.get('id')}",
                    "source": "system",
                    "title_ar": d.get("title_ar") or "إشعار من النظام",
                    "body_ar": d.get("body_ar"),
                    "icon": d.get("icon") or "notifications",
                    "severity": d.get("severity") or "info",
                    "action_url": d.get("action_url"),
                    "ts": ts,
                    "actor_user_id": None,
                    "tenant_id": d.get("tenant_id"),
                    "object_type": "notification",
                    "object_id": str(d.get("id")) if d.get("id") else None,
                    "is_unread": (cursor_iso is None) or (ts > cursor_iso),
                })
            return out
        except Exception:  # noqa: BLE001
            continue
    return []


# ── Public API ──────────────────────────────────────────────────


def list_inbox(
    user_id: str,
    *,
    tenant_id: Optional[str] = None,
    sources: Optional[list[str]] = None,
    only_unread: bool = False,
    limit: int = 200,
    user_roles: Optional[list[str]] = None,
) -> dict:
    """Aggregate items from all enabled sources.

    sources: optional whitelist of {"activity","approval","suggestion","system"}.
    user_roles: required for suggestion gating; pass S.roles from the
                client (the client can be authoritative since this is
                an inbox preview, not security boundary).
    """
    user_roles = user_roles or []
    enabled = set(sources or ["activity", "approval", "suggestion", "system"])
    cursor = _CURSORS.get(_key(user_id, tenant_id))
    cursor_iso = cursor.last_read_at if cursor else None

    items: list[dict] = []
    if "activity" in enabled:
        items.extend(_activity_items(user_id, tenant_id))
    if "approval" in enabled:
        items.extend(_approval_items(user_id, tenant_id, cursor_iso))
    if "suggestion" in enabled:
        items.extend(_suggestion_items(user_id, tenant_id, user_roles, cursor_iso))
    if "system" in enabled:
        items.extend(_system_notifications_items(user_id, tenant_id, cursor_iso))

    if only_unread:
        items = [i for i in items if i.get("is_unread")]

    # Newest first.
    items.sort(key=lambda i: i.get("ts") or "", reverse=True)
    items = items[:limit]

    by_source: dict[str, int] = {}
    unread_total = 0
    for i in items:
        by_source[i["source"]] = by_source.get(i["source"], 0) + 1
        if i.get("is_unread"):
            unread_total += 1

    return {
        "items": items,
        "count": len(items),
        "unread_count": unread_total,
        "by_source": by_source,
        "last_read_at": cursor_iso,
        "sources_enabled": sorted(enabled),
    }


def mark_all_read(user_id: str, *, tenant_id: Optional[str] = None) -> str:
    """Set the cursor for ALL non-activity sources.

    Activity feed has its own cursor (Wave 1P) which we update via the
    activity_feed.mark_read API to keep both in sync.
    """
    now = datetime.now(timezone.utc).isoformat()
    with _LOCK:
        _CURSORS[_key(user_id, tenant_id)] = InboxCursor(
            user_id=user_id, tenant_id=tenant_id, last_read_at=now
        )
        _save()
    # Also bump the activity feed cursor so that surface stays consistent.
    try:
        from app.core.activity_feed import mark_read
        mark_read(user_id, tenant_id=tenant_id)
    except Exception:  # noqa: BLE001
        pass
    return now


def stats(user_id: Optional[str] = None) -> dict:
    """Admin overview of inbox engagement.

    Without user_id: aggregate cursors count.
    With user_id: detail for that user.
    """
    with _LOCK:
        rows = list(_CURSORS.values())
    if user_id is None:
        return {
            "users_with_cursor": len(rows),
            "cursor_path": _PATH,
        }
    matching = [c for c in rows if c.user_id == user_id]
    return {
        "user_id": user_id,
        "tenant_cursors": [
            {"tenant_id": c.tenant_id, "last_read_at": c.last_read_at}
            for c in matching
        ],
    }
