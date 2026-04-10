"""
APEX Platform — Shared Auth Utilities
═══════════════════════════════════════════════════════════════
Consolidates JWT token extraction used across phases 9/10/11.
"""

import os
import jwt
from fastapi import HTTPException

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")


def extract_user_id(authorization: str = None) -> str:
    """Extract user_id from JWT token in Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="يجب تسجيل الدخول")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload.get("sub") or payload.get("user_id")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="انتهت صلاحية الجلسة")
    except Exception:
        raise HTTPException(status_code=401, detail="رمز غير صالح")
