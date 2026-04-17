"""Tabby BNPL (Buy-Now-Pay-Later) integration.

Tabby splits a payment into 4 instalments. Popular in KSA/UAE for SMB
retail + services.

Env vars:
  TABBY_API_KEY             secret key (pk_test_... or pk_...)
  TABBY_MERCHANT_CODE       your assigned merchant code
  TABBY_TEST_MODE           'true' for sandbox (default)
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from app.integrations.payments.factory import PaymentResult

logger = logging.getLogger(__name__)

_API_KEY = os.environ.get("TABBY_API_KEY", "")
_MERCHANT_CODE = os.environ.get("TABBY_MERCHANT_CODE", "")
_TEST_MODE = os.environ.get("TABBY_TEST_MODE", "true").lower() == "true"
_BASE_URL = "https://api.tabby.ai/api/v2"  # same URL for both test + prod


def create_link(
    amount: float,
    currency: str,
    reference: str,
    customer_phone: Optional[str] = None,
    customer_email: Optional[str] = None,
) -> PaymentResult:
    if not (_API_KEY and _MERCHANT_CODE):
        return PaymentResult(
            success=False,
            provider="tabby",
            error="TABBY credentials not configured",
        )
    try:
        import requests
    except ImportError:
        return PaymentResult(success=False, provider="tabby", error="requests not installed")

    payload = {
        "payment": {
            "amount": f"{amount:.2f}",
            "currency": currency.upper(),
            "buyer": {
                "phone": customer_phone or "",
                "email": customer_email or "noemail@example.com",
                "name": "APEX Customer",
            },
            "order": {"reference_id": reference},
        },
        "lang": "ar",
        "merchant_code": _MERCHANT_CODE,
        "merchant_urls": {
            "success": "https://apex-app.com/pay/success",
            "cancel": "https://apex-app.com/pay/cancel",
            "failure": "https://apex-app.com/pay/failure",
        },
    }
    headers = {
        "Authorization": f"Bearer {_API_KEY}",
        "Content-Type": "application/json",
    }

    try:
        resp = requests.post(
            f"{_BASE_URL}/checkout", json=payload, headers=headers, timeout=15
        )
    except requests.RequestException as e:
        logger.error("Tabby network error: %s", e)
        return PaymentResult(success=False, provider="tabby", error=f"network: {e}")

    try:
        data = resp.json()
    except ValueError:
        return PaymentResult(success=False, provider="tabby", error="invalid JSON")

    if resp.status_code in (200, 201):
        config = data.get("configuration", {}).get("available_products", {})
        installments = config.get("installments") or []
        pay_url = installments[0].get("web_url") if installments else None
        return PaymentResult(
            success=True,
            provider="tabby",
            pay_url=pay_url,
            reference=reference,
            raw=data,
        )
    return PaymentResult(
        success=False,
        provider="tabby",
        error=data.get("error", f"HTTP {resp.status_code}"),
        raw=data,
    )
