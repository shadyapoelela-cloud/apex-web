"""Tests for PostgreSQL RLS session hook + migration metadata.

Because we can't spin up a real PostgreSQL in CI cheaply, most of
these tests verify:
  • The hook installs cleanly on non-Postgres engines (no-op path)
  • The RLS migration file is reachable from the head
  • The migration enumerates at least the 4 Q1 infra tables
"""

from __future__ import annotations

import os


def _alembic_cfg():
    from alembic.config import Config
    here = os.path.dirname(os.path.abspath(__file__))
    ini = os.path.abspath(os.path.join(here, "..", "alembic.ini"))
    return Config(ini)


def test_rls_hook_is_noop_on_sqlite():
    """install_rls_session_hook on SQLite should do nothing and not crash."""
    from sqlalchemy import create_engine
    from app.core.rls_session import install_rls_session_hook
    eng = create_engine("sqlite:///:memory:")
    # Should not raise
    install_rls_session_hook(eng)
    install_rls_session_hook(eng)  # idempotent — second call also safe


def test_rls_hook_sets_installed_flag_on_postgres_like_engine(monkeypatch):
    """The idempotence flag is set the first time the hook runs on a
    postgres-shaped engine — we mock the dialect since real Postgres
    isn't available in the test env."""
    from sqlalchemy import create_engine
    from app.core.rls_session import install_rls_session_hook

    eng = create_engine("sqlite:///:memory:")
    # Pretend to be Postgres
    eng.dialect.name = "postgresql"  # type: ignore[assignment]

    # Need a shim for current_tenant import inside the hook
    import app.core.tenant_context as tc
    monkeypatch.setattr(tc, "current_tenant", lambda: None, raising=True)

    install_rls_session_hook(eng)
    assert getattr(eng, "_apex_rls_installed", False) is True

    # Second call should be a no-op (already installed)
    install_rls_session_hook(eng)


def test_rls_migration_reachable_from_head():
    """RLS migration (d3a1e9b4f201) must remain reachable in the revision
    graph. It doesn't have to BE the head — newer migrations can extend
    the chain — but walking back from HEAD must traverse it."""
    from alembic.script import ScriptDirectory
    cfg = _alembic_cfg()
    script = ScriptDirectory.from_config(cfg)
    heads = set(script.get_heads())
    reachable = set()
    for head in heads:
        for rev in script.walk_revisions("base", head):
            reachable.add(rev.revision)
    assert "d3a1e9b4f201" in reachable, (
        f"d3a1e9b4f201 missing from revision chain; heads={heads}"
    )


def test_rls_migration_covers_q1_infra_tables():
    """The RLS migration must list each Q1 infra table so they all
    get policies when the cluster runs on Postgres."""
    import importlib.util
    import pathlib
    p = pathlib.Path(__file__).parent.parent / "alembic" / "versions" / "d3a1e9b4f201_postgres_rls_policies.py"
    spec = importlib.util.spec_from_file_location("_rls", p)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    for table in ("activity_log", "tenant_branding", "sync_operations", "zatca_submissions"):
        assert table in mod._TENANT_TABLES, f"{table} missing from RLS list"


def test_rls_migration_is_postgres_only_via_dialect_check():
    """Regression: the migration must bail out early on non-postgres
    dialects. Grep the source for the guard."""
    import pathlib
    p = pathlib.Path(__file__).parent.parent / "alembic" / "versions" / "d3a1e9b4f201_postgres_rls_policies.py"
    src = p.read_text(encoding="utf-8")
    assert 'bind.dialect.name != "postgresql"' in src
    # Upgrade AND downgrade must both guard.
    assert src.count('bind.dialect.name != "postgresql"') >= 2
