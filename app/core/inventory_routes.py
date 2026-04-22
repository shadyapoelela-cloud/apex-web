"""Inventory & Warehouse API endpoints."""

from __future__ import annotations
from decimal import Decimal, InvalidOperation
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.auth_utils import extract_user_id
from app.core.inventory_service import (
    Item, Warehouse, StockMovement, InventoryInput,
    process_inventory, to_dict,
)

router = APIRouter(tags=["Inventory"])


def _auth(authorization: Optional[str] = Header(None)) -> str:
    return extract_user_id(authorization)


def _dec(v, name: str) -> Decimal:
    if v is None or v == "":
        return Decimal("0")
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        raise HTTPException(status_code=422, detail=f"Invalid decimal for {name}: {v!r}")


class ItemReq(BaseModel):
    sku: str = Field(..., min_length=1, max_length=50)
    name: str = Field(..., min_length=1, max_length=200)
    category: str = Field(default="general", max_length=50)
    unit: str = Field(default="EA", max_length=10)
    valuation_method: str = Field(default="weighted_average")
    reorder_point: str = "0"
    reorder_qty: str = "0"
    nrv: Optional[str] = None


class WarehouseReq(BaseModel):
    code: str = Field(..., min_length=1, max_length=20)
    name: str = Field(..., min_length=1, max_length=200)
    location: str = ""


class MovementReq(BaseModel):
    item_sku: str
    movement_type: str = Field(..., pattern=r"^(receipt|issue|transfer|adjustment|return)$")
    quantity: str
    unit_cost: str
    warehouse_code: str
    to_warehouse_code: Optional[str] = None
    reference: str = ""
    movement_date: Optional[str] = None


class InventoryReq(BaseModel):
    items: List[ItemReq] = Field(..., min_length=1)
    warehouses: List[WarehouseReq] = Field(..., min_length=1)
    movements: List[MovementReq] = Field(default_factory=list)
    as_of_date: str = ""


@router.post("/inventory/process")
async def process_route(body: InventoryReq, user_id: str = Depends(_auth)):
    items = [
        Item(
            sku=i.sku, name=i.name, category=i.category, unit=i.unit,
            valuation_method=i.valuation_method,
            reorder_point=_dec(i.reorder_point, "reorder_point"),
            reorder_qty=_dec(i.reorder_qty, "reorder_qty"),
            nrv=_dec(i.nrv, "nrv") if i.nrv else None,
        )
        for i in body.items
    ]
    warehouses = [Warehouse(code=w.code, name=w.name, location=w.location) for w in body.warehouses]
    movements = [
        StockMovement(
            item_sku=m.item_sku, movement_type=m.movement_type,
            quantity=_dec(m.quantity, "qty"), unit_cost=_dec(m.unit_cost, "cost"),
            warehouse_code=m.warehouse_code,
            to_warehouse_code=m.to_warehouse_code,
            reference=m.reference, movement_date=m.movement_date,
        )
        for m in body.movements
    ]
    try:
        result = process_inventory(InventoryInput(
            items=items, warehouses=warehouses, movements=movements,
            as_of_date=body.as_of_date,
        ))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"success": True, "data": to_dict(result)}
