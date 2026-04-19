"""Corporate Cards integration — Yuze (UAE) + NymCard (MENA-wide).

Lets employees get virtual cards with per-employee limits and
per-merchant-category policy checks. Transactions auto-post to the GL.

This package:
  • cards_service.py — cross-provider facade: issue_card, set_limits,
    check_policy, sync_transactions.
  • yuze_client.py    — Yuze provider implementation.
  • nymcard_client.py — NymCard provider implementation.
  • models.py         — SQLAlchemy models (CorporateCard, CardTransaction,
                          CardPolicy).
"""

from app.integrations.corporate_cards.cards_service import (  # noqa: F401
    CardProvider,
    IssueCardRequest,
    IssueCardResult,
    issue_card,
    set_card_limits,
    check_transaction_policy,
)

__all__ = [
    "CardProvider",
    "IssueCardRequest",
    "IssueCardResult",
    "issue_card",
    "set_card_limits",
    "check_transaction_policy",
]
