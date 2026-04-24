"""GL Engine — محرّك محاسبي للقيود والترحيل وتحويل العملات.

الخدمات الرئيسية:
  • seed_default_coa(db, entity) — يبذر شجرة حسابات SOCPA للعميل الجديد
  • seed_fiscal_periods(db, entity, year) — يفتح 12 فترة شهرية للسنة
  • build_journal_entry(db, ...) — يبني قيد من payload
  • post_journal_entry(db, je_id) — يرحّل القيد إلى GL Postings
  • reverse_journal_entry(db, je_id) — يُنشئ قيداً عكسياً
  • get_fx_rate(db, from_ccy, to_ccy, at_date) — أحدث سعر متاح
  • convert_to_functional(amount, src_ccy, functional_ccy, rate) — تحويل
  • auto_post_pos_sale(db, pos_txn_id) — توليد JE تلقائي من بيع POS
"""

from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import and_, func

from app.pilot.models import (
    Entity, Tenant, CompanySettings,
    FxRate,
    GLAccount, AccountCategory, AccountType, NormalBalance,
    FiscalPeriod, PeriodStatus,
    JournalEntry, JournalEntryKind, JournalEntryStatus,
    JournalLine, GLPosting,
    PosTransaction, PosTransactionLine, PosPayment,
    Product,
)


Q2 = Decimal("0.01")
Q8 = Decimal("0.00000001")


def q2(x) -> Decimal:
    if x is None:
        return Decimal("0")
    return Decimal(str(x)).quantize(Q2, rounding=ROUND_HALF_UP)


# ══════════════════════════════════════════════════════════════════════════
# Chart of Accounts seeding — SOCPA-aligned 5-level structure
# ══════════════════════════════════════════════════════════════════════════

