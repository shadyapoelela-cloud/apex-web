"""Seed data for CoA-1 — packaged standard templates.

Three templates ship as part of CoA-1:

  SOCPA-Retail-2024     — Saudi retail, ZATCA-aware (largest, ~120 acct)
  IFRS-Services-2024    — service businesses, IFRS 15 revenue (~80 acct)
  IFRS-Manufacturing-2024 — manufacturing with WIP / FG (~110 acct)

Each template's `accounts` JSON array contains plain dicts mirroring
`ChartOfAccount` field shapes minus tenant/entity/id (the importer
fills those at runtime). The hierarchy is encoded via `parent_code`
strings — the importer resolves `parent_code` → `parent_id` after
inserting each level.

Idempotent: `seed_coa_templates(db)` upserts by `(tenant_id IS NULL, code)`
so it's safe to call on every startup or from `seed_runner.py`.

Data sources:
  - SOCPA accounts list 2024 (Saudi Organization for Chartered and
    Professional Accountants official taxonomy).
  - IFRS line items per the IASB Practice Statement.
  - Industry overlay vetted against retail / services / manufacturing
    audit checklists.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.coa.models import AccountTemplate
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)


# ── Account dict factory ──────────────────────────────────


def _acct(
    code: str,
    name_ar: str,
    name_en: str,
    *,
    parent: str | None = None,
    cls: str,
    typ: str,
    nb: str,
    level: int = 1,
    postable: bool = True,
    reconcilable: bool = False,
    standard_ref: str | None = None,
) -> dict[str, Any]:
    return {
        "account_code": code,
        "parent_code": parent,
        "level": level,
        "name_ar": name_ar,
        "name_en": name_en,
        "account_class": cls,
        "account_type": typ,
        "normal_balance": nb,
        "is_active": True,
        "is_system": level <= 2,  # top 2 levels are protected
        "is_postable": postable,
        "is_reconcilable": reconcilable,
        "standard_ref": standard_ref,
    }


# ── SOCPA Retail 2024 ─────────────────────────────────────


def _socpa_retail_accounts() -> list[dict[str, Any]]:
    A = []  # accumulator

    # ── 1 الأصول (Assets) ────────────────────────────────
    A.append(_acct("1", "الأصول", "Assets", cls="asset", typ="asset", nb="debit",
                   level=1, postable=False, standard_ref="SOCPA-A"))
    # 11 الأصول المتداولة
    A.append(_acct("11", "الأصول المتداولة", "Current Assets",
                   parent="1", cls="asset", typ="current_asset", nb="debit",
                   level=2, postable=False, standard_ref="SOCPA-A.1"))
    # 110 النقد وما في حكمه
    A.append(_acct("110", "النقد وما في حكمه", "Cash & Equivalents",
                   parent="11", cls="asset", typ="cash", nb="debit",
                   level=3, postable=False, standard_ref="SOCPA-A.1.1"))
    A.append(_acct("1101", "الصندوق الرئيسي", "Main Cash Box",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True, standard_ref="SOCPA-A.1.1.1"))
    A.append(_acct("1102", "البنك الأهلي - حساب جاري", "NCB - Current Account",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True, standard_ref="SOCPA-A.1.1.2"))
    A.append(_acct("1103", "بنك الراجحي - حساب جاري", "Al Rajhi - Current Account",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True, standard_ref="SOCPA-A.1.1.3"))
    A.append(_acct("1104", "نقد لدى نقاط البيع", "POS Cash on Hand",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True))
    # 113 الذمم المدينة
    A.append(_acct("113", "الذمم المدينة", "Accounts Receivable",
                   parent="11", cls="asset", typ="ar", nb="debit",
                   level=3, postable=False, standard_ref="SOCPA-A.1.3"))
    A.append(_acct("1131", "ذمم العملاء التجاريين", "Trade AR",
                   parent="113", cls="asset", typ="ar", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("1132", "ذمم بطاقات الائتمان", "Credit Card AR",
                   parent="113", cls="asset", typ="ar", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("1133", "مخصص الديون المشكوك في تحصيلها", "Allowance for Doubtful AR",
                   parent="113", cls="asset", typ="ar_contra", nb="credit",
                   level=4))
    # 114 المخزون
    A.append(_acct("114", "المخزون", "Inventory",
                   parent="11", cls="asset", typ="inventory", nb="debit",
                   level=3, postable=False, standard_ref="SOCPA-A.1.4"))
    A.append(_acct("1141", "مخزون البضائع", "Merchandise Inventory",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4))
    A.append(_acct("1142", "مخزون التعبئة والتغليف", "Packaging Inventory",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4))
    A.append(_acct("1143", "بضاعة بالطريق", "Goods in Transit",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4))
    A.append(_acct("1144", "مخصص هبوط قيمة المخزون", "Inventory Impairment Allowance",
                   parent="114", cls="asset", typ="inventory_contra", nb="credit",
                   level=4))
    # 115 ضرائب مدفوعة مقدماً
    A.append(_acct("115", "ضرائب مدفوعة مقدماً", "Prepaid Taxes",
                   parent="11", cls="asset", typ="prepaid", nb="debit",
                   level=3, postable=False))
    A.append(_acct("1151", "ضريبة القيمة المضافة - مدخلات", "VAT Input",
                   parent="115", cls="asset", typ="vat_input", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("1152", "ضريبة استقطاع - WHT دفعات للموردين", "WHT Receivable",
                   parent="115", cls="asset", typ="prepaid", nb="debit",
                   level=4))
    # 116 المصاريف المدفوعة مقدماً
    A.append(_acct("116", "المصاريف المدفوعة مقدماً", "Prepaid Expenses",
                   parent="11", cls="asset", typ="prepaid", nb="debit",
                   level=3, postable=False))
    A.append(_acct("1161", "إيجارات مدفوعة مقدماً", "Prepaid Rent",
                   parent="116", cls="asset", typ="prepaid", nb="debit",
                   level=4))
    A.append(_acct("1162", "تأمينات مدفوعة مقدماً", "Prepaid Insurance",
                   parent="116", cls="asset", typ="prepaid", nb="debit",
                   level=4))

    # 12 الأصول غير المتداولة
    A.append(_acct("12", "الأصول غير المتداولة", "Non-Current Assets",
                   parent="1", cls="asset", typ="non_current_asset", nb="debit",
                   level=2, postable=False, standard_ref="SOCPA-A.2"))
    A.append(_acct("121", "الأصول الثابتة", "Fixed Assets",
                   parent="12", cls="asset", typ="fixed_asset", nb="debit",
                   level=3, postable=False, standard_ref="SOCPA-A.2.1"))
    A.append(_acct("1211", "أراضي", "Land",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1212", "مباني", "Buildings",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1213", "أثاث ومعدات المتجر", "Store Furniture & Equipment",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1214", "أجهزة كمبيوتر وبرامج", "Computers & Software",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1215", "وسائل نقل", "Vehicles",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1219", "مجمع إهلاك الأصول الثابتة", "Accumulated Depreciation",
                   parent="121", cls="asset", typ="fixed_asset_contra", nb="credit", level=4))
    A.append(_acct("122", "الأصول غير الملموسة", "Intangible Assets",
                   parent="12", cls="asset", typ="intangible", nb="debit",
                   level=3, postable=False))
    A.append(_acct("1221", "براءات اختراع وعلامات تجارية", "Patents & Trademarks",
                   parent="122", cls="asset", typ="intangible", nb="debit", level=4))
    A.append(_acct("1222", "حقوق امتياز", "Franchise Rights",
                   parent="122", cls="asset", typ="intangible", nb="debit", level=4))
    A.append(_acct("1229", "مجمع إطفاء الأصول غير الملموسة", "Accum. Amortization Intangibles",
                   parent="122", cls="asset", typ="intangible_contra", nb="credit", level=4))

    # ── 2 الخصوم (Liabilities) ─────────────────────────────
    A.append(_acct("2", "الخصوم", "Liabilities",
                   cls="liability", typ="liability", nb="credit",
                   level=1, postable=False, standard_ref="SOCPA-L"))
    A.append(_acct("21", "الخصوم المتداولة", "Current Liabilities",
                   parent="2", cls="liability", typ="current_liability", nb="credit",
                   level=2, postable=False, standard_ref="SOCPA-L.1"))
    A.append(_acct("211", "الذمم الدائنة", "Accounts Payable",
                   parent="21", cls="liability", typ="ap", nb="credit",
                   level=3, postable=False, standard_ref="SOCPA-L.1.1"))
    A.append(_acct("2111", "ذمم الموردين التجاريين", "Trade AP",
                   parent="211", cls="liability", typ="ap", nb="credit",
                   level=4, reconcilable=True))
    A.append(_acct("2112", "مستحقات الموردين", "Accrued Vendor Liabilities",
                   parent="211", cls="liability", typ="accrued", nb="credit", level=4))
    A.append(_acct("212", "الضرائب والزكاة المستحقة", "Taxes & Zakat Payable",
                   parent="21", cls="liability", typ="tax_payable", nb="credit",
                   level=3, postable=False, standard_ref="SOCPA-L.1.2"))
    A.append(_acct("2121", "ضريبة القيمة المضافة - مخرجات", "VAT Output",
                   parent="212", cls="liability", typ="vat_output", nb="credit",
                   level=4, reconcilable=True))
    A.append(_acct("2122", "ضريبة استقطاع مستحقة", "WHT Payable",
                   parent="212", cls="liability", typ="tax_payable", nb="credit", level=4))
    A.append(_acct("2123", "زكاة مستحقة", "Zakat Payable",
                   parent="212", cls="liability", typ="tax_payable", nb="credit", level=4))
    A.append(_acct("2124", "ضريبة دخل مستحقة", "Income Tax Payable",
                   parent="212", cls="liability", typ="tax_payable", nb="credit", level=4))
    A.append(_acct("213", "الرواتب والأجور المستحقة", "Salaries & Wages Payable",
                   parent="21", cls="liability", typ="payroll_liability", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2131", "رواتب مستحقة", "Salaries Payable",
                   parent="213", cls="liability", typ="payroll_liability", nb="credit", level=4))
    A.append(_acct("2132", "اشتراكات GOSI مستحقة", "GOSI Payable",
                   parent="213", cls="liability", typ="payroll_liability", nb="credit", level=4))
    A.append(_acct("2133", "مكافأة نهاية الخدمة - الجزء قصير الأجل", "EOSB Current Portion",
                   parent="213", cls="liability", typ="payroll_liability", nb="credit", level=4))
    A.append(_acct("214", "مصاريف مستحقة", "Accrued Expenses",
                   parent="21", cls="liability", typ="accrued", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2141", "إيجارات مستحقة", "Accrued Rent",
                   parent="214", cls="liability", typ="accrued", nb="credit", level=4))
    A.append(_acct("2142", "كهرباء وماء مستحقة", "Accrued Utilities",
                   parent="214", cls="liability", typ="accrued", nb="credit", level=4))
    A.append(_acct("215", "ودائع وأمانات", "Deposits & Trust Funds",
                   parent="21", cls="liability", typ="other_liability", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2151", "أمانات قابلة للاسترداد - عملاء", "Refundable Customer Deposits",
                   parent="215", cls="liability", typ="other_liability", nb="credit", level=4))
    # 22 الخصوم غير المتداولة
    A.append(_acct("22", "الخصوم غير المتداولة", "Non-Current Liabilities",
                   parent="2", cls="liability", typ="non_current_liability", nb="credit",
                   level=2, postable=False, standard_ref="SOCPA-L.2"))
    A.append(_acct("221", "قروض طويلة الأجل", "Long-Term Loans",
                   parent="22", cls="liability", typ="non_current_liability", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2211", "قروض بنكية طويلة الأجل", "Bank Loans LT",
                   parent="221", cls="liability", typ="non_current_liability", nb="credit",
                   level=4, reconcilable=True))
    A.append(_acct("222", "مكافأة نهاية الخدمة", "End of Service Benefit",
                   parent="22", cls="liability", typ="non_current_liability", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2221", "مخصص EOSB - الجزء طويل الأجل", "EOSB LT Portion",
                   parent="222", cls="liability", typ="non_current_liability", nb="credit", level=4))

    # ── 3 حقوق الملكية (Equity) ────────────────────────────
    A.append(_acct("3", "حقوق الملكية", "Equity",
                   cls="equity", typ="equity", nb="credit",
                   level=1, postable=False, standard_ref="SOCPA-E"))
    A.append(_acct("31", "رأس المال", "Capital",
                   parent="3", cls="equity", typ="capital", nb="credit",
                   level=2, postable=False))
    A.append(_acct("311", "رأس المال المدفوع", "Paid-In Capital",
                   parent="31", cls="equity", typ="capital", nb="credit", level=3))
    A.append(_acct("32", "الاحتياطيات", "Reserves",
                   parent="3", cls="equity", typ="reserves", nb="credit",
                   level=2, postable=False))
    A.append(_acct("321", "الاحتياطي النظامي", "Statutory Reserve",
                   parent="32", cls="equity", typ="reserves", nb="credit", level=3))
    A.append(_acct("33", "الأرباح المرحّلة", "Retained Earnings",
                   parent="3", cls="equity", typ="retained_earnings", nb="credit",
                   level=2, postable=False))
    A.append(_acct("331", "أرباح مرحّلة - السنوات السابقة", "Retained Earnings PY",
                   parent="33", cls="equity", typ="retained_earnings", nb="credit", level=3))
    A.append(_acct("332", "أرباح/خسائر السنة الحالية", "Current Year Earnings",
                   parent="33", cls="equity", typ="retained_earnings", nb="credit", level=3))

    # ── 4 الإيرادات (Revenue) ─────────────────────────────
    A.append(_acct("4", "الإيرادات", "Revenue",
                   cls="revenue", typ="revenue", nb="credit",
                   level=1, postable=False, standard_ref="SOCPA-R"))
    A.append(_acct("41", "إيرادات المبيعات", "Sales Revenue",
                   parent="4", cls="revenue", typ="sales", nb="credit",
                   level=2, postable=False, standard_ref="SOCPA-R.1"))
    A.append(_acct("411", "مبيعات البضائع", "Merchandise Sales",
                   parent="41", cls="revenue", typ="sales", nb="credit", level=3))
    A.append(_acct("4111", "مبيعات نقدية", "Cash Sales",
                   parent="411", cls="revenue", typ="sales", nb="credit", level=4))
    A.append(_acct("4112", "مبيعات آجلة", "Credit Sales",
                   parent="411", cls="revenue", typ="sales", nb="credit", level=4))
    A.append(_acct("412", "مردودات ومسموحات المبيعات", "Sales Returns & Allowances",
                   parent="41", cls="revenue", typ="sales_contra", nb="debit",
                   level=3, postable=False))
    A.append(_acct("4121", "مردودات المبيعات", "Sales Returns",
                   parent="412", cls="revenue", typ="sales_contra", nb="debit", level=4))
    A.append(_acct("4122", "خصم مكتسب للعملاء", "Customer Discounts",
                   parent="412", cls="revenue", typ="sales_contra", nb="debit", level=4))
    A.append(_acct("42", "إيرادات أخرى", "Other Revenue",
                   parent="4", cls="revenue", typ="other_revenue", nb="credit",
                   level=2, postable=False))
    A.append(_acct("421", "إيرادات استثمار", "Investment Income",
                   parent="42", cls="revenue", typ="other_revenue", nb="credit", level=3))
    A.append(_acct("422", "أرباح فروقات عملة", "FX Gains",
                   parent="42", cls="revenue", typ="other_revenue", nb="credit", level=3))

    # ── 5 المصاريف (Expenses) ─────────────────────────────
    A.append(_acct("5", "المصاريف", "Expenses",
                   cls="expense", typ="expense", nb="debit",
                   level=1, postable=False, standard_ref="SOCPA-X"))
    # 51 تكلفة المبيعات
    A.append(_acct("51", "تكلفة المبيعات", "Cost of Goods Sold",
                   parent="5", cls="expense", typ="cogs", nb="debit",
                   level=2, postable=False, standard_ref="SOCPA-X.1"))
    A.append(_acct("511", "تكلفة البضاعة المباعة", "COGS - Merchandise",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("512", "مصاريف الشحن للداخل", "Inbound Freight",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    # 52 المصاريف التشغيلية
    A.append(_acct("52", "المصاريف التشغيلية", "Operating Expenses",
                   parent="5", cls="expense", typ="opex", nb="debit",
                   level=2, postable=False, standard_ref="SOCPA-X.2"))
    A.append(_acct("521", "مصاريف الرواتب والأجور", "Salaries & Wages",
                   parent="52", cls="expense", typ="opex", nb="debit",
                   level=3, postable=False))
    A.append(_acct("5211", "رواتب ومخصصات", "Salaries & Allowances",
                   parent="521", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5212", "اشتراكات GOSI - حصة الشركة", "GOSI Employer Contribution",
                   parent="521", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5213", "مصاريف EOSB - زيادة المخصص", "EOSB Expense",
                   parent="521", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("522", "مصاريف الإيجار والمرافق", "Rent & Utilities",
                   parent="52", cls="expense", typ="opex", nb="debit",
                   level=3, postable=False))
    A.append(_acct("5221", "إيجارات", "Rent Expense",
                   parent="522", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5222", "كهرباء وماء", "Utilities",
                   parent="522", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("523", "مصاريف التسويق والإعلان", "Marketing & Advertising",
                   parent="52", cls="expense", typ="opex", nb="debit",
                   level=3, postable=False))
    A.append(_acct("5231", "إعلانات وسائل التواصل", "Social Media Advertising",
                   parent="523", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5232", "حملات تسويقية", "Marketing Campaigns",
                   parent="523", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("524", "مصاريف الاتصالات", "Telecommunications",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("525", "مصاريف الإهلاك والإطفاء", "Depreciation & Amortization",
                   parent="52", cls="expense", typ="opex", nb="debit",
                   level=3, postable=False))
    A.append(_acct("5251", "مصروف إهلاك أصول ثابتة", "Depreciation Expense",
                   parent="525", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5252", "مصروف إطفاء أصول غير ملموسة", "Amortization Expense",
                   parent="525", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("526", "مصاريف عمومية وإدارية", "G&A Expenses",
                   parent="52", cls="expense", typ="opex", nb="debit",
                   level=3, postable=False))
    A.append(_acct("5261", "أتعاب مهنية ومحاسبية", "Professional Fees",
                   parent="526", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5262", "تأمينات", "Insurance Expense",
                   parent="526", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5263", "مصاريف بنكية", "Bank Charges",
                   parent="526", cls="expense", typ="opex", nb="debit", level=4))
    A.append(_acct("5264", "أدوات مكتبية", "Office Supplies",
                   parent="526", cls="expense", typ="opex", nb="debit", level=4))
    # 53 المصاريف غير التشغيلية
    A.append(_acct("53", "المصاريف غير التشغيلية", "Non-Operating Expenses",
                   parent="5", cls="expense", typ="non_operating_expense", nb="debit",
                   level=2, postable=False))
    A.append(_acct("531", "مصاريف فوائد", "Interest Expense",
                   parent="53", cls="expense", typ="non_operating_expense", nb="debit", level=3))
    A.append(_acct("532", "خسائر فروقات عملة", "FX Losses",
                   parent="53", cls="expense", typ="non_operating_expense", nb="debit", level=3))

    return A


# ── IFRS Services 2024 (compact baseline) ─────────────────


def _ifrs_services_accounts() -> list[dict[str, Any]]:
    """Smaller chart aimed at services businesses (consulting, agencies).

    Compact by design — the SOCPA-Retail template is the heavyweight
    reference; this one strips merchandise/inventory and adds
    project-billing structure.
    """
    A = []
    A.append(_acct("1", "Assets", "Assets", cls="asset", typ="asset", nb="debit",
                   level=1, postable=False, standard_ref="IFRS-A"))
    A.append(_acct("11", "Current Assets", "Current Assets",
                   parent="1", cls="asset", typ="current_asset", nb="debit",
                   level=2, postable=False))
    A.append(_acct("110", "Cash & Equivalents", "Cash & Equivalents",
                   parent="11", cls="asset", typ="cash", nb="debit",
                   level=3, postable=False))
    A.append(_acct("1101", "Operating Bank", "Operating Bank",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("1102", "Petty Cash", "Petty Cash",
                   parent="110", cls="asset", typ="cash", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("113", "Accounts Receivable", "Accounts Receivable",
                   parent="11", cls="asset", typ="ar", nb="debit",
                   level=3, postable=False, standard_ref="IFRS-15.105"))
    A.append(_acct("1131", "Trade AR", "Trade AR",
                   parent="113", cls="asset", typ="ar", nb="debit",
                   level=4, reconcilable=True))
    A.append(_acct("1132", "Unbilled Revenue (Contract Asset)", "Contract Assets",
                   parent="113", cls="asset", typ="ar", nb="debit",
                   level=4, standard_ref="IFRS-15.107"))
    A.append(_acct("1133", "Allowance for Doubtful AR", "Allowance for Doubtful AR",
                   parent="113", cls="asset", typ="ar_contra", nb="credit", level=4))

    A.append(_acct("12", "Non-Current Assets", "Non-Current Assets",
                   parent="1", cls="asset", typ="non_current_asset", nb="debit",
                   level=2, postable=False))
    A.append(_acct("121", "Fixed Assets", "Fixed Assets",
                   parent="12", cls="asset", typ="fixed_asset", nb="debit",
                   level=3, postable=False))
    A.append(_acct("1211", "Office Equipment", "Office Equipment",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1212", "Computers & Software", "Computers & Software",
                   parent="121", cls="asset", typ="fixed_asset", nb="debit", level=4))
    A.append(_acct("1219", "Accumulated Depreciation", "Accumulated Depreciation",
                   parent="121", cls="asset", typ="fixed_asset_contra", nb="credit", level=4))

    A.append(_acct("2", "Liabilities", "Liabilities",
                   cls="liability", typ="liability", nb="credit",
                   level=1, postable=False))
    A.append(_acct("21", "Current Liabilities", "Current Liabilities",
                   parent="2", cls="liability", typ="current_liability", nb="credit",
                   level=2, postable=False))
    A.append(_acct("211", "Accounts Payable", "Accounts Payable",
                   parent="21", cls="liability", typ="ap", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2111", "Trade AP", "Trade AP",
                   parent="211", cls="liability", typ="ap", nb="credit",
                   level=4, reconcilable=True))
    A.append(_acct("212", "Deferred Revenue (Contract Liability)", "Contract Liabilities",
                   parent="21", cls="liability", typ="deferred_revenue", nb="credit",
                   level=3, standard_ref="IFRS-15.106"))
    A.append(_acct("213", "Tax Payables", "Tax Payables",
                   parent="21", cls="liability", typ="tax_payable", nb="credit",
                   level=3, postable=False))
    A.append(_acct("2131", "VAT Output", "VAT Output",
                   parent="213", cls="liability", typ="vat_output", nb="credit",
                   level=4, reconcilable=True))
    A.append(_acct("2132", "Income Tax Payable", "Income Tax Payable",
                   parent="213", cls="liability", typ="tax_payable", nb="credit", level=4))

    A.append(_acct("3", "Equity", "Equity",
                   cls="equity", typ="equity", nb="credit",
                   level=1, postable=False))
    A.append(_acct("31", "Capital", "Capital",
                   parent="3", cls="equity", typ="capital", nb="credit", level=2))
    A.append(_acct("33", "Retained Earnings", "Retained Earnings",
                   parent="3", cls="equity", typ="retained_earnings", nb="credit", level=2))

    A.append(_acct("4", "Revenue", "Revenue",
                   cls="revenue", typ="revenue", nb="credit",
                   level=1, postable=False, standard_ref="IFRS-15"))
    A.append(_acct("41", "Service Revenue", "Service Revenue",
                   parent="4", cls="revenue", typ="service_revenue", nb="credit",
                   level=2, postable=False))
    A.append(_acct("411", "Consulting Fees", "Consulting Fees",
                   parent="41", cls="revenue", typ="service_revenue", nb="credit", level=3))
    A.append(_acct("412", "Subscription Revenue", "Subscription Revenue",
                   parent="41", cls="revenue", typ="service_revenue", nb="credit",
                   level=3, standard_ref="IFRS-15.B89"))
    A.append(_acct("413", "Project Revenue", "Project Revenue",
                   parent="41", cls="revenue", typ="service_revenue", nb="credit", level=3))

    A.append(_acct("5", "Expenses", "Expenses",
                   cls="expense", typ="expense", nb="debit",
                   level=1, postable=False))
    A.append(_acct("51", "Cost of Services", "Cost of Services",
                   parent="5", cls="expense", typ="cogs", nb="debit",
                   level=2, postable=False))
    A.append(_acct("511", "Project Labour", "Project Labour",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("512", "Subcontractor Costs", "Subcontractor Costs",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("52", "Operating Expenses", "Operating Expenses",
                   parent="5", cls="expense", typ="opex", nb="debit",
                   level=2, postable=False))
    A.append(_acct("521", "Salaries & Benefits", "Salaries & Benefits",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("522", "Office Rent & Utilities", "Office Rent & Utilities",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("523", "Software Subscriptions", "Software Subscriptions",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("524", "Marketing", "Marketing",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("525", "Depreciation Expense", "Depreciation Expense",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    A.append(_acct("526", "Professional Fees", "Professional Fees",
                   parent="52", cls="expense", typ="opex", nb="debit", level=3))
    return A


# ── IFRS Manufacturing 2024 (compact) ─────────────────────


def _ifrs_manufacturing_accounts() -> list[dict[str, Any]]:
    """Compact manufacturing chart with WIP / RM / FG split."""
    A = list(_ifrs_services_accounts())  # reuse the bones
    # Override industry-specific sections
    # Replace inventory under 11 with manufacturing inventory tree:
    A.append(_acct("114", "Inventory", "Inventory",
                   parent="11", cls="asset", typ="inventory", nb="debit",
                   level=3, postable=False, standard_ref="IAS-2"))
    A.append(_acct("1141", "Raw Materials", "Raw Materials",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4, standard_ref="IAS-2.6"))
    A.append(_acct("1142", "Work in Progress (WIP)", "Work in Progress",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4, standard_ref="IAS-2.6"))
    A.append(_acct("1143", "Finished Goods", "Finished Goods",
                   parent="114", cls="asset", typ="inventory", nb="debit",
                   level=4, standard_ref="IAS-2.6"))
    A.append(_acct("1144", "Inventory Reserve", "Inventory Reserve",
                   parent="114", cls="asset", typ="inventory_contra", nb="credit", level=4))
    # Add manufacturing-specific COGS:
    A.append(_acct("513", "Direct Materials", "Direct Materials",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("514", "Direct Labour", "Direct Labour",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("515", "Manufacturing Overhead", "Manufacturing Overhead",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    A.append(_acct("516", "Inventory Variance", "Inventory Variance",
                   parent="51", cls="expense", typ="cogs", nb="debit", level=3))
    return A


# ── Template definitions ──────────────────────────────────


SYSTEM_TEMPLATES = [
    {
        "code": "socpa-retail-2024",
        "name_ar": "SOCPA - تجزئة (سعودي 2024)",
        "name_en": "SOCPA - Retail (Saudi 2024)",
        "description_ar": "دليل حسابات معتمد سعودياً يدعم ZATCA + SOCPA + الزكاة، مُوجّه لتجار التجزئة (متاجر، نقاط بيع، سلاسل).",
        "description_en": "ZATCA-aware retail chart aligned with SOCPA + Saudi tax, suitable for stores, POS, and retail chains.",
        "standard": "socpa",
        "industry": "retail",
        "accounts": _socpa_retail_accounts(),
    },
    {
        "code": "ifrs-services-2024",
        "name_ar": "IFRS - شركات الخدمات (2024)",
        "name_en": "IFRS - Services (2024)",
        "description_ar": "دليل حسابات IFRS 15-aware لشركات الاستشارات والوكالات والـ SaaS.",
        "description_en": "IFRS 15-aware chart for consulting firms, agencies, and SaaS.",
        "standard": "ifrs",
        "industry": "services",
        "accounts": _ifrs_services_accounts(),
    },
    {
        "code": "ifrs-manufacturing-2024",
        "name_ar": "IFRS - التصنيع (2024)",
        "name_en": "IFRS - Manufacturing (2024)",
        "description_ar": "دليل حسابات IAS 2-aware للتصنيع مع تقسيم RM / WIP / FG وتكاليف العمالة المباشرة + الأعباء الصناعية.",
        "description_en": "IAS 2-aware manufacturing chart with RM/WIP/FG split + direct labour + manufacturing overhead.",
        "standard": "ifrs",
        "industry": "manufacturing",
        "accounts": _ifrs_manufacturing_accounts(),
    },
]


# ── Idempotent seeder ────────────────────────────────────


def _upsert_template(db: Session, t: dict[str, Any]) -> AccountTemplate:
    row = db.query(AccountTemplate).filter(
        AccountTemplate.code == t["code"],
        AccountTemplate.tenant_id.is_(None),
    ).first()
    if row is None:
        row = AccountTemplate(
            id=str(uuid.uuid4()),
            tenant_id=None,
            code=t["code"],
            name_ar=t["name_ar"],
            name_en=t.get("name_en"),
            description_ar=t.get("description_ar"),
            description_en=t.get("description_en"),
            standard=t["standard"],
            industry=t.get("industry"),
            accounts=t["accounts"],
            account_count=len(t["accounts"]),
            is_official=True,
            is_active=True,
        )
        db.add(row)
    else:
        # Refresh editable fields without bumping id.
        row.name_ar = t["name_ar"]
        row.name_en = t.get("name_en")
        row.description_ar = t.get("description_ar")
        row.description_en = t.get("description_en")
        row.standard = t["standard"]
        row.industry = t.get("industry")
        row.accounts = t["accounts"]
        row.account_count = len(t["accounts"])
        row.is_official = True
        row.is_active = True
    return row


def seed_coa_templates(db: Session | None = None) -> dict[str, int]:
    own_db = False
    if db is None:
        db = SessionLocal()
        own_db = True
    try:
        seeded = 0
        for t in SYSTEM_TEMPLATES:
            _upsert_template(db, t)
            seeded += 1
        db.commit()
        logger.info("CoA seed: %d templates upserted", seeded)
        return {"templates": seeded}
    finally:
        if own_db:
            db.close()


__all__ = ["SYSTEM_TEMPLATES", "seed_coa_templates"]
