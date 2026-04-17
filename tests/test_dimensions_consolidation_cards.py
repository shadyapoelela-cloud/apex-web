"""Tests for Dimensional Accounting + Intercompany Consolidation + Corporate Cards."""

from __future__ import annotations

from decimal import Decimal

import pytest


# ── Dimensional Accounting ────────────────────────────────


def test_dimensions_list_and_create(client):
    # List (may be empty or have defaults)
    listing = client.get("/api/v1/dimensions")
    assert listing.status_code == 200

    # Create
    resp = client.post(
        "/api/v1/dimensions",
        json={"code": "test_dim", "name_ar": "بُعد اختباري", "required": False},
    )
    assert resp.status_code == 201, resp.text
    dim = resp.json()["data"]
    assert dim["code"] == "test_dim"
    assert dim["active"] is True


def test_dimensions_rejects_duplicate_code(client):
    client.post("/api/v1/dimensions", json={"code": "dup_dim", "name_ar": "مكرر"})
    # Second attempt should 409
    resp = client.post("/api/v1/dimensions", json={"code": "dup_dim", "name_ar": "مرة ثانية"})
    assert resp.status_code == 409


def test_dimensions_rejects_invalid_code(client):
    """Code must match [a-z][a-z0-9_]{1,30}."""
    resp = client.post("/api/v1/dimensions", json={"code": "Invalid-Code!", "name_ar": "x"})
    assert resp.status_code == 422


def test_dimension_values_crud(client):
    dim = client.post(
        "/api/v1/dimensions",
        json={"code": "branches", "name_ar": "فروع"},
    ).json()["data"]
    dim_id = dim["id"]

    # Create value
    val = client.post(
        f"/api/v1/dimensions/{dim_id}/values",
        json={"code": "RIY", "name_ar": "الرياض"},
    )
    assert val.status_code == 201
    # List values
    values = client.get(f"/api/v1/dimensions/{dim_id}/values")
    assert values.status_code == 200
    assert any(v["code"] == "RIY" for v in values.json()["data"])


def test_dimension_values_unknown_dim_404(client):
    resp = client.post(
        "/api/v1/dimensions/nonexistent/values",
        json={"code": "X", "name_ar": "X"},
    )
    assert resp.status_code == 404


def test_ensure_default_dimensions_creates_4():
    from app.core.dimensional_accounting import ensure_default_dimensions

    created = ensure_default_dimensions()
    # Second call should create 0 (already there)
    again = ensure_default_dimensions()
    assert len(again) == 0


def test_aggregate_endpoint_returns_empty_for_empty_dim(client):
    dim = client.post(
        "/api/v1/dimensions",
        json={"code": "agg_test", "name_ar": "تجميع"},
    ).json()["data"]
    resp = client.get(f"/api/v1/dimensions/{dim['id']}/aggregate")
    assert resp.status_code == 200
    assert resp.json()["data"] == []


# ── Intercompany matching ─────────────────────────────────


def test_intercompany_matches_opposing_legs():
    from app.core.consolidation_intercompany import (
        IntercompanyLine,
        match_intercompany_lines,
    )

    # A sold to B; A books +100 receivable, B books -100 payable (same reference)
    a = IntercompanyLine(
        entity_id="A",
        counterparty_entity_id="B",
        account_code="1200",
        amount=Decimal("100"),
        currency="SAR",
        reference="IC-001",
    )
    b = IntercompanyLine(
        entity_id="B",
        counterparty_entity_id="A",
        account_code="2100",
        amount=Decimal("-100"),
        currency="SAR",
        reference="IC-001",
    )
    pairs, unmatched = match_intercompany_lines([a, b])
    assert len(pairs) == 1
    assert pairs[0].matched is True
    assert pairs[0].elimination_amount == Decimal("100.00")
    assert unmatched == []


def test_intercompany_flags_unmatched_lines():
    from app.core.consolidation_intercompany import (
        IntercompanyLine,
        match_intercompany_lines,
    )

    # Same sign (both +) — can't be matched
    a = IntercompanyLine("A", "B", "1200", Decimal("50"), "SAR", reference="IC-002")
    b = IntercompanyLine("B", "A", "2100", Decimal("50"), "SAR", reference="IC-002")
    pairs, unmatched = match_intercompany_lines([a, b])
    assert pairs == []
    assert len(unmatched) >= 1


def test_intercompany_tolerance_variance():
    from app.core.consolidation_intercompany import (
        IntercompanyLine,
        match_intercompany_lines,
    )

    # 100 vs -99.99 — within 0.01 tolerance
    a = IntercompanyLine("A", "B", "1200", Decimal("100"), "SAR", reference="IC-003")
    b = IntercompanyLine("B", "A", "2100", Decimal("-99.99"), "SAR", reference="IC-003")
    pairs, unmatched = match_intercompany_lines([a, b], tolerance=Decimal("0.01"))
    assert len(pairs) == 1
    assert pairs[0].matched is True


# ── FX translation ────────────────────────────────────────


