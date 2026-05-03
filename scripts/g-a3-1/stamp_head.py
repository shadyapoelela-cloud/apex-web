#!/usr/bin/env python3
"""scripts/g-a3-1/stamp_head.py — psycopg2-based alembic stamp head equivalent.

G-A3.1.1 (Sprint 12+). Captures the Phase 2b (2026-05-03) ad-hoc
SQL pattern in a reusable, idempotent, safety-gated tool. When alembic
CLI is unavailable (e.g., regional CDN blocks like the EDB 403 issue
that hit the Phase 2b operator), this script does what
`alembic stamp head` does — write a single row into `alembic_version`
with the target revision id — without any DDL beyond that table.

Behavior:
  - Refuses to run without `--prod` flag (safety gate).
  - Reads DATABASE_URL from env. Errors if unset.
  - Connects with connect_timeout=10.
  - Target revision: `--revision <id>` arg, OR auto-detect via the
    `alembic` Python API (no subprocess) from the local chain.
  - Pre-check: SELECT version_num FROM alembic_version. Captures and
    prints current state (handles UndefinedTable cleanly).
  - Confirmation: prints "About to stamp <db_host> with revision
    <id>. Type 'STAMP' to proceed:" — refuses without exact match.
  - Stamp transaction (matches `alembic stamp head` semantics):
        BEGIN;
        CREATE TABLE IF NOT EXISTS alembic_version (
            version_num VARCHAR(32) NOT NULL,
            CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
        );
        DELETE FROM alembic_version;     -- guarantees single-row state
        INSERT INTO alembic_version (version_num) VALUES (%s);
        COMMIT;
    Note: the Phase 2b production operator's ad-hoc SQL used
    `ON CONFLICT DO NOTHING` because the prod table was known empty.
    This script is general-purpose, so it uses DELETE+INSERT to match
    `alembic stamp head` behavior — exactly one row at the target,
    regardless of pre-state. Idempotent: re-run with same revision
    leaves exactly the same single row.
  - Post-check: SELECT version_num. Verifies exactly one row at the
    target revision.
  - Prints structured PR-paste-ready output.
  - Exit 0 on success, non-zero on any error.

Usage examples:
    # Auto-detect revision from local alembic chain
    DATABASE_URL=<prod-url> python scripts/g-a3-1/stamp_head.py --prod

    # Explicit revision (use when alembic CLI/API unavailable)
    DATABASE_URL=<prod-url> python scripts/g-a3-1/stamp_head.py \\
        --prod --revision g1e2b4c9f3d8

Local sqlite test (dry-run-ish — no real production):
    DATABASE_URL=sqlite:///tmp_test.db python scripts/g-a3-1/stamp_head.py \\
        --prod --revision test_rev_001 --no-confirm

Cross-references:
  - scripts/g-a3-1/phase-2b-runbook.md (the canonical runbook this
    script complements, not replaces)
  - APEX_BLUEPRINT/G-A3-1-investigation.md § E
  - APEX_BLUEPRINT/09 § 2 G-A3.1 closure paragraph
"""

from __future__ import annotations

import argparse
import os
import sys
from contextlib import contextmanager
from urllib.parse import urlparse


# ──────────────────────────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="psycopg2-based alembic stamp head equivalent (G-A3.1.1)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument(
        "--prod",
        action="store_true",
        help="Required safety gate. Refuses to run without it.",
    )
    p.add_argument(
        "--revision",
        type=str,
        default=None,
        help="Target revision id. If omitted, auto-detects from local "
             "alembic chain via alembic.script.ScriptDirectory.",
    )
    p.add_argument(
        "--no-confirm",
        action="store_true",
        help="Skip the typed confirmation. ONLY for local sqlite tests "
             "or scripted CI flows. Refused in production-like contexts.",
    )
    p.add_argument(
        "--alembic-ini",
        type=str,
        default="alembic.ini",
        help="Path to alembic.ini for revision auto-detect (default: alembic.ini)",
    )
    return p.parse_args()


# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────

def err(msg: str) -> None:
    """Print to stderr."""
    print(f"[stamp_head.py] ERROR: {msg}", file=sys.stderr)


def info(msg: str) -> None:
    print(f"[stamp_head.py] {msg}")


