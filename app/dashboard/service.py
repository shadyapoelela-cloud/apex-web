"""Dashboard service layer — widget filtering, layout fallback, data dispatch.

Kept thin. Heavy lifting (BS/IS computation, AR aging, cashflow forecast)
lives in the existing routes/services modules referenced by `data_source`
strings; this module just dispatches and caches.

Public API (used by the FastAPI router + tests directly):

    list_widgets_for(user, db)              → list[DashboardWidget]
    get_effective_layout(user, db)          → DashboardLayout | None
    save_user_layout(user, blocks, db)      → DashboardLayout
    save_role_layout(role_id, blocks, db, is_locked) → DashboardLayout
    reset_user_layout(user, db)             → DashboardLayout
    compute_widget_data(code, ctx)          → dict
    compute_batch(codes, ctx)               → BatchDataResponse
    user_can(user, perm)                    → bool
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Awaitable, Callable, Optional

from sqlalchemy.orm import Session

from app.core.cache import get_cache, tenant_key
from app.dashboard.models import (
    DashboardDataCache,
    DashboardLayout,
    DashboardWidget,
    LayoutScope,
)
from app.dashboard.schemas import BatchDataResponse, LayoutBlock

logger = logging.getLogger(__name__)


# ── Permission helpers ────────────────────────────────────


def _user_perms(user: dict) -> set[str]:
    """Pull the user's effective permission strings out of a JWT payload.

    The JWT pattern in this codebase puts permissions either at
    `user["permissions"]` (custom_roles assignment) or under
    `user["role"]` (built-in role name — caller must resolve via
    custom_roles.role_permissions if needed).

    Defensive: returns an empty set when neither is present, rather
    than blowing up — callers are expected to compose with
    fallback paths (`read:dashboard` should always be granted to any
    authenticated user; the seed roles encode this).
    """
    raw = user.get("permissions") if user else None
    if isinstance(raw, list):
        return {str(p) for p in raw}
    if isinstance(raw, set):
        return {str(p) for p in raw}
    # Try to resolve a builtin role label.
    role = user.get("role") if user else None
    if role:
        try:
            from app.core.custom_roles import role_permissions  # lazy

            resolved = role_permissions(role)
            if resolved:
                return set(resolved)
        except Exception:  # noqa: BLE001
            pass
    return set()


def user_can(user: dict, perm: str) -> bool:
    """True if `user` has `perm`. `read:dashboard` is implicitly granted
    to any authenticated user — every authed caller can land on the
    dashboard, even if their role catalog is empty."""
    if not perm:
        return True
    if perm == "read:dashboard" and user is not None:
        return True
    return perm in _user_perms(user)


def filter_blocks_by_perms(
    user: dict, blocks: list[dict | LayoutBlock], widgets_by_code: dict[str, DashboardWidget]
) -> list[dict]:
    """Return only the blocks whose widget the user has all required perms for."""
    out: list[dict] = []
    for b in blocks:
        b_dict = b.model_dump() if isinstance(b, LayoutBlock) else dict(b)
        code = b_dict.get("widget_code")
        widget = widgets_by_code.get(code)
        if widget is None:
            continue
        required = list(widget.required_perms or [])
        if all(user_can(user, p) for p in required):
            out.append(b_dict)
    return out


# ── Catalog ────────────────────────────────────────────────


def list_widgets_for(user: dict, db: Session, tenant_id: Optional[str] = None) -> list[DashboardWidget]:
    """Return the widgets the user is allowed to see.

    Includes:
      - All system widgets (tenant_id IS NULL, is_enabled=True).
      - Tenant-scoped widgets owned by the caller's tenant.
      - Permission-filtered: any widget whose required_perms aren't
        all satisfied is dropped.
    """
    q = db.query(DashboardWidget).filter(DashboardWidget.is_enabled == True)  # noqa: E712
    rows = q.all()
    out: list[DashboardWidget] = []
    for w in rows:
        if w.tenant_id is not None and tenant_id is not None and w.tenant_id != tenant_id:
            continue
        if all(user_can(user, p) for p in (w.required_perms or [])):
            out.append(w)
    return out


# ── Layout fallback chain ─────────────────────────────────


def get_effective_layout(
    user: dict, db: Session, tenant_id: Optional[str] = None
) -> Optional[DashboardLayout]:
    """Resolve the layout the user should see.

    Order: user → role → tenant → system
    """
    user_id = user.get("user_id") or user.get("sub") if user else None
    role = user.get("role") if user else None

    # 1. user-scope
    if user_id:
        row = (
            db.query(DashboardLayout)
            .filter(
                DashboardLayout.scope == LayoutScope.USER,
                DashboardLayout.owner_id == user_id,
            )
            .order_by(DashboardLayout.is_default.desc(), DashboardLayout.updated_at.desc())
            .first()
        )
        if row:
            return row

    # 2. role-scope
    if role:
        row = (
            db.query(DashboardLayout)
            .filter(
                DashboardLayout.scope == LayoutScope.ROLE,
                DashboardLayout.owner_id == role,
            )
            .order_by(DashboardLayout.is_default.desc(), DashboardLayout.updated_at.desc())
            .first()
        )
        if row:
            return row

    # 3. tenant-scope
    if tenant_id:
        row = (
            db.query(DashboardLayout)
            .filter(
                DashboardLayout.scope == LayoutScope.TENANT,
                DashboardLayout.tenant_id == tenant_id,
            )
            .order_by(DashboardLayout.is_default.desc(), DashboardLayout.updated_at.desc())
            .first()
        )
        if row:
            return row

    # 4. system fallback
    return (
        db.query(DashboardLayout)
        .filter(DashboardLayout.scope == LayoutScope.SYSTEM)
        .order_by(DashboardLayout.is_default.desc(), DashboardLayout.updated_at.desc())
        .first()
    )


# ── Save / reset (with permission enforcement) ────────────


class PermissionDeniedError(Exception):
    """Raised when a caller tries to save a block they have no perm for."""


class LayoutLockedError(Exception):
    """Raised when a caller without lock:dashboard tries to overwrite a
    locked layout in the resolution chain."""


def _validate_blocks_against_perms(
    user: dict, blocks: list[LayoutBlock], db: Session
) -> None:
    """Raise PermissionDeniedError if any block references a widget
    whose required_perms the user can't satisfy."""
    codes = {b.widget_code for b in blocks}
    if not codes:
        return
    rows = db.query(DashboardWidget).filter(DashboardWidget.code.in_(codes)).all()
    by_code = {w.code: w for w in rows}
    for b in blocks:
        w = by_code.get(b.widget_code)
        if w is None:
            raise PermissionDeniedError(f"unknown widget: {b.widget_code}")
        if not all(user_can(user, p) for p in (w.required_perms or [])):
            raise PermissionDeniedError(
                f"missing required permission for {b.widget_code}"
            )


