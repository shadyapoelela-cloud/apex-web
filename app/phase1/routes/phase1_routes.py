"""
APEX Platform — Phase 1 API Routes
═══════════════════════════════════════════════════════════════
Auth, Account Center, Subscriptions, Legal, Notifications.
Per execution document section 12 + Zero-Ambiguity Pack section 14.
"""

import os
from fastapi import APIRouter, Cookie, HTTPException, Depends, Header, Request, Response
from pydantic import BaseModel, Field
from typing import Optional
import logging

from app.phase1.services.auth_service import AuthService, decode_token
from app.phase1.services.account_service import AccountService
from app.phase1.services.subscription_service import SubscriptionService, EntitlementEngine
from app.phase1.services.legal_service import LegalService

# ``Secure`` cookies are HTTPS-only; setting them in dev/test (plain HTTP)
# means the browser never sends them back, which silently breaks the
# cookie-auth path. Match the HSTS gating pattern in app/main.py.
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")

# ═══════════════════════════════════════════════════════════════
# Dependency: Current User from JWT
# ═══════════════════════════════════════════════════════════════


async def get_current_user(
    authorization: Optional[str] = Header(None),
    apex_token: Optional[str] = Cookie(None),
) -> dict:
    """Resolve the caller's JWT from EITHER the ``Authorization: Bearer``
    header OR the ``apex_token`` HttpOnly cookie.

    The header path is the legacy default (mobile apps, curl clients,
    server-to-server). The cookie path is the new browser-default after
    commits 851199d + a5dad69 which fixed login/register to actually
    set the cookie. Without this Cookie parameter, every endpoint that
    uses this dependency was header-only — which meant the HttpOnly
    cookie path was end-to-end broken from API entry to handler,
    regardless of what login did on the way out.

    Header wins if both are supplied — preserves existing behaviour
    for anyone currently sending both.
    """
    token: Optional[str] = None
    if authorization and isinstance(authorization, str) and authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1].strip() or None
    # When called via FastAPI's dependency injection, apex_token is a
    # str|None. When invoked directly from main.py (two legacy call
    # sites, see app/main.py:~2236 and ~2410), only `authorization`
    # is passed and apex_token falls back to its declared default —
    # which resolves to the Cookie() dependency *object*, not None.
    # Guard with isinstance so the direct-call path doesn't crash
    # with "'Cookie' object has no attribute 'strip'".
    if not token and isinstance(apex_token, str) and apex_token:
        token = apex_token.strip() or None
    if not token:
        raise HTTPException(status_code=401, detail="غير مصرّح — يرجى تسجيل الدخول")
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
async def register(req: RegisterRequest, request: Request, response: Response):
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
    # Register returns the same token envelope as login — set the
    # HttpOnly cookie here too so a freshly-registered user is on the
    # cookie-auth path from their very first request. Without this,
    # new users spent their whole first session on the legacy
    # Authorization-header path until they explicitly re-logged in,
    # which would 403 once CSRF_ENABLED=true (CSRF depends on the
    # session cookie). Same lookup fallback chain as login.
    access_token = (
        result.get("tokens", {}).get("access_token")
        or result.get("data", {}).get("access_token")
        or result.get("access_token")
    )
    if access_token:
        response.set_cookie(
            key="apex_token",
            value=access_token,
            max_age=60 * 60 * 24,
            httponly=True,
            secure=_IS_PRODUCTION,  # HTTPS-only in prod; allow HTTP in dev/test
            samesite="lax",
            path="/",
        )
    # Also set the refresh token as an HttpOnly cookie on /auth/refresh
    # path only — narrower scope than apex_token (which every endpoint
    # reads). Using path=/auth means refresh never leaks on /clients
    # etc., shrinking the XSS/CSRF exposure window.
    refresh_token = result.get("tokens", {}).get("refresh_token")
    if refresh_token:
        response.set_cookie(
            key="apex_refresh",
            value=refresh_token,
            max_age=60 * 60 * 24 * 30,  # 30 days — matches REFRESH_TOKEN_EXPIRE_DAYS
            httponly=True,
            secure=_IS_PRODUCTION,
            samesite="lax",
            path="/auth",
        )
    return result


