"""
APEX Account Classifier — محرك التبويب المحاسبي
═══════════════════════════════════════════════════

يصنّف كل حساب في ميزان المراجعة إلى normalized_class
باستخدام 5 مستويات تصنيف بالترتيب:

1. Exact match على التبويب الخام (tab_raw)
2. Alias dictionary (عربي + إنجليزي)
3. Regex patterns
4. Account code prefix
5. Fallback → unmapped

كل حساب يخرج منه:
  - normalized_class
  - statement_section
  - sign_rule
  - current/non-current
  - mapping_confidence
  - mapping_source
"""

import re
from typing import Optional
from app.core.constants import ACCOUNT_TAXONOMY

# ═══════════════════════════════════════════════════════════════════════════════
#  Level 1: Exact Tab Match — أعلى ثقة
# ═══════════════════════════════════════════════════════════════════════════════

# ربط التبويبات الخام (كما تأتي من نموذج APEX) بالـ normalized_class
TAB_EXACT_MAP = {
    # ──── قائمة الدخل ────
    "إيرادات - مبيعات": "revenue",
    "إيرادات - مبيعات بضاعة": "revenue",
    "إيرادات - مبيعات خدمات": "service_revenue",
    "إيرادات - إيرادات خدمات": "service_revenue",
    "إيرادات - مرتجع مبيعات": "sales_returns",
    "إيرادات - خصم مسموح به": "sales_discounts",
    "إيرادات - إيرادات تشغيلية أخرى": "other_revenue",
    "إيرادات - مبيعات محلية": "revenue",
    "إيرادات - مردودات ومسموحات مبيعات": "sales_returns",
    "تكلفة المبيعات - تكلفة البضاعة المباعة": "cogs",
    "تكلفة مبيعات - تكلفة بضاعة مباعة": "cogs",
    "تكلفة المبيعات - مشتريات": "purchases",
    "تكلفة المبيعات - مشتريات بضاعة": "purchases",
    "تكلفة المبيعات - مرتجع مشتريات": "purchases_returns",
    "تكلفة مبيعات - مشتريات": "purchases",
    "تكلفة مبيعات - مشتريات بضاعة": "purchases",
    "تكلفة مبيعات - مشتريات بضاعة بغرض البيع": "purchases",
    "تكلفة مبيعات - إجمالي مشتريات بغرض البيع": "purchases",
    "تكلفة مبيعات - مردودات المشتريات": "purchases_returns",
    "تكلفة مبيعات - مرتجع مشتريات": "purchases_returns",
    "تكلفة مبيعات - مسموحات المشتريات": "purchases_returns",
    "تكلفة مبيعات - مسموحات مشتريات": "purchases_returns",
    "تكلفة مبيعات - خصم مكتسب": "purchases_returns",
    "تكلفة مبيعات - تكلفة بضاعة مباعة": "cogs",
    "تكلفة المبيعات - مصاريف شحن ونقل للداخل": "freight_in",
    "تكلفة المبيعات - تكلفة عمالة مباشرة": "direct_labor",
    "مصروفات إدارية وعمومية - رواتب وأجور": "payroll",
    "مصروفات إدارية وعمومية - رواتب وأجور إدارية": "payroll",
    "مصروفات إدارية - رواتب وأجور": "payroll",
    "مصروفات إدارية - رواتب ومزايا": "payroll",
    "مصروفات إدارية وعمومية - إيجارات": "rent_expense",
    "مصروفات إدارية وعمومية - إيجار مقر إداري": "rent_expense",
    "مصروفات إدارية - إيجارات": "rent_expense",
    "مصروفات إدارية وعمومية - كهرباء ومياه": "utilities",
    "مصروفات إدارية - مرافق (كهرباء، ماء، اتصالات)": "utilities",
    "مصروفات إدارية وعمومية - اتصالات وإنترنت": "utilities",
    "مصروفات إدارية وعمومية - إهلاك أصول إدارية": "depreciation_expense",
    "مصروفات إدارية - إهلاك": "depreciation_expense",
    "مصروفات إدارية وعمومية - صيانة وإصلاحات": "misc_admin_expense",
    "مصروفات إدارية وعمومية - مستلزمات مكتبية": "misc_admin_expense",
    "مصروفات إدارية - مصروفات مكتبية": "misc_admin_expense",
    "مصروفات إدارية وعمومية - رسوم حكومية": "government_fees",
    "مصروفات إدارية - رسوم حكومية": "government_fees",
    "مصروفات إدارية وعمومية - تأمينات اجتماعية": "gosi_expense",
    "مصروفات إدارية - تأمينات اجتماعية (GOSI)": "gosi_expense",
    "مصروفات إدارية - تأمينات اجتماعية": "gosi_expense",
    "مصروفات إدارية وعمومية - تأمين طبي": "medical_insurance",
    "مصروفات إدارية وعمومية - أتعاب محاسبة ومراجعة": "professional_fees",
    "مصروفات إدارية وعمومية - أتعاب قانونية": "professional_fees",
    "مصروفات إدارية - استشارات مهنية": "professional_fees",
    "مصروفات إدارية وعمومية - تأمين ممتلكات": "insurance_expense",
    "مصروفات إدارية - تأمينات": "insurance_expense",
    "مصروفات إدارية - تأمين": "insurance_expense",
    "مصروفات إدارية وعمومية - سفر وانتقالات": "travel_expense",
    "مصروفات إدارية - سفر وانتقالات": "travel_expense",
    "مصروفات إدارية وعمومية - مصروفات إدارية متنوعة": "misc_admin_expense",
    "مصروفات إدارية - مصروفات أخرى": "misc_admin_expense",
    "مصروفات إدارية - مصروفات متنوعة": "misc_admin_expense",
    "مصروفات إدارية - صيانة وإصلاح": "misc_admin_expense",
    "مصروفات إدارية - صيانة وإصلاحات": "misc_admin_expense",
    "مصروفات إدارية - أتعاب مهنية": "professional_fees",
    "مصروفات إدارية - مرافق": "utilities",
    "مصروفات بيع وتسويق - رواتب موظفي المبيعات": "selling_expenses",
    "مصروفات بيع - رواتب موظفي المبيعات": "selling_expenses",
    "مصروفات بيع وتسويق - عمولات مبيعات": "sales_commission",
    "مصروفات بيع - عمولات مبيعات": "sales_commission",
    "مصروفات بيع وتسويق - إعلان وتسويق": "marketing_expense",
    "مصروفات بيع - إعلان وتسويق": "marketing_expense",
    "مصروفات بيع وتسويق - مصروفات شحن ونقل للعملاء": "selling_expenses",
    "مصروفات بيع وتسويق - إيجار فروع البيع": "selling_expenses",
    "مصروفات بيع وتوزيع": "selling_expenses",
    "مصروفات بيع وتوزيع - رواتب ومزايا": "selling_expenses",
    "مصروفات بيع وتوزيع - تسويق وإعلان": "marketing_expense",
    "مصروفات بيع وتوزيع - نقل وشحن": "selling_expenses",
    "إيرادات ومصروفات أخرى - أرباح بيع أصول ثابتة": "gains_asset_disposal",
    "إيرادات ومصروفات أخرى - إيرادات استثمار": "finance_income",
    "إيرادات ومصروفات أخرى - أرباح فروقات عملة": "forex_gain",
    "إيرادات ومصروفات أخرى - خسائر بيع أصول ثابتة": "losses_asset_disposal",
    "إيرادات ومصروفات أخرى - مصروفات تمويل": "finance_cost",
    "إيرادات ومصروفات أخرى - مصروفات تمويل (فوائد)": "finance_cost",
    "إيرادات ومصروفات أخرى - خسائر فروقات عملة": "forex_loss",
    "إيرادات ومصروفات أخرى - غرامات وجزاءات": "penalties",
    "إيرادات ومصروفات أخرى - ديون معدومة": "bad_debts",
    "إيرادات ومصروفات أخرى - مصروفات غير تشغيلية أخرى": "other_expenses",
    "إيرادات ومصروفات أخرى - إيرادات متنوعة أخرى": "other_income",
    "إيرادات ومصروفات أخرى - مخصص زكاة وضريبة دخل": "zakat_tax",
    "تكاليف تمويل": "finance_cost",
    "تكاليف تمويل - تمويل قروض بنكية": "finance_cost",
    "تكاليف تمويل - رسوم بنكية": "finance_cost",
    "تكاليف تمويل - تمويل إيجار": "finance_cost",
    "زكاة وضرائب": "zakat_tax",
    "زكاة وضرائب - ضريبة دخل شريك أجنبي": "zakat_tax",
    "زكاة وضرائب - زكاة": "zakat_tax",
    "زكاة وضرائب - ضريبة دخل": "zakat_tax",
    "زكاة وضرائب - استقطاع": "zakat_tax",
    "مصروفات إدارية": "admin_expenses",
    "مصروفات إدارية - إهلاك أصول حق استخدام": "depreciation_expense",
    # ──── أصول متداولة ────
    "أصول متداولة - نقد وما في حكمه": "bank_accounts",
    "أصول متداولة - نقد في الصندوق": "cash_on_hand",
    "أصول متداولة - نقد في البنوك": "bank_accounts",
    "أصول متداولة - ذمم مدينة تجارية": "trade_receivables",
    "أصول متداولة - ذمم مدينة أخرى": "other_receivables",
    "أصول متداولة - مخزون": "inventory",
    "أصول متداولة - مخزون بضاعة جاهزة": "inventory",
    "أصول متداولة - مخزون مواد خام": "inventory_raw",
    "أصول متداولة - مصروفات مدفوعة مقدماً": "prepayments",
    "أصول متداولة - مصروفات مدفوعة": "prepayments",
    "أصول متداولة - ضريبة قيمة مضافة مدخلات": "vat_receivable",
    "أصول متداولة - استثمارات قصيرة الأجل": "short_term_investments",
    # ──── أصول غير متداولة ────
    "أصول غير متداولة - ممتلكات وآلات ومعدات": "machinery",
    "أصول غير متداولة - أراضي": "land",
    "أصول غير متداولة - مباني وإنشاءات": "buildings",
    "أصول غير متداولة - سيارات ووسائل نقل": "vehicles",
    "أصول غير متداولة - أثاث ومفروشات": "furniture",
    "أصول غير متداولة - أجهزة حاسب آلي": "computers",
    "أصول غير متداولة - ديكورات وتحسينات": "leasehold_improvements",
    "أصول غير متداولة - مجمع الإهلاك": "accum_depr_general",
    "أصول غير متداولة - مجمع إهلاك مباني": "accum_depr_buildings",
    "أصول غير متداولة - مجمع إهلاك آلات": "accum_depr_machinery",
    "أصول غير متداولة - مجمع إهلاك سيارات": "accum_depr_vehicles",
    "أصول غير متداولة - مجمع إهلاك أثاث": "accum_depr_furniture",
    "أصول غير متداولة - مجمع إهلاك أجهزة": "accum_depr_computers",
    "أصول غير متداولة - أصول غير ملموسة": "intangible_assets",
    "أصول غير متداولة - أصول حق استخدام": "rou_assets",
    "أصول غير متداولة - استثمارات طويلة الأجل": "long_term_investments",
    # ──── التزامات متداولة ────
    "التزامات متداولة - ذمم دائنة تجارية": "trade_payables",
    "التزامات متداولة - ذمم دائنة أخرى": "other_payables",
    "التزامات متداولة - قروض بنكية قصيرة الأجل": "current_loans",
    "التزامات متداولة - تسهيلات بنكية": "overdraft",
    "التزامات متداولة - الجزء المتداول من القروض طويلة الأجل": "current_portion_ltl",
    "التزامات متداولة - جزء متداول من قروض طويلة": "current_portion_ltl",
    "التزامات متداولة - رواتب مستحقة": "accrued_salaries",
    "التزامات متداولة - رواتب وأجور مستحقة": "accrued_salaries",
    "التزامات متداولة - إجازات مستحقة": "accrued_vacation",
    "التزامات متداولة - مصروفات مستحقة": "accrued_expenses",
    "التزامات متداولة - مستحقات ومصروفات مستحقة": "accrued_expenses",
    "التزامات متداولة - مستحقات ومخصصات": "accrued_expenses",
    "التزامات متداولة - إيرادات مقبوضة مقدماً": "deferred_revenue",
    "التزامات متداولة - ضريبة قيمة مضافة مخرجات": "vat_payable",
    "التزامات متداولة - صافي ضريبة قيمة مضافة مستحقة": "net_vat_payable",
    "التزامات متداولة - زكاة مستحقة": "zakat_payable",
    "التزامات متداولة - ضريبة دخل مستحقة": "income_tax_payable",
    # ──── التزامات غير متداولة ────
    "التزامات غير متداولة - قروض بنكية طويلة الأجل": "long_term_loans",
    "التزامات غير متداولة - قروض طويلة الأجل": "long_term_loans",
    "التزامات غير متداولة - التزامات إيجارية": "non_current_lease_liabilities",
    "التزامات غير متداولة - التزامات إيجارية طويلة الأجل": "non_current_lease_liabilities",
    "التزامات غير متداولة - مخصص مكافأة نهاية الخدمة": "end_of_service",
    "التزامات غير متداولة - مكافأة نهاية الخدمة": "end_of_service",
    # ──── حقوق ملكية ────
    "حقوق ملكية - رأس المال المدفوع": "share_capital",
    "حقوق ملكية - رأس المال": "share_capital",
    "حقوق ملكية - احتياطي نظامي": "statutory_reserve",
    "حقوق ملكية - احتياطي اتفاقي": "contractual_reserve",
    "حقوق ملكية - أرباح مبقاة سنوات سابقة": "retained_earnings",
    "حقوق ملكية - أرباح مبقاة": "retained_earnings",
    "حقوق ملكية - أرباح (خسائر) السنة الحالية": "current_year_profit",
    "حقوق ملكية - جاري الشركاء / المالك": "partners_current_account",
    "حقوق ملكية - جاري الشركاء": "partners_current_account",
    "حقوق ملكية - أرباح خسائر": "retained_earnings",
}


