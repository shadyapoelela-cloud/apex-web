/// APEX — Inventory v2 (FIFO/LIFO/WAC valuation)
/// /operations/inventory-v2 — modern inventory with valuation toggle
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class InventoryV2Screen extends StatefulWidget {
  const InventoryV2Screen({super.key});
  @override
  State<InventoryV2Screen> createState() => _InventoryV2ScreenState();
}

class _InventoryV2ScreenState extends State<InventoryV2Screen> {
  String _valuationMethod = 'fifo';
  String _filter = 'all';

  // Demo items — to be replaced with /pilot/products + valuation API
  final List<Map<String, dynamic>> _items = [
    {'sku': 'SKU-001', 'name': 'لابتوب Dell', 'qty': 24, 'unit_cost': 4500, 'category': 'electronics'},
    {'sku': 'SKU-002', 'name': 'طابعة HP', 'qty': 12, 'unit_cost': 1800, 'category': 'electronics'},
    {'sku': 'SKU-003', 'name': 'كرسي مكتبي', 'qty': 45, 'unit_cost': 850, 'category': 'furniture'},
    {'sku': 'SKU-004', 'name': 'طاولة اجتماعات', 'qty': 6, 'unit_cost': 3200, 'category': 'furniture'},
    {'sku': 'SKU-005', 'name': 'رول ورق A4', 'qty': 0, 'unit_cost': 35, 'category': 'consumables'},
    {'sku': 'SKU-006', 'name': 'حبر طابعة', 'qty': 8, 'unit_cost': 220, 'category': 'consumables'},
  ];

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'low' => _items.where((i) => (i['qty'] as int) < 10 && (i['qty'] as int) > 0).toList(),
      'out' => _items.where((i) => (i['qty'] as int) == 0).toList(),
      _ => _items,
    };
  }

  double get _totalValue => _items.fold<double>(
      0, (a, i) => a + ((i['qty'] as int) * (i['unit_cost'] as num).toDouble()));

  // FIFO/LIFO/WAC modifiers (demo — backend computes real value)
  double _adjustedValue(Map<String, dynamic> item) {
    final base = (item['qty'] as int) * (item['unit_cost'] as num).toDouble();
    return switch (_valuationMethod) {
      'fifo' => base,
      'lifo' => base * 1.05,
      'wac' => base * 1.025,
      _ => base,
    };
  }

  double get _adjustedTotal =>
      _items.fold<double>(0, (a, i) => a + _adjustedValue(i));

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'المخزون',
      subtitle: '${_items.length} صنف · قيمة ${_adjustedTotal.toStringAsFixed(0)} SAR (${_valuationMethod.toUpperCase()})',
      primaryCta: ApexCta(
        label: 'صنف جديد',
        icon: Icons.add,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إنشاء صنف — قادمة')),
          );
        },
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _items.length),
        ApexFilterChip(
            label: 'منخفض',
            selected: _filter == 'low',
            onTap: () => setState(() => _filter = 'low'),
            icon: Icons.warning_amber_outlined,
            count: _items.where((i) => (i['qty'] as int) < 10 && (i['qty'] as int) > 0).length),
        ApexFilterChip(
            label: 'نفد',
            selected: _filter == 'out',
            onTap: () => setState(() => _filter = 'out'),
            icon: Icons.error_outline,
            count: _items.where((i) => (i['qty'] as int) == 0).length),
      ],
      items: _filtered,
      onRefresh: () async {},
      listHeader: _valuationCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('بطاقة الصنف', '/operations/stock-card', Icons.timeline),
        ApexChipLink('بيع سريع POS', '/pos/quick-sale', Icons.point_of_sale),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'لا توجد أصناف',
        description: 'أضف أول صنف لتفعيل التقييم والإحصائيات',
        primaryLabel: 'صنف جديد',
        primaryIcon: Icons.add,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, item) {
        final qty = item['qty'] as int;
        final isOut = qty == 0;
        final isLow = qty < 10 && qty > 0;
        final color = isOut ? AC.err : isLow ? AC.warn : AC.ok;
        final value = _adjustedValue(item);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(
                  isOut ? Icons.cancel : isLow ? Icons.warning_amber : Icons.check_circle,
                  color: color,
                  size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['sku']} — ${item['name']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${item['category']}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ]),
            ),
            SizedBox(
              width: 50,
              child: Text('$qty',
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Text(value.toStringAsFixed(0),
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.left),
            ),
          ]),
        );
      },
    );
  }

  Widget _valuationCard() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.06),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.calculate, color: AC.gold, size: 18),
            const SizedBox(width: 8),
            Text('طريقة التقييم',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final m in [
              ('fifo', 'FIFO', 'الوارد أولاً'),
              ('lifo', 'LIFO', 'الوارد أخيراً'),
              ('wac', 'WAC', 'متوسط مرجّح'),
            ])
              ChoiceChip(
                label: Column(children: [
                  Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(m.$3, style: const TextStyle(fontSize: 9.5)),
                ]),
                selected: _valuationMethod == m.$1,
                onSelected: (_) => setState(() => _valuationMethod = m.$1),
                selectedColor: AC.gold,
                labelStyle: TextStyle(color: _valuationMethod == m.$1 ? AC.navy : AC.tp),
              ),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('قيمة المخزون (${_valuationMethod.toUpperCase()})',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            Text('${_adjustedTotal.toStringAsFixed(2)} SAR',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
          ]),
          if (_valuationMethod != 'fifo')
            Text('الفرق عن FIFO: ${(_adjustedTotal - _totalValue).toStringAsFixed(0)} SAR',
                style: TextStyle(color: AC.warn, fontSize: 10.5, fontStyle: FontStyle.italic)),
        ]),
      );
}
