"""Apple Pay merchant-session integration.

Apple Pay Web requires the merchant to:
  1. Host a domain-verification file at /.well-known/apple-developer-merchantid-domain-association
  2. Own an Apple Pay Merchant Identity Certificate.
  3. Call Apple's validation URL with the certificate to obtain a
     merchant session, which is then passed to the JS SDK.

This scaffold handles step 3 — when presented with the validation URL
from Apple Pay JS, we POST to it with our merchant cert and return the
opaque merchant session payload.

Env vars:
  APPLE_PAY_MERCHANT_ID        merchant.com.apex-app.pay
  APPLE_PAY_DISPLAY_NAME       "APEX Financial Platform"
  APPLE_PAY_INITIATIVE_CONTEXT apex-app.com
  APPLE_PAY_CERT_PATH          path to merchant identity PEM bundle
  APPLE_PAY_KEY_PATH           path to merchant identity key PEM
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from app.integrations.payments.factory import PaymentResult

logger = logging.getLogger(__name__)

_MERCHANT_ID = os.environ.get("APPLE_PAY_MERCHANT_ID", "")
_DISPLAY_NAME = os.environ.get("APPLE_PAY_DISPLAY_NAME", "APEX")
_INITIATIVE_CONTEXT = os.environ.get("APPLE_PAY_INITIATIVE_CONTEXT", "")
_CERT_PATH = os.environ.get("APPLE_PAY_CERT_PATH", "")
_KEY_PATH = os.environ.get("APPLE_PAY_KEY_PATH", "")


def create_session(
    amount: float,
    currency: str,
    reference: str,
    callback_url: Optional[str] = None,
    validation_url: Optional[str] = None,
) -> PaymentResult:
    """Request an Apple Pay merchant session.

    Note: unlike hosted-checkout providers, Apple Pay does not return a
    'pay_url' — the browser's JS handles the UI. This function returns
    the merchant-session JSON to inject into the Apple Pay JS session.
    The `amount`/`reference` are echoed for audit logging.
    """
    if not all([_MERCHANT_ID, _INITIATIVE_CONTEXT, _CERT_PATH, _KEY_PATH]):
        return PaymentResult(
            success=False,
            provider="apple_pay",
            error="APPLE_PAY credentials not configured",
        )
    if not validation_url:
        return PaymentResult(
            success=False,
            provider="apple_pay",
            error="validation_url required (from Apple Pay JS onvalidatemerchant)",
        )
    try:
        import requests
    except ImportError:
        return PaymentResult(
            success=False, provider="apple_pay", error="requests not installed"
        )

    payload = {
        "merchantIdentifier": _MERCHANT_ID,
        "displayName": _DISPLAY_NAME,
        "initiative": "web",
        "initiativeContext": _INITIATIVE_CONTEXT,
    }
    try:
        resp = requests.post(
            validation_url,
            json=payload,
            cert=(_CERT_PATH, _KEY_PATH),
            timeout=10,
        )
    except requests.RequestException as e:
        logger.error("Apple Pay validation error: %s", e)
        return PaymentResult(
            success=False, provider="apple_pay", error=f"network: {e}"
        )

    if resp.status_code != 200:
        return PaymentResult(
            success=False,
            provider="apple_pay",
            error=f"HTTP {resp.status_code}",
        )
    try:
        session_data = resp.json()
    except ValueError:
        return PaymentResult(
            success=False, provider="apple_pay", error="invalid JSON"
        )
    return PaymentResult(
        success=True,
        provider="apple_pay",
        reference=reference,
        raw=session_data,
    )
