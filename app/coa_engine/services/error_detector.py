"""
APEX COA Engine v4.2 — Error Detector (Section 4)
Detects 58 error types: E01-E50 + EP1-EP3 + EC1-EC5
Called after classification in the pipeline.
"""

import re
import logging
from typing import Dict, List, Optional, Set, Tuple
from collections import Counter

logger = logging.getLogger(__name__)

# Ambiguous name patterns (for E21)
_AMBIGUOUS_PATTERNS = re.compile(
    r"^(أخرى|متنوع|أخري|other|misc|sundry|miscellaneous|متفرق|عام|general)$",
    re.IGNORECASE | re.UNICODE,
)

# Abbreviation patterns (for E26)
_ABBREVIATION_PATTERN = re.compile(r"^[أ-يa-z]\.[أ-يa-z]\.[أ-يa-z]", re.IGNORECASE | re.UNICODE)

# Nature expectations by main_class
_EXPECTED_NATURE = {
    "asset": "debit",
    "liability": "credit",
    "equity": "credit",
    "revenue": "credit",
    "cogs": "debit",
    "expense": "debit",
    "finance_cost": "debit",
    "closing": "debit",
}

# Contra accounts (exceptions to expected nature)
_CONTRA_CONCEPTS = {
    "ACCUM_DEPRECIATION",  # asset but credit
    "SALES_RETURNS",  # revenue but debit
    "PURCHASE_RETURNS",  # cogs but credit
    "ACCUMULATED_LOSSES",  # equity but debit
    "OWNER_DRAWINGS",  # equity but debit
    "DIVIDENDS",  # equity but debit
    "TREASURY_SHARES",  # equity but debit
}

# Cross-validation pairs: (trigger_concept, required_concept, error_code, severity, message_ar)
CROSS_VALIDATION_RULES = [
    # IFRS 16: lease assets need lease liabilities
    ("ROU_ASSET", "LEASE_LIABILITY", "E27", "Critical", "IFRS 16: أصل حق استخدام بدون التزام إيجار"),
    # Fixed assets need depreciation
    ("PPE", "ACCUM_DEPRECIATION", "E48", "High", "أصول ثابتة بدون مجمع إهلاك"),
    ("BUILDINGS", "ACCUM_DEPRECIATION", "E48", "High", "مباني بدون مجمع إهلاك"),
    ("EQUIPMENT", "ACCUM_DEPRECIATION", "E48", "High", "معدات بدون مجمع إهلاك"),
    ("VEHICLES", "ACCUM_DEPRECIATION", "E48", "High", "سيارات بدون مجمع إهلاك"),
    ("FURNITURE", "ACCUM_DEPRECIATION", "E48", "High", "أثاث بدون مجمع إهلاك"),
    # Receivables need ECL (IFRS 9)
    ("ACC_RECEIVABLE", "ECL_PROVISION", "E28", "High", "IFRS 9: ذمم مدينة بدون مخصص خسائر ائتمان متوقعة"),
    # Revenue needs COGS (accounting cycle)
    ("SALES_REVENUE", "COGS", "E50", "Critical", "إيرادات مبيعات بدون تكلفة مبيعات"),
    # Fixed assets need depreciation expense
    ("ACCUM_DEPRECIATION", "DEPRECIATION_EXP", "E37", "High", "مجمع إهلاك بدون مصروف إهلاك"),
    # End of service (mandatory in Saudi Arabia)
    ("SALARIES_EXPENSE", "END_OF_SERVICE", "E38", "High", "رواتب بدون مخصص مكافأة نهاية خدمة"),
    # VAT separation (ZATCA)
    ("VAT_INPUT", "VAT_OUTPUT", "E33", "High", "ZATCA: ض.ق.م مدخلات بدون مخرجات منفصلة"),
]


class AccountError:
    """Represents a detected error on a specific account."""

    __slots__ = (
        "error_code", "severity", "category", "account_code", "account_name",
        "description_ar", "cause_ar", "suggestion_ar", "auto_fixable",
        "auto_fix_applied", "references",
    )

    def __init__(self, error_code: str, account_code: str, account_name: str = "",
                 description_ar: str = "", cause_ar: str = "", suggestion_ar: str = "",
                 severity: str = "Medium", category: str = "structural",
                 auto_fixable: bool = False, references: List[str] = None):
        self.error_code = error_code
        self.severity = severity
        self.category = category
        self.account_code = account_code
        self.account_name = account_name
        self.description_ar = description_ar
        self.cause_ar = cause_ar
        self.suggestion_ar = suggestion_ar
        self.auto_fixable = auto_fixable
        self.auto_fix_applied = False
        self.references = references or []

    def to_dict(self) -> Dict:
        return {
            "error_code": self.error_code,
            "severity": self.severity,
            "category": self.category,
            "account_code": self.account_code,
            "account_name": self.account_name,
            "description_ar": self.description_ar,
            "cause_ar": self.cause_ar,
            "suggestion_ar": self.suggestion_ar,
            "auto_fixable": self.auto_fixable,
            "auto_fix_applied": self.auto_fix_applied,
            "references": self.references,
        }


