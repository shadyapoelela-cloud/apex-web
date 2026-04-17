"""WebSocket notification hub — real-time fanout to connected clients.

Design:
  • Each WS client connects with a JWT in the Authorization header or
    ?token=<jwt> query param.
  • Server validates the token, extracts user_id + tenant_id.
  • Clients subscribe to channels — default is their user + tenant.
  • Server-side code publishes events via `publish()`; the hub fans out
    to every subscriber whose channel matches.
  • Dead connections are pruned on next publish attempt.

Channel naming:
  user:{user_id}           personal feed (invoices paid, tasks assigned)
  tenant:{tenant_id}       company-wide broadcasts
  entity:{type}:{id}       per-record updates (invoice changes, etc.)

Event shape (sent over the wire):
  {
    "type": "notification" | "entity_update" | "system",
    "channel": str,
    "payload": { ... }
  }
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Callable, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.websockets import WebSocketState

logger = logging.getLogger(__name__)

# Soft cap on subscribers per channel — prevents leaks from monitoring /
# runaway clients. 500 per channel is generous for an SMB app.
_MAX_SUBSCRIBERS_PER_CHANNEL = int(os.environ.get("WS_MAX_SUBS_PER_CHANNEL", "500"))

# Optional backend for cross-instance fan-out (Redis pub/sub). When not
# configured, the hub is single-process which is fine for Render free tier.
WS_BACKEND = os.environ.get("WS_BACKEND", "memory").lower()


# ── Client connection ──────────────────────────────────────


@dataclass(eq=False)  # identity-based equality so instances are hashable
class WsClient:
    ws: WebSocket
    user_id: str
    tenant_id: Optional[str]
    channels: set[str]

    async def send_json(self, data: dict) -> bool:
        """Send JSON. Return False if the connection is dead — caller prunes."""
        if self.ws.client_state != WebSocketState.CONNECTED:
            return False
        try:
            await self.ws.send_text(json.dumps(data, ensure_ascii=False, default=str))
            return True
        except Exception as e:
            logger.warning("ws send failed (pruning): %s", e)
            return False


# ── Hub ────────────────────────────────────────────────────


class WebSocketHub:
    """In-memory hub. Thread-safe via a single asyncio.Lock.

    Usage:
      hub = WebSocketHub()
      await hub.connect(ws, user_id, tenant_id)
      await hub.publish("tenant:acme", {"type": "invoice.paid", "id": "i-1"})
    """

    def __init__(self):
        self._by_channel: dict[str, set[WsClient]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def add_client(self, client: WsClient) -> None:
        async with self._lock:
            # Default channels: user's personal + their tenant (if any).
            client.channels.add(f"user:{client.user_id}")
            if client.tenant_id:
                client.channels.add(f"tenant:{client.tenant_id}")
            for ch in client.channels:
                subs = self._by_channel[ch]
                if len(subs) >= _MAX_SUBSCRIBERS_PER_CHANNEL:
                    logger.warning("ws: channel %s full, refusing %s", ch, client.user_id)
                    continue
                subs.add(client)

    async def remove_client(self, client: WsClient) -> None:
        async with self._lock:
            for ch in list(client.channels):
                self._by_channel[ch].discard(client)
                if not self._by_channel[ch]:
                    del self._by_channel[ch]

    async def subscribe(self, client: WsClient, channel: str) -> None:
        if not _is_allowed_channel(client, channel):
            raise PermissionError(f"{client.user_id} may not subscribe to {channel}")
        async with self._lock:
            client.channels.add(channel)
            self._by_channel[channel].add(client)

    async def publish(self, channel: str, payload: dict) -> int:
        """Fan out `payload` to every subscriber of `channel`. Returns the
        number of successful deliveries. Dead sockets are pruned."""
        async with self._lock:
            clients = list(self._by_channel.get(channel, set()))

        if not clients:
            return 0

        envelope = {
            "channel": channel,
            **payload,
        }
        delivered = 0
        dead: list[WsClient] = []
        for client in clients:
            ok = await client.send_json(envelope)
            if ok:
                delivered += 1
            else:
                dead.append(client)

        if dead:
            async with self._lock:
                for c in dead:
                    for ch in list(c.channels):
                        self._by_channel[ch].discard(c)
                        if not self._by_channel[ch]:
                            del self._by_channel[ch]
        return delivered

    def stats(self) -> dict:
        return {
            "channels": len(self._by_channel),
            "subscribers": sum(len(s) for s in self._by_channel.values()),
        }


# ── Authorization helpers ─────────────────────────────────


def _is_allowed_channel(client: WsClient, channel: str) -> bool:
    """A client can subscribe to:
        • their own user channel
        • their tenant channel
        • entity:* channels for records they're authorized to view
    For now we trust `entity:*` subscriptions and rely on server-side
    publishers to only send tenant-appropriate payloads.
    """
    if channel == f"user:{client.user_id}":
        return True
    if client.tenant_id and channel == f"tenant:{client.tenant_id}":
        return True
    if channel.startswith("entity:"):
        return True
    return False


# ── Global singleton ───────────────────────────────────────


_hub: WebSocketHub | None = None


def get_hub() -> WebSocketHub:
    global _hub
    if _hub is None:
        _hub = WebSocketHub()
    return _hub


# ── FastAPI router ────────────────────────────────────────


router = APIRouter(prefix="/ws", tags=["WebSocket"])


def _decode_jwt(token: str) -> Optional[dict]:
    if not token:
        return None
    try:
        import jwt
        # We rely on the main auth layer to have pre-validated; here we just
        # peek for user_id / tenant_id. If token is bogus, connect rejects.
        from app.core.auth_utils import JWT_SECRET

        claims = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return claims
    except Exception as e:
        logger.debug("ws jwt decode failed: %s", e)
        return None


@router.websocket("/notifications")
async def notifications_ws(
    ws: WebSocket,
    token: Optional[str] = Query(None),
):
    """Primary WS endpoint. Supply the JWT as ?token=<...> or via the
    Sec-WebSocket-Protocol header."""
    # Try token from query or Authorization header.
    auth = None
    for h in ws.headers.keys():
        if h.lower() == "authorization":
            auth = ws.headers[h]
            break
    if not token and auth and auth.lower().startswith("bearer "):
        token = auth[7:].strip()

    claims = _decode_jwt(token) if token else None
    if not claims:
        await ws.close(code=4401, reason="unauthorized")
        return

    user_id = str(claims.get("sub") or claims.get("user_id") or "")
    tenant_id = claims.get("tenant_id") or claims.get("tid")
    if not user_id:
        await ws.close(code=4401, reason="no subject")
        return

    await ws.accept()
    client = WsClient(ws=ws, user_id=user_id, tenant_id=tenant_id, channels=set())
    hub = get_hub()
    await hub.add_client(client)

    # Greet with subscribed channels.
    await client.send_json({"type": "welcome", "channels": sorted(client.channels)})

    try:
        while True:
            # Clients send subscribe / ping messages; we parse + act.
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except Exception:
                await client.send_json({"type": "error", "error": "bad json"})
                continue
            if msg.get("type") == "subscribe" and msg.get("channel"):
                try:
                    await hub.subscribe(client, msg["channel"])
                    await client.send_json(
                        {"type": "subscribed", "channel": msg["channel"]}
                    )
                except PermissionError:
                    await client.send_json(
                        {"type": "error", "error": "forbidden", "channel": msg["channel"]}
                    )
            elif msg.get("type") == "ping":
                await client.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    finally:
        await hub.remove_client(client)


# ── Public publish helpers for the rest of the app ────────


async def publish_to_user(user_id: str, payload: dict) -> int:
    return await get_hub().publish(f"user:{user_id}", payload)


async def publish_to_tenant(tenant_id: str, payload: dict) -> int:
    return await get_hub().publish(f"tenant:{tenant_id}", payload)


async def publish_to_entity(entity_type: str, entity_id: str, payload: dict) -> int:
    return await get_hub().publish(f"entity:{entity_type}:{entity_id}", payload)
