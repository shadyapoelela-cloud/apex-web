"""
APEX Platform — Phase 1 API Routes
═══════════════════════════════════════════════════════════════
Auth, Account Center, Subscriptions, Legal, Notifications.
Per execution document section 12 + Zero-Ambiguity Pack section 14.
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Request
from pydantic import BaseModel, Field
from typing import Optional
import logging

from app.phase1.services.auth_service import AuthService, decode_token
from app.phase1.services.account_service import AccountService
from app.phase1.services.subscription_service import SubscriptionService, EntitlementEngine
from app.phase1.services.legal_service import LegalService

# ═══════════════════════════════════════════════════════════════
# Dependency: Current User from JWT
# ═══════════════════════════════════════════════════════════════


async def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="غير مصرّح — يرجى تسجيل الدخول")
    token = authorization.split(" ", 1)[1]
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="الجلسة منتهية — يرجى إعادة الدخول")
    return payload


# ═══════════════════════════════════════════════════════════════
# Schemas (DTOs)
# ═══════════════════════════════════════════════════════════════


class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str
    password: str = Field(..., min_length=8)
    display_name: str = Field(..., min_length=2, max_length=100)
    mobile: Optional[str] = None


class LoginRequest(BaseModel):
    username_or_email: str
    password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=8)


class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    mobile: Optional[str] = None
    language: Optional[str] = None
    timezone: Optional[str] = None
    bio: Optional[str] = None
    organization_name: Optional[str] = None
    job_title: Optional[str] = None
    city: Optional[str] = None
    notification_email: Optional[bool] = None
    notification_sms: Optional[bool] = None
    notification_in_app: Optional[bool] = None


class UpgradePlanRequest(BaseModel):
    plan_code: str


class AcceptPolicyRequest(BaseModel):
    policy_document_id: str


class ClosureRequest(BaseModel):
    closure_type: str  # temporary, permanent
    reason: Optional[str] = None


# ═══════════════════════════════════════════════════════════════
# Router
# ═══════════════════════════════════════════════════════════════

router = APIRouter()

auth_service = AuthService()
account_service = AccountService()
subscription_service = SubscriptionService()
entitlement_engine = EntitlementEngine()
legal_service = LegalService()


# ─── Auth APIs ───────────────────────────────────────────────


@router.post("/auth/register", tags=["Auth"])
async def register(req: RegisterRequest, request: Request):
    result = auth_service.register(
        username=req.username,
        email=req.email,
        password=req.password,
        display_name=req.display_name,
        mobile=req.mobile,
        ip_address=request.client.host if request.client else None,
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/auth/login", tags=["Auth"])
async def login(req: LoginRequest, request: Request):
    result = auth_service.login(
        username_or_email=req.username_or_email,
        password=req.password,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    if not result["success"]:
        raise HTTPException(status_code=401, detail=result["error"])
    return result


@router.post("/auth/logout", tags=["Auth"])
async def logout(authorization: Optional[str] = Header(None)):
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1]
        return auth_service.logout(token)
    return {"success": True}


@router.post("/auth/logout-all", tags=["Auth"])
async def logout_all(user: dict = Depends(get_current_user)):
    return auth_service.logout_all(user["sub"])


@router.post("/auth/forgot-password", tags=["Auth"])
async def forgot_password(req: ForgotPasswordRequest):
    return auth_service.forgot_password(req.email)


@router.post("/auth/reset-password", tags=["Auth"])
async def reset_password(req: ResetPasswordRequest):
    return auth_service.reset_password(req.token, req.new_password)


# ─── Account / Profile APIs ─────────────────────────────────


@router.get("/users/me", tags=["Account"])
async def get_my_profile(user: dict = Depends(get_current_user)):
    return account_service.get_profile(user["sub"])


@router.put("/users/me", tags=["Account"])
async def update_my_profile(req: UpdateProfileRequest, user: dict = Depends(get_current_user)):
    updates = req.dict(exclude_none=True)
    return account_service.update_profile(user["sub"], updates)


@router.get("/users/me/security", tags=["Account"])
async def get_security_info(user: dict = Depends(get_current_user)):
    return account_service.get_security_info(user["sub"])


@router.get("/users/me/sessions", tags=["Account"])
async def get_active_sessions(user: dict = Depends(get_current_user)):
    return auth_service.get_active_sessions(user["sub"])


# ─── Subscription APIs ──────────────────────────────────────


@router.get("/plans", tags=["Subscriptions"])
async def list_plans():
    return subscription_service.get_plans()


# [DISABLED - moved to Phase 8] @router.get("/subscriptions/me", tags=["Subscriptions"])
# [DISABLED] async def get_my_subscription(user: dict = Depends(get_current_user)):
# [DISABLED]     return subscription_service.get_user_subscription(user["sub"])
# [DISABLED]
# [DISABLED]
# [DISABLED - moved to Phase 8] @router.get("/entitlements/me", tags=["Subscriptions"])
# [DISABLED] async def get_my_entitlements(user: dict = Depends(get_current_user)):
# [DISABLED]     sub = subscription_service.get_user_subscription(user["sub"])
# [DISABLED]     return {"entitlements": sub.get("entitlements", {})}
# [DISABLED]
# [DISABLED]
# [DISABLED - moved to Phase 8] @router.post("/subscriptions/upgrade", tags=["Subscriptions"])
# [DISABLED] async def upgrade_plan(req: UpgradePlanRequest, user: dict = Depends(get_current_user)):
# [DISABLED]     result = subscription_service.upgrade_plan(user["sub"], req.plan_code)
# [DISABLED]     if not result["success"]:
# [DISABLED]         raise HTTPException(status_code=400, detail=result["error"])
# [DISABLED]     return result
# [DISABLED]
# [DISABLED]
# [DISABLED - moved to Phase 8] @router.post("/subscriptions/downgrade", tags=["Subscriptions"])
# [DISABLED] async def downgrade_plan(req: UpgradePlanRequest, user: dict = Depends(get_current_user)):
# [DISABLED]     result = subscription_service.downgrade_plan(user["sub"], req.plan_code)
# [DISABLED]     if not result["success"]:
# [DISABLED]         raise HTTPException(status_code=400, detail=result["error"])
# [DISABLED]     return result
# [DISABLED]
# [DISABLED]
# [DISABLED] # ─── Entitlement Check API ──────────────────────────────────
# [DISABLED]
# [DISABLED - moved to Phase 8] @router.get("/entitlements/check", tags=["Subscriptions"])
# [DISABLED] async def check_entitlement(feature_code: str, user: dict = Depends(get_current_user)):
# [DISABLED]     return entitlement_engine.check_entitlement(user["sub"], feature_code)
# [DISABLED]
# [DISABLED]
# [DISABLED] # ─── Notifications APIs ─────────────────────────────────────
# [DISABLED]
# [DISABLED-P10] @router.get("/notifications", tags=["Notifications"])
# [DISABLED-P10] async def get_notifications(unread_only: bool = False, limit: int = 50, user: dict = Depends(get_current_user)):
# [DISABLED-P10]     return account_service.get_notifications(user["sub"], unread_only=unread_only, limit=limit)


# [DISABLED-P10] @router.post("/notifications/{notification_id}/read", tags=["Notifications"])
# [DISABLED-P10] async def mark_read(notification_id: str, user: dict = Depends(get_current_user)):
# [DISABLED-P10]     return account_service.mark_notification_read(user["sub"], notification_id)


# [DISABLED-P10] @router.post("/notifications/read-all", tags=["Notifications"])
# [DISABLED-P10] async def mark_all_read(user: dict = Depends(get_current_user)):
# [DISABLED-P10]     return account_service.mark_all_read(user["sub"])


# ─── Legal / Policy APIs ────────────────────────────────────


@router.get("/legal/policies", tags=["Legal"])
async def get_current_policies():
    return legal_service.get_current_policies()


@router.get("/legal/policy/{policy_type}", tags=["Legal"])
async def get_policy(policy_type: str, version: Optional[str] = None):
    return legal_service.get_policy(policy_type, version)


@router.post("/legal/accept", tags=["Legal"])
async def accept_policy(req: AcceptPolicyRequest, request: Request, user: dict = Depends(get_current_user)):
    return legal_service.accept_policy(
        user_id=user["sub"],
        policy_document_id=req.policy_document_id,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )


@router.get("/legal/acceptance/check", tags=["Legal"])
async def check_acceptance(user: dict = Depends(get_current_user)):
    return legal_service.check_mandatory_acceptance(user["sub"])


@router.get("/legal/acceptance/history", tags=["Legal"])
async def get_acceptance_history(user: dict = Depends(get_current_user)):
    return legal_service.get_user_acceptances(user["sub"])


# ─── Account Closure APIs ───────────────────────────────────


@router.post("/account/closure", tags=["Account"])
async def request_closure(req: ClosureRequest, user: dict = Depends(get_current_user)):
    return account_service.request_closure(user["sub"], req.closure_type, req.reason)


@router.post("/account/reactivate", tags=["Account"])
async def reactivate(user: dict = Depends(get_current_user)):
    return account_service.reactivate_account(user["sub"])


@router.post("/auth/change-password", tags=["Auth"])
async def api_change_password(request: Request):
    from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM
    import jwt

    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    token = auth.replace("Bearer ", "")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("user_id") or payload.get("sub")
    except Exception:
        raise HTTPException(401, "Invalid or expired token")
    body = await request.json()
    current_pw = body.get("current_password", "")
    new_pw = body.get("new_password", "")
    if not current_pw or not new_pw:
        raise HTTPException(400, "current_password and new_password required")
    from app.phase1.services.auth_service import verify_password, hash_password
    from app.phase1.models.platform_models import SessionLocal, User

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")
        if not verify_password(current_pw, user.password_hash):
            raise HTTPException(401, "Current password incorrect")
        user.password_hash = hash_password(new_pw)
        db.commit()
        return {"success": True, "data": {"message": "Password changed successfully"}}
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logging.error("Password change error", exc_info=True)
        raise HTTPException(500, "Failed to change password")
    finally:
        db.close()
