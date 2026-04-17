"""STC Pay merchant integration (KSA wallet).

STC Pay uses OAuth2 client-credentials + REST endpoints:
  POST /api/MerchantPayment/DirectPayment.Request
  POST /api/MerchantPayment/DirectPayment.Confirm

Env vars:
  STC_PAY_CLIENT_ID
  STC_PAY_CLIENT_SECRET
  STC_PAY_MERCHANT_ID
  STC_PAY_BASE_URL        default: test.stcpay.com.sa
"""

from __future__ import annotations

import logging
import os
import uuid
from typing import Optional

from app.integrations.payments.factory import PaymentResult

logger = logging.getLogger(__name__)

_CLIENT_ID = os.environ.get("STC_PAY_CLIENT_ID", "")
_CLIENT_SECRET = os.environ.get("STC_PAY_CLIENT_SECRET", "")
_MERCHANT_ID = os.environ.get("STC_PAY_MERCHANT_ID", "")
_BASE_URL = os.environ.get("STC_PAY_BASE_URL", "https://test.stcpay.com.sa").rstrip("/")


def create_link(
    amount: float,
    currency: str,
    reference: str,
    customer_phone: Optional[str] = None,
) -> PaymentResult:
    if not (_CLIENT_ID and _CLIENT_SECRET and _MERCHANT_ID):
        return PaymentResult(
            success=False,
            provider="stc_pay",
            error="STC_PAY credentials not configured",
        )
    if not customer_phone:
        return PaymentResult(
            success=False,
            provider="stc_pay",
            error="STC Pay requires customer_phone (mobile number)",
        )
    try:
        import requests
    except ImportError:
        return PaymentResult(
            success=False, provider="stc_pay", error="requests not installed"
        )

    # Normalize phone to 9665... (E.164 without +)
    phone = "".join(ch for ch in customer_phone if ch.isdigit())
    if phone.startswith("0"):
        phone = "966" + phone[1:]

    request_id = str(uuid.uuid4())
    body = {
        "MobileNo": phone,
        "BranchID": _MERCHANT_ID,
        "Amount": f"{amount:.2f}",
        "Currency": currency.upper(),
        "RefNum": reference,
        "BillNumber": reference,
    }
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "ClientID": _CLIENT_ID,
        "DeviceID": request_id,
    }

    url = f"{_BASE_URL}/api/MerchantPayment/DirectPayment.Request"
    try:
        resp = requests.post(
            url, json=body, headers=headers, auth=(_CLIENT_ID, _CLIENT_SECRET), timeout=15
        )
    except requests.RequestException as e:
        logger.error("STC Pay network error: %s", e)
        return PaymentResult(success=False, provider="stc_pay", error=f"network: {e}")

    try:
        data = resp.json()
    except ValueError:
        return PaymentResult(success=False, provider="stc_pay", error="invalid JSON")

    if resp.status_code == 200 and data.get("RequestedStatus") == "Success":
        return PaymentResult(
            success=True,
            provider="stc_pay",
            pay_url=None,  # STC Pay delivers via push notification to wallet
            reference=reference,
            raw=data,
        )
    return PaymentResult(
        success=False,
        provider="stc_pay",
        error=data.get("StatusDescription", f"HTTP {resp.status_code}"),
        raw=data,
    )
