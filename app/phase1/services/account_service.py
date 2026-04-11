"""
APEX Platform — Account Service
═══════════════════════════════════════════════════════════════
Profile, Security, Notifications, Account Closure.
Per execution document Section 9.
"""

from typing import Optional
import logging
from app.phase1.models.platform_models import (
    User,
    UserProfile,
    UserSecurityEvent,
    Notification,
    AccountClosureRequest,
    AuditEvent,
    UserSession,
    UserStatus,
    ClosureType,
    ClosureStatus,
    SessionLocal,
    gen_uuid,
    utcnow,
)


class AccountService:

    # ─── Profile ─────────────────────────────────────────────

    def get_profile(self, user_id: str) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}

            profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()

            return {
                "success": True,
                "user": {
                    "id": user.id,
                    "username": user.username,
                    "email": user.email,
                    "mobile": user.mobile,
                    "display_name": user.display_name,
                    "status": user.status,
                    "language": user.language,
                    "timezone": user.timezone,
                    "email_verified": user.email_verified,
                    "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
                    "created_at": user.created_at.isoformat(),
                },
                "profile": (
                    {
                        "bio": profile.bio if profile else None,
                        "organization_name": profile.organization_name if profile else None,
                        "job_title": profile.job_title if profile else None,
                        "city": profile.city if profile else None,
                        "country": profile.country if profile else "SA",
                        "notification_email": profile.notification_email if profile else True,
                        "notification_sms": profile.notification_sms if profile else False,
                        "notification_in_app": profile.notification_in_app if profile else True,
                    }
                    if profile
                    else {}
                ),
            }
        finally:
            db.close()

    def update_profile(self, user_id: str, updates: dict) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}

            # User-level fields
            user_fields = {"display_name", "language", "timezone", "mobile"}
            for field in user_fields:
                if field in updates and updates[field] is not None:
                    setattr(user, field, updates[field])

            # Profile-level fields
            profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not profile:
                profile = UserProfile(id=gen_uuid(), user_id=user_id)
                db.add(profile)

            profile_fields = {
                "bio",
                "organization_name",
                "job_title",
                "city",
                "country",
                "notification_email",
                "notification_sms",
                "notification_in_app",
            }
            for field in profile_fields:
                if field in updates and updates[field] is not None:
                    setattr(profile, field, updates[field])

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="profile_update",
                    resource_type="user_profile",
                    details={"updated_fields": list(updates.keys())},
                )
            )

            db.commit()
            return {"success": True, "message": "تم تحديث الملف الشخصي"}

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    # ─── Security ────────────────────────────────────────────

    def get_security_info(self, user_id: str) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}

            events = (
                db.query(UserSecurityEvent)
                .filter(UserSecurityEvent.user_id == user_id)
                .order_by(UserSecurityEvent.created_at.desc())
                .limit(20)
                .all()
            )

            sessions = db.query(UserSession).filter(UserSession.user_id == user_id, UserSession.is_active == True).all()

            return {
                "success": True,
                "active_sessions": len(sessions),
                "last_login": user.last_login_at.isoformat() if user.last_login_at else None,
                "login_count": user.login_count,
                "recent_events": [
                    {
                        "type": e.event_type,
                        "ip": e.ip_address,
                        "at": e.created_at.isoformat(),
                    }
                    for e in events
                ],
            }
        finally:
            db.close()

    # ─── Notifications ───────────────────────────────────────

    def get_notifications(self, user_id: str, unread_only: bool = False, limit: int = 50) -> dict:
        db = SessionLocal()
        try:
            q = db.query(Notification).filter(Notification.user_id == user_id)
            if unread_only:
                q = q.filter(Notification.is_read == False)
            notifs = q.order_by(Notification.created_at.desc()).limit(limit).all()

            unread_count = (
                db.query(Notification).filter(Notification.user_id == user_id, Notification.is_read == False).count()
            )

            return {
                "success": True,
                "unread_count": unread_count,
                "notifications": [
                    {
                        "id": n.id,
                        "title_ar": n.title_ar,
                        "title_en": n.title_en,
                        "body_ar": n.body_ar,
                        "category": n.category,
                        "is_read": n.is_read,
                        "created_at": n.created_at.isoformat(),
                    }
                    for n in notifs
                ],
            }
        finally:
            db.close()

    def mark_notification_read(self, user_id: str, notification_id: str) -> dict:
        db = SessionLocal()
        try:
            n = (
                db.query(Notification)
                .filter(Notification.id == notification_id, Notification.user_id == user_id)
                .first()
            )
            if n:
                n.is_read = True
                n.read_at = utcnow()
                db.commit()
            return {"success": True}
        finally:
            db.close()

    def mark_all_read(self, user_id: str) -> dict:
        db = SessionLocal()
        try:
            count = (
                db.query(Notification)
                .filter(Notification.user_id == user_id, Notification.is_read == False)
                .update({"is_read": True, "read_at": utcnow()})
            )
            db.commit()
            return {"success": True, "marked": count}
        finally:
            db.close()

    # ─── Account Closure ─────────────────────────────────────

    def request_closure(self, user_id: str, closure_type: str, reason: Optional[str] = None) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}

            # Check for existing pending request
            existing = (
                db.query(AccountClosureRequest)
                .filter(
                    AccountClosureRequest.user_id == user_id,
                    AccountClosureRequest.status == ClosureStatus.requested.value,
                )
                .first()
            )
            if existing:
                return {"success": False, "error": "يوجد طلب إغلاق معلّق بالفعل"}

            req = AccountClosureRequest(
                id=gen_uuid(),
                user_id=user_id,
                closure_type=closure_type,
                reason=reason,
            )
            db.add(req)

            if closure_type == ClosureType.temporary.value:
                user.status = UserStatus.deactivated_temp.value
                req.status = ClosureStatus.completed.value
                req.processed_at = utcnow()

                # Revoke all sessions
                db.query(UserSession).filter(UserSession.user_id == user_id, UserSession.is_active == True).update(
                    {"is_active": False}
                )

            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=user_id,
                    title_ar="تم استلام طلب إغلاق الحساب",
                    title_en="Account closure request received",
                    category="auth",
                    source_type="account_closure",
                )
            )

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="account_closure_request",
                    details={"type": closure_type, "reason": reason},
                )
            )

            db.commit()

            return {
                "success": True,
                "message": "تم تقديم طلب إغلاق الحساب" if closure_type == "permanent" else "تم تعطيل الحساب مؤقتاً",
                "closure_type": closure_type,
                "status": req.status,
            }

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def reactivate_account(self, user_id: str) -> dict:
        """Reactivate temporarily deactivated account."""
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}

            if user.status != UserStatus.deactivated_temp.value:
                return {"success": False, "error": "الحساب ليس معطّلاً مؤقتاً"}

            user.status = UserStatus.active.value

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="account_reactivation",
                )
            )

            db.commit()
            return {"success": True, "message": "تم إعادة تفعيل الحساب"}

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()