# ═══════════════════════════════════════════════════════════════════════════════
#  Level 2: Alias Dictionary — مرادفات شائعة
# ═══════════════════════════════════════════════════════════════════════════════

# كل alias يطابَق بالـ contains (أي اسم حساب يحتوي على هذا النص)
ALIAS_MAP = {
    # ─── نقد ───
    "صندوق": "cash_on_hand",
    "نقدية": "cash_on_hand",
    "cash on hand": "cash_on_hand",
    "petty cash": "cash_on_hand",
    "بنك ": "bank_accounts",  # space after to avoid matching بنكية
    "حساب البنك": "bank_accounts",
    "bank account": "bank_accounts",
    "البنك الاهلى": "bank_accounts",
    "البنك العربي": "bank_accounts",
    "بنك الراجحي": "bank_accounts",
    "بنك الرياض": "bank_accounts",
    "بنك ساب": "bank_accounts",
    "بنك الانماء": "bank_accounts",
    "بنك البلاد": "bank_accounts",
    "بنك الجزيرة": "bank_accounts",
    # ─── ذمم مدينة ───
    "مدينون": "trade_receivables",
    "عملاء": "trade_receivables",
    "ذمم مدينة": "trade_receivables",
    "accounts receivable": "trade_receivables",
    "trade receivable": "trade_receivables",
    "مخصص ديون مشكوك": "allowance_doubtful",
    "مخصص ديون معدومة": "allowance_doubtful",
    "allowance for doubtful": "allowance_doubtful",
    "provision for bad debt": "allowance_doubtful",
    # ─── مخزون ───
    "بضاعة اول المدة": "inventory",
    "بضاعة أول المدة": "inventory",
    "بضاعة اخر المدة": "inventory",
    "بضاعة آخر المدة": "inventory",
    "مخزون بضاعة": "inventory",
    "مخزون تحويلات": "inventory",
    "inventory": "inventory",
    "مواد خام": "inventory_raw",
    "raw material": "inventory_raw",
    # ─── مصروفات مدفوعة مقدماً ───
    "مدفوعة مقدما": "prepayments",
    "مقدمة": "prepayments",
    "prepaid": "prepayments",
    "تامين ايجار": "prepaid_rent",
    "تأمين إيجار": "prepaid_rent",
    "deposit": "prepaid_rent",
    "فوائد مؤجلة": "prepayments",
    "فؤائد مؤجلة": "prepayments",
    # ─── عهد وسلف ───
    "عهدة": "employee_advances",
    "سلفة": "employee_advances",
    "عهد موظفين": "employee_advances",
    "employee advance": "employee_advances",
    # ─── أصول ثابتة ───
    "ديكور": "leasehold_improvements",
    "decoration": "leasehold_improvements",
    "سيارات": "vehicles",
    "vehicle": "vehicles",
    "أثاث": "furniture",
    "اثاث": "furniture",
    "furniture": "furniture",
    "أجهزة": "computers",
    "اجهزة": "computers",
    "computer": "computers",
    "آلات": "machinery",
    "الات": "machinery",
    "machinery": "machinery",
    "equipment": "machinery",
    "مباني": "buildings",
    "مبانى": "buildings",
    "building": "buildings",
    "أراضي": "land",
    "اراضي": "land",
    "land": "land",
    # ─── مجمع إهلاك ───
    "مجمع إهلاك": "accum_depr_general",
    "مجمع اهلاك": "accum_depr_general",
    "مجمع الإهلاك": "accum_depr_general",
    "مجمع الاهلاك": "accum_depr_general",
    "accumulated depreciation": "accum_depr_general",
    "acc. depr": "accum_depr_general",
    # ─── التزامات ───
    "دائنون": "trade_payables",
    "موردين": "trade_payables",
    "ذمم دائنة": "trade_payables",
    "trade payable": "trade_payables",
    "accounts payable": "trade_payables",
    "رواتب مستحقة": "accrued_salaries",
    "أجور مستحقة": "accrued_salaries",
    "salary payable": "accrued_salaries",
    "مصروفات مستحقة": "accrued_expenses",
    "accrued expense": "accrued_expenses",
    "قرض قصير": "current_loans",
    "short term loan": "current_loans",
    "تسهيلات": "overdraft",
    "overdraft": "overdraft",
    "قرض طويل": "long_term_loans",
    "long term loan": "long_term_loans",
    "مكافأة نهاية": "end_of_service",
    "مكافاة نهاية": "end_of_service",
    "end of service": "end_of_service",
    # ─── حقوق ملكية ───
    "رأس المال": "share_capital",
    "راس المال": "share_capital",
    "رأس مال": "share_capital",
    "capital": "share_capital",
    "أرباح مبقاة": "retained_earnings",
    "ارباح مبقاة": "retained_earnings",
    "retained earnings": "retained_earnings",
    "ارباح خسائر": "retained_earnings",
    "أرباح خسائر": "retained_earnings",
    "احتياطي نظامي": "statutory_reserve",
    "statutory reserve": "statutory_reserve",
    "جاري الشريك": "partners_current_account",
    "جاري المالك": "partners_current_account",
    "جاري الشركاء": "partners_current_account",
    "owner equity": "partners_current_account",
    "مسحوبات": "drawings",
    "drawings": "drawings",
    # ─── إيرادات ───
    "مبيعات": "revenue",
    "sales": "revenue",
    "إيرادات خدمات": "service_revenue",
    "service revenue": "service_revenue",
    "مرتجع مبيعات": "sales_returns",
    "sales return": "sales_returns",
    "خصم مسموح": "sales_discounts",
    "discount allowed": "sales_discounts",
    # ─── تكلفة مبيعات ───
    "مشتريات": "purchases",
    "purchase": "purchases",
    "مشتريات بغرض البيع": "purchases",
    "إجمالي مشتريات": "purchases",
    "تكلفة بضاعة": "cogs",
    "cost of goods": "cogs",
    "cost of sales": "cogs",
    "مرتجع مشتريات": "purchases_returns",
    "مردودات المشتريات": "purchases_returns",
    "مردودات مشتريات": "purchases_returns",
    "مسموحات المشتريات": "purchases_returns",
    "مسموحات مشتريات": "purchases_returns",
    "خصم مكتسب": "purchases_returns",
    "purchase return": "purchases_returns",
    "purchase discount": "purchases_returns",
    # ─── مصروفات ───
    "رواتب": "payroll",
    "أجور": "payroll",
    "salary": "payroll",
    "wage": "payroll",
    "إيجار": "rent_expense",
    "ايجار": "rent_expense",
    "rent": "rent_expense",
    "كهرباء": "utilities",
    "electricity": "utilities",
    "ماء": "utilities",
    "water": "utilities",
    "اتصالات": "utilities",
    "telecom": "utilities",
    "إهلاك": "depreciation_expense",
    "اهلاك": "depreciation_expense",
    "depreciation": "depreciation_expense",
    "إطفاء": "amortization_expense",
    "amortization": "amortization_expense",
    "تمويل": "finance_cost",
    "فوائد": "finance_cost",
    "interest": "finance_cost",
    "finance cost": "finance_cost",
    "زكاة": "zakat_tax",
    "ضريبة دخل": "zakat_tax",
    "zakat": "zakat_tax",
    "income tax": "zakat_tax",
    "غرامات": "penalties",
    "penalties": "penalties",
    "ديون معدومة": "bad_debts",
    "bad debt": "bad_debts",
    # ─── ض.ق.م ───
    "ضريبة قيمة مضافة مدخلات": "vat_receivable",
    "vat input": "vat_receivable",
    "ضريبة قيمة مضافة مخرجات": "vat_payable",
    "vat output": "vat_payable",
    "صافي ضريبة القيمة": "net_vat_payable",
}


