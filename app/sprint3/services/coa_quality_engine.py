"""
APEX Sprint 3 — COA Quality Assessment Engine
═══════════════════════════════════════════════════════════════
Evaluates COA quality across 5 dimensions:
  1. Completeness — are essential account categories present?
  2. Classification Consistency — do parent/child/type align?
  3. Naming Clarity — are names clear or ambiguous?
  4. Duplication Risk — are there near-duplicate accounts?
  5. Reporting Readiness — can we build financial statements?

Per Apex_Coa_First_Workflow_Execution_Document §14
"""

import re
from typing import List, Dict, Any, Optional, Tuple
from difflib import SequenceMatcher
from app.core.text_utils import normalize_arabic


# ── Essential categories for a complete COA ──

ESSENTIAL_CATEGORIES = {
    "cash": {"ar": ["صندوق", "نقد", "كاش", "بنك"], "en": ["cash", "bank"]},
    "receivables": {"ar": ["ذمم مدين", "عملاء", "مدينون"], "en": ["receivable", "debtor"]},
    "inventory": {"ar": ["مخزون", "بضاع"], "en": ["inventory", "stock"]},
    "fixed_assets": {"ar": ["أصول ثابت", "ممتلكات", "عقار"], "en": ["fixed asset", "property", "equipment", "ppe"]},
    "payables": {"ar": ["ذمم دائن", "موردي", "دائنون"], "en": ["payable", "creditor"]},
    "equity_capital": {"ar": ["رأس مال", "رأسمال"], "en": ["capital", "equity"]},
    "revenue": {"ar": ["إيراد", "مبيعات"], "en": ["revenue", "sales", "income"]},
    "cogs": {"ar": ["تكلف مبيع", "تكلف بضاع", "كلف إيراد"], "en": ["cost of", "cogs"]},
    "operating_expense": {"ar": ["مصروف", "رواتب", "إيجار"], "en": ["expense", "salary", "rent"]},
}

# Some categories only needed for certain activities
CONDITIONAL_CATEGORIES = {
    "inventory": ["retail", "manufacturing", "trading", "wholesale", "general"],
}

# ── Ambiguous name patterns ──
AMBIGUOUS_PATTERNS_AR = [
    r"^حساب عام$", r"^متنوعات$", r"^أخرى$", r"^عهد$", r"^ذمم$",
    r"^حساب \d+$", r"^بند \d+$", r"^أخرى.*أخرى$", r"^حسابات$",
    r"^مصروفات$", r"^إيرادات$",
]
AMBIGUOUS_PATTERNS_EN = [
    r"^other$", r"^misc", r"^general$", r"^account \d+$",
    r"^sundry$", r"^various$", r"^expenses$", r"^revenues$",
]



def assess_completeness(accounts: List[Dict], activity: str = "general") -> Dict:
    """Check if essential account categories are present."""
    all_names = " ".join([normalize_arabic(a.get("account_name_raw", "")) for a in accounts])
    found = {}
    missing = []

    for cat_key, patterns in ESSENTIAL_CATEGORIES.items():
        # Skip conditional categories if not relevant
        if cat_key in CONDITIONAL_CATEGORIES:
            if activity not in CONDITIONAL_CATEGORIES[cat_key]:
                continue

        cat_found = False
        for lang_patterns in [patterns.get("ar", []), patterns.get("en", [])]:
            for p in lang_patterns:
                if normalize_arabic(p) in all_names:
                    cat_found = True
                    break
            if cat_found:
                break

        found[cat_key] = cat_found
        if not cat_found:
            missing.append(cat_key)

    total_expected = len([k for k in ESSENTIAL_CATEGORIES if k not in CONDITIONAL_CATEGORIES or activity in CONDITIONAL_CATEGORIES.get(k, [])])
    found_count = total_expected - len(missing)
    score = round(found_count / max(total_expected, 1), 3)

    return {
        "score": score,
        "found_categories": {k: v for k, v in found.items() if v},
        "missing_categories": missing,
        "total_expected": total_expected,
        "found_count": found_count,
    }


