#!/usr/bin/env python3
"""scripts/g-a3-1/smoke_tests.py — post-deploy verification harness.

G-A3.1.1 (Sprint 12+). Codifies the verification pattern from Phase 2b
(2026-05-03): three checks the operator must run after re-enabling
alembic on Render to confirm the deploy is healthy.

Checks (each pass/fail, paste-ready output):
  1. HTTP GET /health → asserts 200 + JSON has database:true
  2. SELECT version_num FROM alembic_version → asserts non-empty
  3. SELECT COUNT(*) FROM hr_employees → asserts query succeeds
     (the count VALUE is not asserted — table existence + queryability
     is enough; this was the table that drove the 12-deploy-failure
     cascade pre-workaround, so a successful query is the meaningful
     signal)

Usage:
    DATABASE_URL=<prod-url> \\
    APP_HEALTH_URL=https://apex-api-ootk.onrender.com/health \\
    python scripts/g-a3-1/smoke_tests.py

Exit codes:
    0 = all three checks pass.
    non-zero = at least one check failed.

Cross-references:
  - scripts/g-a3-1/phase-2b-runbook.md § 6 (the canonical verification spec)
  - APEX_BLUEPRINT/09 § 2 G-A3.1 closure paragraph (the verification
    actually run on 2026-05-03)
"""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from contextlib import contextmanager
from urllib.parse import urlparse


# ──────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────

DEFAULT_HEALTH_URL = "https://apex-api-ootk.onrender.com/health"


def status(ok: bool, label: str, detail: str = "") -> None:
    """Print a single-line check result."""
    mark = "✓" if ok else "✗"
    suffix = f"  {detail}" if detail else ""
    print(f"  [{mark}] {label}{suffix}")


@contextmanager
def open_connection(url: str):
    """Open postgres or sqlite connection. Mirror of stamp_head.py helper."""
    if url.startswith(("postgres://", "postgresql://")):
        try:
            import psycopg2
        except ImportError as e:
            raise RuntimeError(
                "psycopg2 not available. Run scripts/g-a3-1/install_prereqs.{ps1,sh}."
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
            f"Unsupported DATABASE_URL scheme: {url[:20]}..."
        )


# ──────────────────────────────────────────────────────────────────
# Check 1: HTTP /health
# ──────────────────────────────────────────────────────────────────

def check_health(health_url: str) -> tuple[bool, str]:
    """GET /health and assert 200 + JSON body has database:true.

    Returns (ok, detail). detail is paste-ready (no full body, just
    status code + database flag).
    """
    parsed = urlparse(health_url)
    if parsed.scheme not in ("http", "https"):
        return False, f"non-http scheme {parsed.scheme!r}"

    try:
        req = urllib.request.Request(health_url, method="GET")
        with urllib.request.urlopen(req, timeout=15) as resp:
            code = resp.status
            body_bytes = resp.read()
    except Exception as e:
        return False, f"request failed: {e.__class__.__name__}: {e}"

    if code != 200:
        return False, f"HTTP {code}"

    try:
        body = json.loads(body_bytes.decode("utf-8", errors="replace"))
    except Exception as e:
        return False, f"non-JSON body: {e}"

    db_ok = bool(body.get("database"))
    if not db_ok:
        return False, f"HTTP 200 but database={body.get('database')!r}"

    return True, f"HTTP 200, database={db_ok}"


# ──────────────────────────────────────────────────────────────────
# Check 2: alembic_version row
# ──────────────────────────────────────────────────────────────────

def check_alembic_version(kind: str, conn) -> tuple[bool, str]:
    """SELECT version_num FROM alembic_version → assert non-empty."""
    cur = conn.cursor()
    try:
        cur.execute("SELECT version_num FROM alembic_version")
        row = cur.fetchone()
        if not row:
            return False, "table exists but no row"
        version = row[0]
        if not version:
            return False, f"row exists but version_num is empty: {version!r}"
        return True, f"version_num={version}"
    except Exception as e:
        msg = str(e).lower()
        if (
            "undefinedtable" in msg
            or "does not exist" in msg
            or "no such table" in msg
        ):
            return False, "alembic_version table missing"
        return False, f"query failed: {e.__class__.__name__}: {e}"
    finally:
        try:
            cur.close()
        except Exception:
            pass


# ──────────────────────────────────────────────────────────────────
# Check 3: hr_employees query
# ──────────────────────────────────────────────────────────────────

def check_hr_employees(kind: str, conn) -> tuple[bool, str]:
    """SELECT COUNT(*) FROM hr_employees → assert query succeeds.

    Count value is not asserted — table existence + queryability is
    the signal we care about. This was the table at the heart of the
    12-deploy-failure cascade pre-workaround.
    """
    cur = conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM hr_employees")
        row = cur.fetchone()
        count = row[0] if row else None
        return True, f"COUNT(*)={count}"
    except Exception as e:
        return False, f"query failed: {e.__class__.__name__}: {e}"
    finally:
        try:
            cur.close()
        except Exception:
            pass


# ──────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────

def main() -> int:
    health_url = os.environ.get("APP_HEALTH_URL", DEFAULT_HEALTH_URL)
    db_url = os.environ.get("DATABASE_URL")

    print("G-A3.1.1 smoke tests (post-deploy verification)")
    print("=" * 50)
    print(f"  health URL: {health_url}")
    print(f"  DATABASE_URL: {'set' if db_url else 'NOT SET'}")
    print()

    if not db_url:
        print("[stamp_head.py] ERROR: DATABASE_URL env var not set.", file=sys.stderr)
        return 3

    failures: list[str] = []

    # Check 1: HTTP /health
    ok, detail = check_health(health_url)
    status(ok, "HTTP /health → 200 + database:true", detail)
    if not ok:
        failures.append(f"health: {detail}")

    # Checks 2 + 3 share a connection.
    try:
        with open_connection(db_url) as (kind, conn):
            ok2, detail2 = check_alembic_version(kind, conn)
            status(ok2, "alembic_version row present", detail2)
            if not ok2:
                failures.append(f"alembic_version: {detail2}")

            ok3, detail3 = check_hr_employees(kind, conn)
            status(ok3, "hr_employees count query succeeds", detail3)
            if not ok3:
                failures.append(f"hr_employees: {detail3}")
    except Exception as e:
        status(False, "DB connection", f"{e.__class__.__name__}: {e}")
        failures.append(f"db-connect: {e}")

    print()
    print("=" * 50)
    if failures:
        print(f"FAIL: {len(failures)} check(s) failed:")
        for f in failures:
            print(f"  - {f}")
        return 1

    print("PASS: all 3 smoke tests succeeded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
