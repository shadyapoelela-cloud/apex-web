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

from fastapi import APIRouter, HTTPException, Query, Header
import logging
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase8.middleware.entitlement_middleware import (
    get_user_subscription,
    get_all_user_entitlements,
    check_entitlement,
)
from app.phase8.services.seed_phase8 import (
    PLAN_LIMITS,
    FEATURE_DESCRIPTIONS,
    create_user_subscription,
    upgrade_user_plan,
)

router = APIRouter()

# ─── Plan ordering for upgrade/downgrade validation ──────
PLAN_ORDER = {"Free": 0, "Pro": 1, "Business": 2, "Expert": 3, "Enterprise": 4}

# ─── Plan pricing (SAR) ──────────────────────────────────
PLAN_PRICES = {
    "Free": {"monthly": 0, "yearly": 0},
    "Pro": {"monthly": 99, "yearly": 990},
    "Business": {"monthly": 299, "yearly": 2990},
    "Expert": {"monthly": 0, "yearly": 0},  # commission-based
    "Enterprise": {"monthly": 0, "yearly": 0},  # custom pricing
}


# ─── Helper: Extract user_id from token (SECURE) ─────────
def get_current_user_id(authorization: str = None):
    """Extract user_id from JWT with proper signature verification."""
    if not authorization:
        return None
    # Clean up Bearer prefix if doubled
    if authorization.startswith("Bearer Bearer "):
        authorization = authorization.replace("Bearer Bearer ", "Bearer ")
    try:
        import jwt
        from app.core.auth_utils import JWT_SECRET, JWT_ALGORITHM

        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload.get("sub") or payload.get("user_id")
    except Exception:
        return None


# ─── GET /subscriptions/me ────────────────────────────────
# NOTE: /subscriptions/debug REMOVED (v11.4.0) — exposed sensitive data without auth


