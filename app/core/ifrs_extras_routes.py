"""Additional IFRS endpoints: Revenue 15, EOSB/IAS 19, Impairment 36,
ECL 9, Provisions 37."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.revenue_service import (
    PerformanceObligation, ContractInput, recognise_revenue,
    to_dict as rev_to_dict, RECOGNITION_PATTERNS,
)
from app.core.eosb_service import (
    EosbInput, compute_eosb, to_dict as eosb_to_dict, TERMINATION_REASONS,
)
from app.core.impairment_service import (
    ImpairmentInput, test_impairment, to_dict as imp_to_dict,
)
from app.core.ecl_service import (
    ReceivableBucket, EclInput, compute_ecl, to_dict as ecl_to_dict,
    AGING_BUCKETS, DEFAULT_PD_MATRIX,
)
from app.core.provisions_service import (
    ProvisionItem, ProvisionsInput, classify_provisions,
    to_dict as prov_to_dict, PROBABILITY_LEVELS, ITEM_TYPES,
)


router = APIRouter(tags=["IFRS Extras"])


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
# IFRS 15 — Revenue Recognition
# ═══════════════════════════════════════════════════════════════


class POrequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=200)
    standalone_selling_price: str
    recognition_pattern: str = "point_in_time"
    period_months: int = 0
    progress_pct: Optional[str] = None
    satisfied: bool = False


class ContractRequest(BaseModel):
    contract_id: str = Field(..., min_length=1, max_length=100)
    customer: str = Field(..., min_length=1, max_length=200)
    contract_date: str = Field(default="", max_length=20)
    transaction_price: str
    variable_consideration: str = "0"
    months_elapsed: int = 0
    currency: str = Field(default="SAR", max_length=3)
    obligations: List[POrequest] = Field(..., min_length=1)


@router.post("/revenue/recognise")
async def rev_route(body: ContractRequest, user_id: str = Depends(_auth)):
    obs = []
    for i, o in enumerate(body.obligations):
        if o.recognition_pattern not in RECOGNITION_PATTERNS:
            raise HTTPException(
                status_code=422,
                detail=f"obligations[{i}].recognition_pattern must be one of {sorted(RECOGNITION_PATTERNS)}",
            )
        obs.append(PerformanceObligation(
            description=o.description,
            standalone_selling_price=_dec(o.standalone_selling_price, f"obligations[{i}].ssp"),
            recognition_pattern=o.recognition_pattern,
            period_months=o.period_months,
            progress_pct=_opt_dec(o.progress_pct, f"obligations[{i}].progress_pct"),
            satisfied=o.satisfied,
        ))
    try:
        r = recognise_revenue(ContractInput(
            contract_id=body.contract_id,
            customer=body.customer,
            contract_date=body.contract_date,
            transaction_price=_dec(body.transaction_price, "transaction_price"),
            variable_consideration=_dec(body.variable_consideration, "variable_consideration"),
            months_elapsed=body.months_elapsed,
            currency=body.currency,
            obligations=obs,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": rev_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# IAS 19 — End of Service Benefits
# ═══════════════════════════════════════════════════════════════


class EosbRequest(BaseModel):
    employee_name: str = Field(..., min_length=1, max_length=200)
    employee_id: str = Field(..., min_length=1, max_length=50)
    monthly_basic_salary: str
    monthly_allowances: str = "0"
    years_of_service: str = "0"
    termination_reason: str = "employer_terminated"
    currency: str = Field(default="SAR", max_length=3)
    discount_rate_pct: str = "4"
    wage_growth_pct: str = "3"
    expected_future_years: str = "0"


@router.post("/eosb/compute")
async def eosb_route(body: EosbRequest, user_id: str = Depends(_auth)):
    if body.termination_reason not in TERMINATION_REASONS:
        raise HTTPException(
            status_code=422,
            detail=f"termination_reason must be one of {sorted(TERMINATION_REASONS)}",
        )
    try:
        r = compute_eosb(EosbInput(
            employee_name=body.employee_name,
            employee_id=body.employee_id,
            monthly_basic_salary=_dec(body.monthly_basic_salary, "monthly_basic_salary"),
            monthly_allowances=_dec(body.monthly_allowances, "monthly_allowances"),
            years_of_service=_dec(body.years_of_service, "years_of_service"),
            termination_reason=body.termination_reason,
            currency=body.currency,
            discount_rate_pct=_dec(body.discount_rate_pct, "discount_rate_pct"),
            wage_growth_pct=_dec(body.wage_growth_pct, "wage_growth_pct"),
            expected_future_years=_dec(body.expected_future_years, "expected_future_years"),
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": eosb_to_dict(r)}


@router.get("/eosb/reasons")
async def eosb_reasons(user_id: str = Depends(_auth)):
    return {"success": True, "data": sorted(TERMINATION_REASONS)}


# ═══════════════════════════════════════════════════════════════
# IAS 36 — Impairment
# ═══════════════════════════════════════════════════════════════


class ImpairmentRequest(BaseModel):
    asset_name: str = Field(..., min_length=1, max_length=200)
    asset_class: str = Field(..., min_length=1, max_length=30)
    carrying_amount: str
    fair_value_less_costs_to_sell: Optional[str] = None
    future_cash_flows: Optional[List[str]] = None
    discount_rate_pct: str = "10"
    terminal_value: str = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/impairment/test")
async def imp_route(body: ImpairmentRequest, user_id: str = Depends(_auth)):
    cf_list = []
    if body.future_cash_flows:
        cf_list = [_dec(v, f"future_cash_flows[{i}]") for i, v in enumerate(body.future_cash_flows)]
    try:
        r = test_impairment(ImpairmentInput(
            asset_name=body.asset_name,
            asset_class=body.asset_class,
            carrying_amount=_dec(body.carrying_amount, "carrying_amount"),
            fair_value_less_costs_to_sell=_opt_dec(body.fair_value_less_costs_to_sell, "fv"),
            future_cash_flows=cf_list,
            discount_rate_pct=_dec(body.discount_rate_pct, "discount_rate_pct"),
            terminal_value=_dec(body.terminal_value, "terminal_value"),
            currency=body.currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": imp_to_dict(r)}


# ═══════════════════════════════════════════════════════════════
# IFRS 9 — ECL
# ═══════════════════════════════════════════════════════════════


class BucketRequest(BaseModel):
    bucket: str = Field(..., min_length=1, max_length=20)
    exposure: str
    pd_override_pct: Optional[str] = None
    lgd_pct: str = "50"


class EclRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    currency: str = Field(default="SAR", max_length=3)
    custom_pd_matrix: Optional[Dict[str, str]] = None
    buckets: List[BucketRequest] = Field(..., min_length=1)


@router.post("/ecl/compute")
async def ecl_route(body: EclRequest, user_id: str = Depends(_auth)):
    custom = None
    if body.custom_pd_matrix:
        custom = {k: _dec(v, f"custom_pd[{k}]") for k, v in body.custom_pd_matrix.items()}
    buckets = [
        ReceivableBucket(
            bucket=b.bucket,
            exposure=_dec(b.exposure, f"buckets[{i}].exposure"),
            pd_override_pct=_opt_dec(b.pd_override_pct, f"buckets[{i}].pd_override_pct"),
            lgd_pct=_dec(b.lgd_pct, f"buckets[{i}].lgd_pct"),
        )
        for i, b in enumerate(body.buckets)
    ]
    try:
        r = compute_ecl(EclInput(
            entity_name=body.entity_name,
            period_label=body.period_label,
            currency=body.currency,
            custom_pd_matrix=custom,
            buckets=buckets,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": ecl_to_dict(r)}


@router.get("/ecl/defaults")
async def ecl_defaults(user_id: str = Depends(_auth)):
    return {
        "success": True,
        "data": {
            "buckets": AGING_BUCKETS,
            "default_pd_matrix": {k: f"{v}" for k, v in DEFAULT_PD_MATRIX.items()},
        },
    }


# ═══════════════════════════════════════════════════════════════
# IAS 37 — Provisions
# ═══════════════════════════════════════════════════════════════


class ProvItemRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=300)
    item_type: str = "liability"
    probability: str = "probable"
    best_estimate: str
    can_estimate_reliably: bool = True
    years_to_settlement: str = "0"
    discount_rate_pct: str = "5"


class ProvRequest(BaseModel):
    entity_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    currency: str = Field(default="SAR", max_length=3)
    items: List[ProvItemRequest] = Field(..., min_length=1)


@router.post("/provisions/classify")
async def prov_route(body: ProvRequest, user_id: str = Depends(_auth)):
    for i, it in enumerate(body.items):
        if it.item_type not in ITEM_TYPES:
            raise HTTPException(
                status_code=422,
                detail=f"items[{i}].item_type must be one of {sorted(ITEM_TYPES)}",
            )
        if it.probability not in PROBABILITY_LEVELS:
            raise HTTPException(
                status_code=422,
                detail=f"items[{i}].probability must be one of {sorted(PROBABILITY_LEVELS)}",
            )
    items = [
        ProvisionItem(
            description=it.description,
            item_type=it.item_type,
            probability=it.probability,
            best_estimate=_dec(it.best_estimate, f"items[{i}].best_estimate"),
            can_estimate_reliably=it.can_estimate_reliably,
            years_to_settlement=_dec(it.years_to_settlement, f"items[{i}].years"),
            discount_rate_pct=_dec(it.discount_rate_pct, f"items[{i}].rate"),
        )
        for i, it in enumerate(body.items)
    ]
    try:
        r = classify_provisions(ProvisionsInput(
            entity_name=body.entity_name,
            period_label=body.period_label,
            currency=body.currency,
            items=items,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": prov_to_dict(r)}


@router.get("/provisions/levels")
async def prov_levels(user_id: str = Depends(_auth)):
    return {
        "success": True,
        "data": {
            "probabilities": sorted(PROBABILITY_LEVELS),
            "item_types": sorted(ITEM_TYPES),
        },
    }
