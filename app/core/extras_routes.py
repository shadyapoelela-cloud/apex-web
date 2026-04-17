"""Advanced IFRS (2/40/41) + Advanced Tax (RETT/P2/VAT-G) + Job Costing routes."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.advanced_ifrs_service import (
    SbpInput, compute_sbp, sbp_to_dict, INSTRUMENT_TYPES, VESTING_PATTERNS,
    InvPropertyInput, compute_investment_property, ip_to_dict, PROPERTY_MODELS,
    AgricultureInput, compute_agriculture, ag_to_dict, BIOLOGICAL_TYPES,
)
from app.core.advanced_tax_service import (
    RettInput, compute_rett, rett_to_dict, PROPERTY_TYPES, TRANSACTION_MODES,
    PillarTwoInput, PillarTwoJurisdiction, compute_pillar_two, p2_to_dict,
    VatGroupInput, VatGroupMember, compute_vat_group, vg_to_dict,
)
from app.core.job_costing_service import (
    JobInput, CostEntry, analyse_job, to_dict as job_to_dict, COST_CATEGORIES,
)


router = APIRouter(tags=["Extras"])


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


# ═══════════════════════════════════════════════════════════════
# IFRS 2 — Share-Based Payments
# ═══════════════════════════════════════════════════════════════


class SbpRequest(BaseModel):
    plan_name: str = Field(..., min_length=1, max_length=200)
    instrument_type: str = "stock_option"
    grant_date: str = Field(default="", max_length=20)
    grant_date_fair_value_per_unit: str
    units_granted: int = Field(..., ge=1)
    vesting_period_years: int = Field(..., ge=1, le=50)
    vesting_pattern: str = "cliff"
    forfeiture_rate_pct: str = "5"
    years_elapsed: int = 0
    currency: str = Field(default="SAR", max_length=3)


@router.post("/sbp/compute")
async def sbp_route(body: SbpRequest, user_id: str = Depends(_auth)):
    if body.instrument_type not in INSTRUMENT_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"instrument_type must be one of {sorted(INSTRUMENT_TYPES)}",
        )
    if body.vesting_pattern not in VESTING_PATTERNS:
        raise HTTPException(
            status_code=422,
            detail=f"vesting_pattern must be one of {sorted(VESTING_PATTERNS)}",
        )
    try:
        r = compute_sbp(SbpInput(
            plan_name=body.plan_name,
            instrument_type=body.instrument_type,
            grant_date=body.grant_date,
            grant_date_fair_value_per_unit=_dec(body.grant_date_fair_value_per_unit, "fv"),
            units_granted=body.units_granted,
            vesting_period_years=body.vesting_period_years,
            vesting_pattern=body.vesting_pattern,
            forfeiture_rate_pct=_dec(body.forfeiture_rate_pct, "forfeiture_rate"),
            years_elapsed=body.years_elapsed,
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": sbp_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# IAS 40 — Investment Property
# ═══════════════════════════════════════════════════════════════


class InvPropRequest(BaseModel):
    property_name: str = Field(..., min_length=1, max_length=200)
    acquisition_cost: str
    useful_life_years: int = 40
    residual_value: str = "0"
    model: str = "fair_value"
    current_fair_value: Optional[str] = None
    years_elapsed: int = 0
    rental_income_annual: str = "0"
    operating_costs_annual: str = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/investment-property/compute")
async def ip_route(body: InvPropRequest, user_id: str = Depends(_auth)):
    if body.model not in PROPERTY_MODELS:
        raise HTTPException(
            status_code=422,
            detail=f"model must be one of {sorted(PROPERTY_MODELS)}",
        )
    try:
        r = compute_investment_property(InvPropertyInput(
            property_name=body.property_name,
            acquisition_cost=_dec(body.acquisition_cost, "acquisition_cost"),
            useful_life_years=body.useful_life_years,
            residual_value=_dec(body.residual_value, "residual_value"),
            model=body.model,
            current_fair_value=_opt_dec(body.current_fair_value, "current_fair_value"),
            years_elapsed=body.years_elapsed,
            rental_income_annual=_dec(body.rental_income_annual, "rental"),
            operating_costs_annual=_dec(body.operating_costs_annual, "op_costs"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": ip_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# IAS 41 — Agriculture
# ═══════════════════════════════════════════════════════════════


class AgriRequest(BaseModel):
    asset_name: str = Field(..., min_length=1, max_length=200)
    biological_type: str = "livestock"
    units: str
    fair_value_per_unit_beginning: str
    fair_value_per_unit_end: str
    costs_to_sell_pct: str = "3"
    costs_incurred: str = "0"
    new_units_born_or_planted: str = "0"
    units_harvested_or_sold: str = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/agriculture/compute")
async def agri_route(body: AgriRequest, user_id: str = Depends(_auth)):
    if body.biological_type not in BIOLOGICAL_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"biological_type must be one of {sorted(BIOLOGICAL_TYPES)}",
        )
    try:
        r = compute_agriculture(AgricultureInput(
            asset_name=body.asset_name,
            biological_type=body.biological_type,
            units=_dec(body.units, "units"),
            fair_value_per_unit_beginning=_dec(body.fair_value_per_unit_beginning, "fv_b"),
            fair_value_per_unit_end=_dec(body.fair_value_per_unit_end, "fv_e"),
            costs_to_sell_pct=_dec(body.costs_to_sell_pct, "cts"),
            costs_incurred=_dec(body.costs_incurred, "costs"),
            new_units_born_or_planted=_dec(body.new_units_born_or_planted, "new"),
            units_harvested_or_sold=_dec(body.units_harvested_or_sold, "harvested"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": ag_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# RETT
# ═══════════════════════════════════════════════════════════════


class RettRequest(BaseModel):
    property_type: str = "residential"
    transaction_mode: str = "sale"
    sale_value: str
    sale_date: str = Field(default="", max_length=20)
    is_first_home: bool = False
    is_family_transfer: bool = False
    is_sharia_compliant_finance: bool = False
    buyer_is_saudi_citizen: bool = False
    currency: str = Field(default="SAR", max_length=3)


@router.post("/rett/compute")
async def rett_route(body: RettRequest, user_id: str = Depends(_auth)):
    if body.property_type not in PROPERTY_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"property_type must be one of {sorted(PROPERTY_TYPES)}",
        )
    if body.transaction_mode not in TRANSACTION_MODES:
        raise HTTPException(
            status_code=422,
            detail=f"transaction_mode must be one of {sorted(TRANSACTION_MODES)}",
        )
    try:
        r = compute_rett(RettInput(
            property_type=body.property_type,
            transaction_mode=body.transaction_mode,
            sale_value=_dec(body.sale_value, "sale_value"),
            sale_date=body.sale_date,
            is_first_home=body.is_first_home,
            is_family_transfer=body.is_family_transfer,
            is_sharia_compliant_finance=body.is_sharia_compliant_finance,
            buyer_is_saudi_citizen=body.buyer_is_saudi_citizen,
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": rett_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# Pillar Two
# ═══════════════════════════════════════════════════════════════


class PillarTwoJurRequest(BaseModel):
    jurisdiction: str = Field(..., min_length=2, max_length=10)
    gloBE_income: str
    covered_taxes: str
    payroll: str = "0"
    tangible_assets: str = "0"


class PillarTwoRequest(BaseModel):
    group_name: str = Field(..., min_length=1, max_length=200)
    fiscal_year: str = Field(..., pattern=r"^\d{4}$")
    group_consolidated_revenue: str
    jurisdictions: List[PillarTwoJurRequest] = Field(..., min_length=1)


@router.post("/pillar-two/compute")
async def p2_route(body: PillarTwoRequest, user_id: str = Depends(_auth)):
    jurs = [
        PillarTwoJurisdiction(
            jurisdiction=j.jurisdiction,
            gloBE_income=_dec(j.gloBE_income, f"jurs[{i}].income"),
            covered_taxes=_dec(j.covered_taxes, f"jurs[{i}].taxes"),
            payroll=_dec(j.payroll, f"jurs[{i}].payroll"),
            tangible_assets=_dec(j.tangible_assets, f"jurs[{i}].tangible"),
        )
        for i, j in enumerate(body.jurisdictions)
    ]
    try:
        r = compute_pillar_two(PillarTwoInput(
            group_name=body.group_name,
            fiscal_year=body.fiscal_year,
            group_consolidated_revenue=_dec(body.group_consolidated_revenue, "group_rev"),
            jurisdictions=jurs,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": p2_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# VAT Group
# ═══════════════════════════════════════════════════════════════


class VatGroupMemberRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    vat_registration: str = Field(default="", max_length=50)
    annual_taxable_supplies: str
    vat_collected: str = "0"
    vat_paid: str = "0"
    intra_group_supplies: str = "0"


class VatGroupRequest(BaseModel):
    group_name: str = Field(..., min_length=1, max_length=200)
    fiscal_period: str = Field(..., min_length=1, max_length=100)
    representative_member: str = Field(..., min_length=1, max_length=200)
    members: List[VatGroupMemberRequest] = Field(..., min_length=1)


@router.post("/vat-group/compute")
async def vg_route(body: VatGroupRequest, user_id: str = Depends(_auth)):
    members = [
        VatGroupMember(
            entity_name=m.entity_name,
            vat_registration=m.vat_registration,
            annual_taxable_supplies=_dec(m.annual_taxable_supplies, f"m[{i}].supplies"),
            vat_collected=_dec(m.vat_collected, f"m[{i}].collected"),
            vat_paid=_dec(m.vat_paid, f"m[{i}].paid"),
            intra_group_supplies=_dec(m.intra_group_supplies, f"m[{i}].intra"),
        )
        for i, m in enumerate(body.members)
    ]
    try:
        r = compute_vat_group(VatGroupInput(
            group_name=body.group_name,
            fiscal_period=body.fiscal_period,
            representative_member=body.representative_member,
            members=members,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": vg_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# Job Costing
# ═══════════════════════════════════════════════════════════════


class CostEntryRequest(BaseModel):
    category: str = Field(..., min_length=1, max_length=30)
    description: str = Field(..., min_length=1, max_length=200)
    budgeted: str
    actual: str = "0"


class JobRequest(BaseModel):
    project_name: str = Field(..., min_length=1, max_length=200)
    project_code: str = Field(..., min_length=1, max_length=50)
    contract_value: str
    contract_start_date: str = Field(default="", max_length=20)
    estimated_end_date: str = Field(default="", max_length=20)
    costs: List[CostEntryRequest] = Field(..., min_length=1)
    additional_eac: str = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/job/analyse")
async def job_route(body: JobRequest, user_id: str = Depends(_auth)):
    for i, c in enumerate(body.costs):
        if c.category not in COST_CATEGORIES:
            raise HTTPException(
                status_code=422,
                detail=f"costs[{i}].category must be one of {sorted(COST_CATEGORIES)}",
            )
    costs = [
        CostEntry(
            category=c.category,
            description=c.description,
            budgeted=_dec(c.budgeted, f"c[{i}].budgeted"),
            actual=_dec(c.actual, f"c[{i}].actual"),
        )
        for i, c in enumerate(body.costs)
    ]
    try:
        r = analyse_job(JobInput(
            project_name=body.project_name,
            project_code=body.project_code,
            contract_value=_dec(body.contract_value, "contract_value"),
            contract_start_date=body.contract_start_date,
            estimated_end_date=body.estimated_end_date,
            costs=costs,
            additional_eac=_dec(body.additional_eac, "additional_eac"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": job_to_dict(r)}


@router.get("/extras/enums")
async def enums(user_id: str = Depends(_auth)):
    return {
        "success": True,
        "data": {
            "sbp_instruments": sorted(INSTRUMENT_TYPES),
            "sbp_vesting": sorted(VESTING_PATTERNS),
            "property_models": sorted(PROPERTY_MODELS),
            "biological_types": sorted(BIOLOGICAL_TYPES),
            "property_types": sorted(PROPERTY_TYPES),
            "rett_transaction_modes": sorted(TRANSACTION_MODES),
            "cost_categories": sorted(COST_CATEGORIES),
        },
    }
