"""
APEX Platform — Phase 6: Admin + Reviewer Tooling
═══════════════════════════════════════════════════════════════
Admin dashboard, user management, system stats, reviewer tools.
Per execution document sections 13, 14.
"""

import logging
from typing import Optional
from app.phase1.models.platform_models import (
    User,
    UserRole,
    Role,
    UserSubscription,
    Plan,
    UserSession,
    UserSecurityEvent,
    AuditEvent,
    Notification,
    PolicyAcceptanceLog,
    SessionLocal,
    gen_uuid,
    utcnow,
)
from app.phase2.models.phase2_models import Client, COAUpload, AnalysisResult
from app.phase3.models.phase3_models import KnowledgeFeedbackEvent, KnowledgeCandidateRule
from app.phase4.models.phase4_models import ServiceProvider, ProviderDocument
from app.phase5.models.phase5_models import ServiceRequest, SuspensionEvent, TaskComplianceEvent
from sqlalchemy import func


class AdminService:

    def get_platform_stats(self) -> dict:
        """Full platform statistics for admin dashboard."""
        db = SessionLocal()
        try:
            users_total = db.query(func.count(User.id)).scalar() or 0
            users_active = db.query(func.count(User.id)).filter(User.status == "active").scalar() or 0
            clients_total = db.query(func.count(Client.id)).filter(Client.is_deleted == False).scalar() or 0
            uploads_total = db.query(func.count(COAUpload.id)).scalar() or 0
            analyses_total = db.query(func.count(AnalysisResult.id)).scalar() or 0

            providers_total = db.query(func.count(ServiceProvider.id)).scalar() or 0
            providers_approved = (
                db.query(func.count(ServiceProvider.id))
                .filter(ServiceProvider.verification_status == "approved")
                .scalar()
                or 0
            )
            providers_pending = (
                db.query(func.count(ServiceProvider.id))
                .filter(ServiceProvider.verification_status.in_(["pending", "documents_submitted"]))
                .scalar()
                or 0
            )

            requests_total = db.query(func.count(ServiceRequest.id)).scalar() or 0
            requests_open = (
                db.query(func.count(ServiceRequest.id)).filter(ServiceRequest.status == "open").scalar() or 0
            )
            requests_completed = (
                db.query(func.count(ServiceRequest.id)).filter(ServiceRequest.status == "completed").scalar() or 0
            )

            feedback_total = db.query(func.count(KnowledgeFeedbackEvent.id)).scalar() or 0
            feedback_pending = (
                db.query(func.count(KnowledgeFeedbackEvent.id))
                .filter(KnowledgeFeedbackEvent.status == "submitted")
                .scalar()
                or 0
            )
            candidate_rules = db.query(func.count(KnowledgeCandidateRule.id)).scalar() or 0

            suspensions_active = (
                db.query(func.count(SuspensionEvent.id)).filter(SuspensionEvent.is_active == True).scalar() or 0
            )

            plans_dist = {}
            for plan_code, cnt in (
                db.query(Plan.code, func.count(UserSubscription.id))
                .join(Plan)
                .filter(UserSubscription.status == "active")
                .group_by(Plan.code)
                .all()
            ):
                plans_dist[plan_code] = cnt

            return {
                "users": {"total": users_total, "active": users_active},
                "clients": {"total": clients_total},
                "uploads": {"total": uploads_total},
                "analyses": {"total": analyses_total},
                "providers": {
                    "total": providers_total,
                    "approved": providers_approved,
                    "pending_verification": providers_pending,
                },
                "marketplace": {
                    "total_requests": requests_total,
                    "open": requests_open,
                    "completed": requests_completed,
                },
                "knowledge": {
                    "feedback_total": feedback_total,
                    "pending_review": feedback_pending,
                    "candidate_rules": candidate_rules,
                },
                "suspensions": {"active": suspensions_active},
                "plan_distribution": plans_dist,
            }
        finally:
            db.close()

    def list_users(self, status: Optional[str] = None, search: Optional[str] = None, limit: int = 50) -> list:
        """List users with filters."""
        db = SessionLocal()
        try:
            q = db.query(User)
            if status:
                q = q.filter(User.status == status)
            if search:
                q = q.filter(
                    (User.username.contains(search))
                    | (User.email.contains(search))
                    | (User.display_name.contains(search))
                )
            users = q.order_by(User.created_at.desc()).limit(limit).all()

            # Pre-fetch all roles and subscriptions in bulk to avoid N+1
            user_ids = [u.id for u in users]
            role_rows = (
                db.query(UserRole.user_id, Role.code)
                .join(Role, Role.id == UserRole.role_id)
                .filter(UserRole.user_id.in_(user_ids))
                .all()
                if user_ids
                else []
            )
            roles_map = {}
            for uid, rcode in role_rows:
                roles_map.setdefault(uid, []).append(rcode)

            sub_rows = (
                db.query(UserSubscription)
                .filter(UserSubscription.user_id.in_(user_ids), UserSubscription.status == "active")
                .all()
                if user_ids
                else []
            )
            subs_map = {s.user_id: s.plan_id for s in sub_rows}

            result = []
            for u in users:
                result.append(
                    {
                        "id": u.id,
                        "username": u.username,
                        "email": u.email,
                        "display_name": u.display_name,
                        "status": u.status,
                        "roles": roles_map.get(u.id, []),
                        "plan": subs_map.get(u.id),
                        "created_at": u.created_at.isoformat(),
                    }
                )
            return result
        finally:
            db.close()

    def update_user_status(self, user_id: str, new_status: str, admin_id: str) -> dict:
        """Activate, suspend, or deactivate user."""
        valid = ["active", "suspended", "deactivated"]
        if new_status not in valid:
            return {"success": False, "error": f"الحالة غير صالحة. المتاح: {', '.join(valid)}"}
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "المستخدم غير موجود"}
            old = user.status
            user.status = new_status
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=admin_id,
                    action="user_status_changed",
                    resource_type="user",
                    resource_id=user_id,
                    details={"from": old, "to": new_status},
                )
            )
            db.commit()
            return {"success": True, "user_id": user_id, "old_status": old, "new_status": new_status}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def assign_role(self, user_id: str, role_code: str, admin_id: str) -> dict:
        """Assign role to user."""
        db = SessionLocal()
        try:
            role = db.query(Role).filter(Role.code == role_code).first()
            if not role:
                return {"success": False, "error": f"الدور '{role_code}' غير موجود"}
            existing = db.query(UserRole).filter(UserRole.user_id == user_id, UserRole.role_id == role.id).first()
            if existing:
                return {"success": False, "error": "الدور مُعيّن بالفعل"}
            db.add(UserRole(id=gen_uuid(), user_id=user_id, role_id=role.id, assigned_by=admin_id))
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=admin_id,
                    action="role_assigned",
                    resource_type="user",
                    resource_id=user_id,
                    details={"role": role_code},
                )
            )
            db.commit()
            return {"success": True, "message": f"تم تعيين الدور: {role_code}"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def remove_role(self, user_id: str, role_code: str, admin_id: str) -> dict:
        db = SessionLocal()
        try:
            role = db.query(Role).filter(Role.code == role_code).first()
            if not role:
                return {"success": False, "error": "الدور غير موجود"}
            ur = db.query(UserRole).filter(UserRole.user_id == user_id, UserRole.role_id == role.id).first()
            if not ur:
                return {"success": False, "error": "الدور غير مُعيّن"}
            db.delete(ur)
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=admin_id,
                    action="role_removed",
                    resource_type="user",
                    resource_id=user_id,
                    details={"role": role_code},
                )
            )
            db.commit()
            return {"success": True, "message": f"تم إزالة الدور: {role_code}"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def get_audit_log(self, user_id: Optional[str] = None, action: Optional[str] = None, limit: int = 100) -> list:
        """Get audit trail."""
        db = SessionLocal()
        try:
            q = db.query(AuditEvent)
            if user_id:
                q = q.filter(AuditEvent.user_id == user_id)
            if action:
                q = q.filter(AuditEvent.action == action)
            events = q.order_by(AuditEvent.created_at.desc()).limit(limit).all()
            return [
                {
                    "id": e.id,
                    "user_id": e.user_id,
                    "action": e.action,
                    "resource_type": e.resource_type,
                    "resource_id": e.resource_id,
                    "details": e.details,
                    "at": e.created_at.isoformat(),
                }
                for e in events
            ]
        finally:
            db.close()

    def get_notification_stats(self) -> dict:
        db = SessionLocal()
        try:
            total = db.query(func.count(Notification.id)).scalar() or 0
            unread = db.query(func.count(Notification.id)).filter(Notification.is_read == False).scalar() or 0
            return {"total": total, "unread": unread}
        finally:
            db.close()
