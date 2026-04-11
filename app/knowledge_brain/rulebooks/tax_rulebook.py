"""
Tax Rulebook — قواعد الضرائب والزكاة التنفيذية
═══════════════════════════════════════════════════

كل قاعدة لها:
- condition: متى تنطبق
- evaluate: دالة تفحص البيانات وترجع نتيجة أو None
- reference: المرجع الرسمي
- authority: الجهة
- obligation: إلزامي/موصى/اختياري
"""


def _eval_vat_registration(ctx):
    """هل المنشأة تحتاج تسجيل في ض.ق.م؟"""
    rev = ctx["income"].get("net_revenue", 0)
    if rev > 375000:
        has_vat_out = any(
            k in ctx["balance"].get("current_liabilities", {}).get("detail", {})
            for k in ["vat_payable", "net_vat_payable"]
        )
        if not has_vat_out:
            return {
                "type": "compliance",
                "severity": "warning",
                "message": f"الإيرادات ({rev:,.0f}) تتجاوز حد التسجيل الإلزامي في ض.ق.م (375,000 ريال) — لا يوجد حساب ض.ق.م مخرجات",
                "citation": "نظام ضريبة القيمة المضافة — المادة 50: يجب التسجيل إذا تجاوزت التوريدات الخاضعة 375,000 ريال خلال 12 شهراً",
            }
    elif rev > 187500:
        return {
            "type": "recommendation",
            "severity": "info",
            "message": f"الإيرادات ({rev:,.0f}) تتجاوز حد التسجيل الاختياري في ض.ق.م (187,500 ريال) — يمكن التسجيل طوعياً",
        }
    return None


def _eval_vat_input_output(ctx):
    """هل فيه مدخلات ومخرجات معاً؟"""
    bs_detail = ctx["balance"].get("current_assets", {}).get("detail", {})
    cl_detail = ctx["balance"].get("current_liabilities", {}).get("detail", {})
    has_input = "vat_receivable" in bs_detail
    has_output = any(k in cl_detail for k in ["vat_payable", "net_vat_payable"])
    if has_input and not has_output:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "يوجد ض.ق.م مدخلات بدون مخرجات — تحقق من التسجيل والإقرارات",
            "reference": "لائحة ض.ق.م — الفصل 4",
        }
    if has_output and not has_input:
        return {
            "type": "finding",
            "severity": "info",
            "message": "يوجد ض.ق.م مخرجات بدون مدخلات — تحقق من استرداد ض.ق.م على المشتريات",
        }
    return None


def _eval_zakat_provision(ctx):
    """هل يوجد مخصص زكاة/ضريبة؟"""
    inc = ctx["income"]
    if inc.get("net_revenue", 0) > 0 and inc.get("zakat_tax", 0) == 0:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "لا يوجد مصروف زكاة أو ضريبة دخل رغم وجود إيرادات — يجب احتساب الزكاة أو الضريبة",
            "reference": "نظام جباية الزكاة — المرسوم الملكي 17/2/28/8634",
            "citation": "الزكاة إلزامية بنسبة 2.5% على الوعاء الزكوي لجميع المنشآت السعودية/الخليجية",
        }
    return None


def _eval_withholding_tax(ctx):
    """هل فيه مدفوعات للخارج تحتاج ضريبة استقطاع؟"""
    # Check for professional fees or finance costs that might include foreign payments
    inc = ctx["income"]
    if inc.get("finance_cost", 0) > 100000:
        return {
            "type": "recommendation",
            "severity": "info",
            "message": f"تكاليف تمويل كبيرة ({inc['finance_cost']:,.0f}) — تحقق من ضريبة الاستقطاع على فوائد القروض المدفوعة لجهات غير مقيمة (5%)",
            "reference": "نظام ضريبة الدخل — المادة 68",
        }
    return None


def _eval_e_invoicing(ctx):
    """تذكير بالفوترة الإلكترونية"""
    rev = ctx["income"].get("net_revenue", 0)
    if rev > 375000:
        return {
            "type": "compliance",
            "severity": "info",
            "message": "المنشأة ملزمة بالفوترة الإلكترونية (فاتورة) — المرحلة 1: إصدار إلكتروني | المرحلة 2: ربط مع ZATCA",
            "reference": "قرار ZATCA بشأن الفوترة الإلكترونية — 4 ديسمبر 2021",
        }
    return None


def _eval_transfer_pricing(ctx):
    """هل فيه معاملات أطراف ذات علاقة تحتاج توثيق تسعير تحويلي؟"""
    # Check for related party balances
    bs = ctx["balance"]
    ca = bs.get("current_assets", {}).get("detail", {})
    cl = bs.get("current_liabilities", {}).get("detail", {})
    has_rp = "related_party_receivables" in ca or "related_party_payables" in cl
    if has_rp:
        return {
            "type": "compliance",
            "severity": "warning",
            "message": "وجود أرصدة أطراف ذات علاقة — يجب الالتزام بمبدأ السعر المحايد (Arm's Length) وتوثيق التسعير التحويلي",
            "reference": "لائحة التسعير التحويلي — ZATCA",
            "citation": "المنشآت التي لديها معاملات مع أطراف ذات علاقة ملزمة بتوثيق التسعير التحويلي حسب لائحة ZATCA",
        }
    return None


TAX_RULES = {
    "TAX_001_VAT_REGISTRATION": {
        "domain": "tax",
        "title": "تسجيل ض.ق.م",
        "authority": "ZATCA",
        "reference": "نظام ض.ق.م — المادة 50",
        "obligation": "mandatory",
        "description": "فحص حد التسجيل الإلزامي والاختياري",
        "evaluate": _eval_vat_registration,
    },
    "TAX_002_VAT_IO": {
        "domain": "tax",
        "title": "ض.ق.م مدخلات ومخرجات",
        "authority": "ZATCA",
        "reference": "لائحة ض.ق.م — الفصل 4",
        "obligation": "mandatory",
        "evaluate": _eval_vat_input_output,
    },
    "TAX_003_ZAKAT": {
        "domain": "tax",
        "title": "مخصص الزكاة",
        "authority": "ZATCA",
        "reference": "نظام جباية الزكاة",
        "obligation": "mandatory",
        "evaluate": _eval_zakat_provision,
    },
    "TAX_004_WITHHOLDING": {
        "domain": "tax",
        "title": "ضريبة الاستقطاع",
        "authority": "ZATCA",
        "reference": "نظام ضريبة الدخل — المادة 68",
        "obligation": "mandatory",
        "evaluate": _eval_withholding_tax,
    },
    "TAX_005_E_INVOICING": {
        "domain": "tax",
        "title": "الفوترة الإلكترونية",
        "authority": "ZATCA",
        "reference": "قرار الفوترة الإلكترونية 2021",
        "obligation": "mandatory",
        "evaluate": _eval_e_invoicing,
    },
    "TAX_006_TRANSFER_PRICING": {
        "domain": "tax",
        "title": "التسعير التحويلي",
        "authority": "ZATCA",
        "reference": "لائحة التسعير التحويلي",
        "obligation": "mandatory",
        "evaluate": _eval_transfer_pricing,
    },
}
