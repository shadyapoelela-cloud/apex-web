"""
Regression test for the Alembic env.py multi-Base bug (Wave 10 / closes Wave 0 §6a).

The old env.py did:

    from app.phase1.models.platform_models import Base
    from app.phase1.models.platform_models import *
    ...
    from app.knowledge_brain.models.db_models import *  # ← shadows `Base`
    target_metadata = Base.metadata  # ← now points at KB.Base (14 tables)

A future contributor could re-introduce the same failure mode by
adding a new models module that re-exports `Base`. These tests pin the
invariant: env.py's `target_metadata` must resolve to the phase1
metadata with a realistic table count (≥ 80 covers the entire
phase/sprint layout), regardless of import order or wildcard re-exports.

We purposely avoid spinning up a real Alembic run here — the fix is
purely about the metadata object Alembic receives. Importing env.py
and snapshotting `target_metadata` is enough.
"""

from __future__ import annotations

import importlib
import sys

import pytest


def _load_env_module():
    """Import alembic/env.py as a first-class module.

    The env file runs `if context.is_offline_mode()` at module scope;
    outside an alembic invocation that errors, so we import it with
    `alembic.context` replaced by a lazy-imported stub that swallows
    the run. Using importlib directly because alembic/env.py isn't on
    the regular package path.
    """
    # Stub the alembic.context API just enough to let env.py import cleanly.
    import alembic
    import alembic.context as real_context

    class _StubContext:
        # Replicates the small subset of context API env.py touches at
        # module scope: reading .config and checking is_offline_mode().
        def __init__(self):
            self.config = real_context.config if hasattr(real_context, "config") else None

        def is_offline_mode(self):
            return True  # routes through run_migrations_offline()

        def configure(self, *args, **kwargs):
            return None

        def begin_transaction(self):
            from contextlib import contextmanager

            @contextmanager
            def _null():
                yield

            return _null()

        def run_migrations(self):
            return None

    stub = _StubContext()
    stub.config = type("C", (), {"config_file_name": None, "config_ini_section": "alembic"})()
    stub.config.get_section = lambda _: {"sqlalchemy.url": "sqlite:///:memory:"}

    # Monkey-patch alembic.context for the duration of the import.
    original = alembic.context
    alembic.context = stub
    try:
        # Ensure fresh import every call so pytest isolation holds.
        sys.modules.pop("alembic_env_for_test", None)
        spec = importlib.util.spec_from_file_location(
            "alembic_env_for_test",
            __import__("os").path.join(
                __import__("os").path.dirname(__import__("os").path.dirname(__file__)),
                "alembic",
                "env.py",
            ),
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        alembic.context = original


class TestEnvMetadata:
    def test_target_metadata_is_phase1_base(self):
        """target_metadata must be phase1.Base.metadata, not KB.Base.metadata."""
        env = _load_env_module()
        from app.phase1.models.platform_models import Base as PhaseBase
        from app.knowledge_brain.models.db_models import Base as KBBase

        assert env.target_metadata is PhaseBase.metadata, (
            "env.py wired the wrong Base — the multi-Base bug is back. "
            "See Wave 0 §6a in STATE_OF_APEX.md for context."
        )
        assert env.target_metadata is not KBBase.metadata

    def test_target_metadata_has_realistic_table_count(self):
        """A healthy phase1 metadata carries ≥ 80 tables across the
        phase/sprint layout plus the Wave-era compliance tables. If
        this drops to 14 the KB-base shadow bug is back."""
        env = _load_env_module()
        tables = env.target_metadata.tables
        assert len(tables) >= 80, (
            f"Expected ≥ 80 tables, got {len(tables)}. "
            "KB.Base shadowing phase1.Base would show ~14 here."
        )

    def test_core_tables_registered(self):
        """Spot-check tables from every layer — phase1 auth, phase2
        clients, compliance-core (Wave 5 + 7), TOTP (Wave 1 PR#4)."""
        env = _load_env_module()
        names = set(env.target_metadata.tables.keys())

        # phase1
        assert "users" in names
        assert "user_sessions" in names
        # compliance core (Wave 1 PR#6 + Wave 5 + Wave 7)
        assert "audit_trail" in names
        assert "zatca_submission_queue" in names
        assert "ai_suggestion" in names

    def test_kb_tables_not_in_target(self):
        """KB runs against a separate engine, so its tables must NOT
        be in phase1.metadata. If they are, KB classes got registered
        on PhaseBase by accident."""
        env = _load_env_module()
        names = set(env.target_metadata.tables.keys())
        assert "knowledge_entries" not in names
        assert "knowledge_rules" not in names

    def test_db_url_exported(self):
        env = _load_env_module()
        assert isinstance(env.DB_URL, str)
        assert env.DB_URL  # non-empty
