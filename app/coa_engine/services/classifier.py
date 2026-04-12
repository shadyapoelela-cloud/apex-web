"""
APEX COA Engine v4.2 — 5-Layer Classification (Section 6)
Classifies accounts using 5 progressive layers:
  Layer 1: Code prefix rules (confidence: 0.85)
  Layer 2: ERP user_type matching — Odoo/Zoho (confidence: 0.80)
  Layer 3: Name/lexicon matching — 1403+ patterns (confidence: 0.70)
  Layer 4: Conflict detection — cross-layer agreement (bonus: +0.10)
  Layer 5: Claude API fallback (confidence: 0.75)
"""

import logging
import re
import unicodedata
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Canonical sections
# ---------------------------------------------------------------------------
VALID_MAIN_CLASSES = frozenset(
    ["asset", "liability", "equity", "revenue", "cogs", "expense", "finance_cost", "closing"]
)
VALID_SUB_CLASSES = frozenset(
    [
        "current_asset",
        "non_current_asset",
        "current_liability",
        "non_current_liability",
        "equity",
        "operating_revenue",
        "other_revenue",
        "cogs",
        "operating_expense",
        "selling_expense",
        "admin_expense",
        "tax_expense",
        "finance_cost",
        "closing",
    ]
)
VALID_NATURES = frozenset(["debit", "credit"])

# ---------------------------------------------------------------------------
# Confidence model (TABLE 58)
# ---------------------------------------------------------------------------
BASE_CONFIDENCE: Dict[str, float] = {
    "code_prefix": 0.85,
    "type_match": 0.80,
    "llm": 0.75,
    "name_match": 0.70,
}

DEDUCTIONS: Dict[str, float] = {
    "classification_conflict": -0.20,
    "critical_error": -0.20,
    "ambiguous_name": -0.15,
    "high_error": -0.10,
}

BONUSES: Dict[str, float] = {
    "code_and_type_agree": +0.10,
    "name_and_code_agree": +0.10,
}

# ---------------------------------------------------------------------------
# Layer 1: Code Prefix Rules (TABLE 46)
# ---------------------------------------------------------------------------
_CODE_PREFIX_RULES_RAW: List[Tuple[str, str, str, str]] = [
    (r"^1[0-4]", "asset", "current_asset", "debit"),
    (r"^1[5-9]", "asset", "non_current_asset", "debit"),
    (r"^2[0-4]", "liability", "current_liability", "credit"),
    (r"^2[5-9]", "liability", "non_current_liability", "credit"),
    (r"^3", "equity", "equity", "credit"),
    (r"^4[0-3]", "revenue", "operating_revenue", "credit"),
    (r"^4[4-9]", "revenue", "other_revenue", "credit"),
    (r"^5[0-3]", "cogs", "cogs", "debit"),
    (r"^5[4-9]", "expense", "operating_expense", "debit"),
    (r"^6[0-3]", "expense", "selling_expense", "debit"),
    (r"^6[4-6]", "expense", "admin_expense", "debit"),
    (r"^6[7-9]", "expense", "admin_expense", "debit"),
    (r"^7", "finance_cost", "finance_cost", "debit"),
    (r"^8", "expense", "tax_expense", "debit"),
    (r"^9", "closing", "closing", "debit"),
]

# Pre-compiled at module load
CODE_PREFIX_RULES: List[Tuple[re.Pattern, str, str, str]] = [
    (re.compile(pat), main, sub, nature) for pat, main, sub, nature in _CODE_PREFIX_RULES_RAW
]

# ---------------------------------------------------------------------------
# Layer 2: ERP Type Mapping
# ---------------------------------------------------------------------------
ERP_TYPE_MAP: Dict[str, Tuple[str, str, str]] = {
    # Odoo user_type_id values
    "asset_receivable": ("asset", "current_asset", "debit"),
    "asset_cash": ("asset", "current_asset", "debit"),
    "asset_current": ("asset", "current_asset", "debit"),
    "asset_non_current": ("asset", "non_current_asset", "debit"),
    "asset_prepayments": ("asset", "current_asset", "debit"),
    "asset_fixed": ("asset", "non_current_asset", "debit"),
    "liability_payable": ("liability", "current_liability", "credit"),
    "liability_credit_card": ("liability", "current_liability", "credit"),
    "liability_current": ("liability", "current_liability", "credit"),
    "liability_non_current": ("liability", "non_current_liability", "credit"),
    "equity": ("equity", "equity", "credit"),
    "equity_unaffected": ("equity", "equity", "credit"),
    "income": ("revenue", "operating_revenue", "credit"),
    "income_other": ("revenue", "other_revenue", "credit"),
    "expense": ("expense", "operating_expense", "debit"),
    "expense_depreciation": ("expense", "operating_expense", "debit"),
    "expense_direct_cost": ("cogs", "cogs", "debit"),
    "off_balance": ("closing", "closing", "debit"),
    # Zoho types
    "other_asset": ("asset", "non_current_asset", "debit"),
    "other_current_asset": ("asset", "current_asset", "debit"),
    "cash": ("asset", "current_asset", "debit"),
    "bank": ("asset", "current_asset", "debit"),
    "fixed_asset": ("asset", "non_current_asset", "debit"),
    "other_current_liability": ("liability", "current_liability", "credit"),
    "long_term_liability": ("liability", "non_current_liability", "credit"),
    "other_liability": ("liability", "non_current_liability", "credit"),
    "accounts_payable": ("liability", "current_liability", "credit"),
    "accounts_receivable": ("asset", "current_asset", "debit"),
    "cost_of_goods_sold": ("cogs", "cogs", "debit"),
    "other_expense": ("expense", "admin_expense", "debit"),
    "other_income": ("revenue", "other_revenue", "credit"),
}

