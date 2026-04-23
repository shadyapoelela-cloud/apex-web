"""
APEX — Email verification routes

Adds the missing email-verification flow flagged by the security audit.
Registration currently accepts any email without confirmation. This
module adds two endpoints:

  POST /auth/email/send-verification
    – Authenticated. Generates a one-time verification token, emails
      it to the user, stores the SHA-256 hash in the DB with a 24h TTL.

  POST /auth/email/verify
    – Public (token is the secret). Accepts the token, looks up the
      matching hash, flips User.email_verified = True, marks token
      consumed. Idempotent once verified.

Design mirrors the existing forgot-password flow to stay consistent.
Depends on User.email_verified column (already present) and the
email_service for delivery (console/SMTP/SendGrid per EMAIL_BACKEND).
"""
from __future__ import annotations

import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Column, DateTime, String, Boolean, ForeignKey

from app.core.auth_utils import extract_user_id
from app.core.email_service import send_email
from app.phase1.models.platform_models import Base, SessionLocal, User, gen_uuid, utcnow

router = APIRouter()
logger = logging.getLogger(__name__)

_TOKEN_TTL_HOURS = 24


# ════════════════════════════════════════════════════════════════════
# Storage — minimal standalone model (not polluting platform_models.py).
# The table is created at startup via create_all() since it inherits
# from the shared Base.
# ════════════════════════════════════════════════════════════════════
class EmailVerificationToken(Base):
    __tablename__ = "email_verification_tokens"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash = Column(String(64), nullable=False, unique=True, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    consumed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)


# ════════════════════════════════════════════════════════════════════
# Pydantic models
# ════════════════════════════════════════════════════════════════════
class EmailVerifyRequest(BaseModel):
    token: str = Field(min_length=16, max_length=128)


# ════════════════════════════════════════════════════════════════════
# Endpoints
# ════════════════════════════════════════════════════════════════════
@router.post("/auth/email/send-verification", tags=["Auth / Email"])
async def send_email_verification(authorization: Optional[str] = Header(None)):
    """Issue a one-time verification token and email it to the caller.

    Authenticated. Rate-limited by the global middleware. Silently
    succeeds if email is already verified (idempotent UX).
    """
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if user.email_verified:
            return {
                "success": True,
                "data": {
                    "already_verified": True,
                    "message": "البريد مُوثَّق بالفعل",
                },
            }

        # Generate a URL-safe 32-byte token (~43 char base64).
        plaintext_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(plaintext_token.encode()).hexdigest()
        expires = datetime.now(tz=timezone.utc) + timedelta(
            hours=_TOKEN_TTL_HOURS
        )

        # Invalidate any prior outstanding tokens for this user.
        db.query(EmailVerificationToken).filter(
            EmailVerificationToken.user_id == user_id,
            EmailVerificationToken.consumed_at.is_(None),
        ).update({"consumed_at": datetime.now(tz=timezone.utc)})

        record = EmailVerificationToken(
            user_id=user_id,
            token_hash=token_hash,
            expires_at=expires,
        )
        db.add(record)
        db.commit()

        # Deliver the email (failure is non-fatal — caller can retry).
        body_html = (
            f'<div dir="rtl" style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">'
            f'<h2 style="color:#0A1628;">تأكيد البريد الإلكتروني</h2>'
            f'<p>مرحباً {user.display_name or user.username}،</p>'
            f'<p>استخدم الرمز أدناه لتأكيد بريدك الإلكتروني:</p>'
            f'<div style="background:#f5f5f5;padding:16px;text-align:center;'
            f'font-family:monospace;font-size:18px;border-radius:8px;'
            f'margin:16px 0;word-break:break-all;">{plaintext_token}</div>'
            f'<p style="color:#666;">ينتهي هذا الرمز خلال {_TOKEN_TTL_HOURS} ساعة.</p>'
            f'<p style="color:#999;font-size:11px;">إذا لم تطلب هذا، تجاهل الرسالة.</p>'
            f'</div>'
        )
        body_text = (
            f"مرحباً {user.display_name or user.username}،\n\n"
            f"رمز تأكيد البريد: {plaintext_token}\n\n"
            f"ينتهي خلال {_TOKEN_TTL_HOURS} ساعة.\n— APEX"
        )
        try:
            send_email(
                to=user.email,
                subject="APEX — تأكيد البريد الإلكتروني",
                body_html=body_html,
                body_text=body_text,
            )
        except Exception as e:  # noqa: BLE001
            logger.warning(f"Email verification send failed (non-fatal): {e}")

        import os as _os
        email_backend = _os.environ.get("EMAIL_BACKEND", "console").lower()
        return {
            "success": True,
            "data": {
                "sent": True,
                "expires_in_hours": _TOKEN_TTL_HOURS,
                # Token NEVER returned to client in production; included
                # only when EMAIL_BACKEND=console to aid local testing.
                **(
                    {"debug_token": plaintext_token}
                    if email_backend == "console"
                    else {}
                ),
            },
        }
    finally:
        db.close()


@router.post("/auth/email/verify", tags=["Auth / Email"])
async def verify_email(req: EmailVerifyRequest):
    """Consume a verification token and mark the associated email as
    verified. Public (token acts as the auth). Idempotent.
    """
    token_hash = hashlib.sha256(req.token.encode()).hexdigest()
    db = SessionLocal()
    try:
        record = (
            db.query(EmailVerificationToken)
            .filter(EmailVerificationToken.token_hash == token_hash)
            .first()
        )
        if not record:
            raise HTTPException(status_code=400, detail="رمز غير صالح")
        if record.consumed_at is not None:
            raise HTTPException(status_code=400, detail="الرمز مُستخدَم بالفعل")
        now = datetime.now(tz=timezone.utc)
        # `expires_at` stored as UTC; guard against naive vs aware mix.
        expires = record.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now:
            raise HTTPException(status_code=400, detail="انتهت صلاحية الرمز")

        user = db.query(User).filter(User.id == record.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user.email_verified = True
        record.consumed_at = now
        db.commit()

        return {
            "success": True,
            "data": {"email_verified": True, "user_id": user.id},
        }
    finally:
        db.close()


@router.get("/auth/email/status", tags=["Auth / Email"])
async def email_status(authorization: Optional[str] = Header(None)):
    """Quick status probe — returns whether the current user's email
    is verified. Used by the frontend to show a verification banner.
    """
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return {
            "success": True,
            "data": {
                "email": user.email,
                "verified": bool(user.email_verified),
            },
        }
    finally:
        db.close()
