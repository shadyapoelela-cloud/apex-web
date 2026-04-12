"""
APEX COA Engine v4.2 — Financial Statement Simulator + Compliance (Wave 6)
Simulates financial statement structure from classified COA,
validates completeness for balance sheet, income statement, and
checks IFRS/SOCPA/ZATCA compliance requirements.
"""

import logging
from typing import Dict, List, Optional, Set

logger = logging.getLogger(__name__)


# Financial statement sections
BS_SECTIONS = {
    "current_assets": {"main_class": "asset", "sub_class": "current_asset", "nature": "debit"},
    "non_current_assets": {"main_class": "asset", "sub_class": "non_current_asset", "nature": "debit"},
    "current_liabilities": {"main_class": "liability", "sub_class": "current_liability", "nature": "credit"},
    "non_current_liabilities": {"main_class": "liability", "sub_class": "non_current_liability", "nature": "credit"},
    "equity": {"main_class": "equity", "sub_class": "equity", "nature": "credit"},
}

IS_SECTIONS = {
    "revenue": {"main_class": "revenue", "nature": "credit"},
    "cogs": {"main_class": "cogs", "nature": "debit"},
    "operating_expenses": {"main_class": "expense", "nature": "debit"},
    "finance_costs": {"main_class": "finance_cost", "nature": "debit"},
    "tax_expense": {"main_class": "expense", "sub_class": "tax_expense", "nature": "debit"},
}

# ZATCA/SOCPA compliance requirements
COMPLIANCE_RULES = [
    {
        "rule_id": "ZATCA_VAT",
        "name_ar": "حسابات ض.ق.م منفصلة",
        "name_en": "Separate VAT accounts",
        "authority": "ZATCA",
        "required_concepts": ["VAT"],
        "error_code": "E32",
        "severity": "High",
    },
    {
        "rule_id": "ZATCA_ZAKAT",
        "name_ar": "زكاة مستحقة للشركات السعودية",
        "name_en": "Zakat payable for Saudi companies",
        "authority": "ZATCA",
        "required_concepts": ["INCOME_TAX"],
        "error_code": "E34",
        "severity": "High",
    },
    {
        "rule_id": "IFRS9_ECL",
        "name_ar": "مخصص خسائر ائتمان متوقعة",
        "name_en": "Expected Credit Loss provision",
        "authority": "IFRS 9",
        "required_concepts": ["ECL_PROVISION"],
        "trigger_concepts": ["ACC_RECEIVABLE"],
        "error_code": "E28",
        "severity": "High",
    },
    {
        "rule_id": "IFRS16_LEASE",
        "name_ar": "أصول حق الاستخدام والتزامات الإيجار",
        "name_en": "Right-of-use assets and lease liabilities",
        "authority": "IFRS 16",
        "required_concepts": ["LEASE_LIABILITY"],
        "trigger_concepts": ["RENT_EXPENSE"],
        "error_code": "E27",
        "severity": "High",
    },
    {
        "rule_id": "IAS16_DEPRECIATION",
        "name_ar": "إهلاك الأصول الثابتة",
        "name_en": "Fixed asset depreciation",
        "authority": "IAS 16",
        "required_concepts": ["ACCUM_DEPRECIATION", "DEPRECIATION_EXP"],
        "trigger_concepts": ["PPE", "BUILDINGS", "EQUIPMENT", "VEHICLES", "FURNITURE"],
        "error_code": "E37",
        "severity": "High",
    },
    {
        "rule_id": "SAUDI_EOS",
        "name_ar": "مكافأة نهاية الخدمة",
        "name_en": "End of service benefits",
        "authority": "Saudi Labor Law",
        "required_concepts": ["END_OF_SERVICE"],
        "trigger_concepts": ["SALARIES_EXPENSE"],
        "error_code": "E38",
        "severity": "High",
    },
    {
        "rule_id": "ACCOUNTING_CYCLE",
        "name_ar": "اكتمال الدورة المحاسبية",
        "name_en": "Complete accounting cycle",
        "authority": "IASB Framework",
        "required_concepts": ["COGS"],
        "trigger_concepts": ["SALES_REVENUE"],
        "error_code": "E50",
        "severity": "Critical",
    },
    {
        "rule_id": "RETAINED_EARNINGS",
        "name_ar": "حساب أرباح مبقاة",
        "name_en": "Retained earnings account",
        "authority": "IAS 1",
        "required_concepts": ["RETAINED_EARNINGS"],
        "error_code": None,
        "severity": "Medium",
    },
    {
        "rule_id": "SHARE_CAPITAL",
        "name_ar": "حساب رأس المال",
        "name_en": "Share capital account",
        "authority": "نظام الشركات السعودي",
        "required_concepts": ["SHARE_CAPITAL"],
        "error_code": None,
        "severity": "Medium",
    },
]


