"""
APEX — Bank feeds HTTP routes (Wave 13).

Endpoints:
  POST /bank-feeds/connections                — register new connection
  GET  /bank-feeds/connections                — list with filters
  GET  /bank-feeds/connections/{id}           — detail
  POST /bank-feeds/connections/{id}/sync      — drain provider into DB
  POST /bank-feeds/connections/{id}/disconnect
  GET  /bank-feeds/transactions               — list with filters
  POST /bank-feeds/transactions/{id}/reconcile — tag as matched to an entity
  GET  /bank-feeds/stats                      — dashboard KPIs
  GET  /bank-feeds/providers                  — list registered adapters

No endpoint returns the decrypted access/refresh tokens. Plaintext
stays server-side (same invariant as ZATCA CSID, Wave 11).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.bank_feeds import (
    STATUS_CONNECTED,
    STATUS_DISCONNECTED,
    STATUS_ERROR,
    STATUS_REAUTH,
    ConnectionInput,
    ProviderAccount,
    ProviderAuthTokens,
    available_providers,
    connect,
    disconnect,
    get_connection,
    list_connections,
    list_transactions,
    mark_reconciled,
    stats,
    sync_account,
)

router = APIRouter(prefix="/bank-feeds", tags=["Bank Feeds"])

_VALID_STATUS = {
    STATUS_CONNECTED,
    STATUS_DISCONNECTED,
    STATUS_REAUTH,
    STATUS_ERROR,
}


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


class ConnectRequest(BaseModel):
    tenant_id: str = Field(min_length=1, max_length=36)
    provider: str = Field(min_length=1, max_length=30)
    external_account_id: str = Field(min_length=1, max_length=120)
    access_token: str = Field(min_length=1)
    bank_name: Optional[str] = None
    account_name: Optional[str] = None
    account_number_masked: Optional[str] = None
    iban_masked: Optional[str] = None
    currency: Optional[str] = None
    refresh_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None


@router.post("/connections")
async def connect_route(req: ConnectRequest, _user_id: str = Depends(_auth)):
    try:
        row_id = connect(
            ConnectionInput(
                tenant_id=req.tenant_id,
                provider=req.provider,
                account=ProviderAccount(
                    external_account_id=req.external_account_id,
                    bank_name=req.bank_name,
                    account_name=req.account_name,
                    account_number_masked=req.account_number_masked,
                    iban_masked=req.iban_masked,
                    currency=req.currency,
                ),
                tokens=ProviderAuthTokens(
                    access_token=req.access_token,
                    refresh_token=req.refresh_token,
                    expires_at=req.token_expires_at,
                ),
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"success": True, "data": {"id": row_id}}


@router.get("/connections")
async def list_connections_route(
    tenant_id: Optional[str] = None,
    provider: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
    _user_id: str = Depends(_auth),
):
    if status is not None and status not in _VALID_STATUS:
        raise HTTPException(
            status_code=400,
            detail=f"status must be one of {sorted(_VALID_STATUS)}",
        )
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 500")
    rows = list_connections(
        tenant_id=tenant_id, provider=provider, status=status, limit=limit
    )
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


@router.get("/connections/{conn_id}")
async def connection_detail(conn_id: str, _user_id: str = Depends(_auth)):
    row = get_connection(conn_id)
    if row is None:
        raise HTTPException(status_code=404, detail="connection not found")
    return {"success": True, "data": row}


@router.post("/connections/{conn_id}/sync")
async def sync_route(conn_id: str, _user_id: str = Depends(_auth)):
    try:
        summary = sync_account(conn_id)
    except LookupError:
        raise HTTPException(status_code=404, detail="connection not found")
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    return {"success": True, "data": summary}


class DisconnectRequest(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=2000)


@router.post("/connections/{conn_id}/disconnect")
async def disconnect_route(
    conn_id: str, body: DisconnectRequest, user_id: str = Depends(_auth)
):
    try:
        disconnect(conn_id, user_id=user_id, reason=body.reason)
    except LookupError:
        raise HTTPException(status_code=404, detail="connection not found")
    return {"success": True, "data": {"id": conn_id, "status": STATUS_DISCONNECTED}}


@router.get("/transactions")
async def list_transactions_route(
    tenant_id: Optional[str] = None,
    connection_id: Optional[str] = None,
    unreconciled_only: bool = False,
    limit: int = 200,
    _user_id: str = Depends(_auth),
):
    if limit < 1 or limit > 1000:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 1000")
    rows = list_transactions(
        tenant_id=tenant_id,
        connection_id=connection_id,
        unreconciled_only=unreconciled_only,
        limit=limit,
    )
    return {"success": True, "data": {"count": len(rows), "rows": rows}}


class ReconcileRequest(BaseModel):
    entity_type: str = Field(min_length=1, max_length=40)
    entity_id: str = Field(min_length=1, max_length=36)


@router.post("/transactions/{txn_id}/reconcile")
async def reconcile_route(
    txn_id: str, body: ReconcileRequest, user_id: str = Depends(_auth)
):
    try:
        mark_reconciled(
            txn_id,
            entity_type=body.entity_type,
            entity_id=body.entity_id,
            user_id=user_id,
        )
    except LookupError:
        raise HTTPException(status_code=404, detail="transaction not found")
    return {"success": True, "data": {"id": txn_id, "matched": True}}


@router.get("/stats")
async def stats_route(tenant_id: Optional[str] = None, _user_id: str = Depends(_auth)):
    return {"success": True, "data": stats(tenant_id=tenant_id)}


@router.get("/providers")
async def providers_route(_user_id: str = Depends(_auth)):
    return {"success": True, "data": {"providers": available_providers()}}
