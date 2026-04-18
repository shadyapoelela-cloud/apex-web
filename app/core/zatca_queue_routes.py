"""
APEX — ZATCA retry queue HTTP routes (Wave 5 PR#2).

Endpoints:
  POST /zatca/queue/enqueue        — stage a new submission
  GET  /zatca/queue                — list with status filter
  GET  /zatca/queue/{id}           — detail
  GET  /zatca/queue/stats          — counts per status
  POST /zatca/queue/process        — admin trigger; dry-run by default

The process endpoint uses a safe no-op submit_fn in dry-run mode so
admins can inspect what WOULD be attempted without actually hitting
ZATCA. The real worker runs as a background job (future wave) using
the same zatca_retry_queue.process_due() primitive.
"""

from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.zatca_retry_queue import (
    STATUS_CLEARED,
    STATUS_DRAFT,
    STATUS_GIVEUP,
    STATUS_PENDING,
    SubmissionResult,
    enqueue,
    get_row,
    list_rows,
    process_due,
    stats,
)

router = APIRouter(prefix="/zatca/queue", tags=["ZATCA Queue"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


_VALID_STATUSES = {STATUS_DRAFT, STATUS_PENDING, STATUS_CLEARED, STATUS_GIVEUP}


class EnqueueRequest(BaseModel):
    invoice_id: str = Field(min_length=1, max_length=36)
    payload: dict[str, Any]
    tenant_id: Optional[str] = None
    max_attempts: Optional[int] = Field(default=None, ge=1, le=20)
    start_as: str = Field(default=STATUS_PENDING)


@router.post("/enqueue")
async def enqueue_submission(req: EnqueueRequest, _user_id: str = Depends(_auth)):
    if req.start_as not in (STATUS_DRAFT, STATUS_PENDING):
        raise HTTPException(
            status_code=400,
            detail=f"start_as must be '{STATUS_DRAFT}' or '{STATUS_PENDING}'",
        )
    row_id = enqueue(
        req.invoice_id,
        req.payload,
        tenant_id=req.tenant_id,
        max_attempts=req.max_attempts,
        start_as=req.start_as,
    )
    return {"success": True, "data": {"id": row_id}}


@router.get("")
async def list_queue(
    status: Optional[str] = None,
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
    rows = list_rows(status=status, tenant_id=tenant_id, limit=limit)
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


@router.get("/stats")
async def get_stats(tenant_id: Optional[str] = None, _user_id: str = Depends(_auth)):
    return {"success": True, "data": stats(tenant_id=tenant_id)}


@router.get("/{row_id}")
async def get_submission(row_id: str, _user_id: str = Depends(_auth)):
    row = get_row(row_id)
    if row is None:
        raise HTTPException(status_code=404, detail="submission not found")
    return {"success": True, "data": row}


class ProcessRequest(BaseModel):
    dry_run: bool = Field(default=True)
    limit: int = Field(default=50, ge=1, le=500)


@router.post("/process")
async def process_queue(req: ProcessRequest, _user_id: str = Depends(_auth)):
    """Process due rows. Dry-run (default) just counts what would have
    been attempted without touching any external service."""
    if req.dry_run:
        def _dry(_row):
            return SubmissionResult(ok=False, error_code="DRY_RUN", error_message=None)

        # Dry-run can't mutate state the way a real submit_fn would.
        # Just report the stats snapshot so the caller can see what's due.
        from app.core.zatca_retry_queue import due_for_retry

        pending = due_for_retry(req.limit)
        return {
            "success": True,
            "data": {
                "dry_run": True,
                "pending_count": len(pending),
                "pending": pending,
            },
        }

    # Real run: still no external HTTP call from this endpoint — in
    # production a background worker calls process_due directly with
    # the real ZATCA HTTP client. Here we fail-fast with 501 so nobody
    # accidentally assumes this endpoint submits to Fatoora.
    raise HTTPException(
        status_code=501,
        detail="non-dry-run processing must be invoked from the background worker",
    )
