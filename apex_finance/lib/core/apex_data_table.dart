/// APEX Data Table — reusable list/table widget for APEX screens.
///
/// Inspired by Odoo 19 list view + SAP Fiori responsive tables:
///   - Frozen header on vertical scroll (sticky)
///   - Optional column sorting (click header to cycle asc/desc/none)
///   - Zebra striping + hover highlight + active row accent
///   - Optional checkbox column for bulk selection with overflow action bar
///   - RTL-aware (follows Directionality)
///   - Empty / loading / error states provided by caller
///
/// Usage:
/// ```dart
/// ApexDataTable<Client>(
///   columns: [
///     ApexColumn(key: 'name', label: 'الاسم', cell: (c) => Text(c.name)),
///     ApexColumn(
///       key: 'balance',
///       label: 'الرصيد',
///       cell: (c) => Text(c.balance.toStringAsFixed(2)),
///       numeric: true,
///     ),
///   ],
///   rows: clients,
///   onRowTap: (c) => openClient(c),
///   showCheckboxes: true,
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'theme.dart';

/// Declarative column spec. `cell` renders the cell for one row.
class ApexColumn<T> {
  final String key;
  final String label;
  final Widget Function(T row) cell;
  final Comparable<Object?> Function(T row)? sortValue;
  final double? width; // logical pixels; null = flex
  final int flex;
  final bool numeric;
  final bool sortable;
  final AlignmentGeometry alignment;

  const ApexColumn({
    required this.key,
    required this.label,
    required this.cell,
    this.sortValue,
    this.width,
    this.flex = 1,
    this.numeric = false,
    this.sortable = true,
    this.alignment = AlignmentDirectional.centerStart,
  });
}

enum _SortDir { none, asc, desc }

class ApexDataTable<T> extends StatefulWidget {
  final List<ApexColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final bool showCheckboxes;
  final void Function(Set<T> selected)? onSelectionChanged;
  final Widget? emptyState;
  final bool loading;
  final double rowHeight;
  final double headerHeight;

  const ApexDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.showCheckboxes = false,
    this.onSelectionChanged,
    this.emptyState,
    this.loading = false,
    this.rowHeight = 44,
    this.headerHeight = 40,
  });

  @override
  State<ApexDataTable<T>> createState() => _ApexDataTableState<T>();
}

class _ApexDataTableState<T> extends State<ApexDataTable<T>> {
  String? _sortKey;
  _SortDir _sortDir = _SortDir.none;
  final Set<T> _selected = <T>{};
  int? _hoveredIndex;

  List<T> get _sortedRows {
    if (_sortKey == null || _sortDir == _SortDir.none) return widget.rows;
    final col = widget.columns.firstWhere(
      (c) => c.key == _sortKey,
      orElse: () => widget.columns.first,
    );
    if (col.sortValue == null) return widget.rows;
    final out = [...widget.rows];
    out.sort((a, b) {
      final va = col.sortValue!(a);
      final vb = col.sortValue!(b);
      final cmp = Comparable.compare(va, vb);
      return _sortDir == _SortDir.asc ? cmp : -cmp;
    });
    return out;
  }

  void _onHeaderTap(ApexColumn<T> col) {
    if (!col.sortable || col.sortValue == null) return;
    setState(() {
      if (_sortKey != col.key) {
        _sortKey = col.key;
        _sortDir = _SortDir.asc;
      } else {
        _sortDir = switch (_sortDir) {
          _SortDir.none => _SortDir.asc,
          _SortDir.asc => _SortDir.desc,
          _SortDir.desc => _SortDir.none,
        };
        if (_sortDir == _SortDir.none) _sortKey = null;
      }
    });
  }

