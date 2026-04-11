"""
APEX Core Constants — المرجع الوحيد للتصنيف المحاسبي
═══════════════════════════════════════════════════════

كل تبويب محاسبي، كل مرادف، كل قاعدة إشارة — يُعرَّف هنا مرة واحدة.
باقي المحركات تستورد من هنا فقط.
"""

# ─── Statement Sections ─────────────────────────────────────────────────────
INCOME_STATEMENT = "income_statement"
BALANCE_SHEET = "balance_sheet"
EQUITY = "equity"

# ─── Normalized Account Classes ─────────────────────────────────────────────
# كل class له: section, sign_rule, current_noncurrent, cashflow_role

ACCOUNT_TAXONOMY = {
    # ══════════════════════════════════════════════
    #  قائمة الدخل
    # ══════════════════════════════════════════════
    "revenue": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "الإيرادات",
        "en_label": "Revenue",
    },
    "sales_returns": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مرتجع مبيعات",
        "en_label": "Sales Returns",
    },
    "sales_discounts": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "خصم مسموح به",
        "en_label": "Sales Discounts",
    },
    "other_revenue": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "إيرادات أخرى",
        "en_label": "Other Revenue",
    },
    "service_revenue": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "إيرادات خدمات",
        "en_label": "Service Revenue",
    },
    "cogs": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "تكلفة البضاعة المباعة",
        "en_label": "Cost of Goods Sold",
    },
    "purchases": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مشتريات",
        "en_label": "Purchases",
    },
    "purchases_returns": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "مرتجع مشتريات",
        "en_label": "Purchases Returns",
    },
    "freight_in": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصاريف شحن ونقل للداخل",
        "en_label": "Freight In",
    },
    "direct_labor": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "عمالة مباشرة",
        "en_label": "Direct Labor",
    },
    "admin_expenses": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروفات إدارية وعمومية",
        "en_label": "G&A Expenses",
    },
    "selling_expenses": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروفات بيع وتسويق",
        "en_label": "Selling & Marketing",
    },
    "payroll": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "رواتب وأجور",
        "en_label": "Payroll",
    },
    "rent_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "إيجارات",
        "en_label": "Rent Expense",
    },
    "utilities": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مرافق",
        "en_label": "Utilities",
    },
    "depreciation_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروف إهلاك",
        "en_label": "Depreciation Expense",
    },
    "amortization_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروف إطفاء",
        "en_label": "Amortization Expense",
    },
    "finance_cost": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "تكاليف تمويل",
        "en_label": "Finance Costs",
    },
    "finance_income": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "إيرادات تمويل",
        "en_label": "Finance Income",
    },
    "other_income": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "إيرادات أخرى غير تشغيلية",
        "en_label": "Other Income",
    },
    "other_expenses": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروفات أخرى",
        "en_label": "Other Expenses",
    },
    "zakat_tax": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "زكاة وضريبة دخل",
        "en_label": "Zakat & Income Tax",
    },
    "gains_asset_disposal": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "أرباح بيع أصول",
        "en_label": "Gain on Asset Disposal",
    },
    "losses_asset_disposal": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "خسائر بيع أصول",
        "en_label": "Loss on Asset Disposal",
    },
    "forex_gain": {
        "section": INCOME_STATEMENT,
        "sign": "credit_normal",
        "ar_label": "أرباح فروقات عملة",
        "en_label": "Foreign Exchange Gain",
    },
    "forex_loss": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "خسائر فروقات عملة",
        "en_label": "Foreign Exchange Loss",
    },
    "penalties": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "غرامات وجزاءات",
        "en_label": "Penalties & Fines",
    },
    "bad_debts": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "ديون معدومة",
        "en_label": "Bad Debts",
    },
    "government_fees": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "رسوم حكومية",
        "en_label": "Government Fees",
    },
    "insurance_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "تأمينات",
        "en_label": "Insurance Expense",
    },
    "marketing_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "إعلان وتسويق",
        "en_label": "Marketing & Advertising",
    },
    "travel_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "سفر وانتقالات",
        "en_label": "Travel & Transportation",
    },
    "professional_fees": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "أتعاب مهنية",
        "en_label": "Professional Fees",
    },
    "misc_admin_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "مصروفات إدارية متنوعة",
        "en_label": "Misc. Admin Expenses",
    },
    "sales_commission": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "عمولات مبيعات",
        "en_label": "Sales Commission",
    },
    "gosi_expense": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "تأمينات اجتماعية",
        "en_label": "GOSI / Social Insurance",
    },
    "medical_insurance": {
        "section": INCOME_STATEMENT,
        "sign": "debit_normal",
        "ar_label": "تأمين طبي",
        "en_label": "Medical Insurance",
    },
    # ══════════════════════════════════════════════
    #  أصول متداولة
    # ══════════════════════════════════════════════
    "cash_on_hand": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "cashflow": "cash",
        "ar_label": "نقد في الصندوق",
        "en_label": "Cash on Hand",
    },
    "bank_accounts": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "cashflow": "cash",
        "ar_label": "نقد في البنوك",
        "en_label": "Bank Accounts",
    },
    "demand_deposits": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "cashflow": "cash",
        "ar_label": "ودائع تحت الطلب",
        "en_label": "Demand Deposits",
    },
    "checks_receivable": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "شيكات تحت التحصيل",
        "en_label": "Checks Receivable",
    },
    "trade_receivables": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "ذمم مدينة تجارية",
        "en_label": "Trade Receivables",
    },
    "related_party_receivables": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "ذمم مدينة أطراف ذات علاقة",
        "en_label": "Related Party Receivables",
    },
    "allowance_doubtful": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "contra": True,
        "ar_label": "مخصص ديون مشكوك فيها",
        "en_label": "Allowance for Doubtful Debts",
    },
    "inventory": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "مخزون",
        "en_label": "Inventory",
    },
    "inventory_raw": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "مخزون مواد خام",
        "en_label": "Raw Materials Inventory",
    },
    "inventory_wip": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "مخزون تحت التصنيع",
        "en_label": "Work in Progress Inventory",
    },
    "inventory_transit": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "بضاعة بالطريق",
        "en_label": "Inventory in Transit",
    },
    "prepayments": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "مصروفات مدفوعة مقدماً",
        "en_label": "Prepayments",
    },
    "prepaid_insurance": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "تأمينات مدفوعة مقدماً",
        "en_label": "Prepaid Insurance",
    },
    "prepaid_rent": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "إيجارات مدفوعة مقدماً",
        "en_label": "Prepaid Rent",
    },
    "employee_advances": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "سلف وعهد موظفين",
        "en_label": "Employee Advances",
    },
    "vat_receivable": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "ضريبة قيمة مضافة مدخلات",
        "en_label": "VAT Receivable",
    },
    "short_term_investments": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "استثمارات قصيرة الأجل",
        "en_label": "Short-term Investments",
    },
    "notes_receivable": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "أوراق قبض",
        "en_label": "Notes Receivable",
    },
    "other_receivables": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": True,
        "ar_label": "ذمم مدينة أخرى",
        "en_label": "Other Receivables",
    },
    # ══════════════════════════════════════════════
    #  أصول غير متداولة
    # ══════════════════════════════════════════════
    "land": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "أراضي",
        "en_label": "Land",
    },
    "buildings": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "مباني وإنشاءات",
        "en_label": "Buildings",
    },
    "machinery": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "آلات ومعدات",
        "en_label": "Machinery & Equipment",
    },
    "vehicles": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "سيارات ووسائل نقل",
        "en_label": "Vehicles",
    },
    "furniture": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "أثاث ومفروشات",
        "en_label": "Furniture & Fixtures",
    },
    "computers": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "أجهزة حاسب آلي",
        "en_label": "Computers & IT Equipment",
    },
    "leasehold_improvements": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "ديكورات وتحسينات",
        "en_label": "Leasehold Improvements",
    },
    "accum_depr_buildings": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك مباني",
        "en_label": "Acc. Depr. - Buildings",
    },
    "accum_depr_machinery": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك آلات",
        "en_label": "Acc. Depr. - Machinery",
    },
    "accum_depr_vehicles": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك سيارات",
        "en_label": "Acc. Depr. - Vehicles",
    },
    "accum_depr_furniture": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك أثاث",
        "en_label": "Acc. Depr. - Furniture",
    },
    "accum_depr_computers": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك أجهزة",
        "en_label": "Acc. Depr. - Computers",
    },
    "accum_depr_general": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع الإهلاك",
        "en_label": "Accumulated Depreciation",
    },
    "rou_assets": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "أصول حق استخدام",
        "en_label": "Right-of-Use Assets",
    },
    "accum_depr_rou": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إهلاك أصول حق استخدام",
        "en_label": "Acc. Depr. - ROU Assets",
    },
    "intangible_assets": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "أصول غير ملموسة",
        "en_label": "Intangible Assets",
    },
    "accum_amort_intangibles": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "contra": True,
        "ar_label": "مجمع إطفاء أصول غير ملموسة",
        "en_label": "Acc. Amort. - Intangibles",
    },
    "goodwill": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "شهرة محل",
        "en_label": "Goodwill",
    },
    "long_term_investments": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "استثمارات طويلة الأجل",
        "en_label": "Long-term Investments",
    },
    "projects_under_construction": {
        "section": BALANCE_SHEET,
        "sign": "debit_normal",
        "current": False,
        "ar_label": "مشاريع تحت التنفيذ",
        "en_label": "Projects Under Construction",
    },
    # ══════════════════════════════════════════════
    #  التزامات متداولة
    # ══════════════════════════════════════════════
    "trade_payables": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "ذمم دائنة تجارية",
        "en_label": "Trade Payables",
    },
    "other_payables": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "ذمم دائنة أخرى",
        "en_label": "Other Payables",
    },
    "related_party_payables": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "ذمم دائنة أطراف ذات علاقة",
        "en_label": "Related Party Payables",
    },
    "current_loans": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "قروض بنكية قصيرة الأجل",
        "en_label": "Short-term Bank Loans",
    },
    "overdraft": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "تسهيلات بنكية",
        "en_label": "Bank Overdraft",
    },
    "current_portion_ltl": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "الجزء المتداول من القروض طويلة الأجل",
        "en_label": "Current Portion of LT Loans",
    },
    "notes_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "أوراق دفع",
        "en_label": "Notes Payable",
    },
    "accrued_salaries": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "رواتب مستحقة",
        "en_label": "Accrued Salaries",
    },
    "accrued_vacation": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "إجازات مستحقة",
        "en_label": "Accrued Vacation",
    },
    "accrued_expenses": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "مصروفات مستحقة",
        "en_label": "Accrued Expenses",
    },
    "deferred_revenue": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "إيرادات مقبوضة مقدماً",
        "en_label": "Deferred Revenue",
    },
    "vat_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "ضريبة قيمة مضافة مخرجات",
        "en_label": "VAT Payable",
    },
    "net_vat_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "صافي ضريبة القيمة المضافة المستحقة",
        "en_label": "Net VAT Payable",
    },
    "zakat_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "زكاة مستحقة",
        "en_label": "Zakat Payable",
    },
    "income_tax_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "ضريبة دخل مستحقة",
        "en_label": "Income Tax Payable",
    },
    "retention_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "أمانات ومبالغ محتجزة",
        "en_label": "Retention Payable",
    },
    "warranty_provision": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "مخصص ضمان",
        "en_label": "Warranty Provision",
    },
    "dividends_payable": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": True,
        "liability": True,
        "ar_label": "توزيعات أرباح مستحقة",
        "en_label": "Dividends Payable",
    },
    # ══════════════════════════════════════════════
    #  التزامات غير متداولة
    # ══════════════════════════════════════════════
    "long_term_loans": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "liability": True,
        "ar_label": "قروض بنكية طويلة الأجل",
        "en_label": "Long-term Bank Loans",
    },
    "non_current_lease_liabilities": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "liability": True,
        "ar_label": "التزامات إيجارية طويلة الأجل",
        "en_label": "Non-current Lease Liabilities",
    },
    "end_of_service": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "liability": True,
        "ar_label": "مخصص مكافأة نهاية الخدمة",
        "en_label": "End of Service Benefits",
    },
    "related_party_loans": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "liability": True,
        "ar_label": "قروض أطراف ذات علاقة",
        "en_label": "Related Party Loans",
    },
    "murabaha_financing": {
        "section": BALANCE_SHEET,
        "sign": "credit_normal",
        "current": False,
        "liability": True,
        "ar_label": "التزامات تمويل مرابحة",
        "en_label": "Murabaha Financing",
    },
    # ══════════════════════════════════════════════
    #  حقوق الملكية
    # ══════════════════════════════════════════════
    "share_capital": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "رأس المال المدفوع",
        "en_label": "Share Capital",
    },
    "share_premium": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "علاوة إصدار",
        "en_label": "Share Premium",
    },
    "statutory_reserve": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "احتياطي نظامي",
        "en_label": "Statutory Reserve",
    },
    "contractual_reserve": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "احتياطي اتفاقي",
        "en_label": "Contractual Reserve",
    },
    "retained_earnings": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "أرباح مبقاة",
        "en_label": "Retained Earnings",
    },
    "current_year_profit": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "أرباح (خسائر) السنة الحالية",
        "en_label": "Current Year Profit/Loss",
    },
    "partners_current_account": {
        "section": EQUITY,
        "sign": "credit_normal",
        "ar_label": "جاري الشركاء / المالك",
        "en_label": "Partners Current Account",
    },
    "drawings": {
        "section": EQUITY,
        "sign": "debit_normal",
        "ar_label": "مسحوبات شخصية",
        "en_label": "Drawings / Distributions",
    },
}


