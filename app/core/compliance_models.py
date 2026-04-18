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


def init_compliance_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return [
        "journal_entry_sequence",
        "audit_trail",
        "zatca_submission_queue",
        "ai_suggestion",
    ]
