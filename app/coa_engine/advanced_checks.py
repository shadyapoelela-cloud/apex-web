"""
APEX COA Engine v4.3 — Advanced Checks (Wave 2 Modules)
=========================================================
تنفيذ الملاحق الاستراتيجية:
  - ملحق د: Auto-Match الأصول ومجمعات الإهلاك
  - ملحق و: التحقق المتقاطع (Cross-Validation)
  - ملحق ز: استثناءات الموسمية (Seasonality)
  - ملحق س: كشف أنماط التلاعب (Fraud Detection FP01-FP08)
  - ملحق ك: تتبع تطور الشجرة (Evolution Tracking)
  - ملحق ل: محرك التشابه القطاعي (Similarity Engine)
"""
from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from .error_checks import COAError


# ═══════════════════════════════════════════════════════════════
# ملحق د — Auto-Match الأصول ومجمعات الإهلاك
# ═══════════════════════════════════════════════════════════════

# أنماط المطابقة مستخرجة مباشرة من الوثيقة
ASSET_TO_DEPR_PATTERNS = [
    (re.compile(r"مبانٍ|مباني|بناء|إنشاء", re.I),           re.compile(r"مجمع.*(إهلاك|استهلاك).*(بناء|مبنى|إنشاء)", re.I),    "ACCUM_DEPR_BUILDINGS"),
    (re.compile(r"آلات|معدات.*صناعية|ماكينات", re.I),        re.compile(r"مجمع.*(إهلاك|استهلاك).*(آل|معد|ماكين)", re.I),       "ACCUM_DEPR_MACHINERY"),
    (re.compile(r"أثاث|مفروشات", re.I),                      re.compile(r"مجمع.*(إهلاك|استهلاك).*(أثاث|مفروش)", re.I),         "ACCUM_DEPR_FURNITURE"),
    (re.compile(r"سيارات|مركبات|أسطول|وسائل.*نقل", re.I),    re.compile(r"مجمع.*(إهلاك|استهلاك).*(سيار|مركب|نقل)", re.I),     "ACCUM_DEPR_VEHICLES"),
    (re.compile(r"حاسبات|كمبيوتر|IT|تقنية.*معلومات", re.I), re.compile(r"مجمع.*(إهلاك|استهلاك).*(حاسب|IT|كمبيوتر)", re.I),  "ACCUM_DEPR_COMPUTERS"),
    (re.compile(r"حق.?استخدام|ROU|IFRS.?16", re.I),          re.compile(r"مجمع.*(إهلاك|استهلاك).*(حق|ROU|استخدام)", re.I),    "ACCUM_DEPR_ROU"),
    (re.compile(r"تحسينات.*مستأجر", re.I),                    re.compile(r"مجمع.*(إهلاك|استهلاك).*تحسين", re.I),                "ACCUM_DEPR_IMPROVEMENTS"),
    (re.compile(r"معدات.*طبية|أجهزة.*طبية", re.I),           re.compile(r"مجمع.*(إهلاك|استهلاك).*طبي", re.I),                  "ACCUM_DEPR_MEDICAL"),
]

# نطاقات الأقسام من ملحق هـ
SECTION_RANGES: Dict[str, Tuple[int, int]] = {
    "نقدية":                (1101, 1109),
    "ذمم مدينة":            (1111, 1119),
    "مخزون":                (1121, 1129),
    "مدفوعات مقدمة":        (1131, 1139),
    "ضرائب متداولة":        (1151, 1159),
    "أصول متداولة أخرى":   (1161, 1199),
    "أصول ثابتة":           (1201, 1299),
    "حق الاستخدام":         (1301, 1319),
    "غير ملموسة":           (1401, 1499),
    "استثمارات":            (1501, 1599),
    "ذمم دائنة":            (2101, 2109),
    "مستحقات":              (2111, 2119),
    "إيرادات مؤجلة":        (2121, 2129),
    "ضرائب متداولة دائن":  (2131, 2139),
    "قروض قصيرة":           (2141, 2159),
    "خصوم متداولة أخرى":   (2161, 2199),
    "قروض طويلة":           (2201, 2219),
    "مخصصات":               (2221, 2239),
    "رأس المال":             (3101, 3119),
    "احتياطيات":            (3201, 3299),
    "أرباح مبقاة":          (3301, 3399),
    "إيرادات تشغيلية":      (4101, 4199),
    "إيرادات أخرى":         (4201, 4299),
    "تكلفة مبيعات":         (5101, 5199),
    "مصروفات موظفين":       (6101, 6119),
    "مصروفات تشغيل":        (6121, 6199),
    "مصروفات بيع":          (6201, 6299),
    "ضرائب":                (6301, 6399),
    "تكاليف تمويل":         (7101, 7299),
}


def suggest_code(section: str, existing_codes: set) -> Optional[str]:
    """يقترح كوداً متاحاً في نطاق القسم."""
    start, end = SECTION_RANGES.get(section, (9001, 9999))
    for candidate in range(start, end + 1):
        if str(candidate) not in existing_codes:
            return str(candidate)
    return None


def suggest_depr_code(asset_code: str, existing_codes: set) -> str:
    """يقترح كود مجمع الإهلاك بجوار الأصل."""
    try:
        code = int(str(asset_code).replace(".0","").strip())
        candidate = code + 1
        while str(candidate) in existing_codes:
            candidate += 1
        return str(candidate)
    except ValueError:
        return ""


@dataclass
class AutoMatchSuggestion:
    error:             str
    asset_code:        str
    asset_name:        str
    suggested_depr_code: str
    suggested_depr_name: str
    auto_fix:          bool = True
    concept_id:        str  = ""


def auto_match_depreciation(accounts: List[Dict]) -> List[AutoMatchSuggestion]:
    """
    ملحق د: لكل أصل ثابت — تحقق من وجود مجمع الإهلاك المقابل.
    إذا غاب: أنشئ اقتراحاً تلقائياً.
    """
    existing_codes = {str(a.get("code","") or "") for a in accounts}
    all_names      = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    fixed_assets = [a for a in accounts
                    if re.search(
                        r"أصول.*ثابت|fixed.*asset|property.*plant|non_current_asset|non.current.asset",
                        str(a.get("section","") or ""), re.I)
                    and "مجمع" not in str(a.get("name_raw","") or a.get("name","") or "")]

    suggestions = []
    for asset in fixed_assets:
        name = str(asset.get("name_raw","") or "")
        code = str(asset.get("code","") or "")
        for asset_pat, depr_pat, cid in ASSET_TO_DEPR_PATTERNS:
            if asset_pat.search(name) and not depr_pat.search(all_names):
                suggestions.append(AutoMatchSuggestion(
                    error="E48",
                    asset_code=code,
                    asset_name=name,
                    suggested_depr_code=suggest_depr_code(code, existing_codes),
                    suggested_depr_name=f"مجمع إهلاك {name}",
                    concept_id=cid,
                ))
                break
    return suggestions


