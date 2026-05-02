"""APEX Platform -- app/core/storage_service.py unit tests.

Coverage target: ≥90% of 127 statements (G-T1.7b.4, Sprint 10).

Multi-backend file storage (local filesystem + S3-compatible).
We exercise:

  * `_generate_stored_name` — extension preservation, blank filename.
  * `_get_s3_client` — boto3 success, boto3 ImportError, cached singleton.
  * Local backend: `_local_upload`, `_local_download`, `_local_delete`,
    `_local_get_url` — happy paths + write/read/delete failure branches
    + missing-file branches.
  * S3 backend: `_s3_upload`, `_s3_download`, `_s3_delete`, `_s3_get_url`
    — no-client (boto3 missing), happy paths, exception paths,
    presigned-URL generation success/failure.
  * Public dispatch: `upload_file`, `download_file`, `delete_file`,
    `get_file_url` — both backend branches.

Mock strategy:
  * Local backend uses real `tmp_path` writes (no mocking).
  * S3 backend uses `sys.modules['boto3']` stub (G-T1.7b.1 Stripe pattern)
    + `monkeypatch ss._s3_client` to a MagicMock with controlled methods.
  * `STORAGE_BACKEND` constant monkeypatched per test.
"""

from __future__ import annotations

import sys
import types
from unittest.mock import MagicMock

import pytest

from app.core import storage_service as ss


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture(autouse=True)
def _reset_s3_client(monkeypatch):
    """Each test starts with a fresh _s3_client singleton."""
    monkeypatch.setattr(ss, "_s3_client", None)


@pytest.fixture
def local_dir(tmp_path, monkeypatch):
    """Redirect STORAGE_LOCAL_DIR to a tmp directory."""
    monkeypatch.setattr(ss, "STORAGE_LOCAL_DIR", str(tmp_path))
    return tmp_path


@pytest.fixture
def boto3_stub(monkeypatch):
    """Install a minimal `boto3` stub so `import boto3` succeeds."""
    stub = types.ModuleType("boto3")

    def fake_client(service, **kwargs):
        # Return a MagicMock that records the kwargs it was created with.
        m = MagicMock()
        m._init_kwargs = kwargs
        m._service = service
        return m

    stub.client = fake_client
    monkeypatch.setitem(sys.modules, "boto3", stub)
    return stub


@pytest.fixture
def s3_client_mock(monkeypatch, boto3_stub):
    """Pre-build a MagicMock S3 client and install it as the cached
    `ss._s3_client` (skips the lazy boto3 import)."""
    client = MagicMock()
    monkeypatch.setattr(ss, "_s3_client", client)
    monkeypatch.setattr(ss, "S3_BUCKET", "test-bucket")
    return client


# ══════════════════════════════════════════════════════════════
# _generate_stored_name
# ══════════════════════════════════════════════════════════════


class TestGenerateStoredName:
    def test_preserves_extension(self):
        out = ss._generate_stored_name("invoice.pdf")
        assert out.endswith(".pdf")
        # 32 hex + ".pdf" = 36 chars.
        assert len(out) == 36

    def test_no_extension(self):
        out = ss._generate_stored_name("README")
        # Just 32 hex chars.
        assert len(out) == 32
        assert "." not in out

    def test_blank_filename(self):
        out = ss._generate_stored_name("")
        assert len(out) == 32

    def test_lowercases_extension(self):
        out = ss._generate_stored_name("PHOTO.JPG")
        assert out.endswith(".jpg")

    def test_unique_per_call(self):
        a = ss._generate_stored_name("x.bin")
        b = ss._generate_stored_name("x.bin")
        assert a != b


# ══════════════════════════════════════════════════════════════
# _get_s3_client (lazy + cached)
# ══════════════════════════════════════════════════════════════


class TestGetS3Client:
    def test_returns_none_when_boto3_missing(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "boto3", None)
        assert ss._get_s3_client() is None

    def test_returns_client_and_caches_it(self, boto3_stub, monkeypatch):
        c1 = ss._get_s3_client()
        c2 = ss._get_s3_client()
        assert c1 is c2  # cached singleton
        assert c1._service == "s3"

    def test_passes_endpoint_url_when_set(self, boto3_stub, monkeypatch):
        monkeypatch.setattr(ss, "S3_ENDPOINT_URL", "https://minio.test:9000")
        c = ss._get_s3_client()
        assert c._init_kwargs.get("endpoint_url") == "https://minio.test:9000"

    def test_no_endpoint_url_omits_kwarg(self, boto3_stub, monkeypatch):
        monkeypatch.setattr(ss, "S3_ENDPOINT_URL", "")
        c = ss._get_s3_client()
        assert "endpoint_url" not in c._init_kwargs


