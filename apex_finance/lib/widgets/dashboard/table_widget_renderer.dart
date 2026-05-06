/// Table renderer — paginated DataTable with RTL + Arabic number format.
///
/// Payload shapes accepted (caller may use either one):
/// ```
/// {
///   "columns": [{"key": "id", "label_ar": "المعرف"}, ...],
///   "rows":    [{"id": 1, ...}, ...]
/// }
/// // or the simpler shape used by list_top_customers / list_recent_invoices:
/// {
///   "rows": [{"id": ..., "name": ...}, ...]
/// }
/// ```
///
/// When `columns` isn't supplied we infer them from the first row's
/// keys — keeps the resolver authors free of a schema chore.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '_base.dart';

class TableWidgetRenderer implements DashboardWidgetRenderer {
  const TableWidgetRenderer();

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
        titleAr: 'جارٍ تحميل الجدول…',
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

    final rows = ((payload['rows'] ?? const []) as List)
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    if (rows.isEmpty) {
      return renderErrorState(
        context: context,
        titleAr: def.titleAr,
        message: 'لا توجد صفوف لعرضها',
        onRetry: onRetry,
      );
    }

    final List<_Col> columns = _resolveColumns(payload, rows.first);

    return Container(
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.bdr),
      ),
      padding: const EdgeInsets.all(12),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: _PaginatedTable(
          title: def.titleAr,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  List<_Col> _resolveColumns(Map<String, dynamic> payload, Map<String, dynamic> firstRow) {
    final raw = payload['columns'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final c in raw.whereType<Map>())
          _Col(
            key: (c['key'] ?? '') as String,
            label: (c['label_ar'] ?? c['label_en'] ?? c['key'] ?? '') as String,
          ),
      ];
    }
    return [
      for (final k in firstRow.keys) _Col(key: k, label: k),
    ];
  }
}

class _Col {
  final String key;
  final String label;
  const _Col({required this.key, required this.label});
}

class _PaginatedTable extends StatefulWidget {
  final String title;
  final List<_Col> columns;
  final List<Map<String, dynamic>> rows;

  const _PaginatedTable({
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  State<_PaginatedTable> createState() => _PaginatedTableState();
}

class _PaginatedTableState extends State<_PaginatedTable> {
  static const int _pageSize = 10;
  int _page = 0;

  int get _maxPage => (widget.rows.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.rows.length);
    final pageRows = widget.rows.sublist(start, end);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              headingTextStyle: TextStyle(
                color: AC.ts,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dataTextStyle: TextStyle(color: AC.tp, fontSize: 12),
              columns: [
                for (final c in widget.columns) DataColumn(label: Text(c.label)),
              ],
              rows: [
                for (final row in pageRows)
                  DataRow(
                    cells: [
                      for (final c in widget.columns)
                        DataCell(Text(_formatCell(row[c.key]))),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (widget.rows.length > _pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  iconSize: 18,
                  splashRadius: 18,
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Text(
                  '${_page + 1} / $_maxPage',
                  style: TextStyle(color: AC.ts, fontSize: 12),
                ),
                IconButton(
                  iconSize: 18,
                  splashRadius: 18,
                  onPressed:
                      _page < _maxPage - 1 ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatCell(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      // Prefer Arabic locale when available; falls back to default if not.
      try {
        return NumberFormat.decimalPattern('ar_SA').format(v);
      } catch (_) {
        return v.toString();
      }
    }
    return v.toString();
  }
}
