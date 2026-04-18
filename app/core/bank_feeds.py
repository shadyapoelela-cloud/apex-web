"""
APEX — Bank feeds abstraction layer (Wave 13).

Pattern #137 from APEX_GLOBAL_RESEARCH_210: SAMA Open Banking
aggregation — the differentiator over Qoyod / Wafeq which still rely
on CSV upload. This module defines:

1. A provider-agnostic interface (`BankFeedProvider`) that Lean,
   Tarabut, Salt Edge, or a future national implementation can all
   satisfy. Each provider's concrete adapter lives outside this file
   so the core remains free of vendor HTTP clients.
2. Storage + lifecycle helpers over `bank_feed_connection` and
   `bank_feed_transaction`. Access/refresh tokens are encrypted at
   rest with `BANK_FEEDS_ENCRYPTION_KEY` (same pattern as TOTP + CSID).
3. A `MockBankFeedProvider` for local dev + tests so the whole
   pipeline can be exercised without any external account.

Every state transition (connect, sync, disconnect) emits an audit
event through the Wave 1 hash chain. Every write to the DB funnels
through this module — route handlers never touch the ORM directly.
"""

from __future__ import annotations

import abc
import base64
import hashlib
import logging
import os
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, Iterable, List, Optional

from cryptography.fernet import Fernet, InvalidToken

from app.core.auth_utils import JWT_SECRET
from app.core.compliance_models import BankFeedConnection, BankFeedTransaction
from app.core.compliance_service import write_audit_event
from app.phase1.models.platform_models import SessionLocal, gen_uuid

logger = logging.getLogger(__name__)

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in (
    "production",
    "prod",
)

# Public status constants.
STATUS_CONNECTED = "connected"
STATUS_REAUTH = "reauth_required"
STATUS_DISCONNECTED = "disconnected"
STATUS_ERROR = "error"

DIRECTION_DEBIT = "debit"
DIRECTION_CREDIT = "credit"


# ── Provider interface ────────────────────────────────────────────────


@dataclass
class ProviderAccount:
    """Metadata a provider returns after the user completes auth."""

    external_account_id: str
    bank_name: Optional[str] = None
    account_name: Optional[str] = None
    account_number_masked: Optional[str] = None
    iban_masked: Optional[str] = None
    currency: Optional[str] = None


@dataclass
class ProviderTransaction:
    """Normalized transaction the provider returns. Providers must map
    their response shape to this before handing it to sync_account()."""

    external_id: str
    txn_date: datetime
    amount: Decimal
    currency: str
    direction: str  # "debit" | "credit"
    description: Optional[str] = None
    counterparty: Optional[str] = None
    category_hint: Optional[str] = None
    raw: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ProviderAuthTokens:
    """Tokens returned by the provider auth flow. Any of these can be
    None — e.g. Lean returns no refresh_token for short-lived sandbox
    accounts."""

    access_token: str
    refresh_token: Optional[str] = None
    expires_at: Optional[datetime] = None


class BankFeedProvider(abc.ABC):
    """Abstract base that every concrete provider adapter extends.

    Implementations live outside this module (e.g.
    app/integrations/bank_feeds/lean.py) so the core is free of vendor
    HTTP clients — matching the Wave 5 retry-queue pattern."""

    name: str = "abstract"

    @abc.abstractmethod
    def fetch_transactions(
        self,
        *,
        tokens: ProviderAuthTokens,
        account: ProviderAccount,
        since: Optional[datetime],
    ) -> List[ProviderTransaction]:
        """Return the transactions that occurred on `account` at or
        after `since`. Implementations are expected to paginate."""


class MockBankFeedProvider(BankFeedProvider):
    """Dev + test-only provider. Returns a deterministic slate of
    transactions so the sync pipeline can be exercised offline."""

    name = "mock"

    def __init__(self, transactions: Optional[List[ProviderTransaction]] = None) -> None:
        self._transactions = transactions or [
            ProviderTransaction(
                external_id="MOCK-001",
                txn_date=datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc),
                amount=Decimal("1250.00"),
                currency="SAR",
                direction=DIRECTION_DEBIT,
                description="STC — Mobile bill",
                counterparty="STC",
                category_hint="Utilities",
                raw={"source": "mock"},
            ),
            ProviderTransaction(
                external_id="MOCK-002",
                txn_date=datetime(2026, 4, 3, 14, 30, tzinfo=timezone.utc),
                amount=Decimal("45000.00"),
                currency="SAR",
                direction=DIRECTION_CREDIT,
                description="Client payment — Invoice INV-023",
                counterparty="شركة الرياض للتجارة",
                category_hint="Revenue",
                raw={"source": "mock"},
            ),
        ]

    def fetch_transactions(
        self,
        *,
        tokens: ProviderAuthTokens,  # unused in mock
        account: ProviderAccount,  # unused in mock
        since: Optional[datetime],
    ) -> List[ProviderTransaction]:
        if since is None:
            return list(self._transactions)
        return [t for t in self._transactions if t.txn_date >= since]


