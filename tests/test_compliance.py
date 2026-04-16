"""
APEX Platform — Compliance Core Tests
Covers:
  - Journal Entry Sequence (gap-free, atomic, per client/year)
  - Audit Trail (hash chaining, tamper detection)
  - /compliance/* routes
"""

import pytest
from app.core.compliance_service import (
    next_journal_entry_number,
    peek_journal_entry_sequence,
    write_audit_event,
    verify_audit_chain,
)


# ═══════════════════════════════════════════════════════════════
# Journal Entry Sequence
# ═══════════════════════════════════════════════════════════════


class TestJournalEntrySequence:
    def test_first_number_is_one(self):
        res = next_journal_entry_number("test-client-A", "2026")
        assert res["sequence"] == 1
        assert res["number"] == "JE-2026-00001"
        assert res["prefix"] == "JE"

    def test_numbers_are_sequential(self):
        a = next_journal_entry_number("test-client-B", "2026")
        b = next_journal_entry_number("test-client-B", "2026")
        c = next_journal_entry_number("test-client-B", "2026")
        assert a["sequence"] == 1
        assert b["sequence"] == 2
        assert c["sequence"] == 3
        assert a["number"] == "JE-2026-00001"
        assert b["number"] == "JE-2026-00002"
        assert c["number"] == "JE-2026-00003"

    def test_different_clients_isolated(self):
        x = next_journal_entry_number("client-X", "2026")
        y = next_journal_entry_number("client-Y", "2026")
        x2 = next_journal_entry_number("client-X", "2026")
        assert x["sequence"] == 1
        assert y["sequence"] == 1  # independent counter
        assert x2["sequence"] == 2

    def test_different_years_isolated(self):
        a = next_journal_entry_number("test-client-C", "2025")
        b = next_journal_entry_number("test-client-C", "2026")
        assert a["sequence"] == 1
        assert b["sequence"] == 1

    def test_custom_prefix(self):
        res = next_journal_entry_number("test-client-D", "2026", prefix="ADJ")
        assert res["number"] == "ADJ-2026-00001"

    def test_peek_does_not_increment(self):
        next_journal_entry_number("test-client-E", "2026")
        s1 = peek_journal_entry_sequence("test-client-E", "2026")
        s2 = peek_journal_entry_sequence("test-client-E", "2026")
        assert s1["last_number"] == s2["last_number"] == 1

    def test_peek_unknown_returns_zero(self):
        s = peek_journal_entry_sequence("no-such-client", "2026")
        assert s["last_number"] == 0

    def test_invalid_year_rejected(self):
        with pytest.raises(ValueError):
            next_journal_entry_number("c", "26")
        with pytest.raises(ValueError):
            next_journal_entry_number("c", "abcd")

    def test_empty_client_rejected(self):
        with pytest.raises(ValueError):
            next_journal_entry_number("", "2026")


# ═══════════════════════════════════════════════════════════════
# Audit Trail (hash chaining)
# ═══════════════════════════════════════════════════════════════


class TestAuditTrail:
    def test_write_returns_hash(self):
        h = write_audit_event(action="test.write", actor_user_id="u1")
        assert h and len(h) == 64  # SHA-256 hex

    def test_chain_verifies_after_writes(self):
        write_audit_event(action="test.chain.1", actor_user_id="u1")
        write_audit_event(action="test.chain.2", actor_user_id="u1")
        write_audit_event(action="test.chain.3", actor_user_id="u2")
        res = verify_audit_chain()
        assert res["ok"] is True
        assert res["verified"] >= 3
        assert res["first_mismatch"] is None

    def test_empty_action_rejected(self):
        with pytest.raises(ValueError):
            write_audit_event(action="")

    def test_hashes_differ_per_event(self):
        h1 = write_audit_event(action="test.unique", actor_user_id="u1")
        h2 = write_audit_event(action="test.unique", actor_user_id="u1")
        assert h1 != h2  # chain ties them together → different hashes


