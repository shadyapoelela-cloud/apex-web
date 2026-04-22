import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 137 — Marketplace Provider Jobs
class MarketplaceProviderJobsScreen extends StatefulWidget {
  const MarketplaceProviderJobsScreen({super.key});
  @override
  State<MarketplaceProviderJobsScreen> createState() => _MarketplaceProviderJobsScreenState();
}

class _MarketplaceProviderJobsScreenState extends State<MarketplaceProviderJobsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'المهام النشطة'), Tab(text: 'دعوات العروض'), Tab(text: 'الملفات المنجزة'), Tab(text: 'الأرشيف')])),
        Expanded(child: TabBarView(controller: _tc, children: [_activeTab(), _invitesTab(), _completedTab(), _archiveTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.work, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مهامي كمزوّد خدمة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('إدارة المشاريع النشطة + تتبع الوقت والإنجاز', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final activeRev = _active.fold<double>(0, (s, j) => s + j.value);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('مهام نشطة', '${_active.length}', Icons.work_outline, const Color(0xFF00695C))),
      Expanded(child: _kpi('دعوات جديدة', '${_invites.length}', Icons.mail, const Color(0xFFE65100))),
      Expanded(child: _kpi('قيمة النشط', '${(activeRev/1000).toStringAsFixed(0)}K', Icons.payments, core_theme.AC.gold)),
      Expanded(child: _kpi('إيراد الشهر', '145K', Icons.trending_up, const Color(0xFF2E7D32))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _activeTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _active.length, itemBuilder: (_, i) {
    final j = _active[i]; final progress = j.progress / 100;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF00695C).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.work, color: Color(0xFF00695C))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(j.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${j.client} • ${j.id}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Text('${j.value.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('البداية', j.startDate),
          _mini('النهاية', j.endDate),
          _mini('الأيام المتبقية', '${j.daysRemaining} يوم'),
          _mini('ساعات', '${j.hoursLogged}h'),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: progress, minHeight: 8, backgroundColor: core_theme.AC.bdr,
          valueColor: AlwaysStoppedAnimation(core_theme.AC.gold))),
        const SizedBox(height: 4),
        Row(children: [
          Text('${j.progress}% مكتمل', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(j.nextMilestone, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _invitesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _invites.length, itemBuilder: (_, i) {
    final inv = _invites[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.15),
            child: const Icon(Icons.mail, color: Color(0xFFE65100))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inv.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${inv.client} • ميزانية: ${inv.budget}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(inv.description, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: () {}, child: Text('رفض')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: Text('تقديم عرض'),
          ),
        ]),
      ]),
    ));
  });

  Widget _completedTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _completed.length, itemBuilder: (_, i) {
    final c = _completed[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
        child: const Icon(Icons.check_circle, color: Color(0xFF2E7D32))),
      title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('${c.client} • ${c.completedDate}', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${c.value.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        Row(children: [
          Icon(Icons.star, color: core_theme.AC.gold, size: 12),
          Text(' ${c.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ]),
    ));
  });

  Widget _archiveTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📂 إجمالي المشاريع المنجزة', '248 مشروع منذ 2021', const Color(0xFF2E7D32)),
    _insight('💰 إجمالي الإيرادات', '12.4M ر.س إجمالية', core_theme.AC.gold),
    _insight('⭐ متوسط التقييم', '4.8/5 (عبر 248 مشروع)', core_theme.AC.gold),
    _insight('🏆 أكبر مشروع', '580K ر.س (ZATCA Phase 2 كامل)', const Color(0xFF4A148C)),
    _insight('📈 معدل النمو السنوي', '+38% YoY في عدد المشاريع', const Color(0xFF2E7D32)),
    _insight('🎯 Repeat Clients', '72% من العملاء عادوا لمشاريع أخرى', const Color(0xFF1A237E)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  static const List<_Job> _active = [
    _Job('JOB-2026-0048', 'مراجعة ضريبية - أرامكو فرع', 'أرامكو السعودية', '2026-04-01', '2026-04-30', 12, 45, 18000, 62, 'تسليم مسودة التقرير — 2026-04-22'),
    _Job('JOB-2026-0047', 'تطبيق ZATCA - مصنع الأمل', 'مصنع الأمل الصناعي', '2026-03-15', '2026-05-30', 42, 28, 58000, 45, 'اختبار UAT — 2026-04-25'),
    _Job('JOB-2026-0046', 'إعداد ميزانية 2026', 'شركة النخبة', '2026-04-10', '2026-04-28', 10, 18, 24000, 72, 'اجتماع المجلس — 2026-04-25'),
    _Job('JOB-2026-0045', 'مراجعة GL ومطابقة', 'بنك الراجحي فرع', '2026-04-05', '2026-04-25', 7, 32, 15000, 88, 'تسليم نهائي'),
    _Job('JOB-2026-0044', 'تدقيق IFRS 15 & 16', 'شركة الاتصالات', '2026-03-20', '2026-05-01', 13, 52, 35000, 68, 'مراجعة الإدارة'),
  ];

  static const List<_Invite> _invites = [
    _Invite('تطبيق ZATCA Phase 2', 'مجموعة تجارية', '40,000 - 60,000 ر.س', 'نحتاج تكامل كامل مع نظام ERP الحالي + CSID + شهادة SSL. الموعد النهائي 2026-06-15'),
    _Invite('مراجعة ضريبية سنوية', 'مصنع صغير', '8,000 - 12,000 ر.س', 'مراجعة VAT + Zakat للسنة المالية 2025 مع تدقيق المستندات'),
    _Invite('تدريب فريق المحاسبة', 'شركة ناشئة', '5,000 - 8,000 ر.س', 'تدريب 4 أشخاص على IFRS الأساسيات + ZATCA لمدة أسبوعين'),
    _Invite('تقييم شركة للبيع', 'مستثمر خاص', '25,000 - 40,000 ر.س', 'DCF + Multiples + Due Diligence لشركة في قطاع الخدمات اللوجستية'),
  ];

  static const List<_Completed> _completed = [
    _Completed('تدقيق الأنظمة الداخلية', 'شركة الأفق', '2026-03-25', 18000, 5.0),
    _Completed('تسجيل فرع جديد', 'مؤسسة الابتكار', '2026-03-10', 9500, 4.9),
    _Completed('إقرارات VAT Q1', 'معرض الجزيرة', '2026-02-28', 4500, 4.8),
    _Completed('تطبيق IFRS 16', 'شركة التأجير', '2026-02-15', 22000, 5.0),
    _Completed('مراجعة Q4 2025', 'بنك صغير', '2026-01-30', 14000, 4.9),
  ];
}

class _Job { final String id, title, client, startDate, endDate; final int daysRemaining, hoursLogged; final double value; final int progress; final String nextMilestone;
  const _Job(this.id, this.title, this.client, this.startDate, this.endDate, this.daysRemaining, this.hoursLogged, this.value, this.progress, this.nextMilestone); }
class _Invite { final String title, client, budget, description;
  const _Invite(this.title, this.client, this.budget, this.description); }
class _Completed { final String title, client, completedDate; final double value; final double rating;
  const _Completed(this.title, this.client, this.completedDate, this.value, this.rating); }
