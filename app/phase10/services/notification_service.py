"""
APEX Phase 10 — Notification Engine Service
Handles: emit, list, mark-read, count, preferences
"""
import logging
from datetime import datetime
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase10.models.phase10_models import (
    NotificationV2, NotificationPreference, NotificationDeliveryLog,
    NOTIFICATION_TYPES
)

# Arabic titles for each notification type
TYPE_TITLES = {
    "registration": "مرحباً بك في أبكس",
    "verification": "تم التحقق من حسابك",
    "plan_upgrade": "تمت ترقية خطتك",
    "plan_expiry_warning": "اشتراكك يقترب من الانتهاء",
    "task_assigned": "تم إسناد مهمة جديدة لك",
    "documents_missing": "مستندات مطلوبة ناقصة",
    "deadline_approaching": "موعد التسليم يقترب",
    "account_suspended": "تم تعليق حسابك",
    "account_unsuspended": "تم رفع التعليق عن حسابك",
    "feedback_accepted": "تم قبول ملاحظتك",
    "feedback_rejected": "تم رفض ملاحظتك",
    "terms_changed": "تم تحديث الشروط والأحكام",
    "closure_requested": "تم استلام طلب إغلاق الحساب",
}

TYPE_ICONS = {
    "registration": "person_add",
    "verification": "verified",
    "plan_upgrade": "upgrade",
    "plan_expiry_warning": "timer",
    "task_assigned": "assignment",
    "documents_missing": "folder_off",
    "deadline_approaching": "alarm",
    "account_suspended": "block",
    "account_unsuspended": "check_circle",
    "feedback_accepted": "thumb_up",
    "feedback_rejected": "thumb_down",
    "terms_changed": "policy",
    "closure_requested": "delete_outline",
}

def emit_notification(user_id, notification_type, body_ar=None, body_en=None,
                      reference_id=None, reference_type=None, action_url=None):
    """Create and deliver a notification."""
    if notification_type not in NOTIFICATION_TYPES:
        return {"status": "error", "detail": f"Unknown type: {notification_type}"}

    db = SessionLocal()
    try:
        notif = NotificationV2(
            id=gen_uuid(),
            user_id=user_id,
            notification_type=notification_type,
            title_ar=TYPE_TITLES.get(notification_type, notification_type),
            title_en=notification_type.replace("_", " ").title(),
            body_ar=body_ar,
            body_en=body_en,
            icon=TYPE_ICONS.get(notification_type, "notifications"),
            action_url=action_url,
            reference_id=reference_id,
            reference_type=reference_type,
        )
        db.add(notif)

        # Log in_app delivery
        log = NotificationDeliveryLog(
            id=gen_uuid(),
            notification_id=notif.id,
            channel="in_app",
            status="delivered",
        )
        db.add(log)
        db.commit()

        return {"status": "ok", "notification_id": notif.id}
    except Exception as e:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"status": "error", "detail": "Internal server error"}
    finally:
        db.close()

def get_notifications(user_id, page=1, page_size=20, unread_only=False):
    """Get notifications for a user with pagination."""
    db = SessionLocal()
    try:
        query = db.query(NotificationV2).filter(NotificationV2.user_id == user_id)
        if unread_only:
            query = query.filter(NotificationV2.is_read == False)

        total = query.count()
        notifications = query.order_by(
            NotificationV2.created_at.desc()
        ).offset((page - 1) * page_size).limit(page_size).all()

        return {
            "notifications": [{
                "id": n.id,
                "type": n.notification_type,
                "title_ar": n.title_ar,
                "title_en": n.title_en,
                "body_ar": n.body_ar,
                "body_en": n.body_en,
                "icon": n.icon,
                "action_url": n.action_url,
                "is_read": n.is_read,
                "created_at": str(n.created_at) if n.created_at else None,
            } for n in notifications],
            "total": total,
            "page": page,
            "page_size": page_size,
        }
    finally:
        db.close()

def get_unread_count(user_id):
    """Get count of unread notifications."""
    db = SessionLocal()
    try:
        count = db.query(NotificationV2).filter(
            NotificationV2.user_id == user_id,
            NotificationV2.is_read == False,
        ).count()
        return count
    finally:
        db.close()

def mark_as_read(user_id, notification_id=None):
    """Mark one or all notifications as read."""
    db = SessionLocal()
    try:
        if notification_id:
            n = db.query(NotificationV2).filter(
                NotificationV2.id == notification_id,
                NotificationV2.user_id == user_id,
            ).first()
            if n:
                n.is_read = True
                n.read_at = datetime.utcnow()
                db.commit()
                return {"status": "ok", "marked": 1}
            return {"status": "error", "detail": "الإشعار غير موجود"}
        else:
            count = db.query(NotificationV2).filter(
                NotificationV2.user_id == user_id,
                NotificationV2.is_read == False,
            ).update({"is_read": True, "read_at": datetime.utcnow()})
            db.commit()
            return {"status": "ok", "marked": count}
    except Exception as e:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"status": "error", "detail": "Internal server error"}
    finally:
        db.close()

def get_preferences(user_id):
    """Get notification preferences for a user."""
    db = SessionLocal()
    try:
        prefs = db.query(NotificationPreference).filter(
            NotificationPreference.user_id == user_id
        ).all()

        # Build defaults for missing types
        existing = {p.notification_type: p for p in prefs}
        result = []
        for ntype in NOTIFICATION_TYPES:
            if ntype in existing:
                p = existing[ntype]
                result.append({
                    "type": ntype,
                    "title_ar": TYPE_TITLES.get(ntype, ntype),
                    "in_app": p.channel_in_app,
                    "email": p.channel_email,
                    "sms": p.channel_sms,
                })
            else:
                result.append({
                    "type": ntype,
                    "title_ar": TYPE_TITLES.get(ntype, ntype),
                    "in_app": True,
                    "email": True,
                    "sms": False,
                })
        return result
    finally:
        db.close()

def update_preference(user_id, notification_type, in_app=True, email=True, sms=False):
    """Update notification preference for a specific type."""
    if notification_type not in NOTIFICATION_TYPES:
        return {"status": "error", "detail": f"Unknown type: {notification_type}"}

    db = SessionLocal()
    try:
        pref = db.query(NotificationPreference).filter(
            NotificationPreference.user_id == user_id,
            NotificationPreference.notification_type == notification_type,
        ).first()

        if pref:
            pref.channel_in_app = in_app
            pref.channel_email = email
            pref.channel_sms = sms
            pref.updated_at = datetime.utcnow()
        else:
            pref = NotificationPreference(
                id=gen_uuid(),
                user_id=user_id,
                notification_type=notification_type,
                channel_in_app=in_app,
                channel_email=email,
                channel_sms=sms,
            )
            db.add(pref)

        db.commit()
        return {"status": "ok"}
    except Exception as e:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"status": "error", "detail": "Internal server error"}
    finally:
        db.close()

def seed_welcome_notification(user_id):
    """Send welcome notification on registration."""
    return emit_notification(
        user_id=user_id,
        notification_type="registration",
        body_ar="مرحباً بك في منصة أبكس للتحليل المالي الذكي. ابدأ بإنشاء عميلك الأول.",
        body_en="Welcome to APEX. Start by creating your first client.",
    )
