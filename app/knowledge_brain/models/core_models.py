"""
╔════════════════════════════════════════════════════════════════╗
║  Apex Knowledge Brain — Core Data Models                      ║
║  نماذج البيانات الأساسية للعقل المعرفي                       ║
║                                                                ║
║  7 طبقات: مصادر → معرفة → قواعد → قطاعات → حالات → تحديثات   ║
╚════════════════════════════════════════════════════════════════╝

بدون PostgreSQL/SQLAlchemy — نستخدم Python dicts + JSON
يمكن ترقيته لاحقاً لـ PostgreSQL عند الحاجة
"""

from dataclasses import dataclass, field
from typing import Optional, List, Dict
from datetime import date
from enum import Enum

# ═══════════════════════════════════════════
#  Enums
# ═══════════════════════════════════════════


class SourceType(str, Enum):
    LAW = "law"  # نظام
    REGULATION = "regulation"  # لائحة تنفيذية
    STANDARD = "standard"  # معيار محاسبي
    GUIDE = "guide"  # دليل إرشادي
    BULLETIN = "bulletin"  # تعميم
    BEST_PRACTICE = "best_practice"  # أفضل ممارسة
    CASE = "case"  # حالة/سابقة
    PATTERN = "pattern"  # نمط مستخلص
    INTERNAL = "internal"  # سياسة داخلية


class Status(str, Enum):
    DRAFT = "draft"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    ARCHIVED = "archived"
    SUPERSEDED = "superseded"


class Severity(str, Enum):
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"
    CRITICAL = "critical"


class ObligationLevel(str, Enum):
    MANDATORY = "mandatory"  # إلزامي
    RECOMMENDED = "recommended"  # موصى به
    OPTIONAL = "optional"  # اختياري
    PROHIBITED = "prohibited"  # محظور


# ═══════════════════════════════════════════
#  Knowledge Domains
# ═══════════════════════════════════════════

DOMAINS = {
    "tax": {"ar": "الضرائب والزكاة", "authority": "ZATCA", "priority": 1},
    "accounting": {"ar": "المحاسبة والمراجعة", "authority": "SOCPA", "priority": 1},
    "governance": {"ar": "الحوكمة ونظام الشركات", "authority": "وزارة التجارة", "priority": 1},
    "investment": {"ar": "الاستثمار وسوق المال", "authority": "MISA / CMA", "priority": 2},
    "hr": {"ar": "الموارد البشرية والعمل", "authority": "HRSD", "priority": 2},
    "finance": {"ar": "التمويل والمصرفية", "authority": "SAMA", "priority": 2},
    "operations": {"ar": "التشغيل والتصنيع", "authority": "متعدد", "priority": 3},
    "sales": {"ar": "المبيعات والتسويق", "authority": "وزارة التجارة", "priority": 3},
    "logistics": {"ar": "اللوجستيات والنقل", "authority": "هيئة النقل", "priority": 3},
    "market": {"ar": "الذكاء السوقي", "authority": "متعدد", "priority": 3},
}

SECTORS = {
    "retail": {"ar": "تجارة التجزئة", "vat": True, "inventory": "periodic_or_perpetual"},
    "wholesale": {"ar": "تجارة الجملة", "vat": True, "inventory": "periodic"},
    "manufacturing": {"ar": "التصنيع", "vat": True, "inventory": "perpetual", "costing": True},
    "construction": {"ar": "المقاولات", "vat": True, "revenue_recognition": "over_time"},
    "services": {"ar": "الخدمات المهنية", "vat": True, "inventory": False},
    "technology": {"ar": "التقنية والمنصات", "vat": True, "inventory": False},
    "logistics": {"ar": "اللوجستيات والنقل", "vat": True},
    "healthcare": {"ar": "الرعاية الصحية", "vat": "exempt_partial"},
    "food_beverage": {"ar": "الأغذية والمشروبات", "vat": True, "halal": True},
    "education": {"ar": "التعليم", "vat": "exempt_partial"},
    "real_estate": {"ar": "العقارات", "vat": "rett_5pct"},
    "ecommerce": {"ar": "التجارة الإلكترونية", "vat": True, "maroof": True},
    "finance_sector": {"ar": "التمويل والاستثمار", "vat": "exempt_financial"},
    "tourism": {"ar": "السياحة والضيافة", "vat": True, "municipality_tax": 2.5},
    "mining": {"ar": "التعدين", "royalty": True},
    "energy": {"ar": "الطاقة", "special_tax": True},
}


