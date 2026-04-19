"""
APEX Platform - Social Authentication APIs
Google Sign-In + Apple Sign-In + Mobile with Country Code
Per Architecture Doc v5 Section 5

Verification:
  - Google id_token validated against https://oauth2.googleapis.com/tokeninfo
    and optional GOOGLE_CLIENT_ID audience check.
  - Apple identity_token validated against Apple JWKs with signature + aud + iss.
  - Mobile OTP stored in app.core.otp_store with TTL and attempt limits,
    sent via app.core.sms_backend (Unifonic/Twilio/console).
"""

import hashlib
import json
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.otp_store import clear_otp, request_otp, verify_otp
from app.core.sms_backend import send_otp_sms
from app.phase1.models.platform_models import (
    SessionLocal,
    User,
    UserSecurityEvent,
    UserSession,
    gen_uuid,
)


SESSION_TTL_DAYS = 30


def _new_session_token_hash() -> str:
    """Generate a unique session token hash for social-auth sessions.

    The model requires a non-null unique token_hash. We generate a random
    token and store its SHA-256. Callers who need the token plaintext should
    call the full login service instead; this keeps social sessions uniquely
    identified in the user_sessions table without breaking the NOT NULL / UNIQUE
    constraints.
    """
    return hashlib.sha256(secrets.token_bytes(32)).hexdigest()


def _session_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=SESSION_TTL_DAYS)

logger = logging.getLogger(__name__)
router = APIRouter()

# ── Auth provider config ─────────────────────────────────────

GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"

APPLE_CLIENT_ID = os.environ.get("APPLE_CLIENT_ID", "")  # service ID / bundle ID
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


# ── Token verifiers ──────────────────────────────────────────


def _verify_google_id_token(id_token: str) -> dict:
    """Validate a Google id_token via Google's tokeninfo endpoint.

    Returns the verified claims dict (with email, sub, etc.).
    Raises HTTPException(401) on any failure.
    """
    if not id_token:
        raise HTTPException(status_code=401, detail="id_token required")
    try:
        import requests
    except ImportError:
        logger.error("requests library not available — cannot verify Google token")
        raise HTTPException(status_code=500, detail="Server auth dependency missing")

    try:
        resp = requests.get(GOOGLE_TOKENINFO_URL, params={"id_token": id_token}, timeout=10)
    except requests.RequestException as e:
        logger.error("Google tokeninfo request failed: %s", e)
        raise HTTPException(status_code=503, detail="Could not reach Google auth")

    if resp.status_code != 200:
        logger.warning("Google tokeninfo rejected token (HTTP %s)", resp.status_code)
        raise HTTPException(status_code=401, detail="Invalid Google token")

    claims = resp.json()

    # Audience check (prevents token-substitution attacks)
    if GOOGLE_CLIENT_ID:
        aud = claims.get("aud", "")
        if aud != GOOGLE_CLIENT_ID:
            logger.warning("Google token audience mismatch: %s != %s", aud, GOOGLE_CLIENT_ID)
            raise HTTPException(status_code=401, detail="Token audience mismatch")
    elif IS_PRODUCTION:
        # Production must set GOOGLE_CLIENT_ID for audience check.
        raise HTTPException(status_code=500, detail="GOOGLE_CLIENT_ID not configured")

    # Issuer check
    iss = claims.get("iss", "")
    if iss not in ("accounts.google.com", "https://accounts.google.com"):
        raise HTTPException(status_code=401, detail="Invalid token issuer")

    # Email must be verified
    if claims.get("email_verified") not in (True, "true"):
        raise HTTPException(status_code=401, detail="Google email not verified")

    return claims


