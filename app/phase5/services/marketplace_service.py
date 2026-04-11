"""
APEX Platform — Marketplace Service
═══════════════════════════════════════════════════════════════
Service requests, task lifecycle, compliance, suspension engine.
Per execution document sections 8, 11, 12.
"""

import logging
from typing import Optional
from datetime import datetime, timedelta, timezone
from app.phase1.models.platform_models import (
    User,
    AuditEvent,
    Notification,
    SessionLocal,
    gen_uuid,
    utcnow,
)
from app.phase4.models.phase4_models import ServiceProvider, VerificationStatus
from app.phase5.models.phase5_models import (
    ServiceRequest,
    ServiceRequestMessage,
    TaskComplianceEvent,
    ComplianceAction,
    SuspensionEvent,
    SuspensionAppeal,
    RequestStatus,
    TaskComplianceStatus,
    SuspensionReason,
    AppealStatus,
)


class MarketplaceService:

    # ─── Service Requests ────────────────────────────────────

    def create_request(
        self,
        client_id: str,
        user_id: str,
        title: str,
        description: str,
        scope_code: Optional[str] = None,
        category_required: Optional[str] = None,
        urgency: str = "normal",
        budget_sar: Optional[float] = None,
        deadline_days: Optional[int] = None,
    ) -> dict:
        db = SessionLocal()
        try:
            deadline = None
            if deadline_days:
                deadline = datetime.now(timezone.utc) + timedelta(days=deadline_days)

            req = ServiceRequest(
                id=gen_uuid(),
                client_id=client_id,
                requested_by=user_id,
                title=title.strip(),
                description=description.strip(),
                scope_code=scope_code,
                category_required=category_required,
                urgency=urgency,
                budget_sar=budget_sar,
                deadline=deadline,
            )
            db.add(req)
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="service_request_created",
                    resource_type="service_request",
                    resource_id=req.id,
                )
            )
            db.commit()
            return {
                "success": True,
                "request_id": req.id,
                "status": req.status,
                "deadline": deadline.isoformat() if deadline else None,
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def assign_provider(self, request_id: str, provider_id: str, agreed_price: float, assigned_by: str) -> dict:
        db = SessionLocal()
        try:
            req = db.query(ServiceRequest).filter(ServiceRequest.id == request_id).first()
            if not req:
                return {"success": False, "error": "الطلب غير موجود"}
            if req.status != RequestStatus.open.value:
                return {"success": False, "error": f"لا يمكن التعيين — الحالة: {req.status}"}

            provider = db.query(ServiceProvider).filter(ServiceProvider.id == provider_id).first()
            if not provider:
                return {"success": False, "error": "مقدم الخدمة غير موجود"}
            if provider.verification_status != VerificationStatus.approved.value:
                return {"success": False, "error": "مقدم الخدمة غير معتمد"}

            commission = agreed_price * (provider.commission_rate / 100)
            req.provider_id = provider_id
            req.agreed_price_sar = agreed_price
            req.platform_commission = commission
            req.provider_payout = agreed_price - commission
            req.status = RequestStatus.matched.value
            req.accepted_at = utcnow()

            provider.active_tasks_count += 1

            db.add(
                ServiceRequestMessage(
                    id=gen_uuid(),
                    request_id=request_id,
                    sender_id=assigned_by,
                    message=f"تم تعيين مقدم الخدمة — المبلغ المتفق: {agreed_price} ر.س",
                    is_system=True,
                )
            )

            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=provider.user_id,
                    title_ar=f"تم تعيينك لطلب خدمة جديد: {req.title}",
                    title_en=f"Assigned to: {req.title}",
                    category="marketplace",
                    source_id=request_id,
                )
            )

            db.commit()
            return {
                "success": True,
                "request_id": request_id,
                "status": "matched",
                "agreed_price": agreed_price,
                "commission": commission,
                "payout": agreed_price - commission,
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def update_status(self, request_id: str, new_status: str, user_id: str, message: Optional[str] = None) -> dict:
        valid = [s.value for s in RequestStatus]
        if new_status not in valid:
            return {"success": False, "error": f"الحالة غير صالحة. المتاح: {', '.join(valid)}"}

        db = SessionLocal()
        try:
            req = db.query(ServiceRequest).filter(ServiceRequest.id == request_id).first()
            if not req:
                return {"success": False, "error": "الطلب غير موجود"}

            old_status = req.status
            req.status = new_status

            if new_status == "in_progress" and not req.accepted_at:
                req.accepted_at = utcnow()
            elif new_status == "delivered":
                req.delivered_at = utcnow()
            elif new_status == "completed":
                req.completed_at = utcnow()
                if req.provider_id:
                    provider = db.query(ServiceProvider).filter(ServiceProvider.id == req.provider_id).first()
                    if provider:
                        provider.active_tasks_count = max(0, provider.active_tasks_count - 1)
                        provider.completed_tasks_count += 1
            elif new_status == "cancelled":
                req.cancelled_at = utcnow()

            if message:
                db.add(
                    ServiceRequestMessage(
                        id=gen_uuid(), request_id=request_id, sender_id=user_id, message=message, is_system=False
                    )
                )

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="request_status_changed",
                    resource_type="service_request",
                    resource_id=request_id,
                    details={"from": old_status, "to": new_status},
                )
            )
            db.commit()
            return {"success": True, "request_id": request_id, "old_status": old_status, "new_status": new_status}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def rate_request(
        self, request_id: str, user_id: str, rating: int, review: Optional[str] = None, is_client: bool = True
    ) -> dict:
        if rating < 1 or rating > 5:
            return {"success": False, "error": "التقييم يجب أن يكون بين 1 و 5"}
        db = SessionLocal()
        try:
            req = db.query(ServiceRequest).filter(ServiceRequest.id == request_id).first()
            if not req:
                return {"success": False, "error": "الطلب غير موجود"}
            if req.status != RequestStatus.completed.value:
                return {"success": False, "error": "لا يمكن التقييم إلا بعد الاكتمال"}

            if is_client:
                req.client_rating = rating
                req.client_review = review
                if req.provider_id:
                    self._update_provider_rating(db, req.provider_id)
            else:
                req.provider_rating = rating
                req.provider_review = review
            db.commit()
            return {"success": True, "rating": rating}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def list_requests(
        self,
        client_id: Optional[str] = None,
        provider_id: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> list:
        db = SessionLocal()
        try:
            q = db.query(ServiceRequest)
            if client_id:
                q = q.filter(ServiceRequest.client_id == client_id)
            if provider_id:
                q = q.filter(ServiceRequest.provider_id == provider_id)
            if status:
                q = q.filter(ServiceRequest.status == status)
            reqs = q.order_by(ServiceRequest.created_at.desc()).limit(limit).all()
            return [
                {
                    "id": r.id,
                    "title": r.title,
                    "status": r.status,
                    "urgency": r.urgency,
                    "budget": r.budget_sar,
                    "agreed_price": r.agreed_price_sar,
                    "deadline": r.deadline.isoformat() if r.deadline else None,
                    "created_at": r.created_at.isoformat(),
                }
                for r in reqs
            ]
        finally:
            db.close()

    def get_request_detail(self, request_id: str) -> dict:
        db = SessionLocal()
        try:
            r = db.query(ServiceRequest).filter(ServiceRequest.id == request_id).first()
            if not r:
                return {"success": False, "error": "غير موجود"}
            msgs = (
                db.query(ServiceRequestMessage)
                .filter(ServiceRequestMessage.request_id == request_id)
                .order_by(ServiceRequestMessage.created_at)
                .all()
            )
            return {
                "success": True,
                "request": {
                    "id": r.id,
                    "title": r.title,
                    "description": r.description,
                    "status": r.status,
                    "urgency": r.urgency,
                    "scope": r.scope_code,
                    "budget": r.budget_sar,
                    "agreed_price": r.agreed_price_sar,
                    "commission": r.platform_commission,
                    "payout": r.provider_payout,
                    "deadline": r.deadline.isoformat() if r.deadline else None,
                    "client_rating": r.client_rating,
                    "provider_rating": r.provider_rating,
                    "created_at": r.created_at.isoformat(),
                },
                "messages": [
                    {"sender": m.sender_id, "message": m.message, "system": m.is_system, "at": m.created_at.isoformat()}
                    for m in msgs
                ],
            }
        finally:
            db.close()

    # ─── Compliance ──────────────────────────────────────────

    def check_compliance(self, request_id: str) -> dict:
        db = SessionLocal()
        try:
            req = db.query(ServiceRequest).filter(ServiceRequest.id == request_id).first()
            if not req:
                return {"success": False, "error": "غير موجود"}
            if not req.deadline or not req.provider_id:
                return {"success": True, "status": "no_deadline"}

            now = datetime.now(timezone.utc)
            if req.status in ("completed", "cancelled"):
                return {"success": True, "status": "resolved"}

            days_overdue = (now - req.deadline).days if now > req.deadline else 0
            if days_overdue > 0:
                status = TaskComplianceStatus.overdue.value
                if days_overdue > 7:
                    status = TaskComplianceStatus.escalated.value
            elif (req.deadline - now).days <= 2:
                status = TaskComplianceStatus.warning.value
            else:
                status = TaskComplianceStatus.on_track.value

            event = TaskComplianceEvent(
                id=gen_uuid(),
                request_id=request_id,
                provider_id=req.provider_id,
                status=status,
                days_overdue=days_overdue,
            )
            db.add(event)

            if status == TaskComplianceStatus.escalated.value:
                db.add(
                    ComplianceAction(
                        id=gen_uuid(),
                        compliance_event_id=event.id,
                        action_type="escalated",
                        notes=f"متأخر {days_overdue} أيام — تصعيد تلقائي",
                    )
                )

            db.commit()
            return {"success": True, "status": status, "days_overdue": days_overdue}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    # ─── Suspension Engine ───────────────────────────────────

    def suspend(
        self,
        target_type: str,
        target_id: str,
        reason: str,
        reason_details: Optional[str] = None,
        suspended_by: Optional[str] = None,
        duration_days: Optional[int] = None,
    ) -> dict:
        db = SessionLocal()
        try:
            expires = None
            if duration_days:
                expires = datetime.now(timezone.utc) + timedelta(days=duration_days)

            event = SuspensionEvent(
                id=gen_uuid(),
                target_type=target_type,
                target_id=target_id,
                suspension_type=f"{target_type}_suspension",
                reason=reason,
                reason_details=reason_details,
                suspended_by=suspended_by,
                expires_at=expires,
            )
            db.add(event)

            if target_type == "provider":
                provider = db.query(ServiceProvider).filter(ServiceProvider.id == target_id).first()
                if provider:
                    provider.compliance_status = "suspended"
                    provider.verification_status = "suspended"

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=suspended_by or "system",
                    action="suspension_created",
                    resource_type=target_type,
                    resource_id=target_id,
                    details={"reason": reason},
                )
            )
            db.commit()
            return {
                "success": True,
                "suspension_id": event.id,
                "expires": expires.isoformat() if expires else "permanent",
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def lift_suspension(self, suspension_id: str, lifted_by: str) -> dict:
        db = SessionLocal()
        try:
            event = db.query(SuspensionEvent).filter(SuspensionEvent.id == suspension_id).first()
            if not event:
                return {"success": False, "error": "غير موجود"}
            event.is_active = False
            event.lifted_at = utcnow()
            event.lifted_by = lifted_by

            if event.target_type == "provider":
                provider = db.query(ServiceProvider).filter(ServiceProvider.id == event.target_id).first()
                if provider:
                    provider.compliance_status = "clear"
                    provider.verification_status = "approved"

            db.commit()
            return {"success": True, "message": "تم رفع الإيقاف"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def submit_appeal(self, suspension_id: str, user_id: str, appeal_text: str) -> dict:
        db = SessionLocal()
        try:
            event = (
                db.query(SuspensionEvent)
                .filter(SuspensionEvent.id == suspension_id, SuspensionEvent.is_active == True)
                .first()
            )
            if not event:
                return {"success": False, "error": "الإيقاف غير موجود أو مرفوع"}

            appeal = SuspensionAppeal(
                id=gen_uuid(), suspension_id=suspension_id, appealed_by=user_id, appeal_text=appeal_text.strip()
            )
            db.add(appeal)
            db.commit()
            return {"success": True, "appeal_id": appeal.id, "status": "submitted"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def list_suspensions(self, active_only: bool = True) -> list:
        db = SessionLocal()
        try:
            q = db.query(SuspensionEvent)
            if active_only:
                q = q.filter(SuspensionEvent.is_active == True)
            events = q.order_by(SuspensionEvent.started_at.desc()).all()
            return [
                {
                    "id": e.id,
                    "target_type": e.target_type,
                    "target_id": e.target_id,
                    "reason": e.reason,
                    "is_active": e.is_active,
                    "started_at": e.started_at.isoformat(),
                    "expires_at": e.expires_at.isoformat() if e.expires_at else None,
                }
                for e in events
            ]
        finally:
            db.close()

    # ─── Helpers ─────────────────────────────────────────────
    def _update_provider_rating(self, db, provider_id: str):
        from sqlalchemy import func

        result = (
            db.query(func.avg(ServiceRequest.client_rating), func.count(ServiceRequest.client_rating))
            .filter(ServiceRequest.provider_id == provider_id, ServiceRequest.client_rating.isnot(None))
            .first()
        )
        if result and result[0]:
            provider = db.query(ServiceProvider).filter(ServiceProvider.id == provider_id).first()
            if provider:
                provider.rating_average = round(float(result[0]), 2)
                provider.rating_count = result[1]
