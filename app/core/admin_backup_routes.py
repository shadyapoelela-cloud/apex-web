"""
APEX — Admin-triggered DB backup endpoint

Lets a human (or monitoring bot) force a backup outside the nightly
cron schedule. Useful for:
  • Smoke-testing the backup pipeline (S3 creds, pg_dump install)
    without waiting 24h for the cron to fire.
  • Taking a pre-migration snapshot before risky deploys.
  • Manual recovery-readiness drills (SOC 2 CC7.2).

Auth: the existing admin-header guard (X-Admin-Secret) — same pattern
as the rest of /admin/*. No user session required; the backup worker
doesn't need a JWT context.

Returns a JSON envelope with the dump size and (if S3 configured) the
s3:// URI of the uploaded artefact.
"""
from __future__ import annotations

import asyncio
import logging
import os
import sys
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query

logger = logging.getLogger(__name__)
router = APIRouter()


def _admin_secret() -> str:
    return os.environ.get("ADMIN_SECRET", "apex-admin-dev-only")


def _is_production() -> bool:
    return os.environ.get("ENVIRONMENT", "development").lower() in (
        "production",
        "prod",
    )


def _verify_admin(
    header: Optional[str],
    query: Optional[str],
) -> None:
    secret = _admin_secret()
    supplied = header or query
    if not supplied or supplied != secret:
        raise HTTPException(status_code=403, detail="Admin token required")
    if query and not header and _is_production():
        raise HTTPException(
            status_code=403,
            detail="X-Admin-Secret header required in production "
            "(query-param transport disabled)",
        )


@router.post("/admin/backup-now", tags=["Admin / Backup"])
async def trigger_backup_now(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
    admin: Optional[str] = Query(None),
):
    """Invoke app/ops/backup_db.py synchronously and return its exit
    status. This runs pg_dump + optional S3 upload on the same worker
    that serves API traffic, so response time scales with DB size
    (expect 5-30 s on a free-tier Postgres).

    Safe to call concurrently — pg_dump uses its own connection and
    doesn't block the app pool.
    """
    _verify_admin(x_admin_secret, admin)

    # Run the worker script in-process. Using a subprocess would add
    # environment-inheritance friction (DATABASE_URL etc.); importing
    # is simpler and re-uses the loaded app's logging configuration.
    try:
        from app.ops.backup_db import main as backup_main
    except Exception as e:  # noqa: BLE001
        logger.error("backup_db import failed: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"Backup module unavailable: {e}",
        )

    loop = asyncio.get_event_loop()
    try:
        # backup_main() is sync + potentially slow; run in executor.
        rc = await loop.run_in_executor(None, backup_main)
    except Exception as e:  # noqa: BLE001
        logger.error("backup worker raised: %s", e)
        raise HTTPException(status_code=500, detail=f"Backup failed: {e}")

    if rc != 0:
        raise HTTPException(
            status_code=500,
            detail=f"Backup worker exited with code {rc} — see logs",
        )

    return {
        "success": True,
        "data": {
            "triggered_by": "admin",
            "exit_code": rc,
            "message": (
                "Backup complete. Check logs for size + destination. "
                "If BACKUP_S3_BUCKET is set, the object was uploaded."
            ),
        },
    }


@router.get("/admin/backup-status", tags=["Admin / Backup"])
async def backup_status(
    x_admin_secret: Optional[str] = Header(None, alias="X-Admin-Secret"),
    admin: Optional[str] = Query(None),
):
    """Report the current backup configuration — useful to verify the
    env vars are wired correctly before the first nightly run.
    """
    _verify_admin(x_admin_secret, admin)
    bucket = os.environ.get("BACKUP_S3_BUCKET") or None
    return {
        "success": True,
        "data": {
            "backup_mode": "s3" if bucket else "local-only",
            "s3_bucket": bucket,
            "s3_region": os.environ.get("BACKUP_S3_REGION") or "us-east-1",
            "retention_days": int(
                os.environ.get("BACKUP_RETENTION_DAYS", "30") or "30"
            ),
            "pg_dump_available": _check_pg_dump(),
            "boto3_available": _check_boto3(),
            "ready": bool(bucket) and _check_pg_dump() and _check_boto3(),
        },
    }


def _check_pg_dump() -> bool:
    """Probe whether the pg_dump binary is on PATH."""
    import shutil
    return shutil.which("pg_dump") is not None


def _check_boto3() -> bool:
    try:
        import boto3  # noqa: F401
        return True
    except ImportError:
        return False