_registered_providers: Dict[str, BankFeedProvider] = {}


def register_provider(name: str, provider: BankFeedProvider) -> None:
    """Register a concrete provider under its canonical name so sync
    flows can look it up by tag stored on the connection row."""
    _registered_providers[name] = provider


def get_provider(name: str) -> Optional[BankFeedProvider]:
    return _registered_providers.get(name)


def available_providers() -> List[str]:
    return sorted(_registered_providers.keys())


# Register the mock at import time — always safe.
register_provider("mock", MockBankFeedProvider())


# ── Encryption helpers ────────────────────────────────────────────────


def _get_fernet() -> Fernet:
    key = os.environ.get("BANK_FEEDS_ENCRYPTION_KEY")
    if key:
        return Fernet(key.encode("utf-8") if isinstance(key, str) else key)
    if _IS_PRODUCTION:
        raise RuntimeError(
            "BANK_FEEDS_ENCRYPTION_KEY env var is REQUIRED in production. "
            "Generate one with: python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
        )
    digest = hashlib.sha256(("bank_feeds:" + JWT_SECRET).encode("utf-8")).digest()
    derived = base64.urlsafe_b64encode(digest)
    logger.warning(
        "⚠ BANK_FEEDS_ENCRYPTION_KEY not set — deriving from JWT_SECRET (dev-only)."
    )
    return Fernet(derived)


def _encrypt(plaintext: str) -> str:
    return _get_fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def _decrypt(ciphertext: str) -> str:
    try:
        return _get_fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except InvalidToken as e:
        raise RuntimeError("Failed to decrypt bank-feeds token — key mismatch?") from e


# ── Public connection API ─────────────────────────────────────────────


@dataclass
class ConnectionInput:
    tenant_id: str
    provider: str
    account: ProviderAccount
    tokens: ProviderAuthTokens


def connect(req: ConnectionInput) -> str:
    """Persist a new connection. Returns the row id."""
    if req.provider not in _registered_providers:
        raise ValueError(
            f"provider {req.provider!r} not registered — "
            f"available: {available_providers()}"
        )
    if not req.tokens.access_token:
        raise ValueError("access_token is required")

    db = SessionLocal()
    try:
        row = BankFeedConnection(
            id=gen_uuid(),
            tenant_id=req.tenant_id,
            provider=req.provider,
            external_account_id=req.account.external_account_id,
            bank_name=req.account.bank_name,
            account_name=req.account.account_name,
            account_number_masked=req.account.account_number_masked,
            iban_masked=req.account.iban_masked,
            currency=req.account.currency,
            access_token_encrypted=_encrypt(req.tokens.access_token),
            refresh_token_encrypted=(
                _encrypt(req.tokens.refresh_token)
                if req.tokens.refresh_token
                else None
            ),
            token_expires_at=req.tokens.expires_at,
            status=STATUS_CONNECTED,
        )
        db.add(row)
        db.commit()
        row_id = row.id
    finally:
        db.close()

    write_audit_event(
        action="bank_feeds.connect",
        entity_type="bank_feed_connection",
        entity_id=row_id,
        metadata={
            "tenant_id": req.tenant_id,
            "provider": req.provider,
            "external_account_id": req.account.external_account_id,
        },
    )
    return row_id


def disconnect(
    connection_id: str,
    *,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> None:
    """Transition to disconnected. Retains the row + transactions for
    audit but clears the tokens so a stale session can't be replayed."""
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedConnection)
            .filter(BankFeedConnection.id == connection_id)
            .first()
        )
        if row is None:
            raise LookupError(f"connection {connection_id} not found")
        if row.status == STATUS_DISCONNECTED:
            return
        row.status = STATUS_DISCONNECTED
        row.access_token_encrypted = None
        row.refresh_token_encrypted = None
        row.token_expires_at = None
        db.commit()
        tenant = row.tenant_id
    finally:
        db.close()

    write_audit_event(
        action="bank_feeds.disconnect",
        actor_user_id=user_id,
        entity_type="bank_feed_connection",
        entity_id=connection_id,
        metadata={"tenant_id": tenant, "reason": reason},
    )


