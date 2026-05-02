"""APEX Platform -- app/core/sms_backend.py unit tests.

Coverage target: ≥95% of 78 statements (G-T1.7b.5, Sprint 10 final).

Multi-backend SMS sender: Unifonic (KSA/MENA), Twilio (global), Console (dev).
We exercise:

  * `_send_via_console` — dev fallback with masked recipient.
  * `_send_via_unifonic` — not-configured, requests-missing, API success
    (success=true), API error (success=false), HTTP non-200, RequestException.
  * `_send_via_twilio` — not-configured (any of 3 vars missing),
    requests-missing, success (200 / 201), HTTP non-200, RequestException.
  * `send_sms` — input validation, backend dispatch, unknown-backend
    fallback to console, exception passthrough.
  * `send_otp_sms` — Arabic message construction.

Mock strategy: `sys.modules['requests']` stub (G-T1.7b.4 slack/teams pattern).
Module-level constants (`SMS_BACKEND`, `UNIFONIC_*`, `TWILIO_*`) and
`_BACKENDS` dict monkeypatched directly. Backend dispatch dict references
the function objects so we monkeypatch via `monkeypatch.setattr(sb, "...")`.
"""

from __future__ import annotations

import sys
import types
from unittest.mock import MagicMock

import pytest

from app.core import sms_backend as sb


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def requests_stub(monkeypatch):
    """Install a stub `requests` module that records POSTs."""
    stub = types.ModuleType("requests")
    calls = []

    class RequestException(Exception):
        pass

    stub.RequestException = RequestException

    class _Resp:
        def __init__(self, status_code=200, json_body=None, text=""):
            self.status_code = status_code
            self._json = json_body or {}
            self.text = text

        def json(self):
            return self._json

    stub._Resp = _Resp

    def _post(url, data=None, auth=None, timeout=None):
        calls.append({
            "url": url, "data": data, "auth": auth, "timeout": timeout,
        })
        # Allow the test to override behavior via stub._next_response.
        if hasattr(stub, "_next_response"):
            r = stub._next_response
            if isinstance(r, Exception):
                raise r
            return r
        return _Resp(200, {"success": True})

    stub.post = _post
    stub._calls = calls
    monkeypatch.setitem(sys.modules, "requests", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# _send_via_console
# ══════════════════════════════════════════════════════════════


class TestConsoleBackend:
    def test_long_number_masked(self):
        out = sb._send_via_console("+966501234567", "hello")
        assert out == {"success": True, "backend": "console"}

    def test_short_number_not_masked(self):
        # 6-char or shorter numbers fall through the masking branch.
        out = sb._send_via_console("12345", "hi")
        assert out["success"] is True


# ══════════════════════════════════════════════════════════════
# _send_via_unifonic
# ══════════════════════════════════════════════════════════════


class TestUnifonicBackend:
    def test_not_configured_when_app_sid_missing(self, monkeypatch):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "")
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out == {"success": False, "error": "Unifonic not configured"}

    def test_requests_missing(self, monkeypatch):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-sid-1")
        monkeypatch.setitem(sys.modules, "requests", None)
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out == {"success": False, "error": "requests library not available"}

    def test_api_success(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-sid-1")
        requests_stub._next_response = requests_stub._Resp(
            200, {"success": True, "data": {"MessageID": "msg-123"}}
        )
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out["success"] is True
        assert out["backend"] == "unifonic"
        assert out["message_id"] == "msg-123"
        # Recipient stripped of leading +.
        assert requests_stub._calls[-1]["data"]["Recipient"] == "966501234567"

    def test_api_returns_success_false(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-sid-1")
        requests_stub._next_response = requests_stub._Resp(
            200, {"success": False, "message": "rate limited"}
        )
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out["success"] is False
        assert out["error"] == "rate limited"

    def test_http_non_200(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-sid-1")
        requests_stub._next_response = requests_stub._Resp(
            500, {}, text="Internal Server Error"
        )
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out["success"] is False
        assert "Unifonic HTTP 500" in out["error"]

    def test_request_exception(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-sid-1")
        # Make the next request raise a RequestException.
        requests_stub._next_response = requests_stub.RequestException("network down")
        out = sb._send_via_unifonic("+966501234567", "hi")
        assert out == {"success": False, "error": "Unifonic request failed"}


# ══════════════════════════════════════════════════════════════
# _send_via_twilio
# ══════════════════════════════════════════════════════════════


class TestTwilioBackend:
    def test_not_configured_when_any_var_missing(self, monkeypatch):
        # Missing account_sid → not configured.
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+1555")
        assert sb._send_via_twilio("+1555", "hi")["error"] == "Twilio not configured"

    def test_requests_missing(self, monkeypatch):
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "ac-1")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+1555")
        monkeypatch.setitem(sys.modules, "requests", None)
        out = sb._send_via_twilio("+1555", "hi")
        assert out == {"success": False, "error": "requests library not available"}

    def test_success_with_201(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "ac-1")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+15551234")
        requests_stub._next_response = requests_stub._Resp(
            201, {"sid": "sid-abc"}
        )
        out = sb._send_via_twilio("+15555555", "hi")
        assert out["success"] is True
        assert out["backend"] == "twilio"
        assert out["message_id"] == "sid-abc"

    def test_adds_plus_prefix_when_missing(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "ac-1")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+15551234")
        requests_stub._next_response = requests_stub._Resp(200, {"sid": "x"})
        sb._send_via_twilio("15555555", "hi")  # no leading +
        assert requests_stub._calls[-1]["data"]["To"] == "+15555555"

    def test_http_non_200(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "ac-1")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+15551234")
        requests_stub._next_response = requests_stub._Resp(403, {}, text="forbidden")
        out = sb._send_via_twilio("+15555555", "hi")
        assert "Twilio HTTP 403" in out["error"]

    def test_request_exception(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "TWILIO_ACCOUNT_SID", "ac-1")
        monkeypatch.setattr(sb, "TWILIO_AUTH_TOKEN", "tok")
        monkeypatch.setattr(sb, "TWILIO_FROM_NUMBER", "+15551234")
        requests_stub._next_response = requests_stub.RequestException("network")
        out = sb._send_via_twilio("+15555555", "hi")
        assert out == {"success": False, "error": "Twilio request failed"}


# ══════════════════════════════════════════════════════════════
# send_sms — public API
# ══════════════════════════════════════════════════════════════


class TestSendSms:
    def test_validates_inputs(self):
        assert sb.send_sms("", "msg")["success"] is False
        assert sb.send_sms("+966501234567", "")["success"] is False

    def test_dispatches_to_console(self, monkeypatch):
        monkeypatch.setattr(sb, "SMS_BACKEND", "console")
        out = sb.send_sms("+966501234567", "hi")
        assert out["backend"] == "console"

    def test_dispatches_to_configured_backend(self, monkeypatch, requests_stub):
        monkeypatch.setattr(sb, "SMS_BACKEND", "unifonic")
        monkeypatch.setattr(sb, "UNIFONIC_APP_SID", "app-1")
        requests_stub._next_response = requests_stub._Resp(
            200, {"success": True, "data": {"MessageID": "x"}}
        )
        out = sb.send_sms("+966501234567", "hi")
        assert out["backend"] == "unifonic"

    def test_unknown_backend_falls_back_to_console(self, monkeypatch):
        monkeypatch.setattr(sb, "SMS_BACKEND", "no-such-backend")
        # Note: _BACKENDS dict was built at import time; the lookup is on
        # _BACKENDS.get(SMS_BACKEND), so changing SMS_BACKEND is enough.
        out = sb.send_sms("+966501234567", "hi")
        assert out["backend"] == "console"

    def test_backend_exception_caught(self, monkeypatch):
        monkeypatch.setattr(sb, "SMS_BACKEND", "console")
        monkeypatch.setitem(
            sb._BACKENDS, "console",
            lambda to, msg: (_ for _ in ()).throw(RuntimeError("boom")),
        )
        out = sb.send_sms("+966501234567", "hi")
        assert out == {"success": False, "error": "SMS delivery failed"}


# ══════════════════════════════════════════════════════════════
# send_otp_sms
# ══════════════════════════════════════════════════════════════


class TestSendOtpSms:
    def test_otp_message_in_arabic(self, monkeypatch):
        captured = {}

        def fake_send(to, msg):
            captured["to"] = to
            captured["msg"] = msg
            return {"success": True}

        monkeypatch.setattr(sb, "send_sms", fake_send)
        sb.send_otp_sms("+966501234567", "1234", validity_minutes=10)
        assert captured["to"] == "+966501234567"
        # OTP code embedded.
        assert "1234" in captured["msg"]
        assert "APEX" in captured["msg"]
        assert "10" in captured["msg"]
