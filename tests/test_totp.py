"""
Tests for TOTP 2FA (Wave 1 PR#4).

Covers:
- totp_service: encrypt/decrypt round-trip, recovery code hashing,
  setup_totp returns a valid provisioning URI, verify_totp_code accepts
  valid codes and rejects invalid ones.
- Routes: full /setup → /verify → /status → /disable flow, auth required,
  recovery codes work once, wrong codes fail with 401.
"""

import json
import os
from datetime import datetime, timedelta, timezone

import jwt as pyjwt
import pyotp
import pytest
from fastapi.testclient import TestClient

from app.core import totp_service


@pytest.fixture()
def registered_user(db_session):
    """Create a registered user and return (user_id, auth_header)."""
    from app.phase1.models.platform_models import User, gen_uuid

    uid = gen_uuid()
    user = User(
        id=uid,
        username=f"totp_{uid[:8]}",
        email=f"{uid[:8]}@example.com",
        display_name="TOTP Tester",
        password_hash="x",
    )
    db_session.add(user)
    db_session.commit()

    payload = {
        "sub": uid,
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
    }
    token = pyjwt.encode(payload, os.environ["JWT_SECRET"], algorithm="HS256")
    return uid, {"Authorization": f"Bearer {token}"}


class TestTotpService:
    def test_encrypt_decrypt_round_trip(self):
        enc = totp_service._encrypt_secret("JBSWY3DPEHPK3PXP")
        assert enc != "JBSWY3DPEHPK3PXP"  # actually encrypted
        assert totp_service._decrypt_secret(enc) == "JBSWY3DPEHPK3PXP"

    def test_setup_totp_returns_valid_uri(self):
        result = totp_service.setup_totp("user@example.com")
        assert result.provisioning_uri.startswith("otpauth://totp/")
        assert "APEX" in result.provisioning_uri
        assert len(result.secret_base32) >= 16
        assert len(result.recovery_codes) == 10
        assert all("-" in c and len(c) == 9 for c in result.recovery_codes)

    def test_verify_totp_accepts_correct_code(self):
        secret = pyotp.random_base32()
        enc = totp_service._encrypt_secret(secret)
        code = pyotp.TOTP(secret).now()
        assert totp_service.verify_totp_code(enc, code) is True

    def test_verify_totp_rejects_wrong_code(self):
        secret = pyotp.random_base32()
        enc = totp_service._encrypt_secret(secret)
        assert totp_service.verify_totp_code(enc, "000000") is False

    def test_verify_totp_rejects_empty(self):
        assert totp_service.verify_totp_code("", "123456") is False
        assert totp_service.verify_totp_code("x", "") is False

    def test_recovery_code_hashing_and_consumption(self):
        codes = totp_service._generate_recovery_codes(3)
        hashed_json = totp_service._hash_recovery_codes(codes)
        hashed_list = json.loads(hashed_json)
        assert len(hashed_list) == 3
        # plaintext codes never appear in the stored blob
        for c in codes:
            assert c not in hashed_json

        # consume one
        reduced = totp_service.consume_recovery_code(hashed_json, codes[1])
        assert reduced is not None
        assert len(json.loads(reduced)) == 2
        # same code can't be consumed twice from the reduced blob
        assert totp_service.consume_recovery_code(reduced, codes[1]) is None

    def test_recovery_code_case_normalization(self):
        codes = totp_service._generate_recovery_codes(1)
        hashed_json = totp_service._hash_recovery_codes(codes)
        # lowercase form, via the normalizer — routes uppercase before calling
        assert totp_service.consume_recovery_code(hashed_json, codes[0].upper()) is not None


class TestTotpRoutes:
    def test_setup_requires_auth(self, client: TestClient):
        resp = client.post("/auth/totp/setup")
        assert resp.status_code == 401

    def test_setup_returns_uri_and_codes(self, client: TestClient, registered_user):
        uid, headers = registered_user
        resp = client.post("/auth/totp/setup", headers=headers)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["provisioning_uri"].startswith("otpauth://totp/")
        assert len(body["recovery_codes"]) == 10
        assert body["status"] == "pending_verification"

    def test_full_setup_verify_status_flow(self, client: TestClient, registered_user, db_session):
        uid, headers = registered_user

        # 1) setup
        resp = client.post("/auth/totp/setup", headers=headers)
        assert resp.status_code == 200
        secret = resp.json()["secret_base32"]

        # 2) status should be pending
        status_resp = client.get("/auth/totp/status", headers=headers)
        assert status_resp.json()["state"] == "pending_verification"

        # 3) verify with a real code
        code = pyotp.TOTP(secret).now()
        verify_resp = client.post(
            "/auth/totp/verify", headers=headers, json={"code": code}
        )
        assert verify_resp.status_code == 200, verify_resp.text
        assert verify_resp.json()["activated"] is True
        assert verify_resp.json()["method"] == "totp"

        # 4) status is now active
        status_resp = client.get("/auth/totp/status", headers=headers)
        assert status_resp.json()["state"] == "active"
        assert status_resp.json()["recovery_codes_remaining"] == 10

    def test_verify_rejects_wrong_code(self, client: TestClient, registered_user):
        uid, headers = registered_user
        client.post("/auth/totp/setup", headers=headers)
        resp = client.post(
            "/auth/totp/verify", headers=headers, json={"code": "000000"}
        )
        assert resp.status_code == 401

    def test_verify_without_setup_400s(self, client: TestClient, registered_user):
        uid, headers = registered_user
        resp = client.post(
            "/auth/totp/verify", headers=headers, json={"code": "123456"}
        )
        assert resp.status_code == 400

    def test_recovery_code_activates_and_is_consumed(
        self, client: TestClient, registered_user
    ):
        uid, headers = registered_user
        setup = client.post("/auth/totp/setup", headers=headers).json()
        recovery = setup["recovery_codes"][0]

        # First use activates 2FA
        r1 = client.post("/auth/totp/verify", headers=headers, json={"code": recovery})
        assert r1.status_code == 200
        assert r1.json()["method"] == "recovery"
        assert r1.json()["activated"] is True

        # Second use of the same recovery code fails
        r2 = client.post("/auth/totp/verify", headers=headers, json={"code": recovery})
        assert r2.status_code == 401

        # Status shows 9 codes left
        status = client.get("/auth/totp/status", headers=headers).json()
        assert status["recovery_codes_remaining"] == 9

    def test_disable_requires_valid_code(self, client: TestClient, registered_user):
        uid, headers = registered_user
        setup = client.post("/auth/totp/setup", headers=headers).json()
        secret = setup["secret_base32"]
        # activate first
        client.post(
            "/auth/totp/verify", headers=headers, json={"code": pyotp.TOTP(secret).now()}
        )

        # wrong code should fail
        bad = client.post("/auth/totp/disable", headers=headers, json={"code": "000000"})
        assert bad.status_code == 401

        # right code succeeds and clears state
        good = client.post(
            "/auth/totp/disable", headers=headers, json={"code": pyotp.TOTP(secret).now()}
        )
        assert good.status_code == 200

        status = client.get("/auth/totp/status", headers=headers).json()
        assert status["state"] == "not_configured"
        assert status["recovery_codes_remaining"] == 0
