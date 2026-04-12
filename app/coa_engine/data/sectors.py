"""
APEX COA Engine v4.2 — Sector Dictionary (Section 7)
45 Saudi sectors with regulatory bodies and mandatory accounts.
"""

SECTORS = [
    # 1
    {
        "code": "RETAIL",
        "name_ar": "تجارة التجزئة/الجملة",
        "name_en": "Retail/Wholesale",
        "regulatory_body": "وزارة التجارة",
        "mandatory_accounts": ["INVENTORY", "COGS", "SALES_RETURNS", "PURCHASE_RETURNS"],
    },
    # 2
    {
        "code": "CONSTRUCTION",
        "name_ar": "مقاولات وتشييد",
        "name_en": "Construction",
        "regulatory_body": "وزارة الشؤون البلدية",
        "mandatory_accounts": ["CIP", "DIRECT_LABOR", "RAW_MATERIALS", "RETENTIONS"],
    },
    # 3
    {
        "code": "MANUFACTURING",
        "name_ar": "صناعة",
        "name_en": "Manufacturing",
        "regulatory_body": "وزارة الصناعة",
        "mandatory_accounts": ["RAW_MATERIALS", "WIP", "FINISHED_GOODS", "MFG_OVERHEAD"],
    },
    # 4
    {
        "code": "REAL_ESTATE",
        "name_ar": "عقارات",
        "name_en": "Real Estate",
        "regulatory_body": "الهيئة العامة للعقار",
        "mandatory_accounts": ["INVESTMENT_PROPERTY", "LAND", "BUILDINGS", "CIP"],
    },
    # 5
    {
        "code": "HEALTHCARE",
        "name_ar": "رعاية صحية",
        "name_en": "Healthcare",
        "regulatory_body": "وزارة الصحة",
        "mandatory_accounts": ["MEDICAL_EQUIPMENT", "PHARMA_INVENTORY", "MEDICAL_REV"],
    },
    # 6
    {
        "code": "EDUCATION",
        "name_ar": "تعليم",
        "name_en": "Education",
        "regulatory_body": "وزارة التعليم",
        "mandatory_accounts": ["UNEARNED_REVENUE", "SERVICE_REVENUE", "PREPAID"],
    },
    # 7
    {
        "code": "EDUCATION_PRIVATE",
        "name_ar": "تعليم خاص",
        "name_en": "Private Education",
        "regulatory_body": "وزارة التعليم",
        "mandatory_accounts": ["UNEARNED_REVENUE", "SERVICE_REVENUE", "CUSTOMER_DEPOSITS"],
    },
    # 8
    {
        "code": "TECHNOLOGY",
        "name_ar": "تقنية معلومات",
        "name_en": "Technology",
        "regulatory_body": "هيئة الاتصالات وتقنية المعلومات",
        "mandatory_accounts": ["SOFTWARE", "INTANGIBLES", "SUBSCRIPTION_REV"],
    },
    # 9
    {
        "code": "FOOD_BEV",
        "name_ar": "أغذية ومشروبات",
        "name_en": "Food & Beverages",
        "regulatory_body": "هيئة الغذاء والدواء",
        "mandatory_accounts": ["RAW_MATERIALS", "INVENTORY", "COGS"],
    },
    # 10
    {
        "code": "TRANSPORT",
        "name_ar": "نقل",
        "name_en": "Transport",
        "regulatory_body": "هيئة النقل العام",
        "mandatory_accounts": ["VEHICLES", "FREIGHT_OUT", "SERVICE_REVENUE"],
    },
    # 11
    {
        "code": "AGRICULTURE",
        "name_ar": "زراعة",
        "name_en": "Agriculture",
        "regulatory_body": "وزارة البيئة والمياه والزراعة",
        "mandatory_accounts": ["BIO_ASSETS", "INVENTORY", "SALES_REVENUE"],
    },
    # 12
    {
        "code": "INSURANCE",
        "name_ar": "تأمين",
        "name_en": "Insurance",
        "regulatory_body": "البنك المركزي السعودي (ساما)",
        "mandatory_accounts": ["UNEARNED_PREMIUM", "CLAIMS_RESERVE", "TECH_RESERVE", "REINSURANCE"],
    },
    # 13
    {
        "code": "BANKING",
        "name_ar": "بنوك وتمويل",
        "name_en": "Banking & Finance",
        "regulatory_body": "البنك المركزي السعودي (ساما)",
        "mandatory_accounts": ["MURABAHA_FIN", "ECL_STAGE1", "ECL_STAGE2", "CUSTOMER_DEP", "BANK_REV"],
    },
    # 14
    {
        "code": "TELECOM",
        "name_ar": "اتصالات",
        "name_en": "Telecommunications",
        "regulatory_body": "هيئة الاتصالات وتقنية المعلومات",
        "mandatory_accounts": ["LICENSES", "INTANGIBLES", "SUBSCRIPTION_REV", "UNEARNED_REVENUE"],
    },
    # 15
    {
        "code": "OIL_GAS",
        "name_ar": "نفط وغاز",
        "name_en": "Oil & Gas",
        "regulatory_body": "وزارة الطاقة",
        "mandatory_accounts": ["OIL_WELLS", "DEPLETION", "ROYALTIES", "EXPLORATION_COSTS"],
    },
    # 16
    {
        "code": "TOURISM",
        "name_ar": "سياحة وفندقة",
        "name_en": "Tourism & Hospitality",
        "regulatory_body": "وزارة السياحة",
        "mandatory_accounts": ["UNEARNED_REVENUE", "FURNITURE", "SERVICE_REVENUE"],
    },
    # 17
    {
        "code": "HAJJ_UMRAH",
        "name_ar": "حج وعمرة",
        "name_en": "Hajj & Umrah",
        "regulatory_body": "وزارة الحج والعمرة",
        "mandatory_accounts": ["HAJJ_REV", "HAJJ_COST", "PILGRIMS_DEPOSITS", "VISA_FEES"],
    },
    # 18
    {
        "code": "AVIATION",
        "name_ar": "طيران",
        "name_en": "Aviation",
        "regulatory_body": "هيئة الطيران المدني",
        "mandatory_accounts": ["AIRCRAFT", "TICKET_REV", "LEASE_LIABILITY", "SALARIES_EXPENSE"],
    },
    # 19
    {
        "code": "FINTECH",
        "name_ar": "تقنية مالية",
        "name_en": "Fintech",
        "regulatory_body": "البنك المركزي السعودي (ساما)",
        "mandatory_accounts": ["SOFTWARE", "PLATFORM_FEES", "SUBSCRIPTION_REV"],
    },
    # 20
    {
        "code": "AI",
        "name_ar": "ذكاء اصطناعي",
        "name_en": "Artificial Intelligence",
        "regulatory_body": "هيئة البيانات والذكاء الاصطناعي",
        "mandatory_accounts": ["GPU_SERVERS", "AI_LICENSES", "AI_REV"],
    },
    # 21
    {
        "code": "WATER",
        "name_ar": "مياه ومعالجة",
        "name_en": "Water & Treatment",
        "regulatory_body": "هيئة تنظيم المياه",
        "mandatory_accounts": ["EQUIPMENT", "PPE", "SERVICE_REVENUE"],
    },
    # 22
    {
        "code": "RECRUITMENT",
        "name_ar": "استقدام وتوظيف",
        "name_en": "Recruitment",
        "regulatory_body": "وزارة الموارد البشرية",
        "mandatory_accounts": ["VISA_FEES", "SERVICE_REVENUE", "UNEARNED_REVENUE"],
    },
    # 23
    {
        "code": "BROKERAGE",
        "name_ar": "وساطة مالية",
        "name_en": "Brokerage",
        "regulatory_body": "هيئة السوق المالية",
        "mandatory_accounts": ["COMMISSION_INCOME", "SHORT_TERM_INV", "CUSTOMER_DEPOSITS"],
    },
    # 24
    {
        "code": "ECOMMERCE",
        "name_ar": "تجارة إلكترونية",
        "name_en": "E-Commerce",
        "regulatory_body": "وزارة التجارة",
        "mandatory_accounts": ["INVENTORY", "UNEARNED_REVENUE", "PLATFORM_FEES", "DELIVERY_COSTS"],
    },
    # 25
    {
        "code": "RESTAURANTS",
        "name_ar": "مطاعم",
        "name_en": "Restaurants",
        "regulatory_body": "هيئة الغذاء والدواء",
        "mandatory_accounts": ["RAW_MATERIALS", "EQUIPMENT", "SALES_REVENUE"],
    },
    # 26
    {
        "code": "ENTERTAINMENT",
        "name_ar": "ترفيه",
        "name_en": "Entertainment",
        "regulatory_body": "هيئة الترفيه",
        "mandatory_accounts": ["UNEARNED_REVENUE", "SERVICE_REVENUE", "EQUIPMENT"],
    },
    # 27
    {
        "code": "PHARMA",
        "name_ar": "صناعة دوائية",
        "name_en": "Pharmaceuticals",
        "regulatory_body": "هيئة الغذاء والدواء",
        "mandatory_accounts": ["PHARMA_INVENTORY", "INVENTORY", "SALES_REVENUE"],
    },
    # 28
    {
        "code": "MEDIA",
        "name_ar": "إعلام ونشر",
        "name_en": "Media & Publishing",
        "regulatory_body": "هيئة الإعلام",
        "mandatory_accounts": ["INTANGIBLES", "SOFTWARE", "SERVICE_REVENUE"],
    },
    # 29
    {
        "code": "MINING",
        "name_ar": "تعدين",
        "name_en": "Mining",
        "regulatory_body": "وزارة الصناعة والثروة المعدنية",
        "mandatory_accounts": ["EQUIPMENT", "DEPLETION", "EXPLORATION_COSTS"],
    },
    # 30
    {
        "code": "BEAUTY",
        "name_ar": "تجميل وعناية",
        "name_en": "Beauty & Personal Care",
        "regulatory_body": "هيئة الغذاء والدواء",
        "mandatory_accounts": ["INVENTORY", "EQUIPMENT", "SALES_REVENUE"],
    },
    # 31
    {
        "code": "ENVIRONMENTAL",
        "name_ar": "خدمات بيئية",
        "name_en": "Environmental Services",
        "regulatory_body": "المركز الوطني للرقابة البيئية",
        "mandatory_accounts": ["EQUIPMENT", "SERVICE_REVENUE", "PROFESSIONAL_FEES"],
    },
    # 32
    {
        "code": "PRINTING",
        "name_ar": "طباعة ونشر",
        "name_en": "Printing & Publishing",
        "regulatory_body": "وزارة الإعلام",
        "mandatory_accounts": ["INVENTORY", "EQUIPMENT", "SALES_REVENUE"],
    },
    # 33
    {
        "code": "PETROLEUM",
        "name_ar": "مشتقات نفطية",
        "name_en": "Petroleum Products",
        "regulatory_body": "وزارة الطاقة",
        "mandatory_accounts": ["INVENTORY", "EQUIPMENT", "SALES_REVENUE"],
    },
    # 34
    {
        "code": "SHIPPING",
        "name_ar": "شحن بحري",
        "name_en": "Shipping & Maritime",
        "regulatory_body": "هيئة النقل العام",
        "mandatory_accounts": ["VEHICLES", "FREIGHT_OUT", "SERVICE_REVENUE"],
    },
    # 35
    {
        "code": "CONSULTING",
        "name_ar": "استشارات",
        "name_en": "Consulting & Professional Services",
        "regulatory_body": "وزارة التجارة",
        "mandatory_accounts": ["PROFESSIONAL_FEES", "SERVICE_REVENUE", "ACC_RECEIVABLE"],
    },
    # 36
    {
        "code": "CONTRACTING",
        "name_ar": "مقاولات عامة",
        "name_en": "General Contracting",
        "regulatory_body": "وزارة الشؤون البلدية",
        "mandatory_accounts": ["CIP", "DIRECT_LABOR", "RAW_MATERIALS", "EQUIPMENT"],
    },
    # 37
    {
        "code": "TRADING",
        "name_ar": "تجارة عامة",
        "name_en": "General Trading",
        "regulatory_body": "وزارة التجارة",
        "mandatory_accounts": ["INVENTORY", "COGS", "PURCHASES", "MERCHANDISE"],
    },
    # 38
    {
        "code": "EDUCATION_TRAINING",
        "name_ar": "تدريب وتأهيل",
        "name_en": "Training & Development",
        "regulatory_body": "المؤسسة العامة للتدريب التقني والمهني",
        "mandatory_accounts": ["UNEARNED_REVENUE", "SERVICE_REVENUE", "TRAINING_EXP"],
    },
    # 39
    {
        "code": "SPORTS",
        "name_ar": "رياضة",
        "name_en": "Sports & Fitness",
        "regulatory_body": "وزارة الرياضة",
        "mandatory_accounts": ["UNEARNED_REVENUE", "SERVICE_REVENUE", "EQUIPMENT"],
    },
    # 40
    {
        "code": "FACILITY_MGMT",
        "name_ar": "إدارة مرافق",
        "name_en": "Facility Management",
        "regulatory_body": "وزارة الشؤون البلدية",
        "mandatory_accounts": ["MAINTENANCE_EXP", "EQUIPMENT", "SERVICE_REVENUE"],
    },
    # 41
    {
        "code": "POSTAL",
        "name_ar": "بريد وتوصيل",
        "name_en": "Postal & Delivery",
        "regulatory_body": "هيئة الاتصالات وتقنية المعلومات",
        "mandatory_accounts": ["VEHICLES", "DELIVERY_COSTS", "SERVICE_REVENUE"],
    },
    # 42
    {
        "code": "SECURITY",
        "name_ar": "حراسات أمنية",
        "name_en": "Security Services",
        "regulatory_body": "وزارة الداخلية",
        "mandatory_accounts": ["EQUIPMENT", "SALARIES_EXPENSE", "SERVICE_REVENUE"],
    },
    # 43
    {
        "code": "AUTO_MAINTENANCE",
        "name_ar": "صيانة سيارات",
        "name_en": "Auto Maintenance",
        "regulatory_body": "وزارة التجارة",
        "mandatory_accounts": ["INVENTORY", "EQUIPMENT", "SERVICE_REVENUE"],
    },
    # 44
    {
        "code": "CHARITY",
        "name_ar": "جمعيات خيرية",
        "name_en": "Charity / Non-profit",
        "regulatory_body": "المركز الوطني لتنمية القطاع غير الربحي",
        "mandatory_accounts": ["DONATIONS_REV", "GRANTS_REV", "SALARIES_EXPENSE"],
    },
    # 45
    {
        "code": "HOLDING",
        "name_ar": "شركات قابضة",
        "name_en": "Holding Companies",
        "regulatory_body": "هيئة السوق المالية",
        "mandatory_accounts": ["INV_SUBSIDIARIES", "INV_ASSOCIATES", "MGMT_FEES"],
    },
    # 46
    {
        "code": "LOGISTICS",
        "name_ar": "خدمات لوجستية",
        "name_en": "Logistics",
        "regulatory_body": "هيئة النقل العام",
        "mandatory_accounts": ["INVENTORY", "VEHICLES", "FREIGHT_OUT", "SERVICE_REVENUE"],
    },
]


