/// APEX — AR Aging (live, computed locally from issued invoices)
/// /sales/aging — buckets: Current / 1-30 / 31-60 / 61-90 / 90+
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class ArAgingScreen extends StatefulWidget {
  const ArAgingScreen({super.key});
  @override
  State<ArAgingScreen> createState() => _ArAgingScreenState();
}

class _ArAgingScreenState extends State<ArAgingScreen> {
  List<Map<String, dynamic>> _invoices = [];
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
    final res = await ApiService.pilotListSalesInvoices(entityId, limit: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _invoices = (res.data as List)
            .cast<Map<String, dynamic>>()
            .where((i) => i['status'] == 'issued')
            .toList();
      } else {
        _error = res.error;
      }
    });
  }

  // Aging buckets (in days past due_date)
  Map<String, List<Map<String, dynamic>>> get _buckets {
    final result = {
      'current': <Map<String, dynamic>>[],
      '1-30': <Map<String, dynamic>>[],
      '31-60': <Map<String, dynamic>>[],
      '61-90': <Map<String, dynamic>>[],
      '90+': <Map<String, dynamic>>[],
    };
    final now = DateTime.now();
    for (final inv in _invoices) {
      final dueStr = inv['due_date'];
      if (dueStr == null) {
        result['current']!.add(inv);
        continue;
      }
      try {
        final due = DateTime.parse(dueStr.toString());
        final days = now.difference(due).inDays;
        if (days <= 0) {
          result['current']!.add(inv);
        } else if (days <= 30) {
          result['1-30']!.add(inv);
        } else if (days <= 60) {
          result['31-60']!.add(inv);
        } else if (days <= 90) {
          result['61-90']!.add(inv);
        } else {
          result['90+']!.add(inv);
        }
      } catch (_) {
        result['current']!.add(inv);
      }
    }
    return result;
  }

  double _bucketSum(String key) =>
      (_buckets[key] ?? []).fold<double>(0,
          (a, i) => a + (((i['total'] as num?)?.toDouble() ?? 0) - ((i['paid_amount'] as num?)?.toDouble() ?? 0)));

  double get _totalAr =>
      _bucketSum('current') + _bucketSum('1-30') + _bucketSum('31-60') + _bucketSum('61-90') + _bucketSum('90+');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('أعمار الذمم — العملاء', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _load,
          ),
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
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إجمالي AR', style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${_totalAr.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: AC.gold, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        const SizedBox(height: 12),
        // Stacked bar showing buckets
        SizedBox(
          height: 12,
          child: Row(children: [
            for (final k in ['current', '1-30', '31-60', '61-90', '90+'])
              if (_bucketSum(k) > 0)
                Expanded(
                  flex: (_bucketSum(k) * 100).round(),
                  child: Container(
                    color: switch (k) {
                      'current' => AC.ok,
                      '1-30' => AC.warn,
                      '31-60' => Colors.orange,
                      '61-90' => AC.err,
                      _ => Colors.red.shade900,
                    },
                  ),
                ),
          ]),
        ),
      ]),
    );
  }

  Widget _bucketCard(String key, String title, Color color) {
    final invoices = _buckets[key] ?? [];
    final sum = _bucketSum(key);
    if (invoices.isEmpty) return const SizedBox.shrink();
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
          child: Text('${invoices.length}',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        title: Text(title, style: TextStyle(color: AC.tp, fontSize: 13)),
        subtitle: Text('${invoices.length} فاتورة',
            style: TextStyle(color: AC.ts, fontSize: 10.5)),
        trailing: Text('${sum.toStringAsFixed(0)} SAR',
            style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        children: invoices.map((inv) => ListTile(
              dense: true,
              title: Text('${inv['invoice_number']}',
                  style: TextStyle(color: AC.tp, fontSize: 12.5, fontFamily: 'monospace')),
              subtitle: Text('${inv['issue_date']}',
                  style: TextStyle(color: AC.ts, fontSize: 11)),
              trailing: Text('${inv['total']} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12)),
              onTap: () {
                final jeId = inv['journal_entry_id'] as String?;
                if (jeId != null) {
                  context.go('/compliance/journal-entry/$jeId');
                }
              },
            )).toList(),
      ),
    );
  }
}
