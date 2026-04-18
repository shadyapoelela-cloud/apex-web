"""
Tests for app/core/bank_feeds.py and app/core/bank_feeds_routes.py
(Wave 13).

Covers:
- Encryption round-trip on connection tokens.
- connect / disconnect / sync / duplicate detection.
- list/get projections never leak token material.
- Provider registration + mock provider deterministic output.
- reconcile marks the txn + audits.
- Routes: auth + validation + 404 + 409.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.core import bank_feeds as bf
from app.core.bank_feeds import (
    BankFeedProvider,
    ConnectionInput,
    MockBankFeedProvider,
    ProviderAccount,
    ProviderAuthTokens,
    ProviderTransaction,
)
from app.core.compliance_models import (
    AuditTrail,
    BankFeedConnection,
    BankFeedTransaction,
)
from app.core.compliance_service import verify_audit_chain
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset():
    db = SessionLocal()
    try:
        db.query(BankFeedTransaction).delete()
        db.query(BankFeedConnection).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    # Ensure the mock provider is registered (Fernet + module import
    # runs on first load; this keeps tests deterministic).
    bf.register_provider("mock", MockBankFeedProvider())
    yield


def _make_connect_input(**overrides) -> ConnectionInput:
    defaults = dict(
        tenant_id="tenant-1",
        provider="mock",
        account=ProviderAccount(
            external_account_id="ext-acct-001",
            bank_name="Al Rajhi Bank",
            account_name="شركة اختبار",
            iban_masked="SA**XXXXXXXX1234",
            currency="SAR",
        ),
        tokens=ProviderAuthTokens(
            access_token="TEST_ACCESS_TOKEN_" + ("X" * 40),
            refresh_token="TEST_REFRESH_TOKEN_" + ("Y" * 40),
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
        ),
    )
    defaults.update(overrides)
    return ConnectionInput(**defaults)


# ── Encryption + connect ──────────────────────────────────────────────


class TestConnect:
    def test_connect_persists_and_encrypts(self):
        row_id = bf.connect(_make_connect_input())
        row = bf.get_connection(row_id)
        assert row is not None
        assert row["provider"] == "mock"
        assert row["status"] == "connected"
        # Projection never leaks tokens.
        assert "access_token" not in row
        assert "access_token_encrypted" not in row
        assert verify_audit_chain()["ok"] is True

    def test_ciphertext_differs_from_plaintext(self):
        bf.connect(_make_connect_input())
        db = SessionLocal()
        try:
            raw = db.query(BankFeedConnection).first()
            assert raw.access_token_encrypted
            assert "TEST_ACCESS_TOKEN" not in raw.access_token_encrypted
            assert "TEST_REFRESH_TOKEN" not in (raw.refresh_token_encrypted or "")
        finally:
            db.close()

    def test_unknown_provider_rejected(self):
        with pytest.raises(ValueError, match="not registered"):
            bf.connect(_make_connect_input(provider="no-such-provider"))

    def test_empty_access_token_rejected(self):
        with pytest.raises(ValueError):
            bf.connect(
                _make_connect_input(
                    tokens=ProviderAuthTokens(access_token="", refresh_token=None)
                )
            )


# ── Sync ──────────────────────────────────────────────────────────────


class TestSync:
    def test_sync_pulls_transactions_from_mock(self):
        row_id = bf.connect(_make_connect_input())
        summary = bf.sync_account(row_id)
        assert summary["fetched"] == 2
        assert summary["inserted"] == 2
        assert summary["duplicates"] == 0
        rows = bf.list_transactions(connection_id=row_id)
        assert len(rows) == 2
        # Amounts are stored as decimal strings.
        amounts = {r["amount"] for r in rows}
        assert "1250.00" in amounts
        assert "45000.00" in amounts

    def test_sync_is_idempotent(self):
        row_id = bf.connect(_make_connect_input())
        first = bf.sync_account(row_id)
        second = bf.sync_account(row_id)
        assert first["inserted"] == 2
        assert second["inserted"] == 0
        assert second["duplicates"] == 2

    def test_sync_on_disconnected_raises(self):
        row_id = bf.connect(_make_connect_input())
        bf.disconnect(row_id, user_id="u1", reason="test")
        with pytest.raises(ValueError):
            bf.sync_account(row_id)

    def test_sync_updates_last_sync_at(self):
        row_id = bf.connect(_make_connect_input())
        bf.sync_account(row_id)
        row = bf.get_connection(row_id)
        assert row["last_sync_at"] is not None
        assert row["last_sync_txn_count"] == 2

    def test_sync_handles_provider_exception(self):
        class BoomProvider(BankFeedProvider):
            name = "boom"

            def fetch_transactions(self, *, tokens, account, since):
                raise RuntimeError("network dead")

        bf.register_provider("boom", BoomProvider())
        row_id = bf.connect(_make_connect_input(provider="boom"))
        with pytest.raises(RuntimeError, match="network dead"):
            bf.sync_account(row_id)
        row = bf.get_connection(row_id)
        assert row["status"] == "error"
        assert "network dead" in (row["last_sync_error"] or "")


# ── Disconnect ────────────────────────────────────────────────────────


class TestDisconnect:
    def test_disconnect_clears_tokens(self):
        row_id = bf.connect(_make_connect_input())
        bf.disconnect(row_id, user_id="u1", reason="rotating")
        db = SessionLocal()
        try:
            raw = db.query(BankFeedConnection).filter_by(id=row_id).first()
            assert raw.status == "disconnected"
            assert raw.access_token_encrypted is None
            assert raw.refresh_token_encrypted is None
        finally:
            db.close()

    def test_disconnect_is_idempotent(self):
        row_id = bf.connect(_make_connect_input())
        bf.disconnect(row_id, user_id="u1", reason="x")
        bf.disconnect(row_id, user_id="u1", reason="x")
        assert bf.get_connection(row_id)["status"] == "disconnected"

    def test_disconnect_unknown_raises(self):
        with pytest.raises(LookupError):
            bf.disconnect("nope", user_id="u1", reason=None)


# ── Reconcile ─────────────────────────────────────────────────────────


class TestReconcile:
    def test_mark_reconciled_sets_match(self):
        row_id = bf.connect(_make_connect_input())
        bf.sync_account(row_id)
        txns = bf.list_transactions(connection_id=row_id)
        bf.mark_reconciled(
            txns[0]["id"],
            entity_type="invoice",
            entity_id="INV-001",
            user_id="u1",
        )
        row = bf.list_transactions(connection_id=row_id)[0]
        assert row["matched_entity_type"] == "invoice"
        assert row["matched_entity_id"] == "INV-001"
        assert row["matched_at"] is not None

    def test_unreconciled_only_filter(self):
        row_id = bf.connect(_make_connect_input())
        bf.sync_account(row_id)
        all_rows = bf.list_transactions(connection_id=row_id)
        bf.mark_reconciled(
            all_rows[0]["id"],
            entity_type="invoice",
            entity_id="X",
            user_id="u1",
        )
        unrec = bf.list_transactions(
            connection_id=row_id, unreconciled_only=True
        )
        assert len(unrec) == 1


# ── Stats ─────────────────────────────────────────────────────────────


class TestStats:
    def test_counts(self):
        a = bf.connect(_make_connect_input())
        bf.connect(
            _make_connect_input(
                account=ProviderAccount(external_account_id="ext-002")
            )
        )
        bf.sync_account(a)
        s = bf.stats()
        assert s["connections_total"] == 2
        assert s["connected"] == 2
        assert s["transactions_total"] == 2
        assert s["transactions_unreconciled"] == 2


# ── HTTP routes ───────────────────────────────────────────────────────


class TestRoutes:
    def test_connect_requires_auth(self, client: TestClient):
        r = client.post("/bank-feeds/connections", json={})
        assert r.status_code == 401

    def test_connect_happy_path(self, client: TestClient, auth_header):
        r = client.post(
            "/bank-feeds/connections",
            headers=auth_header,
            json={
                "tenant_id": "t1",
                "provider": "mock",
                "external_account_id": "route-1",
                "access_token": "ACC-route-1",
                "currency": "SAR",
            },
        )
        assert r.status_code == 200, r.text
        assert r.json()["data"]["id"]

    def test_connect_unknown_provider_400(self, client: TestClient, auth_header):
        r = client.post(
            "/bank-feeds/connections",
            headers=auth_header,
            json={
                "tenant_id": "t1",
                "provider": "unknown",
                "external_account_id": "x",
                "access_token": "x",
            },
        )
        assert r.status_code == 400

    def test_sync_route_returns_summary(self, client: TestClient, auth_header):
        rid = bf.connect(_make_connect_input())
        r = client.post(
            f"/bank-feeds/connections/{rid}/sync", headers=auth_header
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["inserted"] == 2

    def test_sync_on_disconnected_returns_409(self, client: TestClient, auth_header):
        rid = bf.connect(_make_connect_input())
        bf.disconnect(rid, user_id="u", reason=None)
        r = client.post(
            f"/bank-feeds/connections/{rid}/sync", headers=auth_header
        )
        assert r.status_code == 409

    def test_sync_unknown_404(self, client: TestClient, auth_header):
        r = client.post(
            "/bank-feeds/connections/nope/sync", headers=auth_header
        )
        assert r.status_code == 404

    def test_list_never_exposes_plaintext(self, client: TestClient, auth_header):
        bf.connect(_make_connect_input())
        r = client.get("/bank-feeds/connections", headers=auth_header)
        assert r.status_code == 200
        body = r.text
        assert "TEST_ACCESS_TOKEN" not in body
        assert "TEST_REFRESH_TOKEN" not in body

    def test_list_invalid_status_400(self, client: TestClient, auth_header):
        r = client.get("/bank-feeds/connections?status=bogus", headers=auth_header)
        assert r.status_code == 400

    def test_transactions_filter_by_connection(self, client: TestClient, auth_header):
        rid = bf.connect(_make_connect_input())
        bf.sync_account(rid)
        r = client.get(
            f"/bank-feeds/transactions?connection_id={rid}",
            headers=auth_header,
        )
        assert r.status_code == 200
        assert r.json()["data"]["count"] == 2

    def test_reconcile_route(self, client: TestClient, auth_header):
        rid = bf.connect(_make_connect_input())
        bf.sync_account(rid)
        txn_id = bf.list_transactions(connection_id=rid)[0]["id"]
        r = client.post(
            f"/bank-feeds/transactions/{txn_id}/reconcile",
            headers=auth_header,
            json={"entity_type": "journal_entry", "entity_id": "JE-1"},
        )
        assert r.status_code == 200

    def test_providers_route(self, client: TestClient, auth_header):
        r = client.get("/bank-feeds/providers", headers=auth_header)
        assert r.status_code == 200
        assert "mock" in r.json()["data"]["providers"]

    def test_stats_route(self, client: TestClient, auth_header):
        bf.connect(_make_connect_input())
        r = client.get("/bank-feeds/stats", headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["connected"] >= 1
