"""GL (General Ledger) — Chart of Accounts, Fiscal Periods, Journal Entries, Postings.

المعمارية:

  GLAccount          شجرة حسابات هرمية لكل كيان (Entity)
    ├── code (1110, 1200, 4100, ...)
    ├── name_ar, name_en
    ├── category: asset | liability | equity | revenue | expense
    ├── subcategory: cash, receivables, inventory, cogs, sales, ...
    ├── parent_account_id (شجرة)
    └── نوع الحساب: header (تجميعي) | detail (تُرحَّل إليه قيود)

  FiscalPeriod       فترات محاسبية لكل كيان (عادة شهرية)
    ├── year + month
    ├── start_date + end_date
    └── status: open | closing | closed | locked

  JournalEntry       قيد اليومية (header)
    ├── je_number تسلسلي per-entity-per-year
    ├── kind: manual | auto_pos | auto_po | auto_payroll | adjusting |
              closing | reversal | opening
    ├── status: draft | submitted | approved | posted | reversed
    ├── entity_id + fiscal_period_id
    ├── source_type + source_id (مثل pos_txn + txn_id للربط العكسي)
    └── total_debit + total_credit (يجب أن يتساويا قبل الترحيل)

  JournalLine        بند قيد يومية
    ├── line_number
    ├── account_id
    ├── debit_amount أو credit_amount (أحدهما فقط > 0)
    ├── currency + exchange_rate
    ├── functional_debit + functional_credit (بعد التحويل)
    ├── cost_center_id + profit_center_id (اختياري)
    └── description + reference

  GLPosting          الأستاذ العام — سجل ثابت post-JE
    ├── (account_id, period_id, entity_id)
    ├── debit_amount + credit_amount بالعملة الوظيفية
    └── مرجع إلى JournalLine

قواعد الترحيل:
  • القيد يجب أن يكون متوازناً (Σdebit = Σcredit) قبل الترحيل
  • الفترة المحاسبية يجب أن تكون مفتوحة
  • الحسابات يجب أن تكون نوع "detail" (الـ header لا يُرحَّل إليها)
  • بمجرد الترحيل، لا يمكن التعديل — فقط قيد عكسي
"""

import enum
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, JSON, Numeric, Text, Date, UniqueConstraint, Index
from sqlalchemy.orm import relationship

from app.phase1.models.platform_models import Base, gen_uuid, utcnow


# ──────────────────────────────────────────────────────────────────────────
# Enums
# ──────────────────────────────────────────────────────────────────────────

class AccountCategory(str, enum.Enum):
    asset = "asset"           # أصول
    liability = "liability"   # التزامات
    equity = "equity"         # حقوق ملكية
    revenue = "revenue"       # إيرادات
    expense = "expense"       # مصروفات


class AccountType(str, enum.Enum):
    header = "header"     # حساب تجميعي لا يُرحَّل إليه
    detail = "detail"     # حساب فعلي يُرحَّل إليه


class NormalBalance(str, enum.Enum):
    debit = "debit"       # رصيد طبيعي مدين (الأصول + المصروفات)
    credit = "credit"     # رصيد طبيعي دائن (الالتزامات + حقوق الملكية + الإيرادات)


class PeriodStatus(str, enum.Enum):
    open = "open"
    closing = "closing"   # قيد الإقفال (soft lock)
    closed = "closed"     # مُقفلة — لا قيود جديدة
    locked = "locked"     # مُقفلة نهائياً (بعد المراجعة)


class JournalEntryKind(str, enum.Enum):
    manual = "manual"
    auto_pos = "auto_pos"               # من نقطة البيع
    auto_po = "auto_po"                  # من أمر الشراء
    auto_payroll = "auto_payroll"        # من الرواتب
    auto_depreciation = "auto_depreciation"
    auto_fx_reval = "auto_fx_reval"      # إعادة تقييم العملات
    adjusting = "adjusting"              # قيود تسوية
    closing = "closing"                  # قيود الإقفال السنوي
    reversal = "reversal"                # قيد عكسي
    opening = "opening"                  # افتتاحي


class JournalEntryStatus(str, enum.Enum):
    draft = "draft"           # قيد الإعداد
    submitted = "submitted"   # مُقدَّم للاعتماد
    approved = "approved"     # معتمد — جاهز للترحيل
    posted = "posted"         # مُرحَّل للأستاذ العام
    rejected = "rejected"     # مرفوض
    reversed = "reversed"     # تم عكسه


# ──────────────────────────────────────────────────────────────────────────
# Chart of Accounts (CoA)
# ──────────────────────────────────────────────────────────────────────────