# ═══════════════════════════════════════════════════════════════
# ملحق و — التحقق المتقاطع (Cross-Validation)
# ═══════════════════════════════════════════════════════════════

# قواعد التحقق المتقاطع مستخرجة مباشرة من الوثيقة
CROSS_VALIDATION_RULES = [
    # (trigger_pattern, required_pattern, error_code, severity, message)
    (re.compile(r"حق.?استخدام|ROU", re.I),
     re.compile(r"التزام.*إيجار|lease.*liabil", re.I),
     "E27", "Critical",
     "وُجد أصل حق استخدام بدون التزام إيجار مقابل — IFRS 16 §22"),

    (re.compile(r"^(مبانٍ|آلات|أثاث|مركبات|حاسبات)", re.I),
     re.compile(r"مجمع.*إهلاك", re.I),
     "E48", "High",
     "أصل ثابت بدون مجمع إهلاك — IAS 16 §43"),

    (re.compile(r"ذمم.*مدينة|حسابات.*قبض|عملاء", re.I),
     re.compile(r"مخصص.*(ائتمان|ديون|ECL|مشكوك)", re.I),
     "E28", "High",
     "ذمم مدينة بدون مخصص ECL — IFRS 9 §5.5"),

    (re.compile(r"إيرادات.*مبيع|مبيعات", re.I),
     re.compile(r"تكلفة.*مبيع|COGS|cost.*goods", re.I),
     "E50", "Critical",
     "إيرادات بيع بدون تكلفة — دورة محاسبية ناقصة"),

    (re.compile(r"ض.?ق.?م.*مدخل|VAT.*input", re.I),
     re.compile(r"ض.?ق.?م.*مخرج|VAT.*output", re.I),
     "E33", "High",
     "ض.ق.م مدخلات بدون ض.ق.م مخرجات — تحقق من الفصل"),

    (re.compile(r"مكافأة.*نهاية.*خدمة.*مخصص|EOSB.*provision", re.I),
     re.compile(r"مصروف.*نهاية.*خدمة|EOSB.*expense", re.I),
     "E38", "High",
     "مخصص EOSB بدون مصروف مقابل — IAS 37"),

    (re.compile(r"محتفظ.*بيع|held.?for.?sale|أصول.*للبيع", re.I),
     None,  # trigger فقط بلا required
     "IFRS5_WATCH", "Medium",
     "أصول IFRS 5 — تحقق: هل مرّ أكثر من 12 شهر على إعادة التصنيف؟"),

    (re.compile(r"مرابحة|murabaha", re.I),
     re.compile(r"إيراد.*مرابحة|murabaha.*income", re.I),
     "E46-BANKING", "High",
     "تمويل مرابحة بدون إيراد مرابحة — قطاع البنوك الإسلامية"),

    (re.compile(r"رأس.?مال", re.I),
     re.compile(r"احتياطي.*نظامي|احتياطي.*قانوني|statutory.*reserve", re.I),
     "E46-COMPANY", "Medium",
     "رأس مال بدون احتياطي نظامي — نظام الشركات السعودي يُلزِم بـ 10%"),
]


def run_cross_validation(accounts: List[Dict]) -> List[COAError]:
    """
    ملحق و: تحقق تلقائي من وجود الحسابات المترابطة.
    """
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    errors: List[COAError] = []

    for trigger_pat, required_pat, err_code, severity, msg in CROSS_VALIDATION_RULES:
        trigger_found = any(trigger_pat.search(n) for n in names)
        if not trigger_found:
            continue

        # required=None → trigger وحده يكفي
        if required_pat is None:
            errors.append(COAError(
                error_code=err_code, severity=severity,
                category="cross_validation",
                description_ar=msg,
                cause_ar="تحقق متقاطع — ملحق و",
                suggestion_ar="راجع متطلبات المعيار المحاسبي ذي الصلة",
                auto_fixable=False,
                references=["ملحق و — التحقق المتقاطع"],
            ))
            continue

        required_found = any(required_pat.search(n) for n in names)
        if not required_found:
            errors.append(COAError(
                error_code=err_code, severity=severity,
                category="cross_validation",
                description_ar=msg,
                cause_ar="التحقق المتقاطع كشف حساباً مفقوداً مرتبطاً بحساب موجود",
                suggestion_ar="أضف الحساب المطلوب حسب المعيار المحاسبي",
                auto_fixable=False,
                references=["ملحق و — التحقق المتقاطع"],
            ))

    return errors


# ═══════════════════════════════════════════════════════════════
# ملحق ز — الموسمية (Seasonality Exceptions)
# ═══════════════════════════════════════════════════════════════

SEASONAL_EXCEPTIONS = {
    "HAJJ_UMRAH": {
        "accounts": ["PILGRIMS_DEPOSITS","HAJJ_REVENUE","HAJJ_COST"],
        "active_months_hijri": [11, 12],
        "warning": "MW_SEASONAL_HAJJ",
        "message": "غياب حسابات الحج مقبول خارج موسم ذي الحجة",
    },
    "AGRICULTURE": {
        "accounts": ["HARVEST_INVENTORY","CROP_REVENUE","BIOLOGICAL_ASSETS"],
        "active_months_gregorian": [3, 4, 9, 10],
        "warning": "MW_SEASONAL_AGRI",
        "message": "غياب المخزون الزراعي مقبول خارج موسمَي الحصاد",
    },
    "DAIRY": {
        "accounts": ["MILK_REVENUE","DAIRY_INVENTORY"],
        "warning": "MW_SEASONAL_DAIRY",
        "message": "تذبذب إيرادات الألبان الموسمي — غير خطأ",
    },
    "CONSTRUCTION": {
        "accounts": ["CIP","WORK_IN_PROGRESS"],
        "warning": "MW_SEASONAL_CONST",
        "message": "غياب الأعمال تحت التنفيذ مقبول بين المشاريع",
    },
}


def check_seasonal_exception(
    sector: str,
    account_id: str,
    upload_date: Optional[date] = None,
) -> bool:
    """
    يُعيد True إذا كان غياب الحساب مقبولاً موسمياً.
    ملحق ز — يُستخدم لتصفية E46.
    """
    rule = SEASONAL_EXCEPTIONS.get(sector.upper())
    if not rule or account_id not in rule.get("accounts", []):
        return False

    if not upload_date:
        return False  # لا نعرف الشهر → نفترض غير موسمي

    if "active_months_gregorian" in rule:
        return upload_date.month not in rule["active_months_gregorian"]

    return False  # الافتراضي: ليس استثناءً موسمياً


# ═══════════════════════════════════════════════════════════════
# ملحق س — Fraud Detection (FP01-FP08)
# ═══════════════════════════════════════════════════════════════

