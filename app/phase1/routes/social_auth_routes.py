"""
APEX Platform - Social Authentication APIs
Google Sign-In + Apple Sign-In + Mobile with Country Code
Per Architecture Doc v5 Section 5
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timezone
import json
import logging

from app.phase1.models.platform_models import (
    User, UserSession, UserSecurityEvent, SessionLocal, gen_uuid, utcnow,
)

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
    """
    Google Sign-In: creates account if new, or logs in if exists.

    ⚠ WARNING: id_token is NOT validated against Google API.
    Production requires: google-auth library to verify token signature + audience.
    """
    logging.warning("Google sign-in: id_token NOT verified (production must validate)")
    db = SessionLocal()
    try:
        if not req.email:
            raise HTTPException(status_code=400, detail="Email is required from Google token")

        user = db.query(User).filter(User.email == req.email).first()

        if user:
            # Existing user - login
            session = UserSession(
                id=gen_uuid(), user_id=user.id,
                device_info="google_sign_in",
                ip_address="social_auth",
            )
            db.add(session)
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type="login", details=json.dumps({"method": "google"}),
            ))
            db.commit()
            return {
                "success": True, "is_new_user": False,
                "user": {"id": user.id, "email": user.email, "username": user.username,
                         "display_name": user.display_name},
                "session_id": session.id,
            }
        else:
            # New user - register
            username = req.email.split("@")[0] + "_g"
            new_user = User(
                id=gen_uuid(), username=username, email=req.email,
                display_name=req.display_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="google",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(), user_id=new_user.id,
                device_info="google_sign_in", ip_address="social_auth",
            )
            db.add(session)
            db.commit()
            return {
                "success": True, "is_new_user": True,
                "user": {"id": new_user.id, "email": new_user.email, "username": new_user.username,
                         "display_name": new_user.display_name},
                "session_id": session.id,
            }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Google sign-in failed", exc_info=True)
        raise HTTPException(status_code=500, detail="Social authentication failed")
    finally:
        db.close()


# ── Apple Sign-In ──

@router.post("/auth/social/apple", tags=["Social Auth"])
async def apple_sign_in(req: AppleSignInRequest):
    """
    Apple Sign-In: creates account if new, or logs in if exists.

    ⚠ WARNING: identity_token is NOT validated against Apple API.
    Production requires: PyJWT + Apple public key validation.
    """
    logging.warning("Apple sign-in: identity_token NOT verified (production must validate)")
    db = SessionLocal()
    try:
        if not req.email:
            raise HTTPException(status_code=400, detail="Email is required")

        user = db.query(User).filter(User.email == req.email).first()

        if user:
            session = UserSession(
                id=gen_uuid(), user_id=user.id,
                device_info="apple_sign_in", ip_address="social_auth",
            )
            db.add(session)
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type="login", details=json.dumps({"method": "apple"}),
            ))
            db.commit()
            return {
                "success": True, "is_new_user": False,
                "user": {"id": user.id, "email": user.email, "username": user.username},
                "session_id": session.id,
            }
        else:
            username = req.email.split("@")[0] + "_a"
            new_user = User(
                id=gen_uuid(), username=username, email=req.email,
                display_name=req.full_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="apple",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(), user_id=new_user.id,
                device_info="apple_sign_in", ip_address="social_auth",
            )
            db.add(session)
            db.commit()
            return {
                "success": True, "is_new_user": True,
                "user": {"id": new_user.id, "email": new_user.email, "username": new_user.username},
                "session_id": session.id,
            }
    except HTTPException:
        raise
    except Exception as e:
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
    logging.warning("SMS send-code called (STUB) — no real SMS sent to %s%s",
                    req.mobile_country_code, req.mobile_number[-4:].rjust(len(req.mobile_number), '*'))
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
    logging.warning("SMS verify called (STUB) — no real verification for %s%s",
                    req.mobile_country_code, req.mobile_number[-4:].rjust(len(req.mobile_number), '*'))
    return {
        "success": True,
        "verified": True,
        "mobile": f"{req.mobile_country_code}{req.mobile_number}",
        "_stub": True,
    }
