"""
APEX Platform — Phase 3 Models
═══════════════════════════════════════════════════════════════
Knowledge Feedback + Review Queue + Candidate Rules

Migrations 08-09 per execution document:
  08: knowledge_feedback_events, feedback_attachments
  09: knowledge_feedback_reviews, knowledge_candidate_rules, active_knowledge_rules

Rules:
- Feedback stored separately — NEVER mutates production results directly
- Knowledge mode gated by client_type
- Review states: submitted → under_review → accepted/rejected/needs_refinement → queued_for_rule_design
"""

import enum
from sqlalchemy import (
    Column, String, Boolean, Integer, Float,
    DateTime, Text, ForeignKey, JSON, Index, UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class FeedbackType(str, enum.Enum):
    classification_correction = "classification_correction"
    missing_account_type = "missing_account_type"
    ratio_interpretation = "ratio_interpretation"
    sector_benchmark = "sector_benchmark"
    regulatory_note = "regulatory_note"
    calculation_issue = "calculation_issue"
    general_observation = "general_observation"


class FeedbackStatus(str, enum.Enum):
    submitted = "submitted"
    under_review = "under_review"
    accepted = "accepted"
    rejected = "rejected"
    needs_refinement = "needs_refinement"
    queued_for_rule_design = "queued_for_rule_design"


class RulePromotionType(str, enum.Enum):
    alias_rule = "alias_rule"
    parsing_rule = "parsing_rule"
    normalization_rule = "normalization_rule"
    classification_rule = "classification_rule"
    sector_rule = "sector_rule"
    regulatory_rule = "regulatory_rule"
    explanation_rule = "explanation_rule"


class RuleStatus(str, enum.Enum):
    candidate = "candidate"
    testing = "testing"
    active = "active"
    deprecated = "deprecated"


class ApplicabilityScope(str, enum.Enum):
    global_all = "global"
    sector_specific = "sector_specific"
    client_type_specific = "client_type_specific"
    entity_specific = "entity_specific"


# ═══════════════════════════════════════════════════════════════
# Migration 08: Knowledge Feedback Events
# ═══════════════════════════════════════════════════════════════

class KnowledgeFeedbackEvent(Base):
    """
    Structured feedback from eligible users.
    Never mutates production results directly.
    """
    __tablename__ = "knowledge_feedback_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    client_id = Column(String(36), ForeignKey("clients.id"), nullable=True, index=True)
    result_id = Column(String(36), nullable=True, index=True)
    explanation_id = Column(String(36), nullable=True)

    feedback_type = Column(String(50), nullable=False)
    status = Column(String(30), default=FeedbackStatus.submitted.value, nullable=False)

    # What metric/result is this about?
    target_metric_key = Column(String(80), nullable=True)
    target_account_name = Column(String(300), nullable=True)
    target_classification = Column(String(50), nullable=True)

    # The feedback content
    title = Column(String(300), nullable=False)
    description = Column(Text, nullable=False)
    suggested_correction = Column(Text, nullable=True)
    suggested_classification = Column(String(50), nullable=True)
    evidence = Column(Text, nullable=True)
    reference_standard = Column(String(100), nullable=True)  # e.g. "IAS 2", "IFRS 16"

    # Scope — not every accepted item is globally reusable
    applicability_scope = Column(String(30), default=ApplicabilityScope.global_all.value)
    scope_sector = Column(String(50), nullable=True)
    scope_client_type = Column(String(50), nullable=True)

    # Metadata
    priority = Column(String(10), default="normal")  # low, normal, high, critical
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    attachments = relationship("FeedbackAttachment", back_populates="feedback", cascade="all, delete-orphan")
    reviews = relationship("KnowledgeFeedbackReview", back_populates="feedback", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_feedback_status_type", "status", "feedback_type"),
        Index("ix_feedback_user_result", "user_id", "result_id"),
    )


class FeedbackAttachment(Base):
    """Files attached to feedback (screenshots, documents)."""
    __tablename__ = "feedback_attachments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    feedback_id = Column(String(36), ForeignKey("knowledge_feedback_events.id", ondelete="CASCADE"), nullable=False, index=True)
    filename = Column(String(300), nullable=False)
    file_type = Column(String(20), nullable=True)
    file_size_bytes = Column(Integer, nullable=True)
    storage_path = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    feedback = relationship("KnowledgeFeedbackEvent", back_populates="attachments")


# ═══════════════════════════════════════════════════════════════
# Migration 09: Knowledge Governance
# ═══════════════════════════════════════════════════════════════

class KnowledgeFeedbackReview(Base):
    """Review decisions on feedback items."""
    __tablename__ = "knowledge_feedback_reviews"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    feedback_id = Column(String(36), ForeignKey("knowledge_feedback_events.id", ondelete="CASCADE"), nullable=False, index=True)
    reviewer_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    decision = Column(String(30), nullable=False)  # accepted, rejected, needs_refinement, queued_for_rule_design
    reviewer_notes = Column(Text, nullable=True)
    quality_score = Column(Integer, nullable=True)  # 1-5
    created_at = Column(DateTime, default=utcnow, nullable=False)

    feedback = relationship("KnowledgeFeedbackEvent", back_populates="reviews")

    __table_args__ = (
        Index("ix_review_feedback_reviewer", "feedback_id", "reviewer_id"),
    )


class KnowledgeCandidateRule(Base):
    """Rules promoted from accepted feedback — awaiting activation."""
    __tablename__ = "knowledge_candidate_rules"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    source_feedback_id = Column(String(36), ForeignKey("knowledge_feedback_events.id"), nullable=True)
    created_by = Column(String(36), ForeignKey("users.id"), nullable=False)

    rule_type = Column(String(50), nullable=False)  # alias_rule, classification_rule, etc.
    rule_code = Column(String(80), unique=True, nullable=False)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=True)
    description = Column(Text, nullable=True)

    # Rule definition
    condition = Column(JSON, nullable=False)  # {"field": "account_name", "contains": "مشتريات"}
    action = Column(JSON, nullable=False)  # {"set_class": "purchases"}
    priority = Column(Integer, default=50)  # Higher = checked first

    # Scope
    applicability_scope = Column(String(30), default=ApplicabilityScope.global_all.value)
    scope_sector = Column(String(50), nullable=True)

    status = Column(String(20), default=RuleStatus.candidate.value, nullable=False)
    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    test_results = Column(JSON, nullable=True)  # Results from testing phase

    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_candidate_rule_status", "status", "rule_type"),
    )


class ActiveKnowledgeRule(Base):
    """Production-active rules promoted from candidates."""
    __tablename__ = "active_knowledge_rules"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    candidate_rule_id = Column(String(36), ForeignKey("knowledge_candidate_rules.id"), nullable=True)
    rule_type = Column(String(50), nullable=False)
    rule_code = Column(String(80), unique=True, nullable=False)
    name_ar = Column(String(200), nullable=False)
    condition = Column(JSON, nullable=False)
    action = Column(JSON, nullable=False)
    priority = Column(Integer, default=50)
    applicability_scope = Column(String(30), default="global")
    is_active = Column(Boolean, default=True)
    activated_by = Column(String(36), nullable=False)
    activated_at = Column(DateTime, default=utcnow, nullable=False)
    version = Column(Integer, default=1)
    created_at = Column(DateTime, default=utcnow, nullable=False)
