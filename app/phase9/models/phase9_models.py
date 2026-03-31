"""
APEX Phase 9 — Account Center Models
Tables: password_resets, user_sessions, account_actions
"""
from sqlalchemy import Column, String, DateTime, Boolean, Text, Integer
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

class PasswordReset(Base):
    """Track password reset requests with expiry tokens."""
    __tablename__ = "password_resets"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    reset_token = Column(String, nullable=False, unique=True, index=True)
    email = Column(String, nullable=False)
    is_used = Column(Boolean, default=False)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)

class UserSession(Base):
    """Track active login sessions per user."""
    __tablename__ = "user_sessions_v2"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    session_token = Column(String, nullable=False, index=True)
    device_info = Column(String, nullable=True)
    ip_address = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    last_activity = Column(DateTime, default=utcnow)
    created_at = Column(DateTime, default=utcnow)
    ended_at = Column(DateTime, nullable=True)

class AccountAction(Base):
    """Audit log for account-level actions."""
    __tablename__ = "account_actions"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    action_type = Column(String, nullable=False)  # password_change, profile_update, closure_request, session_logout, etc.
    action_details = Column(Text, nullable=True)
    ip_address = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

def init_phase9_db():
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    return ["password_resets", "user_sessions_v2", "account_actions"]