def save_user_layout(
    user: dict,
    blocks: list[LayoutBlock],
    db: Session,
    *,
    tenant_id: Optional[str] = None,
    name: str = "default",
) -> DashboardLayout:
    user_id = user.get("user_id") or user.get("sub")
    if not user_id:
        raise PermissionDeniedError("missing user_id in token")
    if not user_can(user, "customize:dashboard"):
        raise PermissionDeniedError("customize:dashboard required")

    # Honour upstream locks: if the role/tenant layout is locked and the
    # user lacks lock:dashboard, refuse the save.
    locked_upstream = (
        db.query(DashboardLayout)
        .filter(
            DashboardLayout.is_locked == True,  # noqa: E712
            DashboardLayout.scope.in_([LayoutScope.ROLE, LayoutScope.TENANT]),
        )
        .first()
    )
    if locked_upstream and not user_can(user, "lock:dashboard"):
        # Only block when the locked upstream actually applies to this user.
        applies = (
            (locked_upstream.scope == LayoutScope.ROLE and locked_upstream.owner_id == user.get("role"))
            or (locked_upstream.scope == LayoutScope.TENANT and locked_upstream.tenant_id == tenant_id)
        )
        if applies:
            raise LayoutLockedError("upstream layout is locked")

    _validate_blocks_against_perms(user, blocks, db)

    row = (
        db.query(DashboardLayout)
        .filter(
            DashboardLayout.scope == LayoutScope.USER,
            DashboardLayout.owner_id == user_id,
            DashboardLayout.name == name,
        )
        .first()
    )
    blocks_payload = [b.model_dump() for b in blocks]
    if row:
        row.blocks = blocks_payload
        row.version = (row.version or 1) + 1
        row.updated_at = datetime.now(timezone.utc)
    else:
        row = DashboardLayout(
            id=str(uuid.uuid4()),
            tenant_id=tenant_id,
            scope=LayoutScope.USER,
            owner_id=user_id,
            name=name,
            blocks=blocks_payload,
            is_default=True,
        )
        db.add(row)
    db.commit()
    db.refresh(row)
    return row


