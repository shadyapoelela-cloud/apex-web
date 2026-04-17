"""
APEX Platform — Subscription & Entitlement Service
═══════════════════════════════════════════════════════════════
Plan management, upgrade/downgrade, entitlement resolution.

Resolution chain (per execution document):
  permission check → subscription entitlement check → business rule check → ownership check
"""

import logging
from app.phase1.models.platform_models import (
    Plan,
    PlanFeature,
    UserSubscription,
    SubscriptionEntitlement,
    Notification,
    AuditEvent,
    SubscriptionStatus,
    SessionLocal,
    gen_uuid,
    utcnow,
)


class SubscriptionService:

    def get_plans(self) -> list:
        """List all active plans."""
        db = SessionLocal()
        try:
            plans = db.query(Plan).filter(Plan.is_active == True).order_by(Plan.sort_order).all()
            # Batch-fetch ALL features in one query (fixes N+1)
            plan_ids = [p.id for p in plans]
            all_features = db.query(PlanFeature).filter(PlanFeature.plan_id.in_(plan_ids)).all() if plan_ids else []
            features_map = {}
            for f in all_features:
                features_map.setdefault(f.plan_id, []).append(f)

            result = []
            for p in plans:
                features = features_map.get(p.id, [])
                result.append(
                    {
                        "id": p.id,
                        "code": p.code,
                        "name_ar": p.name_ar,
                        "name_en": p.name_en,
                        "description_ar": p.description_ar,
                        "description_en": p.description_en,
                        # Serialize Numeric -> float for JSON (Decimal is not JSON-native)
                        "price_monthly_sar": float(p.price_monthly_sar or 0),
                        "price_yearly_sar": float(p.price_yearly_sar or 0),
                        "currency": p.currency or "SAR",
                        "target_user_ar": p.target_user_ar,
                        "target_user_en": p.target_user_en,
                        "features": {
                            f.feature_code: {"value": f.value, "type": f.value_type, "name_ar": f.feature_name_ar}
                            for f in features
                        },
                    }
                )
            return result
        finally:
            db.close()

    def get_user_subscription(self, user_id: str) -> dict:
        """Get current subscription + entitlements for user."""
        db = SessionLocal()
        try:
            sub = db.query(UserSubscription).filter(UserSubscription.user_id == user_id).first()
            if not sub:
                return {"plan": "free", "status": "none", "entitlements": {}}

            plan = db.query(Plan).filter(Plan.id == sub.plan_id).first()
            entitlements = db.query(SubscriptionEntitlement).filter(SubscriptionEntitlement.user_id == user_id).all()

            return {
                "subscription_id": sub.id,
                "plan": plan.code if plan else "free",
                "plan_name_ar": plan.name_ar if plan else "مجاني",
                "plan_name_en": plan.name_en if plan else "Free",
                "status": sub.status,
                "billing_cycle": sub.billing_cycle,
                "started_at": sub.started_at.isoformat() if sub.started_at else None,
                "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
                "entitlements": {e.feature_code: {"value": e.value, "type": e.value_type} for e in entitlements},
            }
        finally:
            db.close()

    def upgrade_plan(self, user_id: str, new_plan_code: str) -> dict:
        """Upgrade user to a new plan — immediately updates entitlements."""
        db = SessionLocal()
        try:
            new_plan = db.query(Plan).filter(Plan.code == new_plan_code, Plan.is_active == True).first()
            if not new_plan:
                return {"success": False, "error": "الخطة غير موجودة"}

            sub = db.query(UserSubscription).filter(UserSubscription.user_id == user_id).first()
            old_plan_code = "free"

            if sub:
                old_plan = db.query(Plan).filter(Plan.id == sub.plan_id).first()
                old_plan_code = old_plan.code if old_plan else "free"
                sub.previous_plan_id = sub.plan_id
                sub.plan_id = new_plan.id
                sub.status = SubscriptionStatus.active.value
                sub.started_at = utcnow()
            else:
                sub = UserSubscription(
                    id=gen_uuid(),
                    user_id=user_id,
                    plan_id=new_plan.id,
                    status=SubscriptionStatus.active.value,
                    billing_cycle="monthly",
                )
                db.add(sub)

            # Refresh entitlements — delete old, insert new
            db.query(SubscriptionEntitlement).filter(SubscriptionEntitlement.user_id == user_id).delete()

            features = db.query(PlanFeature).filter(PlanFeature.plan_id == new_plan.id).all()
            for f in features:
                db.add(
                    SubscriptionEntitlement(
                        id=gen_uuid(),
                        user_id=user_id,
                        feature_code=f.feature_code,
                        value_type=f.value_type,
                        value=f.value,
                        source_plan_id=new_plan.id,
                    )
                )

            # Audit
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="plan_upgrade",
                    resource_type="subscription",
                    details={"from": old_plan_code, "to": new_plan_code},
                )
            )

            # Notification
            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=user_id,
                    title_ar=f"تمت ترقية خطتك إلى {new_plan.name_ar}",
                    title_en=f"Plan upgraded to {new_plan.name_en}",
                    category="subscription",
                    source_type="plan_upgrade",
                )
            )

            db.commit()

            return {
                "success": True,
                "message": f"تمت الترقية من {old_plan_code} إلى {new_plan_code}",
                "plan": new_plan_code,
            }

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "خطأ داخلي في الخادم — حاول لاحقاً أو تواصل مع الدعم"}
        finally:
            db.close()

    def downgrade_plan(self, user_id: str, new_plan_code: str) -> dict:
        """Downgrade — same logic as upgrade but different audit."""
        result = self.upgrade_plan(user_id, new_plan_code)
        if result.get("success"):
            result["message"] = result["message"].replace("الترقية", "التخفيض")
        return result


