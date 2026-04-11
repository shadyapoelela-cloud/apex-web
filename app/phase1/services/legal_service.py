"""
APEX Platform — Legal Service
═══════════════════════════════════════════════════════════════
Policy versioning, acceptance logging, mandatory acceptance check.
Per execution document section 15.
"""

import logging
from typing import Optional
from app.phase1.models.platform_models import (
    PolicyDocument,
    PolicyAcceptanceLog,
    PolicyType,
    SessionLocal,
    gen_uuid,
    utcnow,
)


class LegalService:

    def get_current_policies(self) -> list:
        """Get all current (latest version) policies."""
        db = SessionLocal()
        try:
            policies = (
                db.query(PolicyDocument)
                .filter(PolicyDocument.is_current == True)
                .order_by(PolicyDocument.policy_type)
                .all()
            )
            return [
                {
                    "id": p.id,
                    "type": p.policy_type,
                    "version": p.version,
                    "title_ar": p.title_ar,
                    "title_en": p.title_en,
                    "content_ar": p.content_ar,
                    "effective_from": p.effective_from.isoformat() if p.effective_from else None,
                }
                for p in policies
            ]
        finally:
            db.close()

    def get_policy(self, policy_type: str, version: Optional[str] = None) -> dict:
        """Get specific policy by type and optionally version."""
        db = SessionLocal()
        try:
            q = db.query(PolicyDocument).filter(PolicyDocument.policy_type == policy_type)
            if version:
                q = q.filter(PolicyDocument.version == version)
            else:
                q = q.filter(PolicyDocument.is_current == True)
            policy = q.first()
            if not policy:
                return {"success": False, "error": "السياسة غير موجودة"}
            return {
                "success": True,
                "policy": {
                    "id": policy.id,
                    "type": policy.policy_type,
                    "version": policy.version,
                    "title_ar": policy.title_ar,
                    "title_en": policy.title_en,
                    "content_ar": policy.content_ar,
                    "content_en": policy.content_en,
                    "effective_from": policy.effective_from.isoformat() if policy.effective_from else None,
                },
            }
        finally:
            db.close()

    def accept_policy(
        self,
        user_id: str,
        policy_document_id: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> dict:
        """Log user accepting a specific policy version."""
        db = SessionLocal()
        try:
            policy = db.query(PolicyDocument).filter(PolicyDocument.id == policy_document_id).first()
            if not policy:
                return {"success": False, "error": "السياسة غير موجودة"}

            # Check if already accepted this version
            existing = (
                db.query(PolicyAcceptanceLog)
                .filter(
                    PolicyAcceptanceLog.user_id == user_id,
                    PolicyAcceptanceLog.policy_document_id == policy_document_id,
                )
                .first()
            )
            if existing:
                return {"success": True, "message": "تم قبول هذه السياسة مسبقاً", "already_accepted": True}

            db.add(
                PolicyAcceptanceLog(
                    id=gen_uuid(),
                    user_id=user_id,
                    policy_document_id=policy_document_id,
                    accepted_ip=ip_address,
                    accepted_user_agent=user_agent,
                )
            )
            db.commit()

            return {
                "success": True,
                "message": "تم تسجيل القبول",
                "policy_type": policy.policy_type,
                "version": policy.version,
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def check_mandatory_acceptance(self, user_id: str, required_types: Optional[list] = None) -> dict:
        """
        Check if user has accepted all mandatory policies.
        Returns list of missing acceptances.
        """
        if required_types is None:
            required_types = [
                PolicyType.terms_of_service.value,
                PolicyType.privacy_policy.value,
                PolicyType.acceptable_use.value,
            ]

        db = SessionLocal()
        try:
            missing = []
            for ptype in required_types:
                current = (
                    db.query(PolicyDocument)
                    .filter(
                        PolicyDocument.policy_type == ptype,
                        PolicyDocument.is_current == True,
                    )
                    .first()
                )
                if not current:
                    continue

                accepted = (
                    db.query(PolicyAcceptanceLog)
                    .filter(
                        PolicyAcceptanceLog.user_id == user_id,
                        PolicyAcceptanceLog.policy_document_id == current.id,
                    )
                    .first()
                )

                if not accepted:
                    missing.append(
                        {
                            "policy_type": ptype,
                            "policy_id": current.id,
                            "title_ar": current.title_ar,
                            "version": current.version,
                        }
                    )

            return {
                "all_accepted": len(missing) == 0,
                "missing": missing,
            }
        finally:
            db.close()

    def get_user_acceptances(self, user_id: str) -> list:
        """Get all policy acceptances for a user."""
        db = SessionLocal()
        try:
            logs = (
                db.query(PolicyAcceptanceLog)
                .filter(PolicyAcceptanceLog.user_id == user_id)
                .order_by(PolicyAcceptanceLog.accepted_at.desc())
                .all()
            )
            result = []
            for log in logs:
                policy = db.query(PolicyDocument).filter(PolicyDocument.id == log.policy_document_id).first()
                result.append(
                    {
                        "policy_type": policy.policy_type if policy else "unknown",
                        "version": policy.version if policy else "unknown",
                        "title_ar": policy.title_ar if policy else "",
                        "accepted_at": log.accepted_at.isoformat(),
                        "accepted_ip": log.accepted_ip,
                    }
                )
            return result
        finally:
            db.close()
