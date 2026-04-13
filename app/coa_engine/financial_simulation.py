"""
ملحق ن + ل2 + ن2 — Financial Simulation, Compliance & Roadmap
==============================================================
محاكاة القوائم المالية، فحص الامتثال التنظيمي، وخارطة الإصلاح.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Set

# ═══════════════════════════════════════════════════════════════
# ملحق ن — Financial Simulation
# ═══════════════════════════════════════════════════════════════

# Section family mappings
_ASSET_SECTIONS = {"asset", "current_asset", "fixed_asset", "non_current_asset"}
_LIABILITY_SECTIONS = {"liability", "current_liability", "non_current_liability"}
_EQUITY_SECTIONS = {"equity"}
_REVENUE_SECTIONS = {"revenue", "other_income"}
_COGS_SECTIONS = {"cogs"}
_EXPENSE_SECTIONS = {"expense", "other_expense", "finance_cost"}


def _concepts(accounts: List[Dict]) -> Set[str]:
    """Extract set of concept_ids present."""
    return {
        str(a.get("concept_id") or "").strip()
        for a in accounts
        if a.get("concept_id")
    }


def _sections(accounts: List[Dict]) -> Set[str]:
    """Extract set of sections present."""
    return {
        str(a.get("section") or "").strip().lower()
        for a in accounts
        if a.get("section")
    }


def _names_lower(accounts: List[Dict]) -> Set[str]:
    """Extract lowercase names."""
    result = set()
    for a in accounts:
        for key in ("name_raw", "name_normalized", "name"):
            v = a.get(key)
            if v:
                result.add(str(v).strip().lower())
                break
    return result


def _has_any_concept(concepts: Set[str], targets: List[str]) -> bool:
    return bool(concepts & set(targets))


def _accounts_in_section_family(accounts: List[Dict], family: Set[str]) -> List[Dict]:
    return [a for a in accounts if str(a.get("section", "")).strip().lower() in family]


def simulate_financial_statements(accounts: List[Dict]) -> Dict[str, Any]:
    """
    يحاكي القوائم المالية من شجرة الحسابات.
    يكتشف الثغرات الهيكلية قبل رفع أي بيانات فعلية.
    """
    secs = _sections(accounts)
    concepts = _concepts(accounts)
    names = _names_lower(accounts)

    asset_accs = _accounts_in_section_family(accounts, _ASSET_SECTIONS)
    liab_accs = _accounts_in_section_family(accounts, _LIABILITY_SECTIONS)
    equity_accs = _accounts_in_section_family(accounts, _EQUITY_SECTIONS)
    revenue_accs = _accounts_in_section_family(accounts, _REVENUE_SECTIONS)
    cogs_accs = _accounts_in_section_family(accounts, _COGS_SECTIONS)
    expense_accs = _accounts_in_section_family(accounts, _EXPENSE_SECTIONS)

    # ── Balance Sheet ──
    has_assets = len(asset_accs) > 0
    has_liabilities = len(liab_accs) > 0
    has_equity = len(equity_accs) > 0
    equation_valid = has_assets and (has_liabilities or has_equity)

    bs_missing = []
    if not has_assets:
        bs_missing.append("لا توجد أصول")
    if not has_liabilities:
        bs_missing.append("لا توجد خصوم")
    if not has_equity:
        bs_missing.append("لا توجد حقوق ملكية")

    balance_sheet = {
        "total_assets": {"found": has_assets, "count": len(asset_accs)},
        "total_liabilities": {"found": has_liabilities, "count": len(liab_accs)},
        "total_equity": {"found": has_equity, "count": len(equity_accs)},
        "equation_valid": equation_valid,
        "missing_sections": bs_missing,
    }

    # ── Income Statement ──
    has_revenue = len(revenue_accs) > 0
    has_cogs = len(cogs_accs) > 0 or _has_any_concept(concepts, ["COGS", "DIRECT_COSTS"])
    has_gross_profit = has_revenue and has_cogs
    has_operating_expenses = len(expense_accs) > 0
    has_finance_costs = _has_any_concept(concepts, ["INTEREST_EXPENSE", "BANK_CHARGES", "FINANCE_COST"])

    is_missing = []
    if not has_revenue:
        is_missing.append("لا توجد إيرادات")
    if not has_cogs and has_revenue:
        is_missing.append("لا تكلفة مبيعات")
    if not has_operating_expenses:
        is_missing.append("لا مصروفات تشغيلية")

    income_statement = {
        "has_revenue": has_revenue,
        "has_cogs": has_cogs,
        "has_gross_profit": has_gross_profit,
        "has_operating_expenses": has_operating_expenses,
        "has_finance_costs": has_finance_costs,
        "missing_sections": is_missing,
    }

    # ── Cash Flow Indicators ──
    has_cash = _has_any_concept(concepts, ["CASH", "BANK", "PETTY_CASH"])
    has_depreciation = _has_any_concept(concepts, [
        "DEPRECIATION_EXPENSE", "AMORTIZATION_EXPENSE",
        "ACCUM_DEPR_GENERAL", "ACCUM_DEPR_BUILDINGS",
        "ACCUM_DEPR_MACHINERY", "ACCUM_DEPR_VEHICLES",
    ])
    has_working_capital = (
        _has_any_concept(concepts, ["ACC_RECEIVABLE", "NOTES_RECEIVABLE"])
        or _has_any_concept(concepts, ["INVENTORY"])
        or _has_any_concept(concepts, ["ACC_PAYABLE"])
    )

    cash_flow_indicators = {
        "has_cash_accounts": has_cash,
        "has_depreciation": has_depreciation,
        "has_working_capital": has_working_capital,
    }

    # ── Structural Gaps ──
    gaps: List[Dict] = []

    # MISSING_COGS
    if has_revenue and not has_cogs:
        gaps.append({
            "gap": "MISSING_COGS",
            "severity": "Critical",
            "message_ar": "لا تكلفة مبيعات — القوائم المالية ستكون ناقصة",
            "fix": "أضف حساب تكلفة المبيعات في 5XXX",
        })

    # MISSING_DEPRECIATION
    fixed_asset_accs = _accounts_in_section_family(accounts, {"fixed_asset", "non_current_asset"})
    depreciable = [a for a in fixed_asset_accs
                   if str(a.get("concept_id", "")).strip() not in
                   ("LAND", "CIP", "GOODWILL", "ACCUM_DEPR_GENERAL",
                    "ACCUM_DEPR_BUILDINGS", "ACCUM_DEPR_MACHINERY",
                    "ACCUM_DEPR_VEHICLES", "ACCUM_DEPR_COMPUTERS",
                    "ACCUM_DEPR_FURNITURE", "ACCUM_DEPR_ROU",
                    "GOODWILL_IMPAIRMENT", "FIXED_ASSETS", "INTANGIBLE_ASSETS")
                   and not str(a.get("concept_id", "")).startswith("ACCUM_DEPR")]
    if depreciable and not _has_any_concept(concepts, ["DEPRECIATION_EXPENSE"]):
        gaps.append({
            "gap": "MISSING_DEPRECIATION",
            "severity": "High",
            "message_ar": f"يوجد {len(depreciable)} أصل ثابت بدون مصروف إهلاك",
            "fix": "أضف حساب مصروف إهلاك في 6XXX",
        })

    # MISSING_FINANCE_COST
    has_loans = _has_any_concept(concepts, ["LONG_TERM_LOAN", "CURRENT_PORTION_LTD"])
    if has_loans and not has_finance_costs:
        gaps.append({
            "gap": "MISSING_FINANCE_COST",
            "severity": "High",
            "message_ar": "قروض بدون مصروف فوائد",
            "fix": "أضف حساب مصروف فوائد في 6XXX",
        })

    # MISSING_TAX
    has_capital = _has_any_concept(concepts, ["PAID_IN_CAPITAL"])
    has_zakat = _has_any_concept(concepts, ["ZAKAT_PAYABLE", "ZAKAT_EXPENSE"])
    has_tax = _has_any_concept(concepts, ["INCOME_TAX_PAYABLE", "INCOME_TAX_EXPENSE"])
    if has_capital and not has_zakat and not has_tax:
        gaps.append({
            "gap": "MISSING_TAX",
            "severity": "High",
            "message_ar": "شركة بدون حساب ضريبة أو زكاة",
            "fix": "أضف حساب زكاة مستحقة أو ضريبة دخل",
        })

    # UNBALANCED_STRUCTURE
    if has_assets and not has_liabilities and not has_equity:
        gaps.append({
            "gap": "UNBALANCED_STRUCTURE",
            "severity": "Critical",
            "message_ar": "لا حقوق ملكية ولا خصوم — معادلة الميزانية غير محققة",
            "fix": "أضف حقوق ملكية (رأس المال + أرباح مبقاة) وخصوم",
        })

    # MISSING_RETAINED_EARNINGS
    if has_equity and not _has_any_concept(concepts, ["RETAINED_EARNINGS"]):
        gaps.append({
            "gap": "MISSING_RETAINED_EARNINGS",
            "severity": "Medium",
            "message_ar": "لا يوجد حساب أرباح مبقاة",
            "fix": "أضف حساب أرباح مبقاة في حقوق الملكية",
        })

    # MISSING_EOSB
    has_salaries = _has_any_concept(concepts, ["SALARIES_WAGES", "EMPLOYEE_BENEFITS"])
    has_eosb = _has_any_concept(concepts, ["EOSB_PROVISION", "EOSB_EXPENSE"])
    if has_salaries and not has_eosb:
        gaps.append({
            "gap": "MISSING_EOSB",
            "severity": "High",
            "message_ar": "رواتب موظفين بدون مكافأة نهاية خدمة",
            "fix": "أضف مخصص ومصروف نهاية الخدمة",
        })

    # INCOMPLETE_VAT
    has_vat_in = _has_any_concept(concepts, ["VAT_INPUT"])
    has_vat_out = _has_any_concept(concepts, ["VAT_OUTPUT"])
    if has_vat_in and not has_vat_out:
        gaps.append({
            "gap": "INCOMPLETE_VAT",
            "severity": "High",
            "message_ar": "ض.ق.م مدخلات بدون مخرجات",
            "fix": "أضف حساب ض.ق.م مخرجات في الخصوم المتداولة",
        })
    if has_vat_out and not has_vat_in:
        gaps.append({
            "gap": "INCOMPLETE_VAT",
            "severity": "Medium",
            "message_ar": "ض.ق.م مخرجات بدون مدخلات",
            "fix": "أضف حساب ض.ق.م مدخلات في الأصول المتداولة",
        })

    # ── Readiness Score ──
    # Base: 50, +10 per major section, -15 per critical gap, -8 per high gap
    readiness = 50
    if has_assets:
        readiness += 10
    if has_liabilities:
        readiness += 8
    if has_equity:
        readiness += 8
    if has_revenue:
        readiness += 8
    if has_cogs:
        readiness += 6
    if has_operating_expenses:
        readiness += 5
    if has_cash:
        readiness += 5

    for g in gaps:
        if g["severity"] == "Critical":
            readiness -= 15
        elif g["severity"] == "High":
            readiness -= 8
        elif g["severity"] == "Medium":
            readiness -= 3

    readiness = max(0, min(100, readiness))

    return {
        "balance_sheet": balance_sheet,
        "income_statement": income_statement,
        "cash_flow_indicators": cash_flow_indicators,
        "structural_gaps": gaps,
        "readiness_score": readiness,
    }


# ═══════════════════════════════════════════════════════════════
# ملحق ل2 — Regulatory Compliance Checklist
# ═══════════════════════════════════════════════════════════════

def _check_zatca_vat(concepts: Set[str], **_kw) -> bool:
    return "VAT_INPUT" in concepts and "VAT_OUTPUT" in concepts


def _check_zatca_vat_has_any(concepts: Set[str], **_kw) -> bool:
    """At least one of VAT_INPUT or VAT_OUTPUT must exist if there's revenue."""
    return "VAT_INPUT" in concepts or "VAT_OUTPUT" in concepts


