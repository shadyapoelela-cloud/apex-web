import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 132 — Valuation Models (DCF, Multiples, LBO)
class ValuationModelsScreen extends StatefulWidget {
  const ValuationModelsScreen({super.key});
  @override
  State<ValuationModelsScreen> createState() => _ValuationModelsScreenState();
}

class _ValuationModelsScreenState extends State<ValuationModelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'DCF'), Tab(text: 'مضاعفات السوق'), Tab(text: 'LBO'), Tab(text: 'ملخص التقييم')])),
        Expanded(child: TabBarView(controller: _tc, children: [_dcfTab(), _multiplesTab(), _lboTab(), _summaryTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.monetization_on, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نماذج التقييم المالي', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('DCF + Market Multiples + LBO — تقييم ثلاثي متكامل', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('Enterprise Value', '42.5M', Icons.business, const Color(0xFF0D47A1))),
    Expanded(child: _kpi('Equity Value', '38.2M', Icons.account_balance, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('EV/EBITDA', '10.2x', Icons.show_chart, core_theme.AC.gold)),
    Expanded(child: _kpi('القيمة لكل سهم', '382 ر.س', Icons.bookmark, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _dcfTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _dcfSection('معدل الخصم WACC', [
      ('تكلفة حقوق الملكية (CAPM)', '14.5%'),
      ('تكلفة الدين بعد الضريبة', '6.8%'),
      ('نسبة الدين', '35%'),
      ('نسبة حقوق الملكية', '65%'),
      ('WACC', '12.5%'),
    ]),
    _dcfSection('التدفقات النقدية المخصومة', [
      ('سنة 1 — 2.1M ÷ 1.125', '1.87M'),
      ('سنة 2 — 2.8M ÷ 1.266', '2.21M'),
      ('سنة 3 — 3.7M ÷ 1.424', '2.60M'),
      ('سنة 4 — 4.7M ÷ 1.602', '2.93M'),
      ('سنة 5 — 5.8M ÷ 1.802', '3.22M'),
      ('القيمة النهائية (Gordon)', '28.5M'),
    ]),
    _dcfSection('النتيجة', [
      ('Enterprise Value', '41.3M ر.س'),
      ('(-) صافي الدين', '(2.8M)'),
      ('Equity Value', '38.5M ر.س'),
      ('لكل سهم (100K سهم)', '385 ر.س'),
    ]),
  ]);

  Widget _dcfSection(String title, List<(String, String)> rows) => Card(margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D47A1))),
      const Divider(),
      ...rows.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
        Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12))),
        Text(r.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]))),
    ])));

  Widget _multiplesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _peers.length, itemBuilder: (_, i) {
    final p = _peers[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(p.sector, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 8),
        Row(children: [
          _multStat('EV/EBITDA', p.evEbitda),
          _multStat('EV/Revenue', p.evRevenue),
          _multStat('P/E', p.pe),
          _multStat('P/B', p.pb),
        ]),
      ]),
    ));
  });

  Widget _multStat(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
  ]));

  Widget _lboTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _dcfSection('هيكل الصفقة', [
      ('سعر الشراء', '45.0M ر.س'),
      ('قسط حقوق الملكية (30%)', '13.5M'),
      ('قسط دين البنك (60%)', '27.0M'),
      ('Mezzanine Debt (10%)', '4.5M'),
    ]),
    _dcfSection('فترة الاحتفاظ — 5 سنوات', [
      ('قيمة الخروج المتوقعة', '82.0M'),
      ('صافي الدين في الخروج', '(12.0M)'),
      ('Equity Value في الخروج', '70.0M'),
      ('Exit Multiple (EV/EBITDA)', '10.3x'),
    ]),
    _dcfSection('عوائد المستثمر', [
      ('MOIC (Money Multiple)', '5.2x'),
      ('IRR سنوي', '39.0%'),
      ('Cash-on-cash (سنوي متوسط)', '18%'),
      ('Payback Period', '3.2 سنة'),
    ]),
  ]);

  Widget _summaryTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📊 نطاق التقييم المجمّع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A148C))),
      const SizedBox(height: 12),
      _rangeBar('DCF', '38.5M', 0.75),
      _rangeBar('Market Multiples', '42.0M', 0.85),
      _rangeBar('LBO Implied', '45.0M', 0.95),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('التقييم الموصى به', style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold)),
          SizedBox(height: 4),
          Text('41.8M ر.س (متوسط ترجيحي)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text('نطاق مقبول: 38.0M - 45.0M', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
      ),
    ]))),
    const SizedBox(height: 10),
    _insight('💡 مقاربة DCF', 'الأكثر دقة لكن حسّاسة لافتراضات WACC ومعدل النمو النهائي'),
    _insight('📈 مضاعفات السوق', 'تعكس واقع السوق لكن تعتمد على جودة النظراء المختارين'),
    _insight('🎯 LBO', 'يعطي حد أقصى يمكن للمستثمر المالي دفعه مع تحقيق IRR مستهدف'),
  ]);

  Widget _rangeBar(String label, String value, double ratio) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 8,
        backgroundColor: core_theme.AC.bdr, valueColor: AlwaysStoppedAnimation(core_theme.AC.gold))),
    ]));

  Widget _insight(String title, String text) => Card(margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E))),
      const SizedBox(height: 4),
      Text(text, style: const TextStyle(fontSize: 12)),
    ])));

  static const List<_Peer> _peers = [
    _Peer('شركة SAR للتقنية', 'تقنية/SaaS', '12.4x', '4.2x', '22x', '3.8x'),
    _Peer('إنتاج المملكة', 'صناعي', '8.2x', '1.8x', '15x', '2.2x'),
    _Peer('المجموعة السعودية', 'متعدد', '9.5x', '2.5x', '18x', '2.8x'),
    _Peer('نخبة التجارة', 'تجزئة', '7.8x', '1.2x', '14x', '1.9x'),
    _Peer('شركة الابتكار', 'تقنية', '11.2x', '3.8x', '20x', '3.5x'),
    _Peer('الوسيط (Median)', '—', '9.5x', '2.5x', '18x', '2.8x'),
  ];
}

class _Peer { final String name, sector, evEbitda, evRevenue, pe, pb;
  const _Peer(this.name, this.sector, this.evEbitda, this.evRevenue, this.pe, this.pb); }
