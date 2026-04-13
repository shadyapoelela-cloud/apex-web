"""
APEX COA Engine v4.3 — Error Checks Wave 2 (E21-E58 + EP1-EP3 + EC1-EC5)
=========================================================================
يُكمِّل error_checks.py (E01-E20).
38 خطأ إضافي: مسميات + IFRS + ضريبي سعودي + نقص/زيادة + ترميز + قطاعي + توازن + ERP + ملفات حقيقية.

الاستخدام:
    from apex_coa.error_checks_wave2 import run_wave2_checks
    errors_w2 = run_wave2_checks(accounts, tree)
"""
from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass, field
from datetime import date
from typing import Any, Dict, List, Optional, Set

from .error_checks import COAError  # نعيد استخدام نفس الـ dataclass


# ─────────────────────────────────────────────────────────────
# ═══ الفئة المسميات: E21 - E26 ════════════════════════════════
# ─────────────────────────────────────────────────────────────

def check_E21_ambiguous_name(accounts: List[Dict]) -> List[COAError]:
    """
    E21 — اسم مبهم 'أخرى/متنوعات' | Medium | 🔧 يدوي
    """
    errors = []
    vague = re.compile(r'^(أخرى|متنوعات|مختلفة|عامة|other|misc|general|various)$', re.I)
    for acc in accounts:
        name = str(acc.get("name_raw","") or "").strip()
        if vague.match(name):
            errors.append(COAError(
                error_code="E21", severity="Medium", category="naming",
                account_code=acc.get("code"), account_name=name,
                description_ar=f"الاسم '{name}' مبهم جداً ولا يصف طبيعة الحساب",
                cause_ar="الأسماء المبهمة تُصعِّب التدقيق والتحليل المالي",
                suggestion_ar="أعِد التسمية بوصف محدد أو فصِّل الحساب لحسابات تفصيلية",
                auto_fixable=False, references=["IAS 1 §29"],
            ))
    return errors


def check_E22_duplicate_name(accounts: List[Dict]) -> List[COAError]:
    """
    E22 — اسم مكرر بنفس الكلمات | Medium | ✅ إصلاح تلقائي
    """
    errors = []
    name_count: Dict[str, List[str]] = {}
    for acc in accounts:
        name = str(acc.get("name_raw","") or "").strip().lower()
        code = str(acc.get("code","") or "")
        if name:
            name_count.setdefault(name, []).append(code)

    reported: Set[str] = set()
    for acc in accounts:
        name = str(acc.get("name_raw","") or "").strip().lower()
        code = str(acc.get("code","") or "")
        if name in name_count and len(name_count[name]) > 1 and name not in reported:
            reported.add(name)
            errors.append(COAError(
                error_code="E22", severity="Medium", category="naming",
                account_code=code, account_name=acc.get("name_raw",""),
                description_ar=f"الاسم '{acc.get('name_raw','')}' مكرر في الأكواد: {', '.join(name_count[name])}",
                cause_ar="التكرار يُربك الربط مع ميزان المراجعة",
                suggestion_ar="ميِّز كل حساب بوصف إضافي أو ادمج المتطابقة",
                auto_fixable=True, references=["IASC Framework"],
            ))
    return errors


def check_E23_name_section_mismatch(accounts: List[Dict]) -> List[COAError]:
    """
    E23 — اسم لا يطابق التصنيف | High | 🔧 يدوي
    """
    errors = []
    # كلمات تدل على التصنيف
    section_keywords = {
        "asset":     re.compile(r"أصل|نقد|بنك|مخزون|ذمم.*مدين|استثمار", re.I),
        "liability": re.compile(r"خصم|التزام|ديون|دائن|قرض", re.I),
        "equity":    re.compile(r"رأس.?مال|ملكية|احتياطي|أرباح.*مبقاة", re.I),
        "revenue":   re.compile(r"إيراد|مبيعات|دخل", re.I),
        "expense":   re.compile(r"مصروف|تكلفة|راتب|إيجار", re.I),
    }
    section_map = {
        "current_asset":"asset","non_current_asset":"asset",
        "current_liability":"liability","non_current_liability":"liability",
        "equity":"equity","revenue":"revenue","cogs":"expense",
        "expense":"expense","finance_cost":"expense",
    }
    # كلمات تُستخدم كوصف/تصنيف في آخر الاسم (label) وليست دلالة تصنيف فعلية
    label_suffixes = re.compile(
        r"(مصروفات|مصاريف|إيرادات|أصول|خصوم|التزامات|موجودات|مطلوبات)\s*$",
        re.I,
    )

    for acc in accounts:
        name    = str(acc.get("name_raw","") or "")
        section = str(acc.get("section","") or acc.get("classified_as","") or "").lower()
        main_s  = section_map.get(section, section)

        for sec, pattern in section_keywords.items():
            if sec != main_s and main_s and pattern.search(name):
                match = pattern.search(name)
                matched_text = match.group() if match else ""

                # استثناء: الكلمة في آخر الاسم كـ label وصفي (مثل "ض.ق.م مصروفات")
                words = name.strip().split()
                if len(words) >= 2 and label_suffixes.search(name):
                    # الكلمة المطابقة في آخر الاسم → وصف لا تصنيف
                    if matched_text and name.strip().endswith(matched_text):
                        continue

                # استثناء: كلمة واحدة فقط تطابقت ولها سياق مختلف (حساب فرعي)
                # مثلاً "ض.ق.م المدينة مصروفات" → "مصروفات" وصفية
                if len(words) >= 3 and matched_text in words[-1]:
                    continue

                errors.append(COAError(
                    error_code="E23", severity="High", category="naming",
                    account_code=acc.get("code"), account_name=name,
                    description_ar=f"الاسم '{name}' يوحي بـ '{sec}' لكن التصنيف '{main_s}'",
                    cause_ar="التعارض بين الاسم والتصنيف يُشير لخطأ في أحدهما",
                    suggestion_ar="إذا الاسم صحيح: انقل الحساب. إذا التصنيف صحيح: أعِد التسمية",
                    auto_fixable=False, references=["IAS 1"],
                ))
                break
    return errors


