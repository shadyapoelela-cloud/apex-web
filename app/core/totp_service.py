"""
APEX — TOTP 2FA service (Wave 1 PR#4).

Replaces the SMS-verification stubs in social_auth_routes.py with a real
RFC 6238 TOTP flow. Secrets are stored Fernet-encrypted; recovery codes
are stored as bcrypt hashes only (the raw codes are shown once at setup).

Environment:
- TOTP_ENCRYPTION_KEY (optional): base64 urlsafe 32-byte Fernet key. If
  unset in non-production, a deterministic key is derived from JWT_SECRET
  (with a warning). Production must set this explicitly.
"""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import os
import secrets as _secrets
from dataclasses import dataclass
from typing import List, Optional

import bcrypt
import pyotp
from cryptography.fernet import Fernet, InvalidToken

from app.core.auth_utils import JWT_SECRET

logger = logging.getLogger(__name__)

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")

_ISSUER_NAME = os.environ.get("TOTP_ISSUER", "APEX")
_RECOVERY_CODE_COUNT = 10


def _get_fernet() -> Fernet:
    """Return the Fernet cipher used to encrypt TOTP secrets at rest.

    Production requires TOTP_ENCRYPTION_KEY; dev derives from JWT_SECRET
    so tests and local runs just work without an extra env var.
    """
    key = os.environ.get("TOTP_ENCRYPTION_KEY")
    if key:
        return Fernet(key.encode("utf-8") if isinstance(key, str) else key)

    if _IS_PRODUCTION:
        raise RuntimeError(
            "TOTP_ENCRYPTION_KEY env var is REQUIRED in production. "
            "Generate one with: python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
        )

    # Dev fallback: derive a stable Fernet key from JWT_SECRET. Not
    # suitable for production because it couples two secrets together
    # and leaks through JWT_SECRET rotation.
    digest = hashlib.sha256(JWT_SECRET.encode("utf-8")).digest()
    derived = base64.urlsafe_b64encode(digest)
    logger.warning(
        "⚠ TOTP_ENCRYPTION_KEY not set — deriving from JWT_SECRET (dev-only)."
    )
    return Fernet(derived)


def _encrypt_secret(plaintext_secret: str) -> str:
    return _get_fernet().encrypt(plaintext_secret.encode("utf-8")).decode("utf-8")


def _decrypt_secret(encrypted_secret: str) -> str:
    try:
        return _get_fernet().decrypt(encrypted_secret.encode("utf-8")).decode("utf-8")
    except InvalidToken as e:
        raise RuntimeError("Failed to decrypt TOTP secret — key mismatch?") from e


def _generate_recovery_codes(count: int = _RECOVERY_CODE_COUNT) -> List[str]:
    """Return a list of human-readable recovery codes (XXXX-XXXX)."""
    codes = []
    for _ in range(count):
        raw = _secrets.token_hex(4).upper()
        codes.append(f"{raw[:4]}-{raw[4:]}")
    return codes


def _hash_recovery_codes(codes: List[str]) -> str:
    """Bcrypt-hash each recovery code and store as JSON array of hashes."""
    hashed = [bcrypt.hashpw(c.encode("utf-8"), bcrypt.gensalt()).decode("utf-8") for c in codes]
    return json.dumps(hashed)


def _check_recovery_code(code: str, hashed_json: str) -> Optional[int]:
    """Return the index of a matching recovery hash, or None. Caller
    must remove the matched hash after use (one-time codes)."""
    code_bytes = code.strip().upper().encode("utf-8")
    try:
        hashed_list = json.loads(hashed_json)
    except (TypeError, ValueError):
        return None
    for idx, h in enumerate(hashed_list):
        try:
            if bcrypt.checkpw(code_bytes, h.encode("utf-8")):
                return idx
        except ValueError:
            continue
    return None


@dataclass
class TotpSetupResult:
    """Return value of setup_totp(). recovery_codes are shown ONCE."""

    secret_base32: str  # for manual entry if QR unavailable
    provisioning_uri: str  # otpauth://totp/...
    recovery_codes: List[str]


def setup_totp(user_email: str) -> TotpSetupResult:
    """Generate a fresh TOTP secret + provisioning URI + recovery codes.

    Caller is responsible for persisting the encrypted secret + hashed
    recovery codes on the User row via set_user_totp_columns() below.
    Recovery codes are returned in plaintext for a single display.
    """
    secret = pyotp.random_base32()
    uri = pyotp.TOTP(secret).provisioning_uri(name=user_email, issuer_name=_ISSUER_NAME)
    codes = _generate_recovery_codes()
    return TotpSetupResult(
        secret_base32=secret,
        provisioning_uri=uri,
        recovery_codes=codes,
    )


def verify_totp_code(encrypted_secret: str, code: str, *, valid_window: int = 1) -> bool:
    """Verify a 6-digit TOTP code. valid_window=1 accepts the previous
    and next 30-second step to tolerate small clock drift (pyotp default)."""
    if not code or not encrypted_secret:
        return False
    secret = _decrypt_secret(encrypted_secret)
    return pyotp.TOTP(secret).verify(code.strip(), valid_window=valid_window)


def build_encrypted_columns(
    plaintext_secret: str, recovery_codes: List[str]
) -> tuple[str, str]:
    """Helper for route handlers: encrypt the secret + hash the recovery
    codes in one call so the caller just assigns to the User row."""
    return _encrypt_secret(plaintext_secret), _hash_recovery_codes(recovery_codes)


def consume_recovery_code(hashed_json: str, submitted_code: str) -> Optional[str]:
    """Return the new JSON blob with the matched hash removed, or None
    if the code doesn't match. Lets the caller persist the reduced list."""
    idx = _check_recovery_code(submitted_code, hashed_json)
    if idx is None:
        return None
    try:
        hashed_list = json.loads(hashed_json)
    except (TypeError, ValueError):
        return None
    del hashed_list[idx]
    return json.dumps(hashed_list)
