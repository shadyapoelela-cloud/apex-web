import 'package:flutter/material.dart';

/// Wave 129 — Employee Wellness & Engagement
class EmployeeWellnessScreen extends StatefulWidget {
  const EmployeeWellnessScreen({super.key});
  @override
  State<EmployeeWellnessScreen> createState() => _EmployeeWellnessScreenState();
}

class _EmployeeWellnessScreenState extends State<EmployeeWellnessScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'استطلاعات النبض'), Tab(text: 'البرامج'), Tab(text: 'الصحة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_pulseTab(), _programsTab(), _healthTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF004D40)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.favorite, color: Color(0xFF004D40), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('صحة وسعادة الموظفين', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('استطلاعات النبض، البرامج الصحية، الدعم النفسي', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('eNPS', '+42', Icons.sentiment_very_satisfied, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('رضا الوظيفة', '4.6/5', Icons.mood, const Color(0xFFD4AF37))),
    Expanded(child: _kpi('Burnout Risk', 'منخفض', Icons.health_and_safety, const Color(0xFF00695C))),
    Expanded(child: _kpi('مشاركة البرامج', '87%', Icons.group_add, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _pulseTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _pulses.length, itemBuilder: (_, i) {
    final p = _pulses[i]; final score = p.score / 5.0;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${p.score}/5', style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor(p.score), fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        Text('${p.responses} رد • ${p.responseRate}% معدل المشاركة', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: score, minHeight: 8, backgroundColor: Colors.black12, valueColor: AlwaysStoppedAnimation(_scoreColor(p.score)))),
        if (p.trend != 0) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
          Icon(p.trend > 0 ? Icons.trending_up : Icons.trending_down, size: 14, color: p.trend > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
          const SizedBox(width: 4),
          Text('${p.trend > 0 ? '+' : ''}${p.trend}% منذ الشهر الماضي', style: TextStyle(fontSize: 11, color: p.trend > 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
        ])),
      ]),
    ));
  });

  Widget _programsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _programs.length, itemBuilder: (_, i) {
    final p = _programs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _categoryColor(p.category).withValues(alpha: 0.15),
        child: Icon(_categoryIcon(p.category), color: _categoryColor(p.category))),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.description, style: const TextStyle(fontSize: 11)),
        Text('${p.participants} مشارك • ${p.category}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: const Text('نشط', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _healthTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _health.length, itemBuilder: (_, i) {
    final h = _health[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(h.icon, color: const Color(0xFF00695C)),
          const SizedBox(width: 8),
          Expanded(child: Text(h.metric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(h.value, style: TextStyle(fontWeight: FontWeight.bold, color: _healthColor(h.status))),
        ]),
        Text(h.detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💚 eNPS', '+42 — يصنف ضمن "ممتاز" (أعلى الصناعة 35%)', const Color(0xFF2E7D32)),
    _insight('🧘 Burnout Risk', '12% من الموظفين في مخاطر — خطة دعم مفعّلة', const Color(0xFFE65100)),
    _insight('🏃 الأنشطة الرياضية', '68% شاركوا في التحدي الرياضي الشهري', const Color(0xFFD4AF37)),
    _insight('😊 الصحة النفسية', '24 جلسة استشارة نفسية مجانية مستخدمة', const Color(0xFF00695C)),
    _insight('🎓 التطوير المهني', '92% من الموظفين شاركوا في تدريب', const Color(0xFF4A148C)),
    _insight('🏖️ Work-Life Balance', '4.2/5 — تحسن 0.3 بعد سياسة Flexible Hours', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _scoreColor(double s) {
    if (s >= 4) return const Color(0xFF2E7D32);
    if (s >= 3) return const Color(0xFFD4AF37);
    if (s >= 2) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  Color _categoryColor(String c) {
    if (c.contains('جسدية')) return const Color(0xFF2E7D32);
    if (c.contains('نفسية')) return const Color(0xFF00695C);
    if (c.contains('مالية')) return const Color(0xFFD4AF37);
    if (c.contains('مهنية')) return const Color(0xFF4A148C);
    if (c.contains('اجتماعية')) return const Color(0xFF1A237E);
    return Colors.black54;
  }

  IconData _categoryIcon(String c) {
    if (c.contains('جسدية')) return Icons.fitness_center;
    if (c.contains('نفسية')) return Icons.spa;
    if (c.contains('مالية')) return Icons.account_balance_wallet;
    if (c.contains('مهنية')) return Icons.school;
    if (c.contains('اجتماعية')) return Icons.groups;
    return Icons.favorite;
  }

  Color _healthColor(String s) {
    if (s.contains('ممتاز')) return const Color(0xFF2E7D32);
    if (s.contains('جيد')) return const Color(0xFFD4AF37);
    if (s.contains('تحذير')) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  static const List<_Pulse> _pulses = [
    _Pulse('هل تشعر بأن عملك له معنى؟', 4.5, 185, 92, 5),
    _Pulse('هل تتلقى تغذية راجعة منتظمة؟', 4.2, 185, 92, 8),
    _Pulse('هل لديك الأدوات اللازمة للنجاح؟', 4.4, 185, 92, 2),
    _Pulse('هل تشعر بتقدير إنجازاتك؟', 4.0, 185, 92, 12),
    _Pulse('هل التوازن بين العمل والحياة جيد؟', 4.2, 185, 92, 15),
    _Pulse('هل تنصح أصدقاءك بالعمل هنا؟', 4.6, 185, 92, 6),
    _Pulse('هل تشعر بالانتماء للفريق؟', 4.5, 185, 92, 0),
    _Pulse('هل لديك فرص للنمو المهني؟', 3.8, 185, 92, -4),
  ];

  static const List<_Program> _programs = [
    _Program('تحدي 10,000 خطوة', 'اللياقة الجسدية', 'تحدي شهري للمشي بجوائز أسبوعية', 125),
    _Program('جلسات اليوغا الأسبوعية', 'اللياقة الجسدية', 'جلسات مع مدرب معتمد كل ثلاثاء', 48),
    _Program('الاستشارة النفسية المجانية', 'الصحة النفسية', 'أطباء نفسيون متاحون 24/7', 82),
    _Program('التخطيط المالي الشخصي', 'الصحة المالية', 'استشارات + ورش عمل شهرية', 95),
    _Program('Microsoft Certifications', 'التطوير المهني', 'دورات مجانية + امتحانات مدفوعة', 240),
    _Program('فرق الهوايات', 'الصحة الاجتماعية', 'نادي قراءة، كرة قدم، إلكترونيات', 180),
    _Program('الفحص الطبي السنوي', 'الصحة الجسدية', 'فحوصات شاملة في مستشفيات معتمدة', 285),
  ];

  static const List<_Health> _health = [
    _Health('معدل الغياب المرضي', '2.8 يوم/سنة', 'ممتاز', 'أقل من متوسط الصناعة (5.2)', Icons.sick),
    _Health('استخدام التأمين الصحي', '18%', 'جيد', 'معدل استخدام صحي غير مفرط', Icons.local_hospital),
    _Health('التمارين الأسبوعية', '3.2 جلسة', 'جيد', 'أعلى من المتوسط الوطني', Icons.fitness_center),
    _Health('ساعات النوم', '6.8 ساعة', 'تحذير', 'أقل من الموصى به (7-9)', Icons.bedtime),
    _Health('مستوى الإجهاد', '3.2/5', 'جيد', 'مقبول — برامج تخفيف متاحة', Icons.spa),
    _Health('الرضا العام', '4.6/5', 'ممتاز', 'أعلى نتيجة منذ 3 سنوات', Icons.sentiment_very_satisfied),
  ];
}

class _Pulse { final String question; final double score; final int responses, responseRate, trend;
  const _Pulse(this.question, this.score, this.responses, this.responseRate, this.trend); }
class _Program { final String name, category, description; final int participants;
  const _Program(this.name, this.category, this.description, this.participants); }
class _Health { final String metric, value, status, detail; final IconData icon;
  const _Health(this.metric, this.value, this.status, this.detail, this.icon); }
