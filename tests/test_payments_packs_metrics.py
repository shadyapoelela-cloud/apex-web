"""Tests for payments factory + industry packs + startup metrics."""

from __future__ import annotations

from decimal import Decimal
from unittest.mock import patch

import pytest


# ── Payment factory ────────────────────────────────────────


def test_get_provider_defaults_to_mock(monkeypatch):
    monkeypatch.delenv("PAYMENT_BACKEND", raising=False)
    from app.integrations.payments.factory import PaymentProvider, get_provider

    assert get_provider() == PaymentProvider.MOCK


def test_get_provider_honours_env(monkeypatch):
    monkeypatch.setenv("PAYMENT_BACKEND", "mada")
    from app.integrations.payments.factory import PaymentProvider, get_provider

    assert get_provider() == PaymentProvider.MADA


def test_get_provider_honours_preferred_over_env(monkeypatch):
    monkeypatch.setenv("PAYMENT_BACKEND", "mada")
    from app.integrations.payments.factory import PaymentProvider, get_provider

    assert get_provider("stc_pay") == PaymentProvider.STC_PAY


def test_unknown_provider_falls_back_to_mock():
    from app.integrations.payments.factory import PaymentProvider, get_provider

    assert get_provider("does-not-exist") == PaymentProvider.MOCK


def test_mock_provider_returns_pay_url():
    from app.integrations.payments import create_payment_link

    r = create_payment_link(
        amount=100.0,
        currency="SAR",
        reference="INV-1",
        preferred="mock",
    )
    assert r.success is True
    assert r.provider == "mock"
    assert "INV-1" in r.pay_url


def test_mada_without_creds_fails_gracefully():
    from app.integrations.payments import create_payment_link

    r = create_payment_link(
        amount=100, currency="SAR", reference="INV-2", preferred="mada"
    )
    assert r.success is False
    assert "credentials not configured" in (r.error or "")


def test_stc_pay_requires_phone():
    from app.integrations.payments import create_payment_link

    r = create_payment_link(
        amount=100, currency="SAR", reference="INV-3", preferred="stc_pay"
    )
    assert r.success is False


def test_apple_pay_requires_validation_url():
    from app.integrations.payments.apple_pay import create_session

    r = create_session(
        amount=100, currency="SAR", reference="INV-4", callback_url=None
    )
    assert r.success is False


# ── Industry Packs ─────────────────────────────────────────


def test_list_packs_has_five():
    from app.industry_packs import list_packs

    packs = list_packs()
    ids = {p.id for p in packs}
    assert ids == {"fnb_retail", "construction", "medical", "logistics", "services"}


def test_get_pack_by_id_returns_coa():
    from app.industry_packs import get_pack

    pack = get_pack("fnb_retail")
    assert pack is not None
    assert pack.name_ar == "المطاعم والتجزئة"
    # Look for a known account
    codes = {a.code for a in pack.coa_accounts}
    assert "4300" in codes  # Delivery revenue
    assert "2300" in codes  # Tip pool liability


def test_all_packs_have_coa_and_widgets():
    from app.industry_packs import list_packs

    for p in list_packs():
        assert len(p.coa_accounts) >= 5
        assert len(p.dashboard_widgets) >= 3


def test_construction_pack_has_wip():
    from app.industry_packs import get_pack

    pack = get_pack("construction")
    account_names = {a.name_en for a in pack.coa_accounts}
    assert "Work In Progress" in account_names
    assert "Customer Retention Receivable" in account_names


def test_services_pack_has_mrr_widget():
    from app.industry_packs import get_pack

    pack = get_pack("services")
    metrics = {w.metric for w in pack.dashboard_widgets}
    assert "mrr" in metrics
    assert "burn_rate" in metrics
    assert "runway_months" in metrics


def test_get_unknown_pack_returns_none():
    from app.industry_packs import get_pack

    assert get_pack("unknown-pack") is None


# ── Startup Metrics ────────────────────────────────────────


def test_compute_burn_empty():
    from app.features.startup_metrics import compute_burn

    r = compute_burn([])
    assert r.gross_burn == Decimal("0")