def check_E24_spelling_error(accounts: List[Dict]) -> List[COAError]:
    """
    E24 — خطأ إملائي واضح | Medium | ✅ إصلاح تلقائي
    """
    errors = []
    # أخطاء إملائية شائعة موثقة
    spelling_fixes = {
        re.compile(r"الاهلاك", re.I):     "الإهلاك",
        re.compile(r"الاستهلاك\b", re.I): "الإهلاك",
        re.compile(r"المبيعات\s+جم", re.I):"مجمع إهلاك",
        re.compile(r"ذمم\s+دائنه", re.I): "ذمم دائنة",
        re.compile(r"ذمم\s+مدينه", re.I): "ذمم مدينة",
        re.compile(r"اصول\b", re.I):      "أصول",
        re.compile(r"خصوم\s+متداوله", re.I):"خصوم متداولة",
        re.compile(r"مستحقات\s+موظفين\b", re.I):"مستحقات للموظفين",
    }
    for acc in accounts:
        name = str(acc.get("name_raw","") or "")
        for pattern, correct in spelling_fixes.items():
            if pattern.search(name):
                errors.append(COAError(
                    error_code="E24", severity="Medium", category="naming",
                    account_code=acc.get("code"), account_name=name,
                    description_ar=f"خطأ إملائي محتمل في '{name}' — الصحيح: '{correct}'",
                    cause_ar="الأخطاء الإملائية تُعيق المطابقة التلقائية مع المعجم",
                    suggestion_ar=f"صحِّح إلى: {correct}",
                    auto_fixable=True, references=[],
                ))
                break
    return errors


def check_E25_name_too_long(accounts: List[Dict]) -> List[COAError]:
    """E25 — اسم طويل > 80 حرف | Low | ✅ إصلاح تلقائي"""
    errors = []
    for acc in accounts:
        name = str(acc.get("name_raw","") or "")
        if len(name) > 80:
            errors.append(COAError(
                error_code="E25", severity="Low", category="naming",
                account_code=acc.get("code"), account_name=name[:50]+"...",
                description_ar=f"اسم الحساب طوله {len(name)} حرف (الحد الأقصى 80)",
                cause_ar="الأسماء الطويلة تُعيق عرض التقارير والواجهات",
                suggestion_ar="اختصر مع الحفاظ على المعنى (الحد المقترح 60 حرفاً)",
                auto_fixable=True, references=[],
            ))
    return errors


def check_E26_abbreviation_unclear(accounts: List[Dict]) -> List[COAError]:
    """E26 — اختصار مخِل 'م.إ.م' | Medium | 🔧 يدوي"""
    errors = []
    abbrev = re.compile(r'^[أ-ي]{1,2}\.[أ-ي]{1,2}\.', re.I)
    for acc in accounts:
        name = str(acc.get("name_raw","") or "")
        if abbrev.match(name) and len(name) < 15:
            errors.append(COAError(
                error_code="E26", severity="Medium", category="naming",
                account_code=acc.get("code"), account_name=name,
                description_ar=f"الاسم '{name}' يبدو اختصاراً غير واضح",
                cause_ar="الاختصارات تُعيق المطابقة التلقائية وتُربك المراجعين",
                suggestion_ar="اكتب الاسم كاملاً مثل: 'مجمع إهلاك المركبات'",
                auto_fixable=False, references=[],
            ))
    return errors


# ─────────────────────────────────────────────────────────────
# ═══ الفئة IFRS: E27 - E31 ════════════════════════════════════
# ─────────────────────────────────────────────────────────────

def check_E27_ifrs16_missing(accounts: List[Dict]) -> List[COAError]:
    """E27 — IFRS 16 مفقود | Critical | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    rou_exists     = any(re.search(r"حق.*استخدام|ROU|right.?of.?use", n, re.I) for n in names)
    lease_exists   = any(re.search(r"التزام.*إيجار|lease.*liabil", n, re.I) for n in names)
    has_lease_type = any(re.search(r"إيجار|lease", n, re.I) for n in names)

    if rou_exists and not lease_exists:
        errors.append(COAError(
            error_code="E27", severity="Critical", category="ifrs",
            description_ar="وُجد أصل حق استخدام (ROU) بدون التزام إيجار مقابل",
            cause_ar="IFRS 16 §22: يجب الاعتراف بالأصل والالتزام معاً عند بدء الإيجار",
            suggestion_ar="أضف: (1) التزام إيجار متداول، (2) التزام إيجار غير متداول",
            auto_fixable=False, references=["IFRS 16 §22", "IFRS 16 §47"],
        ))
    elif lease_exists and not rou_exists and has_lease_type:
        errors.append(COAError(
            error_code="E27", severity="High", category="ifrs",
            description_ar="وُجد التزام إيجار بدون أصل حق استخدام (ROU) مقابل",
            cause_ar="IFRS 16 §22: يجب الاعتراف بالأصل والالتزام معاً",
            suggestion_ar="أضف: أصل حق الاستخدام (ROU Asset) في الأصول غير المتداولة",
            auto_fixable=False, references=["IFRS 16 §22"],
        ))
    return errors


def check_E28_ecl_missing(accounts: List[Dict]) -> List[COAError]:
    """E28 — ECL مفقود | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_receivables = any(re.search(r"ذمم.*مدين|مدينون|عملاء|حسابات.*قبض", n, re.I) for n in names)
    has_ecl         = any(re.search(r"مخصص.*(ائتمان|ديون|ECL|مشكوك|معدوم)", n, re.I) for n in names)

    if has_receivables and not has_ecl:
        errors.append(COAError(
            error_code="E28", severity="High", category="ifrs",
            description_ar="ذمم مدينة بدون مخصص خسائر الائتمان المتوقعة (ECL)",
            cause_ar="IFRS 9 §5.5: كل ذمم مدينة تستوجب احتساب ECL",
            suggestion_ar="أضف: مخصص ECL تحت الأصول المتداولة (طبيعته دائن)",
            auto_fixable=False, references=["IFRS 9 §5.5"],
        ))
    return errors


