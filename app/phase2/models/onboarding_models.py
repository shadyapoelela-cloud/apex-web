"""
APEX Platform - Client Onboarding Extension Models
Legal Entity Types + Sectors (Main/Sub) + Client Required Documents
Extension over phase2_models.py - per Architecture Doc v5 Section 29
"""

from sqlalchemy import (
    Column, String, Boolean, Integer,
    DateTime, Text, ForeignKey, JSON, Index,
)
from sqlalchemy.orm import relationship
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# 1. Legal Entity Types (Reference Table)
class LegalEntityType(Base):
    __tablename__ = "legal_entity_types"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=False)
    description_ar = Column(Text, nullable=True)
    description_en = Column(Text, nullable=True)
    required_documents_profile = Column(JSON, nullable=True)  # list of doc codes required for this type
    additional_fields = Column(JSON, nullable=True)  # extra fields needed for this entity type
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


# 2. Sector Main (Reference Table)
class SectorMain(Base):
    __tablename__ = "sector_main"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=False)
    icon = Column(String(50), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    sub_sectors = relationship("SectorSub", back_populates="parent_sector", cascade="all, delete-orphan")


# 3. Sector Sub (Reference Table)
class SectorSub(Base):
    __tablename__ = "sector_sub"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    code = Column(String(50), unique=True, nullable=False, index=True)
    sector_main_code = Column(String(50), ForeignKey("sector_main.code"), nullable=False, index=True)
    name_ar = Column(String(200), nullable=False)
    name_en = Column(String(200), nullable=False)
    requires_license = Column(Boolean, default=False)
    license_type = Column(String(100), nullable=True)
    additional_documents = Column(JSON, nullable=True)  # extra docs for regulated sub-sectors
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    parent_sector = relationship("SectorMain", back_populates="sub_sectors")


# 4. Client Required Documents (Dynamic per client)
class ClientRequiredDocument(Base):
    __tablename__ = "client_required_documents"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    client_id = Column(String(36), ForeignKey("clients.id", ondelete="CASCADE"), nullable=False, index=True)
    document_code = Column(String(50), nullable=False)  # e.g. cr_certificate, tax_certificate, license
    document_name_ar = Column(String(200), nullable=False)
    document_name_en = Column(String(200), nullable=True)
    is_mandatory = Column(Boolean, default=True)
    source_rule = Column(String(50), nullable=True)  # entity_type / sector / service
    status = Column(String(30), default="required")  # required, uploaded, verified, rejected, expired
    file_path = Column(Text, nullable=True)
    file_name = Column(String(300), nullable=True)
    uploaded_at = Column(DateTime, nullable=True)
    verified_at = Column(DateTime, nullable=True)
    verified_by = Column(String(36), nullable=True)
    rejection_reason = Column(Text, nullable=True)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_client_doc_status", "client_id", "status"),
    )


# 5. Client Onboarding Draft (saves wizard progress)
class ClientOnboardingDraft(Base):
    __tablename__ = "client_onboarding_drafts"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    step_completed = Column(Integer, default=0)  # 0-7
    draft_data = Column(JSON, nullable=False, default={})  # all wizard fields as JSON
    is_converted = Column(Boolean, default=False)  # True when client created
    converted_client_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)


# 6. Stage Notes (per Architecture Doc v5 Section 23)
class StageNote(Base):
    __tablename__ = "stage_notes"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    service_key = Column(String(50), nullable=False, index=True)  # e.g. coa_upload, tb_binding, audit
    stage_key = Column(String(50), nullable=False, index=True)  # e.g. upload, mapping, parse
    role_scope = Column(String(30), default="all")  # all, client, reviewer, admin
    title_ar = Column(String(300), nullable=False)
    title_en = Column(String(300), nullable=True)
    body_ar = Column(Text, nullable=False)
    body_en = Column(Text, nullable=True)
    common_errors_ar = Column(Text, nullable=True)
    common_errors_en = Column(Text, nullable=True)
    impact_ar = Column(Text, nullable=True)  # what happens if skipped
    impact_en = Column(Text, nullable=True)
    required_documents = Column(JSON, nullable=True)  # list of doc codes
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_stage_note_lookup", "service_key", "stage_key", "role_scope"),
    )
