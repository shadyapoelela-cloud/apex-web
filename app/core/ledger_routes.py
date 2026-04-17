"""Journal Entry + FX endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.journal_entry_service import (
    JELineInput,
    JournalEntryInput,
    build_journal_entry,
    list_templates,
    get_template,
    result_to_dict as je_to_dict,
)
from app.core.fx_service import (
    FxConvertInput, FxBatchInput, FxBatchItem, FxRevalInput,
    convert_fx, convert_fx_batch, revalue_fx,
    convert_to_dict, batch_to_dict, reval_to_dict,
    SUPPORTED_CURRENCIES,
)

router = APIRouter(tags=["Ledger & FX"])


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
# Journal Entry
# ═══════════════════════════════════════════════════════════════


class JELineRequest(BaseModel):
    account_code: str = Field(..., min_length=1, max_length=30)
    account_name: str = Field(..., min_length=1, max_length=200)
    debit: Optional[str] = "0"
    credit: Optional[str] = "0"
    description: str = Field(default="", max_length=300)


class JournalEntryRequest(BaseModel):
    client_id: str = Field(..., min_length=1)
    fiscal_year: str = Field(..., pattern=r"^\d{4}$")
    date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    memo: str = Field(default="", max_length=500)
    reference: str = Field(default="", max_length=100)
    prefix: str = Field(default="JE", max_length=10)
    currency: str = Field(default="SAR", max_length=3)
    commit: bool = True
    lines: List[JELineRequest] = Field(..., min_length=2)


@router.post("/je/build")
async def build_je_route(
    body: JournalEntryRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    lines = [
        JELineInput(
            account_code=ln.account_code, account_name=ln.account_name,
            debit=_dec(ln.debit, f"lines[{i}].debit"),
            credit=_dec(ln.credit, f"lines[{i}].credit"),
            description=ln.description,
        )
        for i, ln in enumerate(body.lines)
    ]
    try:
        result = build_journal_entry(JournalEntryInput(
            client_id=body.client_id, fiscal_year=body.fiscal_year,
            date=body.date, memo=body.memo, reference=body.reference,
            prefix=body.prefix, currency=body.currency,
            commit=body.commit, lines=lines,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return {"success": True, "data": je_to_dict(result)}


@router.get("/je/templates")
async def list_templates_route(user_id: str = Depends(_auth)):
    return {"success": True, "data": list_templates()}


@router.get("/je/templates/{code}")
async def get_template_route(code: str, user_id: str = Depends(_auth)):
    tmpl = get_template(code)
    if tmpl is None:
        raise HTTPException(status_code=404, detail=f"Template {code!r} not found")
    return {"success": True, "data": tmpl}


# ═══════════════════════════════════════════════════════════════
# FX
# ═══════════════════════════════════════════════════════════════


class FxConvertRequest(BaseModel):
    amount: str
    from_currency: str = Field(..., min_length=3, max_length=3)
    to_currency: str = Field(..., min_length=3, max_length=3)
    direct_rate: Optional[str] = None
    rates_vs_base: Optional[dict] = None
    base_currency: str = Field(default="SAR", max_length=3)


@router.post("/fx/convert")
async def fx_convert_route(
    body: FxConvertRequest, request: Request, user_id: str = Depends(_auth),
):
    rates = None
    if body.rates_vs_base:
        rates = {k: _dec(str(v), f"rates.{k}") for k, v in body.rates_vs_base.items()}
    try:
        result = convert_fx(FxConvertInput(
            amount=_dec(body.amount, "amount"),
            from_currency=body.from_currency,
            to_currency=body.to_currency,
            direct_rate=_opt_dec(body.direct_rate, "direct_rate"),
            rates_vs_base=rates,
            base_currency=body.base_currency,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": convert_to_dict(result)}


class FxBatchItemRequest(BaseModel):
    label: str = Field(..., min_length=1, max_length=200)
    amount: str
    from_currency: str = Field(..., min_length=3, max_length=3)


class FxBatchRequest(BaseModel):
    target_currency: str = Field(default="SAR", max_length=3)
    base_currency: str = Field(default="SAR", max_length=3)
    rates_vs_base: Optional[dict] = None
    items: List[FxBatchItemRequest] = Field(..., min_length=1)


@router.post("/fx/batch")
async def fx_batch_route(
    body: FxBatchRequest, request: Request, user_id: str = Depends(_auth),
):
    rates = None
    if body.rates_vs_base:
        rates = {k: _dec(str(v), f"rates.{k}") for k, v in body.rates_vs_base.items()}
    items = [
        FxBatchItem(
            label=it.label,
            amount=_dec(it.amount, f"items[{i}].amount"),
            from_currency=it.from_currency,
        )
        for i, it in enumerate(body.items)
    ]
    try:
        result = convert_fx_batch(FxBatchInput(
            target_currency=body.target_currency,
            base_currency=body.base_currency,
            rates_vs_base=rates, items=items,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": batch_to_dict(result)}


class FxRevalRequest(BaseModel):
    amount_foreign: str
    foreign_currency: str
    reporting_currency: str = "SAR"
    historical_rate: str
    current_rate: str


@router.post("/fx/revalue")
async def fx_revalue_route(
    body: FxRevalRequest, request: Request, user_id: str = Depends(_auth),
):
    try:
        result = revalue_fx(FxRevalInput(
            amount_foreign=_dec(body.amount_foreign, "amount_foreign"),
            foreign_currency=body.foreign_currency,
            reporting_currency=body.reporting_currency,
            historical_rate=_dec(body.historical_rate, "historical_rate"),
            current_rate=_dec(body.current_rate, "current_rate"),
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": reval_to_dict(result)}


@router.get("/fx/currencies")
async def supported_currencies(user_id: str = Depends(_auth)):
    return {"success": True, "data": SUPPORTED_CURRENCIES}
