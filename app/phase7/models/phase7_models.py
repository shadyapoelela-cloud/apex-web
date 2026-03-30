"""
APEX Phase 7 — Task Document Requirements & Provider Suspension
Per Execution Master §8 + Zero-Ambiguity §4 migrations 12-13
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, Text, DateTime, ForeignKey, Enum as SAEnum
from app.phase1.models.platform_models import Base, gen_uuid, utcnow
import enum

# ═══════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════
class TaskTypeCode(str, enum.Enum):
    bookkeeping = "bookkeeping"
    financial_statement_preparation = "financial_statement_preparation"
    review_vat = "review_vat"
    review_policy_hr = "review_policy_hr"
    tax_filing = "tax_filing"
    audit_support = "audit_support"
    payroll_processing = "payroll_processing"
    zakat_calculation = "zakat_calculation"
    financial_analysis = "financial_analysis"
    compliance_review = "compliance_review"

class DocRequirementType(str, enum.Enum):
    input_required = "input_required"
    output_required = "output_required"

class SubmissionStatus(str, enum.Enum):
    pending = "pending"
    uploaded = "uploaded"
    reviewed = "reviewed"
    rejected = "rejected"
    overdue = "overdue"

class ComplianceAction(str, enum.Enum):
    missing_inputs = "missing_inputs"
    missing_outputs = "missing_outputs"
    incomplete_submission = "incomplete_submission"
    quality_rejection = "quality_rejection"
    deadline_noncompliance = "deadline_noncompliance"

class SuspensionType(str, enum.Enum):
    soft = "suspension_soft"
    hard = "suspension_hard"

class SuspensionStatus(str, enum.Enum):
    active = "active"
    lifted = "lifted"

# ═══════════════════════════════════════════════════════
# Tables — Migration #12: task_document_requirements
# ═══════════════════════════════════════════════════════
class TaskType(Base):
    __tablename__ = "task_types"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=False)
    description_ar = Column(Text)
    description_en = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)

class TaskDocumentRequirement(Base):
    __tablename__ = "task_document_requirements"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    task_type_id = Column(String(36), ForeignKey("task_types.id"), nullable=False)
    requirement_type = Column(SAEnum(DocRequirementType), nullable=False)
    document_name_ar = Column(String(200), nullable=False)
    document_name_en = Column(String(200), nullable=False)
    description_ar = Column(Text)
    is_mandatory = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)
    created_at = Column(DateTime, default=utcnow)

class TaskSubmission(Base):
    __tablename__ = "task_submissions"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_task_id = Column(String(36), nullable=False, index=True)
    requirement_id = Column(String(36), ForeignKey("task_document_requirements.id"), nullable=False)
    provider_id = Column(String(36), nullable=False, index=True)
    file_name = Column(String(500))
    file_url = Column(Text)
    status = Column(SAEnum(SubmissionStatus), default=SubmissionStatus.pending)
    reviewer_notes = Column(Text)
    uploaded_at = Column(DateTime)
    reviewed_at = Column(DateTime)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)

# ═══════════════════════════════════════════════════════
# Tables — Migration #13: provider_suspension_rules
# ═══════════════════════════════════════════════════════
class ProviderComplianceFlag(Base):
    __tablename__ = "provider_compliance_flags"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    provider_id = Column(String(36), nullable=False, index=True)
    service_task_id = Column(String(36))
    action = Column(SAEnum(ComplianceAction), nullable=False)
    description = Column(Text)
    is_resolved = Column(Boolean, default=False)
    resolved_at = Column(DateTime)
    resolved_by = Column(String(36))
    created_at = Column(DateTime, default=utcnow)

class ProviderSuspension(Base):
    __tablename__ = "provider_suspensions"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    provider_id = Column(String(36), nullable=False, index=True)
    suspension_type = Column(SAEnum(SuspensionType), nullable=False)
    reason = Column(Text, nullable=False)
    compliance_flag_id = Column(String(36), ForeignKey("provider_compliance_flags.id"))
    status = Column(SAEnum(SuspensionStatus), default=SuspensionStatus.active)
    suspended_at = Column(DateTime, default=utcnow)
    lifted_at = Column(DateTime)
    lifted_by = Column(String(36))
    created_at = Column(DateTime, default=utcnow)

# ═══════════════════════════════════════════════════════
# Tables — Audit Events (Migration #15 partial)
# ═══════════════════════════════════════════════════════
class AuditEvent(Base):
    __tablename__ = "audit_events"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), index=True)
    action = Column(String(100), nullable=False, index=True)
    entity_type = Column(String(50))
    entity_id = Column(String(36))
    details = Column(Text)
    ip_address = Column(String(45))
    created_at = Column(DateTime, default=utcnow)

# ═══════════════════════════════════════════════════════
# Tables — Result Explanations (Migration #7)
# ═══════════════════════════════════════════════════════
class ResultExplanation(Base):
    __tablename__ = "result_explanations"
    __table_args__ = {"extend_existing": True}
    id = Column(String(36), primary_key=True, default=gen_uuid)
    analysis_id = Column(String(36), nullable=False, index=True)
    result_key = Column(String(100), nullable=False)
    summary_ar = Column(Text)
    summary_en = Column(Text)
    source_rows = Column(Text)
    applied_rules = Column(Text)
    confidence = Column(Float, default=0.0)
    warnings = Column(Text)
    feedback_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=utcnow)

def init_phase7_db():
    """Create all Phase 7 tables"""
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    return [t.__tablename__ for t in [TaskType, TaskDocumentRequirement, TaskSubmission,
            ProviderComplianceFlag, ProviderSuspension, AuditEvent, ResultExplanation]]
