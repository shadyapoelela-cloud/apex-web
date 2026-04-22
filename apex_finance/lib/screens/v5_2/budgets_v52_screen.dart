/// V5.2 — Budgets List using MultiViewTemplate.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class BudgetsV52Screen extends StatefulWidget {
  const BudgetsV52Screen({super.key});

  @override
  State<BudgetsV52Screen> createState() => _BudgetsV52ScreenState();
}

class _BudgetsV52ScreenState extends State<BudgetsV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _budgets = <_B>[
    _B('B-2026', 'الموازنة السنوية 2026', 'سنوية', '2026-01-01 / 2026-12-31', 84000000, 18400000, _St.active, 'د. محمد الراجحي'),
    _B('B-2026-Q1', 'موازنة الربع الأول 2026', 'ربع سنوية', '2026-01-01 / 2026-03-31', 21000000, 20100000, _St.closed, 'أحمد محمد'),
    _B('B-2026-Q2', 'موازنة الربع الثاني 2026', 'ربع سنوية', '2026-04-01 / 2026-06-30', 21000000, 5200000, _St.active, 'أحمد محمد'),
    _B('B-2026-MKT', 'موازنة التسويق 2026', 'قسمية', '2026-01-01 / 2026-12-31', 2800000, 1100000, _St.active, 'دينا حسام'),
    _B('B-2026-IT', 'موازنة التقنية 2026', 'قسمية', '2026-01-01 / 2026-12-31', 2400000, 820000, _St.overBudget, 'سامي طارق'),
    _B('B-2026-HR', 'موازنة الموارد البشرية', 'قسمية', '2026-01-01 / 2026-12-31', 1400000, 420000, _St.active, 'ليلى أحمد'),
    _B('B-2026-OPS', 'موازنة العمليات', 'قسمية', '2026-01-01 / 2026-12-31', 4800000, 1280000, _St.active, 'يوسف عمر'),
    _B('B-2026-EXP-EXPANSION', 'موازنة توسّع جدة', 'مشروع', '2026-03-01 / 2027-02-28', 1800000, 240000, _St.active, 'سعاد الشمراني'),
    _B('B-2027-DRAFT', 'موازنة 2027 (مسودة)', 'سنوية', '2027-01-01 / 2027-12-31', 95000000, 0, _St.draft, 'أحمد محمد'),
  ];

  @override
  Widget build(BuildContext context) {
    final totalBudget = _budgets.where((b) => b.status == _St.active).fold<double>(0, (s, b) => s + b.budget);
    final totalActual = _budgets.where((b) => b.status == _St.active).fold<double>(0, (s, b) => s + b.actual);
    return MultiViewTemplate(
      titleAr: 'الموازنات',
      subtitleAr: '${_budgets.length} موازنة · إجمالي ${(totalBudget / 1e6).toStringAsFixed(1)}M ر.س · استُخدم ${((totalActual / totalBudget) * 100).toStringAsFixed(1)}%',
      enabledViews: const {ViewMode.list, ViewMode.kanban, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'active', labelAr: 'النشطة فقط', icon: Icons.play_arrow, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'over', labelAr: 'تجاوزت الحد', icon: Icons.warning, defaultViewMode: ViewMode.list),
        SavedView(id: 'depts', labelAr: 'حسب القسم', icon: Icons.pie_chart, defaultViewMode: ViewMode.kanban),
      ],
      filterChips: [
        FilterChipDef(id: 'draft', labelAr: 'مسودة', color: core_theme.AC.td, count: _cnt(_St.draft), active: _filter == 'draft'),
        FilterChipDef(id: 'active', labelAr: 'نشطة', color: core_theme.AC.ok, count: _cnt(_St.active), active: _filter == 'active'),
        FilterChipDef(id: 'overBudget', labelAr: 'تجاوز', color: core_theme.AC.err, count: _cnt(_St.overBudget), active: _filter == 'overBudget'),
        FilterChipDef(id: 'closed', labelAr: 'مغلقة', color: core_theme.AC.info, count: _cnt(_St.closed), active: _filter == 'closed'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'موازنة جديدة',
      listBuilder: (_) => _list(),
      kanbanBuilder: (_) => _kanban(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_St s) => _budgets.where((b) => b.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _budgets : _budgets.where((b) => b.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = items[i];
        final util = b.budget > 0 ? (b.actual / b.budget * 100) : 0.0;
        return Card(
          elevation: 0.5,
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 40, color: b.status.color),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.pie_chart, color: _gold)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(b.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(4)), child: Text(b.type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy))),
                ]),
                Text(b.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text('${b.period} · المسؤول: ${b.owner}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الميزانية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${(b.budget / 1e6).toStringAsFixed(2)}M ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
              ]),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: b.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(b.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: b.status.color))),
            ]),
            if (b.status != _St.draft) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('الفعلي: ${(b.actual / 1e6).toStringAsFixed(2)}M', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${util.toStringAsFixed(1)}% من الميزانية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: util > 100 ? core_theme.AC.err : util > 90 ? core_theme.AC.warn : core_theme.AC.ok)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (util / 100).clamp(0.0, 1.0), minHeight: 10, backgroundColor: core_theme.AC.bdr, color: util > 100 ? core_theme.AC.err : util > 90 ? core_theme.AC.warn : core_theme.AC.ok)),
                ])),
              ]),
            ],
          ])),
        );
      },
    );
  }

  Widget _kanban() {
    final types = ['سنوية', 'ربع سنوية', 'قسمية', 'مشروع'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: types.map((t) {
        final items = _budgets.where((b) => b.type == t).toList();
        final total = items.fold<double>(0, (s, b) => s + b.budget);
        return Container(
          width: 300,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _gold.withOpacity(0.10), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))), child: Row(children: [
              Icon(Icons.pie_chart, color: _gold, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _gold)),
                Text('${(total / 1e6).toStringAsFixed(1)}M ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _gold.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _gold))),
            ])),
            ...items.map((b) {
              final util = b.budget > 0 ? (b.actual / b.budget * 100) : 0.0;
              return Container(
                margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: core_theme.AC.bdr)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.id, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: core_theme.AC.ts)),
                  Text(b.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${(b.budget / 1e6).toStringAsFixed(1)}M ر.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold)),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (util / 100).clamp(0.0, 1.0), minHeight: 4, backgroundColor: core_theme.AC.bdr, color: util > 100 ? core_theme.AC.err : _gold)),
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
    final active = _budgets.where((b) => b.status == _St.active || b.status == _St.overBudget).toList();
    active.sort((a, b) => (b.actual / b.budget).compareTo(a.actual / a.budget));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('استغلال الموازنات النشطة — الأعلى أولاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...active.map((b) {
          final util = b.budget > 0 ? b.actual / b.budget : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 240, child: Text(b.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: Stack(children: [
                Container(height: 22, decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(widthFactor: util.clamp(0.0, 1.0), child: Container(height: 22, decoration: BoxDecoration(color: util > 1.0 ? core_theme.AC.err : _gold, borderRadius: BorderRadius.circular(3)))),
              ])),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: Text('${(util * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: util > 1.0 ? core_theme.AC.err : _gold), textAlign: TextAlign.end)),
            ]),
          ]));
        }),
      ]),
    );
  }
}

enum _St { draft, active, overBudget, closed }

extension _StX on _St {
  String get labelAr => switch (this) {
        _St.draft => 'مسودة',
        _St.active => 'نشطة',
        _St.overBudget => 'تجاوز',
        _St.closed => 'مغلقة',
      };
  Color get color => switch (this) {
        _St.draft => core_theme.AC.td,
        _St.active => core_theme.AC.ok,
        _St.overBudget => core_theme.AC.err,
        _St.closed => core_theme.AC.info,
      };
}

class _B {
  final String id, name, type, period, owner;
  final double budget, actual;
  final _St status;
  const _B(this.id, this.name, this.type, this.period, this.budget, this.actual, this.status, this.owner);
}
