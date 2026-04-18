"""Tests for the proactive AI scheduler loop."""

from __future__ import annotations

import asyncio
import os

import pytest


@pytest.fixture(autouse=True)
def _reset_scheduler_state():
    """Ensure no scheduler task leaks between tests."""
    import app.ai.scheduler as sched
    sched._task = None
    yield
    if sched._task is not None and not sched._task.done():
        sched._task.cancel()
    sched._task = None


def test_scheduler_disabled_by_default(monkeypatch):
    """With PROACTIVE_AI_ENABLED unset, start returns False and does
    not schedule a task."""
    from app.ai.scheduler import start_proactive_scheduler
    monkeypatch.delenv("PROACTIVE_AI_ENABLED", raising=False)
    result = start_proactive_scheduler()
    assert result is False


def test_scheduler_enabled_schedules_task(monkeypatch):
    """When enabled, the loop gets a task."""
    from app.ai import scheduler as sched

    monkeypatch.setenv("PROACTIVE_AI_ENABLED", "true")

    async def _run():
        result = sched.start_proactive_scheduler()
        assert result is True
        assert sched._task is not None
        assert not sched._task.done()
        # Stop it before we leave — we don't want the real loop to run.
        await sched.stop_proactive_scheduler()

    asyncio.run(_run())


def test_scheduler_respects_warmup_and_does_not_scan_immediately(monkeypatch):
    """Warmup should delay the first scan so startup can complete."""
    from app.ai import scheduler as sched

    scans: list = []

    def fake_scan(**kwargs):
        scans.append(kwargs)
        return {"total_findings": 0, "scans_run": 0,
                "by_severity": {}, "by_scan": {}, "findings": []}

    monkeypatch.setenv("PROACTIVE_AI_ENABLED", "true")
    monkeypatch.setenv("AI_SCAN_WARMUP_SECONDS", "3600")  # 1h warmup
    # Import proactive lazily — the scheduler does it inside _loop()
    import app.ai.proactive as proactive
    monkeypatch.setattr(proactive, "run_all_scans", fake_scan)

    async def _run():
        sched.start_proactive_scheduler()
        # Wait a short moment — nowhere near the 1h warmup, so no scan
        # should fire.
        await asyncio.sleep(0.1)
        await sched.stop_proactive_scheduler()

    asyncio.run(_run())
    assert scans == []


def test_scheduler_runs_scan_after_zero_warmup(monkeypatch):
    """Setting warmup=0 + interval=0 should cause at least one scan
    before we cancel."""
    from app.ai import scheduler as sched
    import app.ai.proactive as proactive

    scans: list = []

    def fake_scan(**kwargs):
        scans.append(kwargs)
        return {"total_findings": 0, "scans_run": 0,
                "by_severity": {}, "by_scan": {}, "findings": []}

    monkeypatch.setenv("PROACTIVE_AI_ENABLED", "true")
    monkeypatch.setenv("AI_SCAN_WARMUP_SECONDS", "0")
    # Interval is clamped to 60 internally — we just need the first
    # scan to fire before the second sleep starts.
    monkeypatch.setattr(proactive, "run_all_scans", fake_scan)

    async def _run():
        sched.start_proactive_scheduler()
        # Give the task a few event-loop ticks to start + run one scan.
        for _ in range(50):
            await asyncio.sleep(0.01)
            if scans:
                break
        await sched.stop_proactive_scheduler()

    asyncio.run(_run())
    assert len(scans) >= 1


def test_start_is_idempotent_second_call_returns_existing(monkeypatch):
    from app.ai import scheduler as sched

    monkeypatch.setenv("PROACTIVE_AI_ENABLED", "true")

    async def _run():
        first = sched.start_proactive_scheduler()
        second = sched.start_proactive_scheduler()
        assert first is True
        assert second is True
        assert sched._task is not None
        await sched.stop_proactive_scheduler()

    asyncio.run(_run())


def test_interval_respects_minimum_floor(monkeypatch):
    """Even if someone sets AI_SCAN_INTERVAL_SECONDS=5, we clamp to 60."""
    from app.ai import scheduler as sched
    monkeypatch.setenv("AI_SCAN_INTERVAL_SECONDS", "5")
    assert sched._interval_seconds() == 60


def test_bad_env_value_falls_back_to_default(monkeypatch):
    from app.ai import scheduler as sched
    monkeypatch.setenv("AI_SCAN_INTERVAL_SECONDS", "not-a-number")
    assert sched._interval_seconds() == sched._DEFAULT_INTERVAL
