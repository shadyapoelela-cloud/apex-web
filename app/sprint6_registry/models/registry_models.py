"""
APEX Sprint 6 — Official Source Registry + Eligibility Engines
Models for: reference authorities, regulatory updates, approved cache,
            funding programs, support programs, licensing registry,
            eligibility assessments.
"""

from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    Float,
    Numeric,
    DateTime,
    Text,
    ForeignKey,
    JSON,
    Index,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# ══════════════════════════════════════════════════════════════
# OFFICIAL SOURCE REGISTRY
# ══════════════════════════════════════════════════════════════


class ReferenceAuthority(Base):
    """Official bodies whose publications are authoritative."""

    __tablename__ = "reference_authorities"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    name_ar = Column(String(300), nullable=False)
    name_en = Column(String(300), nullable=True)
    authority_type = Column(String(50), nullable=False, default="regulatory")
    # regulatory, standard_setter, government, professional_body
    jurisdiction = Column(String(50), default="SA")
    domain_pack = Column(String(50), default="accounting")
    website_url = Column(Text, nullable=True)
    monitoring_urls_json = Column(JSON, default=list)
    authority_level = Column(String(30), default="regulatory")
    # law > regulation > standard > policy > platform > ai
    review_cycle_days = Column(Integer, default=90)
    is_active = Column(Boolean, default=True)
    last_checked_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_ref_auth_type", "authority_type"),
        Index("ix_ref_auth_domain", "domain_pack"),
    )


class ReferenceDocument(Base):
    """Approved reference documents from authorities."""

    __tablename__ = "reference_documents"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    authority_id = Column(String(36), ForeignKey("reference_authorities.id"), nullable=False, index=True)
    title_ar = Column(String(500), nullable=False)
    title_en = Column(String(500), nullable=True)
    document_type = Column(String(50), default="guide")
    # guide, regulation, standard, circular, form, checklist
    version = Column(String(50), nullable=True)
    effective_from = Column(DateTime, nullable=True)
    effective_to = Column(DateTime, nullable=True)
    validity_status = Column(String(30), default="active")
    # active, superseded, expired, draft
    superseded_by = Column(String(36), nullable=True)
    source_url = Column(Text, nullable=True)
    content_hash = Column(String(64), nullable=True)
    last_verified_at = Column(DateTime, nullable=True)
    review_status = Column(String(30), default="approved")
    # pending_review, approved, rejected, needs_update
    reviewer_notes = Column(Text, nullable=True)
    metadata_json = Column(JSON, default=dict)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_ref_doc_auth", "authority_id"),
        Index("ix_ref_doc_status", "validity_status"),
    )


class RegulatoryUpdateEvent(Base):
    """Detected changes in official sources."""

    __tablename__ = "regulatory_update_events"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    authority_id = Column(String(36), ForeignKey("reference_authorities.id"), nullable=False, index=True)
    reference_document_id = Column(String(36), ForeignKey("reference_documents.id"), nullable=True, index=True)
    change_type = Column(String(30), nullable=False, default="minor")
    # minor, major, critical, new_document, superseded
    change_summary_ar = Column(Text, nullable=True)
    change_summary_en = Column(Text, nullable=True)
    detected_at = Column(DateTime, default=utcnow)
    review_status = Column(String(30), default="pending_review")
    # pending_review, reviewed, applied, dismissed
    reviewed_by = Column(String(36), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    impact_assessment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    __table_args__ = (
        Index("ix_reg_update_auth", "authority_id"),
        Index("ix_reg_update_status", "review_status"),
    )


# ══════════════════════════════════════════════════════════════
# ELIGIBILITY & READINESS ENGINES
# ══════════════════════════════════════════════════════════════


class FundingProgram(Base):
    """Funding programs from banks and financial institutions."""

    __tablename__ = "funding_programs"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    name_ar = Column(String(300), nullable=False)
    name_en = Column(String(300), nullable=True)
    provider_name_ar = Column(String(300), nullable=False)
    provider_name_en = Column(String(300), nullable=True)
    program_type = Column(String(50), default="loan")
    # loan, credit_line, guarantee, grant, equity
    target_sectors_json = Column(JSON, default=list)
    target_entity_types_json = Column(JSON, default=list)
    min_revenue = Column(Numeric(18, 2), nullable=True)
    max_revenue = Column(Numeric(18, 2), nullable=True)
    min_employees = Column(Integer, nullable=True)
    max_employees = Column(Integer, nullable=True)
    min_business_age_months = Column(Integer, nullable=True)
    required_documents_json = Column(JSON, default=list)
    financial_requirements_json = Column(JSON, default=dict)
    # e.g. {"min_current_ratio": 1.0, "max_debt_ratio": 0.7}
    eligibility_rules_json = Column(JSON, default=list)
    jurisdiction = Column(String(50), default="SA")
    reference_authority_id = Column(String(36), ForeignKey("reference_authorities.id"), nullable=True, index=True)
    effective_from = Column(DateTime, nullable=True)
    effective_to = Column(DateTime, nullable=True)
    validity_status = Column(String(30), default="active")
    source_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_funding_type", "program_type"),
        Index("ix_funding_active", "is_active"),
    )