def check_E29_ifrs15_missing(accounts: List[Dict]) -> List[COAError]:
    """E29 — IFRS 15 مفقود | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_contract_rev = any(re.search(r"إيراد.*عقد|contract.*rev|service.*rev", n, re.I) for n in names)
    has_deferred     = any(re.search(r"إيراد.*مؤجل|deferred.*rev|عقود.*مستقبل", n, re.I) for n in names)
    has_accrued_rev  = any(re.search(r"إيراد.*مستحق|accrued.*rev", n, re.I) for n in names)

    if has_contract_rev and not has_deferred and not has_accrued_rev:
        errors.append(COAError(
            error_code="E29", severity="High", category="ifrs",
            description_ar="إيرادات عقود بدون إيرادات مؤجلة أو إيرادات مستحقة",
            cause_ar="IFRS 15: العقود متعددة الأداء تستلزم تأجيل جزء من الإيراد",
            suggestion_ar="أضف: إيرادات مؤجلة (خصوم) و/أو إيرادات مستحقة القبض (أصول)",
            auto_fixable=False, references=["IFRS 15 §9", "IFRS 15 §105-116"],
        ))
    return errors


def check_E30_biological_assets(accounts: List[Dict]) -> List[COAError]:
    """E30 — أصول بيولوجية مفقودة | High | 🔧 يدوي"""
    errors = []
    names  = [str(a.get("name_raw","") or "") for a in accounts]
    is_agri = any(re.search(r"زراع|ألبان|دواجن|مزرعة|agricultural|dairy|poultry", n, re.I) for n in names)
    has_bio = any(re.search(r"أصل.*بيولوج|biological.*asset|حيوانات|محاصيل.*قيد", n, re.I) for n in names)

    if is_agri and not has_bio:
        errors.append(COAError(
            error_code="E30", severity="High", category="ifrs",
            description_ar="شركة زراعية/ألبان بدون أصول بيولوجية (IAS 41)",
            cause_ar="IAS 41: الحيوانات والمحاصيل الحية تُسجَّل كأصول بيولوجية بالقيمة العادلة",
            suggestion_ar="أضف: 'أصول بيولوجية' في الأصول غير المتداولة أو المتداولة",
            auto_fixable=False, references=["IAS 41 §10-29"],
        ))
    return errors


def check_E31_contract_liability(accounts: List[Dict]) -> List[COAError]:
    """E31 — التزامات عقود مفقودة | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_advances     = any(re.search(r"مقدمات.*عميل|سلف.*عميل|دفعات.*مقدمة", n, re.I) for n in names)
    has_deferred_rev = any(re.search(r"إيراد.*مؤجل|deferred.*rev", n, re.I) for n in names)
    has_rev          = any(re.search(r"إيراد|revenue|مبيعات", n, re.I) for n in names)

    if has_advances and has_rev and not has_deferred_rev:
        errors.append(COAError(
            error_code="E31", severity="High", category="ifrs",
            description_ar="دفعات مقدمة من العملاء بدون إيرادات مؤجلة مقابلة",
            cause_ar="IFRS 15: الدفعات المقدمة التزام يُحوَّل لإيراد عند تسليم الخدمة",
            suggestion_ar="تحقق: هل يجب تحويل مقدمات العملاء لحساب 'إيرادات مؤجلة'؟",
            auto_fixable=False, references=["IFRS 15 §9"],
        ))
    return errors


# ─────────────────────────────────────────────────────────────
# ═══ الفئة الضريبية السعودية: E32 - E36 ══════════════════════
# ─────────────────────────────────────────────────────────────

def check_E32_vat_missing(accounts: List[Dict]) -> List[COAError]:
    """E32 — ض.ق.م مفقودة | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_sales = any(re.search(r"مبيعات|إيراد|sales|revenue", n, re.I) for n in names)
    has_vat   = any(re.search(r"ض.?ق.?م|ضريبة.*قيمة|VAT|value.?added", n, re.I) for n in names)

    if has_sales and not has_vat:
        errors.append(COAError(
            error_code="E32", severity="High", category="tax_saudi",
            description_ar="شركة لديها مبيعات بدون حسابات ضريبة القيمة المضافة",
            cause_ar="نظام ضريبة القيمة المضافة السعودي يلزم الفصل بين المدخلات والمخرجات",
            suggestion_ar="أضف: (1) ض.ق.م مدخلات (أصل)، (2) ض.ق.م مخرجات (التزام)",
            auto_fixable=False, references=["نظام ضريبة القيمة المضافة — هيئة الزكاة والضريبة ZATCA"],
        ))
    return errors


def check_E33_vat_unseparated(accounts: List[Dict]) -> List[COAError]:
    """E33 — ض.ق.م غير مفصولة | High | 🔧 يدوي"""
    errors = []
    for acc in accounts:
        name = str(acc.get("name_raw","") or "")
        if re.search(r"ض.?ق.?م|VAT", name, re.I):
            # حساب VAT واحد للمدخلات والمخرجات معاً
            if not re.search(r"(مدخل|input|مخرج|output|تسوية|settlement|صافي)", name, re.I):
                errors.append(COAError(
                    error_code="E33", severity="High", category="tax_saudi",
                    account_code=acc.get("code"), account_name=name,
                    description_ar=f"حساب VAT '{name}' لا يُحدِّد هل هو مدخلات أم مخرجات",
                    cause_ar="ZATCA يتطلب الفصل الكامل بين ض.ق.م المدخلات والمخرجات",
                    suggestion_ar="افصل إلى: (1) ض.ق.م مدخلات، (2) ض.ق.م مخرجات",
                    auto_fixable=False, references=["ZATCA VAT Regulations"],
                ))
                break
    return errors


def check_E34_zakat_missing(accounts: List[Dict]) -> List[COAError]:
    """E34 — زكاة مفقودة | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_equity    = any(re.search(r"رأس.?مال|حقوق.*ملكية|equity", n, re.I) for n in names)
    has_zakat     = any(re.search(r"زكاة|zakat", n, re.I) for n in names)
    has_income_tax= any(re.search(r"ضريبة.*دخل|income.*tax", n, re.I) for n in names)

    if has_equity and not has_zakat and not has_income_tax:
        errors.append(COAError(
            error_code="E34", severity="High", category="tax_saudi",
            description_ar="شركة سعودية (يوجد رأس مال) بدون زكاة مستحقة أو ضريبة دخل",
            cause_ar="الشركات السعودية الخالصة تُلزَم بالزكاة؛ غيرها بضريبة الدخل",
            suggestion_ar="أضف: 'زكاة مستحقة' في الخصوم المتداولة",
            auto_fixable=False, references=["نظام الزكاة السعودي — هيئة الزكاة والضريبة"],
        ))
    return errors


def check_E35_zakat_tax_mixed(accounts: List[Dict]) -> List[COAError]:
    """E35 — خلط زكاة وضريبة دخل | High | 🔧 يدوي"""
    errors = []
    for acc in accounts:
        name = str(acc.get("name_raw","") or "")
        if re.search(r"زكاة.*ضريبة|ضريبة.*زكاة|zakat.*tax|tax.*zakat", name, re.I):
            errors.append(COAError(
                error_code="E35", severity="High", category="tax_saudi",
                account_code=acc.get("code"), account_name=name,
                description_ar=f"'{name}' يخلط الزكاة وضريبة الدخل في حساب واحد",
                cause_ar="الزكاة للمساهمين السعوديين، الضريبة للأجانب — يجب الفصل",
                suggestion_ar="افصل: زكاة مستحقة للسعوديين + ضريبة دخل مستحقة للأجانب",
                auto_fixable=False, references=["نظام الزكاة والضريبة السعودي"],
            ))
    return errors


