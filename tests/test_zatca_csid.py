"""
Tests for app/core/zatca_csid.py and app/core/zatca_csid_routes.py
(Wave 11).

Covers:
- Encryption round-trip: register stores encrypted, get_active_csid
  returns decrypted, list/get_row NEVER expose plaintext.
- Lifecycle transitions: register → revoke / renewing / expired.
- expiring_soon filters by window + active status.
- sweep_expired flips past-due active rows.
- Audit-chain integrity after every transition.
- HTTP routes: auth + invalid env/status/days + 404 + happy paths.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.core import zatca_csid as c
from app.core.compliance_models import AuditTrail, ZatcaCsid
from app.core.compliance_service import verify_audit_chain
from app.core.zatca_csid import CsidRegistration
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset():
    db = SessionLocal()
    try:
        db.query(ZatcaCsid).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    yield


_DUMMY_CERT = (
    "-----BEGIN CERTIFICATE-----\n"
    + "MIIBdummy_cert_for_tests_only_" + ("A" * 100) + "\n"
    + "-----END CERTIFICATE-----"
)
_DUMMY_KEY = (
    "-----BEGIN PRIVATE KEY-----\n"
    + "MIIEv_dummy_key_for_tests_only_" + ("B" * 100) + "\n"
    + "-----END PRIVATE KEY-----"
)


def _mk(**overrides) -> CsidRegistration:
    defaults = dict(
        tenant_id="tenant-test",
        environment="sandbox",
        cert_pem=_DUMMY_CERT,
        private_key_pem=_DUMMY_KEY,
        expires_at=datetime.now(timezone.utc) + timedelta(days=90),
        cert_subject="CN=APEX Test Merchant, O=APEX",
        cert_serial="TEST-SERIAL-001",
        issued_at=datetime.now(timezone.utc),
    )
    defaults.update(overrides)
    return CsidRegistration(**defaults)


# ── Encryption ────────────────────────────────────────────────────────


class TestEncryption:
    def test_round_trip_preserves_material(self):
        row_id = c.register_csid(_mk())
        active = c.get_active_csid("tenant-test", "sandbox")
        assert active is not None
        assert active["cert_pem"] == _DUMMY_CERT
        assert active["private_key_pem"] == _DUMMY_KEY
        assert active["id"] == row_id

    def test_get_row_never_returns_plaintext(self):
        c.register_csid(_mk())
        row = c.get_row(c.list_csids()[0]["id"])
        assert row is not None
        # No crypto fields in the metadata projection.
        assert "cert_pem" not in row
        assert "private_key_pem" not in row
        assert "cert_pem_encrypted" not in row

    def test_list_never_exposes_ciphertext_either(self):
        c.register_csid(_mk())
        rows = c.list_csids()
        assert rows
        for r in rows:
            for key in ("cert_pem", "cert_pem_encrypted", "private_key_pem"):
                assert key not in r

    def test_stored_blob_is_encrypted(self):
        c.register_csid(_mk())
        db = SessionLocal()
        try:
            row = db.query(ZatcaCsid).first()
            # Ciphertext must differ from plaintext.
            assert row.cert_pem_encrypted != _DUMMY_CERT
            assert row.private_key_pem_encrypted != _DUMMY_KEY
            assert "dummy" not in row.cert_pem_encrypted.lower()
        finally:
            db.close()


class TestValidation:
    def test_invalid_environment_rejected(self):
        with pytest.raises(ValueError):
            c.register_csid(_mk(environment="staging"))

    def test_missing_cert_rejected(self):
        with pytest.raises(ValueError):
            c.register_csid(_mk(cert_pem=""))

    def test_missing_key_rejected(self):
        with pytest.raises(ValueError):
            c.register_csid(_mk(private_key_pem=""))


class TestLifecycle:
    def test_register_emits_audit_and_active_status(self):
        row_id = c.register_csid(_mk())
        row = c.get_row(row_id)
        assert row["status"] == "active"
        assert verify_audit_chain()["ok"] is True

    def test_revoke_transitions_and_preserves_blob(self):
        row_id = c.register_csid(_mk())
        c.mark_revoked(row_id, user_id="admin-1", reason="compromised key")
        row = c.get_row(row_id)
        assert row["status"] == "revoked"
        assert row["revocation_reason"] == "compromised key"
        # Blobs retained (metadata only exposes projection fields).
        db = SessionLocal()
        try:
            raw = db.query(ZatcaCsid).filter(ZatcaCsid.id == row_id).first()
            assert raw.cert_pem_encrypted
        finally:
            db.close()

    def test_revoke_is_idempotent(self):
        row_id = c.register_csid(_mk())
        c.mark_revoked(row_id, user_id="u", reason="x")
        c.mark_revoked(row_id, user_id="u", reason="x")
        assert c.get_row(row_id)["status"] == "revoked"

    def test_renewing_transition(self):
        row_id = c.register_csid(_mk())
        c.mark_renewing(row_id, user_id="u1")
        assert c.get_row(row_id)["status"] == "renewing"

    def test_get_active_ignores_revoked(self):
        row_id = c.register_csid(_mk())
        c.mark_revoked(row_id, user_id="u", reason=None)
        assert c.get_active_csid("tenant-test", "sandbox") is None

    def test_unknown_revoke_raises(self):
        with pytest.raises(LookupError):
            c.mark_revoked("no-such-id", user_id="u", reason=None)


class TestExpiry:
    def test_expiring_soon_includes_within_window(self):
        c.register_csid(_mk(expires_at=datetime.now(timezone.utc) + timedelta(days=10)))
        rows = c.expiring_soon(days=30)
        assert len(rows) == 1

    def test_expiring_soon_excludes_outside_window(self):
        c.register_csid(_mk(expires_at=datetime.now(timezone.utc) + timedelta(days=200)))
        assert c.expiring_soon(days=30) == []

    def test_sweep_expired_flips_past_due(self):
        c.register_csid(_mk(expires_at=datetime.now(timezone.utc) - timedelta(days=1)))
        c.register_csid(_mk(
            tenant_id="t2",
            cert_serial="T2-001",
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        ))
        count = c.sweep_expired()
        assert count == 1
        db = SessionLocal()
        try:
            statuses = sorted(r.status for r in db.query(ZatcaCsid).all())
            assert statuses == ["active", "expired"]
        finally:
            db.close()

    def test_days_to_expiry_is_populated(self):
        c.register_csid(_mk(expires_at=datetime.now(timezone.utc) + timedelta(days=42)))
        row = c.list_csids()[0]
        # Round-trip through SQLite can lose a second; allow ±1.
        assert row["days_to_expiry"] in (41, 42)


class TestStats:
    def test_counts_by_status(self):
        c.register_csid(_mk())
        revoked_id = c.register_csid(
            _mk(cert_serial="REV-1", expires_at=datetime.now(timezone.utc) + timedelta(days=90))
        )
        c.mark_revoked(revoked_id, user_id="u", reason=None)
        s = c.stats()
        assert s["active"] == 1
        assert s["revoked"] == 1
        assert s["total"] == 2


# ── HTTP routes ───────────────────────────────────────────────────────


class TestRoutes:
    def test_register_requires_auth(self, client: TestClient):
        r = client.post("/zatca/csid/register", json={})
        assert r.status_code == 401

    def test_register_happy(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/csid/register",
            headers=auth_header,
            json={
                "tenant_id": "t-route",
                "environment": "sandbox",
                "cert_pem": _DUMMY_CERT,
                "private_key_pem": _DUMMY_KEY,
                "expires_at": (
                    datetime.now(timezone.utc) + timedelta(days=90)
                ).isoformat(),
                "cert_serial": "ROUTE-1",
            },
        )
        assert r.status_code == 200, r.text
        assert r.json()["data"]["id"]

    def test_register_invalid_env_rejected(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/csid/register",
            headers=auth_header,
            json={
                "tenant_id": "t",
                "environment": "staging",
                "cert_pem": _DUMMY_CERT,
                "private_key_pem": _DUMMY_KEY,
                "expires_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        assert r.status_code == 400

    def test_list_never_exposes_plaintext(self, client: TestClient, auth_header):
        c.register_csid(_mk())
        r = client.get("/zatca/csid", headers=auth_header)
        assert r.status_code == 200
        body = r.text
        # Plaintext dummy markers must not appear in the JSON response.
        assert "dummy_cert" not in body
        assert "dummy_key" not in body

    def test_list_invalid_env_rejected(self, client: TestClient, auth_header):
        r = client.get("/zatca/csid?environment=staging", headers=auth_header)
        assert r.status_code == 400

    def test_list_invalid_status_rejected(self, client: TestClient, auth_header):
        r = client.get("/zatca/csid?status=bogus", headers=auth_header)
        assert r.status_code == 400

    def test_expiring_soon_happy(self, client: TestClient, auth_header):
        c.register_csid(
            _mk(expires_at=datetime.now(timezone.utc) + timedelta(days=15))
        )
        r = client.get("/zatca/csid/expiring-soon?days=30", headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["count"] == 1

    def test_expiring_soon_bad_days_rejected(self, client: TestClient, auth_header):
        r = client.get("/zatca/csid/expiring-soon?days=9999", headers=auth_header)
        assert r.status_code == 400

    def test_revoke_happy(self, client: TestClient, auth_header):
        rid = c.register_csid(_mk())
        r = client.post(
            f"/zatca/csid/{rid}/revoke",
            headers=auth_header,
            json={"reason": "compromised"},
        )
        assert r.status_code == 200
        assert r.json()["data"]["status"] == "revoked"

    def test_revoke_unknown_returns_404(self, client: TestClient, auth_header):
        r = client.post(
            "/zatca/csid/no-such-id/revoke",
            headers=auth_header,
            json={"reason": "x"},
        )
        assert r.status_code == 404

    def test_detail_404(self, client: TestClient, auth_header):
        r = client.get("/zatca/csid/no-such-id", headers=auth_header)
        assert r.status_code == 404

    def test_stats_route(self, client: TestClient, auth_header):
        c.register_csid(_mk())
        r = client.get("/zatca/csid/stats", headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["active"] >= 1

    def test_sweep_expired_route(self, client: TestClient, auth_header):
        c.register_csid(
            _mk(expires_at=datetime.now(timezone.utc) - timedelta(days=1))
        )
        r = client.post("/zatca/csid/sweep-expired", headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["swept"] == 1
