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
import jwt, os

router = APIRouter(prefix="/account", tags=["Account Center"])

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")

def extract_user_id(authorization: str = None):
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
    if result.get("status") == "error":
        raise HTTPException(status_code=500, detail=result["detail"])
    return result

@router.post("/reset-password")
def reset_password(req: ResetPasswordRequest):
    from app.phase9.services.account_service import execute_password_reset
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="كلمة المرور يجب أن تكون 6 أحرف على الأقل")
    result = execute_password_reset(req.token, req.new_password)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.get("/sessions")
def get_sessions(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import get_user_sessions
    sessions = get_user_sessions(user_id)
    return {"sessions": sessions, "total": len(sessions)}

@router.post("/sessions/logout-all")
def logout_all(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import logout_all_sessions
    result = logout_all_sessions(user_id)
    if result.get("status") == "error":
        raise HTTPException(status_code=500, detail=result["detail"])
    return result

@router.post("/sessions/{session_id}/logout")
def logout_one(session_id: str, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import logout_session
    result = logout_session(user_id, session_id)
    if result.get("status") == "error":
        raise HTTPException(status_code=404, detail=result["detail"])
    return result

@router.put("/profile")
def update_profile(req: ProfileUpdateRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import update_profile
    result = update_profile(user_id, req.display_name, req.email, req.mobile)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.post("/closure")
def close_account(req: ClosureRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import request_account_closure
    result = request_account_closure(user_id, req.closure_type, req.reason)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.get("/activity")
def get_activity(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase9.services.account_service import get_account_activity
    activity = get_account_activity(user_id)
    return {"activity": activity, "total": len(activity)}


@router.post("/auth/change-password", tags=["Account"])
async def change_password(request: Request):
    """Change password for logged-in user (requires current password)"""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    token = auth.replace("Bearer ", "")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("user_id") or payload.get("sub")
    except:
        raise HTTPException(401, "Invalid token")
    
    body = await request.json()
    current_pw = body.get("current_password", "")
    new_pw = body.get("new_password", "")
    
    if not current_pw or not new_pw:
        raise HTTPException(400, "current_password and new_password required")
    if len(new_pw) < 6:
        raise HTTPException(400, "New password must be at least 6 characters")
    
    from app.phase1.models.platform_models import SessionLocal, User
    try:
        from app.phase1.services.auth_service import verify_password, hash_password
    except ImportError:
        raise HTTPException(500, "Auth service not available")
    
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")
        
        if not verify_password(current_pw, user.password_hash):
            raise HTTPException(401, "Current password is incorrect")
        
        user.password_hash = hash_password(new_pw)
        
        # Log the action
        from app.phase9.models.phase9_models import AccountAction
        from app.phase1.models.platform_models import gen_uuid
        db.add(AccountAction(id=gen_uuid(), user_id=user_id, action_type="password_changed"))
        
        db.commit()
        return {"status": "ok", "message": "Password changed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(500, str(e))
    finally:
        db.close()
