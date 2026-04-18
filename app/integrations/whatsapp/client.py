"""WhatsApp Business Cloud API — outbound client.

Env vars (all required to enable real sending):
  WA_PHONE_NUMBER_ID    Phone-number ID (from Meta's business manager)
  WA_ACCESS_TOKEN       Long-lived access token
  WA_API_VERSION        API version (default 'v20.0')

Dev mode: if env vars are missing, send_* functions log the message and
return success=True with backend='console' — mirrors the email/SMS pattern
so tests and local runs don't fail.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger(__name__)

WA_PHONE_NUMBER_ID = os.environ.get("WA_PHONE_NUMBER_ID", "")
WA_ACCESS_TOKEN = os.environ.get("WA_ACCESS_TOKEN", "")
WA_API_VERSION = os.environ.get("WA_API_VERSION", "v20.0")
WA_BACKEND = os.environ.get("WA_BACKEND", "auto").lower()
# 'auto' (default): real API if env vars present, else console
# 'console': force console logging (for tests / local dev)
# 'api': force real API — fails loudly if env is incomplete


class WhatsAppError(Exception):
    """Raised for configuration/HTTP errors from the WhatsApp client."""


@dataclass
class WhatsAppResult:
    success: bool
    backend: str
    message_id: Optional[str] = None
    error: Optional[str] = None


def _api_url() -> str:
    return f"https://graph.facebook.com/{WA_API_VERSION}/{WA_PHONE_NUMBER_ID}/messages"


def _normalize_phone(raw: str) -> str:
    """WhatsApp expects E.164 with no '+' prefix."""
    digits = "".join(ch for ch in (raw or "") if ch.isdigit())
    return digits


def _active_backend() -> str:
    if WA_BACKEND == "console":
        return "console"
    if WA_BACKEND == "api":
        return "api"
    # auto
    return "api" if (WA_PHONE_NUMBER_ID and WA_ACCESS_TOKEN) else "console"


def _send_via_console(to: str, kind: str, payload: dict) -> WhatsAppResult:
    logger.info("WA [console] kind=%s to=%s payload=%s", kind, to[-4:].rjust(len(to), "*"), payload)
    return WhatsAppResult(success=True, backend="console", message_id="console-stub")


def _send_via_api(payload: dict) -> WhatsAppResult:
    if not (WA_PHONE_NUMBER_ID and WA_ACCESS_TOKEN):
        return WhatsAppResult(
            success=False,
            backend="api",
            error="WA_PHONE_NUMBER_ID or WA_ACCESS_TOKEN not configured",
        )
    try:
        import requests
    except ImportError:
        return WhatsAppResult(success=False, backend="api", error="requests not installed")

    headers = {
        "Authorization": f"Bearer {WA_ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }
    try:
        resp = requests.post(_api_url(), json=payload, headers=headers, timeout=15)
    except requests.RequestException as e:
        logger.error("WA network error: %s", e)
        return WhatsAppResult(success=False, backend="api", error=f"network: {e}")

    if resp.status_code in (200, 201):
        data = resp.json() if resp.content else {}
        mid = None
        if isinstance(data, dict):
            msgs = data.get("messages", [])
            if msgs and isinstance(msgs, list):
                mid = msgs[0].get("id")
        return WhatsAppResult(success=True, backend="api", message_id=mid)

    try:
        body = resp.json()
        err = (body.get("error") or {}).get("message", "")
    except Exception:
        err = resp.text[:300]
    return WhatsAppResult(
        success=False,
        backend="api",
        error=f"HTTP {resp.status_code}: {err}",
    )


def send_text_message(to: str, text: str) -> WhatsAppResult:
    """Send a free-form text message.

    Free-form text can only be sent within the 24-hour 'customer service
    window' — i.e., only after the recipient has messaged us first. Outside
    that window you must use template messages.
    """
    if not to or not text:
        return WhatsAppResult(success=False, backend="unknown", error="recipient and text required")
    phone = _normalize_phone(to)
    payload = {
        "messaging_product": "whatsapp",
        "to": phone,
        "type": "text",
        "text": {"body": text},
    }
    backend = _active_backend()
    if backend == "console":
        return _send_via_console(phone, "text", payload)
    return _send_via_api(payload)


def send_template_message(
    to: str,
    template_name: str,
    language_code: str = "ar",
    components: Optional[list[dict]] = None,
) -> WhatsAppResult:
    """Send a pre-approved template message (valid outside the 24h window).

    `components` matches Meta's schema, e.g.:
      [{"type": "body", "parameters": [{"type": "text", "text": "العميل أ"}]}]
    """
    if not to or not template_name:
        return WhatsAppResult(success=False, backend="unknown", error="recipient and template_name required")
    phone = _normalize_phone(to)
    payload = {
        "messaging_product": "whatsapp",
        "to": phone,
        "type": "template",
        "template": {
            "name": template_name,
            "language": {"code": language_code},
            "components": components or [],
        },
    }
    backend = _active_backend()
    if backend == "console":
        return _send_via_console(phone, f"template:{template_name}", payload)
    return _send_via_api(payload)