def save_role_layout(
    user: dict,
    role_id: str,
    blocks: list[LayoutBlock],
    db: Session,
    *,
    tenant_id: Optional[str] = None,
    name: str = "default",
    is_locked: Optional[bool] = None,
) -> DashboardLayout:
    if not user_can(user, "manage:dashboard_role"):
        raise PermissionDeniedError("manage:dashboard_role required")
    _validate_blocks_against_perms(user, blocks, db)

    row = (
        db.query(DashboardLayout)
        .filter(
            DashboardLayout.scope == LayoutScope.ROLE,
            DashboardLayout.owner_id == role_id,
            DashboardLayout.name == name,
        )
        .first()
    )
    blocks_payload = [b.model_dump() for b in blocks]
    if row:
        row.blocks = blocks_payload
        row.version = (row.version or 1) + 1
        row.updated_at = datetime.now(timezone.utc)
        if is_locked is not None:
            if not user_can(user, "lock:dashboard"):
                raise PermissionDeniedError("lock:dashboard required to toggle lock")
            row.is_locked = is_locked
    else:
        row = DashboardLayout(
            id=str(uuid.uuid4()),
            tenant_id=tenant_id,
            scope=LayoutScope.ROLE,
            owner_id=role_id,
            name=name,
            blocks=blocks_payload,
            is_default=True,
            is_locked=bool(is_locked),
        )
        db.add(row)
    db.commit()
    db.refresh(row)
    return row


def set_role_layout_lock(
    user: dict, role_id: str, is_locked: bool, db: Session
) -> DashboardLayout:
    if not user_can(user, "lock:dashboard"):
        raise PermissionDeniedError("lock:dashboard required")
    row = (
        db.query(DashboardLayout)
        .filter(
            DashboardLayout.scope == LayoutScope.ROLE,
            DashboardLayout.owner_id == role_id,
        )
        .first()
    )
    if row is None:
        raise PermissionDeniedError(f"no role layout for {role_id}")
    row.is_locked = is_locked
    row.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(row)
    return row


def reset_user_layout(user: dict, db: Session) -> Optional[DashboardLayout]:
    """Delete the user's personal layout, falling back to role/tenant/system."""
    user_id = user.get("user_id") or user.get("sub")
    if not user_id:
        raise PermissionDeniedError("missing user_id in token")
    rows = (
        db.query(DashboardLayout)
        .filter(
            DashboardLayout.scope == LayoutScope.USER,
            DashboardLayout.owner_id == user_id,
        )
        .all()
    )
    for r in rows:
        db.delete(r)
    db.commit()
    return get_effective_layout(user, db)


# ── Data dispatcher ───────────────────────────────────────


# Per-widget resolver registry. compute_widget_data dispatches by code.
# Each resolver takes (ctx: dict) and returns a JSON-able payload.
WidgetResolver = Callable[[dict], Any]
_RESOLVERS: dict[str, WidgetResolver] = {}


def register_resolver(code: str, fn: WidgetResolver) -> None:
    """Register a resolver for a widget_code. Idempotent."""
    _RESOLVERS[code] = fn


def has_resolver(code: str) -> bool:
    return code in _RESOLVERS


def compute_cache_key(code: str, ctx: dict) -> str:
    """Deterministic cache key for (tenant, widget_code, ctx)."""
    tid = ctx.get("tenant_id") or "system"
    payload = json.dumps(
        {"code": code, "ctx": {k: ctx.get(k) for k in ("entity_id", "as_of_date") if k in ctx}},
        default=str,
        sort_keys=True,
    )
    digest = hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]
    return f"dash:{tid}:{code}:{digest}"


