/// APEX — Withholding Tax v2 (Saudi-aware)
/// /compliance/wht-v2 — WHT calculation + monthly summary
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class WhtV2Screen extends StatefulWidget {
  const WhtV2Screen({super.key});
  @override
  State<WhtV2Screen> createState() => _WhtV2ScreenState();
}

class _WhtV2ScreenState extends State<WhtV2Screen> {
  // Saudi WHT rates
  static const _categories = [
    ('rent', 'إيجار', 5.0),
    ('royalty', 'إتاوات', 15.0),
    ('management', 'خدمات إدارية', 20.0),
    ('technical', 'خدمات فنية', 5.0),
    ('international', 'تحويلات دولية', 5.0),
    ('directors', 'مكافآت مديرين', 20.0),
  ];

  // Demo transactions
  final List<Map<String, dynamic>> _txns = [
    {'vendor': 'شركة استشارات إدارية (مصرية)', 'category': 'management', 'gross': 35000.0, 'date': '2026-04-22'},
    {'vendor': 'مكتب محاماة دولي', 'category': 'technical', 'gross': 18000.0, 'date': '2026-04-20'},
    {'vendor': 'مالك العقار', 'category': 'rent', 'gross': 12000.0, 'date': '2026-04-15'},
    {'vendor': 'شركة برمجيات (هندية)', 'category': 'royalty', 'gross': 8500.0, 'date': '2026-04-10'},
    {'vendor': 'مدير الشركة', 'category': 'directors', 'gross': 25000.0, 'date': '2026-04-05'},
  ];

  double _whtAmount(Map<String, dynamic> t) {
    final rate = _categories.firstWhere((c) => c.$1 == t['category']).$3;
    return (t['gross'] as double) * rate / 100;
  }

  double get _totalGross => _txns.fold<double>(0, (a, t) => a + (t['gross'] as double));
  double get _totalWht => _txns.fold<double>(0, (a, t) => a + _whtAmount(t));
  double get _netPayable => _totalGross - _totalWht;

  String _categoryAr(String code) =>
      _categories.firstWhere((c) => c.$1 == code).$2;
  double _rate(String code) => _categories.firstWhere((c) => c.$1 == code).$3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('استقطاع المصدر (WHT)', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _ratesCard(),
          const SizedBox(height: 12),
          _txnsCard(),
          const SizedBox(height: 12),
          _filingCard(),
          const ApexOutputChips(items: [
            ApexChipLink('فواتير الموردين', '/purchase/bills', Icons.receipt_outlined),
            ApexChipLink('قائمة القيود', '/accounting/je-list', Icons.book),
            ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard() => Container(
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
          Text('WHT المستحقة هذا الشهر',
              style: TextStyle(color: AC.ts, fontSize: 12)),
          Text('${_totalWht.toStringAsFixed(0)} SAR',
              style: TextStyle(
                  color: AC.warn,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _miniMetric('إجمالي المدفوعات', _totalGross, AC.tp)),
            Expanded(child: _miniMetric('الصافي للموردين', _netPayable, AC.ok)),
          ]),
        ]),
      );

  Widget _miniMetric(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
        ],
      );

  Widget _ratesCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نسب الاستقطاع (ZATCA)',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _categories)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AC.navy3,
                  border: Border.all(color: AC.bdr),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.$2, style: TextStyle(color: AC.tp, fontSize: 11)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.warn.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${c.$3.toStringAsFixed(0)}%',
                        style: TextStyle(color: AC.warn, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
          ]),
        ]),
      );

  Widget _txnsCard() => Container(
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
            child: Text('المدفوعات الخاضعة (${_txns.length})',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          ..._txns.map((t) {
            final wht = _whtAmount(t);
            final rate = _rate(t['category'] as String);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t['vendor']}',
                        style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('${_categoryAr(t['category'] as String)} (${rate.toStringAsFixed(0)}%) · ${t['date']}',
                        style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${(t['gross'] as double).toStringAsFixed(0)}',
                      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11.5)),
                  Text('-${wht.toStringAsFixed(0)}',
                      style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ]),
            );
          }),
        ]),
      );

  Widget _filingCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.06),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event, color: AC.gold),
            const SizedBox(width: 8),
            Text('موعد التقديم',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(
            'WHT يُدفع شهرياً قبل اليوم العاشر من الشهر التالي. الإقرار السنوي قبل 120 يوم من نهاية السنة المالية.',
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.send, size: 16),
            label: const Text('قدّم WHT الشهري'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ]),
      );
}
