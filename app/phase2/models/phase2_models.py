"""
APEX Platform — Phase 2 Models
═══════════════════════════════════════════════════════════════
Clients + COA + Analysis Results + Result Explanations

Migrations 05-07 per execution document:
  05: clients, client_types, client_profiles, client_memberships
  06: uploads, coa_accounts, parse_runs, parse_issues
  07: analysis_results, result_explanations, result_warnings
"""

import enum
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
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════


class ClientType(str, enum.Enum):
    standard_business = "standard_business"
    financial_entity = "financial_entity"
    financing_entity = "financing_entity"
    accounting_firm = "accounting_firm"
    audit_firm = "audit_firm"
    investment_entity = "investment_entity"
    sector_consulting_entity = "sector_consulting_entity"
    government_entity = "government_entity"
    legal_regulatory_entity = "legal_regulatory_entity"


# Client types that auto-enable Knowledge Mode (per doc section 5)
KNOWLEDGE_MODE_ELIGIBLE_TYPES = {
    ClientType.accounting_firm.value,
    ClientType.audit_firm.value,
    ClientType.government_entity.value,
    ClientType.legal_regulatory_entity.value,
    ClientType.investment_entity.value,
    ClientType.financial_entity.value,
}


class UploadStatus(str, enum.Enum):
    pending = "pending"
    parsing = "parsing"
    parsed = "parsed"
    analysis_running = "analysis_running"
    completed = "completed"
    failed = "failed"


class AnalysisStatus(str, enum.Enum):
    running = "running"
    completed = "completed"
    failed = "failed"


class ExplanationSeverity(str, enum.Enum):
    info = "info"
    success = "success"
    warning = "warning"
    error = "error"
    critical = "critical"


# ═══════════════════════════════════════════════════════════════
# Migration 05: Clients
# ═══════════════════════════════════════════════════════════════


