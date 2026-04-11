"""
Governance & Companies Rulebook — قواعد الحوكمة ونظام الشركات
═══════════════════════════════════════════════════════════════
"""


def _eval_statutory_reserve(ctx):
    """نظام الشركات: الاحتياطي النظامي"""
    eq = ctx["balance"].get("equity", {}).get("detail", {})
    inc = ctx["income"]
    profit = inc.get("net_profit", 0)
    capital = eq.get("share_capital", 0)
    reserve = eq.get("statutory_reserve", 0)

    if profit > 0 and capital > 0:
        expected_reserve = profit * 0.10
        max_reserve = capital * 0.30
        if reserve < max_reserve and reserve < expected_reserve:
            return {
                "type": "compliance",
                "severity": "info",
                "message": f"يجب تجنيب 10% من صافي الربح ({expected_reserve:,.0f}) كاحتياطي نظامي حتى يبلغ 30% من رأس المال ({max_reserve:,.0f})",
                "reference": "نظام الشركات 2022 — المادة 158/167",
                "citation": "يجنب 10% من صافي أرباح الشركة سنوياً لتكوين احتياطي نظامي، ويجوز التوقف عن ذلك متى بلغ 30% من رأس المال المدفوع",
            }
    return None


def _eval_accumulated_losses(ctx):
    """نظام الشركات: الخسائر المتراكمة"""
    eq = ctx["balance"].get("equity", {}).get("detail", {})
    capital = eq.get("share_capital", 0)
    retained = eq.get("retained_earnings", 0)

    if capital > 0 and retained < 0:
        loss_ratio = abs(retained) / capital
        if loss_ratio >= 0.5:
            return {
                "type": "finding",
                "severity": "critical",
                "message": f"الخسائر المتراكمة ({abs(retained):,.0f}) تبلغ {loss_ratio:.0%} من رأس المال — يجب إخطار وزارة التجارة وعقد جمعية عامة غير عادية",
                "reference": "نظام الشركات 2022",
                "citation": "إذا بلغت خسائر الشركة المتراكمة نصف رأس المال المدفوع، يجب على مجلس الإدارة إخطار وزارة التجارة وعقد جمعية عامة غير عادية خلال 180 يوماً",
            }
        elif loss_ratio >= 0.25:
            return {
                "type": "finding",
                "severity": "warning",
                "message": f"الخسائر المتراكمة ({abs(retained):,.0f}) تبلغ {loss_ratio:.0%} من رأس المال — يُنصح بمراقبة الوضع",
            }
    return None


def _eval_negative_equity(ctx):
    """حقوق ملكية سالبة"""
    eq_total = ctx["balance"].get("equity", {}).get("total", 0)
    if eq_total < 0:
        return {
            "type": "finding",
            "severity": "critical",
            "message": f"حقوق الملكية سالبة ({eq_total:,.0f}) — المنشأة في حالة عسر فني، قد تنطبق إجراءات نظام الإفلاس",
            "reference": "نظام الإفلاس 2018",
            "citation": "إذا كانت التزامات المنشأة تتجاوز أصولها (صافي أصول سالب)، قد يلزم النظر في التسوية الوقائية أو إعادة التنظيم المالي",
        }
    return None


def _eval_qawaem_filing(ctx):
    """منصة قوائم: إيداع القوائم المالية"""
    rev = ctx["income"].get("net_revenue", 0)
    if rev > 0:
        return {
            "type": "compliance",
            "severity": "info",
            "message": "تذكير: يجب إيداع القوائم المالية المدققة في منصة قوائم (وزارة التجارة) خلال 6 أشهر من نهاية السنة المالية",
            "reference": "نظام الشركات — الباب السابع + منصة قوائم",
            "citation": "جميع الشركات ذات المسؤولية المحدودة والمساهمة ملزمة بإيداع قوائمها المالية إلكترونياً في منصة قوائم",
        }
    return None


def _eval_eos_provision(ctx):
    """نظام العمل: مكافأة نهاية الخدمة"""
    inc = ctx["income"]
    bs = ctx["balance"]
    any(k for k in ["payroll", "selling_expenses"] if inc.get(k, 0) > 0)
    # rough check: admin + selling expenses as proxy for payroll
    total_expenses = inc.get("admin_expenses", 0) + inc.get("selling_expenses", 0)

    ncl = bs.get("non_current_liabilities", {}).get("detail", {})
    has_eos = "end_of_service" in ncl

    if total_expenses > 100000 and not has_eos:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "لا يوجد مخصص مكافأة نهاية الخدمة رغم وجود مصروفات رواتب كبيرة — مطلوب حسب نظام العمل المادة 84 و IAS 19",
            "reference": "نظام العمل السعودي — المادة 84 | IAS 19",
            "citation": "يستحق العامل مكافأة نهاية خدمة: نصف شهر عن كل سنة من الخمس الأولى + شهر كامل بعد ذلك. يجب الاعتراف بالمخصص حسب IAS 19 بتقييم اكتواري.",
        }
    return None


def _eval_gosi(ctx):
    """التأمينات الاجتماعية"""
    inc = ctx["income"]
    total_exp = inc.get("admin_expenses", 0) + inc.get("selling_expenses", 0)
    # If there are significant expenses but no GOSI line item detectable
    if total_exp > 500000:
        return {
            "type": "recommendation",
            "severity": "info",
            "message": "تحقق من تسجيل واحتساب مساهمات التأمينات الاجتماعية (GOSI) — حصة صاحب العمل 12.5% للسعوديين و 2% لغير السعوديين",
            "reference": "نظام التأمينات الاجتماعية + GOSI",
        }
    return None


GOVERNANCE_RULES = {
    "GOV_001_RESERVE": {
        "domain": "governance",
        "title": "الاحتياطي النظامي",
        "authority": "وزارة التجارة",
        "reference": "نظام الشركات 2022 — م158/167",
        "obligation": "mandatory",
        "evaluate": _eval_statutory_reserve,
    },
    "GOV_002_LOSSES": {
        "domain": "governance",
        "title": "الخسائر المتراكمة",
        "authority": "وزارة التجارة",
        "reference": "نظام الشركات 2022",
        "obligation": "mandatory",
        "evaluate": _eval_accumulated_losses,
    },
    "GOV_003_NEG_EQUITY": {
        "domain": "governance",
        "title": "حقوق ملكية سالبة",
        "authority": "متعدد",
        "reference": "نظام الإفلاس 2018",
        "obligation": "mandatory",
        "evaluate": _eval_negative_equity,
    },
    "GOV_004_QAWAEM": {
        "domain": "governance",
        "title": "إيداع قوائم مالية",
        "authority": "وزارة التجارة",
        "reference": "منصة قوائم",
        "obligation": "mandatory",
        "evaluate": _eval_qawaem_filing,
    },
    "GOV_005_EOS": {
        "domain": "governance",
        "title": "مكافأة نهاية الخدمة",
        "authority": "HRSD + SOCPA",
        "reference": "نظام العمل م84 + IAS 19",
        "obligation": "mandatory",
        "evaluate": _eval_eos_provision,
    },
    "GOV_006_GOSI": {
        "domain": "governance",
        "title": "التأمينات الاجتماعية",
        "authority": "GOSI",
        "reference": "نظام التأمينات الاجتماعية",
        "obligation": "mandatory",
        "evaluate": _eval_gosi,
    },
}