  void _toggleRow(T row, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(row);
      } else {
        _selected.remove(row);
      }
    });
    widget.onSelectionChanged?.call(Set.from(_selected));
  }

  void _toggleAll(bool? value) {
    setState(() {
      _selected.clear();
      if (value == true) _selected.addAll(widget.rows);
    });
    widget.onSelectionChanged?.call(Set.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return _ApexDataTableShimmer(
        columnCount: widget.columns.length,
        rowHeight: widget.rowHeight,
      );
    }
    if (widget.rows.isEmpty) {
      return widget.emptyState ?? _defaultEmptyState(context);
    }

    return Column(
      children: [
        if (_selected.isNotEmpty) _selectionBar(),
        _header(),
        Expanded(
          child: ListView.builder(
            itemCount: _sortedRows.length,
            itemBuilder: (context, i) => _row(i, _sortedRows[i]),
            itemExtent: widget.rowHeight,
          ),
        ),
      ],
    );
  }

  // ── Header ──

  Widget _header() {
    return Container(
      height: widget.headerHeight,
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border(bottom: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        children: [
          if (widget.showCheckboxes)
            _checkboxCell(
              value: _selected.length == widget.rows.length && widget.rows.isNotEmpty,
              tristate: _selected.isNotEmpty && _selected.length < widget.rows.length,
              onChanged: _toggleAll,
            ),
          ...widget.columns.map(_headerCell),
        ],
      ),
    );
  }

  Widget _headerCell(ApexColumn<T> col) {
    final isSorted = _sortKey == col.key && _sortDir != _SortDir.none;
    final icon = isSorted
        ? (_sortDir == _SortDir.asc ? Icons.arrow_upward : Icons.arrow_downward)
        : null;

    final label = Text(
      col.label,
      style: TextStyle(
        fontSize: AppFontSize.md,
        fontWeight: FontWeight.w600,
        color: AC.tp,
      ),
      overflow: TextOverflow.ellipsis,
    );

    final content = Row(
      mainAxisAlignment: col.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        if (icon != null) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: AC.ts),
        ],
      ],
    );

    final child = InkWell(
      onTap: col.sortable && col.sortValue != null ? () => _onHeaderTap(col) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(alignment: col.alignment, child: content),
      ),
    );

    return _cellBox(col: col, child: child);
  }

  // ── Row ──

  Widget _row(int index, T row) {
    final selected = _selected.contains(row);
    final zebra = index.isOdd;
    final bg = selected
        ? AC.gold.withValues(alpha: 0.10)
        : _hoveredIndex == index
            ? AC.navy3
            : zebra
                ? AC.navy2
                : AC.navy;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: InkWell(
        onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
        child: Container(
          height: widget.rowHeight,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(color: AC.navy4.withValues(alpha: 0.4)),
              left: selected
                  ? BorderSide(color: AC.gold, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              if (widget.showCheckboxes)
                _checkboxCell(
                  value: selected,
                  onChanged: (v) => _toggleRow(row, v),
                ),
              ...widget.columns.map(
                (col) => _cellBox(
                  col: col,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Align(alignment: col.alignment, child: col.cell(row)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cells & helpers ──

  Widget _cellBox({required ApexColumn<T> col, required Widget child}) {
    if (col.width != null) {
      return SizedBox(width: col.width, child: child);
    }
    return Expanded(flex: col.flex, child: child);
  }

  Widget _checkboxCell({
    required bool value,
    bool tristate = false,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      width: 44,
      child: Checkbox(
        value: tristate ? null : value,
        tristate: tristate,
        onChanged: onChanged,
        activeColor: AC.gold,
      ),
    );
  }

  Widget _selectionBar() {
    final count = _selected.length;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: AC.gold)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Text(
            '$count عنصر محدد',
            style: TextStyle(
              color: AC.tp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() => _selected.clear());
              widget.onSelectionChanged?.call({});
            },
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
        ],
      ),
    );
  }

  Widget _defaultEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AC.td),
            const SizedBox(height: AppSpacing.md),
            Text(
              'لا توجد بيانات',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer / loading state ──

class _ApexDataTableShimmer extends StatefulWidget {
  final int columnCount;
  final double rowHeight;

  const _ApexDataTableShimmer({required this.columnCount, required this.rowHeight});

  @override
  State<_ApexDataTableShimmer> createState() => _ApexDataTableShimmerState();
}

class _ApexDataTableShimmerState extends State<_ApexDataTableShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = 0.3 + (_ctrl.value * 0.4);
        return ListView.builder(
          itemCount: 8,
          itemExtent: widget.rowHeight,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: List.generate(
                widget.columnCount,
                (j) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Container(
                      height: widget.rowHeight - AppSpacing.lg,
                      decoration: BoxDecoration(
                        color: AC.navy3.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
