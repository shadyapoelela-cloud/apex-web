"""
APEX Platform — Shared Database Utilities
═══════════════════════════════════════════════════════════════
Consolidates duplicate _db(), _exec(), _now() helpers used across
sprint2, sprint4, sprint5, sprint6 routes and services.
"""

from datetime import datetime, timezone
from sqlalchemy import text as _t


def get_db_session():
    """Create a new database session. Caller MUST close it in finally block."""
    from app.phase1.models.platform_models import SessionLocal

    return SessionLocal()


def exec_sql(db, sql: str, params: dict = None):
    """Execute raw SQL with text() wrapper for SQLAlchemy 2.x compatibility."""
    if params:
        return db.execute(_t(sql), params)
    return db.execute(_t(sql))


def utc_now():
    """Return current UTC datetime (timezone-aware)."""
    return datetime.now(timezone.utc)


def utc_now_iso():
    """Return current UTC datetime as ISO string."""
    return datetime.now(timezone.utc).isoformat()
