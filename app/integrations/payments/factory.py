"""Payment provider factory — unified interface across Stripe + GCC backends.

Usage:
    from app.integrations.payments import create_payment_link
    result = create_payment_link(
        amount=150.00, currency="SAR",
        reference="INV-2026-001", customer_phone="+966501234567",
        preferred="mada",
    )

`preferred` may be: 'mada', 'stc_pay', 'apple_pay', 'tabby', 'tamara',
'benefit', 'stripe', 'mock'. If omitted, falls back to PAYMENT_BACKEND
env var, then 'mock'.

All providers return a PaymentResult with `success`, `provider`, `pay_url`
(or equivalent), and structured error info. Network failures are caught
and mapped to success=False — callers never see raw exceptions.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class PaymentProvider(str, Enum):
    MADA = "mada"
    STC_PAY = "stc_pay"
    APPLE_PAY = "apple_pay"
    TABBY = "tabby"
    TAMARA = "tamara"
    BENEFIT = "benefit"
    STRIPE = "stripe"
    MOCK = "mock"


@dataclass
class PaymentResult:
    success: bool
    provider: str
    pay_url: Optional[str] = None
    reference: Optional[str] = None
    expires_at: Optional[str] = None
    error: Optional[str] = None
    raw: dict | None = None


def get_provider(preferred: Optional[str] = None) -> PaymentProvider:
    """Choose the active provider based on preferred → env → 'mock'."""
    value = (preferred or os.environ.get("PAYMENT_BACKEND", "") or "mock").lower()
    try:
        return PaymentProvider(value)
    except ValueError:
        logger.warning("Unknown payment provider %r — falling back to mock", value)
        return PaymentProvider.MOCK


def create_payment_link(
    amount: float,
    currency: str,
    reference: str,
    customer_phone: Optional[str] = None,
    customer_email: Optional[str] = None,
    callback_url: Optional[str] = None,
    preferred: Optional[str] = None,
) -> PaymentResult:
    """Create a payment link with the chosen provider."""
    provider = get_provider(preferred)

    # Lazy-load the provider implementation to avoid crashing when one
    # backend's optional dep is missing.
    if provider == PaymentProvider.MADA:
        from app.integrations.payments import mada_hyperpay

        return mada_hyperpay.create_link(
            amount, currency, reference, customer_email, callback_url
        )
    if provider == PaymentProvider.STC_PAY:
        from app.integrations.payments import stc_pay

        return stc_pay.create_link(amount, currency, reference, customer_phone)
    if provider == PaymentProvider.APPLE_PAY:
        from app.integrations.payments import apple_pay

        return apple_pay.create_session(amount, currency, reference, callback_url)
    if provider == PaymentProvider.TABBY:
        from app.integrations.payments import tabby

        return tabby.create_link(
            amount, currency, reference, customer_phone, customer_email
        )
    if provider == PaymentProvider.MOCK:
        return PaymentResult(
            success=True,
            provider="mock",
            pay_url=f"https://apex-app.com/mock-pay/{reference}",
            reference=reference,
            raw={"mock": True, "amount": amount, "currency": currency},
        )

    # TAMARA / BENEFIT / STRIPE can follow the same shape once wired.
    return PaymentResult(
        success=False,
        provider=provider.value,
        error=f"Provider {provider.value} not wired yet",
    )
