import 'package:flutter/material.dart';

/// Wave 118 — ESG Sustainability Reporting (GRI, SASB, TCFD)
class SustainabilityReportScreen extends StatefulWidget {
  const SustainabilityReportScreen({super.key});
  @override
  State<SustainabilityReportScreen> createState() => _SustainabilityReportScreenState();
}

class _SustainabilityReportScreenState extends State<SustainabilityReportScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'البيئي E'), Tab(text: 'الاجتماعي S'), Tab(text: 'الحوكمة G'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_envTab(), _socTab(), _govTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.eco, color: Color(0xFF1B5E20), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تقارير الاستدامة ESG', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('GRI · SASB · TCFD · رؤية 2030', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, color: Colors.white, size: 16), SizedBox(width: 4),
          Text('A+', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('تصنيف ESG', 'A+', Icons.grade, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('CO₂ Reduction', '-28%', Icons.co2, const Color(0xFF1B5E20))),
    Expanded(child: _kpi('السعودة', '87%', Icons.flag, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('تنوع الإدارة', '42%', Icons.diversity_3, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _envTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metric('🌍 انبعاثات الكربون Scope 1', '4,280 tCO₂e', '-22% YoY', const Color(0xFF2E7D32), 0.72),
    _metric('⚡ انبعاثات Scope 2', '2,140 tCO₂e', '-18% YoY', const Color(0xFF2E7D32), 0.68),
    _metric('🏭 انبعاثات Scope 3', '8,920 tCO₂e', '-12% YoY', const Color(0xFFD4AF37), 0.55),
    _metric('💧 استهلاك المياه', '48,200 m³', '-8% YoY', const Color(0xFF1A237E), 0.62),
    _metric('🔋 الطاقة المتجددة', '34% من الإجمالي', '+12% YoY', const Color(0xFF2E7D32), 0.34),
    _metric('♻️ إعادة التدوير', '82% النفايات', '+15% YoY', const Color(0xFF2E7D32), 0.82),
    _metric('🌳 مبادرات التشجير', '12,400 شجرة', '+40% YoY', const Color(0xFF1B5E20), 0.90),
  ]);

  Widget _socTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metric('👥 نسبة السعودة', '87%', '+4% YoY (فوق الهدف 80%)', const Color(0xFFD4AF37), 0.87),
    _metric('♀️ تمكين المرأة', '38% قوى عاملة • 42% إدارة', '+8% YoY', const Color(0xFF4A148C), 0.42),
    _metric('🎓 ساعات التدريب', '48 ساعة/موظف سنوياً', '+24% YoY', const Color(0xFF1A237E), 0.80),
    _metric('🏥 حوادث السلامة', '0.8 لكل مليون ساعة', '-42% YoY', const Color(0xFF2E7D32), 0.92),
    _metric('🏘️ الاستثمار المجتمعي', '4.8M ر.س', '+35% YoY', const Color(0xFF1B5E20), 0.75),
    _metric('🤝 رضا الموظفين', '4.6/5', '+0.3 YoY', const Color(0xFF2E7D32), 0.92),
  ]);

  Widget _govTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metric('🏛️ استقلالية المجلس', '67% أعضاء مستقلين', 'معيار CMA 33%+', const Color(0xFF2E7D32), 0.67),
    _metric('🔍 الشفافية', 'تقارير ربعية + سنوية', '100% في الموعد', const Color(0xFFD4AF37), 1.0),
    _metric('⚖️ سياسة مكافحة الفساد', 'معتمدة من المجلس', 'تدريب 100% موظفين', const Color(0xFF2E7D32), 1.0),
    _metric('🛡️ الأمن السيبراني', 'ISO 27001 معتمد', '0 اختراقات 2025', const Color(0xFF1A237E), 0.95),
    _metric('📋 الامتثال التنظيمي', 'ZATCA + CMA + سابر', '100% متوافق', const Color(0xFF2E7D32), 1.0),
    _metric('🤝 أخلاقيات الموردين', '94% موردين موقعين Code', '+12% YoY', const Color(0xFF4A148C), 0.94),
  ]);

  Widget _metric(String title, String value, String change, Color color, double progress) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(change, style: TextStyle(color: color, fontSize: 11)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.black12, valueColor: AlwaysStoppedAnimation(color))),
      ]),
    ));
  }

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏆 التصنيفات الخارجية', 'MSCI: A+ • Sustainalytics: Low Risk • CDP: B', const Color(0xFF2E7D32)),
    _insight('🎯 Net Zero 2050', 'على المسار — 28% خفض حتى الآن', const Color(0xFF1B5E20)),
    _insight('🇸🇦 رؤية 2030', 'متوافق مع 8 أهداف رئيسية من 12', const Color(0xFFD4AF37)),
    _insight('📈 العائد من الاستدامة', 'توفير 18M ر.س من كفاءة الطاقة', const Color(0xFF2E7D32)),
    _insight('⚠️ مخاطر المناخ (TCFD)', '4 مخاطر متوسطة — خطة تخفيف معتمدة', const Color(0xFFE65100)),
    _insight('✅ التدقيق المستقل', 'تقرير 2025 مُدقق من KPMG + Big 4', const Color(0xFF4A148C)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));
}