class ClientTypeRef(Base):
    """Reference table for client types with metadata."""

    __tablename__ = "client_types"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(50), unique=True, nullable=False)
    name_ar = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=False)
    description_ar = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    knowledge_mode_eligible = Column(Boolean, default=False)
    knowledge_mode_features_ar = Column(Text, nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class Client(Base):
    """Client entity — company/organization using analysis services."""

    __tablename__ = "clients"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    client_type_code = Column(String(50), nullable=False, index=True)
    cr_number = Column(String(30), nullable=True)  # Commercial Registration
    tax_number = Column(String(30), nullable=True)  # General tax number (legacy)
    vat_registration_number = Column(String(15), nullable=True, index=True)  # ZATCA 15-digit VAT
    tax_jurisdiction = Column(String(2), default="SA", nullable=False)  # SA, AE, KW, BH, QA, OM, EG
    currency = Column(String(3), default="SAR", nullable=False)  # ISO 4217
    sector = Column(String(50), nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(50), default="SA")
    website = Column(String(300), nullable=True)
    knowledge_mode = Column(Boolean, default=False)
    fiscal_year_end = Column(String(10), default="12-31")  # MM-DD
    inventory_system = Column(String(20), default="unknown")  # periodic, perpetual, unknown
    created_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    # ── New fields (Architecture Doc v5 Section 29) ──
    legal_entity_type = Column(String(50), nullable=True, index=True)  # links to legal_entity_types.code
    sector_main_code = Column(String(50), nullable=True, index=True)  # links to sector_main.code
    sector_sub_code = Column(String(50), nullable=True, index=True)  # links to sector_sub.code
    commercial_name = Column(String(200), nullable=True)  # trade name
    legal_name = Column(String(200), nullable=True)  # official legal name
    national_address = Column(Text, nullable=True)  # full address
    registration_status = Column(String(30), default="draft")  # draft, pending_review, active, suspended
    onboarding_step = Column(Integer, default=0)  # wizard progress 0-7
    onboarding_completed = Column(Boolean, default=False)
    # ── Phase 1: Readiness + COA Stage (Integration Pack) ──
    readiness_status = Column(
        String(30), default="not_ready"
    )  # not_ready, documents_pending, ready_for_coa, coa_in_progress, ready_for_tb
    coa_stage = Column(String(20), default="none")  # none, upload, parse, classify, quality, review, approve, ready
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    memberships = relationship("ClientMembership", back_populates="client", cascade="all, delete-orphan")
    uploads = relationship("COAUpload", back_populates="client", cascade="all, delete-orphan")

    __table_args__ = (Index("ix_client_type_sector", "client_type_code", "sector"),)


class ClientMembership(Base):
    """Links users to client entities with specific roles."""

    __tablename__ = "client_memberships"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role_in_client = Column(String(30), default="member")  # owner, admin, member, viewer
    is_active = Column(Boolean, default=True)
    joined_at = Column(DateTime, default=utcnow, nullable=False)

    client = relationship("Client", back_populates="memberships")

    __table_args__ = (UniqueConstraint("client_id", "user_id", name="uq_client_user"),)


# ═══════════════════════════════════════════════════════════════
# Migration 06: COA Uploads
# ═══════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════
# Phase 1: Client Documents (Integration Pack)
# ═══════════════════════════════════════════════════════════════


class ClientDocument(Base):
    """Client document with lifecycle: missing -> uploaded -> under_review -> accepted/rejected -> expired/replaced"""

    __tablename__ = "client_documents"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    document_type = Column(String(50), nullable=False)  # cr, tax, address, aoa, licenses, etc.
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    required = Column(Boolean, default=False)
    status = Column(
        String(20), default="missing"
    )  # missing, uploaded, under_review, accepted, rejected, expired, replaced
    file_path = Column(String(500), nullable=True)
    uploaded_at = Column(DateTime, nullable=True)
    accepted_at = Column(DateTime, nullable=True)
    rejected_at = Column(DateTime, nullable=True)
    reject_reason = Column(Text, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    replaced_at = Column(DateTime, nullable=True)
    replaced_by_id = Column(String(36), nullable=True)  # links to new version
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (Index("ix_client_doc_type", "client_id", "document_type"),)


class COAUpload(Base):
    """Upload record — tracks each file upload and its processing."""

    __tablename__ = "coa_uploads"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    uploaded_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    filename = Column(String(300), nullable=False)
    file_size_bytes = Column(Integer, nullable=True)
    file_format = Column(String(20), nullable=True)  # apex_v1, apex_v2, unknown
    status = Column(String(20), default=UploadStatus.pending.value, nullable=False)
    industry = Column(String(30), default="general")
    closing_inventory = Column(Numeric(18, 2), nullable=True)
    inventory_system_override = Column(String(20), nullable=True)

    # Parse results summary
    total_accounts = Column(Integer, nullable=True)
    mapped_accounts = Column(Integer, nullable=True)
    unmapped_accounts = Column(Integer, nullable=True)
    classification_confidence = Column(Float, nullable=True)

    # Tab review summary
    tab_consistency_score = Column(Float, nullable=True)
    tab_mismatches = Column(Integer, nullable=True)

    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    client = relationship("Client", back_populates="uploads")
    results = relationship("AnalysisResult", back_populates="upload", cascade="all, delete-orphan")


class COAAccount(Base):
    """Individual account from a parsed upload."""

    __tablename__ = "coa_accounts"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    upload_id = Column(String(36), ForeignKey("coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True)
    account_code = Column(String(30), nullable=True)
    account_name = Column(String(300), nullable=False)
    tab_raw = Column(String(200), nullable=True)
    normalized_class = Column(String(50), nullable=True)
    section = Column(String(30), nullable=True)  # income_statement, balance_sheet
    confidence = Column(Float, nullable=True)
    classification_source = Column(String(20), nullable=True)  # exact_tab, alias, regex, name_override
    net_balance = Column(Numeric(18, 2), default=0, nullable=False)
    open_debit = Column(Numeric(18, 2), nullable=True)
    open_credit = Column(Numeric(18, 2), nullable=True)
    movement_debit = Column(Numeric(18, 2), nullable=True)
    movement_credit = Column(Numeric(18, 2), nullable=True)
    close_debit = Column(Numeric(18, 2), nullable=True)
    close_credit = Column(Numeric(18, 2), nullable=True)
    warnings = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (Index("ix_coa_upload_class", "upload_id", "normalized_class"),)


# ═══════════════════════════════════════════════════════════════
# Migration 07: Analysis Results + Explanations
# ═══════════════════════════════════════════════════════════════


class AnalysisResult(Base):
    """Complete analysis result for an upload."""

    __tablename__ = "analysis_results"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    upload_id = Column(String(36), ForeignKey("coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True)
    client_id = Column(String(36), ForeignKey("clients.id"), nullable=False, index=True)
    analyzed_by = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    status = Column(String(20), default=AnalysisStatus.running.value, nullable=False)

    # Confidence
    overall_confidence = Column(Float, nullable=True)
    confidence_label = Column(String(20), nullable=True)

    # Income Statement (currency-exact)
    revenue = Column(Numeric(18, 2), nullable=True)
    net_revenue = Column(Numeric(18, 2), nullable=True)
    cogs = Column(Numeric(18, 2), nullable=True)
    cogs_method = Column(String(30), nullable=True)
    gross_profit = Column(Numeric(18, 2), nullable=True)
    operating_profit = Column(Numeric(18, 2), nullable=True)
    net_profit = Column(Numeric(18, 2), nullable=True)

    # Balance Sheet (currency-exact)
    total_assets = Column(Numeric(18, 2), nullable=True)
    total_liabilities = Column(Numeric(18, 2), nullable=True)
    total_equity = Column(Numeric(18, 2), nullable=True)
    is_balanced = Column(Boolean, nullable=True)
    balance_diff = Column(Numeric(18, 2), nullable=True)

    # Period locking + Audit trail (ZATCA / IFRS compliance)
    period_locked = Column(Boolean, default=False, nullable=False)
    locked_at = Column(DateTime, nullable=True)
    locked_by = Column(String(36), ForeignKey("users.id"), nullable=True)
    audit_trail_json = Column(JSON, nullable=True)  # immutable event log for this result

    # Key Ratios (stored as JSON for flexibility)
    ratios = Column(JSON, nullable=True)

    # Validation
    errors_count = Column(Integer, default=0)
    warnings_count = Column(Integer, default=0)
    can_approve = Column(Boolean, nullable=True)

    # Knowledge Brain
    brain_rules_evaluated = Column(Integer, nullable=True)
    brain_rules_triggered = Column(Integer, nullable=True)
    brain_findings = Column(JSON, nullable=True)

    # AI Narrative
    has_narrative = Column(Boolean, default=False)
    narrative_platform = Column(String(20), nullable=True)
    executive_summary = Column(Text, nullable=True)
    strengths = Column(JSON, nullable=True)
    weaknesses = Column(JSON, nullable=True)
    risks = Column(JSON, nullable=True)
    recommendations = Column(JSON, nullable=True)
    management_letter = Column(Text, nullable=True)

    # Full JSON result (for backward compatibility)
    full_result_json = Column(JSON, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)

    upload = relationship("COAUpload", back_populates="results")
    explanations = relationship("ResultExplanation", back_populates="result", cascade="all, delete-orphan")


class ResultExplanation(Base):
    """
    Explainability Layer — per document section 6.
    Each major result gets an explanation accessible via ! icon.
    """

    __tablename__ = "result_explanations"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    result_id = Column(String(36), ForeignKey("analysis_results.id", ondelete="CASCADE"), nullable=False, index=True)
    metric_key = Column(String(80), nullable=False)  # e.g. "net_revenue", "current_ratio", "cogs"
    metric_label_ar = Column(String(200), nullable=False)
    metric_label_en = Column(String(200), nullable=True)
    metric_value = Column(Numeric(18, 4), nullable=True)  # 4dp to cover ratios + amounts
    metric_formatted = Column(String(50), nullable=True)

    # How was this result built?
    explanation_ar = Column(Text, nullable=False)
    explanation_en = Column(Text, nullable=True)

    # Source data
    source_accounts = Column(JSON, nullable=True)  # [{name, class, balance}]
    source_rows_count = Column(Integer, nullable=True)

    # Rules & confidence
    applied_rules = Column(JSON, nullable=True)  # [{rule_code, rule_name}]
    confidence = Column(Float, nullable=True)
    severity = Column(String(20), default=ExplanationSeverity.info.value)

    # Warnings
    warnings = Column(JSON, nullable=True)  # [{code, message}]

    # Knowledge feedback count (updated later)
    feedback_count = Column(Integer, default=0)

    created_at = Column(DateTime, default=utcnow, nullable=False)

    result = relationship("AnalysisResult", back_populates="explanations")

    __table_args__ = (
        UniqueConstraint("result_id", "metric_key", name="uq_result_metric"),
        Index("ix_explanation_metric", "result_id", "metric_key"),
    )


class ResultWarning(Base):
    """Warnings/issues associated with analysis results."""

    __tablename__ = "result_warnings"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    result_id = Column(String(36), ForeignKey("analysis_results.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(50), nullable=False)
    severity = Column(String(20), nullable=False)  # error, warning, info
    message_ar = Column(Text, nullable=False)
    message_en = Column(Text, nullable=True)
    source_metric = Column(String(80), nullable=True)
    details = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
