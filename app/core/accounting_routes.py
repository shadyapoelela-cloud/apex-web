"""Bank Rec + Inventory + Aging endpoints."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.compliance_service import write_audit_event
from app.core.bank_rec_service import (
    BankRecInput,
    RecItem,
    compute_bank_rec,
    result_to_dict as br_to_dict,
)
from app.core.inventory_service import (
    InventoryInput,
    InventoryTxn,
    compute_inventory,
    result_to_dict as inv_to_dict,
)
from app.core.aging_service import (
    AgingInput,
    AgingInvoice,
    compute_aging,
    result_to_dict as aging_to_dict,
)

router = APIRouter(tags=["Accounting Operations"])


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
# Bank Reconciliation
# ═══════════════════════════════════════════════════════════════


class RecItemRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=200)
    amount: str
    side: str = Field(..., pattern="^(book|bank)$")
    kind: str = Field(..., pattern="^(add|subtract)$")


class BankRecRequest(BaseModel):
    period_label: str = Field(default="FY", max_length=50)
    book_balance: str
    bank_balance: str
    items: List[RecItemRequest] = Field(default_factory=list)


@router.post("/bank-rec/compute")
async def bank_rec_route(
    body: BankRecRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = BankRecInput(
        period_label=body.period_label,
        book_balance=_dec(body.book_balance, "book_balance"),
        bank_balance=_dec(body.bank_balance, "bank_balance"),
        items=[RecItem(
            description=it.description,
            amount=_dec(it.amount, f"items[{i}].amount"),
            side=it.side,
            kind=it.kind,
        ) for i, it in enumerate(body.items)],
    )
    try:
        result = compute_bank_rec(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    write_audit_event(
        action="bank_rec.compute",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="bank_reconciliation",
        entity_id=body.period_label,
        metadata={"reconciled": result.reconciled, "difference": f"{result.difference}"},
    )
    return {"success": True, "data": br_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Inventory
# ═══════════════════════════════════════════════════════════════


class InventoryTxnRequest(BaseModel):
    kind: str = Field(..., pattern="^(purchase|sale)$")
    quantity: str
    unit_cost: Optional[str] = "0"
    unit_price: Optional[str] = None
    date: str = Field(default="", max_length=20)
    reference: str = Field(default="", max_length=100)


class InventoryRequest(BaseModel):
    method: str = Field(default="fifo", pattern="^(fifo|lifo|wac)$")
    period_label: str = Field(default="FY", max_length=50)
    transactions: List[InventoryTxnRequest] = Field(..., min_length=1)


@router.post("/inventory/valuate")
async def inventory_route(
    body: InventoryRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    txns = [
        InventoryTxn(
            kind=t.kind,
            quantity=_dec(t.quantity, f"transactions[{i}].quantity"),
            unit_cost=_dec(t.unit_cost, f"transactions[{i}].unit_cost"),
            unit_price=_opt_dec(t.unit_price, f"transactions[{i}].unit_price"),
            date=t.date,
            reference=t.reference,
        )
        for i, t in enumerate(body.transactions)
    ]
    try:
        result = compute_inventory(InventoryInput(
            method=body.method,
            period_label=body.period_label,
            transactions=txns,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    write_audit_event(
        action="inventory.valuate",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="inventory_valuation",
        entity_id=body.period_label,
        metadata={
            "method": result.method,
            "ending_value": f"{result.ending_value}",
            "cogs": f"{result.total_cogs}",
        },
    )
    return {"success": True, "data": inv_to_dict(result)}


# ═══════════════════════════════════════════════════════════════
# Aging
# ═══════════════════════════════════════════════════════════════


class AgingInvoiceRequest(BaseModel):
    counterparty: str = Field(..., min_length=1, max_length=200)
    invoice_number: str = Field(..., min_length=1, max_length=100)
    invoice_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    due_date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    balance: str


class AgingRequest(BaseModel):
    kind: str = Field(..., pattern="^(ar|ap)$")
    as_of_date: Optional[str] = Field(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    invoices: List[AgingInvoiceRequest] = Field(..., min_length=1)
    ecl_rates_override: Optional[dict] = None


@router.post("/aging/report")
async def aging_route(
    body: AgingRequest,
    request: Request,
    user_id: str = Depends(_auth),
):
    inp = AgingInput(
        kind=body.kind,
        as_of_date=body.as_of_date,
        invoices=[
            AgingInvoice(
                counterparty=inv.counterparty,
                invoice_number=inv.invoice_number,
                invoice_date=inv.invoice_date,
                due_date=inv.due_date,
                balance=_dec(inv.balance, f"invoices[{i}].balance"),
            )
            for i, inv in enumerate(body.invoices)
        ],
        ecl_rates_override=body.ecl_rates_override,
    )
    try:
        result = compute_aging(inp)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    write_audit_event(
        action="aging.report",
        actor_user_id=user_id,
        actor_ip=request.client.host if request.client else None,
        actor_user_agent=request.headers.get("user-agent"),
        entity_type="aging_report",
        entity_id=body.kind,
        metadata={
            "total_outstanding": f"{result.total_outstanding}",
            "total_ecl": f"{result.total_ecl}",
            "invoices_count": len(result.invoices),
        },
    )
    return {"success": True, "data": aging_to_dict(result)}
