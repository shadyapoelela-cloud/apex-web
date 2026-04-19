import 'package:flutter/material.dart';

/// Wave 144 — Customer Success Platform
class CustomerSuccessScreen extends StatefulWidget {
  const CustomerSuccessScreen({super.key});
  @override
  State<CustomerSuccessScreen> createState() => _CustomerSuccessScreenState();
}

class _CustomerSuccessScreenState extends State<CustomerSuccessScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'Health Score'), Tab(text: 'المخاطر'), Tab(text: 'Upsell'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_healthTab(), _risksTab(), _upsellTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF004D40)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.support, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نجاح العملاء', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Customer Success — Health score + Churn prediction + Upsell', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('صحة العملاء', '87%', Icons.favorite, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('Churn متوقع', '2.8%', Icons.trending_down, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('فرص Upsell', '42', Icons.upgrade, const Color(0xFF4A148C))),
    Expanded(child: _kpi('NPS', '+64', Icons.thumb_up, const Color(0xFF004D40))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _healthTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _customers.length, itemBuilder: (_, i) {
    final c = _customers[i]; final pct = c.healthScore / 100;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(
            color: _scoreColor(c.healthScore).withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(child: Text('${c.healthScore}', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: _scoreColor(c.healthScore))))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${c.plan} • MRR: ${c.mrr}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _scoreColor(c.healthScore).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(c.status, style: TextStyle(color: _scoreColor(c.healthScore), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: pct, minHeight: 6, backgroundColor: Colors.black12,
          valueColor: AlwaysStoppedAnimation(_scoreColor(c.healthScore)))),
        const SizedBox(height: 8),
        Row(children: [
          _signal('استخدام', c.usage),
          _signal('تذاكر', c.tickets),
          _signal('NPS', c.nps),
        ]),
      ]),
    ));
  });

  Widget _signal(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54)),
    Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _risksTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _risks.length, itemBuilder: (_, i) {
    final r = _risks[i];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _severityColor(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.warning_amber, color: _severityColor(r.severity), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(r.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _severityColor(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.severity, style: TextStyle(color: _severityColor(r.severity), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Text('السبب: ${r.reason}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text('الأثر: ${r.impact}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(6)),
          child: Text('✅ الإجراء الموصى به: ${r.action}', style: const TextStyle(fontSize: 11.5))),
      ]),
    ));
  });

  Widget _upsellTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _opportunities.length, itemBuilder: (_, i) {
    final o = _opportunities[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Text('+${o.uplift}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 15)),
        ]),
        Text('الترقية المقترحة: ${o.recommendation}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Text('السبب: ${o.reason}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: o.probability / 100, minHeight: 5, backgroundColor: Colors.black12,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)))),
        const SizedBox(height: 4),
        Text('احتمالية النجاح: ${o.probability}%', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🎯 العملاء في المنطقة الحرجة', '5 عملاء بصحة < 50 — يتطلب تدخل CSM فوري', const Color(0xFFC62828)),
    _insight('💡 فرص Upsell', '42 عميل مؤهل لخطة أعلى — محتمل +1.8M ر.س ARR', const Color(0xFF2E7D32)),
    _insight('📊 معدل Retention', '94% في آخر 90 يوم — أعلى من Industry (80%)', const Color(0xFF2E7D32)),
    _insight('🤝 اجتماعات QBR', '12 QBR هذا الربع — 8 متبقية', const Color(0xFFD4AF37)),
    _insight('💬 CSAT', '4.6/5 — مستقر منذ 6 أشهر', const Color(0xFF4A148C)),
    _insight('🔔 تنبيهات اليوم', '3 عملاء خفّضوا استخدامهم >40% — تدخل مستحسن', const Color(0xFFE65100)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF2E7D32);
    if (s >= 60) return const Color(0xFFD4AF37);
    if (s >= 40) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  Color _severityColor(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return const Color(0xFFD4AF37);
    return const Color(0xFF1A237E);
  }

  static const List<_Customer> _customers = [
    _Customer('شركة الأفق التقني', 'Enterprise', '12,000 ر.س', 92, 'ممتاز', '94% شهري', '2 هذا الشهر', '+82'),
    _Customer('مؤسسة الابتكار', 'Pro', '4,500 ر.س', 78, 'جيد', '78% شهري', '5 هذا الشهر', '+42'),
    _Customer('مطعم الطيبات', 'Starter', '890 ر.س', 45, 'خطر', '28% شهري', '12 هذا الشهر', '-12'),
    _Customer('متجر السلام', 'Starter', '890 ر.س', 62, 'متوسط', '58% شهري', '4 هذا الشهر', '+18'),
    _Customer('شركة الحلول الذكية', 'Pro', '4,500 ر.س', 88, 'ممتاز', '92% شهري', '1 هذا الشهر', '+72'),
    _Customer('مؤسسة الخبرة', 'Enterprise', '18,000 ر.س', 95, 'ممتاز', '98% شهري', '0', '+90'),
    _Customer('أستوديو الإبداع', 'Starter', '890 ر.س', 38, 'خطر حرج', '15% شهري', '18 هذا الشهر', '-24'),
    _Customer('شركة القمة', 'Pro', '4,500 ر.س', 55, 'مراقبة', '42% شهري', '8 هذا الشهر', '+12'),
  ];

  static const List<_Risk> _risks = [
    _Risk('أستوديو الإبداع', 'استخدام منخفض جداً (15%) + NPS سلبي + 18 تذكرة الشهر الحالي', 'عالي احتمال إلغاء', 'حرج',
      'اتصال مباشر من CSM خلال 24 ساعة + تدريب مخصص مجاني'),
    _Risk('مطعم الطيبات', 'انخفاض تدريجي في الاستخدام من 60% → 28% خلال شهرين', 'احتمال downgrade أو إلغاء',
      'عالي', 'اجتماع مراجعة قيمة + عرض ترقية مع خصم للالتزام السنوي'),
    _Risk('شركة القمة', 'زيادة في تذاكر الدعم (8 هذا الشهر) لنفس المشكلة (تكامل API)', 'إحباط من المنتج',
      'متوسط', 'جلسة فنية متخصصة + مراجعة الـ API documentation'),
    _Risk('متجر السلام', 'لم يستخدم الميزات الجديدة منذ 45 يوم', 'انخفاض قيمة مدركة',
      'متوسط', 'webinar عرض للميزات + خصم مؤقت للاشتراك السنوي'),
  ];

  static const List<_Opportunity> _opportunities = [
    _Opportunity('شركة الأفق التقني', 'ترقية من Enterprise إلى Enterprise+', '+4,000 ر.س شهرياً', 92,
      'يستخدم 92% من ميزات الخطة + يطلب AI features الحصرية'),
    _Opportunity('مؤسسة الخبرة', 'إضافة Enterprise Integration Package', '+8,000 ر.س شهرياً', 88,
      'يتعامل مع ERP خارجي + طلب تكاملات متقدمة في 3 tickets'),
    _Opportunity('شركة الحلول الذكية', 'ترقية من Pro إلى Enterprise', '+7,500 ر.س شهرياً', 85,
      'نمو الفريق من 5 إلى 22 مستخدم + يقترب من حد Pro'),
    _Opportunity('مؤسسة الابتكار', 'إضافة AI Suite', '+2,000 ر.س شهرياً', 72,
      'يستخدم Copilot بكثافة + طلب AI Analyst في NPS survey'),
    _Opportunity('بنك الراجحي فرع', 'إضافة Compliance+ Module', '+3,500 ر.س شهرياً', 78,
      'قطاع مصرفي + متطلبات ZATCA + SAMA متقدمة'),
  ];
}

class _Customer { final String name, plan, mrr; final int healthScore; final String status, usage, tickets, nps;
  const _Customer(this.name, this.plan, this.mrr, this.healthScore, this.status, this.usage, this.tickets, this.nps); }
class _Risk { final String customer, reason, impact, severity, action;
  const _Risk(this.customer, this.reason, this.impact, this.severity, this.action); }
class _Opportunity { final String customer, recommendation, uplift; final int probability; final String reason;
  const _Opportunity(this.customer, this.recommendation, this.uplift, this.probability, this.reason); }
