"""
APEX — ZATCA CSID lifecycle (Wave 11 PR#1).

Pattern #121 + #173 from APEX_GLOBAL_RESEARCH_210:
- Certificate Stamp Identifier (CSID) lifecycle UX
- Keystore + rotation UX (encrypted vault + 60/30/7 day alerts)

Responsibilities:
- Register a CSID by storing its PEM cert + private key encrypted at
  rest with Fernet.
- Return decrypted cert/key ONLY through explicit helper for use by
  the submission pipeline. Never flow through any HTTP route.
- Track expiry — denormalize the notAfter date so the dashboard can
  query "expiring in 30 / 7 days" without parsing PEMs on every call.
- Revocation: mark revoked with actor + reason, never delete. The
  audit trail already covers every state transition.

No network I/O, no route imports. Pure function-on-ORM shape mirrors
the Wave 5 + Wave 7 modules.
"""

from __future__ import annotations

import base64
import hashlib
import logging
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from cryptography.fernet import Fernet, InvalidToken

from app.core.auth_utils import JWT_SECRET
from app.core.compliance_models import ZatcaCsid
from app.core.compliance_service import write_audit_event
from app.phase1.models.platform_models import SessionLocal, gen_uuid

logger = logging.getLogger(__name__)

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in (
    "production",
    "prod",
)

# Public status constants.
STATUS_ACTIVE = "active"
STATUS_EXPIRED = "expired"
STATUS_REVOKED = "revoked"
STATUS_RENEWING = "renewing"

ENV_SANDBOX = "sandbox"
ENV_PRODUCTION = "production"
_VALID_ENVIRONMENTS = (ENV_SANDBOX, ENV_PRODUCTION)


# ── Encryption helpers ───────────────────────────────────────────────


def _get_fernet() -> Fernet:
    """Same pattern as totp_service: explicit key in production, JWT-
    derived fallback in dev with a loud warning. A dedicated
    ZATCA_CERT_ENCRYPTION_KEY lets ops rotate cert encryption
    independently of TOTP secrets."""
    key = os.environ.get("ZATCA_CERT_ENCRYPTION_KEY")
    if key:
        return Fernet(key.encode("utf-8") if isinstance(key, str) else key)
    if _IS_PRODUCTION:
        raise RuntimeError(
            "ZATCA_CERT_ENCRYPTION_KEY env var is REQUIRED in production. "
            "Generate one with: python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
        )
    digest = hashlib.sha256(("zatca:" + JWT_SECRET).encode("utf-8")).digest()
    derived = base64.urlsafe_b64encode(digest)
    logger.warning(
        "⚠ ZATCA_CERT_ENCRYPTION_KEY not set — deriving from JWT_SECRET (dev-only)."
    )
    return Fernet(derived)


def _encrypt(plaintext: str) -> str:
    return _get_fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def _decrypt(ciphertext: str) -> str:
    try:
        return _get_fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except InvalidToken as e:
        raise RuntimeError("Failed to decrypt CSID material — key mismatch?") from e


# ── Public types ──────────────────────────────────────────────────────


@dataclass
class CsidRegistration:
    """Payload for register_csid(). cert_pem + private_key_pem are
    stored encrypted; cert_subject / serial / expires_at are metadata
    the caller should extract from the PEM before calling us."""

    tenant_id: str
    environment: str
    cert_pem: str
    private_key_pem: str
    expires_at: datetime

    cert_subject: Optional[str] = None
    cert_serial: Optional[str] = None
    issued_at: Optional[datetime] = None
    compliance_csid: Optional[str] = None


# ── Public API ────────────────────────────────────────────────────────


