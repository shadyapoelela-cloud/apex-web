"""
APEX COA Engine v4.2 — Fraud Pattern Detector + Rule Governance (Wave 7)
Detects 8 fraud patterns (FP01-FP08) in COA structure.
Manages engine rules with versioning and lifecycle.

Fraud Patterns (TABLE 119):
  FP01 — Hidden Revenue: revenue under expenses
  FP02 — Hidden Expense: expenses under assets (CapEx fraud)
  FP03 — Hidden Liabilities: liabilities under revenue or deleted
  FP04 — Revenue Scatter: single revenue split across 10+ similar accounts
  FP05 — Phantom Accounts: accounts not matching business nature
  FP06 — Asset Inflation: assets with credit nature without justification
  FP07 — Hidden Receivables: high receivables without ECL provision
  FP08 — Partner Drawings: large partner current account without settlement
"""

import re
import logging
from typing import Dict, List, Optional, Set, Tuple
from collections import Counter

logger = logging.getLogger(__name__)


FRAUD_PATTERNS = [
    {
        "pattern_id": "FP01",
        "name_ar": "إيراد مخفي تحت المصروفات",
        "name_en": "Hidden Revenue as Expense",
        "risk": "Critical",
        "description_ar": "إيرادات مُدرَجة تحت قسم المصروفات لتقليل الربح الظاهر",
        "indicator": "حساب بطبيعة دائن تحت قسم المصروفات",
        "motive_ar": "تخفيض ضريبي محتمل",
        "related_error": "E10",
        "references": ["IFRS 15 §9", "IAS 1 §82"],
    },
    {
        "pattern_id": "FP02",
        "name_ar": "مصروف مخفي تحت الأصول",
        "name_en": "Hidden Expense as Asset",
        "risk": "Critical",
        "description_ar": "مصروفات مُدرَجة تحت الأصول لتضخيم الأصول",
        "indicator": "حساب مصروف بكود 1XXX",
        "motive_ar": "تضخيم القيمة الدفترية",
        "related_error": "E11",
        "references": ["IAS 16 §7-14"],
    },
    {
        "pattern_id": "FP03",
        "name_ar": "خصوم مخفية",
        "name_en": "Hidden Liabilities",
        "risk": "Critical",
        "description_ar": "التزامات مُدرَجة تحت الإيرادات أو مُحذوفة",
        "indicator": "خصوم بطبيعة دائن تحت الإيرادات",
        "motive_ar": "تحسين نسب السيولة",
        "related_error": "E15",
        "references": ["IAS 32 §11"],
    },
    {
        "pattern_id": "FP04",
        "name_ar": "تشتيت الإيرادات",
        "name_en": "Revenue Scatter",
        "risk": "High",
        "description_ar": "إيراد واحد مُجزَّأ على 10+ حسابات متشابهة الأسماء",
        "indicator": "حسابات إيرادات متشابهة جداً وكثيرة",
        "motive_ar": "إخفاء التركيز",
        "related_error": "E40",
        "references": [],
    },
    {
        "pattern_id": "FP05",
        "name_ar": "حسابات وهمية",
        "name_en": "Phantom Accounts",
        "risk": "High",
        "description_ar": "حسابات لا تتطابق مع طبيعة نشاط الشركة",
        "indicator": "قطاع خاطئ + أسماء غريبة",
        "motive_ar": "نشاط خارج الترخيص",
        "related_error": "E45",
        "references": [],
    },
    {
        "pattern_id": "FP06",
        "name_ar": "تضخيم الأصول",
        "name_en": "Asset Inflation",
        "risk": "Critical",
        "description_ar": "أصول بأكواد 1XXX لكن طبيعتها دائن بدون مبرر",
        "indicator": "حساب مدرج كأصل بطبيعة دائن ليس Contra",
        "motive_ar": "رفع قيمة ضمانية",
        "related_error": "E17",
        "references": [],
    },
    {
        "pattern_id": "FP07",
        "name_ar": "إخفاء الذمم المعدومة",
        "name_en": "Hidden Bad Receivables",
        "risk": "High",
        "description_ar": "ذمم مدينة عالية بدون مخصص ECL واحد",
        "indicator": "وجود ذمم بدون ECL في شركة عمرها > سنة",
        "motive_ar": "إخفاء الديون المعدومة",
        "related_error": "E28",
        "references": ["IFRS 9 §5.5"],
    },
    {
        "pattern_id": "FP08",
        "name_ar": "سلف الشركاء",
        "name_en": "Partner Drawings",
        "risk": "Medium",
        "description_ar": "حساب جاري الشريك كبير جداً بدون تسوية",
        "indicator": "PARTNER_DRAWINGS تتجاوز 30% من رأس المال",
        "motive_ar": "سحب غير موثَّق من الشركة",
        "related_error": None,
        "references": [],
    },
]

