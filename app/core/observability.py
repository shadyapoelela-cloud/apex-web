"""
APEX — Observability bootstrap (Wave 1 PR#7).

Two concerns:
1) Structured JSON logging so production log aggregators (CloudWatch,
   Datadog, Axiom, Grafana Loki) index the right fields.
2) Sentry for exception + performance tracking. Off by default; turns
   on automatically when SENTRY_DSN is set.

Environment:
- SENTRY_DSN            — enables Sentry. Unset = no-op.
- SENTRY_TRACES_SAMPLE_RATE  (0.0–1.0, default 0.05 in prod, 0.0 in dev)
- SENTRY_ENVIRONMENT    — overrides ENVIRONMENT for Sentry tagging.
- SENTRY_RELEASE        — git sha or semver; surfaces in issue UI.
- LOG_FORMAT = json|text (default: json in production, text in dev).
- LOG_LEVEL  = DEBUG|INFO|WARNING|ERROR (default INFO).

Both initializers are idempotent — safe to call more than once (only
the first call takes effect).
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Optional

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")

_sentry_initialized = False
_logging_configured = False


# ── Logging ──


def _pick_log_format() -> str:
    explicit = os.environ.get("LOG_FORMAT", "").lower().strip()
    if explicit in ("json", "text"):
        return explicit
    return "json" if _IS_PRODUCTION else "text"


def configure_logging() -> None:
    """Swap the root handler for JSON or keep human-readable text.

    Uses python-json-logger when format=json. Falls back to the default
    Python formatter on text. Idempotent."""
    global _logging_configured
    if _logging_configured:
        return
    _logging_configured = True

    level_name = os.environ.get("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    fmt = _pick_log_format()

    handler = logging.StreamHandler(stream=sys.stdout)

    if fmt == "json":
        try:
            from pythonjsonlogger import jsonlogger  # type: ignore

            formatter = jsonlogger.JsonFormatter(
                "%(asctime)s %(levelname)s %(name)s %(message)s",
                rename_fields={"asctime": "timestamp", "levelname": "level"},
            )
        except ImportError:
            # Graceful degradation if python-json-logger isn't available
            # (e.g. minimal dev env). Humans can still read the output.
            formatter = logging.Formatter(
                "%(asctime)s %(levelname)s %(name)s %(message)s"
            )
    else:
        formatter = logging.Formatter(
            "%(asctime)s %(levelname)s %(name)s — %(message)s"
        )

    handler.setFormatter(formatter)

    root = logging.getLogger()
    # Remove pre-existing stream handlers so we don't double-log.
    for h in list(root.handlers):
        if isinstance(h, logging.StreamHandler) and h is not handler:
            root.removeHandler(h)
    root.addHandler(handler)
    root.setLevel(level)


# ── Sentry ──


def _default_traces_rate() -> float:
    override = os.environ.get("SENTRY_TRACES_SAMPLE_RATE")
    if override is not None:
        try:
            return max(0.0, min(1.0, float(override)))
        except ValueError:
            pass
    return 0.05 if _IS_PRODUCTION else 0.0


def init_sentry(dsn: Optional[str] = None) -> bool:
    """Initialize Sentry if SENTRY_DSN is set. Returns True if Sentry was
    activated, False if skipped (no DSN or SDK missing). Idempotent."""
    global _sentry_initialized
    if _sentry_initialized:
        return True

    dsn = dsn or os.environ.get("SENTRY_DSN")
    if not dsn:
        logging.getLogger(__name__).info(
            "Sentry disabled — SENTRY_DSN not set."
        )
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
    except ImportError:
        logging.getLogger(__name__).warning(
            "Sentry DSN present but sentry-sdk not installed — skipping."
        )
        return False

    sentry_sdk.init(
        dsn=dsn,
        integrations=[FastApiIntegration(), SqlalchemyIntegration()],
        environment=os.environ.get("SENTRY_ENVIRONMENT")
        or os.environ.get("ENVIRONMENT", "development"),
        release=os.environ.get("SENTRY_RELEASE"),
        traces_sample_rate=_default_traces_rate(),
        send_default_pii=False,  # never ship user PII to Sentry
        attach_stacktrace=True,
    )
    _sentry_initialized = True
    logging.getLogger(__name__).info("Sentry initialized.")
    return True


def reset_for_tests() -> None:
    """Only for the test suite — lets each test run init fresh."""
    global _sentry_initialized, _logging_configured
    _sentry_initialized = False
    _logging_configured = False
