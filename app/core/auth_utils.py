"""
APEX Platform — Shared Auth Utilities
═══════════════════════════════════════════════════════════════
Single source of truth for JWT_SECRET and token extraction.
All modules MUST import JWT_SECRET from here — never re-declare it.
"""

import os
import logging
import jwt
from fastapi import HTTPException

logger = logging.getLogger(__name__)

_ENVIRONMENT = os.environ.get("ENVIRONMENT", "development").lower()
_IS_PRODUCTION = _ENVIRONMENT in ("production", "prod")

_MIN_SECRET_BYTES = 32  # RFC 7518 §3.2 for HS256

_jwt_env = os.environ.get("JWT_SECRET")
if not _jwt_env:
    if _IS_PRODUCTION:
        raise RuntimeError(
            "JWT_SECRET env var is REQUIRED in production. "
            "Refusing to start with insecure default."
        )
    _jwt_env = "apex-dev-secret-CHANGE-IN-PRODUCTION-min32bytes"
    logger.warning("⚠ JWT_SECRET not set — using development-only fallback.")
elif len(_jwt_env.encode("utf-8")) < _MIN_SECRET_BYTES:
    msg = (
        "JWT_SECRET must be at least %d bytes for HS256 (current: %d)."
        % (_MIN_SECRET_BYTES, len(_jwt_env.encode("utf-8")))
    )
    if _IS_PRODUCTION:
        raise RuntimeError(msg)
    logger.warning("⚠ %s Dev-mode continues but this will fail in production.", msg)

JWT_SECRET = _jwt_env
JWT_ALGORITHM = "HS256"


def extract_user_id(authorization: str = None) -> str:
    """Extract user_id from JWT token in Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="يجب تسجيل الدخول")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload.get("sub") or payload.get("user_id")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="انتهت صلاحية الجلسة")
    except Exception as e:
        logger.debug("JWT decode failed: %s", e)
        raise HTTPException(status_code=401, detail="رمز غير صالح")
