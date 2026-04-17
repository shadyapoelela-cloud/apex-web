"""
APEX Platform — Schema Drift Auto-Repair
═══════════════════════════════════════════════════════════════
Single source of truth for ADD COLUMN IF NOT EXISTS statements
that reconcile older production DB snapshots with the current
SQLAlchemy model definitions.

Used by:
  • app.main:_run_startup (automatic on every boot)
  • app.main:/admin/reinit-db (manual re-run)

New drift fixes go into DRIFT_FIXES only. Never inline ALTER TABLE
anywhere else.
"""

from __future__ import annotations

import logging
import re
from typing import List, Tuple

from sqlalchemy import text
from sqlalchemy.engine import Engine


# ── Safety allowlists (defense in depth) ──────────────────────────
_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

_TYPE_WHITELIST = frozenset({
    "VARCHAR", "REAL", "INTEGER", "TEXT", "TIMESTAMP",
    "BOOLEAN", "JSON", "JSONB", "NUMERIC", "DATE",
})


# ── Drift fixes registry ──────────────────────────────────────────
# Tuple: (table_name, column_name, column_type_ddl)
# Type DDL may include DEFAULT clause — the first word before space/( is validated.
DRIFT_FIXES: List[Tuple[str, str, str]] = [
    # Security events
    ("user_security_events", "details",             "JSON"),
    ("user_security_events", "user_agent",          "VARCHAR(500)"),

    # Users auth state
    ("users",                "last_login_at",       "TIMESTAMP"),
    ("users",                "locked_until",        "TIMESTAMP"),
    ("users",                "failed_login_count",  "INTEGER DEFAULT 0"),

    # User profile extras
    ("user_profiles",        "avatar_url",          "VARCHAR(500)"),

    # Subscription plans (Render production DB was missing these)
    ("plans",                "currency",            "VARCHAR(3) DEFAULT 'SAR'"),
    ("plans",                "target_user_ar",      "VARCHAR(200)"),
    ("plans",                "target_user_en",      "VARCHAR(200)"),
    ("plans",                "sort_order",          "INTEGER DEFAULT 0"),
    ("plans",                "description_ar",      "TEXT"),
    ("plans",                "description_en",      "TEXT"),

    # Plan features
    ("plan_features",        "value_type",          "VARCHAR(30) DEFAULT 'count'"),
    ("plan_features",        "description_ar",      "TEXT"),
    ("plan_features",        "description_en",      "TEXT"),

    # Entitlements
    ("subscription_entitlements", "value_type",     "VARCHAR(30) DEFAULT 'count'"),

    # Subscriptions
    ("user_subscriptions",   "billing_cycle",       "VARCHAR(20) DEFAULT 'monthly'"),
]


def _type_head(ddl: str) -> str:
    """Extract the SQL type keyword (VARCHAR/INTEGER/...) for validation."""
    return ddl.split(" ", 1)[0].split("(", 1)[0].upper()


def apply_drift_fixes(engine_or_session_factory, fixes=None) -> dict:
    """Run ALTER TABLE IF NOT EXISTS for each registered drift fix.

    Idempotent: PostgreSQL's ADD COLUMN IF NOT EXISTS is a no-op on
    existing columns. SQLite silently ignores unsupported clauses; if
    the column already exists we just catch and move on.

    Arguments:
      engine_or_session_factory: SQLAlchemy Engine OR SessionLocal
        sessionmaker. We accept either so startup (engine) and
        admin endpoint (session) both work.
      fixes: Optional override of DRIFT_FIXES for testing.

    Returns:
      {"added": int, "skipped": int, "errors": int}
    """
    fixes = fixes if fixes is not None else DRIFT_FIXES
    added = 0
    skipped = 0
    errors = 0

    # Resolve to a session
    if hasattr(engine_or_session_factory, "connect") and isinstance(
        engine_or_session_factory, Engine
    ):
        # It's an Engine — use a connection directly
        _session_cm = engine_or_session_factory.begin
        _use_session = False
    else:
        # It's a session factory (e.g. SessionLocal)
        _session_cm = engine_or_session_factory
        _use_session = True

    for table, column, ddl in fixes:
        # Validate identifiers + type
        if not _IDENT_RE.match(table) or not _IDENT_RE.match(column):
            skipped += 1
            continue
        if _type_head(ddl) not in _TYPE_WHITELIST:
            skipped += 1
            continue

        sql = f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {ddl}"

        try:
            if _use_session:
                db = _session_cm()
                try:
                    db.execute(text(sql))
                    db.commit()
                    added += 1
                except Exception:
                    db.rollback()
                    errors += 1
                finally:
                    db.close()
            else:
                with _session_cm() as conn:
                    conn.execute(text(sql))
                    added += 1
        except Exception as e:
            errors += 1
            logging.debug(f"Schema drift '{table}.{column}' skipped: {e}")

    return {"added": added, "skipped": skipped, "errors": errors}


def apply_drift_fixes_on_startup(session_factory) -> None:
    """Convenience wrapper for startup — logs result at INFO/WARNING."""
    try:
        result = apply_drift_fixes(session_factory)
        if result["added"] > 0:
            logging.info(
                f"Schema drift auto-repair: {result['added']} column(s) ensured "
                f"({result['errors']} errors, {result['skipped']} skipped)"
            )
    except Exception as e:
        logging.warning(f"Schema drift repair skipped: {e}")
