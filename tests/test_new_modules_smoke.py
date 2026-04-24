"""
Smoke tests for modules added in the April 2026 DevOps track.

These bring the new code under coverage (keeps the CI
--cov-fail-under=10 gate happy) and catch the most common
regressions: import errors, undefined names, and broken
routers. Full-feature tests live in their dedicated files.
"""
from __future__ import annotations

import importlib

import pytest


# ════════════════════════════════════════════════════════════════
# Module import smoke — catches syntax errors + missing deps
# ════════════════════════════════════════════════════════════════
@pytest.mark.parametrize(
    "module_path",
    [
        "app.core.json_schemas",
        "app.core.csrf_middleware",
        "app.core.admin_backup_routes",
        "app.core.observability",
        "app.ops.backup_db",
        "app.phase1.routes.email_verify_routes",
        "app.phase1.routes.totp_routes",
    ],
)
def test_module_imports_cleanly(module_path: str) -> None:
    mod = importlib.import_module(module_path)
    assert mod is not None


# ════════════════════════════════════════════════════════════════
# json_schemas — validator behaviour
# ════════════════════════════════════════════════════════════════
def test_approval_thresholds_accepts_valid() -> None:
    from app.core.json_schemas import ApprovalThresholds

    payload = {
        "je": [
            {"max": 1000, "role": "accountant", "level": 1},
            {"max": 10000, "role": "manager", "level": 2},
            {"max": 100000, "role": "admin", "level": 3},
        ],
        "po": [],
        "exp": [],
    }
    out = ApprovalThresholds.model_validate(payload)
    assert len(out.je) == 3
    assert out.je[0].role == "accountant"
    assert out.je[2].max == 100000


def test_approval_thresholds_rejects_unsorted() -> None:
    from app.core.json_schemas import ApprovalThresholds
    from pydantic import ValidationError

    payload = {
        "je": [
            {"max": 10000, "role": "manager", "level": 2},
            {"max": 1000, "role": "clerk", "level": 1},  # out of order
        ]
    }
    with pytest.raises(ValidationError):
        ApprovalThresholds.model_validate(payload)


def test_approval_thresholds_rejects_unknown_role() -> None:
    from app.core.json_schemas import ApprovalThresholds
    from pydantic import ValidationError

    payload = {"je": [{"max": 1000, "role": "pirate", "level": 1}]}
    with pytest.raises(ValidationError):
        ApprovalThresholds.model_validate(payload)


def test_operating_hours_valid_shapes() -> None:
    from app.core.json_schemas import OperatingHours

    out = OperatingHours.model_validate(
        {"sat": "10:00-23:00", "sun": "09:00-17:00", "fri": "closed"}
    )
    assert out.sat == "10:00-23:00"
    assert out.fri == "closed"
    assert out.mon is None  # unspecified days are None


def test_operating_hours_rejects_garbage() -> None:
    from app.core.json_schemas import OperatingHours
    from pydantic import ValidationError

    for bad in ("25:00-26:00", "abc", "10-23", "10:00to23:00"):
        with pytest.raises(ValidationError):
            OperatingHours.model_validate({"sat": bad})


def test_financial_ratios_all_optional() -> None:
    from app.core.json_schemas import FinancialRatios

    empty = FinancialRatios.model_validate({})
    assert empty.current_ratio is None

    filled = FinancialRatios.model_validate(
        {"current_ratio": 1.5, "debt_to_equity": 0.8, "roa": 0.12}
    )
    assert filled.current_ratio == 1.5
    assert filled.roa == 0.12


def test_applied_rule_citation_optional() -> None:
    from app.core.json_schemas import AppliedRule, AppliedRulesList

    r = AppliedRule.model_validate(
        {
            "rule_code": "IAS16_REVAL",
            "rule_name": "IAS 16 revaluation model",
            "severity": "warning",
            "citation": "IAS 16 §31",
        }
    )
    assert r.rule_code == "IAS16_REVAL"
    assert r.severity == "warning"

    rl = AppliedRulesList.model_validate({"rules": [r.model_dump()]})
    assert len(rl.rules) == 1


