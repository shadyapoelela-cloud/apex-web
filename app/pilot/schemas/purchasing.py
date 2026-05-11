"""Pydantic schemas for Purchasing (Vendor + PO + GRN + Purchase Invoice + Vendor Payment)."""

from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


# ──────────────────────────────────────────────────────────────────────────
# Vendor
# ──────────────────────────────────────────────────────────────────────────

class VendorCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=30)
    legal_name_ar: str
    legal_name_en: Optional[str] = None
    trade_name: Optional[str] = None
    kind: str = Field("goods", pattern="^(goods|services|both|employee|government)$")
    category: Optional[str] = None
    country: str = Field("SA", min_length=2, max_length=2)
    cr_number: Optional[str] = None
    vat_number: Optional[str] = None
    default_currency: str = Field("SAR", min_length=3, max_length=3)
    payment_terms: str = Field("net_30", pattern="^(cash|net_0|net_15|net_30|net_45|net_60|net_90|advance)$")
    credit_limit: Optional[Decimal] = None
    bank_name: Optional[str] = None
    bank_iban: Optional[str] = None
    bank_swift: Optional[str] = None
    contact_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    address_line1: Optional[str] = None
    city: Optional[str] = None
    is_preferred: bool = False


class VendorRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    code: str
    legal_name_ar: str
    legal_name_en: Optional[str]
    trade_name: Optional[str]
    kind: str
    category: Optional[str]
    country: str
    cr_number: Optional[str]
    vat_number: Optional[str]
    default_currency: str
    payment_terms: str
    credit_limit: Optional[Decimal]
    bank_name: Optional[str]
    bank_iban: Optional[str]
    contact_name: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    is_active: bool
    is_preferred: bool
    on_hold: bool
    total_purchases_ytd: Decimal
    outstanding_balance: Decimal
    last_purchase_date: Optional[date]


class VendorUpdate(BaseModel):
    legal_name_ar: Optional[str] = None
    trade_name: Optional[str] = None
    payment_terms: Optional[str] = None
    credit_limit: Optional[Decimal] = None
    bank_iban: Optional[str] = None
    contact_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = None
    is_preferred: Optional[bool] = None
    on_hold: Optional[bool] = None
    hold_reason: Optional[str] = None


class VendorLedgerResponse(BaseModel):
    vendor_id: str
    vendor_code: str
    vendor_name_ar: str
    currency: str
    total_invoiced: float
    total_paid: float
    outstanding_balance: float
    invoice_count: int
    payment_count: int
    aging: dict
    last_invoice_date: Optional[str]
    last_payment_date: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# Purchase Order
# ──────────────────────────────────────────────────────────────────────────

class PoLineInput(BaseModel):
    variant_id: Optional[str] = None
    sku: Optional[str] = None
    description: str = Field(..., min_length=1, max_length=500)
    qty_ordered: Decimal = Field(default=Decimal("1"), gt=0)
    uom: str = "piece"
    unit_price: Decimal = Field(..., ge=0)
    discount_pct: Optional[Decimal] = None
    discount_amount: Optional[Decimal] = None
    vat_code: str = Field("standard", pattern="^(standard|zero_rated|exempt|out_of_scope)$")
    vat_rate_pct: Decimal = Field(Decimal("15"), ge=0, le=30)
    expense_account_id: Optional[str] = None
    cost_center_id: Optional[str] = None


class PoLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    line_number: int
    variant_id: Optional[str]
    sku: Optional[str]
    description: str
    qty_ordered: Decimal
    qty_received: Decimal
    qty_invoiced: Decimal
    uom: str
    unit_price: Decimal
    discount_amount: Decimal
    vat_code: str
    vat_rate_pct: Decimal
    line_subtotal: Decimal
    line_taxable: Decimal
    line_vat: Decimal
    line_total: Decimal


class PoCreate(BaseModel):
    entity_id: str
    vendor_id: str
    order_date: date
    branch_id: Optional[str] = None
    destination_warehouse_id: Optional[str] = None
    expected_delivery_date: Optional[date] = None
    payment_terms: str = Field("net_30")
    notes_to_vendor: Optional[str] = None
    created_by_user_id: Optional[str] = None
    lines: list[PoLineInput] = Field(..., min_length=1)


class PoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    vendor_id: str
    branch_id: Optional[str]
    po_number: str
    order_date: date
    expected_delivery_date: Optional[date]
    currency: str
    subtotal: Decimal
    discount_total: Decimal
    taxable_amount: Decimal
    vat_total: Decimal
    shipping: Decimal
    grand_total: Decimal
    destination_warehouse_id: Optional[str]
    payment_terms: str
    status: str
    submitted_at: Optional[datetime]
    approved_at: Optional[datetime]
    issued_at: Optional[datetime]


