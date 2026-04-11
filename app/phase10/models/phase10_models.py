"""
APEX Phase 10 — Notification System Models
Tables: notifications_v2, notification_preferences, notification_delivery_logs
13 notification types per Zero Ambiguity §13
"""

from sqlalchemy import Column, String, DateTime, Boolean, Text
from app.phase1.models.platform_models import Base, gen_uuid, utcnow

# 13 notification types from Zero Ambiguity §13
NOTIFICATION_TYPES = [
    "registration",  # تسجيل جديد
    "verification",  # تحقق الحساب
    "plan_upgrade",  # ترقية الخطة
    "plan_expiry_warning",  # قرب انتهاء الاشتراك
    "task_assigned",  # إسناد مهمة
    "documents_missing",  # نقص مستندات
    "deadline_approaching",  # اقتراب deadline
    "account_suspended",  # تعليق الحساب
    "account_unsuspended",  # رفع التعليق
    "feedback_accepted",  # قبول feedback
    "feedback_rejected",  # رفض feedback
    "terms_changed",  # تغير الشروط
    "closure_requested",  # طلب إغلاق الحساب
]

NOTIFICATION_CHANNELS = ["in_app", "email", "sms"]


class NotificationV2(Base):
    """User notifications — supports 13 types."""

    __tablename__ = "notifications_v2"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    notification_type = Column(String(50), nullable=False, index=True)
    title_ar = Column(String(255), nullable=False)
    title_en = Column(String(255), nullable=True)
    body_ar = Column(Text, nullable=True)
    body_en = Column(Text, nullable=True)
    icon = Column(String(50), nullable=True)
    action_url = Column(String(500), nullable=True)
    reference_id = Column(String, nullable=True)  # related entity id
    reference_type = Column(String(50), nullable=True)  # task, subscription, etc.
    is_read = Column(Boolean, default=False, index=True)
    read_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow)


class NotificationPreference(Base):
    """Per-user notification channel preferences."""

    __tablename__ = "notification_preferences"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, nullable=False, index=True)
    notification_type = Column(String(50), nullable=False)
    channel_in_app = Column(Boolean, default=True)
    channel_email = Column(Boolean, default=True)
    channel_sms = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow)


class NotificationDeliveryLog(Base):
    """Track delivery attempts for each notification."""

    __tablename__ = "notification_delivery_logs"
    __table_args__ = {"extend_existing": True}
    id = Column(String, primary_key=True, default=gen_uuid)
    notification_id = Column(String, nullable=False, index=True)
    channel = Column(String(20), nullable=False)  # in_app, email, sms
    status = Column(String(20), nullable=False, default="delivered")  # delivered, failed, pending
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow)


def init_phase10_db():
    from app.phase1.models.platform_models import engine

    Base.metadata.create_all(bind=engine)
    return ["notifications_v2", "notification_preferences", "notification_delivery_logs"]
