"""
APEX Platform — Persistent File Storage Service
═══════════════════════════════════════════════════════════════
Multi-backend storage: local filesystem or S3-compatible.

Environment variables:
  STORAGE_BACKEND      "local" or "s3" (default: "local")
  STORAGE_LOCAL_DIR    Local directory for uploads (default: "uploads")
  S3_BUCKET            S3 bucket name
  S3_REGION            S3 region (default: "us-east-1")
  S3_ACCESS_KEY        S3 access key ID
  S3_SECRET_KEY        S3 secret access key
  S3_ENDPOINT_URL      Custom endpoint for S3-compatible services (MinIO, DO Spaces)
"""

import os
import uuid
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ── Configuration ──────────────────────────────────────────────

STORAGE_BACKEND = os.environ.get("STORAGE_BACKEND", "local").lower()
STORAGE_LOCAL_DIR = os.environ.get("STORAGE_LOCAL_DIR", "uploads")

S3_BUCKET = os.environ.get("S3_BUCKET", "")
S3_REGION = os.environ.get("S3_REGION", "us-east-1")
S3_ACCESS_KEY = os.environ.get("S3_ACCESS_KEY", "")
S3_SECRET_KEY = os.environ.get("S3_SECRET_KEY", "")
S3_ENDPOINT_URL = os.environ.get("S3_ENDPOINT_URL", "")

# ── Optional boto3 import ──────────────────────────────────────

_s3_client = None


def _get_s3_client():
    """Lazy-init S3 client. Returns None if boto3 is not installed."""
    global _s3_client
    if _s3_client is not None:
        return _s3_client
    try:
        import boto3

        kwargs = {
            "aws_access_key_id": S3_ACCESS_KEY,
            "aws_secret_access_key": S3_SECRET_KEY,
            "region_name": S3_REGION,
        }
        if S3_ENDPOINT_URL:
            kwargs["endpoint_url"] = S3_ENDPOINT_URL
        _s3_client = boto3.client("s3", **kwargs)
        return _s3_client
    except ImportError:
        logger.error("boto3 is not installed. Install it with: pip install boto3")
        return None


# ── Helpers ────────────────────────────────────────────────────


def _generate_stored_name(filename: str) -> str:
    """Generate a unique filename preserving the original extension."""
    ext = os.path.splitext(filename)[1].lower() if filename else ""
    return f"{uuid.uuid4().hex}{ext}"


# ══════════════════════════════════════════════════════════════
# Local Backend
# ══════════════════════════════════════════════════════════════


def _local_upload(content: bytes, filename: str, folder: str, content_type: Optional[str]) -> dict:
    stored_name = _generate_stored_name(filename)
    rel_path = os.path.join(folder, stored_name)
    abs_dir = os.path.join(STORAGE_LOCAL_DIR, folder)
    abs_path = os.path.join(STORAGE_LOCAL_DIR, rel_path)

    try:
        os.makedirs(abs_dir, exist_ok=True)
        with open(abs_path, "wb") as f:
            f.write(content)
        # Normalize to forward slashes for consistent URL paths
        url_path = rel_path.replace("\\", "/")
        return {"success": True, "path": url_path, "url": url_path, "stored_path": abs_path}
    except Exception as e:
        logger.error("Local upload failed: %s", e, exc_info=True)
        return {"success": False, "error": str(e)}


def _local_download(path: str) -> Optional[bytes]:
    abs_path = os.path.join(STORAGE_LOCAL_DIR, path)
    try:
        with open(abs_path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        logger.warning("File not found for download: %s", abs_path)
        return None
    except Exception as e:
        logger.error("Local download failed: %s", e, exc_info=True)
        return None


def _local_delete(path: str) -> dict:
    abs_path = os.path.join(STORAGE_LOCAL_DIR, path)
    try:
        if os.path.exists(abs_path):
            os.remove(abs_path)
        return {"success": True}
    except Exception as e:
        logger.error("Local delete failed: %s", e, exc_info=True)
        return {"success": False, "error": str(e)}


def _local_get_url(path: str) -> str:
    return path.replace("\\", "/")


# ══════════════════════════════════════════════════════════════
# S3 Backend
# ══════════════════════════════════════════════════════════════


def _s3_upload(content: bytes, filename: str, folder: str, content_type: Optional[str]) -> dict:
    client = _get_s3_client()
    if not client:
        return {"success": False, "error": "S3 client not available (boto3 not installed)"}

    stored_name = _generate_stored_name(filename)
    key = f"{folder}/{stored_name}"

    try:
        extra_args = {}
        if content_type:
            extra_args["ContentType"] = content_type
        client.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=content,
            **extra_args,
        )
        url = _s3_get_url(key)
        return {"success": True, "path": key, "url": url, "stored_path": key}
    except Exception as e:
        logger.error("S3 upload failed: %s", e, exc_info=True)
        return {"success": False, "error": str(e)}


def _s3_download(path: str) -> Optional[bytes]:
    client = _get_s3_client()
    if not client:
        return None
    try:
        response = client.get_object(Bucket=S3_BUCKET, Key=path)
        return response["Body"].read()
    except Exception as e:
        logger.error("S3 download failed: %s", e, exc_info=True)
        return None


def _s3_delete(path: str) -> dict:
    client = _get_s3_client()
    if not client:
        return {"success": False, "error": "S3 client not available"}
    try:
        client.delete_object(Bucket=S3_BUCKET, Key=path)
        return {"success": True}
    except Exception as e:
        logger.error("S3 delete failed: %s", e, exc_info=True)
        return {"success": False, "error": str(e)}


def _s3_get_url(path: str) -> str:
    client = _get_s3_client()
    if not client:
        return path
    try:
        url = client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": path},
            ExpiresIn=3600,
        )
        return url
    except Exception as e:
        logger.error("S3 presigned URL failed: %s", e, exc_info=True)
        return path


# ══════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════


def upload_file(
    content: bytes,
    filename: str,
    folder: str = "general",
    content_type: Optional[str] = None,
) -> dict:
    """
    Upload file to the configured storage backend.

    Returns:
        {"success": True, "path": "folder/uuid_filename", "url": "...", "stored_path": "..."}
        or {"success": False, "error": "..."}
    """
    if STORAGE_BACKEND == "s3":
        return _s3_upload(content, filename, folder, content_type)
    return _local_upload(content, filename, folder, content_type)


def download_file(path: str) -> Optional[bytes]:
    """
    Download file by storage path.

    Returns file bytes or None if not found / error.
    """
    if STORAGE_BACKEND == "s3":
        return _s3_download(path)
    return _local_download(path)


def delete_file(path: str) -> dict:
    """
    Delete file from storage.

    Returns {"success": True} or {"success": False, "error": "..."}
    """
    if STORAGE_BACKEND == "s3":
        return _s3_delete(path)
    return _local_delete(path)


def get_file_url(path: str) -> str:
    """
    Get a URL for accessing the file.

    For local backend: returns the relative path.
    For S3 backend: returns a presigned URL (1 hour expiry).
    """
    if STORAGE_BACKEND == "s3":
        return _s3_get_url(path)
    return _local_get_url(path)
