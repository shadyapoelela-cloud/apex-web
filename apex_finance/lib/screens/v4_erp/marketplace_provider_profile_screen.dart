import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 136 — Marketplace Provider Profile
class MarketplaceProviderProfileScreen extends StatefulWidget {
  const MarketplaceProviderProfileScreen({super.key});
  @override
  State<MarketplaceProviderProfileScreen> createState() => _MarketplaceProviderProfileScreenState();
}

class _MarketplaceProviderProfileScreenState extends State<MarketplaceProviderProfileScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الملف التعريفي'), Tab(text: 'الشهادات'), Tab(text: 'المهارات والخدمات'), Tab(text: 'الفريق')])),
        Expanded(child: TabBarView(controller: _tc, children: [_profileTab(), _certsTab(), _skillsTab(), _teamTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      CircleAvatar(radius: 30, backgroundColor: core_theme.AC.gold,
        child: Text('أ ر', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مكتب الراجحي للاستشارات', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Row(children: [
          Icon(Icons.verified, color: core_theme.AC.gold, size: 16),
          SizedBox(width: 4),
          Text('موثّق ★ Premium • محاسبة وضرائب', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
        ]),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('4.9', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        Row(children: List.generate(5, (i) => Icon(Icons.star, color: core_theme.AC.gold, size: 14))),
        Text('128 تقييم', style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
      ]),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('مشاريع منجزة', '248', Icons.task_alt, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('عملاء متكررون', '72%', Icons.repeat, const Color(0xFF4A148C))),
    Expanded(child: _kpi('زمن الرد', '1.2 ساعة', Icons.speed, core_theme.AC.gold)),
    Expanded(child: _kpi('معدل الإتمام', '98%', Icons.check_circle, const Color(0xFF1A237E))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _profileTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('نبذة تعريفية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A148C))),
      const SizedBox(height: 8),
      Text('مكتب محاسبة وضرائب مرخّص من SOCPA منذ 2008. خدمنا أكثر من 500 شركة في المملكة عبر قطاعات متعددة. متخصصون في الفوترة الإلكترونية (ZATCA)، مراجعة الزكاة، ضريبة القيمة المضافة، وتطبيق IFRS.',
        style: TextStyle(fontSize: 13, height: 1.6)),
    ]))),
    const SizedBox(height: 10),
    _infoRow('📍 الموقع', 'الرياض، حي العليا — خدمة كل السعودية + GCC'),
    _infoRow('📅 الخبرة', '18 سنة (2008 - الآن)'),
    _infoRow('👥 حجم الفريق', '42 متخصص (28 معتمد SOCPA)'),
    _infoRow('🌐 اللغات', 'العربية، الإنجليزية'),
    _infoRow('💰 نطاق الأسعار', '500 - 250,000 ر.س لكل مشروع'),
    _infoRow('⏱️ ساعات العمل', 'الأحد - الخميس، 8:00 ص - 5:00 م'),
    _infoRow('📞 الرد على الطلبات', 'خلال ساعة (في أوقات العمل)'),
    _infoRow('🏢 العملاء الرئيسيون', 'أرامكو • سابك • المراعي • stc • الراجحي'),
  ]);

  Widget _infoRow(String label, String value) => Card(margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(dense: true, title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: core_theme.AC.tp))));

  Widget _certsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _certs.length, itemBuilder: (_, i) {
    final c = _certs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: core_theme.AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Icon(_certIcon(c.type), color: core_theme.AC.gold)),
      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.issuer, style: const TextStyle(fontSize: 11)),
        Text('رقم: ${c.number} • ${c.year}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: const Icon(Icons.verified, color: Color(0xFF2E7D32)),
    ));
  });

  IconData _certIcon(String t) {
    if (t.contains('SOCPA')) return Icons.workspace_premium;
    if (t.contains('ZATCA')) return Icons.receipt;
    if (t.contains('IFRS')) return Icons.balance;
    return Icons.card_membership;
  }

  Widget _skillsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _skills.length, itemBuilder: (_, i) {
    final s = _skills[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(s.icon, color: const Color(0xFF4A148C)),
          const SizedBox(width: 10),
          Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text('${s.projects} مشروع', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: s.level / 100, minHeight: 8, backgroundColor: core_theme.AC.bdr,
          valueColor: AlwaysStoppedAnimation(core_theme.AC.gold))),
        const SizedBox(height: 4),
        Text('${s.level}% خبرة • ${s.description}', style: TextStyle(fontSize: 11, color: core_theme.AC.tp)),
      ]),
    ));
  });

  Widget _teamTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _team.length, itemBuilder: (_, i) {
    final t = _team[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF4A148C),
        child: Text(t.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${t.role} • ${t.certs}', style: const TextStyle(fontSize: 11)),
      trailing: Text('${t.years} سنة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
    ));
  });

  static const List<_Cert> _certs = [
    _Cert('شهادة SOCPA - محاسب قانوني', 'هيئة السعوديين للمحاسبين القانونيين', 'SOCPA', 'SC-2008-4521', '2008'),
    _Cert('شهادة ZATCA Phase 2 Integration Partner', 'هيئة الزكاة والضريبة والجمارك', 'ZATCA', 'IP-2024-128', '2024'),
    _Cert('IFRS Certification', 'ACCA International', 'IFRS', 'ACCA-18945', '2015'),
    _Cert('CPA - Certified Public Accountant', 'AICPA (American Institute)', 'CPA', 'AICPA-78421', '2012'),
    _Cert('شهادة ISO 27001 Lead Auditor', 'PECB International', 'ISO', 'LA-2022-0845', '2022'),
    _Cert('Zakat Expert Certification', 'هيئة الزكاة والدخل', 'Zakat', 'ZE-2020-042', '2020'),
  ];

  static const List<_Skill> _skills = [
    _Skill('ZATCA Phase 2 Implementation', Icons.receipt_long, 95, 48, 'تطبيق كامل + CSID + تكامل API'),
    _Skill('مراجعة الزكاة والضرائب', Icons.account_balance, 98, 180, 'مراجعة VAT/Zakat/WHT + إقرارات'),
    _Skill('تطبيق IFRS الكامل', Icons.book, 92, 65, 'انتقال للمعايير الدولية + التدريب'),
    _Skill('تدقيق القوائم المالية', Icons.fact_check, 90, 120, 'تدقيق SOCPA-compliant'),
    _Skill('إعداد الميزانيات', Icons.trending_up, 85, 42, 'نماذج متقدمة + تحليل سيناريوهات'),
    _Skill('التقييم والاستشارات M&A', Icons.handshake, 78, 22, 'DCF + Multiples + LBO'),
  ];

  static const List<_Member> _team = [
    _Member('د. أحمد الراجحي', 'الشريك المؤسس', 'SOCPA + CPA + PhD', 22),
    _Member('فاطمة السبيعي', 'شريك ضرائب', 'SOCPA + Zakat Expert', 18),
    _Member('محمد القحطاني', 'مدير المراجعة', 'SOCPA + CIA', 15),
    _Member('نورة الشمري', 'مدير ZATCA', 'IT + SOCPA', 12),
    _Member('خالد الدوسري', 'مستشار ضرائب', 'SOCPA + CTT', 10),
  ];
}

class _Cert { final String name, issuer, type, number, year;
  const _Cert(this.name, this.issuer, this.type, this.number, this.year); }
class _Skill { final String name; final IconData icon; final int level, projects; final String description;
  const _Skill(this.name, this.icon, this.level, this.projects, this.description); }
class _Member { final String name, role, certs; final int years;
  const _Member(this.name, this.role, this.certs, this.years); }
