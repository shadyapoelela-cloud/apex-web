"""محرّك الشراء — إنشاء/اعتماد PO، استلام بضاعة، ترحيل الفاتورة والدفع."""

from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from sqlalchemy.orm import Session

from app.pilot.models import (
    Entity, Tenant, Branch, Warehouse,
    ProductVariant, StockLevel, StockMovement,
    Vendor, PaymentTerms,
    PurchaseOrder, PurchaseOrderLine, PoStatus,
    GoodsReceipt, GoodsReceiptLine, GrnStatus,
    PurchaseInvoice, PurchaseInvoiceLine, PurchaseInvoiceStatus,
    VendorPayment,
    GLAccount, AccountType,
    JournalEntry, JournalEntryKind,
)
from app.pilot.services.gl_engine import (
    build_journal_entry, find_fiscal_period, get_fx_rate,
)


Q2 = Decimal("0.01")


def q2(x) -> Decimal:
    if x is None:
        return Decimal("0")
    return Decimal(str(x)).quantize(Q2, rounding=ROUND_HALF_UP)


# ══════════════════════════════════════════════════════════════════════════
# Vendor helpers
# ══════════════════════════════════════════════════════════════════════════

def next_po_number(db: Session, entity_id: str, order_date: date) -> str:
    prefix = f"PO-{order_date.year}-{order_date.month:02d}-"
    count = db.query(PurchaseOrder).filter(
        PurchaseOrder.entity_id == entity_id,
        PurchaseOrder.po_number.like(f"{prefix}%"),
    ).count()
    return f"{prefix}{count+1:04d}"


def next_grn_number(db: Session, tenant_id: str, received_at: date) -> str:
    prefix = f"GRN-{received_at.year}-{received_at.month:02d}-"
    count = db.query(GoodsReceipt).filter(
        GoodsReceipt.tenant_id == tenant_id,
        GoodsReceipt.grn_number.like(f"{prefix}%"),
    ).count()
    return f"{prefix}{count+1:04d}"


def next_invoice_number(db: Session, entity_id: str, inv_date: date) -> str:
    prefix = f"PI-{inv_date.year}-{inv_date.month:02d}-"
    count = db.query(PurchaseInvoice).filter(
        PurchaseInvoice.entity_id == entity_id,
        PurchaseInvoice.invoice_number.like(f"{prefix}%"),
    ).count()
    return f"{prefix}{count+1:04d}"


def next_payment_number(db: Session, entity_id: str, pay_date: date) -> str:
    prefix = f"VP-{pay_date.year}-{pay_date.month:02d}-"
    count = db.query(VendorPayment).filter(
        VendorPayment.entity_id == entity_id,
        VendorPayment.payment_number.like(f"{prefix}%"),
    ).count()
    return f"{prefix}{count+1:04d}"


# ══════════════════════════════════════════════════════════════════════════
# PO creation
# ══════════════════════════════════════════════════════════════════════════

