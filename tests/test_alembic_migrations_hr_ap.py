"""End-to-end Alembic test for HR + AP tables.

Guards against regressions like the one discovered on 2026-04-17:
  - HR + AP models were added but env.py did NOT import them → autogenerate
    would miss them.
  - No migration file created HR + AP tables → production deploys failed.

This test runs `alembic upgrade head` against a fresh SQLite DB and
verifies that all the HR + AP tables end up present.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest


REQUIRED_TABLES = {
    "hr_employees",
    "hr_leave_requests",
    "hr_payroll_runs",
    "hr_payslips",
    "ap_invoices",
    "ap_line_items",
}


def test_alembic_upgrade_creates_hr_ap_tables(tmp_path: Path):
    """`alembic upgrade head` on a clean DB creates all HR + AP tables."""
    db_path = tmp_path / "migration_test.db"
    env = {**os.environ, "DATABASE_URL": f"sqlite:///{db_path}"}

    # Run from repo root so alembic.ini resolves.
    repo_root = Path(__file__).resolve().parents[1]

    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=repo_root,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode != 0:
        pytest.fail(
            f"alembic upgrade failed (exit {result.returncode}):\n"
            f"--- stdout ---\n{result.stdout}\n"
            f"--- stderr ---\n{result.stderr}"
        )

    # Inspect the resulting DB.
    import sqlite3

    con = sqlite3.connect(db_path)
    try:
        rows = con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
        tables = {r[0] for r in rows}
    finally:
        con.close()

    missing = REQUIRED_TABLES - tables
    assert not missing, f"Migration missing HR/AP tables: {sorted(missing)}"


def test_env_py_imports_hr_and_ap_models():
    """Regression: env.py must import the new model modules so autogenerate
    detects them. Without this, future migrations won't include new fields."""
    repo_root = Path(__file__).resolve().parents[1]
    env_text = (repo_root / "alembic" / "env.py").read_text(encoding="utf-8")
    assert "app.hr" in env_text, "alembic/env.py must import app.hr models"
    assert "app.features.ap_agent" in env_text, (
        "alembic/env.py must import app.features.ap_agent.models"
    )


def test_main_imports_hr_and_ap_models():
    """Regression: app/main.py must import HR + AP models at startup so the
    create_all() path (dev/tests) also knows about them."""
    repo_root = Path(__file__).resolve().parents[1]
    main_text = (repo_root / "app" / "main.py").read_text(encoding="utf-8")
    assert "app.hr" in main_text, "app/main.py must import HR models"
    assert "app.features.ap_agent" in main_text, (
        "app/main.py must import AP Agent models"
    )