def test_compute_burn_averages():
    from app.features.startup_metrics import compute_burn

    r = compute_burn(
        monthly_expenses=[Decimal("50000"), Decimal("60000"), Decimal("70000")],
        monthly_revenues=[Decimal("10000"), Decimal("15000"), Decimal("20000")],
    )
    assert r.gross_burn == Decimal("60000.00")
    assert r.net_burn == Decimal("45000.00")


def test_compute_runway_zero_burn():
    from app.features.startup_metrics import compute_runway

    r = compute_runway(Decimal("500000"), Decimal("0"))
    assert r.months_remaining == Decimal("9999")


def test_compute_runway_danger_flag():
    from app.features.startup_metrics import compute_runway

    try:
        import dateutil  # noqa: F401
    except ImportError:
        pytest.skip("dateutil not installed")
    r = compute_runway(Decimal("100000"), Decimal("25000"))
    assert r.months_remaining == Decimal("4.00")
    assert r.danger is True


def test_compute_mrr_basic():
    from app.features.startup_metrics import arr_from_mrr, compute_mrr

    subs = [Decimal("100"), Decimal("200"), Decimal("300")]
    r = compute_mrr(subs)
    assert r.mrr == Decimal("600.00")
    assert r.customers == 3
    assert r.arpa == Decimal("200.00")
    arr = arr_from_mrr(r.mrr)
    assert arr.arr == Decimal("7200.00")


def test_ltv_cac_typical():
    from app.features.startup_metrics import compute_ltv_cac

    r = compute_ltv_cac(
        acquisition_cost=Decimal("100000"),
        new_customers=100,
        gross_margin_pct=Decimal("80"),
        arpa=Decimal("500"),
        monthly_churn_pct=Decimal("2"),
    )
    # CAC = 1000; lifetime = 100/2 = 50 months
    # LTV = 500 × 0.8 × 50 = 20,000; ratio = 20
    assert r.cac == Decimal("1000.00")
    assert r.ltv == Decimal("20000.00")
    assert r.ltv_to_cac == Decimal("20.00")
    # payback = 1000 / (500 × 0.8) = 2.5 months
    assert r.payback_months == Decimal("2.50")


def test_ltv_cac_infinite_when_no_churn():
    from app.features.startup_metrics import compute_ltv_cac

    r = compute_ltv_cac(
        acquisition_cost=Decimal("1000"),
        new_customers=1,
        gross_margin_pct=Decimal("80"),
        arpa=Decimal("100"),
        monthly_churn_pct=Decimal("0"),
    )
    # Lifetime = 9999 months
    assert r.ltv > Decimal("100000")


def test_rule_of_40_passes():
    from app.features.startup_metrics import compute_rule_of_40

    r = compute_rule_of_40(
        growth_rate_pct=Decimal("30"),
        ebitda_margin_pct=Decimal("15"),
    )
    assert r.score == Decimal("45.00")
    assert r.passes_rule is True


def test_rule_of_40_fails():
    from app.features.startup_metrics import compute_rule_of_40

    r = compute_rule_of_40(
        growth_rate_pct=Decimal("20"),
        ebitda_margin_pct=Decimal("5"),
    )
    assert r.passes_rule is False


# ── Open Banking consent helpers ────────────────────────────


def test_consent_expiry_defaults_180_days():
    from datetime import datetime, timezone

    from app.integrations.open_banking.consent import consent_expiry

    now = datetime.now(timezone.utc)
    exp = consent_expiry()
    delta = (exp - now).days
    assert 179 <= delta <= 180


def test_generate_state_is_strong():
    from app.integrations.open_banking.consent import generate_state

    s1 = generate_state()
    s2 = generate_state()
    assert s1 != s2
    assert len(s1) >= 32


def test_build_authorize_url_includes_params():
    from app.integrations.open_banking.consent import build_authorize_url

    url = build_authorize_url(
        base_url="https://bank.example.com/api",
        client_id="apex-client",
        redirect_uri="https://apex-app.com/cb",
        scope=["accounts", "transactions"],
        state="rand-state",
    )
    assert "client_id=apex-client" in url
    assert "response_type=code" in url
    assert "state=rand-state" in url
    assert "scope=accounts+transactions" in url
