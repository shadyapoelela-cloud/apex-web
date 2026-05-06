"""coa_chart_templates_changelog

CoA-1, Sprint 17 — adds 3 tables for the canonical Chart of Accounts:

    chart_of_accounts   — 4-level hierarchy (entity-scoped)
    coa_templates       — packaged standard charts (SOCPA, IFRS, GAAP)
    coa_change_log      — audit-grade row-level history

Hand-written, idempotent — same pattern as
`alembic/versions/h2c5e8f1a4b7_dashboard_widgets_layouts_cache.py` (the
DASH-1 hotfix). Each `op.create_table` is gated on
`inspect().has_table(...)` so the migration survives the
`create_all() → alembic-stamp` transition that bit prod after PR #156.

Revision ID: i3d9f6c2e8a5
Revises: h2c5e8f1a4b7
Create Date: 2026-05-06
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect


# ── Identifiers ────────────────────────────────────────────


revision: str = "i3d9f6c2e8a5"
down_revision: Union[str, None] = "h2c5e8f1a4b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ── Idempotency helpers ───────────────────────────────────


def _table_exists(table_name: str) -> bool:
    return inspect(op.get_bind()).has_table(table_name)


def _index_exists(table_name: str, index_name: str) -> bool:
    try:
        existing = {ix["name"] for ix in inspect(op.get_bind()).get_indexes(table_name)}
    except Exception:  # noqa: BLE001 — table may not exist yet
        return False
    return index_name in existing


# ── Upgrade ──────────────────────────────────────────────


def upgrade() -> None:
    # ── chart_of_accounts ────────────────────────────────
    if not _table_exists("chart_of_accounts"):
        op.create_table(
            "chart_of_accounts",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("entity_id", sa.String(length=36), nullable=False),
            sa.Column("account_code", sa.String(length=40), nullable=False),
            sa.Column("parent_id", sa.String(length=36), nullable=True),
            sa.Column("level", sa.Integer(), nullable=False),
            sa.Column("full_path", sa.String(length=400), nullable=False),
            sa.Column("name_ar", sa.String(length=200), nullable=False),
            sa.Column("name_en", sa.String(length=200), nullable=True),
            sa.Column("account_class", sa.String(length=20), nullable=False),
            sa.Column("account_type", sa.String(length=40), nullable=False),
            sa.Column("normal_balance", sa.String(length=10), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.Column("is_system", sa.Boolean(), nullable=False),
            sa.Column("is_postable", sa.Boolean(), nullable=False),
            sa.Column("is_reconcilable", sa.Boolean(), nullable=False),
            sa.Column("requires_cost_center", sa.Boolean(), nullable=False),
            sa.Column("requires_project", sa.Boolean(), nullable=False),
            sa.Column("requires_partner", sa.Boolean(), nullable=False),
            sa.Column("default_tax_rate", sa.String(length=20), nullable=True),
            sa.Column("standard_ref", sa.String(length=40), nullable=True),
            sa.Column("currency_code", sa.String(length=3), nullable=True),
            sa.Column("tags", sa.JSON(), nullable=False),
            sa.Column("custom_fields", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_by", sa.String(length=36), nullable=True),
            sa.ForeignKeyConstraint(
                ["parent_id"],
                ["chart_of_accounts.id"],
                ondelete="SET NULL",
            ),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint(
                "tenant_id", "entity_id", "account_code",
                name="uq_coa_account_code",
            ),
        )

    for ix_name, cols in (
        ("ix_coa_parent", ["parent_id"]),
        ("ix_coa_path", ["full_path"]),
        ("ix_coa_class_active", ["account_class", "is_active"]),
        ("ix_coa_entity", ["entity_id"]),
    ):
        if not _index_exists("chart_of_accounts", ix_name):
            op.create_index(ix_name, "chart_of_accounts", cols, unique=False)

    if not _index_exists("chart_of_accounts", "ix_chart_of_accounts_tenant_id"):
        op.create_index(
            op.f("ix_chart_of_accounts_tenant_id"),
            "chart_of_accounts",
            ["tenant_id"],
            unique=False,
        )

    # ── coa_templates ────────────────────────────────────
    if not _table_exists("coa_templates"):
        op.create_table(
            "coa_templates",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("code", sa.String(length=40), nullable=False),
            sa.Column("name_ar", sa.String(length=160), nullable=False),
            sa.Column("name_en", sa.String(length=160), nullable=True),
            sa.Column("description_ar", sa.String(length=400), nullable=True),
            sa.Column("description_en", sa.String(length=400), nullable=True),
            sa.Column("standard", sa.String(length=20), nullable=False),
            sa.Column("industry", sa.String(length=40), nullable=True),
            sa.Column("accounts", sa.JSON(), nullable=False),
            sa.Column("account_count", sa.Integer(), nullable=False),
            sa.Column("is_official", sa.Boolean(), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("tenant_id", "code", name="uq_coa_template_code"),
        )
    if not _index_exists("coa_templates", "ix_coa_template_standard"):
        op.create_index(
            "ix_coa_template_standard", "coa_templates", ["standard"], unique=False
        )
    if not _index_exists("coa_templates", "ix_coa_templates_code"):
        op.create_index(
            op.f("ix_coa_templates_code"), "coa_templates", ["code"], unique=False
        )
    if not _index_exists("coa_templates", "ix_coa_templates_tenant_id"):
        op.create_index(
            op.f("ix_coa_templates_tenant_id"),
            "coa_templates",
            ["tenant_id"],
            unique=False,
        )

    # ── coa_change_log ───────────────────────────────────
    if not _table_exists("coa_change_log"):
        op.create_table(
            "coa_change_log",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("tenant_id", sa.String(length=36), nullable=True),
            sa.Column("account_id", sa.String(length=36), nullable=True),
            sa.Column("action", sa.String(length=20), nullable=False),
            sa.Column("diff", sa.JSON(), nullable=False),
            sa.Column("user_id", sa.String(length=36), nullable=True),
            sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
            sa.Column("reason", sa.String(length=400), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
    for ix_name, cols in (
        ("ix_coa_changelog_account", ["account_id", "timestamp"]),
        ("ix_coa_changelog_user", ["user_id", "timestamp"]),
        ("ix_coa_changelog_action", ["action"]),
    ):
        if not _index_exists("coa_change_log", ix_name):
            op.create_index(ix_name, "coa_change_log", cols, unique=False)

    if not _index_exists("coa_change_log", "ix_coa_change_log_account_id"):
        op.create_index(
            op.f("ix_coa_change_log_account_id"),
            "coa_change_log",
            ["account_id"],
            unique=False,
        )
    if not _index_exists("coa_change_log", "ix_coa_change_log_tenant_id"):
        op.create_index(
            op.f("ix_coa_change_log_tenant_id"),
            "coa_change_log",
            ["tenant_id"],
            unique=False,
        )


# ── Downgrade ────────────────────────────────────────────


def downgrade() -> None:
    if _table_exists("coa_change_log"):
        for ix in (
            "ix_coa_change_log_tenant_id",
            "ix_coa_change_log_account_id",
            "ix_coa_changelog_action",
            "ix_coa_changelog_user",
            "ix_coa_changelog_account",
        ):
            if _index_exists("coa_change_log", ix):
                op.drop_index(ix, table_name="coa_change_log")
        op.drop_table("coa_change_log")

    if _table_exists("coa_templates"):
        for ix in (
            "ix_coa_templates_tenant_id",
            "ix_coa_templates_code",
            "ix_coa_template_standard",
        ):
            if _index_exists("coa_templates", ix):
                op.drop_index(ix, table_name="coa_templates")
        op.drop_table("coa_templates")

    if _table_exists("chart_of_accounts"):
        for ix in (
            "ix_chart_of_accounts_tenant_id",
            "ix_coa_entity",
            "ix_coa_class_active",
            "ix_coa_path",
            "ix_coa_parent",
        ):
            if _index_exists("chart_of_accounts", ix):
                op.drop_index(ix, table_name="chart_of_accounts")
        op.drop_table("chart_of_accounts")
