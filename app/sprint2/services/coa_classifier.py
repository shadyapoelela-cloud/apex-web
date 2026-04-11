"""
APEX COA Classification Engine — Sprint 2

Classifies each parsed account into:
- normalized_class (asset, liability, equity, revenue, expense, contra, other)
- statement_section (current_assets, noncurrent_assets, current_liabilities, etc.)
- subcategory (cash, receivables, inventory, etc.)
- current_noncurrent (current, noncurrent, na)
- cashflow_role (operating, investing, financing, na)
- sign_rule (debit_normal, credit_normal)
- mapping_confidence (0.0 - 1.0)

Classification priority:
1. Exact name matches (Arabic + English)
2. Account code prefix rules
3. Parent context inheritance
4. Account type raw field
5. Keyword/pattern matching
"""

import re
from app.core.text_utils import remove_diacritics

# ── Normalized Classes ──
CLASSES = ["asset", "liability", "equity", "revenue", "expense", "contra", "other"]

# ── Statement Sections ──
SECTIONS = {
    "asset": ["current_assets", "noncurrent_assets", "other_assets"],
    "liability": ["current_liabilities", "noncurrent_liabilities", "other_liabilities"],
    "equity": ["equity"],
    "revenue": ["operating_revenue", "other_revenue"],
    "expense": ["operating_expense", "cost_of_revenue", "other_expense", "finance_cost"],
    "contra": ["contra_asset", "contra_liability", "contra_equity", "contra_revenue"],
    "other": ["other"],
}

