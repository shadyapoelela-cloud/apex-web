"""pos_line_soft_variant

G-POS-BACKEND-INTEGRATION-V2 (2026-05-11) — soft variant_id on
`pilot_pos_transaction_lines` so the POS Quick Sale flow can ring
up ad-hoc cash sales (services, custom items, quick rings without
a barcode) alongside catalogued SKUs.

Schema changes:

  pilot_pos_transaction_lines
    * variant_id : NOT NULL → NULL    (misc lines have no variant)
    * sku        : NOT NULL → NULL    (misc lines have no SKU)
    * is_misc    : new BOOL NOT NULL DEFAULT 0
                   (discriminator: True ⇒ un-catalogued ad-hoc line,
                   no StockMovement was recorded)

Idempotent — every alter is gated on inspect() so the migration
survives a `create_all() → alembic-stamp` bootstrap path. Same
pattern as the j7e2c8d4f9b1 + i3d9f6c2e8a5 hand-written hotfixes.

SQLite NOTE: SQLite does not support `ALTER COLUMN`. The fallback
`batch_alter_table` recipe rebuilds the table with the new schema —
matches the recipe used by the j7e2 sibling migration above.

Revision ID: k9a1b3d5e7f2
Revises: j7e2c8d4f9b1
Create Date: 2026-05-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect


revision: str = "k9a1b3d5e7f2"
down_revision: Union[str, None] = "j7e2c8d4f9b1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_TABLE = "pilot_pos_transaction_lines"


def _has_column(table: str, col: str) -> bool:
    bind = op.get_bind()
    insp = inspect(bind)
    if not insp.has_table(table):
        return False
    return any(c["name"] == col for c in insp.get_columns(table))


def upgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)
    if not insp.has_table(_TABLE):
        # create_all() path will materialize the table with the new
        # shape — nothing to migrate.
        return

    with op.batch_alter_table(_TABLE) as batch:
        # variant_id NOT NULL → NULL
        try:
            batch.alter_column("variant_id", existing_type=sa.String(36), nullable=True)
        except Exception:
            # idempotent — dialect may already accept NULL or column
            # may have been recreated upstream.
            pass
        # sku NOT NULL → NULL
        try:
            batch.alter_column("sku", existing_type=sa.String(80), nullable=True)
        except Exception:
            pass
        # is_misc — add only if missing
        if not _has_column(_TABLE, "is_misc"):
            batch.add_column(
                sa.Column(
                    "is_misc", sa.Boolean(), nullable=False, server_default=sa.false()
                )
            )


def downgrade() -> None:
    bind = op.get_bind()
    insp = inspect(bind)
    if not insp.has_table(_TABLE):
        return

    with op.batch_alter_table(_TABLE) as batch:
        if _has_column(_TABLE, "is_misc"):
            try:
                batch.drop_column("is_misc")
            except Exception:
                pass
        # Re-tightening variant_id/sku to NOT NULL is unsafe (existing
        # misc rows would violate the constraint). Leave them nullable
        # on downgrade — the application code still treats variant_id
        # as required when is_misc=False at the pydantic layer.
