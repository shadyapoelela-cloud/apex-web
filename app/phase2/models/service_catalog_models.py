"""
APEX Platform - Service Catalog + Audit Service Models
Per Architecture Doc v5 Sections 7, 8, 15
Service Catalog: organized services with stages and workflows
Audit Service: 7-stage accounting audit workflow
"""

from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    Float,
    DateTime,
    Text,
    ForeignKey,
    JSON,
    Index,
)
from sqlalchemy.orm import relationship
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# ═══════════════════════════════════════
# SERVICE CATALOG
# ═══════════════════════════════════════


class ServiceCatalog(Base):
    __tablename__ = "service_catalog"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_code = Column(String(50), unique=True, nullable=False, index=True)
    title_ar = Column(String(300), nullable=False)
    title_en = Column(String(300), nullable=True)
    description_ar = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    category = Column(String(50), nullable=False)  # financial, audit, compliance, readiness, advisory, operational
    icon = Column(String(50), nullable=True)
    requires_review = Column(Boolean, default=False)
    requires_coa = Column(Boolean, default=False)
    requires_tb = Column(Boolean, default=False)
    min_plan = Column(String(20), default="pro")  # free, pro, business, expert, enterprise
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    stages = relationship(
        "ServiceWorkflowStage",
        back_populates="service",
        cascade="all, delete-orphan",
        order_by="ServiceWorkflowStage.stage_order",
    )


class ServiceWorkflowStage(Base):
    __tablename__ = "service_workflow_stages"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_id = Column(String(36), ForeignKey("service_catalog.id", ondelete="CASCADE"), nullable=False, index=True)
    stage_code = Column(String(50), nullable=False)
    stage_order = Column(Integer, nullable=False)
    title_ar = Column(String(300), nullable=False)
    title_en = Column(String(300), nullable=True)
    description_ar = Column(Text, nullable=True)
    is_mandatory = Column(Boolean, default=True)
    input_requirements = Column(JSON, nullable=True)  # list of required inputs
    output_deliverables = Column(JSON, nullable=True)  # list of expected outputs
    completion_rules = Column(JSON, nullable=True)  # rules that must pass to complete
    help_text_ar = Column(Text, nullable=True)
    help_text_en = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    service = relationship("ServiceCatalog", back_populates="stages")

    __table_args__ = (Index("ix_stage_service_order", "service_id", "stage_order"),)


class ServiceCase(Base):
    __tablename__ = "service_cases"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    service_id = Column(String(36), ForeignKey("service_catalog.id"), nullable=False, index=True)
    service_code = Column(String(50), nullable=False)
    status = Column(String(30), default="initiated")  # initiated, in_progress, review, completed, cancelled
    current_stage = Column(String(50), nullable=True)
    progress_percent = Column(Float, default=0.0)
    assigned_provider_id = Column(String(36), nullable=True)
    assigned_reviewer_id = Column(String(36), nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    created_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (Index("ix_case_client_service", "client_id", "service_code"),)


# ═══════════════════════════════════════
# AUDIT SERVICE (7 stages)
# ═══════════════════════════════════════


class AuditProgramTemplate(Base):
    __tablename__ = "audit_program_templates"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    area = Column(String(100), nullable=False)  # e.g. cash, receivables, payables, revenue
    procedure_code = Column(String(50), nullable=False, unique=True)
    title_ar = Column(String(300), nullable=False)
    title_en = Column(String(300), nullable=True)
    description_ar = Column(Text, nullable=True)
    risk_level = Column(String(20), default="medium")  # low, medium, high, critical
    local_std_ref = Column(String(100), nullable=True)  # Saudi standard reference
    international_ref = Column(String(100), nullable=True)  # ISA reference
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class AuditSample(Base):
    __tablename__ = "audit_samples"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_case_id = Column(String(36), ForeignKey("service_cases.id", ondelete="CASCADE"), nullable=False, index=True)
    area = Column(String(100), nullable=False)
    sampling_method = Column(String(30), nullable=False)  # random, risk_based, systematic, judgmental
    population_ref = Column(String(200), nullable=True)  # description of population
    population_size = Column(Integer, nullable=True)
    selected_count = Column(Integer, nullable=False)
    selection_rationale = Column(Text, nullable=True)
    status = Column(String(30), default="selected")  # selected, in_progress, completed, reviewed
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


class AuditWorkpaper(Base):
    __tablename__ = "audit_workpapers"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_case_id = Column(String(36), ForeignKey("service_cases.id", ondelete="CASCADE"), nullable=False, index=True)
    procedure_code = Column(String(50), nullable=False)
    area = Column(String(100), nullable=False)
    title_ar = Column(String(300), nullable=True)
    description = Column(Text, nullable=True)
    evidence_ref = Column(Text, nullable=True)  # file path or archive item ID
    evidence_type = Column(String(50), nullable=True)  # document, calculation, observation, inquiry
    result = Column(String(30), nullable=True)  # satisfactory, exception, not_tested, na
    finding_description = Column(Text, nullable=True)
    severity = Column(String(20), nullable=True)  # low, medium, high, critical
    materiality_impact = Column(Float, nullable=True)
    reviewer_status = Column(String(30), default="pending")  # pending, approved, rejected, needs_revision
    reviewer_id = Column(String(36), nullable=True)
    reviewer_notes = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (Index("ix_wp_case_area", "service_case_id", "area"),)


class AuditFinding(Base):
    __tablename__ = "audit_findings"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_case_id = Column(String(36), ForeignKey("service_cases.id", ondelete="CASCADE"), nullable=False, index=True)
    finding_code = Column(String(50), nullable=False)
    area = Column(String(100), nullable=False)
    title_ar = Column(String(300), nullable=False)
    title_en = Column(String(300), nullable=True)
    description_ar = Column(Text, nullable=False)
    severity = Column(String(20), nullable=False)  # low, medium, high, critical
    materiality = Column(Float, nullable=True)
    owner_id = Column(String(36), nullable=True)  # person responsible
    status = Column(String(30), default="open")  # open, resolved, accepted, disputed
    proposed_adjustment = Column(JSON, nullable=True)  # debit/credit entries
    management_response = Column(Text, nullable=True)
    impact_on_report = Column(String(50), nullable=True)  # no_impact, modified_opinion, qualified, adverse
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (Index("ix_finding_case_severity", "service_case_id", "severity"),)
