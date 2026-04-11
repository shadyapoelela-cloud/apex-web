"""
APEX Sprint 1 — COA First Workflow Models
═══════════════════════════════════════════════════════════════
New tables for COA-first parsing workflow (per Sprint 1 Build Spec):
  - client_coa_uploads: upload metadata + column mapping + status
  - client_chart_of_accounts: parsed/normalized accounts
  - rejected_coa_rows: rows that failed parsing
  - knowledge_feedback_events: structured knowledge from eligible clients

These tables are SEPARATE from Phase 2 coa_uploads/coa_accounts which
handle the TB-first workflow. Sprint 1 builds the COA-first path.
"""

import enum
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    DateTime,
    Text,
    ForeignKey,
    JSON,
    Index,
    UniqueConstraint,
    BigInteger,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════


class CoaUploadStatus(str, enum.Enum):
    uploaded = "uploaded"
    column_mapping_pending = "column_mapping_pending"
    parsing = "parsing"
    parsed = "parsed"
    parsed_with_warnings = "parsed_with_warnings"
    failed = "failed"


class CoaRecordStatus(str, enum.Enum):
    parsed = "parsed"
    parsed_with_issue = "parsed_with_issue"
    rejected = "rejected"


class FeedbackSourceType(str, enum.Enum):
    developer_console = "developer_console"
    privileged_client = "privileged_client"
    internal_reviewer = "internal_reviewer"


class FeedbackCategory(str, enum.Enum):
    column_mapping_issue = "column_mapping_issue"
    parsing_issue = "parsing_issue"
    data_quality_note = "data_quality_note"
    taxonomy_note = "taxonomy_note"
    regulatory_note = "regulatory_note"
    accounting_note = "accounting_note"
    legal_note = "legal_note"
    suggested_classification = "suggested_classification"
    result_explanation = "result_explanation"


class KnowledgeFeedbackStatus(str, enum.Enum):
    submitted = "submitted"
    reviewed = "reviewed"
    accepted = "accepted"
    rejected = "rejected"
    queued_for_rule_design = "queued_for_rule_design"


# ═══════════════════════════════════════════════════════════════
# Table: client_coa_uploads
# ═══════════════════════════════════════════════════════════════


class ClientCoaUpload(Base):
    """COA upload record — tracks file upload + column detection + parse status."""

    __tablename__ = "client_coa_uploads"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    file_name = Column(String(255), nullable=False)
    stored_file_path = Column(Text, nullable=False)
    file_extension = Column(String(10), nullable=False)
    file_size_bytes = Column(BigInteger, nullable=False)
    source_type = Column(String(50), nullable=False, default="user_upload")
    upload_status = Column(String(50), nullable=False, default=CoaUploadStatus.uploaded.value)

    # Column detection
    header_row_index = Column(Integer, nullable=True)
    sheet_name = Column(String(255), nullable=True)
    column_mapping_json = Column(JSON, nullable=True)
    detected_columns_json = Column(JSON, nullable=True)

    # Parse summary
    total_rows_detected = Column(Integer, nullable=True)
    total_rows_parsed = Column(Integer, nullable=True)
    total_rows_rejected = Column(Integer, nullable=True)
    warnings_json = Column(JSON, nullable=True)

    uploaded_by = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_coa_upload_client", "client_id"),
        Index("ix_coa_upload_status", "upload_status"),
        Index("ix_coa_upload_client_date", "client_id", "created_at"),
    )


# ═══════════════════════════════════════════════════════════════
# Table: client_chart_of_accounts
# ═══════════════════════════════════════════════════════════════


class ClientChartOfAccount(Base):
    """Parsed COA account — one row per account from the uploaded file."""

    __tablename__ = "client_chart_of_accounts"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    coa_upload_id = Column(
        String(36), ForeignKey("client_coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True
    )
    source_row_number = Column(Integer, nullable=False)

    # Account fields
    account_code = Column(String(100), nullable=True)
    account_name_raw = Column(String(500), nullable=False)
    account_name_normalized = Column(String(500), nullable=False)
    parent_code = Column(String(100), nullable=True)
    parent_name = Column(String(500), nullable=True)
    account_level = Column(Integer, nullable=True)
    account_type_raw = Column(String(100), nullable=True)
    normal_balance = Column(String(20), nullable=True)  # debit / credit / null
    active_flag = Column(Boolean, nullable=False, default=True)
    notes = Column(Text, nullable=True)

    # Status & issues
    record_status = Column(String(50), nullable=False, default=CoaRecordStatus.parsed.value)
    issues_json = Column(JSON, nullable=False, default=list)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("coa_upload_id", "source_row_number", name="uq_coa_upload_row"),
        Index("ix_coa_account_client", "client_id"),
        Index("ix_coa_account_upload", "coa_upload_id"),
        Index("ix_coa_account_code", "account_code"),
        Index("ix_coa_account_name", "account_name_normalized"),
        Index("ix_coa_account_composite", "client_id", "coa_upload_id", "source_row_number"),
    )


# ═══════════════════════════════════════════════════════════════
# Table: rejected_coa_rows (optional but recommended)
# ═══════════════════════════════════════════════════════════════


class RejectedCoaRow(Base):
    """Rows that failed parsing — kept for debugging and user feedback."""

    __tablename__ = "rejected_coa_rows"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    coa_upload_id = Column(
        String(36), ForeignKey("client_coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True
    )
    source_row_number = Column(Integer, nullable=False)
    raw_row_json = Column(JSON, nullable=False)
    rejection_reasons_json = Column(JSON, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)


# ═══════════════════════════════════════════════════════════════
# Table: coa_knowledge_feedback
# ═══════════════════════════════════════════════════════════════


class CoaKnowledgeFeedback(Base):
    """Structured knowledge feedback from eligible clients (per Sprint 1 Spec §28)."""

    __tablename__ = "coa_knowledge_feedback"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    coa_upload_id = Column(String(36), ForeignKey("client_coa_uploads.id"), nullable=True)
    coa_account_id = Column(String(36), ForeignKey("client_chart_of_accounts.id"), nullable=True)

    feedback_source_type = Column(String(50), nullable=False)
    submitted_by = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    feedback_category = Column(String(50), nullable=False)
    feedback_severity = Column(String(30), nullable=True)
    feedback_text = Column(Text, nullable=False)
    suggested_correction_json = Column(JSON, nullable=True)
    reference_context_json = Column(JSON, nullable=True)

    status = Column(String(50), nullable=False, default=KnowledgeFeedbackStatus.submitted.value)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_kf_client", "client_id"),
        Index("ix_kf_upload", "coa_upload_id"),
        Index("ix_kf_status", "status"),
    )


def init_sprint1_db():
    """Create Sprint 1 tables."""
    from app.phase1.models.platform_models import engine

    # Import to register models
    ClientCoaUpload.__table__.create(bind=engine, checkfirst=True)
    ClientChartOfAccount.__table__.create(bind=engine, checkfirst=True)
    RejectedCoaRow.__table__.create(bind=engine, checkfirst=True)
    CoaKnowledgeFeedback.__table__.create(bind=engine, checkfirst=True)
    return "Sprint 1 tables created"