def check_E36_withholding_missing(accounts: List[Dict]) -> List[COAError]:
    """E36 — استقطاع مفقود | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_foreign_services = any(re.search(r"استشار|خبير.*أجنب|مقاول.*أجنب|foreign.*service|خدم.*خارج", n, re.I) for n in names)
    has_withholding       = any(re.search(r"استقطاع|withholding", n, re.I) for n in names)

    if has_foreign_services and not has_withholding:
        errors.append(COAError(
            error_code="E36", severity="High", category="tax_saudi",
            description_ar="خدمات أجانب/مقاولون بدون حساب ضريبة الاستقطاع",
            cause_ar="لوائح ZATCA: الدفع للأجانب يستوجب استقطاع نسبة ودفعها للهيئة",
            suggestion_ar="أضف: 'ضريبة استقطاع مستحقة' في الخصوم المتداولة",
            auto_fixable=False, references=["ZATCA Withholding Tax Regulations"],
        ))
    return errors


# ─────────────────────────────────────────────────────────────
# ═══ النقص والزيادة والترميز والتوازن: E37 - E50 ═════════════
# ─────────────────────────────────────────────────────────────

def check_E37_depreciation_expense_missing(accounts: List[Dict]) -> List[COAError]:
    """E37 — مصروف إهلاك مفقود | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_fixed_assets = any(re.search(r"أصول.*ثابت|معدات|مبان|آلات", n, re.I) for n in names)
    # نمط دقيق: مصروف إهلاك يجب أن يبدأ بـ "مصروف" أو "depreciation" — لا "مجمع"
    has_depr_expense = any(
        re.search(r"مصروف.*إهلاك|depreciation.*expense", n, re.I)
        and not re.search(r"مجمع", n, re.I)
        for n in names
    )

    if has_fixed_assets and not has_depr_expense:
        errors.append(COAError(
            error_code="E37", severity="High", category="completeness",
            description_ar="أصول ثابتة موجودة بدون مصروف إهلاك",
            cause_ar="IAS 16 §43: يجب تخصيص مصروف الإهلاك للأصول القابلة للاستهلاك",
            suggestion_ar="أضف: 'مصروف الإهلاك' في المصروفات التشغيلية (6XXX)",
            auto_fixable=False, references=["IAS 16 §43-62"],
        ))
    return errors


