"""
Tests for app/core/social_auth_verify.py — Google + Apple token verifiers.
Wave 1 PR#2 & PR#3.

These tests cover:
- Dev-bypass behaviour when the provider client-id env var is unset.
- Production refusal when the client-id is unset.
- Route integration: /auth/social/google no longer trusts arbitrary email
  without verification once GOOGLE_OAUTH_CLIENT_ID is configured.
"""

from unittest.mock import patch

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.core import social_auth_verify


class TestGoogleVerifierDevBypass:
    def test_dev_bypass_without_client_id_accepts_email_hint(self, monkeypatch):
        monkeypatch.delenv("GOOGLE_OAUTH_CLIENT_ID", raising=False)
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", False)
        identity = social_auth_verify.verify_google_id_token(
            "any-token", dev_email_hint="USER@example.COM"
        )
        assert identity.email == "user@example.com"
        assert identity.verified is False
        assert identity.provider == "google"

    def test_dev_bypass_requires_email_hint(self, monkeypatch):
        monkeypatch.delenv("GOOGLE_OAUTH_CLIENT_ID", raising=False)
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", False)
        with pytest.raises(HTTPException) as exc:
            social_auth_verify.verify_google_id_token("token", dev_email_hint=None)
        assert exc.value.status_code == 400

    def test_production_without_client_id_fails(self, monkeypatch):
        monkeypatch.delenv("GOOGLE_OAUTH_CLIENT_ID", raising=False)
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", True)
        with pytest.raises(HTTPException) as exc:
            social_auth_verify.verify_google_id_token("token", dev_email_hint="a@b.com")
        assert exc.value.status_code == 500

    def test_invalid_token_fails_when_client_id_set(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_OAUTH_CLIENT_ID", "test-client-id.apps.googleusercontent.com")
        with pytest.raises(HTTPException) as exc:
            social_auth_verify.verify_google_id_token("clearly-not-a-real-id-token")
        assert exc.value.status_code == 401


class TestGoogleVerifierVerifiedPath:
    def test_verified_path_builds_identity(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_OAUTH_CLIENT_ID", "test-client-id.apps.googleusercontent.com")

        fake_claims = {
            "iss": "https://accounts.google.com",
            "aud": "test-client-id.apps.googleusercontent.com",
            "sub": "google-subject-42",
            "email": "Verified@Example.COM",
            "email_verified": True,
            "name": "Test User",
            "picture": "https://example.com/pic.png",
        }
        with patch(
            "google.oauth2.id_token.verify_oauth2_token",
            return_value=fake_claims,
        ):
            identity = social_auth_verify.verify_google_id_token("ok-token")

        assert identity.email == "verified@example.com"
        assert identity.verified is True
        assert identity.subject == "google-subject-42"
        assert identity.display_name == "Test User"

    def test_unverified_email_rejected(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_OAUTH_CLIENT_ID", "test-client-id.apps.googleusercontent.com")
        fake_claims = {
            "iss": "https://accounts.google.com",
            "aud": "test-client-id.apps.googleusercontent.com",
            "sub": "x",
            "email": "a@b.com",
            "email_verified": False,
        }
        with patch("google.oauth2.id_token.verify_oauth2_token", return_value=fake_claims):
            with pytest.raises(HTTPException) as exc:
                social_auth_verify.verify_google_id_token("t")
            assert exc.value.status_code == 401

    def test_wrong_issuer_rejected(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_OAUTH_CLIENT_ID", "test-client-id.apps.googleusercontent.com")
        fake_claims = {
            "iss": "https://evil.example.com",
            "sub": "x",
            "email": "a@b.com",
            "email_verified": True,
        }
        with patch("google.oauth2.id_token.verify_oauth2_token", return_value=fake_claims):
            with pytest.raises(HTTPException) as exc:
                social_auth_verify.verify_google_id_token("t")
            assert exc.value.status_code == 401


class TestAppleVerifierDevBypass:
    def test_dev_bypass_without_client_id(self, monkeypatch):
        monkeypatch.delenv("APPLE_CLIENT_ID", raising=False)
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", False)
        identity = social_auth_verify.verify_apple_identity_token(
            "any-token",
            dev_email_hint="apple@example.com",
            dev_name_hint="Apple User",
        )
        assert identity.email == "apple@example.com"
        assert identity.display_name == "Apple User"
        assert identity.verified is False
        assert identity.provider == "apple"

    def test_production_without_client_id_fails(self, monkeypatch):
        monkeypatch.delenv("APPLE_CLIENT_ID", raising=False)
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", True)
        with pytest.raises(HTTPException) as exc:
            social_auth_verify.verify_apple_identity_token(
                "token", dev_email_hint="a@b.com"
            )
        assert exc.value.status_code == 500


class TestGoogleRouteIntegration:
    """Verify the /auth/social/google route now runs tokens through the verifier."""

    def test_dev_bypass_still_creates_user(self, client: TestClient):
        # No GOOGLE_OAUTH_CLIENT_ID set (conftest didn't set one) → dev bypass.
        resp = client.post(
            "/auth/social/google",
            json={
                "id_token": "fake-but-ok-in-dev",
                "email": "NewUser@example.com",
                "display_name": "New User",
            },
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        # The verifier lowercases the email.
        assert body["user"]["email"] == "newuser@example.com"

    def test_missing_email_in_dev_bypass_rejected(self, client: TestClient):
        resp = client.post(
            "/auth/social/google",
            json={"id_token": "x"},
        )
        assert resp.status_code == 400

    def test_production_without_client_id_rejected(self, client: TestClient, monkeypatch):
        monkeypatch.setattr(social_auth_verify, "_IS_PRODUCTION", True)
        resp = client.post(
            "/auth/social/google",
            json={"id_token": "x", "email": "a@b.com"},
        )
        assert resp.status_code == 500
