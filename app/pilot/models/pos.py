"""POS (Point-of-Sale) models — shifts, transactions, lines, payments, drawer.

Design:

  PosSession (الوردية / الشيفت)
    ├── opened_at + opened_by_user_id + opening_cash (عدّ النقود الافتتاحي)
    ├── closed_at + closed_by_user_id + closing_cash (عدّ النقود الختامي)
    ├── expected_cash (محسوب من الحركات)
    └── variance = closing_cash - expected_cash   (زيادة/عجز)

  PosTransaction (فاتورة البيع / المرتجع)
    ├── kind: sale | return | void
    ├── lines: PosTransactionLine[]   (أصناف مباعة)
    ├── payments: PosPayment[]         (دفعات — قد تكون مقسّمة)
    ├── subtotal + discount + vat_total + total
    ├── customer_id (اختياري)
    └── يُنشئ StockMovement واحد لكل بند (reason=pos_sale أو pos_return)

  PosPayment
    ├── method: cash | card | mada | visa | mastercard | stc_pay
    │           | apple_pay | tamara | tabby | gift_card | store_credit
    │           | bank_transfer
    ├── amount (بالعملة الوظيفية للفرع)
    ├── reference (رقم العملية من البنك/البوابة)
    └── approval_code

  CashMovement
    ├── kind: opening | sale_cash | change_given | refund_cash
    │         | paid_in | paid_out | closing
    └── amount (موقّع: + دخول، - خروج)

مبادئ:
  • كل حركة بيع ترفع StockMovement (سالب) فورياً
  • المرتجع يرفع StockMovement موجب + قد يضبط سجل الدرج حسب طريقة الرد
  • الإيصال يُرقَّم بتسلسل per-session (RIY-MAIN-2026-04-20-0001)
  • ZATCA: في بيئة الإنتاج يُرسل الإيصال المبسّط فوراً (simplified invoice)

الامتثال الضريبي (السعودية):
  • إيصال البيع المبسّط: VAT محسوبة وظاهرة لكل بند
  • رقم الإيصال QR code مع: اسم البائع، VAT، الإجمالي، التاريخ، الضريبة
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ──────────────────────────────────────────────────────────────────────────
# Enums
# ──────────────────────────────────────────────────────────────────────────

class PosSessionStatus(str, enum.Enum):
    open = "open"                   # مفتوحة
    closing = "closing"             # قيد الإقفال (تم البدء لكن لم يُعتمد)
    closed = "closed"               # مُقفلة
    force_closed = "force_closed"   # إقفال قسري من المدير


class PosTransactionKind(str, enum.Enum):
    sale = "sale"          # بيع
    return_ = "return"     # مرتجع (استخدم return_ في بايثون)
    exchange = "exchange"  # استبدال
    void = "void"          # إلغاء
    no_sale = "no_sale"    # فتح الدرج بدون بيع


class PosTransactionStatus(str, enum.Enum):
    draft = "draft"              # في التحضير
    completed = "completed"      # تمّت
    voided = "voided"            # مُلغاة بعد الإتمام
    refunded = "refunded"        # تم ردّها بالكامل
    partial_refund = "partial_refund"


class PaymentMethod(str, enum.Enum):
    cash = "cash"                    # نقد
    mada = "mada"                    # مدى (السعودية)
    visa = "visa"
    mastercard = "mastercard"
    amex = "amex"
    stc_pay = "stc_pay"              # STC Pay
    apple_pay = "apple_pay"
    google_pay = "google_pay"
    samsung_pay = "samsung_pay"
    tamara = "tamara"                # تمارا (BNPL)
    tabby = "tabby"                  # تابي (BNPL)
    gift_card = "gift_card"
    store_credit = "store_credit"
    bank_transfer = "bank_transfer"
    other = "other"


class CashMovementKind(str, enum.Enum):
    opening = "opening"              # رصيد افتتاحي
    sale_cash = "sale_cash"          # نقد من بيع
    change_given = "change_given"    # صرف باقي للزبون
    refund_cash = "refund_cash"      # رد نقدي
    paid_in = "paid_in"              # إيداع (مثلاً من الخزنة الرئيسية)
    paid_out = "paid_out"            # سحب (مصاريف نثرية)
    closing = "closing"              # رصيد ختامي


# ──────────────────────────────────────────────────────────────────────────
# POS Session (الوردية)
# ──────────────────────────────────────────────────────────────────────────

class PosSession(Base):
    """وردية/شيفت كاشير — من فتح الدرج إلى إقفاله."""
    __tablename__ = "pilot_pos_sessions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="CASCADE"), nullable=False, index=True)
    warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="RESTRICT"), nullable=False)

    # رقم الوردية — تسلسلي ضمن الفرع (e.g., RIY-01-2026-04-20-01)
    code = Column(String(50), nullable=False)

    # المحطة (إن وُجدت أكثر من محطة في الفرع)
    station_id = Column(String(50), nullable=True)  # POS-01, POS-02
    station_label = Column(String(50), nullable=True)

    # الحالة
    status = Column(String(20), nullable=False, default=PosSessionStatus.open.value)
    currency = Column(String(3), nullable=False)   # SAR, AED, ...

    # الفتح
    opened_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    opened_by_user_id = Column(String(36), nullable=False)
    opening_cash = Column(Numeric(18, 2), nullable=False, default=0)
    opening_notes = Column(String(500), nullable=True)

    # الإقفال
    closed_at = Column(DateTime(timezone=True), nullable=True)
    closed_by_user_id = Column(String(36), nullable=True)
    closing_cash = Column(Numeric(18, 2), nullable=True)       # العدّ الفعلي
    expected_cash = Column(Numeric(18, 2), nullable=True)      # المحسوب
    variance = Column(Numeric(18, 2), nullable=True)           # الفرق (زيادة/عجز)
    closing_notes = Column(String(500), nullable=True)

    # إحصائيات (محدّثة live)
    transaction_count = Column(Integer, nullable=False, default=0)
    sale_count = Column(Integer, nullable=False, default=0)
    return_count = Column(Integer, nullable=False, default=0)
    void_count = Column(Integer, nullable=False, default=0)
    gross_sales = Column(Numeric(18, 2), nullable=False, default=0)   # قبل الخصومات
    discount_total = Column(Numeric(18, 2), nullable=False, default=0)
    vat_total = Column(Numeric(18, 2), nullable=False, default=0)
    net_sales = Column(Numeric(18, 2), nullable=False, default=0)     # بعد الخصم + VAT

    # تفصيل المدفوعات لكل طريقة (محسوبة عند الإقفال)
    # { "cash": 1250.00, "mada": 3400.50, "visa": 800.00 }
    payment_breakdown = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    branch = relationship("Branch")
    warehouse = relationship("Warehouse")
    transactions = relationship("PosTransaction", back_populates="session", cascade="all, delete-orphan")
    cash_movements = relationship("CashMovement", back_populates="session", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_pilot_pos_sess_tenant_code"),
        Index("ix_pilot_pos_sess_branch_status", "branch_id", "status"),
        Index("ix_pilot_pos_sess_user_time", "opened_by_user_id", "opened_at"),
    )


# ──────────────────────────────────────────────────────────────────────────
# POS Transaction (الفاتورة)
# ──────────────────────────────────────────────────────────────────────────

class PosTransaction(Base):
    """فاتورة / معاملة نقطة بيع — بيع أو مرتجع أو إلغاء."""
    __tablename__ = "pilot_pos_transactions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    session_id = Column(String(36), ForeignKey("pilot_pos_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(String(36), ForeignKey("pilot_branches.id", ondelete="CASCADE"), nullable=False, index=True)

    # رقم الإيصال — تسلسلي ضمن الوردية
    receipt_number = Column(String(50), nullable=False)   # e.g., RIY-01-2026-04-20-0001

    # التصنيف
    kind = Column(String(20), nullable=False, default=PosTransactionKind.sale.value)
    status = Column(String(20), nullable=False, default=PosTransactionStatus.draft.value)

    # الزبون (اختياري)
    customer_id = Column(String(36), nullable=True)
    customer_name = Column(String(255), nullable=True)
    customer_phone = Column(String(30), nullable=True)
    customer_vat_number = Column(String(50), nullable=True)  # للفواتير B2B

    # العملة
    currency = Column(String(3), nullable=False)

    # الإجماليات
    subtotal = Column(Numeric(18, 2), nullable=False, default=0)           # مجموع البنود قبل الخصم
    discount_total = Column(Numeric(18, 2), nullable=False, default=0)
    discount_pct = Column(Numeric(6, 3), nullable=True)                    # خصم على الفاتورة ككل
    taxable_amount = Column(Numeric(18, 2), nullable=False, default=0)     # (بعد الخصم)
    vat_total = Column(Numeric(18, 2), nullable=False, default=0)
    grand_total = Column(Numeric(18, 2), nullable=False, default=0)        # المبلغ المطلوب
    tendered_total = Column(Numeric(18, 2), nullable=False, default=0)     # ما دفعه الزبون
    change_given = Column(Numeric(18, 2), nullable=False, default=0)       # الباقي المُعاد

    # المراجع
    original_transaction_id = Column(String(36), nullable=True)            # للمرتجعات
    reason_text = Column(String(500), nullable=True)                        # سبب المرتجع / الإلغاء

    # الكاشير
    cashier_user_id = Column(String(36), nullable=False)
    cashier_name = Column(String(150), nullable=True)

    # ZATCA
    zatca_uuid = Column(String(64), nullable=True)                          # UUID للفاتورة
    zatca_hash = Column(String(128), nullable=True)                         # hash السلسلة
    zatca_qr_payload = Column(Text, nullable=True)                          # base64 TLV للـ QR
    zatca_previous_hash = Column(String(128), nullable=True)
    zatca_submitted_at = Column(DateTime(timezone=True), nullable=True)
    zatca_status = Column(String(30), nullable=True)                        # pending|submitted|accepted|rejected
    zatca_response = Column(JSON, nullable=True)

    # الوقت
    transacted_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    voided_at = Column(DateTime(timezone=True), nullable=True)

    # الملاحظات / الحقول الإضافية
    notes = Column(Text, nullable=True)
    extras = Column(JSON, nullable=False, default=dict)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    session = relationship("PosSession", back_populates="transactions")
    lines = relationship("PosTransactionLine", back_populates="transaction", cascade="all, delete-orphan")
    payments = relationship("PosPayment", back_populates="transaction", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("tenant_id", "receipt_number", name="uq_pilot_pos_txn_tenant_receipt"),
        Index("ix_pilot_pos_txn_session_time", "session_id", "transacted_at"),
        Index("ix_pilot_pos_txn_branch_time", "branch_id", "transacted_at"),
        Index("ix_pilot_pos_txn_status", "status"),
        Index("ix_pilot_pos_txn_customer", "customer_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# POS Transaction Line (البند)
# ──────────────────────────────────────────────────────────────────────────

class PosTransactionLine(Base):
    """بند واحد في فاتورة نقطة البيع."""
    __tablename__ = "pilot_pos_transaction_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    transaction_id = Column(String(36), ForeignKey("pilot_pos_transactions.id", ondelete="CASCADE"), nullable=False, index=True)

    line_number = Column(Integer, nullable=False)                           # تسلسلي 1..N

    # المنتج
    variant_id = Column(String(36), ForeignKey("pilot_product_variants.id", ondelete="RESTRICT"), nullable=False, index=True)
    sku = Column(String(80), nullable=False)                                # مخزَّن في البند للتدقيق
    description = Column(String(500), nullable=False)                       # اسم المنتج لحظة البيع
    barcode_scanned = Column(String(50), nullable=True)                     # الباركود الذي مُسح

    # الكميّة
    qty = Column(Numeric(18, 3), nullable=False, default=1)                 # (موجب للبيع، سالب للمرتجع)
    uom = Column(String(20), nullable=False, default="piece")

    # التسعير
    unit_price = Column(Numeric(18, 4), nullable=False)                     # قبل الخصم (مع أو بدون VAT حسب العلَم)
    unit_cost = Column(Numeric(18, 4), nullable=True)                       # للتقارير فقط (هامش)
    prices_include_vat = Column(Boolean, nullable=False, default=True)

    # الخصم على مستوى البند
    discount_pct = Column(Numeric(6, 3), nullable=True)
    discount_amount = Column(Numeric(18, 2), nullable=False, default=0)
    discount_reason = Column(String(100), nullable=True)                    # "promo", "manager", "staff"

    # الضريبة
    vat_code = Column(String(20), nullable=False, default="standard")       # standard|zero_rated|exempt
    vat_rate_pct = Column(Numeric(6, 3), nullable=False, default=15)

    # الإجماليات المحسوبة للبند
    line_subtotal = Column(Numeric(18, 2), nullable=False, default=0)       # قبل الخصم
    line_discount = Column(Numeric(18, 2), nullable=False, default=0)
    line_taxable = Column(Numeric(18, 2), nullable=False, default=0)        # بعد الخصم (الخاضع للـ VAT)
    line_vat = Column(Numeric(18, 2), nullable=False, default=0)
    line_total = Column(Numeric(18, 2), nullable=False, default=0)          # النهائي للبند

    # مرجع للتسعير (للمراجعة إن كان من قائمة عروض)
    price_list_id = Column(String(36), nullable=True)
    promo_badge = Column(String(50), nullable=True)                         # "SALE", "صيف 2026"

    # المخزون المرتبط
    warehouse_id = Column(String(36), ForeignKey("pilot_warehouses.id", ondelete="RESTRICT"), nullable=True)
    stock_movement_id = Column(String(36), nullable=True)                   # الحركة الناتجة

    # الكاشير / البائع (للعمولة إن وُجدت)
    salesperson_user_id = Column(String(36), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    # Relationships
    transaction = relationship("PosTransaction", back_populates="lines")
    variant = relationship("ProductVariant")

    __table_args__ = (
        UniqueConstraint("transaction_id", "line_number", name="uq_pilot_pos_line_txn_num"),
        Index("ix_pilot_pos_line_variant", "variant_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# POS Payment (دفعة)
# ──────────────────────────────────────────────────────────────────────────

class PosPayment(Base):
    """دفعة على فاتورة نقطة بيع — قد تكون مقسّمة (مدى + نقد)."""
    __tablename__ = "pilot_pos_payments"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    transaction_id = Column(String(36), ForeignKey("pilot_pos_transactions.id", ondelete="CASCADE"), nullable=False, index=True)

    sequence = Column(Integer, nullable=False)                              # 1, 2, 3 لو مقسّم
    method = Column(String(30), nullable=False)                             # see PaymentMethod

    amount = Column(Numeric(18, 2), nullable=False)                         # بالعملة الوظيفية
    currency = Column(String(3), nullable=False)

    # مراجع من البوابة / البنك
    reference_number = Column(String(100), nullable=True)                   # STAN/RRN من البنك
    approval_code = Column(String(50), nullable=True)
    terminal_id = Column(String(50), nullable=True)                         # معرِّف جهاز الشبكة
    card_last4 = Column(String(4), nullable=True)
    card_scheme = Column(String(20), nullable=True)                         # visa|mastercard|mada|amex

    # حالة الدفع (للبوابات غير المتزامنة)
    status = Column(String(20), nullable=False, default="captured")         # authorized|captured|refunded|failed|reversed
    authorized_at = Column(DateTime(timezone=True), nullable=True)
    captured_at = Column(DateTime(timezone=True), nullable=True, default=utcnow)
    refunded_at = Column(DateTime(timezone=True), nullable=True)

    # ملاحظات
    notes = Column(String(500), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    # Relationships
    transaction = relationship("PosTransaction", back_populates="payments")

    __table_args__ = (
        UniqueConstraint("transaction_id", "sequence", name="uq_pilot_pos_pay_txn_seq"),
        Index("ix_pilot_pos_pay_method", "method"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Cash Drawer Movement
# ──────────────────────────────────────────────────────────────────────────

class CashMovement(Base):
    """حركة نقدية على الدرج — للرصيد الفعلي مقابل المحسوب."""
    __tablename__ = "pilot_cash_movements"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    session_id = Column(String(36), ForeignKey("pilot_pos_sessions.id", ondelete="CASCADE"), nullable=False, index=True)

    kind = Column(String(30), nullable=False)                               # see CashMovementKind
    amount = Column(Numeric(18, 2), nullable=False)                         # موقّع (+/-)
    currency = Column(String(3), nullable=False)

    # روابط
    transaction_id = Column(String(36), nullable=True)                      # إن كانت من بيع/مرتجع
    payment_id = Column(String(36), nullable=True)

    # السبب / الوصف
    reason = Column(String(255), nullable=True)                             # "مصاريف موقف السيارات"
    reference_number = Column(String(100), nullable=True)                   # رقم المرجع (سند صرف...)

    # Audit
    performed_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    performed_by_user_id = Column(String(36), nullable=True)
    approved_by_user_id = Column(String(36), nullable=True)                 # للـ paid_in/paid_out الكبيرة

    # الرصيد بعد الحركة (للتدقيق)
    balance_after = Column(Numeric(18, 2), nullable=False, default=0)

    # Relationships
    session = relationship("PosSession", back_populates="cash_movements")

    __table_args__ = (
        Index("ix_pilot_cash_session_time", "session_id", "performed_at"),
        Index("ix_pilot_cash_kind", "kind"),
    )
