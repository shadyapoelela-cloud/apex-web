"""
APEX Platform - Social Authentication APIs
Google Sign-In + Apple Sign-In + Mobile with Country Code
Per Architecture Doc v5 Section 5
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
import json
import logging

_SESSION_TTL_HOURS = 24

from app.phase1.models.platform_models import (
    User,
    UserSession,
    UserSecurityEvent,
    SessionLocal,
    gen_uuid,
)
from app.core.social_auth_verify import verify_google_id_token, verify_apple_identity_token
from app.core.compliance_service import write_audit_event

router = APIRouter()


# ── Schemas ──


class GoogleSignInRequest(BaseModel):
    id_token: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    photo_url: Optional[str] = None


class AppleSignInRequest(BaseModel):
    identity_token: str
    authorization_code: str
    email: Optional[str] = None
    full_name: Optional[str] = None


class MobileVerifyRequest(BaseModel):
    mobile_country_code: str = Field(default="+966")
    mobile_number: str
    verification_code: Optional[str] = None


class LinkSocialAccountRequest(BaseModel):
    provider: str  # google, apple
    provider_token: str


# ── Google Sign-In ──


@router.post("/auth/social/google", tags=["Social Auth"])
async def google_sign_in(req: GoogleSignInRequest):
    """Google Sign-In: creates account if new, or logs in if exists.

    The id_token is verified against Google's JWKS and the configured
    GOOGLE_OAUTH_CLIENT_ID audience. In development, if the env var is
    not set, the caller-supplied email is trusted with a warning logged.
    """
    identity = verify_google_id_token(req.id_token, dev_email_hint=req.email)
    verified_email = identity.email
    # Only use the caller-supplied display_name/photo_url if the verifier
    # didn't return its own (dev-bypass path).
    display_name = identity.display_name or req.display_name
    photo_url = identity.photo_url or req.photo_url

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == verified_email).first()

        if user:
            # Existing user - login
            session = UserSession(
                id=gen_uuid(),
                user_id=user.id,
                # Placeholder matches auth_service.py pattern; a real access/refresh
                # token pair should be minted here in a follow-up PR.
                token_hash=f"pending:google:{gen_uuid()}",
                device_info="google_sign_in",
                ip_address="social_auth",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=_SESSION_TTL_HOURS),
            )
            db.add(session)
            db.add(
                UserSecurityEvent(
                    id=gen_uuid(),
                    user_id=user.id,
                    event_type="login",
                    details=json.dumps({"method": "google"}),
                )
            )
            db.commit()
            write_audit_event(
                action="user.login",
                actor_user_id=user.id,
                entity_type="user",
                entity_id=user.id,
                metadata={"method": "google", "verified": identity.verified},
            )
            return {
                "success": True,
                "is_new_user": False,
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "username": user.username,
                    "display_name": user.display_name,
                },
                "session_id": session.id,
            }
        else:
            # New user - register
            username = verified_email.split("@")[0] + "_g"
            new_user = User(
                id=gen_uuid(),
                username=username,
                email=verified_email,
                display_name=display_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="google",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(),
                user_id=new_user.id,
                token_hash=f"pending:google:{gen_uuid()}",
                device_info="google_sign_in",
                ip_address="social_auth",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=_SESSION_TTL_HOURS),
            )
            db.add(session)
            db.commit()
            write_audit_event(
                action="user.register",
                actor_user_id=new_user.id,
                entity_type="user",
                entity_id=new_user.id,
                metadata={"method": "google", "verified": identity.verified},
            )
            return {
                "success": True,
                "is_new_user": True,
                "user": {
                    "id": new_user.id,
                    "email": new_user.email,
                    "username": new_user.username,
                    "display_name": new_user.display_name,
                },
                "session_id": session.id,
            }
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logging.error("Google sign-in failed", exc_info=True)
        raise HTTPException(status_code=500, detail="Social authentication failed")
    finally:
        db.close()


# ── Apple Sign-In ──


@router.post("/auth/social/apple", tags=["Social Auth"])
async def apple_sign_in(req: AppleSignInRequest):
    """Apple Sign-In: creates account if new, or logs in if exists.

    The identity_token is verified against Apple's JWKS
    (https://appleid.apple.com/auth/keys) and the configured
    APPLE_CLIENT_ID audience. In development, if APPLE_CLIENT_ID is
    unset, the caller-supplied email is trusted with a warning logged.
    """
    identity = verify_apple_identity_token(
        req.identity_token,
        dev_email_hint=req.email,
        dev_name_hint=req.full_name,
    )
    verified_email = identity.email
    display_name = identity.display_name or req.full_name

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == verified_email).first()

        if user:
            session = UserSession(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=f"pending:apple:{gen_uuid()}",
                device_info="apple_sign_in",
                ip_address="social_auth",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=_SESSION_TTL_HOURS),
            )
            db.add(session)
            db.add(
                UserSecurityEvent(
                    id=gen_uuid(),
                    user_id=user.id,
                    event_type="login",
                    details=json.dumps({"method": "apple"}),
                )
            )
            db.commit()
            write_audit_event(
                action="user.login",
                actor_user_id=user.id,
                entity_type="user",
                entity_id=user.id,
                metadata={"method": "apple", "verified": identity.verified},
            )
            return {
                "success": True,
                "is_new_user": False,
                "user": {"id": user.id, "email": user.email, "username": user.username},
                "session_id": session.id,
            }
        else:
            username = verified_email.split("@")[0] + "_a"
            new_user = User(
                id=gen_uuid(),
                username=username,
                email=verified_email,
                display_name=display_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="apple",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(),
                user_id=new_user.id,
                token_hash=f"pending:apple:{gen_uuid()}",
                device_info="apple_sign_in",
                ip_address="social_auth",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=_SESSION_TTL_HOURS),
            )
            db.add(session)
            db.commit()
            write_audit_event(
                action="user.register",
                actor_user_id=new_user.id,
                entity_type="user",
                entity_id=new_user.id,
                metadata={"method": "apple", "verified": identity.verified},
            )
            return {
                "success": True,
                "is_new_user": True,
                "user": {"id": new_user.id, "email": new_user.email, "username": new_user.username},
                "session_id": session.id,
            }
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logging.error("Apple sign-in failed", exc_info=True)
        raise HTTPException(status_code=500, detail="Social authentication failed")
    finally:
        db.close()


# ── Mobile Verification ──


@router.post("/auth/mobile/send-code", tags=["Social Auth"])
async def send_mobile_code(req: MobileVerifyRequest):
    """Send verification code to mobile.

    ⚠ STUB: Returns success without actually sending SMS.
    Production requires: Twilio/MessageBird integration + OTP storage.
    """
    logging.warning(
        "SMS send-code called (STUB) — no real SMS sent to %s%s",
        req.mobile_country_code,
        req.mobile_number[-4:].rjust(len(req.mobile_number), "*"),
    )
    return {
        "success": True,
        "message": "Verification code sent",
        "mobile": f"{req.mobile_country_code}{req.mobile_number}",
        "_stub": True,
    }


@router.post("/auth/mobile/verify", tags=["Social Auth"])
async def verify_mobile_code(req: MobileVerifyRequest):
    """Verify mobile code.

    ⚠ STUB: Accepts any 6-digit code without real verification.
    Production requires: OTP validation against stored code + expiry.
    """
    if not req.verification_code:
        raise HTTPException(status_code=400, detail="Verification code required")
    if len(req.verification_code) < 4:
        raise HTTPException(status_code=400, detail="رمز التحقق قصير جداً")
    logging.warning(
        "SMS verify called (STUB) — no real verification for %s%s",
        req.mobile_country_code,
        req.mobile_number[-4:].rjust(len(req.mobile_number), "*"),
    )
    return {
        "success": True,
        "verified": True,
        "mobile": f"{req.mobile_country_code}{req.mobile_number}",
        "_stub": True,
    }
