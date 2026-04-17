"""WhatsApp Business Cloud API integration for APEX.

Sub-modules:
  • client.py   — outbound messaging (text + template + media) via Meta's
                  WhatsApp Cloud API.
  • webhook.py  — FastAPI endpoints for inbound messages + delivery status,
                  with HMAC signature verification.
  • templates.py — pre-defined message templates (invoice issued, payment
                  reminder, payment received, balance inquiry, expense
                  approval). Must be registered with Meta before use.

All network calls are guarded — missing env vars return a structured error
instead of crashing. WhatsApp is an optional integration; if unconfigured,
APEX runs normally and only the WhatsApp-specific endpoints report
'not configured'.
"""

from app.integrations.whatsapp.client import (  # noqa: F401
    WhatsAppError,
    send_template_message,
    send_text_message,
)

__all__ = [
    "WhatsAppError",
    "send_template_message",
    "send_text_message",
]