def register_csid(reg: CsidRegistration) -> str:
    """Persist a new CSID. Rotation policy: the caller is expected to
    revoke/rotate the previous active CSID for the same (tenant, env)
    before registering a new one. We log a warning if two actives
    would coexist, but don't block — the operator may legitimately
    want an overlap window."""
    if reg.environment not in _VALID_ENVIRONMENTS:
        raise ValueError(
            f"environment must be one of {_VALID_ENVIRONMENTS}, got {reg.environment!r}"
        )
    if not reg.cert_pem or not reg.private_key_pem:
        raise ValueError("cert_pem and private_key_pem are required")
    if not isinstance(reg.expires_at, datetime):
        raise ValueError("expires_at must be a datetime")

    db = SessionLocal()
    try:
        # Soft-block: if another active exists for the same (tenant, env),
        # log a warning so the operator sees it in the audit log.
        existing_active = (
            db.query(ZatcaCsid)
            .filter(ZatcaCsid.tenant_id == reg.tenant_id)
            .filter(ZatcaCsid.environment == reg.environment)
            .filter(ZatcaCsid.status == STATUS_ACTIVE)
            .first()
        )
        if existing_active is not None:
            logger.warning(
                "CSID register: another active CSID already exists for "
                "tenant=%s env=%s (id=%s).",
                reg.tenant_id,
                reg.environment,
                existing_active.id,
            )

        row = ZatcaCsid(
            id=gen_uuid(),
            tenant_id=reg.tenant_id,
            environment=reg.environment,
            cert_pem_encrypted=_encrypt(reg.cert_pem),
            private_key_pem_encrypted=_encrypt(reg.private_key_pem),
            cert_subject=(reg.cert_subject or "")[:300] if reg.cert_subject else None,
            cert_serial=(reg.cert_serial or "")[:120] if reg.cert_serial else None,
            issued_at=reg.issued_at,
            expires_at=reg.expires_at,
            status=STATUS_ACTIVE,
            compliance_csid=reg.compliance_csid,
        )
        db.add(row)
        db.commit()
        row_id = row.id
    finally:
        db.close()

    write_audit_event(
        action="zatca.csid.register",
        entity_type="zatca_csid",
        entity_id=row_id,
        metadata={
            "tenant_id": reg.tenant_id,
            "environment": reg.environment,
            "expires_at": reg.expires_at.isoformat(),
            "subject": reg.cert_subject,
        },
    )
    return row_id


def get_active_csid(tenant_id: str, environment: str) -> Optional[Dict[str, Any]]:
    """Return the active CSID including DECRYPTED material for the
    submission pipeline. This is the ONLY function that exposes the
    raw cert / key — callers must never leak the returned dict to
    logs or HTTP responses."""
    db = SessionLocal()
    try:
        row = (
            db.query(ZatcaCsid)
            .filter(ZatcaCsid.tenant_id == tenant_id)
            .filter(ZatcaCsid.environment == environment)
            .filter(ZatcaCsid.status == STATUS_ACTIVE)
            .order_by(ZatcaCsid.created_at.desc())
            .first()
        )
        if row is None:
            return None
        return {
            "id": row.id,
            "tenant_id": row.tenant_id,
            "environment": row.environment,
            "cert_pem": _decrypt(row.cert_pem_encrypted),
            "private_key_pem": _decrypt(row.private_key_pem_encrypted),
            "cert_subject": row.cert_subject,
            "cert_serial": row.cert_serial,
            "expires_at": row.expires_at,
            "compliance_csid": row.compliance_csid,
        }
    finally:
        db.close()


def get_row(csid_id: str) -> Optional[Dict[str, Any]]:
    """Metadata-only lookup. NEVER returns the decrypted cert / key."""
    db = SessionLocal()
    try:
        row = db.query(ZatcaCsid).filter(ZatcaCsid.id == csid_id).first()
        if row is None:
            return None
        return _row_to_dict(row)
    finally:
        db.close()


def list_csids(
    tenant_id: Optional[str] = None,
    environment: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
) -> List[Dict[str, Any]]:
    """List metadata rows with optional filters. Never decrypts."""
    db = SessionLocal()
    try:
        q = db.query(ZatcaCsid)
        if tenant_id is not None:
            q = q.filter(ZatcaCsid.tenant_id == tenant_id)
        if environment is not None:
            q = q.filter(ZatcaCsid.environment == environment)
        if status is not None:
            q = q.filter(ZatcaCsid.status == status)
        rows = q.order_by(ZatcaCsid.expires_at.asc()).limit(limit).all()
        return [_row_to_dict(r) for r in rows]
    finally:
        db.close()


