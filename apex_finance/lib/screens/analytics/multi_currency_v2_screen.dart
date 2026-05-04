/// APEX — Multi-Currency v2 (FX Exposure Dashboard)
/// /analytics/multi-currency-v2 — currencies + exposures + impact
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class MultiCurrencyV2Screen extends StatefulWidget {
  const MultiCurrencyV2Screen({super.key});
  @override
  State<MultiCurrencyV2Screen> createState() => _MultiCurrencyV2ScreenState();
}

class _MultiCurrencyV2ScreenState extends State<MultiCurrencyV2Screen> {
  // Demo exposures — to wire to /api/v1/multi-currency/dashboard
  final List<Map<String, dynamic>> _exposures = [
    {'currency': 'USD', 'flag': '🇺🇸', 'rate': 3.75, 'change_pct': 0.2, 'ar_balance': 45000.0, 'ap_balance': 18000.0},
    {'currency': 'EUR', 'flag': '🇪🇺', 'rate': 4.05, 'change_pct': -0.5, 'ar_balance': 22000.0, 'ap_balance': 35000.0},
    {'currency': 'AED', 'flag': '🇦🇪', 'rate': 1.02, 'change_pct': 0.0, 'ar_balance': 80000.0, 'ap_balance': 12000.0},
    {'currency': 'GBP', 'flag': '🇬🇧', 'rate': 4.65, 'change_pct': 1.2, 'ar_balance': 8500.0, 'ap_balance': 0.0},
    {'currency': 'EGP', 'flag': '🇪🇬', 'rate': 0.078, 'change_pct': -3.5, 'ar_balance': 0.0, 'ap_balance': 250000.0},
  ];

  double get _totalAr => _exposures.fold<double>(0,
      (a, e) => a + (e['ar_balance'] as double) * (e['rate'] as double));
  double get _totalAp => _exposures.fold<double>(0,
      (a, e) => a + (e['ap_balance'] as double) * (e['rate'] as double));
  double get _netExposure => _totalAr - _totalAp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('متابعة العملات الأجنبية', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          _exposureCard(),
          const SizedBox(height: 12),
          _hedgingTipCard(),
          const ApexOutputChips(items: [
            ApexChipLink('توقع التدفق', '/analytics/cash-flow-forecast', Icons.show_chart),
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    final positive = _netExposure >= 0;
    final color = positive ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('صافي التعرّض الأجنبي (Net FX Exposure)',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 6),
        Text('${positive ? "+" : ""}${_netExposure.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _miniMetric('AR (مدين)', _totalAr, AC.ok)),
          Expanded(child: _miniMetric('AP (دائن)', _totalAp, AC.warn)),
        ]),
      ]),
    );
  }

  Widget _miniMetric(String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
          Text('SAR', style: TextStyle(color: AC.ts, fontSize: 9)),
        ],
      );

  Widget _exposureCard() {
    return Container(
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
            Expanded(flex: 2, child: Text('العملة', style: _hdr())),
            Expanded(flex: 2, child: Text('السعر', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('AR', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('AP', style: _hdr(), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Net SAR', style: _hdr(), textAlign: TextAlign.left)),
          ]),
        ),
        ..._exposures.map((e) {
          final ar = e['ar_balance'] as double;
          final ap = e['ap_balance'] as double;
          final rate = e['rate'] as double;
          final change = e['change_pct'] as double;
          final net = (ar - ap) * rate;
          final positive = net >= 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5)))),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: Row(children: [
                  Text('${e['flag']}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text('${e['currency']}',
                      style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(rate.toStringAsFixed(3),
                        style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11)),
                    if (change != 0)
                      Text('${change > 0 ? "+" : ""}${change.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: change > 0 ? AC.ok : AC.err,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(ar > 0 ? ar.toStringAsFixed(0) : '-',
                    style: TextStyle(color: AC.ok, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(ap > 0 ? ap.toStringAsFixed(0) : '-',
                    style: TextStyle(color: AC.warn, fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text(net.toStringAsFixed(0),
                    style: TextStyle(
                        color: positive ? AC.ok : AC.err,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.left),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _hedgingTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.06),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('نصيحة التحوّط',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(
          'تعرّضك في EGP يبلغ -250,000 جنيه (≈ -19,500 ريال). الجنيه انخفض 3.5% الأسبوع الماضي. '
          'ضع في اعتبارك عقد forward لتأمين السعر، أو سدّد الفاتورة مبكراً.',
          style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
        ),
      ]),
    );
  }

  TextStyle _hdr() => TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w800);
}
