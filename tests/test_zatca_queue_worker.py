"""
Tests for app/core/zatca_queue_worker.py (Wave 9).

Covers:
- ZATCA_WORKER_ENABLED flag semantics (disabled by default).
- run_once() calls process_due with the injected submit_fn.
- start()/stop() lifecycle on the asyncio task.
- Graceful cancellation — no hang on shutdown.
- The default noop submit_fn never raises.
"""

from __future__ import annotations

import asyncio
from unittest.mock import patch

import pytest

from app.core import zatca_queue_worker as w
from app.core import zatca_retry_queue as q
from app.core.zatca_retry_queue import SubmissionResult
from app.core.compliance_models import AuditTrail, ZatcaSubmissionQueue
from app.phase1.models.platform_models import SessionLocal


@pytest.fixture(autouse=True)
def _reset_queue():
    db = SessionLocal()
    try:
        db.query(ZatcaSubmissionQueue).delete()
        db.query(AuditTrail).delete()
        db.commit()
    finally:
        db.close()
    yield


# ── Flag handling ─────────────────────────────────────────────────────


class TestEnabled:
    def test_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("ZATCA_WORKER_ENABLED", raising=False)
        worker = w.ZatcaQueueWorker()
        assert worker._enabled is False

    @pytest.mark.parametrize("raw", ["1", "true", "TRUE", "yes", "on"])
    def test_enabled_values(self, monkeypatch, raw):
        monkeypatch.setenv("ZATCA_WORKER_ENABLED", raw)
        worker = w.ZatcaQueueWorker()
        assert worker._enabled is True

    def test_constructor_override_beats_env(self, monkeypatch):
        monkeypatch.delenv("ZATCA_WORKER_ENABLED", raising=False)
        worker = w.ZatcaQueueWorker(enabled=True)
        assert worker._enabled is True

    def test_interval_default_and_clamp(self, monkeypatch):
        monkeypatch.setenv("ZATCA_WORKER_INTERVAL_SECONDS", "3")
        assert w._default_interval_seconds() == 10  # clamped minimum
        monkeypatch.setenv("ZATCA_WORKER_INTERVAL_SECONDS", "120")
        assert w._default_interval_seconds() == 120

    def test_batch_limit_default_and_clamp(self, monkeypatch):
        monkeypatch.setenv("ZATCA_WORKER_BATCH_LIMIT", "0")
        assert w._default_batch_limit() == 1
        monkeypatch.setenv("ZATCA_WORKER_BATCH_LIMIT", "10000")
        assert w._default_batch_limit() == 500


# ── run_once() semantics ──────────────────────────────────────────────


def _run(coro):
    """Tiny wrapper so test bodies can stay readable."""
    return asyncio.new_event_loop().run_until_complete(coro)


class TestRunOnce:
    def test_runs_submit_fn_for_each_due_row(self):
        q.enqueue("INV-A", {"x": 1})
        q.enqueue("INV-B", {"x": 2})
        calls: list[str] = []

        def submit(row):
            calls.append(row["invoice_id"])
            return SubmissionResult(ok=True, cleared_uuid=f"UUID-{row['invoice_id']}")

        worker = w.ZatcaQueueWorker(submit_fn=submit, enabled=True)
        summary = _run(worker.run_once())
        assert summary["processed"] == 2
        assert summary["cleared"] == 2
        assert sorted(calls) == ["INV-A", "INV-B"]
        assert worker.iterations == 1
        assert worker.last_summary == summary

    def test_failure_reschedules_and_worker_tracks_summary(self):
        q.enqueue("INV-FAIL", {})

        def submit(_row):
            return SubmissionResult(
                ok=False, error_code="TIMEOUT", error_message="down"
            )

        worker = w.ZatcaQueueWorker(submit_fn=submit, enabled=True)
        summary = _run(worker.run_once())
        assert summary["pending"] + summary["giveup"] == 1
        assert worker.iterations == 1


# ── start/stop lifecycle ──────────────────────────────────────────────


class TestLifecycle:
    def test_disabled_start_is_noop(self):
        worker = w.ZatcaQueueWorker(enabled=False)
        _run(worker.start())
        assert worker.running is False

    def test_start_and_stop_cleanly(self):
        calls: list[int] = []

        def submit(_row):
            calls.append(1)
            return SubmissionResult(ok=True, cleared_uuid="x")

        q.enqueue("INV-LOOP", {})

        async def scenario():
            worker = w.ZatcaQueueWorker(
                submit_fn=submit, enabled=True, interval_seconds=10
            )
            await worker.start()
            assert worker.running is True
            # Let the first loop iteration fire run_once.
            for _ in range(40):
                if worker.iterations >= 1:
                    break
                await asyncio.sleep(0.05)
            await worker.stop()
            return worker

        worker = _run(scenario())
        assert worker.running is False
        assert worker.iterations >= 1

    def test_stop_without_start_is_noop(self):
        worker = w.ZatcaQueueWorker(enabled=True)
        _run(worker.stop())  # should not raise
        assert worker.running is False

    def test_second_start_while_running_is_noop(self):
        async def scenario():
            worker = w.ZatcaQueueWorker(enabled=True, interval_seconds=60)
            await worker.start()
            first_task = worker._task
            await worker.start()  # should not replace the task
            assert worker._task is first_task
            await worker.stop()

        _run(scenario())


class TestDefaultSubmit:
    def test_never_raises(self):
        r = w.default_noop_submit({"id": "x", "invoice_id": "y", "payload": {}})
        assert r.ok is False
        assert r.error_code == "NOOP"


class TestSingleton:
    def test_get_default_worker_is_stable(self):
        a = w.get_default_worker()
        b = w.get_default_worker()
        assert a is b
