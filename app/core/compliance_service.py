"""
APEX Platform — Compliance Core Services
═══════════════════════════════════════════════════════════════
Business-logic helpers for ZATCA Phase 2 / IFRS / SOCPA compliance.

Provides:
  - next_journal_entry_number(client_id, fiscal_year): atomic counter.
    Gap-free sequential numbering required by ZATCA. Uses SELECT ... FOR
    UPDATE on PostgreSQL (automatic lock on SQLite for dev).
  - write_audit_event(action, ...): appends to the immutable audit_trail
    with SHA-256 hash chaining (tamper-evident).
  - verify_audit_chain(since_id?): walks the chain and verifies each
    row's hash matches SHA-256(prev_hash || canonical_payload).
"""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy.exc import IntegrityError

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.core.compliance_models import JournalEntrySequence, AuditTrail

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
# Journal Entry Sequence
# ═══════════════════════════════════════════════════════════════


def next_journal_entry_number(client_id: str, fiscal_year: str, prefix: str = "JE") -> dict:
    """
    Atomically reserve the next journal-entry number for a client/year.
    Returns {"number": "JE-2026-00001", "sequence": 1, "prefix": "JE", "fiscal_year": "2026"}.

    Gap-free guarantee: only one caller gets each number. Other callers
    wait on the row lock. If the transaction rolls back, the number is
    LOST (never reissued) — this is correct behaviour per ZATCA: numbers
    represent intent, not successful posting.
    """
    if not client_id or not fiscal_year:
        raise ValueError("client_id and fiscal_year are required")
    if len(fiscal_year) != 4 or not fiscal_year.isdigit():
        raise ValueError("fiscal_year must be a 4-digit year, e.g. '2026'")

    db = SessionLocal()
    try:
        # Try INSERT then UPDATE (upsert). Fall back to SELECT on race.
        row = (
            db.query(JournalEntrySequence)
            .filter(
                JournalEntrySequence.client_id == client_id,
                JournalEntrySequence.fiscal_year == fiscal_year,
            )
            .with_for_update()
            .one_or_none()
        )
        if row is None:
            row = JournalEntrySequence(
                id=gen_uuid(),
                client_id=client_id,
                fiscal_year=fiscal_year,
                last_number=0,
                prefix=prefix,
            )
            db.add(row)
            try:
                db.flush()  # emit INSERT to catch unique-constraint races
            except IntegrityError:
                db.rollback()
                # another transaction won — re-read with lock
                row = (
                    db.query(JournalEntrySequence)
                    .filter(
                        JournalEntrySequence.client_id == client_id,
                        JournalEntrySequence.fiscal_year == fiscal_year,
                    )
                    .with_for_update()
                    .one()
                )
        row.last_number = (row.last_number or 0) + 1
        row.updated_at = datetime.now(timezone.utc)
        number = row.last_number
        eff_prefix = row.prefix or prefix
        db.commit()
        return {
            "number": f"{eff_prefix}-{fiscal_year}-{number:05d}",
            "sequence": number,
            "prefix": eff_prefix,
            "fiscal_year": fiscal_year,
            "client_id": client_id,
        }
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def peek_journal_entry_sequence(client_id: str, fiscal_year: str) -> dict:
    """Return current sequence state WITHOUT incrementing. Read-only."""
    db = SessionLocal()
    try:
        row = (
            db.query(JournalEntrySequence)
            .filter(
                JournalEntrySequence.client_id == client_id,
                JournalEntrySequence.fiscal_year == fiscal_year,
            )
            .one_or_none()
        )
        if row is None:
            return {"client_id": client_id, "fiscal_year": fiscal_year, "last_number": 0, "prefix": "JE"}
        return {
            "client_id": client_id,
            "fiscal_year": fiscal_year,
            "last_number": row.last_number,
            "prefix": row.prefix,
            "updated_at": row.updated_at.isoformat() if row.updated_at else None,
        }
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════════
# Audit Trail (immutable, hash-chained)
# ═══════════════════════════════════════════════════════════════


