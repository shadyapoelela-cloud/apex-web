"""
APEX Phase 11 — Legal Acceptance Models
Tables: legal_documents_v2, acceptance_logs_v2
"""

from sqlalchemy import Column, String, DateTime, Boolean, Text, Integer, Float
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

LEGAL_DOC_TYPES = [
    "terms_of_service",
    "privacy_policy",
    "acceptable_use_policy",
    "provider_policy",
    "document_upload_policy",
]


class LegalDocumentV2(Base):
    """Versioned legal/policy documents."""

    __tablename__ = "legal_documents_v2"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    doc_type = Column(String(50), nullable=False, index=True)
    version = Column(String(20), nullable=False)
    title_ar = Column(String(255), nullable=False)
    title_en = Column(String(255), nullable=True)
    content_ar = Column(Text, nullable=False)
    content_en = Column(Text, nullable=True)
    is_current = Column(Boolean, default=True, index=True)
    is_mandatory = Column(Boolean, default=True)
    effective_date = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow)


class AcceptanceLogV2(Base):
    """Track user acceptance of legal documents."""

    __tablename__ = "acceptance_logs_v2"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    document_id = Column(String, nullable=False, index=True)
    doc_type = Column(String(50), nullable=False)
    doc_version = Column(String(20), nullable=False)
    accepted_at = Column(DateTime, default=utcnow)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)


def init_phase11_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["legal_documents_v2", "acceptance_logs_v2"]
