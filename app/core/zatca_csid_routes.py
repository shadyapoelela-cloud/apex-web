"""
APEX — ZATCA CSID lifecycle HTTP routes (Wave 11 PR#2).

Design rule: no endpoint ever returns the decrypted cert or private
key. That material flows only through `get_active_csid()` inside the
submission pipeline — never over HTTP.

Endpoints:
  POST /zatca/csid/register            — persist new CSID
  GET  /zatca/csid                     — list metadata with filters
  GET  /zatca/csid/stats                — counts per status
  GET  /zatca/csid/expiring-soon       — active rows expiring in ≤ N days
  GET  /zatca/csid/{id}                — metadata detail
  POST /zatca/csid/{id}/revoke         — transition to revoked
  POST /zatca/csid/{id}/renewing       — mark as renewing
  POST /zatca/csid/sweep-expired       — admin batch to flip expired rows
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.zatca_csid import (
    CsidRegistration,
    ENV_PRODUCTION,
    ENV_SANDBOX,
    STATUS_ACTIVE,
    STATUS_EXPIRED,
    STATUS_RENEWING,
    STATUS_REVOKED,
    expiring_soon,
    get_row,
    list_csids,
    mark_renewing,
    mark_revoked,
    register_csid,
    stats,
    sweep_expired,
)

router = APIRouter(prefix="/zatca/csid", tags=["ZATCA CSID"])

_VALID_ENV = {ENV_SANDBOX, ENV_PRODUCTION}
_VALID_STATUS = {STATUS_ACTIVE, STATUS_EXPIRED, STATUS_REVOKED, STATUS_RENEWING}


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


class RegisterCsidRequest(BaseModel):
    tenant_id: str = Field(min_length=1, max_length=36)
    environment: str = Field(min_length=1, max_length=20)
    cert_pem: str = Field(min_length=32)
    private_key_pem: str = Field(min_length=32)
    expires_at: datetime
    cert_subject: Optional[str] = None
    cert_serial: Optional[str] = None
    issued_at: Optional[datetime] = None
    compliance_csid: Optional[str] = None


@router.post("/register")
async def register(req: RegisterCsidRequest, _user_id: str = Depends(_auth)):
    if req.environment not in _VALID_ENV:
        raise HTTPException(
            status_code=400,
            detail=f"environment must be one of {sorted(_VALID_ENV)}",
        )
    row_id = register_csid(
        CsidRegistration(
            tenant_id=req.tenant_id,
            environment=req.environment,
            cert_pem=req.cert_pem,
            private_key_pem=req.private_key_pem,
            expires_at=req.expires_at,
            cert_subject=req.cert_subject,
            cert_serial=req.cert_serial,
            issued_at=req.issued_at,
            compliance_csid=req.compliance_csid,
        )
    )
    return {"success": True, "data": {"id": row_id}}


@router.get("")
async def list_rows(
    tenant_id: Optional[str] = None,
    environment: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
    _user_id: str = Depends(_auth),
):
    if environment is not None and environment not in _VALID_ENV:
        raise HTTPException(
            status_code=400,
            detail=f"environment must be one of {sorted(_VALID_ENV)}",
        )
    if status is not None and status not in _VALID_STATUS:
        raise HTTPException(
            status_code=400,
            detail=f"status must be one of {sorted(_VALID_STATUS)}",
        )
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 500")
    rows = list_csids(
        tenant_id=tenant_id,
        environment=environment,
        status=status,
        limit=limit,
    )
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


@router.get("/stats")
async def get_stats(tenant_id: Optional[str] = None, _user_id: str = Depends(_auth)):
    return {"success": True, "data": stats(tenant_id=tenant_id)}


@router.get("/expiring-soon")
async def get_expiring(
    days: int = 30,
    tenant_id: Optional[str] = None,
    _user_id: str = Depends(_auth),
):
    if days < 1 or days > 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365")
    rows = expiring_soon(days=days, tenant_id=tenant_id)
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


@router.get("/{csid_id}")
async def detail(csid_id: str, _user_id: str = Depends(_auth)):
    row = get_row(csid_id)
    if row is None:
        raise HTTPException(status_code=404, detail="CSID not found")
    return {"success": True, "data": row}


class RevokeRequest(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=2000)


@router.post("/{csid_id}/revoke")
async def revoke(
    csid_id: str,
    body: RevokeRequest,
    user_id: str = Depends(_auth),
):
    try:
        mark_revoked(csid_id, user_id=user_id, reason=body.reason)
    except LookupError:
        raise HTTPException(status_code=404, detail="CSID not found")
    return {"success": True, "data": {"id": csid_id, "status": STATUS_REVOKED}}


@router.post("/{csid_id}/renewing")
async def mark_as_renewing(csid_id: str, user_id: str = Depends(_auth)):
    try:
        mark_renewing(csid_id, user_id=user_id)
    except LookupError:
        raise HTTPException(status_code=404, detail="CSID not found")
    return {"success": True, "data": {"id": csid_id, "status": STATUS_RENEWING}}


@router.post("/sweep-expired")
async def sweep(_user_id: str = Depends(_auth)):
    count = sweep_expired()
    return {"success": True, "data": {"swept": count}}
