/// V5.2 — Financial Statements using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class FinancialStatementsV52Screen extends StatefulWidget {
  const FinancialStatementsV52Screen({super.key});

  @override
  State<FinancialStatementsV52Screen> createState() => _FinancialStatementsV52ScreenState();
}

class _FinancialStatementsV52ScreenState extends State<FinancialStatementsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  String _statement = 'bs';

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'القوائم المالية',
      subtitleAr: 'Q1 2026 · IFRS Compliant · Approved',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.pivot,
      listBuilder: (_) => _pivot(),
      savedViews: const [
        SavedView(id: 'yr', labelAr: 'سنوي مقارن', icon: Icons.compare_arrows, defaultViewMode: ViewMode.pivot),
        SavedView(id: 'q', labelAr: 'ربع سنوي', icon: Icons.calendar_view_week, defaultViewMode: ViewMode.pivot),
        SavedView(id: 'monthly', labelAr: 'شهري', icon: Icons.date_range, defaultViewMode: ViewMode.pivot),
        SavedView(id: 'consolidated', labelAr: 'موحّدة (Group)', icon: Icons.merge, defaultViewMode: ViewMode.pivot, isShared: true),
      ],
      filterChips: [
        FilterChipDef(id: 'bs', labelAr: 'الميزانية', icon: Icons.balance, color: _navy, active: _statement == 'bs'),
        FilterChipDef(id: 'is', labelAr: 'الأرباح والخسائر', icon: Icons.trending_up, color: _gold, active: _statement == 'is'),
        FilterChipDef(id: 'cf', labelAr: 'التدفقات النقدية', icon: Icons.water_drop, color: core_theme.AC.info, active: _statement == 'cf'),
        FilterChipDef(id: 'eq', labelAr: 'حقوق الملكية', icon: Icons.donut_large, color: core_theme.AC.ok, active: _statement == 'eq'),
      ],
      onFilterToggle: (id) => setState(() => _statement = id),
      onCreateNew: () {},
      createLabelAr: 'توليد تقرير',
      pivotBuilder: (_) => _pivot(),
      chartBuilder: (_) => _chart(),
    );
  }

  Widget _pivot() {
    switch (_statement) {
      case 'is':
        return _incomeStatement();
      case 'cf':
        return _cashFlow();
      case 'eq':
        return _equity();
      default:
        return _balanceSheet();
    }
  }

  Widget _balanceSheet() {
    const rows = [
      ('الأصول المتداولة', null, null, null, true, false),
      ('  النقدية والبنوك', '3,240,000', '2,890,000', '+12.1%', false, false),
      ('  الذمم المدينة', '4,580,000', '4,120,000', '+11.2%', false, false),
      ('  المخزون', '2,890,000', '3,140,000', '-7.9%', false, false),
      ('  مصروفات مدفوعة مقدماً', '420,000', '380,000', '+10.5%', false, false),
      ('إجمالي الأصول المتداولة', '11,130,000', '10,530,000', '+5.7%', false, true),
      ('الأصول غير المتداولة', null, null, null, true, false),
      ('  الأصول الثابتة (صافي)', '18,400,000', '19,200,000', '-4.2%', false, false),
      ('  الاستثمارات طويلة الأجل', '5,600,000', '5,600,000', '0%', false, false),
      ('  الأصول غير الملموسة', '1,840,000', '1,920,000', '-4.2%', false, false),
      ('إجمالي الأصول غير المتداولة', '25,840,000', '26,720,000', '-3.3%', false, true),
      ('', null, null, null, false, false),
      ('إجمالي الأصول', '36,970,000', '37,250,000', '-0.8%', false, true),
      ('', null, null, null, false, false),
      ('الالتزامات المتداولة', null, null, null, true, false),
      ('  الذمم الدائنة', '2,840,000', '2,620,000', '+8.4%', false, false),
      ('  قروض قصيرة الأجل', '1,500,000', '1,800,000', '-16.7%', false, false),
      ('  ضرائب مستحقة', '680,000', '540,000', '+25.9%', false, false),
      ('إجمالي الالتزامات المتداولة', '5,020,000', '4,960,000', '+1.2%', false, true),
      ('الالتزامات غير المتداولة', null, null, null, true, false),
      ('  قروض طويلة الأجل', '8,400,000', '9,800,000', '-14.3%', false, false),
      ('  مخصصات', '1,200,000', '1,140,000', '+5.3%', false, false),
      ('إجمالي الالتزامات غير المتداولة', '9,600,000', '10,940,000', '-12.2%', false, true),
      ('', null, null, null, false, false),
      ('إجمالي الالتزامات', '14,620,000', '15,900,000', '-8.1%', false, true),
      ('حقوق الملكية', '22,350,000', '21,350,000', '+4.7%', false, true),
      ('', null, null, null, false, false),
      ('إجمالي الالتزامات وحقوق الملكية', '36,970,000', '37,250,000', '-0.8%', false, true),
    ];
    return _renderStatement('قائمة المركز المالي (Balance Sheet)', ['البند', '2026 Q1', '2025', 'التغير'], rows);
  }

  Widget _incomeStatement() {
    const rows = [
      ('الإيرادات', null, null, null, true, false),
      ('  مبيعات المنتجات', '14,200,000', '11,800,000', '+20.3%', false, false),
      ('  إيرادات الخدمات', '4,800,000', '3,400,000', '+41.2%', false, false),
      ('إجمالي الإيرادات', '19,000,000', '15,200,000', '+25.0%', false, true),
      ('', null, null, null, false, false),
      ('تكلفة المبيعات', null, null, null, true, false),
      ('  تكلفة المنتجات', '(7,100,000)', '(6,300,000)', '+12.7%', false, false),
      ('  تكلفة الخدمات', '(1,900,000)', '(1,400,000)', '+35.7%', false, false),
      ('إجمالي تكلفة المبيعات', '(9,000,000)', '(7,700,000)', '+16.9%', false, true),
      ('', null, null, null, false, false),
      ('مجمل الربح', '10,000,000', '7,500,000', '+33.3%', false, true),
      ('هامش مجمل الربح', '52.6%', '49.3%', '+3.3pp', false, false),
      ('', null, null, null, false, false),
      ('المصروفات التشغيلية', null, null, null, true, false),
      ('  مصروفات بيعية', '(1,800,000)', '(1,400,000)', '+28.6%', false, false),
      ('  مصروفات إدارية', '(1,200,000)', '(1,100,000)', '+9.1%', false, false),
      ('  مصروفات أخرى', '(400,000)', '(350,000)', '+14.3%', false, false),
      ('إجمالي المصروفات التشغيلية', '(3,400,000)', '(2,850,000)', '+19.3%', false, true),
      ('', null, null, null, false, false),
      ('الربح التشغيلي (EBIT)', '6,600,000', '4,650,000', '+41.9%', false, true),
      ('', null, null, null, false, false),
      ('إيرادات/مصروفات تمويلية', '(420,000)', '(480,000)', '-12.5%', false, false),
      ('الربح قبل الضريبة', '6,180,000', '4,170,000', '+48.2%', false, true),
      ('الزكاة والضرائب', '(618,000)', '(417,000)', '+48.2%', false, false),
      ('', null, null, null, false, false),
      ('صافي الربح', '5,562,000', '3,753,000', '+48.2%', false, true),
    ];
    return _renderStatement('قائمة الأرباح والخسائر (Income Statement)', ['البند', 'Q1 2026', 'Q1 2025', 'التغير'], rows);
  }

  Widget _cashFlow() {
    const rows = [
      ('التدفقات من الأنشطة التشغيلية', null, null, null, true, false),
      ('  صافي الربح', '5,562,000', '3,753,000', '+48.2%', false, false),
      ('  الإهلاك والاستهلاك', '800,000', '720,000', '+11.1%', false, false),
      ('  التغير في الذمم المدينة', '(460,000)', '(340,000)', '+35.3%', false, false),
      ('  التغير في المخزون', '250,000', '(180,000)', 'إيجابي', false, false),
      ('  التغير في الذمم الدائنة', '220,000', '140,000', '+57.1%', false, false),
      ('صافي التدفق التشغيلي', '6,372,000', '4,093,000', '+55.7%', false, true),
      ('', null, null, null, false, false),
      ('التدفقات من الأنشطة الاستثمارية', null, null, null, true, false),
      ('  شراء أصول ثابتة', '(1,200,000)', '(840,000)', '+42.9%', false, false),
      ('  بيع استثمارات', '400,000', '0', 'جديد', false, false),
      ('صافي التدفق الاستثماري', '(800,000)', '(840,000)', '-4.8%', false, true),
      ('', null, null, null, false, false),
      ('التدفقات من الأنشطة التمويلية', null, null, null, true, false),
      ('  سداد قروض', '(1,400,000)', '(800,000)', '+75.0%', false, false),
      ('  توزيعات أرباح', '(1,500,000)', '(1,000,000)', '+50.0%', false, false),
      ('صافي التدفق التمويلي', '(2,900,000)', '(1,800,000)', '+61.1%', false, true),
      ('', null, null, null, false, false),
      ('صافي التغير في النقدية', '2,672,000', '1,453,000', '+83.9%', false, true),
      ('النقدية في بداية الفترة', '2,890,000', '1,437,000', '+101.1%', false, false),
      ('النقدية في نهاية الفترة', '5,562,000', '2,890,000', '+92.5%', false, true),
    ];
    return _renderStatement('قائمة التدفقات النقدية (Cash Flow Statement)', ['البند', 'Q1 2026', 'Q1 2025', 'التغير'], rows);
  }

  Widget _equity() {
    const rows = [
      ('رأس المال المدفوع', '10,000,000', '10,000,000', '0%', false, true),
      ('الاحتياطي النظامي', '2,500,000', '2,500,000', '0%', false, true),
      ('أرباح محتجزة — بداية الفترة', '8,850,000', '6,097,000', '+45.1%', false, true),
      ('صافي ربح الفترة', '5,562,000', '3,753,000', '+48.2%', false, true),
      ('توزيعات أرباح', '(1,500,000)', '(1,000,000)', '+50.0%', false, true),
      ('تغيّرات احتياطي القيمة العادلة', '(62,000)', '0', 'جديد', false, true),
      ('', null, null, null, false, false),
      ('إجمالي حقوق الملكية', '25,350,000', '21,350,000', '+18.7%', false, true),
    ];
    return _renderStatement('قائمة التغيرات في حقوق الملكية', ['البند', 'Q1 2026', '2025', 'التغير'], rows);
  }

  Widget _renderStatement(String title, List<String> headers, List<(String, String?, String?, String?, bool, bool)> rows) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('IFRS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: core_theme.AC.ok))),
          const Spacer(),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 14), label: Text('تصدير')),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(10),
                color: _navy,
                child: Row(children: [
                  Expanded(flex: 3, child: Text(headers[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(headers[1], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                  Expanded(child: Text(headers[2], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                  Expanded(child: Text(headers[3], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    if (r.$1.isEmpty) return const SizedBox(height: 12);
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: r.$5 ? 10 : 6),
                      decoration: BoxDecoration(
                        color: r.$5 ? core_theme.AC.navy3 : (r.$6 ? _gold.withValues(alpha: 0.05) : null),
                        border: r.$6 ? Border(top: BorderSide(color: _gold, width: 1.5), bottom: BorderSide(color: _gold, width: 0.5)) : Border(bottom: BorderSide(color: core_theme.AC.navy3)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(r.$1, style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$5 || r.$6 ? FontWeight.w800 : FontWeight.w500, color: r.$5 || r.$6 ? _navy : core_theme.AC.tp))),
                        Expanded(child: Text(r.$2 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                        Expanded(child: Text(r.$3 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, fontFamily: 'monospace', color: core_theme.AC.ts), textAlign: TextAlign.end)),
                        Expanded(child: Text(r.$4 ?? '', style: TextStyle(fontSize: r.$5 || r.$6 ? 13 : 12, fontWeight: r.$6 ? FontWeight.w800 : FontWeight.w500, color: (r.$4 ?? '').contains('-') ? core_theme.AC.err : core_theme.AC.ok), textAlign: TextAlign.end)),
                      ]),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chart() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإيرادات vs الأرباح — 4 أرباع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...[
          ('Q2 2025', 14.8, 3.4),
          ('Q3 2025', 16.2, 4.1),
          ('Q4 2025', 17.8, 4.8),
          ('Q1 2026', 19.0, 5.5),
        ].map((q) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                SizedBox(width: 80, child: Text('الإيرادات', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: q.$2 / 20, minHeight: 14, backgroundColor: core_theme.AC.bdr, color: _navy))),
                const SizedBox(width: 10),
                Text('${q.$2}M ر.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                SizedBox(width: 80, child: Text('صافي الربح', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: q.$3 / 20, minHeight: 14, backgroundColor: core_theme.AC.bdr, color: _gold))),
                const SizedBox(width: 10),
                Text('${q.$3}M ر.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
              ]),
            ]))),
      ]),
    );
  }
}
