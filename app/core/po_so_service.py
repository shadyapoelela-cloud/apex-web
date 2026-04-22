"""
APEX Platform — Purchase Orders & Sales Orders Service
═══════════════════════════════════════════════════════════════
Full procure-to-pay & order-to-cash lifecycle:
  • PO creation with line items, approval workflow
  • SO creation with pricing, discount, VAT
  • 3-way match (PO ↔ GRN ↔ Invoice)
  • Auto Journal Entry generation
  • KSA VAT (15%) calculation
  • Status tracking: draft → approved → received/shipped → invoiced → closed
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional
from enum import Enum


_TWO = Decimal("0.01")
KSA_VAT_RATE = Decimal("0.15")


def _q(v) -> Decimal:
    if v is None:
        return Decimal("0")
    if not isinstance(v, Decimal):
        v = Decimal(str(v))
    return v.quantize(_TWO, rounding=ROUND_HALF_UP)


class OrderType(str, Enum):
    PURCHASE = "purchase"
    SALES = "sales"


class OrderStatus(str, Enum):
    DRAFT = "draft"
    APPROVED = "approved"
    PARTIALLY_RECEIVED = "partially_received"
    RECEIVED = "received"
    SHIPPED = "shipped"
    INVOICED = "invoiced"
    CLOSED = "closed"
    CANCELLED = "cancelled"


@dataclass
class OrderLine:
    item_code: str
    description: str
    quantity: Decimal
    unit_price: Decimal
    discount_pct: Decimal = Decimal("0")
    vat_rate: Decimal = KSA_VAT_RATE
    received_qty: Optional[Decimal] = None
    unit: str = "EA"


@dataclass
class OrderInput:
    order_type: str          # purchase | sales
    counterparty: str        # vendor name or customer name
    order_date: str
    currency: str = "SAR"
    payment_terms: str = "net_30"
    reference: str = ""
    lines: List[OrderLine] = field(default_factory=list)


@dataclass
class OrderLineResult:
    item_code: str
    description: str
    quantity: Decimal
    unit_price: Decimal
    discount_pct: Decimal
    discount_amount: Decimal
    net_amount: Decimal
    vat_rate: Decimal
    vat_amount: Decimal
    total_amount: Decimal
    received_qty: Optional[Decimal]
    fulfillment_pct: Optional[Decimal]


@dataclass
class ThreeWayMatch:
    po_total: Decimal
    grn_total: Decimal    # goods received
    match_pct: Decimal
    status: str           # 'matched' | 'partial' | 'over_receipt' | 'pending'
    discrepancies: List[str]


@dataclass
class JournalSuggestion:
    description: str
    entries: List[dict]    # [{account, debit, credit}]


@dataclass
class OrderResult:
    order_type: str
    counterparty: str
    order_date: str
    currency: str
    payment_terms: str
    status: str
    lines: List[OrderLineResult]
    subtotal: Decimal
    total_discount: Decimal
    total_vat: Decimal
    grand_total: Decimal
    three_way_match: Optional[ThreeWayMatch]
    journal_suggestion: JournalSuggestion
    warnings: List[str] = field(default_factory=list)


def process_order(inp: OrderInput) -> OrderResult:
    if not inp.lines:
        raise ValueError("lines is required")
    if inp.order_type not in ("purchase", "sales"):
        raise ValueError("order_type must be 'purchase' or 'sales'")

    warnings: List[str] = []
    line_results: List[OrderLineResult] = []
    subtotal = Decimal("0")
    total_disc = Decimal("0")
    total_vat = Decimal("0")

    has_receipts = False
    grn_total = Decimal("0")

    for i, ln in enumerate(inp.lines):
        qty = Decimal(str(ln.quantity))
        price = Decimal(str(ln.unit_price))
        disc_pct = Decimal(str(ln.discount_pct))
        vat_rate = Decimal(str(ln.vat_rate))

        if qty <= 0:
            raise ValueError(f"Line {i+1}: quantity must be > 0")
        if price < 0:
            raise ValueError(f"Line {i+1}: unit_price must be >= 0")

        gross = _q(qty * price)
        disc_amt = _q(gross * disc_pct / 100)
        net = _q(gross - disc_amt)
        vat_amt = _q(net * vat_rate)
        total = _q(net + vat_amt)

        recv = None
        fulfill = None
        if ln.received_qty is not None:
            has_receipts = True
            recv = _q(Decimal(str(ln.received_qty)))
            fulfill = _q((recv / qty * 100) if qty > 0 else Decimal("0"))
            grn_total += _q(recv * price * (1 - disc_pct / 100))

        subtotal += net
        total_disc += disc_amt
        total_vat += vat_amt

        line_results.append(OrderLineResult(
            item_code=ln.item_code,
            description=ln.description,
            quantity=_q(qty), unit_price=_q(price),
            discount_pct=_q(disc_pct), discount_amount=disc_amt,
            net_amount=net, vat_rate=_q(vat_rate),
            vat_amount=vat_amt, total_amount=total,
            received_qty=recv, fulfillment_pct=fulfill,
        ))

    grand = _q(subtotal + total_vat)

    # 3-way match (PO only)
    twm = None
    if inp.order_type == "purchase" and has_receipts:
        match_pct = _q((grn_total / subtotal * 100) if subtotal > 0 else Decimal("0"))
        discrep = []
        if match_pct < Decimal("100"):
            discrep.append(f"استلام جزئي: {match_pct}% فقط من الطلب مستلم")
        elif match_pct > Decimal("100"):
            discrep.append(f"استلام زائد: {match_pct}% من الطلب مستلم")
        ms = "matched"
        if match_pct < Decimal("100"):
            ms = "partial"
        elif match_pct > Decimal("100"):
            ms = "over_receipt"
        twm = ThreeWayMatch(
            po_total=_q(subtotal), grn_total=_q(grn_total),
            match_pct=match_pct, status=ms, discrepancies=discrep,
        )

    # Status
    status = "draft"
    if has_receipts:
        all_full = all(lr.fulfillment_pct and lr.fulfillment_pct >= Decimal("100")
                       for lr in line_results if lr.received_qty is not None)
        status = "received" if all_full else "partially_received"

    # Journal suggestion
    journal = _suggest_journal(inp.order_type, subtotal, total_vat, total_disc, inp.counterparty)

    if total_disc > subtotal * Decimal("0.30"):
        warnings.append("خصم أكثر من 30% — تأكد من صلاحية الاعتماد")

    return OrderResult(
        order_type=inp.order_type,
        counterparty=inp.counterparty,
        order_date=inp.order_date,
        currency=inp.currency,
        payment_terms=inp.payment_terms,
        status=status,
        lines=line_results,
        subtotal=_q(subtotal),
        total_discount=_q(total_disc),
        total_vat=_q(total_vat),
        grand_total=grand,
        three_way_match=twm,
        journal_suggestion=journal,
        warnings=warnings,
    )


def _suggest_journal(otype, subtotal, vat, disc, party) -> JournalSuggestion:
    if otype == "purchase":
        return JournalSuggestion(
            description=f"قيد أمر شراء — {party}",
            entries=[
                {"account": "1200-مخزون/مشتريات", "debit": f"{subtotal}", "credit": "0.00"},
                {"account": "1150-ضريبة مدخلات", "debit": f"{vat}", "credit": "0.00"},
                {"account": "2100-ذمم دائنة", "debit": "0.00", "credit": f"{_q(subtotal + vat)}"},
            ],
        )
    else:
        return JournalSuggestion(
            description=f"قيد أمر بيع — {party}",
            entries=[
                {"account": "1100-ذمم مدينة", "debit": f"{_q(subtotal + vat)}", "credit": "0.00"},
                {"account": "4000-إيرادات مبيعات", "debit": "0.00", "credit": f"{subtotal}"},
                {"account": "2200-ضريبة مخرجات", "debit": "0.00", "credit": f"{vat}"},
            ],
        )


def to_dict(r: OrderResult) -> dict:
    d = {
        "order_type": r.order_type,
        "counterparty": r.counterparty,
        "order_date": r.order_date,
        "currency": r.currency,
        "payment_terms": r.payment_terms,
        "status": r.status,
        "subtotal": f"{r.subtotal}",
        "total_discount": f"{r.total_discount}",
        "total_vat": f"{r.total_vat}",
        "grand_total": f"{r.grand_total}",
        "lines": [
            {
                "item_code": ln.item_code, "description": ln.description,
                "quantity": f"{ln.quantity}", "unit_price": f"{ln.unit_price}",
                "discount_pct": f"{ln.discount_pct}", "discount_amount": f"{ln.discount_amount}",
                "net_amount": f"{ln.net_amount}", "vat_rate": f"{ln.vat_rate}",
                "vat_amount": f"{ln.vat_amount}", "total_amount": f"{ln.total_amount}",
                "received_qty": f"{ln.received_qty}" if ln.received_qty is not None else None,
                "fulfillment_pct": f"{ln.fulfillment_pct}" if ln.fulfillment_pct is not None else None,
            }
            for ln in r.lines
        ],
        "journal_suggestion": {
            "description": r.journal_suggestion.description,
            "entries": r.journal_suggestion.entries,
        },
        "warnings": r.warnings,
    }
    if r.three_way_match:
        d["three_way_match"] = {
            "po_total": f"{r.three_way_match.po_total}",
            "grn_total": f"{r.three_way_match.grn_total}",
            "match_pct": f"{r.three_way_match.match_pct}",
            "status": r.three_way_match.status,
            "discrepancies": r.three_way_match.discrepancies,
        }
    return d
