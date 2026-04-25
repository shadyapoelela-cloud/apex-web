/// APEX — Cash Flow Forecast (sparkline + 90-day projection)
/// /analytics/cash-flow-forecast — runway calculator
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});
  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  // Demo data — to be replaced with /analytics/cash-flow API
  // Each entry: {day_offset, balance}
  final List<double> _projection = List.generate(
      90, (i) => 50000 + i * 800 - (i % 30 == 0 ? 25000 : 0) + math.sin(i * 0.3) * 3000);

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
          const ApexOutputChips(items: [
            ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
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
