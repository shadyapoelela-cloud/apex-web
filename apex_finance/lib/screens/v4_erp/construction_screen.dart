import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 111 — Construction Project Accounting
/// WIP (Work-in-Progress), Retention, %-of-completion, Progress Billing
class ConstructionScreen extends StatefulWidget {
  const ConstructionScreen({super.key});
  @override
  State<ConstructionScreen> createState() => _ConstructionScreenState();
}

class _ConstructionScreenState extends State<ConstructionScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'المشاريع'), Tab(text: 'المستخلصات'), Tab(text: 'المحتجزات'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_projectsTab(), _billingsTab(), _retentionsTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.engineering, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('محاسبة مقاولات البناء', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('WIP + Retention + %-of-completion + Progress Billing', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final total = _projects.fold<double>(0, (s, p) => s + p.contractValue);
    final billed = _projects.fold<double>(0, (s, p) => s + p.billedToDate);
    final retention = _projects.fold<double>(0, (s, p) => s + p.retention);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('قيمة العقود', _fmtM(total), Icons.gavel, const Color(0xFF1A237E))),
      Expanded(child: _kpi('مفوتر', _fmtM(billed), Icons.receipt_long, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('محتجز', _fmtM(retention), Icons.lock, const Color(0xFFE65100))),
      Expanded(child: _kpi('مشاريع نشطة', '${_projects.where((p)=>p.status.contains('نشط')).length}', Icons.construction, core_theme.AC.gold)),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _projectsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _projects.length, itemBuilder: (_, i) {
    final p = _projects[i]; final completion = p.percentComplete / 100; final billedRatio = p.billedToDate / p.contractValue;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.apartment, color: Color(0xFF4A148C))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${p.code} • ${p.client}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(p.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(p.status, style: TextStyle(color: _statusColor(p.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('العقد', _fmt(p.contractValue)),
          _mini('%-إنجاز', '${p.percentComplete}%'),
          _mini('مفوتر', _fmt(p.billedToDate)),
          _mini('محتجز', _fmt(p.retention)),
        ]),
        const SizedBox(height: 8),
        Text('%-الإنجاز المادي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: completion, minHeight: 5, backgroundColor: core_theme.AC.bdr, valueColor: const AlwaysStoppedAnimation(Color(0xFF4A148C)))),
        const SizedBox(height: 4),
        Text('%-المفوتر', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: billedRatio, minHeight: 5, backgroundColor: core_theme.AC.bdr, valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)))),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ]));

  Widget _billingsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _billings.length, itemBuilder: (_, i) {
    final b = _billings[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1), child: const Icon(Icons.receipt_long, color: Color(0xFF2E7D32))),
      title: Text(b.id, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.project, style: const TextStyle(fontSize: 12)),
        Text('${b.period} • ${b.status}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmt(b.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        Text('محتجز: ${_fmt(b.retention)}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _retentionsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _retentions.length, itemBuilder: (_, i) {
    final r = _retentions[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE65100).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.lock_outline, color: Color(0xFFE65100))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.project, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('${r.percentage}% محتجز • الإفراج: ${r.releaseDate}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: (r.released ? const Color(0xFF2E7D32) : const Color(0xFFE65100)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(r.released ? 'مُفرج' : 'محتجز', style: TextStyle(color: r.released ? const Color(0xFF2E7D32) : const Color(0xFFE65100), fontSize: 9, fontWeight: FontWeight.bold))),
          ]),
        ])),
        Text(_fmt(r.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏗️ مشاريع قيد التنفيذ', '6 مشاريع بقيمة 458M ر.س', const Color(0xFF1A237E)),
    _insight('📈 متوسط %-الإنجاز', '52% معدل الإنجاز المادي', const Color(0xFF2E7D32)),
    _insight('💰 إجمالي المحتجز', '22.9M ر.س — يمثل 5% من قيم العقود', const Color(0xFFE65100)),
    _insight('📊 الاعتراف بالإيراد', 'طريقة %-الإنجاز (IFRS 15) — 2.8M ر.س مؤجل', const Color(0xFF4A148C)),
    _insight('⚠️ مشاريع متأخرة', 'مشروعان فاقا المدة المتعاقد عليها', const Color(0xFFC62828)),
    _insight('✅ الامتثال', 'جميع المستخلصات موثقة بحوافظ قياس + ZATCA', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('متأخر')) return const Color(0xFFC62828);
    if (s.contains('مكتمل')) return const Color(0xFF1A237E);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    return core_theme.AC.ts;
  }

  String _fmt(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(2)}M' : '${(v/1000).toStringAsFixed(0)}K';
  String _fmtM(double v) => _fmt(v);

  static const List<_Project> _projects = [
    _Project('CON-001', 'برج الرياض الإداري', 'شركة الاستثمار العقاري', 125_000_000, 65, 81_250_000, 4_062_500, 'نشط'),
    _Project('CON-002', 'مجمع سكني الخبر', 'شركة الأسهم العقارية', 85_000_000, 80, 68_000_000, 3_400_000, 'نشط'),
    _Project('CON-003', 'طريق الدائري الثاني', 'أمانة جدة', 145_000_000, 45, 65_250_000, 6_525_000, 'نشط'),
    _Project('CON-004', 'مستشفى الملك فهد', 'وزارة الصحة', 65_000_000, 92, 59_800_000, 2_990_000, 'نشط'),
    _Project('CON-005', 'مركز تجاري الدمام', 'مجموعة تجارية', 38_000_000, 100, 38_000_000, 1_900_000, 'مكتمل'),
    _Project('CON-006', 'مدرسة نموذجية', 'وزارة التعليم', 12_000_000, 30, 3_600_000, 180_000, 'متأخر'),
  ];

  static const List<_Billing> _billings = [
    _Billing('BILL-2026-0045', 'برج الرياض الإداري', 'أبريل 2026', 8_500_000, 425_000, 'معتمد'),
    _Billing('BILL-2026-0046', 'مستشفى الملك فهد', 'أبريل 2026', 5_200_000, 260_000, 'قيد المراجعة'),
    _Billing('BILL-2026-0047', 'طريق الدائري الثاني', 'أبريل 2026', 12_800_000, 1_280_000, 'معتمد'),
    _Billing('BILL-2026-0048', 'مجمع سكني الخبر', 'مارس 2026', 6_400_000, 320_000, 'مدفوع'),
    _Billing('BILL-2026-0049', 'برج الرياض الإداري', 'مارس 2026', 7_200_000, 360_000, 'مدفوع'),
  ];

  static const List<_Retention> _retentions = [
    _Retention('برج الرياض الإداري', 5, 4_062_500, '2028-03-15', false),
    _Retention('مجمع سكني الخبر', 5, 3_400_000, '2027-09-20', false),
    _Retention('طريق الدائري الثاني', 10, 6_525_000, '2027-12-30', false),
    _Retention('مستشفى الملك فهد', 5, 2_990_000, '2027-06-10', false),
    _Retention('مركز تجاري الدمام', 5, 1_900_000, '2026-06-01', true),
  ];
}

class _Project { final String code, name, client; final double contractValue; final int percentComplete; final double billedToDate, retention; final String status;
  const _Project(this.code, this.name, this.client, this.contractValue, this.percentComplete, this.billedToDate, this.retention, this.status); }
class _Billing { final String id, project, period; final double amount, retention; final String status;
  const _Billing(this.id, this.project, this.period, this.amount, this.retention, this.status); }
class _Retention { final String project; final int percentage; final double amount; final String releaseDate; final bool released;
  const _Retention(this.project, this.percentage, this.amount, this.releaseDate, this.released); }
