"""
Authority Registry — سجل الجهات المرجعية الرسمية
═════════════════════════════════════════════════════

كل جهة لها: كود، اسم، نطاق، أولوية، مجالات
"""

AUTHORITIES = {
    "ZATCA": {
        "name_ar": "هيئة الزكاة والضريبة والجمارك",
        "name_en": "Zakat, Tax and Customs Authority",
        "jurisdiction": "sa",
        "domain_scope": ["tax", "customs"],
        "official_urls": ["zatca.gov.sa"],
        "source_priority": 1,
        "update_frequency": "monthly",
    },
    "SOCPA": {
        "name_ar": "الهيئة السعودية للمراجعين والمحاسبين",
        "name_en": "Saudi Organization for Chartered and Professional Accountants",
        "jurisdiction": "sa",
        "domain_scope": ["accounting_audit"],
        "official_urls": ["socpa.org.sa"],
        "source_priority": 1,
        "update_frequency": "quarterly",
    },
    "MOC": {
        "name_ar": "وزارة التجارة",
        "name_en": "Ministry of Commerce",
        "jurisdiction": "sa",
        "domain_scope": ["governance", "companies", "commerce"],
        "official_urls": ["mc.gov.sa", "qawaem.mc.gov.sa"],
        "source_priority": 1,
        "update_frequency": "quarterly",
    },
    "MISA": {
        "name_ar": "وزارة الاستثمار",
        "name_en": "Ministry of Investment",
        "jurisdiction": "sa",
        "domain_scope": ["investment"],
        "official_urls": ["misa.gov.sa"],
        "source_priority": 1,
        "update_frequency": "quarterly",
    },
    "CMA": {
        "name_ar": "هيئة السوق المالية",
        "name_en": "Capital Market Authority",
        "jurisdiction": "sa",
        "domain_scope": ["capital_markets", "governance"],
        "official_urls": ["cma.org.sa"],
        "source_priority": 1,
        "update_frequency": "monthly",
    },
    "SAMA": {
        "name_ar": "البنك المركزي السعودي",
        "name_en": "Saudi Central Bank",
        "jurisdiction": "sa",
        "domain_scope": ["finance", "banking", "insurance", "fintech"],
        "official_urls": ["sama.gov.sa"],
        "source_priority": 1,
        "update_frequency": "quarterly",
    },
    "HRSD": {
        "name_ar": "وزارة الموارد البشرية والتنمية الاجتماعية",
        "name_en": "Ministry of Human Resources and Social Development",
        "jurisdiction": "sa",
        "domain_scope": ["hr", "labor"],
        "official_urls": ["hrsd.gov.sa"],
        "source_priority": 1,
        "update_frequency": "quarterly",
    },
    "GOSI": {
        "name_ar": "المؤسسة العامة للتأمينات الاجتماعية",
        "name_en": "General Organization for Social Insurance",
        "jurisdiction": "sa",
        "domain_scope": ["hr", "social_insurance"],
        "official_urls": ["gosi.gov.sa"],
        "source_priority": 1,
        "update_frequency": "annual",
    },
    "MOIM": {
        "name_ar": "وزارة الصناعة والثروة المعدنية",
        "name_en": "Ministry of Industry and Mineral Resources",
        "jurisdiction": "sa",
        "domain_scope": ["manufacturing", "mining"],
        "official_urls": ["industry.gov.sa"],
        "source_priority": 2,
    },
    "TGA": {
        "name_ar": "الهيئة العامة للنقل",
        "name_en": "Transport General Authority",
        "jurisdiction": "sa",
        "domain_scope": ["logistics", "transport"],
        "official_urls": ["tga.gov.sa"],
        "source_priority": 2,
    },
    "SFDA": {
        "name_ar": "هيئة الغذاء والدواء",
        "name_en": "Saudi Food & Drug Authority",
        "jurisdiction": "sa",
        "domain_scope": ["food_beverage", "healthcare", "pharma"],
        "official_urls": ["sfda.gov.sa"],
        "source_priority": 2,
    },
    "CCHI": {
        "name_ar": "مجلس الضمان الصحي",
        "name_en": "Council of Cooperative Health Insurance",
        "jurisdiction": "sa",
        "domain_scope": ["healthcare", "insurance"],
        "official_urls": ["cchi.gov.sa"],
        "source_priority": 2,
    },
    "GAC": {
        "name_ar": "الهيئة العامة للمنافسة",
        "name_en": "General Authority for Competition",
        "jurisdiction": "sa",
        "domain_scope": ["competition"],
        "official_urls": ["gac.gov.sa"],
        "source_priority": 2,
    },
    "SDAIA": {
        "name_ar": "هيئة البيانات والذكاء الاصطناعي",
        "name_en": "Saudi Data & AI Authority",
        "jurisdiction": "sa",
        "domain_scope": ["data_protection", "ai"],
        "official_urls": ["sdaia.gov.sa"],
        "source_priority": 2,
    },
    "NCA": {
        "name_ar": "الهيئة الوطنية للأمن السيبراني",
        "name_en": "National Cybersecurity Authority",
        "jurisdiction": "sa",
        "domain_scope": ["cybersecurity", "technology"],
        "official_urls": ["nca.gov.sa"],
        "source_priority": 2,
    },
    "CITC": {
        "name_ar": "هيئة الاتصالات وتقنية المعلومات",
        "name_en": "Communications, Space & Technology Commission",
        "jurisdiction": "sa",
        "domain_scope": ["technology", "telecom"],
        "official_urls": ["cst.gov.sa"],
        "source_priority": 2,
    },
    "REGA": {
        "name_ar": "الهيئة العامة للعقار",
        "name_en": "Real Estate General Authority",
        "jurisdiction": "sa",
        "domain_scope": ["real_estate"],
        "official_urls": ["rega.gov.sa"],
        "source_priority": 2,
    },
    "MOT": {
        "name_ar": "وزارة السياحة",
        "name_en": "Ministry of Tourism",
        "jurisdiction": "sa",
        "domain_scope": ["tourism", "hospitality"],
        "official_urls": ["mt.gov.sa"],
        "source_priority": 2,
    },
    "MOE": {
        "name_ar": "وزارة التعليم",
        "name_en": "Ministry of Education",
        "jurisdiction": "sa",
        "domain_scope": ["education"],
        "official_urls": ["moe.gov.sa"],
        "source_priority": 2,
    },
    "MOF": {
        "name_ar": "وزارة المالية",
        "name_en": "Ministry of Finance",
        "jurisdiction": "sa",
        "domain_scope": ["fiscal_policy", "government_finance"],
        "official_urls": ["mof.gov.sa"],
        "source_priority": 2,
    },
    "LCGPA": {
        "name_ar": "هيئة المحتوى المحلي والمشتريات الحكومية",
        "name_en": "Local Content & Government Procurement Authority",
        "jurisdiction": "sa",
        "domain_scope": ["government_procurement", "local_content"],
        "official_urls": ["lcgpa.gov.sa"],
        "source_priority": 2,
    },
    "BANKRUPTCY_COMMITTEE": {
        "name_ar": "لجنة الإفلاس",
        "name_en": "Bankruptcy Committee",
        "jurisdiction": "sa",
        "domain_scope": ["bankruptcy"],
        "source_priority": 2,
    },
    "IASB": {
        "name_ar": "مجلس معايير المحاسبة الدولية",
        "name_en": "International Accounting Standards Board",
        "jurisdiction": "international",
        "domain_scope": ["accounting_audit"],
        "official_urls": ["ifrs.org"],
        "source_priority": 3,
        "note": "معايير IFRS تُعتمد في السعودية من خلال SOCPA",
    },
}