@dataclass
class FraudAlert:
    pattern_id:           str
    account_code:         Optional[str]
    account_name:         Optional[str]
    risk:                 str           # Critical | High | Medium
    message:              str
    requires_human_review: bool = True
    auto_fix:             bool  = False
    evidence:             List[str] = field(default_factory=list)

    def to_error(self) -> COAError:
        return COAError(
            error_code=self.pattern_id,
            severity=self.risk,
            category="fraud_pattern",
            account_code=self.account_code,
            account_name=self.account_name,
            description_ar=self.message,
            cause_ar="كشف نمط تلاعب محتمل — يستلزم مراجعة بشرية متخصصة",
            suggestion_ar="هذا تحذير لا اتهام — راجع مع المدقق الداخلي",
            auto_fixable=False,
            references=["ملحق س — Fraud Pattern Detection"],
        )


def _detect_revenue_fragmentation(accounts: List[Dict], threshold: int = 8) -> List[Dict]:
    """كشف الإيرادات المُجزَّأة بشكل مشبوه (FP04)."""
    revenue_accounts = [a for a in accounts
                        if "إيرادات" in str(a.get("section","") or "")
                        and str(a.get("account_level","") or "").lower() in {"detail","تفصيلي","other"}]
    if len(revenue_accounts) < threshold:
        return []
    words = [w for a in revenue_accounts for w in str(a.get("name_raw","") or "").split() if len(w) > 3]
    if not words:
        return []
    common = [w for w, c in Counter(words).most_common(3) if c > threshold * 0.8]
    return revenue_accounts if common else []


def run_fraud_detection(accounts: List[Dict]) -> List[FraudAlert]:
    """
    ملحق س: كشف FP01-FP07 (FP08 يحتاج ميزان المراجعة).
    """
    alerts: List[FraudAlert] = []

    # FP01 — إيراد مخفي تحت المصروفات
    fp01 = [a for a in accounts
            if str(a.get("section","") or "").lower() in {"expense","مصروفات","cogs","تكلفة المبيعات"}
            and str(a.get("nature","") or "").lower() in {"credit","دائن"}
            and "مخصص" not in str(a.get("name_raw","") or a.get("name","") or "")
            and "مردود" not in str(a.get("name_raw","") or a.get("name","") or "")
            and "خصم" not in str(a.get("name_raw","") or a.get("name","") or "")]
    for a in fp01:
        alerts.append(FraudAlert(
            pattern_id="FP01", risk="Critical",
            account_code=a.get("code"), account_name=a.get("name_raw"),
            message=f"'{a.get('name_raw','')}' — حساب بطبيعة دائن تحت المصروفات — راجع: هل هو إيراد مُخفى؟",
            evidence=[f"section={a.get('section')}", f"nature={a.get('nature')}"],
        ))

    # FP02 — مصروف مُرسمَل بشكل مشبوه
    suspicious_kw = re.compile(r"مصروف|رسوم|أتعاب|غرامة|fee|fine|penalty", re.I)
    exclude_kw    = re.compile(r"مدفوع.?مقدم|prepaid|مُرسمَل.*مشروع|capitalized", re.I)
    fp02 = [a for a in accounts
            if str(a.get("section","") or "").lower() in {"current_asset","non_current_asset","أصول متداولة","أصول غير متداولة"}
            and suspicious_kw.search(str(a.get("name_raw","") or ""))
            and not exclude_kw.search(str(a.get("name_raw","") or ""))]
    for a in fp02:
        alerts.append(FraudAlert(
            pattern_id="FP02", risk="Critical",
            account_code=a.get("code"), account_name=a.get("name_raw"),
            message=f"'{a.get('name_raw','')}' — مصروف مُدرَج كأصل — تحقق من مشروعية الرسملة",
            evidence=[f"section={a.get('section')}"],
        ))

    # FP03 — خصوم مخفية (التزامات بطبيعة دائن في الأصول)
    fp03 = [a for a in accounts
            if str(a.get("section","") or "").lower() in {"current_asset","non_current_asset"}
            and str(a.get("nature","") or "").lower() in {"credit","دائن"}
            and "مجمع" not in str(a.get("name_raw","") or "")
            and "مخصص" not in str(a.get("name_raw","") or a.get("name","") or "")]
    for a in fp03:
        alerts.append(FraudAlert(
            pattern_id="FP03", risk="High",
            account_code=a.get("code"), account_name=a.get("name_raw"),
            message=f"'{a.get('name_raw','')}' — حساب دائن في الأصول — قد يكون التزاماً مُخفىً",
            evidence=[f"section={a.get('section')}", f"nature={a.get('nature')}"],
        ))

    # FP04 — تشتيت الإيرادات
    fragmented = _detect_revenue_fragmentation(accounts)
    if fragmented:
        alerts.append(FraudAlert(
            pattern_id="FP04", risk="High",
            account_code=None, account_name=None,
            message=f"عدد كبير من حسابات الإيرادات المتشابهة ({len(fragmented)} حساب) — راجع الضرورة المحاسبية",
            evidence=[a.get("name_raw","") for a in fragmented[:5]],
        ))

    # FP05 — حسابات وهمية (قطاع خاطئ — بدون حسابات أساسية)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_basic = (any(re.search(r"نقد|صندوق|cash", n, re.I) for n in names) and
                 any(re.search(r"إيراد|مبيعات|revenue", n, re.I) for n in names))
    if not has_basic and len(accounts) > 10:
        alerts.append(FraudAlert(
            pattern_id="FP05", risk="High",
            account_code=None, account_name=None,
            message="الشجرة تفتقر لحسابات أساسية (نقدية + إيرادات) — تحقق من صحة الملف",
        ))

    # FP06 — تضخيم الأصول (أصول 1XXX بطبيعة دائن بدون مبرر)
    fp06 = [a for a in accounts
            if str(a.get("code","") or "").startswith("1")
            and str(a.get("nature","") or "").lower() in {"credit","دائن"}
            and not re.search(r"مجمع|مخصص|ECL|contra", str(a.get("name_raw","") or ""), re.I)]
    for a in fp06:
        alerts.append(FraudAlert(
            pattern_id="FP06", risk="Critical",
            account_code=a.get("code"), account_name=a.get("name_raw"),
            message=f"'{a.get('name_raw','')}' — أصل برصيد دائن بدون مبرر واضح (ليس مجمع إهلاك)",
        ))

    # FP07 — إخفاء الذمم (ذمم كبيرة بدون ECL)
    has_large_receivables = any(
        re.search(r"ذمم.*مدينة|مدينون|عملاء", str(a.get("name_raw","") or ""), re.I)
        for a in accounts
    )
    has_ecl = any(
        re.search(r"مخصص.*(ائتمان|ديون|ECL|مشكوك)", str(a.get("name_raw","") or ""), re.I)
        for a in accounts
    )
    if has_large_receivables and not has_ecl:
        alerts.append(FraudAlert(
            pattern_id="FP07", risk="High",
            account_code=None, account_name=None,
            message="ذمم مدينة بدون مخصص ECL — قد يكون تضخيماً مقصوداً لهامش الأصول",
        ))

    return alerts


