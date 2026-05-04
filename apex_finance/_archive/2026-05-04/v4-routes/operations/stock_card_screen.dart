/// APEX — Stock Card / Item Movement Timeline
/// /operations/stock-card/:sku — every movement for one SKU
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class StockCardScreen extends StatelessWidget {
  final String sku;
  const StockCardScreen({super.key, this.sku = 'SKU-001'});

  static final List<Map<String, dynamic>> _movements = [
    {'date': '2026-04-25', 'type': 'sale', 'qty': -2, 'unit_cost': 4500.0, 'reference': 'INV-2026-0042', 'running': 22},
    {'date': '2026-04-22', 'type': 'purchase', 'qty': 10, 'unit_cost': 4500.0, 'reference': 'PO-2026-0018', 'running': 24},
    {'date': '2026-04-18', 'type': 'sale', 'qty': -3, 'unit_cost': 4500.0, 'reference': 'INV-2026-0040', 'running': 14},
    {'date': '2026-04-12', 'type': 'sale', 'qty': -1, 'unit_cost': 4500.0, 'reference': 'INV-2026-0039', 'running': 17},
    {'date': '2026-04-08', 'type': 'transfer', 'qty': -5, 'unit_cost': 4500.0, 'reference': 'WH-A→WH-B', 'running': 18},
    {'date': '2026-04-01', 'type': 'opening', 'qty': 23, 'unit_cost': 4500.0, 'reference': 'افتتاحي', 'running': 23},
  ];

  @override
  Widget build(BuildContext context) {
    final currentQty = _movements.first['running'] as int;
    final currentValue = currentQty * 4500.0;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('بطاقة الصنف — $sku', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(currentQty, currentValue),
          const SizedBox(height: 12),
          _movementsCard(),
          const ApexOutputChips(items: [
            ApexChipLink('المخزون', '/operations/inventory-v2', Icons.inventory_2),
            ApexChipLink('بيع سريع POS', '/pos/quick-sale', Icons.point_of_sale),
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard(int qty, double value) => Container(
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
          Text('لابتوب Dell — SKU-001',
              style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _miniMetric('الكمية الحالية', '$qty', AC.gold)),
            Expanded(child: _miniMetric('قيمة المخزون', '${value.toStringAsFixed(0)} SAR', AC.gold)),
            Expanded(child: _miniMetric('المتوسط شهرياً', '8 وحدات', AC.tp)),
          ]),
        ]),
      );

  Widget _miniMetric(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800)),
          ),
        ],
      );

  Widget _movementsCard() => Container(
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
            child: Text('سجل الحركات',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          ..._movements.map((m) {
            final qty = m['qty'] as int;
            final type = m['type'] as String;
            final color = qty > 0 ? AC.ok : type == 'transfer' ? AC.info : AC.warn;
            final icon = type == 'opening' ? Icons.flag :
                qty > 0 ? Icons.add_circle :
                type == 'transfer' ? Icons.swap_horiz : Icons.remove_circle;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['reference']}',
                        style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text('${m['date']} · ${_typeLabel(type)}',
                        style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${qty > 0 ? "+" : ""}$qty',
                      style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('الرصيد ${m['running']}',
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11)),
                ]),
              ]),
            );
          }),
        ]),
      );

  String _typeLabel(String t) => switch (t) {
        'sale' => 'بيع',
        'purchase' => 'شراء',
        'transfer' => 'تحويل بين مستودعات',
        'opening' => 'رصيد افتتاحي',
        _ => t,
      };
}
