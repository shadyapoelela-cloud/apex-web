"""APEX Platform -- app/core/error_helpers.py unit tests.

Coverage target: 100% of 18 statements (G-T1.7b.1, Sprint 9).

Pure-utility module — no FastAPI app, no DB, no env vars. Six tests
cover all four public functions and the two parameter branches in
log_error (default vs caller-supplied correlation_id).
"""

from __future__ import annotations

import logging
import re

import pytest
from fastapi import HTTPException

from app.core.error_helpers import (
    get_traceback,
    handle_route_error,
    log_error,
    safe_dict_response,
)


# ══════════════════════════════════════════════════════════════
# log_error — generated correlation id + structured extras
# ══════════════════════════════════════════════════════════════


class TestLogError:
    def test_returns_12_char_hex_correlation_id(self, caplog):
        """log_error generates a 12-char hex correlation id when none supplied."""
        with caplog.at_level(logging.ERROR, logger="apex.error"):
            cid = log_error(ValueError("boom"), endpoint="POST /x")
        assert isinstance(cid, str)
        assert len(cid) == 12
        # uuid4().hex[:12] is lowercase hex.
        assert re.fullmatch(r"[0-9a-f]{12}", cid) is not None
        # Record was actually emitted.
        assert any("Unhandled error in POST /x" in r.message for r in caplog.records)

    def test_accepts_caller_supplied_correlation_id(self, caplog):
        """Caller can pin the cid (e.g. propagate request id from middleware)."""
        with caplog.at_level(logging.ERROR, logger="apex.error"):
            cid = log_error(
                RuntimeError("pinned"),
                endpoint="GET /y",
                correlation_id="req-abc-123",
            )
        assert cid == "req-abc-123"

    def test_extra_dict_propagates_into_log_record(self, caplog):
        """`extra` keys land on the LogRecord alongside the canonical fields."""
        with caplog.at_level(logging.ERROR, logger="apex.error"):
            log_error(
                KeyError("missing"),
                endpoint="POST /z",
                extra={"tenant_id": "t-42", "user_id": "u-99"},
                correlation_id="cid-zz",
            )
        rec = next(r for r in caplog.records if r.name == "apex.error")
        # Canonical structured fields.
        assert getattr(rec, "correlation_id", None) == "cid-zz"
        assert getattr(rec, "endpoint", None) == "POST /z"
        assert getattr(rec, "exc_type", None) == "KeyError"
        # Caller-supplied extras must propagate.
        assert getattr(rec, "tenant_id", None) == "t-42"
        assert getattr(rec, "user_id", None) == "u-99"


# ══════════════════════════════════════════════════════════════
# handle_route_error — HTTPException with safe detail
# ══════════════════════════════════════════════════════════════


class TestHandleRouteError:
    def test_builds_http_exception_with_safe_detail(self, caplog):
        """The exception detail must NOT leak the underlying str(exc)."""
        with caplog.at_level(logging.ERROR, logger="apex.error"):
            exc = handle_route_error(
                ValueError("internal stacktrace data"),
                user_message="بيانات غير صالحة",
                status_code=400,
                endpoint="POST /sales-invoices",
            )
        assert isinstance(exc, HTTPException)
        assert exc.status_code == 400
        assert isinstance(exc.detail, dict)
        assert exc.detail["success"] is False
        assert exc.detail["error"] == "بيانات غير صالحة"
        # correlation_id propagated to client for support tracing.
        cid = exc.detail["correlation_id"]
        assert isinstance(cid, str) and len(cid) == 12
        # Internal exception text MUST NOT be in the user-facing detail.
        flat = repr(exc.detail)
        assert "internal stacktrace data" not in flat


# ══════════════════════════════════════════════════════════════
# safe_dict_response — uniform success-shape envelope
# ══════════════════════════════════════════════════════════════


class TestSafeDictResponse:
    def test_wraps_arbitrary_kwargs_with_success_flag(self):
        out = safe_dict_response(True, items=[1, 2, 3], page=1)
        assert out == {"success": True, "items": [1, 2, 3], "page": 1}

    def test_failure_path_keeps_shape(self):
        """Even with success=False, the shape is uniform: success + extras."""
        out = safe_dict_response(False, error="not found")
        assert out["success"] is False
        assert out["error"] == "not found"


# ══════════════════════════════════════════════════════════════
# get_traceback — formatted traceback as string
# ══════════════════════════════════════════════════════════════


class TestGetTraceback:
    def test_returns_string_with_exception_class_name(self):
        """get_traceback() emits the standard traceback.format_exception output."""
        try:
            raise RuntimeError("trap")
        except RuntimeError as e:
            tb = get_traceback(e)
        assert isinstance(tb, str)
        assert "RuntimeError" in tb
        assert "trap" in tb