def check_E38_provisions_missing(accounts: List[Dict]) -> List[COAError]:
    """E38 — مخصصات مفقودة | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_employees = any(re.search(r"رواتب|موظف|salaries|employees", n, re.I) for n in names)
    has_eosb      = any(re.search(r"مكافأة.*نهاية.*خدمة|نهاية.*خدمة|EOSB|end.?of.?service", n, re.I) for n in names)

    if has_employees and not has_eosb:
        errors.append(COAError(
            error_code="E38", severity="High", category="completeness",
            description_ar="شركة لديها موظفون بدون مخصص مكافأة نهاية الخدمة",
            cause_ar="IAS 37 + نظام العمل السعودي: مكافأة نهاية الخدمة التزام إلزامي",
            suggestion_ar="أضف: (1) مخصص نهاية الخدمة (التزام)، (2) مصروف نهاية الخدمة",
            auto_fixable=False, references=["IAS 37", "نظام العمل السعودي"],
        ))
    return errors


def check_E39_redundant_accounts(accounts: List[Dict]) -> List[COAError]:
    """E39 — حسابات زائدة متتالية | Low | 🔧 يدوي"""
    errors = []
    # حسابات متتالية بنفس اسم الجذر
    names = [(acc, str(acc.get("name_raw","") or "")) for acc in accounts]
    for i in range(len(names)-1):
        acc1, n1 = names[i]
        acc2, n2 = names[i+1]
        # تطابق أول 5 أحرف وكودان متتاليان
        c1 = str(acc1.get("code","") or "")
        c2 = str(acc2.get("code","") or "")
        if (n1[:8] == n2[:8] and n1 and len(n1) > 5 and
                c1.isdigit() and c2.isdigit() and int(c2) == int(c1)+1):
            errors.append(COAError(
                error_code="E39", severity="Low", category="redundancy",
                account_code=c1, account_name=n1,
                description_ar=f"حسابان متتاليان متطابقان تقريباً: '{n1}' و'{n2}'",
                cause_ar="الحسابات المتكررة بلا قيمة مستقلة تُضخِّم الشجرة",
                suggestion_ar="ادمج في حساب واحد أو وضِّح الفرق الوظيفي",
                auto_fixable=False, references=["IAS 1 §29: مبدأ الأهمية النسبية"],
            ))
    return errors


def check_E40_over_detailed(accounts: List[Dict]) -> List[COAError]:
    """E40 — تفصيل مبالغ: حساب لكل موظف | Low | 🔧 يدوي"""
    errors = []
    employee_accounts = [a for a in accounts
                         if re.search(r"راتب|أجر|موظف|employee", str(a.get("name_raw","") or ""), re.I)
                         and str(a.get("account_level","") or "").lower() in {"detail","تفصيلي"}]
    if len(employee_accounts) > 15:
        errors.append(COAError(
            error_code="E40", severity="Low", category="redundancy",
            description_ar=f"يوجد {len(employee_accounts)} حساب رواتب تفصيلي — قد يكون حساب لكل موظف",
            cause_ar="الممارسة السليمة: حساب رواتب واحد، التفصيل في كشوف الرواتب",
            suggestion_ar="ادمج حسابات الرواتب. التفصيل يُدار في نظام الرواتب لا شجرة الحسابات",
            auto_fixable=False, references=["IAS 1 §29: الأهمية النسبية"],
        ))
    return errors


def check_E41_code_length_inconsistent(accounts: List[Dict]) -> List[COAError]:
    """E41 — طول كود متفاوت في نفس المستوى | Medium | ✅ إصلاح تلقائي"""
    errors = []
    # نجمع أطوال الأكواد حسب المستوى
    level_lengths: Dict[int, List[int]] = {}
    for acc in accounts:
        code = str(acc.get("code","") or "")
        level = int(acc.get("level_num",1) or 1)
        if code.replace(".","").isdigit():
            level_lengths.setdefault(level, []).append(len(code))

    for level, lengths in level_lengths.items():
        if len(set(lengths)) > 2:   # أكثر من نمطين مختلفين
            errors.append(COAError(
                error_code="E41", severity="Medium", category="coding",
                description_ar=f"المستوى {level} يحتوي أكواداً بأطوال مختلفة: {sorted(set(lengths))}",
                cause_ar="عدم الاتساق في طول الكود يُعيق prefix matching والهرمية",
                suggestion_ar="وحِّد أطوال الأكواد داخل كل مستوى",
                auto_fixable=True, references=[],
            ))
    return errors


def check_E42_code_has_letters(accounts: List[Dict]) -> List[COAError]:
    """E42 — كود يحتوي حروفاً 'ACC11' | High | ✅ إصلاح تلقائي"""
    errors = []
    for acc in accounts:
        code = str(acc.get("code","") or "")
        # كود خطأ إذا يحتوي حروفاً إنجليزية مع أرقام (ACC101, ACCT1100, etc.)
        if re.search(r'[a-zA-Z]', code) and re.search(r'[0-9]', code):
            errors.append(COAError(
                error_code="E42", severity="High", category="coding",
                account_code=code, account_name=acc.get("name_raw",""),
                description_ar=f"الكود '{code}' يحتوي حروفاً إنجليزية مع أرقام",
                cause_ar="الأكواد الهجينة تُعيق prefix matching والربط مع ERP",
                suggestion_ar="حوِّل للأرقام فقط: استبدل الحروف بأرقام أو احذفها",
                auto_fixable=True, references=[],
            ))
    return errors


def check_E43_code_no_parent_prefix(accounts: List[Dict]) -> List[COAError]:
    """E43 — كود لا يرث بادئة الأب | High | 🔧 يدوي"""
    errors = []
    code_index = {str(a.get("code","")): a for a in accounts if a.get("code")}

    for acc in accounts:
        code   = str(acc.get("code","") or "").strip()
        parent = str(acc.get("parent_code","") or "").strip()
        if not parent or not code or parent not in code_index:
            continue
        if code.isdigit() and parent.isdigit():
            if not code.startswith(parent):
                errors.append(COAError(
                    error_code="E43", severity="High", category="coding",
                    account_code=code, account_name=acc.get("name_raw",""),
                    description_ar=f"الكود '{code}' لا يرث بادئة الأب '{parent}'",
                    cause_ar="Prefix matching يعتمد على وراثة الكود من الأب",
                    suggestion_ar=f"أعِد ترقيم الكود ليبدأ بـ '{parent}'",
                    auto_fixable=False, references=[],
                ))
    return errors


def check_E44_large_code_gaps(accounts: List[Dict]) -> List[COAError]:
    """E44 — فجوات ترقيم واسعة | Medium | 🔧 يدوي"""
    errors = []
    from collections import defaultdict
    groups: Dict[str, List[int]] = defaultdict(list)

    for acc in accounts:
        code = str(acc.get("code","") or "").strip()
        if code.isdigit() and len(code) >= 2:
            groups[code[:2]].append(int(code))

    for prefix, codes in groups.items():
        if len(codes) < 3: continue
        codes_sorted = sorted(codes)
        for i in range(1, len(codes_sorted)):
            gap = codes_sorted[i] - codes_sorted[i-1]
            span = codes_sorted[-1] - codes_sorted[0]
            if gap > max(20, span * 0.3):
                errors.append(COAError(
                    error_code="E44", severity="Medium", category="coding",
                    account_code=f"{prefix}XXX",
                    description_ar=f"فجوة ترقيم {gap} بين {codes_sorted[i-1]} و{codes_sorted[i]} في المجموعة {prefix}XX",
                    cause_ar="الفجوات الكبيرة تشير لحسابات محذوفة — تحقق من سلامة البيانات",
                    suggestion_ar="وثِّق أسباب الفجوة. إذا حسابات محذوفة: تأكد أنها لم تُستخدَم في قيود",
                    auto_fixable=False, references=[],
                ))
                break
    return errors


def check_E45_wrong_sector_account(accounts: List[Dict]) -> List[COAError]:
    """E45 — حساب من قطاع آخر | High | 🔧 يدوي"""
    errors = []
    # حسابات Odoo تسوية التي تُدرَج خطأً في COA حقيقي
    odoo_settlement = {"999901", "999902", "999999"}
    for acc in accounts:
        code = str(acc.get("code","") or "").strip()
        if code in odoo_settlement:
            errors.append(COAError(
                error_code="E45", severity="High", category="sector",
                account_code=code, account_name=acc.get("name_raw",""),
                description_ar=f"الكود {code} حساب تسوية Odoo — ليس حساباً محاسبياً حقيقياً",
                cause_ar="حسابات التسوية الداخلية لـ Odoo تُربك التحليل إذا ظهرت في COA",
                suggestion_ar="احذف هذا الحساب من الشجرة أو ضعه في قسم 'حسابات ختامية' 8XXX",
                auto_fixable=False, references=["Odoo Chart of Accounts Documentation"],
            ))
    return errors


def check_E46_mandatory_accounts_missing(accounts: List[Dict], sector: Optional[str] = None) -> List[COAError]:
    """
    E46 — نقص قطاعي | High | 🔧 يدوي
    يُشغَّل فقط إذا تم كشف القطاع.
    """
    if not sector:
        return []
    errors = []
    names = {str(a.get("name_raw","") or "").lower() for a in accounts}
    concepts = {str(a.get("concept_id","") or "") for a in accounts}

    # الحسابات الإلزامية حسب القطاع
    SECTOR_MANDATORY: Dict[str, List[tuple]] = {
        "RETAIL": [
            ("INVENTORY", re.compile(r"مخزون|بضاعة|inventory", re.I)),
            ("COGS",       re.compile(r"تكلفة.*مبيع|COGS", re.I)),
        ],
        "CONSTRUCTION": [
            ("CIP",         re.compile(r"أعمال.*تحت.*تنفيذ|CIP|construction.*progress", re.I)),
            ("DIRECT_LABOR",re.compile(r"عمالة.*مباشرة|direct.*labor", re.I)),
        ],
        "MANUFACTURING": [
            ("RAW_MATERIALS",  re.compile(r"مواد.*خام|raw.*material", re.I)),
            ("WIP",            re.compile(r"تحت.*تشغيل|WIP|work.*progress", re.I)),
            ("FINISHED_GOODS", re.compile(r"منتجات.*تامة|finished.*goods", re.I)),
        ],
        "HEALTHCARE": [
            ("MEDICAL_EQUIPMENT", re.compile(r"معدات.*طبية|أجهزة.*طبية|medical.*equipment", re.I)),
            ("MEDICAL_SUPPLIES",  re.compile(r"مستلزمات.*طبية|medical.*supplies", re.I)),
        ],
        "BANKING": [
            ("MURABAHA_RECEIVABLE", re.compile(r"مرابحة|murabaha", re.I)),
            ("CUSTOMER_DEPOSITS",   re.compile(r"ودائع.*عميل|customer.*deposit", re.I)),
        ],
    }

    mandatory = SECTOR_MANDATORY.get(sector.upper(), [])
    all_names_str = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    for concept_id, pattern in mandatory:
        if concept_id not in concepts and not pattern.search(all_names_str):
            errors.append(COAError(
                error_code="E46", severity="High", category="sector",
                description_ar=f"حساب إلزامي لقطاع {sector} مفقود: {concept_id}",
                cause_ar=f"كل شركة في قطاع {sector} تحتاج هذا الحساب للتشغيل السليم",
                suggestion_ar=f"أضف حساباً بمعرّف {concept_id} في القسم المناسب",
                auto_fixable=False, references=["E46 — نقص قطاعي"],
            ))
    return errors


def check_E47_regulatory_missing(accounts: List[Dict], sector: Optional[str] = None) -> List[COAError]:
    """E47 — نقص تنظيمي | High | 🔧 يدوي"""
    if not sector: return []
    errors = []
    all_names = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    REGULATORY: Dict[str, tuple] = {
        "BANKING":    (re.compile(r"احتياطي.*إلزامي|statutory.*reserve|SAMA", re.I), "هيئة SAMA"),
        "INSURANCE":  (re.compile(r"احتياطي.*فني|technical.*reserve|SAMA.*insurance", re.I), "هيئة SAMA للتأمين"),
        "CAPITAL_MKT":(re.compile(r"صندوق.*استثمار|investment.*fund|CMA", re.I), "هيئة CMA"),
        "HAJJ":       (re.compile(r"ودائع.*حجاج|pilgrims.*deposit", re.I), "وزارة الحج"),
    }

    req = REGULATORY.get(sector.upper())
    if req:
        pattern, regulator = req
        if not pattern.search(all_names):
            errors.append(COAError(
                error_code="E47", severity="High", category="sector",
                description_ar=f"متطلبات {regulator} للقطاع {sector} غير مستوفاة في الشجرة",
                cause_ar=f"الجهة الرقابية {regulator} تشترط حسابات محددة",
                suggestion_ar=f"راجع متطلبات {regulator} وأضف الحسابات الإلزامية",
                auto_fixable=False, references=[f"متطلبات {regulator}"],
            ))
    return errors


def check_E48_missing_accumulated_depr(accounts: List[Dict]) -> List[COAError]:
    """
    E48 — مجمع الإهلاك مفقود | High | ✅ إصلاح تلقائي
    مستخرجة من ملحق د مباشرة.
    """
    ASSET_TO_DEPR_PATTERNS = [
        (re.compile(r"مبانٍ|مباني|بناء|إنشاء", re.I),           re.compile(r"مجمع.*(إهلاك|استهلاك).*(بناء|مبنى|إنشاء)", re.I)),
        (re.compile(r"آلات|معدات.*صناعية|ماكينات", re.I),        re.compile(r"مجمع.*(إهلاك|استهلاك).*(آل|معد|ماكين)", re.I)),
        (re.compile(r"أثاث|مفروشات", re.I),                      re.compile(r"مجمع.*(إهلاك|استهلاك).*(أثاث|مفروش)", re.I)),
        (re.compile(r"سيارات|مركبات|أسطول", re.I),               re.compile(r"مجمع.*(إهلاك|استهلاك).*(سيار|مركب|نقل)", re.I)),
        (re.compile(r"حاسبات|كمبيوتر|IT|تقنية", re.I),           re.compile(r"مجمع.*(إهلاك|استهلاك).*(حاسب|IT|كمبيوتر)", re.I)),
        (re.compile(r"حق.?استخدام|ROU|IFRS.?16", re.I),          re.compile(r"مجمع.*(إهلاك|استهلاك).*(حق|ROU)", re.I)),
    ]
    errors = []
    fixed_assets = [a for a in accounts
                    if re.search(r"أصول.*ثابت|fixed.*asset|property.*plant|non_current_asset|non.current.asset",
                                  str(a.get("section","") or ""), re.I)
                    and "مجمع" not in str(a.get("name_raw","") or "")]
    all_names = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    for asset in fixed_assets:
        name = str(asset.get("name_raw","") or "")
        for asset_pat, depr_pat in ASSET_TO_DEPR_PATTERNS:
            if asset_pat.search(name) and not depr_pat.search(all_names):
                errors.append(COAError(
                    error_code="E48", severity="High", category="completeness",
                    account_code=asset.get("code"), account_name=name,
                    description_ar=f"الأصل '{name}' بدون مجمع إهلاك مقابل",
                    cause_ar="IAS 16 §43: كل أصل قابل للاستهلاك يستوجب مجمع إهلاك",
                    suggestion_ar=f"أضف: 'مجمع إهلاك {name}' في الأصول الثابتة (طبيعته دائن)",
                    auto_fixable=True, references=["IAS 16 §43-62"],
                ))
                break
    return errors


def check_E49_clearing_missing(accounts: List[Dict]) -> List[COAError]:
    """E49 — حساب وسيط مفقود | High | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_banks    = sum(1 for n in names if re.search(r"بنك|bank|مصرف", n, re.I)) > 1
    has_clearing = any(re.search(r"معلق|تسوية|clearing|suspense|قيد.*عبور", n, re.I) for n in names)

    if has_banks and not has_clearing:
        errors.append(COAError(
            error_code="E49", severity="High", category="completeness",
            description_ar="شركة بأكثر من حساب بنكي بدون حساب تسوية/معلقات",
            cause_ar="التحويلات بين البنوك تحتاج حساباً وسيطاً يمنع الازدواجية",
            suggestion_ar="أضف: 'حساب معلقات بنكية' أو 'تسوية بين البنوك'",
            auto_fixable=False, references=[],
        ))
    return errors


