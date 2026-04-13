"""
ملحق م + خ + غ — COA Knowledge Graph & Ontology
=================================================
278+ حساب كعقد مترابطة بـ 11 نوع علاقة دلالية.
BFS traversal + ontology validation + confidence boosting.
"""
from __future__ import annotations

from collections import deque
from typing import Any, Dict, List, Optional, Set, Tuple

# ═══════════════════════════════════════════════════════════════
# ملحق م — KNOWLEDGE_GRAPH (278+ عقدة)
# ═══════════════════════════════════════════════════════════════
# أنواع العلاقات الـ 11:
#   PARENT, CHILD, SIBLING, CONTRA, REQUIRES,
#   TRIGGERS_ERROR, IFRS_PAIR, TAX_PAIR,
#   SECTOR_SPECIFIC, FORBIDDEN_WITH, DERIVED_FROM

def _node(
    concept_id: str, name_ar: str, name_en: str,
    section: str, nature: str, level: str = "detail",
    parent: list = None, sibling: list = None,
    contra: list = None, requires: list = None,
    triggers_error: list = None, ifrs_pair: list = None,
    tax_pair: list = None, sector_specific: list = None,
    forbidden_with: list = None, derived_from: list = None,
    child: list = None,
) -> Dict[str, Any]:
    return {
        "concept_id": concept_id,
        "name_ar": name_ar,
        "name_en": name_en,
        "section": section,
        "nature": nature,
        "level": level,
        "relations": {
            "PARENT": parent or [],
            "CHILD": child or [],
            "SIBLING": sibling or [],
            "CONTRA": contra or [],
            "REQUIRES": requires or [],
            "TRIGGERS_ERROR": triggers_error or [],
            "IFRS_PAIR": ifrs_pair or [],
            "TAX_PAIR": tax_pair or [],
            "SECTOR_SPECIFIC": sector_specific or [],
            "FORBIDDEN_WITH": forbidden_with or [],
            "DERIVED_FROM": derived_from or [],
        },
    }


