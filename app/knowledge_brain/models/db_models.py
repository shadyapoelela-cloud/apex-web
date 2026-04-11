"""
Apex Knowledge Brain — Database Models (SQLAlchemy + SQLite)
═════════════════════════════════════════════════════════════

14 tables per implementation plan:
knowledge_sources, knowledge_entries, knowledge_rules, knowledge_rule_versions,
knowledge_domains, knowledge_sectors, knowledge_sector_mappings,
knowledge_cases, knowledge_patterns, knowledge_updates,
knowledge_review_queue, knowledge_audit_log, knowledge_authorities, knowledge_playbooks
"""

import os
import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    create_engine,
    Column,
    String,
    Text,
    Float,
    Integer,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    JSON,
    Index,
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

# ─── Database Setup ───
import logging as _logging

_kb_logger = _logging.getLogger(__name__)

DB_PATH = os.environ.get("KB_DATABASE_URL", "sqlite:///knowledge_brain.db")
# Render PostgreSQL fix: postgres:// -> postgresql://
if DB_PATH.startswith("postgres://"):
    DB_PATH = DB_PATH.replace("postgres://", "postgresql://", 1)
if "sqlite" in DB_PATH:
    _kb_logger.warning("Knowledge Brain using SQLite — set KB_DATABASE_URL for production PostgreSQL")
    engine = create_engine(DB_PATH, echo=False, connect_args={"check_same_thread": False})
else:
    engine = create_engine(DB_PATH, echo=False, pool_size=5, max_overflow=10, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def gen_id():
    return str(uuid.uuid4())[:12]


# ═══════════════════════════════════════════
#  1. knowledge_authorities — الجهات المرجعية
# ═══════════════════════════════════════════


class Authority(Base):
    __tablename__ = "knowledge_authorities"
    id = Column(String(12), primary_key=True, default=gen_id)
    code = Column(String(20), unique=True, nullable=False, index=True)  # ZATCA, SOCPA, MOC
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200))
    jurisdiction = Column(String(10), default="sa")  # sa, international
    domain_scope = Column(JSON)  # ["tax", "customs"]
    official_urls = Column(JSON)
    source_priority = Column(Integer, default=5)  # 1=highest
    update_frequency = Column(String(20))  # monthly, quarterly, annual
    notes = Column(Text)
    active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


# ═══════════════════════════════════════════
#  2. knowledge_domains — المجالات المعرفية
# ═══════════════════════════════════════════


class Domain(Base):
    __tablename__ = "knowledge_domains"
    id = Column(String(12), primary_key=True, default=gen_id)
    code = Column(String(30), unique=True, nullable=False, index=True)  # tax, accounting, governance
    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100))
    description = Column(Text)
    priority = Column(Integer, default=5)
    active = Column(Boolean, default=True)


# ═══════════════════════════════════════════
#  3. knowledge_sectors — القطاعات
# ═══════════════════════════════════════════


class Sector(Base):
    __tablename__ = "knowledge_sectors"
    id = Column(String(12), primary_key=True, default=gen_id)
    code = Column(String(30), unique=True, nullable=False, index=True)  # retail, manufacturing
    name_ar = Column(String(100), nullable=False)
    name_en = Column(String(100))
    description = Column(Text)
    parent_sector_id = Column(String(12), ForeignKey("knowledge_sectors.id"), index=True)
    active = Column(Boolean, default=True)


# ═══════════════════════════════════════════
#  4. knowledge_sources — المصادر الرسمية
# ═══════════════════════════════════════════


class Source(Base):
    __tablename__ = "knowledge_sources"
    id = Column(String(12), primary_key=True, default=gen_id)
    domain = Column(String(30), index=True)
    subdomain = Column(String(50))
    title = Column(String(300), nullable=False)
    authority_code = Column(String(20), ForeignKey("knowledge_authorities.code"), index=True)
    source_type = Column(String(30), index=True)  # law, regulation, standard, guide, bulletin, best_practice
    legal_force = Column(String(30))  # binding_law, implementing_regulation, professional_standard...
    official_reference = Column(String(200))  # رقم النظام/المعيار
    source_url = Column(String(500))
    country = Column(String(10), default="sa")
    language = Column(String(5), default="ar")
    version_label = Column(String(20))
    issue_date = Column(Date)
    effective_date = Column(Date)
    expiry_date = Column(Date)
    status = Column(String(20), default="active", index=True)  # active, superseded, archived, draft
    superseded_by = Column(String(12))
    raw_text = Column(Text)
    checksum = Column(String(64))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    entries = relationship("Entry", back_populates="source")

    __table_args__ = (Index("idx_source_domain_status", "domain", "status"),)


