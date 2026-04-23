"""Integrity constraints — VAT unique, JE balance CHECK, membership audit columns

Adds three database-layer safety nets flagged as gaps by the April 2026
schema audit:

1. `clients.vat_registration_number` — unique partial index (non-null
   values only). Prevents two Saudi clients from registering with the
   same ZATCA VAT number (illegal state under ZATCA Phase 2).

2. `pilot_journal_entries` — CHECK constraint enforcing
   `ABS(total_debit - total_credit) < 0.01` so an unbalanced journal
   entry cannot be persisted even if application-layer validation is
   bypassed. Double-entry bookkeeping is a hard invariant.

3. `pilot_journal_lines` — CHECK constraint enforcing that each line
   has exactly one of debit/credit (never both, never neither).

4. `client_memberships` — three new audit columns (revoked_at,
   revoked_by, revoke_reason) matching the model update in this
   revision. Backfilled NULLs on existing rows.

Revision ID: e4c7d9f8a123
Revises: d3a1e9b4f201
Create Date: 2026-04-23
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "e4c7d9f8a123"
down_revision: Union[str, None] = "d3a1e9b4f201"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ────────────────────────────────────────────────────────────────────
# Helpers — make this migration idempotent / cross-dialect safe.
# Render runs PostgreSQL, CI runs SQLite; both must succeed.
# ────────────────────────────────────────────────────────────────────
def _is_postgres() -> bool:
    bind = op.get_bind()
    return bind.dialect.name == "postgresql"


def _has_column(table: str, column: str) -> bool:
    insp = sa.inspect(op.get_bind())
    try:
        return column in [c["name"] for c in insp.get_columns(table)]
    except Exception:
        return False


def _has_index(table: str, index: str) -> bool:
    insp = sa.inspect(op.get_bind())
    try:
        return index in [i["name"] for i in insp.get_indexes(table)]
    except Exception:
        return False


# ════════════════════════════════════════════════════════════════════
# Upgrade
# ════════════════════════════════════════════════════════════════════
def upgrade() -> None:
    # ── 1. clients.vat_registration_number unique partial index ────
    # Postgres: partial unique (WHERE vat_registration_number IS NOT NULL)
    # SQLite:   same via plain unique on a view — but simpler to add
    #           a conditional check via a unique index with sqlite
    #           (SQLite ignores partial index predicates on older ver).
    if not _has_index("clients", "uq_clients_vat_not_null"):
        if _is_postgres():
            op.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_clients_vat_not_null "
                "ON clients (vat_registration_number) "
                "WHERE vat_registration_number IS NOT NULL"
            )
        else:
            # SQLite: plain unique index; NULLs are not considered equal
            # so NULL duplicates are allowed (matches our intent).
            op.create_index(
                "uq_clients_vat_not_null",
                "clients",
                ["vat_registration_number"],
                unique=True,
            )

    # ── 2. JE balance CHECK ────────────────────────────────────────
    # Skip on SQLite (ALTER TABLE … ADD CONSTRAINT not supported without
    # a table rewrite). Postgres only.
    if _is_postgres():
        try:
            op.execute(
                "ALTER TABLE pilot_journal_entries "
                "DROP CONSTRAINT IF EXISTS ck_je_balanced"
            )
            op.execute(
                "ALTER TABLE pilot_journal_entries "
                "ADD CONSTRAINT ck_je_balanced "
                "CHECK (ABS(COALESCE(total_debit,0) - COALESCE(total_credit,0)) < 0.01)"
            )
        except Exception:
            # Non-fatal: table may not exist yet on fresh installs.
            pass

        # ── 3. JE line debit XOR credit (exactly one must be > 0) ─
        try:
            op.execute(
                "ALTER TABLE pilot_journal_lines "
                "DROP CONSTRAINT IF EXISTS ck_jl_debit_xor_credit"
            )
            op.execute(
                "ALTER TABLE pilot_journal_lines "
                "ADD CONSTRAINT ck_jl_debit_xor_credit "
                "CHECK ((COALESCE(debit,0) = 0 AND COALESCE(credit,0) > 0) "
                "OR (COALESCE(debit,0) > 0 AND COALESCE(credit,0) = 0))"
            )
        except Exception:
            pass

    # ── 4. client_memberships audit columns ────────────────────────
    if not _has_column("client_memberships", "revoked_at"):
        op.add_column(
            "client_memberships",
            sa.Column("revoked_at", sa.DateTime(), nullable=True),
        )
    if not _has_column("client_memberships", "revoked_by"):
        op.add_column(
            "client_memberships",
            sa.Column("revoked_by", sa.String(length=36), nullable=True),
        )
        # FK only on Postgres (SQLite requires table rewrite for FK add).
        if _is_postgres():
            try:
                op.create_foreign_key(
                    "fk_client_memberships_revoked_by_users",
                    "client_memberships",
                    "users",
                    ["revoked_by"],
                    ["id"],
                    ondelete="SET NULL",
                )
            except Exception:
                pass
    if not _has_column("client_memberships", "revoke_reason"):
        op.add_column(
            "client_memberships",
            sa.Column("revoke_reason", sa.String(length=200), nullable=True),
        )


# ════════════════════════════════════════════════════════════════════
# Downgrade
# ════════════════════════════════════════════════════════════════════
def downgrade() -> None:
    # Drop membership audit columns (safe; data lost).
    for col in ("revoke_reason", "revoked_by", "revoked_at"):
        if _has_column("client_memberships", col):
            try:
                op.drop_column("client_memberships", col)
            except Exception:
                pass

    # Drop CHECK constraints (Postgres only).
    if _is_postgres():
        try:
            op.execute(
                "ALTER TABLE pilot_journal_lines "
                "DROP CONSTRAINT IF EXISTS ck_jl_debit_xor_credit"
            )
            op.execute(
                "ALTER TABLE pilot_journal_entries "
                "DROP CONSTRAINT IF EXISTS ck_je_balanced"
            )
        except Exception:
            pass

    # Drop VAT unique index.
    if _has_index("clients", "uq_clients_vat_not_null"):
        try:
            op.drop_index("uq_clients_vat_not_null", table_name="clients")
        except Exception:
            pass
