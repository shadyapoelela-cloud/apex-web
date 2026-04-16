"""
APEX Platform — Zakat + VAT HTTP routes.

Endpoints:
  POST /tax/zakat/compute     -> compute Zakat liability
  POST /tax/vat/return        -> compute VAT return (output - input)
"""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.vat_service import (
    VatPurchases,
    VatReturnInput,
    VatSales,
    compute_vat_return,
    result_to_dict as vat_to_dict,
)
from app.core.zakat_service import (
    ZakatInput,
    compute_zakat,
    result_to_dict as zakat_to_dict,
)

router = APIRouter(prefix="/tax", tags=["Tax & Zakat"])


# ──────────────────────────────────────────────────────────────
# Auth helper
# ──────────────────────────────────────────────────────────────


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _decimal(value: Optional[str], field_name: str) -> Decimal:
    if value is None or value == "":
        return Decimal("0")
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(
            status_code=422, detail=f"Invalid decimal for {field_name}: {value!r}"
        )


# ──────────────────────────────────────────────────────────────
# Zakat
# ──────────────────────────────────────────────────────────────


class ZakatComputeRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    hijri_year: Optional[str] = Field(default=None, pattern=r"^\d{4}$")
    rate: Optional[str] = Field(default=None, description="Decimal, e.g. '0.025' (2.5%)")

    # Additions
    capital: Optional[str] = "0"
    retained_earnings: Optional[str] = "0"
    statutory_reserve: Optional[str] = "0"
    other_reserves: Optional[str] = "0"
    provisions: Optional[str] = "0"
    long_term_liabilities: Optional[str] = "0"
    shareholder_loans: Optional[str] = "0"
    adjusted_net_profit: Optional[str] = "0"

    # Deductions
    net_fixed_assets: Optional[str] = "0"
    intangible_assets: Optional[str] = "0"
    long_term_investments: Optional[str] = "0"
    accumulated_losses: Optional[str] = "0"
    deferred_tax_assets: Optional[str] = "0"
    capital_work_in_progress: Optional[str] = "0"


@router.post("/zakat/compute")
async def compute_zakat_route(
    body: ZakatComputeRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    rate = _decimal(body.rate, "rate") if body.rate else Decimal("0.025")
    inp = ZakatInput(
        period_label=body.period_label,
        hijri_year=body.hijri_year,
        rate=rate,
        capital=_decimal(body.capital, "capital"),
        retained_earnings=_decimal(body.retained_earnings, "retained_earnings"),
        statutory_reserve=_decimal(body.statutory_reserve, "statutory_reserve"),
        other_reserves=_decimal(body.other_reserves, "other_reserves"),
        provisions=_decimal(body.provisions, "provisions"),
        long_term_liabilities=_decimal(body.long_term_liabilities, "long_term_liabilities"),
        shareholder_loans=_decimal(body.shareholder_loans, "shareholder_loans"),
        adjusted_net_profit=_decimal(body.adjusted_net_profit, "adjusted_net_profit"),
        net_fixed_assets=_decimal(body.net_fixed_assets, "net_fixed_assets"),
        intangible_assets=_decimal(body.intangible_assets, "intangible_assets"),
        long_term_investments=_decimal(body.long_term_investments, "long_term_investments"),
        accumulated_losses=_decimal(body.accumulated_losses, "accumulated_losses"),
        deferred_tax_assets=_decimal(body.deferred_tax_assets, "deferred_tax_assets"),
        capital_work_in_progress=_decimal(
            body.capital_work_in_progress, "capital_work_in_progress"
        ),
    )
    try:
        result = compute_zakat(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="tax.zakat.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="zakat_return",
        entity_id=body.period_label,
        after={
            "zakat_base": f"{result.zakat_base}",
            "zakat_due": f"{result.zakat_due}",
            "rate_pct": f"{result.rate_pct}",
        },
    )
    return {"success": True, "data": zakat_to_dict(result)}


# ──────────────────────────────────────────────────────────────
# VAT
# ──────────────────────────────────────────────────────────────


class VatSalesRequest(BaseModel):
    standard_rated_net: Optional[str] = "0"
    zero_rated_net: Optional[str] = "0"
    exempt_net: Optional[str] = "0"
    out_of_scope_net: Optional[str] = "0"


class VatPurchasesRequest(BaseModel):
    standard_rated_net: Optional[str] = "0"
    zero_rated_net: Optional[str] = "0"
    exempt_net: Optional[str] = "0"
    non_reclaimable_vat: Optional[str] = "0"


class VatReturnRequest(BaseModel):
    jurisdiction: str = Field(default="SA", pattern=r"^[A-Z]{2}$")
    period_label: str = Field(default="Q1", max_length=50)
    standard_rate_override: Optional[str] = None
    prior_period_credit: Optional[str] = "0"
    sales: VatSalesRequest = Field(default_factory=VatSalesRequest)
    purchases: VatPurchasesRequest = Field(default_factory=VatPurchasesRequest)


@router.post("/vat/return")
async def vat_return_route(
    body: VatReturnRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    override: Optional[Decimal] = None
    if body.standard_rate_override:
        override = _decimal(body.standard_rate_override, "standard_rate_override")

    inp = VatReturnInput(
        jurisdiction=body.jurisdiction,
        period_label=body.period_label,
        standard_rate_override=override,
        prior_period_credit=_decimal(body.prior_period_credit, "prior_period_credit"),
        sales=VatSales(
            standard_rated_net=_decimal(body.sales.standard_rated_net, "sales.standard_rated_net"),
            zero_rated_net=_decimal(body.sales.zero_rated_net, "sales.zero_rated_net"),
            exempt_net=_decimal(body.sales.exempt_net, "sales.exempt_net"),
            out_of_scope_net=_decimal(body.sales.out_of_scope_net, "sales.out_of_scope_net"),
        ),
        purchases=VatPurchases(
            standard_rated_net=_decimal(body.purchases.standard_rated_net, "purchases.standard_rated_net"),
            zero_rated_net=_decimal(body.purchases.zero_rated_net, "purchases.zero_rated_net"),
            exempt_net=_decimal(body.purchases.exempt_net, "purchases.exempt_net"),
            non_reclaimable_vat=_decimal(body.purchases.non_reclaimable_vat, "purchases.non_reclaimable_vat"),
        ),
    )
    try:
        result = compute_vat_return(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="tax.vat.return",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="vat_return",
        entity_id=f"{body.jurisdiction}:{body.period_label}",
        after={
            "output_vat": f"{result.output_vat_total}",
            "input_vat": f"{result.input_vat_reclaimable}",
            "net_vat_due": f"{result.net_vat_due}",
            "status": result.status,
        },
    )
    return {"success": True, "data": vat_to_dict(result)}
