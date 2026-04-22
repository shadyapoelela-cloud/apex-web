/// APEX Custom Report Builder — SAP Analytics / Power BI-style.
///
/// Users drag fields from a left-hand catalogue into three drop zones:
///   • Rows (grouping dimensions)
///   • Columns (pivots)
///   • Measures (aggregations: sum, avg, count)
///
/// Plus a filter chip row. The widget doesn't execute the query — it
/// emits a `ReportDefinition` value object that the caller passes to
/// the backend (which runs it as SQL / OLAP / whatever).
///
/// Every change emits via [onChanged] so hosts can persist the draft
/// or live-preview a sample.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';
import 'theme.dart' as core_theme;

enum ReportFieldKind { dimension, measure }
enum AggFn { sum, avg, count, min, max }

class ReportField {
  final String id;
  final String label;
  final ReportFieldKind kind;
  final IconData icon;

  const ReportField({
    required this.id,
    required this.label,
    required this.kind,
    this.icon = Icons.tag,
  });
}

class ReportMeasure {
  final String fieldId;
  final AggFn fn;
  const ReportMeasure({required this.fieldId, required this.fn});
}

class ReportFilter {
  final String fieldId;
  final String op;
  final String value;
  const ReportFilter({
    required this.fieldId,
    required this.op,
    required this.value,
  });
}

class ReportDefinition {
  final List<String> rowFieldIds;
  final List<String> columnFieldIds;
  final List<ReportMeasure> measures;
  final List<ReportFilter> filters;

  const ReportDefinition({
    this.rowFieldIds = const [],
    this.columnFieldIds = const [],
    this.measures = const [],
    this.filters = const [],
  });

  ReportDefinition copyWith({
    List<String>? rowFieldIds,
    List<String>? columnFieldIds,
    List<ReportMeasure>? measures,
    List<ReportFilter>? filters,
  }) =>
      ReportDefinition(
        rowFieldIds: rowFieldIds ?? this.rowFieldIds,
        columnFieldIds: columnFieldIds ?? this.columnFieldIds,
        measures: measures ?? this.measures,
        filters: filters ?? this.filters,
      );
}

class ApexReportBuilder extends StatefulWidget {
  final List<ReportField> catalogue;
  final ReportDefinition initial;
  final ValueChanged<ReportDefinition> onChanged;