def detect_head_revision(alembic_ini: str) -> str:
    """Auto-detect the alembic chain head id locally.

    Uses alembic's Python API directly (no subprocess) so we don't
    need the `alembic` CLI on PATH. If alembic isn't installed at all
    (Render shell scenarios), errors clearly.
    """
    try:
        from alembic.config import Config
        from alembic.script import ScriptDirectory
    except ImportError as e:
        raise RuntimeError(
            "alembic Python package not available. Install with "
            "`pip install alembic` OR pass --revision <id> explicitly."
        ) from e

    if not os.path.exists(alembic_ini):
        raise RuntimeError(
            f"alembic.ini not found at '{alembic_ini}'. Pass --alembic-ini "
            f"<path> or run from the repo root."
        )

    cfg = Config(alembic_ini)
    sd = ScriptDirectory.from_config(cfg)
    heads = sd.get_heads()
    if len(heads) == 0:
        raise RuntimeError("Alembic chain has no head — nothing to stamp.")
    if len(heads) > 1:
        raise RuntimeError(
            f"Alembic chain has multiple heads {heads!r}. Resolve before "
            f"stamping (likely a bad merge); pass --revision <id> only "
            f"if you know which head to stamp."
        )
    return heads[0]


def db_host_from_url(url: str) -> str:
    """Extract a redacted host:port for log/confirmation messages."""
    parsed = urlparse(url)
    host = parsed.hostname or "<unknown>"
    port = f":{parsed.port}" if parsed.port else ""
    return f"{host}{port}"


@contextmanager
def open_connection(url: str):
    """Open a DB connection. Supports postgres:// + sqlite:/// (test-only).

    For sqlite, uses a thin shim around the stdlib `sqlite3` module so
    the rest of stamp_head.py can run uniform code paths against a
    test DB. Production callers always pass a postgres URL.
    """
    if url.startswith(("postgres://", "postgresql://")):
        try:
            import psycopg2
        except ImportError as e:
            raise RuntimeError(
                "psycopg2 not available. Run scripts/g-a3-1/install_prereqs.{ps1,sh} "
                "or `pip install psycopg2-binary`."
            ) from e
        conn = psycopg2.connect(url, connect_timeout=10)
        try:
            yield ("postgres", conn)
        finally:
            conn.close()
    elif url.startswith("sqlite:///"):
        import sqlite3
        path = url[len("sqlite:///"):]
        conn = sqlite3.connect(path)
        try:
            yield ("sqlite", conn)
        finally:
            conn.close()
    else:
        raise RuntimeError(
            f"Unsupported DATABASE_URL scheme: {url[:20]}... "
            f"Expected postgres:// or sqlite:/// (test only)."
        )


def read_current_state(kind: str, conn) -> tuple[list[str], bool]:
    """Read all version_num rows + report whether the table exists.

    Returns (rows, table_exists). `rows` is a list (could be 0, 1, or
    >1 rows — the latter is a corruption signal a prior bad stamp
    can leave behind; this script's DELETE+INSERT cleans it up).
    """
    cur = conn.cursor()
    try:
        cur.execute("SELECT version_num FROM alembic_version")
        rows = [r[0] for r in cur.fetchall()]
        return rows, True
    except Exception as e:
        msg = str(e).lower()
        if (
            "undefinedtable" in msg
            or "does not exist" in msg
            or "no such table" in msg
        ):
            return [], False
        raise
    finally:
        try:
            cur.close()
        except Exception:
            pass


def stamp_revision(kind: str, conn, revision: str) -> None:
    """Stamp a revision matching `alembic stamp head` semantics:
    exactly one row at the target, regardless of pre-state.

    Single transaction:
        CREATE TABLE IF NOT EXISTS alembic_version (...);
        DELETE FROM alembic_version;
        INSERT INTO alembic_version (version_num) VALUES (revision);
        COMMIT;

    Idempotent: re-running with the same revision leaves the same
    single-row state. Safe against multi-row corruption from a prior
    bad stamp (sqlite/postgres both honored).
    """
    cur = conn.cursor()
    try:
        # Table definition matches alembic's internal schema.
        cur.execute(
            "CREATE TABLE IF NOT EXISTS alembic_version ("
            "    version_num VARCHAR(32) NOT NULL,"
            "    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)"
            ")"
        )
        # Clear all existing rows. `alembic stamp head` does this so the
        # outcome is single-row deterministic regardless of pre-state.
        cur.execute("DELETE FROM alembic_version")
        # Insert exactly one row at the target.
        if kind == "postgres":
            cur.execute(
                "INSERT INTO alembic_version (version_num) VALUES (%s)",
                (revision,),
            )
        else:
            cur.execute(
                "INSERT INTO alembic_version (version_num) VALUES (?)",
                (revision,),
            )
        conn.commit()
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        try:
            cur.close()
        except Exception:
            pass