# ════════════════════════════════════════════════════════════════
# csrf_middleware — exemption + safe-method behaviour
# ════════════════════════════════════════════════════════════════
def test_csrf_exempt_paths_configured() -> None:
    from app.core.csrf_middleware import _EXEMPT_PREFIXES, _is_exempt

    assert "/health" in _EXEMPT_PREFIXES
    assert "/auth/login" in _EXEMPT_PREFIXES
    assert _is_exempt("/health") is True
    assert _is_exempt("/health/details") is True
    assert _is_exempt("/auth/login") is True
    assert _is_exempt("/auth/login?next=x") is True
    assert _is_exempt("/api/clients") is False


def test_csrf_safe_methods_set() -> None:
    from app.core.csrf_middleware import _SAFE_METHODS

    assert "GET" in _SAFE_METHODS
    assert "HEAD" in _SAFE_METHODS
    assert "OPTIONS" in _SAFE_METHODS
    assert "POST" not in _SAFE_METHODS
    assert "DELETE" not in _SAFE_METHODS


def test_csrf_mint_token_is_unique() -> None:
    from app.core.csrf_middleware import _mint_token

    tokens = {_mint_token() for _ in range(50)}
    # 50 random 32-byte tokens must all be distinct.
    assert len(tokens) == 50
    # token_hex(32) returns 64 hex chars.
    assert all(len(t) == 64 for t in tokens)


# ════════════════════════════════════════════════════════════════
# admin_backup_routes — env-variable introspection helpers
# ════════════════════════════════════════════════════════════════
def test_admin_backup_helpers_callable() -> None:
    from app.core.admin_backup_routes import (
        _admin_secret,
        _check_boto3,
        _check_pg_dump,
        _is_production,
    )

    assert isinstance(_admin_secret(), str)
    assert isinstance(_is_production(), bool)
    assert isinstance(_check_boto3(), bool)
    assert isinstance(_check_pg_dump(), bool)


# ════════════════════════════════════════════════════════════════
# backup_db — CLI helper smoke (no actual dump)
# ════════════════════════════════════════════════════════════════
def test_backup_db_env_helper() -> None:
    from app.ops.backup_db import _env

    assert _env("NONEXISTENT_ENV_VAR_12345", "default") == "default"
    assert _env("NONEXISTENT_ENV_VAR_12345") is None


# ════════════════════════════════════════════════════════════════
# observability — init helpers are idempotent no-ops without env
# ════════════════════════════════════════════════════════════════
def test_observability_sentry_skips_without_dsn(monkeypatch) -> None:
    from app.core import observability

    # Ensure we start clean for this test.
    monkeypatch.setenv("SENTRY_DSN", "")
    # Reset the module's internal flag so the call isn't short-circuited
    # by a previous test.
    monkeypatch.setattr(observability, "_sentry_initialized", False)

    result = observability.init_sentry()
    # No DSN → returns False (not initialised).
    assert result is False


def test_observability_sentry_warns_loudly_in_prod(monkeypatch, caplog) -> None:
    """Production without SENTRY_DSN is a real operational gap — running
    blind means crashes land in the void. The warning must be at WARNING
    level so it surfaces in Render's default log view, not hide as INFO.
    Regression for app/core/observability.py — if someone later downgrades
    the message back to INFO, this test flags it."""
    import logging as _logging
    from app.core import observability

    monkeypatch.setenv("SENTRY_DSN", "")
    monkeypatch.setattr(observability, "_sentry_initialized", False)
    monkeypatch.setattr(observability, "_IS_PRODUCTION", True)

    with caplog.at_level(_logging.WARNING, logger="app.core.observability"):
        result = observability.init_sentry()
    assert result is False
    # At least one WARNING-level record mentioning the gap must exist.
    warnings = [r for r in caplog.records if r.levelno >= _logging.WARNING]
    joined = " ".join(r.getMessage() for r in warnings)
    assert "SENTRY_DSN" in joined or "Sentry" in joined, (
        f"prod-without-Sentry must log a WARNING; got records: "
        f"{[r.levelname + ':' + r.getMessage()[:80] for r in caplog.records]}"
    )


def test_observability_configure_logging_idempotent() -> None:
    from app.core.observability import configure_logging

    # Should never raise, should be safe to call repeatedly.
    configure_logging()
    configure_logging()
    configure_logging()
