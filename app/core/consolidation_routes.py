"""Consolidation endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.consolidation_service import (
    ConsolLine, Entity, IntercoEntry, ConsolidationInput,
    consolidate, consol_to_dict,
)


router = APIRouter(tags=["Consolidation"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class ConsolLineRequest(BaseModel):
    account_code: str = Field(..., min_length=1, max_length=30)
    account_name: str = Field(..., min_length=1, max_length=200)
    classification: str = Field(..., min_length=3, max_length=20)
    amount: str


class EntityRequest(BaseModel):
    entity_id: str = Field(..., min_length=1, max_length=50)
    entity_name: str = Field(..., min_length=1, max_length=200)
    ownership_pct: str = "100"
    fx_rate_to_presentation: str = "1"
    avg_fx_rate: str = "1"
    is_parent: bool = False
    lines: List[ConsolLineRequest] = Field(..., min_length=1)


class IntercoEntryRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=200)
    from_entity: str = Field(..., min_length=1, max_length=50)
    to_entity: str = Field(..., min_length=1, max_length=50)
    amount: str
    dr_account: str = Field(..., min_length=1, max_length=30)
    cr_account: str = Field(..., min_length=1, max_length=30)


class ConsolRequest(BaseModel):
    group_name: str = Field(..., min_length=1, max_length=200)
    period_label: str = Field(..., min_length=1, max_length=100)
    presentation_currency: str = Field(default="SAR", max_length=3)
    entities: List[EntityRequest] = Field(..., min_length=1)
    intercompany: List[IntercoEntryRequest] = Field(default_factory=list)


@router.post("/consol/build")
async def build_route(body: ConsolRequest, user_id: str = Depends(_auth)):
    entities = []
    for ei, e in enumerate(body.entities):
        lines = [
            ConsolLine(
                account_code=ln.account_code,
                account_name=ln.account_name,
                classification=ln.classification,
                amount=_dec(ln.amount, f"entities[{ei}].lines[{li}].amount"),
            )
            for li, ln in enumerate(e.lines)
        ]
        entities.append(Entity(
            entity_id=e.entity_id,
            entity_name=e.entity_name,
            ownership_pct=_dec(e.ownership_pct, f"entities[{ei}].ownership_pct"),
            fx_rate_to_presentation=_dec(e.fx_rate_to_presentation, f"entities[{ei}].fx_rate_to_presentation"),
            avg_fx_rate=_dec(e.avg_fx_rate, f"entities[{ei}].avg_fx_rate"),
            is_parent=e.is_parent,
            lines=lines,
        ))
    intercos = [
        IntercoEntry(
            description=ic.description,
            from_entity=ic.from_entity,
            to_entity=ic.to_entity,
            amount=_dec(ic.amount, f"intercompany[{i}].amount"),
            dr_account=ic.dr_account,
            cr_account=ic.cr_account,
        )
        for i, ic in enumerate(body.intercompany)
    ]
    try:
        r = consolidate(ConsolidationInput(
            group_name=body.group_name,
            period_label=body.period_label,
            presentation_currency=body.presentation_currency,
            entities=entities,
            intercompany=intercos,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": consol_to_dict(r)}
