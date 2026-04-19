"""Tests for app.phase1.routes.social_auth_routes.

Covers:
  - Google sign-in: invalid token rejected, valid token accepted (mocked)
  - Apple sign-in: malformed / invalid token rejected
  - Mobile send-code: flow with console SMS backend
  - Mobile verify: correct + incorrect code paths
"""

import os
from unittest.mock import patch

import pytest

os.environ["SMS_BACKEND"] = "console"


# ── Google Sign-In ────────────────────────────────────────────


def test_google_rejects_missing_token(client):
    resp = client.post("/auth/social/google", json={"id_token": "", "email": "a@b.com"})
    assert resp.status_code == 401


def test_google_rejects_tokeninfo_non_200(client):
    """If Google's tokeninfo endpoint returns non-200, we must reject.

    Note: GOOGLE_CLIENT_ID is patched so the route takes the tokeninfo
    validation path (not the dev bypass that fires when no CLIENT_ID is
    configured).
    """
    fake_resp = type("R", (), {"status_code": 400, "json": lambda self: {}})()
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-client"):
        with patch("requests.get", return_value=fake_resp):
            resp = client.post(
                "/auth/social/google",
                json={"id_token": "bogus", "email": "a@b.com"},
            )
    assert resp.status_code == 401


def test_google_accepts_valid_token(client):
    """Happy path: Google tokeninfo returns verified claims → user created."""
    claims = {
        "aud": "test-google-client-id",
        "iss": "https://accounts.google.com",
        "email": "google_user@example.com",
        "email_verified": True,
        "name": "Google User",
        "sub": "google-sub-id-123",
    }
    fake_resp = type("R", (), {"status_code": 200, "json": lambda self: claims})()
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-google-client-id"):
        with patch("requests.get", return_value=fake_resp):
            resp = client.post(
                "/auth/social/google",
                json={"id_token": "valid-token"},
            )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["success"] is True
    assert data["user"]["email"] == "google_user@example.com"


def test_google_rejects_wrong_audience(client):
    """Token aud not matching GOOGLE_CLIENT_ID must be rejected."""
    claims = {
        "aud": "attacker-client-id",
        "iss": "https://accounts.google.com",
        "email": "victim@example.com",
        "email_verified": True,
    }
    fake_resp = type("R", (), {"status_code": 200, "json": lambda self: claims})()
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "apex-real-client-id"):
        with patch("requests.get", return_value=fake_resp):
            resp = client.post(
                "/auth/social/google",
                json={"id_token": "stolen"},
            )
    assert resp.status_code == 401


def test_google_rejects_unverified_email(client):
    claims = {
        "aud": "test-google-client-id",
        "iss": "https://accounts.google.com",
        "email": "unverified@example.com",
        "email_verified": False,
    }
    fake_resp = type("R", (), {"status_code": 200, "json": lambda self: claims})()
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-google-client-id"):
        with patch("requests.get", return_value=fake_resp):
            resp = client.post("/auth/social/google", json={"id_token": "t"})
    assert resp.status_code == 401


# ── Apple Sign-In ─────────────────────────────────────────────


def test_apple_rejects_missing_token(client):
    resp = client.post(
        "/auth/social/apple",
        json={"identity_token": "", "authorization_code": "x"},
    )
    assert resp.status_code == 401


def test_apple_rejects_malformed_token(client, monkeypatch):
    """A non-JWT string must be rejected by the JWK-validating path.

    Note: APPLE_CLIENT_ID is set so the route takes the JWK validation
    path (not the dev bypass that fires when no CLIENT_ID is configured).
    """
    monkeypatch.setenv("APPLE_CLIENT_ID", "com.test.apex")
    resp = client.post(
        "/auth/social/apple",
        json={"identity_token": "not-a-jwt", "authorization_code": "x"},
    )
    assert resp.status_code == 401


# ── Mobile OTP ────────────────────────────────────────────────


def _fresh_otp_store():
    from app.core import otp_store

    otp_store._backend_instance = None


def test_mobile_send_code_then_verify(client):
    _fresh_otp_store()
    # Send
    resp = client.post(
        "/auth/mobile/send-code",
        json={"mobile_country_code": "+966", "mobile_number": "501234567"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["success"] is True
    assert data["mobile"] == "+966501234567"

    # Pull the generated code straight from the store (test-only access)
    from app.core.otp_store import get_store

    store = get_store()
    # We don't have the plaintext; verify the wrong-code path first
    resp = client.post(
        "/auth/mobile/verify",
        json={
            "mobile_country_code": "+966",
            "mobile_number": "501234567",
            "verification_code": "000000",
        },
    )
    # Wrong code → 401 (and it counts as one attempt)
    assert resp.status_code == 401


def test_mobile_verify_rejects_short_code(client):
    resp = client.post(
        "/auth/mobile/verify",
        json={
            "mobile_country_code": "+966",
            "mobile_number": "500000000",
            "verification_code": "12",
        },
    )
    # No code stored + wrong length → unauthorized
    assert resp.status_code == 401


def test_mobile_send_code_rate_limit(client):
    """Two rapid sends to the same number should cool-down."""
    _fresh_otp_store()
    phone = {"mobile_country_code": "+966", "mobile_number": "512222222"}

    first = client.post("/auth/mobile/send-code", json=phone)
    assert first.status_code == 200

    second = client.post("/auth/mobile/send-code", json=phone)
    assert second.status_code == 429


def test_mobile_full_flow_with_correct_code(client):
    """End-to-end: send, peek at the stored hash, use generate_otp injection."""
    _fresh_otp_store()
    phone = {"mobile_country_code": "+966", "mobile_number": "599000000"}

    # Patch generate_otp to produce a known value so we can verify end-to-end.
    with patch("app.core.otp_store.generate_otp", return_value="123456"):
        send = client.post("/auth/mobile/send-code", json=phone)
        assert send.status_code == 200

    verify = client.post(
        "/auth/mobile/verify",
        json={**phone, "verification_code": "123456"},
    )
    assert verify.status_code == 200, verify.text
    assert verify.json()["verified"] is True
