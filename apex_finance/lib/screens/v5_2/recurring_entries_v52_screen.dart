/// V5.2 — Recurring Journal Entries using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class RecurringEntriesV52Screen extends StatefulWidget {
  const RecurringEntriesV52Screen({super.key});

  @override
  State<RecurringEntriesV52Screen> createState() => _RecurringEntriesV52ScreenState();
}

class _RecurringEntriesV52ScreenState extends State<RecurringEntriesV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _rules = <_RR>[
    _RR('RC-001', 'إهلاك الأصول الشهري', _Freq.monthly, '2026-05-01', 120000, 'محمد الخالد', _S.active, 24, 48),
    _RR('RC-002', 'استحقاق الإيجار - المقر الرئيسي', _Freq.monthly, '2026-05-01', 85000, 'سارة علي', _S.active, 18, 36),
    _RR('RC-003', 'استحقاق الإيجار - فرع جدة', _Freq.monthly, '2026-05-01', 48000, 'سارة علي', _S.active, 12, 36),
    _RR('RC-004', 'اشتراكات البرمجيات السنوية', _Freq.yearly, '2027-01-15', 420000, 'سامي طارق', _S.active, 2, 5),
    _RR('RC-005', 'استحقاق الفوائد البنكية', _Freq.monthly, '2026-05-01', 28000, 'خالد إبراهيم', _S.active, 18, 0),
    _RR('RC-006', 'مكافأة نهاية العام للموظفين', _Freq.yearly, '2026-12-15', 1200000, 'ليلى أحمد', _S.active, 3, 0),
    _RR('RC-007', 'تأمينات المركبات', _Freq.yearly, '2026-06-30', 180000, 'يوسف عمر', _S.active, 2, 0),
    _RR('RC-008', 'رواتب الشهر', _Freq.monthly, '2026-04-28', 1842000, 'ليلى أحمد', _S.active, 18, 0),
    _RR('RC-009', 'استحقاق ضريبة GOSI الشهرية', _Freq.monthly, '2026-05-01', 138000, 'ليلى أحمد', _S.active, 18, 0),
    _RR('RC-010', 'توزيع أرباح ربع سنوي', _Freq.quarterly, '2026-06-30', 750000, 'د. محمد الراجحي', _S.paused, 6, 0),
    _RR('RC-011', 'مكافآت أداء ربع سنوية', _Freq.quarterly, '2026-06-30', 340000, 'ليلى أحمد', _S.active, 6, 0),
    _RR('RC-012', 'تسوية مخصصات الديون', _Freq.monthly, '2026-05-01', 45000, 'أحمد محمد', _S.draft, 0, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _rules.where((r) => r.status == _S.active).fold<double>(0, (s, r) => s + r.amount);
    return MultiViewTemplate(
      titleAr: 'القيود الدورية (Recurring Entries)',
      subtitleAr: '${_rules.length} قاعدة · ${_rules.where((r) => r.status == _S.active).length} نشطة · إجمالي شهري ${(total / 1e6).toStringAsFixed(2)}M ر.س',
      enabledViews: const {ViewMode.list, ViewMode.calendar, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'active', labelAr: 'القواعد النشطة', icon: Icons.play_arrow, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'due-soon', labelAr: 'تستحق خلال 7 أيام', icon: Icons.schedule, defaultViewMode: ViewMode.calendar, isShared: true),
        SavedView(id: 'high-value', labelAr: 'عالية القيمة >100K', icon: Icons.star, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'monthly', labelAr: 'شهري', color: core_theme.AC.info, count: _rules.where((r) => r.freq == _Freq.monthly).length, active: _filter == 'monthly'),
        FilterChipDef(id: 'quarterly', labelAr: 'ربع سنوي', color: _gold, count: _rules.where((r) => r.freq == _Freq.quarterly).length, active: _filter == 'quarterly'),
        FilterChipDef(id: 'yearly', labelAr: 'سنوي', color: core_theme.AC.purple, count: _rules.where((r) => r.freq == _Freq.yearly).length, active: _filter == 'yearly'),
        FilterChipDef(id: 'active', labelAr: 'نشطة', color: core_theme.AC.ok, count: _cnt(_S.active), active: _filter == 'active'),
        FilterChipDef(id: 'paused', labelAr: 'متوقفة', color: core_theme.AC.warn, count: _cnt(_S.paused), active: _filter == 'paused'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'قاعدة جديدة',
      listBuilder: (_) => _list(),
      calendarBuilder: (_) => _calendar(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_S s) => _rules.where((r) => r.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _rules : _rules.where((r) {
      if (r.status.name == _filter) return true;
      if (r.freq.name == _filter) return true;
      return false;
    }).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = items[i];
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 60, color: r.status.color),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: r.freq.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(r.freq.icon, color: r.freq.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: r.freq.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(r.freq.labelAr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: r.freq.color))),
              ]),
              Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('المسؤول: ${r.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('المبلغ', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text('${(r.amount / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _gold)),
            ]),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الاستحقاق التالي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Text(r.nextRun, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الإحصائيات', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              Row(children: [
                Icon(Icons.check_circle, size: 12, color: core_theme.AC.ok),
                const SizedBox(width: 2),
                Text('${r.runsDone}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                if (r.runsLeft > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.schedule, size: 12, color: core_theme.AC.td),
                  const SizedBox(width: 2),
                  Text('${r.runsLeft}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ],
              ]),
            ]),
            const SizedBox(width: 20),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: r.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(r.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: r.status.color))),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(r.status == _S.active ? Icons.pause : Icons.play_arrow, size: 18, color: r.status == _S.active ? core_theme.AC.warn : core_theme.AC.ok),
              onPressed: () {},
              tooltip: r.status == _S.active ? 'إيقاف مؤقت' : 'تفعيل',
            ),
          ])),
        );
      },
    );
  }

  Widget _calendar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جدول الاستحقاقات القادمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            ..._rules.where((r) => r.status == _S.active).map((r) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.bdr)),
                child: Row(children: [
                  Container(
                    width: 56, padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: r.freq.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Column(children: [
                      Text(r.nextRun.substring(8), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: r.freq.color)),
                      Text(r.nextRun.substring(5, 7), style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: r.freq.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text(r.freq.labelAr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: r.freq.color))),
                      const SizedBox(width: 6),
                      Text(r.owner, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ]),
                  ])),
                  Text('${(r.amount / 1000).toStringAsFixed(0)}K ر.س', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _gold)),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _chart() {
    final freqs = _Freq.values;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('توزيع القيم حسب التكرار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...freqs.map((f) {
          final rules = _rules.where((r) => r.freq == f && r.status == _S.active).toList();
          final total = rules.fold<double>(0, (s, r) => s + r.amount);
          final annualized = total * (f == _Freq.monthly ? 12 : f == _Freq.quarterly ? 4 : 1);
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: f.color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: f.color.withOpacity(0.3))),
            child: Row(children: [
              Icon(f.icon, color: f.color, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.labelAr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text('${rules.length} قاعدة نشطة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('كل تشغيل', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${(total / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: f.color)),
              ]),
              const SizedBox(width: 24),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('سنوياً', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${(annualized / 1e6).toStringAsFixed(2)}M ر.س', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _gold)),
              ]),
            ]),
          ));
        }),
      ]),
    );
  }
}

