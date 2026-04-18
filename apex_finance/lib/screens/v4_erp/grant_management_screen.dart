import 'package:flutter/material.dart';

/// Wave 114 — NGO / Grant & Donor Management
class GrantManagementScreen extends StatefulWidget {
  const GrantManagementScreen({super.key});
  @override
  State<GrantManagementScreen> createState() => _GrantManagementScreenState();
}

class _GrantManagementScreenState extends State<GrantManagementScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'المنح'), Tab(text: 'المانحون'), Tab(text: 'البرامج'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_grantsTab(), _donorsTab(), _programsTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.volunteer_activism, color: Color(0xFF1B5E20), size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إدارة المنح والمانحين', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('القطاع غير الربحي — تتبع المنح، البرامج، التبرعات', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final total = _grants.fold<double>(0, (s, g) => s + g.amount);
    final utilized = _grants.fold<double>(0, (s, g) => s + g.utilized);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('إجمالي المنح', _fmtM(total), Icons.volunteer_activism, const Color(0xFF1B5E20))),
      Expanded(child: _kpi('مستخدم', _fmtM(utilized), Icons.check_circle, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('المانحون', '${_donors.length}', Icons.groups, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('برامج نشطة', '${_programs.where((p)=>p.status.contains('نشط')).length}', Icons.campaign, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _grantsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _grants.length, itemBuilder: (_, i) {
    final g = _grants[i]; final util = g.utilized / g.amount;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.card_giftcard, color: Color(0xFF1B5E20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('من: ${g.donor} • للبرنامج: ${g.program}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(g.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(g.status, style: TextStyle(color: _statusColor(g.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('المبلغ', _fmt(g.amount)),
          _mini('مستخدم', _fmt(g.utilized)),
          _mini('متبقي', _fmt(g.amount - g.utilized)),
          _mini('الانتهاء', g.endDate),
        ]),
        const SizedBox(height: 8),
        Text('نسبة الاستخدام', style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: util, minHeight: 6, backgroundColor: Colors.black12, valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)))),
        const SizedBox(height: 4),
        Text('${(util * 100).toStringAsFixed(0)}% • ${g.reports} تقارير مقدمة',
          style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 9, color: Colors.black54)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _donorsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _donors.length, itemBuilder: (_, i) {
    final d = _donors[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.1),
        child: Icon(d.type.contains('فرد') ? Icons.person : Icons.business, color: const Color(0xFF1B5E20))),
      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d.type} • ${d.country}', style: const TextStyle(fontSize: 11)),
        Text('${d.grantsCount} منح • آخر تبرع: ${d.lastDonation}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fmtM(d.totalGiven), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        Text('إجمالي التبرع', style: const TextStyle(fontSize: 9, color: Colors.black54)),
      ]),
    ));
  });

  Widget _programsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _programs.length, itemBuilder: (_, i) {
    final p = _programs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _programColor(p.category).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(_programIcon(p.category), color: _programColor(p.category))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${p.category} • ${p.beneficiaries} مستفيد', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _statusColor(p.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(p.status, style: TextStyle(color: _statusColor(p.status), fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Text(p.description, style: const TextStyle(fontSize: 12)),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('💚 الأثر', '12,840 مستفيد هذا العام — نمو 32% YoY', const Color(0xFF2E7D32)),
    _insight('💰 معدل التمويل', '87% من البرامج ممولة بالكامل', const Color(0xFF1B5E20)),
    _insight('📊 كفاءة الإنفاق', '92% مباشر للبرامج • 8% إدارية (معيار دولي)', const Color(0xFF1A237E)),
    _insight('🌍 التنوع الجغرافي', '14 دولة — مانحون من 8 دول', const Color(0xFFD4AF37)),
    _insight('📝 الامتثال', 'تقارير مُرسلة للمانحين في الموعد 98%', const Color(0xFF2E7D32)),
    _insight('🏆 الشفافية', 'تقييم 4.9/5 من Charity Navigator', const Color(0xFF4A148C)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('مكتمل')) return const Color(0xFF1A237E);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    if (s.contains('مغلق')) return Colors.black54;
    return const Color(0xFF4A148C);
  }

  Color _programColor(String c) {
    if (c.contains('تعليم')) return const Color(0xFF1565C0);
    if (c.contains('صحة')) return const Color(0xFFC62828);
    if (c.contains('فقر')) return const Color(0xFFE65100);
    if (c.contains('بيئة')) return const Color(0xFF2E7D32);
    return const Color(0xFF4A148C);
  }

  IconData _programIcon(String c) {
    if (c.contains('تعليم')) return Icons.school;
    if (c.contains('صحة')) return Icons.local_hospital;
    if (c.contains('فقر')) return Icons.restaurant;
    if (c.contains('بيئة')) return Icons.eco;
    return Icons.volunteer_activism;
  }

  String _fmt(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(2)}M' : '${(v/1000).toStringAsFixed(0)}K';
  String _fmtM(double v) => _fmt(v);

  static const List<_Grant> _grants = [
    _Grant('منحة مياه آمنة لليمن', 'مؤسسة الملك سلمان', 'برنامج المياه', 8_500_000, 5_200_000, '2026-12-31', 'نشط', 4),
    _Grant('تعليم الأطفال - غزة', 'بنك التنمية الإسلامي', 'برنامج التعليم', 12_000_000, 9_800_000, '2026-09-30', 'نشط', 6),
    _Grant('مستشفى ميداني - السودان', 'الهلال الأحمر السعودي', 'برنامج الصحة', 18_500_000, 15_200_000, '2026-11-15', 'نشط', 8),
    _Grant('أعمال إغاثة الزلازل', 'صناديق خاصة', 'برنامج الإغاثة', 25_000_000, 24_800_000, '2026-05-30', 'نشط', 12),
    _Grant('حماية الغابات', 'USAID', 'برنامج البيئة', 4_500_000, 4_500_000, '2025-12-31', 'مكتمل', 8),
    _Grant('تأهيل الأيتام', 'مؤسسة وقفية', 'برنامج الأيتام', 6_200_000, 2_800_000, '2027-06-30', 'نشط', 3),
  ];

  static const List<_Donor> _donors = [
    _Donor('مؤسسة الملك سلمان الخيرية', 'مؤسسة حكومية', 'السعودية', 8, 45_800_000, '2026-04-10'),
    _Donor('بنك التنمية الإسلامي', 'بنك تنموي', 'دولي', 12, 82_500_000, '2026-04-05'),
    _Donor('أحمد الراشد', 'فرد', 'السعودية', 3, 1_200_000, '2026-04-01'),
    _Donor('شركة أرامكو', 'شركة', 'السعودية', 6, 28_400_000, '2026-03-25'),
    _Donor('الهلال الأحمر السعودي', 'منظمة خيرية', 'السعودية', 14, 65_200_000, '2026-04-18'),
    _Donor('USAID', 'وكالة حكومية', 'أمريكا', 4, 18_700_000, '2025-11-20'),
    _Donor('مؤسسة وقفية', 'وقف', 'السعودية', 5, 12_300_000, '2026-02-15'),
  ];

  static const List<_Program> _programs = [
    _Program('برنامج المياه النظيفة', 'تنموي - مياه', 48_200, 'توفير آبار وأنظمة تنقية المياه في 12 دولة', 'نشط'),
    _Program('برنامج التعليم للجميع', 'تعليم', 125_400, 'بناء مدارس ودعم المعلمين في المناطق النائية', 'نشط'),
    _Program('برنامج الصحة الأساسية', 'صحة', 84_200, 'مستشفيات ميدانية وعيادات متنقلة + لقاحات', 'نشط'),
    _Program('برنامج الإغاثة العاجلة', 'إغاثة - فقر', 240_000, 'استجابة سريعة للكوارث الطبيعية والنزاعات', 'نشط'),
    _Program('برنامج حماية البيئة', 'بيئة', 18_500, 'التشجير وحماية الغابات والتنوع الحيوي', 'نشط'),
    _Program('برنامج كفالة الأيتام', 'اجتماعي', 12_800, 'كفالة الأيتام مع متابعة تعليمية وصحية', 'نشط'),
  ];
}

class _Grant { final String title, donor, program; final double amount, utilized; final String endDate, status; final int reports;
  const _Grant(this.title, this.donor, this.program, this.amount, this.utilized, this.endDate, this.status, this.reports); }
class _Donor { final String name, type, country; final int grantsCount; final double totalGiven; final String lastDonation;
  const _Donor(this.name, this.type, this.country, this.grantsCount, this.totalGiven, this.lastDonation); }
class _Program { final String name, category; final int beneficiaries; final String description, status;
  const _Program(this.name, this.category, this.beneficiaries, this.description, this.status); }
