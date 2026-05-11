"""pos_session_open_unique

G-POS-SESSION-HARDENING (2026-05-11) — close the race in
`_ensureOpenSession` (list-then-create across concurrent cashiers)
by guaranteeing at most one `status=open` session per branch at the
DB layer. PostgreSQL supports partial unique indexes natively;
SQLite emulates via a partial index (added in 3.8.0).

CAVEAT (staging deploy): existing rows where `status='open'` for the
same `branch_id` will block index creation with a constraint
violation. Before applying on staging or any DB with historical data,
close any orphaned open sessions, e.g.:

    UPDATE pilot_pos_sessions
       SET status = 'closed',
           closed_at = NOW()
     WHERE status = 'open'
       AND branch_id IN (
         SELECT branch_id FROM pilot_pos_sessions
          WHERE status = 'open'
          GROUP BY branch_id HAVING COUNT(*) > 1
       );

The frontend `_ensureOpenSession` retry path already handles a 409
from the race-loser cashier — no frontend changes required.

Revision ID: l5b8c1f4a3e7
Revises: k9a1b3d5e7f2
Create Date: 2026-05-11
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "l5b8c1f4a3e7"
down_revision: Union[str, None] = "k9a1b3d5e7f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_INDEX = "uq_pos_session_open_per_branch"
_TABLE = "pilot_pos_sessions"


def upgrade() -> None:
    # Both Postgres and SQLite (>=3.8) accept the partial-index form.
    try:
        op.create_index(
            _INDEX,
            _TABLE,
            ["branch_id"],
            unique=True,
            postgresql_where=sa.text("status = 'open'"),
            sqlite_where=sa.text("status = 'open'"),
        )
    except Exception:
        # idempotent — index may already exist on a re-applied bootstrap
        pass


def downgrade() -> None:
    try:
        op.drop_index(_INDEX, table_name=_TABLE)
    except Exception:
        pass
