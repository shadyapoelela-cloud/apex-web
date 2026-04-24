"""Tests for regulatory news, fixed-asset depreciation, multi-currency dashboard."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def client():
    from app.main import app
    return TestClient(app)


# ── Regulatory news ──────────────────────────────────────


def test_news_list_not_empty():
    from app.core.regulatory_news import list_news
    assert len(list_news()) >= 5


def test_news_filter_by_jurisdiction():
    from app.core.regulatory_news import list_news
    sa = list_news(jurisdiction="sa")
    assert all(n["jurisdiction"] == "sa" for n in sa)


def test_news_only_future_filter():
    from app.core.regulatory_news import list_news
    fut = list_news(only_future=True)
    # Every item's effective date >= today
    from datetime import date
    today = date.today().isoformat()
    assert all(n["effective_date"] >= today for n in fut)


def test_news_endpoint(client):
    r = client.get("/api/v1/ai/regulatory-news?limit=5")
    assert r.status_code == 200
    assert r.json()["success"] is True


def test_news_item_not_found(client):
    r = client.get("/api/v1/ai/regulatory-news/nope")
    assert r.status_code == 404


# ── Fixed assets depreciation ────────────────────────────


def test_straight_line_totals_equal_depreciable():
    from app.core.fixed_assets import straight_line
    r = straight_line(cost=100000, salvage=10000, useful_life_periods=5)
    assert r["total_depreciation"] == 90000
    total = sum(p["depreciation"] for p in r["schedule"])
    assert abs(total - 90000) < 0.01


def test_declining_balance_stops_at_salvage():
    from app.core.fixed_assets import declining_balance
    r = declining_balance(cost=100000, salvage=10000, useful_life_periods=10, rate_pct=40)
    # NBV in last period should not drop below salvage.
    last = r["schedule"][-1]
    assert last["closing_nbv"] >= 10000 - 0.01


def test_double_declining_doubles_sl_rate():
    from app.core.fixed_assets import double_declining
    r = double_declining(cost=100000, salvage=0, useful_life_periods=5)
    assert r["method"] == "double_declining"
    # Rate = 2 / 5 = 40%
    assert abs(r["rate_pct"] - 40) < 0.001


def test_units_of_production():
    from app.core.fixed_assets import units_of_production
    r = units_of_production(
        cost=100000, salvage=10000,
        total_units_lifetime=1000,
        units_per_period=[200, 300, 500],
    )
    # depreciable = 90000, rate = 90/unit
    # periods: 200*90=18000, 300*90=27000, 500*90=45000 → total 90000
    total = sum(p["depreciation"] for p in r["schedule"])
    assert abs(total - 90000) < 0.5


def test_depreciation_endpoint(client):
    r = client.post("/api/v1/ai/fixed-assets/schedule", json={
        "method": "straight_line", "cost": 50000, "salvage": 5000, "useful_life_periods": 3,
    })
    assert r.status_code == 200
    body = r.json()
    assert len(body["data"]["schedule"]) == 3


def test_depreciation_unknown_method(client):
    r = client.post("/api/v1/ai/fixed-assets/schedule", json={
        "method": "not_a_method", "cost": 1, "useful_life_periods": 1,
    })
    assert r.status_code == 400


# ── Multi-currency dashboard ─────────────────────────────


def test_multi_currency_handles_empty_ledger():
    from app.core.multi_currency import dashboard
    r = dashboard(display_currency="SAR")
    assert r["display_currency"] == "SAR"
    assert "positions" in r
    assert "fx_exposure_pct" in r


def test_multi_currency_endpoint(client):
    r = client.get("/api/v1/ai/multi-currency/dashboard?display_currency=SAR")
    assert r.status_code == 200
    body = r.json()
    assert body["success"] is True
    assert body["data"]["display_currency"] == "SAR"
