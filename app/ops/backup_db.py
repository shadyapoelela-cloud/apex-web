"""
APEX — Nightly Database Backup
══════════════════════════════════════════════════════════════════════

Invoked by the Render cron service `apex-api-backup` at 03:00 UTC.
Dumps the production PostgreSQL database and optionally uploads the
dump to S3. Render's free tier has NO built-in backups, so this is
the primary data-protection line.

Modes:
  • Local-only (BACKUP_S3_BUCKET unset):
      writes the dump to /tmp/apex_backup_YYYYMMDD_HHMMSS.sql.gz
      and logs the size. Render's ephemeral disk wipes it on next
      deploy — so this mode is mostly for testing.
  • S3 upload (BACKUP_S3_BUCKET set):
      same dump, then uploads to s3://<bucket>/apex/<yyyy>/<mm>/<dd>/
      and enforces BACKUP_RETENTION_DAYS (default 30) by deleting
      older objects in the same prefix.

Environment:
  DATABASE_URL            (required) postgres connection string
  BACKUP_S3_BUCKET        optional; bucket name only (no s3:// prefix)
  BACKUP_S3_REGION        optional; defaults to "us-east-1"
  BACKUP_RETENTION_DAYS   optional; defaults to 30
  AWS_ACCESS_KEY_ID       required if BACKUP_S3_BUCKET is set
  AWS_SECRET_ACCESS_KEY   required if BACKUP_S3_BUCKET is set

Exit codes:
  0 = success
  1 = pg_dump failed (DB unreachable, auth error, disk full)
  2 = S3 upload failed (wrapped; the local dump is preserved)
"""
from __future__ import annotations

import gzip
import logging
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] backup: %(message)s",
)
log = logging.getLogger("apex.backup")


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    return v if (v is not None and v != "") else default


def _pg_dump(database_url: str, out_path: Path) -> bool:
    """Run pg_dump and pipe through gzip. Returns True on success."""
    try:
        log.info("Running pg_dump → %s", out_path.name)
        # Use --no-owner so a restore into a different role works.
        # --no-acl skips GRANTs that may reference absent roles.
        dump = subprocess.Popen(
            ["pg_dump", "--no-owner", "--no-acl", "--format=plain", database_url],
            stdout=subprocess.PIPE,
        )
        with gzip.open(out_path, "wb", compresslevel=6) as gz:
            assert dump.stdout is not None
            shutil.copyfileobj(dump.stdout, gz)
        rc = dump.wait()
        if rc != 0:
            log.error("pg_dump exited with code %s", rc)
            return False
        return True
    except FileNotFoundError:
        log.error("pg_dump binary not found (install postgresql-client)")
        return False
    except Exception as e:  # noqa: BLE001
        log.error("pg_dump raised: %s", e)
        return False


def _s3_upload(
    local_path: Path, bucket: str, key: str, region: str
) -> bool:
    """Upload the dump to S3. Boto3 is imported lazily so non-S3 runs
    don't require the dependency.
    """
    try:
        import boto3  # type: ignore
    except ImportError:
        log.error("boto3 not installed — cannot upload to S3")
        return False
    try:
        s3 = boto3.client("s3", region_name=region)
        s3.upload_file(
            str(local_path),
            bucket,
            key,
            ExtraArgs={
                "ServerSideEncryption": "AES256",
                "ContentType": "application/gzip",
                "StorageClass": "STANDARD_IA",  # cheaper for rarely-read backups
            },
        )
        log.info("Uploaded to s3://%s/%s", bucket, key)
        return True
    except Exception as e:  # noqa: BLE001
        log.error("S3 upload failed: %s", e)
        return False


def _s3_purge_old(bucket: str, prefix: str, region: str, keep_days: int) -> int:
    """Delete objects in s3://bucket/prefix older than keep_days.
    Returns count of deleted keys. Silent on failure (non-critical).
    """
    try:
        import boto3  # type: ignore
    except ImportError:
        return 0
    try:
        s3 = boto3.client("s3", region_name=region)
        cutoff = datetime.now(tz=timezone.utc) - timedelta(days=keep_days)
        paginator = s3.get_paginator("list_objects_v2")
        deleted = 0
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get("Contents") or []:
                if obj["LastModified"] < cutoff:
                    s3.delete_object(Bucket=bucket, Key=obj["Key"])
                    deleted += 1
        if deleted:
            log.info("Purged %d backups older than %d days", deleted, keep_days)
        return deleted
    except Exception as e:  # noqa: BLE001
        log.warning("S3 purge failed (non-critical): %s", e)
        return 0


def main() -> int:
    database_url = _env("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is required")
        return 1

    now = datetime.now(tz=timezone.utc)
    stamp = now.strftime("%Y%m%d_%H%M%S")
    local_path = Path("/tmp") / f"apex_backup_{stamp}.sql.gz"

    if not _pg_dump(database_url, local_path):
        return 1

    size_mb = local_path.stat().st_size / (1024 * 1024)
    log.info("Local dump OK: %.2f MB", size_mb)

    bucket = _env("BACKUP_S3_BUCKET")
    if not bucket:
        log.info("BACKUP_S3_BUCKET unset — skipping upload (local-only mode)")
        log.info("Backup complete.")
        return 0

    region = _env("BACKUP_S3_REGION", "us-east-1") or "us-east-1"
    prefix = f"apex/{now:%Y}/{now:%m}/{now:%d}"
    key = f"{prefix}/apex_backup_{stamp}.sql.gz"

    if not _s3_upload(local_path, bucket, key, region):
        return 2

    keep_days = int(_env("BACKUP_RETENTION_DAYS", "30") or "30")
    _s3_purge_old(bucket, "apex/", region, keep_days)

    log.info("Backup complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
