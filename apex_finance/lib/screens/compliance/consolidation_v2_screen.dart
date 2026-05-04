/// APEX — Consolidation v2 (multi-entity + intercompany matrix)
/// /compliance/consolidation-v2 — IFRS 10 consolidation
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ConsolidationV2Screen extends StatefulWidget {
  const ConsolidationV2Screen({super.key});
  @override
  State<ConsolidationV2Screen> createState() => _ConsolidationV2ScreenState();
}

class _ConsolidationV2ScreenState extends State<ConsolidationV2Screen> {
  final List<Map<String, dynamic>> _entities = [
    {'name': 'الشركة الأم', 'ownership': 100.0, 'currency': 'SAR', 'revenue': 5_200_000.0, 'assets': 12_000_000.0},
    {'name': 'الشركة التابعة 1 (تجارة)', 'ownership': 100.0, 'currency': 'SAR', 'revenue': 2_800_000.0, 'assets': 4_500_000.0},
    {'name': 'الشركة التابعة 2 (مقاولات)', 'ownership': 80.0, 'currency': 'SAR', 'revenue': 3_500_000.0, 'assets': 6_200_000.0},
    {'name': 'الشركة الزميلة (إماراتية)', 'ownership': 35.0, 'currency': 'AED', 'revenue': 1_800_000.0, 'assets': 3_400_000.0},
  ];

  // Intercompany transactions (eliminations needed)
  final List<Map<String, dynamic>> _intercompany = [
    {'from': 'الشركة الأم', 'to': 'الشركة التابعة 1', 'type': 'بيع داخلي', 'amount': 450_000.0},
    {'from': 'الشركة التابعة 1', 'to': 'الشركة الأم', 'type': 'إيجار داخلي', 'amount': 120_000.0},
    {'from': 'الشركة الأم', 'to': 'الشركة التابعة 2', 'type': 'قرض داخلي', 'amount': 850_000.0},
  ];

  double get _totalRevenueRaw => _entities.fold<double>(0, (a, e) => a + (e['revenue'] as double) * ((e['ownership'] as double) / 100));
  double get _totalAssetsRaw => _entities.fold<double>(0, (a, e) => a + (e['assets'] as double) * ((e['ownership'] as double) / 100));
  double get _eliminations => _intercompany.fold<double>(0, (a, t) => a + (t['amount'] as double));
  double get _consolidatedRevenue => _totalRevenueRaw - _eliminations;
  double get _consolidatedAssets => _totalAssetsRaw - _eliminations * 0.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('التوحيد المحاسبي (IFRS 10)', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _entitiesCard(),
          const SizedBox(height: 12),
          _intercompanyCard(),
          const SizedBox(height: 12),
          _eliminationCard(),
          const ApexOutputChips(items: [
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
            ApexChipLink('متابعة العملات', '/analytics/multi-currency-v2', Icons.currency_exchange),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard() => Container(
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
          Row(children: [
            Icon(Icons.layers, color: AC.gold, size: 24),
            const SizedBox(width: 10),
            Text('المجموعة الموحّدة',
                style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _miniMetric('إيراد موحّد', _consolidatedRevenue, AC.ok)),
            Expanded(child: _miniMetric('أصول موحّدة', _consolidatedAssets, AC.gold)),
            Expanded(child: _miniMetric('استبعادات', _eliminations, AC.warn)),
          ]),
        ]),
      );

  Widget _miniMetric(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text((v / 1000000).toStringAsFixed(2),
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
          ),
          Text('M SAR', style: TextStyle(color: AC.ts, fontSize: 9)),
        ],
      );

  Widget _entitiesCard() => Container(
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
            child: Row(children: [
              Icon(Icons.business, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Text('الكيانات (${_entities.length})',
                  style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
          ..._entities.map((e) {
            final ownership = e['ownership'] as double;
            final method = ownership >= 50
                ? 'توحيد كامل'
                : ownership >= 20
                    ? 'حقوق ملكية'
                    : 'استثمار';
            final color = ownership >= 50 ? AC.ok : ownership >= 20 ? AC.gold : AC.ts;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.20),
                  child: Text('${ownership.toStringAsFixed(0)}%',
                      style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['name']}',
                        style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text('${e['currency']} · $method',
                        style: TextStyle(color: color, fontSize: 11)),
                  ]),
                ),
                Text('${((e['revenue'] as double) / 1000).toStringAsFixed(0)}K',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ]),
      );

  Widget _intercompanyCard() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.warn.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.swap_horiz, color: AC.warn, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('معاملات بين الشركات (تحتاج استبعاد)',
                    style: TextStyle(color: AC.warn, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text('${_eliminations.toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          ..._intercompany.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
                child: Row(children: [
                  Icon(Icons.east, color: AC.warn, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t['from']} ← ${t['to']}',
                          style: TextStyle(color: AC.tp, fontSize: 11.5)),
                      Text('${t['type']}',
                          style: TextStyle(color: AC.ts, fontSize: 10.5)),
                    ]),
                  ),
                  Text('${(t['amount'] as double).toStringAsFixed(0)} SAR',
                      style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              )),
        ]),
      );

  Widget _eliminationCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.06),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bolt, color: AC.gold),
            const SizedBox(width: 8),
            Text('قيود الاستبعاد (Auto)',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(
            'الذكاء الاصطناعي يقترح ${_intercompany.length} قيود استبعاد لإلغاء المعاملات داخل المجموعة. مجموع الاستبعادات ${_eliminations.toStringAsFixed(0)} ريال.',
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('شغّل الاستبعادات تلقائياً'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ]),
      );
}
