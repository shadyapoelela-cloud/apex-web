/// Startup Metrics Dashboard — Burn / Runway / MRR / LTV / Rule-of-40.
///
/// Mirrors app/features/startup_metrics/calculators.py for client-side
/// preview. Swap to ApiService when the REST endpoint is wired.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/apex_form_field.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/validators_ui.dart';

class StartupMetricsScreen extends StatefulWidget {
  const StartupMetricsScreen({super.key});

  @override
  State<StartupMetricsScreen> createState() => _StartupMetricsScreenState();
}

class _StartupMetricsScreenState extends State<StartupMetricsScreen> {
  final _cashCtrl = TextEditingController(text: '2500000');
  final _burnCtrl = TextEditingController(text: '150000');
  final _revCtrl = TextEditingController(text: '30000');
  final _mrrCtrl = TextEditingController(text: '42000');
  final _customersCtrl = TextEditingController(text: '84');
  final _cacTotalCtrl = TextEditingController(text: '80000');
  final _newCustomersCtrl = TextEditingController(text: '20');
  final _grossMarginCtrl = TextEditingController(text: '82');
  final _churnCtrl = TextEditingController(text: '3');
  final _growthCtrl = TextEditingController(text: '35');
  final _ebitdaCtrl = TextEditingController(text: '12');

  double _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  @override
  void dispose() {
    for (final c in [
      _cashCtrl, _burnCtrl, _revCtrl, _mrrCtrl, _customersCtrl,
      _cacTotalCtrl, _newCustomersCtrl, _grossMarginCtrl, _churnCtrl,
      _growthCtrl, _ebitdaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Compute ──
    final grossBurn = _d(_burnCtrl);
    final rev = _d(_revCtrl);
    final netBurn = math.max(grossBurn - rev, 0.0);
    final cash = _d(_cashCtrl);
    final runway = netBurn > 0 ? cash / netBurn : 9999.0;
    final danger = runway < 6;

    final mrr = _d(_mrrCtrl);
    final arr = mrr * 12;
    final customers = _d(_customersCtrl).toInt().clamp(1, 999999);
    final arpa = mrr / customers;

    final cacTotal = _d(_cacTotalCtrl);
    final newCustomers = _d(_newCustomersCtrl).toInt().clamp(1, 999999);
    final cac = cacTotal / newCustomers;
    final gm = _d(_grossMarginCtrl);
    final churn = _d(_churnCtrl);
    final lifetimeMonths = churn > 0 ? 100 / churn : 9999.0;
    final ltv = arpa * (gm / 100) * lifetimeMonths;
    final ltvCac = cac > 0 ? ltv / cac : 0.0;
    final payback = (arpa * gm / 100) > 0 ? cac / (arpa * gm / 100) : 9999.0;

    final growth = _d(_growthCtrl);
    final ebitda = _d(_ebitdaCtrl);
    final rule40 = growth + ebitda;

    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'Startup Metrics Live'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final wide = constraints.maxWidth > 1000;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: wide ? 2 : 1,
                        child: Column(
                          children: [
                            _kpiRow([
                              _kpi('Net Burn (شهرياً)',
                                  '${formatSarAmount(netBurn)} ر.س',
                                  AC.err, Icons.trending_down),
                              _kpi('Runway',
                                  runway >= 9000
                                      ? '∞'
                                      : '${runway.toStringAsFixed(1)} شهر',
                                  danger ? AC.err : AC.ok,
                                  Icons.timer_outlined),
                            ]),
                            _kpiRow([
                              _kpi('MRR', '${formatSarAmount(mrr)} ر.س',
                                  AC.ok, Icons.autorenew),
                              _kpi('ARR', '${formatSarAmount(arr)} ر.س',
                                  AC.ok, Icons.star_outline),
                            ]),
                            _kpiRow([
                              _kpi('CAC', '${formatSarAmount(cac)} ر.س',
                                  AC.cyan, Icons.person_add_alt),
                              _kpi('LTV', '${formatSarAmount(ltv)} ر.س',
                                  AC.cyan, Icons.workspace_premium_outlined),
                            ]),
                            _kpiRow([
                              _kpi(
                                'LTV : CAC',
                                '${ltvCac.toStringAsFixed(2)}:1',
                                ltvCac >= 3 ? AC.ok : AC.warn,
                                Icons.analytics_outlined,
                              ),
                              _kpi(
                                'Payback',
                                payback >= 9000
                                    ? '∞'
                                    : '${payback.toStringAsFixed(1)} شهر',
                                payback <= 12 ? AC.ok : AC.warn,
                                Icons.hourglass_bottom,
                              ),
                            ]),
                            _ruleOf40Card(growth, ebitda, rule40),
                          ],
                        ),
                      ),
                      if (wide) const SizedBox(width: AppSpacing.lg),
                      if (wide)
                        Expanded(flex: 1, child: _inputsPanel()),
                      if (!wide) _inputsPanel(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: children
            .expand((c) => [Expanded(child: c), const SizedBox(width: AppSpacing.md)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(label,
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.md)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: AppFontSize.h3,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleOf40Card(double growth, double ebitda, double score) {
    final pass = score >= 40;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pass
              ? [AC.ok.withValues(alpha: 0.18), AC.navy2]
              : [AC.warn.withValues(alpha: 0.18), AC.navy2],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: (pass ? AC.ok : AC.warn).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Rule of 40',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: AppFontSize.xl,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 4),
                decoration: BoxDecoration(
                  color: (pass ? AC.ok : AC.warn).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(pass ? 'ناجح' : 'تحت الحد',
                    style: TextStyle(
                        color: pass ? AC.ok : AC.warn,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricPart('Growth', '${growth.toStringAsFixed(1)}%'),
              Text('+', style: TextStyle(color: AC.td, fontSize: 32)),
              _metricPart('EBITDA Margin', '${ebitda.toStringAsFixed(1)}%'),
              Text('=', style: TextStyle(color: AC.td, fontSize: 32)),
              _metricPart(
                'Score',
                '${score.toStringAsFixed(1)}',
                color: pass ? AC.ok : AC.warn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPart(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color ?? AC.tp,
                fontSize: AppFontSize.h1,
                fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: AC.td)),
      ],
    );
  }

  Widget _inputsPanel() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.navy4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المدخلات',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          _inp('الرصيد النقدي الحالي', _cashCtrl),
          _inp('المصاريف الشهرية (Gross Burn)', _burnCtrl),
          _inp('الإيرادات الشهرية', _revCtrl),
          _inp('MRR', _mrrCtrl),
          _inp('عدد العملاء', _customersCtrl, integer: true),
          _inp('إنفاق اكتساب إجمالي هذا الشهر', _cacTotalCtrl),
          _inp('عملاء جدد هذا الشهر', _newCustomersCtrl, integer: true),
          _inp('هامش إجمالي (%)', _grossMarginCtrl),
          _inp('معدل Churn شهري (%)', _churnCtrl),
          _inp('نمو الإيراد السنوي (%)', _growthCtrl),
          _inp('هامش EBITDA (%)', _ebitdaCtrl),
        ],
      ),
    );
  }

  Widget _inp(String label, TextEditingController ctrl, {bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ApexFormField(
        label: label,
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
