"""Transfer Pricing endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.transfer_pricing_service import (
    TPTransaction, TPInput, analyse_transfer_pricing, to_dict,
    TP_METHODS, TRANSACTION_TYPES,
)


router = APIRouter(tags=["Transfer Pricing"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class TPTxnRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=300)
    transaction_type: str = Field(..., min_length=1, max_length=30)
    related_party_name: str = Field(..., min_length=1, max_length=200)
    related_party_jurisdiction: str = Field(..., min_length=2, max_length=10)
    method: str = Field(..., min_length=1, max_length=30)
    controlled_price: str
    arm_length_lower: str
    arm_length_upper: str
    arm_length_median: str
    currency: str = Field(default="SAR", max_length=3)


class TPRequest(BaseModel):
    group_name: str = Field(..., min_length=1, max_length=200)
    local_entity_name: str = Field(..., min_length=1, max_length=200)
    fiscal_year: str = Field(..., pattern=r"^\d{4}$")
    group_consolidated_revenue: str = "0"
    local_entity_revenue: str = "0"
    transactions: List[TPTxnRequest] = Field(..., min_length=1)


@router.post("/tp/analyse")
async def analyse_route(body: TPRequest, user_id: str = Depends(_auth)):
    for i, t in enumerate(body.transactions):
        if t.transaction_type not in TRANSACTION_TYPES:
            raise HTTPException(
                status_code=422,
                detail=f"transactions[{i}].transaction_type must be one of {sorted(TRANSACTION_TYPES)}",
            )
        if t.method not in TP_METHODS:
            raise HTTPException(
                status_code=422,
                detail=f"transactions[{i}].method must be one of {sorted(TP_METHODS)}",
            )
    txns = [
        TPTransaction(
            description=t.description,
            transaction_type=t.transaction_type,
            related_party_name=t.related_party_name,
            related_party_jurisdiction=t.related_party_jurisdiction,
            method=t.method,
            controlled_price=_dec(t.controlled_price, f"txn[{i}].cp"),
            arm_length_lower=_dec(t.arm_length_lower, f"txn[{i}].lo"),
            arm_length_upper=_dec(t.arm_length_upper, f"txn[{i}].hi"),
            arm_length_median=_dec(t.arm_length_median, f"txn[{i}].med"),
            currency=t.currency,
        )
        for i, t in enumerate(body.transactions)
    ]
    try:
        r = analyse_transfer_pricing(TPInput(
            group_name=body.group_name,
            local_entity_name=body.local_entity_name,
            fiscal_year=body.fiscal_year,
            group_consolidated_revenue=_dec(body.group_consolidated_revenue, "group_rev"),
            local_entity_revenue=_dec(body.local_entity_revenue, "local_rev"),
            transactions=txns,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(r)}


@router.get("/tp/methods")
async def methods(user_id: str = Depends(_auth)):
    return {
        "success": True,
        "data": {
            "methods": sorted(TP_METHODS),
            "transaction_types": sorted(TRANSACTION_TYPES),
        },
    }
