"""Tests for app.core.db_migrations.

Verifies:
  - Dev default: migrations skipped with reason 'dev_default'.
  - Explicit disable: RUN_MIGRATIONS_ON_STARTUP=false honored in prod too.
  - Production: missing alembic raises RuntimeError.
  - Production happy path: alembic.command.upgrade called with 'head'.
"""

import os
import sys
from unittest.mock import patch

import pytest


def _reload():
    """Reload the module so it picks up fresh env vars."""
    if "app.core.db_migrations" in sys.modules:
        del sys.modules["app.core.db_migrations"]
    import app.core.db_migrations as mod

    return mod


def test_dev_default_skips(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.delenv("RUN_MIGRATIONS_ON_STARTUP", raising=False)
    mod = _reload()
    result = mod.run_migrations_on_startup()
    assert result["ran"] is False
    assert result["reason"] == "dev_default"


def test_explicit_disable_in_prod(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("RUN_MIGRATIONS_ON_STARTUP", "false")
    mod = _reload()
    result = mod.run_migrations_on_startup()
    assert result["ran"] is False
    assert result["reason"] == "disabled_by_env"


def test_production_calls_alembic_upgrade(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("RUN_MIGRATIONS_ON_STARTUP", "true")
    mod = _reload()

    with patch("alembic.command.upgrade") as mock_upgrade:
        with patch("alembic.config.Config") as mock_cfg:
            result = mod.run_migrations_on_startup()

    assert result["ran"] is True
    mock_upgrade.assert_called_once()
    # The second positional arg must be 'head'
    args, _ = mock_upgrade.call_args
    assert args[1] == "head"


def test_production_failure_raises(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("RUN_MIGRATIONS_ON_STARTUP", "true")
    mod = _reload()

    with patch("alembic.command.upgrade", side_effect=Exception("boom")):
        with patch("alembic.config.Config"):
            with pytest.raises(RuntimeError, match="Alembic upgrade failed"):
                mod.run_migrations_on_startup()


def test_dev_opt_in_runs_alembic(monkeypatch):
    """Setting RUN_MIGRATIONS_ON_STARTUP=true in dev should run migrations."""
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("RUN_MIGRATIONS_ON_STARTUP", "true")
    mod = _reload()

    with patch("alembic.command.upgrade") as mock_upgrade:
        with patch("alembic.config.Config"):
            result = mod.run_migrations_on_startup()

    assert result["ran"] is True
    mock_upgrade.assert_called_once()