  const ApexReportBuilder({
    super.key,
    required this.catalogue,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<ApexReportBuilder> createState() => _ApexReportBuilderState();
}

class _ApexReportBuilderState extends State<ApexReportBuilder> {
  late ReportDefinition _def;

  @override
  void initState() {
    super.initState();
    _def = widget.initial;
  }

  ReportField? _find(String id) {
    for (final f in widget.catalogue) {
      if (f.id == id) return f;
    }
    return null;
  }

  void _emit() => widget.onChanged(_def);

  void _addDim(String id, bool isRow) {
    setState(() {
      final rows = [..._def.rowFieldIds];
      final cols = [..._def.columnFieldIds];
      // Dedupe — move if already in other list.
      rows.remove(id);
      cols.remove(id);
      if (isRow) {
        rows.add(id);
      } else {
        cols.add(id);
      }
      _def = _def.copyWith(rowFieldIds: rows, columnFieldIds: cols);
    });
    _emit();
  }

  void _removeDim(String id) {
    setState(() {
      _def = _def.copyWith(
        rowFieldIds: _def.rowFieldIds.where((x) => x != id).toList(),
        columnFieldIds: _def.columnFieldIds.where((x) => x != id).toList(),
      );
    });
    _emit();
  }

  void _addMeasure(String fieldId, AggFn fn) {
    setState(() {
      final list = [..._def.measures, ReportMeasure(fieldId: fieldId, fn: fn)];
      _def = _def.copyWith(measures: list);
    });
    _emit();
  }

  void _removeMeasure(int idx) {
    setState(() {
      final list = [..._def.measures]..removeAt(idx);
      _def = _def.copyWith(measures: list);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final dims = widget.catalogue
        .where((f) => f.kind == ReportFieldKind.dimension)
        .toList();
    final measures = widget.catalogue
        .where((f) => f.kind == ReportFieldKind.measure)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: catalogue
        Expanded(flex: 3, child: _catalogue(dims, measures)),
        const SizedBox(width: AppSpacing.md),
        // Right: definition zones
        Expanded(flex: 5, child: _zones()),
      ],
    );
  }

  Widget _catalogue(List<ReportField> dims, List<ReportField> measures) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الحقول المتاحة',
              style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFontSize.base)),
          const SizedBox(height: AppSpacing.sm),
          Text('الأبعاد',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in dims) _catalogueChip(f)],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('القياسات',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in measures) _catalogueChip(f)],
          ),
        ],
      ),
    );
  }

  Widget _catalogueChip(ReportField f) {
    final color =
        f.kind == ReportFieldKind.measure ? AC.gold : core_theme.AC.info;
    return Draggable<ReportField>(
      data: f,
      feedback: Material(
        color: Colors.transparent,
        child: _chipBody(f, color, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _chipBody(f, color)),
      child: _chipBody(f, color),
    );
  }

  Widget _chipBody(ReportField f, Color color, {bool dragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dragging ? 0.3 : 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(f.icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(f.label,
            style: TextStyle(color: AC.tp, fontSize: AppFontSize.xs)),
      ]),
    );
  }

  Widget _zones() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dropZone('صفوف (Rows)', _def.rowFieldIds,
              accept: (f) => f.kind == ReportFieldKind.dimension,
              onAccept: (f) => _addDim(f.id, true),
              onRemove: _removeDim,
              accent: core_theme.AC.info),
          const SizedBox(height: AppSpacing.sm),
          _dropZone('أعمدة (Columns)', _def.columnFieldIds,
              accept: (f) => f.kind == ReportFieldKind.dimension,
              onAccept: (f) => _addDim(f.id, false),
              onRemove: _removeDim,
              accent: core_theme.AC.purple),
          const SizedBox(height: AppSpacing.sm),
          _measureZone(),
          const SizedBox(height: AppSpacing.sm),
          _preview(),
        ],
      );

  Widget _dropZone(
    String title,
    List<String> fieldIds, {
    required bool Function(ReportField) accept,
    required void Function(ReportField) onAccept,
    required void Function(String) onRemove,
    required Color accent,
  }) {
    return DragTarget<ReportField>(
      onWillAcceptWithDetails: (d) => accept(d.data),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (ctx, cands, __) {
        final hover = cands.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: hover ? accent : AC.bdr,
                width: hover ? 2 : 1,
                style: fieldIds.isEmpty && !hover
                    ? BorderStyle.solid
                    : BorderStyle.solid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(title,
                    style: TextStyle(
                        color: accent,
                        fontSize: AppFontSize.xs,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${fieldIds.length} حقل',
                    style:
                        TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
              ]),
              const SizedBox(height: 6),
              if (fieldIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    hover
                        ? 'أفلت الحقل هنا'
                        : 'اسحب حقلاً من القائمة إلى هنا',
                    style: TextStyle(
                        color: AC.td,
                        fontSize: AppFontSize.xs,
                        fontStyle: FontStyle.italic),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in fieldIds)
                      _activeChip(
                        _find(id)?.label ?? id,
                        accent,
                        onRemove: () => onRemove(id),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _measureZone() {
    return DragTarget<ReportField>(
      onWillAcceptWithDetails: (d) => d.data.kind == ReportFieldKind.measure,
      onAcceptWithDetails: (d) => _addMeasure(d.data.id, AggFn.sum),
      builder: (ctx, cands, __) {
        final hover = cands.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: hover ? AC.gold : AC.bdr, width: hover ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('القياسات (Measures)',
                    style: TextStyle(
                        color: AC.gold,
                        fontSize: AppFontSize.xs,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_def.measures.length} قياس',
                    style:
                        TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
              ]),
              const SizedBox(height: 6),
              if (_def.measures.isEmpty)
                Text(
                    hover
                        ? 'أفلت القياس هنا'
                        : 'اسحب حقلاً رقمياً من القائمة',
                    style: TextStyle(
                        color: AC.td,
                        fontSize: AppFontSize.xs,
                        fontStyle: FontStyle.italic))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _def.measures.length; i++)
                      _measurePill(_def.measures[i], i),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _measurePill(ReportMeasure m, int idx) {
    final field = _find(m.fieldId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<AggFn>(
          value: m.fn,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: TextStyle(color: AC.gold, fontSize: AppFontSize.xs),
          items: [
            for (final fn in AggFn.values)
              DropdownMenuItem(
                value: fn,
                child: Text(fn.name.toUpperCase()),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              final list = [..._def.measures];
              list[idx] = ReportMeasure(fieldId: m.fieldId, fn: v);
              _def = _def.copyWith(measures: list);
            });
            _emit();
          },
        ),
        const SizedBox(width: 4),
        Text(field?.label ?? m.fieldId,
            style: TextStyle(color: AC.tp, fontSize: AppFontSize.xs)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _removeMeasure(idx),
          child: Icon(Icons.close, size: 12, color: AC.gold),
        ),
      ]),
    );
  }

  Widget _activeChip(String label, Color accent,
          {required VoidCallback onRemove}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(color: AC.tp, fontSize: AppFontSize.xs)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: accent),
          ),
        ]),
      );

  Widget _preview() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('استعلام مُولَّد',
                style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _sqlPreview(),
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace',
                  height: 1.4),
            ),
          ],
        ),
      );

  String _sqlPreview() {
    if (_def.measures.isEmpty && _def.rowFieldIds.isEmpty) {
      return '-- اسحب حقولاً لبناء الاستعلام --';
    }
    final sel = <String>[];
    sel.addAll(_def.rowFieldIds);
    for (final m in _def.measures) {
      sel.add('${m.fn.name.toUpperCase()}(${m.fieldId})');
    }
    final parts = [
      'SELECT ${sel.isEmpty ? '*' : sel.join(', ')}',
      'FROM entities',
      if (_def.rowFieldIds.isNotEmpty)
        'GROUP BY ${_def.rowFieldIds.join(', ')}',
    ];
    return parts.join('\n');
  }
}
