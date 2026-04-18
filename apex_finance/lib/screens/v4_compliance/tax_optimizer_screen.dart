import 'package:flutter/material.dart';

/// Wave 127 — Tax Planning & Optimization Simulator
class TaxOptimizerScreen extends StatefulWidget {
  const TaxOptimizerScreen({super.key});
  @override
  State<TaxOptimizerScreen> createState() => _TaxOptimizerScreenState();
}

class _TaxOptimizerScreenState extends State<TaxOptimizerScreen> with SingleTickerProviderStateMixin {
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
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
          tabs: const [Tab(text: 'السيناريوهات'), Tab(text: 'فرص التوفير'), Tab(text: 'المعاهدات الضريبية'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_scenariosTab(), _opportunitiesTab(), _treatiesTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF004D40)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.savings, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('محاكي تخطيط الضرائب', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('محاكاة سيناريوهات + اكتشاف فرص التوفير الضريبي', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final savings = _opps.fold<double>(0, (s, o) => s + o.potentialSaving);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('توفير محتمل', '${(savings/1000).toStringAsFixed(0)}K', Icons.savings, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('معدل فعلي', '15.2%', Icons.percent, const Color(0xFF00695C))),
      Expanded(child: _kpi('بعد التحسين', '11.8%', Icons.trending_down, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('سيناريوهات', '${_scenarios.length}', Icons.science, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _scenariosTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _scenarios.length, itemBuilder: (_, i) {
    final s = _scenarios[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(s.description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _compare('الحالي', '${(s.currentTax/1000).toStringAsFixed(0)}K', const Color(0xFFC62828))),
          const Icon(Icons.arrow_forward, color: Colors.black54),
          Expanded(child: _compare('بالسيناريو', '${(s.projectedTax/1000).toStringAsFixed(0)}K', const Color(0xFF2E7D32))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text('توفير\n${((s.currentTax - s.projectedTax)/1000).toStringAsFixed(0)}K',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ]),
      ]),
    ));
  });

  Widget _compare(String l, String v, Color c) => Container(padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
    ]));

  Widget _opportunitiesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _opps.length, itemBuilder: (_, i) {
    final o = _opps[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.savings, color: Color(0xFF2E7D32))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(o.action, style: const TextStyle(fontSize: 11, color: Colors.black87)),
          Text('المرجع: ${o.reference}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+${(o.potentialSaving/1000).toStringAsFixed(0)}K', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          Text('توفير سنوي', style: const TextStyle(fontSize: 9, color: Colors.black54)),
        ]),
      ]),
    ));
  });

  Widget _treatiesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _treaties.length, itemBuilder: (_, i) {
    final t = _treaties[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFF00695C), child: Icon(Icons.public, color: Colors.white)),
      title: Text(t.country, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('WHT على ${t.type}: ${t.rate}% (بدلاً من 20% الافتراضي)', style: const TextStyle(fontSize: 11)),
      trailing: Text('منذ ${t.year}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💰 توفير إجمالي محتمل', '1.2M ر.س سنوياً بتطبيق جميع التوصيات', const Color(0xFF2E7D32)),
    _insight('📊 المعدل الفعلي الحالي', '15.2% — يمكن خفضه إلى 11.8% بالتحسينات', const Color(0xFFD4AF37)),
    _insight('🎯 الفرص المستخدمة', '6 من 14 فرصة متاحة — 43% معدل الاستخدام', const Color(0xFF4A148C)),
    _insight('🌍 معاهدات مطبقة', '12 معاهدة تجنب ازدواج ضريبي', const Color(0xFF00695C)),
    _insight('⚠️ مخاطر BEPS', '3 تعديلات لازمة للامتثال لـ Pillar 2', const Color(0xFFE65100)),
    _insight('📅 المواعيد الحرجة', 'إقرار Zakat قبل 2026-05-31 — 42 يوم متبقي', const Color(0xFFC62828)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  static const List<_Scenario> _scenarios = [
    _Scenario('تحويل النشاط لمنطقة حرة', 'فتح فرع في منطقة KAEC الاقتصادية الخاصة', 4_800_000, 3_600_000),
    _Scenario('إعادة هيكلة بحصة أجنبية', 'إدخال شريك أجنبي 30% يستفيد من معاهدة ضريبية', 4_800_000, 2_880_000),
    _Scenario('استخدام خسائر 2022', 'تحميل خسائر 2022 المتبقية على 2026', 4_800_000, 4_200_000),
    _Scenario('ترحيل التبرعات الخيرية', 'ترحيل 2M تبرعات لم تُستنفد', 4_800_000, 4_500_000),
    _Scenario('هيكلة عقود IFRS 16', 'تحويل عقود تشغيلية إلى رأسمالية', 4_800_000, 4_350_000),
  ];

  static const List<_Opportunity> _opps = [
    _Opportunity('استغلال خصم R&D', 'طالب 150% خصم على إنفاق R&D المؤهل', 'لائحة ZATCA المادة 37', 280_000),
    _Opportunity('تعديلات التسعير التحويلي', 'تحديث TP لمنع تعديلات ZATCA المحتملة', 'OECD TP Guidelines', 480_000),
    _Opportunity('خصم التأمينات الاجتماعية', '100% من GOSI مخصوم قبل Zakat', 'فتوى هيئة الزكاة 2024', 185_000),
    _Opportunity('Zakat على الاستثمارات', 'استبعاد استثمارات طويلة الأجل (>12 شهر)', 'لائحة الزكاة المادة 12', 220_000),
    _Opportunity('تحصيل VAT على الصادرات', 'استرداد VAT المدفوع على مدخلات الصادرات', 'نظام VAT المادة 19', 48_000),
    _Opportunity('ترحيل خسائر رأسمالية', 'خسائر بيع الأصول قابلة للترحيل 5 سنوات', 'نظام الضريبة المادة 28', 62_000),
  ];

  static const List<_Treaty> _treaties = [
    _Treaty('الإمارات العربية المتحدة', 'توزيعات الأرباح', 5, 2009),
    _Treaty('المملكة المتحدة', 'الفوائد', 5, 2008),
    _Treaty('سنغافورة', 'الإتاوات', 10, 2011),
    _Treaty('فرنسا', 'توزيعات الأرباح', 0, 1990),
    _Treaty('ألمانيا', 'الخدمات الفنية', 10, 2008),
    _Treaty('ماليزيا', 'الإتاوات', 8, 2006),
    _Treaty('مصر', 'توزيعات الأرباح', 5, 2017),
    _Treaty('الصين', 'الفوائد', 10, 2006),
  ];
}

class _Scenario { final String name, description; final double currentTax, projectedTax;
  const _Scenario(this.name, this.description, this.currentTax, this.projectedTax); }
class _Opportunity { final String title, action, reference; final double potentialSaving;
  const _Opportunity(this.title, this.action, this.reference, this.potentialSaving); }
class _Treaty { final String country, type; final int rate, year;
  const _Treaty(this.country, this.type, this.rate, this.year); }