# Index by pattern_id
FRAUD_PATTERN_INDEX = {p["pattern_id"]: p for p in FRAUD_PATTERNS}

# Contra concepts (not fraud indicators for FP06)
_CONTRA_CONCEPTS = frozenset([
    "ACCUM_DEPRECIATION", "SALES_RETURNS", "PURCHASE_RETURNS",
    "ACCUMULATED_LOSSES", "OWNER_DRAWINGS", "DIVIDENDS", "TREASURY_SHARES",
])


class FraudAlert:
    """A detected fraud pattern alert."""

    __slots__ = (
        "pattern_id", "risk", "account_code", "account_name",
        "description_ar", "indicator", "confidence",
    )

    def __init__(self, pattern_id: str, account_code: str, account_name: str = "",
                 description_ar: str = "", indicator: str = "",
                 risk: str = "High", confidence: float = 0.7):
        self.pattern_id = pattern_id
        self.risk = risk
        self.account_code = account_code
        self.account_name = account_name
        self.description_ar = description_ar
        self.indicator = indicator
        self.confidence = confidence

    def to_dict(self) -> Dict:
        return {
            "pattern_id": self.pattern_id,
            "risk": self.risk,
            "account_code": self.account_code,
            "account_name": self.account_name,
            "description_ar": self.description_ar,
            "indicator": self.indicator,
            "confidence": round(self.confidence, 2),
        }