# ── Arabic keyword → (class, section, subcategory, confidence) ──
ARABIC_RULES = [
    # Assets - Current
    (r"صندوق|نقد|كاش", "asset", "current_assets", "cash", 0.95),
    (r"بنك|بنوك|مصرف", "asset", "current_assets", "bank_accounts", 0.95),
    (r"ذمم.*مدين|عملاء|مدينون", "asset", "current_assets", "accounts_receivable", 0.90),
    (r"أوراق.*قبض", "asset", "current_assets", "notes_receivable", 0.88),
    (r"مخزون|بضاع", "asset", "current_assets", "inventory", 0.92),
    (r"مصروف.*مقدم|مدفوع.*مقدم", "asset", "current_assets", "prepaid_expenses", 0.85),
    (r"ضريب.*مدفوع.*مقدم|ضريب.*مسترد", "asset", "current_assets", "prepaid_tax", 0.82),
    (r"عهد|سلف|أمانات.*مدين", "asset", "current_assets", "advances", 0.78),
    (r"استثمار.*قصير|ودائع.*قصير", "asset", "current_assets", "short_term_investments", 0.80),
    # Assets - Non-current
    (r"أص.*ثابت|ممتلكات|عقار|أراضي|أرض", "asset", "noncurrent_assets", "fixed_assets", 0.90),
    (r"مبان|مبنى|إنشاءات", "asset", "noncurrent_assets", "buildings", 0.90),
    (r"آل[اي]ات|معدات|أجهز", "asset", "noncurrent_assets", "equipment", 0.88),
    (r"سيار|مركب|نقل", "asset", "noncurrent_assets", "vehicles", 0.88),
    (r"أثاث|تجهيز", "asset", "noncurrent_assets", "furniture", 0.85),
    (r"إهلاك|استهلاك|اهلاك", "contra", "contra_asset", "accumulated_depreciation", 0.92),
    (r"استثمار.*طويل|مساهم", "asset", "noncurrent_assets", "long_term_investments", 0.82),
    (r"شهر.*تجاري|جودويل|goodwill", "asset", "noncurrent_assets", "goodwill", 0.85),
    (r"غير.*ملموس|برمجيات|براء", "asset", "noncurrent_assets", "intangible_assets", 0.82),
    (r"مشروع.*تحت.*التنفيذ|أعمال.*تحت", "asset", "noncurrent_assets", "work_in_progress", 0.80),
    # Liabilities - Current
    (r"ذمم.*دائن|موردي|دائنون", "liability", "current_liabilities", "accounts_payable", 0.90),
    (r"أوراق.*دفع", "liability", "current_liabilities", "notes_payable", 0.88),
    (r"مصروف.*مستحق|التزام.*متداول", "liability", "current_liabilities", "accrued_expenses", 0.85),
    (r"رواتب.*مستحق|أجور.*مستحق", "liability", "current_liabilities", "salaries_payable", 0.88),
    (r"ضريب.*مستحق|زكا.*مستحق", "liability", "current_liabilities", "tax_payable", 0.85),
    (r"إيراد.*مقدم|دفع.*مقدم.*عميل", "liability", "current_liabilities", "unearned_revenue", 0.82),
    (r"قرض.*قصير|تسهيل.*بنك", "liability", "current_liabilities", "short_term_loans", 0.82),
    (r"جزء.*متداول.*قرض", "liability", "current_liabilities", "current_portion_ltl", 0.80),
    # Liabilities - Non-current
    (r"قرض.*طويل|تمويل.*طويل", "liability", "noncurrent_liabilities", "long_term_loans", 0.85),
    (r"مكافأ.*نهاي|تعويض.*نهاي|مكاف.*خدم", "liability", "noncurrent_liabilities", "end_of_service", 0.90),
    (r"سند|صكوك", "liability", "noncurrent_liabilities", "bonds_payable", 0.78),
    # Equity
    (r"رأس.*مال|رأس مال", "equity", "equity", "share_capital", 0.95),
    (r"احتياطي|احتياط", "equity", "equity", "reserves", 0.88),
    (r"أرباح.*مبق|أرباح.*محتجز", "equity", "equity", "retained_earnings", 0.92),
    (r"خسائر.*متراكم", "equity", "equity", "accumulated_losses", 0.90),
    (r"جاري.*شريك|جاري.*مالك|حساب.*شخصي", "equity", "equity", "owner_drawings", 0.82),
    (r"توزيع.*أرباح", "equity", "equity", "dividends", 0.85),
    (r"عالوة.*إصدار|عالو.*أسهم", "equity", "equity", "share_premium", 0.80),
    # Revenue
    (r"إيراد.*تشغيل|إيراد.*رئيسي|مبيعات", "revenue", "operating_revenue", "operating_revenue", 0.92),
    (r"إيراد.*خدم", "revenue", "operating_revenue", "service_revenue", 0.90),
    (r"إيراد.*أخر|إيراد.*متنوع|إيراد.*استثمار", "revenue", "other_revenue", "other_revenue", 0.78),
    (r"خصم.*مسموح|مردود.*مبيع|خصم.*تجاري", "contra", "contra_revenue", "sales_returns_discounts", 0.85),
    # Expenses - COGS
    (r"تكلف.*مبيع|تكلف.*بضاع|كلف.*إيراد", "expense", "cost_of_revenue", "cost_of_revenue", 0.92),
    # Expenses - Operating
    (r"رواتب|أجور|مكافآت.*موظف|رواتب.*أجور", "expense", "operating_expense", "salaries_wages", 0.90),
    (r"إيجار", "expense", "operating_expense", "rent", 0.88),
    (r"كهرباء|ماء|هاتف|اتصال|مرافق", "expense", "operating_expense", "utilities", 0.85),
    (r"صيان|إصلاح", "expense", "operating_expense", "maintenance", 0.82),
    (r"تأمين", "expense", "operating_expense", "insurance", 0.82),
    (r"إهلاك.*مصروف|مصروف.*إهلاك|مصروف.*استهلاك", "expense", "operating_expense", "depreciation_expense", 0.88),
    (r"مصروف.*إدار|عموم|إدار.*عام", "expense", "operating_expense", "general_admin", 0.80),
    (r"تسويق|إعلان|دعاي", "expense", "operating_expense", "marketing", 0.82),
    (r"مصروف.*سفر|انتقال|بدل.*سفر", "expense", "operating_expense", "travel", 0.78),
    (r"قرطاس|مطبوع|لوازم.*مكتب", "expense", "operating_expense", "office_supplies", 0.78),
    (r"استشار|أتعاب.*مهن|خدم.*مهن", "expense", "operating_expense", "professional_fees", 0.80),
    (r"ضيافة|بدل.*طعام", "expense", "operating_expense", "hospitality", 0.75),
    (r"تدريب|تطوير.*موظف", "expense", "operating_expense", "training", 0.78),
    (r"اشتراك|عضوي|رسوم.*حكوم", "expense", "operating_expense", "subscriptions_fees", 0.75),
    # Expenses - Finance
    (r"فائد|عمول.*بنك|مصروف.*تمويل|رسوم.*بنك", "expense", "finance_cost", "finance_cost", 0.85),
    # Expenses - Other
    (r"خسائر|خسار|مصروف.*أخر|متنوع", "expense", "other_expense", "other_expense", 0.65),
    (r"غرام|جزاء|مخالف", "expense", "other_expense", "penalties", 0.75),
    (r"ديون.*معدوم|مشكوك.*تحصيل", "expense", "operating_expense", "bad_debts", 0.82),
]

