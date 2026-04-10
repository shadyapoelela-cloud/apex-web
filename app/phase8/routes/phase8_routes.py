"""
APEX Phase 8 — Subscription & Entitlement APIs
Per Execution Master §12 + Zero Ambiguity §14

APIs:
- GET /subscriptions/me — current plan for logged-in user
- GET /subscriptions/plans — all available plans with features
- POST /subscriptions/upgrade — upgrade plan
- POST /subscriptions/downgrade — downgrade plan
- GET /entitlements/me — all entitlements for current user
- GET /entitlements/check/{feature} — check specific entitlement
- GET /plans/compare — compare all plans side by side
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Header
import logging
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase8.middleware.entitlement_middleware import (
    get_user_subscription, get_all_user_entitlements, check_entitlement, check_usage_count
)
from app.phase8.services.seed_phase8 import (
    PLAN_LIMITS, FEATURE_DESCRIPTIONS, create_user_subscription, upgrade_user_plan
)

router = APIRouter()

# ─── Helper: Extract user_id from token ───────────────────
def get_current_user_id(authorization: str = None):
    """Extract user_id from JWT — simplified"""
    if not authorization:
        return None
    # Clean up Bearer prefix if doubled
    if authorization.startswith("Bearer Bearer "):
        authorization = authorization.replace("Bearer Bearer ", "Bearer ")
    try:
        import jwt
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload.get("sub") or payload.get("user_id")
    except Exception:
        return None

# ─── GET /subscriptions/me ────────────────────────────────

@router.get("/subscriptions/debug")
def debug_subscription(authorization: str = None):
    """Debug endpoint to trace errors"""
    result = {}
    try:
        result["step1_auth"] = authorization[:50] if authorization else "None"
        uid = get_current_user_id(authorization)
        result["step2_user_id"] = uid
        sub = get_user_subscription(uid) if uid else None
        result["step3_subscription"] = sub
        ents = get_all_user_entitlements(uid) if uid else None
        result["step4_entitlements"] = ents
    except Exception as e:
        logging.error("Entitlement debug error", exc_info=True)
        result["error"] = "Debug check failed"
    return result

@router.get("/subscriptions/me")
def get_my_subscription(authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Get current subscription for logged-in user"""
    from fastapi import Header
    # Simple auth extraction
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")
    
    sub = get_user_subscription(user_id)
    if not sub:
        # Auto-create Free subscription
        result = create_user_subscription(user_id, "Free")
        sub = get_user_subscription(user_id)
    
    entitlements = get_all_user_entitlements(user_id)
    
    return {"success": True, "data": {
        "subscription": sub,
        "entitlements": entitlements,
        "plan_features": _get_plan_display(sub["plan_name"] if sub else "Free")
    }}

# ─── GET /subscriptions/plans ─────────────────────────────
@router.get("/subscriptions/plans")
def list_available_plans():
    """List all available plans with features and limits"""
    plans = []
    plan_order = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    
    prices = {
        "Free": {"monthly": 0, "yearly": 0, "currency": "SAR"},
        "Pro": {"monthly": 99, "yearly": 990, "currency": "SAR"},
        "Business": {"monthly": 299, "yearly": 2990, "currency": "SAR"},
        "Expert": {"monthly": 0, "yearly": 0, "currency": "SAR", "note": "عمولة على الخدمات فقط"},
        "Enterprise": {"monthly": 0, "yearly": 0, "currency": "SAR", "note": "تعاقد خاص"},
    }
    
    for plan_name in plan_order:
        features = PLAN_LIMITS.get(plan_name, {})
        display_features = []
        for key, value in features.items():
            desc = FEATURE_DESCRIPTIONS.get(key, ("", ""))
            display_features.append({
                "key": key,
                "value": value,
                "name_ar": desc[0],
                "name_en": desc[1],
                "is_available": value not in ("false", "none", "0"),
            })
        
        plans.append({
            "name": plan_name,
            "pricing": prices.get(plan_name, {}),
            "features": display_features,
            "feature_count": sum(1 for f in display_features if f["is_available"]),
        })
    
    return {"success": True, "data": {"plans": plans}}

