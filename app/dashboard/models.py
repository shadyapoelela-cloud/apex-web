"""Dashboard data model — widget catalog, layouts, and snapshot cache.

Three tables:

    dashboard_widgets        — system+tenant catalog of available widgets.
    dashboard_layouts        — per-user / per-role / per-tenant arrangements.
    dashboard_data_cache     — short-lived snapshots used to back SSE pushes
                                without re-running compute on every reconnect.

All three live on `PhaseBase` from app.phase1.models.platform_models so
alembic autogenerate picks them up via the `_MODEL_MODULES` registry in
alembic/env.py.

Persistence pattern follows app/core/saved_views.py — same
`(tenant, scope, owner, name)` uniqueness shape, JSON payloads,
TenantMixin for automatic tenant filtering on read.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Index,
    Integer,
    String,
    UniqueConstraint,
)

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base


# ── Layout scopes ─────────────────────────────────────────


class LayoutScope:
    """Allowed values for `DashboardLayout.scope`.

    `user` — owned by a single user_id, overrides role/tenant.
    `role` — applies to every user with that custom_role/builtin role,
             unless they have a `user`-scope layout that wins.
    `tenant` — fallback for everyone in the tenant when no user/role
               layout is present.
    `system` — frozen seeded defaults, never edited at runtime.
    """

    USER = "user"
    ROLE = "role"
    TENANT = "tenant"
    SYSTEM = "system"

    ALL = (USER, ROLE, TENANT, SYSTEM)


class WidgetType:
    """Allowed values for `DashboardWidget.widget_type`.

    The frontend renderer registry switches on this string.
    """

    KPI = "kpi"
    CHART = "chart"
    TABLE = "table"
    LIST = "list"
    AI = "ai"
    ACTION = "action"
    CUSTOM = "custom"

    ALL = (KPI, CHART, TABLE, LIST, AI, ACTION, CUSTOM)


# ── Widget catalog ────────────────────────────────────────


class DashboardWidget(Base, TenantMixin):
    """The catalog of widgets a tenant can place on a dashboard.

    `is_system=True` rows are seeded once and shared across tenants
    (tenant_id is NULL). Tenants can add their own catalog entries
    with is_system=False — those carry tenant_id so cross-tenant
    leakage is impossible by construction.
    """

    __tablename__ = "dashboard_widgets"
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_dashboard_widget_code"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    code = Column(String(120), nullable=False, index=True)

    title_ar = Column(String(160), nullable=False)
    title_en = Column(String(160), nullable=False)
    description_ar = Column(String(400), nullable=True)
    description_en = Column(String(400), nullable=True)

    category = Column(String(64), nullable=False, default="general")
    widget_type = Column(String(16), nullable=False)  # see WidgetType
    data_source = Column(String(200), nullable=True)  # logical key resolved by service

    default_span = Column(Integer, nullable=False, default=4)  # in 12-col grid units
    min_span = Column(Integer, nullable=False, default=2)
    max_span = Column(Integer, nullable=False, default=12)

    required_perms = Column(JSON, nullable=False, default=list)  # list[str]
    config_schema = Column(JSON, nullable=True)  # JSON-schema for per-block config
    refresh_secs = Column(Integer, nullable=False, default=60)  # 0 = no auto refresh

    is_system = Column(Boolean, nullable=False, default=False)
    is_enabled = Column(Boolean, nullable=False, default=True)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


# ── Layout / arrangement ──────────────────────────────────


class DashboardLayout(Base, TenantMixin):
    """A named arrangement of widgets.

    `blocks` is a JSON array of objects:
        {
          "id": "<block-uuid>",
          "widget_code": "kpi.cash_balance",
          "span": 3,            # 1-12 grid units
          "x": 0, "y": 0,       # position in dashboard grid
          "config": { ... }     # widget-specific config (see config_schema)
        }

    Fallback chain at lookup time (service.get_effective_layout):
        user > role > tenant > system

    `is_locked=True` forbids users with only `customize:dashboard`
    (without `lock:dashboard`) from saving over this row's scope.
    """

    __tablename__ = "dashboard_layouts"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "scope", "owner_id", "name",
            name="uq_dashboard_layout_scope",
        ),
        Index("ix_dashboard_layouts_owner", "scope", "owner_id"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    scope = Column(String(16), nullable=False)  # see LayoutScope
    owner_id = Column(String(120), nullable=True, index=True)
    # ^ user_id when scope=user; role_id when scope=role; NULL when scope=tenant.

    name = Column(String(120), nullable=False, default="default")
    blocks = Column(JSON, nullable=False, default=list)

    is_default = Column(Boolean, nullable=False, default=False)
    is_locked = Column(Boolean, nullable=False, default=False)
    version = Column(Integer, nullable=False, default=1)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


# ── Snapshot cache ────────────────────────────────────────


class DashboardDataCache(Base):
    """Short-lived widget payload snapshots.

    Distinct from app.core.cache:
      - app.core.cache is process-local (or Redis) and ephemeral.
      - This table is the durable "last known good" payload that SSE
        replays on reconnect, and that diff-cover can audit.

    Keyed by a deterministic cache_key built by service.compute_cache_key()
    so two parallel computes for the same (tenant, widget, args) collapse
    to one row.
    """

    __tablename__ = "dashboard_data_cache"
    __table_args__ = (Index("ix_dashboard_cache_expiry", "expires_at"),)

    cache_key = Column(String(256), primary_key=True)
    payload = Column(JSON, nullable=False)
    computed_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)


__all__ = [
    "LayoutScope",
    "WidgetType",
    "DashboardWidget",
    "DashboardLayout",
    "DashboardDataCache",
]
