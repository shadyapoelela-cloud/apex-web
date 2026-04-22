import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 146 — Global Compliance Calendar
class ComplianceCalendarGlobalScreen extends StatefulWidget {
  const ComplianceCalendarGlobalScreen({super.key});
  @override
  State<ComplianceCalendarGlobalScreen> createState() => _ComplianceCalendarGlobalScreenState();
}

class _ComplianceCalendarGlobalScreenState extends State<ComplianceCalendarGlobalScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'التقويم'), Tab(text: 'المواعيد القادمة'), Tab(text: 'حسب الجهة'), Tab(text: 'إحصائيات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_calendarTab(), _upcomingTab(), _byAuthorityTab(), _statsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.event_note, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تقويم الامتثال الشامل', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('كل المواعيد التنظيمية في منطقة واحدة — SA + UAE + Global', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final thisMonth = _events.where((e)=>e.month.contains('أبريل')).length;
    final critical = _events.where((e)=>e.priority.contains('حرج')).length;
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('هذا الشهر', '$thisMonth', Icons.today, const Color(0xFFE65100))),
      Expanded(child: _kpi('حرجة', '$critical', Icons.warning, const Color(0xFFC62828))),
      Expanded(child: _kpi('جهات مُتابعة', '12', Icons.account_balance, const Color(0xFF4A148C))),
      Expanded(child: _kpi('نسبة الالتزام', '98%', Icons.check_circle, const Color(0xFF2E7D32))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _calendarTab() => ListView(padding: const EdgeInsets.all(12), children: [
    _monthHeader('📅 أبريل 2026'),
    ..._events.where((e)=>e.month.contains('أبريل')).map((e) => _eventCard(e)),
    _monthHeader('📅 مايو 2026'),
    ..._events.where((e)=>e.month.contains('مايو')).map((e) => _eventCard(e)),
    _monthHeader('📅 يونيو 2026'),
    ..._events.where((e)=>e.month.contains('يونيو')).map((e) => _eventCard(e)),
  ]);

  Widget _monthHeader(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))));

  Widget _eventCard(_Event e) => Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
    child: Row(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(
        color: _priorityColor(e.priority).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(e.day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _priorityColor(e.priority))),
          Text(e.month.split(' ')[0], style: TextStyle(fontSize: 10, color: _priorityColor(e.priority))),
        ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text('${e.authority} • ${e.country}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 4),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _priorityColor(e.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(e.priority, style: TextStyle(color: _priorityColor(e.priority), fontSize: 9, fontWeight: FontWeight.bold))),
          const SizedBox(width: 6),
          Text(e.type, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
      ])),
    ]),
  ));

  Widget _upcomingTab() {
    final upcoming = List<_Event>.from(_events)..sort((a, b) => a.day.compareTo(b.day));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: upcoming.length, itemBuilder: (_, i) {
      return _eventCard(upcoming[i]);
    });
  }

  Widget _byAuthorityTab() {
    final byAuth = <String, List<_Event>>{};
    for (final e in _events) {
      byAuth.putIfAbsent(e.authority, () => []).add(e);
    }
    return ListView(padding: const EdgeInsets.all(12),
      children: byAuth.entries.map((entry) => Card(margin: const EdgeInsets.only(bottom: 10),
        child: ExpansionTile(
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('${entry.value.length} مواعيد', style: const TextStyle(fontSize: 11)),
          leading: CircleAvatar(backgroundColor: _authorityColor(entry.key).withValues(alpha: 0.15),
            child: Icon(Icons.account_balance, color: _authorityColor(entry.key))),
          children: entry.value.map((e) => ListTile(dense: true,
            title: Text(e.title, style: const TextStyle(fontSize: 12)),
            subtitle: Text('${e.day} ${e.month}', style: const TextStyle(fontSize: 10)),
            trailing: Icon(Icons.circle, color: _priorityColor(e.priority), size: 10),
          )).toList(),
        ),
      )).toList());
  }

  Widget _statsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📅 المواعيد 2026', '148 موعد منظم عبر 12 جهة تنظيمية', const Color(0xFF4A148C)),
    _insight('🇸🇦 السعودية', '88 موعد (ZATCA 32 • GOSI 18 • MOC 12 • أخرى 26)', const Color(0xFF2E7D32)),
    _insight('🇦🇪 الإمارات', '42 موعد (FTA 22 • DED 8 • MOHRE 12)', const Color(0xFF1565C0)),
    _insight('🌍 دولي', '18 موعد (IFRS/BEPS/Pillar2/OECD)', core_theme.AC.gold),
    _insight('✅ نسبة الالتزام السنوية', '98% مواعيد في موعدها (أعلى من متوسط الصناعة 85%)', const Color(0xFF2E7D32)),
    _insight('⚠️ مواعيد حرجة قادمة', 'إقرار VAT أبريل + الزكاة 2025 + Excise Q1', const Color(0xFFC62828)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6),
      Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _priorityColor(String p) {
    if (p.contains('حرج')) return const Color(0xFFC62828);
    if (p.contains('عالي')) return const Color(0xFFE65100);
    if (p.contains('متوسط')) return core_theme.AC.gold;
    return const Color(0xFF1A237E);
  }

  Color _authorityColor(String a) {
    if (a.contains('ZATCA')) return const Color(0xFF1A237E);
    if (a.contains('GOSI')) return const Color(0xFF2E7D32);
    if (a.contains('CMA')) return const Color(0xFF4A148C);
    if (a.contains('FTA')) return const Color(0xFF1565C0);
    return core_theme.AC.gold;
  }

  static const List<_Event> _events = [
    _Event('20', 'أبريل 2026', 'تقديم إقرار VAT - مارس 2026', 'ZATCA', 'السعودية', 'حرج', 'إقرار شهري'),
    _Event('25', 'أبريل 2026', 'تقديم إقرار WHT - مارس', 'ZATCA', 'السعودية', 'عالي', 'إقرار شهري'),
    _Event('28', 'أبريل 2026', 'دفع رسوم GOSI - مارس', 'GOSI', 'السعودية', 'عالي', 'دفع شهري'),
    _Event('30', 'أبريل 2026', 'تقديم إقرار الزكاة السنوي 2025', 'ZATCA', 'السعودية', 'حرج', 'إقرار سنوي'),
    _Event('30', 'أبريل 2026', 'Excise Tax Q1 2026', 'ZATCA', 'السعودية', 'عالي', 'إقرار ربعي'),
    _Event('10', 'مايو 2026', 'دفع رواتب WPS - أبريل', 'MOL', 'السعودية', 'حرج', 'WPS شهري'),
    _Event('15', 'مايو 2026', 'تقديم إقرار VAT - أبريل', 'ZATCA', 'السعودية', 'حرج', 'إقرار شهري'),
    _Event('20', 'مايو 2026', 'تجديد شهادة CSID (csid_PRD_2025_5102)', 'ZATCA', 'السعودية', 'عالي', 'تجديد شهادة'),
    _Event('28', 'مايو 2026', 'VAT UAE Q1 2026', 'FTA', 'الإمارات', 'عالي', 'إقرار ربعي'),
    _Event('31', 'مايو 2026', 'نهاية سنة GOSI المالية', 'GOSI', 'السعودية', 'متوسط', 'تقرير سنوي'),
    _Event('5', 'يونيو 2026', 'اجتماع الجمعية العمومية السنوي', 'CMA', 'السعودية', 'عالي', 'اجتماع حوكمة'),
    _Event('15', 'يونيو 2026', 'إقرار VAT مايو 2026', 'ZATCA', 'السعودية', 'حرج', 'إقرار شهري'),
    _Event('30', 'يونيو 2026', 'ISO 9001 Surveillance Audit', 'SGS', 'دولي', 'متوسط', 'تدقيق جودة'),
    _Event('30', 'يونيو 2026', 'Pillar 2 Notification', 'OECD', 'دولي', 'عالي', 'إخطار دولي'),
  ];
}

class _Event { final String day, month, title, authority, country, priority, type;
  const _Event(this.day, this.month, this.title, this.authority, this.country, this.priority, this.type); }
