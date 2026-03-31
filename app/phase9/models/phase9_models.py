
"""
APEX Phase 9 — Account Center Models
Only adds: AccountAction (new table)
Uses PasswordReset and UserSession from Phase 1.
"""
from sqlalchemy import Column, String, DateTime, Text
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

class AccountAction(Base):
    __tablename__ = "account_actions"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    action_type = Column(String, nullable=False)
    action_details = Column(Text, nullable=True)
    ip_address = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow)

def init_phase9_db():
    from app.phase1.models.platform_models import engine
    Base.metadata.create_all(bind=engine)
    return ["account_actions"]
