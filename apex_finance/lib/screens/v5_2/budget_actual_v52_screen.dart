/// V5.2 — Budget vs Actual Variance Matrix.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/templates/multi_view_template.dart';

class BudgetActualV52Screen extends StatefulWidget {
  const BudgetActualV52Screen({super.key});

  @override
  State<BudgetActualV52Screen> createState() => _BudgetActualV52ScreenState();
}

class _BudgetActualV52ScreenState extends State<BudgetActualV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);
  String _filter = '';

  // Monthly variance data — 12 months
  static const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

  static const _lines = <_Line>[
    _Line('4110', 'مبيعات المنتجات', 'إيراد',
      [1100000, 1200000, 1300000, 1350000, 1400000, 1400000, 1300000, 1200000, 1400000, 1500000, 1500000, 1550000],
      [1180000, 1260000, 1420000, 1380000, 0, 0, 0, 0, 0, 0, 0, 0]),
    _Line('4120', 'مبيعات الخدمات', 'إيراد',
      [400000, 420000, 440000, 450000, 460000, 470000, 480000, 490000, 500000, 510000, 520000, 530000],
      [410000, 430000, 460000, 480000, 0, 0, 0, 0, 0, 0, 0, 0]),
    _Line('5110', 'تكلفة المبيعات', 'تكلفة',
      [-640000, -680000, -720000, -740000, -760000, -780000, -740000, -700000, -760000, -800000, -820000, -840000],
      [-680000, -720000, -780000, -760000, 0, 0, 0, 0, 0, 0, 0, 0]),
    _Line('5210', 'الرواتب والأجور', 'تشغيلية',
      [-580000, -580000, -580000, -600000, -600000, -600000, -620000, -620000, -620000, -640000, -640000, -660000],
      [-584000, -590000, -598000, -614000, 0, 0, 0, 0, 0, 0, 0, 0]),
    _Line('5230', 'التسويق', 'تشغيلية',
      [-120000, -140000, -130000, -180000, -200000, -220000, -180000, -160000, -180000, -220000, -260000, -200000],
      [-125000, -148000, -142000, -220000, 0, 0, 0, 0, 0, 0, 0, 0]),
    _Line('5240', 'الإهلاك', 'تشغيلية',
      [-80000, -80000, -80000, -85000, -85000, -85000, -85000, -85000, -85000, -90000, -90000, -90000],
      [-80000, -80000, -85000, -85000, 0, 0, 0, 0, 0, 0, 0, 0]),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiViewTemplate(
      titleAr: 'الموازنة مقابل الفعلي — تحليل الانحرافات',
      subtitleAr: '2026 · 6 حسابات رئيسية × 12 شهر · المحلل AI يُنبّه عند الانحراف >10%',
      enabledViews: const {ViewMode.pivot, ViewMode.chart},
      initialView: ViewMode.pivot,
      listBuilder: (_) => _matrix(),
      savedViews: const [
        SavedView(id: 'ytd', labelAr: 'YTD — حتى اليوم', icon: Icons.timeline, defaultViewMode: ViewMode.pivot, isShared: true),
        SavedView(id: 'variance', labelAr: 'أعلى انحرافات', icon: Icons.warning, defaultViewMode: ViewMode.chart, isShared: true),
      ],
      filterChips: [
        FilterChipDef(id: 'revenue', labelAr: 'الإيرادات', color: core_theme.AC.ok, count: _lines.where((l) => l.category == 'إيراد').length, active: _filter == 'revenue'),
        FilterChipDef(id: 'cost', labelAr: 'التكاليف', color: core_theme.AC.warn, count: _lines.where((l) => l.category == 'تكلفة').length, active: _filter == 'cost'),
        FilterChipDef(id: 'opex', labelAr: 'المصروفات', color: core_theme.AC.err, count: _lines.where((l) => l.category == 'تشغيلية').length, active: _filter == 'opex'),
      ],
      onFilterToggle: (id) => setState(() => _filter = _filter == id ? '' : id),
      onCreateNew: () {},
      createLabelAr: 'تحديث الموازنة',
      pivotBuilder: (_) => _matrix(),
      chartBuilder: (_) => _chart(),
    );
  }

  Widget _matrix() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.bdr)),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), color: _navy, child: Row(children: [
            const SizedBox(width: 180, child: Text('الحساب', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            const SizedBox(width: 70, child: Text('الفئة', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
            ...[for (int m = 0; m < 4; m++) Expanded(child: Text(_monthsAr[m], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.center))],
            const SizedBox(width: 110, child: Text('YTD Budget', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            const SizedBox(width: 110, child: Text('YTD Actual', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
            const SizedBox(width: 90, child: Text('الانحراف', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          ])),
          Expanded(child: ListView(
            children: _lines.map((l) {
              final ytdBudget = l.budget.take(4).fold<double>(0, (s, v) => s + v);
              final ytdActual = l.actual.take(4).fold<double>(0, (s, v) => s + v);
              final variance = ytdActual - ytdBudget;
              final variancePct = ytdBudget != 0 ? (variance / ytdBudget * 100).abs() : 0.0;
              final isFavorable = (l.category == 'إيراد' && variance > 0) || (l.category != 'إيراد' && variance < 0);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.bdr))),
                child: Row(children: [
                  SizedBox(width: 180, child: Row(children: [
                    Text(l.id, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: core_theme.AC.ts)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ])),
                  SizedBox(width: 70, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _catColor(l.category).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(l.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _catColor(l.category)))))),
                  ...[for (int m = 0; m < 4; m++) Expanded(child: _cell(l.budget[m], l.actual[m], l.category == 'إيراد'))],
                  SizedBox(width: 110, child: Text((ytdBudget / 1000).toStringAsFixed(0) + 'K', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                  SizedBox(width: 110, child: Text((ytdActual / 1000).toStringAsFixed(0) + 'K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isFavorable ? core_theme.AC.ok : variance == 0 ? core_theme.AC.tp : core_theme.AC.err, fontFamily: 'monospace'), textAlign: TextAlign.end)),
                  SizedBox(width: 90, child: Text('${variance >= 0 ? '+' : ''}${variancePct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isFavorable ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
                ]),
              );
            }).toList(),
          )),
          _totalRow(),
        ]),
      ),
    );
  }

  Widget _cell(double budget, double actual, bool isRevenue) {
    if (actual == 0) {
      return Container(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text((budget.abs() / 1000).toStringAsFixed(0) + 'K', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.td), textAlign: TextAlign.center));
    }
    final variance = actual - budget;
    final isFavorable = (isRevenue && variance > 0) || (!isRevenue && variance < 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: isFavorable ? core_theme.AC.ok.withValues(alpha: 0.05) : core_theme.AC.err.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(3)),
      child: Column(children: [
        Text((actual.abs() / 1000).toStringAsFixed(0) + 'K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isFavorable ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.center),
        Text('${variance >= 0 ? '+' : ''}${(variance.abs() / 1000).toStringAsFixed(0)}K', style: TextStyle(fontSize: 8, color: isFavorable ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _totalRow() {
    final budgetTotal = _lines.fold<double>(0, (s, l) => s + l.budget.take(4).fold<double>(0, (a, v) => a + v));
    final actualTotal = _lines.fold<double>(0, (s, l) => s + l.actual.take(4).fold<double>(0, (a, v) => a + v));
    return Container(
      padding: const EdgeInsets.all(12),
      color: _gold.withValues(alpha: 0.08),
      child: Row(children: [
        SizedBox(width: 180, child: Text('الإجماليات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy))),
        const SizedBox(width: 70),
        const Expanded(child: SizedBox()),
        const Expanded(child: SizedBox()),
        const Expanded(child: SizedBox()),
        const Expanded(child: SizedBox()),
        SizedBox(width: 110, child: Text('${(budgetTotal / 1e6).toStringAsFixed(2)}M', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace'), textAlign: TextAlign.end)),
        SizedBox(width: 110, child: Text('${(actualTotal / 1e6).toStringAsFixed(2)}M', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _gold, fontFamily: 'monospace'), textAlign: TextAlign.end)),
        SizedBox(width: 90, child: Text('${(((actualTotal - budgetTotal) / budgetTotal).abs() * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.ok), textAlign: TextAlign.end)),
      ]),
    );
  }

  Color _catColor(String cat) {
    if (cat == 'إيراد') return core_theme.AC.ok;
    if (cat == 'تكلفة') return core_theme.AC.warn;
    return core_theme.AC.err;
  }

  Widget _chart() {
    final variances = _lines.map((l) {
      final ytdB = l.budget.take(4).fold<double>(0, (s, v) => s + v);
      final ytdA = l.actual.take(4).fold<double>(0, (s, v) => s + v);
      return (l.name, l.category, ytdB, ytdA, ytdA - ytdB);
    }).toList();
    variances.sort((a, b) => b.$5.abs().compareTo(a.$5.abs()));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('أعلى 6 انحرافات YTD (بالقيمة)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 20),
        ...variances.map((v) {
          final max = variances.first.$5.abs();
          final pct = v.$5.abs() / max;
          final isRev = v.$2 == 'إيراد';
          final isFav = (isRev && v.$5 > 0) || (!isRev && v.$5 < 0);
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 180, child: Text(v.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 22, backgroundColor: core_theme.AC.navy3, color: isFav ? core_theme.AC.ok : core_theme.AC.err))),
              const SizedBox(width: 10),
              SizedBox(width: 140, child: Text('${v.$5 >= 0 ? '+' : ''}${(v.$5.abs() / 1000).toStringAsFixed(0)}K ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isFav ? core_theme.AC.ok : core_theme.AC.err), textAlign: TextAlign.end)),
            ]),
          ]));
        }),
      ]),
    );
  }
}

class _Line {
  final String id, name, category;
  final List<double> budget, actual;
  const _Line(this.id, this.name, this.category, this.budget, this.actual);
}
