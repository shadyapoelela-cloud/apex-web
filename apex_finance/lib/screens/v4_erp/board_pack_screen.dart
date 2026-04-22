/// APEX Wave 83 — Board Pack / Board Meeting Portal.
/// Route: /app/erp/finance/board
///
/// Secure portal for board materials, minutes, resolutions.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class BoardPackScreen extends StatefulWidget {
  const BoardPackScreen({super.key});
  @override
  State<BoardPackScreen> createState() => _BoardPackScreenState();
}

class _BoardPackScreenState extends State<BoardPackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _meetings = const [
    _Meeting('BM-2026-02', 'اجتماع مجلس الإدارة Q2-2026', '2026-04-25 09:00', 'قاعة المجلس + Teams', 'قادم', 18, true),
    _Meeting('BM-2026-01', 'اجتماع مجلس الإدارة Q1-2026', '2026-01-28 09:00', 'قاعة المجلس', 'مكتمل', 22, false),
    _Meeting('AGM-2025', 'الجمعية العمومية السنوية 2025', '2026-03-15 10:00', 'فندق الفيصلية', 'مكتمل', 45, false),
    _Meeting('BM-2025-04', 'اجتماع مجلس الإدارة Q4-2025', '2025-10-20 09:00', 'قاعة المجلس', 'مكتمل', 20, false),
  ];

  final _directors = const [
    _Director('خالد بن عبدالله الفيصل', 'رئيس المجلس', 'مستقل', '2019', true, true),
    _Director('أحمد السعدون', 'الرئيس التنفيذي', 'تنفيذي', '2015', true, true),
    _Director('د. نورة العتيبي', 'نائب الرئيس', 'مستقلة', '2021', true, true),
    _Director('سلطان الراجحي', 'عضو', 'مستقل', '2020', false, true),
    _Director('فهد العيسى', 'عضو', 'غير تنفيذي', '2018', true, false),
    _Director('د. سارة الجهني', 'عضو', 'مستقلة', '2022', true, true),
    _Director('عبدالعزيز المالكي', 'عضو', 'غير تنفيذي', '2017', true, false),
    _Director('لينا البصراوي', 'عضو', 'مستقلة', '2023', true, true),
    _Director('أحمد العتيبي', 'CFO', 'تنفيذي', '2018', true, true),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.event, size: 16), text: 'الاجتماعات'),
            Tab(icon: Icon(Icons.inventory, size: 16), text: 'الحقيبة (Next)'),
            Tab(icon: Icon(Icons.gavel, size: 16), text: 'القرارات'),
            Tab(icon: Icon(Icons.people, size: 16), text: 'الأعضاء'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildMeetingsTab(),
              _buildPackTab(),
              _buildResolutionsTab(),
              _buildDirectorsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF311B92), Color(0xFF4A148C)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('بوابة مجلس الإدارة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Board Portal — حقيبة الاجتماع · قرارات · محاضر · Minutes — متوافق مع هيئة السوق المالية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: core_theme.AC.err.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: core_theme.AC.err),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('سرّي',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _meetings.length,
      itemBuilder: (ctx, i) {
        final m = _meetings[i];
        final isUpcoming = m.status == 'قادم';
        final color = isUpcoming ? core_theme.AC.info : core_theme.AC.ok;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: isUpcoming ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(isUpcoming ? Icons.upcoming : Icons.event_available, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(m.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(m.status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
                        ),
                        if (m.requiresAction) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: core_theme.AC.err, borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.priority_high, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text('تأكيد الحضور',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 4),
                        Text(m.dateTime,
                            style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                        const SizedBox(width: 14),
                        Icon(Icons.place, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 4),
                        Text(m.venue, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 14),
                        Icon(Icons.description, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 4),
                        Text('${m.docCount} وثيقة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (isUpcoming)
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.folder_open, size: 14),
                      label: Text('فتح الحقيبة', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description, size: 14),
                      label: Text('المحضر', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.archive, size: 14),
                      label: Text('الحقيبة', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackTab() {
    final docs = const [
      _PackDoc('1', 'جدول الأعمال المقترح', 'agenda', 3, 'المجلس', true),
      _PackDoc('2', 'محضر اجتماع Q1-2026 (للتثبيت)', 'minutes', 12, 'أمانة المجلس', true),
      _PackDoc('3', 'القوائم المالية الربعية Q1-2026', 'financials', 45, 'المدير المالي', true),
      _PackDoc('4', 'تقرير لجنة المراجعة', 'audit', 18, 'لجنة المراجعة', true),
      _PackDoc('5', 'تقرير لجنة المخاطر', 'risk', 22, 'لجنة المخاطر', true),
      _PackDoc('6', 'التحديثات الاستراتيجية 2026', 'strategy', 28, 'الإدارة التنفيذية', true),
      _PackDoc('7', 'مقترح توزيع أرباح 1.5 ر.س/سهم', 'resolution', 5, 'المدير المالي', true),
      _PackDoc('8', 'اعتماد الميزانية التقديرية Q3', 'resolution', 8, 'المدير المالي', false),
      _PackDoc('9', 'تقرير ESG Q1', 'esg', 32, 'لجنة الاستدامة', true),
      _PackDoc('10', 'قضايا قانونية معلّقة', 'legal', 6, 'المستشار القانوني', true),
      _PackDoc('11', 'ملخص اجتماعات اللجان', 'committees', 14, 'أمانة المجلس', true),
      _PackDoc('12', 'أي أعمال أخرى', 'other', 2, 'المجلس', false),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حقيبة اجتماع BM-2026-02',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    Text('الربع الثاني 2026 · 2026-04-25 @ 09:00',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 16),
                label: Text('تحميل كاملة (ZIP)', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final d in docs) _packDocRow(d),
      ],
    );
  }

  Widget _packDocRow(_PackDoc d) {
    final typeInfo = _typeInfo(d.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d.ready ? core_theme.AC.bdr : core_theme.AC.warn),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: typeInfo.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(d.number,
                  style: TextStyle(color: typeInfo.color, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 12),
          Icon(typeInfo.icon, color: typeInfo.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: typeInfo.color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                      child: Text(typeInfo.label,
                          style: TextStyle(fontSize: 10, color: typeInfo.color, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Text('${d.pages} صفحة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    const SizedBox(width: 8),
                    Text('بواسطة ${d.owner}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  ],
                ),
              ],
            ),
          ),
          if (d.ready)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: core_theme.AC.ok.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text('جاهز', style: TextStyle(color: core_theme.AC.ok, fontSize: 10, fontWeight: FontWeight.w800)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: core_theme.AC.warn.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text('قيد الإعداد', style: TextStyle(color: core_theme.AC.warn, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.open_in_new, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionsTab() {
    final resolutions = const [
      _Resolution('RES-2026-008', 'اعتماد القوائم المالية Q1-2026', '2026-01-28', 'passed', 9, 9, 0),
      _Resolution('RES-2026-007', 'تعيين مراجع خارجي لعام 2026', '2026-01-28', 'passed', 8, 1, 0),
      _Resolution('RES-2026-006', 'توزيع أرباح مؤقتة 0.75 ر.س/سهم', '2026-01-28', 'passed', 7, 1, 1),
      _Resolution('RES-2025-042', 'زيادة رأس المال 500M ر.س', '2025-10-20', 'passed', 9, 0, 0),
      _Resolution('RES-2025-038', 'إطلاق برنامج الأسهم للموظفين', '2025-10-20', 'passed', 8, 0, 1),
      _Resolution('RES-2025-035', 'اعتماد السياسة البيئية', '2025-10-20', 'passed', 9, 0, 0),
      _Resolution('RES-2025-031', 'تعديل هيكل اللجان', '2025-07-12', 'passed', 7, 2, 0),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: resolutions.length,
      itemBuilder: (ctx, i) {
        final r = resolutions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: r.status == 'passed' ? core_theme.AC.ok.withOpacity(0.12) : core_theme.AC.err.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  r.status == 'passed' ? Icons.check_circle : Icons.cancel,
                  color: r.status == 'passed' ? core_theme.AC.ok : core_theme.AC.err,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text(r.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                      ],
                    ),
                    Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _voteBox('موافق', r.yes, core_theme.AC.ok),
              const SizedBox(width: 6),
              _voteBox('معارض', r.no, core_theme.AC.err),
              const SizedBox(width: 6),
              _voteBox('ممتنع', r.abstain, core_theme.AC.td),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r.status == 'passed' ? core_theme.AC.ok.withOpacity(0.15) : core_theme.AC.err.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.status == 'passed' ? 'صادر' : 'مرفوض',
                  style: TextStyle(
                      color: r.status == 'passed' ? core_theme.AC.ok : core_theme.AC.err,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _voteBox(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text('$count', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectorsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _directors.length,
      itemBuilder: (ctx, i) {
        final d = _directors[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _roleColor(d.role).withOpacity(0.15),
                child: Text(d.name.substring(0, 1),
                    style: TextStyle(color: _roleColor(d.role), fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    Text(d.position, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _roleColor(d.role).withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                          child: Text(d.role,
                              style: TextStyle(fontSize: 10, color: _roleColor(d.role), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                          child: Text('عضو منذ ${d.sinceYear}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          d.confirmedNextMeeting ? Icons.check_circle : Icons.warning,
                          color: d.confirmedNextMeeting ? core_theme.AC.ok : core_theme.AC.warn,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(d.confirmedNextMeeting ? 'مؤكّد' : 'بانتظار تأكيد',
                            style: TextStyle(
                                fontSize: 11,
                                color: d.confirmedNextMeeting ? core_theme.AC.ok : core_theme.AC.warn,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text('الاجتماع القادم', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(d.attendancePct ? '96%' : '72%',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: d.attendancePct ? core_theme.AC.ok : core_theme.AC.warn)),
                  Text('حضور سنوي', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  _TypeInfo _typeInfo(String t) {
    switch (t) {
      case 'agenda':
        return _TypeInfo('جدول أعمال', Icons.list_alt, Color(0xFF4A148C));
      case 'minutes':
        return _TypeInfo('محضر', Icons.description, core_theme.AC.info);
      case 'financials':
        return _TypeInfo('قوائم مالية', Icons.account_balance, core_theme.AC.gold);
      case 'audit':
        return _TypeInfo('مراجعة', Icons.fact_check, core_theme.AC.info);
      case 'risk':
        return _TypeInfo('مخاطر', Icons.warning, core_theme.AC.warn);
      case 'strategy':
        return _TypeInfo('استراتيجي', Icons.insights, core_theme.AC.purple);
      case 'resolution':
        return _TypeInfo('مقترح قرار', Icons.gavel, core_theme.AC.err);
      case 'esg':
        return _TypeInfo('ESG', Icons.eco, core_theme.AC.ok);
      case 'legal':
        return _TypeInfo('قانوني', Icons.balance, core_theme.AC.purple);
      case 'committees':
        return _TypeInfo('اللجان', Icons.groups, Colors.brown);
      default:
        return _TypeInfo('أخرى', Icons.folder, core_theme.AC.td);
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'مستقل':
      case 'مستقلة':
        return core_theme.AC.gold;
      case 'تنفيذي':
        return core_theme.AC.info;
      case 'غير تنفيذي':
        return core_theme.AC.purple;
      default:
        return core_theme.AC.td;
    }
  }
}

class _Meeting {
  final String id;
  final String name;
  final String dateTime;
  final String venue;
  final String status;
  final int docCount;
  final bool requiresAction;
  const _Meeting(this.id, this.name, this.dateTime, this.venue, this.status, this.docCount, this.requiresAction);
}

class _PackDoc {
  final String number;
  final String title;
  final String type;
  final int pages;
  final String owner;
  final bool ready;
  const _PackDoc(this.number, this.title, this.type, this.pages, this.owner, this.ready);
}

class _Resolution {
  final String id;
  final String title;
  final String date;
  final String status;
  final int yes;
  final int no;
  final int abstain;
  const _Resolution(this.id, this.title, this.date, this.status, this.yes, this.no, this.abstain);
}

class _Director {
  final String name;
  final String position;
  final String role;
  final String sinceYear;
  final bool confirmedNextMeeting;
  final bool attendancePct;
  const _Director(this.name, this.position, this.role, this.sinceYear, this.confirmedNextMeeting, this.attendancePct);
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  _TypeInfo(this.label, this.icon, this.color);
}
