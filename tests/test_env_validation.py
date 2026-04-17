"""Tests for the strict production env validation in app.main._validate_env.

We invoke _validate_env directly after re-importing the module so we can
test the prod code path without actually booting the app under prod mode.
"""

import importlib
import os
import sys
from unittest.mock import patch

import pytest


def _invoke_validate(env_overrides: dict):
    """Run _validate_env with the given env vars patched in."""
    with patch.dict(os.environ, env_overrides, clear=False):
        # Re-import main so module-level globals (IS_PRODUCTION, ADMIN_SECRET)
        # pick up the patched values. We only need the function.
        if "app.main" in sys.modules:
            # Grab a fresh copy of the validator.
            import app.main as main_mod

            # Poke the module's internal is_prod detection by calling _validate_env
            # directly — it reads os.environ each call.
            main_mod._validate_env()
        else:
            import app.main as main_mod  # noqa: F401


def test_prod_rejects_default_jwt_secret():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "apex-dev-secret-CHANGE-IN-PRODUCTION",
        "ADMIN_SECRET": "a-very-long-admin-secret-value-here-32c",
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "https://apex-app.com",
    }
    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        _invoke_validate(env)


def test_prod_rejects_wildcard_cors():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "a" * 40,
        "ADMIN_SECRET": "b" * 40,
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "*",
    }
    with pytest.raises(RuntimeError, match="CORS_ORIGINS"):
        _invoke_validate(env)


def test_prod_rejects_missing_database_url():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "a" * 40,
        "ADMIN_SECRET": "b" * 40,
        "CORS_ORIGINS": "https://apex-app.com",
    }
    # Remove DATABASE_URL if present
    with patch.dict(os.environ, env, clear=False):
        os.environ.pop("DATABASE_URL", None)
        import app.main as main_mod

        with pytest.raises(RuntimeError, match="DATABASE_URL"):
            main_mod._validate_env()


def test_prod_rejects_stripe_without_secret_key():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "a" * 40,
        "ADMIN_SECRET": "b" * 40,
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "https://apex-app.com",
        "PAYMENT_BACKEND": "stripe",
    }
    with patch.dict(os.environ, env, clear=False):
        os.environ.pop("STRIPE_SECRET_KEY", None)
        import app.main as main_mod

        with pytest.raises(RuntimeError, match="STRIPE_SECRET_KEY"):
            main_mod._validate_env()


def test_prod_rejects_unifonic_without_sid():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "a" * 40,
        "ADMIN_SECRET": "b" * 40,
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "https://apex-app.com",
        "SMS_BACKEND": "unifonic",
    }
    with patch.dict(os.environ, env, clear=False):
        os.environ.pop("UNIFONIC_APP_SID", None)
        import app.main as main_mod

        with pytest.raises(RuntimeError, match="UNIFONIC_APP_SID"):
            main_mod._validate_env()


def test_prod_accepts_fully_configured_env():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "a" * 40,
        "ADMIN_SECRET": "b" * 40,
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "https://apex-app.com,https://api.apex-app.com",
        "PAYMENT_BACKEND": "mock",
        "EMAIL_BACKEND": "console",
        "SMS_BACKEND": "console",
        "STORAGE_BACKEND": "local",
    }
    _invoke_validate(env)  # no exception


def test_dev_only_warns_for_defaults():
    """In development, defaults should warn but never raise."""
    env = {
        "ENVIRONMENT": "development",
        "JWT_SECRET": "apex-dev-secret-CHANGE-IN-PRODUCTION",
        "ADMIN_SECRET": "apex-admin-2026",
    }
    # Should not raise
    _invoke_validate(env)


def test_short_jwt_secret_rejected_in_prod():
    env = {
        "ENVIRONMENT": "production",
        "JWT_SECRET": "too-short",  # < 32 chars
        "ADMIN_SECRET": "b" * 40,
        "DATABASE_URL": "postgresql://localhost/x",
        "CORS_ORIGINS": "https://apex-app.com",
    }
    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        _invoke_validate(env)
