"""Customer module — mirrors Vendor on the sales side.

دورة المبيعات:
  Customer (عميل)
    └── SalesOrder / SalesInvoice (فاتورة بيع)
          ├── lines: SalesInvoiceLine
          └── auto-JE:
              Dr 1130 Accounts Receivable (customer balance ↑)
              Cr 4100 Revenue
              Cr 2150 VAT Output
              (optional) Cr 1140 Inventory  +  Dr 5100 COGS
          └── CustomerPayment
                auto-JE:
                  Dr 1110/1120 Cash/Bank
                  Cr 1130 AR (customer balance ↓)
"""

import enum
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, ForeignKey,
    JSON, Numeric, Date, UniqueConstraint, Index,
)
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


class CustomerKind(str, enum.Enum):
    individual = "individual"    # فرد
    company = "company"          # شركة
    government = "government"    # جهة حكومية


class CustomerPaymentTerms(str, enum.Enum):
    cash = "cash"
    net_0 = "net_0"
    net_15 = "net_15"
    net_30 = "net_30"
    net_45 = "net_45"
    net_60 = "net_60"
    net_90 = "net_90"


# ══════════════════════════════════════════════════════════════════════════
# Customer
# ══════════════════════════════════════════════════════════════════════════


class Customer(Base):
    """عميل — الطرف المقابل لفواتير البيع وكشف الحساب المدين."""
    __tablename__ = "pilot_customers"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    # الترميز الداخلي
    code = Column(String(20), nullable=False)                   # CUST-0001, C0001
    name_ar = Column(String(255), nullable=False)
    name_en = Column(String(255), nullable=True)

    # التصنيف
    kind = Column(String(20), nullable=False, default=CustomerKind.company.value)

    # الاتصال
    email = Column(String(120), nullable=True)
    phone = Column(String(40), nullable=True)
    mobile = Column(String(40), nullable=True)
    contact_person = Column(String(120), nullable=True)

    # الضريبة
    vat_number = Column(String(20), nullable=True)              # 15-digit VAT
    cr_number = Column(String(40), nullable=True)               # سجل تجاري

    # العنوان
    address_street = Column(String(255), nullable=True)
    address_city = Column(String(80), nullable=True)
    address_country = Column(String(2), nullable=True, default="SA")
    address_postal_code = Column(String(20), nullable=True)

    # شروط التعامل
    currency = Column(String(3), nullable=False, default="SAR")
    payment_terms = Column(String(20), nullable=False, default=CustomerPaymentTerms.net_30.value)
    credit_limit = Column(Numeric(18, 2), nullable=True)
    default_ar_account_id = Column(String(36), ForeignKey("pilot_gl_accounts.id"), nullable=True)

    # Tags for segmentation (retail / wholesale / VIP / government)
    tags = Column(JSON, nullable=False, default=list)

    # الحالة
    is_active = Column(Boolean, nullable=False, default=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    notes = Column(String(1000), nullable=True)

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_customers_tenant_code"),
        Index("ix_pilot_customers_tenant", "tenant_id"),
        Index("ix_pilot_customers_name", "tenant_id", "name_ar"),
        Index("ix_pilot_customers_vat", "vat_number"),
    )


# ══════════════════════════════════════════════════════════════════════════
# Sales Invoice (B2B) — POS is covered separately in pos_routes
# ══════════════════════════════════════════════════════════════════════════


class SalesInvoiceStatus(str, enum.Enum):
    draft = "draft"              # قيد الإعداد
    issued = "issued"            # مُصدرة (بعد الترحيل)
    partially_paid = "partially_paid"
    paid = "paid"
    cancelled = "cancelled"


