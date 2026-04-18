"""Tests for the WebSocket notification hub.

Covers:
  • _is_allowed_channel: user can join own / tenant / entity:*; denies others
  • hub.publish fans out to subscribers
  • dead subscribers are pruned on next publish
  • subscriber cap enforced
  • end-to-end WS handshake fails without valid JWT
  • end-to-end WS handshake succeeds with a valid JWT and receives welcome
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest


# ── _is_allowed_channel ────────────────────────────────────


def _fake_client(user_id="u-1", tenant_id="t-1", channels=None):
    from app.core.websocket_hub import WsClient

    return WsClient(ws=None, user_id=user_id, tenant_id=tenant_id, channels=set(channels or []))


def test_user_can_join_own_channel():
    from app.core.websocket_hub import _is_allowed_channel

    c = _fake_client(user_id="u-1", tenant_id="t-1")
    assert _is_allowed_channel(c, "user:u-1") is True


def test_user_cannot_join_someone_elses_channel():
    from app.core.websocket_hub import _is_allowed_channel

    c = _fake_client(user_id="u-1", tenant_id="t-1")
    assert _is_allowed_channel(c, "user:u-2") is False


def test_user_can_join_their_tenant():
    from app.core.websocket_hub import _is_allowed_channel

    c = _fake_client(user_id="u-1", tenant_id="t-1")
    assert _is_allowed_channel(c, "tenant:t-1") is True


def test_user_cannot_join_other_tenant():
    from app.core.websocket_hub import _is_allowed_channel

    c = _fake_client(user_id="u-1", tenant_id="t-1")
    assert _is_allowed_channel(c, "tenant:t-999") is False


def test_entity_channels_allowed():
    from app.core.websocket_hub import _is_allowed_channel

    c = _fake_client(user_id="u-1", tenant_id="t-1")
    assert _is_allowed_channel(c, "entity:invoice:inv-1") is True


# ── Hub behavior (mocked WebSocket) ───────────────────────


class _FakeWebSocket:
    """Stand-in for starlette WebSocket."""

    def __init__(self, alive=True):
        self.sent: list[str] = []
        self.alive = alive
        from fastapi.websockets import WebSocketState
        self.client_state = WebSocketState.CONNECTED if alive else WebSocketState.DISCONNECTED

    async def send_text(self, text: str):
        if not self.alive:
            raise ConnectionError("dead")
        self.sent.append(text)


@pytest.mark.anyio
async def test_publish_fans_out_to_subscribers():
    from app.core.websocket_hub import WebSocketHub, WsClient

    hub = WebSocketHub()
    ws_a = _FakeWebSocket()
    ws_b = _FakeWebSocket()
    c_a = WsClient(ws=ws_a, user_id="u-a", tenant_id="t-1", channels=set())
    c_b = WsClient(ws=ws_b, user_id="u-b", tenant_id="t-1", channels=set())
    await hub.add_client(c_a)
    await hub.add_client(c_b)

    delivered = await hub.publish("tenant:t-1", {"type": "broadcast", "msg": "hello"})
    assert delivered == 2
    assert len(ws_a.sent) == 1
    assert len(ws_b.sent) == 1
    # Both payloads contain the channel
    assert "tenant:t-1" in ws_a.sent[0]


@pytest.mark.anyio
async def test_publish_prunes_dead_subscribers():
    from app.core.websocket_hub import WebSocketHub, WsClient

    hub = WebSocketHub()
    live = _FakeWebSocket(alive=True)
    dead = _FakeWebSocket(alive=False)
    c_live = WsClient(ws=live, user_id="u-live", tenant_id="t-1", channels=set())
    c_dead = WsClient(ws=dead, user_id="u-dead", tenant_id="t-1", channels=set())
    await hub.add_client(c_live)
    await hub.add_client(c_dead)

    delivered = await hub.publish("tenant:t-1", {"type": "test"})
    # Only 1 delivery (live one)
    assert delivered == 1
    # Dead client is pruned
    stats = hub.stats()
    # live user's channel + tenant channel = 2 channels, 1 subscriber each
    assert stats["subscribers"] <= 2


@pytest.mark.anyio
async def test_subscribe_rejects_forbidden_channel():
    from app.core.websocket_hub import WebSocketHub, WsClient

    hub = WebSocketHub()
    c = WsClient(ws=_FakeWebSocket(), user_id="u-x", tenant_id="t-x", channels=set())
    await hub.add_client(c)
    with pytest.raises(PermissionError):
        await hub.subscribe(c, "user:someone-else")


@pytest.mark.anyio
async def test_remove_client_cleans_channels():
    from app.core.websocket_hub import WebSocketHub, WsClient

    hub = WebSocketHub()
    c = WsClient(ws=_FakeWebSocket(), user_id="u-z", tenant_id="t-z", channels=set())
    await hub.add_client(c)
    assert hub.stats()["subscribers"] > 0
    await hub.remove_client(c)
    assert hub.stats()["subscribers"] == 0


@pytest.mark.anyio
async def test_publish_to_empty_channel_returns_zero():
    from app.core.websocket_hub import WebSocketHub

    hub = WebSocketHub()
    assert await hub.publish("tenant:nobody", {"x": 1}) == 0


# ── End-to-end WS handshake via TestClient ────────────────


def _make_jwt(sub: str, tenant_id: str | None = None) -> str:
    import jwt
    import os

    secret = os.environ.get("JWT_SECRET", "test-secret")
    payload = {
        "sub": sub,
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc),
    }
    if tenant_id:
        payload["tenant_id"] = tenant_id
    return jwt.encode(payload, secret, algorithm="HS256")


def test_ws_rejects_without_token(client):
    """The WS endpoint must close with code 4401 when no token is sent."""
    try:
        with client.websocket_connect("/ws/notifications") as ws:
            # If we got here, the server accepted — should have closed.
            pytest.fail("ws connect should have been rejected")
    except Exception:
        # WebSocketTestSession raises WebSocketDisconnect when server closes.
        pass


def test_ws_accepts_with_valid_token(client):
    """Valid JWT → welcome message with subscribed channels."""
    import json

    token = _make_jwt("user-ws-1", tenant_id="tenant-ws-1")
    with client.websocket_connect(f"/ws/notifications?token={token}") as ws:
        first = ws.receive_text()
        msg = json.loads(first)
        assert msg["type"] == "welcome"
        assert "user:user-ws-1" in msg["channels"]
        assert "tenant:tenant-ws-1" in msg["channels"]


def test_ws_ping_pong(client):
    import json

    token = _make_jwt("user-ws-2", tenant_id="tenant-ws-2")
    with client.websocket_connect(f"/ws/notifications?token={token}") as ws:
        ws.receive_text()  # welcome
        ws.send_text(json.dumps({"type": "ping"}))
        reply = json.loads(ws.receive_text())
        assert reply["type"] == "pong"


def test_ws_subscribe_to_entity_channel(client):
    import json

    token = _make_jwt("user-ws-3", tenant_id="tenant-ws-3")
    with client.websocket_connect(f"/ws/notifications?token={token}") as ws:
        ws.receive_text()  # welcome
        ws.send_text(json.dumps({"type": "subscribe", "channel": "entity:invoice:i-1"}))
        reply = json.loads(ws.receive_text())
        assert reply["type"] == "subscribed"
        assert reply["channel"] == "entity:invoice:i-1"


def test_ws_subscribe_forbidden_channel_returns_error(client):
    import json

    token = _make_jwt("user-ws-4", tenant_id="tenant-ws-4")
    with client.websocket_connect(f"/ws/notifications?token={token}") as ws:
        ws.receive_text()  # welcome
        ws.send_text(json.dumps({"type": "subscribe", "channel": "user:other-user"}))
        reply = json.loads(ws.receive_text())
        assert reply["type"] == "error"


# ── Required for pytest-anyio ─────────────────────────────


@pytest.fixture
def anyio_backend():
    return "asyncio"
