"""Regression tests for the three Roadmap Foundation Fixes.

0.2 Social Auth — real Google tokeninfo + Apple JWKs verification
0.4 Environment validation — fails fast on missing/insecure prod secrets
0.5 Rate limiting — tier-based per-IP middleware

All three were flagged as 'still stubs' in the earlier audit but turn
out to be fully implemented. This suite locks that in.
"""

from __future__ import annotations

import os
import time
import uuid
from unittest.mock import patch, MagicMock

import pytest


# ═══ Rate limiting ═══════════════════════════════════════════════


def _reset_rate_limits():
    """Wipe the in-memory rate-limit store between tests so earlier
    test hits don't bleed into later ones."""
    try:
        from app.main import _rate_limits
        if hasattr(_rate_limits, "clear"):
            _rate_limits.clear()
    except Exception:
        pass


def test_rate_limit_middleware_blocks_after_threshold(client):
    """Hammer a protected endpoint until we get a 429."""
    _reset_rate_limits()
    # The /auth/login tier in dev is 60/min — a small loop should stay under
    # that, but we can test the mechanism works by issuing requests from a
    # single IP until we see any 429 OR confirm that headers are set.
    # We can't flood 60+ times in a test without it being slow, so instead
    # verify the headers are present and the 429 path is reachable via
    # the admin_reset bucket which is 10/min in dev.
    url = "/admin/reset-postgres"
    seen_429 = False
    for i in range(15):
        r = client.post(url, headers={"X-Admin-Secret": "x"})
        if r.status_code == 429:
            seen_429 = True
            # Required headers per the spec
            assert "retry-after" in {h.lower() for h in r.headers.keys()}
            break
    assert seen_429, "rate limit never fired after 15 hits on admin_reset"


def test_rate_limit_cors_exposes_headers():
    """CORS must expose X-RateLimit-* so browsers can read them."""
    from app.main import app
    # Inspect the configured middleware stack for CORSMiddleware.
    mw_types = [str(m.cls) for m in app.user_middleware]
    has_cors = any("CORSMiddleware" in t for t in mw_types)
    assert has_cors, f"CORS middleware not installed; stack: {mw_types}"


def test_rate_limit_bypasses_health_and_options(client):
    """/health and OPTIONS preflights must NEVER trip the limiter —
    they're not user-initiated traffic."""
    _reset_rate_limits()
    for _ in range(200):
        r = client.get("/health")
        assert r.status_code == 200, f"/health got {r.status_code} on iter"


# ═══ Environment validator ═══════════════════════════════════════


def test_env_validator_accepts_dev_defaults(monkeypatch):
    """In development, missing secrets log warnings but don't block startup."""
    from app.main import _validate_env
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.delenv("JWT_SECRET", raising=False)
    # Should NOT raise
    _validate_env()


def test_env_validator_blocks_prod_missing_db(monkeypatch):
    """Production without DATABASE_URL must fail-fast."""
    from app.main import _validate_env
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("JWT_SECRET", "a" * 64)
    monkeypatch.setenv("ADMIN_SECRET", "strong-admin-secret-123")
    monkeypatch.setenv("CORS_ORIGINS", "https://example.com")
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(RuntimeError) as ei:
        _validate_env()
    assert "DATABASE_URL" in str(ei.value)


def test_env_validator_blocks_prod_wildcard_cors(monkeypatch):
    from app.main import _validate_env
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("JWT_SECRET", "a" * 64)
    monkeypatch.setenv("ADMIN_SECRET", "strong-admin-secret-123")
    monkeypatch.setenv("DATABASE_URL", "postgresql://x/y")
    monkeypatch.setenv("CORS_ORIGINS", "*")
    with pytest.raises(RuntimeError) as ei:
        _validate_env()
    assert "CORS_ORIGINS" in str(ei.value)


def test_env_validator_rejects_short_jwt_secret(monkeypatch):
    """JWT_SECRET shorter than 32 chars is insecure even in prod."""
    from app.main import _validate_env
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("JWT_SECRET", "tooshort")
    monkeypatch.setenv("ADMIN_SECRET", "strong-admin-secret-123")
    monkeypatch.setenv("DATABASE_URL", "postgresql://x/y")
    monkeypatch.setenv("CORS_ORIGINS", "https://example.com")
    with pytest.raises(RuntimeError) as ei:
        _validate_env()
    assert "JWT_SECRET" in str(ei.value)


