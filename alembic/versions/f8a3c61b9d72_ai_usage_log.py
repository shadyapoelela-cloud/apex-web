"""ai_usage_log — Claude token accounting per tenant

Adds `ai_usage_log`: append-only record of one Anthropic API call each.
Every Copilot agent turn records input/output tokens, estimated USD
cost, latency, and outcome so billing + ops dashboards can attribute
spend to tenants and catch prompt-loop runaways early.

Idempotent + cross-dialect (Postgres + SQLite) per the project's
existing migration pattern.

Revision ID: f8a3c61b9d72
Revises: e4c7d9f8a123
Create Date: 2026-04-24
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "f8a3c61b9d72"
down_revision: Union[str, None] = "e4c7d9f8a123"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(table: str) -> bool:
    insp = sa.inspect(op.get_bind())
    try:
        return table in insp.get_table_names()
    except Exception:
        return False


def upgrade() -> None:
    # If the table already exists (created via Base.metadata.create_all()
    # at startup before Alembic stamped HEAD), this migration is a no-op.
    if _has_table("ai_usage_log"):
        return

    op.create_table(
        "ai_usage_log",
        sa.Column("id", sa.String(length=36), primary_key=True, nullable=False),
        sa.Column("tenant_id", sa.String(length=36), nullable=True, index=True),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("surface", sa.String(length=40), nullable=False),
        sa.Column("model", sa.String(length=60), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("output_tokens", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cache_read_tokens", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cache_creation_tokens", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cost_usd", sa.Float(), nullable=False, server_default="0"),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
        sa.Column("agent_run_id", sa.String(length=36), nullable=True, index=True),
        sa.Column("turn_index", sa.Integer(), nullable=True),
        sa.Column("stop_reason", sa.String(length=40), nullable=True),
        sa.Column("error", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("error_kind", sa.String(length=60), nullable=True),
        sa.Column("extras", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )

    op.create_index(
        "ix_ai_usage_tenant_time",
        "ai_usage_log",
        ["tenant_id", "created_at"],
    )
    op.create_index("ix_ai_usage_surface", "ai_usage_log", ["surface"])
    op.create_index("ix_ai_usage_model", "ai_usage_log", ["model"])


def downgrade() -> None:
    if not _has_table("ai_usage_log"):
        return
    for idx in (
        "ix_ai_usage_model",
        "ix_ai_usage_surface",
        "ix_ai_usage_tenant_time",
    ):
        try:
            op.drop_index(idx, table_name="ai_usage_log")
        except Exception:
            pass
    op.drop_table("ai_usage_log")
