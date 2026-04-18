"""GCC payment backends — Mada, STC Pay, Apple Pay, Tabby, Tamara, Benefit.

Design: each provider exposes the same `create_payment_link(amount, currency,
reference, customer_phone?, customer_email?, callback_url?)` API. The
PaymentProviderFactory chooses the backend based on the `PAYMENT_BACKEND`
env var and delegates — so existing Stripe-based calls keep working while
regional providers can be plugged in per-tenant.

Providers:
  - mada_hyperpay.py  : Mada cards via HyperPay
  - stc_pay.py        : STC Pay wallet (KSA)
  - apple_pay.py      : Apple Pay merchant-session (KSA + UAE)
  - tabby.py          : Tabby BNPL
  - tamara.py         : Tamara BNPL
  - benefit.py        : Benefit Bahrain
"""

from app.integrations.payments.factory import (  # noqa: F401
    PaymentProvider,
    PaymentResult,
    create_payment_link,
    get_provider,
)

__all__ = [
    "PaymentProvider",
    "PaymentResult",
    "create_payment_link",
    "get_provider",
]
