"""Withholding Tax (WHT) endpoints — Saudi Arabia."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.wht_service import (
    WHTInput, WHTBatchInput, WHTBatchItem,
    compute_wht, compute_wht_batch,
    wht_to_dict, batch_to_dict,
    default_rates, PAYMENT_CATEGORIES,
)


router = APIRouter(tags=["Withholding Tax"])


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


class WHTComputeRequest(BaseModel):
    payment_category: str = Field(..., min_length=1, max_length=50)
    amount: str
    is_gross: bool = True
    treaty_rate_pct: Optional[str] = None
    rate_override_pct: Optional[str] = None
    currency: str = Field(default="SAR", max_length=3)
    vendor_name: str = Field(default="", max_length=200)
    reference: str = Field(default="", max_length=100)


@router.post("/wht/compute")
async def compute_route(body: WHTComputeRequest, user_id: str = Depends(_auth)):
    try:
        r = compute_wht(WHTInput(
            payment_category=body.payment_category,
            amount=_dec(body.amount, "amount"),
            is_gross=body.is_gross,
            treaty_rate_pct=_opt_dec(body.treaty_rate_pct, "treaty_rate_pct"),
            rate_override_pct=_opt_dec(body.rate_override_pct, "rate_override_pct"),
            currency=body.currency,
            vendor_name=body.vendor_name,
            reference=body.reference,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": wht_to_dict(r)}


class WHTBatchItemRequest(BaseModel):
    payment_category: str = Field(..., min_length=1, max_length=50)
    amount: str
    vendor_name: str = Field(default="", max_length=200)
    reference: str = Field(default="", max_length=100)
    is_gross: bool = True
    treaty_rate_pct: Optional[str] = None
    rate_override_pct: Optional[str] = None


class WHTBatchRequest(BaseModel):
    currency: str = Field(default="SAR", max_length=3)
    period_label: str = Field(default="", max_length=100)
    custom_rates: Optional[Dict[str, str]] = None
    items: List[WHTBatchItemRequest] = Field(..., min_length=1)


@router.post("/wht/batch")
async def batch_route(body: WHTBatchRequest, user_id: str = Depends(_auth)):
    custom: Optional[Dict[str, Decimal]] = None
    if body.custom_rates:
        custom = {k: _dec(v, f"custom_rates[{k}]") for k, v in body.custom_rates.items()}
    items = [
        WHTBatchItem(
            payment_category=it.payment_category,
            amount=_dec(it.amount, f"items[{i}].amount"),
            vendor_name=it.vendor_name,
            reference=it.reference,
            is_gross=it.is_gross,
            treaty_rate_pct=_opt_dec(it.treaty_rate_pct, f"items[{i}].treaty_rate_pct"),
            rate_override_pct=_opt_dec(it.rate_override_pct, f"items[{i}].rate_override_pct"),
        )
        for i, it in enumerate(body.items)
    ]
    try:
        r = compute_wht_batch(WHTBatchInput(
            currency=body.currency,
            period_label=body.period_label,
            custom_rates=custom,
            items=items,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": batch_to_dict(r)}


@router.get("/wht/categories")
async def categories(user_id: str = Depends(_auth)):
    return {"success": True, "data": PAYMENT_CATEGORIES}


@router.get("/wht/rates")
async def rates(user_id: str = Depends(_auth)):
    return {"success": True, "data": {k: f"{v}" for k, v in default_rates().items()}}
