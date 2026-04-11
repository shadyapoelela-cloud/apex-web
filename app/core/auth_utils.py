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

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")
JWT_ALGORITHM = "HS256"

if JWT_SECRET == "apex-dev-secret-CHANGE-IN-PRODUCTION":
    logger.warning("⚠ JWT_SECRET is using default value! Set JWT_SECRET env var in production.")


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
