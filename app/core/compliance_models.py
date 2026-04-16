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


def init_compliance_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["journal_entry_sequence", "audit_trail"]