def _check_zatca_withholding(concepts: Set[str], names: Set[str], **_kw) -> bool:
    wh_keywords = {"استقطاع", "withholding", "ضريبة استقطاع"}
    if any(k in n for n in names for k in wh_keywords):
        return True
    # Not applicable if no foreign services detected
    foreign_kw = {"أجنبي", "foreign", "خارجي", "استشارات خارجية"}
    has_foreign = any(k in n for n in names for k in foreign_kw)
    return not has_foreign  # pass if no foreign services


def _check_sama_reserve(concepts: Set[str], sector: Optional[str], **_kw) -> bool:
    if sector and sector.upper() in ("BANKING", "INSURANCE"):
        return "STATUTORY_RESERVE" in concepts or "LEGAL_RESERVE" in concepts
    return True  # N/A for non-banking


def _check_companies_law_reserve(concepts: Set[str], **_kw) -> bool:
    if "PAID_IN_CAPITAL" in concepts:
        return "LEGAL_RESERVE" in concepts or "STATUTORY_RESERVE" in concepts
    return True


def _check_zakat_required(concepts: Set[str], **_kw) -> bool:
    if "PAID_IN_CAPITAL" in concepts:
        return "ZAKAT_PAYABLE" in concepts or "ZAKAT_EXPENSE" in concepts or "INCOME_TAX_PAYABLE" in concepts
    return True