enum _Freq { monthly, quarterly, yearly }
enum _S { active, paused, draft }

extension _FreqX on _Freq {
  String get labelAr => switch (this) {
        _Freq.monthly => 'شهري',
        _Freq.quarterly => 'ربع سنوي',
        _Freq.yearly => 'سنوي',
      };
  Color get color => switch (this) {
        _Freq.monthly => core_theme.AC.info,
        _Freq.quarterly => core_theme.AC.gold,
        _Freq.yearly => core_theme.AC.purple,
      };
  IconData get icon => switch (this) {
        _Freq.monthly => Icons.calendar_month,
        _Freq.quarterly => Icons.calendar_view_week,
        _Freq.yearly => Icons.event,
      };
}

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.active => '✓ نشط',
        _S.paused => '⏸ متوقف',
        _S.draft => 'مسودة',
      };
  Color get color => switch (this) {
        _S.active => core_theme.AC.ok,
        _S.paused => core_theme.AC.warn,
        _S.draft => core_theme.AC.td,
      };
}

class _RR {
  final String id, name, owner, nextRun;
  final _Freq freq;
  final double amount;
  final _S status;
  final int runsDone, runsLeft;
  const _RR(this.id, this.name, this.freq, this.nextRun, this.amount, this.owner, this.status, this.runsDone, this.runsLeft);
}
