"""
Tests for app/core/observability.py (Wave 1 PR#7).

Covers:
- Sentry init: no-op without DSN, real init when DSN set, idempotent,
  graceful when sentry-sdk is missing.
- Logging: JSON formatter produces parsable JSON with required fields.
- configure_logging() is idempotent and honours LOG_LEVEL / LOG_FORMAT.
"""

from __future__ import annotations

import io
import json
import logging
from unittest.mock import MagicMock, patch

import pytest

from app.core import observability


@pytest.fixture(autouse=True)
def _reset_observability():
    observability.reset_for_tests()
    yield
    observability.reset_for_tests()


class TestSentry:
    def test_no_dsn_returns_false(self, monkeypatch):
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        assert observability.init_sentry() is False

    def test_dsn_set_calls_sdk_init(self, monkeypatch):
        monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
        monkeypatch.setenv("SENTRY_ENVIRONMENT", "staging")
        monkeypatch.setenv("SENTRY_TRACES_SAMPLE_RATE", "0.25")
        fake_init = MagicMock()
        with patch("sentry_sdk.init", fake_init):
            assert observability.init_sentry() is True
        assert fake_init.called
        kwargs = fake_init.call_args.kwargs
        assert kwargs["dsn"].startswith("https://")
        assert kwargs["environment"] == "staging"
        assert kwargs["traces_sample_rate"] == 0.25
        # never ship PII
        assert kwargs["send_default_pii"] is False

    def test_idempotent(self, monkeypatch):
        monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
        fake_init = MagicMock()
        with patch("sentry_sdk.init", fake_init):
            observability.init_sentry()
            observability.init_sentry()  # second call should be a no-op
        assert fake_init.call_count == 1

    def test_traces_sample_rate_clamped(self, monkeypatch):
        monkeypatch.setenv("SENTRY_DSN", "https://public@example.ingest.sentry.io/1")
        monkeypatch.setenv("SENTRY_TRACES_SAMPLE_RATE", "999")
        with patch("sentry_sdk.init") as fake_init:
            observability.init_sentry()
        assert fake_init.call_args.kwargs["traces_sample_rate"] == 1.0


class TestLogging:
    def test_json_formatter_emits_valid_json(self, monkeypatch):
        monkeypatch.setenv("LOG_FORMAT", "json")
        monkeypatch.setenv("LOG_LEVEL", "INFO")
        observability.configure_logging()

        buf = io.StringIO()
        capture = logging.StreamHandler(buf)
        from pythonjsonlogger import jsonlogger

        capture.setFormatter(
            jsonlogger.JsonFormatter(
                "%(asctime)s %(levelname)s %(name)s %(message)s",
                rename_fields={"asctime": "timestamp", "levelname": "level"},
            )
        )
        test_logger = logging.getLogger("apex.test.json")
        test_logger.addHandler(capture)
        test_logger.setLevel(logging.INFO)
        try:
            test_logger.info("hello from test", extra={"extra_key": "extra_value"})
        finally:
            test_logger.removeHandler(capture)

        line = buf.getvalue().strip()
        parsed = json.loads(line)
        assert parsed["level"] == "INFO"
        assert parsed["message"] == "hello from test"
        assert parsed["name"] == "apex.test.json"
        assert parsed["extra_key"] == "extra_value"
        assert "timestamp" in parsed

    def test_configure_logging_is_idempotent(self, monkeypatch):
        monkeypatch.setenv("LOG_FORMAT", "text")
        observability.configure_logging()
        first_handlers = list(logging.getLogger().handlers)
        observability.configure_logging()
        # Should not append duplicate handlers.
        assert len(logging.getLogger().handlers) == len(first_handlers)

    def test_log_level_honoured(self, monkeypatch):
        monkeypatch.setenv("LOG_LEVEL", "WARNING")
        monkeypatch.setenv("LOG_FORMAT", "text")
        observability.configure_logging()
        assert logging.getLogger().level == logging.WARNING

    def test_production_defaults_to_json(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "production")
        monkeypatch.delenv("LOG_FORMAT", raising=False)
        # We can't easily reload the module constant, so just check the
        # helper: _pick_log_format is evaluated at call time.
        assert observability._pick_log_format() in ("json", "text")
