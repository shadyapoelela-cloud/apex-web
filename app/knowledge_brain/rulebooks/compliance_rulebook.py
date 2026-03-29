"""
Compliance & Finance Readiness Rulebook — قواعد الجاهزية التمويلية والامتثال
═══════════════════════════════════════════════════════════════════════════════
"""


def _eval_dscr(ctx):
    """SAMA: نسبة تغطية خدمة الدين"""
    inc = ctx["income"]
    operating = inc.get("operating_profit", 0)
    depreciation = inc.get("depreciation", 0) + inc.get("amortization", 0)
    ebitda = operating + depreciation
    finance_cost = inc.get("finance_cost", 0)

    if finance_cost > 0:
        dscr = ebitda / finance_cost
        if dscr < 1.25:
            return {
                "type": "finding", "severity": "warning",
                "message": f"نسبة تغطية خدمة الدين (DSCR) = {dscr:.2f} — أقل من الحد الأدنى المطلوب (1.25) للتمويل البنكي",
                "reference": "إرشادات SAMA للتمويل المؤسسي",
                "citation": "البنوك السعودية تشترط عادةً DSCR ≥ 1.25 كحد أدنى لمنح أو تجديد التسهيلات الائتمانية",
            }
        elif dscr < 1.5:
            return {
                "type": "recommendation", "severity": "info",
                "message": f"DSCR = {dscr:.2f} — مقبول لكن قريب من الحد الأدنى. تحسين التدفقات التشغيلية سيعزز الجاهزية التمويلية",
            }
    return None


def _eval_current_ratio_finance(ctx):
    """السيولة للتمويل"""
    liq = ctx["ratios"].get("liquidity", {})
    cr = liq.get("current_ratio")
    qr = liq.get("quick_ratio")

    if cr is not None and cr < 1.0:
        return {
            "type": "finding", "severity": "warning",
            "message": f"نسبة التداول ({cr}) أقل من 1.0 — الأصول المتداولة لا تغطي الالتزامات المتداولة. هذا مؤشر سلبي للبنوك",
            "reference": "متطلبات التمويل البنكي — SAMA",
        }
    if qr is not None and qr < 0.5:
        return {
            "type": "finding", "severity": "warning",
            "message": f"النسبة السريعة ({qr}) منخفضة جداً — صعوبة في تغطية الالتزامات قصيرة الأجل بدون الاعتماد على بيع المخزون",
        }
    return None


def _eval_leverage(ctx):
    """المديونية"""
    lev = ctx["ratios"].get("leverage", {})
    de = lev.get("debt_to_equity")
    da = lev.get("debt_to_assets_pct")

    if de is not None and de > 3.0:
        return {
            "type": "finding", "severity": "warning",
            "message": f"نسبة الدين إلى حقوق الملكية ({de:.2f}) مرتفعة جداً — مخاطر مديونية عالية وصعوبة في الحصول على تمويل إضافي",
            "reference": "معايير التمويل المؤسسي — SAMA",
        }
    if da is not None and da > 80:
        return {
            "type": "finding", "severity": "warning",
            "message": f"نسبة الدين إلى الأصول ({da:.1f}%) تتجاوز 80% — هيكل تمويلي محفوف بالمخاطر",
        }
    return None


def _eval_profitability(ctx):
    """الربحية"""
    prof = ctx["ratios"].get("profitability", {})
    nm = prof.get("net_margin_pct")
    gm = prof.get("gross_margin_pct")

    if nm is not None and nm < 0:
        return {
            "type": "finding", "severity": "warning",
            "message": f"هامش صافي الربح سالب ({nm:.1f}%) — المنشأة تحقق خسائر صافية",
        }
    if gm is not None and gm < 5:
        return {
            "type": "finding", "severity": "info",
            "message": f"هامش مجمل الربح منخفض ({gm:.1f}%) — قد يشير لضغوط تسعيرية أو ارتفاع التكاليف",
        }
    return None


def _eval_working_capital(ctx):
    """رأس المال العامل"""
    liq = ctx["ratios"].get("liquidity", {})
    wc = liq.get("working_capital", 0)
    rev = ctx["income"].get("net_revenue", 0)

    if wc < 0 and rev > 0:
        wc_ratio = wc / rev
        if wc_ratio < -0.2:
            return {
                "type": "finding", "severity": "warning",
                "message": f"رأس المال العامل سالب ({wc:,.0f}) بنسبة {wc_ratio:.1%} من الإيرادات — مشكلة هيكلية في إدارة السيولة",
                "reference": "مبادئ إدارة رأس المال العامل",
            }
    return None


def _eval_audit_readiness(ctx):
    """جاهزية المراجعة"""
    conf = ctx["confidence"]
    overall = conf.get("overall", 0)
    if overall < 0.75:
        return {
            "type": "recommendation", "severity": "warning",
            "message": f"مؤشر الثقة ({overall:.1%}) منخفض — القوائم المالية قد لا تكون جاهزة لمراجعة المراجع الخارجي",
            "reference": "معايير المراجعة — SOCPA",
        }
    return None


def _eval_balance_sheet_integrity(ctx):
    """سلامة الميزانية"""
    bs = ctx["balance"]
    if not bs.get("is_balanced", False):
        diff = bs.get("balance_check", 0)
        return {
            "type": "finding", "severity": "critical",
            "message": f"الميزانية غير متوازنة (فرق: {diff:,.0f}) — خطأ جوهري يمنع اعتماد القوائم المالية",
            "reference": "IAS 1 — معادلة التوازن: الأصول = الالتزامات + حقوق الملكية",
            "citation": "الميزانية العمومية يجب أن تكون متوازنة تماماً. أي فرق يشير لخطأ في التبويب أو القراءة أو الحساب.",
        }
    return None


COMPLIANCE_RULES = {
    "CMP_001_DSCR": {
        "domain": "finance", "title": "نسبة تغطية خدمة الدين",
        "authority": "SAMA", "reference": "إرشادات التمويل المؤسسي",
        "obligation": "recommended", "evaluate": _eval_dscr,
    },
    "CMP_002_LIQUIDITY": {
        "domain": "finance", "title": "السيولة للتمويل",
        "authority": "SAMA", "reference": "متطلبات التمويل البنكي",
        "obligation": "recommended", "evaluate": _eval_current_ratio_finance,
    },
    "CMP_003_LEVERAGE": {
        "domain": "finance", "title": "المديونية",
        "authority": "SAMA", "reference": "معايير التمويل المؤسسي",
        "obligation": "recommended", "evaluate": _eval_leverage,
    },
    "CMP_004_PROFITABILITY": {
        "domain": "finance", "title": "الربحية",
        "authority": "عام", "obligation": "recommended", "evaluate": _eval_profitability,
    },
    "CMP_005_WORKING_CAPITAL": {
        "domain": "finance", "title": "رأس المال العامل",
        "authority": "عام", "obligation": "recommended", "evaluate": _eval_working_capital,
    },
    "CMP_006_AUDIT_READY": {
        "domain": "accounting", "title": "جاهزية المراجعة",
        "authority": "SOCPA", "reference": "معايير المراجعة",
        "obligation": "recommended", "evaluate": _eval_audit_readiness,
    },
    "CMP_007_BALANCE": {
        "domain": "accounting", "title": "سلامة الميزانية",
        "authority": "SOCPA/IFRS", "reference": "IAS 1",
        "obligation": "mandatory", "evaluate": _eval_balance_sheet_integrity,
    },
}
