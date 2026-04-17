"""Cursor-based pagination — replaces offset/limit for scale.

Why cursor over offset:
  • O(1) page fetch vs O(offset) DB scan; matters at 10K+ rows.
  • Stable under concurrent inserts: offset shifts rows; cursors don't.
  • Better UX for infinite scroll and mobile clients.

Cursor shape:
  Opaque base64-urlsafe string that encodes: (sort_field, direction, last_value).
  Clients round-trip it — they never decode it.

Public API:
  paginate(query, *, order_field, direction='asc', limit=25, cursor=None)
      Returns CursorPage(items, next_cursor, has_more, total_hint).

  CursorPage.to_dict() produces the standard envelope:
      {"data": [...], "next_cursor": "...", "has_more": bool}

Usage:
  from app.core.pagination import paginate, parse_pagination_query

  @router.get("/invoices")
  def list_invoices(cursor: str | None = None, limit: int = 25):
      q = db.query(Invoice).order_by(Invoice.created_at.desc())
      page = paginate(q, order_field=Invoice.created_at,
                      direction='desc', cursor=cursor, limit=limit)
      return {"success": True, **page.to_dict()}

For filters + cursor coexisting, apply filters BEFORE calling paginate().
"""

from __future__ import annotations

import base64
import json
import logging
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy.orm import Query
from sqlalchemy.sql.schema import Column

logger = logging.getLogger(__name__)

DEFAULT_LIMIT = 25
MAX_LIMIT = 100


class CursorError(ValueError):
    """Raised when a cursor is malformed / tampered."""


# ── Cursor encoding ─────────────────────────────────────────


def _json_default(obj: Any) -> Any:
    """JSON encoder for the types we commonly sort by."""
    if isinstance(obj, datetime):
        return {"__t__": "datetime", "v": obj.isoformat()}
    if isinstance(obj, date):
        return {"__t__": "date", "v": obj.isoformat()}
    if isinstance(obj, Decimal):
        return {"__t__": "decimal", "v": str(obj)}
    raise TypeError(f"Unserializable cursor value: {type(obj).__name__}")


def _json_hook(payload: dict) -> Any:
    t = payload.get("__t__")
    if t == "datetime":
        return datetime.fromisoformat(payload["v"])
    if t == "date":
        return date.fromisoformat(payload["v"])
    if t == "decimal":
        return Decimal(payload["v"])
    return payload


def encode_cursor(field: str, direction: str, last_value: Any) -> str:
    """Encode a (field, direction, last_value) tuple into an opaque base64 token."""
    payload = json.dumps(
        {"f": field, "d": direction, "v": last_value},
        default=_json_default,
        separators=(",", ":"),
    )
    return base64.urlsafe_b64encode(payload.encode("utf-8")).decode("ascii").rstrip("=")


def decode_cursor(token: str) -> tuple[str, str, Any]:
    """Decode the cursor token. Raises CursorError on anything weird."""
    if not token:
        raise CursorError("empty cursor")
    # Restore padding (urlsafe_b64encode strips '=')
    padded = token + "=" * (-len(token) % 4)
    try:
        raw = base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8")
    except Exception as e:
        raise CursorError(f"bad base64: {e}") from e
    try:
        payload = json.loads(raw, object_hook=_json_hook)
    except Exception as e:
        raise CursorError(f"bad JSON: {e}") from e
    if not isinstance(payload, dict):
        raise CursorError("cursor not a dict")
    try:
        return payload["f"], payload["d"], payload["v"]
    except KeyError as e:
        raise CursorError(f"missing key: {e}") from e


# ── Paginate helper ─────────────────────────────────────────


@dataclass
class CursorPage:
    items: list[Any]
    next_cursor: Optional[str]
    has_more: bool
    limit: int
    total_hint: Optional[int] = None   # Optional; expensive, use sparingly.

    def to_dict(self) -> dict:
        return {
            "data": self.items,
            "next_cursor": self.next_cursor,
            "has_more": self.has_more,
            "limit": self.limit,
            "total_hint": self.total_hint,
        }


def _field_name(order_field) -> str:
    """Extract a stable string name for a Column / InstrumentedAttribute."""
    # SQLAlchemy Column: order_field.name
    # InstrumentedAttribute: order_field.key
    for attr in ("key", "name"):
        v = getattr(order_field, attr, None)
        if isinstance(v, str) and v:
            return v
    return str(order_field)


def paginate(
    query: Query,
    *,
    order_field: Column,
    direction: str = "asc",
    limit: int = DEFAULT_LIMIT,
    cursor: Optional[str] = None,
) -> CursorPage:
    """Apply cursor pagination to a SQLAlchemy query.

    Rules:
      • direction ∈ {'asc', 'desc'}.
      • limit capped at MAX_LIMIT; floor at 1.
      • If cursor is given, it MUST match (order_field, direction) — a
        cursor produced for a different sort is ignored (raises).
      • Returns limit rows and sets has_more if more exist.

    The query passed in may already have .filter() / .options() applied —
    do NOT call .order_by() on it, this helper does.
    """
    limit = max(1, min(limit, MAX_LIMIT))

    field_name = _field_name(order_field)

    # Apply cursor filter, if any.
    if cursor:
        c_field, c_dir, c_val = decode_cursor(cursor)
        if c_field != field_name or c_dir != direction:
            raise CursorError(
                f"cursor is for ({c_field}, {c_dir}) but query is "
                f"({field_name}, {direction})"
            )
        # After filtering — strictly greater/less than the last value.
        if direction == "desc":
            query = query.filter(order_field < c_val)
        else:
            query = query.filter(order_field > c_val)

    # Ordering + fetch (limit + 1 to detect has_more).
    ordering = order_field.desc() if direction == "desc" else order_field.asc()
    rows = query.order_by(ordering).limit(limit + 1).all()

    has_more = len(rows) > limit
    items = rows[:limit]

    next_cursor: Optional[str] = None
    if has_more and items:
        last = items[-1]
        # Pull the field's value from the last row to encode the next cursor.
        last_value = getattr(last, field_name, None)
        next_cursor = encode_cursor(field_name, direction, last_value)

    return CursorPage(
        items=items,
        next_cursor=next_cursor,
        has_more=has_more,
        limit=limit,
    )


# ── FastAPI query-param helper ──────────────────────────────


def parse_pagination_query(
    cursor: Optional[str] = None,
    limit: Optional[int] = None,
) -> tuple[Optional[str], int]:
    """Normalise (?cursor, ?limit) query params with safe defaults.

    Usage:
        @router.get("/items")
        def list_items(cursor: str | None = None, limit: int | None = None):
            cursor, limit = parse_pagination_query(cursor, limit)
            ...
    """
    resolved_limit = DEFAULT_LIMIT if limit is None else limit
    resolved_limit = max(1, min(resolved_limit, MAX_LIMIT))
    return (cursor or None, resolved_limit)
