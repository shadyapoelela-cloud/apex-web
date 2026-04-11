"""
Accounting & Audit Rulebook — قواعد المحاسبة والمراجعة التنفيذية
═══════════════════════════════════════════════════════════════════
"""


def _eval_ecl_provision(ctx):
    """IFRS 9: مخصص خسائر ائتمانية متوقعة"""
    ca = ctx["balance"].get("current_assets", {}).get("detail", {})
    has_recv = "trade_receivables" in ca
    has_allowance = "allowance_doubtful" in ca
    if has_recv and not has_allowance:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "ذمم مدينة تجارية بدون مخصص خسائر ائتمانية متوقعة (ECL) — مطلوب حسب IFRS 9",
            "reference": "IFRS 9 — الفقرات 5.5.1 و 5.5.15",
            "citation": "IFRS 9 يتطلب إنشاء مخصص ECL لجميع الذمم المدينة التجارية باستخدام النموذج المبسّط (مصفوفة المخصص)",
        }
    return None


def _eval_depreciation(ctx):
    """IAS 16: وجود أصول ثابتة بدون إهلاك"""
    nca = ctx["balance"].get("non_current_assets", {}).get("detail", {})
    has_fa = any(
        k in nca for k in ["machinery", "vehicles", "furniture", "computers", "buildings", "leasehold_improvements"]
    )
    has_depr = any(k.startswith("accum_depr") for k in nca)
    if has_fa and not has_depr:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "أصول ثابتة بدون مجمع إهلاك — يجب إهلاك جميع الأصول الثابتة ما عدا الأراضي (IAS 16)",
            "reference": "IAS 16 — الفقرات 43-62",
        }
    return None


def _eval_rou_lease(ctx):
    """IFRS 16: أصول حق استخدام مع التزامات إيجارية"""
    nca = ctx["balance"].get("non_current_assets", {}).get("detail", {})
    ncl = ctx["balance"].get("non_current_liabilities", {}).get("detail", {})
    has_rou = "rou_assets" in nca
    has_lease_liab = "non_current_lease_liabilities" in ncl
    has_rent = ctx["income"].get("admin_expenses", 0) > 0  # rough proxy

    if has_rou and not has_lease_liab:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "أصول حق استخدام بدون التزامات إيجارية مقابلة — مراجعة IFRS 16",
            "reference": "IFRS 16 — الفقرة 22",
        }
    if not has_rou and has_rent:
        rent_total = ctx["income"].get("admin_expenses", 0) * 0.3  # estimate rent portion
        if rent_total > 200000:
            return {
                "type": "recommendation",
                "severity": "info",
                "message": "مصروفات تشغيلية كبيرة قد تتضمن إيجارات — تحقق من تطبيق IFRS 16 على عقود الإيجار",
                "reference": "IFRS 16 — الفقرة 9",
            }
    return None


def _eval_inventory_method(ctx):
    """IAS 2: طريقة تقييم المخزون"""
    inv_system = ctx.get("inventory_system", "unknown")
    if inv_system == "periodic":
        inc = ctx["income"]
        cogs = inc.get("cogs", 0)
        inc.get("cogs_method", "")
        if cogs == 0 and inc.get("net_revenue", 0) > 0:
            return {
                "type": "compliance",
                "severity": "warning",
                "message": "نظام جرد دوري: لم يتم حساب تكلفة البضاعة المباعة — يجب إدخال مخزون آخر المدة من الجرد الفعلي",
                "reference": "IAS 2 — الفقرة 34",
                "citation": "تكلفة البضاعة المباعة = مخزون أول المدة + صافي المشتريات - مخزون آخر المدة (من الجرد الفعلي)",
            }
    return None


def _eval_revenue_recognition(ctx):
    """IFRS 15: الاعتراف بالإيراد"""
    inc = ctx["income"]
    rev = inc.get("net_revenue", 0)
    returns = inc.get("sales_returns", 0) + inc.get("sales_discounts", 0)
    if rev > 0 and returns > 0:
        ratio = returns / rev
        if ratio > 0.20:
            return {
                "type": "finding",
                "severity": "warning",
                "message": f"نسبة المردودات والخصومات ({ratio:.1%}) مرتفعة — قد تشير لمشاكل في جودة المنتج أو سياسة البيع",
                "reference": "IFRS 15 — الفقرة 51 (العوض المتغير)",
            }
    return None


