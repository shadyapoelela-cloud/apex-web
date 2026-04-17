"""Comprehensive audit log middleware — SOC 2 + PDPL compliant.

Logs every state-changing HTTP request (POST/PUT/PATCH/DELETE) with:
  • who: user_id from JWT, tenant_id from ContextVar, client IP
  • what: method, path, status code, duration
  • why: X-Request-Id (if provided) for tracing to business action
  • changes: redacted body preview (PII + secrets stripped)

Storage model:
  - Writes to the `audit_log` table. On failure, falls back to structured
    JSON log so the request itself never fails because of audit.
  - Async by design — captured synchronously, persisted in a background task.

Non-goals:
  - Not a general application log — use standard logging for that.
  - Not for debugging — for compliance. Never contains full request body.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import Request, Response
from sqlalchemy import Column, DateTime, Integer, String, Text, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.tenant_context import current_tenant

logger = logging.getLogger("apex.audit")

AUDIT_ENABLED = os.environ.get("AUDIT_LOG_ENABLED", "true").lower() == "true"
AUDIT_SAMPLE_RATE = float(os.environ.get("AUDIT_SAMPLE_RATE", "1.0"))
AUDIT_DB_URL = os.environ.get("AUDIT_DATABASE_URL", "")  # separate DB recommended

# Methods that need auditing.
_MUTATING_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# Paths we never audit (noise, health probes, the audit endpoint itself).
_EXCLUDED_PATH_PREFIXES = (
    "/health",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/admin/audit-log",   # reading the log shouldn't generate a log entry
    "/integrations/whatsapp/webhook",  # inbound webhooks are noisy
)


# ── PII / secret redaction ─────────────────────────────────


_SENSITIVE_FIELDS = {
    "password",
    "new_password",
    "current_password",
    "confirm_password",
    "password_hash",
    "id_token",
    "identity_token",
    "authorization_code",
    "access_token",
    "refresh_token",
    "token",
    "token_hash",
    "csrf_token",
    "api_key",
    "secret",
    "client_secret",
    "card_number",
    "cvv",
    "cvc",
    "verification_code",
    "otp",
}

_PII_FIELDS = {
    "national_id",
    "iqama_number",
    "emirates_id",
    "bank_iban",
    "iban",
    "tax_id",
    "vat_number",
    "cr_number",
}


def _redact_value(key: str, value: Any) -> Any:
    k = key.lower()
    if k in _SENSITIVE_FIELDS:
        return "***REDACTED***"
    if k in _PII_FIELDS and isinstance(value, str) and len(value) > 4:
        return value[:2] + "*" * (len(value) - 4) + value[-2:]
    return value


def redact(obj: Any) -> Any:
    """Walk a JSON-able object and redact sensitive/PII values.

    Preserves structure so auditors can see "a password was submitted"
    without ever storing the plaintext.
    """
    if isinstance(obj, dict):
        return {k: redact(_redact_value(k, v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact(v) for v in obj]
    return obj


# ── Model ──────────────────────────────────────────────────

# Use its own Base so it doesn't entangle with phase models — the audit
# log can live in a separate database for compliance.
AuditBase = declarative_base()


class AuditLogEntry(AuditBase):
    __tablename__ = "audit_log"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)

    # Actor
    user_id = Column(String(36), nullable=True, index=True)
    tenant_id = Column(String(36), nullable=True, index=True)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)

    # Request
    method = Column(String(10), nullable=False)
    path = Column(String(500), nullable=False, index=True)
    query_string = Column(String(1000), nullable=True)
    request_id = Column(String(64), nullable=True)  # from X-Request-Id

    # Response
    status_code = Column(Integer, nullable=False)
    duration_ms = Column(Integer, nullable=False)

    # Change summary
    body_preview = Column(Text, nullable=True)   # redacted JSON, first 2KB
    response_summary = Column(Text, nullable=True)  # redacted status + key


# ── Storage ───────────────────────────────────────────────


_engine = None
_Session = None


def _get_session_factory():
    """Lazy-initialize the audit DB engine. Falls back to main DB if no
    AUDIT_DATABASE_URL is set."""
    global _engine, _Session
    if _Session is not None:
        return _Session

    url = AUDIT_DB_URL
    if not url:
        # Fall back to main DB — same connection string as everything else.
        url = os.environ.get("DATABASE_URL", "sqlite:///apex.db")

    connect_args = {"check_same_thread": False} if url.startswith("sqlite") else {}
    _engine = create_engine(url, connect_args=connect_args, future=True)
    AuditBase.metadata.create_all(_engine)  # idempotent
    _Session = sessionmaker(bind=_engine, expire_on_commit=False, future=True)
    return _Session


def _persist(entry_dict: dict) -> None:
    """Persist one audit entry. Never raises."""
    try:
        Session = _get_session_factory()
        with Session() as s:
            s.add(AuditLogEntry(**entry_dict))
            s.commit()
    except Exception as e:
        logger.warning("audit persist failed: %s — falling back to log line", e)
        logger.info("AUDIT %s", json.dumps(entry_dict, default=str))


# ── Middleware ────────────────────────────────────────────


def _client_ip(request: Request) -> str:
    for header in ("cf-connecting-ip", "x-real-ip", "x-forwarded-for"):
        v = request.headers.get(header)
        if v:
            return v.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _user_id_from_auth(request: Request) -> Optional[str]:
    """Peek at the JWT sub without verifying signature — the auth layer
    verifies later. For audit we only need the claim."""
    auth = request.headers.get("authorization", "")
    if not auth.lower().startswith("bearer "):
        return None
    try:
        import jwt

        claims = jwt.decode(auth[7:].strip(), options={"verify_signature": False})
        return str(claims.get("sub") or claims.get("user_id") or "") or None
    except Exception:
        return None


def _should_audit(request: Request) -> bool:
    if not AUDIT_ENABLED:
        return False
    if request.method not in _MUTATING_METHODS:
        return False
    path = request.url.path or "/"
    if any(path.startswith(p) for p in _EXCLUDED_PATH_PREFIXES):
        return False
    if AUDIT_SAMPLE_RATE < 1.0:
        import random

        if random.random() > AUDIT_SAMPLE_RATE:
            return False
    return True


class AuditLogMiddleware(BaseHTTPMiddleware):
    """Capture an audit entry for every state-changing request.

    Ordered AFTER TenantContextMiddleware so `current_tenant()` is populated
    by the time we read it.
    """

    async def dispatch(self, request: Request, call_next):
        if not _should_audit(request):
            return await call_next(request)

        start = time.perf_counter()
        # Peek at body before the route consumes it — Starlette docs pattern.
        body_bytes = await request.body()
        body_preview = _body_preview(body_bytes, request.headers.get("content-type", ""))

        async def receive() -> dict:
            return {"type": "http.request", "body": body_bytes}

        request = Request(request.scope, receive)
        response: Response = await call_next(request)

        duration_ms = int((time.perf_counter() - start) * 1000)

        entry = {
            "id": str(uuid.uuid4()),
            "timestamp": datetime.now(timezone.utc),
            "user_id": _user_id_from_auth(request),
            "tenant_id": current_tenant(),
            "ip_address": _client_ip(request),
            "user_agent": (request.headers.get("user-agent") or "")[:500],
            "method": request.method,
            "path": (request.url.path or "")[:500],
            "query_string": (request.url.query or "")[:1000] or None,
            "request_id": request.headers.get("x-request-id"),
            "status_code": response.status_code,
            "duration_ms": duration_ms,
            "body_preview": body_preview,
            "response_summary": f"status={response.status_code}",
        }

        # Persist in the background — don't hold up the response.
        try:
            loop = asyncio.get_event_loop()
            loop.run_in_executor(None, _persist, entry)
        except RuntimeError:
            # No running loop (e.g. sync test client). Persist synchronously.
            _persist(entry)

        return response


def _body_preview(body: bytes, content_type: str, max_size: int = 2048) -> Optional[str]:
    if not body:
        return None
    if "application/json" in content_type:
        try:
            obj = json.loads(body.decode("utf-8", errors="replace"))
            redacted = redact(obj)
            text = json.dumps(redacted, ensure_ascii=False, default=str)
            return text[:max_size]
        except Exception:
            pass
    # Not JSON (form, multipart, raw): store a byte-size hint only.
    return f"<{len(body)} bytes, content-type={content_type or 'unknown'}>"


# ── Query helpers for the admin UI / SOC 2 export ─────────


def query_audit_log(
    *,
    user_id: Optional[str] = None,
    tenant_id: Optional[str] = None,
    path_prefix: Optional[str] = None,
    since: Optional[datetime] = None,
    until: Optional[datetime] = None,
    limit: int = 100,
) -> list[AuditLogEntry]:
    """Filter the audit log for admin review / SOC 2 evidence export."""
    Session = _get_session_factory()
    with Session() as s:
        q = s.query(AuditLogEntry).order_by(AuditLogEntry.timestamp.desc())
        if user_id:
            q = q.filter(AuditLogEntry.user_id == user_id)
        if tenant_id:
            q = q.filter(AuditLogEntry.tenant_id == tenant_id)
        if path_prefix:
            q = q.filter(AuditLogEntry.path.like(f"{path_prefix}%"))
        if since:
            q = q.filter(AuditLogEntry.timestamp >= since)
        if until:
            q = q.filter(AuditLogEntry.timestamp <= until)
        return q.limit(max(1, min(limit, 1000))).all()