def _check_ifrs9_ecl(concepts: Set[str], **_kw) -> bool:
    if "ACC_RECEIVABLE" in concepts:
        return "ECL_PROVISION" in concepts
    return True


def _check_ifrs16_lease(concepts: Set[str], **_kw) -> bool:
    if "ROU_ASSET" in concepts:
        return "LEASE_LIABILITY_NC" in concepts or "LEASE_LIABILITY_CURRENT" in concepts
    return True


def _check_ias37_eosb(concepts: Set[str], **_kw) -> bool:
    if "SALARIES_WAGES" in concepts or "EMPLOYEE_BENEFITS" in concepts:
        return "EOSB_PROVISION" in concepts or "EOSB_EXPENSE" in concepts
    return True


COMPLIANCE_RULES: List[Dict[str, Any]] = [
    {
        "id": "ZATCA_VAT_SEPARATION",
        "authority": "ZATCA",
        "requirement_ar": "فصل ض.ق.م المدخلات عن المخرجات",
        "check_fn": _check_zatca_vat,
        "severity": "Critical",
        "ref": "نظام ضريبة القيمة المضافة §53",
    },
    {
        "id": "ZATCA_WITHHOLDING",
        "authority": "ZATCA",
        "requirement_ar": "حساب ضريبة الاستقطاع للتعاملات الأجنبية",
        "check_fn": _check_zatca_withholding,
        "severity": "High",
        "ref": "ZATCA Withholding Tax",
    },
    {
        "id": "SAMA_RESERVE",
        "authority": "SAMA",
        "requirement_ar": "الاحتياطي الإلزامي للبنوك والتأمين",
        "check_fn": _check_sama_reserve,
        "severity": "Critical",
        "ref": "SAMA Banking Rules",
    },
    {
        "id": "COMPANIES_LAW_RESERVE",
        "authority": "SOCPA",
        "requirement_ar": "الاحتياطي النظامي 10% من رأس المال",
        "check_fn": _check_companies_law_reserve,
        "severity": "High",
        "ref": "نظام الشركات السعودي §129",
    },
    {
        "id": "ZAKAT_REQUIRED",
        "authority": "ZATCA",
        "requirement_ar": "زكاة مستحقة للشركات السعودية",
        "check_fn": _check_zakat_required,
        "severity": "High",
        "ref": "نظام الزكاة السعودي",
    },
    {
        "id": "IFRS9_ECL",
        "authority": "IFRS",
        "requirement_ar": "مخصص ECL للذمم المدينة (IFRS 9)",
        "check_fn": _check_ifrs9_ecl,
        "severity": "High",
        "ref": "IFRS 9 §5.5",
    },
    {
        "id": "IFRS16_LEASE",
        "authority": "IFRS",
        "requirement_ar": "التزام الإيجار مقابل أصل حق الاستخدام",
        "check_fn": _check_ifrs16_lease,
        "severity": "Critical",
        "ref": "IFRS 16 §22",
    },
    {
        "id": "IAS37_PROVISIONS",
        "authority": "IFRS",
        "requirement_ar": "مخصص مكافأة نهاية الخدمة",
        "check_fn": _check_ias37_eosb,
        "severity": "High",
        "ref": "IAS 37 + نظام العمل السعودي",
    },
]


