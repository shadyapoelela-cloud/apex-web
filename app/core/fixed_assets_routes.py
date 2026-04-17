"""Fixed Assets Register endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.fixed_assets_service import (
    AssetInput, build_asset, to_dict,
    DEPRECIATION_METHODS, DISPOSAL_METHODS,
)


router = APIRouter(tags=["Fixed Assets"])


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


class AssetRequest(BaseModel):
    asset_code: str = Field(..., min_length=1, max_length=50)
    asset_name: str = Field(..., min_length=1, max_length=200)
    asset_class: str = Field(default="ppe", max_length=30)
    acquisition_date: str = Field(default="", max_length=20)
    acquisition_cost: str
    initial_direct_costs: str = "0"
    useful_life_years: int = Field(default=5, ge=1, le=100)
    residual_value: str = "0"
    depreciation_method: str = "straight_line"
    currency: str = Field(default="SAR", max_length=3)
    total_units_expected: Optional[str] = None
    units_produced: Optional[str] = None
    revaluation_amount: Optional[str] = None
    revaluation_years_elapsed: Optional[int] = None
    impairment_loss: str = "0"
    disposal_method: Optional[str] = None
    disposal_date: Optional[str] = None
    disposal_proceeds: str = "0"
    years_elapsed_at_disposal: Optional[int] = None


@router.post("/fa/build")
async def build_route(body: AssetRequest, user_id: str = Depends(_auth)):
    if body.depreciation_method not in DEPRECIATION_METHODS:
        raise HTTPException(
            status_code=422,
            detail=f"depreciation_method must be one of {sorted(DEPRECIATION_METHODS)}",
        )
    if body.disposal_method is not None and body.disposal_method not in DISPOSAL_METHODS:
        raise HTTPException(
            status_code=422,
            detail=f"disposal_method must be one of {sorted(DISPOSAL_METHODS)}",
        )
    try:
        r = build_asset(AssetInput(
            asset_code=body.asset_code,
            asset_name=body.asset_name,
            asset_class=body.asset_class,
            acquisition_date=body.acquisition_date,
            acquisition_cost=_dec(body.acquisition_cost, "acquisition_cost"),
            initial_direct_costs=_dec(body.initial_direct_costs, "initial_direct_costs"),
            useful_life_years=body.useful_life_years,
            residual_value=_dec(body.residual_value, "residual_value"),
            depreciation_method=body.depreciation_method,
            currency=body.currency,
            total_units_expected=_opt_dec(body.total_units_expected, "total_units_expected"),
            units_produced=_opt_dec(body.units_produced, "units_produced"),
            revaluation_amount=_opt_dec(body.revaluation_amount, "revaluation_amount"),
            revaluation_years_elapsed=body.revaluation_years_elapsed,
            impairment_loss=_dec(body.impairment_loss, "impairment_loss"),
            disposal_method=body.disposal_method,
            disposal_date=body.disposal_date,
            disposal_proceeds=_dec(body.disposal_proceeds, "disposal_proceeds"),
            years_elapsed_at_disposal=body.years_elapsed_at_disposal,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(r)}


@router.get("/fa/methods")
async def methods(user_id: str = Depends(_auth)):
    return {
        "success": True,
        "data": {
            "depreciation_methods": sorted(DEPRECIATION_METHODS),
            "disposal_methods": sorted(DISPOSAL_METHODS),
        },
    }
