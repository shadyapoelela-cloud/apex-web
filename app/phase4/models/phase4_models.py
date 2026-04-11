"""
APEX Platform — Phase 4 Models
═══════════════════════════════════════════════════════════════
Service Providers + Documents + Scopes + Verification

Migration 10 per execution document:
  service_providers, provider_documents, service_scopes

Rules:
- No provider activated before verification documents uploaded and reviewed
- Each provider has category + approved service scopes
- Verification produces: verification_status + approved_service_scopes + reviewer_notes + verification_score
"""

import enum
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    Float,
    DateTime,
    Text,
    ForeignKey,
    Index,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class ProviderCategory(str, enum.Enum):
    accountant = "accountant"
    senior_accountant = "senior_accountant"
    accounting_manager = "accounting_manager"
    finance_manager = "finance_manager"
    financial_controller = "financial_controller"
    cfo_consultant = "cfo_consultant"
    tax_consultant = "tax_consultant"
    zakat_vat_consultant = "zakat_vat_consultant"
    audit_consultant = "audit_consultant"
    bookkeeping_specialist = "bookkeeping_specialist"
    payroll_specialist = "payroll_specialist"
    hr_consultant = "hr_consultant"
    marketing_consultant = "marketing_consultant"
    legal_consultant = "legal_consultant"
    regulatory_consultant = "regulatory_consultant"
    compliance_consultant = "compliance_consultant"
    investment_consultant = "investment_consultant"


class VerificationStatus(str, enum.Enum):
    pending = "pending"
    documents_submitted = "documents_submitted"
    under_review = "under_review"
    approved = "approved"
    rejected = "rejected"
    suspended = "suspended"


class DocumentType(str, enum.Enum):
    national_id = "national_id"
    professional_license = "professional_license"
    socpa_membership = "socpa_membership"
    university_degree = "university_degree"
    experience_certificate = "experience_certificate"
    cv_resume = "cv_resume"
    portfolio = "portfolio"
    other = "other"


class DocumentStatus(str, enum.Enum):
    uploaded = "uploaded"
    under_review = "under_review"
    approved = "approved"
    rejected = "rejected"


class ServiceProvider(Base):
    """Provider entity — professional offering services on the platform."""

    __tablename__ = "service_providers"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    category = Column(String(50), nullable=False)
    specialization = Column(String(200), nullable=True)
    bio_ar = Column(Text, nullable=True)
    bio_en = Column(Text, nullable=True)
    years_experience = Column(Integer, nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(50), default="SA")

    # Verification
    verification_status = Column(String(30), default=VerificationStatus.pending.value, nullable=False)
    verification_score = Column(Integer, nullable=True)  # 0-100
    verified_at = Column(DateTime, nullable=True)
    verified_by = Column(String(36), nullable=True)
    reviewer_notes = Column(Text, nullable=True)

    # Commercial
    commission_rate = Column(Float, default=20.0)  # Platform takes 20%, provider gets 80%
    is_premium = Column(Boolean, default=False)
    listing_priority = Column(Integer, default=0)  # Higher = shown first
    badge = Column(String(50), nullable=True)  # gold, silver, verified

    # Compliance
    compliance_status = Column(String(30), default="clear")  # clear, pending_compliance, suspended
    active_tasks_count = Column(Integer, default=0)
    completed_tasks_count = Column(Integer, default=0)
    rating_average = Column(Float, nullable=True)
    rating_count = Column(Integer, default=0)

    # Policy acceptance
    provider_policy_accepted = Column(Boolean, default=False)
    policy_accepted_at = Column(DateTime, nullable=True)

    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    documents = relationship("ProviderDocument", back_populates="provider", cascade="all, delete-orphan")
    scopes = relationship("ServiceProviderScope", back_populates="provider", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_provider_category_status", "category", "verification_status"),
        Index("ix_provider_compliance", "compliance_status"),
    )


class ProviderDocument(Base):
    """Verification documents uploaded by provider."""

    __tablename__ = "service_provider_documents"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    provider_id = Column(String(36), ForeignKey("service_providers.id", ondelete="CASCADE"), nullable=False, index=True)
    document_type = Column(String(50), nullable=False)
    filename = Column(String(300), nullable=False)
    file_size_bytes = Column(Integer, nullable=True)
    storage_path = Column(String(500), nullable=True)
    status = Column(String(20), default=DocumentStatus.uploaded.value, nullable=False)
    reviewer_notes = Column(Text, nullable=True)
    reviewed_by = Column(String(36), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    provider = relationship("ServiceProvider", back_populates="documents")


class ServiceProviderScope(Base):
    """Approved service scopes for a provider."""

    __tablename__ = "service_provider_scopes"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    provider_id = Column(String(36), ForeignKey("service_providers.id", ondelete="CASCADE"), nullable=False, index=True)
    scope_code = Column(String(80), nullable=False)
    scope_name_ar = Column(String(200), nullable=False)
    scope_name_en = Column(String(200), nullable=True)
    is_approved = Column(Boolean, default=False)
    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    provider = relationship("ServiceProvider", back_populates="scopes")

    __table_args__ = (UniqueConstraint("provider_id", "scope_code", name="uq_provider_scope"),)


def init_phase4_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["service_providers", "service_provider_documents", "service_provider_scopes"]
