"""
APEX Platform — Compliance API Routes
═══════════════════════════════════════════════════════════════
Endpoints:
  POST /compliance/je/next              -> reserve next JE number
  GET  /compliance/je/peek              -> read current counter (no increment)
  POST /compliance/audit/log            -> append audit event
  GET  /compliance/audit/verify         -> walk + verify the audit chain
"""

from fastapi import APIRouter, Depends, HTTPException, Header, Request
from pydantic import BaseModel, Field
from typing import Any, Optional

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import (
    next_journal_entry_number,
    peek_journal_entry_sequence,
    write_audit_event,
    verify_audit_chain,
)

router = APIRouter(prefix="/compliance", tags=["Compliance"])


class NextJERequest(BaseModel):
    client_id: str = Field(..., min_length=1)
    fiscal_year: str = Field(..., pattern=r"^\d{4}$")
    prefix: str = Field(default="JE", max_length=10)


class AuditLogRequest(BaseModel):
    action: str = Field(..., min_length=1, max_length=80)
    entity_type: Optional[str] = Field(None, max_length=50)
    entity_id: Optional[str] = Field(None, max_length=36)
    before: Optional[Any] = None
    after: Optional[Any] = None
    metadata: Optional[Any] = None


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


@router.post("/je/next")
async def reserve_next_je_number(
    body: NextJERequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    """Reserve the next gap-free journal-entry number for (client, year)."""
    try:
        res = next_journal_entry_number(body.client_id, body.fiscal_year, body.prefix)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    # Fire-and-forget audit record
    write_audit_event(
        action="je.reserve_number",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="journal_entry_sequence",
        entity_id=f"{body.client_id}:{body.fiscal_year}",
        after={"number": res["number"], "sequence": res["sequence"]},
    )
    return {"success": True, "data": res}


@router.get("/je/peek")
async def peek_je_sequence(
    client_id: str,
    fiscal_year: str,
    user_id: str = Depends(_auth),
):
    """Read the current JE counter state without incrementing."""
    if len(fiscal_year) != 4 or not fiscal_year.isdigit():
        raise HTTPException(status_code=400, detail="fiscal_year must be a 4-digit year")
    return {"success": True, "data": peek_journal_entry_sequence(client_id, fiscal_year)}


@router.post("/audit/log")
async def log_audit_event(
    body: AuditLogRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    """Append an application-level event to the immutable audit trail."""
    h = write_audit_event(
        action=body.action,
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type=body.entity_type,
        entity_id=body.entity_id,
        before=body.before,
        after=body.after,
        metadata=body.metadata,
    )
    if not h:
        raise HTTPException(status_code=500, detail="audit write failed")
    return {"success": True, "hash": h}


@router.get("/audit/verify")
async def verify_audit(limit: int = 1000, user_id: str = Depends(_auth)):
    """Verify the integrity of the audit chain (SHA-256 + prev_hash)."""
    if limit < 1 or limit > 10000:
        raise HTTPException(status_code=400, detail="limit must be 1..10000")
    return {"success": True, "data": verify_audit_chain(limit=limit)}
