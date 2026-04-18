"""Open Banking consent flow + shared data shapes.

OAuth2 authorization-code flow with PKCE — the bank redirects the user to
our callback, we exchange the code for a short-lived access token + a
long-lived refresh token, and persist the consent.

Consents in SAMA/UAE are typically valid for 180 days and must be
re-authorized via the bank's Strong Customer Authentication (SCA) flow.
"""

from __future__ import annotations

import logging
import os
import secrets
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from enum import Enum
from typing import Optional

logger = logging.getLogger(__name__)


class RegionProvider(str, Enum):
    SAMA = "sama"            # Saudi Arabian Monetary Authority
    UAE_OPEN_FINANCE = "uae_open_finance"
    PLAID = "plaid"          # Fallback for non-MENA


@dataclass
class ConsentSession:
    """A user's active consent with a given bank."""

    id: str
    tenant_id: Optional[str]
    provider: RegionProvider
    bank_id: str
    consent_id: str                       # issued by the bank
    access_token: str
    refresh_token: Optional[str]
    expires_at: datetime
    scope: list[str] = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def is_active(self) -> bool:
        return datetime.now(timezone.utc) < self.expires_at


@dataclass
class AccountInfo:
    """A bank account the user has consented to share."""

    account_id: str
    iban: Optional[str]
    account_type: str                     # 'current' | 'savings' | 'credit'
    currency: str
    balance: Optional[Decimal] = None
    balance_as_of: Optional[datetime] = None
    nickname: Optional[str] = None


@dataclass
class Transaction:
    """A single transaction fetched via Open Banking."""

    txn_id: str
    account_id: str
    amount: Decimal                       # signed (debit negative, credit positive)
    currency: str
    posted_date: date
    description: str
    merchant_name: Optional[str] = None
    category: Optional[str] = None
    raw: dict = field(default_factory=dict)


def generate_state() -> str:
    """Cryptographically strong OAuth2 state parameter."""
    return secrets.token_urlsafe(32)


def consent_expiry(days: int = 180) -> datetime:
    """Default 180-day expiry per SAMA / CBUAE guidelines."""
    return datetime.now(timezone.utc) + timedelta(days=days)


def build_authorize_url(
    base_url: str,
    client_id: str,
    redirect_uri: str,
    scope: list[str],
    state: str,
) -> str:
    """Build an OAuth2 authorize URL with standard query params."""
    from urllib.parse import urlencode

    qs = urlencode(
        {
            "response_type": "code",
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scope": " ".join(scope),
            "state": state,
        }
    )
    return f"{base_url.rstrip('/')}/auth/authorize?{qs}"
