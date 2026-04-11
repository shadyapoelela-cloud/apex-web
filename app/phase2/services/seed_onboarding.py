"""
APEX Platform - Seed Data for Client Onboarding
Legal Entity Types + Sectors + Stage Notes
"""


def get_legal_entity_types():
    return [
        {"code": "individual", "name_ar": "فرد / شخص طبيعي", "name_en": "Individual", "sort_order": 1},
        {"code": "sole_proprietorship", "name_ar": "مؤسسة فردية", "name_en": "Sole Proprietorship", "sort_order": 2},
        {"code": "single_llc", "name_ar": "شركة شخص واحد", "name_en": "Single Person LLC", "sort_order": 3},
        {"code": "llc", "name_ar": "شركة ذات مسؤولية محدودة", "name_en": "Limited Liability Company", "sort_order": 4},
        {"code": "joint_stock", "name_ar": "شركة مساهمة", "name_en": "Joint Stock Company", "sort_order": 5},
        {
            "code": "simplified_joint_stock",
            "name_ar": "شركة مساهمة مبسطة",
            "name_en": "Simplified Joint Stock",
            "sort_order": 6,
        },
        {"code": "general_partnership", "name_ar": "شركة تضامن", "name_en": "General Partnership", "sort_order": 7},
        {
            "code": "limited_partnership",
            "name_ar": "شركة توصية بسيطة",
            "name_en": "Limited Partnership",
            "sort_order": 8,
        },
        {"code": "foreign_branch", "name_ar": "فرع شركة أجنبية", "name_en": "Foreign Company Branch", "sort_order": 9},
        {"code": "government", "name_ar": "جهة حكومية / جهة عامة", "name_en": "Government Entity", "sort_order": 10},
        {
            "code": "nonprofit",
            "name_ar": "جمعية / كيان غير ربحي",
            "name_en": "Non-Profit Organization",
            "sort_order": 11,
        },
        {
            "code": "professional_office",
            "name_ar": "مكتب مهني / منشأة مهنية",
            "name_en": "Professional Office",
            "sort_order": 12,
        },
        {"code": "other", "name_ar": "أخرى", "name_en": "Other", "sort_order": 99},
    ]


def get_sector_main():
    return [
        {"code": "trade", "name_ar": "تجارة", "name_en": "Trade", "icon": "store", "sort_order": 1},
        {"code": "manufacturing", "name_ar": "صناعة", "name_en": "Manufacturing", "icon": "factory", "sort_order": 2},
        {
            "code": "professional_services",
            "name_ar": "خدمات مهنية",
            "name_en": "Professional Services",
            "icon": "work",
            "sort_order": 3,
        },
        {"code": "healthcare", "name_ar": "صحة", "name_en": "Healthcare", "icon": "health", "sort_order": 4},
        {"code": "education", "name_ar": "تعليم", "name_en": "Education", "icon": "school", "sort_order": 5},
        {"code": "technology", "name_ar": "تقنية", "name_en": "Technology", "icon": "computer", "sort_order": 6},
        {"code": "logistics", "name_ar": "لوجستيات", "name_en": "Logistics", "icon": "truck", "sort_order": 7},
        {"code": "construction", "name_ar": "إنشاءات", "name_en": "Construction", "icon": "build", "sort_order": 8},
        {"code": "agriculture", "name_ar": "زراعة", "name_en": "Agriculture", "icon": "nature", "sort_order": 9},
        {"code": "hospitality", "name_ar": "ضيافة", "name_en": "Hospitality", "icon": "hotel", "sort_order": 10},
        {
            "code": "government",
            "name_ar": "حكومي",
            "name_en": "Government",
            "icon": "account_balance",
            "sort_order": 11,
        },
        {"code": "nonprofit", "name_ar": "غير ربحي", "name_en": "Non-Profit", "icon": "volunteer", "sort_order": 12},
        {
            "code": "financial",
            "name_ar": "مالي / استثماري",
            "name_en": "Financial / Investment",
            "icon": "attach_money",
            "sort_order": 13,
        },
        {"code": "other", "name_ar": "أخرى", "name_en": "Other", "icon": "category", "sort_order": 99},
    ]