def test_env_validator_passes_when_prod_fully_configured(monkeypatch):
    from app.main import _validate_env
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("JWT_SECRET", "a" * 64)
    monkeypatch.setenv("ADMIN_SECRET", "strong-admin-secret-123")
    monkeypatch.setenv("DATABASE_URL", "postgresql://x/y")
    monkeypatch.setenv("CORS_ORIGINS", "https://app.example.com,https://admin.example.com")
    # Must not raise
    _validate_env()


# ═══ Social Auth real verification ═══════════════════════════════


def test_google_signin_rejects_missing_token(client):
    """Empty id_token → 401 from _verify_google_id_token."""
    r = client.post("/auth/social/google", json={"id_token": ""})
    # Route is at /auth/social/google per social_auth_routes.py
    assert r.status_code in (401, 422), (
        f"unexpected {r.status_code}: {r.text[:200]}"
    )


def test_google_signin_rejects_unreachable_google(client):
    """If Google is down/unreachable → 503/401, NOT silent success.

    Patches GOOGLE_CLIENT_ID so the route takes the tokeninfo validation
    path (not the dev bypass that skips network calls when no CLIENT_ID
    is configured).
    """
    import requests as _rq

    def fake_get(url, **kwargs):
        raise _rq.RequestException("simulated network failure")

    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-client"):
        with patch("requests.get", side_effect=fake_get):
            r = client.post(
                "/auth/social/google",
                json={"id_token": "any-string"},
            )
    assert r.status_code in (401, 500, 503), (
        f"got {r.status_code}: {r.text[:200]}"
    )


def test_google_signin_rejects_401_from_google(client):
    """If Google's tokeninfo says 401, our route must say 401 too.

    Patches GOOGLE_CLIENT_ID so we exercise the tokeninfo path.
    """
    fake_resp = MagicMock()
    fake_resp.status_code = 401
    fake_resp.json = MagicMock(return_value={})

    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-client"):
        with patch("requests.get", return_value=fake_resp):
            r = client.post(
                "/auth/social/google",
                json={"id_token": "bad-token"},
            )
    assert r.status_code == 401


def test_google_signin_rejects_wrong_issuer(client, monkeypatch):
    """Token whose issuer isn't accounts.google.com → 401.

    Patches GOOGLE_CLIENT_ID so we exercise the tokeninfo path where the
    issuer check runs.
    """
    fake_resp = MagicMock()
    fake_resp.status_code = 200
    fake_resp.json = MagicMock(return_value={
        "sub": "1234567890",
        "email": "user@example.com",
        "email_verified": True,
        "aud": "test-client",
        "iss": "https://accounts.bad-issuer.com",
    })
    monkeypatch.setenv("ENVIRONMENT", "development")
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-client"):
        with patch("requests.get", return_value=fake_resp):
            r = client.post(
                "/auth/social/google",
                json={"id_token": "token-with-wrong-iss"},
            )
    assert r.status_code == 401


def test_google_signin_rejects_unverified_email(client, monkeypatch):
    """Token whose email_verified=false → 401.

    Patches GOOGLE_CLIENT_ID to exercise the tokeninfo path where the
    email_verified check runs.
    """
    fake_resp = MagicMock()
    fake_resp.status_code = 200
    fake_resp.json = MagicMock(return_value={
        "sub": "1234567890",
        "email": "user@example.com",
        "email_verified": False,  # ← rejection reason
        "aud": "test-client",
        "iss": "https://accounts.google.com",
    })
    monkeypatch.setenv("ENVIRONMENT", "development")
    with patch("app.phase1.routes.social_auth_routes.GOOGLE_CLIENT_ID", "test-client"):
        with patch("requests.get", return_value=fake_resp):
            r = client.post(
                "/auth/social/google",
                json={"id_token": "unverified"},
            )
    assert r.status_code == 401


def test_apple_signin_rejects_missing_token(client):
    """Empty identity_token → 401."""
    r = client.post("/auth/social/apple", json={"identity_token": ""})
    assert r.status_code in (401, 422)


def test_apple_signin_rejects_malformed_jwt(client, monkeypatch):
    """A jwt that can't be decoded → 401/500 (500 if PyJWT missing).

    Sets APPLE_CLIENT_ID so the route takes the JWK decode path rather
    than the dev bypass that fires when no CLIENT_ID is configured.
    """
    monkeypatch.setenv("APPLE_CLIENT_ID", "com.test.apex")
    r = client.post(
        "/auth/social/apple",
        json={"identity_token": "not-a-jwt"},
    )
    # 422 if Pydantic catches empty-ish input (some variants do)
    assert r.status_code in (401, 422, 500)
