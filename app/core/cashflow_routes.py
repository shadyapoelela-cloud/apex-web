"""Cash Flow Statement + Amortization routes."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.cashflow_service import (
    CashFlowInput,
    compute_cashflow,
    result_to_dict as cf_to_dict,
)
from app.core.amortization_service import (
    AmortizationInput,
    compute_amortization,
    result_to_dict as am_to_dict,
)

router = APIRouter(tags=["Cash Flow & Amortization"])


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
# Cash Flow
# ═══════════════════════════════════════════════════════════════


class CashFlowRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    beginning_cash: Optional[str] = "0"
    ending_cash_reported: Optional[str] = None
    # Operating
    net_income: Optional[str] = "0"
    depreciation_amortization: Optional[str] = "0"
    impairment_losses: Optional[str] = "0"
    loss_on_asset_sale: Optional[str] = "0"
    gain_on_asset_sale: Optional[str] = "0"
    increase_receivables: Optional[str] = "0"
    increase_inventory: Optional[str] = "0"
    increase_prepaid: Optional[str] = "0"
    increase_payables: Optional[str] = "0"
    increase_accrued: Optional[str] = "0"
    increase_deferred_revenue: Optional[str] = "0"
    # Investing
    capex: Optional[str] = "0"
    proceeds_asset_sale: Optional[str] = "0"
    purchase_investments: Optional[str] = "0"
    sale_investments: Optional[str] = "0"
    acquisitions: Optional[str] = "0"
    # Financing
    loan_proceeds: Optional[str] = "0"
    loan_repayments: Optional[str] = "0"
    share_issuance: Optional[str] = "0"
    share_buyback: Optional[str] = "0"
    dividends_paid: Optional[str] = "0"
    interest_paid: Optional[str] = "0"


@router.post("/cashflow/compute")
async def compute_cashflow_route(
    body: CashFlowRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = CashFlowInput(
        period_label=body.period_label,
        beginning_cash=_dec(body.beginning_cash, "beginning_cash"),
        ending_cash_reported=_opt_dec(body.ending_cash_reported, "ending_cash_reported"),
        net_income=_dec(body.net_income, "net_income"),
        depreciation_amortization=_dec(body.depreciation_amortization, "depreciation_amortization"),
        impairment_losses=_dec(body.impairment_losses, "impairment_losses"),
        loss_on_asset_sale=_dec(body.loss_on_asset_sale, "loss_on_asset_sale"),
        gain_on_asset_sale=_dec(body.gain_on_asset_sale, "gain_on_asset_sale"),
        increase_receivables=_dec(body.increase_receivables, "increase_receivables"),
        increase_inventory=_dec(body.increase_inventory, "increase_inventory"),
        increase_prepaid=_dec(body.increase_prepaid, "increase_prepaid"),
        increase_payables=_dec(body.increase_payables, "increase_payables"),
        increase_accrued=_dec(body.increase_accrued, "increase_accrued"),
        increase_deferred_revenue=_dec(body.increase_deferred_revenue, "increase_deferred_revenue"),
        capex=_dec(body.capex, "capex"),
        proceeds_asset_sale=_dec(body.proceeds_asset_sale, "proceeds_asset_sale"),
        purchase_investments=_dec(body.purchase_investments, "purchase_investments"),
        sale_investments=_dec(body.sale_investments, "sale_investments"),
        acquisitions=_dec(body.acquisitions, "acquisitions"),
        loan_proceeds=_dec(body.loan_proceeds, "loan_proceeds"),
        loan_repayments=_dec(body.loan_repayments, "loan_repayments"),
        share_issuance=_dec(body.share_issuance, "share_issuance"),
        share_buyback=_dec(body.share_buyback, "share_buyback"),
        dividends_paid=_dec(body.dividends_paid, "dividends_paid"),
        interest_paid=_dec(body.interest_paid, "interest_paid"),
    )
    result = compute_cashflow(inp)
    write_audit_event(
        action="cashflow.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="cashflow_statement",
        entity_id=body.period_label,
        metadata={
            "net_change": f"{result.net_change}",
            "reconciles": result.reconciles,
        },
    )
    return {"success": True, "data": cf_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Amortization
# ═══════════════════════════════════════════════════════════════


class AmortizationRequest(BaseModel):
    principal: str = Field(..., description="Loan principal")
    annual_rate_pct: str = Field(..., description="Annual rate as percent, e.g. '6.5'")
    years: int = Field(..., ge=1, le=50)
    periods_per_year: int = Field(default=12)
    method: str = Field(
        default="fixed_payment",
        pattern="^(fixed_payment|constant_principal)$",
    )


@router.post("/amortization/compute")
async def compute_amortization_route(
    body: AmortizationRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = AmortizationInput(
        principal=_dec(body.principal, "principal"),
        annual_rate_pct=_dec(body.annual_rate_pct, "annual_rate_pct"),
        years=body.years,
        periods_per_year=body.periods_per_year,
        method=body.method,
    )
    try:
        result = compute_amortization(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="amortization.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="amortization_schedule",
        entity_id=f"{body.principal}:{body.years}y:{body.annual_rate_pct}%",
        metadata={
            "total_interest": f"{result.total_interest}",
            "total_payments": f"{result.total_payments}",
        },
    )
    return {"success": True, "data": am_to_dict(result)}
