"""APEX Platform -- app/core/cashflow_forecast.py unit tests.

Coverage target: ≥85% of 132 statements (G-T1.7b.2, Sprint 10).

Pure-algorithmic logic + DB-fetch (GLPosting/GLAccount). We exercise:

  * Pure helpers: `_week_start`, `_linear_regression`, `_stdev_or_zero`.
  * Dataclasses' `to_dict` round-trip (`WeeklyCashflow`, `ProjectedWeek`).
  * `project_forward` — empty-history short-circuit + happy path with
    a synthetic series.
  * `forecast_cashflow` — bound validation (weeks, history_weeks),
    no-history warning path, low-data-warning path, and a happy-path
    integration with `get_historical_series` mocked to return a series.
  * `is_available` — both branches (success, GL-models-missing).
  * `get_historical_series` — import-fallback path only (DB happy
    path needs seeded GLPosting which is out-of-scope per G-T1.7b.1
    rule "no DB writes").
"""

from __future__ import annotations

import builtins
import sys
from datetime import date, timedelta

import pytest

from app.core import cashflow_forecast as cf


# ══════════════════════════════════════════════════════════════
# Pure helpers
# ══════════════════════════════════════════════════════════════


class TestPureHelpers:
    def test_week_start_monday_anchored(self):
        # 2026-05-02 is a Saturday → Monday is 2026-04-27.
        assert cf._week_start(date(2026, 5, 2)) == date(2026, 4, 27)
        # Monday → returns same day.
        assert cf._week_start(date(2026, 4, 27)) == date(2026, 4, 27)
        # Sunday (next week) → previous Monday.
        assert cf._week_start(date(2026, 5, 3)) == date(2026, 4, 27)

    def test_linear_regression_single_point_returns_zero_slope(self):
        slope, intercept = cf._linear_regression([0.0], [42.0])
        assert slope == 0.0
        assert intercept == 42.0

    def test_linear_regression_empty_lists(self):
        slope, intercept = cf._linear_regression([], [])
        assert slope == 0.0
        assert intercept == 0.0

    def test_linear_regression_perfect_line(self):
        # y = 2x + 1
        xs = [0.0, 1.0, 2.0, 3.0, 4.0]
        ys = [1.0, 3.0, 5.0, 7.0, 9.0]
        slope, intercept = cf._linear_regression(xs, ys)
        assert abs(slope - 2.0) < 1e-9
        assert abs(intercept - 1.0) < 1e-9

    def test_linear_regression_zero_variance_x(self):
        # All xs equal → den=0 → slope falls back to 0.
        slope, intercept = cf._linear_regression([3.0, 3.0, 3.0], [1.0, 2.0, 3.0])
        assert slope == 0.0

    def test_stdev_or_zero_empty(self):
        assert cf._stdev_or_zero([]) == 0.0

    def test_stdev_or_zero_single_value(self):
        assert cf._stdev_or_zero([5.0]) == 0.0

    def test_stdev_or_zero_normal_case(self):
        # stdev of [2, 4, 4, 4, 5, 5, 7, 9] is 2.0.
        result = cf._stdev_or_zero([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])
        assert abs(result - 2.138) < 0.01  # population stdev approx


# ══════════════════════════════════════════════════════════════
# Dataclass to_dict round-trip
# ══════════════════════════════════════════════════════════════


class TestDataclassSerialization:
    def test_weekly_cashflow_to_dict_rounds_to_two_decimals(self):
        w = cf.WeeklyCashflow(
            week_starting=date(2026, 4, 27),
            inflow=1000.123,
            outflow=400.456,
            net=599.667,
        )
        d = w.to_dict()
        assert d["week_starting"] == "2026-04-27"
        assert d["inflow"] == 1000.12
        assert d["outflow"] == 400.46
        assert d["net"] == 599.67

    def test_projected_week_to_dict(self):
        p = cf.ProjectedWeek(
            week_starting=date(2026, 5, 4),
            projected_net=500.0,
            lower_bound=300.0,
            upper_bound=700.0,
            cumulative_balance=10500.0,
        )
        d = p.to_dict()
        assert d == {
            "week_starting": "2026-05-04",
            "projected_net": 500.0,
            "lower_bound": 300.0,
            "upper_bound": 700.0,
            "cumulative_balance": 10500.0,
        }


# ══════════════════════════════════════════════════════════════
# project_forward — projection algorithm
# ══════════════════════════════════════════════════════════════


