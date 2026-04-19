import 'package:flutter/material.dart';

/// Wave 142 — Business Intelligence Dashboard (executive 360°)
class BusinessIntelligenceScreen extends StatefulWidget {
  const BusinessIntelligenceScreen({super.key});
  @override
  State<BusinessIntelligenceScreen> createState() => _BusinessIntelligenceScreenState();
}

class _BusinessIntelligenceScreenState extends State<BusinessIntelligenceScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 5, vsync: this); }
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'المبيعات'),
            Tab(text: 'العمليات'),
            Tab(text: 'العملاء'),
            Tab(text: 'الموظفون'),
            Tab(text: 'التنبؤات'),
          ])),
        Expanded(child: TabBarView(controller: _tc, children: [
          _salesTab(), _opsTab(), _customersTab(), _hrTab(), _forecastTab(),
        ])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF0D47A1)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.insights, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ذكاء الأعمال 360°', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Business Intelligence — تحليلات متقدمة + تنبؤات AI', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('إيرادات اليوم', '148K', Icons.today, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('OKRs ✓', '12/14', Icons.flag, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('NPS', '+64', Icons.sentiment_satisfied, const Color(0xFF4A148C))),
    Expanded(child: _kpi('AI Confidence', '94%', Icons.auto_awesome, const Color(0xFF0D47A1))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _salesTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metricCard('إجمالي الإيرادات 2026', '24.8M ر.س', '+18.4% YoY', const Color(0xFF2E7D32), Icons.trending_up),
    _metricCard('الإيرادات الربع الثاني', '6.8M ر.س', '+22% QoQ', const Color(0xFF2E7D32), Icons.trending_up),
    _metricCard('متوسط حجم الصفقة', '48,200 ر.س', '+12% YoY', const Color(0xFFD4AF37), Icons.receipt),
    _metricCard('Pipeline نشط', '18.4M ر.س', '142 صفقة', const Color(0xFF1A237E), Icons.filter_alt),
    _metricCard('Win Rate', '34%', '+5% YoY', const Color(0xFF4A148C), Icons.emoji_events),
    _metricCard('أفضل منتج', 'APEX Enterprise', '8.2M إيرادات', const Color(0xFFD4AF37), Icons.star),
    _topList('🏆 أعلى العملاء (Q2 2026)', [
      ('أرامكو السعودية', '2.8M ر.س'),
      ('بنك الراجحي', '1.9M ر.س'),
      ('سابك', '1.6M ر.س'),
      ('stc', '1.4M ر.س'),
      ('المراعي', '1.1M ر.س'),
    ]),
  ]);

  Widget _opsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metricCard('الفواتير المُصدرة (اليوم)', '285 فاتورة', '248K ر.س', const Color(0xFF1A237E), Icons.receipt),
    _metricCard('معدل الإنتاجية', '92%', '+3% WoW', const Color(0xFF2E7D32), Icons.speed),
    _metricCard('أوامر العمل المفتوحة', '42 أمر', '18 حرج', const Color(0xFFE65100), Icons.work),
    _metricCard('معدل جودة الإنتاج', '96.8%', 'ISO 9001', const Color(0xFF2E7D32), Icons.verified),
    _metricCard('Supply Chain Health', 'ممتاز', '0 delays', const Color(0xFF2E7D32), Icons.local_shipping),
    _topList('📊 أداء الأقسام', [
      ('تقنية المعلومات', '95% ✓'),
      ('المالية والمحاسبة', '92% ✓'),
      ('خدمة العملاء', '89%'),
      ('المبيعات', '88%'),
      ('العمليات', '84%'),
    ]),
  ]);

  Widget _customersTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metricCard('إجمالي العملاء', '2,840', '+18% YoY', const Color(0xFF4A148C), Icons.people),
    _metricCard('عملاء جدد (الشهر)', '128 عميل', 'CAC: 485 ر.س', const Color(0xFFD4AF37), Icons.person_add),
    _metricCard('Churn Rate', '2.8%', '-1.2% YoY', const Color(0xFF2E7D32), Icons.trending_down),
    _metricCard('متوسط LTV', '42,000 ر.س', 'LTV/CAC: 86x', const Color(0xFF2E7D32), Icons.attach_money),
    _metricCard('NPS Score', '+64', '"Leaders" tier', const Color(0xFFD4AF37), Icons.thumb_up),
    _metricCard('Retention @ 90 days', '94%', 'أعلى من الصناعة', const Color(0xFF2E7D32), Icons.loyalty),
    _topList('💬 أكثر القنوات فاعلية', [
      ('Direct Sales', '42% من الإيرادات'),
      ('Referral Program', '28%'),
      ('Inbound Marketing', '18%'),
      ('Partners', '8%'),
      ('Events', '4%'),
    ]),
  ]);

  Widget _hrTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _metricCard('إجمالي الموظفين', '128 موظف', '+14 هذا العام', const Color(0xFF4A148C), Icons.groups),
    _metricCard('نسبة السعودة', '87%', 'فوق المستهدف (80%)', const Color(0xFFD4AF37), Icons.flag),
    _metricCard('eNPS', '+42', '"Excellent" tier', const Color(0xFF2E7D32), Icons.sentiment_very_satisfied),
    _metricCard('معدل الدوران', '8.2%', '-3% YoY', const Color(0xFF2E7D32), Icons.trending_down),
    _metricCard('متوسط زمن التوظيف', '42 يوم', '-8 days YoY', const Color(0xFF2E7D32), Icons.timer),
    _metricCard('ساعات التدريب/موظف', '48 ساعة', 'سنوياً', const Color(0xFFD4AF37), Icons.school),
    _topList('⚡ أعلى الأقسام إنتاجية', [
      ('Engineering', '98% OKRs ✓'),
      ('Product', '95%'),
      ('Marketing', '92%'),
      ('Sales', '88%'),
      ('Operations', '85%'),
    ]),
  ]);

  Widget _forecastTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(color: const Color(0xFF1A237E).withValues(alpha: 0.05), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
        SizedBox(width: 8),
        Text('تنبؤات AI للربع القادم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A237E))),
      ]),
      const SizedBox(height: 12),
      _forecast('الإيرادات', '7.8M ر.س', '92%', const Color(0xFF2E7D32)),
      _forecast('صافي الربح', '1.4M ر.س', '88%', const Color(0xFF2E7D32)),
      _forecast('العملاء الجدد', '180 - 220', '85%', const Color(0xFFD4AF37)),
      _forecast('OKR completion', '88-92%', '94%', const Color(0xFF2E7D32)),
      _forecast('CAC', '~510 ر.س', '78%', const Color(0xFFE65100)),
    ]))),
    const SizedBox(height: 12),
    _alert('⚠️ تنبيه من AI', 'اكتشاف نمط: العملاء في قطاع الطاقة يلغون اشتراكاتهم 3x أسرع', const Color(0xFFC62828)),
    _alert('💡 توصية', 'زيادة فريق Customer Success بـ 3 موظفين سيقلل Churn بـ 40%', const Color(0xFF2E7D32)),
    _alert('📈 فرصة', 'قطاع الصحة يُظهر نمو 45% — زِد جهود التسويق فيه', const Color(0xFFD4AF37)),
    _alert('🎯 ملاحظة', 'متوسط LTV للمنتج B أعلى من A بـ 2.4x — ركّز عليه', const Color(0xFF4A148C)),
  ]);

  Widget _forecast(String label, String value, String confidence, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      const SizedBox(width: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(confidence, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
    ]));

  Widget _metricCard(String title, String value, String subtitle, Color color, IconData icon) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ])),
    ])));

  Widget _topList(String title, List<(String, String)> items) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const Divider(),
      ...items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(it.$1, style: const TextStyle(fontSize: 12))),
          Text(it.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4A148C))),
        ]))),
    ])));

  Widget _alert(String title, String body, Color color) => Card(margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      const SizedBox(height: 4),
      Text(body, style: const TextStyle(fontSize: 12)),
    ])));
}
