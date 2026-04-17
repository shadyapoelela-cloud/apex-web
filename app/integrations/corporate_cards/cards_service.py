"""Corporate Cards — provider-agnostic facade.

All feature code uses this module. Provider-specific HTTP clients live
in sibling files (yuze_client, nymcard_client).

Policy engine evaluates transactions against per-card + per-tenant rules
BEFORE approving. Example:
  "No spend over 5000 AED at MCC 5812 (restaurants) without manager
   approval."
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from decimal import Decimal
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class CardProvider(str, Enum):
    YUZE = "yuze"
    NYMCARD = "nymcard"
    MOCK = "mock"


def _active_provider() -> CardProvider:
    env = os.environ.get("CORP_CARDS_BACKEND", "").lower()
    try:
        return CardProvider(env)
    except ValueError:
        return CardProvider.MOCK


# ── Data types ────────────────────────────────────────────


@dataclass
class IssueCardRequest:
    employee_id: str
    employee_name_en: str
    daily_limit: Decimal
    monthly_limit: Decimal
    allowed_mccs: Optional[list[str]] = None   # None = all allowed
    blocked_mccs: Optional[list[str]] = None


@dataclass
class IssueCardResult:
    success: bool
    provider: str
    card_id: Optional[str] = None
    pan_last4: Optional[str] = None
    expiry_mm_yy: Optional[str] = None
    provisioning_url: Optional[str] = None  # Apple/Google Wallet link
    error: Optional[str] = None


@dataclass
class PolicyDecision:
    allowed: bool
    reason: str
    decision_type: str    # 'allow' | 'deny' | 'requires_approval'


# ── Public API ────────────────────────────────────────────


def issue_card(req: IssueCardRequest) -> IssueCardResult:
    provider = _active_provider()
    if provider == CardProvider.YUZE:
        from app.integrations.corporate_cards import yuze_client

        return yuze_client.issue_card(req)
    if provider == CardProvider.NYMCARD:
        from app.integrations.corporate_cards import nymcard_client

        return nymcard_client.issue_card(req)
    # Mock — always succeeds, handy for dev.
    import uuid

    return IssueCardResult(
        success=True,
        provider="mock",
        card_id=f"card_mock_{uuid.uuid4().hex[:12]}",
        pan_last4="4242",
        expiry_mm_yy="12/29",
        provisioning_url=None,
    )


def set_card_limits(card_id: str, daily: Decimal, monthly: Decimal) -> dict:
    """Update per-card limits. Non-breaking — returns structured result."""
    provider = _active_provider()
    if provider == CardProvider.MOCK:
        return {"success": True, "card_id": card_id, "daily": str(daily), "monthly": str(monthly)}
    # Real providers: delegate via their client
    return {"success": False, "error": f"provider {provider.value} not wired"}


def check_transaction_policy(
    *,
    amount: Decimal,
    currency: str,
    mcc: Optional[str] = None,
    employee_id: Optional[str] = None,
    daily_spent: Decimal = Decimal("0"),
    monthly_spent: Decimal = Decimal("0"),
    daily_limit: Decimal = Decimal("0"),
    monthly_limit: Decimal = Decimal("0"),
    allowed_mccs: Optional[list[str]] = None,
    blocked_mccs: Optional[list[str]] = None,
    approval_required_above: Optional[Decimal] = None,
) -> PolicyDecision:
    """Evaluate a proposed transaction against card + tenant policy.

    Returns (allowed, reason, decision_type).
    """
    # 1. MCC block list (hard deny)
    if mcc and blocked_mccs and mcc in blocked_mccs:
        return PolicyDecision(
            allowed=False,
            reason=f"MCC {mcc} غير مسموح به",
            decision_type="deny",
        )
    # 2. MCC allow list
    if mcc and allowed_mccs and mcc not in allowed_mccs:
        return PolicyDecision(
            allowed=False,
            reason=f"MCC {mcc} خارج القائمة المسموح بها",
            decision_type="deny",
        )
    # 3. Daily limit
    if daily_limit > 0 and (daily_spent + amount) > daily_limit:
        return PolicyDecision(
            allowed=False,
            reason=f"تجاوز الحد اليومي ({daily_spent + amount} > {daily_limit})",
            decision_type="deny",
        )
    # 4. Monthly limit
    if monthly_limit > 0 and (monthly_spent + amount) > monthly_limit:
        return PolicyDecision(
            allowed=False,
            reason=f"تجاوز الحد الشهري ({monthly_spent + amount} > {monthly_limit})",
            decision_type="deny",
        )
    # 5. Approval threshold — allowed but pending human sign-off
    if approval_required_above and amount > approval_required_above:
        return PolicyDecision(
            allowed=True,
            reason=f"المبلغ {amount} فوق حد الموافقة اليدوية",
            decision_type="requires_approval",
        )
    return PolicyDecision(
        allowed=True,
        reason="مطابق للسياسة",
        decision_type="allow",
    )
