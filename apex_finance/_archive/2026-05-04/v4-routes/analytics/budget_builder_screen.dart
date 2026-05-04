/// APEX — Budget Builder
/// /analytics/budget-builder — annual budget input by line item
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class BudgetBuilderScreen extends StatefulWidget {
  const BudgetBuilderScreen({super.key});
  @override
  State<BudgetBuilderScreen> createState() => _BudgetBuilderScreenState();
}

class _BudgetBuilderScreenState extends State<BudgetBuilderScreen> {
  String _period = '2027';

  // Account → 12 months (in thousands SAR)
  final Map<String, List<double>> _budget = {
    'إيرادات — مبيعات': [80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 140],
    'إيرادات — خدمات': [25, 26, 28, 30, 32, 33, 35, 37, 38, 40, 42, 45],
    'COGS — مواد': [-30, -32, -34, -36, -38, -40, -42, -44, -46, -48, -50, -54],
    'COGS — أجور': [-15, -15, -16, -16, -17, -17, -18, -18, -19, -19, -20, -21],
    'مصاريف إدارية': [-12, -12, -13, -13, -14, -14, -15, -15, -16, -16, -17, -18],
    'تسويق وإعلان': [-8, -8, -9, -9, -10, -10, -11, -11, -12, -12, -13, -14],
    'إيجار': [-10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10],
    'رواتب': [-35, -35, -36, -36, -37, -37, -38, -38, -39, -39, -40, -41],
  };

  static const _months = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];

  double _yearTotal(String account) =>
      _budget[account]!.fold<double>(0, (a, m) => a + m);
  double _monthTotal(int monthIdx) =>
      _budget.values.fold<double>(0, (a, months) => a + months[monthIdx]);
  double get _yearGrand =>
      _budget.values.fold<double>(0, (a, months) => a + months.fold<double>(0, (b, m) => b + m));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('بناء الموازنة السنوية', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.psychology, color: AC.gold),
            tooltip: 'AI: ولّد الموازنة من بيانات السنة الماضية',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AC.gold,
                  content: Text('AI ولّد توقعاً بنمو 15% YoY',
                      style: TextStyle(color: AC.navy)),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _gridCard(),
          const SizedBox(height: 12),
          _saveCard(),
          const ApexOutputChips(items: [
            ApexChipLink('انحراف الموازنة', '/analytics/budget-variance-v2', Icons.trending_up),
            ApexChipLink('توقع التدفق', '/analytics/cash-flow-forecast', Icons.show_chart),
            ApexChipLink('Health Score', '/analytics/health-score-v2', Icons.health_and_safety),
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.20), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.calculate, color: AC.gold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text('موازنة $_period (آلاف الريالات)',
                  style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            DropdownButton<String>(
              value: _period,
              dropdownColor: AC.navy2,
              items: const [
                DropdownMenuItem(value: '2026', child: Text('2026')),
                DropdownMenuItem(value: '2027', child: Text('2027')),
                DropdownMenuItem(value: '2028', child: Text('2028')),
              ],
              onChanged: (v) => setState(() => _period = v ?? '2027'),
            ),
          ]),
          const SizedBox(height: 8),
          Text('صافي الموازنة: ${(_yearGrand).toStringAsFixed(0)}K SAR',
              style: TextStyle(color: AC.tp, fontSize: 13)),
        ]),
      );

  Widget _gridCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: AC.navy3,
                child: Row(children: [
                  SizedBox(width: 160, child: Text('البند', style: _hdr())),
                  for (final m in _months)
                    SizedBox(width: 50, child: Text(m, style: _hdr(), textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text('السنة', style: _hdr(), textAlign: TextAlign.left)),
                ]),
              ),
              ..._budget.entries.map((entry) {
                final isRevenue = entry.value.first > 0;
                final total = _yearTotal(entry.key);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
                  child: Row(children: [
                    SizedBox(
                      width: 160,
                      child: Text(entry.key,
                          style: TextStyle(color: AC.tp, fontSize: 11.5)),
                    ),
                    for (final v in entry.value)
                      SizedBox(
                        width: 50,
                        child: Text(v.toStringAsFixed(0),
                            style: TextStyle(
                                color: v >= 0 ? AC.ok : AC.warn,
                                fontFamily: 'monospace',
                                fontSize: 10.5),
                            textAlign: TextAlign.center),
                      ),
                    SizedBox(
                      width: 70,
                      child: Text(total.toStringAsFixed(0),
                          style: TextStyle(
                              color: isRevenue ? AC.gold : AC.warn,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.left),
                    ),
                  ]),
                );
              }),
              // Total row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: AC.navy3,
                child: Row(children: [
                  SizedBox(
                    width: 160,
                    child: Text('صافي الشهر',
                        style: TextStyle(color: AC.gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  for (var i = 0; i < 12; i++)
                    SizedBox(
                      width: 50,
                      child: Text(_monthTotal(i).toStringAsFixed(0),
                          style: TextStyle(
                              color: _monthTotal(i) >= 0 ? AC.ok : AC.err,
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                    ),
                  SizedBox(
                    width: 70,
                    child: Text(_yearGrand.toStringAsFixed(0),
                        style: TextStyle(
                            color: _yearGrand >= 0 ? AC.ok : AC.err,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w900),
                        textAlign: TextAlign.left),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _saveCard() => Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.copy, color: AC.gold, size: 16),
            label: Text('انسخ من $_period السابقة', style: TextStyle(color: AC.gold)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AC.ok,
                content: const Text('تم اعتماد الموازنة'),
              ));
            },
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('اعتمد الموازنة'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ),
      ]);

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 10.5, fontWeight: FontWeight.w800);
}