# ── English keyword rules ──
ENGLISH_RULES = [
    (r"cash|petty cash", "asset", "current_assets", "cash", 0.95),
    (r"bank", "asset", "current_assets", "bank_accounts", 0.92),
    (r"accounts?\s*receivable|trade\s*receivable|debtors?", "asset", "current_assets", "accounts_receivable", 0.90),
    (r"inventor(y|ies)|stock|merchandise", "asset", "current_assets", "inventory", 0.92),
    (r"prepaid|advance.*paid", "asset", "current_assets", "prepaid_expenses", 0.82),
    (r"fixed\s*asset|property|plant|equipment|ppe", "asset", "noncurrent_assets", "fixed_assets", 0.90),
    (r"building", "asset", "noncurrent_assets", "buildings", 0.88),
    (r"vehicle|car|truck", "asset", "noncurrent_assets", "vehicles", 0.85),
    (r"furniture|fixture", "asset", "noncurrent_assets", "furniture", 0.85),
    (r"depreciation|accumulated\s*dep", "contra", "contra_asset", "accumulated_depreciation", 0.92),
    (r"intangible|goodwill|patent|trademark", "asset", "noncurrent_assets", "intangible_assets", 0.82),
    (r"accounts?\s*payable|trade\s*payable|creditors?", "liability", "current_liabilities", "accounts_payable", 0.90),
    (r"accrued|accrual", "liability", "current_liabilities", "accrued_expenses", 0.82),
    (r"salary\s*payable|wages?\s*payable", "liability", "current_liabilities", "salaries_payable", 0.85),
    (r"tax\s*payable|vat\s*payable|zakat", "liability", "current_liabilities", "tax_payable", 0.82),
    (r"unearned|deferred\s*revenue", "liability", "current_liabilities", "unearned_revenue", 0.82),
    (r"long.*term.*loan|mortgage|bond", "liability", "noncurrent_liabilities", "long_term_loans", 0.82),
    (r"end\s*of\s*service|indemnity|gratuity", "liability", "noncurrent_liabilities", "end_of_service", 0.88),
    (r"capital|share\s*capital|paid.*capital", "equity", "equity", "share_capital", 0.92),
    (r"retain.*earning|accumulated.*profit", "equity", "equity", "retained_earnings", 0.90),
    (r"reserve", "equity", "equity", "reserves", 0.85),
    (r"drawing|withdrawal|distribution", "equity", "equity", "owner_drawings", 0.78),
    (r"revenue|sales|income(?!.*tax)", "revenue", "operating_revenue", "operating_revenue", 0.85),
    (r"cost.*(?:good|sale|revenue)", "expense", "cost_of_revenue", "cost_of_revenue", 0.90),
    (r"salar(y|ies)|wage|payroll|compensation", "expense", "operating_expense", "salaries_wages", 0.88),
    (r"rent(?!.*revenue)", "expense", "operating_expense", "rent", 0.85),
    (r"utilit(y|ies)|electric|water|phone", "expense", "operating_expense", "utilities", 0.82),
    (r"insurance", "expense", "operating_expense", "insurance", 0.82),
    (r"depreciation\s*expense", "expense", "operating_expense", "depreciation_expense", 0.85),
    (r"marketing|advertis|promot", "expense", "operating_expense", "marketing", 0.80),
    (r"interest|finance\s*cost|bank\s*charge", "expense", "finance_cost", "finance_cost", 0.82),
    (r"bad\s*debt|doubtful|allowance.*doubt", "expense", "operating_expense", "bad_debts", 0.80),
    (r"other\s*expense|miscellaneous|sundry", "expense", "other_expense", "other_expense", 0.60),
]

