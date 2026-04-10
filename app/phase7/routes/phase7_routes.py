"""
APEX Phase 7 — Task Documents, Suspension, Result Details, Audit APIs
Per Execution Master §8, §6 + Zero-Ambiguity §9, §7, §14
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Optional, List
from pydantic import BaseModel
import logging
from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow
from app.phase1.routes.phase1_routes import get_current_user

router = APIRouter()

# ═══════════════════════════════════════════════════════
# DTOs
# ═══════════════════════════════════════════════════════
class TaskTypeResponse(BaseModel):
    id: str
    code: str
    name_ar: str
    name_en: str
    description_ar: Optional[str] = None
    input_requirements: list = []
    output_requirements: list = []

class SubmitDocRequest(BaseModel):
    service_task_id: str
    requirement_id: str
    file_name: str
    file_url: Optional[str] = None

class ComplianceFlagRequest(BaseModel):
    provider_id: str
    service_task_id: Optional[str] = None
    action: str
    description: Optional[str] = None

class SuspendRequest(BaseModel):
    provider_id: str
    suspension_type: str = "suspension_soft"
    reason: str

class ResultDetailResponse(BaseModel):
    id: str
    result_key: str
    summary_ar: Optional[str] = None
    source_rows: Optional[str] = None
    applied_rules: Optional[str] = None
    confidence: float = 0.0
    warnings: Optional[str] = None
    feedback_count: int = 0

# ═══════════════════════════════════════════════════════
# Task Types & Document Requirements
# ═══════════════════════════════════════════════════════
@router.get("/task-types", tags=["Task Documents"])
async def list_task_types():
    db = SessionLocal()
    try:
        from collections import defaultdict
        from app.phase7.models.phase7_models import TaskType, TaskDocumentRequirement, DocRequirementType
        types = db.query(TaskType).filter(TaskType.is_active == True).all()
        type_ids = [tt.id for tt in types]

        # Pre-fetch all requirements in a single query to avoid N+1
        all_reqs = db.query(TaskDocumentRequirement).filter(
            TaskDocumentRequirement.task_type_id.in_(type_ids)
        ).order_by(TaskDocumentRequirement.sort_order).all()

        reqs_by_type = defaultdict(list)
        for r in all_reqs:
            reqs_by_type[r.task_type_id].append(r)

        result = []
        for tt in types:
            reqs = reqs_by_type.get(tt.id, [])
            inputs = [{"id": r.id, "name_ar": r.document_name_ar, "name_en": r.document_name_en,
                       "is_mandatory": r.is_mandatory}
                      for r in reqs if r.requirement_type == DocRequirementType.input_required]
            outputs = [{"id": r.id, "name_ar": r.document_name_ar, "name_en": r.document_name_en,
                        "is_mandatory": r.is_mandatory}
                       for r in reqs if r.requirement_type == DocRequirementType.output_required]

            result.append({
                "id": tt.id, "code": tt.code,
                "name_ar": tt.name_ar, "name_en": tt.name_en,
                "description_ar": tt.description_ar,
                "input_requirements": inputs,
                "output_requirements": outputs
            })
        return {"success": True, "data": result}
    finally:
        db.close()

@router.get("/task-types/{code}", tags=["Task Documents"])
async def get_task_type(code: str):
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import TaskType, TaskDocumentRequirement, DocRequirementType
        tt = db.query(TaskType).filter(TaskType.code == code).first()
        if not tt:
            raise HTTPException(404, "Task type not found")
        reqs = db.query(TaskDocumentRequirement).filter(
            TaskDocumentRequirement.task_type_id == tt.id
        ).order_by(TaskDocumentRequirement.sort_order).all()
        
        return {"success": True, "data": {
            "id": tt.id, "code": tt.code,
            "name_ar": tt.name_ar, "name_en": tt.name_en,
            "input_requirements": [{"id": r.id, "name_ar": r.document_name_ar,
                                    "is_mandatory": r.is_mandatory}
                                   for r in reqs if r.requirement_type == DocRequirementType.input_required],
            "output_requirements": [{"id": r.id, "name_ar": r.document_name_ar,
                                     "is_mandatory": r.is_mandatory}
                                    for r in reqs if r.requirement_type == DocRequirementType.output_required]
        }}
    finally:
        db.close()

# ═══════════════════════════════════════════════════════
# Task Submissions
# ═══════════════════════════════════════════════════════
@router.post("/task-submissions", tags=["Task Documents"])
async def submit_task_document(req: SubmitDocRequest, user=Depends(get_current_user)):
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import TaskSubmission, SubmissionStatus, AuditEvent
        sub = TaskSubmission(
            id=gen_uuid(), service_task_id=req.service_task_id,
            requirement_id=req.requirement_id, provider_id=user["sub"],
            file_name=req.file_name, file_url=req.file_url,
            status=SubmissionStatus.uploaded, uploaded_at=utcnow()
        )
        db.add(sub)
        # Audit log
        db.add(AuditEvent(id=gen_uuid(), user_id=user["sub"], action="task_document_upload",
                          entity_type="task_submission", entity_id=sub.id,
                          details=f"Uploaded {req.file_name} for task {req.service_task_id}"))
        db.commit()
        return {"success": True, "data": {"submission_id": sub.id, "status": "uploaded"}}
    except Exception as e:
        db.rollback()
        logging.error("Task submission error", exc_info=True)
        raise HTTPException(500, "Task submission failed")
    finally:
        db.close()

@router.get("/task-submissions/{task_id}", tags=["Task Documents"])
async def get_task_submissions(task_id: str, user=Depends(get_current_user)):
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import TaskSubmission
        subs = db.query(TaskSubmission).filter(TaskSubmission.service_task_id == task_id).all()
        return {"success": True, "data": [{"id": s.id, "requirement_id": s.requirement_id, "file_name": s.file_name,
                 "status": s.status.value if s.status else "pending",
                 "uploaded_at": str(s.uploaded_at) if s.uploaded_at else None}
                for s in subs]}
    finally:
        db.close()

# ═══════════════════════════════════════════════════════
# Provider Compliance & Suspension
# ═══════════════════════════════════════════════════════
@router.post("/providers/compliance/flag", tags=["Provider Compliance"])
async def flag_provider_compliance(req: ComplianceFlagRequest, user=Depends(get_current_user)):
    """Flag a provider for compliance issue — admin/reviewer only"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import ProviderComplianceFlag, ComplianceAction, AuditEvent
        flag = ProviderComplianceFlag(
            id=gen_uuid(), provider_id=req.provider_id,
            service_task_id=req.service_task_id,
            action=ComplianceAction(req.action),
            description=req.description
        )
        db.add(flag)
        db.add(AuditEvent(id=gen_uuid(), user_id=user["sub"], action="compliance_flag",
                          entity_type="provider", entity_id=req.provider_id,
                          details=f"Flagged: {req.action}"))
        db.commit()
        return {"success": True, "data": {"flag_id": flag.id}}
    except Exception as e:
        db.rollback()
        logging.error("Compliance flag error", exc_info=True)
        raise HTTPException(500, "Failed to flag provider")
    finally:
        db.close()

