"""Chart of Accounts ORM models (CoA-1, Sprint 17).

Three tables:

    chart_of_accounts   — the canonical 4-level account hierarchy
    coa_templates       — packaged standard charts (SOCPA, IFRS, ...)
    coa_change_log      — audit-grade row-level change history

All three live on `PhaseBase` from app.phase1.models.platform_models so
alembic autogenerate picks them up via `_MODEL_MODULES` in
alembic/env.py.

Persistence pattern follows app.dashboard.models — UUID PKs, JSON
metadata fields, TenantMixin for automatic tenant filtering on read.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base


# ── Enum-like string constants ────────────────────────────


class AccountClass:
    """The five top-level GAAP/IFRS classes. Stored as strings for forward-compat."""

    ASSET = "asset"
    LIABILITY = "liability"
    EQUITY = "equity"
    REVENUE = "revenue"
    EXPENSE = "expense"

    ALL = (ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE)


class AccountAction:
    """The set of actions captured in `coa_change_log.action`."""

    CREATE = "create"
    UPDATE = "update"
    DEACTIVATE = "deactivate"
    REACTIVATE = "reactivate"
    DELETE = "delete"
    MERGE = "merge"
    SPLIT = "split"
    IMPORT_TEMPLATE = "import_template"

    ALL = (CREATE, UPDATE, DEACTIVATE, REACTIVATE, DELETE, MERGE, SPLIT, IMPORT_TEMPLATE)


class NormalBalance:
    DEBIT = "debit"
    CREDIT = "credit"
    ALL = (DEBIT, CREDIT)


# ── Chart of Accounts ─────────────────────────────────────


class ChartOfAccount(Base, TenantMixin):
    """One row per account in the canonical chart.

    `full_path` is denormalised dot-separated lineage (e.g. ``1.11.110.1110``)
    so tree queries don't need recursive CTEs at read time. The service
    layer recomputes `full_path` for the row + every descendant when
    `parent_id` changes.

    `is_postable=False` rows are non-leaf aggregators (header rows in
    reports). `is_reconcilable=True` flags AR / AP / Bank — used by
    reconciliation tooling.

    The four `requires_*` flags are dimensional-tracking gates: when
    True, a journal line referencing this account MUST also carry the
    matching dimension (cost_center / project / partner). Wiring them
    into the GL posting validator is tracked as a follow-up.
    """

    __tablename__ = "chart_of_accounts"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "entity_id", "account_code",
            name="uq_coa_account_code",
        ),
        Index("ix_coa_parent", "parent_id"),
        Index("ix_coa_path", "full_path"),
        Index("ix_coa_class_active", "account_class", "is_active"),
        Index("ix_coa_entity", "entity_id"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    entity_id = Column(String(36), nullable=False, index=True)

    # Numbering / hierarchy
    account_code = Column(String(40), nullable=False)
    parent_id = Column(
        String(36),
        ForeignKey("chart_of_accounts.id", ondelete="SET NULL"),
        nullable=True,
    )
    level = Column(Integer, nullable=False, default=1)
    full_path = Column(String(400), nullable=False, default="")

    # Bilingual names
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)

    # Accounting classification
    account_class = Column(String(20), nullable=False)
    account_type = Column(String(40), nullable=False)
    normal_balance = Column(String(10), nullable=False)

    # State + posting rules
    is_active = Column(Boolean, nullable=False, default=True)
    is_system = Column(Boolean, nullable=False, default=False)
    is_postable = Column(Boolean, nullable=False, default=True)
    is_reconcilable = Column(Boolean, nullable=False, default=False)

    # Dimensional-tracking gates
    requires_cost_center = Column(Boolean, nullable=False, default=False)
    requires_project = Column(Boolean, nullable=False, default=False)
    requires_partner = Column(Boolean, nullable=False, default=False)

    # Tax + standard
    default_tax_rate = Column(String(20), nullable=True)
    standard_ref = Column(String(40), nullable=True)

    # Currency (NULL = multi-currency)
    currency_code = Column(String(3), nullable=True)

    # Free-form metadata
    tags = Column(JSON, nullable=False, default=list)
    custom_fields = Column(JSON, nullable=False, default=dict)

    # Audit
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
    created_by = Column(String(36), nullable=True)

    # Relationships
    parent = relationship(
        "ChartOfAccount",
        remote_side=[id],
        backref="children",
    )


# ── Templates ─────────────────────────────────────────────


class AccountTemplate(Base, TenantMixin):
    """Packaged standard charts (SOCPA-Retail, IFRS-Services, etc.).

    `accounts` is a JSON array of dicts mirroring `ChartOfAccount` field
    shapes (minus tenant/entity/id; the importer fills those at import
    time). Templates with `is_official=True` are seeded by the platform;
    tenants can register their own custom templates with `is_official=False`
    and a non-NULL `tenant_id`.
    """

    __tablename__ = "coa_templates"
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_coa_template_code"),
        Index("ix_coa_template_standard", "standard"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    code = Column(String(40), nullable=False, index=True)
    name_ar = Column(String(160), nullable=False)
    name_en = Column(String(160), nullable=True)
    description_ar = Column(String(400), nullable=True)
    description_en = Column(String(400), nullable=True)

    standard = Column(String(20), nullable=False)  # socpa | ifrs | gaap
    industry = Column(String(40), nullable=True)  # retail | services | manufacturing | saas

    accounts = Column(JSON, nullable=False, default=list)
    account_count = Column(Integer, nullable=False, default=0)

    is_official = Column(Boolean, nullable=False, default=False)
    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


# ── Audit / Change Log ────────────────────────────────────


class AccountChangeLog(Base, TenantMixin):
    """Append-only audit log for every CoA write.

    `diff` is a JSON object mapping each touched field to
    ``{"old": ..., "new": ...}`` for UPDATE rows. CREATE rows omit
    `old`; DELETE rows omit `new`. MERGE rows include
    ``{"merged_into": "<target-id>"}`` on the source row.

    Indexed on `(account_id, timestamp)` so the per-account changelog
    UI fetches in O(log n).
    """

    __tablename__ = "coa_change_log"
    __table_args__ = (
        Index("ix_coa_changelog_account", "account_id", "timestamp"),
        Index("ix_coa_changelog_user", "user_id", "timestamp"),
        Index("ix_coa_changelog_action", "action"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    account_id = Column(String(36), nullable=True, index=True)
    # Nullable because IMPORT_TEMPLATE rows may write a single log entry
    # representing the bulk import without a single account_id.

    action = Column(String(20), nullable=False)
    diff = Column(JSON, nullable=False, default=dict)

    user_id = Column(String(36), nullable=True)
    timestamp = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    reason = Column(String(400), nullable=True)


__all__ = [
    "AccountClass",
    "AccountAction",
    "NormalBalance",
    "ChartOfAccount",
    "AccountTemplate",
    "AccountChangeLog",
]
