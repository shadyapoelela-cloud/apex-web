"""Lease Accounting (IFRS 16) endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.lease_service import LeaseInput, build_lease, lease_to_dict


router = APIRouter(tags=["Lease Accounting"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class LeaseRequest(BaseModel):
    lease_name: str = Field(..., min_length=1, max_length=200)
    start_date: str = Field(default="", max_length=20)
    term_months: int = Field(..., ge=1, le=600)
    payment_amount: str
    payment_frequency: str = Field(default="monthly", max_length=20)
    annual_ibr_pct: str = "5"
    payment_timing: str = Field(default="end", max_length=10)
    initial_direct_costs: str = "0"
    prepaid_lease_payments: str = "0"
    lease_incentives: str = "0"
    residual_value: str = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/lease/build")
async def build_route(body: LeaseRequest, user_id: str = Depends(_auth)):
    try:
        r = build_lease(LeaseInput(
            lease_name=body.lease_name,
            start_date=body.start_date,
            term_months=body.term_months,
            payment_amount=_dec(body.payment_amount, "payment_amount"),
            payment_frequency=body.payment_frequency,
            annual_ibr_pct=_dec(body.annual_ibr_pct, "annual_ibr_pct"),
            payment_timing=body.payment_timing,
            initial_direct_costs=_dec(body.initial_direct_costs, "initial_direct_costs"),
            prepaid_lease_payments=_dec(body.prepaid_lease_payments, "prepaid_lease_payments"),
            lease_incentives=_dec(body.lease_incentives, "lease_incentives"),
            residual_value=_dec(body.residual_value, "residual_value"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": lease_to_dict(r)}