class PoDetail(PoRead):
    lines: list[PoLineRead] = Field(default_factory=list)
    notes_to_vendor: Optional[str] = None
    internal_notes: Optional[str] = None


class PoApprove(BaseModel):
    user_id: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────
# GRN
# ──────────────────────────────────────────────────────────────────────────

class GrnLineInput(BaseModel):
    po_line_id: str
    qty_received: Decimal = Field(..., gt=0)
    qty_accepted: Optional[Decimal] = None    # default = qty_received
    qty_rejected: Decimal = Field(default=Decimal("0"), ge=0)
    rejection_reason: Optional[str] = None


class GrnLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    line_number: int
    po_line_id: str
    variant_id: Optional[str]
    sku: Optional[str]
    description: str
    qty_received: Decimal
    qty_accepted: Optional[Decimal]
    qty_rejected: Decimal
    rejection_reason: Optional[str]
    unit_cost: Decimal
    stock_movement_id: Optional[str]


class GrnCreate(BaseModel):
    po_id: str
    warehouse_id: str
    received_at: date
    delivery_note_number: Optional[str] = None
    received_by_user_id: Optional[str] = None
    notes: Optional[str] = None
    lines: list[GrnLineInput] = Field(..., min_length=1)


class GrnRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    po_id: str
    warehouse_id: str
    grn_number: str
    received_at: date
    delivery_note_number: Optional[str]
    status: str
    confirmed_at: Optional[datetime]
    notes: Optional[str]


class GrnDetail(GrnRead):
    lines: list[GrnLineRead] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# Purchase Invoice
# ──────────────────────────────────────────────────────────────────────────

class PiLineInput(BaseModel):
    po_line_id: Optional[str] = None
    variant_id: Optional[str] = None
    sku: Optional[str] = None
    description: str
    qty: Decimal = Field(default=Decimal("1"), gt=0)
    unit_cost: Decimal = Field(..., ge=0)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=0)
    vat_code: str = "standard"
    vat_rate_pct: Decimal = Decimal("15")
    gl_account_id: Optional[str] = None
    cost_center_id: Optional[str] = None
    profit_center_id: Optional[str] = None


class PiLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    line_number: int
    variant_id: Optional[str]
    sku: Optional[str]
    description: str
    qty: Decimal
    unit_cost: Decimal
    discount_amount: Decimal
    vat_code: str
    vat_rate_pct: Decimal
    line_subtotal: Decimal
    line_taxable: Decimal
    line_vat: Decimal
    line_total: Decimal


class PiCreate(BaseModel):
    entity_id: str
    vendor_id: str
    invoice_date: date
    po_id: Optional[str] = None
    vendor_invoice_number: Optional[str] = None
    due_date: Optional[date] = None
    shipping: Decimal = Field(default=Decimal("0"), ge=0)
    notes: Optional[str] = None
    created_by_user_id: Optional[str] = None
    lines: list[PiLineInput] = Field(..., min_length=1)


class PiRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    vendor_id: str
    po_id: Optional[str]
    invoice_number: str
    vendor_invoice_number: Optional[str]
    invoice_date: date
    due_date: Optional[date]
    currency: str
    subtotal: Decimal
    discount_total: Decimal
    taxable_amount: Decimal
    vat_total: Decimal
    shipping: Decimal
    grand_total: Decimal
    amount_paid: Decimal
    amount_due: Decimal
    status: str
    journal_entry_id: Optional[str]
    posted_at: Optional[datetime]
    paid_at: Optional[datetime]


class PiDetail(PiRead):
    lines: list[PiLineRead] = Field(default_factory=list)
    # G-PURCHASE-PAYMENT-COMPLETION (2026-05-11): payments list so the
    # details screen can render history without a second round-trip.
    # Mirrors the SalesInvoiceDetail.payments shape on the sales side.
    payments: list["VendorPaymentRead"] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# Vendor Payment
# ──────────────────────────────────────────────────────────────────────────

class VendorPaymentCreate(BaseModel):
    entity_id: str
    vendor_id: str
    amount: Decimal = Field(..., gt=0)
    payment_date: date
    method: str = Field("bank_transfer", pattern="^(cash|bank_transfer|cheque|credit_card|other)$")
    invoice_id: Optional[str] = None
    paid_from_account_code: str = Field("1110")   # 1110 cash, 1120 bank
    reference_number: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[str] = None


class VendorPaymentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    entity_id: str
    vendor_id: str
    invoice_id: Optional[str]
    payment_number: str
    payment_date: date
    method: str
    amount: Decimal
    currency: str
    reference_number: Optional[str]
    journal_entry_id: Optional[str]
    posted_at: Optional[datetime]
