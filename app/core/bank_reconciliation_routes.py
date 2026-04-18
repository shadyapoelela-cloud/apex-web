"""
APEX — AI bank reconciliation HTTP routes (Wave 15).

Endpoints:
  POST /bank-rec/propose      — score a bank_tx against candidates,
                                 return ranked proposals (read-only).
  POST /bank-rec/auto-match   — score + gate through AI guardrail;
                                 high-confidence matches auto-post,
                                 low-confidence land in needs_approval.

Both endpoints require auth. Neither one mutates the guardrail's
needs_approval queue without producing an AiSuggestion row — UI can
always trace the decision back.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.bank_reconciliation import (
    approve_and_reconcile,
    auto_match_via_guardrail,
    propose_matches,
)

router = APIRouter(prefix="/bank-rec", tags=["AI Bank Reconciliation"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


# ── Shared input shapes ────────────────────────────────────────────────


class ReconTxn(BaseModel):
    """Minimal transaction shape accepted by both endpoints. Fields
    mirror BankFeedTransaction so the UI can pass rows through without
    a translation layer."""

    id: Optional[str] = None
    amount: Any  # Decimal | str | number — the scorer normalizes.
    date: Optional[str] = None
    vendor: Optional[str] = None
    description: Optional[str] = None
    counterparty: Optional[str] = None


class ProposeRequest(BaseModel):
    bank_tx: ReconTxn
    candidates: List[ReconTxn] = Field(default_factory=list)
    date_window_days: int = Field(default=7, ge=0, le=365)
    min_score: float = Field(default=0.3, ge=0.0, le=1.0)
    top_k: int = Field(default=5, ge=1, le=50)


class AutoMatchRequest(BaseModel):
    bank_tx: ReconTxn
    candidates: List[ReconTxn] = Field(default_factory=list)
    bank_tx_id: Optional[str] = Field(default=None, max_length=80)
    entity_type: str = Field(default="journal_entry", max_length=40)
    tenant_id: Optional[str] = Field(default=None, max_length=36)
    min_confidence: float = Field(default=0.95, ge=0.0, le=1.0)
    date_window_days: int = Field(default=7, ge=0, le=365)
    top_k: int = Field(default=5, ge=1, le=50)
    destructive: bool = False


# ── Endpoints ─────────────────────────────────────────────────────────


@router.post("/propose")
async def propose_route(
    req: ProposeRequest, _user_id: str = Depends(_auth)
) -> Dict[str, Any]:
    proposals = propose_matches(
        req.bank_tx.model_dump(),
        [c.model_dump() for c in req.candidates],
        date_window_days=req.date_window_days,
        min_score=req.min_score,
        top_k=req.top_k,
    )
    return {
        "success": True,
        "data": {"count": len(proposals), "proposals": proposals},
    }


@router.post("/auto-match")
async def auto_match_route(
    req: AutoMatchRequest, user_id: str = Depends(_auth)
) -> Dict[str, Any]:
    result = auto_match_via_guardrail(
        req.bank_tx.model_dump(),
        [c.model_dump() for c in req.candidates],
        bank_tx_id=req.bank_tx_id,
        entity_type=req.entity_type,
        tenant_id=req.tenant_id,
        user_id=user_id,
        min_confidence=req.min_confidence,
        date_window_days=req.date_window_days,
        top_k=req.top_k,
        destructive=req.destructive,
    )
    return {"success": True, "data": result.to_dict()}


@router.post("/approve/{row_id}")
async def approve_and_reconcile_route(
    row_id: str, user_id: str = Depends(_auth)
) -> Dict[str, Any]:
    """Approve a bank-rec AiSuggestion AND execute the reconciliation.

    The generic /ai/guardrails/{id}/approve only flips the suggestion
    status; it has no hook to call bank_feeds.mark_reconciled for the
    bank-rec action_type. This dedicated endpoint closes that gap.

    Returns 404 when the suggestion doesn't exist, 400 when it's not a
    bank-rec row or its after_json is malformed, and 502 when approval
    succeeded but the bank_tx has disappeared between the suggestion
    being created and the human approving it.
    """
    try:
        out = approve_and_reconcile(row_id, user_id=user_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not out["reconciled"]:
        # Suggestion flipped to approved but reconcile failed → surface
        # the partial state to the UI so the operator can investigate.
        raise HTTPException(
            status_code=502,
            detail={
                "message": out.get("error") or "reconcile failed",
                "partial": out,
            },
        )
    return {"success": True, "data": out}