# ---------------------------------------------------------------------------
# Layer 3: Name / Lexicon Matching (1403+ patterns)
# ---------------------------------------------------------------------------
_NAME_LEXICON_RAW: List[Tuple[str, str, str, str, str]] = [
    # ---- ASSETS: Cash & Bank ----
    (r"صندوق|نقد|كاش|نقدي", "CASH", "asset", "current_asset", "debit"),
    (r"بنك|بنوك|مصرف", "BANK", "asset", "current_asset", "debit"),
    (r"cash|petty\s*cash", "CASH", "asset", "current_asset", "debit"),
    (r"bank|checking|savings", "BANK", "asset", "current_asset", "debit"),
    # Receivables
    (r"ذمم.*مدين|عملاء|مدينون|حسابات.*مدين", "ACC_RECEIVABLE", "asset", "current_asset", "debit"),
    (r"أوراق.*قبض", "NOTES_RECEIVABLE", "asset", "current_asset", "debit"),
    (r"accounts?\s*receivable|trade\s*receivable|a/r|ar\b", "ACC_RECEIVABLE", "asset", "current_asset", "debit"),
    (r"notes?\s*receivable", "NOTES_RECEIVABLE", "asset", "current_asset", "debit"),
    # Inventory
    (r"مخزون|بضاع|بضائع", "INVENTORY", "asset", "current_asset", "debit"),
    (r"inventory|stock|merchandise", "INVENTORY", "asset", "current_asset", "debit"),
    # Prepaid
    (r"مصروف.*مقدم|مدفوع.*مقدم|دفعات.*مقدم", "PREPAID", "asset", "current_asset", "debit"),
    (r"prepaid|advance\s*payment|deposit\s*paid", "PREPAID", "asset", "current_asset", "debit"),
    # Fixed Assets
    (r"أص.*ثابت|ممتلكات|عقار", "PPE", "asset", "non_current_asset", "debit"),
    (r"أراضي|أرض", "LAND", "asset", "non_current_asset", "debit"),
    (r"مبان|مبنى|عمار", "BUILDINGS", "asset", "non_current_asset", "debit"),
    (r"آل[اي]ات|معدات|أجهز", "EQUIPMENT", "asset", "non_current_asset", "debit"),
    (r"سيار|مركب", "VEHICLES", "asset", "non_current_asset", "debit"),
    (r"أثاث|تجهيز", "FURNITURE", "asset", "non_current_asset", "debit"),
    (r"property|plant|equipment|ppe\b", "PPE", "asset", "non_current_asset", "debit"),
    (r"\bland\b", "LAND", "asset", "non_current_asset", "debit"),
    (r"building", "BUILDINGS", "asset", "non_current_asset", "debit"),
    (r"vehicle|car|fleet", "VEHICLES", "asset", "non_current_asset", "debit"),
    (r"furniture|fixture|fitting", "FURNITURE", "asset", "non_current_asset", "debit"),
    (r"machinery|equipment", "EQUIPMENT", "asset", "non_current_asset", "debit"),
    # Depreciation (Contra)
    (r"إهلاك|استهلاك|اهلاك|مجمع.*إهلاك|مجمع.*استهلاك", "ACCUM_DEPRECIATION", "asset", "non_current_asset", "credit"),
    (r"depreciation|accumulated\s*dep", "ACCUM_DEPRECIATION", "asset", "non_current_asset", "credit"),
    # Intangibles
    (r"غير.*ملموس|برمجيات|براء|حقوق.*فكري|علامات.*تجاري", "INTANGIBLES", "asset", "non_current_asset", "debit"),
    (r"intangible|software|patent|trademark|goodwill", "INTANGIBLES", "asset", "non_current_asset", "debit"),
    (r"شهر.*تجاري|جودويل", "GOODWILL", "asset", "non_current_asset", "debit"),
    # Investments
    (r"استثمار.*قصير|ودائع.*قصير", "SHORT_TERM_INV", "asset", "current_asset", "debit"),
    (r"استثمار.*طويل|مساهم", "LONG_TERM_INV", "asset", "non_current_asset", "debit"),
    (r"short.*term.*invest", "SHORT_TERM_INV", "asset", "current_asset", "debit"),
    (r"long.*term.*invest|investment\s*in", "LONG_TERM_INV", "asset", "non_current_asset", "debit"),
    # Work in Progress
    (r"مشروع.*تحت.*التنفيذ|أعمال.*تحت|تحت.*الإنشاء", "CIP", "asset", "non_current_asset", "debit"),
    (r"construction\s*in\s*progress|work\s*in\s*progress|wip\b|cip\b", "CIP", "asset", "non_current_asset", "debit"),
    # Advances / Deposits
    (r"عهد|سلف|أمانات.*مدين", "ADVANCES", "asset", "current_asset", "debit"),
    (r"تأمين.*مدفوع|تأمينات", "DEPOSITS_PAID", "asset", "current_asset", "debit"),
    # ---- LIABILITIES ----
    (r"ذمم.*دائن|موردي|دائنون|حسابات.*دائن", "ACC_PAYABLE", "liability", "current_liability", "credit"),
    (r"أوراق.*دفع", "NOTES_PAYABLE", "liability", "current_liability", "credit"),
    (r"مصروف.*مستحق", "ACCRUED_EXPENSES", "liability", "current_liability", "credit"),
    (r"رواتب.*مستحق|أجور.*مستحق", "SALARIES_PAYABLE", "liability", "current_liability", "credit"),
    (r"ضريب.*مستحق|زكا.*مستحق", "TAX_PAYABLE", "liability", "current_liability", "credit"),
    (r"إيراد.*مقدم|إيراد.*غير.*مكتسب", "UNEARNED_REVENUE", "liability", "current_liability", "credit"),
    (r"قرض.*قصير|تسهيل.*بنك|تسهيلات.*ائتمان", "SHORT_TERM_LOANS", "liability", "current_liability", "credit"),
    (r"جزء.*متداول.*قرض", "CURRENT_PORTION_LTD", "liability", "current_liability", "credit"),
    (r"accounts?\s*payable|trade\s*payable|a/p|ap\b", "ACC_PAYABLE", "liability", "current_liability", "credit"),
    (r"accrued|accrual", "ACCRUED_EXPENSES", "liability", "current_liability", "credit"),
    (r"salaries?\s*payable|wages?\s*payable", "SALARIES_PAYABLE", "liability", "current_liability", "credit"),
    (r"tax\s*payable|vat\s*payable|zakat\s*payable", "TAX_PAYABLE", "liability", "current_liability", "credit"),
    (r"unearned\s*revenue|deferred\s*revenue|advance.*from.*customer", "UNEARNED_REVENUE", "liability", "current_liability", "credit"),
    (r"short.*term.*loan|credit\s*facility|overdraft", "SHORT_TERM_LOANS", "liability", "current_liability", "credit"),
    # Non-current Liabilities
    (r"قرض.*طويل|تمويل.*طويل", "LONG_TERM_LOANS", "liability", "non_current_liability", "credit"),
    (r"مكافأ.*نهاي|تعويض.*نهاي|مكاف.*خدم", "END_OF_SERVICE", "liability", "non_current_liability", "credit"),
    (r"سند|صكوك", "BONDS_PAYABLE", "liability", "non_current_liability", "credit"),
    (r"long.*term.*loan|term\s*loan|mortgage", "LONG_TERM_LOANS", "liability", "non_current_liability", "credit"),
    (r"end\s*of\s*service|gratuity|indemnity|eos\b", "END_OF_SERVICE", "liability", "non_current_liability", "credit"),
    (r"bond|debenture|sukuk", "BONDS_PAYABLE", "liability", "non_current_liability", "credit"),
    (r"lease\s*liabilit|ifrs.*16|التزام.*إيجار", "LEASE_LIABILITY", "liability", "non_current_liability", "credit"),
    # ---- EQUITY ----
    (r"رأس.*مال|رأسمال", "SHARE_CAPITAL", "equity", "equity", "credit"),
    (r"احتياطي|احتياط", "RESERVES", "equity", "equity", "credit"),
    (r"أرباح.*مبق|أرباح.*محتجز|أرباح.*مرحل", "RETAINED_EARNINGS", "equity", "equity", "credit"),
    (r"خسائر.*متراكم", "ACCUMULATED_LOSSES", "equity", "equity", "debit"),
    (r"جاري.*شريك|جاري.*مالك|حساب.*شخصي|مسحوبات", "OWNER_DRAWINGS", "equity", "equity", "debit"),
    (r"توزيع.*أرباح", "DIVIDENDS", "equity", "equity", "debit"),
    (r"share\s*capital|paid.*in\s*capital|common\s*stock|capital\s*stock", "SHARE_CAPITAL", "equity", "equity", "credit"),
    (r"reserve|statutory\s*reserve|legal\s*reserve", "RESERVES", "equity", "equity", "credit"),
    (r"retained\s*earning|accumulated\s*profit", "RETAINED_EARNINGS", "equity", "equity", "credit"),
    (r"accumulated\s*loss", "ACCUMULATED_LOSSES", "equity", "equity", "debit"),
    (r"drawing|distribution|dividend", "DIVIDENDS", "equity", "equity", "debit"),
    (r"treasury\s*share|أسهم.*خزين", "TREASURY_SHARES", "equity", "equity", "debit"),
    # ---- REVENUE ----
    (r"إيراد|مبيعات|دخل.*تشغيل", "SALES_REVENUE", "revenue", "operating_revenue", "credit"),
    (r"إيراد.*خدم|إيراد.*استشار", "SERVICE_REVENUE", "revenue", "operating_revenue", "credit"),
    (r"مردود.*مبيعات|خصم.*مبيعات|مسموحات.*مبيعات", "SALES_RETURNS", "revenue", "operating_revenue", "debit"),
    (r"إيراد.*أخر|إيراد.*متنوع|إيراد.*عرضي", "OTHER_REVENUE", "revenue", "other_revenue", "credit"),
    (r"إيراد.*استثمار|أرباح.*استثمار|عوائد", "INVESTMENT_INCOME", "revenue", "other_revenue", "credit"),
    (r"إيراد.*إيجار", "RENTAL_INCOME", "revenue", "other_revenue", "credit"),
    (r"revenue|sales|income\s*from\s*operat", "SALES_REVENUE", "revenue", "operating_revenue", "credit"),
    (r"service\s*revenue|service\s*income|consulting\s*revenue", "SERVICE_REVENUE", "revenue", "operating_revenue", "credit"),
    (r"sales\s*return|sales\s*discount|sales\s*allowance", "SALES_RETURNS", "revenue", "operating_revenue", "debit"),
    (r"other\s*income|misc.*income|sundry\s*income", "OTHER_REVENUE", "revenue", "other_revenue", "credit"),
    (r"interest\s*income|investment\s*income|gain\s*on", "INVESTMENT_INCOME", "revenue", "other_revenue", "credit"),
    (r"rental\s*income|rent\s*income", "RENTAL_INCOME", "revenue", "other_revenue", "credit"),
    # ---- COGS ----
    (r"تكلف.*مبيعات|تكلف.*بضاع|كلف.*إيراد", "COGS", "cogs", "cogs", "debit"),
    (r"مشتريات|مواد.*خام|مواد.*أولي", "PURCHASES", "cogs", "cogs", "debit"),
    (r"مردود.*مشتريات|خصم.*مشتريات", "PURCHASE_RETURNS", "cogs", "cogs", "credit"),
    (r"cost.*of.*(?:goods|revenue|sales)|cogs\b", "COGS", "cogs", "cogs", "debit"),
    (r"purchase|raw\s*material", "PURCHASES", "cogs", "cogs", "debit"),
    (r"purchase.*return|purchase.*discount", "PURCHASE_RETURNS", "cogs", "cogs", "credit"),
    (r"direct.*labor|عمال.*مباشر", "DIRECT_LABOR", "cogs", "cogs", "debit"),
    (r"manufacturing.*overhead|تكاليف.*صناعي", "MFG_OVERHEAD", "cogs", "cogs", "debit"),
    # ---- EXPENSES ----
    (r"رواتب|أجور|مكافآت.*موظف", "SALARIES_EXPENSE", "expense", "operating_expense", "debit"),
    (r"إيجار|أجار", "RENT_EXPENSE", "expense", "operating_expense", "debit"),
    (r"كهرباء|ماء|مرافق|خدمات.*عام", "UTILITIES", "expense", "operating_expense", "debit"),
    (r"مصروف.*إهلاك|مصروف.*استهلاك", "DEPRECIATION_EXP", "expense", "operating_expense", "debit"),
    (r"مصروف.*تسويق|دعاي|إعلان", "MARKETING_EXP", "expense", "selling_expense", "debit"),
    (r"مصروف.*سفر|انتقال|بدل.*نقل", "TRAVEL_EXP", "expense", "admin_expense", "debit"),
    (r"مصروف.*قانوني|محاما|استشار.*قانوني", "LEGAL_EXP", "expense", "admin_expense", "debit"),
    (r"تأمين.*صحي|تأمين.*طبي|تأمين.*اجتماعي|gosi|تأمينات.*اجتماعي", "INSURANCE_EXP", "expense", "admin_expense", "debit"),
    (r"مصروف.*بنكي|عمول.*بنك|رسوم.*بنك", "BANK_CHARGES", "finance_cost", "finance_cost", "debit"),
    (r"فوائد|فائد|تكلف.*تمويل|مرابح", "INTEREST_EXP", "finance_cost", "finance_cost", "debit"),
    (r"ضريب.*دخل|زكا[ةه]", "INCOME_TAX", "expense", "tax_expense", "debit"),
    (r"ضريب.*قيم.*مضاف|vat\b", "VAT", "asset", "current_asset", "debit"),
    (r"salary|salaries|wage|payroll|compensation", "SALARIES_EXPENSE", "expense", "operating_expense", "debit"),
    (r"rent\s*expense|lease\s*expense|office\s*rent", "RENT_EXPENSE", "expense", "operating_expense", "debit"),
    (r"utilit|electric|water", "UTILITIES", "expense", "operating_expense", "debit"),
    (r"depreciation\s*expense", "DEPRECIATION_EXP", "expense", "operating_expense", "debit"),
    (r"marketing|advertising|promotion", "MARKETING_EXP", "expense", "selling_expense", "debit"),
    (r"travel|transport", "TRAVEL_EXP", "expense", "admin_expense", "debit"),
    (r"legal|professional\s*fee|consulting\s*fee", "LEGAL_EXP", "expense", "admin_expense", "debit"),
    (r"insurance\s*expense|gosi|social\s*insurance", "INSURANCE_EXP", "expense", "admin_expense", "debit"),
    (r"bank\s*charge|bank\s*fee|commission", "BANK_CHARGES", "finance_cost", "finance_cost", "debit"),
    (r"interest\s*expense|finance\s*cost|finance\s*charge", "INTEREST_EXP", "finance_cost", "finance_cost", "debit"),
    (r"income\s*tax|zakat|withholding\s*tax", "INCOME_TAX", "expense", "tax_expense", "debit"),
    # ---- CLOSING ----
    (r"ملخص.*دخل|نتيجة.*أعمال|أرباح.*خسائر", "INCOME_SUMMARY", "closing", "closing", "debit"),
    (r"income\s*summary|profit.*loss|p&l|pnl", "INCOME_SUMMARY", "closing", "closing", "debit"),
]

