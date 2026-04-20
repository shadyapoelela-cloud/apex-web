/// Pilot Dashboard — نظرة شاملة على حالة المستأجر
/// ═════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_data_providers.dart';

class PilotDashboardScreen extends ConsumerWidget {
  const PilotDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e', style: TextStyle(color: AC.err))),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── KPI cards ──
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi('الكيانات', d.entityCount, Icons.domain, AC.info),
                _kpi('الفروع', d.branchCount, Icons.store, AC.gold),
                _kpi('المنتجات', d.productCount, Icons.inventory_2, AC.cyan),
                _kpi('الموظفون', d.memberCount, Icons.people, AC.purple),
                _kpi('قوائم أسعار نشطة', d.activePriceLists,
                    Icons.price_change, AC.warn),
                _kpi('وردية مفتوحة', d.openSessions,
                    Icons.point_of_sale, AC.ok),
              ],
            ),

            const SizedBox(height: 20),

            // ── Month income ──
            if (d.monthIncome != null) _incomeCard(d.monthIncome!),
            const SizedBox(height: 20),

            // ── Trial balance summary ──
            if (d.todayTrialBalance != null) _tbCard(d.todayTrialBalance!),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, int value, IconData icon, Color color) =>
      Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(color: AC.ts, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            Text('$value',
                style: TextStyle(
                    color: AC.tp, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _incomeCard(Map<String, dynamic> inc) {
    final revenue = (inc['revenue_total'] ?? 0).toStringAsFixed(2);
    final expense = (inc['expense_total'] ?? 0).toStringAsFixed(2);
    final net = (inc['net_income'] ?? 0);
    final netNum = (net is num) ? net.toDouble() : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.trending_up, color: AC.gold),
          const SizedBox(width: 8),
          Text('قائمة الدخل — الشهر الحالي',
              style: TextStyle(
                  color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        _incRow('الإيرادات', revenue, AC.ok),
        _incRow('المصروفات', expense, AC.err),
        const Divider(),
        _incRow('صافي الدخل', netNum.toStringAsFixed(2),
            netNum >= 0 ? AC.ok : AC.err,
            bold: true),
      ]),
    );
  }

  Widget _incRow(String label, String val, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: AC.ts))),
          Text(val,
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 18 : 15,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );

  Widget _tbCard(Map<String, dynamic> tb) {
    final rows = (tb['rows'] as List?) ?? [];
    final totalDebit = tb['total_debit'] ?? '0';
    final totalCredit = tb['total_credit'] ?? '0';
    final balanced = tb['balanced'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.balance, color: AC.gold),
          const SizedBox(width: 8),
          Text('ميزان المراجعة — اليوم',
              style: TextStyle(
                  color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: balanced ? AC.ok.withValues(alpha: 0.15) : AC.err.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(balanced ? '✓ متوازن' : '⚠ غير متوازن',
                style: TextStyle(
                    color: balanced ? AC.ok : AC.err,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        Text('إجمالي مدين: $totalDebit    |    إجمالي دائن: $totalCredit',
            style: TextStyle(color: AC.ts, fontSize: 13)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text('لا توجد قيود بعد', style: TextStyle(color: AC.td))
        else
          Column(
            children: rows.take(8).map((r) {
              final m = r as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                    width: 50,
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    decoration: BoxDecoration(
                      color: AC.navy3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(m['code'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AC.gold, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(m['name_ar'] ?? '',
                          style: TextStyle(color: AC.tp))),
                  Text('${m['balance'] ?? 0}',
                      style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
                ]),
              );
            }).toList(),
          ),
      ]),
    );
  }
}