DEFAULT_COA: list[dict] = [
    # ─ ASSETS 1xxx ─
    {"code": "1000", "name_ar": "الأصول", "name_en": "Assets",
     "category": "asset", "type": "header", "normal_balance": "debit", "level": 1},
    {"code": "1100", "name_ar": "الأصول المتداولة", "name_en": "Current Assets",
     "parent": "1000", "category": "asset", "type": "header", "normal_balance": "debit", "level": 2},
    {"code": "1110", "name_ar": "النقد في الصندوق", "name_en": "Cash on Hand",
     "parent": "1100", "category": "asset", "subcategory": "cash", "type": "detail",
     "normal_balance": "debit", "level": 3},
    {"code": "1120", "name_ar": "البنوك", "name_en": "Bank Accounts",
     "parent": "1100", "category": "asset", "subcategory": "bank", "type": "detail",
     "normal_balance": "debit", "level": 3},
    {"code": "1130", "name_ar": "ذمم مدينة — العملاء", "name_en": "Accounts Receivable",
     "parent": "1100", "category": "asset", "subcategory": "receivables", "type": "detail",
     "normal_balance": "debit", "level": 3, "is_control": True},
    {"code": "1140", "name_ar": "المخزون", "name_en": "Inventory",
     "parent": "1100", "category": "asset", "subcategory": "inventory", "type": "detail",
     "normal_balance": "debit", "level": 3, "is_control": True},
    {"code": "1150", "name_ar": "ضريبة القيمة المضافة على المشتريات",
     "name_en": "VAT Input (Receivable)",
     "parent": "1100", "category": "asset", "subcategory": "vat", "type": "detail",
     "normal_balance": "debit", "level": 3},
    {"code": "1160", "name_ar": "مصروفات مدفوعة مقدماً", "name_en": "Prepaid Expenses",
     "parent": "1100", "category": "asset", "subcategory": "prepaid", "type": "detail",
     "normal_balance": "debit", "level": 3},

    {"code": "1200", "name_ar": "الأصول الثابتة", "name_en": "Fixed Assets",
     "parent": "1000", "category": "asset", "type": "header", "normal_balance": "debit", "level": 2},
    {"code": "1210", "name_ar": "المعدات والأثاث", "name_en": "Furniture & Equipment",
     "parent": "1200", "category": "asset", "subcategory": "fixed_assets", "type": "detail",
     "normal_balance": "debit", "level": 3},
    {"code": "1220", "name_ar": "السيارات", "name_en": "Vehicles",
     "parent": "1200", "category": "asset", "subcategory": "fixed_assets", "type": "detail",
     "normal_balance": "debit", "level": 3},
    {"code": "1290", "name_ar": "مجمع الإهلاك", "name_en": "Accumulated Depreciation",
     "parent": "1200", "category": "asset", "subcategory": "accumulated_dep", "type": "detail",
     "normal_balance": "credit", "level": 3},

    # ─ LIABILITIES 2xxx ─
    {"code": "2000", "name_ar": "الالتزامات", "name_en": "Liabilities",
     "category": "liability", "type": "header", "normal_balance": "credit", "level": 1},
    {"code": "2100", "name_ar": "الالتزامات المتداولة", "name_en": "Current Liabilities",
     "parent": "2000", "category": "liability", "type": "header", "normal_balance": "credit", "level": 2},
    {"code": "2110", "name_ar": "ذمم دائنة — الموردون", "name_en": "Accounts Payable",
     "parent": "2100", "category": "liability", "subcategory": "payables", "type": "detail",
     "normal_balance": "credit", "level": 3, "is_control": True},
    {"code": "2120", "name_ar": "ضريبة القيمة المضافة على المبيعات",
     "name_en": "VAT Output (Payable)",
     "parent": "2100", "category": "liability", "subcategory": "vat", "type": "detail",
     "normal_balance": "credit", "level": 3},
    {"code": "2130", "name_ar": "مستحقات موظفين", "name_en": "Salaries Payable",
     "parent": "2100", "category": "liability", "subcategory": "payroll", "type": "detail",
     "normal_balance": "credit", "level": 3},
    {"code": "2140", "name_ar": "الزكاة المستحقة", "name_en": "Zakat Payable",
     "parent": "2100", "category": "liability", "subcategory": "zakat", "type": "detail",
     "normal_balance": "credit", "level": 3},
    {"code": "2150", "name_ar": "مخصص مكافأة نهاية الخدمة", "name_en": "EoSB Provision",
     "parent": "2100", "category": "liability", "subcategory": "eosb", "type": "detail",
     "normal_balance": "credit", "level": 3},

    # ─ EQUITY 3xxx ─
    {"code": "3000", "name_ar": "حقوق الملكية", "name_en": "Equity",
     "category": "equity", "type": "header", "normal_balance": "credit", "level": 1},
    {"code": "3100", "name_ar": "رأس المال", "name_en": "Capital",
     "parent": "3000", "category": "equity", "subcategory": "capital", "type": "detail",
     "normal_balance": "credit", "level": 2},
    {"code": "3200", "name_ar": "الأرباح المحتجزة", "name_en": "Retained Earnings",
     "parent": "3000", "category": "equity", "subcategory": "retained", "type": "detail",
     "normal_balance": "credit", "level": 2},
    {"code": "3300", "name_ar": "أرباح العام الحالي", "name_en": "Current Year Earnings",
     "parent": "3000", "category": "equity", "subcategory": "current_earnings", "type": "detail",
     "normal_balance": "credit", "level": 2},

    # ─ REVENUE 4xxx ─
    {"code": "4000", "name_ar": "الإيرادات", "name_en": "Revenue",
     "category": "revenue", "type": "header", "normal_balance": "credit", "level": 1},
    {"code": "4100", "name_ar": "مبيعات", "name_en": "Sales Revenue",
     "parent": "4000", "category": "revenue", "subcategory": "sales", "type": "detail",
     "normal_balance": "credit", "level": 2},
    {"code": "4200", "name_ar": "مرتجعات المبيعات", "name_en": "Sales Returns",
     "parent": "4000", "category": "revenue", "subcategory": "returns", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "4300", "name_ar": "خصومات ممنوحة", "name_en": "Discounts Given",
     "parent": "4000", "category": "revenue", "subcategory": "discounts", "type": "detail",
     "normal_balance": "debit", "level": 2},

    # ─ EXPENSES 5xxx ─
    {"code": "5000", "name_ar": "المصروفات", "name_en": "Expenses",
     "category": "expense", "type": "header", "normal_balance": "debit", "level": 1},
    {"code": "5100", "name_ar": "تكلفة البضاعة المباعة", "name_en": "Cost of Goods Sold",
     "parent": "5000", "category": "expense", "subcategory": "cogs", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5200", "name_ar": "مصاريف الرواتب والأجور", "name_en": "Salaries & Wages",
     "parent": "5000", "category": "expense", "subcategory": "payroll", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5210", "name_ar": "التأمينات الاجتماعية (GOSI)", "name_en": "GOSI Employer",
     "parent": "5000", "category": "expense", "subcategory": "payroll", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5300", "name_ar": "مصاريف الإيجار", "name_en": "Rent",
     "parent": "5000", "category": "expense", "subcategory": "rent", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5400", "name_ar": "مصاريف المرافق", "name_en": "Utilities",
     "parent": "5000", "category": "expense", "subcategory": "utilities", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5500", "name_ar": "مصاريف التسويق", "name_en": "Marketing",
     "parent": "5000", "category": "expense", "subcategory": "marketing", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5600", "name_ar": "مصاريف إدارية", "name_en": "General & Administrative",
     "parent": "5000", "category": "expense", "subcategory": "g&a", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5700", "name_ar": "مصاريف إهلاك", "name_en": "Depreciation Expense",
     "parent": "5000", "category": "expense", "subcategory": "depreciation", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5800", "name_ar": "مصاريف بنكية", "name_en": "Bank Charges",
     "parent": "5000", "category": "expense", "subcategory": "bank_charges", "type": "detail",
     "normal_balance": "debit", "level": 2},
    {"code": "5900", "name_ar": "أرباح/خسائر فروق عملة",
     "name_en": "FX Gain/Loss",
     "parent": "5000", "category": "expense", "subcategory": "fx", "type": "detail",
     "normal_balance": "debit", "level": 2},
]


def seed_default_coa(db: Session, entity: Entity) -> dict:
    """يبذر شجرة حسابات SOCPA الافتراضية لكيان (إذا لم تكن موجودة)."""
    existing = db.query(GLAccount).filter(GLAccount.entity_id == entity.id).count()
    if existing > 0:
        return {"seeded": False, "existing": existing}

    # أولاً: بذر كل الـ headers بدون parent references (سيتم ربطها بعد ذلك)
    code_to_id: dict[str, str] = {}
    for acc in DEFAULT_COA:
        ga = GLAccount(
            tenant_id=entity.tenant_id,
            entity_id=entity.id,
            code=acc["code"],
            name_ar=acc["name_ar"],
            name_en=acc.get("name_en"),
            category=acc["category"],
            subcategory=acc.get("subcategory"),
            type=acc.get("type", "detail"),
            normal_balance=acc["normal_balance"],
            level=acc.get("level", 1),
            is_system=True,
            is_active=True,
            is_control=acc.get("is_control", False),
        )
        db.add(ga)
        db.flush()
        code_to_id[acc["code"]] = ga.id

    # ثانياً: ربط الـ parents
    for acc in DEFAULT_COA:
        if acc.get("parent"):
            parent_id = code_to_id.get(acc["parent"])
            if parent_id:
                ga = db.query(GLAccount).filter(
                    GLAccount.entity_id == entity.id,
                    GLAccount.code == acc["code"],
                ).first()
                ga.parent_account_id = parent_id

    db.flush()
    return {"seeded": True, "accounts_added": len(DEFAULT_COA)}


