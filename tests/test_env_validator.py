"""
Tests for app/core/env_validator.py (Wave 1 PR#8).

Verifies that production refuses to boot with missing/default secrets
and that warnings surface for every optional-but-recommended variable.
"""

from __future__ import annotations

import pytest

from app.core import env_validator


def _good_prod_env(monkeypatch):
    """Set a complete, valid production env so other tests can strip
    one variable at a time and assert the failure."""
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("JWT_SECRET", "x" * 40)
    monkeypatch.setenv("ADMIN_SECRET", "y" * 20)
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@localhost/apex")
    monkeypatch.setenv("CORS_ORIGINS", "https://app.apex.sa")
    monkeypatch.setenv("REDIS_URL", "redis://r:6379/0")
    monkeypatch.setenv("SENTRY_DSN", "https://p@s.ingest.sentry.io/1")
    monkeypatch.setenv("TOTP_ENCRYPTION_KEY", "k" * 44)  # looks like a Fernet key
    monkeypatch.setenv("ZATCA_CERT_ENCRYPTION_KEY", "z" * 44)  # Wave 11
    monkeypatch.setenv("GOOGLE_OAUTH_CLIENT_ID", "test.apps.googleusercontent.com")
    monkeypatch.setenv("APPLE_CLIENT_ID", "com.apex.app")


class TestProductionRequirements:
    def test_full_prod_env_passes(self, monkeypatch):
        _good_prod_env(monkeypatch)
        result = env_validator.validate_env()
        assert result.is_ok()
        assert result.errors == []

    def test_missing_jwt_secret_fails(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.delenv("JWT_SECRET", raising=False)
        result = env_validator.validate_env()
        assert not result.is_ok()
        assert any("JWT_SECRET" in e for e in result.errors)

    def test_short_jwt_secret_fails(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.setenv("JWT_SECRET", "too-short")
        result = env_validator.validate_env()
        assert any("at least 32 bytes" in e for e in result.errors)

    def test_default_admin_secret_fails(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.setenv("ADMIN_SECRET", "apex-admin-2026")
        result = env_validator.validate_env()
        assert any("ADMIN_SECRET" in e for e in result.errors)

    def test_short_admin_secret_fails(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.setenv("ADMIN_SECRET", "short")
        result = env_validator.validate_env()
        assert any("at least 16 bytes" in e for e in result.errors)

    def test_missing_database_url_fails(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.delenv("DATABASE_URL", raising=False)
        result = env_validator.validate_env()
        assert any("DATABASE_URL" in e for e in result.errors)

    def test_missing_totp_key_fails_in_prod(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.delenv("TOTP_ENCRYPTION_KEY", raising=False)
        result = env_validator.validate_env()
        assert any("TOTP_ENCRYPTION_KEY" in e for e in result.errors)

    def test_missing_zatca_cert_key_fails_in_prod(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.delenv("ZATCA_CERT_ENCRYPTION_KEY", raising=False)
        result = env_validator.validate_env()
        assert any("ZATCA_CERT_ENCRYPTION_KEY" in e for e in result.errors)

    def test_zatca_cert_key_missing_in_dev_only_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        monkeypatch.setenv("ADMIN_SECRET", "y" * 20)
        monkeypatch.delenv("ZATCA_CERT_ENCRYPTION_KEY", raising=False)
        result = env_validator.validate_env()
        assert result.is_ok()
        assert any("ZATCA_CERT_ENCRYPTION_KEY" in w for w in result.warnings)

    def test_cors_wildcard_is_warning_not_error(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.setenv("CORS_ORIGINS", "*")
        result = env_validator.validate_env()
        # Downgraded to warning so we don't break deployments that
        # still rely on wildcard CORS during migration.
        assert result.is_ok()
        assert any("CORS_ORIGINS" in w for w in result.warnings)


class TestDevelopmentSoftness:
    def test_dev_missing_jwt_only_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.delenv("JWT_SECRET", raising=False)
        result = env_validator.validate_env()
        assert result.is_ok()
        assert any("JWT_SECRET" in w for w in result.warnings)

    def test_dev_default_admin_only_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        monkeypatch.setenv("ADMIN_SECRET", "apex-admin-2026")
        result = env_validator.validate_env()
        assert result.is_ok()
        assert any("ADMIN_SECRET" in w for w in result.warnings)

    def test_dev_missing_totp_key_only_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        monkeypatch.setenv("ADMIN_SECRET", "y" * 20)
        monkeypatch.delenv("TOTP_ENCRYPTION_KEY", raising=False)
        result = env_validator.validate_env()
        assert result.is_ok()
        assert any("TOTP_ENCRYPTION_KEY" in w for w in result.warnings)


class TestWarnings:
    def test_redis_missing_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        monkeypatch.setenv("ADMIN_SECRET", "y" * 20)
        monkeypatch.delenv("REDIS_URL", raising=False)
        result = env_validator.validate_env()
        assert any("REDIS_URL" in w for w in result.warnings)

    def test_sentry_missing_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        result = env_validator.validate_env()
        assert any("SENTRY_DSN" in w for w in result.warnings)

    def test_invalid_environment_warns(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "qa-ish")
        monkeypatch.setenv("JWT_SECRET", "x" * 40)
        result = env_validator.validate_env()
        assert any("ENVIRONMENT" in w for w in result.warnings)


class TestRunAndLog:
    def test_raises_on_errors(self, monkeypatch):
        _good_prod_env(monkeypatch)
        monkeypatch.delenv("JWT_SECRET", raising=False)
        with pytest.raises(RuntimeError, match="JWT_SECRET"):
            env_validator.run_and_log()

    def test_does_not_raise_on_warnings_only(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "development")
        monkeypatch.delenv("JWT_SECRET", raising=False)  # just a warning in dev
        result = env_validator.run_and_log()
        assert result.is_ok()