# ═══════════════════════════════════════════════════════════════════════════════
#  Level 3: Regex Patterns — أنماط ذكية
# ═══════════════════════════════════════════════════════════════════════════════

REGEX_PATTERNS = [
    # Bank accounts — أي نص يحتوي على رقم حساب بنكي
    (re.compile(r"بنك.*\d{5,}|حساب.*بنك", re.IGNORECASE), "bank_accounts"),
    (re.compile(r"bank.*\d{5,}", re.IGNORECASE), "bank_accounts"),
    # Accumulated depreciation
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*(?:سيارات|نقل)", re.IGNORECASE), "accum_depr_vehicles"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*(?:مباني|مبانى)", re.IGNORECASE), "accum_depr_buildings"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*(?:أثاث|اثاث)", re.IGNORECASE), "accum_depr_furniture"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*(?:أجهزة|اجهزة|حاسب)", re.IGNORECASE), "accum_depr_computers"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*(?:آلات|الات|معدات)", re.IGNORECASE), "accum_depr_machinery"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك).*حق.*استخدام", re.IGNORECASE), "accum_depr_rou"),
    (re.compile(r"مجمع.*(?:إهلاك|اهلاك)", re.IGNORECASE), "accum_depr_general"),
    # VAT patterns
    (re.compile(r"ض.*ق.*م.*مدخل|vat.*input", re.IGNORECASE), "vat_receivable"),
    (re.compile(r"ض.*ق.*م.*مخرج|vat.*output", re.IGNORECASE), "vat_payable"),
    # Partner current accounts
    (re.compile(r"جاري\s+(?:الشريك|شريك)", re.IGNORECASE), "partners_current_account"),
]


