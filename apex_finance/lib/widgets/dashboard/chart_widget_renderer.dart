/// Chart renderer — line / area / bar via fl_chart.
///
/// Payload contracts the backend resolvers emit (chart.revenue_30d,
/// chart.cash_flow_90d):
/// ```
/// // Single-series  (chart.revenue_30d)
/// {
///   "series": [{"date": "2026-04-07", "value": 12.5}, ...],
///   "currency": "SAR"
/// }
/// // Multi-band    (chart.cash_flow_90d)
/// {
///   "series": [
///     {"date": "...", "inflow": 1.0, "outflow": 0.5, "net": 0.5}, ...
///   ]
/// }
/// // Generic shape (caller may also pass labels + named series)
/// {
///   "labels": ["Jan", "Feb"],
///   "series": [{"name": "Revenue", "data": [1.0, 2.0]}]
/// }
/// ```
///
/// `def.config['chart_type']` chooses line / area / bar; defaults to line.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '_base.dart';

class ChartWidgetRenderer implements DashboardWidgetRenderer {
  const ChartWidgetRenderer();

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
        titleAr: 'جارٍ تحميل الرسم البياني…',
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

    final series = _normaliseSeries(payload);
    if (series.isEmpty) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: 'لا توجد بيانات لعرضها بعد',
        onRetry: onRetry,
      );
    }

    final chartType =
        (def.configSchema?['chart_type'] as String?) ?? 'line';
    final colors = [AC.gold, AC.info, AC.ok, AC.purple, AC.warn];

    return Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            def.titleAr,
            style: TextStyle(
              color: AC.tp,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (series.length > 1) _legend(series, colors),
          const SizedBox(height: 4),
          Expanded(
            child: chartType == 'bar'
                ? _buildBar(series, colors)
                : _buildLine(series, colors, area: chartType == 'area'),
          ),
        ],
      ),
    );
  }

  Widget _legend(List<_Series> series, List<Color> colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < series.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                series[i].name,
                style: TextStyle(color: AC.ts, fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLine(List<_Series> series, List<Color> colors,
      {bool area = false}) {
    final lines = <LineChartBarData>[];
    for (var i = 0; i < series.length; i++) {
      final s = series[i];
      lines.add(LineChartBarData(
        spots: [
          for (var j = 0; j < s.data.length; j++)
            FlSpot(j.toDouble(), s.data[j]),
        ],
        isCurved: true,
        color: colors[i % colors.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: area
            ? BarAreaData(
                show: true,
                color: colors[i % colors.length].withValues(alpha: 0.18),
              )
            : BarAreaData(show: false),
      ));
    }
    return LineChart(
      LineChartData(
        lineBarsData: lines,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AC.bdr, strokeWidth: 0.5),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(
          touchTooltipData:
              LineTouchTooltipData(tooltipPadding: EdgeInsets.all(6)),
        ),
      ),
    );
  }

  Widget _buildBar(List<_Series> series, List<Color> colors) {
    if (series.isEmpty) return const SizedBox.shrink();
    final s = series.first; // bar shows first series only by default
    return BarChart(
      BarChartData(
        barGroups: [
          for (var j = 0; j < s.data.length; j++)
            BarChartGroupData(x: j, barRods: [
              BarChartRodData(toY: s.data[j], color: colors.first, width: 8),
            ]),
        ],
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /// Convert any of the 3 wire shapes into `List<_Series>`.
  List<_Series> _normaliseSeries(Map<String, dynamic> payload) {
    final raw = payload['series'];
    if (raw is! List) return const [];
    if (raw.isEmpty) return const [];

    // Shape 3: {labels, series:[{name, data}]} ----------------------------
    if (raw.first is Map && (raw.first as Map).containsKey('data')) {
      return [
        for (final s in raw)
          _Series(
            name: ((s as Map)['name'] ?? 'Series') as String,
            data: ((s['data'] as List?) ?? const [])
                .whereType<num>()
                .map((n) => n.toDouble())
                .toList(),
          ),
      ];
    }

    // Shape 1: list of {date, value}
    if (raw.first is Map && (raw.first as Map).containsKey('value')) {
      return [
        _Series(
          name: payload['label'] as String? ?? 'Value',
          data: raw
              .whereType<Map>()
              .map((m) => (m['value'] as num? ?? 0).toDouble())
              .toList(),
        ),
      ];
    }

    // Shape 2: list of {date, inflow, outflow, net}
    if (raw.first is Map && (raw.first as Map).containsKey('inflow')) {
      List<double> col(String key) => raw
          .whereType<Map>()
          .map((m) => (m[key] as num? ?? 0).toDouble())
          .toList();
      return [
        _Series(name: 'الداخل', data: col('inflow')),
        _Series(name: 'الخارج', data: col('outflow')),
        _Series(name: 'الصافي', data: col('net')),
      ];
    }

    // Shape: flat list of numbers
    if (raw.first is num) {
      return [
        _Series(
          name: payload['label'] as String? ?? 'Value',
          data: raw.whereType<num>().map((n) => n.toDouble()).toList(),
        ),
      ];
    }

    return const [];
  }
}

class _Series {
  final String name;
  final List<double> data;
  const _Series({required this.name, required this.data});
}