def assess_consistency(accounts: List[Dict]) -> Dict:
    """Check classification consistency: parent-child alignment, type coherence."""
    issues = []
    total_checks = 0
    passed_checks = 0

    # Build lookup
    code_map = {}
    for a in accounts:
        code = a.get("account_code")
        if code:
            code_map[code] = a

    for a in accounts:
        nc = a.get("normalized_class")
        parent_code = a.get("parent_code")
        if not nc or not parent_code:
            continue

        parent = code_map.get(parent_code)
        if not parent:
            continue

        parent_nc = parent.get("normalized_class")
        if not parent_nc:
            continue

        total_checks += 1

        # Parent and child should generally share the same top class
        compatible = (
            nc == parent_nc
            or (nc == "contra" and parent_nc in ("asset", "liability", "equity", "revenue"))
            or (parent_nc == "other")
        )

        if compatible:
            passed_checks += 1
        else:
            issues.append({
                "type": "parent_child_mismatch",
                "account_code": a.get("account_code"),
                "account_name": a.get("account_name_raw", "")[:80],
                "account_class": nc,
                "parent_code": parent_code,
                "parent_class": parent_nc,
            })

    # Check sign rule consistency within sections
    section_signs = {}
    for a in accounts:
        section = a.get("statement_section")
        sign = a.get("sign_rule")
        if section and sign:
            if section not in section_signs:
                section_signs[section] = {}
            section_signs[section][sign] = section_signs[section].get(sign, 0) + 1

    for section, signs in section_signs.items():
        if len(signs) > 1:
            dominant = max(signs, key=signs.get)
            minority_count = sum(v for k, v in signs.items() if k != dominant)
            if minority_count > 0:
                total_checks += 1
                if minority_count / sum(signs.values()) > 0.3:
                    issues.append({
                        "type": "sign_rule_inconsistency",
                        "section": section,
                        "sign_distribution": signs,
                    })
                else:
                    passed_checks += 1

    score = round(passed_checks / max(total_checks, 1), 3)
    return {"score": score, "issues": issues[:20], "total_checks": total_checks, "passed_checks": passed_checks}


def assess_naming_clarity(accounts: List[Dict]) -> Dict:
    """Identify ambiguous or unclear account names."""
    ambiguous = []
    total = len(accounts)

    for a in accounts:
        name = a.get("account_name_raw", "")
        norm_name = normalize_arabic(name)

        is_ambiguous = False
        reason = None

        # Check Arabic patterns
        for pat in AMBIGUOUS_PATTERNS_AR:
            if re.search(pat, norm_name):
                is_ambiguous = True
                reason = "ambiguous_arabic_name"
                break

        # Check English patterns
        if not is_ambiguous:
            for pat in AMBIGUOUS_PATTERNS_EN:
                if re.search(pat, name.lower()):
                    is_ambiguous = True
                    reason = "ambiguous_english_name"
                    break

        # Very short names (< 3 chars)
        if not is_ambiguous and len(name.strip()) < 3:
            is_ambiguous = True
            reason = "name_too_short"

        # Very long names (> 100 chars) — may be data quality issue
        if not is_ambiguous and len(name.strip()) > 100:
            is_ambiguous = True
            reason = "name_too_long"

        if is_ambiguous:
            ambiguous.append({
                "account_code": a.get("account_code"),
                "account_name": name[:80],
                "reason": reason,
            })

    clear_count = total - len(ambiguous)
    score = round(clear_count / max(total, 1), 3)
    return {"score": score, "ambiguous_accounts": ambiguous[:30], "total": total, "clear_count": clear_count}


def assess_duplication_risk(accounts: List[Dict]) -> Dict:
    """Find near-duplicate accounts that may cause confusion."""
    suspects = []
    names_with_idx = [(i, normalize_arabic(a.get("account_name_raw", ""))) for i, a in enumerate(accounts)]

    # Compare pairs — limit to avoid O(n²) explosion on large COAs
    max_compare = min(len(names_with_idx), 500)
    checked = 0

    for i in range(max_compare):
        for j in range(i + 1, max_compare):
            idx_a, name_a = names_with_idx[i]
            idx_b, name_b = names_with_idx[j]

            if not name_a or not name_b:
                continue
            if len(name_a) < 3 or len(name_b) < 3:
                continue

            ratio = SequenceMatcher(None, name_a, name_b).ratio()
            checked += 1

            if ratio >= 0.85 and name_a != name_b:
                acc_a = accounts[idx_a]
                acc_b = accounts[idx_b]
                # Different codes but similar names = suspect
                if acc_a.get("account_code") != acc_b.get("account_code"):
                    suspects.append({
                        "account_a": {"code": acc_a.get("account_code"), "name": acc_a.get("account_name_raw", "")[:60]},
                        "account_b": {"code": acc_b.get("account_code"), "name": acc_b.get("account_name_raw", "")[:60]},
                        "similarity": round(ratio, 3),
                    })

    # Exact code duplicates
    code_counts = {}
    for a in accounts:
        code = a.get("account_code")
        if code:
            code_counts[code] = code_counts.get(code, 0) + 1
    exact_dups = {k: v for k, v in code_counts.items() if v > 1}

    risk_count = len(suspects) + len(exact_dups)
    total = len(accounts)
    score = round(max(0, 1.0 - (risk_count / max(total, 1))), 3)

    return {
        "score": score,
        "duplicate_suspects": suspects[:20],
        "exact_code_duplicates": exact_dups,
        "risk_count": risk_count,
    }


