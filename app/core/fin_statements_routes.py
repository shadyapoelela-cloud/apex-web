"""Financial Statements endpoints (TB / IS / BS / Close)."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.fin_statements_service import (
    TBLine, TBInput,
    build_trial_balance, build_income_statement, build_balance_sheet,
    generate_closing_entries,
    tb_to_dict, is_to_dict, bs_to_dict, closing_to_dict,
    VALID_CLASSES,
)


router = APIRouter(tags=["Financial Statements"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class TBLineRequest(BaseModel):
    account_code: str = Field(..., min_length=1, max_length=30)
    account_name: str = Field(..., min_length=1, max_length=200)
    classification: str = Field(..., min_length=3, max_length=20)
    debit: Optional[str] = "0"
    credit: Optional[str] = "0"


class TBRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    currency: str = Field(default="SAR", max_length=3)
    lines: List[TBLineRequest] = Field(..., min_length=1)
    opening_retained_earnings: Optional[str] = "0"


def _build_tb_input(body: TBRequest) -> TBInput:
    lines = []
    for i, ln in enumerate(body.lines):
        if ln.classification not in VALID_CLASSES:
            raise HTTPException(
                status_code=422,
                detail=f"lines[{i}].classification must be one of {sorted(VALID_CLASSES)}",
            )
        lines.append(TBLine(
            account_code=ln.account_code,
            account_name=ln.account_name,
            classification=ln.classification,
            debit=_dec(ln.debit, f"lines[{i}].debit"),
            credit=_dec(ln.credit, f"lines[{i}].credit"),
        ))
    return TBInput(
        entity_name=body.entity_name,
        period_label=body.period_label,
        currency=body.currency,
        lines=lines,
        opening_retained_earnings=_dec(body.opening_retained_earnings, "opening_retained_earnings"),
    )


@router.post("/fs/trial-balance")
async def tb_route(body: TBRequest, user_id: str = Depends(_auth)):
    try:
        r = build_trial_balance(_build_tb_input(body))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": tb_to_dict(r)}


@router.post("/fs/income-statement")
async def is_route(body: TBRequest, user_id: str = Depends(_auth)):
    try:
        r = build_income_statement(_build_tb_input(body))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": is_to_dict(r)}


@router.post("/fs/balance-sheet")
async def bs_route(body: TBRequest, user_id: str = Depends(_auth)):
    try:
        r = build_balance_sheet(_build_tb_input(body))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": bs_to_dict(r)}


@router.post("/fs/closing-entries")
async def close_route(body: TBRequest, user_id: str = Depends(_auth)):
    try:
        r = generate_closing_entries(_build_tb_input(body))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": closing_to_dict(r)}


@router.get("/fs/classifications")
async def supported_classifications(user_id: str = Depends(_auth)):
    return {"success": True, "data": sorted(VALID_CLASSES)}
