"""Tests for app/services/copilot_tools_ledger.py — the real-ledger
aggregation layer that replaces the placeholder tool implementations.

Covers:
  • parse_period — shorthand parsing (this_month / last_month / ytd / ranges)
  • aggregate_metric — returns the legacy shape even with no data
  • lookup_entity — empty result on empty query
  • get_report_summary — TB / P&L / BS sections
  • explain_variance — "account not found" path
  • forecast_metric — zero-filled on a fresh DB

These are deliberately offline tests: the pilot_gl_postings table may or
may not exist in the test DB. Every function is proven defensive here.
"""

from __future__ import annotations

from datetime import date


# ── parse_period ──────────────────────────────────────────


def test_parse_period_this_month():
    from app.services.copilot_tools_ledger import parse_period
    r = parse_period("this_month")
    today = date.today()
    assert r.start == today.replace(day=1)
    assert r.end == today
    assert r.label == f"{r.start:%Y-%m}"


def test_parse_period_last_month():
    from app.services.copilot_tools_ledger import parse_period
    r = parse_period("last_month")
    today = date.today()
    first_this = today.replace(day=1)
    # end should be the last day of the previous month
    assert r.end < first_this
    assert r.start <= r.end
    assert r.start.day == 1


def test_parse_period_ytd():
    from app.services.copilot_tools_ledger import parse_period
    r = parse_period("ytd")
    today = date.today()
    assert r.start == today.replace(month=1, day=1)
    assert r.end == today
    assert "YTD" in r.label


def test_parse_period_iso_range():
    from app.services.copilot_tools_ledger import parse_period
    r = parse_period("2026-01-15:2026-02-20")
    assert r.start == date(2026, 1, 15)
    assert r.end == date(2026, 2, 20)


def test_parse_period_invalid_fallback_to_this_month():
    """An unparseable input returns this_month, not an exception."""
    from app.services.copilot_tools_ledger import parse_period
    r = parse_period("gibberish!")
    today = date.today()
    assert r.start == today.replace(day=1)


# ── aggregate_metric ─────────────────────────────────────


def test_aggregate_metric_shape_on_empty_db():
    """When no data exists the legacy placeholder shape is preserved."""
    from app.services.copilot_tools_ledger import aggregate_metric
    r = aggregate_metric("total_revenue", "this_month")
    assert r["metric"] == "total_revenue"
    assert r["value"] == 0
    assert r["currency"] == "SAR"
    assert "breakdown" in r
    assert isinstance(r["breakdown"], list)


def test_aggregate_metric_unknown_metric():
    from app.services.copilot_tools_ledger import aggregate_metric
    r = aggregate_metric("not_a_real_metric", "this_month")
    assert r["value"] == 0
    assert "_note" in r


def test_aggregate_metric_mrr_burn_are_deferred():
    from app.services.copilot_tools_ledger import aggregate_metric
    for m in ("mrr", "burn_rate"):
        r = aggregate_metric(m, "this_month")
        assert r["value"] == 0
        assert "_note" in r


# ── lookup_entity ────────────────────────────────────────


def test_lookup_entity_empty_query():
    from app.services.copilot_tools_ledger import lookup_entity
    r = lookup_entity("client", "")
    assert r["entity_type"] == "client"
    assert r["matches"] == []


def test_lookup_entity_unknown_type_returns_empty():
    """Unknown entity types don't raise — return empty list."""
    from app.services.copilot_tools_ledger import lookup_entity
    r = lookup_entity("employee", "ahmad")
    assert r["matches"] == []


# ── get_report_summary ───────────────────────────────────


def test_get_report_summary_trial_balance():
    from app.services.copilot_tools_ledger import get_report_summary
    r = get_report_summary("trial_balance", "this_month")
    assert r["report_type"] == "trial_balance"
    # TB summary has six sections: revenue / expenses / net income / cash / AR / AP
    names = [s["name"] for s in r["sections"]]
    assert len(names) == 6


def test_get_report_summary_profit_and_loss():
    from app.services.copilot_tools_ledger import get_report_summary
    r = get_report_summary("profit_and_loss", "this_month")
    assert r["report_type"] == "profit_and_loss"
    names = [s["name"] for s in r["sections"]]
    assert any("إيرادات" in n or "Revenue" in n for n in names)


def test_get_report_summary_unknown_deferred():
    from app.services.copilot_tools_ledger import get_report_summary
    r = get_report_summary("cash_flow", "this_month")
    assert r["sections"] == []
    assert "_note" in r


# ── explain_variance ─────────────────────────────────────


def test_explain_variance_account_not_found():
    from app.services.copilot_tools_ledger import explain_variance
    r = explain_variance("ACCT_THAT_DOES_NOT_EXIST_9999", "last_month", "this_month")
    assert r["value_a"] == 0
    assert r["value_b"] == 0
    assert r["delta"] == 0
    assert "_note" in r


# ── forecast_metric ──────────────────────────────────────


def test_forecast_metric_shape():
    from app.services.copilot_tools_ledger import forecast_metric
    r = forecast_metric("total_revenue", 3)
    assert r["horizon_months"] == 3
    assert len(r["projected_values"]) == 3
    assert len(r["confidence_interval"]["low"]) == 3
    assert len(r["confidence_interval"]["high"]) == 3
    assert r["method"] == "moving_average"


def test_forecast_metric_horizon_clamped():
    """horizon > 24 should be clamped to 24, not explode."""
    from app.services.copilot_tools_ledger import forecast_metric
    r = forecast_metric("total_revenue", 100)
    assert r["horizon_months"] == 24
    assert len(r["projected_values"]) == 24


def test_forecast_metric_cash_balance_uses_current_plus_trend():
    from app.services.copilot_tools_ledger import forecast_metric
    r = forecast_metric("cash_balance", 2)
    assert r["metric"] == "cash_balance"
    assert len(r["projected_values"]) == 2
