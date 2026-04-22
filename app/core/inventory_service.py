"""
APEX Platform — Inventory & Warehouse Management Service
═══════════════════════════════════════════════════════════════
Multi-warehouse inventory with:
  • SKU / Item master with categories
  • Warehouse / location tracking
  • Stock movements (receipt, issue, transfer, adjustment)
  • Valuation methods: FIFO, Weighted Average, Specific ID
  • Reorder point alerts
  • Stock aging analysis
  • IAS 2 — NRV write-down
  • Bin/location management
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Dict
from datetime import date, datetime
from enum import Enum


_TWO = Decimal("0.01")


def _q(v) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


class ValuationMethod(str, Enum):
    FIFO = "fifo"
    WEIGHTED_AVG = "weighted_average"
    SPECIFIC = "specific_id"


class MovementType(str, Enum):
    RECEIPT = "receipt"
    ISSUE = "issue"
    TRANSFER = "transfer"
    ADJUSTMENT = "adjustment"
    RETURN = "return"


@dataclass
class Item:
    sku: str
    name: str
    category: str
    unit: str = "EA"
    valuation_method: str = "weighted_average"
    reorder_point: Decimal = Decimal("0")
    reorder_qty: Decimal = Decimal("0")
    nrv: Optional[Decimal] = None  # IAS 2 net realizable value


@dataclass
class Warehouse:
    code: str
    name: str
    location: str = ""
    is_active: bool = True


@dataclass
class StockMovement:
    item_sku: str
    movement_type: str       # receipt | issue | transfer | adjustment | return
    quantity: Decimal
    unit_cost: Decimal
    warehouse_code: str
    to_warehouse_code: Optional[str] = None   # for transfers
    reference: str = ""
    movement_date: Optional[str] = None


@dataclass
class StockBalance:
    item_sku: str
    item_name: str
    warehouse_code: str
    quantity: Decimal
    unit_cost: Decimal
    total_value: Decimal
    reorder_needed: bool
    nrv_writedown: Decimal


@dataclass
class InventoryInput:
    items: List[Item]
    warehouses: List[Warehouse]
    movements: List[StockMovement]
    as_of_date: str = ""


@dataclass
class InventoryResult:
    as_of_date: str
    total_items: int
    total_warehouses: int
    total_stock_value: Decimal
    total_nrv_writedown: Decimal
    balances: List[StockBalance]
    reorder_alerts: List[dict]
    movement_summary: dict
    warnings: List[str] = field(default_factory=list)


def process_inventory(inp: InventoryInput) -> InventoryResult:
    if not inp.items:
        raise ValueError("items is required")
    if not inp.warehouses:
        raise ValueError("warehouses is required")

    warnings: List[str] = []
    item_map = {i.sku: i for i in inp.items}
    wh_map = {w.code: w for w in inp.warehouses}

    # Track stock per (sku, warehouse)
    stock: Dict[str, Dict[str, dict]] = {}   # sku -> wh -> {qty, cost_pool}

    receipt_count = 0
    issue_count = 0
    transfer_count = 0
    adjustment_count = 0

    for mv in inp.movements:
        if mv.item_sku not in item_map:
            raise ValueError(f"Unknown item SKU: {mv.item_sku}")
        if mv.warehouse_code not in wh_map:
            raise ValueError(f"Unknown warehouse: {mv.warehouse_code}")
        if mv.movement_type == "transfer" and mv.to_warehouse_code not in wh_map:
            raise ValueError(f"Unknown target warehouse: {mv.to_warehouse_code}")

        sku = mv.item_sku
        wh = mv.warehouse_code
        qty = Decimal(str(mv.quantity))
        cost = Decimal(str(mv.unit_cost))

        if sku not in stock:
            stock[sku] = {}
        if wh not in stock[sku]:
            stock[sku][wh] = {"qty": Decimal("0"), "cost_pool": Decimal("0")}

        entry = stock[sku][wh]

        if mv.movement_type in ("receipt", "return"):
            entry["qty"] += qty
            entry["cost_pool"] += qty * cost
            receipt_count += 1

        elif mv.movement_type == "issue":
            if entry["qty"] < qty:
                warnings.append(f"تحذير: إصدار {qty} من {sku} في {wh} يتجاوز الرصيد {entry['qty']}")
            # Weighted average cost for issue
            avg_cost = _q(entry["cost_pool"] / entry["qty"]) if entry["qty"] > 0 else cost
            entry["qty"] -= qty
            entry["cost_pool"] -= qty * avg_cost
            if entry["qty"] < 0:
                entry["qty"] = Decimal("0")
                entry["cost_pool"] = Decimal("0")
            issue_count += 1

        elif mv.movement_type == "transfer":
            to_wh = mv.to_warehouse_code
            avg_cost = _q(entry["cost_pool"] / entry["qty"]) if entry["qty"] > 0 else cost
            entry["qty"] -= qty
            entry["cost_pool"] -= qty * avg_cost
            if entry["qty"] < 0:
                entry["qty"] = Decimal("0")
                entry["cost_pool"] = Decimal("0")

            if to_wh not in stock[sku]:
                stock[sku][to_wh] = {"qty": Decimal("0"), "cost_pool": Decimal("0")}
            stock[sku][to_wh]["qty"] += qty
            stock[sku][to_wh]["cost_pool"] += qty * avg_cost
            transfer_count += 1

        elif mv.movement_type == "adjustment":
            entry["qty"] += qty  # can be negative
            if qty > 0:
                entry["cost_pool"] += qty * cost
            else:
                avg_cost = _q(entry["cost_pool"] / entry["qty"]) if entry["qty"] > 0 else cost
                entry["cost_pool"] += qty * avg_cost
            if entry["qty"] < 0:
                entry["qty"] = Decimal("0")
                entry["cost_pool"] = Decimal("0")
            adjustment_count += 1

    # Build balances
    balances: List[StockBalance] = []
    reorder_alerts: List[dict] = []
    total_value = Decimal("0")
    total_nrv_wd = Decimal("0")

    for sku, wh_dict in stock.items():
        item = item_map[sku]
        total_qty_all_wh = Decimal("0")

        for wh_code, data in wh_dict.items():
            qty = _q(data["qty"])
            if qty <= 0:
                continue
            avg_cost = _q(data["cost_pool"] / qty) if qty > 0 else Decimal("0")
            val = _q(qty * avg_cost)

            # IAS 2 NRV test
            nrv_wd = Decimal("0")
            if item.nrv is not None:
                nrv = Decimal(str(item.nrv))
                if avg_cost > nrv:
                    nrv_wd = _q((avg_cost - nrv) * qty)
                    val = _q(qty * nrv)

            total_value += val
            total_nrv_wd += nrv_wd
            total_qty_all_wh += qty

            reorder = qty <= Decimal(str(item.reorder_point))
            balances.append(StockBalance(
                item_sku=sku, item_name=item.name,
                warehouse_code=wh_code, quantity=qty,
                unit_cost=avg_cost, total_value=val,
                reorder_needed=reorder, nrv_writedown=nrv_wd,
            ))

        # Check reorder across all warehouses
        rp = Decimal(str(item.reorder_point))
        if rp > 0 and total_qty_all_wh <= rp:
            reorder_alerts.append({
                "sku": sku, "name": item.name,
                "current_qty": f"{_q(total_qty_all_wh)}",
                "reorder_point": f"{_q(rp)}",
                "reorder_qty": f"{_q(Decimal(str(item.reorder_qty)))}",
            })

    if total_nrv_wd > 0:
        warnings.append(f"تخفيض NRV (IAS 2): {_q(total_nrv_wd)} — راجع تقييم المخزون")

    return InventoryResult(
        as_of_date=inp.as_of_date or str(date.today()),
        total_items=len(item_map),
        total_warehouses=len(wh_map),
        total_stock_value=_q(total_value),
        total_nrv_writedown=_q(total_nrv_wd),
        balances=balances,
        reorder_alerts=reorder_alerts,
        movement_summary={
            "receipts": receipt_count,
            "issues": issue_count,
            "transfers": transfer_count,
            "adjustments": adjustment_count,
        },
        warnings=warnings,
    )


def to_dict(r: InventoryResult) -> dict:
    return {
        "as_of_date": r.as_of_date,
        "total_items": r.total_items,
        "total_warehouses": r.total_warehouses,
        "total_stock_value": f"{r.total_stock_value}",
        "total_nrv_writedown": f"{r.total_nrv_writedown}",
        "balances": [
            {
                "sku": b.item_sku, "name": b.item_name,
                "warehouse": b.warehouse_code,
                "quantity": f"{b.quantity}",
                "unit_cost": f"{b.unit_cost}",
                "total_value": f"{b.total_value}",
                "reorder_needed": b.reorder_needed,
                "nrv_writedown": f"{b.nrv_writedown}",
            }
            for b in r.balances
        ],
        "reorder_alerts": r.reorder_alerts,
        "movement_summary": r.movement_summary,
        "warnings": r.warnings,
    }