def compute_widget_data(code: str, ctx: dict, *, db: Optional[Session] = None) -> Any:
    """Dispatch to the registered resolver, with TTL cache.

    Returns the payload directly (not wrapped) — callers wrap into the
    `{success, data}` envelope at the API layer.
    """
    key = compute_cache_key(code, ctx)
    cache = get_cache()
    hit = cache.get(key)
    if hit is not None:
        return hit
    resolver = _RESOLVERS.get(code)
    if resolver is None:
        raise KeyError(f"no resolver for widget: {code}")
    payload = resolver(ctx)
    # Honour widget refresh_secs if available — fall back to 60s.
    ttl = ctx.get("__ttl_override") or 60
    if db is not None:
        widget = db.query(DashboardWidget).filter(DashboardWidget.code == code).first()
        if widget is not None and widget.refresh_secs:
            ttl = widget.refresh_secs
    if ttl and ttl > 0:
        cache.set(key, payload, ttl)
        # Mirror to durable snapshot table for SSE replay.
        if db is not None:
            try:
                expires = datetime.now(timezone.utc) + timedelta(seconds=ttl)
                row = db.query(DashboardDataCache).filter(
                    DashboardDataCache.cache_key == key
                ).first()
                if row is None:
                    row = DashboardDataCache(
                        cache_key=key,
                        payload=payload,
                        expires_at=expires,
                    )
                    db.add(row)
                else:
                    row.payload = payload
                    row.computed_at = datetime.now(timezone.utc)
                    row.expires_at = expires
                db.commit()
            except Exception as e:  # noqa: BLE001
                logger.warning("dashboard cache mirror failed: %s", e)
                db.rollback()
    return payload


def compute_batch(
    codes: list[str], ctx: dict, *, db: Optional[Session] = None, user: Optional[dict] = None
) -> BatchDataResponse:
    """Compute many widgets in one call. Errors are returned per-widget
    rather than failing the whole batch — keeps the dashboard partially
    usable when one source is down.
    """
    data: dict[str, Any] = {}
    errors: dict[str, str] = {}

    # Permission filtering: if user is provided, drop codes the user
    # can't see and surface them as `permission_denied` so the UI can
    # render a placeholder.
    permitted: list[str] = []
    if user is not None and db is not None:
        rows = (
            db.query(DashboardWidget)
            .filter(DashboardWidget.code.in_(codes))
            .all()
        )
        by_code = {w.code: w for w in rows}
        for c in codes:
            w = by_code.get(c)
            if w is None:
                errors[c] = "unknown_widget"
                continue
            if not all(user_can(user, p) for p in (w.required_perms or [])):
                errors[c] = "permission_denied"
                continue
            permitted.append(c)
    else:
        permitted = list(codes)

    for code in permitted:
        try:
            data[code] = compute_widget_data(code, ctx, db=db)
        except KeyError as e:
            errors[code] = "no_resolver"
        except Exception as e:  # noqa: BLE001
            logger.warning("widget %s compute failed: %s", code, e)
            errors[code] = "compute_failed"

    return BatchDataResponse(
        computed_at=datetime.now(timezone.utc),
        data=data,
        errors=errors,
    )


async def compute_batch_async(
    codes: list[str], ctx: dict, *, db: Optional[Session] = None, user: Optional[dict] = None
) -> BatchDataResponse:
    """asyncio.gather variant for parallel resolver execution.

    Each resolver runs in a threadpool because the existing data
    sources are sync — we don't fork them into async right now.
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, compute_batch, codes, ctx, db, user)


# ── Cache invalidation hooks ──────────────────────────────


def invalidate_widget(code: str, ctx: Optional[dict] = None) -> None:
    """Drop a widget's cached payload (memory + durable snapshot)."""
    cache = get_cache()
    if ctx is None:
        ctx = {}
    key = compute_cache_key(code, ctx)
    cache.delete(key)


def invalidate_codes(codes: list[str], ctx: Optional[dict] = None) -> None:
    for c in codes:
        invalidate_widget(c, ctx)


__all__ = [
    "PermissionDeniedError",
    "LayoutLockedError",
    "user_can",
    "filter_blocks_by_perms",
    "list_widgets_for",
    "get_effective_layout",
    "save_user_layout",
    "save_role_layout",
    "set_role_layout_lock",
    "reset_user_layout",
    "register_resolver",
    "has_resolver",
    "compute_widget_data",
    "compute_batch",
    "compute_batch_async",
    "compute_cache_key",
    "invalidate_widget",
    "invalidate_codes",
]
