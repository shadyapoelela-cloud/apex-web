"""
APEX Platform â€” Database Models Phase 1
â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
Identity + Account + Plans + Entitlements + Legal Acceptance

Based on: Apex_Final_Claude_Execution_Master_v1.pdf
Migrations 01-04: users, roles, subscriptions, legal

All tables use:
- UUID primary keys
- created_at / updated_at timestamps
- soft delete (is_deleted + deleted_at) where applicable
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    create_engine, Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, Enum, JSON, Index, UniqueConstraint,
    event,
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
from sqlalchemy.sql import func
import enum
import os

# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Database Setup
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

DB_URL = os.environ.get("DATABASE_URL", "sqlite:///apex_platform.db")
# Render PostgreSQL fix: postgres:// -> postgresql://
if DB_URL.startswith("postgres://"):
    DB_URL = DB_URL.replace("postgres://", "postgresql://", 1)
if DB_URL.startswith("sqlite"):
    engine = create_engine(DB_URL, connect_args={"check_same_thread": False}, echo=False)
else:
    engine = create_engine(DB_URL, pool_size=10, max_overflow=20, pool_pre_ping=True, echo=False)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def gen_uuid():
    return str(uuid.uuid4())


def utcnow():
    return datetime.now(timezone.utc)


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# ENUMS â€” Centralized (per execution document rule)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class UserStatus(str, enum.Enum):
    active = "active"
    suspended = "suspended"
    deactivated_temp = "deactivated_temp"
    deactivated_permanent = "deactivated_permanent"
    pending_verification = "pending_verification"


class RoleCode(str, enum.Enum):
    guest = "guest"
    registered_user = "registered_user"
    client_user = "client_user"
    client_admin = "client_admin"
    provider_user = "provider_user"
    provider_admin = "provider_admin"
    reviewer = "reviewer"
    knowledge_reviewer = "knowledge_reviewer"
    platform_admin = "platform_admin"
    super_admin = "super_admin"


class PlanCode(str, enum.Enum):
    free = "free"
    pro = "pro"
    business = "business"
    expert = "expert"
    enterprise = "enterprise"


class SubscriptionStatus(str, enum.Enum):
    active = "active"
    expired = "expired"
    cancelled = "cancelled"
    suspended = "suspended"
    trial = "trial"


class PolicyType(str, enum.Enum):
    terms_of_service = "terms_of_service"
    privacy_policy = "privacy_policy"
    acceptable_use = "acceptable_use"
    provider_policy = "provider_policy"
    document_upload_policy = "document_upload_policy"
    knowledge_contributor_policy = "knowledge_contributor_policy"


class SecurityEventType(str, enum.Enum):
    login = "login"
    logout = "logout"
    password_change = "password_change"
    password_reset_request = "password_reset_request"
    password_reset_complete = "password_reset_complete"
    failed_login = "failed_login"
    session_revoked = "session_revoked"
    account_deactivated = "account_deactivated"
    account_reactivated = "account_reactivated"
    suspicious_activity = "suspicious_activity"


class ClosureType(str, enum.Enum):
    temporary = "temporary"
    permanent = "permanent"


class ClosureStatus(str, enum.Enum):
    requested = "requested"
    approved = "approved"
    completed = "completed"
    cancelled = "cancelled"


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Migration 01: Users + Auth Core
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class User(Base):
    """Primary user account â€” unique identity for login."""
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    mobile = Column(String(20), unique=True, nullable=True)
    display_name = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    status = Column(String(30), default=UserStatus.pending_verification.value, nullable=False)
    email_verified = Column(Boolean, default=False)
    mobile_verified = Column(Boolean, default=False)
    last_login_at = Column(DateTime, nullable=True)
    login_count = Column(Integer, default=0)
    failed_login_count = Column(Integer, default=0)
    locked_until = Column(DateTime, nullable=True)
    language = Column(String(5), default="ar")
    timezone = Column(String(50), default="Asia/Riyadh")

    # Soft delete
    # Social Auth + Mobile (Doc v5 Section 5)
    auth_provider = Column(String(20), nullable=True)  # local, google, apple
    google_sub = Column(String(100), nullable=True)
    apple_sub = Column(String(100), nullable=True)
    mobile_country_code = Column(String(10), nullable=True, default='+966')
    mobile_number = Column(String(20), nullable=True)
    mobile_verified = Column(Boolean, default=False)
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    roles = relationship("UserRole", back_populates="user", cascade="all, delete-orphan")
    sessions = relationship("UserSession", back_populates="user", cascade="all, delete-orphan")
    security_events = relationship("UserSecurityEvent", back_populates="user", cascade="all, delete-orphan")
    subscription = relationship("UserSubscription", back_populates="user", uselist=False, cascade="all, delete-orphan")
    entitlements = relationship("SubscriptionEntitlement", back_populates="user", cascade="all, delete-orphan")
    acceptance_logs = relationship("PolicyAcceptanceLog", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    closure_requests = relationship("AccountClosureRequest", back_populates="user", cascade="all, delete-orphan")


class UserProfile(Base):
    """Extended profile â€” personal info, preferences."""
    __tablename__ = "user_profiles"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    bio = Column(Text, nullable=True)
    organization_name = Column(String(200), nullable=True)
    job_title = Column(String(100), nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(50), default="SA")
    avatar_url = Column(String(500), nullable=True)
    notification_email = Column(Boolean, default=True)
    notification_sms = Column(Boolean, default=False)
    notification_in_app = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    user = relationship("User", back_populates="profile")


class UserSession(Base):
    """Active login sessions â€” for session management & security."""
    __tablename__ = "user_sessions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(255), nullable=False, unique=True)
    refresh_token_hash = Column(String(255), nullable=True, unique=True)
    device_info = Column(String(500), nullable=True)
    ip_address = Column(String(45), nullable=True)
    is_active = Column(Boolean, default=True)
    expires_at = Column(DateTime, nullable=False)
    last_used_at = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("User", back_populates="sessions")


class PasswordReset(Base):
    """Password reset tokens."""
    __tablename__ = "password_resets"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(255), nullable=False, unique=True)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class UserSecurityEvent(Base):
    """Audit log for security-sensitive actions."""
    __tablename__ = "user_security_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    event_type = Column(String(50), nullable=False)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)
    details = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("User", back_populates="security_events")

    __table_args__ = (
        Index("ix_security_events_user_type", "user_id", "event_type"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Migration 02: Roles + Permissions
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class Role(Base):
    """Platform roles â€” 10 defined in execution document."""
    __tablename__ = "roles"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(30), unique=True, nullable=False)
    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    is_system = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class Permission(Base):
    """Granular permissions."""
    __tablename__ = "permissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(80), unique=True, nullable=False)
    name_ar = Column(String(150), nullable=True)
    name_en = Column(String(150), nullable=True)
    resource = Column(String(50), nullable=False)
    action = Column(String(30), nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_perm_resource_action", "resource", "action"),
    )


class RolePermission(Base):
    """Many-to-many: Role â†” Permission."""
    __tablename__ = "role_permissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    role_id = Column(String(36), ForeignKey("roles.id", ondelete="CASCADE"), nullable=False)
    permission_id = Column(String(36), ForeignKey("permissions.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("role_id", "permission_id", name="uq_role_perm"),
    )


class UserRole(Base):
    """Many-to-many: User â†” Role."""
    __tablename__ = "user_roles"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role_id = Column(String(36), ForeignKey("roles.id", ondelete="CASCADE"), nullable=False)
    assigned_at = Column(DateTime, default=utcnow, nullable=False)
    assigned_by = Column(String(36), nullable=True)

    user = relationship("User", back_populates="roles")
    role = relationship("Role")

    __table_args__ = (
        UniqueConstraint("user_id", "role_id", name="uq_user_role"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Migration 03: Subscription + Entitlements
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class Plan(Base):
    """Subscription plans â€” 5 defined in execution document."""
    __tablename__ = "plans"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(20), unique=True, nullable=False)
    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=False)
    description_ar = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    price_monthly_sar = Column(Float, default=0)
    price_yearly_sar = Column(Float, default=0)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)
    target_user_ar = Column(String(200), nullable=True)
    target_user_en = Column(String(200), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    features = relationship("PlanFeature", back_populates="plan", cascade="all, delete-orphan")


class PlanFeature(Base):
    """Feature flags per plan â€” entitlement definitions."""
    __tablename__ = "plan_features"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    plan_id = Column(String(36), ForeignKey("plans.id", ondelete="CASCADE"), nullable=False, index=True)
    feature_code = Column(String(80), nullable=False)
    feature_name_ar = Column(String(150), nullable=True)
    feature_name_en = Column(String(150), nullable=True)
    value_type = Column(String(20), default="boolean")  # boolean, integer, string
    value = Column(String(50), nullable=False)  # "true", "false", "20", "unlimited"
    created_at = Column(DateTime, default=utcnow, nullable=False)

    plan = relationship("Plan", back_populates="features")

    __table_args__ = (
        UniqueConstraint("plan_id", "feature_code", name="uq_plan_feature"),
    )


class UserSubscription(Base):
    """One active subscription per user."""
    __tablename__ = "user_subscriptions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    plan_id = Column(String(36), ForeignKey("plans.id"), nullable=False)
    status = Column(String(20), default=SubscriptionStatus.active.value, nullable=False)
    billing_cycle = Column(String(10), default="monthly")  # monthly, yearly
    started_at = Column(DateTime, default=utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)
    renewed_at = Column(DateTime, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)
    previous_plan_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    user = relationship("User", back_populates="subscription")
    plan = relationship("Plan")


class SubscriptionEntitlement(Base):
    """Resolved entitlements snapshot â€” updated on plan change."""
    __tablename__ = "subscription_entitlements"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    feature_code = Column(String(80), nullable=False)
    value_type = Column(String(20), default="boolean")
    value = Column(String(50), nullable=False)
    source_plan_id = Column(String(36), ForeignKey("plans.id"), nullable=True)
    granted_at = Column(DateTime, default=utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="entitlements")

    __table_args__ = (
        UniqueConstraint("user_id", "feature_code", name="uq_user_entitlement"),
        Index("ix_entitlement_user_feature", "user_id", "feature_code"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Migration 04: Legal Acceptance
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class PolicyDocument(Base):
    """Versioned legal documents â€” terms, privacy, etc."""
    __tablename__ = "policy_documents"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    policy_type = Column(String(50), nullable=False)
    version = Column(String(20), nullable=False)
    title_ar = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    content_ar = Column(Text, nullable=False)
    content_en = Column(Text, nullable=True)
    is_current = Column(Boolean, default=True)
    effective_from = Column(DateTime, default=utcnow, nullable=False)
    superseded_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("policy_type", "version", name="uq_policy_version"),
        Index("ix_policy_type_current", "policy_type", "is_current"),
    )


class PolicyAcceptanceLog(Base):
    """Proof of user accepting specific policy version."""
    __tablename__ = "policy_acceptance_logs"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    policy_document_id = Column(String(36), ForeignKey("policy_documents.id"), nullable=False)
    accepted_at = Column(DateTime, default=utcnow, nullable=False)
    accepted_ip = Column(String(45), nullable=True)
    accepted_user_agent = Column(String(500), nullable=True)

    user = relationship("User", back_populates="acceptance_logs")
    policy = relationship("PolicyDocument")

    __table_args__ = (
        Index("ix_acceptance_user_policy", "user_id", "policy_document_id"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Notifications (Migration 14 â€” but needed early)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class Notification(Base):
    """Platform notifications linked to user."""
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title_ar = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=True)
    body_ar = Column(Text, nullable=True)
    body_en = Column(Text, nullable=True)
    category = Column(String(50), default="general")  # general, auth, subscription, task, compliance, knowledge
    source_type = Column(String(50), nullable=True)  # registration, verification, plan_change, etc.
    source_id = Column(String(36), nullable=True)
    is_read = Column(Boolean, default=False)
    read_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("User", back_populates="notifications")

    __table_args__ = (
        Index("ix_notification_user_read", "user_id", "is_read"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Account Closure (Migration 15)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class AccountClosureRequest(Base):
    """Temporary or permanent account closure workflow."""
    __tablename__ = "account_closure_requests"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    closure_type = Column(String(20), nullable=False)  # temporary, permanent
    reason = Column(Text, nullable=True)
    status = Column(String(20), default=ClosureStatus.requested.value, nullable=False)
    requested_at = Column(DateTime, default=utcnow, nullable=False)
    processed_at = Column(DateTime, nullable=True)
    processed_by = Column(String(36), nullable=True)
    reactivation_date = Column(DateTime, nullable=True)  # For temporary closures
    retention_notice_sent = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("User", back_populates="closure_requests")


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Audit Events (general purpose)
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class AuditEvent(Base):
    """General audit trail for sensitive operations."""
    __tablename__ = "audit_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), nullable=True)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50), nullable=True)
    resource_id = Column(String(36), nullable=True)
    details = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_audit_user_action", "user_id", "action"),
        Index("ix_audit_resource", "resource_type", "resource_id"),
    )


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Database Initialization
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

def init_platform_db():
    """Create all tables."""
    Base.metadata.create_all(bind=engine)
    print(f"APEX Platform DB initialized: {len(Base.metadata.tables)} tables")
    return list(Base.metadata.tables.keys())