# ══════════════════════════════════════════════════════════════
# Local backend
# ══════════════════════════════════════════════════════════════


class TestLocalBackend:
    def test_upload_writes_file_and_returns_path(self, local_dir):
        out = ss._local_upload(b"hello", "greeting.txt", "general", "text/plain")
        assert out["success"] is True
        assert out["path"].startswith("general/")
        assert out["url"] == out["path"]
        # File exists on disk.
        from pathlib import Path
        assert Path(out["stored_path"]).read_bytes() == b"hello"

    def test_upload_failure_returns_error(self, local_dir, monkeypatch):
        # Force open() to raise during the write step.
        real_open = open

        def boom(path, *args, **kwargs):
            mode = args[0] if args else kwargs.get("mode", "r")
            if "wb" in mode:
                raise OSError("disk full")
            return real_open(path, *args, **kwargs)

        monkeypatch.setattr("builtins.open", boom)
        out = ss._local_upload(b"x", "f.txt", "g", None)
        assert out["success"] is False
        assert "disk full" in out["error"]

    def test_download_returns_bytes(self, local_dir):
        # Pre-seed a file.
        target = local_dir / "folder" / "file.bin"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"contents")
        out = ss._local_download("folder/file.bin")
        assert out == b"contents"

    def test_download_missing_returns_none(self, local_dir):
        out = ss._local_download("does/not/exist.bin")
        assert out is None

    def test_download_other_exception_returns_none(self, local_dir, monkeypatch):
        # Force open() to raise something other than FileNotFoundError.
        def boom(*a, **kw):
            raise RuntimeError("permission denied")

        monkeypatch.setattr("builtins.open", boom)
        assert ss._local_download("anything") is None

    def test_delete_existing_file(self, local_dir):
        target = local_dir / "f.txt"
        target.write_bytes(b"x")
        out = ss._local_delete("f.txt")
        assert out == {"success": True}
        assert not target.exists()

    def test_delete_missing_file_still_succeeds(self, local_dir):
        out = ss._local_delete("never-existed.bin")
        # The function silently succeeds when the file doesn't exist.
        assert out == {"success": True}

    def test_delete_failure_returns_error(self, local_dir, monkeypatch):
        target = local_dir / "f.txt"
        target.write_bytes(b"x")

        def boom(path):
            raise OSError("locked")

        monkeypatch.setattr(ss.os, "remove", boom)
        out = ss._local_delete("f.txt")
        assert out["success"] is False
        assert "locked" in out["error"]

    def test_get_url_normalizes_separators(self):
        assert ss._local_get_url("a\\b\\c.txt") == "a/b/c.txt"
        assert ss._local_get_url("a/b/c.txt") == "a/b/c.txt"


# ══════════════════════════════════════════════════════════════
# S3 backend
# ══════════════════════════════════════════════════════════════


