"""Purchase Orders & Sales Orders API endpoints."""

from __future__ import annotations
from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.po_so_service import OrderLine, OrderInput, process_order, to_dict

router = APIRouter(tags=["PO/SO"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}")


class OrderLineReq(BaseModel):
    item_code: str = Field(..., min_length=1)
    description: str = Field(..., min_length=1)
    quantity: str
    unit_price: str
    discount_pct: str = "0"
    vat_rate: str = "0.15"
    received_qty: Optional[str] = None


class OrderReq(BaseModel):
    order_type: str = Field(..., pattern=r"^(purchase|sales)$")
    counterparty: str = Field(..., min_length=1, max_length=200)
    order_date: str = Field(..., min_length=10, max_length=10)
    currency: str = "SAR"
    payment_terms: str = "net_30"
    reference: str = ""
    lines: List[OrderLineReq] = Field(..., min_length=1)


@router.post("/orders/process")
async def process_route(body: OrderReq, user_id: str = Depends(_auth)):
    lines = [
        OrderLine(
            item_code=ln.item_code, description=ln.description,
            quantity=_dec(ln.quantity, "qty"),
            unit_price=_dec(ln.unit_price, "price"),
            discount_pct=_dec(ln.discount_pct, "disc"),
            vat_rate=_dec(ln.vat_rate, "vat"),
            received_qty=_dec(ln.received_qty, "recv") if ln.received_qty else None,
        )
        for ln in body.lines
    ]
    try:
        result = process_order(OrderInput(
            order_type=body.order_type,
            counterparty=body.counterparty,
            order_date=body.order_date,
            currency=body.currency,
            payment_terms=body.payment_terms,
            reference=body.reference,
            lines=lines,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(result)}