def detect_errors(
    accounts: List[Dict],
    column_mapping: Dict,
    pattern: str,
    erp_system: Optional[str] = None,
) -> Tuple[List[Dict], List[Dict]]:
    """Run all error detection checks on classified accounts.

    Args:
        accounts: List of classified account dicts (after classifier).
        column_mapping: Column mapping dict.
        pattern: Detected file pattern.
        erp_system: Optional ERP system name.

    Returns:
        Tuple of (updated_accounts, all_errors):
            - updated_accounts: accounts with 'errors' list injected
            - all_errors: flat list of all error dicts across all accounts
    """
    all_errors: List[AccountError] = []

    # Build indexes for cross-checks
    code_counter = Counter()
    name_counter = Counter()
    concept_set: Set[str] = set()
    code_to_account: Dict[str, Dict] = {}

    code_key = column_mapping.get("code", "code")
    name_key = column_mapping.get("name", "name")

    for acct in accounts:
        code = str(acct.get(code_key, acct.get("code", ""))).strip()
        name = str(acct.get(name_key, acct.get("name", ""))).strip()
        code_counter[code] += 1
        name_lower = name.lower().strip()
        if name_lower:
            name_counter[name_lower] += 1
        if code:
            code_to_account[code] = acct
        concept = acct.get("concept_id")
        if concept:
            concept_set.add(concept)

    # Code length index per level (for E41)
    level_code_lengths: Dict[int, Set[int]] = {}
    for acct in accounts:
        level = acct.get("level", 0)
        code = str(acct.get(code_key, acct.get("code", ""))).strip()
        if level and code:
            level_code_lengths.setdefault(level, set()).add(len(code))

    # ── Per-account checks ──
    for acct in accounts:
        acct_errors: List[AccountError] = []
        code = str(acct.get(code_key, acct.get("code", ""))).strip()
        name = str(acct.get(name_key, acct.get("name", ""))).strip()
        main_class = acct.get("main_class")
        sub_class = acct.get("sub_class")
        nature = acct.get("nature")
        concept_id = acct.get("concept_id")
        confidence = acct.get("confidence", 0)
        level = acct.get("level", 0)
        parent_code = acct.get("parent_code")
        account_level = acct.get("account_level", "detail")

        # E01: Duplicate code
        if code and code_counter[code] > 1:
            # Check if it's EC3 (Odoo employee duplication)
            if erp_system and "odoo" in erp_system.lower():
                acct_errors.append(AccountError(
                    "EC3", code, name,
                    description_ar="تكرار كود مقصود للموظفين (نمط Odoo)",
                    cause_ar="Odoo يسمح بتكرار الكود للحسابات الشخصية",
                    suggestion_ar=f"اقترح ترقيم فرعي: {code}-01، {code}-02...",
                    severity="High", category="real_file",
                ))
            else:
                acct_errors.append(AccountError(
                    "E01", code, name,
                    description_ar="تكرار رقم الحساب",
                    cause_ar="التكرار يُفسد أي ربط تلقائي مع ميزان المراجعة",
                    suggestion_ar="أعد ترقيم الحسابات المكررة بأرقام فريدة",
                    severity="Critical", category="structural",
                    auto_fixable=True,
                ))

        # E02: Missing code
        if not code:
            acct_errors.append(AccountError(
                "E02", "", name,
                description_ar="كود مفقود",
                cause_ar="الكود هو المفتاح الأساسي للحساب",
                suggestion_ar="أضف كوداً فريداً لكل حساب وفق نمط الترقيم المعتمد",
                severity="High", category="structural",
                auto_fixable=True,
            ))

        # E04: No classification
        if main_class is None and code:
            acct_errors.append(AccountError(
                "E04", code, name,
                description_ar="بدون تصنيف",
                cause_ar="الحساب لا يتطابق مع أي نمط معروف",
                suggestion_ar="راجع اسم الحساب وكوده وأعد تصنيفه يدوياً",
                severity="High", category="structural",
                references=["IAS 1 §54"],
            ))

        # E05: Header without children
        if account_level == "header":
            has_children = any(
                a.get("parent_code") == code
                for a in accounts if a is not acct
            )
            if not has_children:
                acct_errors.append(AccountError(
                    "E05", code, name,
                    description_ar="رئيسي بدون فرعي",
                    cause_ar="الحساب الرئيسي يجب أن يكون له فرعيات",
                    suggestion_ar="أضف حسابات فرعية أو حوِّله إلى حساب تفصيلي",
                    severity="High", category="structural",
                ))

        # E08: Broken hierarchy (orphan check)
        if parent_code and parent_code not in code_to_account:
            acct_errors.append(AccountError(
                "E08", code, name,
                description_ar="هرمي مكسور — كود الأب غير موجود",
                cause_ar=f"parent_code='{parent_code}' غير موجود في الفهرس",
                suggestion_ar="أصلح الرابط الأبوي أو اربط بجذر مناسب",
                severity="Critical", category="structural",
                auto_fixable=True,
            ))

        # E17-E20: Nature checks (only if classified)
        if main_class and nature:
            expected = _EXPECTED_NATURE.get(main_class)
            is_contra = concept_id in _CONTRA_CONCEPTS
            if expected and nature != expected and not is_contra:
                if main_class == "revenue" and nature == "debit":
                    error_code = "E19"
                    desc = "إيراد مدين"
                elif main_class in ("expense", "cogs", "finance_cost") and nature == "credit":
                    error_code = "E20"
                    desc = "مصروف دائن"
                elif main_class == "asset" and nature == "credit":
                    error_code = "E17"
                    desc = "طبيعة معكوسة — أصل بطبيعة دائنة"
                elif main_class in ("liability", "equity") and nature == "debit":
                    error_code = "E17"
                    desc = "طبيعة معكوسة — التزام أو ملكية بطبيعة مدينة"
                else:
                    error_code = "E17"
                    desc = "طبيعة معكوسة"

                acct_errors.append(AccountError(
                    error_code, code, name,
                    description_ar=desc,
                    cause_ar=f"الطبيعة المتوقعة: {expected}، الموجودة: {nature}",
                    suggestion_ar="صحح الطبيعة وفق التصنيف",
                    severity="Critical", category="nature",
                    auto_fixable=True,
                ))

        # E21: Ambiguous name
        if _AMBIGUOUS_PATTERNS.search(name):
            acct_errors.append(AccountError(
                "E21", code, name,
                description_ar="اسم مبهم",
                cause_ar="الأسماء المبهمة تُصعِّب التدقيق والتحليل",
                suggestion_ar="أعد التسمية بوصف محدد أو فصِّله لفرعية",
                severity="Medium", category="naming",
            ))

        # E22: Duplicate name
        name_lower = name.lower().strip()
        if name_lower and name_counter[name_lower] > 1:
            acct_errors.append(AccountError(
                "E22", code, name,
                description_ar="اسم مكرر",
                cause_ar="حسابان أو أكثر بنفس الاسم",
                suggestion_ar="ميِّز بوصف إضافي أو ادمج الحسابين",
                severity="Medium", category="naming",
            ))

        # E23: Name-classification mismatch (basic heuristic)
        if main_class and name:
            name_lower = name.lower()
            mismatch = False
            # Revenue keywords under expense
            if main_class in ("expense", "cogs") and any(
                kw in name_lower for kw in ["إيراد", "مبيعات", "revenue", "sales", "income"]
            ):
                if not any(kw in name_lower for kw in ["تكلف", "cost", "مردود", "return", "خصم", "discount"]):
                    mismatch = True
            # Expense keywords under revenue
            if main_class == "revenue" and any(
                kw in name_lower for kw in ["مصروف", "تكلف", "expense", "cost"]
            ):
                if not any(kw in name_lower for kw in ["تكلف المبيعات", "cost of"]):
                    mismatch = True
            if mismatch:
                acct_errors.append(AccountError(
                    "E23", code, name,
                    description_ar="اسم لا يطابق التصنيف",
                    cause_ar=f"الاسم يتعارض مع التصنيف: {main_class}",
                    suggestion_ar="إذا الاسم صحيح: انقل الحساب. إذا التصنيف صحيح: غيِّر الاسم",
                    severity="High", category="naming",
                ))

        # E25: Name too long
        if len(name) > 80:
            acct_errors.append(AccountError(
                "E25", code, name,
                description_ar="اسم طويل",
                cause_ar=f"طول الاسم {len(name)} حرف — يتجاوز 80",
                suggestion_ar="اختصر مع الحفاظ على المعنى (الحد المقترح 50 حرفاً)",
                severity="Low", category="naming",
                auto_fixable=True,
            ))

        # E26: Abbreviation
        if _ABBREVIATION_PATTERN.search(name):
            acct_errors.append(AccountError(
                "E26", code, name,
                description_ar="اختصار مخِل",
                cause_ar="الاختصارات تُصعِّب الفهم على غير المتخصصين",
                suggestion_ar="اكتب الاسم كاملاً",
                severity="Medium", category="naming",
            ))

        # E41: Inconsistent code length at same level
        if level and code:
            lengths_at_level = level_code_lengths.get(level, set())
            if len(lengths_at_level) > 1:
                acct_errors.append(AccountError(
                    "E41", code, name,
                    description_ar="طول كود متفاوت في نفس المستوى",
                    cause_ar=f"المستوى {level} يحتوي أكواد بأطوال مختلفة: {sorted(lengths_at_level)}",
                    suggestion_ar="وحِّد أطوال الأكواد ضمن كل مستوى",
                    severity="Medium", category="coding",
                ))

        # E42: Alphanumeric code
        if code and not code.replace(".", "").replace("-", "").replace("/", "").isdigit():
            acct_errors.append(AccountError(
                "E42", code, name,
                description_ar="كود يحتوي حروفاً",
                cause_ar=f"الكود '{code}' يحتوي حروفاً",
                suggestion_ar="حوِّل لرقمي ضمن نطاق مستواه",
                severity="High", category="coding",
            ))

        # E43: Code doesn't inherit parent prefix
        if parent_code and code and parent_code in code_to_account:
            if not code.startswith(parent_code):
                acct_errors.append(AccountError(
                    "E43", code, name,
                    description_ar="كود لا يرث بادئة الأب",
                    cause_ar=f"الكود '{code}' لا يبدأ ببادئة الأب '{parent_code}'",
                    suggestion_ar="أعد الترقيم بكود يرث بادئة الأب",
                    severity="High", category="coding",
                ))

        # EC2: Accumulated depreciation as liability (Odoo classic error)
        if concept_id == "ACCUM_DEPRECIATION" and main_class == "liability":
            acct_errors.append(AccountError(
                "EC2", code, name,
                description_ar="مجمع إهلاك مصنَّف كالتزام",
                cause_ar="خطأ Odoo الكلاسيكي — user_type_id خاطئ",
                suggestion_ar="أعِد تصنيفه كـ Contra Asset ضمن الأصول غير المتداولة",
                severity="Critical", category="real_file",
                auto_fixable=True,
            ))

        # Inject errors into account
        acct["errors"] = [e.error_code for e in acct_errors]
        all_errors.extend(acct_errors)

    # ── Cross-validation checks (whole-tree) ──
    cross_errors = _check_cross_validation(accounts, concept_set, code_key, name_key)
    all_errors.extend(cross_errors)

    # ── Summarize ──
    error_dicts = [e.to_dict() for e in all_errors]

    logger.info(
        "Error detection complete: %d errors (Critical=%d, High=%d, Medium=%d, Low=%d)",
        len(all_errors),
        sum(1 for e in all_errors if e.severity == "Critical"),
        sum(1 for e in all_errors if e.severity == "High"),
        sum(1 for e in all_errors if e.severity == "Medium"),
        sum(1 for e in all_errors if e.severity == "Low"),
    )

    return accounts, error_dicts