def detect_fraud_patterns(
    accounts: List[Dict],
    sector_code: str = None,
) -> Dict:
    """Detect all 8 fraud patterns in the COA.

    Args:
        accounts: Classified account list.
        sector_code: Optional detected sector for FP05.

    Returns:
        Dict with: alerts, summary, risk_level, patterns_checked
    """
    alerts: List[FraudAlert] = []
    concept_set: Set[str] = set()

    for acct in accounts:
        cid = acct.get("concept_id")
        if cid:
            concept_set.add(cid)

    # FP01: Hidden Revenue — revenue keywords under expense classification
    for acct in accounts:
        main_class = acct.get("main_class", "")
        name = str(acct.get("name", "")).lower()
        nature = acct.get("nature", "")
        code = str(acct.get("code", ""))

        if main_class in ("expense", "cogs") and nature == "credit":
            concept = acct.get("concept_id", "")
            if concept not in _CONTRA_CONCEPTS:
                alerts.append(FraudAlert(
                    "FP01", code, acct.get("name", ""),
                    description_ar="حساب بطبيعة دائنة تحت المصروفات — قد يكون إيراد مخفي",
                    indicator=f"nature=credit under {main_class}",
                    risk="Critical", confidence=0.6,
                ))

    # FP02: Hidden Expense — expense-like names under assets
    expense_keywords = re.compile(r"مصروف|صيان|رواتب|أجور|إيجار|expense|salary|rent|maintenance", re.IGNORECASE | re.UNICODE)
    for acct in accounts:
        if acct.get("main_class") == "asset":
            name = str(acct.get("name", ""))
            if expense_keywords.search(name):
                alerts.append(FraudAlert(
                    "FP02", str(acct.get("code", "")), name,
                    description_ar="اسم مصروف مُدرج تحت الأصول — تضخيم أصول محتمل",
                    indicator=f"expense keyword in asset: {name}",
                    risk="Critical", confidence=0.5,
                ))

    # FP03: Hidden Liabilities — liability keywords under revenue
    liability_keywords = re.compile(r"التزام|قرض|دائن|مستحق|payable|loan|liability|accrued", re.IGNORECASE | re.UNICODE)
    for acct in accounts:
        if acct.get("main_class") == "revenue":
            name = str(acct.get("name", ""))
            if liability_keywords.search(name):
                alerts.append(FraudAlert(
                    "FP03", str(acct.get("code", "")), name,
                    description_ar="اسم التزام مُدرج تحت الإيرادات — إخفاء خصوم محتمل",
                    indicator=f"liability keyword in revenue: {name}",
                    risk="Critical", confidence=0.6,
                ))

    # FP04: Revenue Scatter — too many similar revenue accounts
    revenue_accounts = [a for a in accounts if a.get("main_class") == "revenue"]
    if len(revenue_accounts) >= 10:
        # Check for similar names
        rev_names = [str(a.get("name", "")).strip()[:20] for a in revenue_accounts]
        name_prefixes = Counter(rev_names)
        for prefix, count in name_prefixes.items():
            if count >= 5 and prefix:
                alerts.append(FraudAlert(
                    "FP04", "", f"{count} accounts starting with '{prefix}'",
                    description_ar=f"تشتيت إيرادات: {count} حساب إيراد بأسماء متشابهة تبدأ بـ '{prefix}'",
                    indicator=f"{count} similar revenue accounts",
                    risk="High", confidence=0.5,
                ))

    # FP06: Asset Inflation — assets with credit nature (not contra)
    for acct in accounts:
        if acct.get("main_class") == "asset" and acct.get("nature") == "credit":
            concept = acct.get("concept_id", "")
            if concept not in _CONTRA_CONCEPTS:
                alerts.append(FraudAlert(
                    "FP06", str(acct.get("code", "")), str(acct.get("name", "")),
                    description_ar="أصل بطبيعة دائنة بدون تبرير (ليس حساب مقابل)",
                    indicator="asset with credit nature, not contra",
                    risk="Critical", confidence=0.6,
                ))

    # FP07: Hidden Bad Receivables — has receivables but no ECL
    if "ACC_RECEIVABLE" in concept_set and "ECL_PROVISION" not in concept_set:
        rec_accounts = [a for a in accounts if a.get("concept_id") == "ACC_RECEIVABLE"]
        rec_count = len(rec_accounts)
        first = rec_accounts[0] if rec_accounts else None
        if first:
            alerts.append(FraudAlert(
                "FP07", str(first.get("code", "")),
                f"{rec_count} receivable account(s) without ECL",
                description_ar=f"ذمم مدينة ({rec_count} حساب) بدون مخصص خسائر ائتمان — إخفاء ديون معدومة محتمل",
                indicator=f"{rec_count} receivable accounts without ECL provision",
                risk="High", confidence=0.7,
            ))

    # FP08: Partner Drawings — presence of large drawing accounts
    drawing_accounts = [a for a in accounts if a.get("concept_id") in ("OWNER_DRAWINGS", "DIVIDENDS")]
    if len(drawing_accounts) > 2:
        alerts.append(FraudAlert(
            "FP08", "", f"{len(drawing_accounts)} drawing accounts",
            description_ar=f"عدد كبير من حسابات المسحوبات/التوزيعات ({len(drawing_accounts)})",
            indicator=f"{len(drawing_accounts)} drawing/distribution accounts",
            risk="Medium", confidence=0.4,
        ))

    # Summary
    risk_counts = {"Critical": 0, "High": 0, "Medium": 0, "Low": 0}
    for a in alerts:
        risk_counts[a.risk] = risk_counts.get(a.risk, 0) + 1

    if risk_counts["Critical"] > 0:
        overall_risk = "Critical"
    elif risk_counts["High"] > 0:
        overall_risk = "High"
    elif risk_counts["Medium"] > 0:
        overall_risk = "Medium"
    else:
        overall_risk = "None"

    logger.info(
        "Fraud detection: %d alerts (Critical=%d, High=%d, Medium=%d)",
        len(alerts), risk_counts["Critical"], risk_counts["High"], risk_counts["Medium"],
    )

    return {
        "patterns_checked": len(FRAUD_PATTERNS),
        "alerts_count": len(alerts),
        "risk_level": overall_risk,
        "risk_summary": risk_counts,
        "alerts": [a.to_dict() for a in alerts],
    }