def _canonical_payload(
    actor_user_id: Optional[str],
    action: str,
    entity_type: Optional[str],
    entity_id: Optional[str],
    before_json: Any,
    after_json: Any,
    metadata_json: Any,
    chain_seq: int,
) -> str:
    """Deterministic JSON serialization for hashing.
    Uses chain_seq (integer) instead of a timestamp so the hash is stable
    across DB round-trips that may strip tzinfo or microseconds."""
    payload = {
        "actor_user_id": actor_user_id,
        "action": action,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "before": before_json,
        "after": after_json,
        "metadata": metadata_json,
        "chain_seq": chain_seq,
    }
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False, default=str)


def write_audit_event(
    action: str,
    *,
    actor_user_id: Optional[str] = None,
    actor_ip: Optional[str] = None,
    actor_user_agent: Optional[str] = None,
    entity_type: Optional[str] = None,
    entity_id: Optional[str] = None,
    before: Any = None,
    after: Any = None,
    metadata: Any = None,
) -> str:
    """
    Append an immutable audit event. Returns the row's SHA-256 hash.
    Never raises to the caller — the audit write is best-effort but logged.
    """
    if not action or len(action) > 80:
        raise ValueError("action is required and must be <= 80 chars")

    db = SessionLocal()
    try:
        # Previous row — latest by chain_seq (not created_at, to avoid
        # DB-precision ambiguity).
        prev = (
            db.query(AuditTrail.this_hash, AuditTrail.chain_seq)
            .order_by(AuditTrail.chain_seq.desc(), AuditTrail.id.desc())
            .limit(1)
            .one_or_none()
        )
        prev_hash = prev[0] if prev else None
        next_seq = (prev[1] + 1) if prev else 1

        canonical = _canonical_payload(
            actor_user_id, action, entity_type, entity_id, before, after, metadata, next_seq
        )
        chain_input = (prev_hash or "") + "|" + canonical
        this_hash = hashlib.sha256(chain_input.encode("utf-8")).hexdigest()

        row = AuditTrail(
            id=gen_uuid(),
            actor_user_id=actor_user_id,
            actor_ip=actor_ip[:64] if actor_ip else None,
            actor_user_agent=actor_user_agent[:300] if actor_user_agent else None,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            before_json=before,
            after_json=after,
            metadata_json=metadata,
            prev_hash=prev_hash,
            this_hash=this_hash,
            chain_seq=next_seq,
            created_at=datetime.now(timezone.utc),
        )
        db.add(row)
        db.commit()
        return this_hash
    except Exception:
        db.rollback()
        logger.exception("audit trail write failed for action=%s", action)
        return ""  # never propagate — audit is best-effort
    finally:
        db.close()


def verify_audit_chain(limit: int = 1000) -> dict:
    """
    Walk the audit chain (newest first up to `limit`) and verify each row.
    Returns {"ok": bool, "verified": int, "first_mismatch": {...} | None}.
    """
    db = SessionLocal()
    try:
        rows = (
            db.query(AuditTrail)
            .order_by(AuditTrail.chain_seq.asc(), AuditTrail.id.asc())
            .limit(limit)
            .all()
        )
        prev_hash: Optional[str] = None
        expected_seq = 1
        for r in rows:
            if r.prev_hash != prev_hash:
                return {
                    "ok": False,
                    "verified": 0,
                    "first_mismatch": {
                        "id": r.id,
                        "expected_prev": prev_hash,
                        "actual_prev": r.prev_hash,
                    },
                }
            if r.chain_seq != expected_seq:
                return {
                    "ok": False,
                    "verified": 0,
                    "first_mismatch": {
                        "id": r.id,
                        "expected_seq": expected_seq,
                        "actual_seq": r.chain_seq,
                    },
                }
            canonical = _canonical_payload(
                r.actor_user_id,
                r.action,
                r.entity_type,
                r.entity_id,
                r.before_json,
                r.after_json,
                r.metadata_json,
                r.chain_seq,
            )
            chain_input = (prev_hash or "") + "|" + canonical
            expected = hashlib.sha256(chain_input.encode("utf-8")).hexdigest()
            if expected != r.this_hash:
                return {
                    "ok": False,
                    "verified": 0,
                    "first_mismatch": {
                        "id": r.id,
                        "expected_hash": expected,
                        "actual_hash": r.this_hash,
                    },
                }
            prev_hash = r.this_hash
            expected_seq += 1
        return {"ok": True, "verified": len(rows), "first_mismatch": None}
    finally:
        db.close()
