"""
APEX Platform — Knowledge Feedback Service
═══════════════════════════════════════════════════════════════
Submit, review, promote feedback to rules.
Per execution document section 10.
"""

import logging
from typing import Optional
from app.phase1.models.platform_models import (
    AuditEvent,
    Notification,
    SessionLocal,
    gen_uuid,
)
from app.phase2.models.phase2_models import Client
from app.phase3.models.phase3_models import (
    KnowledgeFeedbackEvent,
    KnowledgeFeedbackReview,
    KnowledgeCandidateRule,
    FeedbackStatus,
)


class KnowledgeFeedbackService:

    def submit_feedback(
        self,
        user_id: str,
        feedback_type: str,
        title: str,
        description: str,
        client_id: Optional[str] = None,
        result_id: Optional[str] = None,
        target_metric_key: Optional[str] = None,
        target_account_name: Optional[str] = None,
        suggested_correction: Optional[str] = None,
        suggested_classification: Optional[str] = None,
        reference_standard: Optional[str] = None,
        applicability_scope: str = "global",
        priority: str = "normal",
    ) -> dict:
        """Submit knowledge feedback — gated by client type."""
        db = SessionLocal()
        try:
            # Check knowledge mode eligibility
            if client_id:
                client = db.query(Client).filter(Client.id == client_id).first()
                if client and not client.knowledge_mode:
                    return {"success": False, "error": "وضع المعرفة غير مفعّل لهذا العميل. متاح فقط للجهات المؤهلة."}

            feedback = KnowledgeFeedbackEvent(
                id=gen_uuid(),
                user_id=user_id,
                client_id=client_id,
                result_id=result_id,
                feedback_type=feedback_type,
                target_metric_key=target_metric_key,
                target_account_name=target_account_name,
                title=title.strip(),
                description=description.strip(),
                suggested_correction=suggested_correction,
                suggested_classification=suggested_classification,
                reference_standard=reference_standard,
                applicability_scope=applicability_scope,
                priority=priority,
            )
            db.add(feedback)

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="knowledge_feedback_submitted",
                    resource_type="knowledge_feedback",
                    resource_id=feedback.id,
                )
            )

            db.commit()
            return {
                "success": True,
                "feedback_id": feedback.id,
                "status": feedback.status,
                "message": "تم تقديم الملاحظة المعرفية وستخضع للمراجعة",
            }

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def list_feedback(
        self,
        user_id: Optional[str] = None,
        status: Optional[str] = None,
        client_id: Optional[str] = None,
        limit: int = 50,
    ) -> list:
        """List feedback — filterable."""
        db = SessionLocal()
        try:
            q = db.query(KnowledgeFeedbackEvent).filter(KnowledgeFeedbackEvent.is_deleted == False)
            if user_id:
                q = q.filter(KnowledgeFeedbackEvent.user_id == user_id)
            if status:
                q = q.filter(KnowledgeFeedbackEvent.status == status)
            if client_id:
                q = q.filter(KnowledgeFeedbackEvent.client_id == client_id)

            items = q.order_by(KnowledgeFeedbackEvent.created_at.desc()).limit(limit).all()
            return [
                {
                    "id": f.id,
                    "feedback_type": f.feedback_type,
                    "title": f.title,
                    "status": f.status,
                    "priority": f.priority,
                    "target_metric_key": f.target_metric_key,
                    "applicability_scope": f.applicability_scope,
                    "created_at": f.created_at.isoformat(),
                }
                for f in items
            ]
        finally:
            db.close()

    def get_review_queue(self, limit: int = 50) -> list:
        """Get pending feedback for reviewers."""
        db = SessionLocal()
        try:
            items = (
                db.query(KnowledgeFeedbackEvent)
                .filter(
                    KnowledgeFeedbackEvent.status.in_(
                        [
                            FeedbackStatus.submitted.value,
                            FeedbackStatus.under_review.value,
                        ]
                    )
                )
                .order_by(
                    KnowledgeFeedbackEvent.priority.desc(),
                    KnowledgeFeedbackEvent.created_at.asc(),
                )
                .limit(limit)
                .all()
            )

            return [
                {
                    "id": f.id,
                    "feedback_type": f.feedback_type,
                    "title": f.title,
                    "description": f.description[:200],
                    "status": f.status,
                    "priority": f.priority,
                    "suggested_correction": f.suggested_correction,
                    "reference_standard": f.reference_standard,
                    "user_id": f.user_id,
                    "created_at": f.created_at.isoformat(),
                }
                for f in items
            ]
        finally:
            db.close()

    def review_feedback(
        self,
        feedback_id: str,
        reviewer_id: str,
        decision: str,
        reviewer_notes: Optional[str] = None,
        quality_score: Optional[int] = None,
    ) -> dict:
        """Review a feedback item — accept/reject/refine/queue for rule."""
        valid_decisions = [s.value for s in FeedbackStatus if s.value != "submitted"]
        if decision not in valid_decisions:
            return {"success": False, "error": f"القرار غير صالح. المتاح: {', '.join(valid_decisions)}"}

        db = SessionLocal()
        try:
            feedback = db.query(KnowledgeFeedbackEvent).filter(KnowledgeFeedbackEvent.id == feedback_id).first()
            if not feedback:
                return {"success": False, "error": "الملاحظة غير موجودة"}

            # Update status
            feedback.status = decision

            # Create review record
            db.add(
                KnowledgeFeedbackReview(
                    id=gen_uuid(),
                    feedback_id=feedback_id,
                    reviewer_id=reviewer_id,
                    decision=decision,
                    reviewer_notes=reviewer_notes,
                    quality_score=quality_score,
                )
            )

            # Notify submitter
            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=feedback.user_id,
                    title_ar=f"تم مراجعة ملاحظتك: {self._decision_ar(decision)}",
                    title_en=f"Feedback reviewed: {decision}",
                    category="knowledge",
                    source_type="feedback_review",
                    source_id=feedback_id,
                )
            )

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=reviewer_id,
                    action="knowledge_feedback_reviewed",
                    resource_type="knowledge_feedback",
                    resource_id=feedback_id,
                    details={"decision": decision, "quality_score": quality_score},
                )
            )

            db.commit()
            return {"success": True, "feedback_id": feedback_id, "new_status": decision}

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def promote_to_candidate_rule(
        self,
        feedback_id: str,
        creator_id: str,
        rule_type: str,
        rule_code: str,
        name_ar: str,
        condition: dict,
        action: dict,
        priority: int = 50,
    ) -> dict:
        """Promote accepted feedback to a candidate rule."""
        db = SessionLocal()
        try:
            feedback = (
                db.query(KnowledgeFeedbackEvent)
                .filter(
                    KnowledgeFeedbackEvent.id == feedback_id,
                    KnowledgeFeedbackEvent.status.in_(
                        [
                            FeedbackStatus.accepted.value,
                            FeedbackStatus.queued_for_rule_design.value,
                        ]
                    ),
                )
                .first()
            )
            if not feedback:
                return {"success": False, "error": "الملاحظة غير موجودة أو لم يتم قبولها"}

            rule = KnowledgeCandidateRule(
                id=gen_uuid(),
                source_feedback_id=feedback_id,
                created_by=creator_id,
                rule_type=rule_type,
                rule_code=rule_code,
                name_ar=name_ar,
                condition=condition,
                action=action,
                priority=priority,
                applicability_scope=feedback.applicability_scope,
                scope_sector=feedback.scope_sector,
            )
            db.add(rule)
            db.commit()

            return {"success": True, "rule_id": rule.id, "rule_code": rule_code, "status": "candidate"}

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def list_candidate_rules(self, status: Optional[str] = None) -> list:
        """List candidate rules."""
        db = SessionLocal()
        try:
            q = db.query(KnowledgeCandidateRule)
            if status:
                q = q.filter(KnowledgeCandidateRule.status == status)
            rules = q.order_by(KnowledgeCandidateRule.created_at.desc()).all()
            return [
                {
                    "id": r.id,
                    "rule_code": r.rule_code,
                    "rule_type": r.rule_type,
                    "name_ar": r.name_ar,
                    "status": r.status,
                    "condition": r.condition,
                    "action": r.action,
                    "priority": r.priority,
                    "created_at": r.created_at.isoformat(),
                }
                for r in rules
            ]
        finally:
            db.close()

    @staticmethod
    def _decision_ar(decision: str) -> str:
        return {
            "accepted": "مقبولة",
            "rejected": "مرفوضة",
            "needs_refinement": "تحتاج تحسين",
            "under_review": "قيد المراجعة",
            "queued_for_rule_design": "في قائمة تصميم القواعد",
        }.get(decision, decision)
