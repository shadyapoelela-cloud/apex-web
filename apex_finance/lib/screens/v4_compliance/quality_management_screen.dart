import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 107 — Quality Management System (QMS) — ISO 9001
class QualityManagementScreen extends StatefulWidget {
  const QualityManagementScreen({super.key});
  @override
  State<QualityManagementScreen> createState() => _QualityManagementScreenState();
}

class _QualityManagementScreenState extends State<QualityManagementScreen> with SingleTickerProviderStateMixin {
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
        body: SafeArea(
          child: Column(children: [
            _hero(), _kpis(),
            Container(color: Colors.white, child: TabBar(
              controller: _tc,
              labelColor: const Color(0xFF4A148C),
              unselectedLabelColor: core_theme.AC.ts,
              indicatorColor: core_theme.AC.gold,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'عدم المطابقة'),
                Tab(text: 'الإجراءات التصحيحية'),
                Tab(text: 'عمليات التدقيق'),
                Tab(text: 'التحليلات'),
              ],
            )),
            Expanded(child: TabBarView(controller: _tc, children: [
              _ncrTab(), _capaTab(), _auditsTab(), _analyticsTab(),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.verified_user, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إدارة الجودة QMS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('نظام إدارة الجودة المتكامل — ISO 9001:2015', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, color: core_theme.AC.gold, size: 16), SizedBox(width: 4),
          Text('ISO 9001', style: TextStyle(color: Colors.white, fontSize: 12)),
        ])),
    ]),
  );

  Widget _kpis() {
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('NCR مفتوح', '${_ncrs.where((n)=>n.status.contains('مفتوح')).length}', Icons.error, const Color(0xFFC62828))),
      Expanded(child: _kpi('CAPA نشط', '${_capas.where((c)=>c.status.contains('قيد')).length}', Icons.build, const Color(0xFFE65100))),
      Expanded(child: _kpi('التدقيقات', '${_audits.length}', Icons.fact_check, const Color(0xFF1A237E))),
      Expanded(child: _kpi('المطابقة', '96.4%', Icons.check_circle, const Color(0xFF2E7D32))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 24), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _ncrTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _ncrs.length, itemBuilder: (_, i) {
    final n = _ncrs[i]; final c = _severityColor(n.severity);
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(Icons.error_outline, color: c)),
      title: Text(n.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.description, style: const TextStyle(fontSize: 12)),
        Text('${n.department} • ${n.date}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(n.severity, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))),
        const SizedBox(height: 4),
        Text(n.status, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _capaTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _capas.length, itemBuilder: (_, i) {
    final c = _capas[i]; final progress = c.progress / 100;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.build_circle, color: Color(0xFF4A148C))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(c.title, style: const TextStyle(fontSize: 12)),
          ])),
          Text('${c.progress}%', style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold)),
        ]),
        const SizedBox(height: 8),
        Text(c.rootCause, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: core_theme.AC.bdr, valueColor: AlwaysStoppedAnimation(core_theme.AC.gold))),
        const SizedBox(height: 6),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _capaStatusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(c.status, style: TextStyle(color: _capaStatusColor(c.status), fontSize: 10, fontWeight: FontWeight.bold))),
          const Spacer(),
          Text('المسؤول: ${c.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
      ]),
    ));
  });

  Widget _auditsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _audits.length, itemBuilder: (_, i) {
    final a = _audits[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.1), child: const Icon(Icons.fact_check, color: Color(0xFF1A237E))),
      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.type} • ${a.auditor}', style: const TextStyle(fontSize: 12)),
        Text('نتائج: ${a.findings} • نقاط عدم مطابقة: ${a.nonConformities}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Text(a.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🎯 معدل الامتثال', '96.4% مطابقة عامة — زيادة 2.3% عن الربع السابق', const Color(0xFF2E7D32)),
    _insight('⚠️ الأقسام الأعلى NCR', 'الإنتاج 34% • المشتريات 22% • المستودعات 18%', const Color(0xFFE65100)),
    _insight('⏱️ متوسط إغلاق CAPA', '12 يوم (الهدف ≤ 14)', const Color(0xFF1A237E)),
    _insight('📊 تكلفة عدم الجودة', '2.8M ر.س — انخفاض 18% YoY', const Color(0xFF2E7D32)),
    _insight('✅ جاهزية ISO 9001', '100% — الشهادة سارية حتى 2027-06', const Color(0xFF2E7D32)),
    _insight('🔄 التدقيق القادم', 'تدقيق مراقبة SGS في 2026-06-15', const Color(0xFF4A148C)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _severityColor(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  Color _capaStatusColor(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('قيد')) return const Color(0xFFE65100);
    if (s.contains('جديد')) return const Color(0xFF1A237E);
    return core_theme.AC.ts;
  }

  static const List<_Ncr> _ncrs = [
    _Ncr('NCR-2026-001', 'مواد خام غير مطابقة — الدفعة 4521', 'الإنتاج', '2026-04-18', 'حرج', 'مفتوح'),
    _Ncr('NCR-2026-002', 'انحراف معايير التغليف', 'التغليف', '2026-04-15', 'عالي', 'قيد المعالجة'),
    _Ncr('NCR-2026-003', 'خطأ في قراءة حساسات الحرارة', 'الإنتاج', '2026-04-14', 'متوسط', 'مفتوح'),
    _Ncr('NCR-2026-004', 'تأخر في فحص الوارد', 'المستودعات', '2026-04-12', 'منخفض', 'مغلق'),
    _Ncr('NCR-2026-005', 'شكوى عميل — عيب تشغيلي', 'خدمة العملاء', '2026-04-10', 'عالي', 'قيد المعالجة'),
    _Ncr('NCR-2026-006', 'خطأ في وثائق الشحن', 'اللوجستيات', '2026-04-08', 'متوسط', 'مغلق'),
  ];

  static const List<_Capa> _capas = [
    _Capa('CAPA-001', 'تحديث إجراء فحص المواد الواردة', 'نقص تدريب فريق الفحص', 'أحمد الغامدي', 75, 'قيد التنفيذ'),
    _Capa('CAPA-002', 'معايرة أجهزة قياس الحرارة', 'عدم الصيانة الدورية', 'فاطمة السبيعي', 40, 'قيد التنفيذ'),
    _Capa('CAPA-003', 'إعادة تدريب فريق التغليف', 'تغيير المورد دون تحديث الإجراءات', 'محمد العتيبي', 100, 'مكتمل'),
    _Capa('CAPA-004', 'تحسين نظام تتبع الشكاوى', 'نظام قديم لا يتتبع كل المراحل', 'نورة الشمري', 20, 'جديد'),
  ];

  static const List<_Audit> _audits = [
    _Audit('تدقيق داخلي ISO 9001', 'داخلي', 'فريق الجودة', '2026-03-15', 14, 3),
    _Audit('تدقيق SGS السنوي', 'طرف ثالث', 'SGS KSA', '2026-02-20', 8, 2),
    _Audit('تدقيق عملية المشتريات', 'داخلي', 'سعد الدوسري', '2026-01-10', 6, 1),
    _Audit('تدقيق متابعة CAPA', 'داخلي', 'فريق الجودة', '2025-12-20', 4, 0),
  ];
}

class _Ncr { final String id, description, department, date, severity, status;
  const _Ncr(this.id, this.description, this.department, this.date, this.severity, this.status); }
class _Capa { final String id, title, rootCause, owner; final int progress; final String status;
  const _Capa(this.id, this.title, this.rootCause, this.owner, this.progress, this.status); }
class _Audit { final String title, type, auditor, date; final int findings, nonConformities;
  const _Audit(this.title, this.type, this.auditor, this.date, this.findings, this.nonConformities); }
