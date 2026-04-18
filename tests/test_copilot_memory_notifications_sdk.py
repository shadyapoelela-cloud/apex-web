"""Tests for Copilot memory + notifications bridge + Python SDK."""

from __future__ import annotations

import uuid

import pytest


# ── Copilot memory: sessions ──────────────────────────────


def test_start_session_returns_id():
    from app.services.copilot_memory import start_session

    sid = start_session(user_id="u-test-1", title="جلسة اختبار")
    assert sid
    assert len(sid) == 36


def test_append_and_get_history():
    from app.services.copilot_memory import (
        append_message,
        get_session_history,
        start_session,
    )

    sid = start_session(user_id="u-test-2")
    append_message(sid, "user", "كم صرفنا على التسويق الشهر الماضي؟")
    append_message(sid, "assistant", "لم يتم صرف شيء هذا الشهر.")
    append_message(sid, "user", "وقبل ذلك؟")

    hist = get_session_history(sid)
    assert len(hist) == 3
    assert hist[0]["role"] == "user"
    assert hist[1]["role"] == "assistant"
    assert hist[-1]["content"] == "وقبل ذلك؟"


def test_list_recent_sessions_returns_most_recent_first():
    from app.services.copilot_memory import list_recent_sessions, start_session

    user = f"u-list-{uuid.uuid4().hex[:8]}"
    s1 = start_session(user_id=user, title="أولى")
    s2 = start_session(user_id=user, title="ثانية")

    listed = list_recent_sessions(user_id=user)
    assert len(listed) >= 2
    ids = [s["id"] for s in listed]
    assert s1 in ids and s2 in ids


# ── Copilot memory: facts ─────────────────────────────────


def test_remember_and_recall_by_keyword():
    from app.services.copilot_memory import recall_facts, remember_fact

    user = f"u-fact-{uuid.uuid4().hex[:8]}"
    remember_fact(
        content="المدير المالي يطلب تقارير ربع سنوية في ٥ من الشهر",
        user_id=user,
        tags=["cfo", "reporting"],
        importance=90,
    )
    remember_fact(
        content="قسم التسويق يتبع Google Ads",
        user_id=user,
        tags=["marketing"],
        importance=40,
    )

    results = recall_facts(query_text="ربع سنوية", user_id=user)
    assert any("ربع سنوية" in r["content"] for r in results)


def test_recall_by_embedding_cosine():
    from app.services.copilot_memory import recall_facts, remember_fact

    user = f"u-emb-{uuid.uuid4().hex[:8]}"
    # Fact A's embedding is "close" to query; fact B's is far.
    remember_fact(
        content="CFO quarterly reporting",
        user_id=user,
        embedding=[1.0, 0.0, 0.0, 0.0],
        importance=50,
    )
    remember_fact(
        content="Catering menu preferences",
        user_id=user,
        embedding=[0.0, 0.0, 0.0, 1.0],
        importance=50,
    )

    results = recall_facts(
        query_embedding=[0.95, 0.05, 0, 0],
        user_id=user,
        top_k=2,
    )
    assert len(results) >= 1
    assert "CFO" in results[0]["content"]


def test_forget_fact_removes_it():
    from app.services.copilot_memory import forget_fact, recall_facts, remember_fact

    user = f"u-forget-{uuid.uuid4().hex[:8]}"
    fid = remember_fact(
        content="نسخة قابلة للمسح",
        user_id=user,
        tags=["temporary"],
    )
    assert forget_fact(fid) is True
    listed = recall_facts(query_text="قابلة للمسح", user_id=user)
    assert all(r["id"] != fid for r in listed)


def test_forget_returns_false_for_unknown():
    from app.services.copilot_memory import forget_fact

    assert forget_fact("does-not-exist-id") is False


# ── Notifications bridge ──────────────────────────────────


@pytest.mark.anyio
async def test_notify_handles_missing_phase10_gracefully(monkeypatch):
    """If Phase 10 or WebSocket fails, notify() should still return a dict."""
    from app.core import notifications_bridge

    result = await notifications_bridge.notify(
        user_id="u-x",
        kind="test",
        title="t",
        body="b",
    )
    assert "persisted" in result
    assert "websocket_delivered" in result


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ── Python SDK ────────────────────────────────────────────


def test_sdk_cursor_page_from_body():
    from sdks.python.apex_sdk.client import CursorPage

    page = CursorPage.from_body({
        "data": [{"id": 1}, {"id": 2}],
        "next_cursor": "abc",
        "has_more": True,
        "limit": 25,
    })
    assert len(page.items) == 2
    assert page.next_cursor == "abc"
    assert page.has_more is True
    assert page.limit == 25


def test_sdk_cursor_page_handles_empty():
    from sdks.python.apex_sdk.client import CursorPage

    page = CursorPage.from_body({})
    assert page.items == []
    assert page.next_cursor is None
    assert page.has_more is False


def test_sdk_client_builds_headers_with_api_key():
    from sdks.python.apex_sdk.client import ApexClient

    c = ApexClient(base_url="https://x", api_key="key-123", tenant_id="t-9")
    h = c._headers()
    assert h["Authorization"] == "Bearer key-123"
    assert h["X-Tenant-Id"] == "t-9"
    assert h["Accept"] == "application/json"


def test_sdk_client_namespaces_exist():
    from sdks.python.apex_sdk.client import ApexClient

    c = ApexClient(base_url="https://x")
    assert c.hr.employees
    assert c.hr.leave
    assert c.hr.payroll
    assert c.webhooks
    assert c.saved_views


def test_sdk_api_error_formatting():
    from sdks.python.apex_sdk.client import ApexApiError

    err = ApexApiError(404, {"detail": "not found"}, request_url="https://x/y")
    assert "404" in str(err)
    assert err.request_url == "https://x/y"
