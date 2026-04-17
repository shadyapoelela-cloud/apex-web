/// APEX Forecast Chart — historical + AI-projected timeseries.
///
/// Renders a line chart with:
///   • solid line for actuals (past data)
///   • dashed line for forecast (future data)
///   • shaded band showing the 90% confidence interval
///   • threshold line (e.g. cash = 0 "runway") + anomaly dots
///
/// No external charting lib — pure CustomPainter so the output is
/// identical across platforms and lightweight.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class ForecastPoint {
  final String label;
  final double value;
  final double? lower;   // confidence interval lower bound (forecast only)
  final double? upper;
  final bool isForecast;

  const ForecastPoint({
    required this.label,
    required this.value,
    this.lower,
    this.upper,
    this.isForecast = false,
  });
}

class ApexForecastChart extends StatelessWidget {
  final List<ForecastPoint> series;
  final double? thresholdValue;
  final String? thresholdLabel;
  final String yLabel;
  final Color accent;

  const ApexForecastChart({
    super.key,
    required this.series,
    this.thresholdValue,
    this.thresholdLabel,
    this.yLabel = 'القيمة',
    this.accent = const Color(0xFFD4AF37),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      height: 340,
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _legend(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, cons) => CustomPaint(
                painter: _ForecastPainter(
                  series: series,
                  thresholdValue: thresholdValue,
                  thresholdLabel: thresholdLabel,
                  accent: accent,
                  textColor: AC.ts,
                  gridColor: AC.navy4,
                ),
                size: Size(cons.maxWidth, cons.maxHeight),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _xLabels(),
        ],
      ),
    );
  }

  Widget _legend() => Row(children: [
        _legendItem(Icons.show_chart, 'فعلي', accent, solid: true),
        const SizedBox(width: AppSpacing.md),
        _legendItem(Icons.show_chart, 'توقّع AI', accent, solid: false),
        const SizedBox(width: AppSpacing.md),
        _legendItem(Icons.square, 'مجال الثقة 90%',
            accent.withValues(alpha: 0.3), solid: true),
        const Spacer(),
        Text(yLabel,
            style: TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
      ]);

  Widget _legendItem(IconData icon, String label, Color color,
          {required bool solid}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: solid ? color : Colors.transparent,
            border: solid ? null : Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
      ]);

  Widget _xLabels() => Row(
        children: [
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: Text(
                series[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: series[i].isForecast ? AC.gold : AC.td,
                    fontSize: AppFontSize.xs,
                    fontStyle: series[i].isForecast
                        ? FontStyle.italic
                        : FontStyle.normal),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
}

class _ForecastPainter extends CustomPainter {
  final List<ForecastPoint> series;
  final double? thresholdValue;
  final String? thresholdLabel;
  final Color accent;
  final Color textColor;
  final Color gridColor;

  _ForecastPainter({
    required this.series,
    required this.accent,
    required this.textColor,
    required this.gridColor,
    this.thresholdValue,
    this.thresholdLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    // Range.
    double minY = double.infinity, maxY = -double.infinity;
    for (final p in series) {
      minY = minY > p.value ? p.value : minY;
      maxY = maxY < p.value ? p.value : maxY;
      if (p.lower != null) minY = minY > p.lower! ? p.lower! : minY;
      if (p.upper != null) maxY = maxY < p.upper! ? p.upper! : maxY;
    }
    if (thresholdValue != null) {
      minY = minY > thresholdValue! ? thresholdValue! : minY;
      maxY = maxY < thresholdValue! ? thresholdValue! : maxY;
    }
    // Add 10% padding.
    final pad = (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;

    final xStep = size.width / (series.length - 1);
    double xOf(int i) => i * xStep;
    double yOf(double v) =>
        size.height - ((v - minY) / (maxY - minY)) * size.height;

    // Grid lines.
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = size.height / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Confidence band.
    final bandPath = Path();
    bool started = false;
    for (var i = 0; i < series.length; i++) {
      final p = series[i];
      if (p.upper == null) continue;
      if (!started) {
        bandPath.moveTo(xOf(i), yOf(p.upper!));
        started = true;
      } else {
        bandPath.lineTo(xOf(i), yOf(p.upper!));
      }
    }
    for (var i = series.length - 1; i >= 0; i--) {
      final p = series[i];
      if (p.lower == null) continue;
      bandPath.lineTo(xOf(i), yOf(p.lower!));
    }
    bandPath.close();
    canvas.drawPath(
        bandPath, Paint()..color = accent.withValues(alpha: 0.2));

    // Split actual vs forecast paths.
    final actualPath = Path();
    final forecastPath = Path();
    bool actualStarted = false;
    bool forecastStarted = false;
    int? forecastStartIdx;
    for (var i = 0; i < series.length; i++) {
      final p = series[i];
      final x = xOf(i);
      final y = yOf(p.value);
      if (p.isForecast) {
        if (!forecastStarted) {
          forecastStartIdx = i;
          // Bridge from last actual to first forecast.
          if (i > 0) {
            forecastPath.moveTo(xOf(i - 1), yOf(series[i - 1].value));
            forecastPath.lineTo(x, y);
          } else {
            forecastPath.moveTo(x, y);
          }
          forecastStarted = true;
        } else {
          forecastPath.lineTo(x, y);
        }
      } else {
        if (!actualStarted) {
          actualPath.moveTo(x, y);
          actualStarted = true;
        } else {
          actualPath.lineTo(x, y);
        }
      }
    }
    // Actual — solid line.
    canvas.drawPath(
      actualPath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    // Forecast — dashed line.
    _drawDashed(canvas, forecastPath, accent, 2);

    // Dots.
    for (var i = 0; i < series.length; i++) {
      final p = series[i];
      final c = p.isForecast ? accent.withValues(alpha: 0.8) : accent;
      canvas.drawCircle(Offset(xOf(i), yOf(p.value)), 3, Paint()..color = c);
    }

    // Vertical divider between actual and forecast.
    if (forecastStartIdx != null) {
      final divX = xOf(forecastStartIdx);
      canvas.drawLine(
        Offset(divX, 0),
        Offset(divX, size.height),
        Paint()
          ..color = textColor.withValues(alpha: 0.3)
          ..strokeWidth = 0.8,
      );
      final tp = TextPainter(
        text: TextSpan(
            text: 'اليوم',
            style: TextStyle(color: textColor, fontSize: 10)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(divX + 4, 4));
    }

    // Threshold line.
    if (thresholdValue != null) {
      final y = yOf(thresholdValue!);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFE74C3C)
          ..strokeWidth = 1.5,
      );
      if (thresholdLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
              text: thresholdLabel,
              style: const TextStyle(
                  color: Color(0xFFE74C3C), fontSize: 10)),
          textDirection: TextDirection.rtl,
        )..layout();
        tp.paint(canvas, Offset(4, y - 14));
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    const dashW = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final seg = metric.extractPath(dist, dist + dashW);
        canvas.drawPath(seg, paint);
        dist += dashW + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) =>
      old.series != series ||
      old.thresholdValue != thresholdValue ||
      old.accent != accent;
}
