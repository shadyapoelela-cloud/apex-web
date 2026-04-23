/// APEX V5.1 — Action-Oriented Dashboard (Enhancement #3).
///
/// Replaces static KPI tiles with widgets that link to relevant
/// filtered screens. Inspired by QuickBooks Online + Xero.
///
/// Each widget shows:
///   - KPI value OR action list
///   - Click → drill-through to filtered screen
///   - "Draft with AI" optional (enhancement #6)
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

import 'v5_models.dart';

class ApexV5ActionDashboard extends StatelessWidget {
  final String titleAr;
  final String? subtitleAr;
  final List<V5DashboardWidget> widgets;

  /// Optional data binder — POC uses null (mock values).
  /// Production: `(endpoint) async => await ApiService.fetch(endpoint)`
  final Future<Map<String, dynamic>> Function(String endpoint)? dataBinder;

  const ApexV5ActionDashboard({
    super.key,
    required this.titleAr,
    this.subtitleAr,
    required this.widgets,
    this.dataBinder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.dashboard, size: 24),
              const SizedBox(width: 8),
              Text(
                titleAr,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('تحديث'),
              ),
            ],
          ),
          if (subtitleAr != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitleAr!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: core_theme.AC.ts,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          // Widgets grid — responsive
          LayoutBuilder(
            builder: (ctx, constraints) {
              // Break widgets into: action lists (full-width) + KPIs + charts
              final actionLists = widgets
                  .where((w) => w.kind == V5WidgetKind.actionList)
                  .toList();
              final kpis =
                  widgets.where((w) => w.kind == V5WidgetKind.kpi).toList();
              final charts =
                  widgets.where((w) => w.kind == V5WidgetKind.chart).toList();

              final kpiCols = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;
              final chartCols = constraints.maxWidth > 900 ? 2 : 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action lists (priority — always at top)
                  for (final w in actionLists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ActionListCard(widget: w, dataBinder: dataBinder),
                    ),
                  if (actionLists.isNotEmpty && kpis.isNotEmpty)
                    const SizedBox(height: 8),
                  // KPIs grid
                  if (kpis.isNotEmpty)
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: kpiCols,
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final w in kpis)
                          _KpiCard(widget: w, dataBinder: dataBinder),
                      ],
                    ),
                  if (kpis.isNotEmpty && charts.isNotEmpty)
                    const SizedBox(height: 16),
                  // Charts
                  if (charts.isNotEmpty)
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: chartCols,
                      childAspectRatio: 1.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final w in charts)
                          _ChartCard(widget: w),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Color _severityColor(V5WidgetSeverity s) {
  switch (s) {
    case V5WidgetSeverity.critical:
      return core_theme.AC.err;
    case V5WidgetSeverity.warning:
      return core_theme.AC.warn;
    case V5WidgetSeverity.success:
      return core_theme.AC.ok;
    case V5WidgetSeverity.info:
      return core_theme.AC.info;
  }
}

class _ActionListCard extends StatelessWidget {
  final V5DashboardWidget widget;
  final Future<Map<String, dynamic>> Function(String)? dataBinder;

  const _ActionListCard({required this.widget, this.dataBinder});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(widget.severity);

    // POC mock values based on widget label
    final mockCount = _mockCountFor(widget.labelAr);
    final mockDetail = _mockDetailFor(widget.labelAr);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$mockCount ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.labelAr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  mockDetail,
                  style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                ),
              ],
            ),
          ),
          if (widget.actionLabelAr != null) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: widget.actionRoute != null
                  ? () => context.go(widget.actionRoute!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.actionLabelAr!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_back, size: 16), // RTL forward
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _mockCountFor(String label) {
    if (label.contains('فواتير')) return 5;
    if (label.contains('أصناف')) return 12;
    if (label.contains('قيود')) return 3;
    if (label.contains('إجازات')) return 4;
    if (label.contains('أوامر')) return 8;
    if (label.contains('معاملات')) return 17;
    if (label.contains('CSID')) return 2;
    return 0;
  }

  String _mockDetailFor(String label) {
    if (label.contains('فواتير')) return 'قيمة إجمالية: 124,500 ريال';
    if (label.contains('أصناف')) return 'منها 3 أصناف حرجة';
    if (label.contains('قيود')) return 'قيمة إجمالية: 87,250 ريال';
    if (label.contains('إجازات')) return 'منذ 3-7 أيام';
    if (label.contains('أوامر')) return 'قيمة إجمالية: 245,000 ريال';
    if (label.contains('معاملات')) return 'من بنك الراجحي والأهلي';
    if (label.contains('CSID')) return 'ينتهي في 15 يوم';
    return 'اضغط للعرض';
  }
}

class _KpiCard extends StatelessWidget {
  final V5DashboardWidget widget;
  final Future<Map<String, dynamic>> Function(String)? dataBinder;

  const _KpiCard({required this.widget, this.dataBinder});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(widget.severity);
    final (value, unit) = _mockValueFor(widget.labelAr);

    return MouseRegion(
      cursor: widget.actionRoute != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.actionRoute != null
            ? () => context.go(widget.actionRoute!)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.labelAr,
                      style: TextStyle(
                        fontSize: 11,
                        color: core_theme.AC.ts,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: core_theme.AC.td,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String) _mockValueFor(String label) {
    if (label.contains('متوسط')) return ('42', 'يوم');
    if (label.contains('النقدي')) return ('1.2', 'مليون');
    if (label.contains('أرصدة')) return ('4.8', 'مليون');
    if (label.contains('عدد الموظفين')) return ('87', '');
    if (label.contains('راتب')) return ('780', 'ألف');
    if (label.contains('تعرّض')) return ('320', 'ألف USD');
    if (label.contains('الربع')) return ('45', 'يوم');
    if (label.contains('الامتثال')) return ('94%', '');
    if (label.contains('المفتوحة')) return ('8', '');
    return ('—', '');
  }
}

class _ChartCard extends StatelessWidget {
  final V5DashboardWidget widget;

  const _ChartCard({required this.widget});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(widget.severity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.labelAr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withValues(alpha: 0.05),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart, size: 32, color: color.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Text(
                      'رسم بياني — بيانات حيّة قريباً',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
