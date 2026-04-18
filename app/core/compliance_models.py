"""
APEX Platform — Compliance & Audit-Trail Core Models
═══════════════════════════════════════════════════════════════
ZATCA Phase 2 / IFRS / SOCPA compliance primitives.

Tables:
  - journal_entry_sequence: gap-free per-client/per-fiscal-year counter.
    Required by ZATCA and most GAAPs: journal entry numbers must be
    consecutive, no gaps allowed. Obtaining a new number is an atomic
    SELECT ... FOR UPDATE operation on this table.
  - audit_trail: immutable append-only event log for sensitive actions.
    Never updated, never deleted. Every write carries a hash chaining
    it to the previous event (tamper-evidence).
"""

from sqlalchemy import (
    Column,
    String,
    Integer,
    BigInteger,
    DateTime,
    Text,
    JSON,
    Index,
    UniqueConstraint,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class JournalEntrySequence(Base):
    """
    Gap-free counter for journal entries.
    One row per (client_id, fiscal_year). Counter is incremented atomically.
    """

    __tablename__ = "journal_entry_sequence"
    __table_args__ = (
        UniqueConstraint("client_id", "fiscal_year", name="uq_je_seq_client_year"),
        Index("ix_je_seq_client_year", "client_id", "fiscal_year"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), nullable=False, index=True)
    fiscal_year = Column(String(4), nullable=False)  # e.g. "2026"
    last_number = Column(Integer, default=0, nullable=False)
    prefix = Column(String(10), default="JE", nullable=False)  # JE-2026-00001
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class AuditTrail(Base):
    """
    Immutable append-only audit log.
    Writes ONLY; no updates, no deletes.
    Each row carries the SHA-256 hash of the previous row in chronological
    order, forming a tamper-evident chain.
    """

    __tablename__ = "audit_trail"
    __table_args__ = (
        Index("ix_audit_trail_actor", "actor_user_id"),
        Index("ix_audit_trail_entity", "entity_type", "entity_id"),
        Index("ix_audit_trail_action", "action"),
        Index("ix_audit_trail_created", "created_at"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    actor_user_id = Column(String(36), nullable=True, index=True)
    actor_ip = Column(String(64), nullable=True)
    actor_user_agent = Column(String(300), nullable=True)

    action = Column(String(80), nullable=False)
    # examples: user.login, plan.upgrade, result.lock, je.create, admin.reset_db

    entity_type = Column(String(50), nullable=True)  # user, plan, client, result, je
    entity_id = Column(String(36), nullable=True)

    # before/after snapshots (compact JSON diff)
    before_json = Column(JSON, nullable=True)
    after_json = Column(JSON, nullable=True)
    metadata_json = Column(JSON, nullable=True)

    # hash chaining (SHA-256 of prev row's hash + this row's canonical payload)
    prev_hash = Column(String(64), nullable=True)
    this_hash = Column(String(64), nullable=False)

    # Monotonic integer counter used in hash input — avoids datetime round-trip
    # precision issues across DB backends. Populated by the service layer.
    chain_seq = Column(BigInteger, nullable=False, default=0)

    created_at = Column(DateTime, default=utcnow, nullable=False)


class ZatcaSubmissionQueue(Base):
    """
    Persisted retry queue for ZATCA Fatoora submissions (Wave 5 PR#1).

    Invoices that fail to clear or that we can't even submit (because
    the Fatoora gateway is down) land here with an exponential backoff
    schedule. A worker — or a manual /zatca/queue/process call — picks
    up rows whose next_retry_at has passed and re-attempts submission.

    Status lifecycle:
        pending  → next_retry_at <= now, eligible for a new attempt.
        cleared  → ZATCA accepted it. Terminal.
        giveup   → exceeded max_attempts. Terminal. Requires human action.
        draft    → enqueued but never attempted yet.
    """

    __tablename__ = "zatca_submission_queue"
    __table_args__ = (
        Index("ix_zatca_queue_status_next_retry", "status", "next_retry_at"),
        Index("ix_zatca_queue_invoice", "invoice_id"),
        Index("ix_zatca_queue_tenant", "tenant_id"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=True, index=True)
    invoice_id = Column(String(36), nullable=False, index=True)
    payload = Column(JSON, nullable=False)  # serialized UBL XML or full request

    status = Column(String(20), nullable=False, default="draft")
    attempts = Column(Integer, nullable=False, default=0)
    max_attempts = Column(Integer, nullable=False, default=7)

    next_retry_at = Column(DateTime, nullable=True, index=True)
    last_attempt_at = Column(DateTime, nullable=True)
    last_error_code = Column(String(80), nullable=True)
    last_error_message = Column(Text, nullable=True)

    cleared_uuid = Column(String(64), nullable=True)  # ZATCA-issued clearance uuid
    cleared_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class AiSuggestion(Base):
    """
    Confidence-gated AI suggestion queue (Wave 7 PR#1).

    Every AI proposal — whether from the Copilot, the COA classifier,
    the OCR pipeline, or any future agent — lands here before being
    applied to real data. The gate_decision column is set by the
    guardrail at write time:

      auto_applied       — confidence >= min_confidence AND NOT destructive.
      needs_approval     — confidence below threshold OR destructive action.
      rejected           — guardrail rejected outright (confidence <=0 etc.).

    Humans transition needs_approval rows to approved/rejected with an
    audit event; auto_applied rows can still be reverted by a subsequent
    manual rejection.
    """

    __tablename__ = "ai_suggestion"
    __table_args__ = (
        Index("ix_ai_suggestion_status", "status"),
        Index("ix_ai_suggestion_tenant", "tenant_id"),
        Index("ix_ai_suggestion_created", "created_at"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=True, index=True)
    source = Column(String(60), nullable=False)  # "copilot" | "coa" | "ocr" | ...
    action_type = Column(String(60), nullable=False)  # e.g. "categorize_txn"

    # Subject of the suggestion — free-form so each source owns its shape.
    target_type = Column(String(60), nullable=True)  # "transaction" | "invoice" | ...
    target_id = Column(String(64), nullable=True)

    # Full structured suggestion (before → after diff).
    before_json = Column(JSON, nullable=True)
    after_json = Column(JSON, nullable=False)
    reasoning = Column(Text, nullable=True)  # human-readable AI explanation

    # The confidence score the model reported. Accept [0.0, 1.0].
    confidence = Column(Integer, nullable=False)  # stored as permille (0-1000)
    destructive = Column(Integer, nullable=False, default=0)  # 0/1 flag

    # Lifecycle state.
    status = Column(String(20), nullable=False)
    gate_reason = Column(String(120), nullable=True)  # why gate decided as it did

    # Approval details.
    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    rejected_by = Column(String(36), nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    rejection_reason = Column(Text, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class ZatcaCsid(Base):
    """
    ZATCA Fatoora CSID (Cryptographic Stamp Identifier) lifecycle
    (Wave 11). Pattern #121 from APEX_GLOBAL_RESEARCH_210 — "CSID
    lifecycle UX (issue / renew / sandbox↔prod)".

    Security model:
    - cert_pem_encrypted and private_key_pem_encrypted are stored
      Fernet-encrypted at rest (same key derivation as TOTP —
      ZATCA_CERT_ENCRYPTION_KEY in production, derived from
      JWT_SECRET in dev with a logged warning).
    - The raw cert / key only surface via decrypt helpers in
      zatca_csid.py. Routes never return them in API responses.

    Expiry handling: expires_at is denormalized from the cert's
    notAfter field at register time so dashboard queries can filter
    by "expiring in N days" without round-tripping through the
    crypto library for every row.
    """

    __tablename__ = "zatca_csid"
    __table_args__ = (
        Index("ix_zatca_csid_tenant_env", "tenant_id", "environment"),
        Index("ix_zatca_csid_status", "status"),
        Index("ix_zatca_csid_expires_at", "expires_at"),
        UniqueConstraint(
            "tenant_id",
            "environment",
            "cert_serial",
            name="uq_zatca_csid_tenant_env_serial",
        ),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=False, index=True)
    environment = Column(String(20), nullable=False)  # "sandbox" | "production"

    cert_pem_encrypted = Column(Text, nullable=False)
    private_key_pem_encrypted = Column(Text, nullable=False)

    cert_subject = Column(String(300), nullable=True)  # CN / O / OU summary
    cert_serial = Column(String(120), nullable=True)  # issuer-assigned serial
    issued_at = Column(DateTime, nullable=True)       # cert.notBefore
    expires_at = Column(DateTime, nullable=False)     # cert.notAfter

    status = Column(String(20), nullable=False, default="active")
    # active | expired | revoked | renewing

    compliance_csid = Column(String(120), nullable=True)  # ZATCA-issued id
    production_csid = Column(String(120), nullable=True)  # after prod onboarding

    revoked_at = Column(DateTime, nullable=True)
    revoked_by = Column(String(36), nullable=True)
    revocation_reason = Column(Text, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class BankFeedConnection(Base):
    """
    Bank-feed connection to an external aggregator (Wave 13).

    Pattern #137 from APEX_GLOBAL_RESEARCH_210: SAMA Open Banking
    aggregation via Lean / Tarabut / Salt Edge — the real differentiator
    over CSV-upload competitors (Qoyod / Wafeq).

    One row per connected bank account. Access tokens + refresh tokens
    are stored Fernet-encrypted at rest with BANK_FEEDS_ENCRYPTION_KEY
    (falls back to JWT_SECRET-derived in dev, same pattern as TOTP +
    CSID modules).
    """

    __tablename__ = "bank_feed_connection"
    __table_args__ = (
        Index("ix_bfc_tenant", "tenant_id"),
        Index("ix_bfc_status", "status"),
        Index("ix_bfc_provider", "provider"),
        UniqueConstraint(
            "tenant_id",
            "provider",
            "external_account_id",
            name="uq_bfc_tenant_provider_account",
        ),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=False, index=True)
    provider = Column(String(30), nullable=False)  # lean | tarabut | saltedge | mock
    external_account_id = Column(String(120), nullable=False)

    # Metadata the provider returned about the account.
    bank_name = Column(String(120), nullable=True)
    account_name = Column(String(200), nullable=True)
    account_number_masked = Column(String(60), nullable=True)
    iban_masked = Column(String(60), nullable=True)
    currency = Column(String(3), nullable=True)

    # Encrypted tokens (provider-specific). Plaintext NEVER leaves the
    # server side — get_decrypted_token() is the only reader, used by
    # the sync path.
    access_token_encrypted = Column(Text, nullable=True)
    refresh_token_encrypted = Column(Text, nullable=True)
    token_expires_at = Column(DateTime, nullable=True)

    status = Column(String(20), nullable=False, default="connected")
    # connected | reauth_required | disconnected | error

    last_sync_at = Column(DateTime, nullable=True)
    last_sync_error = Column(Text, nullable=True)
    last_sync_txn_count = Column(Integer, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class BankFeedTransaction(Base):
    """
    Normalized transaction pulled from a provider via BankFeedConnection.

    Provider-specific raw payloads are preserved in `raw_json` so we
    can re-run the normalization if we find a bug, without re-hitting
    the provider's rate limit.
    """

    __tablename__ = "bank_feed_transaction"
    __table_args__ = (
        Index("ix_bft_connection_date", "connection_id", "txn_date"),
        Index("ix_bft_tenant_date", "tenant_id", "txn_date"),
        UniqueConstraint(
            "connection_id",
            "external_id",
            name="uq_bft_connection_external_id",
        ),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), nullable=False, index=True)
    connection_id = Column(String(36), nullable=False, index=True)

    external_id = Column(String(120), nullable=False)  # provider's txn id

    txn_date = Column(DateTime, nullable=False)
    amount = Column(String(40), nullable=False)  # decimal string for exactness
    currency = Column(String(3), nullable=False)
    description = Column(Text, nullable=True)
    counterparty = Column(String(200), nullable=True)
    direction = Column(String(10), nullable=False)  # "debit" | "credit"

    # Suggested GL category from the provider (if any) + a confidence
    # score so downstream AI classifiers know whether to trust it.
    category_hint = Column(String(80), nullable=True)

    # Reconciliation pointer — set when a user (or AI) matches this row
    # to an existing journal entry or invoice.
    matched_entity_type = Column(String(40), nullable=True)  # "journal_entry" | "invoice"
    matched_entity_id = Column(String(36), nullable=True)
    matched_at = Column(DateTime, nullable=True)
    matched_by = Column(String(36), nullable=True)

    raw_json = Column(JSON, nullable=True)  # provider's untouched payload

    created_at = Column(DateTime, default=utcnow, nullable=False)


def init_compliance_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return [
        "journal_entry_sequence",
        "audit_trail",
        "zatca_submission_queue",
        "ai_suggestion",
        "zatca_csid",
        "bank_feed_connection",
        "bank_feed_transaction",
    ]
