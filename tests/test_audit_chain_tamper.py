"""
Tamper-detection tests for the audit_trail hash chain (Wave 1 PR#6).

The existing tests/test_compliance.py::TestAuditTrail covers the happy
path. These tests prove the chain's core property: verify_audit_chain()
rejects ANY mutation of a historical row.

Also verifies the auth/TOTP routes now emit audit events after this PR.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import os

import jwt as pyjwt
import pyotp
import pytest
from fastapi.testclient import TestClient

from app.core.compliance_models import AuditTrail
from app.core.compliance_service import verify_audit_chain, write_audit_event
from app.phase1.models.platform_models import SessionLocal


def _reset_audit_trail():
    db = SessionLocal()
    try:
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()


def _fresh_chain(n: int) -> list[str]:
    _reset_audit_trail()
    hashes = []
    for i in range(n):
        h = write_audit_event(
            action=f"test.chain.row{i}",
            actor_user_id=f"user-{i}",
            entity_type="test",
            entity_id=f"e-{i}",
        )
        hashes.append(h)
    return hashes


class TestAuditChainTamperEvidence:
    def test_pristine_chain_verifies(self):
        _fresh_chain(5)
        res = verify_audit_chain()
        assert res["ok"] is True
        assert res["verified"] == 5
        assert res["first_mismatch"] is None

    def test_mutated_before_json_caught(self):
        _fresh_chain(3)
        db = SessionLocal()
        try:
            row = db.query(AuditTrail).order_by(AuditTrail.chain_seq).first()
            row.before_json = {"injected": "evidence"}
            db.commit()
        finally:
            db.close()
        res = verify_audit_chain()
        assert res["ok"] is False
        assert res["first_mismatch"] is not None
        # The hash of row 1 is different from what the chain expects.
        assert "expected_hash" in res["first_mismatch"]

    def test_mutated_action_caught(self):
        _fresh_chain(3)
        db = SessionLocal()
        try:
            row = (
                db.query(AuditTrail)
                .order_by(AuditTrail.chain_seq.desc())
                .first()
            )
            row.action = "test.chain.forged"
            db.commit()
        finally:
            db.close()
        res = verify_audit_chain()
        assert res["ok"] is False

    def test_dropped_prev_hash_caught(self):
        _fresh_chain(4)
        db = SessionLocal()
        try:
            # Break the link on row 3: clear prev_hash while keeping this_hash.
            row = (
                db.query(AuditTrail)
                .filter(AuditTrail.chain_seq == 3)
                .first()
            )
            tampered_id = row.id
            row.prev_hash = None
            db.commit()
        finally:
            db.close()
        res = verify_audit_chain()
        assert res["ok"] is False
        assert res["first_mismatch"]["id"] == tampered_id

    def test_resequenced_row_caught(self):
        _fresh_chain(4)
        db = SessionLocal()
        try:
            # Swap chain_seq 2 and 3 — row ordering is wrong even if hashes survive.
            a = db.query(AuditTrail).filter(AuditTrail.chain_seq == 2).first()
            b = db.query(AuditTrail).filter(AuditTrail.chain_seq == 3).first()
            a.chain_seq, b.chain_seq = 99, 100  # sidestep unique-ish ordering
            db.commit()
        finally:
            db.close()
        res = verify_audit_chain()
        assert res["ok"] is False


class TestAuthRoutesEmitAuditEvents:
    """PR#6 wires write_audit_event into the social auth + TOTP routes."""

    def _make_user_and_header(self, db_session):
        from app.phase1.models.platform_models import User, gen_uuid

        uid = gen_uuid()
        user = User(
            id=uid,
            username=f"audit_{uid[:8]}",
            email=f"audit_{uid[:8]}@example.com",
            display_name="Audit Tester",
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

    def test_google_signup_emits_register_event(self, client: TestClient):
        _reset_audit_trail()
        resp = client.post(
            "/auth/social/google",
            json={
                "id_token": "x",
                "email": "brand-new@example.com",
                "display_name": "Newbie",
            },
        )
        assert resp.status_code == 200

        db = SessionLocal()
        try:
            events = db.query(AuditTrail).all()
            actions = [e.action for e in events]
        finally:
            db.close()
        assert "user.register" in actions
        assert verify_audit_chain()["ok"] is True

    def test_totp_setup_verify_disable_emit_events(
        self, client: TestClient, db_session
    ):
        _reset_audit_trail()
        _uid, headers = self._make_user_and_header(db_session)

        setup = client.post("/auth/totp/setup", headers=headers).json()
        code = pyotp.TOTP(setup["secret_base32"]).now()
        assert client.post(
            "/auth/totp/verify", headers=headers, json={"code": code}
        ).status_code == 200
        assert client.post(
            "/auth/totp/disable", headers=headers, json={"code": pyotp.TOTP(setup["secret_base32"]).now()}
        ).status_code == 200

        db = SessionLocal()
        try:
            actions = [e.action for e in db.query(AuditTrail).order_by(AuditTrail.chain_seq).all()]
        finally:
            db.close()
        assert "totp.setup" in actions
        assert "totp.verify" in actions
        assert "totp.disable" in actions
        # The chain is still unbroken after route-driven writes.
        assert verify_audit_chain()["ok"] is True

    def test_failed_totp_code_emits_failure_event(
        self, client: TestClient, db_session
    ):
        _reset_audit_trail()
        _uid, headers = self._make_user_and_header(db_session)
        client.post("/auth/totp/setup", headers=headers)
        resp = client.post(
            "/auth/totp/verify", headers=headers, json={"code": "000000"}
        )
        assert resp.status_code == 401

        db = SessionLocal()
        try:
            actions = [e.action for e in db.query(AuditTrail).all()]
        finally:
            db.close()
        assert "totp.verify.failed" in actions
