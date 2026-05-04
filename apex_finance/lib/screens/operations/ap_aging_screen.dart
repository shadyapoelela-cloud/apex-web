/// APEX — AP Aging (مرآة AR Aging)
/// /purchase/aging — buckets: Current / 1-30 / 31-60 / 61-90 / 90+
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ApAgingScreen extends StatefulWidget {
  const ApAgingScreen({super.key});
  @override
  State<ApAgingScreen> createState() => _ApAgingScreenState();
}

class _ApAgingScreenState extends State<ApAgingScreen> {
  List<Map<String, dynamic>> _bills = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListPurchaseInvoices(entityId, limit: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _bills = (res.data as List)
            .cast<Map<String, dynamic>>()
            .where((b) => b['status'] == 'posted')
            .toList();
      } else {
        _error = res.error;
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> get _buckets {
    final result = {
      'current': <Map<String, dynamic>>[],
      '1-30': <Map<String, dynamic>>[],
      '31-60': <Map<String, dynamic>>[],
      '61-90': <Map<String, dynamic>>[],
      '90+': <Map<String, dynamic>>[],
    };
    final now = DateTime.now();
    for (final b in _bills) {
      final dueStr = b['due_date'];
      if (dueStr == null) {
        result['current']!.add(b);
        continue;
      }
      try {
        final due = DateTime.parse(dueStr.toString());
        final days = now.difference(due).inDays;
        if (days <= 0) {
          result['current']!.add(b);
        } else if (days <= 30) {
          result['1-30']!.add(b);
        } else if (days <= 60) {
          result['31-60']!.add(b);
        } else if (days <= 90) {
          result['61-90']!.add(b);
        } else {
          result['90+']!.add(b);
        }
      } catch (_) {
        result['current']!.add(b);
      }
    }
    return result;
  }

  double _bucketSum(String key) =>
      (_buckets[key] ?? []).fold<double>(0,
          (a, b) => a + (((b['total'] as num?)?.toDouble() ?? 0) - ((b['paid_amount'] as num?)?.toDouble() ?? 0)));

  double get _totalAp => _bucketSum('current') + _bucketSum('1-30') + _bucketSum('31-60') + _bucketSum('61-90') + _bucketSum('90+');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('أعمار الذمم — الموردون', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: AC.gold), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AC.err)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 12),
                      _bucketCard('current', 'حالية (لم تستحق)', AC.ok),
                      _bucketCard('1-30', '1-30 يوم', AC.warn),
                      _bucketCard('31-60', '31-60 يوم', Colors.orange),
                      _bucketCard('61-90', '61-90 يوم', AC.err),
                      _bucketCard('90+', 'أكثر من 90 يوم', Colors.red.shade900),
                      const ApexOutputChips(
                        title: 'مرتبطة بـ',
                        items: [
                          ApexChipLink('فواتير الموردين', '/purchase/bills', Icons.receipt_outlined),
                          ApexChipLink('الموردون', '/purchase/vendors', Icons.business),
                          ApexChipLink('توقع التدفق', '/analytics/cash-flow-forecast', Icons.show_chart),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.warn.withValues(alpha: 0.20), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.warn.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إجمالي AP (المستحق للموردين)', style: TextStyle(color: AC.ts, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${_totalAp.toStringAsFixed(0)} SAR',
              style: TextStyle(
                  color: AC.warn, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(height: 12),
          SizedBox(
            height: 12,
            child: Row(children: [
              for (final k in ['current', '1-30', '31-60', '61-90', '90+'])
                if (_bucketSum(k) > 0)
                  Expanded(
                    flex: (_bucketSum(k) * 100).round(),
                    child: Container(color: switch (k) {
                      'current' => AC.ok,
                      '1-30' => AC.warn,
                      '31-60' => Colors.orange,
                      '61-90' => AC.err,
                      _ => Colors.red.shade900,
                    }),
                  ),
            ]),
          ),
        ]),
      );

  Widget _bucketCard(String key, String title, Color color) {
    final bills = _buckets[key] ?? [];
    final sum = _bucketSum(key);
    if (bills.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.20),
          radius: 14,
          child: Text('${bills.length}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        title: Text(title, style: TextStyle(color: AC.tp, fontSize: 13)),
        trailing: Text('${sum.toStringAsFixed(0)} SAR',
            style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        children: bills.map((b) => ListTile(
          dense: true,
          title: Text('${b['bill_number'] ?? b['invoice_number'] ?? '-'}',
              style: TextStyle(color: AC.tp, fontSize: 12.5, fontFamily: 'monospace')),
          subtitle: Text('${b['issue_date']}', style: TextStyle(color: AC.ts, fontSize: 11)),
          trailing: Text('${b['total']} SAR',
              style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12)),
          onTap: () {
            final jeId = b['journal_entry_id'] as String?;
            if (jeId != null) context.go('/app/erp/finance/je-builder/$jeId');
          },
        )).toList(),
      ),
    );
  }
}