# ═══════════════════════════════════════════
#  Knowledge Entry Schema
# ═══════════════════════════════════════════


@dataclass
class KnowledgeEntry:
    """وحدة معرفة واحدة — يمكن أن تكون مادة قانونية أو معيار أو قاعدة أو نمط"""

    entry_id: str
    domain: str  # tax, accounting, governance, etc.
    subdomain: str  # vat, zakat, ifrs_16, etc.
    title_ar: str
    title_en: str = ""
    source_type: str = "standard"  # SourceType
    authority: str = ""  # الجهة المصدرة
    official_reference: str = ""  # رقم النظام/المادة
    version: str = "1.0"
    issue_date: Optional[date] = None
    effective_date: Optional[date] = None
    expiry_date: Optional[date] = None
    status: str = "approved"  # Status

    # المحتوى المنظم
    summary: str = ""
    key_points: List[str] = field(default_factory=list)
    obligations: List[Dict] = field(default_factory=list)
    exceptions: List[str] = field(default_factory=list)

    # التأثيرات
    financial_impact: List[str] = field(default_factory=list)
    tax_impact: List[str] = field(default_factory=list)
    governance_impact: List[str] = field(default_factory=list)
    operational_impact: List[str] = field(default_factory=list)

    # الانطباق
    applicable_entities: List[str] = field(default_factory=list)  # llc, jsc, sole, all
    applicable_sectors: List[str] = field(default_factory=list)  # retail, manufacturing, etc.
    applicable_thresholds: Dict = field(default_factory=dict)  # revenue_min, employees_min, etc.

    # الربط
    linked_rules: List[str] = field(default_factory=list)
    linked_cases: List[str] = field(default_factory=list)
    linked_entries: List[str] = field(default_factory=list)

    # الثقة والحوكمة
    confidence: float = 0.95
    obligation_level: str = "mandatory"  # ObligationLevel
    review_frequency: str = "annual"
    source_url: str = ""
    notes: str = ""


# ═══════════════════════════════════════════
#  Executable Rule Schema
# ═══════════════════════════════════════════


@dataclass
class ExecutableRule:
    """قاعدة تنفيذية قابلة للتطبيق داخل المحرك"""

    rule_id: str
    domain: str
    subdomain: str
    rule_name_ar: str
    rule_name_en: str = ""

    # الشرط والفعل
    condition: Dict = field(default_factory=dict)  # {"field": "net_revenue", "operator": ">", "value": 375000}
    action: Dict = field(default_factory=dict)  # {"type": "flag", "severity": "warning", "message": "..."}
    exceptions: List[Dict] = field(default_factory=list)

    # المصدر
    source_entry_id: str = ""
    source_reference: str = ""
    obligation_level: str = "mandatory"

    # الحالة
    active: bool = True
    version: str = "1.0"
    status: str = "approved"
    confidence: float = 0.95


# ═══════════════════════════════════════════
#  Sector Pattern
# ═══════════════════════════════════════════


@dataclass
class SectorPattern:
    """نمط خاص بقطاع معيّن"""

    pattern_id: str
    sector: str
    pattern_name: str
    description: str = ""
    typical_accounts: List[str] = field(default_factory=list)
    typical_ratios: Dict = field(default_factory=dict)
    risk_flags: List[str] = field(default_factory=list)
    tax_notes: List[str] = field(default_factory=list)
    compliance_notes: List[str] = field(default_factory=list)


# ═══════════════════════════════════════════
#  Case Memory
# ═══════════════════════════════════════════


@dataclass
class CaseMemory:
    """حالة/سابقة معتمدة"""

    case_id: str
    domain: str
    sector: str = ""
    title: str = ""
    description: str = ""
    input_summary: str = ""
    decision: str = ""
    reasoning: str = ""
    outcome: str = ""
    lessons: List[str] = field(default_factory=list)
    linked_rules: List[str] = field(default_factory=list)
    status: str = "approved"
    date_recorded: Optional[date] = None


# ═══════════════════════════════════════════
#  Knowledge Update
# ═══════════════════════════════════════════


@dataclass
class KnowledgeUpdate:
    """تحديث نظامي أو معياري"""

    update_id: str
    update_type: str  # regulatory, standard, tax, market
    title: str = ""
    authority: str = ""
    change_summary: str = ""
    effective_date: Optional[date] = None
    impacted_domains: List[str] = field(default_factory=list)
    impacted_rules: List[str] = field(default_factory=list)
    impacted_entries: List[str] = field(default_factory=list)
    status: str = "detected"  # detected, under_review, approved, applied, archived
    source_url: str = ""
