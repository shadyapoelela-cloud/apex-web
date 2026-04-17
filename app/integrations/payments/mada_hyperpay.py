"""Mada payment via HyperPay gateway (KSA).

HyperPay is the most common aggregator for Saudi merchants. This module
creates a Checkout session which the UI then completes by redirecting
the customer to a hosted widget.

Env vars:
  HYPERPAY_ACCESS_TOKEN     Bearer token from HyperPay dashboard
  HYPERPAY_ENTITY_ID_MADA   Entity ID for Mada channel
  HYPERPAY_TEST_MODE        'true' (default) uses eu-test / ksa-test endpoints
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from app.integrations.payments.factory import PaymentResult

logger = logging.getLogger(__name__)

_ACCESS_TOKEN = os.environ.get("HYPERPAY_ACCESS_TOKEN", "")
_ENTITY_ID = os.environ.get("HYPERPAY_ENTITY_ID_MADA", "")
_TEST_MODE = os.environ.get("HYPERPAY_TEST_MODE", "true").lower() == "true"
_BASE_URL = (
    "https://eu-test.oppwa.com/v1/checkouts"
    if _TEST_MODE
    else "https://oppwa.com/v1/checkouts"
)


def create_link(
    amount: float,
    currency: str,
    reference: str,
    customer_email: Optional[str] = None,
    callback_url: Optional[str] = None,
) -> PaymentResult:
    if not _ACCESS_TOKEN or not _ENTITY_ID:
        return PaymentResult(
            success=False,
            provider="mada",
            error="HYPERPAY credentials not configured",
        )
    try:
        import requests
    except ImportError:
        return PaymentResult(success=False, provider="mada", error="requests not installed")

    payload = {
        "entityId": _ENTITY_ID,
        "amount": f"{amount:.2f}",
        "currency": currency.upper(),
        "paymentType": "DB",
        "merchantTransactionId": reference,
    }
    if customer_email:
        payload["customer.email"] = customer_email
    if callback_url:
        payload["shopperResultUrl"] = callback_url

    headers = {
        "Authorization": f"Bearer {_ACCESS_TOKEN}",
        "Content-Type": "application/x-www-form-urlencoded",
    }

    try:
        resp = requests.post(_BASE_URL, data=payload, headers=headers, timeout=15)
    except requests.RequestException as e:
        logger.error("HyperPay network error: %s", e)
        return PaymentResult(success=False, provider="mada", error=f"network: {e}")

    try:
        body = resp.json()
    except ValueError:
        return PaymentResult(success=False, provider="mada", error="invalid JSON from HyperPay")

    checkout_id = body.get("id")
    result_code = (body.get("result") or {}).get("code", "")
    # HyperPay success codes start with '000.'
    success = resp.status_code == 200 and result_code.startswith("000.")

    pay_url = (
        f"https://eu-test.oppwa.com/v1/paymentWidgets.js?checkoutId={checkout_id}"
        if _TEST_MODE and checkout_id
        else (f"https://oppwa.com/v1/paymentWidgets.js?checkoutId={checkout_id}" if checkout_id else None)
    )

    return PaymentResult(
        success=success,
        provider="mada",
        pay_url=pay_url,
        reference=reference,
        error=None if success else (body.get("result") or {}).get("description"),
        raw=body,
    )
