/// APEX — Petty Cash management
/// /operations/petty-cash — small cash fund tracking + replenishment
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({super.key});
  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> {
  static const _initialFund = 5000.0;

  final List<Map<String, dynamic>> _txns = [
    {'date': '2026-04-25', 'description': 'تموين مكتب', 'amount': -185.0, 'category': 'مكتبية'},
    {'date': '2026-04-24', 'description': 'مواصلات اجتماع', 'amount': -120.0, 'category': 'مواصلات'},
    {'date': '2026-04-22', 'description': 'تجديد رصيد', 'amount': 1000.0, 'category': 'replenish'},
    {'date': '2026-04-20', 'description': 'وجبة عمل', 'amount': -340.0, 'category': 'ضيافة'},
    {'date': '2026-04-18', 'description': 'مستلزمات نظافة', 'amount': -75.0, 'category': 'مكتبية'},
    {'date': '2026-04-15', 'description': 'بريد سريع', 'amount': -55.0, 'category': 'بريد'},
  ];

  double get _balance =>
      _initialFund + _txns.fold<double>(0, (a, t) => a + (t['amount'] as double));
  double get _spent => _txns.where((t) => (t['amount'] as double) < 0).fold<double>(0, (a, t) => a + (-(t['amount'] as double)));

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'العهدة النقدية (Petty Cash)',
      subtitle: 'الرصيد ${_balance.toStringAsFixed(0)} SAR',
      primaryCta: ApexCta(
        label: 'إضافة معاملة',
        icon: Icons.add,
        onPressed: () {},
      ),
      items: _txns,
      onRefresh: () async {},
      listHeader: _heroCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/accounting/je-list', Icons.book),
        ApexChipLink('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_long),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.savings,
        title: 'لا توجد معاملات',
        description: 'سجل المصاريف الصغيرة من العهدة النقدية',
      ),
      itemBuilder: (ctx, t) {
        final amount = t['amount'] as double;
        final isReplenish = t['category'] == 'replenish';
        final color = isReplenish ? AC.ok : AC.warn;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(isReplenish ? Icons.add_circle : Icons.remove_circle,
                  color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['description']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${t['category']} · ${t['date']}',
                    style: TextStyle(color: AC.ts, fontSize: 10.5)),
              ]),
            ),
            Text('${amount > 0 ? "+" : ""}${amount.toStringAsFixed(0)} SAR',
                style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }

  Widget _heroCard() {
    final lowBalance = _balance < 1000;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [(lowBalance ? AC.warn : AC.gold).withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: (lowBalance ? AC.warn : AC.gold).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.savings, color: lowBalance ? AC.warn : AC.gold),
          const SizedBox(width: 8),
          Text('الرصيد الحالي',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text('${_balance.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: lowBalance ? AC.warn : AC.gold,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text('من $_initialFund أصلي · مصروف ${_spent.toStringAsFixed(0)}',
            style: TextStyle(color: AC.ts, fontSize: 11)),
        if (lowBalance) ...[
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('طلب تجديد'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.warn, foregroundColor: Colors.white),
          ),
        ],
      ]),
    );
  }
}
