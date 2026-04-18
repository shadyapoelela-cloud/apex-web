"""
APEX — AI guardrails HTTP routes (Wave 7 PR#2).

Lets any AI-producing module enqueue a suggestion through the gate,
and lets admins / accountants approve or reject pending ones.

Endpoints:
  POST /ai/guardrails/evaluate     — submit a suggestion
  GET  /ai/guardrails              — list with status/source filter
  GET  /ai/guardrails/stats        — counts per verdict
  GET  /ai/guardrails/{id}         — detail
  POST /ai/guardrails/{id}/approve — human approval
  POST /ai/guardrails/{id}/reject  — human rejection with reason
"""

from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.ai_guardrails import (
    Suggestion,
    Verdict,
    approve,
    get_row,
    guard,
    list_rows,
    reject,
    stats,
)
from app.core.auth_utils import extract_user_id

router = APIRouter(prefix="/ai/guardrails", tags=["AI Guardrails"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


_VALID_STATUSES = {v.value for v in Verdict}


class EvaluateRequest(BaseModel):
    source: str = Field(min_length=1, max_length=60)
    action_type: str = Field(min_length=1, max_length=60)
    after: dict[str, Any]
    confidence: float = Field(ge=0.0, le=1.0)
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    before: Optional[dict[str, Any]] = None
    reasoning: Optional[str] = None
    destructive: bool = False
    tenant_id: Optional[str] = None
    min_confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)


@router.post("/evaluate")
async def evaluate(req: EvaluateRequest, _user_id: str = Depends(_auth)):
    decision = guard(
        Suggestion(
            source=req.source,
            action_type=req.action_type,
            after=req.after,
            confidence=req.confidence,
            target_type=req.target_type,
            target_id=req.target_id,
            before=req.before,
            reasoning=req.reasoning,
            destructive=req.destructive,
            tenant_id=req.tenant_id,
            min_confidence=req.min_confidence,
        )
    )
    return {
        "success": True,
        "data": {
            "id": decision.row_id,
            "verdict": decision.verdict.value,
            "reason": decision.reason,
        },
    }


@router.get("")
async def list_suggestions(
    status: Optional[str] = None,
    source: Optional[str] = None,
    tenant_id: Optional[str] = None,
    limit: int = 100,
    _user_id: str = Depends(_auth),
):
    if status is not None and status not in _VALID_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"status must be one of {sorted(_VALID_STATUSES)}",
        )
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 500")
    rows = list_rows(status=status, source=source, tenant_id=tenant_id, limit=limit)
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


@router.get("/stats")
async def get_stats(tenant_id: Optional[str] = None, _user_id: str = Depends(_auth)):
    return {"success": True, "data": stats(tenant_id=tenant_id)}


@router.get("/{row_id}")
async def get_suggestion(row_id: str, _user_id: str = Depends(_auth)):
    row = get_row(row_id)
    if row is None:
        raise HTTPException(status_code=404, detail="suggestion not found")
    return {"success": True, "data": row}


@router.post("/{row_id}/approve")
async def approve_suggestion(row_id: str, user_id: str = Depends(_auth)):
    try:
        verdict = approve(row_id, user_id=user_id)
    except LookupError:
        raise HTTPException(status_code=404, detail="suggestion not found")
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return {"success": True, "data": {"id": row_id, "verdict": verdict.value}}


class RejectRequest(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=2000)


@router.post("/{row_id}/reject")
async def reject_suggestion(
    row_id: str,
    body: RejectRequest,
    user_id: str = Depends(_auth),
):
    try:
        verdict = reject(row_id, user_id=user_id, reason=body.reason)
    except LookupError:
        raise HTTPException(status_code=404, detail="suggestion not found")
    return {"success": True, "data": {"id": row_id, "verdict": verdict.value}}
