"""Working Capital + Health Score endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.working_capital_service import (
    WorkingCapitalInput,
    compute_working_capital,
    result_to_dict as wc_to_dict,
)
from app.core.health_score_service import (
    HealthScoreInput,
    compute_health_score,
    result_to_dict as hs_to_dict,
)

router = APIRouter(tags=["Analytics"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v: Optional[str], name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


def _opt_dec(v: Optional[str], name: str) -> Optional[Decimal]:
    if v is None or v == "":
        return None
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


# ═══════════════════════════════════════════════════════════════
# Working capital
# ═══════════════════════════════════════════════════════════════


class WorkingCapitalRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    period_days: int = Field(default=365, ge=30, le=730)
    revenue: Optional[str] = "0"
    cogs: Optional[str] = "0"
    current_assets: Optional[str] = "0"
    current_liabilities: Optional[str] = "0"
    accounts_receivable: Optional[str] = "0"
    inventory: Optional[str] = "0"
    accounts_payable: Optional[str] = "0"
    cash: Optional[str] = "0"


@router.post("/working-capital/analyze")
async def working_capital_route(
    body: WorkingCapitalRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = WorkingCapitalInput(
        period_label=body.period_label,
        period_days=body.period_days,
        revenue=_dec(body.revenue, "revenue"),
        cogs=_dec(body.cogs, "cogs"),
        current_assets=_dec(body.current_assets, "current_assets"),
        current_liabilities=_dec(body.current_liabilities, "current_liabilities"),
        accounts_receivable=_dec(body.accounts_receivable, "accounts_receivable"),
        inventory=_dec(body.inventory, "inventory"),
        accounts_payable=_dec(body.accounts_payable, "accounts_payable"),
        cash=_dec(body.cash, "cash"),
    )
    result = compute_working_capital(inp)
    write_audit_event(
        action="working_capital.analyze",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="working_capital_analysis",
        entity_id=body.period_label,
        metadata={
            "ccc": None if result.ccc is None else f"{result.ccc}",
            "health": result.health,
        },
    )
    return {"success": True, "data": wc_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Health Score
# ═══════════════════════════════════════════════════════════════


class HealthScoreRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    current_ratio: Optional[str] = None
    quick_ratio: Optional[str] = None
    debt_to_equity: Optional[str] = None
    interest_coverage: Optional[str] = None
    net_margin_pct: Optional[str] = None
    roe_pct: Optional[str] = None
    asset_turnover: Optional[str] = None
    ccc_days: Optional[str] = None
    ocf_to_ni_ratio: Optional[str] = None
    ocf_ratio: Optional[str] = None


@router.post("/health-score/compute")
async def health_score_route(
    body: HealthScoreRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = HealthScoreInput(
        period_label=body.period_label,
        current_ratio=_opt_dec(body.current_ratio, "current_ratio"),
        quick_ratio=_opt_dec(body.quick_ratio, "quick_ratio"),
        debt_to_equity=_opt_dec(body.debt_to_equity, "debt_to_equity"),
        interest_coverage=_opt_dec(body.interest_coverage, "interest_coverage"),
        net_margin_pct=_opt_dec(body.net_margin_pct, "net_margin_pct"),
        roe_pct=_opt_dec(body.roe_pct, "roe_pct"),
        asset_turnover=_opt_dec(body.asset_turnover, "asset_turnover"),
        ccc_days=_opt_dec(body.ccc_days, "ccc_days"),
        ocf_to_ni_ratio=_opt_dec(body.ocf_to_ni_ratio, "ocf_to_ni_ratio"),
        ocf_ratio=_opt_dec(body.ocf_ratio, "ocf_ratio"),
    )
    result = compute_health_score(inp)
    write_audit_event(
        action="health_score.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="financial_health",
        entity_id=body.period_label,
        metadata={"composite_score": result.composite_score, "grade": result.grade},
    )
    return {"success": True, "data": hs_to_dict(result)}