def sync_account(connection_id: str) -> Dict[str, Any]:
    """Pull new transactions from the provider and persist them.

    Returns {"fetched": N, "inserted": M, "duplicates": K}.
    Updates connection.last_sync_at and last_sync_txn_count.
    """
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedConnection)
            .filter(BankFeedConnection.id == connection_id)
            .first()
        )
        if row is None:
            raise LookupError(f"connection {connection_id} not found")
        if row.status != STATUS_CONNECTED:
            raise ValueError(
                f"cannot sync connection in status {row.status!r}"
            )

        provider = get_provider(row.provider)
        if provider is None:
            raise RuntimeError(
                f"provider {row.provider!r} is not registered in this process"
            )
        if row.access_token_encrypted is None:
            raise RuntimeError(
                f"connection {connection_id} has no stored access token"
            )

        tokens = ProviderAuthTokens(
            access_token=_decrypt(row.access_token_encrypted),
            refresh_token=(
                _decrypt(row.refresh_token_encrypted)
                if row.refresh_token_encrypted
                else None
            ),
            expires_at=row.token_expires_at,
        )
        account = ProviderAccount(
            external_account_id=row.external_account_id,
            bank_name=row.bank_name,
            account_name=row.account_name,
            account_number_masked=row.account_number_masked,
            iban_masked=row.iban_masked,
            currency=row.currency,
        )
        tenant_id = row.tenant_id
        row_id = row.id
    finally:
        db.close()

    try:
        fetched = provider.fetch_transactions(
            tokens=tokens, account=account, since=None
        )
    except Exception as e:
        logger.exception("bank_feeds sync: provider raised")
        _mark_sync_error(connection_id, str(e))
        raise

    inserted = 0
    duplicates = 0

    db = SessionLocal()
    try:
        for t in fetched:
            # Uniqueness guard — avoid duplicates without trusting an
            # integrity error round-trip.
            exists = (
                db.query(BankFeedTransaction.id)
                .filter(BankFeedTransaction.connection_id == row_id)
                .filter(BankFeedTransaction.external_id == t.external_id)
                .first()
            )
            if exists:
                duplicates += 1
                continue
            db.add(
                BankFeedTransaction(
                    id=gen_uuid(),
                    tenant_id=tenant_id,
                    connection_id=row_id,
                    external_id=t.external_id,
                    txn_date=t.txn_date,
                    amount=str(t.amount),
                    currency=t.currency,
                    direction=t.direction,
                    description=t.description,
                    counterparty=t.counterparty,
                    category_hint=t.category_hint,
                    raw_json=t.raw,
                )
            )
            inserted += 1
        db.commit()
    finally:
        db.close()

    # Update sync metadata on the connection.
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedConnection)
            .filter(BankFeedConnection.id == row_id)
            .first()
        )
        if row is not None:
            row.last_sync_at = datetime.now(timezone.utc)
            row.last_sync_txn_count = inserted
            row.last_sync_error = None
            db.commit()
    finally:
        db.close()

    summary = {
        "fetched": len(fetched),
        "inserted": inserted,
        "duplicates": duplicates,
    }
    write_audit_event(
        action="bank_feeds.sync",
        entity_type="bank_feed_connection",
        entity_id=row_id,
        metadata=summary,
    )
    return summary


def _mark_sync_error(connection_id: str, message: str) -> None:
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedConnection)
            .filter(BankFeedConnection.id == connection_id)
            .first()
        )
        if row is None:
            return
        row.status = STATUS_ERROR
        row.last_sync_error = message[:2000]
        db.commit()
    finally:
        db.close()


# ── Read-side helpers ────────────────────────────────────────────────


def get_connection(connection_id: str) -> Optional[Dict[str, Any]]:
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedConnection)
            .filter(BankFeedConnection.id == connection_id)
            .first()
        )
        if row is None:
            return None
        return _connection_to_dict(row)
    finally:
        db.close()


