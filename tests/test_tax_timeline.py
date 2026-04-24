"""Tests for app/core/tax_timeline.py and GET /api/v1/ai/tax-timeline."""

from __future__ import annotations

from datetime import date

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


# ── Pure function tests ──────────────────────────────────


def test_ksa_monthly_vat_returns_obligations():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 15),
        horizon_days=90,
        tenant_profile={"country": "sa", "vat_cadence": "monthly"},
    )
    assert len(rows) > 0
    vat = [r for r in rows if r["kind"] == "vat"]
    assert vat
    # Every row must have these keys.
    for r in rows:
        assert "id" in r and "kind" in r and "due_date" in r
        assert "severity" in r and r["severity"] in ("info", "warning", "error")
        assert "days_until" in r


def test_ksa_quarterly_vat_returns_obligations():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 15),
        horizon_days=180,
        tenant_profile={"country": "sa", "vat_cadence": "quarterly"},
    )
    assert any(r["kind"] == "vat" for r in rows)


def test_zakat_obligation_when_fiscal_year_set():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 1, 15),
        horizon_days=365,
        tenant_profile={
            "country": "sa",
            "vat_cadence": "monthly",
            "fiscal_year_end": "2025-12-31",
        },
    )
    zakat = [r for r in rows if r["kind"] == "zakat"]
    assert len(zakat) == 1
    assert zakat[0]["jurisdiction"] == "sa"


def test_csid_expiry_shows_in_timeline():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 15),
        horizon_days=60,
        tenant_profile={
            "country": "sa",
            "zatca_csid_expires_at": "2026-05-15",
        },
    )
    csid = [r for r in rows if r["kind"] == "zatca_csid"]
    assert len(csid) == 1
    assert csid[0]["days_until"] == 30


def test_severity_ramps_as_deadline_nears():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 25),
        horizon_days=60,
        tenant_profile={"country": "sa", "vat_cadence": "monthly"},
    )
    # Some obligations should be "warning" (≤21d) or "error" (≤7d).
    severities = {r["severity"] for r in rows}
    assert "warning" in severities or "error" in severities


def test_uae_quarterly_and_corporate_tax():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 15),
        horizon_days=365,
        tenant_profile={
            "country": "ae",
            "fiscal_year_end": "2025-12-31",
        },
    )
    assert any(r["kind"] == "vat" and r["jurisdiction"] == "ae" for r in rows)
    assert any(r["kind"] == "corporate_tax" for r in rows)


def test_results_are_sorted_by_due_date():
    from app.core.tax_timeline import upcoming_obligations
    rows = upcoming_obligations(
        today=date(2026, 4, 15),
        horizon_days=180,
        tenant_profile={"country": "sa", "vat_cadence": "monthly"},
    )
    dates = [r["due_date"] for r in rows]
    assert dates == sorted(dates)


# ── HTTP endpoint tests ──────────────────────────────────


def test_tax_timeline_endpoint_returns_200(client):
    r = client.get("/api/v1/ai/tax-timeline?country=sa&horizon_days=90")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert "data" in body
    assert isinstance(body["data"], list)


def test_tax_timeline_endpoint_horizon_clamped(client):
    r = client.get("/api/v1/ai/tax-timeline?horizon_days=9999")
    assert r.status_code == 422  # pydantic clamps via le=365


def test_tax_timeline_with_fiscal_year_param(client):
    r = client.get(
        "/api/v1/ai/tax-timeline?country=sa&fiscal_year_end=2025-12-31&horizon_days=200"
    )
    assert r.status_code == 200
    body = r.json()
    rows = body["data"]
    assert any(r["kind"] == "zakat" for r in rows)
