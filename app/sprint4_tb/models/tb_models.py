"""
APEX Platform — Sprint 4 Models (TB Binding)
═══════════════════════════════════════════════════════════════
Trial Balance Upload + TB-COA Binding Results

New tables:
  - trial_balance_uploads: TB upload metadata + period + linked COA
  - tb_parsed_rows: individual parsed TB rows with amounts
  - tb_binding_results: matching results between TB accounts and approved COA

Per Apex_Coa_First_Workflow_Execution_Document §6.5, §6.6, §8.6, §8.7
"""

import enum
from sqlalchemy import (
    Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, JSON, Index, UniqueConstraint, BigInteger,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ─── Enums ───

class TbUploadStatus(str, enum.Enum):
    uploaded = "uploaded"
    parsing = "parsing"
    parsed = "parsed"
    parsed_with_warnings = "parsed_with_warnings"
    binding = "binding"
    bound = "bound"
    bound_with_issues = "bound_with_issues"
    approved = "approved"
    failed = "failed"


class TbMatchType(str, enum.Enum):
    exact_code = "exact_code"
    exact_name = "exact_name"
    normalized_name = "normalized_name"
    client_alias = "client_alias"
    client_rule = "client_rule"
    fuzzy_match = "fuzzy_match"
    manual = "manual"
    unmatched = "unmatched"
    new_account = "new_account"


# ═══════════════════════════════════════════════════════════
# Table: trial_balance_uploads
# ═══════════════════════════════════════════════════════════

class TrialBalanceUpload(Base):
    """TB upload record — tracks file, period, and linked approved COA."""
    __tablename__ = "trial_balance_uploads"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    coa_upload_id = Column(String(36), ForeignKey("client_coa_uploads.id"), nullable=True, index=True)

    # File info
    file_name = Column(String(255), nullable=False)
    stored_file_path = Column(Text, nullable=False)
    file_extension = Column(String(10), nullable=False)
    file_size_bytes = Column(BigInteger, nullable=False)
    file_format = Column(String(20), nullable=True)  # apex_v1, apex_v2, generic

    # Period
    period_label = Column(String(100), nullable=True)  # e.g. "2025-12", "Q4 2025"
    fiscal_year = Column(String(10), nullable=True)

    # Status
    upload_status = Column(String(50), nullable=False, default=TbUploadStatus.uploaded.value)

    # Parse summary
    total_rows_detected = Column(Integer, nullable=True)
    total_rows_parsed = Column(Integer, nullable=True)
    total_rows_skipped = Column(Integer, nullable=True)
    company_name_detected = Column(String(300), nullable=True)

    # Binding summary
    total_matched = Column(Integer, nullable=True)
    total_unmatched = Column(Integer, nullable=True)
    total_new_accounts = Column(Integer, nullable=True)
    binding_confidence_avg = Column(Float, nullable=True)
    binding_approved = Column(Boolean, default=False)

    uploaded_by = Column(String(36), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_tb_upload_client", "client_id"),
        Index("ix_tb_upload_status", "upload_status"),
        Index("ix_tb_upload_coa", "coa_upload_id"),
    )


# ═══════════════════════════════════════════════════════════
# Table: tb_parsed_rows
# ═══════════════════════════════════════════════════════════

class TbParsedRow(Base):
    """Individual parsed row from a trial balance file."""
    __tablename__ = "tb_parsed_rows"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tb_upload_id = Column(String(36), ForeignKey("trial_balance_uploads.id", ondelete="CASCADE"), nullable=False, index=True)
    source_row_number = Column(Integer, nullable=False)

    # Raw fields from file
    account_code = Column(String(100), nullable=True)
    account_name_raw = Column(String(500), nullable=False)
    account_name_normalized = Column(String(500), nullable=True)
    tab_raw = Column(String(200), nullable=True)
    sub_tab = Column(String(200), nullable=True)

    # Amounts
    open_debit = Column(Float, default=0.0)
    open_credit = Column(Float, default=0.0)
    movement_debit = Column(Float, default=0.0)
    movement_credit = Column(Float, default=0.0)
    close_debit = Column(Float, default=0.0)
    close_credit = Column(Float, default=0.0)
    net_balance = Column(Float, default=0.0)

    # Status
    is_summary_row = Column(Boolean, default=False)
    issues_json = Column(JSON, default=list)

    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("tb_upload_id", "source_row_number", name="uq_tb_row"),
        Index("ix_tb_row_upload", "tb_upload_id"),
        Index("ix_tb_row_code", "account_code"),
    )


# ═══════════════════════════════════════════════════════════
# Table: tb_binding_results
# ═══════════════════════════════════════════════════════════

class TbBindingResult(Base):
    """Result of binding a TB row to an approved COA account."""
    __tablename__ = "tb_binding_results"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tb_upload_id = Column(String(36), ForeignKey("trial_balance_uploads.id", ondelete="CASCADE"), nullable=False, index=True)
    tb_row_id = Column(String(36), ForeignKey("tb_parsed_rows.id"), nullable=False)
    coa_account_id = Column(String(36), ForeignKey("client_chart_of_accounts.id"), nullable=True)

    # TB side
    tb_account_code = Column(String(100), nullable=True)
    tb_account_name_raw = Column(String(500), nullable=False)

    # Amounts (copied for quick access)
    tb_amount_debit = Column(Float, default=0.0)
    tb_amount_credit = Column(Float, default=0.0)
    tb_net_balance = Column(Float, default=0.0)

    # Binding result
    matched = Column(Boolean, default=False)
    match_type = Column(String(50), nullable=True)
    binding_confidence = Column(Float, default=0.0)
    mismatch_reason = Column(String(200), nullable=True)
    requires_review = Column(Boolean, default=False)

    # COA side (from matched account)
    coa_normalized_class = Column(String(100), nullable=True)
    coa_statement_section = Column(String(100), nullable=True)
    coa_cashflow_role = Column(String(50), nullable=True)

    # Review
    review_status = Column(String(30), default="auto")  # auto, manually_matched, approved, rejected
    reviewed_by = Column(String(36), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_binding_upload", "tb_upload_id"),
        Index("ix_binding_matched", "tb_upload_id", "matched"),
        Index("ix_binding_review", "tb_upload_id", "requires_review"),
    )


def init_sprint4_tb_db():
    """Create Sprint 4 TB tables."""
    from app.phase1.models.platform_models import engine
    TrialBalanceUpload.__table__.create(bind=engine, checkfirst=True)
    TbParsedRow.__table__.create(bind=engine, checkfirst=True)
    TbBindingResult.__table__.create(bind=engine, checkfirst=True)
    return "Sprint 4 TB tables created"
