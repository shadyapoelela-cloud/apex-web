"""
APEX Platform — Sprint 3 Models
═══════════════════════════════════════════════════════════════
COA Quality Assessment + Client-Specific Rules + COA Approval

New tables:
  - client_coa_assessments: quality scores per upload
  - client_coa_rules: client-specific classification rules/aliases
  - coa_approval_records: approval history for COA uploads

These build on Sprint 1 (parsing) and Sprint 2 (classification).
"""

from sqlalchemy import (
    Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, JSON, Index, UniqueConstraint,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class ClientCoaAssessment(Base):
    """Quality assessment result for a COA upload."""
    __tablename__ = "client_coa_assessments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    coa_upload_id = Column(String(36), ForeignKey("client_coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True)

    # Scores (0.0 - 1.0)
    overall_score = Column(Float, nullable=False, default=0.0)
    completeness_score = Column(Float, nullable=False, default=0.0)
    consistency_score = Column(Float, nullable=False, default=0.0)
    naming_clarity_score = Column(Float, nullable=False, default=0.0)
    duplication_risk_score = Column(Float, nullable=False, default=0.0)
    reporting_readiness_score = Column(Float, nullable=False, default=0.0)

    # Details
    total_accounts = Column(Integer, default=0)
    classified_accounts = Column(Integer, default=0)
    high_confidence_count = Column(Integer, default=0)
    low_confidence_count = Column(Integer, default=0)
    unclassified_count = Column(Integer, default=0)

    # Issues and recommendations (JSON arrays)
    issues_json = Column(JSON, default=list)
    recommendations_json = Column(JSON, default=list)
    missing_categories_json = Column(JSON, default=list)
    ambiguous_accounts_json = Column(JSON, default=list)
    duplicate_suspects_json = Column(JSON, default=list)

    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("coa_upload_id", name="uq_assessment_upload"),
        Index("ix_assessment_client", "client_id"),
    )


class ClientCoaRule(Base):
    """Client-specific classification rule or alias override."""
    __tablename__ = "client_coa_rules"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)

    rule_name = Column(String(200), nullable=False)
    rule_type = Column(String(50), nullable=False, default="alias")  # alias, classification_override, remap
    condition_json = Column(JSON, nullable=False)  # {"field": "account_name_raw", "contains": "..."}
    action_json = Column(JSON, nullable=False)  # {"set_class": "expense", "set_section": "operating_expense"}
    priority = Column(Integer, default=50)

    is_active = Column(Boolean, default=True)
    created_by = Column(String(36), nullable=True)
    source_upload_id = Column(String(36), nullable=True)  # which upload triggered this rule
    source_account_id = Column(String(36), nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_client_rule_active", "client_id", "is_active"),
    )


class CoaApprovalRecord(Base):
    """Tracks COA upload approval history."""
    __tablename__ = "coa_approval_records"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    coa_upload_id = Column(String(36), ForeignKey("client_coa_uploads.id", ondelete="CASCADE"), nullable=False, index=True)
    client_id = Column(String(36), ForeignKey("clients.id"), nullable=False)

    action = Column(String(30), nullable=False)  # approved, rejected, returned_for_review
    approved_by = Column(String(36), nullable=True)
    notes = Column(Text, nullable=True)

    # Snapshot at time of approval
    total_accounts = Column(Integer, default=0)
    approved_accounts = Column(Integer, default=0)
    overall_quality_score = Column(Float, nullable=True)
    avg_confidence = Column(Float, nullable=True)

    is_current = Column(Boolean, default=True)  # latest approval record
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_approval_upload", "coa_upload_id", "is_current"),
    )


def init_sprint3_db():
    """Create Sprint 3 tables."""
    from app.phase1.models.platform_models import engine
    ClientCoaAssessment.__table__.create(bind=engine, checkfirst=True)
    ClientCoaRule.__table__.create(bind=engine, checkfirst=True)
    CoaApprovalRecord.__table__.create(bind=engine, checkfirst=True)
    return "Sprint 3 tables created"