def create_purchase_order(
    db: Session, *, entity: Entity, vendor: Vendor,
    order_date: date, lines_input: list[dict],
    branch_id: Optional[str] = None,
    destination_warehouse_id: Optional[str] = None,
    expected_delivery_date: Optional[date] = None,
    payment_terms: str = PaymentTerms.net_30.value,
    notes_to_vendor: Optional[str] = None,
    created_by_user_id: Optional[str] = None,
) -> PurchaseOrder:
    if not lines_input:
        raise ValueError("PO بدون بنود غير مسموح")

    currency = vendor.default_currency or entity.functional_currency

    po = PurchaseOrder(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        branch_id=branch_id,
        vendor_id=vendor.id,
        po_number=next_po_number(db, entity.id, order_date),
        order_date=order_date,
        expected_delivery_date=expected_delivery_date,
        currency=currency,
        destination_warehouse_id=destination_warehouse_id,
        payment_terms=payment_terms,
        notes_to_vendor=notes_to_vendor,
        status=PoStatus.draft.value,
        created_by_user_id=created_by_user_id,
    )
    db.add(po)
    db.flush()

    subtotal = Decimal("0")
    disc_total = Decimal("0")
    taxable = Decimal("0")
    vat_total = Decimal("0")

    for idx, ln in enumerate(lines_input, start=1):
        qty = Decimal(str(ln.get("qty_ordered", 1)))
        unit_price = Decimal(str(ln["unit_price"]))
        line_sub = q2(qty * unit_price)

        disc = Decimal("0")
        if ln.get("discount_amount"):
            disc = q2(ln["discount_amount"])
        elif ln.get("discount_pct"):
            disc = q2(line_sub * Decimal(str(ln["discount_pct"])) / Decimal("100"))

        line_tax = line_sub - disc
        vat_rate = Decimal(str(ln.get("vat_rate_pct", 15)))
        vat_code = ln.get("vat_code", "standard")
        if vat_code in ("zero_rated", "exempt"):
            vat_rate = Decimal("0")
        line_vat = q2(line_tax * vat_rate / Decimal("100"))
        line_tot = line_tax + line_vat

        pol = PurchaseOrderLine(
            tenant_id=entity.tenant_id,
            po_id=po.id,
            line_number=idx,
            variant_id=ln.get("variant_id"),
            sku=ln.get("sku"),
            description=ln["description"],
            qty_ordered=qty,
            uom=ln.get("uom", "piece"),
            unit_price=unit_price,
            discount_pct=ln.get("discount_pct"),
            discount_amount=disc,
            vat_code=vat_code,
            vat_rate_pct=vat_rate,
            line_subtotal=line_sub,
            line_taxable=line_tax,
            line_vat=line_vat,
            line_total=line_tot,
            expense_account_id=ln.get("expense_account_id"),
            cost_center_id=ln.get("cost_center_id"),
        )
        db.add(pol)
        subtotal += line_sub
        disc_total += disc
        taxable += line_tax
        vat_total += line_vat

    po.subtotal = subtotal
    po.discount_total = disc_total
    po.taxable_amount = taxable
    po.vat_total = vat_total
    po.grand_total = taxable + vat_total
    db.flush()
    return po


def approve_po(db: Session, po_id: str, user_id: Optional[str]) -> PurchaseOrder:
    po = db.query(PurchaseOrder).filter(PurchaseOrder.id == po_id).first()
    if not po:
        raise ValueError("PO not found")
    if po.status not in (PoStatus.draft.value, PoStatus.submitted.value):
        raise ValueError(f"لا يمكن اعتماد PO بحالة {po.status}")
    po.status = PoStatus.approved.value
    po.approved_at = datetime.now(timezone.utc)
    po.approved_by_user_id = user_id
    db.flush()
    return po


def issue_po(db: Session, po_id: str) -> PurchaseOrder:
    po = db.query(PurchaseOrder).filter(PurchaseOrder.id == po_id).first()
    if not po:
        raise ValueError("PO not found")
    if po.status != PoStatus.approved.value:
        raise ValueError("يجب اعتماد الـ PO قبل إصداره")
    po.status = PoStatus.issued.value
    po.issued_at = datetime.now(timezone.utc)
    db.flush()
    return po


# ══════════════════════════════════════════════════════════════════════════
# Goods Receipt
# ══════════════════════════════════════════════════════════════════════════

