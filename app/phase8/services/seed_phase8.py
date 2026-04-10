"""
APEX Phase 8 — Seed Plan Limits & Default Entitlements
Per Execution Master §4 + Zero Ambiguity §5, §10

Plans: Free, Pro, Business, Expert, Enterprise
Feature Keys per plan with limits
"""
import logging
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow, UserSubscription, SubscriptionEntitlement
from app.phase8.models.phase8_models import P8PlanLimit, P8EntitlementAuditLog

# ─── Plan Limits Matrix (Execution Master §4 + Zero Ambiguity §10) ─────
PLAN_LIMITS = {
    "Free": {
        "coa_uploads_limit": "2",
        "analysis_runs_limit": "2",
        "result_details_access": "basic",
        "knowledge_mode_access": "false",
        "marketplace_access": "browse_only",
        "provider_registration": "false",
        "team_members_limit": "0",
        "exports_downloads": "limited",
        "priority_support": "false",
        "api_access": "false",
        "enterprise_controls": "false",
        "provider_listing_priority": "false",
    },
    "Pro": {
        "coa_uploads_limit": "20",
        "analysis_runs_limit": "20",
        "result_details_access": "full",
        "knowledge_mode_access": "limited",
        "marketplace_access": "request_services",
        "provider_registration": "false",
        "team_members_limit": "3",
        "exports_downloads": "limited",
        "priority_support": "false",
        "api_access": "false",
        "enterprise_controls": "false",
        "provider_listing_priority": "false",
    },
    "Business": {
        "coa_uploads_limit": "100",
        "analysis_runs_limit": "100",
        "result_details_access": "full_export",
        "knowledge_mode_access": "eligible_by_type",
        "marketplace_access": "request_manage",
        "provider_registration": "false",
        "team_members_limit": "10",
        "exports_downloads": "full",
        "priority_support": "true",
        "api_access": "false",
        "enterprise_controls": "false",
        "provider_listing_priority": "false",
    },
    "Expert": {
        "coa_uploads_limit": "unlimited",
        "analysis_runs_limit": "unlimited",
        "result_details_access": "full",
        "knowledge_mode_access": "by_permission",
        "marketplace_access": "provide_services",
        "provider_registration": "true",
        "team_members_limit": "5",
        "exports_downloads": "full",
        "priority_support": "true",
        "api_access": "false",
        "enterprise_controls": "false",
        "provider_listing_priority": "false",
    },
    "Enterprise": {
        "coa_uploads_limit": "unlimited",
        "analysis_runs_limit": "unlimited",
        "result_details_access": "full_admin",
        "knowledge_mode_access": "full_governance",
        "marketplace_access": "custom",
        "provider_registration": "true",
        "team_members_limit": "unlimited",
        "exports_downloads": "full",
        "priority_support": "true",
        "api_access": "true",
        "enterprise_controls": "true",
        "provider_listing_priority": "true",
    },
}

# Arabic descriptions for each feature
FEATURE_DESCRIPTIONS = {
    "coa_uploads_limit": ("حد رفع شجرة الحسابات شهرياً", "Monthly COA upload limit"),
    "analysis_runs_limit": ("حد التحليلات شهرياً", "Monthly analysis runs limit"),
    "result_details_access": ("مستوى عرض تفاصيل النتائج", "Result details access level"),
    "knowledge_mode_access": ("وصول العقل المعرفي", "Knowledge mode access"),
    "marketplace_access": ("وصول سوق الخدمات", "Marketplace access level"),
    "provider_registration": ("تسجيل كمقدم خدمة", "Provider registration"),
    "team_members_limit": ("حد أعضاء الفريق", "Team members limit"),
    "exports_downloads": ("التصدير والتحميل", "Exports & downloads"),
    "priority_support": ("دعم أولوية", "Priority support"),
    "api_access": ("وصول API", "API access"),
    "enterprise_controls": ("أدوات التحكم المؤسسي", "Enterprise controls"),
    "provider_listing_priority": ("أولوية ظهور مقدم الخدمة", "Provider listing priority"),
}

