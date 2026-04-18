"""
APEX — Environment validation (Wave 1 PR#8).

Single entry point for startup env checks. Replaces the ad-hoc block in
app/main.py::_validate_env() with a structured validator that:

- Refuses to boot in production when any *required* variable is missing
  or still holds a known dev default.
- Logs *warnings* for optional-but-recommended variables (Sentry, Redis,
  OAuth client ids, TOTP encryption key) so misconfigurations surface
  in logs without bringing the service down.
- Returns the (errors, warnings) tuple so tests can assert the exact
  decisions without provoking a real raise.

This runs BEFORE observability is initialized, so we use plain logging.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import List

logger = logging.getLogger(__name__)

_VALID_ENVIRONMENTS = {"development", "dev", "staging", "production", "prod", "test"}

_KNOWN_DEFAULTS = {
    "JWT_SECRET": {"apex-dev-secret-CHANGE-IN-PRODUCTION", "test-secret"},
    "ADMIN_SECRET": {"apex-admin-2026", "test-admin"},
}


@dataclass
class EnvCheck:
    errors: List[str]
    warnings: List[str]

    def is_ok(self) -> bool:
        return not self.errors

    def raise_if_error(self) -> None:
        if self.errors:
            raise RuntimeError(
                "Environment validation failed:\n  - "
                + "\n  - ".join(self.errors)
            )


def _is_production() -> bool:
    return os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def _missing_or_default(var: str) -> bool:
    val = os.environ.get(var, "")
    if not val:
        return True
    defaults = _KNOWN_DEFAULTS.get(var, set())
    return val in defaults


def validate_env() -> EnvCheck:
    """Run all startup env checks and return the structured result."""
    errors: List[str] = []
    warnings: List[str] = []

    env = os.environ.get("ENVIRONMENT", "development").lower()
    if env not in _VALID_ENVIRONMENTS:
        warnings.append(
            f"ENVIRONMENT={env!r} is not one of {sorted(_VALID_ENVIRONMENTS)}"
        )

    is_prod = _is_production()

    # ── Required in production, warned in dev. ──
    if _missing_or_default("JWT_SECRET"):
        (errors if is_prod else warnings).append(
            "JWT_SECRET is missing or using a known dev default"
        )
    elif len(os.environ["JWT_SECRET"].encode("utf-8")) < 32:
        (errors if is_prod else warnings).append(
            "JWT_SECRET must be at least 32 bytes (HS256 RFC 7518)"
        )

    if _missing_or_default("ADMIN_SECRET"):
        (errors if is_prod else warnings).append(
            "ADMIN_SECRET is missing or using a known dev default"
        )
    elif len(os.environ["ADMIN_SECRET"].encode("utf-8")) < 16:
        (errors if is_prod else warnings).append(
            "ADMIN_SECRET should be at least 16 bytes"
        )

    if is_prod and not os.environ.get("DATABASE_URL"):
        errors.append("DATABASE_URL is required in production")

    # CORS_ORIGINS = "*" in production is a real risk — downgrade to
    # warning for now so we don't break existing deployments that rely
    # on it, but call it out loudly.
    cors = os.environ.get("CORS_ORIGINS", "*")
    if is_prod and cors.strip() == "*":
        warnings.append(
            "CORS_ORIGINS='*' in production exposes the API to any origin"
        )

    # ── Warned-only (feature-dependent). ──
    if not os.environ.get("REDIS_URL"):
        warnings.append(
            "REDIS_URL not set — rate limiter falls back to in-memory "
            "(not safe across multiple workers)"
        )

    if not os.environ.get("SENTRY_DSN"):
        warnings.append("SENTRY_DSN not set — no error tracking")

    if not os.environ.get("TOTP_ENCRYPTION_KEY"):
        if is_prod:
            # PR#4's totp_service raises at first use in production; we
            # surface it here too so it's visible at startup rather
            # than only on the first TOTP operation.
            errors.append(
                "TOTP_ENCRYPTION_KEY is required in production "
                "(generate with Fernet.generate_key())"
            )
        else:
            warnings.append(
                "TOTP_ENCRYPTION_KEY not set — dev deriving from JWT_SECRET"
            )

    # OAuth client ids: warning only, since social sign-in is opt-in.
    # Real production deployments that advertise these sign-in buttons
    # should configure the ids explicitly.
    if not os.environ.get("GOOGLE_OAUTH_CLIENT_ID"):
        warnings.append(
            "GOOGLE_OAUTH_CLIENT_ID not set — Google sign-in will fail in production"
        )
    if not os.environ.get("APPLE_CLIENT_ID"):
        warnings.append(
            "APPLE_CLIENT_ID not set — Apple sign-in will fail in production"
        )

    # ZATCA queue worker (Wave 9): off by default so dev doesn't drain
    # the queue silently. In production, flip it on once the real
    # Fatoora HTTP client is wired into the worker's submit_fn.
    if not os.environ.get("ZATCA_WORKER_ENABLED"):
        warnings.append(
            "ZATCA_WORKER_ENABLED not set — retry queue will not process automatically"
        )

    # ZATCA CSID cert encryption (Wave 11): a dedicated key for cert/
    # private-key storage at rest. Dev falls back to a JWT_SECRET-
    # derived key with a warning; production must set it explicitly.
    if not os.environ.get("ZATCA_CERT_ENCRYPTION_KEY"):
        if is_prod:
            errors.append(
                "ZATCA_CERT_ENCRYPTION_KEY is required in production "
                "(generate with Fernet.generate_key())"
            )
        else:
            warnings.append(
                "ZATCA_CERT_ENCRYPTION_KEY not set — dev deriving from JWT_SECRET"
            )

    # Bank feeds token encryption (Wave 13): same pattern as TOTP + CSID.
    # A dedicated key lets ops rotate bank credentials independently.
    if not os.environ.get("BANK_FEEDS_ENCRYPTION_KEY"):
        if is_prod:
            errors.append(
                "BANK_FEEDS_ENCRYPTION_KEY is required in production "
                "(generate with Fernet.generate_key())"
            )
        else:
            warnings.append(
                "BANK_FEEDS_ENCRYPTION_KEY not set — dev deriving from JWT_SECRET"
            )

    return EnvCheck(errors=errors, warnings=warnings)


def run_and_log() -> EnvCheck:
    """Convenience: run validate_env(), log every warning, then raise
    if there are any errors. Called once from app/main.py at import."""
    result = validate_env()
    for w in result.warnings:
        logger.warning("⚠ %s", w)
    result.raise_if_error()
    return result
