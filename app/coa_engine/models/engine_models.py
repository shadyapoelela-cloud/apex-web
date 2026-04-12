"""
APEX COA Engine v4.2 -- Database Models
================================================================
14 tables for the COA analysis engine:
  - Error registry & per-account errors
  - Canonical accounts & sector lexicon
  - Accounting references (IFRS/SOCPA/ZATCA)
  - Upload processing, account analysis, quality assessment
  - Approval workflow, version tracking, evolution log
  - Sector benchmarks, engine rules, migration mapping

All tables use "v2" suffix where needed to avoid collision with
existing sprint tables.
"""

from datetime import datetime

from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Boolean,
    Text,
    DateTime,
    JSON,
    ForeignKey,
)
from sqlalchemy.orm import declarative_base, relationship

# ================================================================
# Declarative Base
# ================================================================

COAEngineBase = declarative_base()


# ================================================================
# 1. coa_error_registry -- 58 error type definitions
# ================================================================

class CoaErrorRegistry(COAEngineBase):
    __tablename__ = "coa_error_registry"

    id = Column(Integer, primary_key=True, autoincrement=True)
    error_code = Column(String(50), unique=True, nullable=False)
    name_ar = Column(String(255), nullable=False)
    severity = Column(String(20), nullable=False)  # Critical/High/Medium/Low
    category = Column(String(100), nullable=False)
    description_ar = Column(Text, nullable=True)
    cause_ar = Column(Text, nullable=True)
    suggestion_ar = Column(Text, nullable=True)
    auto_fixable = Column(Boolean, default=False)
    references = Column(JSON, nullable=True)

    def __repr__(self):
        return f"<CoaErrorRegistry(error_code={self.error_code!r}, severity={self.severity!r})>"


# ================================================================
# 2. coa_uploads_v2 -- Upload + processing status
#    (defined before dependents so FKs resolve)
# ================================================================

class CoaUploadV2(COAEngineBase):
    __tablename__ = "coa_uploads_v2"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, nullable=True)
    filename = Column(String(500), nullable=True)
    upload_date = Column(DateTime, nullable=True)
    upload_status = Column(String(20), default="pending")  # pending/processing/completed/failed
    pattern_detected = Column(String(100), nullable=True)
    erp_system = Column(String(100), nullable=True)
    encoding_detected = Column(String(50), nullable=True)
    column_mapping = Column(JSON, nullable=True)
    warnings = Column(JSON, nullable=True)
    row_count = Column(Integer, nullable=True)
    processing_ms = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    accounts = relationship("CoaAccountV2", back_populates="upload", lazy="dynamic")
    errors = relationship("CoaAccountError", back_populates="upload", lazy="dynamic")
    assessment = relationship("CoaAssessmentV2", back_populates="upload", uselist=False)
    approvals = relationship("CoaApprovalRecord", back_populates="upload", lazy="dynamic")
    versions = relationship("CoaVersion", back_populates="upload", lazy="dynamic")

    def __repr__(self):
        return f"<CoaUploadV2(id={self.id}, filename={self.filename!r}, status={self.upload_status!r})>"


# ================================================================
# 3. coa_account_errors -- Detected errors per account
# ================================================================

class CoaAccountError(COAEngineBase):
    __tablename__ = "coa_account_errors"

    id = Column(Integer, primary_key=True, autoincrement=True)
    upload_id = Column(Integer, ForeignKey("coa_uploads_v2.id"), nullable=False)
    account_code = Column(String(50), nullable=False)
    error_code = Column(String(50), nullable=False)
    description = Column(Text, nullable=True)
    cause = Column(Text, nullable=True)
    suggestion = Column(Text, nullable=True)
    references = Column(JSON, nullable=True)
    auto_fix_applied = Column(Boolean, default=False)
    resolved = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    upload = relationship("CoaUploadV2", back_populates="errors")

    def __repr__(self):
        return f"<CoaAccountError(account={self.account_code!r}, error={self.error_code!r})>"


# ================================================================
# 4. canonical_accounts -- 278+ canonical account definitions
# ================================================================

