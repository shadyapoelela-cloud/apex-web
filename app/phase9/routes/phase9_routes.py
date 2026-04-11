"""
APEX Phase 9 — Account Center Routes
Endpoints:
  POST /account/forgot-password
  POST /account/reset-password
  GET  /account/sessions
  POST /account/sessions/logout-all
  POST /account/sessions/{session_id}/logout
  PUT  /account/profile
  POST /account/closure
  GET  /account/activity
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional

from app.core.auth_utils import extract_user_id

router = APIRouter(prefix="/account", tags=["Account Center"])


# ─── Schemas ──────────────────────────────────────────────
class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class ProfileUpdateRequest(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    mobile: Optional[str] = None


class ClosureRequest(BaseModel):
    closure_type: str = "temporary"  # temporary or permanent
    reason: str = ""


# ─── Endpoints ────────────────────────────────────────────
@router.post("/forgot-password")
def forgot_password(req: ForgotPasswordRequest):
    from app.phase9.services.account_service import create_password_reset

    result = create_password_reset(req.email)
    if not result.get("success", True):
        raise HTTPException(status_code=500, detail=result.get("error", "حدث خطأ"))
    return result


@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest):
    from app.phase9.services.account_service import execute_password_reset

    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="كلمة المرور يجب أن تكون 6 أحرف على الأقل")
    result = execute_password_reset(req.token, req.new_password)
    if not result.get("success", True):
        raise HTTPException(status_code=400, detail=result.get("error", "حدث خطأ"))
    return result


@router.get("/sessions")
def get_sessions(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import get_user_sessions

    sessions = get_user_sessions(user_id)
    return {"success": True, "data": {"sessions": sessions, "total": len(sessions)}}


@router.post("/sessions/logout-all")
def logout_all(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import logout_all_sessions

    result = logout_all_sessions(user_id)
    if not result.get("success", True):
        raise HTTPException(status_code=500, detail=result.get("error", "حدث خطأ"))
    return result


@router.post("/sessions/{session_id}/logout")
def logout_one(session_id: str, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import logout_session

    result = logout_session(user_id, session_id)
    if not result.get("success", True):
        raise HTTPException(status_code=404, detail=result.get("error", "حدث خطأ"))
    return result


@router.put("/profile")
def update_profile(req: ProfileUpdateRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import update_profile

    result = update_profile(user_id, req.display_name, req.email, req.mobile)
    if not result.get("success", True):
        raise HTTPException(status_code=400, detail=result.get("error", "حدث خطأ"))
    return result


@router.post("/closure")
def close_account(req: ClosureRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import request_account_closure

    result = request_account_closure(user_id, req.closure_type, req.reason)
    if not result.get("success", True):
        raise HTTPException(status_code=400, detail=result.get("error", "حدث خطأ"))
    return result


@router.get("/activity")
def get_activity(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import get_account_activity

    activity = get_account_activity(user_id)
    return {"success": True, "data": {"activity": activity, "total": len(activity)}}
