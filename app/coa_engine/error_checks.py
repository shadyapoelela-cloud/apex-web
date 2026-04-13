"""
APEX COA Engine v4.3 — Error Checks (Wave 1: E01-E20)
======================================================
محرك كشف الأخطاء — الفئات الحرجة التي تغطي 80% من مشكلات COA الحقيقية.

كل دالة مستخرجة مباشرة من الوثيقة (القسم 4):
  E01-E08: أخطاء هيكلية
  E09-E16: أخطاء تصنيفية
  E17-E20: أخطاء الطبيعة المحاسبية

الاستخدام:
    from apex_coa.error_checks import run_all_checks
    errors = run_all_checks(accounts, tree)
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set


# ─────────────────────────────────────────────────────────────
# Data Classes
# ─────────────────────────────────────────────────────────────
@dataclass
class COAError:
    """
    خطأ مكتشف في شجرة الحسابات.
    كل حقل مستخرج من مواصفات الوثيقة (القسم 4).
    """
    error_code:       str                      # E01, E08, EC2 ...
    severity:         str                      # Critical | High | Medium | Low
    category:         str                      # structural | classification | nature
    account_code:     Optional[str] = None
    account_name:     Optional[str] = None
    description_ar:   str = ""
    cause_ar:         str = ""
    suggestion_ar:    str = ""
    auto_fixable:     bool = False
    auto_fix_applied: bool = False
    references:       List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "error_code":       self.error_code,
            "severity":         self.severity,
            "category":         self.category,
            "account_code":     self.account_code,
            "account_name":     self.account_name,
            "description_ar":   self.description_ar,
            "cause_ar":         self.cause_ar,
            "suggestion_ar":    self.suggestion_ar,
            "auto_fixable":     self.auto_fixable,
            "auto_fix_applied": self.auto_fix_applied,
            "references":       self.references,
        }


# ─────────────────────────────────────────────────────────────
# ═══ الفئة الهيكلية: E01 - E08 ═══════════════════════════════
# ─────────────────────────────────────────────────────────────

def check_E01_duplicate_code(accounts: List[Dict]) -> List[COAError]:
    """
    E01 — تكرار رقم الحساب (Duplicate Code) | Critical | ✅ إصلاح تلقائي

    الوصف: نفس كود الحساب يظهر لأكثر من حساب في نفس الشجرة.
    السبب: التكرار يُفسد أي ربط تلقائي مع ميزان المراجعة أو القيود.
    المراجع: IASC Framework | SOCPA: الدليل المحاسبي
    """
    errors: List[COAError] = []
    seen: Dict[str, str] = {}       # code → account_name

    for acc in accounts:
        code = str(acc.get("code", "")).strip()
        name = str(acc.get("name_raw", acc.get("name", "")))
        if not code:
            continue
        if code in seen:
            errors.append(COAError(
                error_code="E01",
                severity="Critical",
                category="structural",
                account_code=code,
                account_name=name,
                description_ar=f"الكود {code!r} مكرر — يظهر مع: {seen[code]!r}",
                cause_ar="تكرار الكود يُفسد الربط مع ميزان المراجعة والقيود المحاسبية",
                suggestion_ar="أعطِ كل حساب كوداً فريداً. إذا تشابها: ادمجهما أو ميِّز بكود فرعي",
                auto_fixable=True,
                references=["IASC Framework", "SOCPA: الدليل المحاسبي"],
            ))
        else:
            seen[code] = name

    return errors


def check_E02_missing_code(accounts: List[Dict]) -> List[COAError]:
    """
    E02 — كود مفقود (Missing Code) | High | ✅ إصلاح تلقائي

    الوصف: حساب موجود في الشجرة بدون كود رقمي (فراغ أو NaN).
    السبب: الحساب بدون كود لا يمكن الاستدلال عليه في أي تقرير.
    المراجع: IAS 1: تعريف واضح لكل بند
    """
    errors: List[COAError] = []

    for acc in accounts:
        code = acc.get("code")
        name = str(acc.get("name_raw", acc.get("name", "")))

        is_missing = (
            code is None
            or str(code).strip() == ""
            or str(code).strip().lower() in {"nan", "none", "null", "محذوف"}
        )

        if is_missing:
            errors.append(COAError(
                error_code="E02",
                severity="High",
                category="structural",
                account_code=None,
                account_name=name,
                description_ar=f"حساب '{name}' موجود بدون كود رقمي",
                cause_ar="كل حساب يحمل كوداً لتتبعه — الحساب بدون كود لا يظهر في أي تقرير",
                suggestion_ar="أضف كوداً متسلسلاً ضمن نطاق مستواه الهرمي",
                auto_fixable=True,
                references=["IAS 1: تعريف واضح لكل بند"],
            ))

    return errors


def check_E03_non_sequential(accounts: List[Dict]) -> List[COAError]:
    """
    E03 — ترقيم غير متسلسل (Non-Sequential) | Medium | 🔧 يدوي

    الوصف: فجوات واضحة في تسلسل الأكواد داخل نفس المجموعة.
    السبب: الفجوات تشير لحسابات محذوفة قد تكون استُخدمت في قيود سابقة.
    المراجع: Numbering Best Practices
    """
    errors: List[COAError] = []

    # نجمّع الأكواد الرقمية حسب بادئة المجموعة (أول رقمين)
    from collections import defaultdict
    groups: Dict[str, List[int]] = defaultdict(list)

    for acc in accounts:
        code = str(acc.get("code", "")).strip()
        if code.isdigit() and len(code) >= 2:
            prefix = code[:2]
            groups[prefix].append(int(code))

    for prefix, codes in groups.items():
        if len(codes) < 3:
            continue
        codes_sorted = sorted(codes)
        # نبحث عن فجوات كبيرة (> 10 في المئة من النطاق)
        code_range = codes_sorted[-1] - codes_sorted[0]
        if code_range == 0:
            continue
        for i in range(1, len(codes_sorted)):
            gap = codes_sorted[i] - codes_sorted[i - 1]
            if gap > max(10, code_range * 0.1):
                errors.append(COAError(
                    error_code="E03",
                    severity="Medium",
                    category="structural",
                    account_code=f"{prefix}XXX",
                    description_ar=f"فجوة في ترقيم المجموعة {prefix}: "
                                   f"من {codes_sorted[i-1]} إلى {codes_sorted[i]} (فجوة={gap})",
                    cause_ar="الفجوات تشير لحسابات محذوفة — تحقق أنها لم تُستخدَم في قيود سابقة",
                    suggestion_ar="وثِّق الفجوات. تحقق من أن الحسابات المحذوفة لم تُستخدَم في قيود",
                    auto_fixable=False,
                    references=["Numbering Best Practices"],
                ))
                break   # خطأ واحد لكل مجموعة يكفي

    return errors


def check_E04_no_classification(accounts: List[Dict]) -> List[COAError]:
    """
    E04 — بدون تصنيف (No Classification) | High | 🔧 يدوي

    الوصف: حساب غير مصنَّف ضمن أي من الأقسام الخمسة الرئيسية.
    السبب: كل حساب ينتمي لقسم محاسبي محدد لظهوره في القوائم المالية.
    المراجع: IAS 1: تصنيف العرض المالي
    """
    errors: List[COAError] = []
    valid_sections = {
        "أصول متداولة", "أصول غير متداولة", "أصول ثابتة",
        "خصوم متداولة", "خصوم غير متداولة",
        "حقوق الملكية",
        "إيرادات", "تكلفة المبيعات", "مصروفات", "تكاليف تمويل",
        "حسابات ختامية",
        "current_asset", "non_current_asset", "current_liability",
        "non_current_liability", "equity", "revenue", "cogs",
        "expense", "finance_cost", "closing",
    }

    for acc in accounts:
        section = acc.get("section") or acc.get("classified_as")
        concept = acc.get("concept_id")
        code = str(acc.get("code", ""))
        name = str(acc.get("name_raw", acc.get("name", "")))

        # حسابات 8XXX (ختامية) مستثناة
        if code.startswith("8") or code.startswith("8"):
            continue

        if not section and not concept:
            errors.append(COAError(
                error_code="E04",
                severity="High",
                category="structural",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) غير مصنَّف ضمن أي قسم رئيسي",
                cause_ar="كل حساب ينتمي لقسم محاسبي محدد لظهوره في القوائم المالية",
                suggestion_ar="حدِّد طبيعة الحساب من سياقه (اسمه + موقعه + أبيه) وصنِّفه",
                auto_fixable=False,
                references=["IAS 1: تصنيف العرض المالي"],
            ))

    return errors


def check_E05_header_no_children(accounts: List[Dict], tree: Dict) -> List[COAError]:
    """
    E05 — رئيسي بدون فرعي (No Children) | High | 🔧 يدوي

    الوصف: حساب مُعرَّف كـ Header لكنه لا يحمل أي حسابات فرعية.
    السبب: الحساب الرئيسي بدون فروع رصيده صفر دائماً ولا يؤدي وظيفة.
    المراجع: IASC Framework: حسابات التحكم والتفصيلية
    """
    errors: List[COAError] = []

    # نبني مجموعة الأكواد التي لها أبناء
    codes_with_children: Set[str] = set()
    for acc in accounts:
        parent = str(acc.get("parent_code", "") or "").strip()
        if parent:
            codes_with_children.add(parent)

    for acc in accounts:
        code  = str(acc.get("code", "")).strip()
        name  = str(acc.get("name_raw", acc.get("name", "")))
        level = str(acc.get("account_level", "") or acc.get("level_type", "")).lower()
        utype = str(acc.get("user_type_id", "") or acc.get("type", "")).lower()

        is_header = (
            level in {"header", "رئيسي", "view"}
            or "رئيسي" in utype
            or "header" in utype
        )

        if is_header and code not in codes_with_children:
            errors.append(COAError(
                error_code="E05",
                severity="High",
                category="structural",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب الرئيسي '{name}' ({code}) بدون حسابات فرعية",
                cause_ar="الحساب الرئيسي بدون فروع رصيده صفر دائماً ولا يؤدي وظيفة",
                suggestion_ar="حوِّله لـ Posting إذا يُرحَّل إليه مباشرة، أو أضف الحسابات الفرعية المنطقية",
                auto_fixable=False,
                references=["IASC Framework: حسابات التحكم والتفصيلية"],
            ))

    return errors


def check_E06_inconsistent_detail(accounts: List[Dict]) -> List[COAError]:
    """
    E06 — تفصيل غير متناسق (Inconsistent Detail) | Medium | 🔧 يدوي

    الوصف: مجموعات مُفصَّلة جداً بينما مجموعات موازية تحمل 1-2 حسابات.
    المراجع: IAS 1 §29: مبدأ الأهمية النسبية
    """
    errors: List[COAError] = []
    from collections import defaultdict

    # نحسب عدد الأبناء لكل حساب رئيسي
    children_count: Dict[str, int] = defaultdict(int)
    parent_names: Dict[str, str] = {}

    for acc in accounts:
        parent = str(acc.get("parent_code", "") or "").strip()
        code   = str(acc.get("code", "")).strip()
        name   = str(acc.get("name_raw", acc.get("name", "")))
        parent_names[code] = name
        if parent:
            children_count[parent] += 1

    if not children_count:
        return errors

    counts = list(children_count.values())
    if len(counts) < 3:
        return errors

    avg = sum(counts) / len(counts)
    # نعلّم المجموعات الكبيرة جداً والصغيرة جداً
    for parent_code, count in children_count.items():
        if count > avg * 3 and avg > 2:
            errors.append(COAError(
                error_code="E06",
                severity="Medium",
                category="structural",
                account_code=parent_code,
                account_name=parent_names.get(parent_code, ""),
                description_ar=f"المجموعة {parent_code} تحمل {count} حساباً (متوسط الشجرة: {avg:.1f})",
                cause_ar="عدم الاتساق في مستوى التفصيل يصعِّب المقارنة والتحليل",
                suggestion_ar="راجع مستوى التفصيل المطلوب لكل مجموعة واجعله متناسقاً",
                auto_fixable=False,
                references=["IAS 1 §29: مبدأ الأهمية النسبية"],
            ))

    return errors


def check_E07_mix_header_posting(accounts: List[Dict]) -> List[COAError]:
    """
    E07 — خلط رئيسي/فرعي (Mix Parent-Child) | High | ✅ إصلاح تلقائي

    الوصف: حساب Header يقبل قيوداً مباشرة، أو حساب Posting يحمل فروعاً.
    المراجع: IFRS Foundation: Chart of Accounts Design
    """
    errors: List[COAError] = []
    codes_with_children: Set[str] = set()

    for acc in accounts:
        parent = str(acc.get("parent_code", "") or "").strip()
        if parent:
            codes_with_children.add(parent)

    for acc in accounts:
        code   = str(acc.get("code", "")).strip()
        name   = str(acc.get("name_raw", acc.get("name", "")))
        level  = str(acc.get("account_level", "") or "").lower()
        utype  = str(acc.get("user_type_id", "") or "").lower()

        is_posting = (
            level in {"detail", "posting", "تفصيلي"}
            or "payable" in utype
            or "receivable" in utype
        )
        has_children = code in codes_with_children

        if is_posting and has_children:
            errors.append(COAError(
                error_code="E07",
                severity="High",
                category="structural",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) مُعرَّف كـ Posting لكنه يحمل فروعاً",
                cause_ar="الفصل بين حسابات التحكم وحسابات الترحيل أساسي لصحة الإجماليات",
                suggestion_ar="إذا يحمل فروعاً → Header فقط. إذا لا فروع → Posting",
                auto_fixable=True,
                references=["IFRS Foundation: Chart of Accounts Design"],
            ))

    return errors


def check_E08_broken_hierarchy(accounts: List[Dict]) -> List[COAError]:
    """
    E08 — هرمي مكسور (Broken Hierarchy) | Critical | ✅ إصلاح تلقائي

    الوصف: سلسلة الهرمية منقطعة — حساب يشير لأب غير موجود أو حلقة دورية.
    السبب: الهرمية المكسورة تجعل بناء القوائم المالية مستحيلاً.
    المراجع: IASC Framework: تكامل الهيكل | SOCPA: دليل متكامل
    """
    errors: List[COAError] = []
    code_set = {str(a.get("code", "")).strip() for a in accounts}

    # 1) أب غير موجود
    for acc in accounts:
        code   = str(acc.get("code", "")).strip()
        name   = str(acc.get("name_raw", acc.get("name", "")))
        parent = str(acc.get("parent_code", "") or "").strip()

        if parent and parent not in code_set:
            errors.append(COAError(
                error_code="E08",
                severity="Critical",
                category="structural",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) يشير لأب {parent!r} غير موجود في الشجرة",
                cause_ar="الهرمية المكسورة تجعل بناء القوائم المالية مستحيلاً",
                suggestion_ar="ابحث عن كل parent_code غير موجود. أعِد الأب أو صحِّح الكود أو اربط بالجد",
                auto_fixable=True,
                references=["IASC Framework: تكامل الهيكل", "SOCPA: دليل متكامل"],
            ))

    # 2) كشف الحلقات الدورية (Cycle Detection بـ DFS)
    parent_map: Dict[str, str] = {}
    for acc in accounts:
        code   = str(acc.get("code", "")).strip()
        parent = str(acc.get("parent_code", "") or "").strip()
        if parent:
            parent_map[code] = parent

    visited: Set[str] = set()
    in_stack: Set[str] = set()

    def has_cycle(node: str) -> bool:
        if node in in_stack:
            return True
        if node in visited:
            return False
        visited.add(node)
        in_stack.add(node)
        parent = parent_map.get(node)
        if parent and has_cycle(parent):
            return True
        in_stack.discard(node)
        return False

    for code in parent_map:
        visited.clear()
        in_stack.clear()
        if has_cycle(code) and not any(e.account_code == code and "حلقة" in e.description_ar
                                        for e in errors):
            errors.append(COAError(
                error_code="E08",
                severity="Critical",
                category="structural",
                account_code=code,
                description_ar=f"حلقة دورية مكتشفة عند الحساب {code} — A أب B وB أب A",
                cause_ar="الحلقات الدورية تُجمِّد أي خوارزمية تعتمد على الهرمية",
                suggestion_ar="اكسر الحلقة بتعيين parent_code=None لأحد الحسابات",
                auto_fixable=True,
                references=["IASC Framework: تكامل الهيكل"],
            ))

    return errors


# ─────────────────────────────────────────────────────────────
# ═══ الفئة التصنيفية: E09 - E16 ══════════════════════════════
# ─────────────────────────────────────────────────────────────

# خريطة: بادئة الكود → القسم الصحيح
CODE_PREFIX_SECTION: Dict[str, str] = {
    "1": "asset",
    "2": "liability",
    "3": "equity",
    "4": "revenue",
    "5": "cogs",
    "6": "expense",
    "7": "finance_cost",
}


def _expected_section(code: str) -> Optional[str]:
    """يُعيد القسم المتوقع من بادئة الكود، أو None إذا غير معروف."""
    code = str(code).strip()
    if not code:
        return None
    # Odoo 6-digit
    if len(code) >= 6 and code.isdigit():
        return CODE_PREFIX_SECTION.get(code[0])
    return CODE_PREFIX_SECTION.get(code[0]) if code[0] in CODE_PREFIX_SECTION else None


def check_E09_asset_as_liability(accounts: List[Dict]) -> List[COAError]:
    """
    E09 — أصل←التزام (Asset as Liability) | Critical | ✅ إصلاح تلقائي

    الوصف: حساب بطبيعة أصل مصنَّف ضمن الخصوم أو العكس.
    السبب: يُقلَب الميزانية ويُفسَد المعادلة: أصول = خصوم + حقوق ملكية.
    المراجع: IAS 32 §11 | المعادلة المحاسبية الأساسية
    """
    errors: List[COAError] = []

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or acc.get("classified_as", "")).lower()
        expected = _expected_section(code)

        if not expected or not section:
            continue

        if expected == "asset" and "liability" in section:
            errors.append(COAError(
                error_code="E09",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) يبدأ بـ 1 (أصل) لكن مصنَّف ضمن الخصوم",
                cause_ar="يُقلَب الميزانية ويُفسَد المعادلة: أصول = خصوم + حقوق ملكية",
                suggestion_ar="انقل للقسم الصحيح: أصول 1XXX، خصوم 2XXX",
                auto_fixable=True,
                references=["IAS 32 §11: الأصول والالتزامات المالية"],
            ))
        elif expected == "liability" and "asset" in section:
            errors.append(COAError(
                error_code="E09",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) يبدأ بـ 2 (خصم) لكن مصنَّف ضمن الأصول",
                cause_ar="يُقلَب الميزانية ويُفسَد المعادلة المحاسبية",
                suggestion_ar="انقل للقسم الصحيح: خصوم 2XXX",
                auto_fixable=True,
                references=["IAS 32 §11"],
            ))

    return errors


def check_E10_revenue_as_expense(accounts: List[Dict]) -> List[COAError]:
    """
    E10 — إيراد←مصروف (Revenue as Expense) | Critical | ✅ إصلاح تلقائي

    المراجع: IFRS 15: الإيرادات من العقود | IAS 1 §82
    """
    errors: List[COAError] = []
    revenue_keywords = re.compile(r'إيراد|مبيعات|دخل|عائد|ريع|رسوم.*خدم', re.IGNORECASE)
    expense_keywords = re.compile(r'مصروف|تكلفة|راتب|أجر|إيجار.*مدفوع', re.IGNORECASE)

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or acc.get("classified_as", "")).lower()
        expected = _expected_section(code)

        if expected == "revenue" and "expense" in section:
            errors.append(COAError(
                error_code="E10",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"الحساب '{name}' ({code}) إيراد لكن مصنَّف ضمن المصروفات",
                cause_ar="يُقلَب قائمة الدخل: ربح يصبح خسارة",
                suggestion_ar="إيرادات → 4XXX. مصروفات → 5XXX أو 6XXX",
                auto_fixable=True,
                references=["IFRS 15: الإيرادات من العقود", "IAS 1 §82"],
            ))
        elif revenue_keywords.search(name) and "expense" in section:
            errors.append(COAError(
                error_code="E10",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"الاسم '{name}' يُشير لإيراد لكن مصنَّف ضمن المصروفات",
                cause_ar="تعارض بين الاسم والتصنيف",
                suggestion_ar="راجع تصنيف الحساب وانقله للإيرادات إن كان صحيحاً",
                auto_fixable=False,
                references=["IFRS 15", "IAS 1 §82"],
            ))

    return errors


def check_E11_capex_as_opex(accounts: List[Dict]) -> List[COAError]:
    """
    E11 — رأسمالي←تشغيلي (CapEx as OpEx) | Critical | 🔧 يدوي

    الوصف: مصروف رأسمالي مُسجَّل كمصروف تشغيلي فوري.
    المراجع: IAS 16 §7-14 | SOCPA معيار 16
    """
    errors: List[COAError] = []
    capex_patterns = re.compile(
        r'(شراء|اقتناء|تكلفة\s+إنشاء|تحسينات\s+مبنى|'
        r'purchase.*asset|capital.*expenditure)',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()

        if capex_patterns.search(name) and "expense" in section and not "asset" in section:
            errors.append(COAError(
                error_code="E11",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"'{name}' قد يكون مصروفاً رأسمالياً مسجَّلاً كمصروف تشغيلي",
                cause_ar="الرسملة مقابل الإقرار الفوري لها أثر جوهري على صافي الربح والأصول",
                suggestion_ar="إذا التحسين يمتد > سنة ومبلغه جوهري → رسمَله كأصل ثابت",
                auto_fixable=False,
                references=["IAS 16 §7-14: الاعتراف والرسملة"],
            ))

    return errors


def check_E12_current_as_noncurrent(accounts: List[Dict]) -> List[COAError]:
    """
    E12 — متداول←غير متداول | Critical | 🔧 يدوي

    المراجع: IAS 1 §60-67
    """
    errors: List[COAError] = []
    current_indicators = re.compile(
        r'قصير\s*الأجل|short.?term|جاري|متداول|'
        r'(ضريبة|زكاة).*مستحق(?!\s*غير)|'
        r'أوراق\s*دفع\s*قصير',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()

        if current_indicators.search(name) and "non_current" in section:
            errors.append(COAError(
                error_code="E12",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"'{name}' يبدو متداولاً (< 12 شهراً) لكن مصنَّف ضمن غير المتداول",
                cause_ar="التصنيف أساسي لتحليل السيولة ونسبة التداول",
                suggestion_ar="< 12 شهراً → متداول. > 12 شهراً → غير متداول",
                auto_fixable=False,
                references=["IAS 1 §60-67: المتداول وغير المتداول"],
            ))

    return errors


def check_E13_noncurrent_as_current(accounts: List[Dict]) -> List[COAError]:
    """
    E13 — غير متداول←متداول | Critical | 🔧 يدوي

    المراجع: IAS 1 §60-67 | IFRS 16 §47
    """
    errors: List[COAError] = []
    noncurrent_indicators = re.compile(
        r'طويل\s*الأجل|long.?term|أصول\s*ثابتة|عقار|IFRS\s*16|'
        r'حق\s*استخدام|استثمار\s*طويل',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()

        if noncurrent_indicators.search(name) and section in {"current_asset", "current_liability",
                                                               "أصول متداولة", "خصوم متداولة"}:
            errors.append(COAError(
                error_code="E13",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"'{name}' يبدو غير متداول لكن مصنَّف ضمن المتداول",
                cause_ar="تضخيم الأصول المتداولة يُظهر سيولة وهمية",
                suggestion_ar="قروض طويلة → 2200+. أصول ثابتة → 1200+. IFRS16 طويل → غير متداول",
                auto_fixable=False,
                references=["IAS 1 §60-67", "IFRS 16 §47"],
            ))

    return errors


def check_E14_wrong_category(accounts: List[Dict]) -> List[COAError]:
    """
    E14 — تصنيف خاطئ عام | Critical | 🔧 يدوي

    يكتشف التعارض الواضح بين بادئة الكود والتصنيف المُعطى.
    المراجع: IAS 1 | IFRS 9
    """
    errors: List[COAError] = []
    section_map = {
        "asset":        {"1"},
        "liability":    {"2"},
        "equity":       {"3"},
        "revenue":      {"4"},
        "cogs":         {"5"},
        "expense":      {"6"},
        "finance_cost": {"7"},
    }

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or acc.get("classified_as", ""))

        if not code or not code[0].isdigit() or code.startswith("8") or code.startswith("9"):
            continue

        # إذا user_type_id صريح وموثوق (confidence ≥ 0.80)، اعتمد التصنيف ولا تُشغِّل E14
        confidence = acc.get("confidence", 0) or 0
        user_type  = acc.get("user_type_id") or acc.get("user_type") or ""
        cls_method = str(acc.get("classification_method", "") or "")
        if user_type and float(confidence) >= 0.80:
            continue
        # الطبقة 2 (user_type) بثقة عالية → لا تعارض
        if cls_method in ("user_type", "user_type_id") and float(confidence) >= 0.80:
            continue

        prefix  = code[0]
        expected_prefix = CODE_PREFIX_SECTION.get(prefix)
        if not expected_prefix:
            continue

        # نحاول تحديد ما إذا كان التصنيف المُعطى غير متوافق
        classified_main = None
        for main_sec, prefixes in section_map.items():
            if main_sec in section.lower() or section.lower().startswith(main_sec[:3]):
                classified_main = main_sec
                break

        if classified_main and classified_main != expected_prefix:
            # تجنب التكرار مع E09-E13
            related_errors = {"E09", "E10", "E11", "E12", "E13"}
            errors.append(COAError(
                error_code="E14",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=(
                    f"الحساب '{name}' ({code}) مصنَّف كـ '{classified_main}' "
                    f"لكن الكود يشير لـ '{expected_prefix}'"
                ),
                cause_ar="التصنيف الخاطئ يُفسَد أي تحليل مالي",
                suggestion_ar="ابحث عن الحساب المناسب بناءً على اسمه + طبيعته + كوده + سياقه",
                auto_fixable=False,
                references=["IAS 1: عرض القوائم المالية", "IFRS 9: التصنيف والقياس"],
            ))

    return errors


def check_E15_equity_as_liability(accounts: List[Dict]) -> List[COAError]:
    """
    E15 — ملكية←التزام | Critical | ✅ إصلاح تلقائي

    المراجع: IAS 32 §11
    """
    errors: List[COAError] = []
    equity_keywords = re.compile(
        r'رأس.*مال|حقوق.*ملكية|احتياطي|أرباح.*مبقاة|'
        r'capital|equity|retained\s*earnings',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()

        if equity_keywords.search(name) and "liability" in section:
            errors.append(COAError(
                error_code="E15",
                severity="Critical",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"'{name}' يبدو حقوق ملكية لكن مصنَّف ضمن الالتزامات",
                cause_ar="حقوق الملكية ليست ديناً — وضعها بالخصوم يُفسَد نسب الرفع المالي",
                suggestion_ar="انقل جميع حسابات رأس المال والاحتياطيات إلى 3XXX",
                auto_fixable=True,
                references=["IAS 32 §11: التمييز بين الالتزام والملكية"],
            ))

    return errors


def check_E16_cogs_as_admin(accounts: List[Dict]) -> List[COAError]:
    """
    E16 — تكلفة←إداري (COGS as Admin) | High | 🔧 يدوي

    المراجع: IAS 2 §10 | IAS 1 §99-100
    """
    errors: List[COAError] = []
    cogs_keywords = re.compile(
        r'مواد\s*خام|أجور\s*إنتاج|تكلفة\s*إنتاج|raw\s*material|'
        r'direct\s*labor|manufacturing\s*cost',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()

        if cogs_keywords.search(name) and section in {"expense", "admin_expense",
                                                       "selling_expense", "مصروفات"}:
            errors.append(COAError(
                error_code="E16",
                severity="High",
                category="classification",
                account_code=code,
                account_name=name,
                description_ar=f"'{name}' تكلفة مباشرة مصنَّفة ضمن المصروفات الإدارية",
                cause_ar="الفصل بين COGS والمصروفات التشغيلية ضروري لحساب هامش الربح الإجمالي",
                suggestion_ar="أعِد تصنيف التكاليف المباشرة ضمن تكلفة المبيعات 5XXX",
                auto_fixable=False,
                references=["IAS 2 §10: تكلفة المخزون", "IAS 1 §99-100"],
            ))

    return errors


# ─────────────────────────────────────────────────────────────
# ═══ الفئة الطبيعية: E17 - E20 ═══════════════════════════════
# ─────────────────────────────────────────────────────────────

EXPECTED_NATURE: Dict[str, str] = {
    "asset":        "debit",
    "cogs":         "debit",
    "expense":      "debit",
    "finance_cost": "debit",
    "liability":    "credit",
    "equity":       "credit",
    "revenue":      "credit",
}


def check_E17_reversed_balance(accounts: List[Dict]) -> List[COAError]:
    """
    E17 — طبيعة معكوسة (Reversed Normal Balance) | Critical | ✅ إصلاح تلقائي

    الاستثناء الوحيد: مجمع الإهلاك (أصل مقابل) طبيعته دائن — صحيح تماماً.
    المراجع: IASB Framework | قاعدة القيد المزدوج
    """
    errors: List[COAError] = []
    # كلمات تدل على حسابات مقابلة (contra accounts) — طبيعتها معكوسة بالتعريف
    contra_pattern = re.compile(
        r'مجمع.*(إهلاك|اهلاك|استهلاك|إطفاء)|'
        r'خصم.*(إصدار|سندات)|علاوة.*(إصدار)',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or acc.get("classified_as", "")).lower()
        nature  = str(acc.get("nature", "") or acc.get("normal_balance", "")).lower()

        if not section or not nature:
            continue

        # استثناء: حسابات مقابلة
        if contra_pattern.search(name):
            continue

        expected_nature = None
        for sec_key, nat in EXPECTED_NATURE.items():
            if sec_key in section:
                expected_nature = nat
                break

        if expected_nature and nature != expected_nature:
            errors.append(COAError(
                error_code="E17",
                severity="Critical",
                category="nature",
                account_code=code,
                account_name=name,
                description_ar=(
                    f"'{name}' ({code}) طبيعته المُسجَّلة '{nature}' "
                    f"لكن المتوقع '{expected_nature}'"
                ),
                cause_ar="الانحراف عن الطبيعة الطبيعية يُفسَد القيد المزدوج وأرصدة الحسابات",
                suggestion_ar="صحِّح الطبيعة. الاستثناء: مجمع الإهلاك طبيعته دائن — صحيح",
                auto_fixable=True,
                references=["IASB Framework: خصائص الأصول", "قاعدة القيد المزدوج"],
            ))

    return errors


def check_E18_provision_debit(accounts: List[Dict]) -> List[COAError]:
    """
    E18 — مخصص مدين (Provision Debit) | High | ✅ إصلاح تلقائي

    المراجع: IAS 37: المخصصات والالتزامات المحتملة
    """
    errors: List[COAError] = []
    provision_pattern = re.compile(
        r'مخصص|احتياطي\s*(ضمان|قضايا|نهاية\s*خدمة)|'
        r'provision|allowance\s*for|مخصصات',
        re.IGNORECASE
    )

    for acc in accounts:
        code   = str(acc.get("code", "")).strip()
        name   = str(acc.get("name_raw", acc.get("name", "")))
        nature = str(acc.get("nature", "") or acc.get("normal_balance", "")).lower()

        if provision_pattern.search(name) and nature == "debit":
            # استثناء: مخصص انخفاض قيمة (contra asset)
            if re.search(r'انخفاض\s*قيمة|impairment', name, re.IGNORECASE):
                continue
            errors.append(COAError(
                error_code="E18",
                severity="High",
                category="nature",
                account_code=code,
                account_name=name,
                description_ar=f"مخصص '{name}' طبيعته مدين — المخصصات التزامات طبيعتها دائن",
                cause_ar="مخصص بطبيعة مدين يُسجَّل كأصل وهو في الحقيقة التزام",
                suggestion_ar="غيِّر طبيعة جميع المخصصات (ضمان، قضايا، نهاية خدمة) إلى دائن",
                auto_fixable=True,
                references=["IAS 37: المخصصات والالتزامات المحتملة"],
            ))

    return errors


def check_E19_revenue_debit(accounts: List[Dict]) -> List[COAError]:
    """
    E19 — إيراد مدين (Revenue as Debit) | Critical | ✅ إصلاح تلقائي

    المراجع: IFRS 15 | IAS 1
    """
    errors: List[COAError] = []

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()
        nature  = str(acc.get("nature", "") or acc.get("normal_balance", "")).lower()

        is_revenue = "revenue" in section or code.startswith("4")
        if is_revenue and nature == "debit":
            errors.append(COAError(
                error_code="E19",
                severity="Critical",
                category="nature",
                account_code=code,
                account_name=name,
                description_ar=f"إيراد '{name}' ({code}) طبيعته مدين — الإيرادات دائماً دائنة",
                cause_ar="إيراد بطبيعة مدين ينعكس على قائمة الدخل ويُفسَد صافي الربح",
                suggestion_ar="غيِّر طبيعة الإيراد إلى دائن",
                auto_fixable=True,
                references=["IFRS 15", "IAS 1"],
            ))

    return errors


def check_E20_expense_credit(accounts: List[Dict]) -> List[COAError]:
    """
    E20 — مصروف دائن (Expense as Credit) | High | ✅ إصلاح تلقائي

    المراجع: IAS 1 §99
    """
    errors: List[COAError] = []
    # استثناء: خصومات وعوائد مشتريات (contra expense)
    contra_expense = re.compile(
        r'خصم\s*مكتسب|عائد\s*مشتريات|returns\s*inward|purchase\s*discount',
        re.IGNORECASE
    )

    for acc in accounts:
        code    = str(acc.get("code", "")).strip()
        name    = str(acc.get("name_raw", acc.get("name", "")))
        section = str(acc.get("section", "") or "").lower()
        nature  = str(acc.get("nature", "") or acc.get("normal_balance", "")).lower()

        if contra_expense.search(name):
            continue

        is_expense = ("expense" in section or "cogs" in section
                      or code.startswith("5") or code.startswith("6"))
        if is_expense and nature == "credit":
            errors.append(COAError(
                error_code="E20",
                severity="Critical",
                category="nature",
                account_code=code,
                account_name=name,
                description_ar=f"مصروف '{name}' ({code}) طبيعته دائن — المصروفات دائماً مدينة",
                cause_ar="مصروف بطبيعة دائن ينعكس على الدخل بشكل معكوس",
                suggestion_ar="غيِّر طبيعة المصروف إلى مدين",
                auto_fixable=True,
                references=["IAS 1 §99"],
            ))

    return errors


# ─────────────────────────────────────────────────────────────
# الدالة الرئيسية — تشغيل كل الفحوصات
# ─────────────────────────────────────────────────────────────
def run_all_checks(
    accounts: List[Dict[str, Any]],
    tree:     Optional[Dict[str, Any]] = None,
) -> List[COAError]:
    """
    يُشغِّل كل فحوصات Wave 1 (E01-E20) ويُعيد قائمة الأخطاء المكتشفة.

    Args:
        accounts: قائمة الحسابات الموحدة من Pipeline
        tree:     الشجرة الهرمية المبنية (اختياري، يُحسِّن بعض الفحوصات)

    Returns:
        قائمة COAError مرتبة حسب الخطورة (Critical أولاً)
    """
    tree = tree or {}
    all_errors: List[COAError] = []

    checks = [
        # هيكلية
        check_E01_duplicate_code(accounts),
        check_E02_missing_code(accounts),
        check_E03_non_sequential(accounts),
        check_E04_no_classification(accounts),
        check_E05_header_no_children(accounts, tree),
        check_E06_inconsistent_detail(accounts),
        check_E07_mix_header_posting(accounts),
        check_E08_broken_hierarchy(accounts),
        # تصنيفية
        check_E09_asset_as_liability(accounts),
        check_E10_revenue_as_expense(accounts),
        check_E11_capex_as_opex(accounts),
        check_E12_current_as_noncurrent(accounts),
        check_E13_noncurrent_as_current(accounts),
        check_E14_wrong_category(accounts),
        check_E15_equity_as_liability(accounts),
        check_E16_cogs_as_admin(accounts),
        # الطبيعة المحاسبية
        check_E17_reversed_balance(accounts),
        check_E18_provision_debit(accounts),
        check_E19_revenue_debit(accounts),
        check_E20_expense_credit(accounts),
    ]

    for error_list in checks:
        all_errors.extend(error_list)

    # ترتيب: Critical → High → Medium → Low
    severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    all_errors.sort(key=lambda e: severity_order.get(e.severity, 99))

    return all_errors


def summarize_errors(errors: List[COAError]) -> Dict[str, int]:
    """
    يُنتج ملخص الأخطاء حسب الخطورة.
    """
    summary = {"critical": 0, "high": 0, "medium": 0, "low": 0, "total": len(errors)}
    for e in errors:
        key = e.severity.lower()
        if key in summary:
            summary[key] += 1
    return summary