class TestProjectForward:
    def test_empty_history_returns_flat_zero_projection(self):
        out = cf.project_forward([], weeks=3, starting_balance=1000.0)
        assert len(out) == 3
        for p in out:
            assert p.projected_net == 0.0
            assert p.lower_bound == 0.0
            assert p.upper_bound == 0.0
            assert p.cumulative_balance == 1000.0  # carried unchanged

    def test_increasing_trend_projects_higher_each_week(self):
        # 4-week history with steady +100 trend.
        history = [
            cf.WeeklyCashflow(date(2026, 4, 6), 200, 100, 100),
            cf.WeeklyCashflow(date(2026, 4, 13), 300, 100, 200),
            cf.WeeklyCashflow(date(2026, 4, 20), 400, 100, 300),
            cf.WeeklyCashflow(date(2026, 4, 27), 500, 100, 400),
        ]
        out = cf.project_forward(history, weeks=2, starting_balance=10000.0)
        assert len(out) == 2
        # Slope is +100/week; week 5 of timeline (i=1) projects 500.
        assert out[0].projected_net > 400  # higher than last historical
        assert out[1].projected_net > out[0].projected_net  # monotone up
        # Confidence band widens with horizon.
        band_0 = out[0].upper_bound - out[0].lower_bound
        band_1 = out[1].upper_bound - out[1].lower_bound
        assert band_1 >= band_0
        # Cumulative grows from starting_balance.
        assert out[0].cumulative_balance > 10000.0
        # week_starting is one Monday after the last historical week.
        assert out[0].week_starting == date(2026, 5, 4)
        assert out[1].week_starting == date(2026, 5, 11)


# ══════════════════════════════════════════════════════════════
# forecast_cashflow — top-level API
# ══════════════════════════════════════════════════════════════


class TestForecastCashflow:
    def test_invalid_weeks_returns_error(self):
        assert cf.forecast_cashflow("t1", weeks=0) == {"ok": False, "error": "weeks must be 1..52"}
        assert cf.forecast_cashflow("t1", weeks=53)["ok"] is False

    def test_invalid_history_weeks_returns_error(self):
        out = cf.forecast_cashflow("t1", weeks=4, history_weeks=3)
        assert out == {"ok": False, "error": "history_weeks must be 4..104"}
        assert cf.forecast_cashflow("t1", weeks=4, history_weeks=200)["ok"] is False

    def test_no_history_yields_warning_and_flat_projection(self, monkeypatch):
        monkeypatch.setattr(cf, "get_historical_series", lambda *a, **kw: [])
        out = cf.forecast_cashflow("t1", weeks=3, starting_balance=500.0)
        assert out["ok"] is True
        assert out["history"] == []
        assert len(out["projection"]) == 3
        # No-history warning surfaces.
        assert any("No GL postings" in w for w in out["warnings"])
        # Flat projection → projected_net == 0 for each week.
        for p in out["projection"]:
            assert p["projected_net"] == 0.0

    def test_low_data_warning_when_history_short(self, monkeypatch):
        # Only 2 weeks for a 12-week request → low-confidence warning.
        history = [
            cf.WeeklyCashflow(date(2026, 4, 20), 100, 50, 50),
            cf.WeeklyCashflow(date(2026, 4, 27), 200, 100, 100),
        ]
        monkeypatch.setattr(cf, "get_historical_series", lambda *a, **kw: history)
        out = cf.forecast_cashflow("t1", weeks=2, history_weeks=12)
        assert out["ok"] is True
        assert any("low-confidence forecast" in w for w in out["warnings"])

    def test_full_path_with_synthetic_history(self, monkeypatch):
        history = [
            cf.WeeklyCashflow(date(2026, 4, 6), 200, 100, 100),
            cf.WeeklyCashflow(date(2026, 4, 13), 300, 100, 200),
            cf.WeeklyCashflow(date(2026, 4, 20), 400, 100, 300),
            cf.WeeklyCashflow(date(2026, 4, 27), 500, 100, 400),
        ]
        monkeypatch.setattr(cf, "get_historical_series", lambda *a, **kw: history)
        out = cf.forecast_cashflow("t1", weeks=2, history_weeks=4, starting_balance=1000.0)
        assert out["ok"] is True
        assert out["method"] == "linear_regression_v1"
        assert len(out["history"]) == 4
        assert len(out["projection"]) == 2
        # Summary fields populated.
        s = out["summary"]
        assert s["history_weeks"] == 4
        assert s["avg_weekly_net"] == 250.0  # (100+200+300+400)/4
        assert s["trend_per_week"] == 100.0  # perfect +100 trend
        assert s["stdev"] > 0  # non-degenerate
        assert s["starting_balance"] == 1000.0
        assert s["horizon_weeks"] == 2
        assert s["ending_projected_balance"] > 1000.0  # net positive


