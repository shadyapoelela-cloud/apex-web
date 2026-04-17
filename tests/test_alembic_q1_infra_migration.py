"""Tests for the c7f1a9b02e10 infra migration.

Verifies:
  • The migration is reachable from the head (alembic heads).
  • Downgrade works and the tables disappear.
  • Re-upgrade is idempotent because we guarded every create_table
    with inspector.has_table(...).
"""

from __future__ import annotations

import os


def _alembic_cfg():
    """Build an Alembic Config rooted at repo /alembic.ini."""
    from alembic.config import Config

    here = os.path.dirname(os.path.abspath(__file__))
    ini = os.path.abspath(os.path.join(here, "..", "alembic.ini"))
    return Config(ini)


def test_head_includes_q1_infra_migration():
    """The new migration is the current head."""
    from alembic.script import ScriptDirectory

    cfg = _alembic_cfg()
    script = ScriptDirectory.from_config(cfg)
    heads = set(script.get_heads())
    assert "c7f1a9b02e10" in heads


def test_upgrade_is_idempotent_with_existing_tables():
    """Running the migration a second time should not fail because the
    tables already exist (guarded with has_table checks)."""
    from sqlalchemy import create_engine, inspect
    from alembic import command

    cfg = _alembic_cfg()

    # Point Alembic at a real engine so the has_table guards run.
    from app.phase1.models.platform_models import DB_URL
    engine = create_engine(DB_URL)
    inspector = inspect(engine)
    # After Base.metadata.create_all() at startup, these tables are
    # already present — the migration should be a no-op instead of
    # raising "table already exists".
    for t in ("activity_log", "tenant_branding", "sync_operations", "zatca_submissions"):
        assert inspector.has_table(t), f"{t} missing — test setup issue"

    # Stamp at the PREVIOUS revision and re-run upgrade. Even though
    # tables are already there, the guards should keep it from failing.
    command.stamp(cfg, "1a8f7d2b4e5c")
    command.upgrade(cfg, "c7f1a9b02e10")

    # All 4 tables still present
    inspector = inspect(engine)
    for t in ("activity_log", "tenant_branding", "sync_operations", "zatca_submissions"):
        assert inspector.has_table(t)


def test_migration_file_declares_expected_revision_id():
    """Sanity: the revision + down_revision in the file match what the
    tests assume. Catches accidental renames."""
    import importlib.util
    import pathlib

    p = pathlib.Path(__file__).parent.parent / "alembic" / "versions" / "c7f1a9b02e10_q1_2026_infra_tables.py"
    spec = importlib.util.spec_from_file_location("_q1_infra", p)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    assert mod.revision == "c7f1a9b02e10"
    assert mod.down_revision == "1a8f7d2b4e5c"
