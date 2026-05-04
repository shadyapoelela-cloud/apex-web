/// APEX — Fixed Assets Register v2
/// /operations/fixed-assets-v2 — IAS 16 register with depreciation schedule
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class FixedAssetsV2Screen extends StatefulWidget {
  const FixedAssetsV2Screen({super.key});
  @override
  State<FixedAssetsV2Screen> createState() => _FixedAssetsV2ScreenState();
}

class _FixedAssetsV2ScreenState extends State<FixedAssetsV2Screen> {
  String _filter = 'all';

  // Demo assets
  final List<Map<String, dynamic>> _assets = [
    {
      'id': 'FA-001', 'name': 'مبنى المقر', 'category': 'building',
      'cost': 2500000.0, 'accumulated': 250000.0, 'method': 'straight_line',
      'useful_life': 25, 'acquired': '2024-01-15',
    },
    {
      'id': 'FA-002', 'name': 'سيارة تويوتا كامري', 'category': 'vehicle',
      'cost': 95000.0, 'accumulated': 19000.0, 'method': 'straight_line',
      'useful_life': 5, 'acquired': '2024-03-10',
    },
    {
      'id': 'FA-003', 'name': 'أجهزة كمبيوتر (15 جهاز)', 'category': 'computer',
      'cost': 75000.0, 'accumulated': 30000.0, 'method': 'straight_line',
      'useful_life': 3, 'acquired': '2024-06-01',
    },
    {
      'id': 'FA-004', 'name': 'أثاث مكتبي', 'category': 'furniture',
      'cost': 45000.0, 'accumulated': 9000.0, 'method': 'straight_line',
      'useful_life': 5, 'acquired': '2024-08-20',
    },
    {
      'id': 'FA-005', 'name': 'آلة تصوير صناعية', 'category': 'machinery',
      'cost': 120000.0, 'accumulated': 96000.0, 'method': 'declining_balance',
      'useful_life': 8, 'acquired': '2020-02-01',
    },
  ];

  double _nbv(Map<String, dynamic> a) => (a['cost'] as double) - (a['accumulated'] as double);
  double get _totalCost => _assets.fold<double>(0, (a, e) => a + (e['cost'] as double));
  double get _totalAcc => _assets.fold<double>(0, (a, e) => a + (e['accumulated'] as double));
  double get _totalNbv => _totalCost - _totalAcc;

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _assets;
    return _assets.where((a) => a['category'] == _filter).toList();
  }

  String _categoryAr(String c) => switch (c) {
        'building' => 'مباني',
        'vehicle' => 'مركبات',
        'computer' => 'حاسبات',
        'furniture' => 'أثاث',
        'machinery' => 'آلات',
        _ => c,
      };

  IconData _categoryIcon(String c) => switch (c) {
        'building' => Icons.business,
        'vehicle' => Icons.directions_car,
        'computer' => Icons.computer,
        'furniture' => Icons.chair,
        'machinery' => Icons.precision_manufacturing,
        _ => Icons.inventory,
      };

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'سجل الأصول الثابتة',
      subtitle: '${_assets.length} أصل · NBV ${_totalNbv.toStringAsFixed(0)} SAR',
      primaryCta: ApexCta(
        label: 'إضافة أصل',
        icon: Icons.add,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إضافة أصل — قادمة')),
          );
        },
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _assets.length),
        for (final cat in ['building', 'vehicle', 'computer', 'furniture', 'machinery'])
          ApexFilterChip(
            label: _categoryAr(cat),
            selected: _filter == cat,
            onTap: () => setState(() => _filter = cat),
            icon: _categoryIcon(cat),
            count: _assets.where((a) => a['category'] == cat).length,
          ),
      ],
      items: _filtered,
      onRefresh: () async {},
      listHeader: _summaryCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
        ApexChipLink('IFRS 16 — الإيجارات', '/compliance/lease-v2', Icons.apartment),
        ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.business,
        title: 'لا توجد أصول مسجّلة',
        description: 'سجّل أول أصل ثابت ليُحسب الإهلاك تلقائياً وفق IAS 16',
        primaryLabel: 'إضافة أصل',
        primaryIcon: Icons.add,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, a) {
        final cost = a['cost'] as double;
        final acc = a['accumulated'] as double;
        final nbv = _nbv(a);
        final pct = cost > 0 ? acc / cost * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AC.gold.withValues(alpha: 0.20),
              child: Icon(_categoryIcon(a['category']), color: AC.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['id']} — ${a['name']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${_categoryAr(a['category'])} · ${a['method']}',
                    style: TextStyle(color: AC.ts, fontSize: 10.5)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: AC.navy3,
                    color: pct > 80 ? AC.err : pct > 50 ? AC.warn : AC.ok,
                    minHeight: 4,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${nbv.toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${pct.toStringAsFixed(0)}% مُهلك',
                  style: TextStyle(color: AC.ts, fontSize: 10)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _summaryCard() => Container(
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
            Icon(Icons.account_balance, color: AC.gold, size: 18),
            const SizedBox(width: 8),
            Text('ملخص IAS 16',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _summaryItem('التكلفة', _totalCost, AC.tp)),
            Expanded(child: _summaryItem('الإهلاك', _totalAcc, AC.warn)),
            Expanded(child: _summaryItem('NBV', _totalNbv, AC.gold)),
          ]),
        ]),
      );

  Widget _summaryItem(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900)),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9)),
        ],
      );
}
