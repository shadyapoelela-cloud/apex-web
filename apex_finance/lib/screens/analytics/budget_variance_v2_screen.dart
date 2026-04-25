/// APEX — Budget vs Actual Variance v2
/// /analytics/budget-variance-v2 — IBCS-style variance dashboard
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class BudgetVarianceV2Screen extends StatefulWidget {
  const BudgetVarianceV2Screen({super.key});
  @override
  State<BudgetVarianceV2Screen> createState() => _BudgetVarianceV2ScreenState();
}

class _BudgetVarianceV2ScreenState extends State<BudgetVarianceV2Screen> {
  String _period = 'mtd';

  // Demo data
  final List<Map<String, dynamic>> _lines = [
    {'category': 'الإيرادات — مبيعات', 'budget': 80000.0, 'actual': 92500.0, 'is_revenue': true},
    {'category': 'الإيرادات — خدمات', 'budget': 25000.0, 'actual': 18750.0, 'is_revenue': true},
    {'category': 'COGS — مواد', 'budget': 30000.0, 'actual': 32100.0, 'is_revenue': false},
    {'category': 'COGS — أجور مباشرة', 'budget': 15000.0, 'actual': 14200.0, 'is_revenue': false},
    {'category': 'مصاريف إدارية', 'budget': 12000.0, 'actual': 13800.0, 'is_revenue': false},
    {'category': 'تسويق وإعلان', 'budget': 8000.0, 'actual': 5500.0, 'is_revenue': false},
    {'category': 'إيجار', 'budget': 10000.0, 'actual': 10000.0, 'is_revenue': false},
    {'category': 'رواتب', 'budget': 35000.0, 'actual': 36500.0, 'is_revenue': false},
  ];

  double get _budgetRev => _lines.where((l) => l['is_revenue'] == true).fold<double>(0, (a, l) => a + (l['budget'] as double));
  double get _actualRev => _lines.where((l) => l['is_revenue'] == true).fold<double>(0, (a, l) => a + (l['actual'] as double));
  double get _budgetExp => _lines.where((l) => l['is_revenue'] == false).fold<double>(0, (a, l) => a + (l['budget'] as double));
  double get _actualExp => _lines.where((l) => l['is_revenue'] == false).fold<double>(0, (a, l) => a + (l['actual'] as double));
  double get _budgetNi => _budgetRev - _budgetExp;
  double get _actualNi => _actualRev - _actualExp;
  double get _niVariance => _actualNi - _budgetNi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('تحليل الانحرافات', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _periodSelector(),
          const SizedBox(height: 12),
          _heroCard(),
          const SizedBox(height: 12),
          _ibcsTableCard(),
          const SizedBox(height: 12),
          _aiCommentaryCard(),
          const ApexOutputChips(items: [
            ApexChipLink('بناء الموازنة', '/analytics/budget-builder', Icons.calculate),
            ApexChipLink('انحراف التكاليف', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
            ApexChipLink('توقع التدفق', '/analytics/cash-flow-forecast', Icons.show_chart),
          ]),
        ]),
      ),
    );
  }

  Widget _periodSelector() => Wrap(spacing: 8, children: [
        for (final p in [('mtd', 'هذا الشهر'), ('qtd', 'هذا الربع'), ('ytd', 'هذه السنة')])
          ChoiceChip(
            label: Text(p.$2),
            selected: _period == p.$1,
            onSelected: (_) => setState(() => _period = p.$1),
            selectedColor: AC.gold,
            labelStyle: TextStyle(color: _period == p.$1 ? AC.navy : AC.tp),
          ),
      ]);

  Widget _heroCard() {
    final positive = _niVariance >= 0;
    final color = positive ? AC.ok : AC.err;
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
        Text('انحراف صافي الدخل',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(positive ? Icons.trending_up : Icons.trending_down, color: color, size: 28),
          const SizedBox(width: 8),
          Text('${positive ? "+" : ""}${_niVariance.toStringAsFixed(0)} SAR',
              style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _miniMetric('الموازنة', _budgetNi, AC.ts)),
          Expanded(child: _miniMetric('الفعلي', _actualNi, color)),
        ]),
      ]),
    );
  }

  Widget _miniMetric(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9)),
        ],
      );

  Widget _ibcsTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: Text('البند', style: _hdr())),
            Expanded(flex: 2, child: Text('الموازنة', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('الفعلي', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('الانحراف', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 3, child: Text('IBCS', style: _hdr(), textAlign: TextAlign.center)),
          ]),
        ),
        ..._lines.map((l) {
          final budget = l['budget'] as double;
          final actual = l['actual'] as double;
          final variance = actual - budget;
          final isRevenue = l['is_revenue'] == true;
          // Favorable: revenue up OR expense down
          final favorable = isRevenue ? variance >= 0 : variance <= 0;
          final color = favorable ? AC.ok : AC.err;
          final pct = budget == 0 ? 0 : variance.abs() / budget;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Text(l['category'],
                    style: TextStyle(color: AC.tp, fontSize: 11.5)),
              ),
              Expanded(
                flex: 2,
                child: Text(budget.toStringAsFixed(0),
                    style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(actual.toStringAsFixed(0),
                    style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text('${variance >= 0 ? "+" : ""}${variance.toStringAsFixed(0)}',
                    style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: _ibcsBar(variance, budget, color, favorable),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // IBCS-style horizontal variance bar
  Widget _ibcsBar(double variance, double budget, Color color, bool favorable) {
    if (budget == 0) return const SizedBox.shrink();
    final pct = (variance.abs() / budget).clamp(0.0, 1.0);
    return Row(children: [
      Expanded(
        flex: variance < 0 ? 1 : 0,
        child: variance < 0
            ? FractionallySizedBox(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: pct,
                child: Container(height: 8, color: color),
              )
            : const SizedBox.shrink(),
      ),
      Container(width: 1, height: 12, color: AC.gold),
      Expanded(
        flex: variance >= 0 ? 1 : 0,
        child: variance >= 0
            ? FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: pct,
                child: Container(height: 8, color: color),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _aiCommentaryCard() {
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
          Text('تعليق الذكاء الاصطناعي',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(
          'الإيرادات تجاوزت الموازنة بنسبة ${((_actualRev - _budgetRev) / _budgetRev * 100).toStringAsFixed(1)}%، '
          'بينما المصاريف زادت بنسبة ${((_actualExp - _budgetExp) / _budgetExp * 100).toStringAsFixed(1)}%. '
          'صافي الدخل أعلى بـ ${_niVariance.toStringAsFixed(0)} ريال. '
          'يُنصح بمراجعة بنود المصاريف الإدارية والرواتب.',
          style: TextStyle(color: AC.tp, fontSize: 13, height: 1.6),
        ),
      ]),
    );
  }

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800);
}