def check_E50_sales_without_cogs(accounts: List[Dict]) -> List[COAError]:
    """E50 — مبيعات بدون تكلفة | Critical | 🔧 يدوي"""
    errors = []
    # يدعم name_raw (من engine) وname (من الاختبارات المباشرة)
    names = [str(a.get("name_raw","") or a.get("name","") or "") for a in accounts]
    has_sales = any(re.search(r"مبيعات|إيراد.*بيع|sales.*rev", n, re.I) for n in names)
    has_cogs  = any(re.search(r"تكلفة.*مبيع|COGS|cost.*goods|cost.*sales", n, re.I) for n in names)

    if has_sales and not has_cogs:
        errors.append(COAError(
            error_code="E50", severity="Critical", category="balance",
            description_ar="وُجدت مبيعات بدون تكلفة المبيعات (COGS) — دورة محاسبية ناقصة",
            cause_ar="كل إيراد بيع يقابله تكلفة — غياب COGS يُفسَد هامش الربح الإجمالي",
            suggestion_ar="أضف: 'تكلفة البضاعة المباعة' أو 'تكلفة الخدمات' في 5XXX",
            auto_fixable=False, references=["IAS 2 §10", "IAS 1 §99"],
        ))
    return errors


# ─────────────────────────────────────────────────────────────
# ═══ أخطاء البرنامج: EP1 - EP3 ═══════════════════════════════
# ─────────────────────────────────────────────────────────────

