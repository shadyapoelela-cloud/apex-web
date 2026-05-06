/// KPI tile renderer — shows a single value with trend + sparkline.
///
/// Payload contract (from app/dashboard/resolvers.py kpi_*):
/// ```
/// {
///   "value": 12345.67,         // required when no error
///   "currency": "SAR",          // optional unit suffix
///   "as_of": "2026-05-06",
///   "trend": [                  // optional sparkline
///     {"date": "...", "value": 1.0},
///     ...
///   ]
/// }
/// ```
///
/// `trend` may also be a flat `List<num>` for terser payloads.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '_base.dart';

class KpiWidgetRenderer implements DashboardWidgetRenderer {
  const KpiWidgetRenderer();

  @override
  Widget render(
    BuildContext context,
    DashboardCatalogEntry def,
    Map<String, dynamic>? payload, {
    VoidCallback? onRetry,
  }) {
    if (payload == null) {
      return renderErrorState(
        context: context,
        titleAr: 'جارٍ تحميل المؤشر…',
        onRetry: onRetry,
      );
    }
    if (payload.containsKey('error') && payload['error'] != null) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: payload['error']?.toString(),
        onRetry: onRetry,
      );
    }

    final num? value = (payload['value'] as num?);
    final String? currency = payload['currency'] as String?;
    final String? asOf = payload['as_of'] as String?;
    final accentColor = _resolveAccent(payload);

    final trendValues = _extractTrend(payload);
    final trendChange = _computeTrendChange(trendValues);

    final route = payload['route'] as String?;

    final card = Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            def.titleAr,
            style: TextStyle(
              color: AC.ts,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value == null ? '—' : _formatValue(value),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (currency != null) ...[
                const SizedBox(width: 6),
                Text(
                  currency,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (trendChange != null) ...[
            const SizedBox(height: 6),
            _TrendChip(change: trendChange),
          ],
          if (trendValues.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: trendValues,
                  color: accentColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
          if (asOf != null) ...[
            const SizedBox(height: 6),
            Text(
              asOf,
              style: TextStyle(color: AC.td, fontSize: 10),
            ),
          ],
        ],
      ),
    );

    if (route == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(route),
      child: card,
    );
  }

  Color _resolveAccent(Map<String, dynamic> payload) {
    final accent = payload['accent'] as String?;
    switch (accent) {
      case 'ok':
        return AC.ok;
      case 'warn':
        return AC.warn;
      case 'err':
        return AC.err;
      case 'info':
        return AC.info;
      default:
        return AC.gold;
    }
  }

  String _formatValue(num value) {
    final fmt = NumberFormat.decimalPattern('ar_SA');
    if (value is double && value.truncateToDouble() != value) {
      return fmt.format(value);
    }
    return fmt.format(value);
  }

  List<double> _extractTrend(Map<String, dynamic> payload) {
    final raw = payload['trend'] ?? payload['sparkline'];
    if (raw is List) {
      final out = <double>[];
      for (final item in raw) {
        if (item is num) {
          out.add(item.toDouble());
        } else if (item is Map && item['value'] is num) {
          out.add((item['value'] as num).toDouble());
        }
      }
      return out;
    }
    return const [];
  }

  double? _computeTrendChange(List<double> values) {
    if (values.length < 2) return null;
    final first = values.first;
    final last = values.last;
    if (first == 0) return null;
    return ((last - first) / first.abs()) * 100;
  }
}

class _TrendChip extends StatelessWidget {
  final double change;
  const _TrendChip({required this.change});

  @override
  Widget build(BuildContext context) {
    final isUp = change >= 0;
    final color = isUp ? AC.ok : AC.err;
    final icon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    final text = '${change.abs().toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;
    final stepX = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final ratio = range == 0 ? 0.5 : (values[i] - minV) / range;
      // Y axis inverted — top is small.
      final y = size.height - (ratio * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