def test_translate_trial_balance_applies_correct_rates():
    from app.core.consolidation_intercompany import FxRate, translate_trial_balance

    rate = FxRate(
        currency_from="AED",
        currency_to="SAR",
        rate_current=Decimal("1.02"),
        rate_average=Decimal("1.01"),
        rate_historical=Decimal("1.00"),
    )
    tb = [
        {"account_code": "1100", "account_type": "asset", "amount": 1000, "currency": "AED"},
        {"account_code": "2100", "account_type": "liability", "amount": 500, "currency": "AED"},
        {"account_code": "3000", "account_type": "equity", "amount": 300, "currency": "AED"},
        {"account_code": "4000", "account_type": "revenue", "amount": 200, "currency": "AED"},
        {"account_code": "5000", "account_type": "expense", "amount": 50, "currency": "AED"},
    ]
    translated, cta = translate_trial_balance(tb, rate)
    # Assets at current rate: 1000 × 1.02 = 1020
    asset = next(t for t in translated if t.account_code == "1100")
    assert asset.translated_amount == Decimal("1020.00")
    assert asset.rate_basis == "current"
    # Revenue at average rate: 200 × 1.01 = 202
    rev = next(t for t in translated if t.account_code == "4000")
    assert rev.translated_amount == Decimal("202.00")
    assert rev.rate_basis == "average"
    # Equity at historical rate: 300 × 1.00 = 300
    eq = next(t for t in translated if t.account_code == "3000")
    assert eq.translated_amount == Decimal("300.00")
    assert eq.rate_basis == "historical"


def test_translate_trial_balance_skips_other_currencies():
    from app.core.consolidation_intercompany import FxRate, translate_trial_balance

    rate = FxRate(
        currency_from="AED", currency_to="SAR",
        rate_current=Decimal("1.0"), rate_average=Decimal("1.0"),
    )
    tb = [
        {"account_code": "1", "account_type": "asset", "amount": 100, "currency": "AED"},
        {"account_code": "2", "account_type": "asset", "amount": 200, "currency": "USD"},
    ]
    translated, _cta = translate_trial_balance(tb, rate)
    assert len(translated) == 1
    assert translated[0].account_code == "1"


# ── Minority interest ─────────────────────────────────────


def test_minority_interest_splits():
    from app.core.consolidation_intercompany import compute_minority_interest

    r = compute_minority_interest(
        subsidiary_net_income=Decimal("1000"),
        ownership_pct=Decimal("75"),
    )
    assert r.majority_share == Decimal("750.00")
    assert r.minority_share == Decimal("250.00")


def test_minority_interest_clamps_bad_pct():
    from app.core.consolidation_intercompany import compute_minority_interest

    # -10% clamps to 0, 150% clamps to 100
    r_neg = compute_minority_interest(Decimal("1000"), Decimal("-10"))
    assert r_neg.majority_share == Decimal("0.00")
    r_over = compute_minority_interest(Decimal("1000"), Decimal("150"))
    assert r_over.majority_share == Decimal("1000.00")
    assert r_over.minority_share == Decimal("0.00")


# ── Corporate Cards ──────────────────────────────────────


def test_issue_card_mock_succeeds_by_default():
    from app.integrations.corporate_cards import IssueCardRequest, issue_card

    r = issue_card(IssueCardRequest(
        employee_id="emp-1",
        employee_name_en="Ahmed Ali",
        daily_limit=Decimal("1000"),
        monthly_limit=Decimal("10000"),
    ))
    assert r.success is True
    assert r.provider == "mock"
    assert r.pan_last4 == "4242"


def test_policy_blocked_mcc_denies():
    from app.integrations.corporate_cards import check_transaction_policy

    d = check_transaction_policy(
        amount=Decimal("100"),
        currency="SAR",
        mcc="7995",  # Gambling
        blocked_mccs=["7995"],
    )
    assert d.allowed is False
    assert d.decision_type == "deny"


def test_policy_allowed_list_restricts():
    from app.integrations.corporate_cards import check_transaction_policy

    # Only 5411 (grocery) allowed
    d = check_transaction_policy(
        amount=Decimal("50"),
        currency="SAR",
        mcc="5812",      # restaurants
        allowed_mccs=["5411"],
    )
    assert d.allowed is False


def test_policy_daily_limit_exceeded_denies():
    from app.integrations.corporate_cards import check_transaction_policy

    d = check_transaction_policy(
        amount=Decimal("200"),
        currency="SAR",
        daily_spent=Decimal("900"),
        daily_limit=Decimal("1000"),
    )
    # 900 + 200 = 1100 > 1000 → deny
    assert d.allowed is False
    assert "اليومي" in d.reason


def test_policy_approval_threshold_flags_requires_approval():
    from app.integrations.corporate_cards import check_transaction_policy

    d = check_transaction_policy(
        amount=Decimal("5000"),
        currency="SAR",
        daily_limit=Decimal("10000"),
        monthly_limit=Decimal("100000"),
        approval_required_above=Decimal("1000"),
    )
    assert d.allowed is True
    assert d.decision_type == "requires_approval"


def test_policy_within_all_limits_allows():
    from app.integrations.corporate_cards import check_transaction_policy

    d = check_transaction_policy(
        amount=Decimal("50"),
        currency="SAR",
        daily_spent=Decimal("100"),
        daily_limit=Decimal("1000"),
        monthly_spent=Decimal("500"),
        monthly_limit=Decimal("10000"),
    )
    assert d.allowed is True
    assert d.decision_type == "allow"
