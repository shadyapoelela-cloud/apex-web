import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 109 — Budget Planning Workflow (Anaplan-killer)
class BudgetPlanningScreen extends StatefulWidget {
  const BudgetPlanningScreen({super.key});
  @override
  State<BudgetPlanningScreen> createState() => _BudgetPlanningScreenState();
}

class _BudgetPlanningScreenState extends State<BudgetPlanningScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(child: Column(children: [
          _hero(), _kpis(),
          Container(color: Colors.white, child: TabBar(
            controller: _tc, labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
            indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
            tabs: const [
              Tab(text: 'دورات الموازنة'), Tab(text: 'الموازنات القسمية'), Tab(text: 'سير الاعتماد'), Tab(text: 'التحليلات'),
            ],
          )),
          Expanded(child: TabBarView(controller: _tc, children: [
            _cyclesTab(), _deptsTab(), _workflowTab(), _analyticsTab(),
          ])),
        ])),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.account_tree, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تخطيط الموازنات التعاوني', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('سير عمل Top-Down / Bottom-Up مع التوافق والاعتماد متعدد المستويات', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final total = _depts.fold<double>(0, (s, d) => s + d.budget);
    final approved = _depts.where((d)=>d.status.contains('معتمد')).fold<double>(0, (s, d) => s + d.budget);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('إجمالي الموازنة', _fmtM(total), Icons.pie_chart, const Color(0xFF1A237E))),
      Expanded(child: _kpi('معتمد', _fmtM(approved), Icons.check_circle, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('قيد المراجعة', '${_depts.where((d)=>d.status.contains('مراجعة')).length}', Icons.rate_review, const Color(0xFFE65100))),
      Expanded(child: _kpi('دورة 2026', 'Q2', Icons.calendar_today, core_theme.AC.gold)),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 24), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _cyclesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _cycles.length, itemBuilder: (_, i) {
    final c = _cycles[i]; final progress = c.progress / 100;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _cycleColor(c.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.account_tree, color: _cycleColor(c.status))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${c.year} • ${c.method}', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _cycleColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(c.status, style: TextStyle(color: _cycleColor(c.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: core_theme.AC.bdr, valueColor: AlwaysStoppedAnimation(_cycleColor(c.status)))),
        const SizedBox(height: 6),
        Row(children: [
          Text('${c.progress}% مكتمل', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const Spacer(),
          Text('المهلة: ${c.deadline}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
        ]),
      ]),
    ));
  });

  Widget _deptsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _depts.length, itemBuilder: (_, i) {
    final d = _depts[i]; final variance = d.requested - d.budget;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.business, color: Color(0xFF4A148C))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('المسؤول: ${d.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Row(children: [
            _miniStat('مُعتمد', _fmtM(d.budget)),
            _miniStat('مطلوب', _fmtM(d.requested)),
            _miniStat('الفرق', '${variance >= 0 ? '+' : ''}${_fmtM(variance)}'),
          ]),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _deptColor(d.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(d.status, style: TextStyle(color: _deptColor(d.status), fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _miniStat(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  ]));

  Widget _workflowTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _steps.length, itemBuilder: (_, i) {
    final s = _steps[i]; final done = s.completed;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(
          color: done ? const Color(0xFF2E7D32) : (s.active ? core_theme.AC.gold : core_theme.AC.td),
          shape: BoxShape.circle,
        ), child: Icon(done ? Icons.check : Icons.circle, color: Colors.white, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
            color: done ? core_theme.AC.tp : (s.active ? core_theme.AC.gold : core_theme.AC.td))),
          Text(s.assignee, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          Text(s.description, style: TextStyle(fontSize: 11.5, color: core_theme.AC.tp)),
        ])),
        if (done) Text(s.completedDate, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🎯 دقة التوقعات', '94.2% دقة مقارنة بالفعلي — تحسّن 5% YoY', const Color(0xFF2E7D32)),
    _insight('⏱️ زمن الدورة', '45 يوم من بداية التخطيط للاعتماد (الصناعة 60 يوم)', const Color(0xFF1A237E)),
    _insight('📊 توزيع الموازنة', 'الرواتب 42% • التسويق 18% • العمليات 22% • أخرى 18%', const Color(0xFF4A148C)),
    _insight('⚠️ التجاوزات', '3 أقسام طلبت زيادة > 20% — تحتاج لجنة الموازنة', const Color(0xFFE65100)),
    _insight('✅ معدل الاعتماد', '87% من الطلبات معتمدة دون تعديل', const Color(0xFF2E7D32)),
    _insight('🔄 إعادة التخصيص', '5 طلبات إعادة تخصيص خلال الربع', core_theme.AC.gold),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _cycleColor(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('جاري')) return core_theme.AC.gold;
    if (s.contains('متأخر')) return const Color(0xFFC62828);
    return const Color(0xFF1A237E);
  }

  Color _deptColor(String s) {
    if (s.contains('معتمد')) return const Color(0xFF2E7D32);
    if (s.contains('مراجعة')) return const Color(0xFFE65100);
    if (s.contains('مرفوض')) return const Color(0xFFC62828);
    if (s.contains('مسودة')) return core_theme.AC.ts;
    return const Color(0xFF1A237E);
  }

  String _fmtM(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v/1000000).toStringAsFixed(2)}M';
    if (abs >= 1000) return '${(v/1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  static const List<_Cycle> _cycles = [
    _Cycle('موازنة تشغيلية 2026', '2026', 'Top-Down', 65, '2026-05-31', 'جاري'),
    _Cycle('موازنة رأسمالية 2026', '2026', 'Bottom-Up', 85, '2026-04-30', 'جاري'),
    _Cycle('موازنة تشغيلية 2025', '2025', 'Top-Down', 100, '2025-05-31', 'مكتمل'),
    _Cycle('موازنة 5-سنوات استراتيجية', '2026-2030', 'هجين', 40, '2026-09-30', 'جاري'),
  ];

  static const List<_Dept> _depts = [
    _Dept('المالية والمحاسبة', 'سارة المهندس', 2_400_000, 2_350_000, 'معتمد'),
    _Dept('التسويق والمبيعات', 'خالد الزهراني', 5_800_000, 6_200_000, 'قيد المراجعة'),
    _Dept('العمليات والإنتاج', 'محمد القحطاني', 12_400_000, 12_100_000, 'معتمد'),
    _Dept('الموارد البشرية', 'نورة الشمري', 3_200_000, 3_400_000, 'قيد المراجعة'),
    _Dept('تقنية المعلومات', 'أحمد الغامدي', 4_500_000, 5_800_000, 'قيد المراجعة'),
    _Dept('البحث والتطوير', 'فاطمة السبيعي', 2_800_000, 2_900_000, 'معتمد'),
    _Dept('الشؤون القانونية', 'سعد الدوسري', 1_200_000, 1_100_000, 'معتمد'),
    _Dept('خدمة العملاء', 'هند العتيبي', 1_800_000, 2_400_000, 'مرفوض'),
  ];

  static const List<_Step> _steps = [
    _Step('إطلاق دورة الموازنة', 'الرئيس المالي', 'نشر الإرشادات والأهداف العامة للفترة المالية', true, false, '2026-01-15'),
    _Step('جمع الطلبات من الأقسام', 'مديرو الأقسام', 'كل قسم يقدم طلبه مع المبررات', true, false, '2026-02-28'),
    _Step('المراجعة المالية الأولى', 'قسم المالية', 'تحليل الطلبات والمقارنة بالأداء التاريخي', true, false, '2026-03-15'),
    _Step('لجنة الموازنة', 'اللجنة التنفيذية', 'جلسات المفاوضة والتعديلات', false, true, ''),
    _Step('اعتماد المجلس', 'مجلس الإدارة', 'الاعتماد النهائي للموازنة الكلية', false, false, ''),
    _Step('التوزيع والإبلاغ', 'جميع الأقسام', 'إرسال الموازنات المعتمدة وتفعيل النظام', false, false, ''),
  ];
}

class _Cycle { final String name, year, method; final int progress; final String deadline, status;
  const _Cycle(this.name, this.year, this.method, this.progress, this.deadline, this.status); }
class _Dept { final String name, owner; final double budget, requested; final String status;
  const _Dept(this.name, this.owner, this.budget, this.requested, this.status); }
class _Step { final String title, assignee, description; final bool completed, active; final String completedDate;
  const _Step(this.title, this.assignee, this.description, this.completed, this.active, this.completedDate); }
