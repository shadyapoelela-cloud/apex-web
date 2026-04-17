"""DSCR + WACC + DCF endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.dscr_service import DscrInput, compute_dscr, result_to_dict as dscr_to_dict
from app.core.valuation_service import (
    WaccInput, DcfInput,
    compute_wacc, compute_dcf,
    wacc_result_to_dict, dcf_result_to_dict,
)

router = APIRouter(tags=["Valuation & DSCR"])


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


# ══════════════════════════════════════════════════════════════
# DSCR
# ══════════════════════════════════════════════════════════════


class DscrRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    ebitda: Optional[str] = "0"
    net_operating_income: Optional[str] = None
    interest_expense: Optional[str] = "0"
    current_principal_payments: Optional[str] = "0"
    total_debt: Optional[str] = "0"
    target_dscr: Optional[str] = "1.25"
    proposed_rate_pct: Optional[str] = "6"
    proposed_term_years: int = Field(default=5, ge=1, le=30)


@router.post("/dscr/analyze")
async def dscr_route(body: DscrRequest, request: Request, user_id: str = Depends(_auth)):
    inp = DscrInput(
        period_label=body.period_label,
        ebitda=_dec(body.ebitda, "ebitda"),
        net_operating_income=_opt_dec(body.net_operating_income, "net_operating_income"),
        interest_expense=_dec(body.interest_expense, "interest_expense"),
        current_principal_payments=_dec(body.current_principal_payments, "current_principal_payments"),
        total_debt=_dec(body.total_debt, "total_debt"),
        target_dscr=_dec(body.target_dscr, "target_dscr"),
        proposed_rate_pct=_dec(body.proposed_rate_pct, "proposed_rate_pct"),
        proposed_term_years=body.proposed_term_years,
    )
    try:
        result = compute_dscr(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="dscr.analyze",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="dscr_analysis",
        entity_id=body.period_label,
        metadata={"dscr": None if result.dscr is None else f"{result.dscr}",
                  "decision": result.dscr_decision},
    )
    return {"success": True, "data": dscr_to_dict(result)}


# ══════════════════════════════════════════════════════════════
# WACC
# ══════════════════════════════════════════════════════════════


class WaccRequest(BaseModel):
    equity_value: str
    debt_value: str
    risk_free_rate: Optional[str] = "0.04"
    beta: Optional[str] = "1.0"
    equity_risk_premium: Optional[str] = "0.06"
    cost_of_equity_override: Optional[str] = None
    cost_of_debt: Optional[str] = "0.06"
    tax_rate: Optional[str] = "0.20"


@router.post("/wacc/compute")
async def wacc_route(body: WaccRequest, request: Request, user_id: str = Depends(_auth)):
    inp = WaccInput(
        equity_value=_dec(body.equity_value, "equity_value"),
        debt_value=_dec(body.debt_value, "debt_value"),
        risk_free_rate=_dec(body.risk_free_rate, "risk_free_rate"),
        beta=_dec(body.beta, "beta"),
        equity_risk_premium=_dec(body.equity_risk_premium, "equity_risk_premium"),
        cost_of_equity_override=_opt_dec(body.cost_of_equity_override, "cost_of_equity_override"),
        cost_of_debt=_dec(body.cost_of_debt, "cost_of_debt"),
        tax_rate=_dec(body.tax_rate, "tax_rate"),
    )
    try:
        result = compute_wacc(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="wacc.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="wacc",
        entity_id="cost_of_capital",
        metadata={"wacc_pct": f"{result.wacc_pct}"},
    )
    return {"success": True, "data": wacc_result_to_dict(result)}


# ══════════════════════════════════════════════════════════════
# DCF
# ══════════════════════════════════════════════════════════════


class DcfRequest(BaseModel):
    company_name: str = Field(default="", max_length=200)
    free_cash_flows: List[str] = Field(..., min_length=1)
    wacc_pct: str
    terminal_growth_pct: Optional[str] = "2.5"
    net_debt: Optional[str] = "0"
    shares_outstanding: Optional[str] = None


@router.post("/dcf/analyze")
async def dcf_route(body: DcfRequest, request: Request, user_id: str = Depends(_auth)):
    cfs = [_dec(v, f"free_cash_flows[{i}]") for i, v in enumerate(body.free_cash_flows)]
    inp = DcfInput(
        company_name=body.company_name,
        free_cash_flows=cfs,
        wacc_pct=_dec(body.wacc_pct, "wacc_pct"),
        terminal_growth_pct=_dec(body.terminal_growth_pct, "terminal_growth_pct"),
        net_debt=_dec(body.net_debt, "net_debt"),
        shares_outstanding=_opt_dec(body.shares_outstanding, "shares_outstanding"),
    )
    try:
        result = compute_dcf(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="dcf.analyze",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="dcf_valuation",
        entity_id=body.company_name or "unnamed",
        metadata={
            "enterprise_value": f"{result.enterprise_value}",
            "equity_value": f"{result.equity_value}",
        },
    )
    return {"success": True, "data": dcf_result_to_dict(result)}