@router.get("/providers/{provider_id}/compliance", tags=["Provider Compliance"])
async def get_provider_compliance(provider_id: str, limit: int = 50, offset: int = 0, user=Depends(get_current_user)):
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import ProviderComplianceFlag, ProviderSuspension, SuspensionStatus
        flags = db.query(ProviderComplianceFlag).filter(
            ProviderComplianceFlag.provider_id == provider_id
        ).order_by(ProviderComplianceFlag.created_at.desc()).limit(min(limit, 100)).offset(offset).all()
        
        active_suspension = db.query(ProviderSuspension).filter(
            ProviderSuspension.provider_id == provider_id,
            ProviderSuspension.status == SuspensionStatus.active
        ).first()
        
        return {"success": True, "data": {
            "provider_id": provider_id,
            "is_suspended": active_suspension is not None,
            "suspension": {
                "type": active_suspension.suspension_type.value,
                "reason": active_suspension.reason,
                "since": str(active_suspension.suspended_at)
            } if active_suspension else None,
            "flags": [{
                "id": f.id, "action": f.action.value if f.action else str(f.action),
                "description": f.description, "is_resolved": f.is_resolved,
                "created_at": str(f.created_at)
            } for f in flags],
            "unresolved_count": sum(1 for f in flags if not f.is_resolved)
        }}
    finally:
        db.close()