def _format_rows(rows: list[str], table_exists: bool) -> str:
    if not table_exists:
        return "(table absent)"
    if not rows:
        return "(table present, 0 rows)"
    if len(rows) == 1:
        return rows[0]
    return f"{len(rows)} rows: " + ", ".join(repr(r) for r in rows[:5])


def print_pr_paste(args, host: str,
                   before: tuple[list[str], bool],
                   after: tuple[list[str], bool]) -> None:
    """Print a PR-paste-ready summary block."""
    print()
    print("─" * 60)
    print("Stamp result (paste this into the PR description):")
    print("─" * 60)
    print(f"  DB host (redacted):  {host}")
    print(f"  Pre-stamp state:     {_format_rows(*before)}")
    print(f"  Target revision:     {args.revision}")
    print(f"  Post-stamp state:    {_format_rows(*after)}")
    print(f"  Semantics:           DELETE+INSERT (matches `alembic stamp head`)")
    print("─" * 60)


# ──────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────

def main() -> int:
    args = parse_args()

    # Safety gate.
    if not args.prod:
        err("Refusing to run without --prod flag. This script touches "
            "real schema state; the gate is intentional.")
        return 2

    # Read DATABASE_URL.
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        err("DATABASE_URL env var not set.")
        return 3

    # Resolve target revision.
    if not args.revision:
        try:
            args.revision = detect_head_revision(args.alembic_ini)
            info(f"Auto-detected head revision: {args.revision}")
        except Exception as e:
            err(str(e))
            return 4
    else:
        info(f"Using --revision {args.revision} (skipping auto-detect)")

    if not args.revision or len(args.revision) > 32:
        err(f"Invalid revision id: {args.revision!r} (must be 1-32 chars).")
        return 5

    host = db_host_from_url(db_url)

    # Confirmation. --no-confirm only honored for sqlite test paths.
    if not args.no_confirm:
        prompt = (
            f"\nAbout to stamp {host} with revision {args.revision}.\n"
            f"Type 'STAMP' to proceed (anything else aborts): "
        )
        try:
            answer = input(prompt).strip()
        except (EOFError, KeyboardInterrupt):
            err("Aborted (no input or interrupt).")
            return 6
        if answer != "STAMP":
            err(f"Aborted — confirmation expected 'STAMP', got {answer!r}.")
            return 7
    else:
        if db_url.startswith(("postgres://", "postgresql://")):
            err("--no-confirm is refused on postgres URLs (production safety).")
            return 8
        info("--no-confirm honored for non-postgres test URL.")

    # Connect + stamp.
    try:
        with open_connection(db_url) as (kind, conn):
            info(f"Connected ({kind}). Reading current alembic_version...")
            before_rows, before_table = read_current_state(kind, conn)
            info(f"Pre-stamp: table_exists={before_table}, rows={before_rows!r}")
            if len(before_rows) > 1:
                info(f"NOTE: pre-state has {len(before_rows)} rows — DELETE+INSERT "
                     f"will clean up to a single-row state at the target revision.")

            info(f"Stamping revision {args.revision} (DELETE+INSERT)...")
            stamp_revision(kind, conn, args.revision)

            after_rows, after_table = read_current_state(kind, conn)
            info(f"Post-stamp: table_exists={after_table}, rows={after_rows!r}")

            # Verify: exactly one row, equal to target.
            if not after_table:
                err("Post-check: alembic_version table missing. Stamp failed.")
                return 9
            if len(after_rows) != 1:
                err(f"Post-check: expected exactly 1 row, got {len(after_rows)}: "
                    f"{after_rows!r}")
                print_pr_paste(args, host,
                               (before_rows, before_table),
                               (after_rows, after_table))
                return 10
            if after_rows[0] != args.revision:
                err(f"Post-check: row value {after_rows[0]!r} != target "
                    f"{args.revision!r}")
                print_pr_paste(args, host,
                               (before_rows, before_table),
                               (after_rows, after_table))
                return 11

            print_pr_paste(args, host,
                           (before_rows, before_table),
                           (after_rows, after_table))
            info("Stamp complete. Verify on production via psql or smoke_tests.py.")
            return 0
    except Exception as e:
        err(f"Connection or stamp failed: {e.__class__.__name__}: {e}")
        return 12


if __name__ == "__main__":
    sys.exit(main())