# ─── POST /subscriptions/upgrade ──────────────────────────
@router.post("/subscriptions/upgrade")
def upgrade_subscription(plan_name: str = Query(...), authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Upgrade to a new plan"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")
    
    valid_plans = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    if plan_name not in valid_plans:
        raise HTTPException(400, f"خطة غير معروفة: {plan_name}")
    
    result = upgrade_user_plan(user_id, plan_name)
    if not result.get("success", True):
        raise HTTPException(500, result.get("error", "حدث خطأ"))

    return {"success": True, "data": result}

# ─── POST /subscriptions/downgrade ────────────────────────
@router.post("/subscriptions/downgrade")
def downgrade_subscription(plan_name: str = Query(...), authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Downgrade to a lower plan"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    valid_plans = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    if plan_name not in valid_plans:
        raise HTTPException(400, f"خطة غير معروفة: {plan_name}")

    result = upgrade_user_plan(user_id, plan_name)
    if not result.get("success", True):
        raise HTTPException(500, result.get("error", "حدث خطأ"))

    return {"success": True, "data": result}

# ─── GET /entitlements/me ─────────────────────────────────
@router.get("/entitlements/me")
def get_my_entitlements(authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Get all entitlements for current user"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")
    
    entitlements = get_all_user_entitlements(user_id)
    if not entitlements:
        # Auto-create Free subscription
        create_user_subscription(user_id, "Free")
        entitlements = get_all_user_entitlements(user_id)
    
    return {"success": True, "data": {
        "user_id": user_id,
        "entitlements": entitlements,
        "total": len(entitlements)
    }}

# ─── GET /entitlements/check/{feature} ────────────────────
@router.get("/entitlements/check/{feature}")
def check_my_entitlement(feature: str, authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Check if current user has entitlement for a specific feature"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")
    
    allowed, value, message = check_entitlement(user_id, feature)
    return {"success": True, "data": {
        "feature": feature,
        "allowed": allowed,
        "current_value": value,
        "message": message
    }}

# ─── GET /plans/compare ──────────────────────────────────
@router.get("/plans/compare")
def compare_plans():
    """Compare all plans side by side"""
    plan_order = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    features = list(FEATURE_DESCRIPTIONS.keys())
    
    comparison = []
    for feature_key in features:
        desc = FEATURE_DESCRIPTIONS[feature_key]
        row = {
            "feature_key": feature_key,
            "name_ar": desc[0],
            "name_en": desc[1],
        }
        for plan in plan_order:
            row[plan] = PLAN_LIMITS.get(plan, {}).get(feature_key, "N/A")
        comparison.append(row)
    
    return {"success": True, "data": {"plans": plan_order, "comparison": comparison}}


# ─── Helper ───────────────────────────────────────────────
def _get_plan_display(plan_name):
    """Get display-friendly features for a plan"""
    features = PLAN_LIMITS.get(plan_name, {})
    display = []
    for key, value in features.items():
        desc = FEATURE_DESCRIPTIONS.get(key, ("", ""))
        display.append({
            "key": key,
            "value": value,
            "name_ar": desc[0],
            "is_available": value not in ("false", "none", "0"),
            "display_value": _format_value(value),
        })
    return display

def _format_value(value):
    """Format entitlement value for display"""
    if value == "true": return "✅ متاح"
    if value == "false": return "❌ غير متاح"
    if value == "unlimited": return "♾️ غير محدود"
    if value == "none": return "❌ غير متاح"
    if value == "browse_only": return "👁️ تصفح فقط"
    if value == "basic": return "📊 أساسي"
    if value == "full": return "📊 كامل"
    if value == "full_export": return "📊 كامل + تصدير"
    if value == "full_admin": return "📊 كامل + إدارة"
    if value == "limited": return "📊 محدود"
    if value == "request_services": return "🛒 طلب خدمات"
    if value == "request_manage": return "🛒 طلب + إدارة"
    if value == "provide_services": return "💼 تقديم خدمات"
    if value == "eligible_by_type": return "✅ حسب نوع العميل"
    if value == "by_permission": return "✅ حسب الصلاحية"
    if value == "full_governance": return "✅ كامل مع الحوكمة"
    if value == "custom": return "⚙️ مخصص"
    try:
        return f"📊 {int(value)} شهرياً"
    except Exception:
        return value