def simulate_financial_statements(accounts: List[Dict]) -> Dict:
    """Simulate financial statement structure from classified accounts.

    Builds:
    1. Balance Sheet structure (5 sections)
    2. Income Statement structure (5 sections)
    3. Completeness checks for each section

    Args:
        accounts: Classified account list from the pipeline.

    Returns:
        Dict with balance_sheet, income_statement, completeness, issues.
    """
    concept_set: Set[str] = set()
    for acct in accounts:
        cid = acct.get("concept_id")
        if cid:
            concept_set.add(cid)

    # Build balance sheet
    balance_sheet = {}
    for section_name, criteria in BS_SECTIONS.items():
        section_accounts = [
            a for a in accounts
            if a.get("main_class") == criteria["main_class"]
            and (criteria.get("sub_class") is None or a.get("sub_class") == criteria.get("sub_class"))
        ]
        balance_sheet[section_name] = {
            "count": len(section_accounts),
            "accounts": [
                {"code": a.get("code", ""), "name": a.get("name", ""), "concept_id": a.get("concept_id")}
                for a in section_accounts[:20]  # Limit for API response size
            ],
        }

    # Build income statement
    income_statement = {}
    for section_name, criteria in IS_SECTIONS.items():
        section_accounts = [
            a for a in accounts
            if a.get("main_class") == criteria["main_class"]
            and (criteria.get("sub_class") is None or a.get("sub_class") == criteria.get("sub_class"))
        ]
        income_statement[section_name] = {
            "count": len(section_accounts),
            "accounts": [
                {"code": a.get("code", ""), "name": a.get("name", ""), "concept_id": a.get("concept_id")}
                for a in section_accounts[:20]
            ],
        }

    # Completeness issues
    issues = []
    total = len(accounts)

    # Check for missing main sections
    has_assets = any(a.get("main_class") == "asset" for a in accounts)
    has_liabilities = any(a.get("main_class") in ("liability", "equity") for a in accounts)
    has_revenue = any(a.get("main_class") == "revenue" for a in accounts)

    if not has_assets:
        issues.append({"issue": "MISSING_ASSETS", "severity": "Critical",
                        "description_ar": "لا توجد حسابات أصول في الشجرة"})
    if not has_liabilities:
        issues.append({"issue": "MISSING_LIABILITIES", "severity": "Critical",
                        "description_ar": "لا توجد حسابات خصوم أو ملكية"})
    if not has_revenue:
        issues.append({"issue": "MISSING_REVENUE", "severity": "Critical",
                        "description_ar": "لا توجد حسابات إيرادات"})
    if has_revenue and not any(a.get("main_class") == "cogs" for a in accounts):
        issues.append({"issue": "MISSING_COGS", "severity": "High",
                        "description_ar": "إيرادات موجودة بدون تكلفة مبيعات — E50"})
    if not any(a.get("main_class") == "equity" for a in accounts):
        issues.append({"issue": "MISSING_EQUITY", "severity": "High",
                        "description_ar": "لا توجد حسابات حقوق ملكية"})
    if "SHARE_CAPITAL" not in concept_set and has_liabilities:
        issues.append({"issue": "MISSING_CAPITAL", "severity": "High",
                        "description_ar": "لا يوجد حساب رأس مال في حقوق الملكية"})

    # Calculate completeness score
    bs_sections_present = sum(1 for s in balance_sheet.values() if s["count"] > 0)
    is_sections_present = sum(1 for s in income_statement.values() if s["count"] > 0)
    completeness_score = (
        (bs_sections_present / len(BS_SECTIONS) * 60) +
        (is_sections_present / len(IS_SECTIONS) * 40)
    )

    return {
        "balance_sheet": balance_sheet,
        "income_statement": income_statement,
        "completeness_score": round(completeness_score, 2),
        "issues": issues,
        "total_accounts": total,
        "bs_sections_filled": bs_sections_present,
        "is_sections_filled": is_sections_present,
    }


def check_compliance(accounts: List[Dict], sector_code: str = None) -> Dict:
    """Check COA compliance against IFRS/SOCPA/ZATCA requirements.

    Args:
        accounts: Classified account list.
        sector_code: Optional sector code for sector-specific checks.

    Returns:
        Dict with: rules_checked, passed, failed, compliance_score, details.
    """
    concept_set: Set[str] = set()
    for acct in accounts:
        cid = acct.get("concept_id")
        if cid:
            concept_set.add(cid)

    results = []
    passed = 0
    failed = 0

    for rule in COMPLIANCE_RULES:
        # Check if trigger concepts are present (if applicable)
        trigger_concepts = rule.get("trigger_concepts", [])
        if trigger_concepts:
            has_trigger = any(tc in concept_set for tc in trigger_concepts)
            if not has_trigger:
                # Rule not applicable — no trigger present
                results.append({
                    "rule_id": rule["rule_id"],
                    "name_ar": rule["name_ar"],
                    "name_en": rule["name_en"],
                    "authority": rule["authority"],
                    "status": "not_applicable",
                    "description_ar": "غير مطبق — لا توجد حسابات تُشغِّل هذا الفحص",
                })
                continue

        # Check if required concepts are present
        required = rule["required_concepts"]
        present = [c for c in required if c in concept_set]
        missing = [c for c in required if c not in concept_set]

        if not missing:
            passed += 1
            results.append({
                "rule_id": rule["rule_id"],
                "name_ar": rule["name_ar"],
                "name_en": rule["name_en"],
                "authority": rule["authority"],
                "status": "passed",
                "description_ar": "متوافق",
            })
        else:
            failed += 1
            results.append({
                "rule_id": rule["rule_id"],
                "name_ar": rule["name_ar"],
                "name_en": rule["name_en"],
                "authority": rule["authority"],
                "status": "failed",
                "severity": rule["severity"],
                "error_code": rule.get("error_code"),
                "missing_concepts": missing,
                "description_ar": f"غير متوافق — مفقود: {', '.join(missing)}",
            })

    total_applicable = passed + failed
    compliance_score = (passed / total_applicable * 100) if total_applicable else 100.0

    return {
        "rules_checked": len(results),
        "applicable": total_applicable,
        "passed": passed,
        "failed": failed,
        "compliance_score": round(compliance_score, 2),
        "details": results,
    }