# ═══════════════════════════════════════════════════════════════════════════════
#  Level 4: Account Code Prefix — أكواد الحسابات
# ═══════════════════════════════════════════════════════════════════════════════

CODE_PREFIX_MAP = {
    "1110": "cash_on_hand",
    "1120": "bank_accounts",
    "1130": "demand_deposits",
    "1140": "checks_receivable",
    "1150": "trade_receivables",
    "1160": "other_receivables",
    "1170": "allowance_doubtful",
    "1180": "inventory",
    "1190": "prepayments",
    "1210": "land",
    "1220": "buildings",
    "1230": "machinery",
    "1240": "vehicles",
    "1250": "furniture",
    "1260": "computers",
    "2110": "trade_payables",
    "2120": "other_payables",
    "2130": "current_loans",
    "2140": "accrued_salaries",
    "2150": "accrued_expenses",
    "2160": "vat_payable",
    "2170": "zakat_payable",
    "2210": "long_term_loans",
    "2220": "non_current_lease_liabilities",
    "2230": "end_of_service",
    "3010": "share_capital",
    "3020": "statutory_reserve",
    "3030": "retained_earnings",
    "3040": "current_year_profit",
    "3050": "partners_current_account",
    "4010": "revenue",
    "4020": "service_revenue",
    "4030": "sales_returns",
    "4040": "sales_discounts",
    "5010": "cogs",
    "5020": "purchases",
    "5030": "purchases_returns",
    "6010": "payroll",
    "6020": "rent_expense",
    "6030": "utilities",
    "6040": "depreciation_expense",
    "6050": "government_fees",
    "7010": "selling_expenses",
    "7020": "sales_commission",
    "7030": "marketing_expense",
    "8010": "other_income",
    "8020": "finance_cost",
    "8030": "zakat_tax",
}