class CanonicalAccount(COAEngineBase):
    __tablename__ = "canonical_accounts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    concept_id = Column(String(100), unique=True, nullable=False)  # e.g. "CASH", "ACC_RECEIVABLE"
    code_pattern = Column(String(100), nullable=True)
    name_ar = Column(String(255), nullable=False)
    name_en = Column(String(255), nullable=True)
    section = Column(String(100), nullable=True)
    nature = Column(String(10), nullable=True)  # debit/credit
    level = Column(Integer, nullable=True)
    definition_ar = Column(Text, nullable=True)
    mandatory_sectors = Column(JSON, nullable=True)

    def __repr__(self):
        return f"<CanonicalAccount(concept_id={self.concept_id!r}, name_ar={self.name_ar!r})>"


# ================================================================
# 5. sector_lexicon -- 45 Saudi sectors
# ================================================================

class SectorLexicon(COAEngineBase):
    __tablename__ = "sector_lexicon"

    id = Column(Integer, primary_key=True, autoincrement=True)
    sector_code = Column(String(50), unique=True, nullable=False)
    sector_name_ar = Column(String(255), nullable=False)
    sector_name_en = Column(String(255), nullable=True)
    mandatory_accounts = Column(JSON, nullable=True)
    regulatory_body = Column(String(200), nullable=True)
    ifrs_requirements = Column(Text, nullable=True)

    def __repr__(self):
        return f"<SectorLexicon(sector_code={self.sector_code!r}, name_ar={self.sector_name_ar!r})>"


# ================================================================
# 6. accounting_references -- IFRS/SOCPA/ZATCA references
# ================================================================

class AccountingReference(COAEngineBase):
    __tablename__ = "accounting_references"

    id = Column(Integer, primary_key=True, autoincrement=True)
    reference_id = Column(String(100), unique=True, nullable=False)
    standard_name = Column(String(200), nullable=False)
    paragraph = Column(String(100), nullable=True)
    title_ar = Column(String(500), nullable=True)
    full_text_ar = Column(Text, nullable=True)
    applicable_errors = Column(JSON, nullable=True)

    def __repr__(self):
        return f"<AccountingReference(reference_id={self.reference_id!r}, standard={self.standard_name!r})>"


# ================================================================
# 7. coa_accounts_v2 -- Analyzed accounts
# ================================================================

class CoaAccountV2(COAEngineBase):
    __tablename__ = "coa_accounts_v2"

    id = Column(Integer, primary_key=True, autoincrement=True)
    upload_id = Column(Integer, ForeignKey("coa_uploads_v2.id"), nullable=False)
    account_code = Column(String(50), nullable=False)
    name_raw = Column(String(500), nullable=True)
    name_normalized = Column(String(500), nullable=True)
    parent_code = Column(String(50), nullable=True)
    level = Column(Integer, nullable=True)
    concept_id = Column(String(100), nullable=True)
    section = Column(String(100), nullable=True)
    nature = Column(String(10), nullable=True)  # debit/credit
    account_level = Column(String(20), nullable=True)  # header/sub/detail
    confidence = Column(Float, nullable=True)
    classification_method = Column(String(50), nullable=True)
    review_status = Column(String(20), default="pending")  # auto_approved/pending/rejected
    errors = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    upload = relationship("CoaUploadV2", back_populates="accounts")

    def __repr__(self):
        return f"<CoaAccountV2(code={self.account_code!r}, concept={self.concept_id!r})>"


# ================================================================
# 8. coa_assessments_v2 -- Quality assessment
# ================================================================

class CoaAssessmentV2(COAEngineBase):
    __tablename__ = "coa_assessments_v2"

    id = Column(Integer, primary_key=True, autoincrement=True)
    upload_id = Column(Integer, ForeignKey("coa_uploads_v2.id"), unique=True, nullable=False)
    overall_score = Column(Float, nullable=True)
    quality_dimensions = Column(JSON, nullable=True)
    errors_summary = Column(JSON, nullable=True)
    recommendations = Column(JSON, nullable=True)
    report_card = Column(JSON, nullable=True)
    sector_detected = Column(String(100), nullable=True)
    sector_similarity = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    upload = relationship("CoaUploadV2", back_populates="assessment")

    def __repr__(self):
        return f"<CoaAssessmentV2(upload_id={self.upload_id}, score={self.overall_score})>"


# ================================================================
# 9. coa_approval_records -- Approval log
# ================================================================