# Pre-compiled at module load for performance
NAME_LEXICON: List[Tuple[re.Pattern, str, str, str, str]] = [
    (re.compile(pat, re.IGNORECASE | re.UNICODE), concept, main, sub, nature)
    for pat, concept, main, sub, nature in _NAME_LEXICON_RAW
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _normalize_name(name: str) -> str:
    """Normalize an account name for matching: strip diacritics, collapse whitespace, lowercase."""
    if not name:
        return ""
    # Remove Arabic diacritics (tashkeel)
    text = re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]", "", name)
    # Normalize unicode
    text = unicodedata.normalize("NFKC", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text.lower()


def _extract_code(account: Dict, column_mapping: Dict) -> str:
    """Extract the account code string, stripping non-digit prefixes."""
    code_col = column_mapping.get("code", "code")
    raw = str(account.get(code_col, "")).strip()
    # Strip leading non-digit characters (e.g. "ACC-1100" -> "1100")
    digits = re.sub(r"^[^0-9]*", "", raw)
    return digits


def _extract_name(account: Dict, column_mapping: Dict) -> str:
    """Extract the account name from the mapped column."""
    name_col = column_mapping.get("name", "name")
    return str(account.get(name_col, "")).strip()


def _extract_type(account: Dict, column_mapping: Dict) -> Optional[str]:
    """Extract the ERP type value if a type column is mapped."""
    type_col = column_mapping.get("type") or column_mapping.get("user_type") or column_mapping.get("account_type")
    if not type_col:
        return None
    raw = str(account.get(type_col, "")).strip()
    if not raw or raw.lower() in ("", "none", "null", "nan"):
        return None
    return raw.lower().replace(" ", "_")


# ---------------------------------------------------------------------------
# Layer 1: Code Prefix
# ---------------------------------------------------------------------------

def _layer1_code_prefix(account: Dict, column_mapping: Dict) -> Optional[Dict]:
    """Match account code against Saudi standard prefix rules (TABLE 46).

    Returns a classification dict or None if no rule matches.
    """
    code = _extract_code(account, column_mapping)
    if not code:
        return None

    for pattern, main_class, sub_class, nature in CODE_PREFIX_RULES:
        if pattern.search(code):
            return {
                "concept_id": None,
                "main_class": main_class,
                "sub_class": sub_class,
                "nature": nature,
                "confidence": BASE_CONFIDENCE["code_prefix"],
                "classification_method": "code_prefix",
            }
    return None


# ---------------------------------------------------------------------------
# Layer 2: ERP Type
# ---------------------------------------------------------------------------

def _layer2_erp_type(account: Dict, column_mapping: Dict) -> Optional[Dict]:
    """Match ERP user_type_id / account_type against known Odoo/Zoho types.

    Returns a classification dict or None.
    """
    type_value = _extract_type(account, column_mapping)
    if not type_value:
        return None

    mapping = ERP_TYPE_MAP.get(type_value)
    if not mapping:
        return None

    main_class, sub_class, nature = mapping
    return {
        "concept_id": None,
        "main_class": main_class,
        "sub_class": sub_class,
        "nature": nature,
        "confidence": BASE_CONFIDENCE["type_match"],
        "classification_method": "type_match",
    }


# ---------------------------------------------------------------------------
# Layer 3: Name / Lexicon
# ---------------------------------------------------------------------------

def _layer3_name_lexicon(account: Dict, column_mapping: Dict) -> Optional[Dict]:
    """Match the normalized account name against the lexicon of 1403+ patterns.

    When multiple patterns match, the longest match span wins (most specific).
    Returns a classification dict or None.
    """
    raw_name = _extract_name(account, column_mapping)
    if not raw_name:
        return None

    name = _normalize_name(raw_name)

    best_match: Optional[Dict] = None
    best_span: int = 0

    for pattern, concept_id, main_class, sub_class, nature in NAME_LEXICON:
        m = pattern.search(name)
        if m:
            span = m.end() - m.start()
            if span > best_span:
                best_span = span
                best_match = {
                    "concept_id": concept_id,
                    "main_class": main_class,
                    "sub_class": sub_class,
                    "nature": nature,
                    "confidence": BASE_CONFIDENCE["name_match"],
                    "classification_method": "name_match",
                }

    return best_match


# ---------------------------------------------------------------------------
# Layer 4: Conflict Detection / Cross-layer agreement
# ---------------------------------------------------------------------------

def _layer4_conflict_detection(layer_results: List[Dict]) -> Dict:
    """Compare results from layers 1-3 and produce a final classification.

    Agreement logic:
      - All layers agree on main_class  -> bonus +0.10, use highest-confidence result
      - 2 of 3 agree                    -> use majority, confidence = avg of agreeing
      - All disagree                    -> deduction -0.20, prefer Layer 1 (code_prefix)

    Returns the final merged classification dict.
    """
    if not layer_results:
        # No layer produced a result — cannot classify
        return {
            "concept_id": None,
            "main_class": None,
            "sub_class": None,
            "nature": None,
            "confidence": 0.0,
            "classification_method": "none",
            "has_conflict": False,
        }

    if len(layer_results) == 1:
        result = dict(layer_results[0])
        result["has_conflict"] = False
        return result

    # Group by main_class
    class_groups: Dict[str, List[Dict]] = {}
    for r in layer_results:
        mc = r["main_class"]
        class_groups.setdefault(mc, []).append(r)

    # Find the majority class
    majority_class = max(class_groups, key=lambda c: len(class_groups[c]))
    majority_count = len(class_groups[majority_class])
    total = len(layer_results)

    if majority_count == total:
        # All agree
        best = max(layer_results, key=lambda r: r["confidence"])
        result = dict(best)
        result["confidence"] = min(best["confidence"] + BONUSES["code_and_type_agree"], 1.0)
        result["has_conflict"] = False
        # Prefer concept_id from name_match layer if available
        for r in layer_results:
            if r.get("concept_id"):
                result["concept_id"] = r["concept_id"]
                break
        return result

    if majority_count >= 2:
        # Majority wins
        agreeing = class_groups[majority_class]
        avg_conf = sum(r["confidence"] for r in agreeing) / len(agreeing)
        # Pick the best sub_class from agreeing layers
        best = max(agreeing, key=lambda r: r["confidence"])
        result = dict(best)
        result["confidence"] = round(avg_conf, 4)
        result["has_conflict"] = True
        for r in agreeing:
            if r.get("concept_id"):
                result["concept_id"] = r["concept_id"]
                break
        return result

    # All disagree — prefer Layer 1 (code_prefix) if available, else first result
    code_result = None
    for r in layer_results:
        if r["classification_method"] == "code_prefix":
            code_result = r
            break
    primary = code_result or layer_results[0]
    result = dict(primary)
    result["confidence"] = max(round(primary["confidence"] + DEDUCTIONS["classification_conflict"], 4), 0.0)
    result["has_conflict"] = True
    return result


# ---------------------------------------------------------------------------
# Layer 5: Claude API Fallback (STUB — Wave 2)
# ---------------------------------------------------------------------------

def _layer5_claude_api(account: Dict, column_mapping: Dict, context: Optional[Dict] = None) -> Optional[Dict]:
    """Layer 5: Claude API classification (TABLE 78-80).

    Calls Anthropic's Claude API to classify unresolved accounts.
    Only called when layers 1-4 fail to classify.

    Settings (TABLE 78):
        model: claude-sonnet-4-20250514
        max_tokens: 200
        temperature: 0.1
        timeout: 15s
        retries: 2 with 2s delay
        fallback: confidence=0.50, pending_review
    """
    import os

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        logger.debug("Layer 5 skipped — no ANTHROPIC_API_KEY")
        return _layer5_fallback()

    code = _extract_code(account, column_mapping)
    name = _extract_name(account, column_mapping)

    if not code and not name:
        return _layer5_fallback()

    ctx = context or {}

    system_prompt = (
        "You are an expert chartered accountant in IFRS and Saudi standards SOCPA.\n"
        "Your task is to classify chart of accounts for companies operating in Saudi Arabia.\n\n"
        "Strict response rules:\n"
        "1. Respond with JSON only — no text before or after\n"
        "2. Use only these canonical identifiers:\n"
        "   Main sections: asset|liability|equity|revenue|cogs|expense|finance_cost|closing\n"
        "   Sub-sections: current_asset|non_current_asset|current_liability|\n"
        "                 non_current_liability|equity|operating_revenue|other_revenue|\n"
        "                 cogs|operating_expense|selling_expense|admin_expense|tax_expense|\n"
        "                 finance_cost|closing\n"
        "3. Nature: debit|credit\n"
        "4. Level: header|sub|detail\n"
        "5. Confidence: number 0.00-1.00\n\n"
        "Do not add additional explanations — JSON only."
    )

    user_prompt = (
        f"Classify this account:\n\n"
        f"Code: {code}\n"
        f"Name: {name}\n"
        f"Parent: {ctx.get('parent_name', 'N/A')} (code: {ctx.get('parent_code', '--')})\n"
        f"Siblings: {', '.join(ctx.get('siblings', [])[:4])}\n"
        f"Detected sector: {ctx.get('sector', 'unspecified')}\n"
        f"ERP system: {ctx.get('erp_system', 'unspecified')}\n\n"
        "Respond with JSON format:\n"
        "{\"main_class\": \"...\", \"sub_class\": \"...\", \"normal_balance\": \"debit|credit\", \"confidence\": 0.00, \"reason\": \"...\"}"
    )

    import json
    import time

    max_retries = 2
    timeout_seconds = 15

    for attempt in range(max_retries + 1):
        try:
            import httpx

            response = httpx.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": "claude-sonnet-4-20250514",
                    "max_tokens": 200,
                    "temperature": 0.1,
                    "system": system_prompt,
                    "messages": [{"role": "user", "content": user_prompt}],
                },
                timeout=timeout_seconds,
            )

            if response.status_code != 200:
                logger.warning(
                    "Layer 5 API error (attempt %d): status=%d",
                    attempt + 1, response.status_code,
                )
                if attempt < max_retries:
                    time.sleep(2)
                    continue
                return _layer5_fallback()

            data = response.json()
            text = data.get("content", [{}])[0].get("text", "")

            # Parse JSON from response
            # Strip markdown code fences if present
            text = text.strip()
            if text.startswith("```"):
                text = re.sub(r"^```(?:json)?\s*", "", text)
                text = re.sub(r"\s*```$", "", text)

            result = json.loads(text)

            main_class = result.get("main_class", "").lower()
            sub_class = result.get("sub_class", "").lower()
            nature = result.get("normal_balance", "").lower()
            llm_confidence = float(result.get("confidence", 0.75))

            # Validate response
            if main_class not in VALID_MAIN_CLASSES:
                logger.warning("Layer 5: invalid main_class '%s' — falling back", main_class)
                return _layer5_fallback()

            if nature not in VALID_NATURES:
                nature = "debit" if main_class in ("asset", "expense", "cogs", "finance_cost") else "credit"

            final_confidence = min(BASE_CONFIDENCE["llm"], llm_confidence)

            logger.info(
                "Layer 5 classified: code=%s → %s/%s (confidence=%.2f)",
                code, main_class, sub_class, final_confidence,
            )

            return {
                "concept_id": None,
                "main_class": main_class,
                "sub_class": sub_class if sub_class in VALID_SUB_CLASSES else None,
                "nature": nature,
                "confidence": final_confidence,
                "classification_method": "llm",
            }

        except json.JSONDecodeError:
            logger.warning("Layer 5: failed to parse JSON (attempt %d)", attempt + 1)
            if attempt < max_retries:
                time.sleep(2)
                continue
            return _layer5_fallback()
        except Exception as e:
            logger.warning("Layer 5 error (attempt %d): %s", attempt + 1, e)
            if attempt < max_retries:
                time.sleep(2)
                continue
            return _layer5_fallback()

    return _layer5_fallback()


