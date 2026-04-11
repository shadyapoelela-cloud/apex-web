"""
APEX Phase 1 - All thresholds in one place.
"""

QUALITY_WEIGHTS = {
    "completeness": 0.25,
    "consistency": 0.20,
    "naming": 0.15,
    "duplication": 0.15,
    "reporting": 0.15,
    "mapping": 0.10,
}

AUTO_APPROVE_CONFIDENCE = 85
MIN_QUALITY_FOR_APPROVAL = 70
MIN_COMPLETENESS_FOR_TB = 80
MIN_REPORTING_FOR_TB = 60
LOW_CONFIDENCE_THRESHOLD = 60
MAX_FILE_SIZE_MB = 10
MIN_ROWS = 5
ACCEPTED_FORMATS = [".csv", ".xlsx", ".xls"]

CLIENT_STATUSES = ["draft", "active", "suspended", "archived"]
READINESS_STATUSES = ["not_ready", "documents_pending", "ready_for_coa", "coa_in_progress", "ready_for_tb"]
DOCUMENT_STATUSES = ["missing", "uploaded", "under_review", "accepted", "rejected", "expired", "replaced"]
ACCOUNT_STATUSES = ["parsed", "classified", "low_confidence", "flagged", "edited", "approved", "rejected"]
COA_STAGES = ["upload", "parse", "classify", "quality", "review", "approve", "ready"]

ENTITY_TYPES = [
    {"id": "llc", "ar": "شركة ذات مسؤولية محدودة", "en": "LLC"},
    {"id": "closed_jsc", "ar": "شركة مساهمة مقفلة", "en": "Closed JSC"},
    {"id": "sole_prop", "ar": "مؤسسة فردية", "en": "Sole Proprietorship"},
    {"id": "public_jsc", "ar": "شركة مساهمة عامة", "en": "Public JSC"},
    {"id": "partnership", "ar": "شركة تضامن", "en": "Partnership"},
    {"id": "foreign_branch", "ar": "فرع شركة أجنبية", "en": "Foreign Branch"},
    {"id": "professional", "ar": "شركة مهنية", "en": "Professional Co."},
    {"id": "nonprofit", "ar": "جمعية / مؤسسة غير ربحية", "en": "Non-profit"},
]

REQUIRED_DOCUMENTS = [
    {"id": "cr", "name_ar": "السجل التجاري", "name_en": "Commercial Registration", "required": True},
    {"id": "tax", "name_ar": "شهادة التسجيل الضريبي", "name_en": "Tax Registration", "required": True},
    {"id": "address", "name_ar": "العنوان الوطني", "name_en": "National Address", "required": True},
    {"id": "aoa", "name_ar": "عقد التأسيس", "name_en": "Articles of Association", "required": True},
    {"id": "licenses", "name_ar": "الرخص القائمة", "name_en": "Existing Licenses", "required": False},
    {"id": "financials", "name_ar": "القوائم المالية السابقة", "name_en": "Prior Financials", "required": False},
    {"id": "zakat", "name_ar": "شهادة الزكاة", "name_en": "Zakat Certificate", "required": False},
    {"id": "coa_guide", "name_ar": "دليل الحسابات", "name_en": "Internal COA Guide", "required": False},
]

NOTIFICATION_EVENTS = [
    "client_ready_for_coa",
    "coa_file_uploaded",
    "coa_parsing_failed",
    "coa_quality_below_threshold",
    "coa_review_required",
    "coa_returned_for_fix",
    "coa_approved",
    "coa_ready_for_tb",
    "document_expired",
    "document_rejected",
    "alias_promotion_proposed",
]
