"""APEX Platform -- app/core/notifications_bridge.py unit tests.

Coverage target: ≥95% of 39 statements (G-T1.7b.5, Sprint 10 final).

Async notification dispatcher: persists to Phase 10 DB + pushes via
WebSocket. We exercise:

  * `notify` — full happy path (persist + ws push), Phase 10 import
    failure (silent), Phase 10 commit failure (rollback path), WS
    push failure (silent), generic Phase 10 exception.
  * `notify_sync` — no-loop branch (asyncio.run) and running-loop
    branch (task scheduled, partial result returned).

Mock strategy: monkeypatch `app.phase10.models.phase10_models` and
`app.core.websocket_hub.publish_to_user` via `sys.modules` stubs.
Coroutines invoked via `asyncio.run()` directly (no pytest-asyncio
dependency).
"""

from __future__ import annotations

import asyncio
import sys
import types
from unittest.mock import MagicMock

import pytest

from app.core import notifications_bridge as nb


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def phase10_stub(monkeypatch):
    """Install a stub `app.phase10.models.phase10_models`."""
    stub = types.ModuleType("app.phase10.models.phase10_models")
    sess = MagicMock()
    sess.commit = MagicMock()
    sess.rollback = MagicMock()
    sess.close = MagicMock()
    sess.add = MagicMock()
    SessionLocal = MagicMock(return_value=sess)
    stub.Notification = lambda **kw: MagicMock(**kw)
    stub.SessionLocal = SessionLocal
    stub._sess = sess  # for assertions
    stub._SessionLocal = SessionLocal
    monkeypatch.setitem(sys.modules, "app.phase10.models.phase10_models", stub)
    return stub


@pytest.fixture
def ws_stub(monkeypatch):
    """Install a stub `app.core.websocket_hub.publish_to_user`."""
    stub = types.ModuleType("app.core.websocket_hub")
    calls = []

    async def fake_publish(user_id, payload):
        calls.append({"user_id": user_id, "payload": payload})
        return 2  # 2 sockets received

    stub.publish_to_user = fake_publish
    stub._calls = calls
    monkeypatch.setitem(sys.modules, "app.core.websocket_hub", stub)
    return stub


def _run(coro):
    """Drive a coroutine to completion via asyncio.run."""
    return asyncio.run(coro)


# ══════════════════════════════════════════════════════════════
# notify (async) — driven via asyncio.run
# ══════════════════════════════════════════════════════════════


class TestNotify:
    def test_full_happy_path_persists_and_publishes(
        self, phase10_stub, ws_stub
    ):
        out = _run(nb.notify(
            user_id="u-1",
            kind="invoice_paid",
            title="paid",
            body="invoice paid",
            entity_type="invoice",
            entity_id="i-1",
        ))
        assert out == {"persisted": True, "websocket_delivered": 2}
        # Phase 10 commit called.
        phase10_stub._sess.commit.assert_called_once()
        phase10_stub._sess.add.assert_called_once()
        phase10_stub._sess.close.assert_called_once()
        # WS push called once with the right payload shape.
        assert len(ws_stub._calls) == 1
        call = ws_stub._calls[0]
        assert call["user_id"] == "u-1"
        assert call["payload"]["type"] == "notification"
        assert call["payload"]["kind"] == "invoice_paid"

    def test_phase10_import_failure_silently_skipped(
        self, ws_stub, monkeypatch
    ):
        # Force the inner phase10 import to raise ImportError.
        monkeypatch.setitem(
            sys.modules, "app.phase10.models.phase10_models", None
        )
        out = _run(nb.notify(
            user_id="u-1", kind="x", title="t", body="b",
        ))
        assert out["persisted"] is False
        # WS push still ran.
        assert out["websocket_delivered"] == 2

    def test_phase10_commit_failure_rolls_back(
        self, phase10_stub, ws_stub
    ):
        phase10_stub._sess.commit.side_effect = RuntimeError("DB locked")
        out = _run(nb.notify(
            user_id="u-1", kind="x", title="t", body="b",
        ))
        assert out["persisted"] is False
        # rollback + close still called.
        phase10_stub._sess.rollback.assert_called_once()
        phase10_stub._sess.close.assert_called_once()
        # WS push still ran.
        assert out["websocket_delivered"] == 2

    def test_phase10_generic_exception_silently_skipped(
        self, phase10_stub, ws_stub, monkeypatch
    ):
        # Make the phase10 import succeed but SessionLocal() blow up before commit.
        def boom_session():
            raise RuntimeError("Phase 10 broken")

        phase10_stub._SessionLocal.side_effect = boom_session
        out = _run(nb.notify(user_id="u-1", kind="x", title="t", body="b"))
        assert out["persisted"] is False
        # WS push still ran.
        assert out["websocket_delivered"] == 2

    def test_websocket_failure_silently_swallowed(
        self, phase10_stub, monkeypatch
    ):
        # Stub WS that raises.
        stub = types.ModuleType("app.core.websocket_hub")

        async def boom(*a, **kw):
            raise RuntimeError("ws hub down")

        stub.publish_to_user = boom
        monkeypatch.setitem(sys.modules, "app.core.websocket_hub", stub)
        out = _run(nb.notify(user_id="u-1", kind="x", title="t", body="b"))
        # Persisted but ws not delivered.
        assert out["persisted"] is True
        assert out["websocket_delivered"] == 0


# ══════════════════════════════════════════════════════════════
# notify_sync — sync wrapper for non-async callers
# ══════════════════════════════════════════════════════════════


class TestNotifySync:
    def test_no_running_loop_runs_to_completion(
        self, phase10_stub, ws_stub
    ):
        """When no loop exists, asyncio.run drives the coroutine to completion."""
        out = nb.notify_sync(
            user_id="u-1", kind="x", title="t", body="b",
        )
        # asyncio.run path → returns the actual notify() result.
        assert out["persisted"] is True
        assert out["websocket_delivered"] == 2

    def test_running_loop_schedules_task_and_returns_partial(
        self, phase10_stub, ws_stub
    ):
        """When a loop is already running, schedule the coroutine and
        return a partial result indicating the task is scheduled."""
        async def _runner():
            return nb.notify_sync(
                user_id="u-1", kind="x", title="t", body="b",
            )

        out = asyncio.run(_runner())
        assert out["_task_scheduled"] is True
        # Per the function contract: persisted=False + ws_delivered=0
        # since the task hasn't necessarily completed yet.
        assert out["persisted"] is False
        assert out["websocket_delivered"] == 0
