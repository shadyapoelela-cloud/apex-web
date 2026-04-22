/// V5.2 — Profit Centers using MultiViewTemplate.
///
/// Tracks profitability by business line / division / subsidiary within
/// a single legal entity (SAP CO-PCA pattern).
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class ProfitCentersV52Screen extends StatefulWidget {
  const ProfitCentersV52Screen({super.key});

  @override
  State<ProfitCentersV52Screen> createState() => _ProfitCentersV52ScreenState();
}

class _ProfitCentersV52ScreenState extends State<ProfitCentersV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  static const _centers = <_PC>[
    _PC('PC-1000', 'المجموعة الكلّية', null, 'عبدالله المحمد', 84500000, 62000000, 22500000, _S.profitable),
    _PC('PC-1100', 'الرياض', 'PC-1000', 'أحمد السعيد', 42000000, 30500000, 11500000, _S.profitable),
    _PC('PC-1110', 'فرع الرياض — التجزئة', 'PC-1100', 'محمد العمري', 18500000, 13200000, 5300000, _S.profitable),
    _PC('PC-1120', 'فرع الرياض — الجملة', 'PC-1100', 'خالد الشمراني', 23500000, 17300000, 6200000, _S.profitable),
    _PC('PC-1200', 'جدة', 'PC-1000', 'ليلى أحمد', 28000000, 22000000, 6000000, _S.profitable),
    _PC('PC-1210', 'فرع جدة — المطاعم', 'PC-1200', 'سعاد الشمراني', 9800000, 8600000, 1200000, _S.lowMargin),
    _PC('PC-1220', 'فرع جدة — التجزئة', 'PC-1200', 'ريم القحطاني', 18200000, 13400000, 4800000, _S.profitable),
    _PC('PC-1300', 'الدمام', 'PC-1000', 'يوسف عمر', 12000000, 8800000, 3200000, _S.profitable),
    _PC('PC-1400', 'التصدير', 'PC-1000', 'نورة الدوسري', 2500000, 700000, 1800000, _S.starPerformer),
    _PC('PC-1500', 'الخدمات الرقمية', 'PC-1000', 'سامي طارق', 0, 800000, -800000, _S.loss),
  ];

  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final total = _centers.first;
    return MultiViewTemplate(
      titleAr: 'مراكز الربحية',
      subtitleAr: 'أداء ${_centers.length} مركز ربحية · إجمالي المجموعة ${(total.profit / 1e6).toStringAsFixed(1)}M ر.س',
      enabledViews: const {ViewMode.list, ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.list,
      savedViews: const [
        SavedView(id: 'top', labelAr: 'الأعلى ربحية', icon: Icons.star, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'loss', labelAr: 'خاسرة فقط', icon: Icons.trending_down, defaultViewMode: ViewMode.list, isShared: true),
        SavedView(id: 'by-region', labelAr: 'حسب المنطقة', icon: Icons.map, defaultViewMode: ViewMode.pivot),
      ],
      filterChips: [
        FilterChipDef(id: 'star', labelAr: 'نجوم', icon: Icons.star, color: core_theme.AC.ok, count: _cnt(_S.starPerformer), active: _filter == 'star'),
        FilterChipDef(id: 'profitable', labelAr: 'مربحة', icon: Icons.trending_up, color: _gold, count: _cnt(_S.profitable), active: _filter == 'profitable'),
        FilterChipDef(id: 'lowMargin', labelAr: 'هامش منخفض', icon: Icons.warning, color: core_theme.AC.warn, count: _cnt(_S.lowMargin), active: _filter == 'lowMargin'),
        FilterChipDef(id: 'loss', labelAr: 'خاسرة', icon: Icons.trending_down, color: core_theme.AC.err, count: _cnt(_S.loss), active: _filter == 'loss'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'مركز ربحية جديد',
      listBuilder: (_) => _list(),
      pivotBuilder: (_) => _hierarchy(),
      chartBuilder: (_) => _chart(),
    );
  }

  int _cnt(_S s) => _centers.where((c) => c.status == s).length;

  Widget _list() {
    final items = _filter.isEmpty ? _centers : _centers.where((c) => c.status.name == _filter).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final c = items[i];
        final margin = c.revenue > 0 ? (c.profit / c.revenue * 100) : 0.0;
        final depth = _depth(c);
        return Card(
          elevation: 0.5,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: 12 + depth * 20, end: 12, top: 12, bottom: 12),
            child: Row(children: [
              Container(width: 4, height: 50, color: c.status.color),
              const SizedBox(width: 12),
              Icon(depth == 0 ? Icons.business : Icons.corporate_fare, color: c.status.color, size: 20),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
                Text(c.name, style: TextStyle(fontSize: depth == 0 ? 14 : 13, fontWeight: FontWeight.w800)),
                Text('المسؤول: ${c.manager}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ])),
              _kv('الإيراد', '${(c.revenue / 1e6).toStringAsFixed(2)}M', core_theme.AC.info),
              const SizedBox(width: 14),
              _kv('التكلفة', '${(c.cost / 1e6).toStringAsFixed(2)}M', core_theme.AC.warn),
              const SizedBox(width: 14),
              _kv('الربح', '${(c.profit / 1e6).toStringAsFixed(2)}M', c.profit >= 0 ? core_theme.AC.ok : core_theme.AC.err),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الهامش', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: margin >= 20 ? core_theme.AC.ok : margin >= 10 ? _gold : core_theme.AC.err)),
              ]),
              const SizedBox(width: 14),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(c.status.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.status.color))),
            ]),
          ),
        );
      },
    );
  }

  int _depth(_PC c) {
    if (c.parent == null) return 0;
    final parent = _centers.firstWhere((p) => p.id == c.parent, orElse: () => c);
    return 1 + _depth(parent);
  }

  Widget _kv(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]);
  }

  Widget _hierarchy() {
    // Show hierarchical P&L matrix
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('هيكل المراكز — تحليل Top-Down', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 16),
        Expanded(child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(10), color: _navy, child: const Row(children: [
              Expanded(flex: 3, child: Text('المركز', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              Expanded(child: Text('الإيراد (م ر.س)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('التكلفة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('الربح', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
              Expanded(child: Text('الهامش %', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            ])),
            Expanded(child: ListView(children: _centers.map((c) {
              final depth = _depth(c);
              final margin = c.revenue > 0 ? (c.profit / c.revenue * 100) : 0.0;
              final isRoot = c.parent == null;
              return Container(
                padding: EdgeInsetsDirectional.only(start: 10 + depth * 20, end: 10, top: 10, bottom: 10),
                decoration: BoxDecoration(color: isRoot ? _gold.withOpacity(0.05) : null, border: Border(top: BorderSide(color: core_theme.AC.bdr))),
                child: Row(children: [
                  Expanded(flex: 3, child: Row(children: [
                    if (depth > 0) Text('└ ', style: TextStyle(color: core_theme.AC.td)),
                    Expanded(child: Text(c.name, style: TextStyle(fontSize: isRoot ? 13 : 12, fontWeight: isRoot ? FontWeight.w800 : FontWeight.w500))),
                  ])),
                  Expanded(child: Text((c.revenue / 1e6).toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                  Expanded(child: Text((c.cost / 1e6).toStringAsFixed(2), style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.warn), textAlign: TextAlign.end)),
                  Expanded(child: Text((c.profit / 1e6).toStringAsFixed(2), style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: c.profit >= 0 ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
                  Expanded(child: Text('${margin.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: margin >= 20 ? core_theme.AC.ok : margin >= 10 ? _gold : core_theme.AC.err), textAlign: TextAlign.end)),
                ]),
              );
            }).toList())),
          ]),
        )),
      ]),
    );
  }

  Widget _chart() {
    final leaves = _centers.where((c) => !_centers.any((p) => p.parent == c.id)).toList();
    leaves.sort((a, b) => b.profit.compareTo(a.profit));
    final max = leaves.map((c) => c.profit.abs()).reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مقارنة الربحية (Leaves فقط)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...leaves.map((c) {
          final pct = c.profit.abs() / max;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 200, child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 22, backgroundColor: core_theme.AC.navy3, color: c.profit >= 0 ? core_theme.AC.ok : core_theme.AC.err))),
              const SizedBox(width: 10),
              SizedBox(width: 120, child: Text('${c.profit >= 0 ? '+' : ''}${(c.profit / 1e6).toStringAsFixed(2)}M ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.profit >= 0 ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
            ]),
          ]));
        }),
      ]),
    );
  }
}

enum _S { starPerformer, profitable, lowMargin, loss }

extension _SX on _S {
  String get labelAr => switch (this) {
        _S.starPerformer => '⭐ نجم',
        _S.profitable => 'مربحة',
        _S.lowMargin => 'هامش منخفض',
        _S.loss => 'خاسرة',
      };
  Color get color => switch (this) {
        _S.starPerformer => core_theme.AC.ok,
        _S.profitable => core_theme.AC.gold,
        _S.lowMargin => core_theme.AC.warn,
        _S.loss => core_theme.AC.err,
      };
}

class _PC {
  final String id, name, manager;
  final String? parent;
  final double revenue, cost, profit;
  final _S status;
  const _PC(this.id, this.name, this.parent, this.manager, this.revenue, this.cost, this.profit, this.status);
}