def receive_goods(
    db: Session, *, po: PurchaseOrder, warehouse: Warehouse,
    received_at: date, lines_input: list[dict],
    delivery_note_number: Optional[str] = None,
    notes: Optional[str] = None,
    received_by_user_id: Optional[str] = None,
) -> GoodsReceipt:
    """ينشئ GRN + ينشئ StockMovement لكل بند مُستلَم.

    lines_input: [{po_line_id, qty_received, qty_accepted, qty_rejected, rejection_reason}]
    """
    if po.status not in (PoStatus.issued.value,
                         PoStatus.approved.value,
                         PoStatus.partially_received.value):
        raise ValueError(f"لا يمكن الاستلام من PO بحالة {po.status}")

    grn = GoodsReceipt(
        tenant_id=po.tenant_id,
        po_id=po.id,
        warehouse_id=warehouse.id,
        grn_number=next_grn_number(db, po.tenant_id, received_at),
        received_at=received_at,
        delivery_note_number=delivery_note_number,
        status=GrnStatus.draft.value,
        notes=notes,
        received_by_user_id=received_by_user_id,
    )
    db.add(grn)
    db.flush()

    from app.pilot.routes.catalog_routes import _variant_or_404  # type: ignore

    for idx, ln in enumerate(lines_input, start=1):
        pol = db.query(PurchaseOrderLine).filter(
            PurchaseOrderLine.id == ln["po_line_id"],
            PurchaseOrderLine.po_id == po.id,
        ).first()
        if not pol:
            raise ValueError(f"السطر {idx}: po_line_id غير صالح")

        qty_received = Decimal(str(ln["qty_received"]))
        qty_accepted = Decimal(str(ln.get("qty_accepted", qty_received)))
        qty_rejected = Decimal(str(ln.get("qty_rejected", 0)))
        if qty_received > (pol.qty_ordered - pol.qty_received):
            raise ValueError(
                f"السطر {idx}: qty_received ({qty_received}) يتجاوز المتبقّي "
                f"({pol.qty_ordered - pol.qty_received})"
            )

        grn_line = GoodsReceiptLine(
            tenant_id=po.tenant_id,
            grn_id=grn.id,
            po_line_id=pol.id,
            line_number=idx,
            variant_id=pol.variant_id,
            sku=pol.sku,
            description=pol.description,
            qty_received=qty_received,
            qty_accepted=qty_accepted,
            qty_rejected=qty_rejected,
            rejection_reason=ln.get("rejection_reason"),
            unit_cost=pol.unit_price,
            uom=pol.uom,
        )
        db.add(grn_line)

        # StockMovement (إذا كان variant — المنتجات فقط، الخدمات تتخطّى)
        if pol.variant_id and qty_accepted > 0:
            variant = db.query(ProductVariant).filter(
                ProductVariant.id == pol.variant_id
            ).first()
            level = db.query(StockLevel).filter(
                StockLevel.warehouse_id == warehouse.id,
                StockLevel.variant_id == variant.id,
            ).first()
            if not level:
                level = StockLevel(
                    tenant_id=po.tenant_id,
                    warehouse_id=warehouse.id,
                    variant_id=variant.id,
                )
                db.add(level)
                db.flush()

            unit_cost = pol.unit_price
            # weighted-avg cost update
            new_on_hand = level.on_hand + qty_accepted
            if new_on_hand > 0:
                level.weighted_avg_cost = (
                    (level.on_hand * level.weighted_avg_cost + qty_accepted * unit_cost)
                    / new_on_hand
                )
            level.last_cost = unit_cost
            level.on_hand = new_on_hand
            level.available = level.on_hand - level.reserved
            level.last_movement_at = datetime.now(timezone.utc)

            mv = StockMovement(
                tenant_id=po.tenant_id,
                warehouse_id=warehouse.id,
                variant_id=variant.id,
                qty=qty_accepted,
                unit_cost=unit_cost,
                total_cost=qty_accepted * unit_cost,
                reason="po_receipt",
                reference_type="grn",
                reference_id=grn.id,
                reference_number=grn.grn_number,
                balance_after=level.on_hand,
                performed_at=datetime.now(timezone.utc),
                performed_by_user_id=received_by_user_id,
                branch_id=warehouse.branch_id,
            )
            db.add(mv)
            db.flush()
            grn_line.stock_movement_id = mv.id

            # تحديث variant rollup
            all_levels = db.query(StockLevel).filter(StockLevel.variant_id == variant.id).all()
            variant.total_on_hand = sum((lv.on_hand for lv in all_levels), Decimal("0"))
            variant.total_available = variant.total_on_hand - variant.total_reserved

        # تحديث qty_received على الـ PO line
        pol.qty_received = (pol.qty_received or Decimal("0")) + qty_received

    # تحديث حالة الـ PO
    total_ordered = sum((l.qty_ordered for l in po.lines), Decimal("0"))
    total_received = sum((l.qty_received for l in po.lines), Decimal("0"))
    if total_received >= total_ordered:
        po.status = PoStatus.fully_received.value
    else:
        po.status = PoStatus.partially_received.value

    grn.status = GrnStatus.confirmed.value
    grn.confirmed_at = datetime.now(timezone.utc)
    db.flush()
    return grn


