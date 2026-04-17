"""Tests for new integration modules: whatsapp, uae_fta, hr.gosi."""

from __future__ import annotations

from decimal import Decimal
from unittest.mock import patch

import pytest


# ── WhatsApp client ──────────────────────────────────────────


def test_wa_console_backend(monkeypatch):
    monkeypatch.setenv("WA_BACKEND", "console")
    import importlib

    from app.integrations.whatsapp import client

    importlib.reload(client)
    r = client.send_text_message("+966501234567", "hello")
    assert r.success is True
    assert r.backend == "console"


def test_wa_text_requires_inputs(monkeypatch):
    monkeypatch.setenv("WA_BACKEND", "console")
    import importlib

    from app.integrations.whatsapp import client

    importlib.reload(client)
    assert client.send_text_message("", "x").success is False
    assert client.send_text_message("+966", "").success is False


def test_wa_api_missing_creds():
    """Force-api backend must fail gracefully when env is incomplete."""
    import importlib

    from app.integrations.whatsapp import client

    client.WA_PHONE_NUMBER_ID = ""
    client.WA_ACCESS_TOKEN = ""
    client.WA_BACKEND = "api"
    r = client.send_text_message("+966501234567", "hi")
    assert r.success is False
    assert "not configured" in (r.error or "")
    importlib.reload(client)  # restore


def test_wa_api_happy_path(monkeypatch):
    monkeypatch.setenv("WA_BACKEND", "api")
    monkeypatch.setenv("WA_PHONE_NUMBER_ID", "123")
    monkeypatch.setenv("WA_ACCESS_TOKEN", "tok")
    import importlib

    from app.integrations.whatsapp import client

    importlib.reload(client)

    fake_resp = type(
        "R",
        (),
        {
            "status_code": 200,
            "json": lambda self: {"messages": [{"id": "msg123"}]},
            "content": b"{}",
            "text": "",
        },
    )()
    with patch("requests.post", return_value=fake_resp):
        r = client.send_text_message("+966501234567", "hi")
    assert r.success is True
    assert r.message_id == "msg123"


# ── WhatsApp templates ───────────────────────────────────────


def test_templates_lookup():
    from app.integrations.whatsapp.templates import (
        INVOICE_ISSUED_AR,
        build_body_components,
        get_template,
    )

    assert get_template("apex_invoice_issued_ar") is INVOICE_ISSUED_AR
    assert get_template("does-not-exist") is None

    comps = build_body_components(["أحمد", "1500", "INV-001", "2026-04-30"])
    assert comps[0]["type"] == "body"
    assert len(comps[0]["parameters"]) == 4
    assert comps[0]["parameters"][0]["text"] == "أحمد"


# ── WhatsApp webhook signature ──────────────────────────────


def test_wa_webhook_signature_check():
    from app.integrations.whatsapp.webhook import _verify_signature

    secret = "the-secret"
    body = b'{"hello":"world"}'
    import hashlib
    import hmac

    sig = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    assert _verify_signature(secret, body, sig) is True
    assert _verify_signature(secret, body, "sha256=deadbeef") is False
    assert _verify_signature(secret, body, None) is False
    assert _verify_signature("", body, sig) is False


# ── UAE FTA TRN validator ────────────────────────────────────


def test_trn_valid():
    from app.integrations.uae_fta import validate_trn

    ok, reason = validate_trn("100123456789012")
    assert ok is True
    assert reason is None


def test_trn_strips_spaces_dashes():
    from app.integrations.uae_fta import normalize_trn, validate_trn

    assert normalize_trn("100-123 456-789 012") == "100123456789012"
    ok, _ = validate_trn("100-123 456-789 012")
    assert ok is True


def test_trn_rejects_short():
    from app.integrations.uae_fta import validate_trn

    ok, reason = validate_trn("123")
    assert ok is False
    assert "15" in reason


def test_trn_rejects_wrong_prefix():
    from app.integrations.uae_fta import validate_trn

    ok, reason = validate_trn("200000000000000")
    assert ok is False
    assert "1" in reason


def test_trn_rejects_all_same():
    from app.integrations.uae_fta import validate_trn

    ok, _ = validate_trn("111111111111111")
    assert ok is False


# ── UAE Corporate Tax ────────────────────────────────────────


def test_ct_below_threshold_pays_zero():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("100000"),
            taxable_income=Decimal("200000"),
        )
    )
    assert r.ct_due == Decimal("0.00")
    assert r.rule_applied == "standard"


def test_ct_above_threshold_pays_9_pct_only_on_excess():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("5000000"),
            taxable_income=Decimal("500000"),
        )
    )
    # 500,000 - 375,000 = 125,000 × 9% = 11,250
    assert r.ct_due == Decimal("11250.00")


def test_ct_sbr_eligible_pays_zero():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("2000000"),
            prior_period_revenue=Decimal("1500000"),
            taxable_income=Decimal("800000"),
            elect_small_business_relief=True,
        )
    )
    assert r.ct_due == Decimal("0.00")
    assert r.rule_applied == "sbr"


def test_ct_sbr_ineligible_if_over_3m():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("3500000"),
            prior_period_revenue=Decimal("2500000"),
            taxable_income=Decimal("800000"),
            elect_small_business_relief=True,
        )
    )
    assert r.rule_applied == "standard"
    assert r.ct_due > 0


def test_ct_loss_cap_at_75_pct():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("5000000"),
            taxable_income=Decimal("400000"),
            loss_brought_forward=Decimal("400000"),
        )
    )
    # 75% of 400K = 300K used, 100K carried forward
    assert r.losses_utilized == Decimal("300000.00")
    assert r.losses_carried_forward == Decimal("100000.00")


def test_ct_qfzp_zero_on_qualifying_nine_on_rest():
    from app.integrations.uae_fta import CorporateTaxInput, calculate_corporate_tax

    r = calculate_corporate_tax(
        CorporateTaxInput(
            revenue=Decimal("10000000"),
            taxable_income=Decimal("2000000"),
            is_qfzp=True,
            qfzp_qualifying_income=Decimal("1500000"),
            qfzp_non_qualifying_income=Decimal("500000"),
        )
    )
    # 500K × 9% = 45K, no 375K exemption
    assert r.ct_due == Decimal("45000.00")
    assert r.rule_applied == "qfzp"


# ── GOSI calculator ──────────────────────────────────────────


def test_ksa_gosi_saudi_national():
    from app.hr.gosi_calculator import calculate_ksa_gosi

    r = calculate_ksa_gosi(
        basic_salary=Decimal("8000"),
        housing_allowance=Decimal("2000"),
        is_saudi=True,
    )
    # Base = 10,000; EE 10% = 1,000; ER 12% = 1,200
    assert r.applicable is True
    assert r.employee_contribution == Decimal("1000.00")
    assert r.employer_contribution == Decimal("1200.00")


def test_ksa_gosi_non_saudi_zero():
    from app.hr.gosi_calculator import calculate_ksa_gosi

    r = calculate_ksa_gosi(
        basic_salary=Decimal("15000"),
        housing_allowance=Decimal("5000"),
        is_saudi=False,
    )
    assert r.applicable is False
    assert r.employee_contribution == Decimal("0")
    assert r.employer_contribution == Decimal("0")


def test_ksa_gosi_caps_at_45k():
    from app.hr.gosi_calculator import calculate_ksa_gosi

    r = calculate_ksa_gosi(
        basic_salary=Decimal("60000"),
        housing_allowance=Decimal("10000"),
        is_saudi=True,
    )
    # Cap is 45K regardless of input
    assert r.salary_base == Decimal("45000.00")
    assert r.employee_contribution == Decimal("4500.00")


def test_uae_gpssa_national():
    from app.hr.gosi_calculator import calculate_uae_gpssa

    r = calculate_uae_gpssa(
        basic_salary=Decimal("20000"),
        housing_allowance=Decimal("5000"),
        is_gcc_national=True,
    )
    # Base 25K; EE 5% = 1,250; ER 12.5% = 3,125
    assert r.employee_contribution == Decimal("1250.00")
    assert r.employer_contribution == Decimal("3125.00")
