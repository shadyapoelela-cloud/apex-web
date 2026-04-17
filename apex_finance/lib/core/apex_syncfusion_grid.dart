/// APEX Syncfusion DataGrid — high-performance alternative to
/// ApexDataTable for screens with >1000 rows or frozen columns.
///
/// V2 Blueprint § 2.0.1 recommends Syncfusion for list views that need
/// freeze-column, virtual scroll, and inline editing out of the box.
/// ApexDataTable stays the default for small lists (< 500 rows) where
/// the custom look + Semantics integration matter most; this widget
/// is opt-in where raw scale is the constraint.
///
/// Wraps SfDataGrid with the APEX theme (navy background, gold accent,
/// tabular figures for numerics) and accepts the same `ApexColumn<T>`
/// definitions ApexDataTable uses — so screens can swap in/out with
/// minimal code churn.
library;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'apex_data_table.dart' show ApexColumn;
import 'design_tokens.dart';
import 'theme.dart';

class ApexSyncfusionGrid<T> extends StatefulWidget {
  final List<ApexColumn<T>> columns;
  final List<T> rows;

  /// Names of columns to freeze (left/leading side).
  final Set<String> frozenColumns;

  /// Enable inline editing on these columns.
  final Set<String> editableColumns;

  /// Called when a cell commits a new value.
  final void Function(T row, String columnKey, Object? newValue)? onCellEdit;

  /// Max rows visible before virtual scroll kicks in. Syncfusion renders
  /// only what's on screen, so 10k+ rows are fine.
  final double rowHeight;
  final double headerHeight;

  final void Function(T row)? onRowTap;

  const ApexSyncfusionGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.frozenColumns = const {},
    this.editableColumns = const {},
    this.onCellEdit,
    this.rowHeight = 40,
    this.headerHeight = 44,
    this.onRowTap,
  });

  @override
  State<ApexSyncfusionGrid<T>> createState() => _ApexSyncfusionGridState<T>();
}

class _ApexSyncfusionGridState<T> extends State<ApexSyncfusionGrid<T>> {
  late _ApexGridSource<T> _source;

  @override
  void initState() {
    super.initState();
    _source = _ApexGridSource<T>(
      rows: widget.rows,
      columns: widget.columns,
      editableColumns: widget.editableColumns,
      onCellEdit: widget.onCellEdit,
    );
  }

  @override
  void didUpdateWidget(covariant ApexSyncfusionGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows != oldWidget.rows) {
      _source = _ApexGridSource<T>(
        rows: widget.rows,
        columns: widget.columns,
        editableColumns: widget.editableColumns,
        onCellEdit: widget.onCellEdit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Count how many frozen columns are in the frontmost positions —
    // Syncfusion only supports freezing columns contiguously from the
    // leading edge, so we iterate columns and break on first non-frozen.
    int frozenCount = 0;
    for (final c in widget.columns) {
      if (widget.frozenColumns.contains(c.key)) {
        frozenCount++;
      } else {
        break;
      }
    }

    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: AC.navy3,
        gridLineColor: AC.bdr,
        selectionColor: AC.gold.withValues(alpha: 0.12),
        frozenPaneLineColor: AC.gold,
      ),
      child: SfDataGrid(
        source: _source,
        gridLinesVisibility: GridLinesVisibility.horizontal,
        headerGridLinesVisibility: GridLinesVisibility.horizontal,
        rowHeight: widget.rowHeight,
        headerRowHeight: widget.headerHeight,
        frozenColumnsCount: frozenCount,
        allowSorting: true,
        allowEditing: widget.editableColumns.isNotEmpty,
        allowFiltering: false,
        editingGestureType: EditingGestureType.doubleTap,
        onCellTap: widget.onRowTap == null
            ? null
            : (details) {
                final i = details.rowColumnIndex.rowIndex - 1;
                if (i >= 0 && i < widget.rows.length) {
                  widget.onRowTap!(widget.rows[i]);
                }
              },
        columns: [
          for (final c in widget.columns)
            GridColumn(
              columnName: c.key,
              width: c.width ?? double.nan,
              minimumWidth: 80,
              allowSorting: c.sortable,
              allowEditing: widget.editableColumns.contains(c.key),
              label: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                alignment: c.numeric
                    ? Alignment.centerRight
                    : AlignmentDirectional.centerStart,
                color: AC.navy3,
                child: Text(
                  c.label,
                  style: TextStyle(
                    color: AC.gold,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApexGridSource<T> extends DataGridSource {
  final List<T> _sourceRows;
  final List<ApexColumn<T>> columns;
  final Set<String> editableColumns;
  final void Function(T row, String columnKey, Object? newValue)? onCellEdit;

  late List<DataGridRow> _gridRows;

  _ApexGridSource({
    required List<T> rows,
    required this.columns,
    required this.editableColumns,
    required this.onCellEdit,
  }) : _sourceRows = rows {
    _rebuild();
  }

  void _rebuild() {
    _gridRows = _sourceRows.map((r) {
      return DataGridRow(
        cells: columns.map((c) {
          // Store the Comparable/sort value for sorting; the display
          // widget comes from c.cell() and is built in buildRow below.
          final sortVal = c.sortValue?.call(r) ?? '';
          return DataGridCell(columnName: c.key, value: sortVal);
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _gridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _gridRows.indexOf(row);
    final data = rowIndex >= 0 && rowIndex < _sourceRows.length
        ? _sourceRows[rowIndex]
        : null;
    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? AC.navy2 : AC.navy3,
      cells: [
        for (final c in columns)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            alignment: c.numeric
                ? Alignment.centerRight
                : AlignmentDirectional.centerStart,
            child: data == null
                ? const SizedBox.shrink()
                : c.cell(data),
          ),
      ],
    );
  }
}