# ── Code prefix rules (common Saudi/IFRS patterns) ──
CODE_PREFIX_RULES = [
    ("1", "asset", 0.60),
    ("11", "asset", 0.70),  # current assets
    ("12", "asset", 0.70),  # receivables
    ("13", "asset", 0.65),  # inventory
    ("14", "asset", 0.65),  # prepaid
    ("15", "asset", 0.65),  # noncurrent
    ("16", "asset", 0.65),  # fixed
    ("2", "liability", 0.60),
    ("21", "liability", 0.70),  # current
    ("22", "liability", 0.65),  # noncurrent
    ("3", "equity", 0.65),
    ("31", "equity", 0.70),
    ("4", "revenue", 0.65),
    ("41", "revenue", 0.70),
    ("5", "expense", 0.60),
    ("51", "expense", 0.65),
    ("52", "expense", 0.65),
]


def _normalize_for_match(text: str) -> str:
    """Normalize text for classification matching."""
    if not text:
        return ""
    t = remove_diacritics(text.strip().lower())
    # Normalize common Arabic chars
    t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    t = t.replace("ى", "ي").replace("ة", "ه")
    t = re.sub(r"\s+", " ", t)
    return t


def classify_account(
    account_name_raw: str,
    account_name_normalized: str = None,
    account_code: str = None,
    parent_code: str = None,
    parent_name: str = None,
    account_type_raw: str = None,
    account_level: int = None,
    normal_balance: str = None,
    parent_classification: dict = None,
) -> dict:
    """
    Classify a single account.
    Returns dict with: normalized_class, statement_section, subcategory,
    current_noncurrent, cashflow_role, sign_rule, mapping_confidence,
    mapping_source, classification_issues
    """
    name = _normalize_for_match(account_name_raw or "")
    _normalize_for_match(account_name_normalized or account_name_raw or "")
    code = (account_code or "").strip()
    issues = []

    best = None  # (class, section, subcategory, confidence, source)

    # ── Step 1: Arabic keyword matching ──
    for pattern, cls, section, subcat, conf in ARABIC_RULES:
        if re.search(pattern, name):
            if best is None or conf > best[3]:
                best = (cls, section, subcat, conf, "exact_match")
            break

    # ── Step 2: English keyword matching ──
    if best is None or best[3] < 0.85:
        for pattern, cls, section, subcat, conf in ENGLISH_RULES:
            if re.search(pattern, name, re.IGNORECASE):
                if best is None or conf > best[3]:
                    best = (cls, section, subcat, conf, "exact_match")
                break

    # ── Step 3: Account code prefix ──
    if best is None or best[3] < 0.70:
        if code:
            for prefix, cls, conf in sorted(CODE_PREFIX_RULES, key=lambda x: -len(x[0])):
                if code.startswith(prefix):
                    if best is None or conf > best[3]:
                        default_section = SECTIONS.get(cls, ["other"])[0]
                        best = (cls, default_section, None, conf, "code_prefix")
                    break

    # ── Step 4: Parent context inheritance ──
    if best is None or best[3] < 0.65:
        if parent_classification and parent_classification.get("normalized_class"):
            pc = parent_classification
            inherited_conf = (pc.get("mapping_confidence", 0.5)) * 0.7
            if best is None or inherited_conf > best[3]:
                best = (
                    pc["normalized_class"],
                    pc.get("statement_section", SECTIONS.get(pc["normalized_class"], ["other"])[0]),
                    None,
                    inherited_conf,
                    "parent_context",
                )

    # ── Step 5: Account type raw field ──
    if best is None or best[3] < 0.55:
        if account_type_raw:
            atr = _normalize_for_match(account_type_raw)
            type_map = {
                "asset": ("asset", "current_assets"),
                "اصول": ("asset", "current_assets"),
                "اصول متداوله": ("asset", "current_assets"),
                "اصول ثابته": ("asset", "noncurrent_assets"),
                "liability": ("liability", "current_liabilities"),
                "التزام": ("liability", "current_liabilities"),
                "equity": ("equity", "equity"),
                "حقوق ملكيه": ("equity", "equity"),
                "revenue": ("revenue", "operating_revenue"),
                "ايراد": ("revenue", "operating_revenue"),
                "expense": ("expense", "operating_expense"),
                "مصروف": ("expense", "operating_expense"),
            }
            for key, (cls, section) in type_map.items():
                if key in atr:
                    if best is None or 0.55 > best[3]:
                        best = (cls, section, None, 0.55, "auto_rule")
                    break

    # ── Step 6: Normal balance fallback ──
    if best is None:
        if normal_balance == "debit":
            best = ("asset", "current_assets", None, 0.30, "auto_rule")
            issues.append("low_confidence_debit_fallback")
        elif normal_balance == "credit":
            best = ("liability", "current_liabilities", None, 0.30, "auto_rule")
            issues.append("low_confidence_credit_fallback")
        else:
            best = ("other", "other", None, 0.10, "auto_rule")
            issues.append("unclassified_account")

    cls, section, subcat, confidence, source = best

    # ── Derive current_noncurrent ──
    current_noncurrent = "na"
    if section:
        if "current_" in section and "noncurrent" not in section:
            current_noncurrent = "current"
        elif "noncurrent" in section:
            current_noncurrent = "noncurrent"

    # ── Derive sign_rule ──
    sign_rule = "debit_normal"
    if cls in ("liability", "equity", "revenue"):
        sign_rule = "credit_normal"
    elif cls == "contra":
        if section and "asset" in section:
            sign_rule = "credit_normal"
        else:
            sign_rule = "debit_normal"

    # ── Derive cashflow_role ──
    cashflow_role = "operating"
    if section and ("noncurrent_assets" in section or section == "contra_asset"):
        cashflow_role = "investing"
    elif section and "noncurrent_liabilities" in section:
        cashflow_role = "financing"
    elif cls == "equity":
        cashflow_role = "financing"

    # ── Issues ──
    if confidence < 0.50:
        issues.append("low_confidence_classification")
    if not subcat:
        issues.append("no_subcategory_detected")

    return {
        "normalized_class": cls,
        "statement_section": section,
        "subcategory": subcat,
        "current_noncurrent": current_noncurrent,
        "cashflow_role": cashflow_role,
        "sign_rule": sign_rule,
        "mapping_confidence": round(confidence, 3),
        "mapping_source": source,
        "classification_issues": issues,
        "review_status": "auto_classified",
    }


