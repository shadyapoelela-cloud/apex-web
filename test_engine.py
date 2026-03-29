"""
اختبار المحرك المالي الجديد بميزان مراجعة تجريبي
يحاكي بيانات شركة أوفر التجارية (البيانات الحقيقية من المحادثة السابقة)
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from openpyxl import Workbook


def create_test_trial_balance(filepath: str):
    """Create a realistic trial balance Excel file for testing."""
    wb = Workbook()
    ws = wb.active
    ws.title = "ميزان المراجعة"

    # Header rows 1-6
    ws.append(["", "", "", "شركة أوفر التجارية"])
    ws.append(["", "", "", "ميزان المراجعة"])
    ws.append(["", "", "", "للسنة المنتهية في 31/12/2024"])
    ws.append([])
    ws.append([])
    ws.append([])

    # Column headers (row 7-8)
    ws.append(["كود", "التبويب الرئيسي", "التبويب الفرعي", "اسم الحساب",
               "رصيد أول مدين", "رصيد أول دائن",
               "حركة المدين", "حركة الدائن",
               "رصيد آخر مدين", "رصيد آخر دائن"])
    ws.append(["Code", "Main Category", "Sub Category", "Account Name",
               "Opening Dr", "Opening Cr", "Movement Dr", "Movement Cr",
               "Closing Dr", "Closing Cr"])

    # Data rows (row 9+) — ميزان مراجعة متوازن بدقة
    # القاعدة: مجموع المدين = مجموع الدائن في كل عمود
    accounts = [
        # ─── أصول متداولة ───
        # [code, main_tab, sub_tab, name, open_dr, open_cr, mov_dr, mov_cr, close_dr, close_cr]
        ["1110", "أصول متداولة", "نقد في الصندوق", "صندوق النقدية الرئيسي",
         15000, 0, 500000, 485000, 30000, 0],
        ["1120", "أصول متداولة", "نقد في البنوك", "بنك الراجحي (407608017777128)",
         120000, 0, 3500000, 3200000, 420000, 0],
        ["1120", "أصول متداولة", "نقد في البنوك", "البنك الاهلى (394000000087603)",
         85000, 0, 2800000, 2750000, 135000, 0],
        ["1150", "أصول متداولة", "ذمم مدينة تجارية", "عملاء محليين",
         450000, 0, 5200000, 5100000, 550000, 0],
        ["1170", "أصول متداولة", "مخصص ديون مشكوك فيها", "مخصص ديون مشكوك فيها",
         0, 30000, 0, 15000, 0, 45000],
        ["1180", "أصول متداولة", "مخزون", "بضاعة تامة الصنع",
         1200000, 0, 8500000, 8300000, 1400000, 0],
        ["1190", "أصول متداولة", "مصروفات مدفوعة مقدماً", "تأمين مدفوع مقدماً",
         60000, 0, 24000, 48000, 36000, 0],
        ["", "أصول متداولة", "ضريبة قيمة مضافة مدخلات", "ض.ق.م مدخلات",
         25000, 0, 780000, 780000, 25000, 0],

        # ─── أصول غير متداولة ───
        ["1250", "أصول غير متداولة", "أثاث ومفروشات", "أثاث وتجهيزات",
         300000, 0, 50000, 0, 350000, 0],
        ["1240", "أصول غير متداولة", "سيارات ووسائل نقل", "سيارات نقل",
         200000, 0, 0, 0, 200000, 0],
        ["", "أصول غير متداولة", "مجمع الإهلاك", "مجمع إهلاك الأصول",
         0, 100000, 0, 80000, 0, 180000],

        # ─── الإيرادات ───
        ["4010", "إيرادات", "مبيعات", "مبيعات بضاعة",
         0, 0, 200000, 6200000, 0, 6000000],
        ["4030", "إيرادات", "مرتجع مبيعات", "مرتجع مبيعات",
         0, 0, 120000, 0, 120000, 0],

        # ─── تكلفة المبيعات ───
        ["5020", "تكلفة المبيعات", "مشتريات", "مشتريات بضاعة",
         0, 0, 4100000, 0, 4100000, 0],
        ["5030", "تكلفة المبيعات", "مرتجع مشتريات", "مرتجع مشتريات",
         0, 0, 0, 80000, 0, 80000],

        # ─── مصروفات إدارية ───
        ["6010", "مصروفات إدارية وعمومية", "رواتب وأجور", "رواتب الموظفين",
         0, 0, 720000, 0, 720000, 0],
        ["6020", "مصروفات إدارية وعمومية", "إيجارات", "إيجار المعرض",
         0, 0, 180000, 0, 180000, 0],
        ["6030", "مصروفات إدارية وعمومية", "كهرباء ومياه", "كهرباء ومياه",
         0, 0, 48000, 0, 48000, 0],
        ["6040", "مصروفات إدارية وعمومية", "إهلاك", "مصروف إهلاك",
         0, 0, 80000, 0, 80000, 0],
        ["", "مصروفات إدارية وعمومية", "تأمينات اجتماعية", "GOSI",
         0, 0, 50000, 0, 50000, 0],

        # ─── مصروفات بيع ───
        ["7030", "مصروفات بيع وتسويق", "إعلان وتسويق", "مصاريف تسويق",
         0, 0, 35000, 0, 35000, 0],

        # ─── تمويل ───
        ["8020", "إيرادات ومصروفات أخرى", "مصروفات تمويل", "فوائد قرض بنكي",
         0, 0, 30000, 0, 30000, 0],

        # ─── التزامات متداولة ───
        ["2110", "التزامات متداولة", "ذمم دائنة تجارية", "موردين",
         0, 380000, 3800000, 3920000, 0, 500000],
        ["2140", "التزامات متداولة", "رواتب مستحقة", "رواتب مستحقة",
         0, 40000, 720000, 750000, 0, 70000],
        ["2160", "التزامات متداولة", "ضريبة قيمة مضافة مخرجات", "ض.ق.م مخرجات",
         0, 80000, 780000, 830000, 0, 130000],
        ["2150", "التزامات متداولة", "مصروفات مستحقة", "مصروفات مستحقة أخرى",
         0, 15000, 15000, 25000, 0, 25000],

        # ─── التزامات غير متداولة ───
        ["2210", "التزامات غير متداولة", "قروض بنكية طويلة الأجل", "قرض بنك الراجحي",
         0, 500000, 100000, 0, 0, 400000],
        ["2230", "التزامات غير متداولة", "مخصص مكافأة نهاية الخدمة", "مكافأة نهاية الخدمة",
         0, 80000, 0, 30000, 0, 110000],

        # ─── حقوق ملكية ───
        ["3010", "حقوق ملكية", "رأس المال المدفوع", "رأس المال",
         0, 800000, 0, 0, 0, 800000],
        ["3030", "حقوق ملكية", "أرباح مبقاة", "أرباح مبقاة سنوات سابقة",
         0, 530000, 0, 0, 0, 530000],
    ]

    for acc in accounts:
        ws.append(acc)

    wb.save(filepath)
    return filepath


def run_test():
    """Run the full analysis pipeline and print results."""
    # Create test file
    filepath = "/tmp/test_trial_balance.xlsx"
    create_test_trial_balance(filepath)
    print("✅ Created test trial balance")

    # Run analysis
    from app.services.orchestrator import AnalysisOrchestrator
    orch = AnalysisOrchestrator()
    result = orch.analyze(filepath=filepath, industry="retail")

    print(f"\n{'═' * 60}")
    print(f"  APEX Financial Engine v2 — Test Results")
    print(f"{'═' * 60}")

    if not result.get("success"):
        print(f"❌ FAILED: {result.get('error')}")
        return

    meta = result["meta"]
    conf = result["confidence"]
    print(f"\n📋 الشركة: {meta.get('company_name', 'غير محدد')}")
    print(f"📅 الفترة: {meta.get('period', 'غير محدد')}")
    print(f"📊 عدد الحسابات: {meta.get('total_accounts')}")
    print(f"📁 تنسيق الملف: {meta.get('file_format')}")

    # Classification
    cls = result["classification"]["summary"]
    print(f"\n{'─' * 40}")
    print(f"📌 التصنيف:")
    print(f"   مصنّف: {cls['mapped_accounts']} / {cls['total_accounts']}")
    print(f"   غير مصنّف: {cls['unmapped_accounts_count']}")
    print(f"   متوسط الثقة: {cls['average_confidence']:.1%}")
    print(f"   الجودة: {cls['quality_label']}")
    if cls['unmapped_accounts']:
        print(f"   ⚠️ حسابات غير مصنّفة:")
        for u in cls['unmapped_accounts'][:5]:
            print(f"      - {u['name']} ({u['tab']})")

    # Income Statement
    inc = result["income_statement"]
    print(f"\n{'─' * 40}")
    print(f"📊 قائمة الدخل:")
    print(f"   الإيرادات:          {inc['revenue']:>15,.2f}")
    print(f"   مرتجع مبيعات:      {inc['sales_returns']:>15,.2f}")
    print(f"   صافي الإيرادات:     {inc['net_revenue']:>15,.2f}")
    print(f"   تكلفة المبيعات:     {inc['cogs']:>15,.2f} ({inc['cogs_method']})")
    print(f"   مجمل الربح:         {inc['gross_profit']:>15,.2f}")
    print(f"   م. إدارية:          {inc['admin_expenses']:>15,.2f}")
    print(f"   م. بيع وتسويق:     {inc['selling_expenses']:>15,.2f}")
    print(f"   الربح التشغيلي:     {inc['operating_profit']:>15,.2f}")
    print(f"   EBITDA:             {inc['ebitda']:>15,.2f}")
    print(f"   تكاليف تمويل:       {inc['finance_cost']:>15,.2f}")
    print(f"   صافي الربح:         {inc['net_profit']:>15,.2f}")

    # Balance Sheet
    bs = result["balance_sheet"]
    print(f"\n{'─' * 40}")
    print(f"📊 الميزانية:")
    print(f"   أصول متداولة:       {bs['current_assets']['total']:>15,.2f}")
    print(f"   أصول غير متداولة:   {bs['non_current_assets']['total']:>15,.2f}")
    print(f"   إجمالي الأصول:      {bs['total_assets']:>15,.2f}")
    print(f"   التزامات متداولة:   {bs['current_liabilities']['total']:>15,.2f}")
    print(f"   التزامات غير متداولة: {bs['non_current_liabilities']['total']:>15,.2f}")
    print(f"   إجمالي الالتزامات:  {bs['total_liabilities']:>15,.2f}")
    print(f"   حقوق الملكية:       {bs['equity']['total']:>15,.2f}")
    print(f"   فحص التوازن:        {bs['balance_check']:>15,.2f} {'✅' if bs['is_balanced'] else '❌'}")

    # Cash Flow
    cf = result.get("cash_flow", {})
    if cf:
        print(f"\n{'─' * 40}")
        print(f"📊 التدفقات النقدية (confidence: {cf.get('confidence', 0):.0%}):")
        op = cf.get("operating", {})
        print(f"   تدفقات تشغيلية:    {op.get('net_operating_cf', 0):>15,.2f}")
        print(f"   تدفقات استثمارية:   {cf.get('investing', {}).get('net_investing_cf', 0):>15,.2f}")
        print(f"   تدفقات تمويلية:     {cf.get('financing', {}).get('net_financing_cf', 0):>15,.2f}")
        print(f"   صافي التغير:        {cf.get('net_cash_change', 0):>15,.2f}")

    # Ratios
    ratios = result.get("ratios", {})
    print(f"\n{'─' * 40}")
    print(f"📊 النسب المالية:")
    prof = ratios.get("profitability", {})
    liq = ratios.get("liquidity", {})
    lev = ratios.get("leverage", {})
    eff = ratios.get("efficiency", {})
    for label, val in [
        ("هامش مجمل الربح", prof.get("gross_margin_pct")),
        ("هامش صافي الربح", prof.get("net_margin_pct")),
        ("EBITDA margin", prof.get("ebitda_margin_pct")),
        ("ROA", prof.get("roa_pct")),
        ("ROE", prof.get("roe_pct")),
        ("نسبة التداول", liq.get("current_ratio")),
        ("النسبة السريعة", liq.get("quick_ratio")),
        ("الدين/الأصول", lev.get("debt_to_assets_pct")),
        ("دوران الأصول", eff.get("asset_turnover")),
        ("DSO", eff.get("dso")),
        ("أيام المخزون", eff.get("days_in_inventory")),
    ]:
        if val is not None:
            print(f"   {label}: {val}")

    # Readiness
    readiness = result.get("readiness", {})
    if readiness:
        print(f"\n{'─' * 40}")
        print(f"📊 الجاهزية التمويلية:")
        print(f"   الدرجة: {readiness.get('score', 0):.0f} / 100")
        print(f"   التصنيف: {readiness.get('label', '')}")
        breakdown = readiness.get("breakdown", {})
        for k, v in breakdown.items():
            print(f"   {k}: {v:.1f}")

    # Validations
    vals = result.get("validations", [])
    val_sum = result.get("validation_summary", {})
    print(f"\n{'─' * 40}")
    print(f"🔍 التحققات:")
    print(f"   أخطاء: {val_sum.get('errors', 0)} | تحذيرات: {val_sum.get('warnings', 0)} | معلومات: {val_sum.get('info', 0)}")
    print(f"   يمكن اعتماد التقرير: {'✅ نعم' if val_sum.get('can_approve') else '❌ لا'}")
    for v in vals:
        icon = "❌" if v["severity"] == "ERROR" else "⚠️" if v["severity"] == "WARNING" else "ℹ️"
        print(f"   {icon} [{v['code']}] {v['message']}")

    # Confidence
    print(f"\n{'─' * 40}")
    print(f"🎯 مؤشر الثقة:")
    print(f"   الإجمالي: {conf['overall']:.1%} — {conf['label']}")
    print(f"   التصنيف: {conf['mapping']:.1%}")
    print(f"   التحقق: {conf['validation']:.1%}")
    print(f"   الاكتمال: {conf['completeness']:.1%}")

    print(f"\n{'═' * 60}")

    # Save full JSON for inspection
    output_path = "/tmp/apex_v2_test_result.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"📄 Full JSON saved to: {output_path}")

    return result


if __name__ == "__main__":
    run_test()