# ═══════════════════════════════════════════════════════════════════════════════
#  Classifier — المحرك الرئيسي
# ═══════════════════════════════════════════════════════════════════════════════


class AccountClassifier:
    """
    يصنّف حساب واحد من ميزان المراجعة إلى normalized_class.

    Usage:
        classifier = AccountClassifier()
        result = classifier.classify(
            tab_raw="أصول متداولة - نقد وما في حكمه",
            account_name="بنك الراجحي (407608017777128)",
            account_code="1120"
        )
        # result = ClassificationResult(
        #     normalized_class="bank_accounts",
        #     confidence=0.98,
        #     source="exact_tab",
        #     ...
        # )
    """

    def classify(
        self,
        tab_raw: str,
        account_name: str,
        account_code: Optional[str] = None,
        sub_tab: Optional[str] = None,
    ) -> dict:
        """
        Classify a single account through 5 levels.
        Returns dict with classification details.
        """
        # Normalize inputs
        tab_clean = (tab_raw or "").strip()
        name_clean = (account_name or "").strip()
        name_lower = name_clean.lower()
        code_clean = (account_code or "").strip()

        # Build combined tab for matching
        if sub_tab:
            combined_tab = f"{tab_clean} - {sub_tab.strip()}"
        else:
            combined_tab = tab_clean

        # Level 1: Exact tab match
        result = self._match_exact_tab(combined_tab, tab_clean)
        if result:
            # Name override: if tab says COGS but name clearly says purchases
            result = self._name_override(result, name_clean, name_lower)
            return self._build_result(result, 0.98, "exact_tab", tab_clean, name_clean)

        # Level 2: Alias match on account name
        result = self._match_alias(name_clean, name_lower)
        if result:
            return self._build_result(result, 0.88, "alias", tab_clean, name_clean)

        # Level 3: Regex match on account name
        result = self._match_regex(name_clean)
        if result:
            return self._build_result(result, 0.82, "regex", tab_clean, name_clean)

        # Level 4: Account code prefix
        if code_clean:
            result = self._match_code(code_clean)
            if result:
                return self._build_result(result, 0.85, "code_prefix", tab_clean, name_clean)

        # Level 5: Fallback — try alias on tab itself
        result = self._match_alias(tab_clean, tab_clean.lower())
        if result:
            return self._build_result(result, 0.70, "tab_alias_fallback", tab_clean, name_clean)

        # Unmapped
        return {
            "normalized_class": None,
            "confidence": 0.0,
            "source": "unmapped",
            "tab_raw": tab_clean,
            "account_name": name_clean,
            "section": None,
            "sign": None,
            "current": None,
            "warnings": [f"حساب غير مصنّف: {name_clean} ({tab_clean})"],
        }

    def classify_rows(self, rows: list) -> list:
        """Classify all rows and return enriched rows with classification."""
        classified = []
        for row in rows:
            cls = self.classify(
                tab_raw=row.get("tab", ""),
                account_name=row.get("name", ""),
                account_code=row.get("code", ""),
                sub_tab=row.get("sub_tab", ""),
            )
            enriched = {**row, **cls}
            classified.append(enriched)
        return classified

    def get_summary(self, classified_rows: list) -> dict:
        """Get classification quality summary."""
        total = len(classified_rows)
        mapped = sum(1 for r in classified_rows if r.get("normalized_class"))
        unmapped = total - mapped

        confidence_vals = [r.get("confidence", 0) for r in classified_rows if r.get("normalized_class")]
        avg_confidence = sum(confidence_vals) / len(confidence_vals) if confidence_vals else 0

        sources = {}
        for r in classified_rows:
            src = r.get("source", "unknown")
            sources[src] = sources.get(src, 0) + 1

        unmapped_accounts = [
            {"name": r.get("account_name", ""), "tab": r.get("tab_raw", "")}
            for r in classified_rows
            if not r.get("normalized_class")
        ]

        return {
            "total_accounts": total,
            "mapped_accounts": mapped,
            "unmapped_accounts_count": unmapped,
            "unmapped_accounts": unmapped_accounts,
            "average_confidence": round(avg_confidence, 3),
            "mapping_sources": sources,
            "quality_label": (
                "ممتاز"
                if avg_confidence >= 0.90
                else "جيد" if avg_confidence >= 0.80 else "مقبول" if avg_confidence >= 0.60 else "يحتاج مراجعة"
            ),
        }

    # ─── Internal matching methods ───────────────────────────────────────

    def _match_exact_tab(self, combined_tab: str, tab_raw: str) -> Optional[str]:
        if combined_tab in TAB_EXACT_MAP:
            return TAB_EXACT_MAP[combined_tab]
        if tab_raw in TAB_EXACT_MAP:
            return TAB_EXACT_MAP[tab_raw]
        return None

    def _name_override(self, classification: str, name: str, name_lower: str) -> str:
        """
        Override classification when account name clearly contradicts the tab.
        Example: tab says "تكلفة بضاعة مباعة" but name is "إجمالي مشتريات بغرض البيع"
        → should be purchases, not cogs.
        """
        if classification == "cogs":
            # If name contains clear purchase indicators → override to purchases
            purchase_keywords = ["مشتريات", "إجمالي مشتريات", "مشتريات بغرض"]
            returns_keywords = ["مردودات المشتريات", "مرتجع مشتريات", "مسموحات المشتريات", "مسموحات مشتريات"]
            discount_keywords = ["خصم مكتسب"]

            for kw in returns_keywords:
                if kw in name:
                    return "purchases_returns"
            for kw in discount_keywords:
                if kw in name:
                    return "purchases_returns"
            for kw in purchase_keywords:
                if kw in name:
                    return "purchases"

        return classification

    def _match_alias(self, text: str, text_lower: str) -> Optional[str]:
        # Try longest match first for better accuracy
        for alias in sorted(ALIAS_MAP.keys(), key=len, reverse=True):
            if alias.lower() in text_lower:
                return ALIAS_MAP[alias]
        return None

    def _match_regex(self, text: str) -> Optional[str]:
        for pattern, cls in REGEX_PATTERNS:
            if pattern.search(text):
                return cls
        return None

    def _match_code(self, code: str) -> Optional[str]:
        # Try exact 4-digit match first
        prefix4 = code[:4] if len(code) >= 4 else code
        if prefix4 in CODE_PREFIX_MAP:
            return CODE_PREFIX_MAP[prefix4]
        # Try 3-digit prefix
        prefix3 = code[:3] if len(code) >= 3 else code
        for k, v in CODE_PREFIX_MAP.items():
            if k.startswith(prefix3):
                return v
        return None

    def _build_result(
        self,
        normalized_class: str,
        confidence: float,
        source: str,
        tab_raw: str,
        account_name: str,
    ) -> dict:
        taxonomy = ACCOUNT_TAXONOMY.get(normalized_class, {})
        warnings = []

        return {
            "normalized_class": normalized_class,
            "confidence": confidence,
            "source": source,
            "tab_raw": tab_raw,
            "account_name": account_name,
            "section": taxonomy.get("section"),
            "sign": taxonomy.get("sign"),
            "current": taxonomy.get("current"),
            "is_liability": taxonomy.get("liability", False),
            "is_contra": taxonomy.get("contra", False),
            "ar_label": taxonomy.get("ar_label", ""),
            "en_label": taxonomy.get("en_label", ""),
            "warnings": warnings,
        }
