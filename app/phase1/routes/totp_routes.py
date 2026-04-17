"""
APEX — TOTP 2FA routes (Wave 1 PR#4).

Flow:
1) POST /auth/totp/setup  → returns provisioning_uri + recovery_codes
   (shown once; secret is encrypted and stored but NOT yet activated).
2) POST /auth/totp/verify → accepts a 6-digit code; on first success
   the totp_enabled_at timestamp is set, marking 2FA live.
3) POST /auth/totp/disable → clears the secret after proving knowledge
   of either the current code or a recovery code.

All three routes require a valid JWT in the Authorization header.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.totp_service import (
    build_encrypted_columns,
    consume_recovery_code,
    setup_totp,
    verify_totp_code,
)
from app.phase1.models.platform_models import SessionLocal, User

router = APIRouter()
logger = logging.getLogger(__name__)


class TotpVerifyRequest(BaseModel):
    code: str = Field(min_length=4, max_length=16)


class TotpSetupResponse(BaseModel):
    provisioning_uri: str
    secret_base32: str
    recovery_codes: list[str]
    status: str = "pending_verification"


@router.post("/auth/totp/setup", response_model=TotpSetupResponse, tags=["Auth / 2FA"])
async def totp_setup(authorization: Optional[str] = Header(None)):
    """Generate a fresh TOTP secret + recovery codes for the caller.

    Re-running this before verification overwrites the pending secret;
    re-running after verification rotates the secret AND resets 2FA to
    pending (user must re-scan QR).
    """
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        result = setup_totp(user_email=user.email)
        encrypted, hashed_codes = build_encrypted_columns(
            result.secret_base32, result.recovery_codes
        )
        user.totp_secret_encrypted = encrypted
        user.totp_recovery_codes_hashed = hashed_codes
        user.totp_enabled_at = None  # reset — must re-verify
        db.commit()

        return TotpSetupResponse(
            provisioning_uri=result.provisioning_uri,
            secret_base32=result.secret_base32,
            recovery_codes=result.recovery_codes,
        )
    finally:
        db.close()


@router.post("/auth/totp/verify", tags=["Auth / 2FA"])
async def totp_verify(req: TotpVerifyRequest, authorization: Optional[str] = Header(None)):
    """Verify a 6-digit TOTP code (or an 8-char recovery code).

    First success activates 2FA (sets totp_enabled_at). Recovery codes
    are one-shot and the matching hash is removed on use.
    """
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.totp_secret_encrypted:
            raise HTTPException(status_code=400, detail="TOTP not set up for this user")

        # Try TOTP first.
        if verify_totp_code(user.totp_secret_encrypted, req.code):
            if user.totp_enabled_at is None:
                user.totp_enabled_at = datetime.now(timezone.utc)
                db.commit()
                return {"success": True, "activated": True, "method": "totp"}
            db.commit()
            return {"success": True, "activated": False, "method": "totp"}

        # Fall back to recovery code (normalized to upper, ignore stray dashes).
        if user.totp_recovery_codes_hashed:
            normalized = req.code.strip().upper()
            reduced = consume_recovery_code(user.totp_recovery_codes_hashed, normalized)
            if reduced is not None:
                user.totp_recovery_codes_hashed = reduced
                if user.totp_enabled_at is None:
                    user.totp_enabled_at = datetime.now(timezone.utc)
                db.commit()
                return {"success": True, "activated": True, "method": "recovery"}

        raise HTTPException(status_code=401, detail="Invalid TOTP or recovery code")
    finally:
        db.close()


@router.post("/auth/totp/disable", tags=["Auth / 2FA"])
async def totp_disable(req: TotpVerifyRequest, authorization: Optional[str] = Header(None)):
    """Disable 2FA for the caller. Requires proof of current possession
    (a valid TOTP code or a recovery code) so a stolen session can't
    trivially remove 2FA."""
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.totp_secret_encrypted:
            raise HTTPException(status_code=400, detail="TOTP not active for this user")

        code_ok = verify_totp_code(user.totp_secret_encrypted, req.code)
        if not code_ok and user.totp_recovery_codes_hashed:
            code_ok = consume_recovery_code(
                user.totp_recovery_codes_hashed, req.code.strip().upper()
            ) is not None

        if not code_ok:
            raise HTTPException(status_code=401, detail="Invalid TOTP or recovery code")

        user.totp_secret_encrypted = None
        user.totp_enabled_at = None
        user.totp_recovery_codes_hashed = None
        db.commit()
        return {"success": True, "disabled": True}
    finally:
        db.close()


@router.get("/auth/totp/status", tags=["Auth / 2FA"])
async def totp_status(authorization: Optional[str] = Header(None)):
    """Return whether 2FA is pending setup, active, or not configured."""
    user_id = extract_user_id(authorization)
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        if not user.totp_secret_encrypted:
            state = "not_configured"
        elif user.totp_enabled_at is None:
            state = "pending_verification"
        else:
            state = "active"
        remaining = 0
        try:
            import json as _json

            remaining = len(_json.loads(user.totp_recovery_codes_hashed or "[]"))
        except ValueError:
            remaining = 0
        return {
            "state": state,
            "enabled_at": user.totp_enabled_at.isoformat() if user.totp_enabled_at else None,
            "recovery_codes_remaining": remaining,
        }
    finally:
        db.close()
