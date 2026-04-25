/// APEX — Recurring Invoices (subscription billing)
/// /sales/recurring — auto-bill on schedule
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';

class RecurringInvoicesScreen extends StatefulWidget {
  const RecurringInvoicesScreen({super.key});
  @override
  State<RecurringInvoicesScreen> createState() => _RecurringInvoicesScreenState();
}

class _RecurringInvoicesScreenState extends State<RecurringInvoicesScreen> {
  String _filter = 'active';

  final List<Map<String, dynamic>> _profiles = [
    {
      'id': 'REC-001', 'customer': 'شركة الرياض للمقاولات',
      'amount': 11500.0, 'frequency': 'monthly',
      'next_run': '2026-05-01', 'status': 'active',
      'invoices_issued': 12, 'total_billed': 138000.0,
    },
    {
      'id': 'REC-002', 'customer': 'شركة جدة العقارية',
      'amount': 3450.0, 'frequency': 'monthly',
      'next_run': '2026-05-15', 'status': 'active',
      'invoices_issued': 8, 'total_billed': 27600.0,
    },
    {
      'id': 'REC-003', 'customer': 'شركة الدمام للصناعة',
      'amount': 25000.0, 'frequency': 'quarterly',
      'next_run': '2026-07-01', 'status': 'active',
      'invoices_issued': 4, 'total_billed': 100000.0,
    },
    {
      'id': 'REC-004', 'customer': 'شركة المدينة',
      'amount': 5750.0, 'frequency': 'monthly',
      'next_run': null, 'status': 'paused',
      'invoices_issued': 6, 'total_billed': 34500.0,
    },
    {
      'id': 'REC-005', 'customer': 'شركة مكة',
      'amount': 8500.0, 'frequency': 'annual',
      'next_run': '2026-12-31', 'status': 'active',
      'invoices_issued': 1, 'total_billed': 8500.0,
    },
  ];

  String _freqAr(String f) => switch (f) {
        'weekly' => 'أسبوعي',
        'monthly' => 'شهري',
        'quarterly' => 'ربع سنوي',
        'annual' => 'سنوي',
        _ => f,
      };

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'active' => _profiles.where((p) => p['status'] == 'active').toList(),
      'paused' => _profiles.where((p) => p['status'] == 'paused').toList(),
      _ => _profiles,
    };
  }

  double get _mrr {
    var total = 0.0;
    for (final p in _profiles.where((p) => p['status'] == 'active')) {
      final amount = p['amount'] as double;
      total += switch (p['frequency']) {
        'weekly' => amount * 4.33,
        'monthly' => amount,
        'quarterly' => amount / 3,
        'annual' => amount / 12,
        _ => amount,
      };
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'الفواتير المتكررة',
      subtitle: '${_profiles.length} اشتراك · MRR ${_mrr.toStringAsFixed(0)} SAR',
      primaryCta: ApexCta(
        label: 'اشتراك جديد',
        icon: Icons.add,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إنشاء اشتراك متكرر — قادمة')),
          );
        },
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _profiles.length),
        ApexFilterChip(
            label: 'فعال', selected: _filter == 'active',
            onTap: () => setState(() => _filter = 'active'),
            icon: Icons.play_arrow,
            count: _profiles.where((p) => p['status'] == 'active').length),
        ApexFilterChip(
            label: 'متوقف', selected: _filter == 'paused',
            onTap: () => setState(() => _filter = 'paused'),
            icon: Icons.pause,
            count: _profiles.where((p) => p['status'] == 'paused').length),
      ],
      items: _filtered,
      onRefresh: () async {},
      listHeader: _mrrCard(),
      emptyState: ApexEmptyState(
        icon: Icons.repeat,
        title: 'لا توجد اشتراكات',
        description: 'الفواتير المتكررة تُصدر تلقائياً حسب الجدول',
        primaryLabel: 'إنشاء اشتراك',
        primaryIcon: Icons.add,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, p) {
        final isActive = p['status'] == 'active';
        final color = isActive ? AC.ok : AC.ts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(isActive ? Icons.repeat : Icons.pause, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['id']} — ${p['customer']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Row(children: [
                  Text('${_freqAr(p['frequency'] as String)}',
                      style: TextStyle(color: color, fontSize: 11)),
                  if (p['next_run'] != null) ...[
                    Text(' · التالي: ${p['next_run']}',
                        style: TextStyle(color: AC.ts, fontSize: 10.5, fontFamily: 'monospace')),
                  ],
                ]),
                Text('${p['invoices_issued']} فاتورة صادرة · إجمالي ${(p['total_billed'] as double).toStringAsFixed(0)} SAR',
                    style: TextStyle(color: AC.ts, fontSize: 10.5)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(p['amount'] as double).toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
              Text('/ ${_freqAr(p['frequency'] as String).toLowerCase()}',
                  style: TextStyle(color: AC.ts, fontSize: 9.5)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _mrrCard() {
    final activeCount = _profiles.where((p) => p['status'] == 'active').length;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.repeat, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text('Monthly Recurring Revenue (MRR)',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text('${_mrr.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: AC.gold,
                fontSize: 26,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900)),
        Text('من $activeCount اشتراك فعال · ARR ≈ ${(_mrr * 12).toStringAsFixed(0)} SAR',
            style: TextStyle(color: AC.ts, fontSize: 11.5)),
      ]),
    );
  }
}
