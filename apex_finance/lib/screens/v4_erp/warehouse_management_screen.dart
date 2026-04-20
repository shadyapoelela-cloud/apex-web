/// APEX Warehouse Management — LIVE backed by Pilot backend.
///
/// Reads warehouses + stock levels from /pilot/*.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/v5/entity_scope_selector.dart' as v5scope;
import '../../pilot/api/pilot_client.dart';
import '../../pilot/bridge/pilot_bridge.dart';

class WarehouseManagementScreen extends StatefulWidget {
  const WarehouseManagementScreen({super.key});
  @override
  State<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends State<WarehouseManagementScreen> {
  PilotBridge get _bridge => PilotBridge.instance;
  PilotClient get _client => pilotClient;

  List<Map<String, dynamic>> _warehouses = [];
  Map<String, List<Map<String, dynamic>>> _stockByWh = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bridge.addListener(_reload);
    v5scope.EntityScopeController.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _bridge.removeListener(_reload);
    v5scope.EntityScopeController.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!_bridge.isBound) {
      setState(() {
        _warehouses = [];
        _stockByWh = {};
      });
      return;
    }
    setState(() => _loading = true);
    final branches = _bridge.branchesForCurrentEntity();
    final allWh = <Map<String, dynamic>>[];
    for (final b in branches) {
      final r = await _client.listWarehouses(b['id']);
      if (r.success) {
        allWh.addAll(List<Map<String, dynamic>>.from(r.data));
      }
    }
    final stock = <String, List<Map<String, dynamic>>>{};
    for (final w in allWh) {
      final r = await _client.getWarehouseStock(w['id']);
      if (r.success) {
        stock[w['id']] = List<Map<String, dynamic>>.from(r.data);
      }
    }
    if (!mounted) return;
    setState(() {
      _warehouses = allWh;
      _stockByWh = stock;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_bridge.isBound) {
      return _empty('ربط مستأجر مطلوب لعرض المستودعات الحقيقية.');
    }
    if (_bridge.currentPilotEntity == null) {
      return _empty('اختر كياناً من شريط العنوان.');
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: AC.navy,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _warehouses.isEmpty
                  ? _empty('لا توجد مستودعات لهذا الكيان.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _warehouses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _warehouseCard(_warehouses[i]),
                    ),
        ),
      ),
    );
  }

  Widget _empty(String msg) => Container(
        color: AC.navy,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warehouse_outlined, size: 64, color: AC.td),
              const SizedBox(height: 12),
              Text(msg, style: TextStyle(color: AC.ts, fontSize: 15)),
            ],
          ),
        ),
      );

  Widget _warehouseCard(Map<String, dynamic> w) {
    final stock = _stockByWh[w['id']] ?? [];
    final totalOnHand = stock.fold<double>(
      0,
      (s, lv) => s + (double.tryParse('${lv['on_hand']}') ?? 0),
    );
    final branchName = _bridge.branchesForCurrentEntity().firstWhere(
          (b) => b['id'] == w['branch_id'],
          orElse: () => <String, dynamic>{'name_ar': '—'},
        )['name_ar'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warehouse, color: AC.gold, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w['name_ar'] ?? w['code'],
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text('$branchName • ${w['code']}',
                    style: TextStyle(color: AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (w['status'] == 'active' ? AC.ok : AC.warn)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(w['status'] ?? '?',
                style: TextStyle(
                    color: w['status'] == 'active' ? AC.ok : AC.warn,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _metric('النوع', w['type'] ?? '—'),
          _metric('أصناف مختلفة', '${stock.length}'),
          _metric('الكمية الإجمالية', totalOnHand.toStringAsFixed(0)),
          if (w['is_default'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('⭐ افتراضي',
                  style: TextStyle(color: AC.gold, fontSize: 11)),
            ),
        ]),
      ]),
    );
  }

  Widget _metric(String k, String v) => Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(color: AC.td, fontSize: 11)),
            const SizedBox(height: 2),
            Text(v,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
