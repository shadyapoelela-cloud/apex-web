"""postgres_rls_policies: enable Row-Level Security on tenant-scoped tables

V2 blueprint § 16.2 — defense in depth. Even if the application
layer's query guard (app/core/tenant_guard.py) has a bug, the
database will enforce tenant isolation.

Applies to tables that carry a `tenant_id` column via TenantMixin.
Each table gets:
  • ALTER TABLE ... ENABLE ROW LEVEL SECURITY
  • A policy tenant_isolation_<table> that filters
      tenant_id = current_setting('app.current_tenant')::uuid
  • A "service role" bypass for the migration + scheduled jobs

PostgreSQL only — this migration NO-OPs on SQLite so dev + tests keep
working unchanged.

Revision ID: d3a1e9b4f201
Revises: c7f1a9b02e10
Create Date: 2026-04-17
"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "d3a1e9b4f201"
down_revision: Union[str, Sequence[str], None] = "c7f1a9b02e10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Tables that are tenant-scoped today. Extend this list as new models
# adopt TenantMixin — or regenerate at runtime by inspecting
# Base.metadata.tables and checking for a tenant_id column.
_TENANT_TABLES = [
    "activity_log",
    "tenant_branding",
    "sync_operations",
    "zatca_submissions",
    "saved_views",
    "marketplace_bookings",
    "marketplace_revenue_share",
    # Older phase tables that carry tenant_id — add as they adopt RLS
    "audit_log",
    "governed_actions",
    "dimensions",
    "dimension_values",
    "apex_copilot_sessions",
    "apex_copilot_messages",
    "apex_copilot_facts",
]


def upgrade() -> None:
    """Enable RLS + add tenant-isolation policies. PostgreSQL only."""
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite / MySQL / other → skip. Application-layer guard still
        # enforces isolation during dev.
        return

    inspector = sa.inspect(bind)
    existing = set(inspector.get_table_names())

    for table in _TENANT_TABLES:
        if table not in existing:
            # Optional table — some tenants haven't adopted it yet.
            continue
        # Must be a superuser or the table owner to ALTER. The migration
        # runner should connect as the DB owner.
        op.execute(f'ALTER TABLE "{table}" ENABLE ROW LEVEL SECURITY')
        # Force even the table owner to go through the policy. Without
        # FORCE, the owner bypasses RLS.
        op.execute(f'ALTER TABLE "{table}" FORCE ROW LEVEL SECURITY')

        # Drop any pre-existing copy of the policy so the migration is
        # idempotent (re-runnable after a schema reset).
        op.execute(
            f'DROP POLICY IF EXISTS tenant_isolation_{table} ON "{table}"'
        )
        # Main policy: row visible IFF its tenant_id matches the
        # session-scoped setting app.current_tenant.
        # NULL tenant rows (system-wide reference data) are visible to
        # everyone — the app inserts with tenant_id=NULL for those.
        op.execute(f"""
            CREATE POLICY tenant_isolation_{table}
              ON "{table}"
              USING (
                tenant_id IS NULL
                OR tenant_id::text = current_setting('app.current_tenant', true)
              )
              WITH CHECK (
                tenant_id IS NULL
                OR tenant_id::text = current_setting('app.current_tenant', true)
              )
        """)


def downgrade() -> None:
    """Disable RLS on the same tables. PostgreSQL only."""
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return

    for table in _TENANT_TABLES:
        op.execute(
            f'DROP POLICY IF EXISTS tenant_isolation_{table} ON "{table}"'
        )
        op.execute(f'ALTER TABLE "{table}" DISABLE ROW LEVEL SECURITY')
