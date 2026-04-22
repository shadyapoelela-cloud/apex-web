import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 115 — Franchise Management
class FranchiseManagementScreen extends StatefulWidget {
  const FranchiseManagementScreen({super.key});
  @override
  State<FranchiseManagementScreen> createState() => _FranchiseManagementScreenState();
}

class _FranchiseManagementScreenState extends State<FranchiseManagementScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الفروع'), Tab(text: 'الأتاوى'), Tab(text: 'الجودة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_branchesTab(), _royaltiesTab(), _qualityTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.store_mall_directory, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إدارة الامتياز التجاري', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('تتبع الفروع، الأتاوى، معايير الجودة والامتثال', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final totalSales = _branches.fold<double>(0, (s, b) => s + b.monthlySales);
    final totalRoyalty = _royalties.fold<double>(0, (s, r) => s + r.amount);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('الفروع', '${_branches.length}', Icons.store, const Color(0xFF1A237E))),
      Expanded(child: _kpi('مبيعات الشهر', '${(totalSales/1000000).toStringAsFixed(1)}M', Icons.trending_up, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('أتاوى شهرية', '${(totalRoyalty/1000).toStringAsFixed(0)}K', Icons.percent, core_theme.AC.gold)),
      Expanded(child: _kpi('متوسط الجودة', '92%', Icons.star, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _branchesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _branches.length, itemBuilder: (_, i) {
    final b = _branches[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.store, color: Color(0xFF4A148C))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${b.franchisee} • ${b.city}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Row(children: [
            _mini('مبيعات', '${(b.monthlySales/1000).toStringAsFixed(0)}K'),
            _mini('تقييم', '${b.qualityScore}%'),
            _mini('افتتح', b.openedYear),
          ]),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: _statusColor(b.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(b.status, style: TextStyle(color: _statusColor(b.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ]));

  Widget _royaltiesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _royalties.length, itemBuilder: (_, i) {
    final r = _royalties[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: core_theme.AC.gold.withValues(alpha: 0.2), child: Icon(Icons.percent, color: core_theme.AC.gold)),
      title: Text(r.branch, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('${r.period} • ${r.rate}% من المبيعات', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${r.amount.toStringAsFixed(0)} ر.س', style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: (r.paid ? const Color(0xFF2E7D32) : const Color(0xFFE65100)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(r.paid ? 'مدفوع' : 'مستحق', style: TextStyle(color: r.paid ? const Color(0xFF2E7D32) : const Color(0xFFE65100), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _qualityTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _audits.length, itemBuilder: (_, i) {
    final a = _audits[i]; final score = a.score / 100;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(a.branch, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${a.score}%', style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor(a.score))),
        ]),
        Text('تدقيق: ${a.auditor} • ${a.date}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: score, minHeight: 6, backgroundColor: core_theme.AC.bdr, valueColor: AlwaysStoppedAnimation(_scoreColor(a.score)))),
        const SizedBox(height: 6),
        Text(a.notes, style: TextStyle(fontSize: 11, color: core_theme.AC.tp)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏪 التوسع', '6 فروع جديدة هذا العام — نمو 20% في الشبكة', const Color(0xFF2E7D32)),
    _insight('💰 نمو الإيرادات', '18.4% YoY على مستوى الشبكة', core_theme.AC.gold),
    _insight('⭐ معدل الجودة', '92% — أعلى من معيار العلامة التجارية (85%)', const Color(0xFF4A148C)),
    _insight('📍 التغطية الجغرافية', '8 مدن سعودية + 2 دولة خليجية', const Color(0xFF1A237E)),
    _insight('⚠️ فروع تحت المراقبة', '2 فرع تحت برنامج تحسين الأداء', const Color(0xFFE65100)),
    _insight('📊 معدل نجاح الفرع', '94% خلال أول سنتين', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('مراقبة')) return const Color(0xFFE65100);
    if (s.contains('مغلق')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  Color _scoreColor(int s) {
    if (s >= 90) return const Color(0xFF2E7D32);
    if (s >= 75) return core_theme.AC.gold;
    if (s >= 60) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  static const List<_Branch> _branches = [
    _Branch('فرع الرياض العليا', 'مجموعة الرياض', 'الرياض', '2022', 1_850_000, 95, 'نشط'),
    _Branch('فرع جدة الشاطئ', 'شركة الشاطئ الغربي', 'جدة', '2021', 2_100_000, 92, 'نشط'),
    _Branch('فرع الخبر كورنيش', 'مؤسسة الخليج', 'الخبر', '2023', 1_480_000, 88, 'نشط'),
    _Branch('فرع مكة المكرمة', 'شركة الحرم التجارية', 'مكة المكرمة', '2020', 2_450_000, 96, 'نشط'),
    _Branch('فرع المدينة المنورة', 'مؤسسة طيبة', 'المدينة', '2022', 1_320_000, 78, 'مراقبة'),
    _Branch('فرع الدمام المنتزة', 'مجموعة الشرقية', 'الدمام', '2024', 980_000, 85, 'نشط'),
    _Branch('فرع أبها', 'شركة الجنوب', 'أبها', '2023', 720_000, 68, 'مراقبة'),
    _Branch('فرع الرياض الرائد', 'مجموعة الرياض', 'الرياض', '2021', 1_680_000, 94, 'نشط'),
    _Branch('فرع الكويت السالمية', 'الشريك الكويتي', 'الكويت', '2024', 1_240_000, 90, 'نشط'),
    _Branch('فرع دبي الديرة', 'الشريك الإماراتي', 'دبي', '2023', 1_580_000, 91, 'نشط'),
  ];

  static const List<_Royalty> _royalties = [
    _Royalty('فرع الرياض العليا', 'أبريل 2026', 6, 111_000, true),
    _Royalty('فرع جدة الشاطئ', 'أبريل 2026', 6, 126_000, true),
    _Royalty('فرع الخبر كورنيش', 'أبريل 2026', 6, 88_800, false),
    _Royalty('فرع مكة المكرمة', 'أبريل 2026', 6, 147_000, true),
    _Royalty('فرع الدمام المنتزة', 'أبريل 2026', 6, 58_800, false),
    _Royalty('فرع أبها', 'مارس 2026', 6, 43_200, true),
  ];

  static const List<_Audit> _audits = [
    _Audit('فرع مكة المكرمة', 'فريق الجودة', '2026-04-05', 96, 'أداء ممتاز في جميع المعايير'),
    _Audit('فرع الرياض العليا', 'فريق الجودة', '2026-04-03', 95, 'ممتاز — نموذج يُحتذى به'),
    _Audit('فرع أبها', 'فريق الجودة', '2026-03-28', 68, 'يحتاج تحسين في النظافة وخدمة العملاء'),
    _Audit('فرع المدينة المنورة', 'فريق الجودة', '2026-03-25', 78, 'مقبول — بعض الملاحظات على العرض'),
    _Audit('فرع جدة الشاطئ', 'فريق الجودة', '2026-03-20', 92, 'جيد جداً — ملاحظات طفيفة'),
  ];
}

class _Branch { final String name, franchisee, city, openedYear; final double monthlySales; final int qualityScore; final String status;
  const _Branch(this.name, this.franchisee, this.city, this.openedYear, this.monthlySales, this.qualityScore, this.status); }
class _Royalty { final String branch, period; final double rate, amount; final bool paid;
  const _Royalty(this.branch, this.period, this.rate, this.amount, this.paid); }
class _Audit { final String branch, auditor, date; final int score; final String notes;
  const _Audit(this.branch, this.auditor, this.date, this.score, this.notes); }
