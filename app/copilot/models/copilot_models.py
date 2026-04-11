"""
APEX — Copilot database models (sessions, messages, escalations)
نماذج قاعدة بيانات المساعد الذكي (الجلسات، الرسائل، التصعيدات)
"""

from sqlalchemy import Column, String, Text, JSON, DateTime, ForeignKey, Float, Index
from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class CopilotSession(Base):
    __tablename__ = "copilot_sessions"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    client_id = Column(String(36), nullable=True)
    session_type = Column(String(50), default="general")
    context = Column(JSON, default=dict)
    status = Column(String(20), default="active")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)


class CopilotMessage(Base):
    __tablename__ = "copilot_messages"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    session_id = Column(String(36), ForeignKey("copilot_sessions.id"), nullable=False, index=True)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    intent = Column(String(100), nullable=True)
    tools_used = Column(JSON, nullable=True)
    confidence = Column(Float, nullable=True)
    risk_level = Column(String(20), nullable=True)
    references = Column(JSON, nullable=True)
    escalation = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=utcnow)


class CopilotEscalation(Base):
    __tablename__ = "copilot_escalations"
    id = Column(String(36), primary_key=True, default=gen_uuid)
    session_id = Column(String(36), ForeignKey("copilot_sessions.id"), nullable=False, index=True)
    message_id = Column(String(36), ForeignKey("copilot_messages.id"), nullable=True, index=True)
    reason = Column(String(200), nullable=False)
    severity = Column(String(20), default="medium")
    status = Column(String(20), default="pending")
    assigned_to = Column(String(200), nullable=True)
    resolution = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    resolved_at = Column(DateTime, nullable=True)


def init_copilot_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["copilot_sessions", "copilot_messages", "copilot_escalations"]
