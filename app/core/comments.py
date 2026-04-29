"""
APEX — Universal Comments + @Mentions
======================================
Lets users discuss any APEX entity (invoice, JE, COA account, bill,
period, etc.) without us building a separate comment thread per
feature. Threading via parent_id, mentions emit events for routing.

Why universal:
- Don't repeat the comment widget for each entity type
- @mentions become first-class events (mention.received) → workflow
  rules can route notifications, send Slack DMs, etc.
- Storage is uniform: one Comment table keyed by (object_type, object_id)

API:
    add_comment(object_type, object_id, author_user_id, body, ...)
    list_comments(object_type, object_id, tenant_id?)
    delete_comment(comment_id, by_user_id)
    react(comment_id, user_id, emoji)         (lightweight emoji reactions)

Mention extraction: any @{user_id} or @username token in the body becomes
a mentioned_user_ids[] entry. The format @{user_id} (UUID-style) is what
the frontend should send; @username is parsed only when a username->user
resolver is provided.

Reference: Layer 10.4 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import json
import logging
import os
import re
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


# ── Storage ───────────────────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get("COMMENTS_PATH", os.path.join(_DATA_DIR, "comments.json"))

_LOCK = threading.RLock()


# ── Models ───────────────────────────────────────────────────────


@dataclass
class Comment:
    id: str
    object_type: str  # "invoice" | "bill" | "je" | "coa_account" | "period" | ...
    object_id: str
    author_user_id: str
    body: str
    mentioned_user_ids: list[str] = field(default_factory=list)
    parent_id: Optional[str] = None  # for threading replies
    tenant_id: Optional[str] = None
    reactions: dict[str, list[str]] = field(default_factory=dict)
    """emoji → list of user_ids who reacted"""
    is_deleted: bool = False
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    edited_at: Optional[str] = None


_STORE: dict[str, Comment] = {}


# ── Persistence ──────────────────────────────────────────────────


def _load() -> None:
    global _STORE
    with _LOCK:
        if not os.path.exists(_PATH):
            _STORE = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _STORE = {c["id"]: Comment(**c) for c in raw.get("comments", [])}
            logger.info("Loaded %d comments from %s", len(_STORE), _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load comments: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "comments": [asdict(c) for c in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── Mention extraction ──────────────────────────────────────────


# Matches @{uuid-or-id} — frontend sends this when user picks from
# the @ autocomplete. We also accept @ followed by an email-safe ID.
_MENTION_RE = re.compile(r"@\{([A-Za-z0-9._\-]+)\}|@([A-Za-z0-9._\-]{2,64})")


def _extract_mentions(body: str) -> list[str]:
    matches: list[str] = []
    for m in _MENTION_RE.finditer(body):
        # group 1 (the {…} form) wins over the bare @ form
        uid = m.group(1) or m.group(2)
        if uid and uid not in matches:
            matches.append(uid)
    return matches


# ── CRUD ─────────────────────────────────────────────────────────


def add_comment(
    *,
    object_type: str,
    object_id: str,
    author_user_id: str,
    body: str,
    parent_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    extra_mentions: Optional[list[str]] = None,
) -> Comment:
    if not body.strip():
        raise ValueError("Comment body cannot be empty")
    if len(body) > 5000:
        raise ValueError("Comment body too long (max 5000 chars)")

    mentions = _extract_mentions(body)
    if extra_mentions:
        for u in extra_mentions:
            if u not in mentions:
                mentions.append(u)

    c = Comment(
        id=str(uuid.uuid4()),
        object_type=object_type,
        object_id=str(object_id),
        author_user_id=author_user_id,
        body=body,
        mentioned_user_ids=mentions,
        parent_id=parent_id,
        tenant_id=tenant_id,
    )
    with _LOCK:
        _STORE[c.id] = c
        _save()

    # Emit comment.added (always) + mention.received (per mention)
    emit(
        "comment.added",
        {
            "comment_id": c.id,
            "object_type": c.object_type,
            "object_id": c.object_id,
            "author_user_id": c.author_user_id,
            "tenant_id": c.tenant_id,
            "body_excerpt": (body[:200] + "…") if len(body) > 200 else body,
            "mention_count": len(mentions),
        },
        source="comments",
    )
    for uid in mentions:
        emit(
            "mention.received",
            {
                "comment_id": c.id,
                "object_type": c.object_type,
                "object_id": c.object_id,
                "mentioned_user_id": uid,
                "by_user_id": author_user_id,
                "tenant_id": c.tenant_id,
                "body_excerpt": (body[:200] + "…") if len(body) > 200 else body,
            },
            source="comments",
        )

    return c


def list_comments(
    *,
    object_type: str,
    object_id: str,
    tenant_id: Optional[str] = None,
    include_deleted: bool = False,
) -> list[Comment]:
    with _LOCK:
        out = [
            c
            for c in _STORE.values()
            if c.object_type == object_type and c.object_id == str(object_id)
        ]
    if not include_deleted:
        out = [c for c in out if not c.is_deleted]
    if tenant_id is not None:
        out = [c for c in out if c.tenant_id is None or c.tenant_id == tenant_id]
    out.sort(key=lambda c: c.created_at)
    return out


def get_comment(comment_id: str) -> Optional[Comment]:
    with _LOCK:
        return _STORE.get(comment_id)


def edit_comment(comment_id: str, by_user_id: str, new_body: str) -> Optional[Comment]:
    """Author-only edit. Returns None if not found / not author. Emits comment.edited."""
    if not new_body.strip():
        raise ValueError("Comment body cannot be empty")
    if len(new_body) > 5000:
        raise ValueError("Comment body too long (max 5000 chars)")
    with _LOCK:
        c = _STORE.get(comment_id)
        if not c or c.author_user_id != by_user_id or c.is_deleted:
            return None
        c.body = new_body
        c.mentioned_user_ids = _extract_mentions(new_body)
        c.edited_at = datetime.now(timezone.utc).isoformat()
        _save()

    emit(
        "comment.edited",
        {
            "comment_id": c.id,
            "object_type": c.object_type,
            "object_id": c.object_id,
            "author_user_id": by_user_id,
            "tenant_id": c.tenant_id,
        },
        source="comments",
    )
    return c


def delete_comment(comment_id: str, by_user_id: str) -> bool:
    """Soft-delete: marks is_deleted but keeps the row for audit + threading."""
    with _LOCK:
        c = _STORE.get(comment_id)
        if not c or c.is_deleted or c.author_user_id != by_user_id:
            return False
        c.is_deleted = True
        c.body = ""
        c.mentioned_user_ids = []
        c.edited_at = datetime.now(timezone.utc).isoformat()
        _save()

    emit(
        "comment.deleted",
        {
            "comment_id": c.id,
            "object_type": c.object_type,
            "object_id": c.object_id,
            "deleted_by": by_user_id,
            "tenant_id": c.tenant_id,
        },
        source="comments",
    )
    return True


def react(comment_id: str, user_id: str, emoji: str) -> Optional[Comment]:
    """Toggle a user's emoji reaction on a comment. Idempotent."""
    if not emoji or len(emoji) > 16:
        raise ValueError("Invalid emoji")
    with _LOCK:
        c = _STORE.get(comment_id)
        if not c or c.is_deleted:
            return None
        bucket = c.reactions.setdefault(emoji, [])
        if user_id in bucket:
            bucket.remove(user_id)
            if not bucket:
                del c.reactions[emoji]
        else:
            bucket.append(user_id)
        _save()
        return c


# Initial load.
_load()


def stats() -> dict:
    with _LOCK:
        active = sum(1 for c in _STORE.values() if not c.is_deleted)
        by_obj_type: dict[str, int] = {}
        for c in _STORE.values():
            if c.is_deleted:
                continue
            by_obj_type[c.object_type] = by_obj_type.get(c.object_type, 0) + 1
        return {
            "comments_total": len(_STORE),
            "comments_active": active,
            "comments_deleted": len(_STORE) - active,
            "by_object_type": by_obj_type,
            "storage_path": _PATH,
        }
