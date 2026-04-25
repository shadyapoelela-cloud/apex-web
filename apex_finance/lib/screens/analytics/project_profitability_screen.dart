/// APEX — Project Profitability
/// /analytics/project-profitability — per-project P&L
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ProjectProfitabilityScreen extends StatelessWidget {
  const ProjectProfitabilityScreen({super.key});

  static final List<Map<String, dynamic>> _projects = [
    {
      'id': 'PRJ-001', 'name': 'مبنى الرياض التجاري', 'client': 'شركة الرياض للمقاولات',
      'budget': 5000000.0, 'actual_cost': 4200000.0, 'revenue': 6500000.0,
      'progress': 0.85, 'due': '2026-08-30', 'status': 'on_track',
    },
    {
      'id': 'PRJ-002', 'name': 'تطوير ERP داخلي', 'client': 'داخلي',
      'budget': 800000.0, 'actual_cost': 920000.0, 'revenue': 0.0,
      'progress': 0.95, 'due': '2026-05-30', 'status': 'over_budget',
    },
    {
      'id': 'PRJ-003', 'name': 'تشييد فيلا جدة', 'client': 'شركة جدة العقارية',
      'budget': 2200000.0, 'actual_cost': 1450000.0, 'revenue': 2800000.0,
      'progress': 0.65, 'due': '2026-12-15', 'status': 'on_track',
    },
    {
      'id': 'PRJ-004', 'name': 'صيانة دورية — الدمام', 'client': 'شركة الدمام للصناعة',
      'budget': 350000.0, 'actual_cost': 280000.0, 'revenue': 480000.0,
      'progress': 1.0, 'due': '2026-04-01', 'status': 'complete',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final totalRev = _projects.fold<double>(0, (a, p) => a + (p['revenue'] as double));
    final totalCost = _projects.fold<double>(0, (a, p) => a + (p['actual_cost'] as double));
    final totalGross = totalRev - totalCost;
    final marginPct = totalRev == 0 ? 0 : totalGross / totalRev * 100;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('ربحية المشاريع', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(totalRev, totalCost, totalGross, marginPct.toDouble()),
          const SizedBox(height: 12),
          ..._projects.map(_projectCard),
          const ApexOutputChips(items: [
            ApexChipLink('انحراف التكاليف', '/analytics/cost-variance-v2', Icons.precision_manufacturing),
            ApexChipLink('بناء الموازنة', '/analytics/budget-builder', Icons.calculate),
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard(double rev, double cost, double gross, double margin) {
    final color = gross >= 0 ? AC.ok : AC.err;
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
        Text('إجمالي ربح المحفظة',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        Text('${gross.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        Text('هامش ${margin.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _miniMetric('الإيرادات', rev, AC.gold)),
          Expanded(child: _miniMetric('التكاليف', cost, AC.warn)),
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
                  fontSize: 16,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
        ],
      );

  Widget _projectCard(Map<String, dynamic> p) {
    final budget = p['budget'] as double;
    final actual = p['actual_cost'] as double;
    final revenue = p['revenue'] as double;
    final gross = revenue - actual;
    final marginPct = revenue == 0 ? 0 : gross / revenue * 100;
    final status = p['status'] as String;
    final progress = p['progress'] as double;
    final budgetUtil = budget == 0 ? 0 : actual / budget;
    final statusColor = switch (status) {
      'on_track' => AC.ok,
      'over_budget' => AC.err,
      'complete' => AC.gold,
      _ => AC.warn,
    };
    final statusLabel = switch (status) {
      'on_track' => 'على المسار',
      'over_budget' => 'تجاوز الموازنة',
      'complete' => 'مكتمل',
      _ => 'متأخر',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Text('${p['id']}',
              style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11)),
          const Spacer(),
          Text('${p['due']}',
              style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Text('${p['name']}',
            style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
        Text('${p['client']}', style: TextStyle(color: AC.ts, fontSize: 11)),
        const SizedBox(height: 10),
        // Progress bar
        Row(children: [
          Text('التقدم', style: TextStyle(color: AC.ts, fontSize: 10.5)),
          const SizedBox(width: 4),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: AC.tp, fontSize: 10.5)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress, backgroundColor: AC.navy3, color: AC.gold, minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('الموازنة', style: TextStyle(color: AC.ts, fontSize: 10.5)),
          const SizedBox(width: 4),
          Text('${(budgetUtil * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: budgetUtil > 1 ? AC.err : AC.tp, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: budgetUtil.clamp(0.0, 1.0).toDouble(),
            backgroundColor: AC.navy3,
            color: budgetUtil > 1 ? AC.err : budgetUtil > 0.9 ? AC.warn : AC.ok,
            minHeight: 6,
          ),
        ),
        const Divider(),
        Row(children: [
          Expanded(child: _projMetric('إيراد', revenue, AC.ok)),
          Expanded(child: _projMetric('تكلفة', actual, AC.warn)),
          Expanded(child: _projMetric('ربح', gross, gross >= 0 ? AC.ok : AC.err)),
          Expanded(child: _projMetric('هامش', marginPct.toDouble(), marginPct >= 0 ? AC.ok : AC.err, isPercent: true)),
        ]),
      ]),
    );
  }

  Widget _projMetric(String label, double v, Color color, {bool isPercent = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10)),
          Text(isPercent ? '${v.toStringAsFixed(1)}%' : v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
        ],
      );
}