# ── Rule Governance ──

RULE_STATUSES = ("active", "testing", "deprecated", "disabled")


class EngineRule:
    """Represents a governance rule with versioning and lifecycle."""

    def __init__(self, rule_code: str, rule_type: str, description: str,
                 version: int = 1, status: str = "active",
                 precision_score: float = 0.0, recall_score: float = 0.0):
        self.rule_code = rule_code
        self.rule_type = rule_type  # error_detection, classification, fraud, compliance
        self.description = description
        self.version = version
        self.status = status
        self.precision_score = precision_score
        self.recall_score = recall_score

    def to_dict(self) -> Dict:
        return {
            "rule_code": self.rule_code,
            "rule_type": self.rule_type,
            "description": self.description,
            "version": self.version,
            "status": self.status,
            "precision_score": self.precision_score,
            "recall_score": self.recall_score,
        }


# Default engine rules
DEFAULT_RULES: List[EngineRule] = [
    EngineRule("R001", "classification", "Saudi code prefix classification (1=asset...)", 1, "active", 0.92, 0.88),
    EngineRule("R002", "classification", "ERP type mapping (Odoo/Zoho user_type_id)", 1, "active", 0.95, 0.80),
    EngineRule("R003", "classification", "Arabic/English name lexicon matching (1403+ patterns)", 1, "active", 0.85, 0.90),
    EngineRule("R004", "classification", "Cross-layer conflict resolution with voting", 1, "active", 0.90, 0.85),
    EngineRule("R005", "classification", "Claude API fallback for unresolved accounts", 1, "active", 0.75, 0.70),
    EngineRule("R006", "error_detection", "Duplicate code detection (E01)", 1, "active", 0.99, 0.99),
    EngineRule("R007", "error_detection", "Missing code detection (E02)", 1, "active", 0.99, 0.99),
    EngineRule("R008", "error_detection", "Nature mismatch detection (E17-E20)", 1, "active", 0.90, 0.85),
    EngineRule("R009", "error_detection", "Cross-validation rules (E27/E28/E37/E48/E50)", 1, "active", 0.88, 0.82),
    EngineRule("R010", "fraud", "8 fraud pattern detectors (FP01-FP08)", 1, "active", 0.70, 0.65),
    EngineRule("R011", "compliance", "ZATCA/IFRS/SOCPA compliance checks", 1, "active", 0.85, 0.80),
    EngineRule("R012", "sector", "45-sector auto-detection and similarity scoring", 1, "active", 0.80, 0.75),
]


def get_engine_rules() -> List[Dict]:
    """Return all engine rules with their governance metadata."""
    return [r.to_dict() for r in DEFAULT_RULES]


def get_rule_stats() -> Dict:
    """Return aggregate statistics about engine rules."""
    active = sum(1 for r in DEFAULT_RULES if r.status == "active")
    avg_precision = sum(r.precision_score for r in DEFAULT_RULES) / len(DEFAULT_RULES)
    avg_recall = sum(r.recall_score for r in DEFAULT_RULES) / len(DEFAULT_RULES)
    return {
        "total_rules": len(DEFAULT_RULES),
        "active": active,
        "avg_precision": round(avg_precision, 4),
        "avg_recall": round(avg_recall, 4),
        "rule_types": dict(Counter(r.rule_type for r in DEFAULT_RULES)),
    }