# ═══════════════════════════════════════════
#  5. knowledge_entries — المعرفة المنظمة
# ═══════════════════════════════════════════


class Entry(Base):
    __tablename__ = "knowledge_entries"
    id = Column(String(12), primary_key=True, default=gen_id)
    source_id = Column(String(12), ForeignKey("knowledge_sources.id"), index=True)
    entry_code = Column(String(50), index=True)  # IAS_2_PERIODIC_COGS
    domain = Column(String(30), index=True)
    subdomain = Column(String(50))
    title = Column(String(300), nullable=False)
    summary = Column(Text)
    structured_json = Column(JSON)  # key_points, obligations, exceptions
    applicability_json = Column(JSON)  # entity_types, sectors, thresholds
    obligations_json = Column(JSON)
    exceptions_json = Column(JSON)
    impacts_json = Column(JSON)  # financial, tax, governance, operational
    linked_rules = Column(JSON)  # [rule_ids]
    linked_cases = Column(JSON)  # [case_ids]
    confidence_level = Column(Float, default=0.95)
    obligation_level = Column(String(20), default="mandatory")  # mandatory, recommended, optional
    review_frequency = Column(String(20), default="annual")
    status = Column(String(20), default="approved", index=True)  # draft, under_review, approved, archived, superseded
    review_status = Column(String(20), default="approved")
    owner_user = Column(String(50))
    reviewer_user = Column(String(50))
    approver_user = Column(String(50))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    source = relationship("Source", back_populates="entries")

    __table_args__ = (Index("idx_entry_domain_status", "domain", "status"),)


# ═══════════════════════════════════════════
#  6. knowledge_rules — القواعد التنفيذية
# ═══════════════════════════════════════════


class Rule(Base):
    __tablename__ = "knowledge_rules"
    id = Column(String(12), primary_key=True, default=gen_id)
    rule_code = Column(String(50), unique=True, nullable=False, index=True)  # TAX_001_VAT
    domain = Column(String(30), index=True)
    subdomain = Column(String(50))
    rule_name_ar = Column(String(200), nullable=False)
    rule_name_en = Column(String(200))
    rule_type = Column(String(30))  # compliance, warning, recommendation, info
    scope = Column(String(50))  # all, sector_specific, entity_specific
    priority = Column(Integer, default=5)
    condition_json = Column(JSON)  # {"field": "revenue", "op": ">", "value": 375000}
    action_json = Column(JSON)  # {"type": "flag", "severity": "warning", "message": "..."}
    exception_json = Column(JSON)
    source_entry_id = Column(String(12), ForeignKey("knowledge_entries.id"), index=True)
    authority_code = Column(String(20))
    reference = Column(String(200))
    obligation_level = Column(String(20), default="mandatory")
    confidence_weight = Column(Float, default=0.95)
    active = Column(Boolean, default=True, index=True)
    version = Column(Integer, default=1)
    review_status = Column(String(20), default="approved")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )

    versions = relationship("RuleVersion", back_populates="rule")


# ═══════════════════════════════════════════
#  7. knowledge_rule_versions
# ═══════════════════════════════════════════


class RuleVersion(Base):
    __tablename__ = "knowledge_rule_versions"
    id = Column(String(12), primary_key=True, default=gen_id)
    rule_id = Column(String(12), ForeignKey("knowledge_rules.id"), index=True)
    version_no = Column(Integer, nullable=False)
    snapshot_json = Column(JSON)
    change_reason = Column(Text)
    changed_by = Column(String(50))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    rule = relationship("Rule", back_populates="versions")


# ═══════════════════════════════════════════
#  8. knowledge_sector_mappings
# ═══════════════════════════════════════════


class SectorMapping(Base):
    __tablename__ = "knowledge_sector_mappings"
    id = Column(String(12), primary_key=True, default=gen_id)
    sector_code = Column(String(30), ForeignKey("knowledge_sectors.code"), index=True)
    entity_type = Column(String(20))  # source, entry, rule, playbook
    entity_id = Column(String(12), index=True)
    notes = Column(Text)


# ═══════════════════════════════════════════
#  9. knowledge_cases — السوابق والحالات
# ═══════════════════════════════════════════


class Case(Base):
    __tablename__ = "knowledge_cases"
    id = Column(String(12), primary_key=True, default=gen_id)
    domain = Column(String(30), index=True)
    sector = Column(String(30))
    title = Column(String(300))
    description = Column(Text)
    input_summary = Column(Text)
    decision = Column(Text)
    reasoning = Column(Text)
    outcome = Column(Text)
    lessons_json = Column(JSON)
    linked_rules = Column(JSON)
    linked_entries = Column(JSON)
    status = Column(String(20), default="approved", index=True)
    date_recorded = Column(Date)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


