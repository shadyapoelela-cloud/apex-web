"""
APEX Platform — Phase 5 Models
═══════════════════════════════════════════════════════════════
Service Requests + Tasks + Compliance + Suspension Engine

Migrations 11-13 per execution document:
  11: service_requests, service_request_messages
  12: task_compliance_events, compliance_actions
  13: suspension_events, suspension_appeals
"""

import enum
from sqlalchemy import (
    Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, JSON, Index,
)
from sqlalchemy.orm import relationship
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class RequestStatus(str, enum.Enum):
    draft = "draft"
    open = "open"
    matched = "matched"
    in_progress = "in_progress"
    delivered = "delivered"
    revision_requested = "revision_requested"
    completed = "completed"
    cancelled = "cancelled"
    disputed = "disputed"


class TaskComplianceStatus(str, enum.Enum):
    on_track = "on_track"
    warning = "warning"
    overdue = "overdue"
    escalated = "escalated"
    resolved = "resolved"


class SuspensionType(str, enum.Enum):
    provider_suspension = "provider_suspension"
    client_suspension = "client_suspension"
    user_suspension = "user_suspension"
    account_freeze = "account_freeze"


class SuspensionReason(str, enum.Enum):
    repeated_overdue = "repeated_overdue"
    quality_issues = "quality_issues"
    policy_violation = "policy_violation"
    fraud_suspected = "fraud_suspected"
    payment_issues = "payment_issues"
    manual_admin = "manual_admin"


class AppealStatus(str, enum.Enum):
    submitted = "submitted"
    under_review = "under_review"
    accepted = "accepted"
    rejected = "rejected"


# ═══════════════════════════════════════════════════════════════
# Migration 11: Service Requests
# ═══════════════════════════════════════════════════════════════

class ServiceRequest(Base):
    """Client request for a professional service."""
    __tablename__ = "service_requests"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id"), nullable=False, index=True)
    requested_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    provider_id = Column(String(36), ForeignKey("service_providers.id"), nullable=True, index=True)

    # Request details
    title = Column(String(300), nullable=False)
    description = Column(Text, nullable=False)
    scope_code = Column(String(80), nullable=True)
    category_required = Column(String(50), nullable=True)
    urgency = Column(String(20), default="normal")  # low, normal, high, urgent
    budget_sar = Column(Float, nullable=True)

    # Status
    status = Column(String(30), default=RequestStatus.open.value, nullable=False)
    accepted_at = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)

    # Deadline
    deadline = Column(DateTime, nullable=True)
    deadline_extended = Column(Boolean, default=False)

    # Rating (after completion)
    client_rating = Column(Integer, nullable=True)  # 1-5
    client_review = Column(Text, nullable=True)
    provider_rating = Column(Integer, nullable=True)
    provider_review = Column(Text, nullable=True)

    # Payment
    agreed_price_sar = Column(Float, nullable=True)
    platform_commission = Column(Float, nullable=True)
    provider_payout = Column(Float, nullable=True)
    payment_status = Column(String(20), default="pending")

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    messages = relationship("ServiceRequestMessage", back_populates="request", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_request_status_client", "status", "client_id"),
        Index("ix_request_provider", "provider_id", "status"),
    )


class ServiceRequestMessage(Base):
    """Messages between client and provider for a request."""
    __tablename__ = "service_request_messages"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    request_id = Column(String(36), ForeignKey("service_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    message = Column(Text, nullable=False)
    is_system = Column(Boolean, default=False)
    attachment_filename = Column(String(300), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    request = relationship("ServiceRequest", back_populates="messages")


# ═══════════════════════════════════════════════════════════════
# Migration 12: Task Compliance
# ═══════════════════════════════════════════════════════════════

class TaskComplianceEvent(Base):
    """Track compliance status for service requests."""
    __tablename__ = "task_compliance_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    request_id = Column(String(36), ForeignKey("service_requests.id"), nullable=False, index=True)
    provider_id = Column(String(36), ForeignKey("service_providers.id"), nullable=False, index=True)
    status = Column(String(20), nullable=False)
    reason = Column(Text, nullable=True)
    days_overdue = Column(Integer, default=0)
    auto_generated = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_compliance_provider", "provider_id", "status"),
    )


class ComplianceAction(Base):
    """Actions taken for compliance issues."""
    __tablename__ = "compliance_actions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    compliance_event_id = Column(String(36), ForeignKey("task_compliance_events.id"), nullable=False, index=True)
    action_type = Column(String(50), nullable=False)  # warning_sent, deadline_extended, escalated, suspended
    action_by = Column(String(36), nullable=True)  # null = system
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


# ═══════════════════════════════════════════════════════════════
# Migration 13: Suspension Engine
# ═══════════════════════════════════════════════════════════════

class SuspensionEvent(Base):
    """Suspension records for providers, clients, users."""
    __tablename__ = "suspension_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    target_type = Column(String(30), nullable=False)  # provider, client, user
    target_id = Column(String(36), nullable=False, index=True)
    suspension_type = Column(String(50), nullable=False)
    reason = Column(String(50), nullable=False)
    reason_details = Column(Text, nullable=True)
    suspended_by = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)  # null = system
    is_active = Column(Boolean, default=True)
    started_at = Column(DateTime, default=utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)
    lifted_at = Column(DateTime, nullable=True)
    lifted_by = Column(String(36), nullable=True)

    appeals = relationship("SuspensionAppeal", back_populates="suspension", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_suspension_target", "target_type", "target_id", "is_active"),
    )


class SuspensionAppeal(Base):
    """Appeals against suspensions."""
    __tablename__ = "suspension_appeals"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    suspension_id = Column(String(36), ForeignKey("suspension_events.id", ondelete="CASCADE"), nullable=False, index=True)
    appealed_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    appeal_text = Column(Text, nullable=False)
    status = Column(String(20), default=AppealStatus.submitted.value, nullable=False)
    reviewed_by = Column(String(36), nullable=True)
    reviewer_notes = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    suspension = relationship("SuspensionEvent", back_populates="appeals")


def init_phase5_db():
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    return ["service_requests", "service_request_messages", "task_compliance_events",
            "compliance_actions", "suspension_events", "suspension_appeals"]
