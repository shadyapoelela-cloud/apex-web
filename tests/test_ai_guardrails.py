"""
Tests for app/core/ai_guardrails.py + routes (Wave 7).

Covers:
- _evaluate() pure logic: confidence floor, destructive override,
  out-of-range rejection.
- guard() persistence + audit event emission.
- approve()/reject() transitions + idempotency + terminal-state errors.
- HTTP routes: evaluate, list (with status+source filter), stats,
  detail, approve (happy + 404 + conflict), reject.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core import ai_guardrails as g
from app.core.ai_guardrails import Suggestion, Verdict
from app.core.compliance_models import AiSuggestion
from app.core.compliance_service import verify_audit_chain
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset():
    from app.core.compliance_models import AuditTrail

    db = SessionLocal()
    try:
        db.query(AiSuggestion).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    yield


def _mk(**overrides) -> Suggestion:
    defaults = dict(
        source="copilot",
        action_type="categorize_txn",
        after={"category": "Travel"},
        confidence=0.97,
        target_type="transaction",
        target_id="TXN-1",
        reasoning="Vendor 'Marriott' matches Travel",
    )
    defaults.update(overrides)
    return Suggestion(**defaults)


# ── Pure logic ────────────────────────────────────────────────────────


class TestEvaluate:
    def test_high_confidence_auto_applies(self):
        verdict, reason = g._evaluate(_mk(confidence=0.99), 0.95)
        assert verdict == Verdict.AUTO_APPLIED
        assert "99.0" in reason

    def test_exact_floor_auto_applies(self):
        verdict, _ = g._evaluate(_mk(confidence=0.95), 0.95)
        assert verdict == Verdict.AUTO_APPLIED

    def test_below_floor_needs_approval(self):
        verdict, reason = g._evaluate(_mk(confidence=0.80), 0.95)
        assert verdict == Verdict.NEEDS_APPROVAL
        assert "دون" in reason

    def test_destructive_always_needs_approval(self):
        verdict, reason = g._evaluate(_mk(destructive=True, confidence=0.99), 0.95)
        assert verdict == Verdict.NEEDS_APPROVAL
        assert "تدميري" in reason

    def test_out_of_range_confidence_rejected(self):
        verdict, _ = g._evaluate(_mk(confidence=1.5), 0.95)
        assert verdict == Verdict.REJECTED
        verdict, _ = g._evaluate(_mk(confidence=-0.1), 0.95)
        assert verdict == Verdict.REJECTED

    def test_min_confidence_per_suggestion_override(self):
        # Caller overrides floor to 0.70 — a 0.80 confidence now auto-applies.
        verdict, _ = g._evaluate(_mk(confidence=0.80), 0.70)
        assert verdict == Verdict.AUTO_APPLIED


# ── guard() with DB ───────────────────────────────────────────────────


class TestGuardPersistence:
    def test_guard_persists_and_audits(self):
        decision = g.guard(_mk())
        assert decision.verdict == Verdict.AUTO_APPLIED
        row = g.get_row(decision.row_id)
        assert row is not None
        assert row["status"] == "auto_applied"
        assert row["confidence"] == pytest.approx(0.97, abs=0.001)
        # Audit chain remains valid after the guard write.
        assert verify_audit_chain()["ok"] is True

    def test_low_confidence_lands_in_pending(self):
        d = g.guard(_mk(confidence=0.40))
        assert d.verdict == Verdict.NEEDS_APPROVAL
        assert g.get_row(d.row_id)["status"] == "needs_approval"

    def test_confidence_stored_as_permille(self):
        d = g.guard(_mk(confidence=0.875))
        db = SessionLocal()
        try:
            row = db.query(AiSuggestion).filter(AiSuggestion.id == d.row_id).first()
            assert row.confidence == 875
        finally:
            db.close()


# ── approve / reject ──────────────────────────────────────────────────


class TestTransitions:
    def test_approve_needs_approval_row(self):
        d = g.guard(_mk(confidence=0.5))
        v = g.approve(d.row_id, user_id="user-1")
        assert v == Verdict.APPROVED
        row = g.get_row(d.row_id)
        assert row["status"] == "approved"
        assert row["approved_by"] == "user-1"

    def test_approve_is_idempotent(self):
        d = g.guard(_mk(confidence=0.5))
        g.approve(d.row_id, user_id="u1")
        v = g.approve(d.row_id, user_id="u1")  # no-op
        assert v == Verdict.APPROVED

    def test_cannot_approve_rejected(self):
        d = g.guard(_mk(confidence=0.5))
        g.reject(d.row_id, user_id="u1", reason="wrong")
        with pytest.raises(ValueError):
            g.approve(d.row_id, user_id="u1")

    def test_reject_from_needs_approval(self):
        d = g.guard(_mk(confidence=0.5))
        g.reject(d.row_id, user_id="u1", reason="mis-categorized")
        row = g.get_row(d.row_id)
        assert row["status"] == "rejected"
        assert row["rejection_reason"] == "mis-categorized"

    def test_reject_retroactive_over_auto_applied(self):
        # Auto-applied suggestion can still be flipped by a human.
        d = g.guard(_mk(confidence=0.99))
        g.reject(d.row_id, user_id="u1", reason="false positive")
        assert g.get_row(d.row_id)["status"] == "rejected"

    def test_reject_is_idempotent(self):
        d = g.guard(_mk(confidence=0.5))
        g.reject(d.row_id, user_id="u1", reason="x")
        v = g.reject(d.row_id, user_id="u1", reason="x")
        assert v == Verdict.REJECTED

    def test_approve_unknown_raises(self):
        with pytest.raises(LookupError):
            g.approve("no-such-row", user_id="u1")


class TestStats:
    def test_counts_by_verdict(self):
        g.guard(_mk(confidence=0.99))        # auto_applied
        g.guard(_mk(confidence=0.5))          # needs_approval
        low_id = g.guard(_mk(confidence=0.4)).row_id
        g.reject(low_id, user_id="u1", reason="no")  # rejected
        s = g.stats()
        assert s["auto_applied"] == 1
        assert s["needs_approval"] == 1
        assert s["rejected"] == 1
        assert s["total"] == 3


# ── HTTP routes ───────────────────────────────────────────────────────


class TestEvaluateRoute:
    def test_auth_required(self, client: TestClient):
        r = client.post(
            "/ai/guardrails/evaluate",
            json={
                "source": "copilot",
                "action_type": "x",
                "after": {},
                "confidence": 0.9,
            },
        )
        assert r.status_code == 401

    def test_happy_path_returns_verdict(self, client: TestClient, auth_header):
        r = client.post(
            "/ai/guardrails/evaluate",
            headers=auth_header,
            json={
                "source": "copilot",
                "action_type": "categorize",
                "after": {"category": "Travel"},
                "confidence": 0.97,
            },
        )
        assert r.status_code == 200
        data = r.json()["data"]
        assert data["verdict"] == "auto_applied"
        assert data["id"]

    def test_destructive_flag_forces_approval(self, client: TestClient, auth_header):
        r = client.post(
            "/ai/guardrails/evaluate",
            headers=auth_header,
            json={
                "source": "copilot",
                "action_type": "reverse_je",
                "after": {"je_id": "JE-1"},
                "confidence": 0.99,
                "destructive": True,
            },
        )
        assert r.json()["data"]["verdict"] == "needs_approval"

    def test_confidence_out_of_range_rejected_by_schema(
        self, client: TestClient, auth_header
    ):
        r = client.post(
            "/ai/guardrails/evaluate",
            headers=auth_header,
            json={
                "source": "x",
                "action_type": "y",
                "after": {},
                "confidence": 1.5,
            },
        )
        assert r.status_code == 422


class TestQueryRoutes:
    def test_list_filters_by_status(self, client: TestClient, auth_header):
        g.guard(_mk(confidence=0.99))
        g.guard(_mk(confidence=0.4))
        r = client.get(
            "/ai/guardrails?status=needs_approval", headers=auth_header
        )
        assert r.status_code == 200
        assert r.json()["data"]["count"] == 1

    def test_list_bad_status_rejected(self, client: TestClient, auth_header):
        r = client.get("/ai/guardrails?status=bogus", headers=auth_header)
        assert r.status_code == 400

    def test_stats_endpoint(self, client: TestClient, auth_header):
        g.guard(_mk(confidence=0.99))
        r = client.get("/ai/guardrails/stats", headers=auth_header)
        assert r.status_code == 200
        assert r.json()["data"]["auto_applied"] >= 1

    def test_detail_404(self, client: TestClient, auth_header):
        r = client.get("/ai/guardrails/does-not-exist", headers=auth_header)
        assert r.status_code == 404


class TestApproveRejectRoutes:
    def test_approve_happy(self, client: TestClient, auth_header):
        d = g.guard(_mk(confidence=0.5))
        r = client.post(
            f"/ai/guardrails/{d.row_id}/approve",
            headers=auth_header,
        )
        assert r.status_code == 200
        assert r.json()["data"]["verdict"] == "approved"

    def test_approve_rejected_returns_409(self, client: TestClient, auth_header):
        d = g.guard(_mk(confidence=0.5))
        g.reject(d.row_id, user_id="u1", reason="x")
        r = client.post(
            f"/ai/guardrails/{d.row_id}/approve",
            headers=auth_header,
        )
        assert r.status_code == 409

    def test_reject_happy_with_reason(self, client: TestClient, auth_header):
        d = g.guard(_mk(confidence=0.5))
        r = client.post(
            f"/ai/guardrails/{d.row_id}/reject",
            headers=auth_header,
            json={"reason": "looks wrong"},
        )
        assert r.status_code == 200
        assert r.json()["data"]["verdict"] == "rejected"
        # reason persisted
        row = g.get_row(d.row_id)
        assert row["rejection_reason"] == "looks wrong"