def get_sector_sub():
    return [
        # Trade
        {"code": "ecommerce", "sector_main_code": "trade", "name_ar": "تجارة إلكترونية", "name_en": "E-Commerce"},
        {"code": "wholesale", "sector_main_code": "trade", "name_ar": "تجارة جملة", "name_en": "Wholesale"},
        {"code": "retail", "sector_main_code": "trade", "name_ar": "تجارة تجزئة", "name_en": "Retail"},
        {"code": "packaging", "sector_main_code": "trade", "name_ar": "تعبئة وتغليف", "name_en": "Packaging"},
        # Professional Services
        {
            "code": "accounting",
            "sector_main_code": "professional_services",
            "name_ar": "محاسبة",
            "name_en": "Accounting",
            "requires_license": True,
        },
        {
            "code": "auditing",
            "sector_main_code": "professional_services",
            "name_ar": "مراجعة",
            "name_en": "Auditing",
            "requires_license": True,
        },
        {
            "code": "legal",
            "sector_main_code": "professional_services",
            "name_ar": "خدمات قانونية",
            "name_en": "Legal Services",
            "requires_license": True,
        },
        {
            "code": "consulting",
            "sector_main_code": "professional_services",
            "name_ar": "استشارات",
            "name_en": "Consulting",
        },
        {
            "code": "hr_services",
            "sector_main_code": "professional_services",
            "name_ar": "موارد بشرية",
            "name_en": "HR Services",
        },
        # Technology
        {"code": "saas", "sector_main_code": "technology", "name_ar": "برمجيات كخدمة", "name_en": "SaaS"},
        {"code": "it_services", "sector_main_code": "technology", "name_ar": "خدمات تقنية", "name_en": "IT Services"},
        # Healthcare
        {
            "code": "hospitals",
            "sector_main_code": "healthcare",
            "name_ar": "مستشفيات",
            "name_en": "Hospitals",
            "requires_license": True,
        },
        {
            "code": "pharmacies",
            "sector_main_code": "healthcare",
            "name_ar": "صيدليات",
            "name_en": "Pharmacies",
            "requires_license": True,
        },
        # Construction
        {"code": "contracting", "sector_main_code": "construction", "name_ar": "مقاولات", "name_en": "Contracting"},
        {"code": "real_estate", "sector_main_code": "construction", "name_ar": "عقارات", "name_en": "Real Estate"},
        # Financial
        {
            "code": "investment",
            "sector_main_code": "financial",
            "name_ar": "استثمار",
            "name_en": "Investment",
            "requires_license": True,
        },
        {
            "code": "insurance",
            "sector_main_code": "financial",
            "name_ar": "تأمين",
            "name_en": "Insurance",
            "requires_license": True,
        },
        {
            "code": "fintech",
            "sector_main_code": "financial",
            "name_ar": "تقنية مالية",
            "name_en": "FinTech",
            "requires_license": True,
        },
    ]


