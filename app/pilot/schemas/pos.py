"""Pydantic schemas for POS (نقطة البيع)."""

from datetime import datetime
from decimal import Decimal
from typing import Optional, Literal
from pydantic import BaseModel, Field, ConfigDict, model_validator


# ──────────────────────────────────────────────────────────────────────────
# Session
# ──────────────────────────────────────────────────────────────────────────

class PosSessionOpen(BaseModel):
    branch_id: str
    warehouse_id: str
    opened_by_user_id: str
    opening_cash: Decimal = Field(default=Decimal("0"), ge=0)
    station_id: Optional[str] = None
    station_label: Optional[str] = None
    opening_notes: Optional[str] = None


class PosSessionClose(BaseModel):
    closed_by_user_id: str
    closing_cash: Decimal = Field(..., ge=0, description="العدّ الفعلي للنقد")
    closing_notes: Optional[str] = None


class PosSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    branch_id: str
    warehouse_id: str
    code: str
    station_id: Optional[str]
    station_label: Optional[str]
    status: str
    currency: str
    opened_at: datetime
    opened_by_user_id: str
    opening_cash: Decimal
    opening_notes: Optional[str]
    closed_at: Optional[datetime]
    closed_by_user_id: Optional[str]
    closing_cash: Optional[Decimal]
    expected_cash: Optional[Decimal]
    variance: Optional[Decimal]
    closing_notes: Optional[str]
    transaction_count: int
    sale_count: int
    return_count: int
    void_count: int
    gross_sales: Decimal
    discount_total: Decimal
    vat_total: Decimal
    net_sales: Decimal
    payment_breakdown: dict


# ──────────────────────────────────────────────────────────────────────────
# Transaction lines
# ──────────────────────────────────────────────────────────────────────────

class PosLineInput(BaseModel):
    """سطر دخَل نقطة البيع — يحتوي ما يكفي لحساب السعر والضريبة.

    G-POS-BACKEND-INTEGRATION-V2 (2026-05-11): soft variant_id. The
    previous shape REQUIRED `variant_id` on every line which broke
    ad-hoc cash sales (services, custom items, quick rings without
    a barcoded SKU). The new shape introduces an `is_misc` discriminator:

      * `is_misc=False` (default): catalogued SKU — `variant_id` MUST
        be set, price-lookup runs against the price list, StockMovement
        is recorded.
      * `is_misc=True`: ad-hoc line — `variant_id` is ignored,
        `description` + `unit_price_override` MUST be supplied, NO
        StockMovement is recorded (un-catalogued items have no
        inventory to deduct from).

    The `vat_rate_override` lets the cashier pin a non-default rate
    per line (e.g. zero-rated services); when absent the route falls
    back to the product's `vat_code` (catalogued path) or the
    company's `default_vat_rate` (misc path).
    """
    variant_id: Optional[str] = None
    qty: Decimal = Field(..., description="موجب للبيع، سالب للمرتجع")
    barcode_scanned: Optional[str] = None
    # اختياري: تجاوز تسعير قائمة الأسعار
    unit_price_override: Optional[Decimal] = None
    discount_pct: Optional[Decimal] = Field(None, ge=0, le=100)
    discount_amount: Optional[Decimal] = Field(None, ge=0)
    discount_reason: Optional[str] = None
    salesperson_user_id: Optional[str] = None
    # G-POS-BACKEND-INTEGRATION-V2: soft-variant fields
    is_misc: bool = False
    description: Optional[str] = None
    vat_rate_override: Optional[Decimal] = Field(None, ge=0, le=100)

    @model_validator(mode="after")
    def _check_variant_vs_misc(self) -> "PosLineInput":
        """Enforce the discriminator:
          * catalogued (is_misc=False) → variant_id required
          * misc      (is_misc=True)  → description + unit_price_override required
        """
        if not self.is_misc:
            if not self.variant_id:
                raise ValueError(
                    "variant_id مطلوب للبنود المُفهرَسة (is_misc=False)"
                )
        else:
            if not self.description or not self.description.strip():
                raise ValueError(
                    "description مطلوب للبنود المتنوّعة (is_misc=True)"
                )
            if self.unit_price_override is None:
                raise ValueError(
                    "unit_price_override مطلوب للبنود المتنوّعة (is_misc=True) "
                    "— لا يمكن لـ price-lookup إيجاد سعر بدون variant_id"
                )
        return self


class PosLineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    line_number: int
    # G-POS-BACKEND-INTEGRATION-V2: variant_id is now nullable so misc
    # lines (un-catalogued ad-hoc sales) can round-trip through the read
    # model without violating the schema.
    variant_id: Optional[str] = None
    is_misc: bool = False
    sku: Optional[str] = None
    description: str
    barcode_scanned: Optional[str]
    qty: Decimal
    uom: str
    unit_price: Decimal
    unit_cost: Optional[Decimal]
    prices_include_vat: bool
    discount_pct: Optional[Decimal]
    discount_amount: Decimal
    discount_reason: Optional[str]
    vat_code: str
    vat_rate_pct: Decimal
    line_subtotal: Decimal
    line_discount: Decimal
    line_taxable: Decimal
    line_vat: Decimal
    line_total: Decimal
    price_list_id: Optional[str]
    promo_badge: Optional[str]
    warehouse_id: Optional[str]
    stock_movement_id: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# Payments
# ──────────────────────────────────────────────────────────────────────────