# ─── Legal Force Levels ───
LEGAL_FORCE = {
    "binding_law": {"ar": "نظام ملزم", "priority": 1, "description": "قانون/نظام صادر بمرسوم ملكي"},
    "implementing_regulation": {"ar": "لائحة تنفيذية", "priority": 2, "description": "لائحة صادرة من الجهة المختصة"},
    "regulatory_instruction": {"ar": "تعليمات تنظيمية", "priority": 3, "description": "قواعد وتعليمات من الجهة"},
    "official_guidance": {"ar": "دليل رسمي", "priority": 4, "description": "دليل إرشادي من الجهة"},
    "professional_standard": {"ar": "معيار مهني", "priority": 5, "description": "معيار محاسبي أو مراجعي معتمد"},
    "official_bulletin": {"ar": "نشرة/تعميم رسمي", "priority": 6, "description": "تعميم أو نشرة من الجهة"},
    "best_practice": {"ar": "أفضل ممارسة", "priority": 7, "description": "ممارسة مهنية متعارف عليها"},
    "internal_practice": {"ar": "سياسة داخلية", "priority": 8, "description": "سياسة أو إجراء داخلي للمنصة"},
    "market_insight": {"ar": "رؤية سوقية", "priority": 9, "description": "تحليل أو نمط سوقي داعم للاستدلال"},
}


def get_authority(code: str) -> dict:
    return AUTHORITIES.get(code, {})

def get_authorities_by_domain(domain: str) -> list:
    return [k for k, v in AUTHORITIES.items() if domain in v.get("domain_scope", [])]

def get_all_authorities() -> dict:
    return AUTHORITIES

def get_legal_force_hierarchy() -> list:
    return sorted(LEGAL_FORCE.items(), key=lambda x: x[1]["priority"])