@router.post("/auth/login", tags=["Auth"])
async def login(req: LoginRequest, request: Request, response: Response):
    result = auth_service.login(
        username_or_email=req.username_or_email,
        password=req.password,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    if not result["success"]:
        raise HTTPException(status_code=401, detail=result["error"])
    # ── Set HttpOnly cookie alongside the JSON response ───────────
    # Frontend can continue reading the token from the body for
    # backwards compat, but browsers also store it securely as
    # HttpOnly so XSS cannot steal it. Over time the frontend can
    # drop localStorage.setItem('apex_token', …) and rely solely on
    # this cookie + credentials:'include' on fetch.
    #
    # BUG fixed 2026-04-24: auth_service.login() returns the JWT at
    # `result["tokens"]["access_token"]`, not under `data` or at the
    # top level. The old lookup resolved to None so the set_cookie
    # block was dead code — the HttpOnly auth path never actually
    # worked. Check `tokens` first, then fall back to the old
    # locations for compat with any other login callers.
    access_token = (
        result.get("tokens", {}).get("access_token")
        or result.get("data", {}).get("access_token")
        or result.get("access_token")
    )
    if access_token:
        response.set_cookie(
            key="apex_token",
            value=access_token,
            max_age=60 * 60 * 24,        # 24 hours (matches access-token TTL)
            httponly=True,
            secure=_IS_PRODUCTION,        # HTTPS-only in prod; dev/test uses HTTP
            samesite="lax",               # blocks cross-site POST while allowing top-level navigations
            path="/",
        )
    # Refresh token on a narrower /auth path — same rationale as the
    # register endpoint: the long-lived refresh token is never sent
    # on /clients or /pilot/* requests, shrinking CSRF + log-leak
    # exposure. Lives 30 days to match REFRESH_TOKEN_EXPIRE_DAYS.
    refresh_token = result.get("tokens", {}).get("refresh_token")
    if refresh_token:
        response.set_cookie(
            key="apex_refresh",
            value=refresh_token,
            max_age=60 * 60 * 24 * 30,
            httponly=True,
            secure=_IS_PRODUCTION,
            samesite="lax",
            path="/auth",
        )
    return result


class RefreshTokenRequest(BaseModel):
    # Body is optional — the token can also ride on the apex_refresh cookie
    # set at login/register time. Required field would break browser-only
    # clients that rely on cookies.
    refresh_token: Optional[str] = None


@router.post("/auth/refresh", tags=["Auth"])
async def refresh_access_token(
    req: RefreshTokenRequest,
    response: Response,
    apex_refresh: Optional[str] = Cookie(None),
):
    """Exchange a valid refresh token for a new access token.

    Accepts the refresh token from the request body (``refresh_token`` field)
    OR the ``apex_refresh`` HttpOnly cookie. Header takes no refresh — unlike
    access tokens, refresh tokens should never travel in Authorization
    (they live longer, and Authorization is often logged).

    On success, mints a fresh access token AND updates the HttpOnly
    ``apex_token`` cookie so cookie-auth clients don't have to read the
    response body. The refresh token itself is NOT rotated in this
    cut — follow-up commit can add rotation once token revocation lists
    are in place to prevent replay.
    """
    token = (req.refresh_token or "").strip() or (apex_refresh or "").strip() or None
    if not token:
        raise HTTPException(status_code=400, detail="refresh_token required")

    result = auth_service.refresh_access_token(token)
    if not result.get("success"):
        # 401 rather than 400 — it's an auth failure (bad/expired/revoked).
        raise HTTPException(status_code=401, detail=result.get("error", "refresh failed"))

    new_access = result.get("access_token")
    if new_access:
        response.set_cookie(
            key="apex_token",
            value=new_access,
            max_age=60 * 60 * 24,
            httponly=True,
            secure=_IS_PRODUCTION,
            samesite="lax",
            path="/",
        )
    return result


@router.post("/auth/logout", tags=["Auth"])
async def logout(
    response: Response,
    authorization: Optional[str] = Header(None),
    apex_token: Optional[str] = Cookie(None),
):
    """Revoke the current session and clear the auth cookies.

    BUG fixed 2026-04-24: this route used to call
    ``auth_service.logout(token)`` — but the service signature is
    ``logout(self, user_id, token="", session_id="")``. Passing the
    JWT as ``user_id`` meant the session-revocation query
    ``WHERE user_id = <JWT>`` matched zero rows, so logout silently
    did nothing. Users who "logged out" stayed logged in server-side;
    a refresh-token replay after logout still worked. Now we decode
    the token, extract the real user_id, and pass it positionally.
    """
    # Clear BOTH HttpOnly cookies so the browser forgets us.
    response.delete_cookie("apex_token", path="/")
    response.delete_cookie("apex_refresh", path="/auth")
    # Resolve the actual user from whatever credential the client sent.
    token: Optional[str] = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ", 1)[1].strip() or None
    if not token and isinstance(apex_token, str) and apex_token:
        token = apex_token.strip() or None
    if not token:
        # No credentials → nothing server-side to revoke, cookies are
        # already cleared above.
        return {"success": True}
    payload = decode_token(token)
    user_id = payload.get("sub") if isinstance(payload, dict) else None
    if not user_id:
        return {"success": True}
    return auth_service.logout(user_id, token=token)


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