class SupportProgram(Base):
    """Government support programs, incentives, subsidies."""

    __tablename__ = "support_programs"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    name_ar = Column(String(300), nullable=False)
    name_en = Column(String(300), nullable=True)
    provider_name_ar = Column(String(300), nullable=False)
    provider_type = Column(String(50), default="government")
    # government, semi_government, ngo, international
    support_type = Column(String(50), default="subsidy")
    # subsidy, training, mentoring, workspace, tax_exemption, employment_support
    target_sectors_json = Column(JSON, default=list)
    target_entity_types_json = Column(JSON, default=list)
    eligibility_rules_json = Column(JSON, default=list)
    required_documents_json = Column(JSON, default=list)
    benefits_json = Column(JSON, default=list)
    jurisdiction = Column(String(50), default="SA")
    reference_authority_id = Column(String(36), ForeignKey("reference_authorities.id"), nullable=True, index=True)
    effective_from = Column(DateTime, nullable=True)
    effective_to = Column(DateTime, nullable=True)
    validity_status = Column(String(30), default="active")
    source_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_support_type", "support_type"),
        Index("ix_support_active", "is_active"),
    )


class LicenseRegistry(Base):
    """License types: commercial, professional, medical, industrial."""

    __tablename__ = "license_registry"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    name_ar = Column(String(300), nullable=False)
    name_en = Column(String(300), nullable=True)
    license_type = Column(String(50), nullable=False)
    # commercial, professional, medical, industrial, regulatory, sector_specific
    issuing_authority_ar = Column(String(300), nullable=False)
    issuing_authority_id = Column(String(36), ForeignKey("reference_authorities.id"), nullable=True, index=True)
    target_activities_json = Column(JSON, default=list)
    required_documents_json = Column(JSON, default=list)
    requirements_json = Column(JSON, default=dict)
    # e.g. {"min_capital": 50000, "requires_audit": true}
    fees_json = Column(JSON, default=dict)
    renewal_cycle_months = Column(Integer, nullable=True)
    jurisdiction = Column(String(50), default="SA")
    effective_from = Column(DateTime, nullable=True)
    effective_to = Column(DateTime, nullable=True)
    validity_status = Column(String(30), default="active")
    source_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_license_type", "license_type"),
        Index("ix_license_active", "is_active"),
    )


class EligibilityAssessment(Base):
    """Result of running eligibility check for a client against a program/license."""

    __tablename__ = "eligibility_assessments"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False)
    assessment_type = Column(String(30), nullable=False)
    # funding, support, licensing, investment_pathway
    target_program_id = Column(String(36), nullable=True)
    # FK to funding_programs / support_programs / license_registry
    target_program_type = Column(String(30), nullable=True)
    # funding_program, support_program, license
    target_program_name = Column(String(300), nullable=True)
    # Assessment results
    eligibility_status = Column(String(30), nullable=False, default="pending")
    # eligible, conditionally_eligible, likely_eligible, not_eligible, pending, review_required
    readiness_score = Column(Float, default=0.0)
    confidence = Column(Float, default=0.0)
    risk_severity = Column(String(20), default="low")
    boundary_status = Column(String(30), default="advisory")
    # authoritative, advisory, suggestive, uncertain, review_required
    # Gap analysis
    met_requirements_json = Column(JSON, default=list)
    gaps_json = Column(JSON, default=list)
    missing_documents_json = Column(JSON, default=list)
    next_actions_json = Column(JSON, default=list)
    # Evidence
    financial_data_json = Column(JSON, default=dict)
    references_json = Column(JSON, default=list)
    explanation_ar = Column(Text, nullable=True)
    explanation_en = Column(Text, nullable=True)
    requires_human_review = Column(Boolean, default=False)
    human_review_reason = Column(Text, nullable=True)
    # Related analysis
    analysis_run_id = Column(String(36), nullable=True)
    # Audit
    assessed_by = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    __table_args__ = (
        Index("ix_elig_client", "client_id"),
        Index("ix_elig_type", "assessment_type"),
        Index("ix_elig_status", "eligibility_status"),
    )


def init_sprint6_db():
    from app.phase1.models.platform_models import engine

    ReferenceAuthority.__table__.create(bind=engine, checkfirst=True)
    ReferenceDocument.__table__.create(bind=engine, checkfirst=True)
    RegulatoryUpdateEvent.__table__.create(bind=engine, checkfirst=True)
    FundingProgram.__table__.create(bind=engine, checkfirst=True)
    SupportProgram.__table__.create(bind=engine, checkfirst=True)
    LicenseRegistry.__table__.create(bind=engine, checkfirst=True)
    EligibilityAssessment.__table__.create(bind=engine, checkfirst=True)
    return "Sprint 6 tables created (7 tables)"