# ══════════════════════════════════════════════════════════════════════════
# Fiscal Period seeding
# ══════════════════════════════════════════════════════════════════════════

def seed_fiscal_periods(db: Session, entity: Entity, year: int) -> dict:
    """يفتح 12 فترة شهرية لسنة معيّنة."""
    existing = db.query(FiscalPeriod).filter(
        FiscalPeriod.entity_id == entity.id,
        FiscalPeriod.year == year,
    ).count()
    if existing > 0:
        return {"seeded": False, "year": year, "existing": existing}

    from calendar import monthrange
    added = 0
    for month in range(1, 13):
        _, last_day = monthrange(year, month)
        period = FiscalPeriod(
            tenant_id=entity.tenant_id,
            entity_id=entity.id,
            code=f"{year}-{month:02d}",
            name_ar=f"{['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'][month-1]} {year}",
            year=year,
            month=month,
            quarter=((month - 1) // 3) + 1,
            start_date=date(year, month, 1),
            end_date=date(year, month, last_day),
            status=PeriodStatus.open.value,
        )
        db.add(period)
        added += 1
    db.flush()
    return {"seeded": True, "year": year, "periods_added": added}


def find_fiscal_period(db: Session, entity_id: str, je_date: date) -> Optional[FiscalPeriod]:
    """يعثر على الفترة المحاسبية التي يقع فيها تاريخ القيد."""
    return db.query(FiscalPeriod).filter(
        FiscalPeriod.entity_id == entity_id,
        FiscalPeriod.start_date <= je_date,
        FiscalPeriod.end_date >= je_date,
    ).first()


# ══════════════════════════════════════════════════════════════════════════
# FX rate lookup
# ══════════════════════════════════════════════════════════════════════════

def get_fx_rate(
    db: Session, *, tenant_id: str, from_currency: str, to_currency: str,
    at_date: date, rate_type: str = "spot",
) -> Decimal:
    """أحدث سعر متاح في أو قبل at_date. يرجع 1 إذا العملتان متطابقتان."""
    if from_currency == to_currency:
        return Decimal("1")
    rate = db.query(FxRate).filter(
        FxRate.tenant_id == tenant_id,
        FxRate.from_currency == from_currency,
        FxRate.to_currency == to_currency,
        FxRate.rate_type == rate_type,
        FxRate.effective_date <= at_date,
    ).order_by(FxRate.effective_date.desc()).first()
    if rate:
        return Decimal(str(rate.rate))
    # حاول العكس
    inv = db.query(FxRate).filter(
        FxRate.tenant_id == tenant_id,
        FxRate.from_currency == to_currency,
        FxRate.to_currency == from_currency,
        FxRate.rate_type == rate_type,
        FxRate.effective_date <= at_date,
    ).order_by(FxRate.effective_date.desc()).first()
    if inv:
        return (Decimal("1") / Decimal(str(inv.rate))).quantize(Q8)
    raise ValueError(f"لا يوجد سعر صرف {from_currency}→{to_currency} في أو قبل {at_date}")


def convert_amount(amount: Decimal, rate: Decimal) -> Decimal:
    return (Decimal(str(amount)) * rate).quantize(Q2, rounding=ROUND_HALF_UP)


# ══════════════════════════════════════════════════════════════════════════
# JE number generation
# ══════════════════════════════════════════════════════════════════════════

def next_je_number(db: Session, entity_id: str, je_date: date) -> str:
    """JE-2026-04-00042"""
    prefix = f"JE-{je_date.year}-{je_date.month:02d}-"
    count = db.query(JournalEntry).filter(
        JournalEntry.entity_id == entity_id,
        JournalEntry.je_number.like(f"{prefix}%"),
    ).count()
    return f"{prefix}{count+1:05d}"


# ══════════════════════════════════════════════════════════════════════════
# Build & Post Journal Entry
# ══════════════════════════════════════════════════════════════════════════

def build_journal_entry(
    db: Session, *,
    entity: Entity,
    kind: str,
    je_date: date,
    memo_ar: str,
    lines_input: list[dict],
    source_type: Optional[str] = None,
    source_id: Optional[str] = None,
    source_reference: Optional[str] = None,
    created_by_user_id: Optional[str] = None,
    memo_en: Optional[str] = None,
    auto_post: bool = False,
) -> JournalEntry:
    """يبني قيد يومية + بنوده (بدون ترحيل افتراضياً).

    lines_input: list of dicts each having:
      account_id (أو account_code)
      debit (Decimal) OR credit (Decimal) — أحدهما فقط > 0
      currency (optional — default = functional)
      description (optional)
      reference, cost_center_id, profit_center_id, branch_id (optional)
      partner_type, partner_id, partner_name (optional)
      vat_code, vat_amount (optional)
    """
    if not lines_input:
        raise ValueError("قيد بدون بنود غير مسموح")

    # الفترة
    period = find_fiscal_period(db, entity.id, je_date)
    if not period:
        raise ValueError(f"لا توجد فترة محاسبية مفتوحة لـ {je_date}")
    if period.status not in (PeriodStatus.open.value, PeriodStatus.closing.value):
        raise ValueError(f"الفترة {period.code} بحالة {period.status} — غير متاحة للقيود")

    functional_ccy = entity.functional_currency

    # بناء القيد
    je = JournalEntry(
        tenant_id=entity.tenant_id,
        entity_id=entity.id,
        fiscal_period_id=period.id,
        je_number=next_je_number(db, entity.id, je_date),
        kind=kind,
        status=JournalEntryStatus.draft.value,
        source_type=source_type,
        source_id=source_id,
        source_reference=source_reference,
        memo_ar=memo_ar,
        memo_en=memo_en,
        je_date=je_date,
        created_by_user_id=created_by_user_id,
        currency=functional_ccy,
    )
    db.add(je)
    db.flush()

    total_debit = Decimal("0")
    total_credit = Decimal("0")

    for idx, lin in enumerate(lines_input, start=1):
        # العثور على الحساب
        account = None
        if lin.get("account_id"):
            account = db.query(GLAccount).filter(
                GLAccount.id == lin["account_id"],
                GLAccount.entity_id == entity.id,
            ).first()
        elif lin.get("account_code"):
            account = db.query(GLAccount).filter(
                GLAccount.entity_id == entity.id,
                GLAccount.code == lin["account_code"],
            ).first()
        if not account:
            raise ValueError(f"السطر {idx}: الحساب غير موجود")
        if account.type != AccountType.detail.value:
            raise ValueError(f"السطر {idx}: الحساب {account.code} header — لا يقبل قيود")

        debit = q2(lin.get("debit") or 0)
        credit = q2(lin.get("credit") or 0)
        if debit > 0 and credit > 0:
            raise ValueError(f"السطر {idx}: debit و credit معاً غير مسموح")
        if debit == 0 and credit == 0:
            raise ValueError(f"السطر {idx}: مبلغ صفر غير مسموح")

        line_ccy = lin.get("currency") or functional_ccy
        rate = Decimal("1")
        if line_ccy != functional_ccy:
            rate = get_fx_rate(
                db, tenant_id=entity.tenant_id,
                from_currency=line_ccy, to_currency=functional_ccy,
                at_date=je_date,
            )
        functional_debit = convert_amount(debit, rate) if debit > 0 else Decimal("0")
        functional_credit = convert_amount(credit, rate) if credit > 0 else Decimal("0")

        jl = JournalLine(
            tenant_id=entity.tenant_id,
            journal_entry_id=je.id,
            line_number=idx,
            account_id=account.id,
            currency=line_ccy,
            debit_amount=debit,
            credit_amount=credit,
            exchange_rate=rate,
            functional_debit=functional_debit,
            functional_credit=functional_credit,
            cost_center_id=lin.get("cost_center_id"),
            profit_center_id=lin.get("profit_center_id"),
            project_id=lin.get("project_id"),
            branch_id=lin.get("branch_id"),
            partner_type=lin.get("partner_type"),
            partner_id=lin.get("partner_id"),
            partner_name=lin.get("partner_name"),
            description=lin.get("description"),
            reference=lin.get("reference"),
            vat_code=lin.get("vat_code"),
            vat_amount=lin.get("vat_amount"),
        )
        db.add(jl)
        total_debit += functional_debit
        total_credit += functional_credit

    # التوازن
    if total_debit != total_credit:
        raise ValueError(
            f"القيد غير متوازن: Σdebit={total_debit} ≠ Σcredit={total_credit} "
            f"(فرق: {total_debit - total_credit})"
        )

    je.total_debit = total_debit
    je.total_credit = total_credit
    db.flush()

    if auto_post:
        post_journal_entry(db, je.id)

    return je


def post_journal_entry(db: Session, je_id: str) -> JournalEntry:
    """ترحيل قيد معتمد → إنشاء GL Postings."""
    je = db.query(JournalEntry).filter(JournalEntry.id == je_id).first()
    if not je:
        raise ValueError("القيد غير موجود")
    if je.status == JournalEntryStatus.posted.value:
        return je
    if je.status not in (JournalEntryStatus.draft.value, JournalEntryStatus.approved.value):
        raise ValueError(f"لا يمكن ترحيل قيد بحالة {je.status}")

    period = db.query(FiscalPeriod).filter(FiscalPeriod.id == je.fiscal_period_id).first()
    if period.status not in (PeriodStatus.open.value, PeriodStatus.closing.value):
        raise ValueError(f"الفترة {period.code} بحالة {period.status} — غير مفتوحة")

    # تحقق من التوازن
    if je.total_debit != je.total_credit:
        raise ValueError("القيد غير متوازن — لا يمكن ترحيله")

    # Session uses autoflush=False — explicitly flush so pending JournalLine
    # rows added by the caller (e.g. sales invoice flow) become visible to
    # this query. Without this, lines=[] silently → 0 GLPostings created
    # → JE.status='posted' but Trial Balance is empty.
    db.flush()
    lines = db.query(JournalLine).filter(JournalLine.journal_entry_id == je.id).all()
    if not lines:
        raise ValueError(f"JE {je.je_number} has no lines — cannot post")
    now = datetime.now(timezone.utc)

    for line in lines:
        account = db.query(GLAccount).filter(GLAccount.id == line.account_id).first()
        posting = GLPosting(
            tenant_id=je.tenant_id,
            entity_id=je.entity_id,
            fiscal_period_id=je.fiscal_period_id,
            account_id=line.account_id,
            journal_entry_id=je.id,
            journal_line_id=line.id,
            debit_amount=line.functional_debit,
            credit_amount=line.functional_credit,
            currency=je.currency,
            cost_center_id=line.cost_center_id,
            profit_center_id=line.profit_center_id,
            project_id=line.project_id,
            branch_id=line.branch_id,
            partner_type=line.partner_type,
            partner_id=line.partner_id,
            posting_date=je.je_date,
        )
        db.add(posting)

    je.status = JournalEntryStatus.posted.value
    je.posted_at = now
    je.posting_date = je.je_date

    # تحديث إحصائيات الفترة
    period.je_count = (period.je_count or 0) + 1
    period.total_debits = (period.total_debits or Decimal("0")) + je.total_debit
    period.total_credits = (period.total_credits or Decimal("0")) + je.total_credit

    db.flush()
    return je


def reverse_journal_entry(
    db: Session, je_id: str, reversal_date: date, memo_ar: str,
    user_id: Optional[str] = None,
) -> JournalEntry:
    """ينشئ قيداً عكسياً (نفس الحسابات، debit↔credit)."""
    original = db.query(JournalEntry).filter(JournalEntry.id == je_id).first()
    if not original:
        raise ValueError("القيد الأصلي غير موجود")
    if original.status != JournalEntryStatus.posted.value:
        raise ValueError("لا يمكن عكس قيد غير مُرحَّل")
    if original.reversed_by_je_id:
        raise ValueError("القيد مُعكَّس مسبقاً")

    entity = db.query(Entity).filter(Entity.id == original.entity_id).first()
    orig_lines = db.query(JournalLine).filter(JournalLine.journal_entry_id == original.id).all()

    lines_input = []
    for line in orig_lines:
        lines_input.append({
            "account_id": line.account_id,
            "debit": line.credit_amount,   # عكس
            "credit": line.debit_amount,   # عكس
            "currency": line.currency,
            "cost_center_id": line.cost_center_id,
            "profit_center_id": line.profit_center_id,
            "project_id": line.project_id,
            "branch_id": line.branch_id,
            "description": f"عكس: {line.description or ''}",
            "reference": line.reference,
        })

    reversal = build_journal_entry(
        db, entity=entity,
        kind=JournalEntryKind.reversal.value,
        je_date=reversal_date,
        memo_ar=memo_ar,
        lines_input=lines_input,
        source_type="je_reversal",
        source_id=original.id,
        source_reference=original.je_number,
        created_by_user_id=user_id,
        auto_post=True,
    )
    reversal.reversal_of_je_id = original.id
    original.reversed_by_je_id = reversal.id
    original.status = JournalEntryStatus.reversed.value
    db.flush()
    return reversal


# ══════════════════════════════════════════════════════════════════════════
# Auto-post from POS
# ══════════════════════════════════════════════════════════════════════════

def _find_account(db: Session, entity_id: str, code: str) -> GLAccount:
    a = db.query(GLAccount).filter(
        GLAccount.entity_id == entity_id, GLAccount.code == code
    ).first()
    if not a:
        raise ValueError(f"الحساب {code} غير موجود في شجرة حسابات هذا الكيان")
    return a


def auto_post_pos_sale(db: Session, pos_txn_id: str, auto_post: bool = True) -> JournalEntry:
    """يُنشئ قيداً تلقائياً من معاملة POS مكتملة.

    منطق البيع النقدي (سعر شامل VAT):

      المدين: 1110 النقد              = grand_total
      الدائن: 4100 المبيعات            = taxable_amount
      الدائن: 2120 VAT مستحقة          = vat_total

      المدين: 5100 COGS                = Σ(qty × unit_cost)  [إن وُجد cost]
      الدائن: 1140 المخزون             = Σ(qty × unit_cost)

    للدفعات المتعددة نوزّع المدين حسب الطريقة:
      cash → 1110، mada/visa → 1120

    للمرتجعات: نعكس الاتجاهات.
    """
    txn = db.query(PosTransaction).filter(PosTransaction.id == pos_txn_id).first()
    if not txn:
        raise ValueError("معاملة POS غير موجودة")
    if txn.status != "completed":
        raise ValueError(f"لا يمكن ترحيل معاملة بحالة {txn.status}")

    # هل مُرحّلة سابقاً؟
    existing = db.query(JournalEntry).filter(
        JournalEntry.source_type == "pos_txn",
        JournalEntry.source_id == txn.id,
    ).first()
    if existing:
        return existing

    # تحميل الكيان
    from app.pilot.models import Branch
    branch = db.query(Branch).filter(Branch.id == txn.branch_id).first()
    entity = db.query(Entity).filter(Entity.id == branch.entity_id).first()

    is_return = txn.kind == "return"
    sign = Decimal("-1") if is_return else Decimal("1")

    lines_input: list[dict] = []

    # 1) جانب النقد/البنك حسب طريقة الدفع
    payments = db.query(PosPayment).filter(
        PosPayment.transaction_id == txn.id, PosPayment.status == "captured"
    ).all()
    for p in payments:
        if p.method == "cash":
            # للبيع: debit cash (+ tendered - change). للمرتجع: credit cash.
            net_cash = p.amount - (txn.change_given if not is_return else Decimal("0"))
            if net_cash > 0:
                lines_input.append({
                    "account_code": "1110",
                    "debit": net_cash if not is_return else 0,
                    "credit": net_cash if is_return else 0,
                    "description": f"نقد — إيصال {txn.receipt_number}",
                    "reference": txn.receipt_number,
                    "branch_id": txn.branch_id,
                })
        else:
            # بطاقة / بوابة إلكترونية → بنك
            lines_input.append({
                "account_code": "1120",
                "debit": p.amount if not is_return else 0,
                "credit": p.amount if is_return else 0,
                "description": f"{p.method} — إيصال {txn.receipt_number}",
                "reference": p.reference_number or txn.receipt_number,
                "branch_id": txn.branch_id,
            })

    # 2) المبيعات (قيمة صافية قبل VAT)
    if txn.taxable_amount:
        lines_input.append({
            "account_code": "4200" if is_return else "4100",
            "debit": abs(txn.taxable_amount) if is_return else 0,
            "credit": abs(txn.taxable_amount) if not is_return else 0,
            "description": f"{'مرتجع' if is_return else 'مبيعات'} — {txn.receipt_number}",
            "reference": txn.receipt_number,
            "branch_id": txn.branch_id,
        })

    # 3) VAT
    if txn.vat_total and abs(txn.vat_total) > 0:
        lines_input.append({
            "account_code": "2120",
            "debit": abs(txn.vat_total) if is_return else 0,
            "credit": abs(txn.vat_total) if not is_return else 0,
            "description": f"VAT — {txn.receipt_number}",
            "reference": txn.receipt_number,
            "branch_id": txn.branch_id,
            "vat_code": "standard",
            "vat_amount": abs(txn.vat_total),
        })

    # 4) COGS + Inventory
    lines = db.query(PosTransactionLine).filter(
        PosTransactionLine.transaction_id == txn.id
    ).all()
    total_cogs = Decimal("0")
    for ln in lines:
        if ln.unit_cost and ln.qty:
            cogs_value = (Decimal(str(ln.unit_cost)) * Decimal(str(ln.qty))).quantize(Q2)
            total_cogs += cogs_value
    if total_cogs > 0:
        # للبيع: debit COGS / credit Inventory.
        # للمرتجع: العكس.
        lines_input.append({
            "account_code": "5100",
            "debit": total_cogs if not is_return else 0,
            "credit": total_cogs if is_return else 0,
            "description": f"COGS — {txn.receipt_number}",
            "reference": txn.receipt_number,
            "branch_id": txn.branch_id,
        })
        lines_input.append({
            "account_code": "1140",
            "debit": total_cogs if is_return else 0,
            "credit": total_cogs if not is_return else 0,
            "description": f"مخزون — {txn.receipt_number}",
            "reference": txn.receipt_number,
            "branch_id": txn.branch_id,
        })

    memo = f"{'مرتجع' if is_return else 'مبيعات'} نقطة البيع — {txn.receipt_number}"
    je = build_journal_entry(
        db, entity=entity,
        kind=(JournalEntryKind.auto_pos.value),
        je_date=txn.transacted_at.date(),
        memo_ar=memo,
        lines_input=lines_input,
        source_type="pos_txn",
        source_id=txn.id,
        source_reference=txn.receipt_number,
        created_by_user_id=txn.cashier_user_id,
        auto_post=auto_post,
    )
    return je


# ══════════════════════════════════════════════════════════════════════════
# Trial Balance
# ══════════════════════════════════════════════════════════════════════════

def compute_trial_balance(
    db: Session, *, entity_id: str, as_of_date: date,
    include_zero: bool = False,
) -> list[dict]:
    """ميزان المراجعة حتى تاريخ معيّن — صف واحد لكل حساب detail."""
    from sqlalchemy import case

    # كل الـ postings لهذا الكيان ≤ as_of_date
    rows = (
        db.query(
            GLPosting.account_id,
            func.sum(GLPosting.debit_amount).label("total_debit"),
            func.sum(GLPosting.credit_amount).label("total_credit"),
        )
        .filter(
            GLPosting.entity_id == entity_id,
            GLPosting.posting_date <= as_of_date,
        )
        .group_by(GLPosting.account_id)
        .all()
    )
    by_acct = {r[0]: (Decimal(str(r[1] or 0)), Decimal(str(r[2] or 0))) for r in rows}

    # كل الحسابات detail
    accounts = db.query(GLAccount).filter(
        GLAccount.entity_id == entity_id,
        GLAccount.type == AccountType.detail.value,
        GLAccount.is_active == True,  # noqa: E712
    ).order_by(GLAccount.code).all()

    result = []
    for acc in accounts:
        debit, credit = by_acct.get(acc.id, (Decimal("0"), Decimal("0")))
        if not include_zero and debit == 0 and credit == 0:
            continue
        # الرصيد وفقاً للطبيعة
        if acc.normal_balance == NormalBalance.debit.value:
            balance = debit - credit
        else:
            balance = credit - debit
        result.append({
            "account_id": acc.id,
            "code": acc.code,
            "name_ar": acc.name_ar,
            "name_en": acc.name_en,
            "category": acc.category,
            "subcategory": acc.subcategory,
            "normal_balance": acc.normal_balance,
            "total_debit": debit,
            "total_credit": credit,
            "balance": balance,
        })
    return result


def compute_income_statement(
    db: Session, *, entity_id: str, start_date: date, end_date: date,
) -> dict:
    """قائمة الدخل (P&L) لفترة."""
    rows = (
        db.query(
            GLAccount.category,
            GLAccount.subcategory,
            func.sum(GLPosting.debit_amount).label("total_debit"),
            func.sum(GLPosting.credit_amount).label("total_credit"),
        )
        .join(GLAccount, GLAccount.id == GLPosting.account_id)
        .filter(
            GLPosting.entity_id == entity_id,
            GLPosting.posting_date >= start_date,
            GLPosting.posting_date <= end_date,
            GLAccount.category.in_([AccountCategory.revenue.value, AccountCategory.expense.value]),
        )
        .group_by(GLAccount.category, GLAccount.subcategory)
        .all()
    )

    revenue_total = Decimal("0")
    expense_total = Decimal("0")
    by_subcat = {"revenue": {}, "expense": {}}
    for cat, subcat, dr, cr in rows:
        dr = Decimal(str(dr or 0))
        cr = Decimal(str(cr or 0))
        if cat == "revenue":
            amount = cr - dr   # الإيرادات طبيعتها دائنة
            revenue_total += amount
            by_subcat["revenue"][subcat or "other"] = amount
        else:
            amount = dr - cr   # المصروفات طبيعتها مدينة
            expense_total += amount
            by_subcat["expense"][subcat or "other"] = amount

    net_income = revenue_total - expense_total
    return {
        "entity_id": entity_id,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "revenue_total": float(revenue_total),
        "expense_total": float(expense_total),
        "net_income": float(net_income),
        "revenue_by_subcat": {k: float(v) for k, v in by_subcat["revenue"].items()},
        "expense_by_subcat": {k: float(v) for k, v in by_subcat["expense"].items()},
    }


def compute_balance_sheet(db: Session, *, entity_id: str, as_of_date: date) -> dict:
    """قائمة المركز المالي حتى تاريخ."""
    tb = compute_trial_balance(db, entity_id=entity_id, as_of_date=as_of_date, include_zero=False)
    assets = sum((r["balance"] for r in tb if r["category"] == "asset"), Decimal("0"))
    liabilities = sum((r["balance"] for r in tb if r["category"] == "liability"), Decimal("0"))
    equity = sum((r["balance"] for r in tb if r["category"] == "equity"), Decimal("0"))

    # صافي الدخل يُضاف كحقوق ملكية حتى الإقفال
    # نحسب revenue/expense لتاريخ بداية السنة حتى as_of_date
    year_start = date(as_of_date.year, 1, 1)
    income = compute_income_statement(db, entity_id=entity_id, start_date=year_start, end_date=as_of_date)
    current_earnings = Decimal(str(income["net_income"]))

    total_equity_effective = equity + current_earnings

    return {
        "entity_id": entity_id,
        "as_of_date": as_of_date.isoformat(),
        "assets": float(assets),
        "liabilities": float(liabilities),
        "equity": float(equity),
        "current_earnings": float(current_earnings),
        "total_equity": float(total_equity_effective),
        "balanced": (assets - (liabilities + total_equity_effective)).quantize(Q2) == Decimal("0.00"),
        "difference": float(assets - (liabilities + total_equity_effective)),
    }


def compute_cash_flow(
    db: Session, *, entity_id: str, start_date: date, end_date: date,
) -> dict:
    """قائمة التدفقات النقدية بطريقة غير مباشرة (Indirect Method).

    Net Income
      + Depreciation & Amortization
      - Increase in AR / + Decrease in AR
      - Increase in Inventory / + Decrease
      + Increase in AP / - Decrease
    = Cash Flow from Operations

    Investing: purchases/sales of fixed assets
    Financing: loans, equity issuance, dividends

    For v1 we compute Operating activities from P&L + WC changes.
    Investing/Financing require account tagging (future).
    """
    # 1) Net income من قائمة الدخل
    income = compute_income_statement(db, entity_id=entity_id,
                                       start_date=start_date, end_date=end_date)
    net_income = Decimal(str(income["net_income"]))

    # 2) حساب التغيّر في working capital (AR + Inventory + AP)
    # نحسب رصيد بداية وآخر الفترة لكل category
    def _category_balance(cat: str, on_date: date) -> Decimal:
        tb = compute_trial_balance(db, entity_id=entity_id,
                                    as_of_date=on_date, include_zero=False)
        return sum((r["balance"] for r in tb if r["category"] == cat),
                    Decimal("0"))

    # تغيّر الأصول المتداولة (AR, Inventory) — زيادة = استخدام نقدية
    # نُحدّد الحسابات بـ subcategory (لو موجودة). v1: نستخدم الـ category الكلية
    start_date_prev = date(start_date.year, start_date.month, start_date.day)
    # رصيد يوم قبل البداية
    from datetime import timedelta
    start_prev_day = start_date - timedelta(days=1)

    try:
        ar_change = _category_balance("asset", end_date) - _category_balance("asset", start_prev_day)
        ap_change = _category_balance("liability", end_date) - _category_balance("liability", start_prev_day)
    except Exception:
        ar_change = Decimal("0")
        ap_change = Decimal("0")

    # دلالة: زيادة أصول = تدفق خارج، زيادة خصوم = تدفق داخل
    operating_cf = net_income - ar_change + ap_change

    # 3) الفرق في النقدية (من TB — نقارن رصيد النقدية والبنوك)
    # حسابات النقدية تبدأ بـ 111x (cash) و 112x (banks) حسب SOCPA
    cash_start = Decimal("0")
    cash_end = Decimal("0")
    tb_end = compute_trial_balance(db, entity_id=entity_id,
                                    as_of_date=end_date, include_zero=False)
    for r in tb_end:
        if r["code"].startswith(("111", "112")):
            cash_end += r["balance"]
    tb_start = compute_trial_balance(db, entity_id=entity_id,
                                      as_of_date=start_prev_day, include_zero=False)
    for r in tb_start:
        if r["code"].startswith(("111", "112")):
            cash_start += r["balance"]

    actual_cash_change = cash_end - cash_start

    return {
        "entity_id": entity_id,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "net_income": float(net_income),
        "working_capital_change": float(-ar_change + ap_change),
        "ar_change": float(ar_change),
        "ap_change": float(ap_change),
        "operating_cf": float(operating_cf),
        "investing_cf": 0.0,  # v2: سنضيف تصنيف الأصول الثابتة
        "financing_cf": 0.0,  # v2: سنضيف تصنيف القروض وحقوق الملكية
        "net_cash_change": float(operating_cf),
        "cash_beginning": float(cash_start),
        "cash_ending": float(cash_end),
        "actual_cash_change": float(actual_cash_change),
        "variance": float(actual_cash_change - operating_cf),
    }


def compute_comparative_report(
    db: Session, *, entity_id: str, report_type: str,
    current_start: date, current_end: date,
    prior_start: Optional[date] = None, prior_end: Optional[date] = None,
) -> dict:
    """تقرير مقارن — التقرير الحالي vs فترة سابقة.

    report_type: income_statement | balance_sheet | trial_balance

    إذا prior_start/end غير محدد، يُحسب تلقائياً = نفس الفترة في السنة السابقة.
    """
    # Default: نفس الفترة في السنة السابقة
    if prior_start is None or prior_end is None:
        prior_start = date(
            current_start.year - 1, current_start.month, current_start.day
        )
        prior_end = date(current_end.year - 1, current_end.month, current_end.day)

    if report_type == "income_statement":
        current = compute_income_statement(
            db, entity_id=entity_id,
            start_date=current_start, end_date=current_end,
        )
        prior = compute_income_statement(
            db, entity_id=entity_id,
            start_date=prior_start, end_date=prior_end,
        )
        # احسب النسب
        def _variance(c: float, p: float) -> dict:
            diff = c - p
            pct = (diff / abs(p) * 100) if p != 0 else (100.0 if c != 0 else 0.0)
            return {"current": c, "prior": p, "diff": diff, "pct": pct}

        return {
            "report_type": "income_statement",
            "current_period": {
                "start": current_start.isoformat(),
                "end": current_end.isoformat(),
            },
            "prior_period": {
                "start": prior_start.isoformat(),
                "end": prior_end.isoformat(),
            },
            "revenue": _variance(current["revenue_total"], prior["revenue_total"]),
            "expenses": _variance(current["expense_total"], prior["expense_total"]),
            "net_income": _variance(current["net_income"], prior["net_income"]),
        }
    elif report_type == "balance_sheet":
        current = compute_balance_sheet(db, entity_id=entity_id, as_of_date=current_end)
        prior = compute_balance_sheet(db, entity_id=entity_id, as_of_date=prior_end)

        def _variance(c: float, p: float) -> dict:
            diff = c - p
            pct = (diff / abs(p) * 100) if p != 0 else (100.0 if c != 0 else 0.0)
            return {"current": c, "prior": p, "diff": diff, "pct": pct}

        return {
            "report_type": "balance_sheet",
            "current_as_of": current_end.isoformat(),
            "prior_as_of": prior_end.isoformat(),
            "assets": _variance(current["assets"], prior["assets"]),
            "liabilities": _variance(current["liabilities"], prior["liabilities"]),
            "equity": _variance(current["total_equity"], prior["total_equity"]),
        }
    else:
        raise ValueError(f"Unsupported report_type: {report_type}")


def compute_account_ledger(
    db: Session, *, account_id: str, start_date: Optional[date] = None,
    end_date: Optional[date] = None, limit: int = 500,
) -> dict:
    """دفتر الأستاذ لحساب واحد — كل حركاته (postings) بين تاريخين.

    يُرجع:
        • الحساب (code, name)
        • رصيد افتتاحي (قبل start_date)
        • جميع الحركات في الفترة مع running_balance
        • رصيد ختامي
    """
    acc = db.query(GLAccount).filter(GLAccount.id == account_id).first()
    if not acc:
        raise ValueError(f"Account {account_id} not found")

    q = db.query(GLPosting).filter(GLPosting.account_id == account_id)

    # رصيد افتتاحي
    opening_balance = Decimal("0")
    if start_date:
        openings = db.query(
            func.sum(GLPosting.debit_amount).label("d"),
            func.sum(GLPosting.credit_amount).label("c"),
        ).filter(
            GLPosting.account_id == account_id,
            GLPosting.posting_date < start_date,
        ).first()
        d = Decimal(str(openings.d or 0))
        c = Decimal(str(openings.c or 0))
        if acc.normal_balance == NormalBalance.debit.value:
            opening_balance = d - c
        else:
            opening_balance = c - d
        q = q.filter(GLPosting.posting_date >= start_date)

    if end_date:
        q = q.filter(GLPosting.posting_date <= end_date)

    postings = q.order_by(GLPosting.posting_date, GLPosting.created_at).limit(limit).all()

    # بناء صفوف مع running balance
    running = opening_balance
    rows = []
    for p in postings:
        d = Decimal(str(p.debit_amount or 0))
        c = Decimal(str(p.credit_amount or 0))
        if acc.normal_balance == NormalBalance.debit.value:
            running += (d - c)
        else:
            running += (c - d)
        # جلب JE number + memo للعرض
        je = p.journal_entry if p.journal_entry else None
        rows.append({
            "id": p.id,
            "posting_date": p.posting_date.isoformat() if p.posting_date else None,
            "je_number": je.je_number if je else None,
            "je_memo_ar": je.memo_ar if je else None,
            "description": p.description,
            "reference": p.reference,
            "partner_name": p.partner_name,
            "debit": float(d),
            "credit": float(c),
            "running_balance": float(running),
        })

    total_debit = sum((Decimal(str(r["debit"])) for r in rows), Decimal("0"))
    total_credit = sum((Decimal(str(r["credit"])) for r in rows), Decimal("0"))

    return {
        "account_id": account_id,
        "code": acc.code,
        "name_ar": acc.name_ar,
        "name_en": acc.name_en,
        "category": acc.category,
        "normal_balance": acc.normal_balance,
        "start_date": start_date.isoformat() if start_date else None,
        "end_date": end_date.isoformat() if end_date else None,
        "opening_balance": float(opening_balance),
        "total_debit": float(total_debit),
        "total_credit": float(total_credit),
        "closing_balance": float(running),
        "rows": rows,
    }
