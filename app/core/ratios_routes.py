"""
APEX Platform — Financial Ratios route.

Endpoint:
  POST /ratios/compute  -> 18 ratios grouped into 5 categories.
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.ratios_service import (
    RatiosInput,
    compute_ratios,
    result_to_dict,
)

router = APIRouter(prefix="/ratios", tags=["Financial Ratios"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _opt_decimal(value: Optional[str], field_name: str) -> Optional[Decimal]:
    if value is None or value == "":
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {field_name}: {value!r}")


class RatiosRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    # Balance Sheet
    current_assets: Optional[str] = None
    cash_and_equivalents: Optional[str] = None
    inventory: Optional[str] = None
    receivables: Optional[str] = None
    current_liabilities: Optional[str] = None
    total_assets: Optional[str] = None
    total_liabilities: Optional[str] = None
    total_equity: Optional[str] = None
    long_term_debt: Optional[str] = None
    # Income Statement
    revenue: Optional[str] = None
    cogs: Optional[str] = None
    gross_profit: Optional[str] = None
    operating_income: Optional[str] = None
    interest_expense: Optional[str] = None
    net_income: Optional[str] = None
    # Cash Flow
    operating_cash_flow: Optional[str] = None
    # Market
    market_cap: Optional[str] = None
    shares_outstanding: Optional[str] = None
    share_price: Optional[str] = None
    dividends_per_share: Optional[str] = None


@router.post("/compute")
async def compute_ratios_route(
    body: RatiosRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = RatiosInput(
        period_label=body.period_label,
        current_assets=_opt_decimal(body.current_assets, "current_assets"),
        cash_and_equivalents=_opt_decimal(body.cash_and_equivalents, "cash_and_equivalents"),
        inventory=_opt_decimal(body.inventory, "inventory"),
        receivables=_opt_decimal(body.receivables, "receivables"),
        current_liabilities=_opt_decimal(body.current_liabilities, "current_liabilities"),
        total_assets=_opt_decimal(body.total_assets, "total_assets"),
        total_liabilities=_opt_decimal(body.total_liabilities, "total_liabilities"),
        total_equity=_opt_decimal(body.total_equity, "total_equity"),
        long_term_debt=_opt_decimal(body.long_term_debt, "long_term_debt"),
        revenue=_opt_decimal(body.revenue, "revenue"),
        cogs=_opt_decimal(body.cogs, "cogs"),
        gross_profit=_opt_decimal(body.gross_profit, "gross_profit"),
        operating_income=_opt_decimal(body.operating_income, "operating_income"),
        interest_expense=_opt_decimal(body.interest_expense, "interest_expense"),
        net_income=_opt_decimal(body.net_income, "net_income"),
        operating_cash_flow=_opt_decimal(body.operating_cash_flow, "operating_cash_flow"),
        market_cap=_opt_decimal(body.market_cap, "market_cap"),
        shares_outstanding=_opt_decimal(body.shares_outstanding, "shares_outstanding"),
        share_price=_opt_decimal(body.share_price, "share_price"),
        dividends_per_share=_opt_decimal(body.dividends_per_share, "dividends_per_share"),
    )
    result = compute_ratios(inp)

    write_audit_event(
        action="ratios.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="financial_ratios",
        entity_id=body.period_label,
        metadata={"ratio_count": len(result.ratios)},
    )
    return {"success": True, "data": result_to_dict(result)}
