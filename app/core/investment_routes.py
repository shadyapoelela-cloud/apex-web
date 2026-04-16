"""Investment (NPV/IRR) + Budget variance endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.investment_service import (
    InvestmentInput,
    compute_investment,
    result_to_dict as inv_to_dict,
)
from app.core.budget_service import (
    BudgetInput,
    BudgetLineInput,
    compute_budget,
    result_to_dict as bud_to_dict,
)

router = APIRouter(tags=["Investment & Budget"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v: Optional[str], name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


# ═══════════════════════════════════════════════════════════════
# NPV / IRR
# ═══════════════════════════════════════════════════════════════


class InvestmentRequest(BaseModel):
    period_label: str = Field(default="Project", max_length=100)
    period_unit: str = Field(default="year", pattern="^(year|quarter|month)$")
    cash_flows: List[str] = Field(..., min_length=2, description="Period-0 first")
    discount_rate: str = Field(default="0.10")


@router.post("/investment/analyze")
async def analyze_route(
    body: InvestmentRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    cfs = [_dec(v, f"cash_flows[{i}]") for i, v in enumerate(body.cash_flows)]
    rate = _dec(body.discount_rate, "discount_rate")
    try:
        result = compute_investment(InvestmentInput(
            period_label=body.period_label,
            period_unit=body.period_unit,
            cash_flows=cfs,
            discount_rate=rate,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="investment.analyze",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="investment_project",
        entity_id=body.period_label,
        metadata={
            "npv": f"{result.npv}",
            "irr_pct": None if result.irr_pct is None else f"{result.irr_pct}",
            "decision": result.decision,
        },
    )
    return {"success": True, "data": inv_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Budget vs Actual
# ═══════════════════════════════════════════════════════════════


class BudgetLineRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    kind: str = Field(..., pattern="^(revenue|expense)$")
    budget: str
    actual: str


class BudgetRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    lines: List[BudgetLineRequest] = Field(..., min_length=1)


@router.post("/budget/variance")
async def variance_route(
    body: BudgetRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    input_lines = [
        BudgetLineInput(
            name=ln.name,
            kind=ln.kind,
            budget=_dec(ln.budget, f"lines[{i}].budget"),
            actual=_dec(ln.actual, f"lines[{i}].actual"),
        )
        for i, ln in enumerate(body.lines)
    ]
    try:
        result = compute_budget(BudgetInput(
            period_label=body.period_label,
            lines=input_lines,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="budget.variance",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="budget_analysis",
        entity_id=body.period_label,
        metadata={
            "net_variance": f"{result.net_variance}",
            "lines_count": len(result.lines),
        },
    )
    return {"success": True, "data": bud_to_dict(result)}
