"""Deferred Tax (IAS 12) endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.deferred_tax_service import (
    TDItem, DeferredTaxInput, compute_deferred_tax, dt_to_dict, TD_CATEGORIES,
)


router = APIRouter(tags=["Deferred Tax"])


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


class TDItemRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=200)
    category: str = Field(..., min_length=3, max_length=30)
    carrying_amount: str = "0"
    tax_base: str = "0"
    expiry_years: Optional[int] = None


class DTRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    tax_rate_pct: str = "20"
    zakat_rate_pct: str = "2.5"
    expected_future_profit: Optional[str] = None
    currency: str = Field(default="SAR", max_length=3)
    opening_dta: str = "0"
    opening_dtl: str = "0"
    items: List[TDItemRequest] = Field(..., min_length=1)


@router.post("/dt/compute")
async def compute_route(body: DTRequest, user_id: str = Depends(_auth)):
    for i, it in enumerate(body.items):
        if it.category not in TD_CATEGORIES:
            raise HTTPException(
                status_code=422,
                detail=f"items[{i}].category must be one of {sorted(TD_CATEGORIES)}",
            )
    items = [
        TDItem(
            description=it.description,
            category=it.category,
            carrying_amount=_dec(it.carrying_amount, f"items[{i}].carrying_amount"),
            tax_base=_dec(it.tax_base, f"items[{i}].tax_base"),
            expiry_years=it.expiry_years,
        )
        for i, it in enumerate(body.items)
    ]
    try:
        r = compute_deferred_tax(DeferredTaxInput(
            entity_name=body.entity_name,
            period_label=body.period_label,
            tax_rate_pct=_dec(body.tax_rate_pct, "tax_rate_pct"),
            zakat_rate_pct=_dec(body.zakat_rate_pct, "zakat_rate_pct"),
            expected_future_profit=_opt_dec(body.expected_future_profit, "expected_future_profit"),
            currency=body.currency,
            opening_dta=_dec(body.opening_dta, "opening_dta"),
            opening_dtl=_dec(body.opening_dtl, "opening_dtl"),
            items=items,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": dt_to_dict(r)}


@router.get("/dt/categories")
async def categories(user_id: str = Depends(_auth)):
    return {"success": True, "data": sorted(TD_CATEGORIES)}