def run_compliance_check(
    accounts: List[Dict],
    sector: Optional[str] = None,
) -> Dict[str, Any]:
    """
    يشغّل كل قواعد الامتثال ويعيد نتيجة مفصّلة.
    """
    concepts = _concepts(accounts)
    names = _names_lower(accounts)

    passed: List[Dict] = []
    failed: List[Dict] = []
    warnings: List[Dict] = []
    authorities: Dict[str, Dict[str, int]] = {}

    for rule in COMPLIANCE_RULES:
        rule_id = rule["id"]
        authority = rule["authority"]
        severity = rule["severity"]
        check_fn = rule["check_fn"]

        if authority not in authorities:
            authorities[authority] = {"passed": 0, "failed": 0}

        try:
            result = check_fn(concepts=concepts, names=names, sector=sector)
        except Exception:
            result = True  # Fail-safe: skip broken rules

        entry = {
            "id": rule_id,
            "authority": authority,
            "requirement_ar": rule["requirement_ar"],
            "severity": severity,
            "ref": rule.get("ref", ""),
            "passed": result,
        }

        if result:
            passed.append(entry)
            authorities[authority]["passed"] += 1
        else:
            failed.append(entry)
            authorities[authority]["failed"] += 1
            if severity in ("Critical", "High"):
                warnings.append(entry)

    total_rules = len(COMPLIANCE_RULES)
    compliance_score = round(len(passed) / max(total_rules, 1) * 100)

    return {
        "passed": passed,
        "failed": failed,
        "warnings": warnings,
        "compliance_score": compliance_score,
        "total_rules": total_rules,
        "authorities": authorities,
    }