# ═══════════════════════════════════════════════════════════════
# ملحق ك-2 — FP08 Partner Drawings Detection
# ═══════════════════════════════════════════════════════════════

def detect_fp08_partner_drawings(accounts: List[Dict], trial_balance: Optional[Dict] = None) -> Optional[FraudAlert]:
    """
    FP08: كشف سحوبات الشركاء المفرطة.
    - بدون ميزان مراجعة: تنبيه استباقي إذا وُجد حساب سحوبات
    - مع ميزان مراجعة: تنبيه إذا تجاوزت السحوبات 50% من رأس المال
    """
    drawings_accounts = []
    capital_accounts = []

    for acc in accounts:
        name = str(acc.get("name_raw", "") or acc.get("name_ar", "") or "").strip()
        code = str(acc.get("code", "") or "")
        nature = str(acc.get("nature", "") or "").lower()

        # Detect drawings accounts
        if re.search(r"سحوبات|جاري.*(شريك|مالك)|drawings|partner.*(current|withdraw)", name, re.I):
            drawings_accounts.append({"code": code, "name": name})

        # Detect capital accounts (exclude drawings)
        is_drawing = re.search(r"سحوبات|جاري.*(شريك|مالك)|drawings|partner.*(current|withdraw)", name, re.I)
        if not is_drawing and (re.search(r"رأس.*(مال|المال)|capital|equity.*paid", name, re.I) or nature in ("equity",)):
            capital_accounts.append({"code": code, "name": name})

    if not drawings_accounts:
        return None

    # With trial balance: compare drawings vs capital
    if trial_balance and isinstance(trial_balance, dict):
        total_drawings = 0.0
        total_capital = 0.0

        for d_acc in drawings_accounts:
            bal = trial_balance.get(d_acc["code"], {})
            total_drawings += abs(float(bal.get("debit", 0) or 0) - float(bal.get("credit", 0) or 0))

        for c_acc in capital_accounts:
            bal = trial_balance.get(c_acc["code"], {})
            total_capital += abs(float(bal.get("credit", 0) or 0) - float(bal.get("debit", 0) or 0))

        if total_capital > 0 and total_drawings > (total_capital * 0.3):
            ratio = round(total_drawings / total_capital * 100, 1)
            return FraudAlert(
                pattern_id="FP08", risk="Critical",
                account_code=drawings_accounts[0]["code"],
                account_name=drawings_accounts[0]["name"],
                message=f"سحوبات الشركاء ({ratio}% من رأس المال) تتجاوز الحد الآمن 30% — خطر تآكل حقوق الملكية",
            )
        return None

    # Without trial balance: proactive warning
    codes = ", ".join(d["code"] for d in drawings_accounts[:3])
    return FraudAlert(
        pattern_id="FP08", risk="Medium",
        account_code=drawings_accounts[0]["code"],
        account_name=drawings_accounts[0]["name"],
        message=f"حسابات سحوبات شركاء موجودة ({codes}) — يُنصح بمراجعة الأرصدة مقابل رأس المال",
    )


def check_trial_balance(trial_balance: Dict) -> Dict:
    """
    فحص توازن ميزان المراجعة: مجموع المدين = مجموع الدائن.
    """
    total_debit = 0.0
    total_credit = 0.0
    account_count = 0

    for code, balances in trial_balance.items():
        if not isinstance(balances, dict):
            continue
        total_debit += float(balances.get("debit", 0) or 0)
        total_credit += float(balances.get("credit", 0) or 0)
        account_count += 1

    difference = round(abs(total_debit - total_credit), 2)
    is_balanced = difference < 0.01

    return {
        "is_balanced": is_balanced,
        "total_debit": round(total_debit, 2),
        "total_credit": round(total_credit, 2),
        "difference": difference,
        "account_count": account_count,
        "status": "متوازن" if is_balanced else "غير متوازن",
    }


# ═══════════════════════════════════════════════════════════════
# ملحق ك — COA Evolution Tracking
# ═══════════════════════════════════════════════════════════════

@dataclass
class EvolutionChange:
    change_type:  str       # added | deleted | renamed | reclassified | reparented | rebalanced
    account_code: str
    old_value:    Optional[Dict] = None
    new_value:    Optional[Dict] = None
    risk_level:   str = "medium"


@dataclass
class EvolutionReport:
    total_changes:   int
    changes:         List[EvolutionChange]
    critical_count:  int
    high_count:      int
    summary:         str
    blocking_issues: List[str] = field(default_factory=list)


CRITICAL_TRANSITIONS = {
    # عربي
    ("أصول","خصوم"),       ("خصوم","أصول"),
    ("إيرادات","مصروفات"), ("مصروفات","إيرادات"),
    ("أصول","إيرادات"),    ("خصوم","حقوق الملكية"),
    # إنجليزي (من engine.py)
    ("asset","liability"),     ("liability","asset"),
    ("revenue","expense"),     ("expense","revenue"),
    ("asset","revenue"),       ("liability","equity"),
    ("current_asset","liability"), ("non_current_asset","liability"),
    ("current_asset","current_liability"), ("current_asset","non_current_liability"),
    ("equity","liability"),    ("equity","expense"),
    # مختلط
    ("asset","خصوم"),      ("liability","أصول"),
    ("revenue","مصروفات"), ("expense","إيرادات"),
}

EVOLUTION_BLOCKING_RULES = [
    {"trigger": "reclassified", "old_prefix": "أصول",    "new_prefix": "خصوم",
     "message": "حساب انتقل من الأصول للخصوم — يستلزم موافقة المدقق الخارجي"},
    {"trigger": "rebalanced",   "message": "تغيير طبيعة الحساب يؤثر على جميع القيود التاريخية"},
    {"trigger": "deleted",      "had_balance": True,
     "message": "حساب محذوف كان يحمل رصيداً — يجب التسوية أولاً"},
    {"trigger": "bulk_change",  "threshold": 0.20,
     "message": "نسبة التغيير > 20% — هل تم استيراد شجرة من نظام مختلف؟"},
]


