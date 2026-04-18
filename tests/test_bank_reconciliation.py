"""
Tests for app/core/bank_reconciliation.py and
app/core/bank_reconciliation_routes.py (Wave 15).

Covers:
- Feature scoring: amount, date, vendor (Arabic folding), description.
- propose_matches: ranking, min_score filter, top_k cap, window decay.
- auto_match_via_guardrail: high-score auto-applies; low-score routes
  to needs_approval; destructive forces approval; no candidates →
  rejected; AUTO_APPLIED path posts via bank_feeds.mark_reconciled.
- Routes: auth required; propose happy path; auto-match high score.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List

import pytest
from fastapi.testclient import TestClient

from app.core import bank_feeds as bf
from app.core import bank_reconciliation as br
from app.core.ai_guardrails import Verdict
from app.core.bank_feeds import (
    ConnectionInput,
    MockBankFeedProvider,
    ProviderAccount,
    ProviderAuthTokens,
)
from app.core.compliance_models import (
    AiSuggestion,
    AuditTrail,
    BankFeedConnection,
    BankFeedTransaction,
)
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset():
    db = SessionLocal()
    try:
        db.query(BankFeedTransaction).delete()
        db.query(BankFeedConnection).delete()
        db.query(AiSuggestion).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    bf.register_provider("mock", MockBankFeedProvider())
    yield


# ── Feature-level scoring ─────────────────────────────────────────────


class TestAmountScore:
    def test_identical_scores_one(self):
        s = br._amount_score(Decimal("100"), Decimal("100"))
        assert s == pytest.approx(1.0)

    def test_small_delta_scores_near_one(self):
        s = br._amount_score(Decimal("1000"), Decimal("1001"))
        assert s > 0.99

    def test_large_delta_scores_low(self):
        s = br._amount_score(Decimal("10"), Decimal("10000"))
        assert s < 0.01

    def test_sign_mismatch_zero(self):
        # A credit can't reconcile a debit.
        s = br._amount_score(Decimal("100"), Decimal("-100"))
        assert s == 0.0

    def test_missing_amount_zero(self):
        assert br._amount_score(None, Decimal("10")) == 0.0
        assert br._amount_score(Decimal("10"), None) == 0.0


class TestDateScore:
    def test_same_day_one(self):
        d = date(2026, 4, 1)
        assert br._date_score(d, d, window_days=7) == 1.0

    def test_three_days_decay(self):
        a, b = date(2026, 4, 1), date(2026, 4, 4)
        s = br._date_score(a, b, window_days=7)
        assert s == pytest.approx(1 - 3 / 7)

    def test_outside_window_zero(self):
        a, b = date(2026, 4, 1), date(2026, 4, 15)
        assert br._date_score(a, b, window_days=7) == 0.0

    def test_missing_zero(self):
        assert br._date_score(None, date(2026, 4, 1), 7) == 0.0


class TestVendorScore:
    def test_exact_match_one(self):
        assert br._vendor_score("STC", "STC") == 1.0

    def test_arabic_folded_equal(self):
        # آ / أ fold to ا; ة folds to ه; case-insensitive.
        assert br._vendor_score("شركة الرياض", "شركه الرياض") == 1.0

    def test_jaccard_partial(self):
        s = br._vendor_score("Al Rajhi Bank", "Al Rajhi")
        # Tokens {al, rajhi, bank} vs {al, rajhi} → 2/3.
        assert s == pytest.approx(2 / 3)

    def test_missing_zero(self):
        assert br._vendor_score("", "STC") == 0.0
        assert br._vendor_score(None, None) == 0.0


class TestWeights:
    def test_weights_sum_to_one(self):
        total = br._W_AMOUNT + br._W_DATE + br._W_VENDOR + br._W_DESC
        assert abs(total - 1.0) < 1e-9

    def test_amount_dominates(self):
        assert br._W_AMOUNT > br._W_DATE > br._W_VENDOR > br._W_DESC


# ── propose_matches ────────────────────────────────────────────────────


def _txn(id_, amount, date_str, vendor=None, description=None):
    return {
        "id": id_,
        "amount": amount,
        "date": date_str,
        "vendor": vendor,
        "description": description,
    }


class TestPropose:
    def test_identical_candidate_top(self):
        bank = _txn("B1", "1000", "2026-04-01", "STC", "Mobile bill")
        candidates = [
            _txn("C1", "1000", "2026-04-01", "STC", "Mobile bill"),
            _txn("C2", "500", "2026-04-05", "Other", "Random"),
        ]
        proposals = br.propose_matches(bank, candidates)
        assert proposals[0]["candidate_id"] == "C1"
        assert proposals[0]["score"] == pytest.approx(1.0)

    def test_min_score_filters(self):
        bank = _txn("B1", "1000", "2026-04-01", "STC")
        candidates = [
            _txn("C1", "1", "2030-01-01", "OtherCo"),  # terrible match
        ]
        # Default min_score=0.3 drops it.
        assert br.propose_matches(bank, candidates) == []
        # Lowering min_score returns it.
        assert len(br.propose_matches(bank, candidates, min_score=0.0)) == 1

    def test_top_k_caps(self):
        bank = _txn("B1", "1000", "2026-04-01", "STC", "Bill")
        candidates = [
            _txn(f"C{i}", "1000", "2026-04-01", "STC", "Bill")
            for i in range(10)
        ]
        proposals = br.propose_matches(bank, candidates, top_k=3)
        assert len(proposals) == 3

    def test_date_window_decay(self):
        bank = _txn("B1", "1000", "2026-04-01", "STC", "Bill")
        c_same = _txn("CS", "1000", "2026-04-01", "STC", "Bill")
        c_shifted = _txn("CD", "1000", "2026-04-05", "STC", "Bill")
        props = br.propose_matches(bank, [c_same, c_shifted])
        # Same-day candidate should outrank the shifted one.
        assert props[0]["candidate_id"] == "CS"
        assert props[0]["score"] > props[1]["score"]


# ── auto_match_via_guardrail ──────────────────────────────────────────


class TestAutoMatch:
    def test_high_score_auto_applied(self):
        bank = _txn("B1", "1000.00", "2026-04-01", "STC", "Mobile bill")
        candidates = [
            _txn("JE-1", "1000.00", "2026-04-01", "STC", "Mobile bill"),
            _txn("JE-2", "999.00", "2026-04-05", "STC", "Mobile"),
        ]
        result = br.auto_match_via_guardrail(
            bank, candidates, tenant_id="t1"
        )
        # Identical pair → score 1.0 → well above 0.95 floor.
        assert result.score == pytest.approx(1.0)
        assert result.verdict == Verdict.AUTO_APPLIED.value
        assert result.best_candidate_id == "JE-1"
        assert result.row_id  # AiSuggestion persisted

    def test_low_score_needs_approval(self):
        bank = _txn("B1", "1000.00", "2026-04-01", "STC", "Mobile bill")
        # Matches on amount only (50% weight) → ~0.5 < 0.95 floor.
        candidates = [
            _txn("JE-X", "1000.00", "2026-05-15", "مورد آخر", "Something else"),
        ]
        result = br.auto_match_via_guardrail(
            bank, candidates, tenant_id="t1"
        )
        assert result.verdict == Verdict.NEEDS_APPROVAL.value
        assert result.score < 0.95
        assert result.row_id  # still persisted for human review

    def test_no_candidates_rejected(self):
        result = br.auto_match_via_guardrail(
            _txn("B1", "1000", "2026-04-01"), []
        )
        assert result.verdict == Verdict.REJECTED.value
        assert result.row_id is None
        assert result.matched is False

    def test_destructive_forces_approval(self):
        bank = _txn("B1", "1000.00", "2026-04-01", "STC", "Bill")
        candidates = [_txn("JE-1", "1000.00", "2026-04-01", "STC", "Bill")]
        result = br.auto_match_via_guardrail(
            bank, candidates, destructive=True
        )
        # Even at confidence 1.0 the destructive flag routes to human.
        assert result.verdict == Verdict.NEEDS_APPROVAL.value

    def test_auto_applied_posts_reconciliation(self):
        """AUTO_APPLIED with a real bank_tx_id should mark the row
        reconciled via bank_feeds.mark_reconciled."""
        rid = bf.connect(
            ConnectionInput(
                tenant_id="t1",
                provider="mock",
                account=ProviderAccount(
                    external_account_id="acct-1",
                    bank_name="Al Rajhi",
                    currency="SAR",
                ),
                tokens=ProviderAuthTokens(access_token="X" * 40),
            )
        )
        bf.sync_account(rid)
        txns = bf.list_transactions(connection_id=rid)
        assert txns, "mock provider should have produced rows"
        bank_row = txns[0]
        bank_tx_id = bank_row["id"]

        # Build a candidate identical to the bank row so the scorer
        # returns 1.0 → guardrail auto-applies.
        candidate = {
            "id": "JE-777",
            "amount": bank_row["amount"],
            "date": bank_row["txn_date"],
            "vendor": bank_row.get("counterparty"),
            "description": bank_row.get("description"),
        }
        result = br.auto_match_via_guardrail(
            {
                "id": bank_tx_id,
                "amount": bank_row["amount"],
                "date": bank_row["txn_date"],
                "vendor": bank_row.get("counterparty"),
                "description": bank_row.get("description"),
            },
            [candidate],
            bank_tx_id=bank_tx_id,
            entity_type="journal_entry",
            tenant_id="t1",
            user_id="tester",
        )

        assert result.verdict == Verdict.AUTO_APPLIED.value
        assert result.matched is True

        # Verify the row was actually marked in the DB.
        db = SessionLocal()
        try:
            row = (
                db.query(BankFeedTransaction)
                .filter(BankFeedTransaction.id == bank_tx_id)
                .one()
            )
            assert row.matched_entity_id == "JE-777"
            assert row.matched_entity_type == "journal_entry"
        finally:
            db.close()


# ── HTTP routes ───────────────────────────────────────────────────────


class TestProposeRoute:
    def test_requires_auth(self, client: TestClient):
        r = client.post("/bank-rec/propose", json={})
        assert r.status_code == 401

    def test_happy_path(self, client: TestClient, auth_header):
        payload = {
            "bank_tx": {
                "id": "B1",
                "amount": "1000.00",
                "date": "2026-04-01",
                "vendor": "STC",
                "description": "Mobile bill",
            },
            "candidates": [
                {
                    "id": "JE-1",
                    "amount": "1000.00",
                    "date": "2026-04-01",
                    "vendor": "STC",
                    "description": "Mobile bill",
                },
                {
                    "id": "JE-2",
                    "amount": "500.00",
                    "date": "2026-04-20",
                    "vendor": "Other",
                    "description": "Rent",
                },
            ],
        }
        r = client.post("/bank-rec/propose", headers=auth_header, json=payload)
        assert r.status_code == 200, r.text
        data = r.json()["data"]
        assert data["count"] >= 1
        assert data["proposals"][0]["candidate_id"] == "JE-1"
        assert data["proposals"][0]["score"] == pytest.approx(1.0)

    def test_validation_rejects_bad_window(self, client: TestClient, auth_header):
        r = client.post(
            "/bank-rec/propose",
            headers=auth_header,
            json={"bank_tx": {"amount": "1"}, "date_window_days": -5},
        )
        assert r.status_code == 422


class TestAutoMatchRoute:
    def test_requires_auth(self, client: TestClient):
        r = client.post("/bank-rec/auto-match", json={})
        assert r.status_code == 401

    def test_auto_match_high_score(self, client: TestClient, auth_header):
        payload = {
            "bank_tx": {
                "id": "B1",
                "amount": "1000.00",
                "date": "2026-04-01",
                "vendor": "STC",
                "description": "Mobile bill",
            },
            "candidates": [
                {
                    "id": "JE-1",
                    "amount": "1000.00",
                    "date": "2026-04-01",
                    "vendor": "STC",
                    "description": "Mobile bill",
                }
            ],
            "tenant_id": "t1",
        }
        r = client.post(
            "/bank-rec/auto-match", headers=auth_header, json=payload
        )
        assert r.status_code == 200, r.text
        data = r.json()["data"]
        assert data["verdict"] == Verdict.AUTO_APPLIED.value
        assert data["score"] == pytest.approx(1.0)
        assert data["best_candidate_id"] == "JE-1"
        assert data["row_id"]

    def test_auto_match_low_score_needs_approval(
        self, client: TestClient, auth_header
    ):
        payload = {
            "bank_tx": {
                "id": "B1",
                "amount": "1000.00",
                "date": "2026-04-01",
                "vendor": "STC",
                "description": "Mobile bill",
            },
            "candidates": [
                {
                    "id": "JE-X",
                    "amount": "1000.00",
                    "date": "2026-06-20",
                    "vendor": "مورد غير معروف",
                    "description": "Totally different memo",
                }
            ],
            "tenant_id": "t1",
        }
        r = client.post(
            "/bank-rec/auto-match", headers=auth_header, json=payload
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["verdict"] == Verdict.NEEDS_APPROVAL.value
        assert data["matched"] is False