def check_EP1_erp_structure_mismatch(accounts: List[Dict], erp_system: Optional[str] = None) -> List[COAError]:
    """EP1 — هيكل لا يتوافق مع ERP المستهدف | High | 🔧 يدوي"""
    if not erp_system: return []
    errors = []
    ERP_REQUIREMENTS = {
        "SAP":   {"min_code_len": 4, "max_code_len": 10, "require_numeric": True},
        "Odoo":  {"allow_6digit": True, "require_user_type": False},
        "Zoho":  {"require_long_id": True},
    }
    req = ERP_REQUIREMENTS.get(erp_system.upper(), {})
    if not req: return []

    for acc in accounts:
        code = str(acc.get("code","") or "")
        if "min_code_len" in req and code.isdigit():
            if len(code) < req["min_code_len"]:
                errors.append(COAError(
                    error_code="EP1", severity="High", category="erp",
                    account_code=code, account_name=acc.get("name_raw",""),
                    description_ar=f"الكود '{code}' أقصر من الحد الأدنى لـ {erp_system} ({req['min_code_len']} أرقام)",
                    cause_ar=f"{erp_system} يتطلب أكواداً بطول معين للمزامنة الصحيحة",
                    suggestion_ar=f"أعِد ترقيم الكود بما يتوافق مع متطلبات {erp_system}",
                    auto_fixable=False, references=[f"{erp_system} Chart of Accounts Guidelines"],
                ))
    return errors


def check_EP2_coding_pattern_mismatch(accounts: List[Dict], erp_system: Optional[str] = None) -> List[COAError]:
    """EP2 — ترميز لا يتبع نمط ERP | Medium | ✅ إصلاح تلقائي"""
    if not erp_system: return []
    errors = []
    # نتحقق: Odoo يستخدم 6 أرقام عادةً
    if erp_system.upper() == "ODOO":
        short_codes = [a for a in accounts
                       if str(a.get("code","") or "").isdigit()
                       and len(str(a.get("code","") or "")) < 4]
        if len(short_codes) > len(accounts) * 0.5:
            errors.append(COAError(
                error_code="EP2", severity="Medium", category="erp",
                description_ar=f"معظم الأكواد أقصر من المعتاد لـ Odoo ({len(short_codes)} كود قصير)",
                cause_ar="Odoo يستخدم أكواداً من 4-6 أرقام عادةً — الأكواد القصيرة قد تُربك الاستيراد",
                suggestion_ar="وسِّع الأكواد لتتوافق مع نمط Odoo: 4+ أرقام",
                auto_fixable=True, references=["Odoo Chart of Accounts Best Practices"],
            ))
    return errors


def check_EP3_code_too_long(accounts: List[Dict], erp_system: Optional[str] = None) -> List[COAError]:
    """EP3 — طول الكود يتجاوز حد ERP | Medium | 🔧 يدوي"""
    errors = []
    ERP_MAX_LEN = {"SAP": 10, "QuickBooks": 7, "Xero": 10, "Zoho": 15}
    if not erp_system: return []
    max_len = ERP_MAX_LEN.get(erp_system, 999)

    for acc in accounts:
        code = str(acc.get("code","") or "")
        if len(code) > max_len:
            errors.append(COAError(
                error_code="EP3", severity="Medium", category="erp",
                account_code=code, account_name=acc.get("name_raw",""),
                description_ar=f"الكود '{code}' ({len(code)} رقم) يتجاوز الحد الأقصى لـ {erp_system} ({max_len})",
                cause_ar=f"{erp_system} لا يقبل أكواداً أطول من {max_len} خانة",
                suggestion_ar="اختصر الكود أو أعِد هيكلة الترقيم",
                auto_fixable=False, references=[f"{erp_system} Account Code Limits"],
            ))
    return errors


# ─────────────────────────────────────────────────────────────
# ═══ أخطاء الملفات الحقيقية: EC1 - EC5 ══════════════════════
# ─────────────────────────────────────────────────────────────

def check_EC1_negative_cash(accounts: List[Dict]) -> List[COAError]:
    """EC1 — رصيد سالب في صندوق نقدي | Critical | ✅ إصلاح تلقائي"""
    errors = []
    for acc in accounts:
        name    = str(acc.get("name_raw","") or "")
        balance = acc.get("balance", 0)
        is_cash = re.search(r"صندوق|نثرية|petty.?cash|cash.?on.?hand", name, re.I)
        if is_cash and balance is not None:
            try:
                if float(balance) < 0:
                    errors.append(COAError(
                        error_code="EC1", severity="Critical", category="real_file",
                        account_code=acc.get("code"), account_name=name,
                        description_ar=f"صندوق '{name}' برصيد سالب: {balance}",
                        cause_ar="الصندوق النقدي لا يمكن أن يكون سالباً — يشير لخطأ في التسجيل",
                        suggestion_ar="إما خطأ في القيود أو تحويل من حساب الصندوق لم يُسجَّل",
                        auto_fixable=True, references=["IASC Framework: خصائص الأصول"],
                    ))
            except (ValueError, TypeError):
                pass
    return errors


def check_EC2_accum_depr_as_liability(accounts: List[Dict]) -> List[COAError]:
    """EC2 — مجمع إهلاك كـ التزام (خطأ Odoo) | Critical | ✅ إصلاح تلقائي"""
    errors = []
    for acc in accounts:
        name    = str(acc.get("name_raw","") or "")
        section = str(acc.get("section","") or acc.get("classified_as","") or "")
        utype   = str(acc.get("type","") or "")
        is_accum_depr = re.search(r"مجمع.*(إهلاك|اهلاك|استهلاك)", name, re.I)
        is_liability  = "liability" in section.lower() or "التزام" in utype.lower() or "الالتزامات" in utype

        if is_accum_depr and is_liability:
            errors.append(COAError(
                error_code="EC2", severity="Critical", category="real_file",
                account_code=acc.get("code"), account_name=name,
                description_ar=f"'{name}' مُصنَّف كالتزام — خطأ Odoo الكلاسيكي",
                cause_ar="مجمع الإهلاك حساب مقابل للأصول (contra-asset)، ليس التزاماً",
                suggestion_ar="انقل لقسم الأصول الثابتة مع الحفاظ على طبيعته الدائنة",
                auto_fixable=True, references=["IAS 16 §73", "IASC Framework: الأصول المقابلة"],
            ))
    return errors