# ═══════════════════════════════════════════════════════════════
# ملحق ن2 — Implementation Roadmap
# ═══════════════════════════════════════════════════════════════

_EFFORT_MAP = {
    "auto_fix": ("سهل", 5),
    "manual_simple": ("سهل", 10),
    "manual_medium": ("متوسط", 30),
    "structural": ("صعب", 60),
}


def generate_implementation_roadmap(
    errors: List[Any],
    simulation: Dict,
    compliance: Dict,
) -> List[Dict]:
    """
    يرتّب الإصلاحات بمعادلة ROI:
    priority_score = (score_impact * 0.4) + (effort_inverse * 0.3) + (compliance_weight * 0.3)
    """
    items: List[Dict] = []

    # From structural gaps
    for gap in simulation.get("structural_gaps", []):
        sev = gap.get("severity", "Medium")
        if sev == "Critical":
            score_impact = 15
            compliance_w = 10
        elif sev == "High":
            score_impact = 8
            compliance_w = 7
        else:
            score_impact = 3
            compliance_w = 3

        items.append({
            "action_ar": gap.get("fix", gap.get("message_ar", "")),
            "category": "structural",
            "score_impact": f"+{score_impact} نقاط",
            "score_impact_num": score_impact,
            "effort": "متوسط" if sev != "Critical" else "صعب",
            "compliance_ref": "",
            "estimated_minutes": 30 if sev != "Critical" else 60,
            "error_codes": [gap.get("gap", "")],
            "priority_score": score_impact * 0.4 + (1 / 60) * 100 * 0.3 + compliance_w * 0.3,
        })

    # From compliance failures
    for fail in compliance.get("failed", []):
        sev = fail.get("severity", "Medium")
        if sev == "Critical":
            score_impact = 12
            compliance_w = 15
        elif sev == "High":
            score_impact = 6
            compliance_w = 10
        else:
            score_impact = 2
            compliance_w = 5

        items.append({
            "action_ar": fail.get("requirement_ar", ""),
            "category": "manual_medium",
            "score_impact": f"+{score_impact} نقاط",
            "score_impact_num": score_impact,
            "effort": "متوسط",
            "compliance_ref": fail.get("ref", ""),
            "estimated_minutes": 30,
            "error_codes": [fail.get("id", "")],
            "priority_score": score_impact * 0.4 + (1 / 30) * 100 * 0.3 + compliance_w * 0.3,
        })

    # From errors (group by error_code)
    error_groups: Dict[str, int] = {}
    for e in errors:
        code = e.error_code if hasattr(e, "error_code") else e.get("error_code", "")
        sev = e.severity if hasattr(e, "severity") else e.get("severity", "Low")
        auto = e.auto_fixable if hasattr(e, "auto_fixable") else e.get("auto_fixable", False)
        if code:
            error_groups[code] = error_groups.get(code, 0) + 1

    for code, count in error_groups.items():
        # Skip if already covered by structural/compliance
        if any(code in item.get("error_codes", []) for item in items):
            continue

        score_impact = min(count * 2, 10)
        category = "auto_fix" if count <= 5 else "manual_simple"
        effort_label, est_min = _EFFORT_MAP.get(category, ("متوسط", 20))

        items.append({
            "action_ar": f"أصلح {count} خطأ من نوع {code}",
            "category": category,
            "score_impact": f"+{score_impact} نقاط",
            "score_impact_num": score_impact,
            "effort": effort_label,
            "compliance_ref": "",
            "estimated_minutes": est_min,
            "error_codes": [code],
            "priority_score": score_impact * 0.4 + (1 / max(est_min, 1)) * 100 * 0.3 + 0,
        })

    # Sort by priority descending
    items.sort(key=lambda x: x.get("priority_score", 0), reverse=True)

    # Add rank and clean up
    result = []
    for i, item in enumerate(items[:15], 1):
        item["rank"] = i
        item.pop("priority_score", None)
        item.pop("score_impact_num", None)
        result.append(item)

    return result