# ─── Grouping helpers ────────────────────────────────────────────────────────


def get_classes_by_section(section: str) -> list:
    """Get all normalized_class keys for a given section."""
    return [k for k, v in ACCOUNT_TAXONOMY.items() if v["section"] == section]


def get_current_assets() -> list:
    return [
        k
        for k, v in ACCOUNT_TAXONOMY.items()
        if v["section"] == BALANCE_SHEET and v.get("current") and not v.get("liability") and not v.get("contra")
    ]


def get_non_current_assets() -> list:
    return [
        k
        for k, v in ACCOUNT_TAXONOMY.items()
        if v["section"] == BALANCE_SHEET and not v.get("current") and not v.get("liability")
    ]


def get_current_liabilities() -> list:
    return [
        k
        for k, v in ACCOUNT_TAXONOMY.items()
        if v["section"] == BALANCE_SHEET and v.get("current") and v.get("liability")
    ]


def get_non_current_liabilities() -> list:
    return [
        k
        for k, v in ACCOUNT_TAXONOMY.items()
        if v["section"] == BALANCE_SHEET and not v.get("current") and v.get("liability")
    ]


def get_equity_classes() -> list:
    return [k for k, v in ACCOUNT_TAXONOMY.items() if v["section"] == EQUITY]


# ─── Industry Benchmarks ────────────────────────────────────────────────────

