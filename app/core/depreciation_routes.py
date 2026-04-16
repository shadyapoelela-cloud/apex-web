"""
APEX Platform — Depreciation route.

Endpoint:
  POST /depreciation/compute
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.depreciation_service import (
    DepreciationInput,
    compute_depreciation,
    result_to_dict,
)

router = APIRouter(prefix="/depreciation", tags=["Depreciation"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _decimal(value: str, field_name: str) -> Decimal:
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {field_name}: {value!r}")


class DepreciationRequest(BaseModel):
    cost: str = Field(..., description="Asset cost (Decimal as string)")
    salvage_value: str = Field(default="0")
    useful_life_years: int = Field(..., ge=1, le=50)
    method: str = Field(
        default="straight_line",
        pattern="^(straight_line|declining_balance|sum_of_years_digits)$",
    )
    asset_name: str = Field(default="", max_length=200)
    first_year_months: int = Field(default=12, ge=1, le=12)


@router.post("/compute")
async def compute_route(
    body: DepreciationRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = DepreciationInput(
        cost=_decimal(body.cost, "cost"),
        salvage_value=_decimal(body.salvage_value, "salvage_value"),
        useful_life_years=body.useful_life_years,
        method=body.method,
        asset_name=body.asset_name,
        first_year_months=body.first_year_months,
    )
    try:
        result = compute_depreciation(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="depreciation.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="depreciation_schedule",
        entity_id=body.asset_name or "unnamed",
        metadata={
            "method": result.method,
            "cost": f"{result.cost}",
            "total_depreciation": f"{result.total_depreciation}",
        },
    )
    return {"success": True, "data": result_to_dict(result)}