def seed_plan_limits():
    """Seed plan_limits table with all plan features"""
    from app.phase8.models.phase8_models import PlanLimit
    db = SessionLocal()
    try:
        existing = db.query(PlanLimit).count()
        if existing > 0:
            return f"Already seeded: {existing} limits"
        
        count = 0
        for plan_name, features in PLAN_LIMITS.items():
            for feature_key, feature_value in features.items():
                desc = FEATURE_DESCRIPTIONS.get(feature_key, ("", ""))
                limit = PlanLimit(
                    id=gen_uuid(),
                    plan_name=plan_name,
                    feature_code=feature_key,
                    value=feature_value,
                    description_ar=desc[0],
                    description_en=desc[1],
                )
                db.add(limit)
                count += 1
        
        db.commit()
        return f"Seeded {count} plan limits across {len(PLAN_LIMITS)} plans"
    except Exception as e:
        db.rollback()
        return f"Seed error: {e}"
    finally:
        db.close()


def create_user_subscription(user_id, plan_name="Free"):
    """Create a default subscription for a new user"""
    from app.phase1.models.platform_models import UserSubscription
    db = SessionLocal()
    try:
        # Check if user already has subscription
        existing = db.query(UserSubscription).filter_by(user_id=user_id, status="active").first()
        if existing:
            return {"status": "exists", "plan": existing.plan_name}
        
        # Create subscription
        sub = UserSubscription(
            id=gen_uuid(),
            user_id=user_id,
            plan_id=plan_name.lower(),
            plan_name=plan_name,
            status="active",
        )
        db.add(sub)
        
        # Resolve entitlements from plan limits
        limits = PLAN_LIMITS.get(plan_name, PLAN_LIMITS["Free"])
        for feature_key, feature_value in limits.items():
            ent = SubscriptionEntitlement(
                id=gen_uuid(),
                user_id=user_id,
                feature_code=feature_key,
                value=feature_value,
                source="plan",
            )
            db.add(ent)
        
        db.commit()
        return {"success": True, "plan": plan_name, "entitlements": len(limits)}
    except Exception as e:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()


def upgrade_user_plan(user_id, new_plan_name):
    """Upgrade/downgrade user plan using Phase 1 models"""
    from app.phase1.models.platform_models import UserSubscription, Plan
    from app.phase8.models.phase8_models import P8EntitlementAuditLog
    db = SessionLocal()
    try:
        # Find new plan first
        new_plan = db.query(Plan).filter(
            (Plan.name_en == new_plan_name) | (Plan.code == new_plan_name.lower())
        ).first()
        
        if not new_plan:
            return {"success": False, "error": f"Plan not found: {new_plan_name}"}
        
        # Find current subscription
        current = db.query(UserSubscription).filter_by(user_id=user_id, status="active").first()
        
        old_plan_name = "None"
        if current:
            old_plan = db.query(Plan).filter_by(id=current.plan_id).first()
            old_plan_name = old_plan.name_en if old_plan else "None"
            # UPDATE existing subscription (unique constraint on user_id)
            current.plan_id = new_plan.id
        else:
            # Create new subscription
            sub = UserSubscription(
                id=gen_uuid(),
                user_id=user_id,
                plan_id=new_plan.id,
                status="active",
            )
            db.add(sub)
        
        # Audit log
        audit = P8EntitlementAuditLog(
            id=gen_uuid(),
            user_id=user_id,
            action="plan_changed",
            old_plan=old_plan_name,
            new_plan=new_plan_name,
            performed_by=user_id,
        )
        db.add(audit)
        
        db.commit()
        return {"success": True, "old_plan": old_plan_name, "new_plan": new_plan_name}
    except Exception as e:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()

