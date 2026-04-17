"""
APEX Platform -- Alembic migration runner.

Policy:
  - Production: migrations MUST run on startup; failure is fatal.
  - Development: migrations run if alembic is available; otherwise falls
    back to SQLAlchemy create_all (legacy path), which is fine for local dev
    and tests where we want immediate schema from ORM models.

Usage (in app startup):
    from app.core.db_migrations import run_migrations_on_startup
    run_migrations_on_startup()

CLI equivalent: `alembic upgrade head`
"""

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")
# Explicit opt-out for dev/test environments that want the fast ORM create_all path.
RUN_MIGRATIONS_ON_STARTUP = os.environ.get("RUN_MIGRATIONS_ON_STARTUP", "").lower()


def _repo_root() -> Path:
    """Return the directory containing alembic.ini (repo root)."""
    return Path(__file__).resolve().parents[2]


def run_migrations_on_startup() -> dict:
    """Run `alembic upgrade head` programmatically.

    Returns a dict describing what happened, for logging.

    Raises RuntimeError in production if the migration fails — the app
    must not start against an un-migrated schema.
    """
    # Explicit escape hatches.
    if RUN_MIGRATIONS_ON_STARTUP == "false":
        logger.info("Migrations skipped: RUN_MIGRATIONS_ON_STARTUP=false")
        return {"ran": False, "reason": "disabled_by_env"}
    # Default: run in prod, optional in dev. Respect an explicit "true" in dev.
    if not IS_PRODUCTION and RUN_MIGRATIONS_ON_STARTUP != "true":
        logger.info(
            "Migrations skipped (dev default). Set RUN_MIGRATIONS_ON_STARTUP=true to enable."
        )
        return {"ran": False, "reason": "dev_default"}

    try:
        from alembic import command
        from alembic.config import Config
    except ImportError as e:
        msg = f"Alembic not installed: {e}"
        if IS_PRODUCTION:
            raise RuntimeError(msg) from e
        logger.warning("%s — falling back to create_all in dev", msg)
        return {"ran": False, "reason": "alembic_missing"}

    ini_path = _repo_root() / "alembic.ini"
    if not ini_path.exists():
        msg = f"alembic.ini not found at {ini_path}"
        if IS_PRODUCTION:
            raise RuntimeError(msg)
        logger.warning(msg)
        return {"ran": False, "reason": "ini_missing"}

    logger.info("Running alembic upgrade head …")
    try:
        cfg = Config(str(ini_path))
        # env.py reads DATABASE_URL at runtime; nothing else to wire here.
        command.upgrade(cfg, "head")
        logger.info("Alembic migrations applied")
        return {"ran": True}
    except Exception as e:
        msg = f"Alembic upgrade failed: {e}"
        logger.error(msg, exc_info=True)
        if IS_PRODUCTION:
            raise RuntimeError(msg) from e
        return {"ran": False, "reason": "failed", "error": str(e)}