# ═══════════════════════════════════════════
#  10. knowledge_patterns — الأنماط
# ═══════════════════════════════════════════


class Pattern(Base):
    __tablename__ = "knowledge_patterns"
    id = Column(String(12), primary_key=True, default=gen_id)
    domain = Column(String(30), index=True)
    sector = Column(String(30))
    pattern_type = Column(String(30))  # risk, behavior, seasonal, macro
    title = Column(String(200))
    description = Column(Text)
    data_json = Column(JSON)
    confidence = Column(Float, default=0.7)
    status = Column(String(20), default="approved")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


# ═══════════════════════════════════════════
#  11. knowledge_updates — التحديثات
# ═══════════════════════════════════════════


class Update(Base):
    __tablename__ = "knowledge_updates"
    id = Column(String(12), primary_key=True, default=gen_id)
    update_type = Column(String(30), index=True)  # regulatory, standard, tax, market
    title = Column(String(300), nullable=False)
    authority_code = Column(String(20))
    change_summary = Column(Text)
    effective_date = Column(Date)
    impacted_domains = Column(JSON)
    impacted_rules = Column(JSON)
    impacted_entries = Column(JSON)
    impacted_playbooks = Column(JSON)
    source_url = Column(String(500))
    status = Column(String(20), default="detected", index=True)  # detected, under_review, approved, applied, archived
    review_deadline = Column(Date)
    applied_at = Column(DateTime)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


# ═══════════════════════════════════════════
#  12. knowledge_playbooks — الأدلة التشغيلية
# ═══════════════════════════════════════════


class Playbook(Base):
    __tablename__ = "knowledge_playbooks"
    id = Column(String(12), primary_key=True, default=gen_id)
    title = Column(String(200), nullable=False)
    domain = Column(String(30), index=True)
    sector = Column(String(30))
    objective = Column(Text)
    when_to_use = Column(Text)
    required_inputs = Column(JSON)
    invoked_rules = Column(JSON)
    invoked_entries = Column(JSON)
    steps_json = Column(JSON)
    outputs_expected = Column(JSON)
    risk_flags = Column(JSON)
    status = Column(String(20), default="approved")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc)
    )


# ═══════════════════════════════════════════
#  13. knowledge_review_queue — طابور المراجعة
# ═══════════════════════════════════════════


class ReviewQueueItem(Base):
    __tablename__ = "knowledge_review_queue"
    id = Column(String(12), primary_key=True, default=gen_id)
    entity_type = Column(String(20), nullable=False)  # source, entry, rule, playbook, update
    entity_id = Column(String(12), nullable=False, index=True)
    action = Column(String(20))  # create, update, activate, deactivate, archive
    requested_by = Column(String(50))
    assigned_to = Column(String(50))
    status = Column(String(20), default="pending", index=True)  # pending, approved, rejected
    notes = Column(Text)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    resolved_at = Column(DateTime)


# ═══════════════════════════════════════════
#  14. knowledge_audit_log — سجل التعديلات
# ═══════════════════════════════════════════


class AuditLog(Base):
    __tablename__ = "knowledge_audit_log"
    id = Column(String(12), primary_key=True, default=gen_id)
    entity_type = Column(String(20), nullable=False, index=True)
    entity_id = Column(String(12), nullable=False, index=True)
    action = Column(String(20), nullable=False)  # create, update, delete, approve, reject, archive
    field_changed = Column(String(100))
    old_value = Column(Text)
    new_value = Column(Text)
    user = Column(String(50))
    reason = Column(Text)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)


# ═══════════════════════════════════════════
#  Create All Tables
# ═══════════════════════════════════════════


def init_db():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)
    return True


def get_table_stats(db):
    """Get count of records in each table."""
    return {
        "authorities": db.query(Authority).count(),
        "domains": db.query(Domain).count(),
        "sectors": db.query(Sector).count(),
        "sources": db.query(Source).count(),
        "entries": db.query(Entry).count(),
        "rules": db.query(Rule).count(),
        "cases": db.query(Case).count(),
        "patterns": db.query(Pattern).count(),
        "updates": db.query(Update).count(),
        "playbooks": db.query(Playbook).count(),
        "review_queue": db.query(ReviewQueueItem).count(),
        "audit_log": db.query(AuditLog).count(),
    }