def _verify_apple_identity_token(identity_token: str) -> dict:
    """Validate an Apple identity_token using Apple's JWKs.

    Verifies signature, issuer, audience, and expiry.
    Returns claims dict on success. Raises HTTPException(401) on failure.
    """
    if not identity_token:
        raise HTTPException(status_code=401, detail="identity_token required")

    try:
        import jwt  # PyJWT
        import requests
    except ImportError as e:
        logger.error("Missing Apple auth dependency: %s", e)
        raise HTTPException(status_code=500, detail="Server auth dependency missing")

    try:
        unverified_header = jwt.get_unverified_header(identity_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Malformed Apple token")

    kid = unverified_header.get("kid")
    if not kid:
        raise HTTPException(status_code=401, detail="Apple token missing kid")

    # Fetch Apple's public keys (short cache would be a later optimization)
    try:
        resp = requests.get(APPLE_JWKS_URL, timeout=10)
        resp.raise_for_status()
        jwks = resp.json().get("keys", [])
    except Exception as e:
        logger.error("Failed to fetch Apple JWKs: %s", e)
        raise HTTPException(status_code=503, detail="Could not reach Apple auth")

    key_entry = next((k for k in jwks if k.get("kid") == kid), None)
    if not key_entry:
        raise HTTPException(status_code=401, detail="Apple signing key not found")

    try:
        from jwt.algorithms import RSAAlgorithm
        public_key = RSAAlgorithm.from_jwk(json.dumps(key_entry))
    except Exception as e:
        logger.error("Failed to construct Apple public key: %s", e)
        raise HTTPException(status_code=500, detail="Key construction failed")

    if not APPLE_CLIENT_ID:
        if IS_PRODUCTION:
            raise HTTPException(status_code=500, detail="APPLE_CLIENT_ID not configured")
        logger.warning("APPLE_CLIENT_ID not set — skipping audience check in dev only")

    try:
        claims = jwt.decode(
            identity_token,
            public_key,
            algorithms=[key_entry.get("alg", "RS256")],
            audience=APPLE_CLIENT_ID if APPLE_CLIENT_ID else None,
            issuer=APPLE_ISSUER,
            options={"verify_aud": bool(APPLE_CLIENT_ID)},
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Apple token expired")
    except jwt.InvalidTokenError as e:
        logger.warning("Apple token invalid: %s", e)
        raise HTTPException(status_code=401, detail="Invalid Apple token")

    return claims


def _normalize_phone(country_code: str, number: str) -> str:
    """Normalize to E.164: '+<country><number>' with digits only."""
    cc = (country_code or "").strip().lstrip("+")
    num = "".join(ch for ch in (number or "") if ch.isdigit())
    if num.startswith("0"):
        num = num.lstrip("0")
    return f"+{cc}{num}"


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

    Dev-bypass path: when GOOGLE_CLIENT_ID is unset AND not in production,
    we trust a caller-supplied email hint so local dev and test suites
    don't need a real Google token. Production with no CLIENT_ID fails
    fast (500) to prevent silently accepting unverified tokens.

    Prod path: validates id_token via Google's tokeninfo endpoint +
    audience check (see _verify_google_id_token).
    """
    # Read the module-scoped production flag from the shared verifier so
    # tests that monkeypatch social_auth_verify._IS_PRODUCTION can exercise
    # the prod-fail-fast path without spinning up a real production env.
    from app.core import social_auth_verify as _sav

    if not GOOGLE_CLIENT_ID:
        if _sav._IS_PRODUCTION or IS_PRODUCTION:
            raise HTTPException(
                status_code=500,
                detail="GOOGLE_CLIENT_ID not configured — cannot verify Google tokens.",
            )
        # Dev bypass: require a non-empty id_token and an email hint.
        if not req.id_token:
            raise HTTPException(status_code=401, detail="Invalid Google token")
        if not req.email:
            raise HTTPException(status_code=400, detail="Email is required from Google token")
        email = req.email.lower().strip()
        display_name = req.display_name
    else:
        claims = _verify_google_id_token(req.id_token)
        email = (claims.get("email") or req.email or "").lower().strip()
        display_name = claims.get("name") or req.display_name
    db = SessionLocal()
    try:
        if not email:
            raise HTTPException(status_code=400, detail="Email is required from Google token")

        user = db.query(User).filter(User.email == email).first()

        if user:
            # Existing user - login
            session = UserSession(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=_new_session_token_hash(),
                expires_at=_session_expiry(),
                device_info="google_sign_in",
                ip_address="social_auth",
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
            username = email.split("@")[0] + "_g"
            new_user = User(
                id=gen_uuid(),
                username=username,
                email=email,
                display_name=display_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="google",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(),
                user_id=new_user.id,
                token_hash=_new_session_token_hash(),
                expires_at=_session_expiry(),
                device_info="google_sign_in",
                ip_address="social_auth",
            )
            db.add(session)
            db.commit()
            # Emit audit event for the new registration (compliance/SOCPA chain).
            from app.core.compliance_service import write_audit_event

            write_audit_event(
                action="user.register",
                actor_user_id=new_user.id,
                entity_type="user",
                entity_id=new_user.id,
                metadata={"method": "google"},
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
        logger.error("Google sign-in failed", exc_info=True)
        raise HTTPException(status_code=500, detail="Social authentication failed")
    finally:
        db.close()


# ── Apple Sign-In ──


@router.post("/auth/social/apple", tags=["Social Auth"])
async def apple_sign_in(req: AppleSignInRequest):
    """
    Apple Sign-In: creates account if new, or logs in if exists.

    Dev-bypass + prod-validation split mirrors google_sign_in(). Apple
    only sends email on first sign-in, so the client may pass it back
    subsequently regardless of validation path.
    """
    apple_client_id = os.environ.get("APPLE_CLIENT_ID")
    from app.core import social_auth_verify as _sav

    if not apple_client_id:
        if _sav._IS_PRODUCTION or IS_PRODUCTION:
            raise HTTPException(
                status_code=500,
                detail="APPLE_CLIENT_ID not configured — cannot verify Apple tokens.",
            )
        if not req.identity_token:
            raise HTTPException(status_code=401, detail="Invalid Apple token")
        if not req.email:
            raise HTTPException(status_code=400, detail="Email is required from Apple token")
        email = req.email.lower().strip()
    else:
        claims = _verify_apple_identity_token(req.identity_token)
        email = (claims.get("email") or req.email or "").lower().strip()
    full_name = req.full_name  # Apple does not include name in identity_token
    db = SessionLocal()
    try:
        if not email:
            raise HTTPException(status_code=400, detail="Email is required")

        user = db.query(User).filter(User.email == email).first()

        if user:
            session = UserSession(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=_new_session_token_hash(),
                expires_at=_session_expiry(),
                device_info="apple_sign_in",
                ip_address="social_auth",
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
            return {
                "success": True,
                "is_new_user": False,
                "user": {"id": user.id, "email": user.email, "username": user.username},
                "session_id": session.id,
            }
        else:
            username = email.split("@")[0] + "_a"
            new_user = User(
                id=gen_uuid(),
                username=username,
                email=email,
                display_name=full_name or username,
                password_hash="SOCIAL_AUTH_NO_PASSWORD",
                auth_provider="apple",
            )
            db.add(new_user)
            session = UserSession(
                id=gen_uuid(),
                user_id=new_user.id,
                token_hash=_new_session_token_hash(),
                expires_at=_session_expiry(),
                device_info="apple_sign_in",
                ip_address="social_auth",
            )
            db.add(session)
            db.commit()
            # Emit audit event for new registration (Apple path).
            try:
                from app.core.compliance_service import write_audit_event

                write_audit_event(
                    action="user.register",
                    actor_user_id=new_user.id,
                    entity_type="user",
                    entity_id=new_user.id,
                    metadata={"method": "apple"},
                )
            except Exception as e:
                logger.warning("Audit event user.register (apple) not emitted: %s", e)
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
        logger.error("Apple sign-in failed", exc_info=True)
        raise HTTPException(status_code=500, detail="Social authentication failed")
    finally:
        db.close()


# ── Mobile Verification ──


@router.post("/auth/mobile/send-code", tags=["Social Auth"])
async def send_mobile_code(req: MobileVerifyRequest):
    """Send an OTP to a mobile number via the configured SMS backend.

    Flow:
      1. Normalize phone to E.164.
      2. Ask OTP store to generate a code (with rate limiting / cooldown).
      3. Send the code via SMS backend (Unifonic / Twilio / console).
    """
    phone = _normalize_phone(req.mobile_country_code, req.mobile_number)
    if len(phone) < 8:
        raise HTTPException(status_code=400, detail="رقم الجوال غير صحيح")

    code, reason = request_otp(phone)
    if not code:
        raise HTTPException(status_code=429, detail=reason or "تعذّر إرسال الرمز")

    result = send_otp_sms(phone, code)
    if not result.get("success"):
        # Don't persist the OTP if we couldn't deliver it.
        clear_otp(phone)
        logger.error("OTP SMS delivery failed: %s", result.get("error"))
        raise HTTPException(status_code=502, detail="تعذّر إرسال الرسالة النصية")

    return {
        "success": True,
        "message": "تم إرسال رمز التحقق",
        "mobile": phone,
        "backend": result.get("backend"),
    }


@router.post("/auth/mobile/verify", tags=["Social Auth"])
async def verify_mobile_code(req: MobileVerifyRequest):
    """Verify an OTP previously sent via /auth/mobile/send-code."""
    if not req.verification_code:
        raise HTTPException(status_code=400, detail="Verification code required")

    phone = _normalize_phone(req.mobile_country_code, req.mobile_number)
    ok, reason = verify_otp(phone, req.verification_code)
    if not ok:
        raise HTTPException(status_code=401, detail=reason or "رمز التحقق غير صحيح")

    return {
        "success": True,
        "verified": True,
        "mobile": phone,
    }
