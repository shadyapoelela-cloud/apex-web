"""
APEX Platform — Provider Service
═══════════════════════════════════════════════════════════════
Registration, document upload, verification, scope management.
Per execution document section 7.
"""

import logging
from typing import Optional
from app.phase1.models.platform_models import (
    User,
    UserRole,
    Role,
    AuditEvent,
    Notification,
    SessionLocal,
    gen_uuid,
    utcnow,
)
from app.phase4.models.phase4_models import (
    ServiceProvider,
    ProviderDocument,
    ServiceProviderScope,
    VerificationStatus,
    ProviderCategory,
)

# Required documents per category
REQUIRED_DOCS = {
    "accountant": ["national_id", "professional_license", "cv_resume"],
    "senior_accountant": ["national_id", "professional_license", "cv_resume", "experience_certificate"],
    "tax_consultant": ["national_id", "professional_license", "cv_resume"],
    "zakat_vat_consultant": ["national_id", "professional_license", "cv_resume"],
    "audit_consultant": ["national_id", "socpa_membership", "cv_resume"],
    "bookkeeping_specialist": ["national_id", "cv_resume"],
    "hr_consultant": ["national_id", "cv_resume"],
    "legal_consultant": ["national_id", "professional_license", "cv_resume"],
}
DEFAULT_REQUIRED = ["national_id", "cv_resume"]

# Service scopes per category
CATEGORY_SCOPES = {
    "accountant": [
        ("bookkeeping", "مسك الدفاتر", "Bookkeeping"),
        ("financial_statements", "إعداد القوائم المالية", "Financial Statements"),
    ],
    "senior_accountant": [
        ("bookkeeping", "مسك الدفاتر", "Bookkeeping"),
        ("financial_statements", "إعداد القوائم المالية", "Financial Statements"),
        ("financial_analysis", "تحليل مالي", "Financial Analysis"),
    ],
    "tax_consultant": [
        ("vat_review", "مراجعة ض.ق.م", "VAT Review"),
        ("tax_planning", "تخطيط ضريبي", "Tax Planning"),
        ("zakat_filing", "إعداد إقرار الزكاة", "Zakat Filing"),
    ],
    "zakat_vat_consultant": [
        ("vat_review", "مراجعة ض.ق.م", "VAT Review"),
        ("zakat_filing", "إعداد إقرار الزكاة", "Zakat Filing"),
    ],
    "audit_consultant": [
        ("internal_audit", "تدقيق داخلي", "Internal Audit"),
        ("external_audit_support", "دعم التدقيق الخارجي", "External Audit Support"),
    ],
    "bookkeeping_specialist": [
        ("bookkeeping", "مسك الدفاتر", "Bookkeeping"),
        ("reconciliation", "تسويات بنكية", "Reconciliation"),
    ],
    "hr_consultant": [
        ("hr_policy_review", "مراجعة سياسات HR", "HR Policy Review"),
        ("payroll_setup", "إعداد الرواتب", "Payroll Setup"),
    ],
}


