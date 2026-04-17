"""Full Cash Flow Statement endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.cashflow_statement_service import (
    CFSLine, CFSInput, build_cash_flow_statement, cfs_to_dict, CFS_CLASSES,
)


router = APIRouter(tags=["Cash Flow Statement"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


def _opt_dec(v, name: str) -> Optional[Decimal]:
    if v is None or v == "":
        return None
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class CFSLineRequest(BaseModel):
    account_code: str = Field(..., min_length=1, max_length=30)
    account_name: str = Field(..., min_length=1, max_length=200)
    cfs_class: str = Field(..., min_length=3, max_length=20)
    opening_balance: str = "0"
    closing_balance: str = "0"
    explicit_flow: Optional[str] = None


class CFSRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    currency: str = Field(default="SAR", max_length=3)
    net_income: str = "0"
    lines: List[CFSLineRequest] = Field(..., min_length=1)


@router.post("/cfs/build")
async def build_route(body: CFSRequest, user_id: str = Depends(_auth)):
    lines: List[CFSLine] = []
    for i, ln in enumerate(body.lines):
        if ln.cfs_class not in CFS_CLASSES:
            raise HTTPException(
                status_code=422,
                detail=f"lines[{i}].cfs_class must be one of {sorted(CFS_CLASSES)}",
            )
        lines.append(CFSLine(
            account_code=ln.account_code,
            account_name=ln.account_name,
            cfs_class=ln.cfs_class,
            opening_balance=_dec(ln.opening_balance, f"lines[{i}].opening_balance"),
            closing_balance=_dec(ln.closing_balance, f"lines[{i}].closing_balance"),
            explicit_flow=_opt_dec(ln.explicit_flow, f"lines[{i}].explicit_flow"),
        ))
    try:
        r = build_cash_flow_statement(CFSInput(
            entity_name=body.entity_name,
            period_label=body.period_label,
            currency=body.currency,
            net_income=_dec(body.net_income, "net_income"),
            lines=lines,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": cfs_to_dict(r)}


@router.get("/cfs/classifications")
async def classifications(user_id: str = Depends(_auth)):
    return {"success": True, "data": sorted(CFS_CLASSES)}
