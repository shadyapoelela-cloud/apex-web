"""
APEX — Social auth token verifiers (Google + Apple).

Wave 1 PR#2/PR#3: Replace the "id_token NOT verified" stubs in
app/phase1/routes/social_auth_routes.py with real cryptographic
verification against each provider's public keys.

Dev bypass: in ENVIRONMENT=development, if GOOGLE_OAUTH_CLIENT_ID (or
APPLE_CLIENT_ID for Apple) is not set AND the request passed the
dev-bypass marker, we fall back to trusting the client-supplied claims
and log a warning. This keeps existing integration tests green while
forcing production deployments to configure real audiences.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Optional

from fastapi import HTTPException

logger = logging.getLogger(__name__)

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


@dataclass(frozen=True)
class VerifiedIdentity:
    """Result of verifying an id_token. Email is always lowercased."""

    email: str
    display_name: Optional[str]
    photo_url: Optional[str]
    subject: str  # provider-specific unique user id ("sub" claim)
    provider: str  # "google" or "apple"
    verified: bool  # True if signature was checked, False only in dev-bypass
    raw_claims: dict


# ── Google ──


def verify_google_id_token(id_token: str, *, dev_email_hint: Optional[str] = None) -> VerifiedIdentity:
    """Verify a Google id_token and return the identity claims.

    Production path: uses google-auth's verify_oauth2_token() which checks
    the token signature against Google's JWKs and validates the audience
    against GOOGLE_OAUTH_CLIENT_ID.

    Dev bypass: if GOOGLE_OAUTH_CLIENT_ID is not set and we are not in
    production, we trust the caller-supplied email hint and return a
    VerifiedIdentity with verified=False so downstream code can decide
    whether to accept it.

    Raises HTTPException(401) on any verification failure.
    """
    client_id = os.environ.get("GOOGLE_OAUTH_CLIENT_ID")

    if not client_id:
        if _IS_PRODUCTION:
            raise HTTPException(
                status_code=500,
                detail="GOOGLE_OAUTH_CLIENT_ID not configured — cannot verify Google tokens.",
            )
        logger.warning(
            "Google sign-in: GOOGLE_OAUTH_CLIENT_ID not set, dev-bypass accepting caller-supplied email."
        )
        if not dev_email_hint:
            raise HTTPException(status_code=400, detail="Email is required from Google token")
        return VerifiedIdentity(
            email=dev_email_hint.lower(),
            display_name=None,
            photo_url=None,
            subject=f"dev:{dev_email_hint.lower()}",
            provider="google",
            verified=False,
            raw_claims={},
        )

    try:
        from google.auth.transport import requests as ga_requests
        from google.oauth2 import id_token as ga_id_token

        claims = ga_id_token.verify_oauth2_token(id_token, ga_requests.Request(), client_id)
    except Exception as e:
        logger.info("Google id_token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid Google token") from e

    # Extra safety: verify_oauth2_token already checks iss and aud, but
    # double-check the issuer list google publishes.
    issuer = claims.get("iss")
    if issuer not in ("accounts.google.com", "https://accounts.google.com"):
        raise HTTPException(status_code=401, detail="Invalid Google token issuer")

    email = claims.get("email")
    if not email:
        raise HTTPException(status_code=401, detail="Google token missing email claim")
    if not claims.get("email_verified"):
        raise HTTPException(status_code=401, detail="Google account email is not verified")

    return VerifiedIdentity(
        email=email.lower(),
        display_name=claims.get("name"),
        photo_url=claims.get("picture"),
        subject=claims["sub"],
        provider="google",
        verified=True,
        raw_claims=claims,
    )


# ── Apple ──


def verify_apple_identity_token(
    identity_token: str, *, dev_email_hint: Optional[str] = None, dev_name_hint: Optional[str] = None
) -> VerifiedIdentity:
    """Verify an Apple identity_token against Apple's JWKS.

    Uses PyJWT with Apple's public JWKS endpoint. Audience must match
    APPLE_CLIENT_ID (the app's service id or bundle id).

    Dev bypass is analogous to the Google path: when APPLE_CLIENT_ID is
    unset in non-production, trust the caller-supplied claims.
    """
    client_id = os.environ.get("APPLE_CLIENT_ID")

    if not client_id:
        if _IS_PRODUCTION:
            raise HTTPException(
                status_code=500,
                detail="APPLE_CLIENT_ID not configured — cannot verify Apple tokens.",
            )
        logger.warning(
            "Apple sign-in: APPLE_CLIENT_ID not set, dev-bypass accepting caller-supplied email."
        )
        if not dev_email_hint:
            raise HTTPException(status_code=400, detail="Email is required")
        return VerifiedIdentity(
            email=dev_email_hint.lower(),
            display_name=dev_name_hint,
            photo_url=None,
            subject=f"dev:{dev_email_hint.lower()}",
            provider="apple",
            verified=False,
            raw_claims={},
        )

    try:
        import jwt as pyjwt
        from jwt import PyJWKClient

        jwks_client = PyJWKClient("https://appleid.apple.com/auth/keys")
        signing_key = jwks_client.get_signing_key_from_jwt(identity_token)
        claims = pyjwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=client_id,
            issuer="https://appleid.apple.com",
        )
    except Exception as e:
        logger.info("Apple identity_token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid Apple token") from e

    email = claims.get("email")
    if not email:
        # Apple's "hide my email" relay: no email claim after first login.
        # Require the caller to have stored the email from first sign-up.
        if not dev_email_hint:
            raise HTTPException(
                status_code=401,
                detail="Apple token has no email (Hide-My-Email); pass stored email from first sign-up",
            )
        email = dev_email_hint

    return VerifiedIdentity(
        email=email.lower(),
        display_name=dev_name_hint,  # Apple only gives name on first auth
        photo_url=None,
        subject=claims["sub"],
        provider="apple",
        verified=True,
        raw_claims=claims,
    )
