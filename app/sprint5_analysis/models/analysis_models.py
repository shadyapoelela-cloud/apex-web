"""
APEX Sprint 5 — Analysis Trigger Models
Links financial analysis to approved COA mapping + TB binding.
Tables: analysis_runs, analysis_results_linked
"""

from sqlalchemy import (
    Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, JSON, Index,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class AnalysisRun(Base):
    """Each approved TB binding can trigger one or more analysis runs."""
    __tablename__ = "analysis_runs"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    tb_upload_id = Column(String(36), ForeignKey("trial_balance_uploads.id", ondelete="CASCADE"), nullable=False)
    coa_upload_id = Column(String(36), ForeignKey("client_coa_uploads.id"), nullable=False)
    # Run metadata
    run_status = Column(String(30), nullable=False, default="pending")
    # pending -> running -> completed -> failed
    industry = Column(String(100), default="general")
    closing_inventory = Column(Float, nullable=True)
    # Results summary
    overall_confidence = Column(Float, nullable=True)
    total_accounts_analyzed = Column(Integer, default=0)
    matched_accounts = Column(Integer, default=0)
    unmatched_accounts = Column(Integer, default=0)
    binding_quality_score = Column(Float, nullable=True)
    # JSON snapshots of full results
    income_statement_json = Column(JSON, nullable=True)
    balance_sheet_json = Column(JSON, nullable=True)
    cash_flow_json = Column(JSON, nullable=True)
    ratios_json = Column(JSON, nullable=True)
    readiness_json = Column(JSON, nullable=True)
    validations_json = Column(JSON, nullable=True)
    knowledge_brain_json = Column(JSON, nullable=True)
    classification_json = Column(JSON, nullable=True)
    warnings_json = Column(JSON, default=list)
    error_message = Column(Text, nullable=True)
    # Audit
    triggered_by = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)
    __table_args__ = (
        Index("ix_analysis_run_client", "client_id"),
        Index("ix_analysis_run_tb", "tb_upload_id"),
        Index("ix_analysis_run_status", "run_status"),
    )


class AnalysisResultExplanation(Base):
    """Per-line-item explanation linked to an analysis run + COA account."""
    __tablename__ = "analysis_result_explanations"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    analysis_run_id = Column(String(36), ForeignKey("analysis_runs.id", ondelete="CASCADE"), nullable=False)
    coa_account_id = Column(String(36), nullable=True)
    result_type = Column(String(50), nullable=False)
    # income_line, balance_line, ratio, validation, readiness
    result_key = Column(String(100), nullable=False)
    result_value = Column(Float, nullable=True)
    explanation_ar = Column(Text, nullable=True)
    explanation_en = Column(Text, nullable=True)
    confidence = Column(Float, default=0.0)
    risk_severity = Column(String(20), default="low")
    source_rows_json = Column(JSON, default=list)
    applied_rules_json = Column(JSON, default=list)
    references_json = Column(JSON, default=list)
    requires_human_review = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    __table_args__ = (
        Index("ix_explanation_run", "analysis_run_id"),
        Index("ix_explanation_type", "result_type"),
    )


def init_sprint5_analysis_db():
    from app.phase1.models.platform_models import engine
    AnalysisRun.__table__.create(bind=engine, checkfirst=True)
    AnalysisResultExplanation.__table__.create(bind=engine, checkfirst=True)
    return "Sprint 5 Analysis tables created"
