"""Purchasing models — Vendors + PO + GRN + Purchase Invoice + Vendor Payment.

دورة الشراء الكاملة:

  Vendor (المورد)
    └── PurchaseOrder (طلب شراء — تعهّد مبدئي)
          ├── lines: PurchaseOrderLine
          └── GoodsReceipt (محضر استلام — عند وصول البضاعة)
                  ├── lines: GoodsReceiptLine
                  │     └── يُنشئ StockMovement موجب
                  └── PurchaseInvoice (فاتورة المورد — مستند محاسبي)
                        ├── lines: PurchaseInvoiceLine
                        └── auto-JE:
                            Dr 1140 Inventory (or 5xxx expense)
                            Dr 1150 VAT Input
                            Cr 2110 Accounts Payable (vendor balance ↑)
                        └── VendorPayment (سند صرف للمورد)
                              auto-JE:
                                Dr 2110 AP (vendor balance ↓)
                                Cr 1110/1120 Cash/Bank

"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, Date, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ══════════════════════════════════════════════════════════════════════════
# Enums
# ══════════════════════════════════════════════════════════════════════════

class VendorKind(str, enum.Enum):
    goods = "goods"              # مورد بضائع
    services = "services"        # مورد خدمات (كهرباء، صيانة)
    both = "both"
    employee = "employee"        # مصاريف موظفين
    government = "government"    # جهات حكومية (GOSI، ضرائب)


class PaymentTerms(str, enum.Enum):
    cash = "cash"            # نقد فوري
    net_0 = "net_0"          # عند الاستلام
    net_15 = "net_15"
    net_30 = "net_30"
    net_45 = "net_45"
    net_60 = "net_60"
    net_90 = "net_90"
    advance = "advance"      # دفعة مقدمة


class PoStatus(str, enum.Enum):
    draft = "draft"
    submitted = "submitted"       # للاعتماد
    approved = "approved"
    issued = "issued"             # أُرسل للمورد
    partially_received = "partially_received"
    fully_received = "fully_received"
    invoiced = "invoiced"
    closed = "closed"
    cancelled = "cancelled"


class GrnStatus(str, enum.Enum):
    draft = "draft"
    confirmed = "confirmed"       # استُلمت البضاعة فعلاً (StockMovement أُنشئ)
    rejected = "rejected"


class PurchaseInvoiceStatus(str, enum.Enum):
    draft = "draft"
    submitted = "submitted"
    approved = "approved"
    posted = "posted"             # مُرحّلة للـ GL
    partially_paid = "partially_paid"
    paid = "paid"
    cancelled = "cancelled"


class VendorPaymentMethod(str, enum.Enum):
    cash = "cash"
    bank_transfer = "bank_transfer"
    cheque = "cheque"
    credit_card = "credit_card"
    other = "other"


# ══════════════════════════════════════════════════════════════════════════
# Vendor
# ══════════════════════════════════════════════════════════════════════════

class Vendor(Base):
    """المورد — شركة أو فرد نشتري منه."""
    __tablename__ = "pilot_vendors"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(30), nullable=False)             # V-0001, ACME-001
    legal_name_ar = Column(String(255), nullable=False)
    legal_name_en = Column(String(255), nullable=True)
    trade_name = Column(String(255), nullable=True)

    # التصنيف
    kind = Column(String(20), nullable=False, default=VendorKind.goods.value)
    category = Column(String(50), nullable=True)           # raw_material, utility, services, ...

    # الهوية القانونية
    country = Column(String(2), nullable=False, default="SA")
    cr_number = Column(String(50), nullable=True)
    vat_number = Column(String(50), nullable=True)         # 15 رقم سعودي / TRN إماراتي

    # العملة الافتراضية للتعامل
    default_currency = Column(String(3), nullable=False, default="SAR")

    # شروط الدفع
    payment_terms = Column(String(20), nullable=False, default=PaymentTerms.net_30.value)
    credit_limit = Column(Numeric(18, 2), nullable=True)

    # حسابات محاسبية (للتبسيط: حساب مراقبة AP العام 2110 افتراضياً)
    default_payable_account_id = Column(String(36), nullable=True)   # يشير إلى GLAccount
    # للمصروفات المباشرة بدون مخزون (utilities etc)
    default_expense_account_id = Column(String(36), nullable=True)

    # معلومات البنك (لدفعات WPS الخارجية)
    bank_name = Column(String(100), nullable=True)
    bank_account_number = Column(String(50), nullable=True)
    bank_iban = Column(String(34), nullable=True)
    bank_swift = Column(String(20), nullable=True)

    # الاتصال
    contact_name = Column(String(150), nullable=True)
    email = Column(String(255), nullable=True)
    phone = Column(String(30), nullable=True)
    whatsapp = Column(String(30), nullable=True)

    # العنوان
    address_line1 = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)
    postal_code = Column(String(20), nullable=True)

    # الحالة
    is_active = Column(Boolean, nullable=False, default=True)
    is_preferred = Column(Boolean, nullable=False, default=False)
    on_hold = Column(Boolean, nullable=False, default=False)       # معلّق (بسبب نزاع مثلاً)
    hold_reason = Column(String(500), nullable=True)

    # ملخص سريع (مُحدّث عند كل معاملة)
    total_purchases_ytd = Column(Numeric(18, 2), nullable=False, default=0)
    outstanding_balance = Column(Numeric(18, 2), nullable=False, default=0)  # المتبقّي له
    last_purchase_date = Column(Date, nullable=True)

    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_vendor_tenant_code"),
        Index("ix_pilot_vendor_tenant_active", "tenant_id", "is_active"),
    )


# ══════════════════════════════════════════════════════════════════════════
# Purchase Order
# ══════════════════════════════════════════════════════════════════════════

class PurchaseOrder(Base):
    """طلب شراء — تعهّد بالشراء قبل الاستلام."""
    __tablename__ = "pilot_purchase_orders"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="SET NULL"), nullable=True, index=True)
    vendor_id = Column(String(36), ForeignKey("pilot_vendors.id", ondelete="RESTRICT"), nullable=False, index=True)

    po_number = Column(String(50), nullable=False)           # PO-2026-04-0001

    # التواريخ
    order_date = Column(Date, nullable=False)
    expected_delivery_date = Column(Date, nullable=True)

    # العملة
    currency = Column(String(3), nullable=False)
    exchange_rate = Column(Numeric(18, 8), nullable=False, default=1)

    # الإجماليات (بعملة المورد)
    subtotal = Column(Numeric(18, 2), nullable=False, default=0)
    discount_total = Column(Numeric(18, 2), nullable=False, default=0)
    taxable_amount = Column(Numeric(18, 2), nullable=False, default=0)
    vat_total = Column(Numeric(18, 2), nullable=False, default=0)
    shipping = Column(Numeric(18, 2), nullable=False, default=0)
    grand_total = Column(Numeric(18, 2), nullable=False, default=0)

    # المستودع المُستهدف (للاستلام)
    destination_warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="SET NULL"), nullable=True)

    # شروط
    payment_terms = Column(String(20), nullable=False, default=PaymentTerms.net_30.value)
    notes_to_vendor = Column(Text, nullable=True)
    internal_notes = Column(Text, nullable=True)

    # الحالة
    status = Column(String(30), nullable=False, default=PoStatus.draft.value)

    # الاعتماد
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    submitted_by_user_id = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    approved_by_user_id = Column(String(36), nullable=True)
    issued_at = Column(DateTime(timezone=True), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)

    lines = relationship("PurchaseOrderLine", back_populates="po", cascade="all, delete-orphan")
    receipts = relationship("GoodsReceipt", back_populates="po")

    __table_args__ = (
        UniqueConstraint("entity_id", "po_number", name="uq_pilot_po_entity_number"),
        Index("ix_pilot_po_vendor_status", "vendor_id", "status"),
    )


class PurchaseOrderLine(Base):
    """بند في طلب شراء."""
    __tablename__ = "pilot_purchase_order_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    po_id = Column(String(36), ForeignKey("pilot_purchase_orders.id", ondelete="CASCADE"), nullable=False, index=True)

    line_number = Column(Integer, nullable=False)

    # الصنف — إما متغيّر منتج، أو وصف حر (للخدمات)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="SET NULL"), nullable=True)
    sku = Column(String(80), nullable=True)
    description = Column(String(500), nullable=False)          # نص الوصف حتى للخدمات

    # الكميات
    qty_ordered = Column(Numeric(18, 3), nullable=False, default=1)
    qty_received = Column(Numeric(18, 3), nullable=False, default=0)      # تُحدَّث من GRN
    qty_invoiced = Column(Numeric(18, 3), nullable=False, default=0)      # تُحدَّث من PI
    uom = Column(String(20), nullable=False, default="piece")

    # التسعير (بعملة الـ PO)
    unit_price = Column(Numeric(18, 4), nullable=False)
    discount_pct = Column(Numeric(6, 3), nullable=True)
    discount_amount = Column(Numeric(18, 2), nullable=False, default=0)
    vat_code = Column(String(20), nullable=False, default="standard")
    vat_rate_pct = Column(Numeric(6, 3), nullable=False, default=15)

    # محسوبات
    line_subtotal = Column(Numeric(18, 2), nullable=False, default=0)
    line_taxable = Column(Numeric(18, 2), nullable=False, default=0)
    line_vat = Column(Numeric(18, 2), nullable=False, default=0)
    line_total = Column(Numeric(18, 2), nullable=False, default=0)

    # حساب GL الافتراضي لهذا البند (للخدمات/المصاريف)
    expense_account_id = Column(String(36), nullable=True)
    cost_center_id = Column(String(36), nullable=True)

    po = relationship("PurchaseOrder", back_populates="lines")
    variant = relationship("ProductVariant")

    __table_args__ = (
        UniqueConstraint("po_id", "line_number", name="uq_pilot_po_line_num"),
    )


# ══════════════════════════════════════════════════════════════════════════
# Goods Receipt (GRN)
# ══════════════════════════════════════════════════════════════════════════

class GoodsReceipt(Base):
    """محضر استلام بضاعة — يُنشئ StockMovement عند التأكيد."""
    __tablename__ = "pilot_goods_receipts"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    po_id = Column(String(36), ForeignKey("pilot_purchase_orders.id", ondelete="RESTRICT"), nullable=False, index=True)
    warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="RESTRICT"), nullable=False)

    grn_number = Column(String(50), nullable=False)           # GRN-2026-04-0001
    received_at = Column(Date, nullable=False)
    delivery_note_number = Column(String(100), nullable=True)
    delivery_driver_name = Column(String(150), nullable=True)

    status = Column(String(20), nullable=False, default=GrnStatus.draft.value)

    notes = Column(Text, nullable=True)
    received_by_user_id = Column(String(36), nullable=True)
    confirmed_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    po = relationship("PurchaseOrder", back_populates="receipts")
    lines = relationship("GoodsReceiptLine", back_populates="grn", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "grn_number", name="uq_pilot_grn_tenant_number"),
    )


class GoodsReceiptLine(Base):
    __tablename__ = "pilot_goods_receipt_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    grn_id = Column(String(36), ForeignKey("pilot_goods_receipts.id", ondelete="CASCADE"), nullable=False, index=True)
    po_line_id = Column(String(36), ForeignKey("pilot_purchase_order_lines.id", ondelete="RESTRICT"), nullable=False)

    line_number = Column(Integer, nullable=False)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="RESTRICT"), nullable=True)
    sku = Column(String(80), nullable=True)
    description = Column(String(500), nullable=False)

    qty_received = Column(Numeric(18, 3), nullable=False)
    unit_cost = Column(Numeric(18, 4), nullable=False, default=0)
    uom = Column(String(20), nullable=False, default="piece")

    # الحركة المُنشأة
    stock_movement_id = Column(String(36), nullable=True)

    # حالات تحكّم الجودة
    qty_accepted = Column(Numeric(18, 3), nullable=True)
    qty_rejected = Column(Numeric(18, 3), nullable=False, default=0)
    rejection_reason = Column(String(500), nullable=True)

    grn = relationship("GoodsReceipt", back_populates="lines")


# ══════════════════════════════════════════════════════════════════════════
# Purchase Invoice
# ══════════════════════════════════════════════════════════════════════════

class PurchaseInvoice(Base):
    """فاتورة مورد — مستند محاسبي يرفع الذمم الدائنة ويسجّل VAT Input."""
    __tablename__ = "pilot_purchase_invoices"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    vendor_id = Column(String(36), ForeignKey("pilot_vendors.id", ondelete="RESTRICT"), nullable=False, index=True)
    po_id = Column(String(36), ForeignKey("pilot_purchase_orders.id", ondelete="SET NULL"), nullable=True, index=True)

    invoice_number = Column(String(50), nullable=False)          # رقمنا الداخلي
    vendor_invoice_number = Column(String(100), nullable=True)   # رقم المورد الأصلي

    invoice_date = Column(Date, nullable=False)
    due_date = Column(Date, nullable=True)

    # العملة
    currency = Column(String(3), nullable=False)
    exchange_rate = Column(Numeric(18, 8), nullable=False, default=1)

    # الإجماليات
    subtotal = Column(Numeric(18, 2), nullable=False, default=0)
    discount_total = Column(Numeric(18, 2), nullable=False, default=0)
    taxable_amount = Column(Numeric(18, 2), nullable=False, default=0)
    vat_total = Column(Numeric(18, 2), nullable=False, default=0)
    shipping = Column(Numeric(18, 2), nullable=False, default=0)
    grand_total = Column(Numeric(18, 2), nullable=False, default=0)

    # حالة الدفع
    amount_paid = Column(Numeric(18, 2), nullable=False, default=0)
    amount_due = Column(Numeric(18, 2), nullable=False, default=0)

    # الربط العكسي
    journal_entry_id = Column(String(36), nullable=True)         # عند الترحيل

    status = Column(String(20), nullable=False, default=PurchaseInvoiceStatus.draft.value)
    posted_at = Column(DateTime(timezone=True), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)

    notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    is_deleted = Column(Boolean, nullable=False, default=False)

    lines = relationship("PurchaseInvoiceLine", back_populates="invoice", cascade="all, delete-orphan")
    payments = relationship("VendorPayment", back_populates="invoice")

    __table_args__ = (
        UniqueConstraint("entity_id", "invoice_number", name="uq_pilot_pi_entity_number"),
        Index("ix_pilot_pi_vendor_status", "vendor_id", "status"),
    )


class PurchaseInvoiceLine(Base):
    __tablename__ = "pilot_purchase_invoice_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("pilot_purchase_invoices.id", ondelete="CASCADE"), nullable=False, index=True)
    po_line_id = Column(String(36), ForeignKey("pilot_purchase_order_lines.id", ondelete="SET NULL"), nullable=True)

    line_number = Column(Integer, nullable=False)
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="SET NULL"), nullable=True)
    sku = Column(String(80), nullable=True)
    description = Column(String(500), nullable=False)

    qty = Column(Numeric(18, 3), nullable=False, default=1)
    unit_cost = Column(Numeric(18, 4), nullable=False)
    discount_amount = Column(Numeric(18, 2), nullable=False, default=0)

    vat_code = Column(String(20), nullable=False, default="standard")
    vat_rate_pct = Column(Numeric(6, 3), nullable=False, default=15)

    line_subtotal = Column(Numeric(18, 2), nullable=False, default=0)
    line_taxable = Column(Numeric(18, 2), nullable=False, default=0)
    line_vat = Column(Numeric(18, 2), nullable=False, default=0)
    line_total = Column(Numeric(18, 2), nullable=False, default=0)

    # حساب GL (مخزون vs مصروف مباشر)
    gl_account_id = Column(String(36), nullable=True)             # افتراضياً 1140 أو 5xxx
    cost_center_id = Column(String(36), nullable=True)
    profit_center_id = Column(String(36), nullable=True)

    invoice = relationship("PurchaseInvoice", back_populates="lines")


# ══════════════════════════════════════════════════════════════════════════
# Vendor Payment
# ══════════════════════════════════════════════════════════════════════════

class VendorPayment(Base):
    """سند صرف للمورد — قد يُخصَّص على فاتورة واحدة أو أكثر."""
    __tablename__ = "pilot_vendor_payments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    vendor_id = Column(String(36), ForeignKey("pilot_vendors.id", ondelete="RESTRICT"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("pilot_purchase_invoices.id", ondelete="SET NULL"), nullable=True, index=True)

    payment_number = Column(String(50), nullable=False)           # VP-2026-04-0001
    payment_date = Column(Date, nullable=False)

    method = Column(String(30), nullable=False, default=VendorPaymentMethod.bank_transfer.value)
    amount = Column(Numeric(18, 2), nullable=False)
    currency = Column(String(3), nullable=False)
    exchange_rate = Column(Numeric(18, 8), nullable=False, default=1)

    # المصدر النقدي
    paid_from_account_id = Column(String(36), nullable=True)      # يشير لحساب 1110 أو 1120

    # المراجع
    reference_number = Column(String(100), nullable=True)         # رقم الحوالة/الشيك
    bank_reference = Column(String(100), nullable=True)

    # الترحيل
    journal_entry_id = Column(String(36), nullable=True)
    posted_at = Column(DateTime(timezone=True), nullable=True)

    notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    invoice = relationship("PurchaseInvoice", back_populates="payments")

    __table_args__ = (
        UniqueConstraint("entity_id", "payment_number", name="uq_pilot_vp_entity_number"),
        Index("ix_pilot_vp_vendor", "vendor_id"),
    )
