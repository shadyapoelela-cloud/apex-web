"""
APEX Phase 8 — Plan Limits & Entitlement Audit Models
Uses UserSubscription and SubscriptionEntitlement from Phase 1.
Only adds: P8PlanLimit, P8EntitlementAuditLog (new tables)
"""

from sqlalchemy import Column, String, Float, Numeric, DateTime, JSON, ForeignKey, Integer, Boolean
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


class PaymentRecord(Base):
    __tablename__ = "payment_records"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    plan_code = Column(String, nullable=False)
    amount = Column(Numeric(18, 2), nullable=False)  # currency-exact
    tax_amount = Column(Numeric(18, 2), default=0, nullable=False)  # VAT/tax portion
    net_amount = Column(Numeric(18, 2), nullable=True)  # amount - tax_amount
    currency = Column(String(3), default="SAR", nullable=False)
    payment_method = Column(String)  # stripe, mock
    session_id = Column(String, index=True)
    # Idempotency key to prevent double-charging (required by all serious payment systems)
    idempotency_key = Column(String(64), unique=True, nullable=True, index=True)
    status = Column(String, default="pending")  # pending, completed, failed, refunded
    # ZATCA / e-invoice reference
    einvoice_uuid = Column(String(36), nullable=True, index=True)
    einvoice_hash = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=utcnow)
    completed_at = Column(DateTime, nullable=True)


def init_phase8_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["plan_limits", "entitlement_audit_log", "payment_records"]
