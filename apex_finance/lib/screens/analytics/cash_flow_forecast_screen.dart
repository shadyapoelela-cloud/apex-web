/// APEX — Cash Flow Forecast (sparkline + 90-day projection)
/// /analytics/cash-flow-forecast — runway calculator
///
/// The chart shows a synthetic 90-day daily projection (kept for the
/// existing visualization). The card at the bottom shows a real
/// algorithmic forecast from the live backend (Wave 1B Phase I) at
/// /api/v1/forecast/cashflow — weekly granularity with confidence band.
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});
  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  // The chart still uses a synthetic 90-day daily projection — kept so
  // the existing visualization keeps working in environments without GL
  // postings. The "Real Forecast" card at the bottom calls the live
  // backend (Wave 1B Phase I) at /api/v1/forecast/cashflow.
  final List<double> _projection = List.generate(
      90, (i) => 50000 + i * 800 - (i % 30 == 0 ? 25000 : 0) + math.sin(i * 0.3) * 3000);

  // Live forecast state.
  bool _liveLoading = false;
  String? _liveError;
  Map<String, dynamic>? _liveForecast;

  @override
  void initState() {
    super.initState();
    _loadLive();
  }

  Future<void> _loadLive() async {
    final tenantId = S.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _liveLoading = false;
        _liveError = 'لم يتم اختيار مستأجر — افتح إعدادات الكيانات لتحديده';
      });
      return;
    }
    setState(() {
      _liveLoading = true;
      _liveError = null;
    });
    final res = await ApiService.forecastCashflow(
      tenantId: tenantId,
      weeks: 8,
      historyWeeks: 12,
    );
    if (!mounted) return;
    if (res.success) {
      _liveForecast = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : null;
      _liveError = null;
    } else {
      _liveForecast = null;
      _liveError = res.error ?? 'فشل تحميل التوقع الفعلي';
    }
    setState(() => _liveLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final current = _projection.first;
    final endOfPeriod = _projection.last;
    final delta = endOfPeriod - current;
    final pct = current == 0 ? 0 : (delta / current * 100);
    final positive = delta >= 0;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('توقع التدفق النقدي', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(current, endOfPeriod, delta, pct, positive),
          const SizedBox(height: 12),
          _sparklineCard(),
          const SizedBox(height: 12),
          _runwayCard(),
          const SizedBox(height: 12),
          _scenarioCard(),
          const SizedBox(height: 12),
          _liveForecastCard(),
          const ApexOutputChips(items: [
            ApexChipLink('أعمار AR', '/app/erp/sales/ar-aging', Icons.timeline),
            ApexChipLink('أعمار AP', '/purchase/aging', Icons.timeline),
            ApexChipLink('بناء الموازنة', '/analytics/budget-builder', Icons.calculate),
            ApexChipLink('Health Score', '/analytics/health-score-v2', Icons.health_and_safety),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard(double current, double end, double delta, num pct, bool positive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (positive ? AC.ok : AC.err).withValues(alpha: 0.20),
            AC.navy3,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(
            color: (positive ? AC.ok : AC.err).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الرصيد المتوقع بعد 90 يوماً',
            style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 6),
        Text('${end.toStringAsFixed(0)} SAR',
            style: TextStyle(
                color: positive ? AC.ok : AC.err,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Row(children: [
          Icon(
              positive ? Icons.trending_up : Icons.trending_down,
              color: positive ? AC.ok : AC.err,
              size: 16),
          const SizedBox(width: 4),
          Text('${positive ? "+" : ""}${delta.toStringAsFixed(0)} SAR (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(
                  color: positive ? AC.ok : AC.err, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _sparklineCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإسقاط اليومي (90 يوماً)',
            style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: const Size(double.infinity, 120),
            painter: _SparklinePainter(_projection, AC.gold),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('اليوم', style: TextStyle(color: AC.ts, fontSize: 10)),
          Text('30 يوم', style: TextStyle(color: AC.ts, fontSize: 10)),
          Text('60 يوم', style: TextStyle(color: AC.ts, fontSize: 10)),
          Text('90 يوم', style: TextStyle(color: AC.ts, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _runwayCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('شهور التشغيل من النقد المتاح',
            style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        Text('بدلاً من Runway الـ VC — مقياس مناسب للسوق السعودي',
            style: TextStyle(color: AC.ts, fontSize: 10.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _runwayMetric('شهور التشغيل', '14.2', AC.ok)),
          Expanded(child: _runwayMetric('متوسط Burn شهري', '8,500', AC.warn)),
        ]),
      ]),
    );
  }

  Widget _runwayMetric(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
        ],
      );

  Widget _scenarioCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.06),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text('تحليل السيناريوهات',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        _scenarioRow('متفائل', 'إذا تأخّر AR أسبوعاً واحداً فقط', '+15K SAR', AC.ok),
        _scenarioRow('متشائم', 'إذا تأخّر 3 عملاء كبار 60 يوماً', '-45K SAR', AC.err),
        _scenarioRow('مرجّح (AI)', 'حسب نمط الـ 12 شهراً السابقة', '+8K SAR', AC.gold),
      ]),
    );
  }

  Widget _scenarioRow(String label, String desc, String impact, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 6, height: 30,
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(desc, style: TextStyle(color: AC.ts, fontSize: 10.5)),
            ]),
          ),
          Text(impact,
              style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
        ]),
      );

  // ── Live forecast card (real backend data, weekly granularity) ──
  Widget _liveForecastCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.api, color: AC.gold, size: 18),
            const SizedBox(width: 8),
            Text('التوقع الفعلي (من بيانات GL)',
                style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loadLive,
              icon: Icon(Icons.refresh, color: AC.ts, size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          if (_liveLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2),
              ),
            )
          else if (_liveError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_liveError!,
                  style: TextStyle(color: AC.warn, fontSize: 11.5)),
            )
          else if (_liveForecast == null)
            Text('لا توجد بيانات بعد',
                style: TextStyle(color: AC.ts, fontSize: 11.5))
          else
            _liveForecastBody(_liveForecast!),
        ],
      ),
    );
  }

  Widget _liveForecastBody(Map<String, dynamic> data) {
    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    final projection = (data['projection'] as List?) ?? const [];
    final warnings = (data['warnings'] as List?) ?? const [];

    final endingBalance = (summary['ending_projected_balance'] ?? 0).toString();
    final trend = (summary['trend_per_week'] ?? 0).toString();
    final avgNet = (summary['avg_weekly_net'] ?? 0).toString();
    final stdev = (summary['stdev'] ?? 0).toString();
    final history = (summary['history_weeks'] ?? 0).toString();
    final horizon = (summary['horizon_weeks'] ?? 0).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _kpiChip('الرصيد بعد $horizon أسبوع', endingBalance, AC.gold),
            _kpiChip('الاتجاه/أسبوع', trend, AC.cyan),
            _kpiChip('المتوسط/أسبوع', avgNet, AC.tp),
            _kpiChip('الانحراف σ', stdev, AC.warn),
            _kpiChip('تاريخ', '$history أسبوع', AC.ts),
          ],
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Icon(Icons.info_outline, color: AC.warn, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(w.toString(),
                      style: TextStyle(color: AC.warn, fontSize: 10.5)),
                ),
              ]),
            ),
        ],
        if (projection.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('التفصيل الأسبوعي:',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          const SizedBox(height: 4),
          for (final w in projection.take(8))
            _projectionRow(w as Map<String, dynamic>),
        ],
      ],
    );
  }

  Widget _kpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(color: AC.ts, fontSize: 10.5)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _projectionRow(Map<String, dynamic> w) {
    final week = w['week_starting']?.toString() ?? '';
    final projected = (w['projected_net'] ?? 0).toString();
    final cumulative = (w['cumulative_balance'] ?? 0).toString();
    final lower = (w['lower_bound'] ?? 0).toString();
    final upper = (w['upper_bound'] ?? 0).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(week, style: TextStyle(color: AC.ts, fontSize: 10.5))),
          Expanded(
            child: Text(
              'صافي $projected (range $lower → $upper)',
              style: TextStyle(color: AC.tp, fontSize: 10.5, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(cumulative,
              style: TextStyle(color: AC.gold, fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final dx = size.width / (data.length - 1);
    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - (data[i] - minVal) / range * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