class EntitlementEngine:
    """
    Resolution chain:
    1. Permission check (role-based)
    2. Subscription entitlement check (plan-based)
    3. Business rule check (context-specific)
    4. Ownership check (resource-specific)
    """

    def check_permission(self, user_id: str, permission_code: str) -> bool:
        """Check if user's roles grant the permission."""
        db = SessionLocal()
        try:
            from sqlalchemy import text

            result = db.execute(
                text("""
                SELECT COUNT(*) FROM role_permissions rp
                JOIN user_roles ur ON ur.role_id = rp.role_id
                JOIN permissions p ON p.id = rp.permission_id
                WHERE ur.user_id = :uid AND p.code = :pcode
            """),
                {"uid": user_id, "pcode": permission_code},
            ).scalar()
            return result > 0
        except Exception:
            return False
        finally:
            db.close()

    def check_entitlement(self, user_id: str, feature_code: str) -> dict:
        """Check if user's plan includes the feature."""
        db = SessionLocal()
        try:
            ent = (
                db.query(SubscriptionEntitlement)
                .filter(
                    SubscriptionEntitlement.user_id == user_id,
                    SubscriptionEntitlement.feature_code == feature_code,
                )
                .first()
            )

            if not ent:
                return {"allowed": False, "reason": "feature_not_in_plan", "value": None}

            if ent.value_type == "boolean":
                allowed = ent.value.lower() in ("true", "1", "yes")
                return {"allowed": allowed, "reason": "plan_entitlement", "value": ent.value}
            elif ent.value_type == "integer":
                return {"allowed": True, "reason": "plan_entitlement", "value": int(ent.value), "limit": True}
            else:
                return {"allowed": True, "reason": "plan_entitlement", "value": ent.value}
        finally:
            db.close()

    def can_access(self, user_id: str, permission_code: str, feature_code: str) -> dict:
        """Full resolution chain: permission + entitlement."""
        # Step 1: Permission check
        has_permission = self.check_permission(user_id, permission_code)
        if not has_permission:
            return {"allowed": False, "reason": "no_role_permission", "permission": permission_code}

        # Step 2: Entitlement check
        ent = self.check_entitlement(user_id, feature_code)
        if not ent["allowed"]:
            return {"allowed": False, "reason": "plan_not_entitled", "feature": feature_code}

        return {"allowed": True, "reason": "authorized", "permission": permission_code, "feature": feature_code}
