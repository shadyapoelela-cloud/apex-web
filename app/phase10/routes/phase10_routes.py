"""
APEX Phase 10 — Notification Routes
Endpoints:
  GET  /notifications           — list notifications (paginated)
  GET  /notifications/count     — unread count
  POST /notifications/mark-read — mark one or all as read
  GET  /notifications/preferences — get preferences
  PUT  /notifications/preferences — update a preference
  POST /notifications/emit      — admin: emit a notification (testing)
"""
from fastapi import APIRouter, HTTPException, Header, Query
from pydantic import BaseModel
from typing import Optional
import jwt, os

router = APIRouter(prefix="/notifications", tags=["Notifications"])

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")

def extract_user_id(authorization: str = None):
    if not authorization:
        raise HTTPException(status_code=401, detail="يجب تسجيل الدخول")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload.get("sub") or payload.get("user_id")
    except Exception:
        raise HTTPException(status_code=401, detail="رمز غير صالح")

class MarkReadRequest(BaseModel):
    notification_id: Optional[str] = None  # None = mark all

class PreferenceUpdateRequest(BaseModel):
    notification_type: str
    in_app: bool = True
    email: bool = True
    sms: bool = False

class EmitRequest(BaseModel):
    user_id: str
    notification_type: str
    body_ar: Optional[str] = None

@router.get("")
def list_notifications(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
    authorization: str = Header(None),
):
    user_id = extract_user_id(authorization)
    from app.phase10.services.notification_service import get_notifications
    return get_notifications(user_id, page, page_size, unread_only)

@router.get("/count")
def unread_count(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase10.services.notification_service import get_unread_count
    return {"unread": get_unread_count(user_id)}

@router.post("/mark-read")
def mark_read(req: MarkReadRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase10.services.notification_service import mark_as_read
    result = mark_as_read(user_id, req.notification_id)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.get("/preferences")
def get_prefs(authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase10.services.notification_service import get_preferences
    return {"preferences": get_preferences(user_id)}

@router.put("/preferences")
def update_pref(req: PreferenceUpdateRequest, authorization: str = Header(None)):
    user_id = extract_user_id(authorization)
    from app.phase10.services.notification_service import update_preference
    result = update_preference(user_id, req.notification_type, req.in_app, req.email, req.sms)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result

@router.post("/emit")
def emit(req: EmitRequest, authorization: str = Header(None)):
    """Admin endpoint to emit a notification (for testing)."""
    from app.phase10.services.notification_service import emit_notification
    result = emit_notification(req.user_id, req.notification_type, body_ar=req.body_ar)
    if result.get("status") == "error":
        raise HTTPException(status_code=400, detail=result["detail"])
    return result
