"""Tests for audit workflow, consolidation, and Islamic finance modules."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


# ── Benford ──────────────────────────────────────────────


def test_benford_flags_uniform_distribution():
    """A uniform distribution should NOT pass Benford's test."""
    from app.core.audit_workflow import benford_analyze
    uniform = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0] * 50
    result = benford_analyze(uniform)
    assert result.sample_size == 450
    assert not result.passes_95         # uniform fails Benford
    assert result.flagged_digits         # has outliers


def test_benford_passes_on_natural_distribution():
    """A Benford-like distribution should pass the test."""
    from app.core.audit_workflow import benford_analyze
    # First-digit frequencies matching Benford (approximate)
    amounts = []
    counts = [30, 18, 12, 10, 8, 7, 6, 5, 4]   # per 100
    for digit, count in enumerate(counts, 1):
        for _ in range(count * 2):
            amounts.append(digit * 100 + 50)
    result = benford_analyze(amounts)
    assert result.passes_95


def test_benford_handles_empty_amounts():
    from app.core.audit_workflow import benford_analyze
    result = benford_analyze([])
    assert result.sample_size == 0


def test_benford_endpoint(client):
    r = client.post("/api/v1/ai/audit/benford", json={"amounts": [100, 200, 150, 900, 800, 700, 120, 130, 140]})
    assert r.status_code == 200
    assert r.json()["success"] is True


# ── Workpapers ───────────────────────────────────────────


def test_list_workpapers_has_four():
    from app.core.audit_workflow import list_workpapers
    rows = list_workpapers()
    ids = {r["id"] for r in rows}
    assert "revenue_recognition" in ids
    assert "je_testing" in ids
    assert "cutoff_testing" in ids


def test_workpaper_endpoint(client):
    r = client.get("/api/v1/ai/audit/workpapers/je_testing")
    assert r.status_code == 200
    body = r.json()
    assert "procedures_ar" in body["data"]
    assert len(body["data"]["procedures_ar"]) > 0


def test_workpaper_not_found(client):
    r = client.get("/api/v1/ai/audit/workpapers/nope")
    assert r.status_code == 404


# ── Consolidation ────────────────────────────────────────


def test_consolidate_simple_two_entities():
    from app.core.consolidation import consolidate_from_dicts
    payload = {
        "group_name": "Test Group",
        "period_label": "FY 2025",
        "functional_currency": "SAR",
        "entities": [
            {
                "entity_id": "e1",
                "entity_name": "KSA Parent",
                "currency": "SAR",
                "fx_rate_closing": 1.0,
                "fx_rate_average": 1.0,
                "lines": [
                    {"code": "1110", "name_ar": "نقد", "classification": "asset",
                     "debit": 100000, "credit": 0},
                    {"code": "3000", "name_ar": "رأس المال", "classification": "equity",
                     "debit": 0, "credit": 100000},
                ],
            },
            {
                "entity_id": "e2",
                "entity_name": "UAE Sub",
                "currency": "AED",
                "fx_rate_closing": 1.02,   # 1 AED = 1.02 SAR
                "fx_rate_average": 1.02,
                "lines": [
                    {"code": "1110", "name_ar": "نقد", "classification": "asset",
                     "debit": 50000, "credit": 0},
                    {"code": "3000", "name_ar": "رأس المال", "classification": "equity",
                     "debit": 0, "credit": 50000},
                ],
            },
        ],
    }
    result = consolidate_from_dicts(payload)
    assert result["entity_count"] == 2
    assert result["is_balanced"] is True


def test_consolidate_eliminates_intercompany():
    from app.core.consolidation import consolidate_from_dicts
    payload = {
        "group_name": "IC Test",
        "period_label": "FY 2025",
        "functional_currency": "SAR",
        "entities": [
            {
                "entity_id": "parent",
                "entity_name": "Parent",
                "currency": "SAR", "fx_rate_closing": 1.0, "fx_rate_average": 1.0,
                "lines": [
                    {"code": "1130", "name_ar": "مدينون داخل المجموعة",
                     "classification": "asset", "debit": 20000, "credit": 0,
                     "partner_entity_id": "sub"},
                ],
            },
            {
                "entity_id": "sub",
                "entity_name": "Sub",
                "currency": "SAR", "fx_rate_closing": 1.0, "fx_rate_average": 1.0,
                "lines": [
                    {"code": "2130", "name_ar": "دائنون داخل المجموعة",
                     "classification": "liability", "debit": 0, "credit": 20000,
                     "partner_entity_id": "parent"},
                ],
            },
        ],
    }
    result = consolidate_from_dicts(payload)
    assert result["eliminations_count"] == 2


def test_consolidation_endpoint(client):
    r = client.post("/api/v1/ai/consolidation", json={
        "group_name": "X",
        "period_label": "Q1",
        "functional_currency": "SAR",
        "entities": [],
    })
    assert r.status_code == 200
    assert r.json()["data"]["entity_count"] == 0


# ── Islamic finance ──────────────────────────────────────


def test_murabaha_schedule_sums_correctly():
    from app.core.islamic_finance import murabaha_schedule
    r = murabaha_schedule(
        cost_price=100000,
        selling_price=120000,
        start_date="2026-01-01",
        installments=12,
    )
    assert r["total_markup"] == 20000
    assert len(r["schedule"]) == 12
    total_profit = sum(p["profit_recognized"] for p in r["schedule"])
    assert abs(total_profit - 20000) < 0.5   # cumulative rounding tolerance


def test_murabaha_rejects_bad_inputs():
    from app.core.islamic_finance import murabaha_schedule
    r = murabaha_schedule(cost_price=100, selling_price=50, start_date="2026-01-01", installments=12)
    assert "error" in r


def test_zakah_base_simple():
    from app.core.islamic_finance import zakah_base
    r = zakah_base(
        current_assets=500000,
        investments_for_trade=100000,
        fixed_assets_net=800000,
        intangibles=50000,
        current_liabilities=200000,
        long_term_liabilities_due_within_year=100000,
    )
    # base = 500k + 100k - 200k - 100k = 300k
    # zakah = 300k * 2.5% = 7500
    assert r["base"] == 300000
    assert r["zakah_payable"] == 7500


def test_zakah_base_zero_floor():
    """Negative base clamps to zero (can't owe negative zakah)."""
    from app.core.islamic_finance import zakah_base
    r = zakah_base(
        current_assets=100,
        investments_for_trade=0,
        fixed_assets_net=0,
        intangibles=0,
        current_liabilities=10000,   # way more than assets
        long_term_liabilities_due_within_year=0,
    )
    assert r["base"] == 0
    assert r["zakah_payable"] == 0


def test_islamic_endpoints(client):
    # Murabaha
    r = client.post("/api/v1/ai/islamic/murabaha", json={
        "cost_price": 10000, "selling_price": 12000,
        "start_date": "2026-01-01", "installments": 6,
    })
    assert r.status_code == 200
    # Zakah
    r2 = client.post("/api/v1/ai/islamic/zakah", json={"current_assets": 1000})
    assert r2.status_code == 200
    # Ijarah
    r3 = client.post("/api/v1/ai/islamic/ijarah", json={
        "rental_per_period": 5000, "periods": 12, "start_date": "2026-01-01",
    })
    assert r3.status_code == 200
    assert len(r3.json()["data"]["schedule"]) == 12