def classify_upload(accounts: list, parent_map: dict = None) -> list:
    """
    Classify all accounts from an upload.
    accounts: list of dicts with account fields
    parent_map: dict of account_code -> classification result (for parent context)
    Returns list of classification results in same order.
    """
    if parent_map is None:
        parent_map = {}

    results = []

    # First pass: classify accounts with level 1 (roots)
    # Second pass: classify children using parent context
    # We do 2 passes for better parent context propagation

    for pass_num in range(2):
        for i, acc in enumerate(accounts):
            code = acc.get("account_code", "")
            parent_code = acc.get("parent_code", "")

            # Skip already classified with high confidence on pass 2
            if pass_num == 1 and i < len(results) and results[i].get("mapping_confidence", 0) >= 0.75:
                continue

            parent_cls = parent_map.get(parent_code) if parent_code else None

            result = classify_account(
                account_name_raw=acc.get("account_name_raw", ""),
                account_name_normalized=acc.get("account_name_normalized"),
                account_code=code,
                parent_code=parent_code,
                parent_name=acc.get("parent_name"),
                account_type_raw=acc.get("account_type_raw"),
                account_level=acc.get("account_level"),
                normal_balance=acc.get("normal_balance"),
                parent_classification=parent_cls,
            )

            if pass_num == 0:
                results.append(result)
            else:
                results[i] = result

            # Update parent_map for children
            if code:
                parent_map[code] = result

    return results