def expiring_soon(
    days: int = 30, tenant_id: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Active CSIDs whose expires_at falls within the next `days`.
    Drives the compliance dashboard's "certificate expires in N days"
    banner + the 60/30/7-day alert scheduler (pattern #173)."""
    cutoff = datetime.now(timezone.utc) + timedelta(days=days)
    db = SessionLocal()
    try:
        q = (
            db.query(ZatcaCsid)
            .filter(ZatcaCsid.status == STATUS_ACTIVE)
            .filter(ZatcaCsid.expires_at <= cutoff)
        )
        if tenant_id is not None:
            q = q.filter(ZatcaCsid.tenant_id == tenant_id)
        rows = q.order_by(ZatcaCsid.expires_at.asc()).all()
        return [_row_to_dict(r) for r in rows]
    finally:
        db.close()


def mark_expired(csid_id: str) -> None:
    """Flip the status to expired. Normally called by a background
    scan; exposed here so admins can force it via the UI if ZATCA
    rejected a cert before its notAfter."""
    _transition(
        csid_id,
        new_status=STATUS_EXPIRED,
        audit_action="zatca.csid.expired",
    )


def mark_revoked(
    csid_id: str,
    *,
    user_id: Optional[str] = None,
    reason: Optional[str] = None,
) -> None:
    """Mark the row revoked. Retains the encrypted blobs so the audit
    binder can still prove WHAT was revoked; never delete."""
    db = SessionLocal()
    try:
        row = db.query(ZatcaCsid).filter(ZatcaCsid.id == csid_id).first()
        if row is None:
            raise LookupError(f"CSID {csid_id} not found")
        if row.status == STATUS_REVOKED:
            return
        row.status = STATUS_REVOKED
        row.revoked_at = datetime.now(timezone.utc)
        row.revoked_by = user_id
        row.revocation_reason = reason
        db.commit()
        tenant = row.tenant_id
    finally:
        db.close()

    write_audit_event(
        action="zatca.csid.revoked",
        actor_user_id=user_id,
        entity_type="zatca_csid",
        entity_id=csid_id,
        metadata={"tenant_id": tenant, "reason": reason},
    )


def mark_renewing(csid_id: str, *, user_id: Optional[str] = None) -> None:
    """Transition to renewing — used when a new cert is being
    provisioned but the current one is still serving. Caller flips
    back to active or expired explicitly."""
    _transition(
        csid_id,
        new_status=STATUS_RENEWING,
        audit_action="zatca.csid.renewing",
        user_id=user_id,
    )


def sweep_expired() -> int:
    """Batch job: flip any active row whose expires_at is in the past
    to status=expired. Returns the count. Runs from the background
    worker (future wave) but exposed for admin triggers too."""
    now = datetime.now(timezone.utc)
    db = SessionLocal()
    try:
        rows = (
            db.query(ZatcaCsid)
            .filter(ZatcaCsid.status == STATUS_ACTIVE)
            .filter(ZatcaCsid.expires_at <= now)
            .all()
        )
        ids = [r.id for r in rows]
        for r in rows:
            r.status = STATUS_EXPIRED
        db.commit()
    finally:
        db.close()

    for rid in ids:
        write_audit_event(
            action="zatca.csid.expired",
            entity_type="zatca_csid",
            entity_id=rid,
            metadata={"swept": True},
        )
    return len(ids)


def stats(tenant_id: Optional[str] = None) -> Dict[str, int]:
    db = SessionLocal()
    try:
        q = db.query(ZatcaCsid)
        if tenant_id is not None:
            q = q.filter(ZatcaCsid.tenant_id == tenant_id)
        rows = q.all()
        out = {STATUS_ACTIVE: 0, STATUS_EXPIRED: 0, STATUS_REVOKED: 0, STATUS_RENEWING: 0}
        for r in rows:
            out[r.status] = out.get(r.status, 0) + 1
        out["total"] = len(rows)
        return out
    finally:
        db.close()


# ── Internal helpers ──────────────────────────────────────────────────


def _transition(
    csid_id: str,
    *,
    new_status: str,
    audit_action: str,
    user_id: Optional[str] = None,
) -> None:
    db = SessionLocal()
    try:
        row = db.query(ZatcaCsid).filter(ZatcaCsid.id == csid_id).first()
        if row is None:
            raise LookupError(f"CSID {csid_id} not found")
        if row.status == new_status:
            return
        row.status = new_status
        db.commit()
        tenant = row.tenant_id
    finally:
        db.close()

    write_audit_event(
        action=audit_action,
        actor_user_id=user_id,
        entity_type="zatca_csid",
        entity_id=csid_id,
        metadata={"tenant_id": tenant, "new_status": new_status},
    )


def _row_to_dict(r: ZatcaCsid) -> Dict[str, Any]:
    """Metadata projection — omits encrypted blobs so no route ever
    accidentally leaks them. Callers that need the cert itself call
    get_active_csid()."""
    now = datetime.now(timezone.utc)
    days_to_expiry: Optional[int] = None
    if r.expires_at is not None:
        # SQLite drops tz on round-trip; treat naive expires_at as UTC.
        exp = r.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        days_to_expiry = int((exp - now).total_seconds() // 86400)
    return {
        "id": r.id,
        "tenant_id": r.tenant_id,
        "environment": r.environment,
        "cert_subject": r.cert_subject,
        "cert_serial": r.cert_serial,
        "issued_at": r.issued_at.isoformat() if r.issued_at else None,
        "expires_at": r.expires_at.isoformat() if r.expires_at else None,
        "days_to_expiry": days_to_expiry,
        "status": r.status,
        "compliance_csid": r.compliance_csid,
        "production_csid": r.production_csid,
        "revoked_at": r.revoked_at.isoformat() if r.revoked_at else None,
        "revoked_by": r.revoked_by,
        "revocation_reason": r.revocation_reason,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }
