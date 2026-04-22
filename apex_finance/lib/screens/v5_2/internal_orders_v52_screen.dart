/// V5.2 — Internal Orders using MultiViewTemplate.
///
/// Short-term cost tracking for campaigns, events, R&D projects, exhibitions.
/// SAP CO-OPA pattern: plan → release → actual → settlement → close.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class InternalOrdersV52Screen extends StatefulWidget {
  const InternalOrdersV52Screen({super.key});

  @override
  State<InternalOrdersV52Screen> createState() => _InternalOrdersV52ScreenState();
}

class _InternalOrdersV52ScreenState extends State<InternalOrdersV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _orders = <_IO>[
    _IO('IO-2026-142', 'حملة إطلاق منتج Q2', 'تسويق', 'دينا حسام', 420000, 380000, '2026-04-01', '2026-06-30', _S.active),
    _IO('IO-2026-141', 'معرض الرياض الدولي', 'تسويق', 'أحمد العمري', 280000, 310000, '2026-03-15', '2026-04-20', _S.overBudget),
    _IO('IO-2026-140', 'تطوير منتج AI جديد', 'R&D', 'سامي طارق', 1800000, 1240000, '2026-01-01', '2026-12-31', _S.active),
    _IO('IO-2026-139', 'تدريب الموظفين Q2', 'HR', 'ليلى أحمد', 180000, 82000, '2026-04-01', '2026-06-30', _S.active),
    _IO('IO-2026-138', 'إعادة تصميم العلامة', 'تسويق', 'ريم القحطاني', 340000, 340000, '2026-02-01', '2026-04-30', _S.released),
    _IO('IO-2026-137', 'مؤتمر تقني Q3', 'تسويق', 'خالد الشمراني', 220000, 0, '2026-07-01', '2026-09-15', _S.planning),
    _IO('IO-2026-136', 'تحديث البنية التحتية IT', 'IT', 'يوسف عمر', 960000, 840000, '2026-01-15', '2026-03-31', _S.closed),
    _IO('IO-2026-135', 'افتتاح فرع جدة', 'تشغيل', 'سعاد الشمراني', 1400000, 1420000, '2025-11-01', '2026-02-28', _S.closed),
    _IO('IO-2026-134', 'دراسة جدوى للإمارات', 'استراتيجية', 'د. محمد الراجحي', 420000, 380000, '2026-02-15', '2026-05-31', _S.active),
    _IO('IO-2026-133', 'بحث السوق H1', 'تسويق', 'نورة الدوسري', 140000, 128000, '2026-01-01', '2026-06-30', _S.active),
  ];

  @override
  Widget build(BuildContext context) {
    final totalBudget = _orders.fold<double>(0, (s, o) => s + o.budget);
    final totalActual = _orders.fold<double>(0, (s, o) => s + o.actual);
    return MultiViewTemplate(
      titleAr: 'الأوامر الداخلية',
      subtitleAr: '${_orders.length} أمر · ميزانية إجمالية ${(totalBudget / 1e6).toStringAsFixed(1)}M · فعلي ${(totalActual / 1e6).toStringAsFixed(1)}M',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.kanban,
      savedViews: const [
        SavedView(id: 'active', labelAr: 'النشطة', icon: Icons.play_arrow, defaultViewMode: ViewMode.kanban, isShared: true),
        SavedView(id: 'over', labelAr: 'تجاوزت الميزانية', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'marketing', labelAr: 'التسويق فقط', icon: Icons.campaign, defaultViewMode: ViewMode.kanban),
      ],
      filterChips: [
        FilterChipDef(id: 'planning', labelAr: 'تخطيط', color: core_theme.AC.td, count: _cnt(_S.planning), active: _filter == 'planning'),
        FilterChipDef(id: 'released', labelAr: 'مُفرج', color: core_theme.AC.info, count: _cnt(_S.released), active: _filter == 'released'),
        FilterChipDef(id: 'active', labelAr: 'نشط', color: core_theme.AC.ok, count: _cnt(_S.active), active: _filter == 'active'),
        FilterChipDef(id: 'overBudget', labelAr: 'تجاوز الميزانية', color: core_theme.AC.err, count: _cnt(_S.overBudget), active: _filter == 'overBudget'),
        FilterChipDef(id: 'closed', labelAr: 'مُغلق', color: core_theme.AC.ts, count: _cnt(_S.closed), active: _filter == 'closed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'أمر داخلي جديد',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_S s) => _orders.where((o) => o.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _orders : _orders.where((o) => o.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final o = items[i];
        final util = o.budget > 0 ? (o.actual / o.budget).clamp(0.0, 2.0) : 0.0;
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 4, height: 56, color: o.status.color),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(4)), child: Text(o.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
              ]),
              Text(o.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text('${o.manager} · ${o.start} → ${o.end}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ])),
            SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [Text('الفعلي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)), const Spacer(), Text('${(o.actual / 1000).toStringAsFixed(0)}K / ${(o.budget / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 2),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: util.clamp(0.0, 1.0), minHeight: 8, backgroundColor: core_theme.AC.bdr, color: util > 1.0 ? core_theme.AC.err : util > 0.9 ? core_theme.AC.warn : core_theme.AC.ok)),
              Text('${(util * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: util > 1.0 ? core_theme.AC.err : util > 0.9 ? core_theme.AC.warn : core_theme.AC.ok)),
            ])),
            const SizedBox(width: 16),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: o.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(o.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: o.status.color))),
          ])),
        );
      },
    );
  }

  Widget _kanban() {
    final cols = [_S.planning, _S.released, _S.active, _S.overBudget, _S.closed];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols.map((s) {
        final items = _orders.where((o) => o.status == s).toList();
        final total = items.fold<double>(0, (sum, o) => sum + o.budget);
        return Container(
          width: 280,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.color.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.labelAr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.color)),
                Text('${(total / 1000).toStringAsFixed(0)}K ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.color))),
            ])),
            ...items.map((o) {
              final util = o.budget > 0 ? (o.actual / o.budget).clamp(0.0, 2.0) : 0.0;
              return Container(
                margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(o.id, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: core_theme.AC.ts)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(3)), child: Text(o.category, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _navy))),
                  ]),
                  Text(o.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(o.manager, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: util.clamp(0.0, 1.0), minHeight: 6, backgroundColor: core_theme.AC.bdr, color: util > 1.0 ? core_theme.AC.err : _gold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${(o.actual / 1000).toStringAsFixed(0)}K / ${(o.budget / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    const Spacer(),
                    Text('${(util * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: util > 1.0 ? core_theme.AC.err : _gold)),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ]),
        );
      }).toList()),
    );
  }

  Widget _chart() {
    final by = <String, (double, double)>{};
    for (final o in _orders) {
      final cur = by[o.category] ?? (0.0, 0.0);
      by[o.category] = (cur.$1 + o.budget, cur.$2 + o.actual);
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الميزانية مقابل الفعلي حسب الفئة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...by.entries.map((e) {
          final util = e.value.$1 > 0 ? e.value.$2 / e.value.$1 : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const Spacer(), Text('${(util * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: util > 1.0 ? core_theme.AC.err : _gold))]),
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(width: 80, child: Text('الميزانية', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: 1.0, minHeight: 14, backgroundColor: core_theme.AC.navy3, color: _navy.withOpacity(0.5)))),
              const SizedBox(width: 10),
              Text('${(e.value.$1 / 1e6).toStringAsFixed(2)}M', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 80, child: Text('الفعلي', style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: util.clamp(0.0, 1.0), minHeight: 14, backgroundColor: core_theme.AC.navy3, color: util > 1.0 ? core_theme.AC.err : _gold))),
              const SizedBox(width: 10),
              Text('${(e.value.$2 / 1e6).toStringAsFixed(2)}M', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: util > 1.0 ? core_theme.AC.err : _gold)),
            ]),
          ]));
        }),
      ]),
    );
  }
}

enum _S { planning, released, active, overBudget, closed }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.planning => 'تخطيط',
        _S.released => 'مُفرج',
        _S.active => 'نشط',
        _S.overBudget => 'تجاوز الميزانية',
        _S.closed => 'مُغلق',
      };
  Color get color => switch (this) {
        _S.planning => core_theme.AC.td,
        _S.released => core_theme.AC.info,
        _S.active => core_theme.AC.ok,
        _S.overBudget => core_theme.AC.err,
        _S.closed => const Color(0xFF607D8B),
      };
}

class _IO {
  final String id, title, category, manager, start, end;
  final double budget, actual;
  final _S status;
  const _IO(this.id, this.title, this.category, this.manager, this.budget, this.actual, this.start, this.end, this.status);
}