# ═══════════════════════════════════════════════════════════════
# /compliance/* HTTP routes
# ═══════════════════════════════════════════════════════════════


class TestComplianceRoutes:
    def test_je_next_requires_auth(self, client):
        r = client.post(
            "/compliance/je/next",
            json={"client_id": "c1", "fiscal_year": "2026"},
        )
        assert r.status_code == 401

    def test_je_next_with_auth(self, client, auth_header):
        r = client.post(
            "/compliance/je/next",
            json={"client_id": "test-client-http-1", "fiscal_year": "2026"},
            headers=auth_header,
        )
        assert r.status_code == 200
        data = r.json()
        assert data["success"] is True
        assert data["data"]["sequence"] >= 1
        assert data["data"]["number"].startswith("JE-2026-")

    def test_je_next_rejects_bad_year(self, client, auth_header):
        r = client.post(
            "/compliance/je/next",
            json={"client_id": "c1", "fiscal_year": "20"},
            headers=auth_header,
        )
        assert r.status_code == 422  # pydantic validation

    def test_audit_log_then_verify(self, client, auth_header):
        r1 = client.post(
            "/compliance/audit/log",
            json={"action": "test.http.audit", "entity_type": "test", "entity_id": "x1"},
            headers=auth_header,
        )
        assert r1.status_code == 200
        assert r1.json()["success"] is True
        assert len(r1.json()["hash"]) == 64

        r2 = client.get("/compliance/audit/verify", headers=auth_header)
        assert r2.status_code == 200
        assert r2.json()["data"]["ok"] is True

    def test_audit_verify_requires_auth(self, client):
        r = client.get("/compliance/audit/verify")
        assert r.status_code == 401

    def test_audit_verify_bad_limit(self, client, auth_header):
        r = client.get("/compliance/audit/verify?limit=0", headers=auth_header)
        assert r.status_code == 400


# ═══════════════════════════════════════════════════════════════
# Schema smoke: verify Float → Numeric migration worked
# ═══════════════════════════════════════════════════════════════


class TestNumericMigration:
    def test_plan_price_is_numeric(self):
        from sqlalchemy import Numeric
        from app.phase1.models.platform_models import Plan

        assert isinstance(Plan.__table__.c.price_monthly_sar.type, Numeric)
        assert isinstance(Plan.__table__.c.price_yearly_sar.type, Numeric)

    def test_tb_amounts_are_numeric(self):
        from sqlalchemy import Numeric
        from app.sprint4_tb.models.tb_models import TbParsedRow

        for field in ("open_debit", "open_credit", "movement_debit",
                      "movement_credit", "close_debit", "close_credit", "net_balance"):
            col = TbParsedRow.__table__.c[field]
            assert isinstance(col.type, Numeric), f"{field} must be Numeric"

    def test_payment_amount_is_numeric(self):
        from sqlalchemy import Numeric
        from app.phase8.models.phase8_models import PaymentRecord

        assert isinstance(PaymentRecord.__table__.c.amount.type, Numeric)
        assert isinstance(PaymentRecord.__table__.c.tax_amount.type, Numeric)

    def test_client_has_zatca_fields(self):
        from app.phase2.models.phase2_models import Client

        cols = {c.name for c in Client.__table__.columns}
        assert "vat_registration_number" in cols
        assert "tax_jurisdiction" in cols
        assert "currency" in cols

    def test_plan_has_currency(self):
        from app.phase1.models.platform_models import Plan

        assert "currency" in {c.name for c in Plan.__table__.columns}

    def test_analysis_result_has_locking(self):
        from app.phase2.models.phase2_models import AnalysisResult

        cols = {c.name for c in AnalysisResult.__table__.columns}
        for required in ("period_locked", "locked_at", "locked_by", "audit_trail_json"):
            assert required in cols

    def test_payment_has_idempotency(self):
        from app.phase8.models.phase8_models import PaymentRecord

        cols = {c.name for c in PaymentRecord.__table__.columns}
        assert "idempotency_key" in cols
        assert "einvoice_uuid" in cols
