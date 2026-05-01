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


# ── Approved-suggestion drain (G-T1.7a additions) ─────────


@pytest.fixture(autouse=True)
def _reset_drain_state():
    """Ensure no drain task leaks between tests (mirror of scheduler reset)."""
    import app.ai.scheduler as sched
    sched._drain_task = None
    yield
    if sched._drain_task is not None and not sched._drain_task.done():
        sched._drain_task.cancel()
    sched._drain_task = None


def test_drain_disabled_by_default(monkeypatch):
    """With AI_DRAIN_APPROVED_ENABLED unset, _drain_enabled() is False
    and start_drain_scheduler() returns False."""
    from app.ai.scheduler import start_drain_scheduler, _drain_enabled
    monkeypatch.delenv("AI_DRAIN_APPROVED_ENABLED", raising=False)
    assert _drain_enabled() is False
    assert start_drain_scheduler() is False


def test_drain_interval_floor(monkeypatch):
    """Even if AI_DRAIN_APPROVED_INTERVAL_SECONDS=5, we clamp to a 30s floor."""
    from app.ai import scheduler as sched
    monkeypatch.setenv("AI_DRAIN_APPROVED_INTERVAL_SECONDS", "5")
    assert sched._drain_interval_seconds() == 30


def test_drain_bad_env_falls_back_to_default(monkeypatch):
    """ValueError on parse → returns _DEFAULT_DRAIN_INTERVAL."""
    from app.ai import scheduler as sched
    monkeypatch.setenv("AI_DRAIN_APPROVED_INTERVAL_SECONDS", "not-a-number")
    assert sched._drain_interval_seconds() == sched._DEFAULT_DRAIN_INTERVAL


def test_drain_enabled_schedules_task(monkeypatch):
    """When AI_DRAIN_APPROVED_ENABLED=true, start schedules a drain task."""
    from app.ai import scheduler as sched

    monkeypatch.setenv("AI_DRAIN_APPROVED_ENABLED", "true")

    async def _run():
        result = sched.start_drain_scheduler()
        assert result is True
        assert sched._drain_task is not None
        assert not sched._drain_task.done()
        await sched.stop_drain_scheduler()

    asyncio.run(_run())


def test_drain_start_is_idempotent(monkeypatch):
    """Calling start_drain_scheduler twice returns True both times
    and reuses the same task."""
    from app.ai import scheduler as sched

    monkeypatch.setenv("AI_DRAIN_APPROVED_ENABLED", "true")

    async def _run():
        first = sched.start_drain_scheduler()
        task_after_first = sched._drain_task
        second = sched.start_drain_scheduler()
        assert first is True
        assert second is True
        # Same task is preserved on the second call (no new task created).
        assert sched._drain_task is task_after_first
        await sched.stop_drain_scheduler()

    asyncio.run(_run())


def test_drain_stop_when_no_task_is_noop():
    """stop_drain_scheduler() must not raise when _drain_task is None."""
    import app.ai.scheduler as sched
    sched._drain_task = None
    # Should complete cleanly without raising.
    asyncio.run(sched.stop_drain_scheduler())
    assert sched._drain_task is None


def test_drain_runs_at_least_once_with_zero_warmup(monkeypatch):
    """Setting warmup=0 should let the drain fire its first iteration."""
    from app.ai import scheduler as sched
    import app.ai.approval_executor as exec_mod

    drains: list = []

    def fake_drain(limit=50):
        drains.append(limit)
        return {"considered": 0, "executed": 0, "failed": 0}

    monkeypatch.setenv("AI_DRAIN_APPROVED_ENABLED", "true")
    monkeypatch.setenv("AI_SCAN_WARMUP_SECONDS", "0")
    monkeypatch.setattr(exec_mod, "execute_all_approved", fake_drain)

    async def _run():
        sched.start_drain_scheduler()
        for _ in range(50):
            await asyncio.sleep(0.01)
            if drains:
                break
        await sched.stop_drain_scheduler()

    asyncio.run(_run())
    assert len(drains) >= 1
