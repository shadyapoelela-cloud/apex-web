"""Payroll + Break-even endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.payroll_service import (
    PayrollInput,
    compute_payroll,
    result_to_dict as payroll_to_dict,
)
from app.core.breakeven_service import (
    BreakevenInput,
    compute_breakeven,
    result_to_dict as breakeven_to_dict,
)

router = APIRouter(tags=["Payroll & Break-even"])


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
# Payroll
# ═══════════════════════════════════════════════════════════════


class PayrollRequest(BaseModel):
    employee_name: str = Field(default="", max_length=200)
    nationality: str = Field(default="SA", pattern=r"^[A-Z]{2}$")
    period_label: str = Field(default="", max_length=50)
    basic_salary: Optional[str] = "0"
    housing_allowance: Optional[str] = "0"
    transport_allowance: Optional[str] = "0"
    other_allowances: Optional[str] = "0"
    overtime: Optional[str] = "0"
    bonus: Optional[str] = "0"
    absence_deduction: Optional[str] = "0"
    loan_deduction: Optional[str] = "0"
    other_deductions: Optional[str] = "0"
    gosi_base_cap: Optional[str] = "45000"
    gosi_employee_rate: Optional[str] = None
    gosi_employer_rate: Optional[str] = None
    income_tax_rate: Optional[str] = "0"
    currency: str = Field(default="SAR", max_length=3)


@router.post("/payroll/compute")
async def compute_payroll_route(
    body: PayrollRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = PayrollInput(
        employee_name=body.employee_name,
        nationality=body.nationality,
        period_label=body.period_label,
        basic_salary=_dec(body.basic_salary, "basic_salary"),
        housing_allowance=_dec(body.housing_allowance, "housing_allowance"),
        transport_allowance=_dec(body.transport_allowance, "transport_allowance"),
        other_allowances=_dec(body.other_allowances, "other_allowances"),
        overtime=_dec(body.overtime, "overtime"),
        bonus=_dec(body.bonus, "bonus"),
        absence_deduction=_dec(body.absence_deduction, "absence_deduction"),
        loan_deduction=_dec(body.loan_deduction, "loan_deduction"),
        other_deductions=_dec(body.other_deductions, "other_deductions"),
        gosi_base_cap=_dec(body.gosi_base_cap, "gosi_base_cap"),
        gosi_employee_rate=_opt_dec(body.gosi_employee_rate, "gosi_employee_rate"),
        gosi_employer_rate=_opt_dec(body.gosi_employer_rate, "gosi_employer_rate"),
        income_tax_rate=_dec(body.income_tax_rate, "income_tax_rate"),
        currency=body.currency,
    )
    try:
        result = compute_payroll(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="payroll.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="payroll_run",
        entity_id=f"{body.employee_name}:{body.period_label}",
        metadata={
            "gross": f"{result.gross_earnings}",
            "net_pay": f"{result.net_pay}",
            "total_cost": f"{result.total_cost_to_employer}",
        },
    )
    return {"success": True, "data": payroll_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Break-even
# ═══════════════════════════════════════════════════════════════


class BreakevenRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    fixed_costs: Optional[str] = "0"
    unit_price: Optional[str] = "0"
    variable_cost_per_unit: Optional[str] = "0"
    target_profit: Optional[str] = "0"
    actual_units_sold: Optional[str] = None


@router.post("/breakeven/compute")
async def compute_breakeven_route(
    body: BreakevenRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = BreakevenInput(
        period_label=body.period_label,
        fixed_costs=_dec(body.fixed_costs, "fixed_costs"),
        unit_price=_dec(body.unit_price, "unit_price"),
        variable_cost_per_unit=_dec(body.variable_cost_per_unit, "variable_cost_per_unit"),
        target_profit=_dec(body.target_profit, "target_profit"),
        actual_units_sold=_opt_dec(body.actual_units_sold, "actual_units_sold"),
    )
    try:
        result = compute_breakeven(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    write_audit_event(
        action="breakeven.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="breakeven_analysis",
        entity_id=body.period_label,
        metadata={
            "break_even_units": result.break_even_units,
            "cm_ratio_pct": f"{result.contribution_margin_ratio_pct}",
        },
    )
    return {"success": True, "data": breakeven_to_dict(result)}
