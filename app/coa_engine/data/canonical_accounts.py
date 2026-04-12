"""
APEX COA Engine v4.2 — Canonical Accounts Registry
278+ accounts organized by section with Canonical IDs.
Source: Document Tables 23-37
"""

# Each account: (concept_id, code_pattern, name_ar, name_en, section, nature, level)
# code_pattern is the typical Saudi code prefix for this account type

CANONICAL_ACCOUNTS = [
    # ═══════════════════════════════════════════════════════════
    # ASSETS — Current Assets (codes 10xx-14xx)
    # ═══════════════════════════════════════════════════════════
    ("CASH", "1001", "النقدية", "Cash", "current_asset", "debit", 1),
    ("PETTY_CASH", "1002", "صندوق نثرية", "Petty Cash", "current_asset", "debit", 2),
    ("CASH_IN_HAND", "1003", "نقدية في الصندوق", "Cash in Hand", "current_asset", "debit", 2),
    ("BANK", "1010", "البنوك", "Bank Accounts", "current_asset", "debit", 1),
    ("BANK_LOCAL", "1011", "بنوك محلية", "Local Banks", "current_asset", "debit", 2),
    ("BANK_FOREIGN", "1012", "بنوك خارجية", "Foreign Banks", "current_asset", "debit", 2),
    ("SHORT_TERM_DEPOSITS", "1020", "ودائع قصيرة الأجل", "Short-term Deposits", "current_asset", "debit", 2),
    ("ACC_RECEIVABLE", "1101", "ذمم مدينة تجارية", "Accounts Receivable", "current_asset", "debit", 1),
    ("TRADE_RECEIVABLE", "1102", "ذمم عملاء", "Trade Receivables", "current_asset", "debit", 2),
    ("NOTES_RECEIVABLE", "1103", "أوراق قبض", "Notes Receivable", "current_asset", "debit", 2),
    ("ALLOWANCE_DOUBTFUL", "1109", "مخصص ديون مشكوك فيها", "Allowance for Doubtful Accounts", "current_asset", "credit", 2),
    ("EMPLOYEE_RECEIVABLE", "1110", "ذمم موظفين", "Employee Receivables", "current_asset", "debit", 2),
    ("RELATED_PARTY_REC", "1120", "ذمم أطراف ذات علاقة", "Related Party Receivables", "current_asset", "debit", 2),
    ("OTHER_RECEIVABLE", "1130", "ذمم مدينة أخرى", "Other Receivables", "current_asset", "debit", 2),
    ("INVENTORY", "1200", "المخزون", "Inventory", "current_asset", "debit", 1),
    ("RAW_MATERIALS", "1201", "مواد خام", "Raw Materials", "current_asset", "debit", 2),
    ("WIP", "1202", "إنتاج تحت التشغيل", "Work in Process", "current_asset", "debit", 2),
    ("FINISHED_GOODS", "1203", "بضاعة تامة الصنع", "Finished Goods", "current_asset", "debit", 2),
    ("MERCHANDISE", "1204", "بضاعة جاهزة", "Merchandise", "current_asset", "debit", 2),
    ("INVENTORY_PROVISION", "1209", "مخصص هبوط المخزون", "Inventory Provision", "current_asset", "credit", 2),
    ("PREPAID", "1300", "مصروفات مدفوعة مقدماً", "Prepaid Expenses", "current_asset", "debit", 1),
    ("PREPAID_RENT", "1301", "إيجار مدفوع مقدماً", "Prepaid Rent", "current_asset", "debit", 2),
    ("PREPAID_INSURANCE", "1302", "تأمين مدفوع مقدماً", "Prepaid Insurance", "current_asset", "debit", 2),
    ("ADVANCES_SUPPLIERS", "1310", "دفعات مقدمة للموردين", "Advances to Suppliers", "current_asset", "debit", 2),
    ("ADVANCES_EMPLOYEES", "1320", "سلف موظفين", "Employee Advances", "current_asset", "debit", 2),
    ("DEPOSITS_PAID", "1330", "تأمينات مدفوعة", "Deposits Paid", "current_asset", "debit", 2),
    ("VAT_INPUT", "1340", "ضريبة قيمة مضافة - مدخلات", "VAT Input", "current_asset", "debit", 2),
    ("SHORT_TERM_INV", "1400", "استثمارات قصيرة الأجل", "Short-term Investments", "current_asset", "debit", 1),

    # ═══════════════════════════════════════════════════════════
    # ASSETS — Non-Current Assets (codes 15xx-19xx)
    # ═══════════════════════════════════════════════════════════
    ("PPE", "1500", "ممتلكات ومعدات", "Property, Plant & Equipment", "non_current_asset", "debit", 1),
    ("LAND", "1501", "أراضي", "Land", "non_current_asset", "debit", 2),
    ("BUILDINGS", "1510", "مباني", "Buildings", "non_current_asset", "debit", 2),
    ("EQUIPMENT", "1520", "معدات وآلات", "Machinery & Equipment", "non_current_asset", "debit", 2),
    ("VEHICLES", "1530", "سيارات ومركبات", "Vehicles", "non_current_asset", "debit", 2),
    ("FURNITURE", "1540", "أثاث وتجهيزات", "Furniture & Fixtures", "non_current_asset", "debit", 2),
    ("IT_EQUIPMENT", "1550", "أجهزة حاسب آلي", "IT Equipment", "non_current_asset", "debit", 2),
    ("LEASEHOLD_IMPROVE", "1560", "تحسينات مستأجرة", "Leasehold Improvements", "non_current_asset", "debit", 2),
    ("ACCUM_DEPRECIATION", "1590", "مجمع الإهلاك", "Accumulated Depreciation", "non_current_asset", "credit", 1),
    ("ACCUM_DEP_BUILDINGS", "1591", "مجمع إهلاك مباني", "Accum. Dep. - Buildings", "non_current_asset", "credit", 2),
    ("ACCUM_DEP_EQUIPMENT", "1592", "مجمع إهلاك معدات", "Accum. Dep. - Equipment", "non_current_asset", "credit", 2),
    ("ACCUM_DEP_VEHICLES", "1593", "مجمع إهلاك سيارات", "Accum. Dep. - Vehicles", "non_current_asset", "credit", 2),
    ("ACCUM_DEP_FURNITURE", "1594", "مجمع إهلاك أثاث", "Accum. Dep. - Furniture", "non_current_asset", "credit", 2),
    ("ACCUM_DEP_IT", "1595", "مجمع إهلاك حاسب آلي", "Accum. Dep. - IT Equipment", "non_current_asset", "credit", 2),
    ("CIP", "1600", "مشاريع تحت التنفيذ", "Construction in Progress", "non_current_asset", "debit", 1),
    ("INTANGIBLES", "1700", "أصول غير ملموسة", "Intangible Assets", "non_current_asset", "debit", 1),
    ("GOODWILL", "1701", "شهرة تجارية", "Goodwill", "non_current_asset", "debit", 2),
    ("SOFTWARE", "1710", "برمجيات", "Software", "non_current_asset", "debit", 2),
    ("PATENTS", "1720", "براءات اختراع", "Patents", "non_current_asset", "debit", 2),
    ("TRADEMARKS", "1730", "علامات تجارية", "Trademarks", "non_current_asset", "debit", 2),
    ("LICENSES", "1740", "تراخيص", "Licenses", "non_current_asset", "debit", 2),
    ("ACCUM_AMORTIZATION", "1790", "مجمع استهلاك أصول غير ملموسة", "Accumulated Amortization", "non_current_asset", "credit", 1),
    ("LONG_TERM_INV", "1800", "استثمارات طويلة الأجل", "Long-term Investments", "non_current_asset", "debit", 1),
    ("INV_SUBSIDIARIES", "1810", "استثمارات في شركات تابعة", "Investment in Subsidiaries", "non_current_asset", "debit", 2),
    ("INV_ASSOCIATES", "1820", "استثمارات في شركات شقيقة", "Investment in Associates", "non_current_asset", "debit", 2),
    ("INVESTMENT_PROPERTY", "1830", "عقارات استثمارية", "Investment Property", "non_current_asset", "debit", 2),
    ("ROU_ASSETS", "1900", "أصول حق الاستخدام", "Right-of-Use Assets", "non_current_asset", "debit", 1),
    ("BIO_ASSETS", "1950", "أصول بيولوجية", "Biological Assets", "non_current_asset", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # LIABILITIES — Current (codes 20xx-24xx)
    # ═══════════════════════════════════════════════════════════
    ("ACC_PAYABLE", "2001", "ذمم دائنة تجارية", "Accounts Payable", "current_liability", "credit", 1),
    ("TRADE_PAYABLE", "2002", "ذمم موردين", "Trade Payables", "current_liability", "credit", 2),
    ("NOTES_PAYABLE", "2010", "أوراق دفع", "Notes Payable", "current_liability", "credit", 2),
    ("ACCRUED_EXPENSES", "2100", "مصروفات مستحقة", "Accrued Expenses", "current_liability", "credit", 1),
    ("SALARIES_PAYABLE", "2101", "رواتب مستحقة", "Salaries Payable", "current_liability", "credit", 2),
    ("ACCRUED_VACATION", "2102", "إجازات مستحقة", "Accrued Vacation", "current_liability", "credit", 2),
    ("ACCRUED_BONUS", "2103", "مكافآت مستحقة", "Accrued Bonuses", "current_liability", "credit", 2),
    ("TAX_PAYABLE", "2200", "ضرائب مستحقة", "Tax Payable", "current_liability", "credit", 1),
    ("ZAKAT_PAYABLE", "2201", "زكاة مستحقة", "Zakat Payable", "current_liability", "credit", 2),
    ("VAT_OUTPUT", "2210", "ضريبة قيمة مضافة - مخرجات", "VAT Output", "current_liability", "credit", 2),
    ("WHT_PAYABLE", "2220", "ضريبة استقطاع مستحقة", "Withholding Tax Payable", "current_liability", "credit", 2),
    ("GOSI_PAYABLE", "2230", "تأمينات اجتماعية مستحقة", "GOSI Payable", "current_liability", "credit", 2),
    ("UNEARNED_REVENUE", "2300", "إيرادات مقدمة", "Unearned Revenue", "current_liability", "credit", 1),
    ("CUSTOMER_DEPOSITS", "2310", "أمانات عملاء", "Customer Deposits", "current_liability", "credit", 2),
    ("SHORT_TERM_LOANS", "2400", "قروض قصيرة الأجل", "Short-term Loans", "current_liability", "credit", 1),
    ("BANK_OVERDRAFT", "2410", "سحب على المكشوف", "Bank Overdraft", "current_liability", "credit", 2),
    ("CURRENT_PORTION_LTD", "2420", "الجزء المتداول من القروض طويلة الأجل", "Current Portion of LTD", "current_liability", "credit", 2),
    ("DIVIDENDS_PAYABLE", "2430", "توزيعات أرباح مستحقة", "Dividends Payable", "current_liability", "credit", 2),
    ("RELATED_PARTY_PAY", "2500", "ذمم أطراف ذات علاقة دائنة", "Related Party Payables", "current_liability", "credit", 2),
    ("OTHER_PAYABLE", "2510", "ذمم دائنة أخرى", "Other Payables", "current_liability", "credit", 2),

    # ═══════════════════════════════════════════════════════════
    # LIABILITIES — Non-Current (codes 25xx-29xx)
    # ═══════════════════════════════════════════════════════════
    ("LONG_TERM_LOANS", "2600", "قروض طويلة الأجل", "Long-term Loans", "non_current_liability", "credit", 1),
    ("BONDS_PAYABLE", "2610", "سندات وصكوك", "Bonds/Sukuk Payable", "non_current_liability", "credit", 2),
    ("END_OF_SERVICE", "2700", "مكافأة نهاية الخدمة", "End of Service Benefits", "non_current_liability", "credit", 1),
    ("LEASE_LIABILITY", "2800", "التزامات عقود الإيجار", "Lease Liabilities", "non_current_liability", "credit", 1),
    ("DEFERRED_TAX", "2900", "ضرائب مؤجلة", "Deferred Tax Liability", "non_current_liability", "credit", 2),
    ("PROVISIONS", "2910", "مخصصات", "Provisions", "non_current_liability", "credit", 1),
    ("PROVISION_LITIGATION", "2911", "مخصص قضايا", "Provision for Litigation", "non_current_liability", "credit", 2),

    # ═══════════════════════════════════════════════════════════
    # EQUITY (codes 3xxx)
    # ═══════════════════════════════════════════════════════════
    ("SHARE_CAPITAL", "3001", "رأس المال", "Share Capital", "equity", "credit", 1),
    ("PAID_IN_CAPITAL", "3010", "رأس مال مدفوع", "Paid-in Capital", "equity", "credit", 2),
    ("SHARE_PREMIUM", "3020", "علاوة إصدار", "Share Premium", "equity", "credit", 2),
    ("STATUTORY_RESERVE", "3100", "احتياطي نظامي", "Statutory Reserve", "equity", "credit", 2),
    ("GENERAL_RESERVE", "3110", "احتياطي عام", "General Reserve", "equity", "credit", 2),
    ("CONTRACTUAL_RESERVE", "3120", "احتياطي اتفاقي", "Contractual Reserve", "equity", "credit", 2),
    ("RESERVES", "3100", "احتياطيات", "Reserves", "equity", "credit", 1),
    ("RETAINED_EARNINGS", "3200", "أرباح مبقاة", "Retained Earnings", "equity", "credit", 1),
    ("ACCUMULATED_LOSSES", "3210", "خسائر متراكمة", "Accumulated Losses", "equity", "debit", 2),
    ("CURRENT_YEAR_PROFIT", "3220", "أرباح العام الحالي", "Current Year Profit/Loss", "equity", "credit", 2),
    ("OWNER_DRAWINGS", "3300", "مسحوبات شخصية", "Owner Drawings", "equity", "debit", 1),
    ("PARTNER_CURRENT", "3310", "جاري الشركاء", "Partner Current Accounts", "equity", "debit", 2),
    ("DIVIDENDS", "3400", "توزيعات أرباح", "Dividends", "equity", "debit", 2),
    ("TREASURY_SHARES", "3500", "أسهم خزينة", "Treasury Shares", "equity", "debit", 2),
    ("OCI", "3600", "الدخل الشامل الآخر", "Other Comprehensive Income", "equity", "credit", 1),
    ("FVOCI_RESERVE", "3610", "احتياطي القيمة العادلة", "FVOCI Reserve", "equity", "credit", 2),
    ("TRANSLATION_RESERVE", "3620", "احتياطي ترجمة عملات", "Translation Reserve", "equity", "credit", 2),

    # ═══════════════════════════════════════════════════════════
    # REVENUE (codes 4xxx)
    # ═══════════════════════════════════════════════════════════
    ("SALES_REVENUE", "4001", "إيرادات المبيعات", "Sales Revenue", "operating_revenue", "credit", 1),
    ("PRODUCT_SALES", "4010", "مبيعات بضائع", "Product Sales", "operating_revenue", "credit", 2),
    ("SERVICE_REVENUE", "4020", "إيرادات خدمات", "Service Revenue", "operating_revenue", "credit", 2),
    ("CONTRACT_REVENUE", "4030", "إيرادات عقود", "Contract Revenue", "operating_revenue", "credit", 2),
    ("SUBSCRIPTION_REV", "4040", "إيرادات اشتراكات", "Subscription Revenue", "operating_revenue", "credit", 2),
    ("SALES_RETURNS", "4100", "مردودات مبيعات", "Sales Returns", "operating_revenue", "debit", 2),
    ("SALES_DISCOUNTS", "4110", "خصم مبيعات", "Sales Discounts", "operating_revenue", "debit", 2),
    ("SALES_ALLOWANCES", "4120", "مسموحات مبيعات", "Sales Allowances", "operating_revenue", "debit", 2),
    ("OTHER_REVENUE", "4400", "إيرادات أخرى", "Other Revenue", "other_revenue", "credit", 1),
    ("INVESTMENT_INCOME", "4410", "إيرادات استثمارات", "Investment Income", "other_revenue", "credit", 2),
    ("RENTAL_INCOME", "4420", "إيرادات إيجارات", "Rental Income", "other_revenue", "credit", 2),
    ("GAIN_DISPOSAL", "4430", "أرباح بيع أصول", "Gain on Disposal", "other_revenue", "credit", 2),
    ("FX_GAIN", "4440", "أرباح فروقات عملة", "Foreign Exchange Gain", "other_revenue", "credit", 2),
    ("COMMISSION_INCOME", "4450", "إيرادات عمولات", "Commission Income", "other_revenue", "credit", 2),

    # ═══════════════════════════════════════════════════════════
    # COGS (codes 50xx-53xx)
    # ═══════════════════════════════════════════════════════════
    ("COGS", "5001", "تكلفة المبيعات", "Cost of Goods Sold", "cogs", "debit", 1),
    ("PURCHASES", "5010", "مشتريات", "Purchases", "cogs", "debit", 2),
    ("PURCHASE_RETURNS", "5020", "مردودات مشتريات", "Purchase Returns", "cogs", "credit", 2),
    ("PURCHASE_DISCOUNTS", "5030", "خصم مشتريات", "Purchase Discounts", "cogs", "credit", 2),
    ("DIRECT_LABOR", "5100", "عمالة مباشرة", "Direct Labor", "cogs", "debit", 2),
    ("MFG_OVERHEAD", "5200", "تكاليف صناعية غير مباشرة", "Manufacturing Overhead", "cogs", "debit", 2),
    ("FREIGHT_IN", "5300", "مصاريف نقل مشتريات", "Freight In", "cogs", "debit", 2),
    ("CUSTOMS", "5310", "رسوم جمركية", "Customs Duties", "cogs", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # OPERATING EXPENSES (codes 54xx-59xx)
    # ═══════════════════════════════════════════════════════════
    ("SALARIES_EXPENSE", "5400", "رواتب وأجور", "Salaries & Wages", "operating_expense", "debit", 1),
    ("EMPLOYEE_BENEFITS", "5410", "مزايا موظفين", "Employee Benefits", "operating_expense", "debit", 2),
    ("EOS_EXPENSE", "5420", "مصروف مكافأة نهاية خدمة", "EOS Expense", "operating_expense", "debit", 2),
    ("RENT_EXPENSE", "5500", "إيجارات", "Rent Expense", "operating_expense", "debit", 2),
    ("UTILITIES", "5510", "مرافق (كهرباء وماء)", "Utilities", "operating_expense", "debit", 2),
    ("TELECOM_EXP", "5520", "اتصالات وإنترنت", "Telecom & Internet", "operating_expense", "debit", 2),
    ("OFFICE_SUPPLIES", "5530", "مستلزمات مكتبية", "Office Supplies", "operating_expense", "debit", 2),
    ("DEPRECIATION_EXP", "5600", "مصروف إهلاك", "Depreciation Expense", "operating_expense", "debit", 2),
    ("AMORTIZATION_EXP", "5610", "مصروف استهلاك", "Amortization Expense", "operating_expense", "debit", 2),
    ("MAINTENANCE_EXP", "5700", "صيانة وإصلاح", "Maintenance & Repairs", "operating_expense", "debit", 2),
    ("PROFESSIONAL_FEES", "5710", "أتعاب مهنية", "Professional Fees", "operating_expense", "debit", 2),
    ("CONSULTING_EXP", "5720", "استشارات", "Consulting Expenses", "operating_expense", "debit", 2),

    # Selling Expenses (codes 60xx-63xx)
    ("MARKETING_EXP", "6000", "مصاريف تسويق", "Marketing Expenses", "selling_expense", "debit", 1),
    ("ADVERTISING", "6010", "دعاية وإعلان", "Advertising", "selling_expense", "debit", 2),
    ("SALES_COMMISSION", "6020", "عمولات مبيعات", "Sales Commissions", "selling_expense", "debit", 2),
    ("FREIGHT_OUT", "6030", "مصاريف نقل مبيعات", "Freight Out", "selling_expense", "debit", 2),
    ("EXHIBITIONS_EXP", "6040", "معارض ومؤتمرات", "Exhibitions", "selling_expense", "debit", 2),

    # Administrative Expenses (codes 64xx-69xx)
    ("ADMIN_EXPENSE", "6400", "مصاريف إدارية وعمومية", "G&A Expenses", "admin_expense", "debit", 1),
    ("TRAVEL_EXP", "6410", "سفر وانتقالات", "Travel Expenses", "admin_expense", "debit", 2),
    ("TRAINING_EXP", "6420", "تدريب وتطوير", "Training & Development", "admin_expense", "debit", 2),
    ("LEGAL_EXP", "6430", "مصاريف قانونية", "Legal Expenses", "admin_expense", "debit", 2),
    ("INSURANCE_EXP", "6440", "تأمين", "Insurance Expense", "admin_expense", "debit", 2),
    ("AUDIT_EXP", "6450", "مراجعة وتدقيق", "Audit Fees", "admin_expense", "debit", 2),
    ("GOV_FEES", "6460", "رسوم حكومية", "Government Fees", "admin_expense", "debit", 2),
    ("LICENSES_EXP", "6470", "تراخيص ورخص", "License Fees", "admin_expense", "debit", 2),
    ("SUBSCRIPTION_EXP", "6480", "اشتراكات", "Subscriptions", "admin_expense", "debit", 2),
    ("BAD_DEBT_EXP", "6490", "مصروف ديون معدومة", "Bad Debt Expense", "admin_expense", "debit", 2),
    ("DONATION_EXP", "6500", "تبرعات وهبات", "Donations", "admin_expense", "debit", 2),
    ("PENALTY_EXP", "6510", "غرامات وجزاءات", "Penalties & Fines", "admin_expense", "debit", 2),
    ("LOSS_DISPOSAL", "6520", "خسائر بيع أصول", "Loss on Disposal", "admin_expense", "debit", 2),
    ("FX_LOSS", "6530", "خسائر فروقات عملة", "Foreign Exchange Loss", "admin_expense", "debit", 2),
    ("MISC_EXPENSE", "6900", "مصاريف متنوعة", "Miscellaneous Expenses", "admin_expense", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # FINANCE COSTS (codes 7xxx)
    # ═══════════════════════════════════════════════════════════
    ("INTEREST_EXP", "7001", "مصاريف فوائد", "Interest Expense", "finance_cost", "debit", 1),
    ("MURABAHA_COST", "7010", "تكلفة مرابحات", "Murabaha Cost", "finance_cost", "debit", 2),
    ("BANK_CHARGES", "7020", "عمولات بنكية", "Bank Charges", "finance_cost", "debit", 2),
    ("LEASE_INTEREST", "7030", "فوائد عقود إيجار", "Lease Interest", "finance_cost", "debit", 2),
    ("LC_CHARGES", "7040", "مصاريف اعتمادات مستندية", "LC Charges", "finance_cost", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # TAX EXPENSE (codes 8xxx)
    # ═══════════════════════════════════════════════════════════
    ("INCOME_TAX", "8001", "ضريبة دخل", "Income Tax", "tax_expense", "debit", 1),
    ("ZAKAT", "8010", "زكاة", "Zakat", "tax_expense", "debit", 2),
    ("DEFERRED_TAX_EXP", "8020", "مصروف ضريبة مؤجلة", "Deferred Tax Expense", "tax_expense", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # CLOSING ACCOUNTS (codes 9xxx)
    # ═══════════════════════════════════════════════════════════
    ("INCOME_SUMMARY", "9001", "ملخص الدخل", "Income Summary", "closing", "debit", 1),
    ("CLEARING_ACCOUNT", "9010", "حساب مقاصة", "Clearing Account", "closing", "debit", 2),
    ("SUSPENSE", "9020", "حساب معلق", "Suspense Account", "closing", "debit", 2),
    ("OPENING_BALANCE", "9030", "أرصدة افتتاحية", "Opening Balance", "closing", "debit", 2),

    # ═══════════════════════════════════════════════════════════
    # SECTOR-SPECIFIC ACCOUNTS (common across multiple sectors)
    # ═══════════════════════════════════════════════════════════
    # Healthcare
    ("MEDICAL_EQUIPMENT", "1551", "أجهزة طبية", "Medical Equipment", "non_current_asset", "debit", 2),
    ("PHARMA_INVENTORY", "1205", "مخزون أدوية", "Pharmaceutical Inventory", "current_asset", "debit", 2),
    ("MEDICAL_REV", "4050", "إيرادات طبية", "Medical Revenue", "operating_revenue", "credit", 2),

    # Insurance
    ("UNEARNED_PREMIUM", "2301", "أقساط غير مكتسبة", "Unearned Premiums", "current_liability", "credit", 2),
    ("CLAIMS_RESERVE", "2920", "مخصص مطالبات", "Claims Reserve", "non_current_liability", "credit", 2),
    ("TECH_RESERVE", "2921", "احتياطي فني", "Technical Reserve", "non_current_liability", "credit", 2),
    ("REINSURANCE", "1140", "إعادة تأمين", "Reinsurance Receivable", "current_asset", "debit", 2),

    # Banking/Islamic Finance
    ("MURABAHA_FIN", "1150", "تمويل مرابحات", "Murabaha Financing", "current_asset", "debit", 2),
    ("ECL_STAGE1", "1160", "مخصص خسائر ائتمانية - المرحلة 1", "ECL Stage 1", "current_asset", "credit", 2),
    ("ECL_STAGE2", "1161", "مخصص خسائر ائتمانية - المرحلة 2", "ECL Stage 2", "current_asset", "credit", 2),
    ("CUSTOMER_DEP", "2320", "ودائع عملاء", "Customer Deposits", "current_liability", "credit", 2),
    ("BANK_REV", "4060", "إيرادات مصرفية", "Banking Revenue", "operating_revenue", "credit", 2),

    # Construction
    ("RETENTIONS", "1141", "محتجزات", "Retentions Receivable", "current_asset", "debit", 2),

    # Hajj & Umrah
    ("HAJJ_REV", "4070", "إيرادات حج", "Hajj Revenue", "operating_revenue", "credit", 2),
    ("HAJJ_COST", "5110", "تكلفة خدمات حج", "Hajj Service Cost", "cogs", "debit", 2),
    ("PILGRIMS_DEPOSITS", "2330", "أمانات حجاج", "Pilgrims Deposits", "current_liability", "credit", 2),
    ("VISA_FEES", "5320", "رسوم تأشيرات", "Visa Fees", "cogs", "debit", 2),

    # Aviation
    ("AIRCRAFT", "1570", "طائرات", "Aircraft", "non_current_asset", "debit", 2),
    ("TICKET_REV", "4080", "إيرادات تذاكر", "Ticket Revenue", "operating_revenue", "credit", 2),

    # Technology/AI
    ("GPU_SERVERS", "1560", "خوادم GPU", "GPU Servers", "non_current_asset", "debit", 2),
    ("AI_LICENSES", "1741", "تراخيص ذكاء اصطناعي", "AI Licenses", "non_current_asset", "debit", 2),
    ("AI_REV", "4090", "إيرادات ذكاء اصطناعي", "AI Revenue", "operating_revenue", "credit", 2),

    # Oil & Gas
    ("OIL_WELLS", "1580", "آبار نفط", "Oil Wells", "non_current_asset", "debit", 2),
    ("DEPLETION", "5620", "نضوب", "Depletion Expense", "operating_expense", "debit", 2),
    ("ROYALTIES", "5330", "إتاوات", "Royalties", "cogs", "debit", 2),
    ("EXPLORATION_COSTS", "1610", "تكاليف استكشاف", "Exploration Costs", "non_current_asset", "debit", 2),

    # E-Commerce
    ("PLATFORM_FEES", "5340", "رسوم منصة", "Platform Fees", "cogs", "debit", 2),
    ("DELIVERY_COSTS", "6050", "تكاليف توصيل", "Delivery Costs", "selling_expense", "debit", 2),

    # Non-profit
    ("DONATIONS_REV", "4500", "تبرعات واردة", "Donations Revenue", "operating_revenue", "credit", 2),
    ("GRANTS_REV", "4510", "منح ودعم", "Grants Revenue", "operating_revenue", "credit", 2),

    # Holding Companies
    ("MGMT_FEES", "4520", "رسوم إدارة", "Management Fees Revenue", "operating_revenue", "credit", 2),
]

# Build lookup indexes for fast access
CONCEPT_INDEX = {acct[0]: acct for acct in CANONICAL_ACCOUNTS}
CODE_PATTERN_INDEX = {acct[1]: acct[0] for acct in CANONICAL_ACCOUNTS}


def get_account_by_concept(concept_id: str):
    """Get canonical account by concept_id."""
    return CONCEPT_INDEX.get(concept_id)


def get_concept_by_code_pattern(code_pattern: str):
    """Get concept_id by code pattern."""
    return CODE_PATTERN_INDEX.get(code_pattern)


def get_accounts_by_section(section: str):
    """Get all canonical accounts in a section."""
    return [a for a in CANONICAL_ACCOUNTS if a[4] == section]


def get_mandatory_for_sector(sector_code: str):
    """Get mandatory concept_ids for a sector. Requires sectors.py data."""
    from app.coa_engine.data.sectors import SECTORS
    sector = next((s for s in SECTORS if s["code"] == sector_code), None)
    if not sector:
        return []
    return sector.get("mandatory_accounts", [])