# ══════════════════════════════════════════════════════════════
# get_historical_series — import-fallback only (DB-write rule)
# ══════════════════════════════════════════════════════════════


class TestGetHistoricalSeries:
    def test_returns_empty_when_gl_models_unavailable(self, monkeypatch):
        """Forces the inner `from app.pilot.models.gl import ...` to fail."""
        real_import = builtins.__import__

        def boom(name, *args, **kwargs):
            if name == "app.pilot.models.gl":
                raise ImportError("gl models offline")
            return real_import(name, *args, **kwargs)

        monkeypatch.setattr(builtins, "__import__", boom)
        out = cf.get_historical_series("t1", "e1", history_weeks=4)
        assert out == []

    def test_no_cash_accounts_returns_empty_series(self, monkeypatch):
        """Mock SessionLocal to simulate a tenant with no cash/bank GL accounts."""
        from unittest.mock import MagicMock

        fake_session = MagicMock()
        # cash_account_ids_q.all() → empty list
        fake_session.query.return_value.filter.return_value.all.return_value = []
        # entity_id branch chains another .filter()
        (
            fake_session.query.return_value.filter.return_value
            .filter.return_value.all.return_value
        ) = []
        monkeypatch.setattr(cf, "SessionLocal", lambda: fake_session)

        out = cf.get_historical_series("t1", "e1", history_weeks=4)
        assert out == []
        fake_session.close.assert_called_once()

    def test_with_postings_buckets_by_week_and_fills_zeros(self, monkeypatch):
        """Mock SessionLocal to simulate a tenant with 2 cash accounts and
        2 weeks of postings — verifies bucketing and zero-fill."""
        from unittest.mock import MagicMock

        # Build a fake row for postings (debit=inflow, credit=outflow).
        wk1 = date.today() - timedelta(weeks=2)
        wk2 = date.today() - timedelta(weeks=1)
        posting_rows = [
            MagicMock(posting_date=wk1, debit=500, credit=200),
            MagicMock(posting_date=wk2, debit=1000, credit=400),
        ]

        fake_session = MagicMock()
        # Layer 1 — cash_account_ids_q.all() returns 2 (id,) tuples.
        cash_q = MagicMock()
        cash_q.all.return_value = [("acc-1",), ("acc-2",)]
        # First db.query(...).filter(...) returns cash_q.
        # Second db.query(...).filter().filter().group_by().all() returns posting_rows.
        postings_chain = MagicMock()
        postings_chain.filter.return_value = postings_chain
        postings_chain.group_by.return_value = postings_chain
        postings_chain.all.return_value = posting_rows
        # cash_q itself supports .filter() for the entity_id chain.
        cash_q.filter.return_value = cash_q

        # Side-effect-style: alternate between the two query types.
        fake_session.query.side_effect = [
            # First call: cash account query.
            MagicMock(filter=MagicMock(return_value=cash_q)),
            # Second call: GLPosting query — returns a chainable mock.
            postings_chain,
        ]
        monkeypatch.setattr(cf, "SessionLocal", lambda: fake_session)

        out = cf.get_historical_series("t1", entity_id=None, history_weeks=4)
        assert isinstance(out, list)
        assert len(out) >= 4  # zero-fill ensures >=4 weeks
        # Each row is a WeeklyCashflow.
        for w in out:
            assert isinstance(w, cf.WeeklyCashflow)
            assert w.net == w.inflow - w.outflow


# ══════════════════════════════════════════════════════════════
# is_available — health check
# ══════════════════════════════════════════════════════════════


class TestIsAvailable:
    def test_returns_false_when_gl_import_fails(self, monkeypatch):
        real_import = builtins.__import__

        def boom(name, *args, **kwargs):
            if name == "app.pilot.models.gl":
                raise ImportError("gl models offline")
            return real_import(name, *args, **kwargs)

        monkeypatch.setattr(builtins, "__import__", boom)
        assert cf.is_available() is False

    def test_returns_false_when_db_session_fails(self, monkeypatch):
        # GL import succeeds, but SessionLocal() raises.
        def fail_session():
            raise RuntimeError("DB unavailable")

        monkeypatch.setattr(cf, "SessionLocal", fail_session)
        assert cf.is_available() is False