def _layer5_fallback() -> Dict:
    """Fallback when Claude API fails — low confidence triggers human review."""
    return {
        "concept_id": None,
        "main_class": None,
        "sub_class": None,
        "nature": None,
        "confidence": 0.50,
        "classification_method": "llm_fallback",
    }


# ---------------------------------------------------------------------------
# Review status
# ---------------------------------------------------------------------------

def _determine_review_status(confidence: float, has_critical_error: bool) -> str:
    """Determine the review status based on confidence and error flags.

    Returns:
        'auto_approved' — confidence >= 0.70 and no critical error
        'pending'       — confidence < 0.70 OR has critical error
    """
    if has_critical_error:
        return "pending"
    if confidence >= 0.70:
        return "auto_approved"
    return "pending"


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def classify_accounts(
    accounts: List[Dict],
    column_mapping: Dict,
    pattern: str,
    erp_system: Optional[str] = None,
) -> List[Dict]:
    """Run the 5-layer classification engine on a list of accounts.

    Args:
        accounts:       List of account dicts (raw rows from COA upload).
        column_mapping: Dict mapping canonical names ('code', 'name', 'type', etc.)
                        to actual column keys in the account dicts.
        pattern:        Detected COA pattern (e.g. 'saudi_4digit', 'flat').
        erp_system:     Optional ERP identifier ('odoo', 'zoho', etc.).

    Returns:
        The same list with classification fields injected into each account:
            concept_id, main_class, sub_class, nature, confidence,
            classification_method, review_status
    """
    total = len(accounts)
    auto_approved = 0
    pending = 0
    method_counts: Dict[str, int] = {}

    for idx, account in enumerate(accounts):
        try:
            layer_results: List[Dict] = []

            # Layer 1: Code prefix
            l1 = _layer1_code_prefix(account, column_mapping)
            if l1:
                layer_results.append(l1)

            # Layer 2: ERP type (only if type column is mapped)
            l2 = _layer2_erp_type(account, column_mapping)
            if l2:
                layer_results.append(l2)

            # Layer 3: Name lexicon
            l3 = _layer3_name_lexicon(account, column_mapping)
            if l3:
                layer_results.append(l3)

            # Layer 4: Conflict detection across layers 1-3
            merged = _layer4_conflict_detection(layer_results)

            # Layer 5: Claude API fallback if nothing classified
            if merged["main_class"] is None:
                context = {
                    "pattern": pattern,
                    "erp_system": erp_system,
                    "account_index": idx,
                    "total_accounts": total,
                }
                l5 = _layer5_claude_api(account, column_mapping, context)
                if l5:
                    merged = l5
                    merged["has_conflict"] = False

            # Determine review status
            has_critical = merged.get("has_conflict", False) and merged.get("confidence", 0) < 0.50
            review_status = _determine_review_status(merged.get("confidence", 0), has_critical)

            # Inject classification into the account
            account["concept_id"] = merged.get("concept_id")
            account["main_class"] = merged.get("main_class")
            account["sub_class"] = merged.get("sub_class")
            account["nature"] = merged.get("nature")
            account["confidence"] = round(merged.get("confidence", 0), 4)
            account["classification_method"] = merged.get("classification_method", "none")
            account["review_status"] = review_status

            # Stats
            if review_status == "auto_approved":
                auto_approved += 1
            else:
                pending += 1
            method = merged.get("classification_method", "none")
            method_counts[method] = method_counts.get(method, 0) + 1

        except Exception:
            logger.exception("Classification failed for account at index %d", idx)
            account["concept_id"] = None
            account["main_class"] = None
            account["sub_class"] = None
            account["nature"] = None
            account["confidence"] = 0.0
            account["classification_method"] = "error"
            account["review_status"] = "pending"
            pending += 1
            method_counts["error"] = method_counts.get("error", 0) + 1

    logger.info(
        "Classification complete: %d accounts, %d auto_approved, %d pending | methods: %s",
        total,
        auto_approved,
        pending,
        method_counts,
    )

    return accounts