def list_connections(
    tenant_id: Optional[str] = None,
    provider: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        q = db.query(BankFeedConnection)
        if tenant_id is not None:
            q = q.filter(BankFeedConnection.tenant_id == tenant_id)
        if provider is not None:
            q = q.filter(BankFeedConnection.provider == provider)
        if status is not None:
            q = q.filter(BankFeedConnection.status == status)
        rows = (
            q.order_by(BankFeedConnection.updated_at.desc())
            .limit(limit)
            .all()
        )
        return [_connection_to_dict(r) for r in rows]
    finally:
        db.close()


def list_transactions(
    tenant_id: Optional[str] = None,
    connection_id: Optional[str] = None,
    unreconciled_only: bool = False,
    limit: int = 200,
) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        q = db.query(BankFeedTransaction)
        if tenant_id is not None:
            q = q.filter(BankFeedTransaction.tenant_id == tenant_id)
        if connection_id is not None:
            q = q.filter(BankFeedTransaction.connection_id == connection_id)
        if unreconciled_only:
            q = q.filter(BankFeedTransaction.matched_entity_id.is_(None))
        rows = (
            q.order_by(BankFeedTransaction.txn_date.desc())
            .limit(limit)
            .all()
        )
        return [_transaction_to_dict(r) for r in rows]
    finally:
        db.close()


def mark_reconciled(
    txn_id: str,
    *,
    entity_type: str,
    entity_id: str,
    user_id: Optional[str] = None,
) -> None:
    db = SessionLocal()
    try:
        row = (
            db.query(BankFeedTransaction)
            .filter(BankFeedTransaction.id == txn_id)
            .first()
        )
        if row is None:
            raise LookupError(f"transaction {txn_id} not found")
        row.matched_entity_type = entity_type
        row.matched_entity_id = entity_id
        row.matched_at = datetime.now(timezone.utc)
        row.matched_by = user_id
        db.commit()
    finally:
        db.close()

    write_audit_event(
        action="bank_feeds.reconcile",
        actor_user_id=user_id,
        entity_type="bank_feed_transaction",
        entity_id=txn_id,
        metadata={"matched_entity_type": entity_type, "matched_entity_id": entity_id},
    )


def stats(tenant_id: Optional[str] = None) -> Dict[str, int]:
    db = SessionLocal()
    try:
        cq = db.query(BankFeedConnection)
        if tenant_id is not None:
            cq = cq.filter(BankFeedConnection.tenant_id == tenant_id)
        conn_rows = cq.all()

        tq = db.query(BankFeedTransaction)
        if tenant_id is not None:
            tq = tq.filter(BankFeedTransaction.tenant_id == tenant_id)
        txn_rows = tq.all()

        by_status = {
            STATUS_CONNECTED: 0,
            STATUS_REAUTH: 0,
            STATUS_DISCONNECTED: 0,
            STATUS_ERROR: 0,
        }
        for c in conn_rows:
            by_status[c.status] = by_status.get(c.status, 0) + 1

        unreconciled = sum(1 for t in txn_rows if t.matched_entity_id is None)
        return {
            "connections_total": len(conn_rows),
            **by_status,
            "transactions_total": len(txn_rows),
            "transactions_unreconciled": unreconciled,
        }
    finally:
        db.close()


def _connection_to_dict(r: BankFeedConnection) -> Dict[str, Any]:
    """Metadata projection — never leaks token material."""
    return {
        "id": r.id,
        "tenant_id": r.tenant_id,
        "provider": r.provider,
        "external_account_id": r.external_account_id,
        "bank_name": r.bank_name,
        "account_name": r.account_name,
        "account_number_masked": r.account_number_masked,
        "iban_masked": r.iban_masked,
        "currency": r.currency,
        "status": r.status,
        "token_expires_at": (
            r.token_expires_at.isoformat() if r.token_expires_at else None
        ),
        "last_sync_at": r.last_sync_at.isoformat() if r.last_sync_at else None,
        "last_sync_error": r.last_sync_error,
        "last_sync_txn_count": r.last_sync_txn_count,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }


def _transaction_to_dict(r: BankFeedTransaction) -> Dict[str, Any]:
    try:
        amount_str = str(Decimal(r.amount))
    except (InvalidOperation, TypeError):
        amount_str = r.amount
    return {
        "id": r.id,
        "tenant_id": r.tenant_id,
        "connection_id": r.connection_id,
        "external_id": r.external_id,
        "txn_date": r.txn_date.isoformat() if r.txn_date else None,
        "amount": amount_str,
        "currency": r.currency,
        "direction": r.direction,
        "description": r.description,
        "counterparty": r.counterparty,
        "category_hint": r.category_hint,
        "matched_entity_type": r.matched_entity_type,
        "matched_entity_id": r.matched_entity_id,
        "matched_at": r.matched_at.isoformat() if r.matched_at else None,
        "matched_by": r.matched_by,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }
