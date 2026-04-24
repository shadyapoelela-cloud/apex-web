"""Tests for industry-specific COA templates."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


# ── Pure data tests ──────────────────────────────────────


def test_list_templates_has_five_industries():
    from app.core.coa_industry_templates import list_templates
    rows = list_templates()
    ids = {r["id"] for r in rows}
    assert ids == {"restaurant", "retail", "services", "contracting", "medical"}


def test_each_template_has_accounts():
    from app.core.coa_industry_templates import TEMPLATES
    for tid, tpl in TEMPLATES.items():
        assert tpl["accounts"], f"{tid} template is empty"
        for account in tpl["accounts"]:
            assert "code" in account
            assert "name_ar" in account
            assert "category" in account
            assert account["category"] in ("asset", "liability", "equity", "revenue", "expense")


def test_restaurant_splits_delivery_vs_dine_in():
    from app.core.coa_industry_templates import get_template
    tpl = get_template("restaurant")
    names = {a["name_ar"] for a in tpl["accounts"]}
    assert "مبيعات الصالة" in names
    assert "مبيعات التوصيل" in names


def test_contracting_has_retention_payable():
    """Muqawala retention is non-negotiable for construction in KSA."""
    from app.core.coa_industry_templates import get_template
    tpl = get_template("contracting")
    codes = {a["code"] for a in tpl["accounts"]}
    assert "2501" in codes  # retention payable


def test_medical_splits_insurance_ar():
    from app.core.coa_industry_templates import get_template
    tpl = get_template("medical")
    names = {a["name_ar"] for a in tpl["accounts"]}
    assert any("تأمين" in n for n in names)


def test_services_has_deferred_revenue():
    """Retainer-based firms need deferred revenue from day 1."""
    from app.core.coa_industry_templates import get_template
    tpl = get_template("services")
    names = {a["name_ar"] for a in tpl["accounts"]}
    assert any("مؤجّلة" in n for n in names)


def test_get_template_unknown_returns_none():
    from app.core.coa_industry_templates import get_template
    assert get_template("not_a_real_industry") is None


# ── HTTP endpoints ───────────────────────────────────────


def test_list_endpoint_returns_all_templates(client):
    r = client.get("/api/v1/ai/coa-templates")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert len(body["data"]) == 5
    for row in body["data"]:
        assert "account_count" in row
        assert row["account_count"] > 0


def test_get_endpoint_returns_template(client):
    r = client.get("/api/v1/ai/coa-templates/restaurant")
    assert r.status_code == 200
    body = r.json()
    assert body["data"]["id"] == "restaurant"
    assert body["data"]["accounts"]


def test_get_endpoint_404_unknown(client):
    r = client.get("/api/v1/ai/coa-templates/nope")
    assert r.status_code == 404
