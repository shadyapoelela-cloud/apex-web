"""
APEX Platform — Inventory Valuation (FIFO / LIFO / WAC)
═══════════════════════════════════════════════════════════════
Computes ending inventory value + cost of goods sold (COGS) for a
sequence of purchases and sales using three industry-standard
methods:

  • FIFO  — First In, First Out
  • LIFO  — Last In, First Out     (permitted under US GAAP; NOT
                                    permitted under IFRS — warning emitted)
  • WAC   — Weighted Average Cost

Transactions are processed in input order. Each sale consumes units
from the on-hand layers per the chosen method. If a sale exceeds
the on-hand quantity, it is rejected (no short sales).

Returns:
  - per-transaction trace (units + cost impact)
  - ending inventory (qty + value)
  - total COGS
  - total sales revenue (if sale_price provided)
  - gross profit
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional


_TWO = Decimal("0.01")
_FOUR = Decimal("0.0001")


def _q(v: Decimal | int | float | str) -> Decimal:
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


METHODS = ("fifo", "lifo", "wac")


@dataclass
class InventoryTxn:
    kind: str                    # 'purchase' | 'sale'
    quantity: Decimal
    unit_cost: Decimal = Decimal("0")     # required for purchases, ignored for sales
    unit_price: Optional[Decimal] = None  # optional sale price (for revenue calc)
    date: str = ""                         # informational, e.g. "2026-01-05"
    reference: str = ""


@dataclass
class InventoryInput:
    method: str = "fifo"
    transactions: List[InventoryTxn] = field(default_factory=list)
    period_label: str = "FY"


@dataclass
class InventoryTraceLine:
    seq: int
    kind: str
    date: str
    reference: str
    quantity: Decimal
    unit_cost: Decimal
    value: Decimal           # cost impact (+ for purchase, − for sale)
    running_qty: Decimal
    running_value: Decimal


@dataclass
class InventoryResult:
    method: str
    period_label: str
    ending_qty: Decimal
    ending_value: Decimal
    ending_unit_cost: Decimal          # WAC or average for display
    total_purchases_qty: Decimal
    total_purchases_value: Decimal
    total_sales_qty: Decimal
    total_cogs: Decimal
    total_revenue: Decimal             # sum of qty × unit_price if provided
    gross_profit: Decimal
    trace: List[InventoryTraceLine] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ═══════════════════════════════════════════════════════════════
# Core
# ═══════════════════════════════════════════════════════════════


def compute_inventory(inp: InventoryInput) -> InventoryResult:
    method = (inp.method or "fifo").lower()
    if method not in METHODS:
        raise ValueError(f"Unknown method {method!r}. Expected {METHODS}")
    if not inp.transactions:
        raise ValueError("At least one transaction is required")

    warnings: list[str] = []
    if method == "lifo":
        warnings.append(
            "طريقة LIFO غير مسموح بها وفق معايير IFRS المستخدمة في السعودية — "
            "تستخدم أساساً تحت US GAAP."
        )

    # Each layer = (qty, unit_cost)
    layers: List[List[Decimal]] = []   # using list[list] for mutability
    total_purchases_qty = Decimal("0")
    total_purchases_value = Decimal("0")
    total_sales_qty = Decimal("0")
    total_cogs = Decimal("0")
    total_revenue = Decimal("0")
    trace: List[InventoryTraceLine] = []

    for i, txn in enumerate(inp.transactions, start=1):
        kind = (txn.kind or "").lower()
        if kind not in ("purchase", "sale"):
            raise ValueError(f"txn {i}: kind must be 'purchase' or 'sale'")
        qty = _q(txn.quantity)
        if qty <= 0:
            raise ValueError(f"txn {i}: quantity must be positive")

        if kind == "purchase":
            unit_cost = _q(txn.unit_cost)
            if unit_cost < 0:
                raise ValueError(f"txn {i}: unit_cost cannot be negative")

            if method == "wac":
                # Collapse into a single moving-average layer
                if layers:
                    total_qty = layers[0][0] + qty
                    total_val = (layers[0][0] * layers[0][1]) + (qty * unit_cost)
                    new_avg = (total_val / total_qty) if total_qty != 0 else Decimal("0")
                    layers[0] = [total_qty, new_avg.quantize(_FOUR, rounding=ROUND_HALF_UP)]
                else:
                    layers.append([qty, unit_cost])
            else:
                # FIFO / LIFO — track each layer separately
                layers.append([qty, unit_cost])

            total_purchases_qty += qty
            total_purchases_value += qty * unit_cost

            running_qty = sum((l[0] for l in layers), Decimal("0"))
            running_val = sum((l[0] * l[1] for l in layers), Decimal("0"))
            trace.append(InventoryTraceLine(
                seq=i, kind="purchase", date=txn.date, reference=txn.reference,
                quantity=qty, unit_cost=unit_cost,
                value=_q(qty * unit_cost),
                running_qty=_q(running_qty),
                running_value=_q(running_val),
            ))

        else:  # sale
            # Consume from layers per the method
            on_hand = sum((l[0] for l in layers), Decimal("0"))
            if qty > on_hand:
                raise ValueError(
                    f"txn {i}: sale quantity {qty} exceeds on-hand {on_hand}"
                )
            remaining = qty
            cogs_this = Decimal("0")
            if method == "wac":
                # Single layer — consume proportionally
                avg = layers[0][1]
                layers[0][0] -= remaining
                cogs_this = remaining * avg
                if layers[0][0] == 0:
                    layers.clear()
            else:
                # FIFO pops from front, LIFO from back
                while remaining > 0 and layers:
                    if method == "fifo":
                        layer = layers[0]
                    else:  # lifo
                        layer = layers[-1]
                    take = min(layer[0], remaining)
                    cogs_this += take * layer[1]
                    layer[0] -= take
                    remaining -= take
                    if layer[0] == 0:
                        if method == "fifo":
                            layers.pop(0)
                        else:
                            layers.pop()

            total_sales_qty += qty
            total_cogs += cogs_this
            if txn.unit_price is not None:
                total_revenue += qty * _q(txn.unit_price)

            running_qty = sum((l[0] for l in layers), Decimal("0"))
            running_val = sum((l[0] * l[1] for l in layers), Decimal("0"))
            trace.append(InventoryTraceLine(
                seq=i, kind="sale", date=txn.date, reference=txn.reference,
                quantity=qty, unit_cost=_q(cogs_this / qty) if qty != 0 else Decimal("0"),
                value=-_q(cogs_this),
                running_qty=_q(running_qty),
                running_value=_q(running_val),
            ))

    ending_qty = sum((l[0] for l in layers), Decimal("0"))
    ending_value = sum((l[0] * l[1] for l in layers), Decimal("0"))
    ending_unit_cost = Decimal("0")
    if ending_qty > 0:
        ending_unit_cost = (ending_value / ending_qty).quantize(_FOUR, rounding=ROUND_HALF_UP)

    gross_profit = _q(total_revenue - total_cogs)

    return InventoryResult(
        method=method,
        period_label=inp.period_label,
        ending_qty=_q(ending_qty),
        ending_value=_q(ending_value),
        ending_unit_cost=ending_unit_cost,
        total_purchases_qty=_q(total_purchases_qty),
        total_purchases_value=_q(total_purchases_value),
        total_sales_qty=_q(total_sales_qty),
        total_cogs=_q(total_cogs),
        total_revenue=_q(total_revenue),
        gross_profit=gross_profit,
        trace=trace,
        warnings=warnings,
    )


def result_to_dict(r: InventoryResult) -> dict:
    return {
        "method": r.method,
        "period_label": r.period_label,
        "ending_qty": f"{r.ending_qty}",
        "ending_value": f"{r.ending_value}",
        "ending_unit_cost": f"{r.ending_unit_cost}",
        "total_purchases_qty": f"{r.total_purchases_qty}",
        "total_purchases_value": f"{r.total_purchases_value}",
        "total_sales_qty": f"{r.total_sales_qty}",
        "total_cogs": f"{r.total_cogs}",
        "total_revenue": f"{r.total_revenue}",
        "gross_profit": f"{r.gross_profit}",
        "trace": [
            {
                "seq": t.seq,
                "kind": t.kind,
                "date": t.date,
                "reference": t.reference,
                "quantity": f"{t.quantity}",
                "unit_cost": f"{t.unit_cost}",
                "value": f"{t.value}",
                "running_qty": f"{t.running_qty}",
                "running_value": f"{t.running_value}",
            }
            for t in r.trace
        ],
        "warnings": r.warnings,
    }