class GLAccount(Base):
    """حساب في شجرة الحسابات — لكل كيان (Entity) شجرته الخاصة."""
    __tablename__ = "pilot_gl_accounts"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    parent_account_id = Column(String(36), ForeignKey("pilot_gl_accounts.id", ondelete="SET NULL"), nullable=True)

    # الترميز
    code = Column(String(20), nullable=False)                   # 1110, 4100, ...
    name_ar = Column(String(255), nullable=False)               # النقد في الصندوق
    name_en = Column(String(255), nullable=True)

    # التصنيف
    category = Column(String(20), nullable=False)               # see AccountCategory
    subcategory = Column(String(50), nullable=True)             # cash, inventory, cogs, ...
    type = Column(String(20), nullable=False, default=AccountType.detail.value)
    normal_balance = Column(String(10), nullable=False)         # debit | credit
    level = Column(Integer, nullable=False, default=1)          # عمق الشجرة

    # الخصائص
    is_system = Column(Boolean, nullable=False, default=False)
    is_active = Column(Boolean, nullable=False, default=True)
    is_control = Column(Boolean, nullable=False, default=False)  # حساب مراقبة (sub-ledger)

    # العملة الخاصة (إن وُجد حساب بعملة معيّنة)
    currency = Column(String(3), nullable=True)                  # None = يقبل كل العملات
    require_cost_center = Column(Boolean, nullable=False, default=False)
    require_profit_center = Column(Boolean, nullable=False, default=False)

    # VAT default (اختياري، للبنود التلقائية)
    default_vat_code = Column(String(20), nullable=True)

    # Audit
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    parent = relationship("GLAccount", remote_side=[id], backref="children")

    __table_args__ = (
        UniqueConstraint("entity_id", "code", name="uq_pilot_gl_acct_entity_code"),
        Index("ix_pilot_gl_acct_tenant_entity", "tenant_id", "entity_id"),
        Index("ix_pilot_gl_acct_category", "entity_id", "category"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Fiscal Period
# ──────────────────────────────────────────────────────────────────────────

class FiscalPeriod(Base):
    """فترة محاسبية (عادة شهرية) لكل كيان."""
    __tablename__ = "pilot_fiscal_periods"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)

    # التعريف
    code = Column(String(20), nullable=False)                   # 2026-04, FY2026-Q2
    name_ar = Column(String(100), nullable=False)               # أبريل 2026
    year = Column(Integer, nullable=False)                      # 2026
    month = Column(Integer, nullable=True)                      # 1..12 (null للسنوية)
    quarter = Column(Integer, nullable=True)                    # 1..4

    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)

    status = Column(String(20), nullable=False, default=PeriodStatus.open.value)

    # تواريخ الإقفال
    closed_at = Column(DateTime(timezone=True), nullable=True)
    closed_by_user_id = Column(String(36), nullable=True)
    locked_at = Column(DateTime(timezone=True), nullable=True)

    # إحصائيات محدّثة عند الترحيل
    je_count = Column(Integer, nullable=False, default=0)
    total_debits = Column(Numeric(20, 2), nullable=False, default=0)
    total_credits = Column(Numeric(20, 2), nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    __table_args__ = (
        UniqueConstraint("entity_id", "code", name="uq_pilot_fiscal_entity_code"),
        Index("ix_pilot_fiscal_entity_status", "entity_id", "status"),
        Index("ix_pilot_fiscal_dates", "entity_id", "start_date", "end_date"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Journal Entry
# ──────────────────────────────────────────────────────────────────────────

class JournalEntry(Base):
    """قيد اليومية (Header)."""
    __tablename__ = "pilot_journal_entries"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    fiscal_period_id = Column(String(36), ForeignKey("pilot_fiscal_periods.id", ondelete="RESTRICT"), nullable=False, index=True)

    # الترميز
    je_number = Column(String(50), nullable=False)              # JE-2026-04-00123

    # التصنيف
    kind = Column(String(30), nullable=False, default=JournalEntryKind.manual.value)
    status = Column(String(20), nullable=False, default=JournalEntryStatus.draft.value)

    # المصدر (للقيود التلقائية)
    source_type = Column(String(40), nullable=True)             # pos_txn, po_receipt, payroll, ...
    source_id = Column(String(36), nullable=True)
    source_reference = Column(String(100), nullable=True)       # receipt_number, PO-2026-0042

    # الوصف
    memo_ar = Column(String(500), nullable=False)
    memo_en = Column(String(500), nullable=True)

    # التواريخ
    je_date = Column(Date, nullable=False)                      # تاريخ القيد
    posting_date = Column(Date, nullable=True)                  # متى تم الترحيل فعلاً
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_by_user_id = Column(String(36), nullable=True)

    # الاعتماد
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    submitted_by_user_id = Column(String(36), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    approved_by_user_id = Column(String(36), nullable=True)
    posted_at = Column(DateTime(timezone=True), nullable=True)
    posted_by_user_id = Column(String(36), nullable=True)
    rejected_at = Column(DateTime(timezone=True), nullable=True)
    rejection_reason = Column(String(500), nullable=True)

    # المبالغ (بالعملة الوظيفية للكيان)
    currency = Column(String(3), nullable=False)
    total_debit = Column(Numeric(20, 2), nullable=False, default=0)
    total_credit = Column(Numeric(20, 2), nullable=False, default=0)

    # العكس
    reversal_of_je_id = Column(String(36), nullable=True)       # إن كان هذا القيد عكس قيد آخر
    reversed_by_je_id = Column(String(36), nullable=True)       # إن تم عكس هذا القيد

    # إضافات
    extras = Column(JSON, nullable=False, default=dict)

    updated_at = Column(DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow)

    # Relationships
    lines = relationship("JournalLine", back_populates="journal_entry", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("entity_id", "je_number", name="uq_pilot_je_entity_number"),
        Index("ix_pilot_je_entity_date", "entity_id", "je_date"),
        Index("ix_pilot_je_status", "status"),
        Index("ix_pilot_je_source", "source_type", "source_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# Journal Line
# ──────────────────────────────────────────────────────────────────────────

class JournalLine(Base):
    """بند في قيد يومية — مدين أو دائن (ليس كليهما)."""
    __tablename__ = "pilot_journal_lines"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    journal_entry_id = Column(String(36), ForeignKey("pilot_journal_entries.id", ondelete="CASCADE"), nullable=False, index=True)

    line_number = Column(Integer, nullable=False)               # 1..N
    account_id = Column(String(36), ForeignKey("pilot_gl_accounts.id", ondelete="RESTRICT"), nullable=False, index=True)

    # المبالغ (بعملة السطر الأصلية — قد تختلف عن العملة الوظيفية)
    currency = Column(String(3), nullable=False)
    debit_amount = Column(Numeric(20, 2), nullable=False, default=0)
    credit_amount = Column(Numeric(20, 2), nullable=False, default=0)

    # التحويل للعملة الوظيفية
    exchange_rate = Column(Numeric(18, 8), nullable=False, default=1)
    functional_debit = Column(Numeric(20, 2), nullable=False, default=0)
    functional_credit = Column(Numeric(20, 2), nullable=False, default=0)

    # الأبعاد (Cost Accounting dimensions — Day 7-10)
    cost_center_id = Column(String(36), nullable=True, index=True)
    profit_center_id = Column(String(36), nullable=True, index=True)
    project_id = Column(String(36), nullable=True, index=True)
    segment_id = Column(String(36), nullable=True)
    branch_id = Column(String(36), nullable=True, index=True)

    # الطرف المقابل (للحسابات الرقابية مثل AR/AP)
    partner_type = Column(String(30), nullable=True)            # customer | vendor | employee
    partner_id = Column(String(36), nullable=True)
    partner_name = Column(String(255), nullable=True)

    # الوصف المرجعي
    description = Column(String(500), nullable=True)
    reference = Column(String(100), nullable=True)              # رقم فاتورة، رقم شيك، ...

    # VAT tracking
    vat_code = Column(String(20), nullable=True)
    vat_amount = Column(Numeric(18, 2), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    # Relationships
    journal_entry = relationship("JournalEntry", back_populates="lines")
    account = relationship("GLAccount")

    __table_args__ = (
        UniqueConstraint("journal_entry_id", "line_number", name="uq_pilot_jline_je_num"),
        Index("ix_pilot_jline_account", "account_id"),
    )


# ──────────────────────────────────────────────────────────────────────────
# GL Posting (الأستاذ العام)
# ──────────────────────────────────────────────────────────────────────────

class GLPosting(Base):
    """سجل ثابت في الأستاذ العام — ناتج عن ترحيل JournalLine."""
    __tablename__ = "pilot_gl_postings"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    tenant_id = Column(String(36), ForeignKey("pilot_tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    entity_id = Column(String(36), ForeignKey("pilot_entities.id", ondelete="CASCADE"), nullable=False, index=True)
    fiscal_period_id = Column(String(36), ForeignKey("pilot_fiscal_periods.id", ondelete="RESTRICT"), nullable=False, index=True)
    account_id = Column(String(36), ForeignKey("pilot_gl_accounts.id", ondelete="RESTRICT"), nullable=False, index=True)

    # المرجع الأصلي
    journal_entry_id = Column(String(36), ForeignKey("pilot_journal_entries.id", ondelete="RESTRICT"), nullable=False, index=True)
    journal_line_id = Column(String(36), ForeignKey("pilot_journal_lines.id", ondelete="RESTRICT"), nullable=False)

    # المبالغ بالعملة الوظيفية (هذه هي المراحل النهائية للتقارير)
    debit_amount = Column(Numeric(20, 2), nullable=False, default=0)
    credit_amount = Column(Numeric(20, 2), nullable=False, default=0)
    currency = Column(String(3), nullable=False)                # العملة الوظيفية للكيان

    # الأبعاد المنقولة من السطر
    cost_center_id = Column(String(36), nullable=True, index=True)
    profit_center_id = Column(String(36), nullable=True, index=True)
    project_id = Column(String(36), nullable=True, index=True)
    branch_id = Column(String(36), nullable=True, index=True)

    # الطرف
    partner_type = Column(String(30), nullable=True)
    partner_id = Column(String(36), nullable=True)

    # التاريخ
    posting_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    __table_args__ = (
        Index("ix_pilot_glpost_entity_acct_date", "entity_id", "account_id", "posting_date"),
        Index("ix_pilot_glpost_period_acct", "fiscal_period_id", "account_id"),
        Index("ix_pilot_glpost_je", "journal_entry_id"),
    )