# ══════════════════════════════════════════════════════════════════════════
# Purchase Invoice + auto-post GL
# ══════════════════════════════════════════════════════════════════════════

def create_purchase_invoice(
    db: Session, *, entity: Entity, vendor: Vendor,
    invoice_date: date, lines_input: list[dict],
    po: Optional[PurchaseOrder] = None,
    vendor_invoice_number: Optional[str] = None,
    due_date: Optional[date] = None,
    shipping: Decimal = Decimal("0"),
    notes: Optional[str] = None,
    created_by_user_id: Optional[str] = None,
) -> PurchaseInvoice:
    currency = vendor.default_currency or entity.functional_currency

    inv = PurchaseInvoice(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        vendor_id=vendor.id,
        po_id=po.id if po else None,
        invoice_number=next_invoice_number(db, entity.id, invoice_date),
        vendor_invoice_number=vendor_invoice_number,
        invoice_date=invoice_date,
        due_date=due_date,
        currency=currency,
        shipping=shipping,
        status=PurchaseInvoiceStatus.draft.value,
        notes=notes,
        created_by_user_id=created_by_user_id,
    )
    db.add(inv)
    db.flush()

    subtotal = Decimal("0")
    disc_total = Decimal("0")
    taxable = Decimal("0")
    vat_total = Decimal("0")

    for idx, ln in enumerate(lines_input, start=1):
        qty = Decimal(str(ln.get("qty", 1)))
        unit_cost = Decimal(str(ln["unit_cost"]))
        line_sub = q2(qty * unit_cost)
        disc = q2(ln.get("discount_amount", 0))
        line_tax = line_sub - disc
        vat_code = ln.get("vat_code", "standard")
        vat_rate = Decimal("0") if vat_code in ("zero_rated", "exempt") else Decimal(str(ln.get("vat_rate_pct", 15)))
        line_vat = q2(line_tax * vat_rate / Decimal("100"))
        line_tot = line_tax + line_vat

        il = PurchaseInvoiceLine(
            tenant_id=entity.tenant_id,
            invoice_id=inv.id,
            po_line_id=ln.get("po_line_id"),
            line_number=idx,
            variant_id=ln.get("variant_id"),
            sku=ln.get("sku"),
            description=ln["description"],
            qty=qty,
            unit_cost=unit_cost,
            discount_amount=disc,
            vat_code=vat_code,
            vat_rate_pct=vat_rate,
            line_subtotal=line_sub,
            line_taxable=line_tax,
            line_vat=line_vat,
            line_total=line_tot,
            gl_account_id=ln.get("gl_account_id"),
            cost_center_id=ln.get("cost_center_id"),
        )
        db.add(il)
        subtotal += line_sub
        disc_total += disc
        taxable += line_tax
        vat_total += line_vat

        # تحديث qty_invoiced على الـ PO line
        if ln.get("po_line_id"):
            pol = db.query(PurchaseOrderLine).filter(PurchaseOrderLine.id == ln["po_line_id"]).first()
            if pol:
                pol.qty_invoiced = (pol.qty_invoiced or Decimal("0")) + qty

    inv.subtotal = subtotal
    inv.discount_total = disc_total
    inv.taxable_amount = taxable
    inv.vat_total = vat_total
    inv.grand_total = taxable + vat_total + shipping
    inv.amount_due = inv.grand_total
    db.flush()
    return inv


