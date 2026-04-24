"""SAP-style Universal Journal: dimensions + ledger_id on journal_lines

Adds two SAP-inspired columns to `pilot_journal_lines`:

  • ledger_id (String 20) — default 'L1'. Supports parallel ledgers
    (IFRS + local GAAP + tax) by letting the same posting live under
    multiple ledger IDs with different valuations. This is SAP ACDOCA's
    defining architectural choice.

  • dimensions (JSONB / JSON) — free-form tag map per line:
    {"project": "P-001", "department": "SALES",
     "cost_center": "CC-100", "profit_center": "PC-05"}
    Replaces the SMB anti-pattern of encoding dimensions into account
    codes. Line-level means each row can be sliced by any dimension.
    The existing cost_center_id / profit_center_id / project_id /
    segment_id / branch_id columns remain for back-compat; the JSONB
    provides extension headroom without further migrations.

Idempotent + cross-dialect (Postgres + SQLite). Postgres gets a real
JSONB column; SQLite gets JSON (stored as TEXT).

Revision ID: g1e2b4c9f3d8
Revises: f8a3c61b9d72
Create Date: 2026-04-24
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "g1e2b4c9f3d8"
down_revision: Union[str, None] = "f8a3c61b9d72"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _is_postgres() -> bool:
    return op.get_bind().dialect.name == "postgresql"


def _has_table(name: str) -> bool:
    insp = sa.inspect(op.get_bind())
    try:
        return name in insp.get_table_names()
    except Exception:
        return False


def _has_column(table: str, col: str) -> bool:
    if not _has_table(table):
        return False
    insp = sa.inspect(op.get_bind())
    try:
        return col in [c["name"] for c in insp.get_columns(table)]
    except Exception:
        return False


def upgrade() -> None:
    if not _has_table("pilot_journal_lines"):
        return

    # ledger_id — defaults 'L1'. The primary ledger. Additional ledgers
    # (L2, L3...) represent parallel valuations; the application layer
    # keeps them in sync via closing-entry rules.
    if not _has_column("pilot_journal_lines", "ledger_id"):
        op.add_column(
            "pilot_journal_lines",
            sa.Column("ledger_id", sa.String(length=20), nullable=False, server_default="L1"),
        )
        try:
            op.create_index(
                "ix_pilot_jline_ledger",
                "pilot_journal_lines",
                ["ledger_id"],
            )
        except Exception:
            pass

    # dimensions — JSONB on Postgres, JSON on SQLite.
    if not _has_column("pilot_journal_lines", "dimensions"):
        if _is_postgres():
            op.execute("ALTER TABLE pilot_journal_lines ADD COLUMN dimensions JSONB")
            # GIN index so queries like ... WHERE dimensions @> '{"project": "P-001"}'
            # stay fast at 100K+ lines.
            try:
                op.execute(
                    "CREATE INDEX IF NOT EXISTS ix_pilot_jline_dimensions_gin "
                    "ON pilot_journal_lines USING gin (dimensions)"
                )
            except Exception:
                pass
        else:
            op.add_column(
                "pilot_journal_lines",
                sa.Column("dimensions", sa.JSON(), nullable=True),
            )


def downgrade() -> None:
    if not _has_table("pilot_journal_lines"):
        return

    if _has_column("pilot_journal_lines", "dimensions"):
        try:
            if _is_postgres():
                op.execute("DROP INDEX IF EXISTS ix_pilot_jline_dimensions_gin")
        except Exception:
            pass
        op.drop_column("pilot_journal_lines", "dimensions")

    if _has_column("pilot_journal_lines", "ledger_id"):
        try:
            op.drop_index("ix_pilot_jline_ledger", table_name="pilot_journal_lines")
        except Exception:
            pass
        op.drop_column("pilot_journal_lines", "ledger_id")
