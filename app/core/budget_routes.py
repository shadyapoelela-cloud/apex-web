"""Budget vs Actual API endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.budget_service import (
    BudgetLineItem, BudgetInput, analyse_budget, to_dict,
)

router = APIRouter(tags=["Budget vs Actual"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class LineItemRequest(BaseModel):
    account_code: str = Field(..., min_length=1, max_length=20)
    account_name: str = Field(..., min_length=1, max_length=200)
    category: str = Field(..., pattern=r"^(revenue|cogs|opex|capex)$")
    budget_amount: str
    actual_amount: str
    prior_year_amount: Optional[str] = None
    notes: str = ""


class BudgetRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period: str = Field(..., min_length=4, max_length=10)
    period_type: str = Field(..., pattern=r"^(monthly|quarterly|annual)$")
    currency: str = Field(default="SAR", max_length=3)
    department: str = ""
    cost_center: str = ""
    line_items: List[LineItemRequest] = Field(..., min_length=1)


@router.post("/budget/analyse")
async def analyse_route(body: BudgetRequest, user_id: str = Depends(_auth)):
    items = [
        BudgetLineItem(
            account_code=li.account_code,
            account_name=li.account_name,
            category=li.category,
            budget_amount=_dec(li.budget_amount, f"item.budget"),
            actual_amount=_dec(li.actual_amount, f"item.actual"),
            prior_year_amount=_dec(li.prior_year_amount, "prior") if li.prior_year_amount else None,
            notes=li.notes,
        )
        for li in body.line_items
    ]
    try:
        result = analyse_budget(BudgetInput(
            entity_name=body.entity_name,
            period=body.period,
            period_type=body.period_type,
            currency=body.currency,
            department=body.department,
            cost_center=body.cost_center,
            line_items=items,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(result)}
