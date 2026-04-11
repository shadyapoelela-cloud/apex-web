"""
APEX Platform - Archive System Models
Per Architecture Doc v5 Section 25
Retention: 30 days default, auto-purge, reuse from archive
"""

from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    BigInteger,
    DateTime,
    Text,
    ForeignKey,
    Index,
)
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class ArchiveItem(Base):
    __tablename__ = "archive_items"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    owner_user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    client_id = Column(String(36), ForeignKey("clients.id"), nullable=True, index=True)
    source_type = Column(String(50), nullable=False)  # coa_upload, tb_upload, service_output, manual
    source_id = Column(String(36), nullable=True)  # ID of the source record
    file_name = Column(String(300), nullable=False)
    file_ext = Column(String(20), nullable=True)
    mime_type = Column(String(100), nullable=True)
    storage_key = Column(Text, nullable=False)  # path or object key
    size_bytes = Column(BigInteger, nullable=True)
    visibility_scope = Column(String(30), default="private")  # private, client, organization
    status = Column(String(30), default="active")  # active, expiring_soon, locked_by_process, deleted, purged
    archived_at = Column(DateTime, default=utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)  # archived_at + retention_days
    deleted_at = Column(DateTime, nullable=True)
    purged_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (
        Index("ix_archive_user_client", "owner_user_id", "client_id"),
        Index("ix_archive_status_expires", "status", "expires_at"),
    )


class ArchiveLink(Base):
    __tablename__ = "archive_links"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    archive_item_id = Column(String(36), ForeignKey("archive_items.id", ondelete="CASCADE"), nullable=False, index=True)
    target_process_type = Column(String(50), nullable=False)  # coa_upload, tb_upload, service_case
    target_process_id = Column(String(36), nullable=False)
    attached_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    attached_at = Column(DateTime, default=utcnow, nullable=False)


class ArchiveRetentionEvent(Base):
    __tablename__ = "archive_retention_events"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    archive_item_id = Column(String(36), ForeignKey("archive_items.id", ondelete="CASCADE"), nullable=False, index=True)
    event_type = Column(
        String(30), nullable=False
    )  # warning_30d, warning_7d, warning_3d, warning_1d, deleted, purged, hold_applied, hold_released
    event_at = Column(DateTime, default=utcnow, nullable=False)
    actor_id = Column(String(36), nullable=True)  # system or user
    notes = Column(Text, nullable=True)


class ArchivePolicy(Base):
    __tablename__ = "archive_policies"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    scope_type = Column(String(30), nullable=False)  # global, client_type, service, role
    scope_id = Column(String(50), nullable=True)  # specific code or null for global
    retention_days = Column(Integer, default=30, nullable=False)
    allow_reuse = Column(Boolean, default=True)
    allow_download = Column(Boolean, default=True)
    hold_rule = Column(String(100), nullable=True)  # e.g. "active_process", "legal_hold"
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)
