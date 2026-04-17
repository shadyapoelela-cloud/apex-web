"""Cost Accounting / Variance Analysis endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.cost_accounting_service import (
    MaterialVarianceInput, LabourVarianceInput, OverheadVarianceInput,
    ComprehensiveVarianceInput,
    analyse_material, analyse_labour, analyse_overhead, analyse_comprehensive,
    material_to_dict, labour_to_dict, overhead_to_dict, comprehensive_to_dict,
)


router = APIRouter(tags=["Cost Accounting"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class MaterialVarianceRequest(BaseModel):
    item_name: str = Field(..., min_length=1, max_length=200)
    std_price: str
    std_qty_per_output: str
    actual_price: str
    actual_qty_used: str
    output_units: str
    currency: str = Field(default="SAR", max_length=3)


@router.post("/cost/variance/material")
async def material_route(body: MaterialVarianceRequest, user_id: str = Depends(_auth)):
    try:
        r = analyse_material(MaterialVarianceInput(
            item_name=body.item_name,
            std_price=_dec(body.std_price, "std_price"),
            std_qty_per_output=_dec(body.std_qty_per_output, "std_qty_per_output"),
            actual_price=_dec(body.actual_price, "actual_price"),
            actual_qty_used=_dec(body.actual_qty_used, "actual_qty_used"),
            output_units=_dec(body.output_units, "output_units"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": material_to_dict(r)}


class LabourVarianceRequest(BaseModel):
    cost_center: str = Field(..., min_length=1, max_length=200)
    std_rate_per_hour: str
    std_hours_per_output: str
    actual_rate_per_hour: str
    actual_hours: str
    output_units: str
    currency: str = Field(default="SAR", max_length=3)


@router.post("/cost/variance/labour")
async def labour_route(body: LabourVarianceRequest, user_id: str = Depends(_auth)):
    try:
        r = analyse_labour(LabourVarianceInput(
            cost_center=body.cost_center,
            std_rate_per_hour=_dec(body.std_rate_per_hour, "std_rate_per_hour"),
            std_hours_per_output=_dec(body.std_hours_per_output, "std_hours_per_output"),
            actual_rate_per_hour=_dec(body.actual_rate_per_hour, "actual_rate_per_hour"),
            actual_hours=_dec(body.actual_hours, "actual_hours"),
            output_units=_dec(body.output_units, "output_units"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": labour_to_dict(r)}


class OverheadVarianceRequest(BaseModel):
    cost_center: str = Field(..., min_length=1, max_length=200)
    budgeted_overhead: str
    actual_overhead: str
    std_rate_per_hour: str
    std_hours_per_output: str
    actual_hours: str
    output_units: str
    currency: str = Field(default="SAR", max_length=3)


@router.post("/cost/variance/overhead")
async def overhead_route(body: OverheadVarianceRequest, user_id: str = Depends(_auth)):
    try:
        r = analyse_overhead(OverheadVarianceInput(
            cost_center=body.cost_center,
            budgeted_overhead=_dec(body.budgeted_overhead, "budgeted_overhead"),
            actual_overhead=_dec(body.actual_overhead, "actual_overhead"),
            std_rate_per_hour=_dec(body.std_rate_per_hour, "std_rate_per_hour"),
            std_hours_per_output=_dec(body.std_hours_per_output, "std_hours_per_output"),
            actual_hours=_dec(body.actual_hours, "actual_hours"),
            output_units=_dec(body.output_units, "output_units"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": overhead_to_dict(r)}


class ComprehensiveVarianceRequest(BaseModel):
    period_label: str = Field(..., min_length=1, max_length=100)
    output_units: str
    material: Optional[MaterialVarianceRequest] = None
    labour: Optional[LabourVarianceRequest] = None
    overhead: Optional[OverheadVarianceRequest] = None


@router.post("/cost/variance/comprehensive")
async def comprehensive_route(
    body: ComprehensiveVarianceRequest, user_id: str = Depends(_auth),
):
    def _mat(m: Optional[MaterialVarianceRequest]):
        if m is None:
            return None
        return MaterialVarianceInput(
            item_name=m.item_name,
            std_price=_dec(m.std_price, "material.std_price"),
            std_qty_per_output=_dec(m.std_qty_per_output, "material.std_qty_per_output"),
            actual_price=_dec(m.actual_price, "material.actual_price"),
            actual_qty_used=_dec(m.actual_qty_used, "material.actual_qty_used"),
            output_units=_dec(m.output_units, "material.output_units"),
            currency=m.currency,
        )

    def _lab(ln: Optional[LabourVarianceRequest]):
        if ln is None:
            return None
        return LabourVarianceInput(
            cost_center=ln.cost_center,
            std_rate_per_hour=_dec(ln.std_rate_per_hour, "labour.std_rate_per_hour"),
            std_hours_per_output=_dec(ln.std_hours_per_output, "labour.std_hours_per_output"),
            actual_rate_per_hour=_dec(ln.actual_rate_per_hour, "labour.actual_rate_per_hour"),
            actual_hours=_dec(ln.actual_hours, "labour.actual_hours"),
            output_units=_dec(ln.output_units, "labour.output_units"),
            currency=ln.currency,
        )

    def _oh(o: Optional[OverheadVarianceRequest]):
        if o is None:
            return None
        return OverheadVarianceInput(
            cost_center=o.cost_center,
            budgeted_overhead=_dec(o.budgeted_overhead, "overhead.budgeted_overhead"),
            actual_overhead=_dec(o.actual_overhead, "overhead.actual_overhead"),
            std_rate_per_hour=_dec(o.std_rate_per_hour, "overhead.std_rate_per_hour"),
            std_hours_per_output=_dec(o.std_hours_per_output, "overhead.std_hours_per_output"),
            actual_hours=_dec(o.actual_hours, "overhead.actual_hours"),
            output_units=_dec(o.output_units, "overhead.output_units"),
            currency=o.currency,
        )

    try:
        r = analyse_comprehensive(ComprehensiveVarianceInput(
            period_label=body.period_label,
            output_units=_dec(body.output_units, "output_units"),
            material=_mat(body.material),
            labour=_lab(body.labour),
            overhead=_oh(body.overhead),
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": comprehensive_to_dict(r)}
