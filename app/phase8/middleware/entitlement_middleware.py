"""
APEX Phase 8 — Entitlement Resolution Middleware
Per Execution Master §13 + Zero Ambiguity §5

Resolution chain: permission check → entitlement check → business rule → ownership check

Usage:
    @app.get("/some-endpoint")
    async def endpoint(user=Depends(require_entitlement("coa_uploads_limit", min_value=1))):
        ...
"""

from fastapi import Depends, HTTPException, Request
from functools import wraps
from app.phase1.models.platform_models import SessionLocal


def get_user_entitlement(user_id: str, feature_key: str):
    """Get a specific entitlement value for a user"""
    from app.phase1.models.platform_models import SubscriptionEntitlement

    db = SessionLocal()
    try:
        ent = db.query(SubscriptionEntitlement).filter_by(user_id=user_id, feature_code=feature_key).first()
        if ent:
            return ent.value
        return None
    finally:
        db.close()


def get_all_user_entitlements(user_id: str):
    """Get all entitlements for a user as a dict"""
    from app.phase1.models.platform_models import SubscriptionEntitlement

    db = SessionLocal()
    try:
        ents = db.query(SubscriptionEntitlement).filter_by(user_id=user_id).all()
        return {e.feature_code: e.value for e in ents}
    finally:
        db.close()


def get_user_subscription(user_id: str):
    """Get active subscription for a user"""
    from app.phase1.models.platform_models import UserSubscription, Plan

    db = SessionLocal()
    try:
        sub = db.query(UserSubscription).filter_by(user_id=user_id, status="active").first()
        if sub:
            # Get plan name from plans table
            plan = db.query(Plan).filter_by(id=sub.plan_id).first()
            plan_name = plan.name_en if plan else "Free"
            return {
                "id": sub.id,
                "plan_id": sub.plan_id,
                "plan_name": plan_name,
                "plan_name_ar": plan.name_ar if plan else "مجاني",
                "status": sub.status,
                "billing_cycle": getattr(sub, "billing_cycle", "monthly"),
                "started_at": str(sub.started_at) if sub.started_at else None,
                "expires_at": str(getattr(sub, "expires_at", None)) if getattr(sub, "expires_at", None) else None,
            }
        return None
    finally:
        db.close()


def check_entitlement(user_id: str, feature_key: str, required_value=None):
    """
    Check if user has entitlement for a feature.
    Returns (allowed: bool, current_value: str, message: str)
    """
    value = get_user_entitlement(user_id, feature_key)

    if value is None:
        return False, None, f"لا توجد صلاحية للميزة: {feature_key}"

    # Boolean features
    if value in ("true", "false"):
        allowed = value == "true"
        return allowed, value, "" if allowed else f"الميزة غير متاحة في خطتك: {feature_key}"

    # "none" means no access
    if value == "none" or value == "browse_only":
        return False, value, f"الميزة غير متاحة في خطتك الحالية"

    # Numeric limits
    if value == "unlimited":
        return True, value, ""

    try:
        limit = int(value)
        if required_value is not None:
            allowed = limit >= int(required_value)
        else:
            allowed = limit > 0
        return allowed, value, "" if allowed else f"تجاوزت الحد المسموح ({limit})"
    except ValueError:
        # String values like "basic", "full", "full_export" — allow by default
        return True, value, ""


def check_usage_count(user_id: str, feature_key: str, current_usage: int):
    """Check if user has remaining quota for a feature"""
    value = get_user_entitlement(user_id, feature_key)
    if value is None or value == "false" or value == "none":
        return False, 0, "الميزة غير متاحة"
    if value == "unlimited":
        return True, -1, ""
    try:
        limit = int(value)
        remaining = limit - current_usage
        if remaining <= 0:
            return False, 0, f"استنفذت الحد الشهري ({limit})"
        return True, remaining, ""
    except ValueError:
        return True, -1, ""


def require_entitlement(feature_key: str, required_value=None):
    """FastAPI dependency that checks entitlement before allowing access"""

    async def dependency(request: Request):
        # Extract user_id from JWT token (already decoded by auth middleware)
        user_id = getattr(request.state, "user_id", None)
        if not user_id:
            # Try to get from Authorization header
            auth = request.headers.get("Authorization", "")
            if auth.startswith("Bearer "):
                try:
                    import jwt
                    from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM

                    token = auth.split(" ")[1]
                    payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
                    user_id = payload.get("sub") or payload.get("user_id")
                except Exception:
                    pass

        if not user_id:
            raise HTTPException(401, "غير مصرح — يجب تسجيل الدخول")

        allowed, value, message = check_entitlement(user_id, feature_key, required_value)
        if not allowed:
            raise HTTPException(
                403,
                detail={
                    "error": "entitlement_denied",
                    "feature": feature_key,
                    "current_value": value,
                    "message": message,
                    "upgrade_hint": "قم بترقية خطتك للحصول على هذه الميزة",
                },
            )
        return {"user_id": user_id, "feature_key": feature_key, "feature_value": value}

    return dependency
