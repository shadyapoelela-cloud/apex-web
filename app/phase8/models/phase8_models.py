"""
APEX Phase 8 — Plan Limits & Entitlement Audit Models
Uses UserSubscription and SubscriptionEntitlement from Phase 1.
Only adds: P8PlanLimit, P8EntitlementAuditLog (new tables)
"""
from sqlalchemy import Column, String, Integer, DateTime, JSON
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

class P8PlanLimit(Base):
    __tablename__ = "plan_limits"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    plan_name = Column(String, nullable=False, index=True)
    feature_key = Column(String, nullable=False)
    feature_value = Column(String, nullable=False)
    description_ar = Column(String, nullable=True)
    description_en = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

class P8EntitlementAuditLog(Base):
    __tablename__ = "entitlement_audit_log"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False)
    old_plan = Column(String, nullable=True)
    new_plan = Column(String, nullable=True)
    details = Column(JSON, nullable=True)
    performed_by = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

def init_phase8_db():
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    return ["plan_limits", "entitlement_audit_log"]