class SalesInvoice(Base):
    """فاتورة بيع B2B — تمر على دليل الحسابات والـ JE."""
    __tablename__ = "pilot_sales_invoices"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    customer_id = Column(String(36), ForeignKey("pilot_customers.id"), nullable=False, index=True)

    # الترميز
    invoice_number = Column(String(50), nullable=False)         # INV-2026-0001
    issue_date = Column(Date, nullable=False)
    due_date = Column(Date, nullable=True)

    # الحالة
    status = Column(String(20), nullable=False, default=SalesInvoiceStatus.draft.value)

    # العملة والمبالغ
    currency = Column(String(3), nullable=False, default="SAR")
    subtotal = Column(Numeric(20, 2), nullable=False, default=0)
    vat_amount = Column(Numeric(20, 2), nullable=False, default=0)
    total = Column(Numeric(20, 2), nullable=False, default=0)
    paid_amount = Column(Numeric(20, 2), nullable=False, default=0)

    # المرجع المحاسبي (بعد الإصدار)
    journal_entry_id = Column(String(36), ForeignKey("pilot_journal_entries.id"), nullable=True)
    zatca_submission_id = Column(String(36), nullable=True)

    # الوصف
    memo = Column(String(500), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)
    issued_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    lines = relationship("SalesInvoiceLine", back_populates="invoice", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("entity_id", "invoice_number", name="uq_pilot_si_entity_number"),
        Index("ix_pilot_si_customer", "customer_id"),
        Index("ix_pilot_si_status", "status"),
        Index("ix_pilot_si_date", "issue_date"),
    )


class SalesInvoiceLine(Base):
    """بند فاتورة بيع."""
    __tablename__ = "pilot_sales_invoice_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    invoice_id = Column(String(36), ForeignKey("pilot_sales_invoices.id", ondelete="CASCADE"), nullable=False, index=True)
    line_number = Column(Integer, nullable=False)

    # المنتج
    product_id = Column(String(36), ForeignKey("pilot_products.id"), nullable=True)
    variant_id = Column(String(36), nullable=True)
    description = Column(String(500), nullable=False)

    # الكمية والسعر
    quantity = Column(Numeric(18, 4), nullable=False, default=1)
    unit_price = Column(Numeric(18, 4), nullable=False, default=0)
    discount_pct = Column(Numeric(8, 4), nullable=False, default=0)
    discount_amount = Column(Numeric(18, 2), nullable=False, default=0)

    # الضريبة
    vat_code = Column(String(20), nullable=True, default="15")
    vat_rate = Column(Numeric(8, 4), nullable=False, default=15)

    # المجاميع
    subtotal = Column(Numeric(18, 2), nullable=False, default=0)   # (qty * price) - discount
    vat_amount = Column(Numeric(18, 2), nullable=False, default=0)
    line_total = Column(Numeric(18, 2), nullable=False, default=0)  # subtotal + vat

    # الحساب المحاسبي (للربط مع GL)
    revenue_account_id = Column(String(36), ForeignKey("pilot_gl_accounts.id"), nullable=True)

    # Relationship
    invoice = relationship("SalesInvoice", back_populates="lines")

    __table_args__ = (
        UniqueConstraint("invoice_id", "line_number", name="uq_pilot_sil_invoice_line"),
    )


class CustomerPayment(Base):
    """سند قبض من عميل — يخفّض رصيد AR."""
    __tablename__ = "pilot_customer_payments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    customer_id = Column(String(36), ForeignKey("pilot_customers.id"), nullable=False, index=True)
    invoice_id = Column(String(36), ForeignKey("pilot_sales_invoices.id"), nullable=True)

    receipt_number = Column(String(50), nullable=False)
    payment_date = Column(Date, nullable=False)

    currency = Column(String(3), nullable=False, default="SAR")
    amount = Column(Numeric(20, 2), nullable=False)

    method = Column(String(30), nullable=False, default="bank_transfer")  # cash | bank | check | card
    reference = Column(String(100), nullable=True)                         # رقم الشيك أو المرجع البنكي

    # المراجع المحاسبية
    journal_entry_id = Column(String(36), ForeignKey("pilot_journal_entries.id"), nullable=True)

    memo = Column(String(500), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        Index("ix_pilot_cp_customer", "customer_id"),
        Index("ix_pilot_cp_invoice", "invoice_id"),
        Index("ix_pilot_cp_date", "payment_date"),
    )