class TestS3Backend:
    def test_upload_no_client_returns_error(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "boto3", None)
        out = ss._s3_upload(b"x", "f.txt", "folder", None)
        assert out["success"] is False
        assert "S3 client not available" in out["error"]

    def test_upload_success(self, s3_client_mock):
        s3_client_mock.generate_presigned_url.return_value = (
            "https://test-bucket.s3.amazonaws.com/presigned"
        )
        out = ss._s3_upload(b"data", "report.pdf", "reports", "application/pdf")
        assert out["success"] is True
        assert out["path"].startswith("reports/")
        assert out["url"].startswith("https://")
        # put_object called with correct kwargs.
        s3_client_mock.put_object.assert_called_once()
        kw = s3_client_mock.put_object.call_args.kwargs
        assert kw["Bucket"] == "test-bucket"
        assert kw["Body"] == b"data"
        assert kw["ContentType"] == "application/pdf"

    def test_upload_without_content_type_omits_extra_arg(self, s3_client_mock):
        s3_client_mock.generate_presigned_url.return_value = "https://x"
        out = ss._s3_upload(b"data", "file.bin", "f", None)
        assert out["success"] is True
        kw = s3_client_mock.put_object.call_args.kwargs
        assert "ContentType" not in kw

    def test_upload_exception_returns_error(self, s3_client_mock):
        s3_client_mock.put_object.side_effect = RuntimeError("S3 down")
        out = ss._s3_upload(b"x", "f.bin", "f", None)
        assert out["success"] is False
        assert "S3 down" in out["error"]

    def test_download_no_client_returns_none(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "boto3", None)
        assert ss._s3_download("any/path") is None

    def test_download_success(self, s3_client_mock):
        body = MagicMock()
        body.read.return_value = b"file-contents"
        s3_client_mock.get_object.return_value = {"Body": body}
        out = ss._s3_download("folder/key.bin")
        assert out == b"file-contents"
        s3_client_mock.get_object.assert_called_once_with(
            Bucket="test-bucket", Key="folder/key.bin"
        )

    def test_download_exception_returns_none(self, s3_client_mock):
        s3_client_mock.get_object.side_effect = RuntimeError("S3 fetch err")
        assert ss._s3_download("any/key") is None

    def test_delete_no_client_returns_error(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "boto3", None)
        out = ss._s3_delete("any/key")
        assert out["success"] is False

    def test_delete_success(self, s3_client_mock):
        out = ss._s3_delete("folder/file.bin")
        assert out == {"success": True}
        s3_client_mock.delete_object.assert_called_once_with(
            Bucket="test-bucket", Key="folder/file.bin"
        )

    def test_delete_exception_returns_error(self, s3_client_mock):
        s3_client_mock.delete_object.side_effect = RuntimeError("forbidden")
        out = ss._s3_delete("any/key")
        assert out["success"] is False
        assert "forbidden" in out["error"]

    def test_get_url_no_client_returns_path(self, monkeypatch):
        monkeypatch.setitem(sys.modules, "boto3", None)
        assert ss._s3_get_url("a/b") == "a/b"

    def test_get_url_success(self, s3_client_mock):
        s3_client_mock.generate_presigned_url.return_value = (
            "https://signed.example.com/x?sig=abc"
        )
        out = ss._s3_get_url("folder/key.bin")
        assert out == "https://signed.example.com/x?sig=abc"
        s3_client_mock.generate_presigned_url.assert_called_once()
        # Verify key params were passed.
        call_kwargs = s3_client_mock.generate_presigned_url.call_args.kwargs
        assert call_kwargs["Params"]["Bucket"] == "test-bucket"
        assert call_kwargs["Params"]["Key"] == "folder/key.bin"
        assert call_kwargs["ExpiresIn"] == 3600

    def test_get_url_exception_returns_path(self, s3_client_mock):
        s3_client_mock.generate_presigned_url.side_effect = RuntimeError("bad sig")
        # Falls back to returning the path itself.
        assert ss._s3_get_url("a/b/c") == "a/b/c"


# ══════════════════════════════════════════════════════════════
# Public API dispatch (STORAGE_BACKEND branch)
# ══════════════════════════════════════════════════════════════


class TestPublicAPI:
    def test_upload_file_dispatches_to_local_by_default(
        self, local_dir, monkeypatch
    ):
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "local")
        out = ss.upload_file(b"hello", "f.txt")
        assert out["success"] is True
        assert out["path"].startswith("general/")  # default folder

    def test_upload_file_dispatches_to_s3(self, s3_client_mock, monkeypatch):
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "s3")
        s3_client_mock.generate_presigned_url.return_value = "https://x"
        out = ss.upload_file(b"x", "f.bin", folder="reports")
        assert out["success"] is True
        s3_client_mock.put_object.assert_called_once()

    def test_download_file_dispatches_by_backend(
        self, local_dir, s3_client_mock, monkeypatch
    ):
        # Local seed.
        (local_dir / "f.bin").write_bytes(b"local")
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "local")
        assert ss.download_file("f.bin") == b"local"
        # S3 seed.
        body = MagicMock()
        body.read.return_value = b"s3-data"
        s3_client_mock.get_object.return_value = {"Body": body}
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "s3")
        assert ss.download_file("any/key") == b"s3-data"

    def test_delete_file_dispatches_by_backend(
        self, local_dir, s3_client_mock, monkeypatch
    ):
        (local_dir / "f.bin").write_bytes(b"x")
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "local")
        assert ss.delete_file("f.bin") == {"success": True}
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "s3")
        assert ss.delete_file("any/key") == {"success": True}

    def test_get_file_url_dispatches_by_backend(
        self, s3_client_mock, monkeypatch
    ):
        # Local just normalizes the path.
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "local")
        assert ss.get_file_url("a\\b") == "a/b"
        # S3 returns presigned URL.
        s3_client_mock.generate_presigned_url.return_value = "https://signed"
        monkeypatch.setattr(ss, "STORAGE_BACKEND", "s3")
        assert ss.get_file_url("a/b") == "https://signed"
