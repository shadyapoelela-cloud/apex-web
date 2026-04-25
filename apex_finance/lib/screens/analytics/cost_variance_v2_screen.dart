/// APEX — Cost Variance v2 (Material / Labour / Overhead breakdown)
/// /analytics/cost-variance-v2 — manufacturing/services variance
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class CostVarianceV2Screen extends StatefulWidget {
  const CostVarianceV2Screen({super.key});
  @override
  State<CostVarianceV2Screen> createState() => _CostVarianceV2ScreenState();
}

class _CostVarianceV2ScreenState extends State<CostVarianceV2Screen> {
  String _category = 'all';

  // Demo variances
  final List<Map<String, dynamic>> _variances = [
    // Material variances
    {'category': 'material', 'name': 'Material Price', 'standard': 50000.0, 'actual': 53500.0, 'unit': 'كرتون', 'qty': 200},
    {'category': 'material', 'name': 'Material Usage', 'standard': 25000.0, 'actual': 23800.0, 'unit': 'متر', 'qty': 1200},
    // Labour variances
    {'category': 'labour', 'name': 'Labour Rate', 'standard': 80000.0, 'actual': 82500.0, 'unit': 'ساعة', 'qty': 800},
    {'category': 'labour', 'name': 'Labour Efficiency', 'standard': 80000.0, 'actual': 75000.0, 'unit': 'ساعة', 'qty': 800},
    // Overhead variances
    {'category': 'overhead', 'name': 'Overhead Volume', 'standard': 30000.0, 'actual': 32500.0, 'unit': '—', 'qty': 0},
    {'category': 'overhead', 'name': 'Overhead Spending', 'standard': 30000.0, 'actual': 28800.0, 'unit': '—', 'qty': 0},
  ];

  String _categoryAr(String c) => switch (c) {
        'material' => 'المواد',
        'labour' => 'العمالة',
        'overhead' => 'المصاريف غير المباشرة',
        _ => c,
      };

  Color _categoryColor(String c) => switch (c) {
        'material' => AC.gold,
        'labour' => AC.info,
        'overhead' => AC.warn,
        _ => AC.ts,
      };

  IconData _categoryIcon(String c) => switch (c) {
        'material' => Icons.precision_manufacturing,
        'labour' => Icons.engineering,
        'overhead' => Icons.calculate,
        _ => Icons.category,
      };

  List<Map<String, dynamic>> get _filtered {
    if (_category == 'all') return _variances;
    return _variances.where((v) => v['category'] == _category).toList();
  }

  double _totalVariance(String? cat) {
    final list = cat == null ? _variances : _variances.where((v) => v['category'] == cat).toList();
    return list.fold<double>(0, (a, v) => a + ((v['actual'] as double) - (v['standard'] as double)));
  }

  @override
  Widget build(BuildContext context) {
    final totalVar = _totalVariance(null);
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('تحليل انحراف التكاليف', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(totalVar),
          const SizedBox(height: 12),
          _categoryRow(),
          const SizedBox(height: 12),
          _variancesCard(),
          const SizedBox(height: 12),
          _aiCommentaryCard(),
          const ApexOutputChips(items: [
            ApexChipLink('انحراف الموازنة', '/analytics/budget-variance-v2', Icons.trending_up),
            ApexChipLink('ربحية المشاريع', '/analytics/project-profitability', Icons.engineering),
            ApexChipLink('المخزون', '/operations/inventory-v2', Icons.inventory_2),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard(double totalVar) {
    final unfavorable = totalVar > 0;
    final color = unfavorable ? AC.err : AC.ok;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إجمالي انحراف التكاليف',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        Text('${unfavorable ? "+" : ""}${totalVar.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        Text(unfavorable ? 'غير ملائم — تكاليف فعلية تجاوزت المعيار' : 'ملائم — وفّرت ${(-totalVar).toStringAsFixed(0)} ريال',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _categoryRow() => Row(children: [
        for (final c in [
          ('all', 'الكل', Icons.apps),
          ('material', 'المواد', Icons.precision_manufacturing),
          ('labour', 'العمالة', Icons.engineering),
          ('overhead', 'OH', Icons.calculate),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                avatar: Icon(c.$3, size: 14, color: _category == c.$1 ? AC.navy : AC.tp),
                label: Text(c.$2, style: const TextStyle(fontSize: 11)),
                selected: _category == c.$1,
                onSelected: (_) => setState(() => _category = c.$1),
                selectedColor: AC.gold,
                labelStyle: TextStyle(color: _category == c.$1 ? AC.navy : AC.tp),
              ),
            ),
          ),
      ]);

  Widget _variancesCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Expanded(flex: 4, child: Text('الانحراف', style: _hdr())),
              Expanded(flex: 2, child: Text('معياري', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('فعلي', style: _hdr(), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('الفرق', style: _hdr(), textAlign: TextAlign.left)),
            ]),
          ),
          ..._filtered.map((v) {
            final std = v['standard'] as double;
            final act = v['actual'] as double;
            final diff = act - std;
            final unfavorable = diff > 0;
            final color = unfavorable ? AC.err : AC.ok;
            final catColor = _categoryColor(v['category'] as String);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                Expanded(flex: 4, child: Row(children: [
                  Icon(_categoryIcon(v['category'] as String), color: catColor, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v['name'] as String,
                          style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(_categoryAr(v['category'] as String),
                          style: TextStyle(color: catColor, fontSize: 10)),
                    ]),
                  ),
                ])),
                Expanded(flex: 2, child: Text(std.toStringAsFixed(0),
                    style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(act.toStringAsFixed(0),
                    style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('${unfavorable ? "+" : ""}${diff.toStringAsFixed(0)}',
                    style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.left)),
              ]),
            );
          }),
        ]),
      );

  Widget _aiCommentaryCard() {
    final matVar = _totalVariance('material');
    final labVar = _totalVariance('labour');
    final ohVar = _totalVariance('overhead');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.psychology, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('تعليق الذكاء',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(
          'انحراف المواد ${matVar > 0 ? "+" : ""}${matVar.toStringAsFixed(0)} ريال (السعر فوق المعيار). '
          'انحراف العمالة ${labVar > 0 ? "+" : ""}${labVar.toStringAsFixed(0)} ريال. '
          'انحراف الإضافي ${ohVar > 0 ? "+" : ""}${ohVar.toStringAsFixed(0)} ريال. '
          'يُنصح بمراجعة عقود الموردين للمواد ومراجعة كفاءة العمالة.',
          style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
        ),
      ]),
    );
  }

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800);
}