class PosPaymentInput(BaseModel):
    method: str = Field(..., pattern="^(cash|mada|visa|mastercard|amex|stc_pay|apple_pay|google_pay|samsung_pay|tamara|tabby|gift_card|store_credit|bank_transfer|other)$")
    amount: Decimal = Field(..., gt=0)
    reference_number: Optional[str] = None
    approval_code: Optional[str] = None
    terminal_id: Optional[str] = None
    card_last4: Optional[str] = Field(None, min_length=4, max_length=4)
    card_scheme: Optional[str] = None
    notes: Optional[str] = None


class PosPaymentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    sequence: int
    method: str
    amount: Decimal
    currency: str
    reference_number: Optional[str]
    approval_code: Optional[str]
    terminal_id: Optional[str]
    card_last4: Optional[str]
    card_scheme: Optional[str]
    status: str
    authorized_at: Optional[datetime]
    captured_at: Optional[datetime]
    refunded_at: Optional[datetime]
    notes: Optional[str]


# ──────────────────────────────────────────────────────────────────────────
# Transaction
# ──────────────────────────────────────────────────────────────────────────

class PosTransactionCreate(BaseModel):
    """إنشاء فاتورة بيع مكتملة.

    يحسب النظام:
      • سعر كل بند من price-lookup (ما لم يكن unit_price_override)
      • حركة المخزون (StockMovement) لكل بند
      • VAT
      • مقارنة tendered_total بـ grand_total → حساب change_given
    """
    session_id: str
    kind: str = Field("sale", pattern="^(sale|return|exchange|void|no_sale)$")
    cashier_user_id: str
    cashier_name: Optional[str] = None
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_vat_number: Optional[str] = None
    customer_group_code: Optional[str] = None     # لاستخدام قائمة أسعار VIP

    # البنود
    lines: list[PosLineInput] = Field(..., min_length=1)

    # خصم إضافي على الفاتورة (بعد خصومات البنود)
    discount_pct: Optional[Decimal] = Field(None, ge=0, le=100)

    # الدفع
    payments: list[PosPaymentInput] = Field(..., min_length=1)

    # مرتجع
    original_transaction_id: Optional[str] = None
    reason_text: Optional[str] = None

    notes: Optional[str] = None


class PosTransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tenant_id: str
    session_id: str
    branch_id: str
    receipt_number: str
    kind: str
    status: str
    customer_id: Optional[str]
    customer_name: Optional[str]
    customer_phone: Optional[str]
    customer_vat_number: Optional[str]
    currency: str
    subtotal: Decimal
    discount_total: Decimal
    discount_pct: Optional[Decimal]
    taxable_amount: Decimal
    vat_total: Decimal
    grand_total: Decimal
    tendered_total: Decimal
    change_given: Decimal
    original_transaction_id: Optional[str]
    reason_text: Optional[str]
    cashier_user_id: str
    cashier_name: Optional[str]
    zatca_uuid: Optional[str]
    zatca_qr_payload: Optional[str]
    zatca_status: Optional[str]
    transacted_at: datetime
    completed_at: Optional[datetime]
    voided_at: Optional[datetime]
    notes: Optional[str]


class PosTransactionDetail(PosTransactionRead):
    lines: list[PosLineRead] = Field(default_factory=list)
    payments: list[PosPaymentRead] = Field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────
# Void / Refund
# ──────────────────────────────────────────────────────────────────────────

class PosVoidRequest(BaseModel):
    reason_text: str = Field(..., min_length=3, max_length=500)
    voided_by_user_id: str


class PosRefundRequest(BaseModel):
    """مرتجع كامل أو جزئي."""
    session_id: str
    cashier_user_id: str
    lines: list[PosLineInput] = Field(..., min_length=1, description="البنود المُرتجعة — qty موجب")
    refund_payments: list[PosPaymentInput] = Field(..., min_length=1)
    reason_text: str = Field(..., min_length=3, max_length=500)


# ──────────────────────────────────────────────────────────────────────────
# Cash drawer
# ──────────────────────────────────────────────────────────────────────────

class CashMovementCreate(BaseModel):
    kind: str = Field(..., pattern="^(paid_in|paid_out)$")
    amount: Decimal = Field(..., gt=0)
    reason: str = Field(..., min_length=3, max_length=255)
    reference_number: Optional[str] = None
    performed_by_user_id: str
    approved_by_user_id: Optional[str] = None


class CashMovementRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    session_id: str
    kind: str
    amount: Decimal
    currency: str
    transaction_id: Optional[str]
    payment_id: Optional[str]
    reason: Optional[str]
    reference_number: Optional[str]
    performed_at: datetime
    performed_by_user_id: Optional[str]
    approved_by_user_id: Optional[str]
    balance_after: Decimal


# ──────────────────────────────────────────────────────────────────────────
# Z-Report (إقفال الوردية)
# ──────────────────────────────────────────────────────────────────────────

class ZReportResponse(BaseModel):
    session: PosSessionRead
    # breakdown
    expected_cash: Decimal
    closing_cash: Decimal
    variance: Decimal
    variance_pct: Optional[Decimal] = None
    # إحصائيات
    transaction_count: int
    total_sales_gross: Decimal
    total_refunds: Decimal
    total_vat: Decimal
    total_net: Decimal
    # تحليل طرق الدفع
    payment_breakdown: dict[str, Decimal]
    # تحليل أفضل المنتجات مبيعاً
    top_skus: list[dict] = Field(default_factory=list)
