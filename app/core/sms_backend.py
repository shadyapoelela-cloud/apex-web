"""
APEX Platform -- SMS Backend
Supports Unifonic (KSA/MENA), Twilio (global), and Console (dev) backends.
Config via environment variables.

Pattern mirrors app.core.email_service for consistency.
"""

import os
import logging

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────

SMS_BACKEND = os.environ.get("SMS_BACKEND", "console")  # "unifonic", "twilio", "console"

# Unifonic settings (preferred for KSA/MENA)
UNIFONIC_APP_SID = os.environ.get("UNIFONIC_APP_SID", "")
UNIFONIC_SENDER_ID = os.environ.get("UNIFONIC_SENDER_ID", "APEX")
UNIFONIC_BASE_URL = os.environ.get(
    "UNIFONIC_BASE_URL", "https://el.cloud.unifonic.com/rest/SMS/messages"
)

# Twilio settings (fallback / global)
TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM_NUMBER = os.environ.get("TWILIO_FROM_NUMBER", "")

PLATFORM_NAME = "APEX"


# ── Backend Implementations ───────────────────────────────────


def _send_via_console(to: str, message: str) -> dict:
    """Development backend -- logs SMS to console."""
    masked = to[:4] + "****" + to[-2:] if len(to) > 6 else to
    logger.info("SMS [console] To=%s Body=%s", masked, message)
    return {"success": True, "backend": "console"}


def _send_via_unifonic(to: str, message: str) -> dict:
    """Send SMS via Unifonic REST API (KSA/MENA primary)."""
    if not UNIFONIC_APP_SID:
        logger.error("Unifonic not configured (UNIFONIC_APP_SID missing)")
        return {"success": False, "error": "Unifonic not configured"}

    try:
        import requests
    except ImportError:
        logger.error("requests library not installed — needed for Unifonic backend")
        return {"success": False, "error": "requests library not available"}

    # Unifonic expects number without leading +
    recipient = to.lstrip("+")

    payload = {
        "AppSid": UNIFONIC_APP_SID,
        "SenderID": UNIFONIC_SENDER_ID,
        "Recipient": recipient,
        "Body": message,
        "async": "false",
    }

    try:
        resp = requests.post(UNIFONIC_BASE_URL, data=payload, timeout=30)
        if resp.status_code == 200:
            data = resp.json()
            if data.get("success"):
                logger.info("SMS [unifonic] sent to %s", recipient[-4:].rjust(len(recipient), "*"))
                return {"success": True, "backend": "unifonic", "message_id": data.get("data", {}).get("MessageID")}
            else:
                logger.error("Unifonic API error: %s", data.get("message", "unknown"))
                return {"success": False, "error": data.get("message", "Unifonic API error")}
        else:
            logger.error("Unifonic HTTP %s: %s", resp.status_code, resp.text[:300])
            return {"success": False, "error": f"Unifonic HTTP {resp.status_code}"}
    except requests.RequestException as e:
        logger.error("Unifonic request failed: %s", e)
        return {"success": False, "error": "Unifonic request failed"}


def _send_via_twilio(to: str, message: str) -> dict:
    """Send SMS via Twilio REST API (global fallback)."""
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN or not TWILIO_FROM_NUMBER:
        logger.error("Twilio not fully configured (account_sid/auth_token/from_number)")
        return {"success": False, "error": "Twilio not configured"}

    try:
        import requests
    except ImportError:
        logger.error("requests library not installed — needed for Twilio backend")
        return {"success": False, "error": "requests library not available"}

    url = f"https://api.twilio.com/2010-04-01/Accounts/{TWILIO_ACCOUNT_SID}/Messages.json"
    payload = {
        "From": TWILIO_FROM_NUMBER,
        "To": to if to.startswith("+") else f"+{to}",
        "Body": message,
    }

    try:
        resp = requests.post(
            url,
            data=payload,
            auth=(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN),
            timeout=30,
        )
        if resp.status_code in (200, 201):
            data = resp.json()
            logger.info("SMS [twilio] sent sid=%s", data.get("sid", "?"))
            return {"success": True, "backend": "twilio", "message_id": data.get("sid")}
        else:
            logger.error("Twilio HTTP %s: %s", resp.status_code, resp.text[:300])
            return {"success": False, "error": f"Twilio HTTP {resp.status_code}"}
    except requests.RequestException as e:
        logger.error("Twilio request failed: %s", e)
        return {"success": False, "error": "Twilio request failed"}


# ── Public API ────────────────────────────────────────────────

_BACKENDS = {
    "console": _send_via_console,
    "unifonic": _send_via_unifonic,
    "twilio": _send_via_twilio,
}


def send_sms(to: str, message: str) -> dict:
    """
    Send an SMS using the configured backend.

    Args:
        to: E.164 phone number (e.g. "+966501234567")
        message: SMS body (max 160 chars for single segment)

    Returns:
        {"success": True, "backend": str, ...} on success
        {"success": False, "error": str} on failure
    """
    if not to or not message:
        return {"success": False, "error": "recipient and message are required"}

    backend_fn = _BACKENDS.get(SMS_BACKEND)
    if not backend_fn:
        logger.error("Unknown SMS_BACKEND=%s, falling back to console", SMS_BACKEND)
        backend_fn = _send_via_console

    try:
        return backend_fn(to, message)
    except Exception as e:
        logger.error("SMS send failed (backend=%s): %s", SMS_BACKEND, e)
        return {"success": False, "error": "SMS delivery failed"}


def send_otp_sms(to: str, code: str, validity_minutes: int = 5) -> dict:
    """Send an OTP verification code via SMS (Arabic message)."""
    message = (
        f"{PLATFORM_NAME}: رمز التحقق الخاص بك هو {code}. "
        f"صالح لمدة {validity_minutes} دقائق. لا تشاركه مع أحد."
    )
    return send_sms(to, message)