def post_purchase_invoice_to_gl(db: Session, invoice_id: str) -> JournalEntry:
    """ترحيل فاتورة مورد إلى الأستاذ العام.

    منطق القيد (بفرض بضاعة + VAT):
      Dr 1140 Inventory   = taxable (إذا كان variant)
      Dr 5xxx Expense     = taxable (إذا كان خدمة)
      Dr 1150 VAT Input   = vat_total
      Cr 2110 AP (vendor) = grand_total
    """
    inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == invoice_id).first()
    if not inv:
        raise ValueError("الفاتورة غير موجودة")
    if inv.status == PurchaseInvoiceStatus.posted.value:
        if inv.journal_entry_id:
            return db.query(JournalEntry).filter(JournalEntry.id == inv.journal_entry_id).first()

    entity = db.query(Entity).filter(Entity.id == inv.entity_id).first()
    vendor = db.query(Vendor).filter(Vendor.id == inv.vendor_id).first()

    lines_input = []

    # لكل بند: dr Inventory أو Expense
    for il in db.query(PurchaseInvoiceLine).filter(PurchaseInvoiceLine.invoice_id == inv.id).order_by(PurchaseInvoiceLine.line_number).all():
        if il.gl_account_id:
            # account_id directly; need to lookup code
            acc = db.query(GLAccount).filter(GLAccount.id == il.gl_account_id).first()
            acct_code = acc.code if acc else None
        elif il.variant_id:
            acct_code = "1140"  # inventory
        else:
            acct_code = "5600"  # general & admin (fallback)

        lines_input.append({
            "account_code": acct_code,
            "debit": il.line_taxable,
            "credit": 0,
            "description": il.description[:100],
            "reference": inv.invoice_number,
            "cost_center_id": il.cost_center_id,
            "profit_center_id": il.profit_center_id,
        })

    # VAT Input
    if inv.vat_total and inv.vat_total > 0:
        lines_input.append({
            "account_code": "1150",
            "debit": inv.vat_total,
            "credit": 0,
            "description": f"VAT Input — {inv.invoice_number}",
            "reference": inv.invoice_number,
            "vat_code": "standard",
            "vat_amount": inv.vat_total,
        })

    # shipping (separate line if present)
    if inv.shipping and inv.shipping > 0:
        lines_input.append({
            "account_code": "5600",
            "debit": inv.shipping,
            "credit": 0,
            "description": f"شحن — {inv.invoice_number}",
            "reference": inv.invoice_number,
        })

    # Credit AP (vendor)
    lines_input.append({
        "account_code": "2110",
        "debit": 0,
        "credit": inv.grand_total,
        "description": f"{vendor.legal_name_ar} — {inv.invoice_number}",
        "reference": inv.invoice_number,
        "partner_type": "vendor",
        "partner_id": vendor.id,
        "partner_name": vendor.legal_name_ar,
    })

    je = build_journal_entry(
        db, entity=entity,
        kind=JournalEntryKind.auto_po.value,
        je_date=inv.invoice_date,
        memo_ar=f"فاتورة مورد — {vendor.legal_name_ar} — {inv.invoice_number}",
        lines_input=lines_input,
        source_type="purchase_invoice",
        source_id=inv.id,
        source_reference=inv.invoice_number,
        auto_post=True,
    )
    inv.journal_entry_id = je.id
    inv.status = PurchaseInvoiceStatus.posted.value
    inv.posted_at = datetime.now(timezone.utc)

    # تحديث رصيد المورد
    vendor.outstanding_balance = (vendor.outstanding_balance or Decimal("0")) + inv.grand_total
    vendor.total_purchases_ytd = (vendor.total_purchases_ytd or Decimal("0")) + inv.grand_total
    vendor.last_purchase_date = inv.invoice_date

    db.flush()
    return je


# ══════════════════════════════════════════════════════════════════════════
# Vendor Payment + auto-post GL
# ══════════════════════════════════════════════════════════════════════════