def _assess_reclassification_risk(old: Dict, new: Dict) -> str:
    """تقييم خطورة إعادة التصنيف — يدعم القيم العربية والإنجليزية."""
    # خريطة: القيم الإنجليزية → المجموعة الرئيسية
    SECTION_GROUP = {
        "asset": "asset", "current_asset": "asset", "non_current_asset": "asset",
        "liability": "liability", "current_liability": "liability", "non_current_liability": "liability",
        "equity": "equity",
        "revenue": "revenue", "cogs": "expense",
        "expense": "expense", "finance_cost": "expense",
        "أصول": "asset", "أصول متداولة": "asset", "أصول غير متداولة": "asset",
        "خصوم": "liability", "خصوم متداولة": "liability", "خصوم غير متداولة": "liability",
        "حقوق الملكية": "equity", "إيرادات": "revenue", "مصروفات": "expense",
    }
    old_sec = str(old.get("section","")).strip().lower()
    new_sec = str(new.get("section","")).strip().lower()
    old_grp = SECTION_GROUP.get(old_sec, old_sec.split()[0] if old_sec else "")
    new_grp = SECTION_GROUP.get(new_sec, new_sec.split()[0] if new_sec else "")
    t = (old_grp, new_grp)
    CRITICAL_PAIRS = {
        ("asset","liability"), ("liability","asset"),
        ("asset","equity"),    ("equity","liability"),
        ("revenue","expense"), ("expense","revenue"),
    }
    return "critical" if t in CRITICAL_PAIRS else "high"


def compare_coa_versions(
    old_coa: List[Dict],
    new_coa: List[Dict],
) -> EvolutionReport:
    """
    ملحق ك: مقارنة نسختين من شجرة الحسابات.
    """
    old_map = {str(a.get("code","")): a for a in old_coa}
    new_map = {str(a.get("code","")): a for a in new_coa}
    old_codes = set(old_map.keys())
    new_codes = set(new_map.keys())
    changes: List[EvolutionChange] = []
    blocking: List[str] = []

    # 1. حسابات جديدة
    for code in (new_codes - old_codes):
        changes.append(EvolutionChange("added", code, new_value=new_map[code], risk_level="low"))

    # 2. حسابات محذوفة
    for code in (old_codes - new_codes):
        changes.append(EvolutionChange("deleted", code, old_value=old_map[code], risk_level="critical"))
        blocking.append(f"حذف الحساب {code}: '{old_map[code].get('name_raw','')}'")

    # 3. تغييرات الحسابات المشتركة
    for code in (old_codes & new_codes):
        old, new = old_map[code], new_map[code]

        if str(old.get("name_raw","")) != str(new.get("name_raw","")):
            changes.append(EvolutionChange("renamed", code,
                old_value={"name": old.get("name_raw")},
                new_value={"name": new.get("name_raw")}, risk_level="low"))

        if str(old.get("section","")) != str(new.get("section","")):
            risk = _assess_reclassification_risk(old, new)
            changes.append(EvolutionChange("reclassified", code,
                old_value={"section": old.get("section"), "nature": old.get("nature")},
                new_value={"section": new.get("section"), "nature": new.get("nature")},
                risk_level=risk))
            if risk == "critical":
                blocking.append(f"إعادة تصنيف حرجة للحساب {code}")

        if str(old.get("parent_code","")) != str(new.get("parent_code","")):
            changes.append(EvolutionChange("reparented", code,
                old_value={"parent": old.get("parent_code")},
                new_value={"parent": new.get("parent_code")}, risk_level="medium"))

        if str(old.get("nature","")) != str(new.get("nature","")):
            changes.append(EvolutionChange("rebalanced", code,
                old_value={"nature": old.get("nature")},
                new_value={"nature": new.get("nature")}, risk_level="critical"))
            blocking.append(f"تغيير طبيعة الحساب {code}: {old.get('nature')} → {new.get('nature')}")

    # فحص التغيير الجماعي
    total = max(len(old_codes), 1)
    if len(changes) / total > 0.20:
        blocking.append(f"نسبة التغيير {len(changes)/total:.0%} — مرتفعة جداً")

    critical_count = sum(1 for c in changes if c.risk_level == "critical")
    high_count     = sum(1 for c in changes if c.risk_level == "high")

    summary = (
        f"إجمالي التغييرات: {len(changes)} | "
        f"حرجة: {critical_count} | "
        f"مرتفعة: {high_count} | "
        f"مضافة: {len(new_codes-old_codes)} | "
        f"محذوفة: {len(old_codes-new_codes)}"
    )

    return EvolutionReport(
        total_changes=len(changes),
        changes=changes,
        critical_count=critical_count,
        high_count=high_count,
        summary=summary,
        blocking_issues=blocking,
    )


def compute_version_impact(
    old_report: Dict,
    new_report: Dict,
    evolution: EvolutionReport,
) -> Dict:
    """
    ملحق ع: يحسب أثر كل تغيير على درجة الجودة.

    reclassified صحيح → improvement
    reclassified خاطئ → degradation
    deleted حساب إلزامي → -15 نقطة
    deleted حساب كان خطأ → +5 نقاط
    added حساب إلزامي مفقود → +12 نقطة
    rebalanced (طبيعة) → critical دائماً
    """
    score_before = float(old_report.get("quality_score", 0))
    score_after = float(new_report.get("quality_score", 0))
    score_delta = round(score_after - score_before, 2)

    if score_delta > 1:
        direction = "improved"
    elif score_delta < -1:
        direction = "degraded"
    else:
        direction = "neutral"

    impact_breakdown: List[Dict] = []
    critical_regressions: List[Dict] = []
    top_improvements: List[Dict] = []

    for change in evolution.changes:
        entry = {
            "change_type": change.change_type,
            "account_code": change.account_code,
            "score_impact": 0.0,
            "direction": "neutral",
        }

        if change.change_type == "deleted":
            # Deleted accounts are generally negative
            entry["score_impact"] = -15.0
            entry["direction"] = "degradation"
            critical_regressions.append(entry.copy())

        elif change.change_type == "added":
            entry["score_impact"] = 12.0
            entry["direction"] = "improvement"
            top_improvements.append(entry.copy())

        elif change.change_type == "reclassified":
            if change.risk_level == "critical":
                entry["score_impact"] = -10.0
                entry["direction"] = "degradation"
                critical_regressions.append(entry.copy())
            else:
                entry["score_impact"] = 3.0
                entry["direction"] = "improvement"
                top_improvements.append(entry.copy())

        elif change.change_type == "rebalanced":
            entry["score_impact"] = -20.0
            entry["direction"] = "critical_regression"
            critical_regressions.append(entry.copy())

        elif change.change_type == "renamed":
            entry["score_impact"] = 1.0
            entry["direction"] = "improvement"

        elif change.change_type == "reparented":
            entry["score_impact"] = 2.0
            entry["direction"] = "improvement"

        impact_breakdown.append(entry)

    # Sort by absolute impact
    impact_breakdown.sort(key=lambda x: abs(x["score_impact"]), reverse=True)
    critical_regressions.sort(key=lambda x: x["score_impact"])
    top_improvements.sort(key=lambda x: x["score_impact"], reverse=True)

    return {
        "score_before": score_before,
        "score_after": score_after,
        "score_delta": score_delta,
        "direction": direction,
        "critical_regressions": critical_regressions[:10],
        "top_improvements": top_improvements[:10],
        "impact_breakdown": impact_breakdown[:20],
    }