@router.get("/subscriptions/me")
def get_my_subscription(authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Get current subscription for logged-in user"""

    # Simple auth extraction
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    sub = get_user_subscription(user_id)
    if not sub:
        # Auto-create Free subscription
        create_user_subscription(user_id, "Free")
        sub = get_user_subscription(user_id)

    entitlements = get_all_user_entitlements(user_id)

    return {
        "success": True,
        "data": {
            "subscription": sub,
            "entitlements": entitlements,
            "plan_features": _get_plan_display(sub["plan_name"] if sub else "Free"),
        },
    }


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
            display_features.append(
                {
                    "key": key,
                    "value": value,
                    "name_ar": desc[0],
                    "name_en": desc[1],
                    "is_available": value not in ("false", "none", "0"),
                }
            )

        plans.append(
            {
                "name": plan_name,
                "pricing": prices.get(plan_name, {}),
                "features": display_features,
                "feature_count": sum(1 for f in display_features if f["is_available"]),
            }
        )

    return {"success": True, "data": {"plans": plans}}


# ─── Helper: get current plan name for a user ────────────
def _get_current_plan_name(user_id: str) -> str:
    """Return the current plan name for a user, or 'Free' if none."""
    sub = get_user_subscription(user_id)
    if sub and sub.get("plan_name"):
        return sub["plan_name"]
    return "Free"


# ─── POST /subscriptions/upgrade ──────────────────────────
@router.post("/subscriptions/upgrade")
def upgrade_subscription(
    plan_name: str = Query(...), authorization: str = None, x_token: str = Header(None, alias="Authorization")
):
    """Upgrade to a new plan"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    valid_plans = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    if plan_name not in valid_plans:
        raise HTTPException(400, f"خطة غير معروفة: {plan_name}")

    current_plan = _get_current_plan_name(user_id)
    current_order = PLAN_ORDER.get(current_plan, 0)
    new_order = PLAN_ORDER.get(plan_name, 0)
    if new_order <= current_order:
        raise HTTPException(400, f"الترقية تتطلب خطة أعلى من {current_plan}. استخدم نقطة التخفيض بدلاً من ذلك")

    result = upgrade_user_plan(user_id, plan_name)
    if not result.get("success", True):
        raise HTTPException(500, result.get("error", "حدث خطأ"))

    return {"success": True, "data": result}


# ─── POST /subscriptions/downgrade ────────────────────────
@router.post("/subscriptions/downgrade")
def downgrade_subscription(
    plan_name: str = Query(...), authorization: str = None, x_token: str = Header(None, alias="Authorization")
):
    """Downgrade to a lower plan"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    valid_plans = ["Free", "Pro", "Business", "Expert", "Enterprise"]
    if plan_name not in valid_plans:
        raise HTTPException(400, f"خطة غير معروفة: {plan_name}")

    current_plan = _get_current_plan_name(user_id)
    current_order = PLAN_ORDER.get(current_plan, 0)
    new_order = PLAN_ORDER.get(plan_name, 0)
    if new_order >= current_order:
        raise HTTPException(400, f"التخفيض يتطلب خطة أقل من {current_plan}. استخدم نقطة الترقية بدلاً من ذلك")

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

    return {"success": True, "data": {"user_id": user_id, "entitlements": entitlements, "total": len(entitlements)}}


# ─── GET /entitlements/check/{feature} ────────────────────
@router.get("/entitlements/check/{feature}")
def check_my_entitlement(feature: str, authorization: str = None, x_token: str = Header(None, alias="Authorization")):
    """Check if current user has entitlement for a specific feature"""
    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    allowed, value, message = check_entitlement(user_id, feature)
    return {
        "success": True,
        "data": {"feature": feature, "allowed": allowed, "current_value": value, "message": message},
    }


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
        display.append(
            {
                "key": key,
                "value": value,
                "name_ar": desc[0],
                "is_available": value not in ("false", "none", "0"),
                "display_value": _format_value(value),
            }
        )
    return display


def _format_value(value):
    """Format entitlement value for display"""
    if value == "true":
        return "✅ متاح"
    if value == "false":
        return "❌ غير متاح"
    if value == "unlimited":
        return "♾️ غير محدود"
    if value == "none":
        return "❌ غير متاح"
    if value == "browse_only":
        return "👁️ تصفح فقط"
    if value == "basic":
        return "📊 أساسي"
    if value == "full":
        return "📊 كامل"
    if value == "full_export":
        return "📊 كامل + تصدير"
    if value == "full_admin":
        return "📊 كامل + إدارة"
    if value == "limited":
        return "📊 محدود"
    if value == "request_services":
        return "🛒 طلب خدمات"
    if value == "request_manage":
        return "🛒 طلب + إدارة"
    if value == "provide_services":
        return "💼 تقديم خدمات"
    if value == "eligible_by_type":
        return "✅ حسب نوع العميل"
    if value == "by_permission":
        return "✅ حسب الصلاحية"
    if value == "full_governance":
        return "✅ كامل مع الحوكمة"
    if value == "custom":
        return "⚙️ مخصص"
    try:
        return f"📊 {int(value)} شهرياً"
    except Exception:
        return value


# ═══════════════════════════════════════════════════════════════
# Payment Gateway Endpoints
# ═══════════════════════════════════════════════════════════════


# ─── POST /subscriptions/checkout ─────────────────────────────
@router.post("/subscriptions/checkout")
def create_checkout(
    plan_name: str = Query(...),
    period: str = Query("monthly"),
    authorization: str = None,
    x_token: str = Header(None, alias="Authorization"),
):
    """Create a payment checkout session for a plan."""
    from app.core.payment_service import create_checkout_session, PAYMENT_BACKEND
    from app.phase8.models.phase8_models import PaymentRecord

    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    if plan_name not in PLAN_PRICES:
        raise HTTPException(400, f"خطة غير معروفة: {plan_name}")

    if period not in ("monthly", "yearly"):
        raise HTTPException(400, "الفترة يجب أن تكون monthly أو yearly")

    amount = PLAN_PRICES[plan_name].get(period, 0)

    # Create checkout session via payment service
    result = create_checkout_session(
        user_id=user_id,
        plan_code=plan_name,
        plan_name=plan_name,
        amount_sar=amount,
        period=period,
    )

    if not result.get("success"):
        raise HTTPException(500, result.get("error", "فشل إنشاء جلسة الدفع"))

    # Save PaymentRecord with status=pending
    db = SessionLocal()
    try:
        record = PaymentRecord(
            id=gen_uuid(),
            user_id=user_id,
            plan_code=plan_name,
            amount=amount,
            currency="SAR",
            payment_method=PAYMENT_BACKEND,
            session_id=result["session_id"],
            status="pending",
            created_at=utcnow(),
        )
        db.add(record)
        db.commit()
    except Exception as e:
        db.rollback()
        logging.error("Failed to save payment record: %s", e)
    finally:
        db.close()

    return {
        "success": True,
        "data": {
            "checkout_url": result["checkout_url"],
            "session_id": result["session_id"],
            "plan": plan_name,
            "amount": amount,
            "currency": "SAR",
            "period": period,
        },
    }


# ─── POST /subscriptions/verify-payment ──────────────────────
@router.post("/subscriptions/verify-payment")
def verify_payment_endpoint(
    session_id: str = Query(...),
    authorization: str = None,
    x_token: str = Header(None, alias="Authorization"),
):
    """Verify payment and activate the user's plan."""
    from app.core.payment_service import verify_payment
    from app.phase8.models.phase8_models import PaymentRecord

    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    # Look up payment record
    db = SessionLocal()
    try:
        record = (
            db.query(PaymentRecord)
            .filter(PaymentRecord.session_id == session_id, PaymentRecord.user_id == user_id)
            .first()
        )
        if not record:
            raise HTTPException(404, "سجل الدفع غير موجود")

        if record.status == "completed":
            return {"success": True, "data": {"message": "تم تفعيل الدفع مسبقاً", "plan": record.plan_code}}

        # Verify with payment backend
        result = verify_payment(session_id)
        if not result.get("success"):
            raise HTTPException(500, result.get("error", "فشل التحقق من الدفع"))

        if result.get("paid"):
            # Update payment record
            record.status = "completed"
            record.completed_at = utcnow()
            db.commit()

            # Activate the plan
            plan_code = record.plan_code
            upgrade_result = upgrade_user_plan(user_id, plan_code)

            return {
                "success": True,
                "data": {
                    "message": f"تم تفعيل خطة {plan_code} بنجاح",
                    "plan": plan_code,
                    "paid": True,
                    "upgrade_result": upgrade_result,
                },
            }
        else:
            record.status = "failed"
            db.commit()
            return {"success": True, "data": {"paid": False, "message": "لم يتم إتمام الدفع"}}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Payment verification error: %s", e)
        raise HTTPException(500, "حدث خطأ أثناء التحقق من الدفع")
    finally:
        db.close()


# ─── GET /subscriptions/payment-history ───────────────────────
@router.get("/subscriptions/payment-history")
def get_payment_history_endpoint(
    authorization: str = None,
    x_token: str = Header(None, alias="Authorization"),
):
    """Get the current user's payment history."""
    from app.core.payment_service import get_payment_history

    user_id = get_current_user_id(authorization or x_token)
    if not user_id:
        raise HTTPException(401, "يجب تسجيل الدخول")

    history = get_payment_history(user_id)
    return {"success": True, "data": {"payments": history, "total": len(history)}}
