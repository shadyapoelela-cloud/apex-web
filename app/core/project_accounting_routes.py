"""Project Accounting API endpoints."""

from __future__ import annotations
from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.project_accounting_service import (
    ProjectPhase, ProjectInput, analyse_project, to_dict,
)

router = APIRouter(tags=["Project Accounting"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}")


class PhaseReq(BaseModel):
    phase_name: str = Field(..., min_length=1, max_length=200)
    budget: str
    actual_cost: str
    earned_value: str
    planned_value: str
    hours_budget: str = "0"
    hours_actual: str = "0"


class ProjectReq(BaseModel):
    project_name: str = Field(..., min_length=1, max_length=200)
    client_name: str = Field(..., min_length=1, max_length=200)
    contract_value: str
    start_date: str = Field(..., min_length=10, max_length=10)
    end_date: str = Field(..., min_length=10, max_length=10)
    currency: str = "SAR"
    phases: List[PhaseReq] = Field(..., min_length=1)


@router.post("/projects/analyse")
async def analyse_route(body: ProjectReq, user_id: str = Depends(_auth)):
    phases = [
        ProjectPhase(
            phase_name=p.phase_name,
            budget=_dec(p.budget, "budget"),
            actual_cost=_dec(p.actual_cost, "actual"),
            earned_value=_dec(p.earned_value, "ev"),
            planned_value=_dec(p.planned_value, "pv"),
            hours_budget=_dec(p.hours_budget, "hrs_b"),
            hours_actual=_dec(p.hours_actual, "hrs_a"),
        )
        for p in body.phases
    ]
    try:
        result = analyse_project(ProjectInput(
            project_name=body.project_name,
            client_name=body.client_name,
            contract_value=_dec(body.contract_value, "contract"),
            start_date=body.start_date,
            end_date=body.end_date,
            currency=body.currency,
            phases=phases,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(result)}
