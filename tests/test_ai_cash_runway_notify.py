"""APEX Platform -- app/ai/proactive.py cash_runway_warning notification block tests.

Coverage target: cover lines 262-265 (severity dispatch) + 269-299
(notification dispatch block) of `cash_runway_warning`. These are the
DB-integration / async-dispatch paths that G-T1.7a deliberately left
uncovered (G-T1.7a.1, Sprint 11).

Existing tests (G-T1.7a) cover the early-return guards (no signal,
growing balance, safe runway). Here we drive the function INTO the
warning + error severity zones and verify:

  1. The notification block fires (notify called with the right kwargs).
  2. Severity is "warning" when 7 < runway <= 30 days.
  3. Severity is "error" when runway <= 7 days.
  4. Notification dispatch failure is silently swallowed (best-effort
     contract — caller must never see the warning vanish because of
     a notification-bridge problem).

Mock strategy:
  * `aggregate_metric` + `forecast_metric` monkeypatched on
    `app.services.copilot_tools_ledger` to drive runway into the target
    zone (current_balance + projected[-1] determine runway).
  * `app.core.notifications_bridge.notify` (async) replaced via
    `sys.modules` stub that captures invocations. The function uses
    `asyncio.new_event_loop().run_until_complete(_push())` internally,
    so a real coroutine is awaited; our stub returns a coroutine.
"""

from __future__ import annotations

import sys
import types

import pytest


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def ledger_mock(monkeypatch):
    """Monkeypatch `app.services.copilot_tools_ledger` helpers."""
    import app.services.copilot_tools_ledger as ledger

    state = {"current": 100_000, "projected": [100_000] * 6}

    def aggregate(metric, period, *, tenant_id=None):
        return {"value": state["current"]}

    def forecast(metric, *, horizon_months=6, tenant_id=None):
        return {"projected_values": state["projected"]}

    monkeypatch.setattr(ledger, "aggregate_metric", aggregate)
    monkeypatch.setattr(ledger, "forecast_metric", forecast)
    return state


@pytest.fixture
def notify_capture(monkeypatch):
    """Replace `app.core.notifications_bridge.notify` with a capturing
    async stub. The real function returns a coroutine that the
    cash_runway_warning code awaits via run_until_complete."""
    captured = {"calls": []}

    async def fake_notify(**kwargs):
        captured["calls"].append(kwargs)
        return {"persisted": False, "websocket_delivered": 0}

    stub = types.ModuleType("app.core.notifications_bridge")
    stub.notify = fake_notify
    monkeypatch.setitem(sys.modules, "app.core.notifications_bridge", stub)
    return captured


# ══════════════════════════════════════════════════════════════
# Tests
# ══════════════════════════════════════════════════════════════


class TestCashRunwayNotify:
    def test_warning_severity_triggers_notification(
        self, ledger_mock, notify_capture
    ):
        """Runway between 7 and 30 days → severity='warning' + notify fires."""
        from app.ai import proactive as p

        # current=10_000, projected ending=0 over 6 months
        # → total_burn = 10_000, monthly_burn = ~1666, runway = (10_000/1666)*30 = 180 days
        # Need a tighter ratio: try smaller current + larger burn.
        # current=1000, projected ending=0 → burn 1000/6 = 166.67/mo
        # → runway = (1000/166.67)*30 = ~180 days (still too high)
        #
        # Try: current=600, projected ending=0 over 6 months
        # → total_burn = 600, monthly_burn = 100/mo
        # → runway = (600/100)*30 = 180 days (still high)
        #
        # The runway formula: (current_balance / monthly_burn) * 30
        # To land in (7, 30] days we need monthly_burn high relative to current.
        # current=1000, monthly_burn=2000 → runway = (1000/2000)*30 = 15 days ✓
        # That means total_burn over horizon_months=6 must equal 12_000.
        # If current=1000 and projected_values[-1]=-11_000 → burn=12_000 ✓
        ledger_mock["current"] = 1000
        ledger_mock["projected"] = [800, 600, 400, 200, 0, -11_000]

        result = p.cash_runway_warning(min_runway_days=30)
        assert len(result) == 1
        finding = result[0]
        assert finding.severity == "warning"
        assert "مدى السيولة المتوقع" in finding.summary

        # Notification fired.
        assert len(notify_capture["calls"]) == 1
        call = notify_capture["calls"][0]
        assert call["kind"] == "cash_runway"
        assert call["severity"] == "warning"
        assert call["entity_type"] == "cash_forecast"
        assert "تحذير: انخفاض" in call["title"]

    def test_error_severity_triggers_notification(
        self, ledger_mock, notify_capture
    ):
        """Runway <= 7 days → severity='error' + notify fires."""
        from app.ai import proactive as p

        # Need monthly_burn × 7 / 30 >= current_balance:
        # current=300, total_burn over 6 months = 12_000 → monthly_burn = 2000
        # runway = (300/2000)*30 = 4.5 days ✓
        ledger_mock["current"] = 300
        ledger_mock["projected"] = [200, 100, 0, -3000, -7000, -11_700]

        result = p.cash_runway_warning(min_runway_days=30)
        assert len(result) == 1
        finding = result[0]
        assert finding.severity == "error"

        # Notification fired with error severity.
        assert len(notify_capture["calls"]) == 1
        assert notify_capture["calls"][0]["severity"] == "error"

    def test_notification_dispatch_failure_silently_swallowed(
        self, ledger_mock, monkeypatch
    ):
        """If notify() raises during dispatch, the warning still emits;
        the failure is best-effort logged + swallowed (lines 296-297)."""
        from app.ai import proactive as p

        async def bad_notify(**kwargs):
            raise RuntimeError("notification bridge offline")

        stub = types.ModuleType("app.core.notifications_bridge")
        stub.notify = bad_notify
        monkeypatch.setitem(sys.modules, "app.core.notifications_bridge", stub)

        # Drive into warning severity zone.
        ledger_mock["current"] = 1000
        ledger_mock["projected"] = [800, 600, 400, 200, 0, -11_000]

        # Must NOT raise — notification failure is non-fatal.
        result = p.cash_runway_warning(min_runway_days=30)
        # Finding still emitted despite notification failure.
        assert len(result) == 1
        assert result[0].severity == "warning"

    def test_tenant_id_propagated_into_notify_payload(
        self, ledger_mock, notify_capture
    ):
        """tenant_id arg flows into the notify call (entity_id derives
        from `cash-runway-{date.today()}`, not tenant)."""
        from app.ai import proactive as p

        ledger_mock["current"] = 1000
        ledger_mock["projected"] = [800, 600, 400, 200, 0, -11_000]

        p.cash_runway_warning(min_runway_days=30, tenant_id="tenant-test-1")
        assert notify_capture["calls"][0]["tenant_id"] == "tenant-test-1"
        # user_id falls through to tenant_id when set.
        assert notify_capture["calls"][0]["user_id"] == "tenant-test-1"
