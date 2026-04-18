"""
Tests for app/core/auth_utils.py — JWT secret enforcement and token extraction.
Wave 1 PR#1: verify the security guardrails around JWT_SECRET length and
production refusal to start with a missing or short secret.
"""

import importlib
import os
import sys

import pytest


def _reload_auth_utils():
    """Force re-evaluation of the module-level JWT_SECRET validation."""
    sys.modules.pop("app.core.auth_utils", None)
    return importlib.import_module("app.core.auth_utils")


class TestJwtSecretValidation:
    def test_production_requires_secret(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "production")
        monkeypatch.delenv("JWT_SECRET", raising=False)
        with pytest.raises(RuntimeError, match="JWT_SECRET env var is REQUIRED"):
            _reload_auth_utils()

    def test_production_rejects_short_secret(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "production")
        monkeypatch.setenv("JWT_SECRET", "tooshort")
        with pytest.raises(RuntimeError, match="at least 32 bytes"):
            _reload_auth_utils()

    def test_production_accepts_32_byte_secret(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "production")
        monkeypatch.setenv("JWT_SECRET", "a" * 32)
        mod = _reload_auth_utils()
        assert mod.JWT_SECRET == "a" * 32
        assert mod.JWT_ALGORITHM == "HS256"

    def test_development_warns_on_short_secret_but_runs(self, monkeypatch, caplog):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "shortdev")
        mod = _reload_auth_utils()
        assert mod.JWT_SECRET == "shortdev"
        assert any("at least 32 bytes" in r.message for r in caplog.records)

    def test_development_uses_fallback_when_missing(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.delenv("JWT_SECRET", raising=False)
        mod = _reload_auth_utils()
        assert mod.JWT_SECRET.startswith("apex-dev-secret")
        assert len(mod.JWT_SECRET.encode("utf-8")) >= 32

    def teardown_method(self):
        # Restore the environment set by conftest.py so other tests keep working.
        os.environ["ENVIRONMENT"] = "development"
        os.environ["JWT_SECRET"] = "apex-test-jwt-secret-32bytes-min-length"
        _reload_auth_utils()


class TestExtractUserId:
    def test_missing_header_raises_401(self):
        import jwt as pyjwt
        from fastapi import HTTPException

        mod = _reload_auth_utils()
        with pytest.raises(HTTPException) as exc:
            mod.extract_user_id(None)
        assert exc.value.status_code == 401

    def test_invalid_token_raises_401(self):
        from fastapi import HTTPException

        mod = _reload_auth_utils()
        with pytest.raises(HTTPException) as exc:
            mod.extract_user_id("Bearer not-a-real-token")
        assert exc.value.status_code == 401

    def test_valid_token_returns_sub(self):
        import jwt as pyjwt
        from datetime import datetime, timedelta, timezone

        mod = _reload_auth_utils()
        payload = {
            "sub": "user-42",
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        }
        token = pyjwt.encode(payload, mod.JWT_SECRET, algorithm=mod.JWT_ALGORITHM)
        assert mod.extract_user_id(f"Bearer {token}") == "user-42"
