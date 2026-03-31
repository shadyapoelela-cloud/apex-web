"""
APEX Phase 8 — Subscription & Entitlement Models
Per Execution Master §4 + Zero Ambiguity §5

Tables:
- user_subscriptions: links user to active plan
- plan_limits: feature limits per plan (uploads, runs, etc.)
- subscription_entitlements: resolved feature flags per user
- entitlement_audit_log: tracks changes to entitlements
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# ─── User Subscription (1 active per user) ───────────────
class P8UserSubscription(Base):
    __tablename__ = "user_subscriptions"
    __table_args__ = {"extend_existing": True}
    
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    plan_id = Column(String, nullable=False)  # references plans.id
    plan_name = Column(String, nullable=False)  # Free/Pro/Business/Expert/Enterprise
    status = Column(String, default="active")  # active, expired, cancelled, suspended
    started_at = Column(DateTime, default=utcnow)
    expires_at = Column(DateTime, nullable=True)
    renewed_at = Column(DateTime, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)
    previous_plan_id = Column(String, nullable=True)
    upgrade_path = Column(String, nullable=True)  # next recommended plan
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)

# ─── Plan Limits (per plan feature flags + limits) ───────
class P8PlanLimit(Base):
    __tablename__ = "plan_limits"
    __table_args__ = {"extend_existing": True}
    
    id = Column(String, primary_key=True, default=gen_uuid)
    plan_name = Column(String, nullable=False, index=True)  # Free/Pro/Business/Expert/Enterprise
    feature_key = Column(String, nullable=False)  # coa_uploads_limit, analysis_runs_limit, etc.
    feature_value = Column(String, nullable=False)  # number or "true"/"false"/"unlimited"
    description_ar = Column(String, nullable=True)
    description_en = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

# ─── Subscription Entitlements (resolved per user) ───────
class P8SubscriptionEntitlement(Base):
    __tablename__ = "subscription_entitlements"
    __table_args__ = {"extend_existing": True}
    
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    feature_key = Column(String, nullable=False)
    feature_value = Column(String, nullable=False)
    source = Column(String, default="plan")  # plan, override, promotion
    granted_at = Column(DateTime, default=utcnow)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)

# ─── Entitlement Audit Log ────────────────────────────────
class P8EntitlementAuditLog(Base):
    __tablename__ = "entitlement_audit_log"
    __table_args__ = {"extend_existing": True}
    
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False)  # subscription_created, upgraded, downgraded, entitlement_changed
    old_plan = Column(String, nullable=True)
    new_plan = Column(String, nullable=True)
    details = Column(JSON, nullable=True)
    performed_by = Column(String, nullable=True)  # user_id or "system"
    created_at = Column(DateTime, default=utcnow)


def init_phase8_db():
    """Create all Phase 8 tables"""
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    tables = [t for t in Base.metadata.tables if t in [
        "user_subscriptions", "plan_limits", "subscription_entitlements", "entitlement_audit_log"
    ]]
    return tables
