"""Open Banking integration — SAMA (KSA) + UAE Open Finance.

Both regulators define an OAuth2 + FAPI-compliant API for AISPs
(Account Information Service Providers) and PISPs (Payment Initiation
Service Providers). APEX integrates as an AISP to fetch balances +
transactions automatically.

Structure:
  • sama_client.py   — SAMA-specific endpoints (balances, transactions).
  • uae_client.py    — UAE CBUAE endpoints.
  • consent.py       — common OAuth2 consent-flow helpers.

All clients share the same ConsentSession + AccountInfo shapes so the
UI layer can work provider-agnostic.
"""

from app.integrations.open_banking.consent import (  # noqa: F401
    ConsentSession,
    Transaction,
    AccountInfo,
    RegionProvider,
)

__all__ = ["ConsentSession", "Transaction", "AccountInfo", "RegionProvider"]