def check_EC3_employee_code_duplicate(accounts: List[Dict]) -> List[COAError]:
    """EC3 — تكرار كود مقصود للموظفين (Odoo) | High | 🔧 يدوي"""
    errors = []
    code_count: Dict[str, int] = {}
    for acc in accounts:
        code = str(acc.get("code","") or "")
        name = str(acc.get("name_raw","") or "")
        if re.search(r"موظف|عامل|employee|worker", name, re.I):
            code_count[code] = code_count.get(code, 0) + 1

    for code, count in code_count.items():
        if count > 1:
            errors.append(COAError(
                error_code="EC3", severity="High", category="real_file",
                account_code=code,
                description_ar=f"الكود {code} مستخدم لـ {count} حسابات موظفين مختلفة",
                cause_ar="Odoo يستخدم أحياناً نفس الكود لموظفين متعددين — يُربك الميزان",
                suggestion_ar="أعطِ كل موظف كوداً فريداً أو ادمج في حساب 'رواتب موظفين' واحد",
                auto_fixable=False, references=["Odoo HR Payroll Configuration"],
            ))
    return errors


def check_EC4_journals_mixed(accounts: List[Dict]) -> List[COAError]:
    """EC4 — يوميات مخلوطة مع COA | High | ✅ إصلاح تلقائي"""
    errors = []
    journal_codes = {"TA","INV","BILL","MISC","JNL","PO","SO","BANK"}
    for acc in accounts:
        code = str(acc.get("code","") or "").upper().strip()
        if code in journal_codes:
            errors.append(COAError(
                error_code="EC4", severity="High", category="real_file",
                account_code=code, account_name=acc.get("name_raw",""),
                description_ar=f"الكود '{code}' يبدو قيد يوميات مُدرَج في شجرة الحسابات",
                cause_ar="اختلاط السجلات المحاسبية مع الشجرة يُفسد التحليل",
                suggestion_ar="احذف هذا السجل من شجرة الحسابات — اليوميات تُعالَج منفصلاً",
                auto_fixable=True, references=[],
            ))
    return errors


def check_EC5_operational_data_mixed(accounts: List[Dict]) -> List[COAError]:
    """EC5 — ملف بيانات مختلطة | Critical | ✅ إصلاح تلقائي (رفض)"""
    errors = []
    mixed_indicators = 0
    all_names = " ".join(str(a.get("name_raw","") or "") for a in accounts)

    if re.search(r"عميل|customer|زبون|client", all_names, re.I): mixed_indicators += 1
    if re.search(r"مورد|vendor|supplier", all_names, re.I):       mixed_indicators += 1
    if re.search(r"صنف|منتج|product|item", all_names, re.I):     mixed_indicators += 1
    if len(accounts) > 0:
        avg_fields = sum(len(a) for a in accounts) / len(accounts)
        if avg_fields > 10: mixed_indicators += 1

    if mixed_indicators >= 3:
        errors.append(COAError(
            error_code="EC5", severity="Critical", category="real_file",
            description_ar="الملف يخلط بيانات COA مع بيانات عملاء/موردين/أصناف",
            cause_ar="الملفات المختلطة لا تُمثِّل شجرة حسابات — تحتاج فصلاً قبل المعالجة",
            suggestion_ar="ارفع ملف COA منفصلاً يحتوي الحسابات فقط",
            auto_fixable=True, references=[],
        ))
    return errors


# ─────────────────────────────────────────────────────────────
# الدالة الرئيسية لـ Wave 2
# ─────────────────────────────────────────────────────────────
def run_wave2_checks(
    accounts:   List[Dict[str, Any]],
    tree:       Optional[Dict] = None,
    erp_system: Optional[str] = None,
    sector:     Optional[str] = None,
    upload_date: Optional[date] = None,
) -> List[COAError]:
    """
    يُشغِّل كل فحوصات Wave 2 (E21-E50 + EP1-EP3 + EC1-EC5).
    يُستدعى بعد run_all_checks() من Wave 1.
    """
    tree = tree or {}
    all_errors: List[COAError] = []

    checks = [
        # مسميات E21-E26
        check_E21_ambiguous_name(accounts),
        check_E22_duplicate_name(accounts),
        check_E23_name_section_mismatch(accounts),
        check_E24_spelling_error(accounts),
        check_E25_name_too_long(accounts),
        check_E26_abbreviation_unclear(accounts),
        # IFRS E27-E31
        check_E27_ifrs16_missing(accounts),
        check_E28_ecl_missing(accounts),
        check_E29_ifrs15_missing(accounts),
        check_E30_biological_assets(accounts),
        check_E31_contract_liability(accounts),
        # ضريبي سعودي E32-E36
        check_E32_vat_missing(accounts),
        check_E33_vat_unseparated(accounts),
        check_E34_zakat_missing(accounts),
        check_E35_zakat_tax_mixed(accounts),
        check_E36_withholding_missing(accounts),
        # نقص/زيادة/ترميز/توازن E37-E50
        check_E37_depreciation_expense_missing(accounts),
        check_E38_provisions_missing(accounts),
        check_E39_redundant_accounts(accounts),
        check_E40_over_detailed(accounts),
        check_E41_code_length_inconsistent(accounts),
        check_E42_code_has_letters(accounts),
        check_E43_code_no_parent_prefix(accounts),
        check_E44_large_code_gaps(accounts),
        check_E45_wrong_sector_account(accounts),
        check_E46_mandatory_accounts_missing(accounts, sector),
        check_E47_regulatory_missing(accounts, sector),
        check_E48_missing_accumulated_depr(accounts),
        check_E49_clearing_missing(accounts),
        check_E50_sales_without_cogs(accounts),
        # ERP EP1-EP3
        check_EP1_erp_structure_mismatch(accounts, erp_system),
        check_EP2_coding_pattern_mismatch(accounts, erp_system),
        check_EP3_code_too_long(accounts, erp_system),
        # ملفات حقيقية EC1-EC5
        check_EC1_negative_cash(accounts),
        check_EC2_accum_depr_as_liability(accounts),
        check_EC3_employee_code_duplicate(accounts),
        check_EC4_journals_mixed(accounts),
        check_EC5_operational_data_mixed(accounts),
    ]

    for error_list in checks:
        all_errors.extend(error_list)

    severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    all_errors.sort(key=lambda e: severity_order.get(e.severity, 99))
    return all_errors


def run_all_checks_complete(
    accounts:   List[Dict],
    tree:       Optional[Dict] = None,
    erp_system: Optional[str] = None,
    sector:     Optional[str] = None,
) -> List[COAError]:
    """
    يُشغِّل الـ 58 خطأ كاملاً (Wave 1 + Wave 2).
    هذه هي نقطة الدخول الموحّدة.
    """
    from .error_checks import run_all_checks
    w1 = run_all_checks(accounts, tree)
    w2 = run_wave2_checks(accounts, tree, erp_system, sector)
    combined = w1 + w2
    severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3}
    combined.sort(key=lambda e: severity_order.get(e.severity, 99))
    return combined