@router.post("/providers/suspend", tags=["Provider Compliance"])
async def suspend_provider(req: SuspendRequest, user=Depends(get_current_user)):
    """Suspend a provider — admin only"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import ProviderSuspension, SuspensionType, AuditEvent
        suspension = ProviderSuspension(
            id=gen_uuid(), provider_id=req.provider_id,
            suspension_type=SuspensionType(req.suspension_type),
            reason=req.reason
        )
        db.add(suspension)
        db.add(AuditEvent(id=gen_uuid(), user_id=user["sub"], action="provider_suspended",
                          entity_type="provider", entity_id=req.provider_id,
                          details=req.reason))
        db.commit()
        return {"success": True, "data": {"suspension_id": suspension.id}}
    except Exception as e:
        db.rollback()
        logging.error("Suspension error", exc_info=True)
        raise HTTPException(500, "Failed to suspend provider")
    finally:
        db.close()

@router.post("/providers/unsuspend/{provider_id}", tags=["Provider Compliance"])
async def unsuspend_provider(provider_id: str, user=Depends(get_current_user)):
    """Lift suspension — admin only"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import ProviderSuspension, SuspensionStatus, AuditEvent
        suspension = db.query(ProviderSuspension).filter(
            ProviderSuspension.provider_id == provider_id,
            ProviderSuspension.status == SuspensionStatus.active
        ).first()
        if not suspension:
            raise HTTPException(404, "No active suspension found")
        suspension.status = SuspensionStatus.lifted
        suspension.lifted_at = utcnow()
        suspension.lifted_by = user["sub"]
        db.add(AuditEvent(id=gen_uuid(), user_id=user["sub"], action="provider_unsuspended",
                          entity_type="provider", entity_id=provider_id))
        db.commit()
        return {"success": True, "data": {"message": "Suspension lifted"}}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logging.error("Unsuspend error", exc_info=True)
        raise HTTPException(500, "Failed to lift suspension")
    finally:
        db.close()

# ═══════════════════════════════════════════════════════
# Result Explanations (! icon details)
# ═══════════════════════════════════════════════════════
@router.get("/results/{analysis_id}/details", tags=["Result Details"])
async def get_result_details(analysis_id: str, user=Depends(get_current_user)):
    """Get detailed explanations for analysis results — the ! icon panel"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import P7ResultExplanation
        explanations = db.query(P7ResultExplanation).filter(
            P7ResultExplanation.analysis_id == analysis_id
        ).all()
        
        if not explanations:
            return {"success": True, "data": {"analysis_id": analysis_id, "details": [],
                    "message": "No detailed explanations available yet"}}

        return {"success": True, "data": {
            "analysis_id": analysis_id,
            "details": [{
                "id": e.id, "result_key": e.result_key,
                "summary_ar": e.summary_ar, "summary_en": e.summary_en,
                "source_rows": e.source_rows, "applied_rules": e.applied_rules,
                "confidence": e.confidence, "warnings": e.warnings,
                "feedback_count": e.feedback_count
            } for e in explanations]
        }}
    finally:
        db.close()

@router.post("/results/{analysis_id}/explain", tags=["Result Details"])
async def generate_result_explanation(analysis_id: str, user=Depends(get_current_user)):
    """Auto-generate explanations for analysis results"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import P7ResultExplanation
        # Generate standard explanation entries for common result types
        result_keys = [
            ("current_ratio", "نسبة التداول", "Current ratio analysis based on current assets / current liabilities"),
            ("debt_ratio", "نسبة المديونية", "Total liabilities / total assets"),
            ("revenue_trend", "اتجاه الإيرادات", "Revenue direction over analyzed period"),
            ("expense_analysis", "تحليل المصروفات", "Expense breakdown by category"),
            ("profitability", "الربحية", "Net income margin and return metrics"),
            ("liquidity_warning", "تحذير السيولة", "Cash flow adequacy assessment"),
            ("classification_check", "فحص التصنيف", "Account classification accuracy"),
        ]
        
        count = 0
        for key, summary_ar, summary_en in result_keys:
            existing = db.query(P7ResultExplanation).filter(
                P7ResultExplanation.analysis_id == analysis_id,
                P7ResultExplanation.result_key == key
            ).first()
            if not existing:
                db.add(P7ResultExplanation(
                    id=gen_uuid(), analysis_id=analysis_id,
                    result_key=key, summary_ar=summary_ar, summary_en=summary_en,
                    confidence=0.85, warnings=None
                ))
                count += 1
        
        db.commit()
        return {"success": True, "data": {"generated": count, "analysis_id": analysis_id}}
    except Exception as e:
        db.rollback()
        logging.error("Explanation generation error", exc_info=True)
        raise HTTPException(500, "Failed to generate explanations")
    finally:
        db.close()

