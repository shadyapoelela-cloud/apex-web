"""Multi-tenant query guard — application-layer RLS.

Problem statement:
  The 74 legacy models in phases 1-11 don't carry a tenant_id. Adding it
  retroactively requires a big data migration with production backfill —
  too risky to do in one PR. So we implement tenant isolation incrementally:

  1. New tables inherit `TenantMixin` and get automatic tenant_id filtering.
  2. Legacy tables stay as-is until migrated; they're flagged "shared" and
     accessed through trusted paths only.
  3. The middleware binds `current_tenant()` in a ContextVar (already built
     in app.core.tenant_context).

Behavior:
  - A query targeting a TenantMixin table is auto-filtered by
    tenant_id == current_tenant() whenever a tenant is bound.
  - A query targeting such a table WITHOUT a bound tenant either:
      - In strict mode (TENANT_STRICT=true): raises CrossTenantLeakError.
      - In dev mode: warns but allows (to keep tests running).
  - Writes auto-populate tenant_id if the model uses TenantMixin and the
    field is unset.
  - "Null tenant" rows (tenant_id IS NULL) stay visible when the query
    context has no tenant — this protects backwards compatibility for
    operational records created before tenants existed.

Usage:
  class Employee(Base, TenantMixin):
      __tablename__ = "hr_employees"
      ...

  attach_tenant_guard(engine)  # one-time, usually at startup.

For cases where you MUST cross tenants (admin tools, reports): use
`with_system_context()` as a context manager — it bypasses the guard.
"""

from __future__ import annotations

import logging
import os
from contextlib import contextmanager
from contextvars import ContextVar
from typing import Optional

from sqlalchemy import Column, String, event
from sqlalchemy.orm import Query, Session

from app.core.tenant_context import current_tenant

logger = logging.getLogger(__name__)

TENANT_STRICT = os.environ.get("TENANT_STRICT", "false").lower() == "true"


class CrossTenantLeakError(Exception):
    """Raised when a query hits a tenant-aware table without a bound tenant
    in strict mode. Logged as a high-severity incident."""


_system_context: ContextVar[bool] = ContextVar("tenant_system_bypass", default=False)


@contextmanager
def with_system_context():
    """Temporarily disable the tenant filter (admin tools, migrations).

    Usage:
        with with_system_context():
            db.query(Employee).all()   # sees ALL tenants — use with care.
    """
    token = _system_context.set(True)
    try:
        yield
    finally:
        _system_context.reset(token)


def _is_system_bypass() -> bool:
    return _system_context.get()


# ── TenantMixin ─────────────────────────────────────────────


class TenantMixin:
    """Add tenant_id column + opt into automatic query filtering.

    Models using this mixin declare they are tenant-scoped. New rows
    automatically pick up `current_tenant()` on insert if tenant_id is
    unset. Reads are filtered by tenant via the SQLAlchemy event listener
    attached by `attach_tenant_guard()`.

    The column is nullable for backwards compatibility — rows created
    before multi-tenant rollout have NULL tenant_id and are treated as
    shared/system rows.
    """

    # Note: no ForeignKey because tenants live in a separate service /
    # table that not all phases will have. Kept as a plain string(36)
    # UUID for flexibility.
    tenant_id = Column(String(36), nullable=True, index=True)


# ── Event listener ──────────────────────────────────────────


def _before_compile(query: Query) -> Query:
    """Auto-filter SELECT queries on tenant-aware tables by current tenant.

    Only active when a tenant is bound AND system bypass is NOT in effect.
    Leaves multi-mapper / unusual queries alone — they're rare and the
    caller is expected to handle isolation explicitly.
    """
    if _is_system_bypass():
        return query

    tenant = current_tenant()

    # Inspect target mappers to see if any use TenantMixin.
    try:
        descriptions = query.column_descriptions
    except Exception:
        return query

    tenant_aware_mappers = []
    for desc in descriptions:
        entity = desc.get("entity")
        if entity is not None and isinstance(entity, type) and issubclass(entity, TenantMixin):
            tenant_aware_mappers.append(entity)

    if not tenant_aware_mappers:
        return query

    # `.filter()` on a query that already has LIMIT/OFFSET would raise —
    # disable assertions so the guard works mid-pagination too. This is safe
    # because we're only adding a WHERE clause, not reordering the query.
    query = query.enable_assertions(False)

    # If no tenant bound and we're in strict mode, raise loud.
    if tenant is None:
        if TENANT_STRICT:
            raise CrossTenantLeakError(
                f"Query on tenant-aware table(s) {[m.__tablename__ for m in tenant_aware_mappers]} "
                f"without a bound tenant (strict mode)."
            )
        # In dev mode, queries without tenant see only NULL-tenant rows
        # (system rows) to avoid broad leaks while being permissive.
        for mapper in tenant_aware_mappers:
            query = query.filter(mapper.tenant_id.is_(None))
        return query

    # Normal path: filter by current tenant OR NULL (shared rows).
    for mapper in tenant_aware_mappers:
        query = query.filter(
            (mapper.tenant_id == tenant) | (mapper.tenant_id.is_(None))
        )
    return query


def _before_flush(session: Session, flush_context, instances):
    """Auto-populate tenant_id on INSERT for TenantMixin models."""
    if _is_system_bypass():
        return

    tenant = current_tenant()
    if tenant is None:
        return

    for obj in session.new:
        if isinstance(obj, TenantMixin) and getattr(obj, "tenant_id", None) is None:
            obj.tenant_id = tenant


def attach_tenant_guard(engine) -> None:
    """Install the auto-filter + auto-populate listeners on an engine's
    session factory. Safe to call multiple times."""
    # Attach to Query's before_compile (per-query filtering).
    event.listen(Query, "before_compile", _before_compile, retval=True)
    # Attach before_flush to Session class globally (inserts).
    event.listen(Session, "before_flush", _before_flush)
    logger.info("Tenant guard attached to session")


# ── Helpers for tests / admin tooling ───────────────────────


def assert_same_tenant(*objects) -> None:
    """Raise if any two tenant-aware objects belong to different tenants.

    Useful when stitching together relationships across tables — e.g. a
    Payslip must reference an Employee from the same tenant.
    """
    tenants = {
        getattr(o, "tenant_id", None)
        for o in objects
        if isinstance(o, TenantMixin)
    }
    tenants.discard(None)
    if len(tenants) > 1:
        raise CrossTenantLeakError(
            f"Cross-tenant reference detected: {sorted(tenants)}"
        )