# ═══════════════════════════════════════════════════════════════
# ملحق ل — Similarity Engine (قطاعي)
# ═══════════════════════════════════════════════════════════════

# قوالب قطاعية مبسطة (الـ 45 قطاع كاملة في DB)
SECTOR_TEMPLATES: Dict[str, Dict] = {
    # ── 1-8: القطاعات الأصلية ──
    "RETAIL": {
        "name_ar": "التجزئة والجملة",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","ACC_PAYABLE"],
        "optional":  ["SALES_RETURNS","PURCHASE_RETURNS","FREIGHT","MARKETING"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS","MINING_ASSETS"],
    },
    "CONSTRUCTION": {
        "name_ar": "المقاولات",
        "mandatory": ["CIP","DIRECT_LABOR","CONTRACT_REVENUE","SUBCONTRACTORS"],
        "optional":  ["EQUIPMENT_RENTAL","SITE_COSTS","RETENTION_RECEIVABLE"],
        "forbidden": ["MURABAHA_RECEIVABLE","HARVEST_INVENTORY"],
    },
    "MANUFACTURING": {
        "name_ar": "الصناعة والتصنيع",
        "mandatory": ["RAW_MATERIALS","WIP","FINISHED_GOODS","COGS","MACHINERY_EQUIPMENT"],
        "optional":  ["SCRAP_SALES","FACTORY_OVERHEAD","QUALITY_CONTROL"],
        "forbidden": ["MURABAHA_RECEIVABLE"],
    },
    "HEALTHCARE": {
        "name_ar": "الرعاية الصحية",
        "mandatory": ["MEDICAL_EQUIPMENT","MEDICAL_SUPPLIES","SERVICE_REVENUE","ACC_RECEIVABLE"],
        "optional":  ["DEFERRED_REVENUE","PATIENT_DEPOSITS","MEDICAL_INSURANCE"],
        "forbidden": ["INVENTORY","RAW_MATERIALS"],
    },
    "BANKING": {
        "name_ar": "البنوك والتمويل الإسلامي",
        "mandatory": ["MURABAHA_RECEIVABLE","CUSTOMER_DEPOSITS","IJARA_RECEIVABLE","ECL_STAGE1"],
        "optional":  ["MUSHARAKA_INVESTMENT","MURABAHA_INCOME","IJARA_INCOME"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "REAL_ESTATE": {
        "name_ar": "العقارات والتطوير",
        "mandatory": ["INVESTMENT_PROPERTY","CIP","RENTAL_INCOME","LAND"],
        "optional":  ["DEFERRED_REVENUE","ADVANCE_TO_SUPPLIERS","BROKER_COMMISSIONS"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "HAJJ_UMRAH": {
        "name_ar": "الحج والعمرة",
        "mandatory": ["PILGRIMS_DEPOSITS","HAJJ_REVENUE","HAJJ_COST","HAJJ_PACKAGES"],
        "optional":  ["ACCOMMODATION_REVENUE","TRANSPORT_REVENUE","VISA_SERVICES"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "AGRICULTURE": {
        "name_ar": "الزراعة والألبان",
        "mandatory": ["BIOLOGICAL_ASSETS","HARVEST_INVENTORY","CROP_REVENUE"],
        "optional":  ["IRRIGATION_EQUIPMENT","FERTILIZER_COSTS","FARM_VEHICLES"],
        "forbidden": ["MURABAHA_RECEIVABLE","PATIENT_DEPOSITS"],
    },
    # ── 9-45: القطاعات الجديدة ──
    "FOOD_BEVERAGE": {
        "name_ar": "الأغذية والمشروبات",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","RAW_MATERIALS","ACC_RECEIVABLE"],
        "optional":  ["PACKAGING_MATERIALS","SPOILAGE_EXPENSE","QUALITY_CONTROL"],
        "forbidden": ["MURABAHA_RECEIVABLE","MINING_ASSETS"],
    },
    "HOSPITALITY": {
        "name_ar": "الضيافة والفنادق",
        "mandatory": ["ROOM_REVENUE","SERVICE_REVENUE","ACC_RECEIVABLE","INVENTORY"],
        "optional":  ["DEFERRED_REVENUE","LOYALTY_LIABILITY","FOOD_BEVERAGE_REVENUE"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS","RAW_MATERIALS"],
    },
    "EDUCATION": {
        "name_ar": "التعليم والتدريب",
        "mandatory": ["TUITION_REVENUE","DEFERRED_REVENUE","ACC_RECEIVABLE","SALARIES_WAGES"],
        "optional":  ["STUDENT_DEPOSITS","GRANTS_INCOME","SCHOLARSHIP_EXPENSE"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "INSURANCE": {
        "name_ar": "التأمين",
        "mandatory": ["PREMIUM_REVENUE","CLAIMS_EXPENSE","UNEARNED_PREMIUM","REINSURANCE_RECEIVABLE"],
        "optional":  ["INVESTMENT_INCOME","ACTUARIAL_RESERVE","COMMISSION_EXPENSE"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "TELECOM": {
        "name_ar": "الاتصالات وتقنية المعلومات",
        "mandatory": ["SERVICE_REVENUE","ACC_RECEIVABLE","DEFERRED_REVENUE","NETWORK_EQUIPMENT"],
        "optional":  ["SPECTRUM_LICENSE","SUBSCRIBER_ACQUISITION","ROAMING_REVENUE"],
        "forbidden": ["BIOLOGICAL_ASSETS","HARVEST_INVENTORY"],
    },
    "TRANSPORT": {
        "name_ar": "النقل",
        "mandatory": ["TRANSPORT_REVENUE","VEHICLES","FUEL_EXPENSE","ACC_RECEIVABLE"],
        "optional":  ["MAINTENANCE_EXPENSE","TOLLS_EXPENSE","INSURANCE_EXPENSE"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "LOGISTICS": {
        "name_ar": "الخدمات اللوجستية",
        "mandatory": ["SERVICE_REVENUE","WAREHOUSE_COSTS","ACC_RECEIVABLE","VEHICLES"],
        "optional":  ["CUSTOMS_DUTIES","FREIGHT","STORAGE_REVENUE"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "ENERGY": {
        "name_ar": "الطاقة والكهرباء",
        "mandatory": ["ENERGY_REVENUE","GENERATION_EQUIPMENT","DEPRECIATION_EXPENSE","ACC_RECEIVABLE"],
        "optional":  ["FUEL_COSTS","GRID_MAINTENANCE","RENEWABLE_ASSETS"],
        "forbidden": ["BIOLOGICAL_ASSETS","HARVEST_INVENTORY"],
    },
    "OIL_GAS": {
        "name_ar": "النفط والغاز",
        "mandatory": ["EXPLORATION_COSTS","PRODUCTION_REVENUE","MINING_ASSETS","DEPRECIATION_EXPENSE"],
        "optional":  ["REFINERY_EQUIPMENT","PIPELINE_ASSETS","ENVIRONMENTAL_RESERVE"],
        "forbidden": ["BIOLOGICAL_ASSETS","PATIENT_DEPOSITS"],
    },
    "MINING": {
        "name_ar": "التعدين",
        "mandatory": ["MINING_ASSETS","EXTRACTION_COSTS","MINERAL_REVENUE","DEPRECIATION_EXPENSE"],
        "optional":  ["ENVIRONMENTAL_RESERVE","LAND","EXPLORATION_COSTS"],
        "forbidden": ["BIOLOGICAL_ASSETS","PATIENT_DEPOSITS"],
    },
    "GOVERNMENT": {
        "name_ar": "الجهات الحكومية",
        "mandatory": ["GOVERNMENT_GRANTS","SALARIES_WAGES","SERVICE_REVENUE","ACC_PAYABLE"],
        "optional":  ["CAPITAL_GRANTS","TRANSFERRED_ASSETS","PROGRAM_EXPENSES"],
        "forbidden": ["MURABAHA_RECEIVABLE","COGS"],
    },
    "NGO": {
        "name_ar": "المنظمات غير الربحية",
        "mandatory": ["DONATION_REVENUE","GRANT_REVENUE","PROGRAM_EXPENSES","RESTRICTED_FUNDS"],
        "optional":  ["ENDOWMENT_FUND","VOLUNTEER_EXPENSE","FUNDRAISING_EXPENSE"],
        "forbidden": ["COGS","MURABAHA_RECEIVABLE","INVENTORY"],
    },
    "PROFESSIONAL_SERVICES": {
        "name_ar": "الخدمات المهنية",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","ACC_RECEIVABLE","ACC_PAYABLE"],
        "optional":  ["DEFERRED_REVENUE","WIP","SUBCONTRACTORS"],
        "forbidden": ["INVENTORY","RAW_MATERIALS","BIOLOGICAL_ASSETS"],
    },
    "MEDIA": {
        "name_ar": "الإعلام والإنتاج",
        "mandatory": ["ADVERTISING_REVENUE","SERVICE_REVENUE","ACC_RECEIVABLE","SALARIES_WAGES"],
        "optional":  ["CONTENT_ASSETS","LICENSING_REVENUE","ROYALTY_EXPENSE"],
        "forbidden": ["BIOLOGICAL_ASSETS","MINING_ASSETS"],
    },
    "ECOMMERCE": {
        "name_ar": "التجارة الإلكترونية",
        "mandatory": ["SALES_REVENUE","INVENTORY","COGS","ACC_RECEIVABLE","SHIPPING_COSTS"],
        "optional":  ["PAYMENT_GATEWAY_FEES","RETURNS_PROVISION","MARKETING"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "AUTOMOTIVE": {
        "name_ar": "السيارات وقطع الغيار",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","WARRANTY_PROVISION"],
        "optional":  ["SPARE_PARTS_INVENTORY","SERVICE_REVENUE","SHOWROOM_ASSETS"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "PHARMA": {
        "name_ar": "الأدوية والمستحضرات",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","RAW_MATERIALS","QUALITY_CONTROL"],
        "optional":  ["R_AND_D_EXPENSE","CLINICAL_TRIAL_COSTS","LICENSING_REVENUE"],
        "forbidden": ["MINING_ASSETS","BIOLOGICAL_ASSETS"],
    },
    "DAIRY": {
        "name_ar": "الألبان والمنتجات الحيوانية",
        "mandatory": ["BIOLOGICAL_ASSETS","INVENTORY","COGS","SALES_REVENUE","HARVEST_INVENTORY"],
        "optional":  ["FEED_COSTS","VETERINARY_EXPENSE","COLD_STORAGE"],
        "forbidden": ["MURABAHA_RECEIVABLE","MINING_ASSETS"],
    },
    "INVESTMENT": {
        "name_ar": "الاستثمار وإدارة الأصول",
        "mandatory": ["INVESTMENT_INCOME","FINANCIAL_ASSETS","MANAGEMENT_FEE_REVENUE","ACC_RECEIVABLE"],
        "optional":  ["DIVIDEND_INCOME","REALIZED_GAINS","UNREALIZED_GAINS"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "HOLDING": {
        "name_ar": "الشركات القابضة",
        "mandatory": ["INVESTMENT_IN_SUBSIDIARIES","DIVIDEND_INCOME","MANAGEMENT_FEE_REVENUE","ACC_RECEIVABLE"],
        "optional":  ["INTERCOMPANY_RECEIVABLE","INTERCOMPANY_PAYABLE","GOODWILL"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "CONTRACTING": {
        "name_ar": "المقاولات العامة",
        "mandatory": ["CIP","CONTRACT_REVENUE","DIRECT_LABOR","SUBCONTRACTORS","RETENTION_RECEIVABLE"],
        "optional":  ["PERFORMANCE_BOND","EQUIPMENT_RENTAL","SITE_COSTS"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "CATERING": {
        "name_ar": "التموين والإعاشة",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","FOOD_COSTS"],
        "optional":  ["EVENT_REVENUE","CATERING_EQUIPMENT","PACKAGING_MATERIALS"],
        "forbidden": ["MURABAHA_RECEIVABLE","MINING_ASSETS"],
    },
    "CLEANING": {
        "name_ar": "خدمات النظافة",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","SUPPLIES_EXPENSE","ACC_RECEIVABLE"],
        "optional":  ["EQUIPMENT","UNIFORMS_EXPENSE","TRANSPORT_EXPENSE"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "SECURITY_SERVICES": {
        "name_ar": "خدمات الحراسات الأمنية",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","ACC_RECEIVABLE","ACC_PAYABLE"],
        "optional":  ["SECURITY_EQUIPMENT","UNIFORMS_EXPENSE","TRAINING_EXPENSE"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "PRINTING": {
        "name_ar": "الطباعة والنشر",
        "mandatory": ["SALES_REVENUE","RAW_MATERIALS","COGS","INVENTORY","MACHINERY_EQUIPMENT"],
        "optional":  ["DESIGN_REVENUE","BINDING_MATERIALS","PRINTING_SUPPLIES"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "TRADING": {
        "name_ar": "التجارة العامة",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","ACC_PAYABLE"],
        "optional":  ["PURCHASE_RETURNS","SALES_RETURNS","CUSTOMS_DUTIES"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "IMPORT_EXPORT": {
        "name_ar": "الاستيراد والتصدير",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","CUSTOMS_DUTIES","ACC_RECEIVABLE"],
        "optional":  ["FREIGHT","LETTER_OF_CREDIT","FOREX_GAINS_LOSSES"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "FRANCHISE": {
        "name_ar": "الامتياز التجاري",
        "mandatory": ["FRANCHISE_FEE","ROYALTY_EXPENSE","SALES_REVENUE","INVENTORY","ACC_RECEIVABLE"],
        "optional":  ["MARKETING","TRAINING_EXPENSE","FRANCHISE_RECEIVABLE"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "GYM_FITNESS": {
        "name_ar": "الصالات الرياضية واللياقة",
        "mandatory": ["MEMBERSHIP_REVENUE","DEFERRED_REVENUE","SERVICE_REVENUE","SALARIES_WAGES"],
        "optional":  ["EQUIPMENT","PERSONAL_TRAINING_REVENUE","SUPPLEMENT_SALES"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "DENTAL_CLINIC": {
        "name_ar": "عيادات الأسنان",
        "mandatory": ["SERVICE_REVENUE","MEDICAL_SUPPLIES","ACC_RECEIVABLE","MEDICAL_EQUIPMENT"],
        "optional":  ["PATIENT_DEPOSITS","INSURANCE_RECEIVABLE","LAB_COSTS"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "LAW_FIRM": {
        "name_ar": "المحاماة والاستشارات القانونية",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","ACC_RECEIVABLE","WIP"],
        "optional":  ["TRUST_LIABILITY","COURT_FEES","RESEARCH_EXPENSE"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "ACCOUNTING_FIRM": {
        "name_ar": "مكاتب المحاسبة والمراجعة",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","ACC_RECEIVABLE","WIP"],
        "optional":  ["DEFERRED_REVENUE","TRAINING_EXPENSE","SOFTWARE_LICENSES"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "IT_SERVICES": {
        "name_ar": "خدمات تقنية المعلومات",
        "mandatory": ["SERVICE_REVENUE","SALARIES_WAGES","ACC_RECEIVABLE","SOFTWARE_LICENSES"],
        "optional":  ["DEFERRED_REVENUE","R_AND_D_EXPENSE","HOSTING_COSTS"],
        "forbidden": ["INVENTORY","BIOLOGICAL_ASSETS","MINING_ASSETS"],
    },
    "EVENTS": {
        "name_ar": "تنظيم الفعاليات والمعارض",
        "mandatory": ["EVENT_REVENUE","DEFERRED_REVENUE","ACC_RECEIVABLE","SALARIES_WAGES"],
        "optional":  ["VENUE_COSTS","SPONSORSHIP_REVENUE","SUBCONTRACTORS"],
        "forbidden": ["INVENTORY","COGS","BIOLOGICAL_ASSETS"],
    },
    "DECORATION": {
        "name_ar": "الديكور والتصميم الداخلي",
        "mandatory": ["SERVICE_REVENUE","INVENTORY","COGS","ACC_RECEIVABLE","SUBCONTRACTORS"],
        "optional":  ["DESIGN_REVENUE","MATERIAL_COSTS","CIP"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
    "FASHION_RETAIL": {
        "name_ar": "الأزياء والموضة",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","ACC_PAYABLE"],
        "optional":  ["SALES_RETURNS","MARKETING","SEASONAL_MARKDOWN"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS","MINING_ASSETS"],
    },
    "JEWELRY": {
        "name_ar": "المجوهرات والذهب",
        "mandatory": ["INVENTORY","COGS","SALES_REVENUE","ACC_RECEIVABLE","GOLD_INVENTORY"],
        "optional":  ["MANUFACTURING_COSTS","APPRAISAL_COSTS","CONSIGNMENT_INVENTORY"],
        "forbidden": ["MURABAHA_RECEIVABLE","BIOLOGICAL_ASSETS"],
    },
}


@dataclass
class SimilarityResult:
    sector:               str
    sector_name_ar:       str
    similarity_pct:       float
    mandatory_coverage:   str
    missing_mandatory:    List[str]
    forbidden_found:      List[str]
    suggestions:          List[str]


def compute_coa_similarity(
    accounts: List[Dict],
    sector_code: str,
) -> SimilarityResult:
    """
    ملحق ل: يقيس التشابه على 4 محاور مُرجَّحة.
    """
    template = SECTOR_TEMPLATES.get(sector_code.upper(), {})
    if not template:
        return SimilarityResult(sector_code,"",0,"0/0",[],[],[])

    client_concepts = {str(a.get("concept_id","") or "") for a in accounts if a.get("concept_id")}
    client_names    = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    mandatory = template.get("mandatory", [])
    optional  = template.get("optional", [])
    forbidden = template.get("forbidden", [])

    # محور 1: تغطية الحسابات الإلزامية (50%)
    mandatory_covered = [m for m in mandatory if m in client_concepts]
    coverage_score    = len(mandatory_covered) / max(len(mandatory), 1)

    # محور 2: الحسابات الاختيارية (25%)
    optional_covered = [o for o in optional if o in client_concepts]
    optional_score   = len(optional_covered) / max(len(optional), 1)

    # محور 3: غياب المحظورات (15%)
    forbidden_present = [f for f in forbidden if f in client_concepts]
    forbidden_score   = 1.0 - len(forbidden_present) / max(len(forbidden), 1)

    # محور 4: نمط الأكواد (10%)
    code_pattern_score = 0.8  # افتراضي — يُحسَّن مع البيانات الفعلية

    total = (coverage_score * 0.50 + optional_score * 0.25 +
             forbidden_score * 0.15 + code_pattern_score * 0.10)

    missing = [m for m in mandatory if m not in client_concepts]
    suggestions = [f"أضف حساب '{m}' الإلزامي لقطاع {template.get('name_ar','')}" for m in missing[:3]]
    if forbidden_present:
        suggestions.append(f"راجع: {', '.join(forbidden_present)} غير معتاد في هذا القطاع")

    return SimilarityResult(
        sector=sector_code,
        sector_name_ar=template.get("name_ar",""),
        similarity_pct=round(total * 100, 1),
        mandatory_coverage=f"{len(mandatory_covered)}/{len(mandatory)}",
        missing_mandatory=missing,
        forbidden_found=forbidden_present,
        suggestions=suggestions,
    )


def rank_all_sectors(accounts: List[Dict]) -> List[SimilarityResult]:
    """يُشغِّل المقارنة على كل القوالب ويُرتِّبها تنازلياً."""
    results = [compute_coa_similarity(accounts, sec) for sec in SECTOR_TEMPLATES]
    return sorted(results, key=lambda r: r.similarity_pct, reverse=True)


def detect_sector(accounts: List[Dict]) -> Optional[str]:
    """يكتشف القطاع الأرجح تلقائياً."""
    ranked = rank_all_sectors(accounts)
    if ranked and ranked[0].similarity_pct >= 50:
        return ranked[0].sector
    return None