def assess_reporting_readiness(accounts: List[Dict]) -> Dict:
    """Can we build income statement, balance sheet, cash flow from this COA?"""
    sections_found = set()
    class_counts = {}

    for a in accounts:
        nc = a.get("normalized_class")
        ss = a.get("statement_section")
        if nc:
            class_counts[nc] = class_counts.get(nc, 0) + 1
        if ss:
            sections_found.add(ss)

    # Required for income statement
    has_revenue = "revenue" in class_counts
    has_expense = "expense" in class_counts
    income_ready = has_revenue and has_expense

    # Required for balance sheet
    has_asset = "asset" in class_counts
    has_liability = "liability" in class_counts
    has_equity = "equity" in class_counts
    balance_ready = has_asset and (has_liability or has_equity)

    # Required for cash flow
    has_current_noncurrent = any("noncurrent" in s for s in sections_found)
    cashflow_ready = income_ready and balance_ready and has_current_noncurrent

    # Required for ratios
    has_sections = len(sections_found) >= 4
    ratio_ready = has_sections and income_ready and balance_ready

    readiness_items = {
        "income_statement": income_ready,
        "balance_sheet": balance_ready,
        "cash_flow": cashflow_ready,
        "ratio_analysis": ratio_ready,
    }

    ready_count = sum(1 for v in readiness_items.values() if v)
    score = round(ready_count / len(readiness_items), 3)

    return {
        "score": score,
        "readiness": readiness_items,
        "class_distribution": class_counts,
        "sections_found": sorted(sections_found),
    }


def run_full_assessment(
    accounts: List[Dict],
    activity: str = "general",
) -> Dict:
    """
    Run all 5 quality assessments and compute overall score.

    accounts: list of dicts with keys:
      account_code, account_name_raw, parent_code, normalized_class,
      statement_section, sign_rule, mapping_confidence, etc.
    """
    completeness = assess_completeness(accounts, activity)
    consistency = assess_consistency(accounts)
    naming = assess_naming_clarity(accounts)
    duplication = assess_duplication_risk(accounts)
    readiness = assess_reporting_readiness(accounts)

    # Weighted overall score
    weights = {
        "completeness": 0.25,
        "consistency": 0.20,
        "naming_clarity": 0.15,
        "duplication_risk": 0.15,
        "reporting_readiness": 0.25,
    }

    overall = round(
        completeness["score"] * weights["completeness"]
        + consistency["score"] * weights["consistency"]
        + naming["score"] * weights["naming_clarity"]
        + duplication["score"] * weights["duplication_risk"]
        + readiness["score"] * weights["reporting_readiness"],
        3
    )

    # Build recommendations
    recommendations = []
    if completeness["missing_categories"]:
        cats_ar = ", ".join(completeness["missing_categories"][:5])
        recommendations.append(f"أضف حسابات للفئات الناقصة: {cats_ar}")

    if consistency["issues"]:
        recommendations.append(f"راجع {len(consistency['issues'])} حالة عدم اتساق في تبويب الحسابات الأب والأبناء")

    if naming["ambiguous_accounts"]:
        recommendations.append(f"وضّح أسماء {len(naming['ambiguous_accounts'])} حساب مبهم لتحسين دقة التصنيف")

    if duplication["duplicate_suspects"]:
        recommendations.append(f"تحقق من {len(duplication['duplicate_suspects'])} حساب مشتبه بالتكرار")

    if not readiness["readiness"]["cash_flow"]:
        recommendations.append("أضف تمييز الأصول والالتزامات المتداولة/غير المتداولة لتمكين قائمة التدفقات النقدية")

    # Collect all issues
    all_issues = []
    for issue in consistency["issues"][:10]:
        all_issues.append({"type": issue["type"], "details": issue})
    for amb in naming["ambiguous_accounts"][:10]:
        all_issues.append({"type": "ambiguous_name", "details": amb})

    return {
        "overall_score": overall,
        "completeness_score": completeness["score"],
        "consistency_score": consistency["score"],
        "naming_clarity_score": naming["score"],
        "duplication_risk_score": duplication["score"],
        "reporting_readiness_score": readiness["score"],
        "completeness": completeness,
        "consistency": consistency,
        "naming_clarity": naming,
        "duplication_risk": duplication,
        "reporting_readiness": readiness,
        "recommendations": recommendations,
        "issues": all_issues,
        "total_accounts": len(accounts),
    }