# ═══════════════════════════════════════════════════════════════
# Common Mandatory Accounts
# ═══════════════════════════════════════════════════════════════
# These accounts are expected in 95%+ of companies regardless of sector.
# Missing common accounts generate a general warning (not E46).
COMMON_MANDATORY_ACCOUNTS = [
    "CASH", "BANK", "ACC_RECEIVABLE", "INVENTORY", "PREPAID",
    "PPE", "ACCUM_DEPRECIATION", "ACC_PAYABLE", "ACCRUED_EXPENSES",
    "TAX_PAYABLE", "VAT_INPUT", "VAT_OUTPUT", "SHARE_CAPITAL",
    "RETAINED_EARNINGS", "SALES_REVENUE", "COGS", "SALARIES_EXPENSE",
    "RENT_EXPENSE", "DEPRECIATION_EXP", "BANK_CHARGES", "INCOME_TAX",
    "NOTES_RECEIVABLE", "ALLOWANCE_DOUBTFUL", "OTHER_RECEIVABLE",
    "ADVANCES_EMPLOYEES", "DEPOSITS_PAID", "LAND", "BUILDINGS",
    "EQUIPMENT", "VEHICLES", "FURNITURE", "NOTES_PAYABLE",
    "SALARIES_PAYABLE", "GOSI_PAYABLE", "UNEARNED_REVENUE",
    "SHORT_TERM_LOANS", "END_OF_SERVICE", "STATUTORY_RESERVE",
    "OTHER_REVENUE", "PURCHASES", "UTILITIES", "MARKETING_EXP",
    "PROFESSIONAL_FEES", "INTEREST_EXP",
]


# Build sector lookup indexes
SECTOR_INDEX = {s["code"]: s for s in SECTORS}


def get_sector(code: str):
    """Get sector dict by code."""
    return SECTOR_INDEX.get(code)


def get_all_sector_codes():
    """Get list of all sector codes."""
    return [s["code"] for s in SECTORS]
