/// V5.2 — Cost Centers using MultiView + Hierarchy.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class CostCentersV52Screen extends StatefulWidget {
  const CostCentersV52Screen({super.key});

  @override
  State<CostCentersV52Screen> createState() => _CostCentersV52ScreenState();
}

class _CostCentersV52ScreenState extends State<CostCentersV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  static const _centers = <_CC>[
    _CC('CC-1000', 'المركز الرئيسي', null, 'د. محمد الراجحي', 22000000, 18400000, _S.underBudget),
    _CC('CC-1100', 'الإدارة التنفيذية', 'CC-1000', 'المجلس', 3400000, 3200000, _S.onBudget),
    _CC('CC-1200', 'الإدارة المالية', 'CC-1000', 'أحمد محمد', 1800000, 1620000, _S.underBudget),
    _CC('CC-1210', 'المحاسبة', 'CC-1200', 'سارة علي', 1200000, 1080000, _S.underBudget),
    _CC('CC-1220', 'الخزينة', 'CC-1200', 'خالد إبراهيم', 600000, 540000, _S.underBudget),
    _CC('CC-1300', 'الموارد البشرية', 'CC-1000', 'ليلى أحمد', 1400000, 1460000, _S.overBudget),
    _CC('CC-1400', 'التقنية (IT)', 'CC-1000', 'سامي طارق', 2400000, 2820000, _S.overBudget),
    _CC('CC-1500', 'التسويق', 'CC-1000', 'دينا حسام', 2800000, 3100000, _S.overBudget),
    _CC('CC-1510', 'الحملات الرقمية', 'CC-1500', 'ريم القحطاني', 1400000, 1620000, _S.overBudget),
    _CC('CC-1520', 'المعارض والفعاليات', 'CC-1500', 'نورة الدوسري', 1400000, 1480000, _S.onBudget),
    _CC('CC-1600', 'المبيعات', 'CC-1000', 'عمر حسن', 3200000, 2920000, _S.underBudget),
    _CC('CC-1700', 'العمليات', 'CC-1000', 'يوسف عمر', 4800000, 4620000, _S.onBudget),
    _CC('CC-1800', 'الفرع — جدة', 'CC-1000', 'سعاد الشمراني', 2200000, 1680000, _S.underBudget),
    _CC('CC-1900', 'الفرع — الدمام', 'CC-1000', 'طلال الغامدي', 1200000, 980000, _S.underBudget),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _centers.first;
    final utilization = (total.actual / total.budget * 100).toInt();
    return MultiViewTemplate(
      titleAr: 'مراكز التكلفة',
      subtitleAr: '${_centers.length} مركز · استغلال الميزانية ${utilization}% · توفير ${((total.budget - total.actual) / 1e6).toStringAsFixed(1)}M ر.س',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'over', labelAr: 'تجاوزت الميزانية', icon: Icons.warning, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'saved', labelAr: 'موفّرة للميزانية', icon: Icons.savings, defaultViewMode: ViewMode.list),
        SavedView(id: 'mine', labelAr: 'مراكزي', icon: Icons.person, defaultViewMode: ViewMode.list),
      ],
      filterChips: [
        FilterChipDef(id: 'onBudget', labelAr: 'ضمن الميزانية', color: core_theme.AC.ok, count: _cnt(_S.onBudget), active: _filter == 'onBudget'),
        FilterChipDef(id: 'underBudget', labelAr: 'توفير', color: _gold, count: _cnt(_S.underBudget), active: _filter == 'underBudget'),
        FilterChipDef(id: 'overBudget', labelAr: 'تجاوز', color: core_theme.AC.err, count: _cnt(_S.overBudget), active: _filter == 'overBudget'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'مركز تكلفة جديد',
      listBuilder: (_) => _list(),
      pivotBuilder: (_) => _hierarchy(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_S s) => _centers.where((c) => c.status == s).length;
  int _depth(_CC c) {
    if (c.parent == null) return 0;
    final parent = _centers.firstWhere((p) => p.id == c.parent, orElse: () => c);
    return 1 + _depth(parent);
  }

  Widget _list() {
    final items = _filter.isEmpty ? _centers : _centers.where((c) => c.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final c = items[i];
        final util = (c.actual / c.budget * 100);
        final depth = _depth(c);
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: 12 + depth * 20, end: 12, top: 12, bottom: 12),
            child: Row(children: [
              Container(width: 4, height: 50, color: c.status.color),
              const SizedBox(width: 12),
              Icon(depth == 0 ? Icons.account_tree : depth == 1 ? Icons.business : Icons.folder, color: c.status.color, size: 20),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                Text(c.name, style: TextStyle(fontSize: depth == 0 ? 14 : 13, fontWeight: FontWeight.w800)),
                Text('المسؤول: ${c.manager}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الميزانية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${(c.budget / 1e6).toStringAsFixed(2)}M', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الفعلي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${(c.actual / 1e6).toStringAsFixed(2)}M', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.status.color)),
              ]),
              const SizedBox(width: 16),
              SizedBox(width: 110, child: Column(children: [
                Row(children: [Text('الاستغلال', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)), const Spacer(), Text('${util.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.status.color))]),
                const SizedBox(height: 2),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (util / 100).clamp(0.0, 1.0), minHeight: 6, backgroundColor: core_theme.AC.bdr, color: c.status.color)),
              ])),
              const SizedBox(width: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(c.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.status.color))),
            ]),
          ),
        );
      },
    );
  }

  Widget _hierarchy() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(10), color: _navy, child: const Row(children: [
            Expanded(flex: 3, child: Text('المركز', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
            Expanded(child: Text('الميزانية', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            Expanded(child: Text('الفعلي', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            Expanded(child: Text('الفرق', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            Expanded(child: Text('الاستغلال', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          ])),
          Expanded(child: ListView(children: _centers.map((c) {
            final depth = _depth(c);
            final variance = c.budget - c.actual;
            final util = (c.actual / c.budget * 100);
            final isRoot = c.parent == null;
            return Container(
              padding: EdgeInsetsDirectional.only(start: 10 + depth * 20, end: 10, top: 10, bottom: 10),
              decoration: BoxDecoration(color: isRoot ? _gold.withValues(alpha: 0.05) : null, border: Border(top: BorderSide(color: core_theme.AC.bdr))),
              child: Row(children: [
                Expanded(flex: 3, child: Row(children: [
                  if (depth > 0) Text('└ ', style: TextStyle(color: core_theme.AC.td)),
                  Expanded(child: Text(c.name, style: TextStyle(fontSize: isRoot ? 13 : 12, fontWeight: isRoot ? FontWeight.w800 : FontWeight.w500))),
                ])),
                Expanded(child: Text((c.budget / 1e6).toStringAsFixed(2) + 'M', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                Expanded(child: Text((c.actual / 1e6).toStringAsFixed(2) + 'M', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: c.status.color), textAlign: TextAlign.end)),
                Expanded(child: Text('${variance >= 0 ? '+' : ''}${(variance / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: variance >= 0 ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
                Expanded(child: Text('${util.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.status.color), textAlign: TextAlign.end)),
              ]),
            );
          }).toList())),
        ]),
      ),
    );
  }

  Widget _chart() {
    final leaves = _centers.where((c) => !_centers.any((p) => p.parent == c.id)).toList();
    leaves.sort((a, b) => (b.actual / b.budget).compareTo(a.actual / a.budget));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('استغلال الميزانية — تنازلياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        Text('يظهر الأعلى تجاوزاً في الأعلى', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 20),
        ...leaves.map((c) {
          final util = (c.actual / c.budget);
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 200, child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: Stack(children: [
                Container(height: 24, decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(widthFactor: util.clamp(0.0, 1.0), child: Container(height: 24, decoration: BoxDecoration(color: c.status.color, borderRadius: BorderRadius.circular(3)))),
                if (util > 1.0) Positioned(
                  right: 0,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: core_theme.AC.err.withValues(alpha: 0.8), borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3))),
                    child: Center(child: Text('+${((util - 1) * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              SizedBox(width: 80, child: Text('${(util * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.status.color), textAlign: TextAlign.end)),
            ]),
          ]));
        }),
      ]),
    );
  }
}

enum _S { onBudget, underBudget, overBudget }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.onBudget => 'ضمن الميزانية',
        _S.underBudget => 'توفير',
        _S.overBudget => 'تجاوز',
      };
  Color get color => switch (this) {
        _S.onBudget => core_theme.AC.ok,
        _S.underBudget => core_theme.AC.gold,
        _S.overBudget => core_theme.AC.err,
      };
}

class _CC {
  final String id, name, manager;
  final String? parent;
  final double budget, actual;
  final _S status;
  const _CC(this.id, this.name, this.parent, this.manager, this.budget, this.actual, this.status);
}