def get_stage_notes():
    return [
        {
            "service_key": "coa_upload",
            "stage_key": "upload",
            "role_scope": "all",
            "title_ar": "رفع شجرة الحسابات",
            "title_en": "Upload Chart of Accounts",
            "body_ar": "ارفع ملف شجرة الحسابات بصيغة Excel أو CSV. تأكد أن الملف يحتوي على عمود اسم الحساب كحد أدنى.",
            "body_en": "Upload your Chart of Accounts file in Excel or CSV format.",
            "common_errors_ar": "ملف فارغ، صيغة غير مدعومة، أعمدة غير واضحة",
            "impact_ar": "بدون شجرة حسابات معتمدة لا يمكن رفع ميزان المراجعة أو بدء التحليل",
        },
        {
            "service_key": "coa_upload",
            "stage_key": "mapping",
            "role_scope": "all",
            "title_ar": "ربط الأعمدة",
            "title_en": "Column Mapping",
            "body_ar": "راجع الأعمدة المكتشفة وتأكد من صحة الربط. عمود اسم الحساب إلزامي.",
            "body_en": "Review detected columns and confirm the mapping.",
            "common_errors_ar": "ربط عمود خاطئ، نسيان عمود اسم الحساب",
            "impact_ar": "ربط خاطئ يؤدي إلى نتائج تحليل غير دقيقة",
        },
        {
            "service_key": "coa_upload",
            "stage_key": "parse",
            "role_scope": "all",
            "title_ar": "قراءة وتحليل الملف",
            "title_en": "Parse File",
            "body_ar": "النظام يقرأ الملف ويحول البيانات إلى سجلات موحدة. الصفوف التالفة تُرصد ولا توقف العملية.",
            "body_en": "System reads the file and converts data to normalized records.",
            "common_errors_ar": "صفوف فارغة، أكواد مكررة، قيم غير مفهومة",
            "impact_ar": "الصفوف المرفوضة لن تدخل في التحليل",
        },
        {
            "service_key": "tb_upload",
            "stage_key": "upload",
            "role_scope": "all",
            "title_ar": "رفع ميزان المراجعة",
            "title_en": "Upload Trial Balance",
            "body_ar": "ارفع ميزان المراجعة بعد اعتماد شجرة الحسابات. يجب أن يحتوي على أكواد الحسابات والأرصدة.",
            "body_en": "Upload Trial Balance after approving the Chart of Accounts.",
            "common_errors_ar": "رفع ميزان قبل اعتماد الشجرة، أرصدة غير متوازنة",
            "impact_ar": "لا يمكن بدء التحليل المالي بدون ميزان مراجعة مربوط بالشجرة",
        },
        {
            "service_key": "tb_upload",
            "stage_key": "binding",
            "role_scope": "all",
            "title_ar": "ربط الميزان بالشجرة",
            "title_en": "Bind TB to COA",
            "body_ar": "النظام يربط أرصدة الميزان بالحسابات المعتمدة. الحسابات غير المطابقة تحتاج مراجعة يدوية.",
            "body_en": "System binds TB balances to approved COA accounts.",
            "common_errors_ar": "أكواد غير موجودة في الشجرة، حسابات جديدة لم تُضف",
            "impact_ar": "الحسابات غير المربوطة لن تدخل في التحليل",
        },
        {
            "service_key": "client_onboarding",
            "stage_key": "entity_info",
            "role_scope": "all",
            "title_ar": "بيانات الكيان الأساسية",
            "title_en": "Entity Information",
            "body_ar": "أدخل بيانات المنشأة: الاسم التجاري، الاسم القانوني، السجل التجاري، الرقم الضريبي.",
            "body_en": "Enter entity details: trade name, legal name, CR number, tax number.",
            "impact_ar": "هذه البيانات تبني هوية العميل داخل المنصة",
        },
        {
            "service_key": "client_onboarding",
            "stage_key": "legal_entity",
            "role_scope": "all",
            "title_ar": "الشكل القانوني",
            "title_en": "Legal Entity Type",
            "body_ar": "اختر نوع الكيان القانوني بدقة. هذا الاختيار يحدد المستندات المطلوبة والخدمات المتاحة.",
            "body_en": "Select your legal entity type carefully. This determines required documents and available services.",
            "impact_ar": "اختيار خاطئ يؤدي إلى متطلبات مستندية غير صحيحة",
        },
        {
            "service_key": "client_onboarding",
            "stage_key": "sector",
            "role_scope": "all",
            "title_ar": "النشاط الرئيسي والفرعي",
            "title_en": "Main and Sub Activity",
            "body_ar": "اختر نشاطك الرئيسي ثم الفرعي. الأنشطة المنظمة قد تتطلب تراخيص إضافية.",
            "body_en": "Select your main activity then sub-activity. Regulated activities may require additional licenses.",
            "impact_ar": "النشاط يحدد القواعد المعرفية والمقارنات المرجعية المناسبة",
        },
        {
            "service_key": "client_onboarding",
            "stage_key": "documents",
            "role_scope": "all",
            "title_ar": "المستندات المطلوبة",
            "title_en": "Required Documents",
            "body_ar": "ارفع المستندات الإلزامية حسب نوع الكيان والنشاط. يمكنك استخدام ملفات من الأرشيف.",
            "body_en": "Upload mandatory documents based on entity type and activity.",
            "impact_ar": "لا يمكن تفعيل العميل أو فتح الخدمات مع مستندات ناقصة",
        },
    ]