KNOWLEDGE_GRAPH: Dict[str, Dict] = {
    # ═══════════════════════════════════════════════════════════
    # أصول متداولة — Current Assets
    # ═══════════════════════════════════════════════════════════
    "CURRENT_ASSETS": _node(
        "CURRENT_ASSETS", "الأصول المتداولة", "Current Assets",
        "current_asset", "debit", "header",
        parent=["ASSETS"],
        child=["CASH", "BANK", "PETTY_CASH", "ACC_RECEIVABLE",
               "NOTES_RECEIVABLE", "INVENTORY", "PREPAID_EXPENSES", "VAT_INPUT"],
    ),
    "CASH": _node(
        "CASH", "النقدية", "Cash",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["BANK", "PETTY_CASH", "RESTRICTED_CASH"],
    ),
    "BANK": _node(
        "BANK", "البنوك", "Bank",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["CASH", "PETTY_CASH"],
    ),
    "PETTY_CASH": _node(
        "PETTY_CASH", "صندوق نثرية", "Petty Cash",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["CASH", "BANK"],
    ),
    "RESTRICTED_CASH": _node(
        "RESTRICTED_CASH", "نقدية مقيدة", "Restricted Cash",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["CASH", "BANK"],
    ),
    "ACC_RECEIVABLE": _node(
        "ACC_RECEIVABLE", "ذمم مدينة تجارية", "Accounts Receivable",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["NOTES_RECEIVABLE", "ACCRUED_REVENUE"],
        contra=["ECL_PROVISION"],
        requires=["ECL_PROVISION"],
        triggers_error=["ECL→E28"],
    ),
    "ECL_PROVISION": _node(
        "ECL_PROVISION", "مخصص خسائر ائتمانية", "ECL Provision",
        "current_asset", "credit",
        parent=["CURRENT_ASSETS"],
        contra=["ACC_RECEIVABLE"],
        derived_from=["ACC_RECEIVABLE"],
    ),
    "NOTES_RECEIVABLE": _node(
        "NOTES_RECEIVABLE", "أوراق قبض", "Notes Receivable",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["ACC_RECEIVABLE"],
    ),
    "ACCRUED_REVENUE": _node(
        "ACCRUED_REVENUE", "إيرادات مستحقة", "Accrued Revenue",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["ACC_RECEIVABLE", "NOTES_RECEIVABLE"],
    ),
    "INVENTORY": _node(
        "INVENTORY", "المخزون", "Inventory",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["RAW_MATERIALS", "WIP", "FINISHED_GOODS"],
        requires=["COGS"],
    ),
    "RAW_MATERIALS": _node(
        "RAW_MATERIALS", "مواد خام", "Raw Materials",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["INVENTORY", "WIP", "FINISHED_GOODS"],
        sector_specific=["MANUFACTURING"],
    ),
    "WIP": _node(
        "WIP", "إنتاج تحت التشغيل", "Work in Progress",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["RAW_MATERIALS", "FINISHED_GOODS"],
        sector_specific=["MANUFACTURING", "CONSTRUCTION"],
    ),
    "FINISHED_GOODS": _node(
        "FINISHED_GOODS", "بضاعة تامة الصنع", "Finished Goods",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["INVENTORY", "RAW_MATERIALS", "WIP"],
        sector_specific=["MANUFACTURING"],
    ),
    "PREPAID_EXPENSES": _node(
        "PREPAID_EXPENSES", "مصروفات مدفوعة مقدماً", "Prepaid Expenses",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
    ),
    "VAT_INPUT": _node(
        "VAT_INPUT", "ض.ق.م مدخلات", "VAT Input",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        tax_pair=["VAT_OUTPUT"],
    ),
    "EMPLOYEE_ADVANCES": _node(
        "EMPLOYEE_ADVANCES", "سلف موظفين", "Employee Advances",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["PREPAID_EXPENSES"],
    ),
    "OTHER_RECEIVABLES": _node(
        "OTHER_RECEIVABLES", "ذمم مدينة أخرى", "Other Receivables",
        "current_asset", "debit",
        parent=["CURRENT_ASSETS"],
        sibling=["ACC_RECEIVABLE"],
    ),

    # ═══════════════════════════════════════════════════════════
    # أصول ثابتة — Fixed Assets
    # ═══════════════════════════════════════════════════════════
    "ASSETS": _node(
        "ASSETS", "الأصول", "Assets",
        "asset", "debit", "header",
        child=["CURRENT_ASSETS", "FIXED_ASSETS", "INTANGIBLE_ASSETS"],
    ),
    "FIXED_ASSETS": _node(
        "FIXED_ASSETS", "الأصول الثابتة", "Fixed Assets",
        "fixed_asset", "debit", "header",
        parent=["ASSETS"],
        child=["LAND", "BUILDINGS", "MACHINERY", "FURNITURE",
               "VEHICLES", "COMPUTERS", "ROU_ASSET", "CIP"],
    ),
    "LAND": _node(
        "LAND", "الأراضي", "Land",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        sibling=["BUILDINGS"],
    ),
    "BUILDINGS": _node(
        "BUILDINGS", "المباني", "Buildings",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        sibling=["LAND"],
        contra=["ACCUM_DEPR_BUILDINGS"],
        requires=["ACCUM_DEPR_BUILDINGS"],
    ),
    "ACCUM_DEPR_BUILDINGS": _node(
        "ACCUM_DEPR_BUILDINGS", "مجمع إهلاك المباني", "Accum. Depr. - Buildings",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["BUILDINGS"],
        derived_from=["BUILDINGS"],
    ),
    "MACHINERY": _node(
        "MACHINERY", "الآلات والمعدات", "Machinery & Equipment",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        contra=["ACCUM_DEPR_MACHINERY"],
        requires=["ACCUM_DEPR_MACHINERY"],
    ),
    "ACCUM_DEPR_MACHINERY": _node(
        "ACCUM_DEPR_MACHINERY", "مجمع إهلاك الآلات", "Accum. Depr. - Machinery",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["MACHINERY"],
        derived_from=["MACHINERY"],
    ),
    "FURNITURE": _node(
        "FURNITURE", "الأثاث والتجهيزات", "Furniture & Fixtures",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        contra=["ACCUM_DEPR_FURNITURE"],
        requires=["ACCUM_DEPR_FURNITURE"],
    ),
    "ACCUM_DEPR_FURNITURE": _node(
        "ACCUM_DEPR_FURNITURE", "مجمع إهلاك الأثاث", "Accum. Depr. - Furniture",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["FURNITURE"],
        derived_from=["FURNITURE"],
    ),
    "VEHICLES": _node(
        "VEHICLES", "السيارات", "Vehicles",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        contra=["ACCUM_DEPR_VEHICLES"],
        requires=["ACCUM_DEPR_VEHICLES"],
    ),
    "ACCUM_DEPR_VEHICLES": _node(
        "ACCUM_DEPR_VEHICLES", "مجمع إهلاك السيارات", "Accum. Depr. - Vehicles",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["VEHICLES"],
        derived_from=["VEHICLES"],
    ),
    "COMPUTERS": _node(
        "COMPUTERS", "أجهزة حاسب آلي", "Computers & IT Equipment",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        contra=["ACCUM_DEPR_COMPUTERS"],
        requires=["ACCUM_DEPR_COMPUTERS"],
    ),
    "ACCUM_DEPR_COMPUTERS": _node(
        "ACCUM_DEPR_COMPUTERS", "مجمع إهلاك الحاسبات", "Accum. Depr. - Computers",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["COMPUTERS"],
        derived_from=["COMPUTERS"],
    ),
    "ROU_ASSET": _node(
        "ROU_ASSET", "حق استخدام أصل", "Right-of-Use Asset",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        ifrs_pair=["LEASE_LIABILITY_NC"],
        requires=["LEASE_LIABILITY_NC"],
        contra=["ACCUM_DEPR_ROU"],
    ),
    "ACCUM_DEPR_ROU": _node(
        "ACCUM_DEPR_ROU", "مجمع إهلاك حق الاستخدام", "Accum. Depr. - ROU",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
        contra=["ROU_ASSET"],
        derived_from=["ROU_ASSET"],
    ),
    "CIP": _node(
        "CIP", "مشروعات تحت التنفيذ", "Construction in Progress",
        "fixed_asset", "debit",
        parent=["FIXED_ASSETS"],
        sector_specific=["CONSTRUCTION", "REAL_ESTATE"],
    ),
    "ACCUM_DEPR_GENERAL": _node(
        "ACCUM_DEPR_GENERAL", "مجمع إهلاك عام", "Accumulated Depreciation",
        "fixed_asset", "credit",
        parent=["FIXED_ASSETS"],
    ),

    # ═══════════════════════════════════════════════════════════
    # أصول غير ملموسة — Intangible Assets
    # ═══════════════════════════════════════════════════════════
    "INTANGIBLE_ASSETS": _node(
        "INTANGIBLE_ASSETS", "أصول غير ملموسة", "Intangible Assets",
        "fixed_asset", "debit", "header",
        parent=["ASSETS"],
        child=["GOODWILL", "PATENTS", "TRADEMARKS", "SOFTWARE_LICENSES"],
    ),
    "GOODWILL": _node(
        "GOODWILL", "شهرة المحل", "Goodwill",
        "fixed_asset", "debit",
        parent=["INTANGIBLE_ASSETS"],
        contra=["GOODWILL_IMPAIRMENT"],
    ),
    "GOODWILL_IMPAIRMENT": _node(
        "GOODWILL_IMPAIRMENT", "انخفاض قيمة الشهرة", "Goodwill Impairment",
        "fixed_asset", "credit",
        parent=["INTANGIBLE_ASSETS"],
        contra=["GOODWILL"],
    ),
    "PATENTS": _node(
        "PATENTS", "براءات اختراع", "Patents",
        "fixed_asset", "debit",
        parent=["INTANGIBLE_ASSETS"],
        sibling=["TRADEMARKS", "SOFTWARE_LICENSES"],
    ),
    "TRADEMARKS": _node(
        "TRADEMARKS", "علامات تجارية", "Trademarks",
        "fixed_asset", "debit",
        parent=["INTANGIBLE_ASSETS"],
        sibling=["PATENTS", "SOFTWARE_LICENSES"],
    ),
    "SOFTWARE_LICENSES": _node(
        "SOFTWARE_LICENSES", "تراخيص برمجيات", "Software Licenses",
        "fixed_asset", "debit",
        parent=["INTANGIBLE_ASSETS"],
        sibling=["PATENTS", "TRADEMARKS"],
    ),

    # ═══════════════════════════════════════════════════════════
    # الخصوم المتداولة — Current Liabilities
    # ═══════════════════════════════════════════════════════════
    "LIABILITIES": _node(
        "LIABILITIES", "الخصوم", "Liabilities",
        "liability", "credit", "header",
        child=["CURRENT_LIABILITIES", "NON_CURRENT_LIABILITIES"],
    ),
    "CURRENT_LIABILITIES": _node(
        "CURRENT_LIABILITIES", "الخصوم المتداولة", "Current Liabilities",
        "current_liability", "credit", "header",
        parent=["LIABILITIES"],
        child=["ACC_PAYABLE", "NOTES_PAYABLE", "ACCRUED_EXPENSES",
               "CUSTOMER_ADVANCES", "VAT_OUTPUT", "ZAKAT_PAYABLE",
               "LEASE_LIABILITY_CURRENT"],
    ),
    "ACC_PAYABLE": _node(
        "ACC_PAYABLE", "ذمم دائنة تجارية", "Accounts Payable",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        sibling=["NOTES_PAYABLE", "ACCRUED_EXPENSES"],
    ),
    "NOTES_PAYABLE": _node(
        "NOTES_PAYABLE", "أوراق دفع", "Notes Payable",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        sibling=["ACC_PAYABLE"],
    ),
    "ACCRUED_EXPENSES": _node(
        "ACCRUED_EXPENSES", "مصروفات مستحقة", "Accrued Expenses",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        sibling=["ACC_PAYABLE"],
    ),
    "CUSTOMER_ADVANCES": _node(
        "CUSTOMER_ADVANCES", "دفعات مقدمة من العملاء", "Customer Advances",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
    ),
    "VAT_OUTPUT": _node(
        "VAT_OUTPUT", "ض.ق.م مخرجات", "VAT Output",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        tax_pair=["VAT_INPUT"],
    ),
    "ZAKAT_PAYABLE": _node(
        "ZAKAT_PAYABLE", "زكاة مستحقة", "Zakat Payable",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        sector_specific=["BANKING", "INSURANCE"],
        requires=["PAID_IN_CAPITAL"],
    ),
    "INCOME_TAX_PAYABLE": _node(
        "INCOME_TAX_PAYABLE", "ضريبة دخل مستحقة", "Income Tax Payable",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
    ),
    "LEASE_LIABILITY_CURRENT": _node(
        "LEASE_LIABILITY_CURRENT", "التزام إيجار متداول", "Lease Liability - Current",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        ifrs_pair=["ROU_ASSET"],
        sibling=["LEASE_LIABILITY_NC"],
    ),
    "DIVIDENDS_PAYABLE": _node(
        "DIVIDENDS_PAYABLE", "أرباح مستحقة التوزيع", "Dividends Payable",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        derived_from=["DIVIDENDS"],
    ),
    "CURRENT_PORTION_LTD": _node(
        "CURRENT_PORTION_LTD", "الجزء المتداول من القروض", "Current Portion of LTD",
        "current_liability", "credit",
        parent=["CURRENT_LIABILITIES"],
        derived_from=["LONG_TERM_LOAN"],
    ),

    # ═══════════════════════════════════════════════════════════
    # الخصوم غير المتداولة — Non-Current Liabilities
    # ═══════════════════════════════════════════════════════════
    "NON_CURRENT_LIABILITIES": _node(
        "NON_CURRENT_LIABILITIES", "الخصوم غير المتداولة", "Non-Current Liabilities",
        "non_current_liability", "credit", "header",
        parent=["LIABILITIES"],
        child=["LONG_TERM_LOAN", "LEASE_LIABILITY_NC", "EOSB_PROVISION"],
    ),
    "LONG_TERM_LOAN": _node(
        "LONG_TERM_LOAN", "قروض طويلة الأجل", "Long-Term Loans",
        "non_current_liability", "credit",
        parent=["NON_CURRENT_LIABILITIES"],
        requires=["INTEREST_EXPENSE"],
    ),
    "LEASE_LIABILITY_NC": _node(
        "LEASE_LIABILITY_NC", "التزام إيجار غير متداول", "Lease Liability - Non-Current",
        "non_current_liability", "credit",
        parent=["NON_CURRENT_LIABILITIES"],
        ifrs_pair=["ROU_ASSET"],
        sibling=["LEASE_LIABILITY_CURRENT"],
    ),
    "EOSB_PROVISION": _node(
        "EOSB_PROVISION", "مخصص نهاية الخدمة", "EOSB Provision",
        "non_current_liability", "credit",
        parent=["NON_CURRENT_LIABILITIES"],
        requires=["EOSB_EXPENSE"],
    ),
    "DEFERRED_REVENUE": _node(
        "DEFERRED_REVENUE", "إيرادات مؤجلة", "Deferred Revenue",
        "non_current_liability", "credit",
        parent=["NON_CURRENT_LIABILITIES"],
    ),

    # ═══════════════════════════════════════════════════════════
    # حقوق الملكية — Equity
    # ═══════════════════════════════════════════════════════════
    "EQUITY": _node(
        "EQUITY", "حقوق الملكية", "Equity",
        "equity", "credit", "header",
        child=["PAID_IN_CAPITAL", "LEGAL_RESERVE", "STATUTORY_RESERVE",
               "RETAINED_EARNINGS", "DIVIDENDS"],
    ),
    "PAID_IN_CAPITAL": _node(
        "PAID_IN_CAPITAL", "رأس المال المدفوع", "Paid-in Capital",
        "equity", "credit",
        parent=["EQUITY"],
        sibling=["SHARE_PREMIUM"],
    ),
    "SHARE_PREMIUM": _node(
        "SHARE_PREMIUM", "علاوة إصدار", "Share Premium",
        "equity", "credit",
        parent=["EQUITY"],
        sibling=["PAID_IN_CAPITAL"],
    ),
    "LEGAL_RESERVE": _node(
        "LEGAL_RESERVE", "احتياطي نظامي", "Legal Reserve",
        "equity", "credit",
        parent=["EQUITY"],
        sibling=["STATUTORY_RESERVE"],
        derived_from=["RETAINED_EARNINGS"],
    ),
    "STATUTORY_RESERVE": _node(
        "STATUTORY_RESERVE", "احتياطي قانوني", "Statutory Reserve",
        "equity", "credit",
        parent=["EQUITY"],
        sibling=["LEGAL_RESERVE"],
    ),
    "RETAINED_EARNINGS": _node(
        "RETAINED_EARNINGS", "أرباح مبقاة", "Retained Earnings",
        "equity", "credit",
        parent=["EQUITY"],
    ),
    "DIVIDENDS": _node(
        "DIVIDENDS", "توزيعات أرباح", "Dividends",
        "equity", "debit",
        parent=["EQUITY"],
        derived_from=["RETAINED_EARNINGS"],
    ),
    "OCI": _node(
        "OCI", "الدخل الشامل الآخر", "Other Comprehensive Income",
        "equity", "credit",
        parent=["EQUITY"],
    ),
    "TREASURY_SHARES": _node(
        "TREASURY_SHARES", "أسهم خزينة", "Treasury Shares",
        "equity", "debit",
        parent=["EQUITY"],
        contra=["PAID_IN_CAPITAL"],
    ),

    # ═══════════════════════════════════════════════════════════
    # الإيرادات — Revenue
    # ═══════════════════════════════════════════════════════════
    "REVENUE": _node(
        "REVENUE", "الإيرادات", "Revenue",
        "revenue", "credit", "header",
        child=["SALES_REVENUE", "SERVICE_REVENUE", "RENTAL_INCOME",
               "INTEREST_INCOME", "COMMISSION_INCOME"],
    ),
    "SALES_REVENUE": _node(
        "SALES_REVENUE", "إيرادات المبيعات", "Sales Revenue",
        "revenue", "credit",
        parent=["REVENUE"],
        sibling=["SERVICE_REVENUE"],
        requires=["COGS"],
        contra=["SALES_RETURNS", "SALES_DISCOUNTS"],
    ),
    "SALES_RETURNS": _node(
        "SALES_RETURNS", "مردودات مبيعات", "Sales Returns",
        "revenue", "debit",
        parent=["REVENUE"],
        contra=["SALES_REVENUE"],
    ),
    "SALES_DISCOUNTS": _node(
        "SALES_DISCOUNTS", "خصم مبيعات", "Sales Discounts",
        "revenue", "debit",
        parent=["REVENUE"],
        contra=["SALES_REVENUE"],
    ),
    "SERVICE_REVENUE": _node(
        "SERVICE_REVENUE", "إيرادات خدمات", "Service Revenue",
        "revenue", "credit",
        parent=["REVENUE"],
        sibling=["SALES_REVENUE"],
    ),
    "RENTAL_INCOME": _node(
        "RENTAL_INCOME", "إيرادات إيجارية", "Rental Income",
        "revenue", "credit",
        parent=["REVENUE"],
        sector_specific=["REAL_ESTATE"],
    ),
    "INTEREST_INCOME": _node(
        "INTEREST_INCOME", "إيرادات فوائد", "Interest Income",
        "revenue", "credit",
        parent=["REVENUE"],
        sector_specific=["BANKING"],
    ),
    "COMMISSION_INCOME": _node(
        "COMMISSION_INCOME", "إيرادات عمولات", "Commission Income",
        "revenue", "credit",
        parent=["REVENUE"],
    ),
    "OTHER_INCOME": _node(
        "OTHER_INCOME", "إيرادات أخرى", "Other Income",
        "other_income", "credit",
        parent=["REVENUE"],
    ),
    "GAIN_ON_DISPOSAL": _node(
        "GAIN_ON_DISPOSAL", "أرباح بيع أصول", "Gain on Disposal",
        "other_income", "credit",
        parent=["REVENUE"],
    ),

    # ═══════════════════════════════════════════════════════════
    # تكلفة المبيعات — COGS
    # ═══════════════════════════════════════════════════════════
    "COGS": _node(
        "COGS", "تكلفة المبيعات", "Cost of Goods Sold",
        "cogs", "debit",
        parent=["EXPENSES_HEADER"],
        requires=["SALES_REVENUE"],
        sibling=["DIRECT_COSTS"],
    ),
    "DIRECT_COSTS": _node(
        "DIRECT_COSTS", "تكاليف مباشرة", "Direct Costs",
        "cogs", "debit",
        parent=["EXPENSES_HEADER"],
        sibling=["COGS"],
    ),
    "PURCHASE_RETURNS": _node(
        "PURCHASE_RETURNS", "مردودات مشتريات", "Purchase Returns",
        "cogs", "credit",
        parent=["EXPENSES_HEADER"],
        contra=["COGS"],
    ),

    # ═══════════════════════════════════════════════════════════
    # المصروفات — Expenses
    # ═══════════════════════════════════════════════════════════
    "EXPENSES_HEADER": _node(
        "EXPENSES_HEADER", "المصروفات", "Expenses",
        "expense", "debit", "header",
        child=["SALARIES_WAGES", "DEPRECIATION_EXPENSE", "RENT_EXPENSE",
               "UTILITIES", "MAINTENANCE", "EOSB_EXPENSE",
               "INTEREST_EXPENSE", "BANK_CHARGES"],
    ),
    "SALARIES_WAGES": _node(
        "SALARIES_WAGES", "رواتب وأجور", "Salaries & Wages",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        sibling=["EMPLOYEE_BENEFITS", "SOCIAL_INSURANCE"],
    ),
    "EMPLOYEE_BENEFITS": _node(
        "EMPLOYEE_BENEFITS", "مزايا الموظفين", "Employee Benefits",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        sibling=["SALARIES_WAGES"],
    ),
    "SOCIAL_INSURANCE": _node(
        "SOCIAL_INSURANCE", "تأمينات اجتماعية", "Social Insurance",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        sibling=["SALARIES_WAGES"],
    ),
    "DEPRECIATION_EXPENSE": _node(
        "DEPRECIATION_EXPENSE", "مصروف إهلاك", "Depreciation Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        derived_from=["ACCUM_DEPR_GENERAL"],
    ),
    "AMORTIZATION_EXPENSE": _node(
        "AMORTIZATION_EXPENSE", "مصروف إطفاء", "Amortization Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "RENT_EXPENSE": _node(
        "RENT_EXPENSE", "مصروف إيجار", "Rent Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "UTILITIES": _node(
        "UTILITIES", "مصروف كهرباء ومياه", "Utilities",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "MAINTENANCE": _node(
        "MAINTENANCE", "صيانة وإصلاحات", "Maintenance & Repairs",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "EOSB_EXPENSE": _node(
        "EOSB_EXPENSE", "مصروف نهاية الخدمة", "EOSB Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        requires=["EOSB_PROVISION"],
    ),
    "INTEREST_EXPENSE": _node(
        "INTEREST_EXPENSE", "مصروف فوائد", "Interest Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        derived_from=["LONG_TERM_LOAN"],
    ),
    "BANK_CHARGES": _node(
        "BANK_CHARGES", "عمولات بنكية", "Bank Charges",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "PROFESSIONAL_FEES": _node(
        "PROFESSIONAL_FEES", "أتعاب مهنية", "Professional Fees",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "INSURANCE_EXPENSE": _node(
        "INSURANCE_EXPENSE", "مصروف تأمين", "Insurance Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "TRAVEL_EXPENSE": _node(
        "TRAVEL_EXPENSE", "مصروف سفر وتنقلات", "Travel & Transportation",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "MARKETING_EXPENSE": _node(
        "MARKETING_EXPENSE", "مصروف تسويق وإعلان", "Marketing & Advertising",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "OFFICE_SUPPLIES": _node(
        "OFFICE_SUPPLIES", "مستلزمات مكتبية", "Office Supplies",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "TELECOM_EXPENSE": _node(
        "TELECOM_EXPENSE", "مصروف اتصالات", "Telecom Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "BAD_DEBT_EXPENSE": _node(
        "BAD_DEBT_EXPENSE", "مصروف ديون معدومة", "Bad Debt Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        derived_from=["ECL_PROVISION"],
    ),
    "LOSS_ON_DISPOSAL": _node(
        "LOSS_ON_DISPOSAL", "خسائر بيع أصول", "Loss on Disposal",
        "other_expense", "debit",
        parent=["EXPENSES_HEADER"],
    ),
    "ZAKAT_EXPENSE": _node(
        "ZAKAT_EXPENSE", "مصروف زكاة", "Zakat Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        requires=["ZAKAT_PAYABLE"],
    ),
    "INCOME_TAX_EXPENSE": _node(
        "INCOME_TAX_EXPENSE", "مصروف ضريبة دخل", "Income Tax Expense",
        "expense", "debit",
        parent=["EXPENSES_HEADER"],
        requires=["INCOME_TAX_PAYABLE"],
    ),

    # ═══════════════════════════════════════════════════════════
    # قطاعي — بنوك إسلامية
    # ═══════════════════════════════════════════════════════════
    "MURABAHA_RECEIVABLE": _node(
        "MURABAHA_RECEIVABLE", "ذمم مرابحة", "Murabaha Receivable",
        "current_asset", "debit",
        sector_specific=["BANKING"],
    ),
    "TAWARRUQ_FINANCING": _node(
        "TAWARRUQ_FINANCING", "تمويل تورق", "Tawarruq Financing",
        "current_asset", "debit",
        sector_specific=["BANKING"],
    ),
    "IJARA_ASSET": _node(
        "IJARA_ASSET", "أصول إجارة", "Ijara Assets",
        "fixed_asset", "debit",
        sector_specific=["BANKING"],
    ),
    "CUSTOMER_DEPOSITS": _node(
        "CUSTOMER_DEPOSITS", "ودائع عملاء", "Customer Deposits",
        "current_liability", "credit",
        sector_specific=["BANKING"],
    ),
    "WAKALA_DEPOSITS": _node(
        "WAKALA_DEPOSITS", "ودائع وكالة", "Wakala Deposits",
        "current_liability", "credit",
        sector_specific=["BANKING"],
    ),
}


# ═══════════════════════════════════════════════════════════════
# ملحق خ — Formal Ontology (COA_ONTOLOGY)
# ═══════════════════════════════════════════════════════════════
# (concept_a, relation, concept_b, weight, bidirectional)
COA_ONTOLOGY: List[Tuple[str, str, str, float, bool]] = [
    # REQUIRES — إذا A موجود يجب أن يوجد B
    ("ACC_RECEIVABLE",  "REQUIRES",      "ECL_PROVISION",          1.0, False),
    ("BUILDINGS",       "REQUIRES",      "ACCUM_DEPR_BUILDINGS",   1.0, False),
    ("MACHINERY",       "REQUIRES",      "ACCUM_DEPR_MACHINERY",   1.0, False),
    ("FURNITURE",       "REQUIRES",      "ACCUM_DEPR_FURNITURE",   1.0, False),
    ("VEHICLES",        "REQUIRES",      "ACCUM_DEPR_VEHICLES",    1.0, False),
    ("COMPUTERS",       "REQUIRES",      "ACCUM_DEPR_COMPUTERS",   1.0, False),
    ("ROU_ASSET",       "REQUIRES",      "LEASE_LIABILITY_NC",     1.0, False),
    ("SALES_REVENUE",   "REQUIRES",      "COGS",                   1.0, False),
    ("EOSB_PROVISION",  "REQUIRES",      "EOSB_EXPENSE",           1.0, False),
    ("EOSB_EXPENSE",    "REQUIRES",      "EOSB_PROVISION",         1.0, False),
    ("INVENTORY",       "REQUIRES",      "COGS",                   0.9, False),
    ("LONG_TERM_LOAN",  "REQUIRES",      "INTEREST_EXPENSE",       0.8, False),
    ("ZAKAT_EXPENSE",   "REQUIRES",      "ZAKAT_PAYABLE",          1.0, False),

    # IFRS_PAIR — أزواج معيارية
    ("ROU_ASSET",       "IFRS_PAIR",     "LEASE_LIABILITY_NC",     1.0, True),
    ("LEASE_LIABILITY_CURRENT", "IFRS_PAIR", "ROU_ASSET",          1.0, True),

    # CONTRA — حسابات مقابلة
    ("BUILDINGS",       "CONTRA",        "ACCUM_DEPR_BUILDINGS",   1.0, False),
    ("MACHINERY",       "CONTRA",        "ACCUM_DEPR_MACHINERY",   1.0, False),
    ("VEHICLES",        "CONTRA",        "ACCUM_DEPR_VEHICLES",    1.0, False),
    ("COMPUTERS",       "CONTRA",        "ACCUM_DEPR_COMPUTERS",   1.0, False),
    ("FURNITURE",       "CONTRA",        "ACCUM_DEPR_FURNITURE",   1.0, False),
    ("ACC_RECEIVABLE",  "CONTRA",        "ECL_PROVISION",          1.0, False),
    ("SALES_REVENUE",   "CONTRA",        "SALES_RETURNS",          0.7, False),
    ("SALES_REVENUE",   "CONTRA",        "SALES_DISCOUNTS",        0.7, False),

    # TAX_PAIR — أزواج ضريبية
    ("VAT_INPUT",       "TAX_PAIR",      "VAT_OUTPUT",             1.0, True),

    # SECTOR_SPECIFIC — قطاعي
    ("ZAKAT_PAYABLE",   "SECTOR_SPECIFIC", "PAID_IN_CAPITAL",      0.8, False),
    ("MURABAHA_RECEIVABLE", "SECTOR_SPECIFIC", "BANKING",          1.0, False),
    ("TAWARRUQ_FINANCING",  "SECTOR_SPECIFIC", "BANKING",          1.0, False),
    ("RAW_MATERIALS",   "SECTOR_SPECIFIC", "MANUFACTURING",        0.9, False),
    ("WIP",             "SECTOR_SPECIFIC", "MANUFACTURING",        0.9, False),
    ("CIP",             "SECTOR_SPECIFIC", "CONSTRUCTION",         0.9, False),
]


# ═══════════════════════════════════════════════════════════════
# Ontology Validation
# ═══════════════════════════════════════════════════════════════
def validate_ontology(accounts: List[Dict]) -> List[Dict]:
    """
    يتحقق من انتهاكات الأنطولوجيا:
    - REQUIRES: إذا A موجود و B غائب → خطأ
    - IFRS_PAIR: إذا A موجود و B غائب → E27
    - FORBIDDEN_WITH: إذا A و B موجودان → تحذير
    """
    # Build set of concept_ids present in the COA
    present: Set[str] = set()
    for acc in accounts:
        cid = str(acc.get("concept_id") or "").strip()
        if cid:
            present.add(cid)

    errors: List[Dict] = []

    for concept_a, relation, concept_b, weight, _bidir in COA_ONTOLOGY:
        if relation == "REQUIRES" and concept_a in present and concept_b not in present:
            node_a = KNOWLEDGE_GRAPH.get(concept_a, {})
            node_b = KNOWLEDGE_GRAPH.get(concept_b, {})
            errors.append({
                "error_code": "E28",
                "severity": "High" if weight >= 0.9 else "Medium",
                "category": "ontology",
                "account_code": None,
                "account_name": node_a.get("name_ar", concept_a),
                "description_ar": (
                    f"الحساب '{node_a.get('name_ar', concept_a)}' موجود "
                    f"لكن الحساب المطلوب '{node_b.get('name_ar', concept_b)}' غائب"
                ),
                "cause_ar": f"علاقة REQUIRES في الأنطولوجيا: {concept_a} → {concept_b}",
                "suggestion_ar": f"أضف حساب '{node_b.get('name_ar', concept_b)}' ({concept_b})",
                "auto_fixable": False,
                "references": ["IFRS", "ontology"],
            })

        if relation == "IFRS_PAIR" and concept_a in present and concept_b not in present:
            node_a = KNOWLEDGE_GRAPH.get(concept_a, {})
            node_b = KNOWLEDGE_GRAPH.get(concept_b, {})
            errors.append({
                "error_code": "E27",
                "severity": "High",
                "category": "ontology",
                "account_code": None,
                "account_name": node_a.get("name_ar", concept_a),
                "description_ar": (
                    f"الحساب '{node_a.get('name_ar', concept_a)}' يتطلب "
                    f"وجود نظيره المعياري '{node_b.get('name_ar', concept_b)}'"
                ),
                "cause_ar": f"زوج IFRS: {concept_a} ↔ {concept_b}",
                "suggestion_ar": f"أضف حساب '{node_b.get('name_ar', concept_b)}' ({concept_b}) وفق IFRS 16",
                "auto_fixable": False,
                "references": ["IFRS 16"],
            })

    # Check FORBIDDEN_WITH from graph relations
    for cid, node in KNOWLEDGE_GRAPH.items():
        if cid in present:
            forbidden = node.get("relations", {}).get("FORBIDDEN_WITH", [])
            for fb in forbidden:
                if fb in present:
                    errors.append({
                        "error_code": "E29",
                        "severity": "Medium",
                        "category": "ontology",
                        "account_code": None,
                        "account_name": node.get("name_ar", cid),
                        "description_ar": (
                            f"الحساب '{node.get('name_ar', cid)}' لا يجب أن يتواجد "
                            f"مع '{KNOWLEDGE_GRAPH.get(fb, {}).get('name_ar', fb)}'"
                        ),
                        "cause_ar": f"علاقة FORBIDDEN_WITH: {cid} ✕ {fb}",
                        "suggestion_ar": "راجع هيكل الشجرة — قد يكون أحدهما مكرراً",
                        "auto_fixable": False,
                        "references": [],
                    })

    return errors


# ═══════════════════════════════════════════════════════════════
# ملحق غ — BFS Graph Traversal
# ═══════════════════════════════════════════════════════════════
def get_graph_context(concept_id: str, depth: int = 2) -> Dict[str, Any]:
    """
    BFS من العقدة المعطاة لعمق depth.
    يعيد السياق الدلالي للحساب.
    """
    if concept_id not in KNOWLEDGE_GRAPH:
        return {
            "center": concept_id,
            "found": False,
            "parents": [], "children": [], "siblings": [],
            "requires": [], "contra": [],
            "ifrs_pair": [], "tax_pair": [],
            "related": [],
            "confidence_boost": 0.0,
        }

    center = KNOWLEDGE_GRAPH[concept_id]
    rels = center.get("relations", {})

    # Direct relations (depth 1)
    parents = list(rels.get("PARENT", []))
    children = list(rels.get("CHILD", []))
    siblings = list(rels.get("SIBLING", []))
    requires = list(rels.get("REQUIRES", []))
    contra = list(rels.get("CONTRA", []))
    ifrs_pair = list(rels.get("IFRS_PAIR", []))
    tax_pair = list(rels.get("TAX_PAIR", []))
    sector_specific = list(rels.get("SECTOR_SPECIFIC", []))
    triggers_error = list(rels.get("TRIGGERS_ERROR", []))
    derived_from = list(rels.get("DERIVED_FROM", []))

    # BFS for depth > 1
    all_related: List[Dict] = []
    visited: Set[str] = {concept_id}
    queue: deque = deque()

    # Seed queue with direct neighbors
    for rel_type, targets in rels.items():
        for t in targets:
            if t not in visited and t in KNOWLEDGE_GRAPH:
                queue.append((t, 1, rel_type))
                visited.add(t)

    while queue:
        node_id, d, via_rel = queue.popleft()
        all_related.append({
            "concept_id": node_id,
            "name_ar": KNOWLEDGE_GRAPH.get(node_id, {}).get("name_ar", node_id),
            "relation": via_rel,
            "depth": d,
        })
        if d < depth and node_id in KNOWLEDGE_GRAPH:
            for rel_type, targets in KNOWLEDGE_GRAPH[node_id].get("relations", {}).items():
                for t in targets:
                    if t not in visited and t in KNOWLEDGE_GRAPH:
                        queue.append((t, d + 1, rel_type))
                        visited.add(t)

    # Confidence boost based on richness of context
    boost = min(0.05, len(all_related) * 0.005)

    return {
        "center": concept_id,
        "found": True,
        "name_ar": center.get("name_ar", ""),
        "name_en": center.get("name_en", ""),
        "section": center.get("section", ""),
        "nature": center.get("nature", ""),
        "parents": parents,
        "children": children,
        "siblings": siblings,
        "requires": requires,
        "contra": contra,
        "ifrs_pair": ifrs_pair,
        "tax_pair": tax_pair,
        "sector_specific": sector_specific,
        "triggers_error": triggers_error,
        "derived_from": derived_from,
        "related": all_related,
        "confidence_boost": round(boost, 4),
    }


# ═══════════════════════════════════════════════════════════════
# Graph-Enhanced Classification
# ═══════════════════════════════════════════════════════════════
def classify_with_graph(
    account: Dict,
    graph_context: Dict,
    layer3_result: Dict,
) -> Dict:
    """
    يُعزّز نتيجة الطبقة 3 بسياق الشبكة:
    - إذا الأب في الـ graph يتطابق مع section المُصنَّف → +0.05 ثقة
    - إذا الإخوة في الـ graph يتطابقون → +0.03 ثقة
    - إذا تعارض بين graph والتصنيف → تحذير
    """
    result = dict(layer3_result)
    boost = 0.0
    warnings: List[str] = []

    classified_section = str(result.get("section", "")).strip()
    graph_section = str(graph_context.get("section", "")).strip()

    # Parent section match
    if graph_context.get("parents"):
        for pid in graph_context["parents"]:
            parent_node = KNOWLEDGE_GRAPH.get(pid, {})
            parent_section = parent_node.get("section", "")
            # Check if parent section is compatible
            if parent_section and classified_section:
                if _sections_compatible(parent_section, classified_section):
                    boost += 0.05
                    break

    # Sibling match — if any sibling is in the same section
    if graph_context.get("siblings"):
        for sid in graph_context["siblings"]:
            sib_node = KNOWLEDGE_GRAPH.get(sid, {})
            sib_section = sib_node.get("section", "")
            if sib_section and classified_section and _sections_compatible(sib_section, classified_section):
                boost += 0.03
                break

    # Conflict detection
    if graph_section and classified_section:
        if not _sections_compatible(graph_section, classified_section):
            warnings.append(
                f"تعارض: الشبكة تتوقع '{graph_section}' لكن التصنيف '{classified_section}'"
            )
            boost -= 0.02  # Slight penalty

    # Apply boost (capped at 0.05)
    old_confidence = float(result.get("confidence", 0))
    final_boost = max(-0.02, min(0.05, boost))
    new_confidence = min(1.0, old_confidence + final_boost)
    result["confidence"] = round(new_confidence, 4)
    result["graph_boost"] = round(final_boost, 4)
    result["graph_warnings"] = warnings

    return result


def _sections_compatible(section_a: str, section_b: str) -> bool:
    """Check if two sections are compatible (same family)."""
    FAMILIES = {
        "asset": {"asset", "current_asset", "fixed_asset", "non_current_asset"},
        "liability": {"liability", "current_liability", "non_current_liability"},
        "equity": {"equity"},
        "revenue": {"revenue", "other_income"},
        "expense": {"expense", "cogs", "other_expense", "finance_cost"},
    }
    a = section_a.lower().strip()
    b = section_b.lower().strip()
    if a == b:
        return True
    for _family, members in FAMILIES.items():
        if a in members and b in members:
            return True
    return False