INDUSTRY_BENCHMARKS = {
    "general": {
        "gross_margin": 35.0,
        "net_margin": 8.0,
        "ebitda_margin": 15.0,
        "roe": 12.0,
        "roa": 6.0,
        "current_ratio": 1.5,
        "quick_ratio": 1.0,
        "debt_to_equity": 1.0,
        "interest_coverage": 3.0,
        "asset_turnover": 1.0,
        "inventory_days": 60,
        "dso": 45,
        "dpo": 30,
    },
    "retail": {
        "gross_margin": 28.0,
        "net_margin": 4.0,
        "ebitda_margin": 10.0,
        "roe": 15.0,
        "roa": 8.0,
        "current_ratio": 1.2,
        "quick_ratio": 0.7,
        "debt_to_equity": 1.5,
        "interest_coverage": 2.5,
        "asset_turnover": 1.8,
        "inventory_days": 45,
        "dso": 20,
        "dpo": 25,
    },
    "manufacturing": {
        "gross_margin": 30.0,
        "net_margin": 7.0,
        "ebitda_margin": 18.0,
        "roe": 13.0,
        "roa": 5.0,
        "current_ratio": 1.8,
        "quick_ratio": 1.0,
        "debt_to_equity": 1.2,
        "interest_coverage": 4.0,
        "asset_turnover": 0.8,
        "inventory_days": 90,
        "dso": 60,
        "dpo": 45,
    },
    "services": {
        "gross_margin": 55.0,
        "net_margin": 12.0,
        "ebitda_margin": 22.0,
        "roe": 20.0,
        "roa": 10.0,
        "current_ratio": 1.3,
        "quick_ratio": 1.2,
        "debt_to_equity": 0.5,
        "interest_coverage": 5.0,
        "asset_turnover": 1.5,
        "inventory_days": 10,
        "dso": 35,
        "dpo": 20,
    },
    "construction": {
        "gross_margin": 20.0,
        "net_margin": 5.0,
        "ebitda_margin": 12.0,
        "roe": 15.0,
        "roa": 4.0,
        "current_ratio": 1.3,
        "quick_ratio": 0.9,
        "debt_to_equity": 1.8,
        "interest_coverage": 2.0,
        "asset_turnover": 0.6,
        "inventory_days": 30,
        "dso": 90,
        "dpo": 60,
    },
    "food_beverage": {
        "gross_margin": 35.0,
        "net_margin": 6.0,
        "ebitda_margin": 14.0,
        "roe": 14.0,
        "roa": 7.0,
        "current_ratio": 1.4,
        "quick_ratio": 0.8,
        "debt_to_equity": 1.0,
        "interest_coverage": 3.5,
        "asset_turnover": 1.2,
        "inventory_days": 40,
        "dso": 25,
        "dpo": 30,
    },
}
