from sqlalchemy import Column, String, Text, JSON, DateTime, ForeignKey, Integer, Boolean, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from app.phase1.models.platform_models import Base

class CopilotSession(Base):
    __tablename__ = copilot_sessions
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey(auth_users.id), nullable=False)
    client_id = Column(String, nullable=True)
    session_type = Column(String(50), default=general)
    context = Column(JSON, default={})
    status = Column(String(20), default=active)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class CopilotMessage(Base):
    __tablename__ = copilot_messages
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey(copilot_sessions.id), nullable=False)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    intent = Column(String(100), nullable=True)
    tools_used = Column(JSON, nullable=True)
    confidence = Column(Float, nullable=True)
    risk_level = Column(String(20), nullable=True)
    references = Column(JSON, nullable=True)
    escalation = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class CopilotEscalation(Base):
    __tablename__ = copilot_escalations
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey(copilot_sessions.id), nullable=False)
    message_id = Column(UUID(as_uuid=True), ForeignKey(copilot_messages.id), nullable=True)
    reason = Column(String(200), nullable=False)
    severity = Column(String(20), default=medium)
    status = Column(String(20), default=pending)
    assigned_to = Column(String(200), nullable=True)
    resolution = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)