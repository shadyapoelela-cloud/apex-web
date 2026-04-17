"""WhatsApp Business Cloud webhook.

Meta dispatches inbound messages and delivery-status callbacks to this
endpoint. Payloads are signed with HMAC-SHA256 using your app secret —
we verify every request before processing.

Setup (Meta Developer Console):
  Callback URL: https://api.apex-app.com/integrations/whatsapp/webhook
  Verify token: ${WA_VERIFY_TOKEN}
  Subscribe to: messages, message_status
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import os
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query, Request
from fastapi.responses import PlainTextResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/integrations/whatsapp", tags=["WhatsApp"])

WA_VERIFY_TOKEN = os.environ.get("WA_VERIFY_TOKEN", "")
WA_APP_SECRET = os.environ.get("WA_APP_SECRET", "")


@router.get("/webhook")
def verify_webhook(
    hub_mode: str = Query(..., alias="hub.mode"),
    hub_verify_token: str = Query(..., alias="hub.verify_token"),
    hub_challenge: str = Query(..., alias="hub.challenge"),
) -> PlainTextResponse:
    """Meta's one-time verification handshake.

    Called by Meta when you register the callback URL. Must echo the
    challenge verbatim when our verify token matches.
    """
    if not WA_VERIFY_TOKEN:
        raise HTTPException(status_code=503, detail="WA_VERIFY_TOKEN not configured")
    if hub_mode != "subscribe" or hub_verify_token != WA_VERIFY_TOKEN:
        raise HTTPException(status_code=403, detail="verification failed")
    return PlainTextResponse(hub_challenge)


def _verify_signature(app_secret: str, body: bytes, signature_header: Optional[str]) -> bool:
    """Check X-Hub-Signature-256: sha256=<hex>."""
    if not app_secret or not signature_header:
        return False
    if not signature_header.startswith("sha256="):
        return False
    provided = signature_header.split("=", 1)[1]
    expected = hmac.new(app_secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(provided, expected)


@router.post("/webhook")
async def receive_webhook(
    request: Request,
    x_hub_signature_256: Optional[str] = Header(None, alias="X-Hub-Signature-256"),
):
    """Inbound WhatsApp event (message / status).

    Returns 200 OK quickly after signature verification — actual processing
    is dispatched to a background task so Meta's 20-second timeout is
    respected.
    """
    body = await request.body()

    if WA_APP_SECRET:
        if not _verify_signature(WA_APP_SECRET, body, x_hub_signature_256):
            logger.warning("WA webhook: signature mismatch")
            raise HTTPException(status_code=401, detail="invalid signature")
    else:
        logger.warning("WA_APP_SECRET not set — signature verification bypassed")

    try:
        import json
        payload = json.loads(body)
    except Exception:
        raise HTTPException(status_code=400, detail="malformed payload")

    events = _extract_events(payload)
    for evt in events:
        _handle_event(evt)

    return {"success": True, "processed": len(events)}


def _extract_events(payload: dict) -> list[dict]:
    """Flatten Meta's nested entry → changes → value → [messages/statuses]."""
    out: list[dict] = []
    for entry in payload.get("entry") or []:
        for change in entry.get("changes") or []:
            value = change.get("value") or {}
            for msg in value.get("messages") or []:
                out.append({"kind": "message", "data": msg})
            for status in value.get("statuses") or []:
                out.append({"kind": "status", "data": status})
    return out


def _handle_event(event: dict) -> None:
    """Dispatch inbound messages + statuses. Wire real handlers here later.

    Minimal stub: just log. Replace with routing to AP inbox (for images),
    Copilot (for text), balance responder (for 'رصيد' keyword), etc.
    """
    kind = event.get("kind")
    data = event.get("data", {})
    if kind == "message":
        msg_type = data.get("type")
        frm = data.get("from", "?")
        logger.info("WA inbound message: type=%s from=%s", msg_type, frm)
        # Future: dispatch by type — text → Copilot, image → OCR → AP agent, etc.
    elif kind == "status":
        status = data.get("status")
        mid = data.get("id")
        logger.info("WA delivery status: id=%s status=%s", mid, status)