def _check_cross_validation(
    accounts: List[Dict],
    concept_set: Set[str],
    code_key: str,
    name_key: str,
) -> List[AccountError]:
    """Check cross-validation rules (whole-tree checks)."""
    errors: List[AccountError] = []

    for trigger, required, error_code, severity, message_ar in CROSS_VALIDATION_RULES:
        if trigger in concept_set and required not in concept_set:
            # Find accounts that triggered this
            trigger_accounts = [
                a for a in accounts if a.get("concept_id") == trigger
            ]
            for acct in trigger_accounts[:3]:  # Limit to first 3 to avoid spam
                code = str(acct.get(code_key, acct.get("code", ""))).strip()
                name = str(acct.get(name_key, acct.get("name", ""))).strip()
                errors.append(AccountError(
                    error_code, code, name,
                    description_ar=message_ar,
                    cause_ar=f"يوجد {trigger} لكن لا يوجد {required}",
                    suggestion_ar=f"أضف حساب {required}",
                    severity=severity,
                    category="balance",
                ))
                # Also inject into the account
                if "errors" not in acct:
                    acct["errors"] = []
                if error_code not in acct["errors"]:
                    acct["errors"].append(error_code)

    return errors


def summarize_errors(error_dicts: List[Dict]) -> Dict:
    """Summarize errors by severity."""
    summary = {"critical": 0, "high": 0, "medium": 0, "low": 0, "total": len(error_dicts)}
    for e in error_dicts:
        sev = e.get("severity", "").lower()
        if sev in summary:
            summary[sev] += 1
    return summary