def _eval_going_concern(ctx):
    """IAS 1: الاستمرارية"""
    bs = ctx["balance"]
    equity = bs.get("equity", {}).get("total", 0)
    ca = bs.get("current_assets", {}).get("total", 0)
    cl = bs.get("current_liabilities", {}).get("total", 0)
    working_capital = ca - cl

    red_flags = []
    if equity < 0:
        red_flags.append("حقوق ملكية سالبة")
    if working_capital < 0 and cl > 0:
        if abs(working_capital) > cl * 0.5:
            red_flags.append("رأس مال عامل سالب بشكل جوهري")

    liq = ctx["ratios"].get("liquidity", {})
    cr = liq.get("current_ratio")
    if cr is not None and cr < 0.5:
        red_flags.append(f"نسبة تداول منخفضة جداً ({cr})")

    if red_flags:
        return {
            "type": "finding",
            "severity": "critical",
            "message": f"مؤشرات خطر استمرارية: {' | '.join(red_flags)} — مطلوب تقييم Going Concern حسب IAS 1",
            "reference": "IAS 1 — الفقرات 25-26",
            "citation": "يجب على الإدارة تقييم قدرة المنشأة على الاستمرار لمدة 12 شهراً على الأقل. وجود شكوك جوهرية يتطلب إفصاحاً واضحاً.",
        }
    return None


def _eval_comparative_info(ctx):
    """IAS 1: معلومات مقارنة"""
    # Without prior period, always recommend
    cf = ctx.get("balance", {}).get("cash_flow", {}) or {}
    if not cf.get("has_prior_period"):
        return {
            "type": "recommendation",
            "severity": "info",
            "message": "لا تتوفر بيانات فترة مقارنة — يُنصح بإضافة ميزان مراجعة الفترة السابقة لتحسين التحليل ودقة التدفقات النقدية",
            "reference": "IAS 1 — الفقرة 38",
        }
    return None


def _eval_materiality_checks(ctx):
    """فحوصات الأهمية النسبية"""
    total_assets = ctx["balance"].get("total_assets", 0)
    ctx["income"].get("net_revenue", 0)
    if total_assets == 0:
        return None

    # Check if any single account is > 50% of total assets
    for section in ["current_assets", "non_current_assets"]:
        detail = ctx["balance"].get(section, {}).get("detail", {})
        for k, v in detail.items():
            if abs(v) > total_assets * 0.5:
                return {
                    "type": "finding",
                    "severity": "info",
                    "message": f"تركز جوهري: {k} يمثل أكثر من 50% من إجمالي الأصول — يتطلب إفصاح إضافي",
                    "reference": "IAS 1 — الأهمية النسبية",
                }
    return None


ACCOUNTING_RULES = {
    "ACC_001_ECL": {
        "domain": "accounting",
        "title": "مخصص خسائر ائتمانية (IFRS 9)",
        "authority": "SOCPA/IFRS",
        "reference": "IFRS 9 — 5.5.15",
        "obligation": "mandatory",
        "evaluate": _eval_ecl_provision,
    },
    "ACC_002_DEPRECIATION": {
        "domain": "accounting",
        "title": "إهلاك الأصول الثابتة (IAS 16)",
        "authority": "SOCPA/IFRS",
        "reference": "IAS 16 — 43",
        "obligation": "mandatory",
        "evaluate": _eval_depreciation,
    },
    "ACC_003_IFRS16": {
        "domain": "accounting",
        "title": "عقود الإيجار (IFRS 16)",
        "authority": "SOCPA/IFRS",
        "reference": "IFRS 16",
        "obligation": "mandatory",
        "evaluate": _eval_rou_lease,
    },
    "ACC_004_INVENTORY": {
        "domain": "accounting",
        "title": "المخزون والجرد الدوري (IAS 2)",
        "authority": "SOCPA/IFRS",
        "reference": "IAS 2 — 34",
        "obligation": "mandatory",
        "evaluate": _eval_inventory_method,
    },
    "ACC_005_REVENUE": {
        "domain": "accounting",
        "title": "الاعتراف بالإيراد (IFRS 15)",
        "authority": "SOCPA/IFRS",
        "reference": "IFRS 15 — 51",
        "obligation": "mandatory",
        "evaluate": _eval_revenue_recognition,
    },
    "ACC_006_GOING_CONCERN": {
        "domain": "accounting",
        "title": "الاستمرارية (IAS 1)",
        "authority": "SOCPA/IFRS",
        "reference": "IAS 1 — 25-26",
        "obligation": "mandatory",
        "evaluate": _eval_going_concern,
    },
    "ACC_007_COMPARATIVE": {
        "domain": "accounting",
        "title": "معلومات مقارنة",
        "authority": "SOCPA/IFRS",
        "reference": "IAS 1 — 38",
        "obligation": "recommended",
        "evaluate": _eval_comparative_info,
    },
    "ACC_008_MATERIALITY": {
        "domain": "accounting",
        "title": "الأهمية النسبية",
        "authority": "SOCPA/IFRS",
        "reference": "IAS 1",
        "obligation": "recommended",
        "evaluate": _eval_materiality_checks,
    },
}
