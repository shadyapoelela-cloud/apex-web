"""
APEX Platform — Phase 3 API Routes
═══════════════════════════════════════════════════════════════
Knowledge Feedback, Review Queue, Candidate Rules.
Per execution document sections 10, 12.
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional

from app.phase1.routes.phase1_routes import get_current_user
from app.phase3.services.knowledge_feedback_service import KnowledgeFeedbackService

router = APIRouter()
feedback_service = KnowledgeFeedbackService()


# ═══════════════════════════════════════════════════════════════
# Schemas
# ═══════════════════════════════════════════════════════════════

class SubmitFeedbackRequest(BaseModel):
    feedback_type: str
    title: str = Field(..., min_length=5)
    description: str = Field(..., min_length=10)
    client_id: Optional[str] = None
    result_id: Optional[str] = None
    target_metric_key: Optional[str] = None
    target_account_name: Optional[str] = None
    suggested_correction: Optional[str] = None
    suggested_classification: Optional[str] = None
    reference_standard: Optional[str] = None
    applicability_scope: str = "global"
    priority: str = "normal"

class ReviewFeedbackRequest(BaseModel):
    decision: str  # accepted, rejected, needs_refinement, queued_for_rule_design
    reviewer_notes: Optional[str] = None
    quality_score: Optional[int] = Field(None, ge=1, le=5)

class PromoteRuleRequest(BaseModel):
    rule_type: str
    rule_code: str
    name_ar: str
    condition: dict
    action: dict
    priority: int = 50


# ═══════════════════════════════════════════════════════════════
# Knowledge Feedback APIs
# ═══════════════════════════════════════════════════════════════

@router.post("/knowledge-feedback", tags=["Knowledge"])
async def submit_feedback(req: SubmitFeedbackRequest, user: dict = Depends(get_current_user)):
    """Submit knowledge feedback — gated by client type knowledge mode."""
    result = feedback_service.submit_feedback(
        user_id=user["sub"],
        feedback_type=req.feedback_type,
        title=req.title,
        description=req.description,
        client_id=req.client_id,
        result_id=req.result_id,
        target_metric_key=req.target_metric_key,
        target_account_name=req.target_account_name,
        suggested_correction=req.suggested_correction,
        suggested_classification=req.suggested_classification,
        reference_standard=req.reference_standard,
        applicability_scope=req.applicability_scope,
        priority=req.priority,
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/knowledge-feedback", tags=["Knowledge"])
async def list_my_feedback(
    status: Optional[str] = None,
    client_id: Optional[str] = None,
    limit: int = Query(50, le=100),
    user: dict = Depends(get_current_user),
):
    """List my submitted feedback."""
    return feedback_service.list_feedback(user_id=user["sub"], status=status, client_id=client_id, limit=limit)


@router.get("/knowledge-feedback/review-queue", tags=["Knowledge Governance"])
async def get_review_queue(
    limit: int = Query(50, le=100),
    user: dict = Depends(get_current_user),
):
    """Get pending feedback for review — requires reviewer role."""
    # Role check: reviewer or knowledge_reviewer or platform_admin
    allowed_roles = {"reviewer", "knowledge_reviewer", "platform_admin", "super_admin"}
    user_roles = set(user.get("roles", []))
    if not user_roles & allowed_roles:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية المراجعة")
    return feedback_service.get_review_queue(limit=limit)


@router.post("/knowledge-feedback/{feedback_id}/review", tags=["Knowledge Governance"])
async def review_feedback(
    feedback_id: str,
    req: ReviewFeedbackRequest,
    user: dict = Depends(get_current_user),
):
    """Review a feedback item — accept/reject/refine."""
    allowed_roles = {"reviewer", "knowledge_reviewer", "platform_admin", "super_admin"}
    user_roles = set(user.get("roles", []))
    if not user_roles & allowed_roles:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية المراجعة")

    result = feedback_service.review_feedback(
        feedback_id=feedback_id,
        reviewer_id=user["sub"],
        decision=req.decision,
        reviewer_notes=req.reviewer_notes,
        quality_score=req.quality_score,
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/knowledge-feedback/{feedback_id}/promote-rule", tags=["Knowledge Governance"])
async def promote_to_rule(
    feedback_id: str,
    req: PromoteRuleRequest,
    user: dict = Depends(get_current_user),
):
    """Promote accepted feedback to a candidate rule."""
    allowed_roles = {"knowledge_reviewer", "platform_admin", "super_admin"}
    user_roles = set(user.get("roles", []))
    if not user_roles & allowed_roles:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية ترقية القواعد")

    result = feedback_service.promote_to_candidate_rule(
        feedback_id=feedback_id,
        creator_id=user["sub"],
        rule_type=req.rule_type,
        rule_code=req.rule_code,
        name_ar=req.name_ar,
        condition=req.condition,
        action=req.action,
        priority=req.priority,
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/knowledge-feedback/candidate-rules", tags=["Knowledge Governance"])
async def list_candidate_rules(
    status: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """List candidate rules — for reviewers."""
    return feedback_service.list_candidate_rules(status=status)