def create_vendor_payment(
    db: Session, *, entity: Entity, vendor: Vendor,
    amount: Decimal, payment_date: date, method: str,
    invoice: Optional[PurchaseInvoice] = None,
    paid_from_account_code: str = "1110",   # 1110 cash or 1120 bank
    reference_number: Optional[str] = None,
    notes: Optional[str] = None,
    created_by_user_id: Optional[str] = None,
    auto_post: bool = True,
) -> VendorPayment:
    currency = vendor.default_currency or entity.functional_currency
    vp = VendorPayment(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        vendor_id=vendor.id,
        invoice_id=invoice.id if invoice else None,
        payment_number=next_payment_number(db, entity.id, payment_date),
        payment_date=payment_date,
        method=method,
        amount=q2(amount),
        currency=currency,
        reference_number=reference_number,
        notes=notes,
        created_by_user_id=created_by_user_id,
    )
    db.add(vp)
    db.flush()

    if auto_post:
        # JE: Dr 2110 AP / Cr 1110 or 1120
        lines_input = [
            {
                "account_code": "2110",
                "debit": vp.amount,
                "credit": 0,
                "description": f"دفعة — {vendor.legal_name_ar}",
                "reference": vp.payment_number,
                "partner_type": "vendor",
                "partner_id": vendor.id,
                "partner_name": vendor.legal_name_ar,
            },
            {
                "account_code": paid_from_account_code,
                "debit": 0,
                "credit": vp.amount,
                "description": f"دفع — {vp.payment_number}",
                "reference": vp.payment_number,
            },
        ]
        je = build_journal_entry(
            db, entity=entity,
            kind=JournalEntryKind.auto_po.value,
            je_date=payment_date,
            memo_ar=f"سند صرف — {vendor.legal_name_ar} — {vp.payment_number}",
            lines_input=lines_input,
            source_type="vendor_payment",
            source_id=vp.id,
            source_reference=vp.payment_number,
            auto_post=True,
        )
        vp.journal_entry_id = je.id
        vp.posted_at = datetime.now(timezone.utc)

    # تحديث الفاتورة
    if invoice:
        invoice.amount_paid = (invoice.amount_paid or Decimal("0")) + vp.amount
        invoice.amount_due = invoice.grand_total - invoice.amount_paid
        if invoice.amount_due <= Decimal("0.01"):
            invoice.status = PurchaseInvoiceStatus.paid.value
            invoice.paid_at = datetime.now(timezone.utc)
        else:
            invoice.status = PurchaseInvoiceStatus.partially_paid.value

    # تحديث رصيد المورد
    vendor.outstanding_balance = (vendor.outstanding_balance or Decimal("0")) - vp.amount

    db.flush()
    return vp


# ══════════════════════════════════════════════════════════════════════════
# Vendor Ledger
# ══════════════════════════════════════════════════════════════════════════

def vendor_ledger(db: Session, *, vendor_id: str) -> dict:
    """يعيد كشف حساب المورد: الفواتير، الدفعات، الرصيد المتبقّي."""
    vendor = db.query(Vendor).filter(Vendor.id == vendor_id).first()
    if not vendor:
        raise ValueError("المورد غير موجود")

    invoices = db.query(PurchaseInvoice).filter(
        PurchaseInvoice.vendor_id == vendor_id,
        PurchaseInvoice.is_deleted == False,  # noqa: E712
    ).order_by(PurchaseInvoice.invoice_date).all()

    payments = db.query(VendorPayment).filter(
        VendorPayment.vendor_id == vendor_id,
    ).order_by(VendorPayment.payment_date).all()

    total_invoiced = sum((i.grand_total for i in invoices), Decimal("0"))
    total_paid = sum((p.amount for p in payments), Decimal("0"))
    outstanding = total_invoiced - total_paid

    # Aging buckets
    today = date.today()
    buckets = {"current": Decimal("0"), "1-30": Decimal("0"),
               "31-60": Decimal("0"), "61-90": Decimal("0"), ">90": Decimal("0")}
    for i in invoices:
        if i.amount_due <= 0:
            continue
        due = i.due_date or i.invoice_date
        days_overdue = (today - due).days
        if days_overdue <= 0:
            buckets["current"] += i.amount_due
        elif days_overdue <= 30:
            buckets["1-30"] += i.amount_due
        elif days_overdue <= 60:
            buckets["31-60"] += i.amount_due
        elif days_overdue <= 90:
            buckets["61-90"] += i.amount_due
        else:
            buckets[">90"] += i.amount_due

    return {
        "vendor_id": vendor.id,
        "vendor_code": vendor.code,
        "vendor_name_ar": vendor.legal_name_ar,
        "currency": vendor.default_currency,
        "total_invoiced": float(total_invoiced),
        "total_paid": float(total_paid),
        "outstanding_balance": float(outstanding),
        "invoice_count": len(invoices),
        "payment_count": len(payments),
        "aging": {k: float(v) for k, v in buckets.items()},
        "last_invoice_date": invoices[-1].invoice_date.isoformat() if invoices else None,
        "last_payment_date": payments[-1].payment_date.isoformat() if payments else None,
    }