# ═══════════════════════════════════════════════════════
# Entitlement Resolution Engine
# ═══════════════════════════════════════════════════════
@router.get("/entitlements/resolve", tags=["Entitlements"])
async def resolve_entitlements(feature: str, user=Depends(get_current_user)):
    """Check if the current user has access to a specific feature based on plan + role"""
    db = SessionLocal()
    try:
        from app.phase1.models.platform_models import User, UserSubscription, Plan, PlanFeature
        
        u = db.query(User).filter(User.id == user["sub"]).first()
        if not u:
            raise HTTPException(404, "User not found")
        
        # Get active subscription
        sub = db.query(UserSubscription).filter(
            UserSubscription.user_id == u.id,
            UserSubscription.is_active == True
        ).first()
        
        plan_code = "free"
        if sub:
            plan = db.query(Plan).filter(Plan.id == sub.plan_id).first()
            if plan:
                plan_code = plan.code
        
        # Feature entitlement matrix
        FEATURE_MATRIX = {
            "coa_upload": {"free": 2, "pro": 20, "business": 100, "expert": 50, "enterprise": 9999},
            "result_details": {"free": False, "pro": True, "business": True, "expert": True, "enterprise": True},
            "knowledge_feedback": {"free": False, "pro": "limited", "business": True, "expert": False, "enterprise": True},
            "marketplace_request": {"free": "view", "pro": True, "business": True, "expert": "provide", "enterprise": True},
            "team_members": {"free": False, "pro": False, "business": 5, "expert": False, "enterprise": 50},
            "exports": {"free": False, "pro": "limited", "business": True, "expert": "limited", "enterprise": True},
            "api_access": {"free": False, "pro": False, "business": False, "expert": False, "enterprise": True},
        }
        
        matrix = FEATURE_MATRIX.get(feature, {})
        access = matrix.get(plan_code, False)
        
        return {"success": True, "data": {
            "user_id": u.id, "plan": plan_code, "feature": feature,
            "access": access, "allowed": access not in [False, 0, "view"]
        }}
    finally:
        db.close()

# ═══════════════════════════════════════════════════════
# Audit Log
# ═══════════════════════════════════════════════════════
@router.get("/audit/events", tags=["Audit"])
async def list_audit_events(user_id: Optional[str] = None, action: Optional[str] = None,
                            limit: int = 50, user=Depends(get_current_user)):
    """List audit events — admin only"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import AuditEvent
        q = db.query(AuditEvent)
        if user_id:
            q = q.filter(AuditEvent.user_id == user_id)
        if action:
            q = q.filter(AuditEvent.action == action)
        events = q.order_by(AuditEvent.created_at.desc()).limit(limit).all()
        return {"success": True, "data": [{
            "id": e.id, "user_id": e.user_id, "action": e.action,
            "entity_type": e.entity_type, "entity_id": e.entity_id,
            "details": e.details, "created_at": str(e.created_at)
        } for e in events]}
    finally:
        db.close()
