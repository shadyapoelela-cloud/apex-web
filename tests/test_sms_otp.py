"""Tests for app.core.sms_backend and app.core.otp_store.

Covers:
  - SMS console backend (no network)
  - OTP generation, verify (success + failure paths)
  - OTP TTL expiry
  - OTP attempt limit
  - OTP cooldown between sends
"""

import os
import time

import pytest

# Force console backend before any imports touch the backend module
os.environ["SMS_BACKEND"] = "console"


def test_console_backend_returns_success():
    from app.core.sms_backend import send_sms

    result = send_sms("+966501234567", "Test message")
    assert result["success"] is True
    assert result["backend"] == "console"


def test_empty_inputs_fail_gracefully():
    from app.core.sms_backend import send_sms

    assert send_sms("", "body")["success"] is False
    assert send_sms("+966500000000", "")["success"] is False


def test_otp_generation_format():
    from app.core.otp_store import OTP_LENGTH, generate_otp

    code = generate_otp()
    assert code.isdigit()
    assert len(code) == OTP_LENGTH


def _fresh_store():
    """Create a fresh memory backend to avoid cross-test contamination."""
    from app.core import otp_store

    otp_store._backend_instance = None
    return otp_store


def test_otp_happy_path():
    otp_store = _fresh_store()
    phone = "+966500000001"
    code, reason = otp_store.request_otp(phone)
    assert code is not None and reason is None

    ok, reason = otp_store.verify_otp(phone, code)
    assert ok is True and reason is None


def test_otp_wrong_code():
    otp_store = _fresh_store()
    phone = "+966500000002"
    code, _ = otp_store.request_otp(phone)
    assert code is not None

    wrong = "0" * len(code) if code != "0" * len(code) else "1" * len(code)
    ok, reason = otp_store.verify_otp(phone, wrong)
    assert ok is False
    assert reason and "غير صحيح" in reason


def test_otp_attempt_limit_clears_code():
    otp_store = _fresh_store()
    phone = "+966500000003"
    code, _ = otp_store.request_otp(phone)
    assert code is not None

    # Exhaust attempts with wrong code
    wrong = "0" * len(code) if code != "0" * len(code) else "1" * len(code)
    last_reason = None
    for _ in range(10):
        ok, last_reason = otp_store.verify_otp(phone, wrong)
        if "تجاوز" in (last_reason or ""):
            break
    assert last_reason and "تجاوز" in last_reason

    # The correct code should now also fail (record deleted)
    ok, reason = otp_store.verify_otp(phone, code)
    assert ok is False


def test_otp_cooldown_blocks_rapid_resend():
    otp_store = _fresh_store()
    phone = "+966500000004"
    code1, reason = otp_store.request_otp(phone)
    assert code1 is not None and reason is None

    code2, reason = otp_store.request_otp(phone)
    assert code2 is None
    assert reason and "انتظر" in reason


def test_otp_format_validation():
    otp_store = _fresh_store()
    phone = "+966500000005"
    otp_store.request_otp(phone)

    # Non-numeric code rejected
    ok, reason = otp_store.verify_otp(phone, "abcdef")
    assert ok is False
    assert reason and "أرقام" in reason

    # Wrong length rejected
    ok, reason = otp_store.verify_otp(phone, "123")
    assert ok is False


def test_otp_expiry(monkeypatch):
    """After TTL elapses, verification fails with 'expired' reason."""
    otp_store = _fresh_store()
    phone = "+966500000006"
    code, _ = otp_store.request_otp(phone)
    assert code is not None

    # Fast-forward time past TTL
    from app.core import otp_store as mod

    future = time.time() + mod.OTP_TTL_SECONDS + 10
    monkeypatch.setattr("time.time", lambda: future)

    ok, reason = mod.verify_otp(phone, code)
    assert ok is False
    assert reason and "انتهت" in reason


def test_otp_clear():
    otp_store = _fresh_store()
    phone = "+966500000007"
    code, _ = otp_store.request_otp(phone)
    assert code is not None

    otp_store.clear_otp(phone)
    ok, reason = otp_store.verify_otp(phone, code)
    assert ok is False