class ProviderService:

    def register_provider(
        self,
        user_id: str,
        category: str,
        bio_ar: Optional[str] = None,
        years_experience: Optional[int] = None,
        city: Optional[str] = None,
    ) -> dict:
        """Register as service provider — free registration with mandatory verification."""
        valid_cats = [c.value for c in ProviderCategory]
        if category not in valid_cats:
            return {"success": False, "error": f"الفئة غير صالحة. المتاح: {', '.join(valid_cats[:5])}..."}

        db = SessionLocal()
        try:
            existing = db.query(ServiceProvider).filter(ServiceProvider.user_id == user_id).first()
            if existing:
                return {"success": False, "error": "أنت مسجل كمقدم خدمة بالفعل"}

            provider = ServiceProvider(
                id=gen_uuid(),
                user_id=user_id,
                category=category,
                bio_ar=bio_ar,
                years_experience=years_experience,
                city=city,
            )
            db.add(provider)

            # Auto-create scopes from category
            scopes = CATEGORY_SCOPES.get(category, [])
            for code, name_ar, name_en in scopes:
                db.add(
                    ServiceProviderScope(
                        id=gen_uuid(),
                        provider_id=provider.id,
                        scope_code=code,
                        scope_name_ar=name_ar,
                        scope_name_en=name_en,
                    )
                )

            # Assign provider role
            role = db.query(Role).filter(Role.code == "provider_user").first()
            if role:
                existing_role = (
                    db.query(UserRole).filter(UserRole.user_id == user_id, UserRole.role_id == role.id).first()
                )
                if not existing_role:
                    db.add(UserRole(id=gen_uuid(), user_id=user_id, role_id=role.id))

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="provider_registered",
                    resource_type="service_provider",
                    resource_id=provider.id,
                )
            )
            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=user_id,
                    title_ar="تم التسجيل كمقدم خدمة — يرجى رفع مستندات التحقق",
                    title_en="Registered as provider — please upload verification documents",
                    category="general",
                    source_type="provider_registered",
                )
            )

            db.commit()

            required = REQUIRED_DOCS.get(category, DEFAULT_REQUIRED)
            return {
                "success": True,
                "provider_id": provider.id,
                "category": category,
                "verification_status": provider.verification_status,
                "required_documents": required,
                "service_scopes": [{"code": c, "name_ar": n} for c, n, _ in scopes],
                "message": "تم التسجيل — يرجى رفع المستندات المطلوبة للتحقق",
            }

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def upload_document(self, user_id: str, document_type: str, filename: str, file_size: int = 0) -> dict:
        """Upload verification document."""
        db = SessionLocal()
        try:
            provider = db.query(ServiceProvider).filter(ServiceProvider.user_id == user_id).first()
            if not provider:
                return {"success": False, "error": "أنت غير مسجل كمقدم خدمة"}

            doc = ProviderDocument(
                id=gen_uuid(),
                provider_id=provider.id,
                document_type=document_type,
                filename=filename,
                file_size_bytes=file_size,
            )
            db.add(doc)

            # Check if all required docs uploaded
            required = REQUIRED_DOCS.get(provider.category, DEFAULT_REQUIRED)
            uploaded_types = {
                d.document_type
                for d in db.query(ProviderDocument).filter(ProviderDocument.provider_id == provider.id).all()
            }
            uploaded_types.add(document_type)

            all_uploaded = all(r in uploaded_types for r in required)
            if all_uploaded and provider.verification_status == VerificationStatus.pending.value:
                provider.verification_status = VerificationStatus.documents_submitted.value

            db.commit()
            return {
                "success": True,
                "document_id": doc.id,
                "all_required_uploaded": all_uploaded,
                "verification_status": provider.verification_status,
            }
        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def review_provider(
        self,
        provider_id: str,
        reviewer_id: str,
        decision: str,
        reviewer_notes: Optional[str] = None,
        verification_score: Optional[int] = None,
    ) -> dict:
        """Review and approve/reject provider."""
        if decision not in ("approved", "rejected"):
            return {"success": False, "error": "القرار يجب أن يكون approved أو rejected"}

        db = SessionLocal()
        try:
            provider = db.query(ServiceProvider).filter(ServiceProvider.id == provider_id).first()
            if not provider:
                return {"success": False, "error": "مقدم الخدمة غير موجود"}

            provider.verification_status = decision
            provider.verified_by = reviewer_id
            provider.verified_at = utcnow()
            provider.reviewer_notes = reviewer_notes
            provider.verification_score = verification_score

            if decision == "approved":
                # Approve all scopes
                for scope in provider.scopes:
                    scope.is_approved = True
                    scope.approved_by = reviewer_id
                    scope.approved_at = utcnow()

            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=provider.user_id,
                    title_ar=f"نتيجة التحقق: {'تمت الموافقة' if decision == 'approved' else 'مرفوض'}",
                    title_en=f"Verification: {decision}",
                    category="general",
                    source_type="provider_verification",
                )
            )
            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=reviewer_id,
                    action="provider_reviewed",
                    resource_type="service_provider",
                    resource_id=provider_id,
                    details={"decision": decision, "score": verification_score},
                )
            )

            db.commit()
            return {"success": True, "provider_id": provider_id, "status": decision}

        except Exception:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def get_my_provider_profile(self, user_id: str) -> dict:
        db = SessionLocal()
        try:
            p = db.query(ServiceProvider).filter(ServiceProvider.user_id == user_id).first()
            if not p:
                return {"success": False, "error": "غير مسجل كمقدم خدمة"}

            docs = db.query(ProviderDocument).filter(ProviderDocument.provider_id == p.id).all()
            scopes = db.query(ServiceProviderScope).filter(ServiceProviderScope.provider_id == p.id).all()

            return {
                "success": True,
                "provider": {
                    "id": p.id,
                    "category": p.category,
                    "bio_ar": p.bio_ar,
                    "years_experience": p.years_experience,
                    "city": p.city,
                    "verification_status": p.verification_status,
                    "verification_score": p.verification_score,
                    "compliance_status": p.compliance_status,
                    "commission_rate": p.commission_rate,
                    "is_premium": p.is_premium,
                    "rating_average": p.rating_average,
                    "completed_tasks": p.completed_tasks_count,
                },
                "documents": [
                    {"id": d.id, "type": d.document_type, "filename": d.filename, "status": d.status} for d in docs
                ],
                "scopes": [
                    {"code": s.scope_code, "name_ar": s.scope_name_ar, "is_approved": s.is_approved} for s in scopes
                ],
                "required_documents": REQUIRED_DOCS.get(p.category, DEFAULT_REQUIRED),
            }
        finally:
            db.close()

    def list_providers(self, category: Optional[str] = None, verified_only: bool = True) -> list:
        """List providers for marketplace."""
        db = SessionLocal()
        try:
            q = db.query(ServiceProvider).filter(ServiceProvider.is_deleted == False)
            if verified_only:
                q = q.filter(ServiceProvider.verification_status == VerificationStatus.approved.value)
            if category:
                q = q.filter(ServiceProvider.category == category)
            providers = q.order_by(ServiceProvider.listing_priority.desc(), ServiceProvider.rating_average.desc()).all()

            # Batch fetch users and scopes to avoid N+1
            provider_ids = [p.id for p in providers]
            user_ids = [p.user_id for p in providers]

            users_map = {}
            if user_ids:
                users = db.query(User).filter(User.id.in_(user_ids)).all()
                users_map = {u.id: u for u in users}

            scopes_map = {}
            if provider_ids:
                all_scopes = (
                    db.query(ServiceProviderScope)
                    .filter(
                        ServiceProviderScope.provider_id.in_(provider_ids), ServiceProviderScope.is_approved == True
                    )
                    .all()
                )
                for s in all_scopes:
                    scopes_map.setdefault(s.provider_id, []).append(s)

            result = []
            for p in providers:
                user = users_map.get(p.user_id)
                scopes = scopes_map.get(p.id, [])
                result.append(
                    {
                        "id": p.id,
                        "display_name": user.display_name if user else "",
                        "category": p.category,
                        "bio_ar": p.bio_ar,
                        "years_experience": p.years_experience,
                        "city": p.city,
                        "rating": p.rating_average,
                        "completed_tasks": p.completed_tasks_count,
                        "is_premium": p.is_premium,
                        "badge": p.badge,
                        "scopes": [s.scope_name_ar for s in scopes],
                    }
                )
            return result
        finally:
            db.close()

    def list_pending_verification(self) -> list:
        """List providers pending verification — for reviewers."""
        db = SessionLocal()
        try:
            providers = (
                db.query(ServiceProvider)
                .filter(
                    ServiceProvider.verification_status.in_(
                        [
                            VerificationStatus.documents_submitted.value,
                            VerificationStatus.under_review.value,
                        ]
                    )
                )
                .order_by(ServiceProvider.created_at.asc())
                .all()
            )

            # Batch fetch users and docs to avoid N+1
            provider_ids = [p.id for p in providers]
            user_ids = [p.user_id for p in providers]

            users_map = {}
            if user_ids:
                users = db.query(User).filter(User.id.in_(user_ids)).all()
                users_map = {u.id: u for u in users}

            docs_map = {}
            if provider_ids:
                all_docs = db.query(ProviderDocument).filter(ProviderDocument.provider_id.in_(provider_ids)).all()
                for d in all_docs:
                    docs_map.setdefault(d.provider_id, []).append(d)

            result = []
            for p in providers:
                user = users_map.get(p.user_id)
                docs = docs_map.get(p.id, [])
                result.append(
                    {
                        "id": p.id,
                        "display_name": user.display_name if user else "",
                        "category": p.category,
                        "verification_status": p.verification_status,
                        "documents": [
                            {"type": d.document_type, "filename": d.filename, "status": d.status} for d in docs
                        ],
                        "created_at": p.created_at.isoformat(),
                    }
                )
            return result
        finally:
            db.close()