class CoaApprovalRecord(COAEngineBase):
    __tablename__ = "coa_approval_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    upload_id = Column(Integer, ForeignKey("coa_uploads_v2.id"), nullable=False)
    action = Column(String(20), nullable=False)  # approved/rejected/pending_review
    approved_by = Column(Integer, nullable=True)
    quality_score = Column(Float, nullable=True)
    blocked_by_errors = Column(JSON, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    upload = relationship("CoaUploadV2", back_populates="approvals")

    def __repr__(self):
        return f"<CoaApprovalRecord(upload_id={self.upload_id}, action={self.action!r})>"


# ================================================================
# 10. coa_versions -- COA version tracking
# ================================================================

class CoaVersion(COAEngineBase):
    __tablename__ = "coa_versions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, nullable=False)
    version_number = Column(Integer, nullable=False)
    upload_id = Column(Integer, ForeignKey("coa_uploads_v2.id"), nullable=False)
    label = Column(String(200), nullable=True)
    is_active = Column(Boolean, default=True)
    total_accounts = Column(Integer, nullable=True)
    quality_score = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    upload = relationship("CoaUploadV2", back_populates="versions")

    def __repr__(self):
        return f"<CoaVersion(client={self.client_id}, v={self.version_number}, active={self.is_active})>"


# ================================================================
# 11. coa_evolution_log -- Changes between versions
# ================================================================

class CoaEvolutionLog(COAEngineBase):
    __tablename__ = "coa_evolution_log"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, nullable=False)
    from_version = Column(Integer, nullable=False)
    to_version = Column(Integer, nullable=False)
    change_type = Column(String(30), nullable=False)  # added/removed/renamed/recoded/reclassified
    account_code = Column(String(50), nullable=False)
    old_value = Column(String(500), nullable=True)
    new_value = Column(String(500), nullable=True)
    risk_level = Column(String(10), nullable=True)  # low/medium/high
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<CoaEvolutionLog(client={self.client_id}, {self.from_version}->{self.to_version}, {self.change_type!r})>"


# ================================================================
# 12. sector_benchmarks -- Quality stats by sector
# ================================================================

class SectorBenchmark(COAEngineBase):
    __tablename__ = "sector_benchmarks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    sector_code = Column(String(50), nullable=False)
    period = Column(String(20), nullable=True)
    sample_size = Column(Integer, nullable=True)
    avg_score = Column(Float, nullable=True)
    p25_score = Column(Float, nullable=True)
    p50_score = Column(Float, nullable=True)
    p75_score = Column(Float, nullable=True)
    p90_score = Column(Float, nullable=True)
    top_errors = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<SectorBenchmark(sector={self.sector_code!r}, avg={self.avg_score})>"


# ================================================================
# 13. engine_rules -- Engine rules lifecycle
# ================================================================

class EngineRule(COAEngineBase):
    __tablename__ = "engine_rules"

    id = Column(Integer, primary_key=True, autoincrement=True)
    rule_code = Column(String(100), unique=True, nullable=False)
    rule_type = Column(String(50), nullable=False)
    status = Column(String(20), default="active")  # active/deprecated/testing
    version = Column(Integer, default=1)
    precision_score = Column(Float, nullable=True)
    recall_score = Column(Float, nullable=True)
    false_positive_rate = Column(Float, nullable=True)
    approved_by = Column(String(200), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<EngineRule(rule_code={self.rule_code!r}, status={self.status!r}, v={self.version})>"


# ================================================================
# 14. coa_migration_map -- Code mapping between versions
# ================================================================

class CoaMigrationMap(COAEngineBase):
    __tablename__ = "coa_migration_map"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(Integer, nullable=False)
    from_version = Column(Integer, nullable=False)
    to_version = Column(Integer, nullable=False)
    old_code = Column(String(50), nullable=False)
    new_code = Column(String(50), nullable=True)
    canonical_id = Column(String(100), nullable=True)
    map_type = Column(String(20), nullable=False)  # SAME/RENAMED/RECODED/RECLASSIFIED/MERGED/SPLIT/DELETED
    confidence = Column(Float, nullable=True)
    auto_matched = Column(Boolean, default=True)
    reviewed_by = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<CoaMigrationMap(client={self.client_id}, {self.old_code!r}->{self.new_code!r}, type={self.map_type!r})>"


# ================================================================
# Table Creation Helper
# ================================================================

def init_coa_engine_db(engine):
    """
    Create all COA Engine v4.2 tables.
    Called during application startup via lifespan.
    """
    COAEngineBase.metadata.create_all(bind=engine)
