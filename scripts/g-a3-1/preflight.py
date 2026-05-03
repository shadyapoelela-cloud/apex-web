#!/usr/bin/env python3
"""scripts/g-a3-1/preflight.py — pre-execution sanity check for any
locked-in production priority.

G-A3.1.1 (Sprint 12+). Codifies the operational guardrails that the
Phase 2b runbook required as a manual checklist. Run this BEFORE
stamp_head.py or any other production-affecting script. Fail-fast:
the first ✗ check stops execution; fix and re-run.

Checks (in order):
  a. Python version >= 3.10
  b. psycopg2 importable
  c. DATABASE_URL set + length > 50 + starts with postgres://
  d. Connection to DATABASE_URL succeeds (SELECT 1)
  e. Current alembic head id matches expected (read from
     alembic chain locally; --expected-head <id> override)
  f. git status clean on a sprint-* branch

Usage:
    DATABASE_URL=<prod-url> python scripts/g-a3-1/preflight.py \\
        --expected-head g1e2b4c9f3d8

Exit codes:
    0 = all checks pass.
    non-zero = at least one check failed (specific code per check).

Cross-references:
  - scripts/g-a3-1/phase-2b-runbook.md § 1 (the manual pre-flight
    checklist this script replaces)
  - scripts/g-a3-1/stamp_head.py (the next script to run after
    preflight passes)
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from urllib.parse import urlparse


def status(ok: bool, label: str, detail: str = "") -> None:
    mark = "✓" if ok else "✗"
    suffix = f"  {detail}" if detail else ""
    print(f"  [{mark}] {label}{suffix}")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="G-A3.1.1 preflight checks")
    p.add_argument(
        "--expected-head",
        type=str,
        default=None,
        help="Expected alembic head id to assert against. If omitted, "
             "auto-detects from local chain (any single head OK).",
    )
    p.add_argument(
        "--alembic-ini",
        type=str,
        default="alembic.ini",
        help="Path to alembic.ini (default: alembic.ini).",
    )
    p.add_argument(
        "--allow-dirty-tree",
        action="store_true",
        help="Skip the git-status-clean check. Use only when intentionally "
             "running with uncommitted changes.",
    )
    p.add_argument(
        "--allow-non-sprint-branch",
        action="store_true",
        help="Skip the sprint-* branch name check.",
    )
    return p.parse_args()


# ──────────────────────────────────────────────────────────────────
# Individual check functions (return (ok, detail))
# ──────────────────────────────────────────────────────────────────

def check_python_version() -> tuple[bool, str]:
    v = sys.version_info
    ok = (v.major, v.minor) >= (3, 10)
    return ok, f"Python {v.major}.{v.minor}.{v.micro}"


def check_psycopg2_importable() -> tuple[bool, str]:
    try:
        import psycopg2  # noqa: F401
        return True, f"psycopg2 {psycopg2.__version__}"
    except ImportError as e:
        return False, f"import failed: {e}"


def check_database_url() -> tuple[bool, str]:
    url = os.environ.get("DATABASE_URL")
    if not url:
        return False, "DATABASE_URL env var not set"
    if len(url) < 50:
        return False, f"DATABASE_URL suspiciously short ({len(url)} chars)"
    if not url.startswith(("postgres://", "postgresql://")):
        return False, f"DATABASE_URL scheme is not postgres:// (got {url[:20]}...)"
    parsed = urlparse(url)
    host = parsed.hostname or "<unknown>"
    return True, f"len={len(url)}, host={host}"


def check_db_connection() -> tuple[bool, str]:
    url = os.environ.get("DATABASE_URL", "")
    if not url:
        return False, "DATABASE_URL not set (skipped)"
    try:
        import psycopg2
    except ImportError:
        return False, "psycopg2 not importable (skipped)"
    try:
        conn = psycopg2.connect(url, connect_timeout=10)
        try:
            cur = conn.cursor()
            cur.execute("SELECT 1")
            row = cur.fetchone()
            cur.close()
            if row != (1,):
                return False, f"SELECT 1 returned {row!r}"
            return True, "SELECT 1 OK"
        finally:
            conn.close()
    except Exception as e:
        return False, f"connect failed: {e.__class__.__name__}: {e}"


def check_alembic_head(expected: str | None, alembic_ini: str) -> tuple[bool, str]:
    if not os.path.exists(alembic_ini):
        return False, f"alembic.ini not found at '{alembic_ini}'"
    try:
        from alembic.config import Config
        from alembic.script import ScriptDirectory
    except ImportError as e:
        return False, f"alembic not importable: {e}"

    try:
        cfg = Config(alembic_ini)
        sd = ScriptDirectory.from_config(cfg)
        heads = sd.get_heads()
    except Exception as e:
        return False, f"alembic chain read failed: {e}"

    if len(heads) == 0:
        return False, "alembic chain has no head"
    if len(heads) > 1:
        return False, f"alembic chain has multiple heads {heads!r} — resolve before stamping"

    actual = heads[0]
    if expected and actual != expected:
        return False, f"head mismatch: expected {expected!r}, got {actual!r}"
    return True, f"head={actual}" + (f" (matches --expected-head)" if expected else "")


def check_git_status_clean() -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except FileNotFoundError:
        return False, "git not on PATH"
    except subprocess.TimeoutExpired:
        return False, "git status timed out"
    if result.returncode != 0:
        return False, f"git status exit {result.returncode}: {result.stderr.strip()}"

    # Filter pre-existing noise (build artifacts, .pyc, test_register.py etc).
    # We accept any line as "dirty" — the operator should know what's
    # uncommitted before running production scripts. Allow override via
    # --allow-dirty-tree.
    lines = [ln for ln in result.stdout.strip().splitlines() if ln.strip()]
    if lines:
        sample = lines[0][:60]
        return False, f"{len(lines)} uncommitted file(s); first: {sample}"
    return True, "working tree clean"


def check_branch_name() -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except FileNotFoundError:
        return False, "git not on PATH"
    except subprocess.TimeoutExpired:
        return False, "git rev-parse timed out"
    if result.returncode != 0:
        return False, f"git rev-parse exit {result.returncode}"
    branch = result.stdout.strip()
    if not branch:
        return False, "empty branch name (detached HEAD?)"
    if not branch.startswith("sprint-"):
        return False, f"branch {branch!r} is not sprint-*"
    return True, f"branch={branch}"


# ──────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────

def main() -> int:
    args = parse_args()

    print("G-A3.1.1 preflight checks")
    print("=" * 50)

    # Order matters: cheaper checks first, fail-fast.
    checks: list[tuple[str, callable, int]] = [
        ("a. Python >= 3.10",                 check_python_version,            10),
        ("b. psycopg2 importable",            check_psycopg2_importable,       11),
        ("c. DATABASE_URL set + valid",       check_database_url,              12),
        ("d. DB connection (SELECT 1)",       check_db_connection,             13),
        ("e. alembic head matches",
            (lambda: check_alembic_head(args.expected_head, args.alembic_ini)), 14),
    ]
    if not args.allow_dirty_tree:
        checks.append(("f1. git working tree clean",   check_git_status_clean, 15))
    if not args.allow_non_sprint_branch:
        checks.append(("f2. branch name = sprint-*",   check_branch_name,      16))

    for label, fn, exit_code in checks:
        try:
            ok, detail = fn()
        except Exception as e:
            ok, detail = False, f"unexpected exception: {e.__class__.__name__}: {e}"
        status(ok, label, detail)
        if not ok:
            print()
            print(f"FAIL: preflight check '{label}' failed.")
            print(f"      Fix the underlying issue and re-run preflight.py.")
            print(f"      Exit code {exit_code}.")
            return exit_code

    print()
    print("PASS: all preflight checks succeeded.")
    print("Operator may proceed to stamp_head.py / smoke_tests.py.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
