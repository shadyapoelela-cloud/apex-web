/// APEX Dashboard Builder — drag-drop composable dashboards.
///
/// Source: SAP Fiori card composer + Notion blocks + Odoo 19 dashboard
/// designer. Lets users add/remove/reorder/resize widgets on a 12-column
/// grid. Widget definitions are provided by the caller so the same
/// builder works across different contexts (exec / startup CFO / retail).
///
/// Persistence is up to the host screen — it gets a `List<DashboardBlock>`
/// via `onLayoutChanged` and persists it wherever it likes.
///
/// Usage:
/// ```dart
/// ApexDashboardBuilder(
///   blocks: [
///     DashboardBlock(id: k1, widgetId: w1, span: 3),
///     DashboardBlock(id: k2, widgetId: w2, span: 3),
///     DashboardBlock(id: k3, widgetId: w3, span: 6),
///   ],
///   widgetRegistry: myRegistry,
///   onLayoutChanged: saveLayout,
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'apex_responsive.dart';
import 'design_tokens.dart';
import 'theme.dart';

/// A block on the dashboard — one instance of a widget.
class DashboardBlock {
  final String id;            // unique per dashboard
  final String widgetId;      // lookup in widgetRegistry
  final int span;             // 1..12 (columns)

  const DashboardBlock({
    required this.id,
    required this.widgetId,
    this.span = 3,
  });

  DashboardBlock copyWith({int? span}) =>
      DashboardBlock(id: id, widgetId: widgetId, span: span ?? this.span);
}

/// A widget definition — what the builder offers when the user hits "+ Add".
class DashboardWidgetDef {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  final int defaultSpan;

  const DashboardWidgetDef({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.builder,
    this.defaultSpan = 3,
  });
}

class ApexDashboardBuilder extends StatefulWidget {
  final List<DashboardBlock> blocks;
  final List<DashboardWidgetDef> widgetRegistry;
  final ValueChanged<List<DashboardBlock>> onLayoutChanged;
  final bool editable;

  const ApexDashboardBuilder({
    super.key,
    required this.blocks,
    required this.widgetRegistry,
    required this.onLayoutChanged,
    this.editable = true,
  });

  @override
  State<ApexDashboardBuilder> createState() => _ApexDashboardBuilderState();
}

class _ApexDashboardBuilderState extends State<ApexDashboardBuilder> {
  late List<DashboardBlock> _blocks;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _blocks = [...widget.blocks];
  }

  @override
  void didUpdateWidget(covariant ApexDashboardBuilder old) {
    super.didUpdateWidget(old);
    if (widget.blocks != old.blocks) {
      _blocks = [...widget.blocks];
    }
  }

  Map<String, DashboardWidgetDef> get _registry =>
      {for (final w in widget.widgetRegistry) w.id: w};

  void _emit() => widget.onLayoutChanged(List.unmodifiable(_blocks));

  void _add(DashboardWidgetDef def) {
    setState(() {
      _blocks.add(DashboardBlock(
        id: 'block_${DateTime.now().millisecondsSinceEpoch}',
        widgetId: def.id,
        span: def.defaultSpan,
      ));
    });
    _emit();
  }

  void _remove(String blockId) {
    setState(() => _blocks.removeWhere((b) => b.id == blockId));
    _emit();
  }

  void _resize(String blockId, int newSpan) {
    setState(() {
      final i = _blocks.indexWhere((b) => b.id == blockId);
      if (i >= 0) _blocks[i] = _blocks[i].copyWith(span: newSpan.clamp(1, 12));
    });
    _emit();
  }

  void _reorder(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx -= 1;
    setState(() {
      final item = _blocks.removeAt(oldIdx);
      _blocks.insert(newIdx, item);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ApexResponsive.isMobile(context);
    // On mobile, force single-column layout (all blocks span 12).
    final totalColumns = isMobile ? 1 : 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.editable) _toolbar(),
        const SizedBox(height: AppSpacing.md),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: _reorder,
          itemCount: _blocks.length,
          itemBuilder: (ctx, i) {
            final block = _blocks[i];
            final def = _registry[block.widgetId];
            final span = isMobile ? totalColumns : block.span;
            return Padding(
              key: ValueKey(block.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _blockFrame(block, def, span, totalColumns, i),
            );
          },
        ),
        if (_editMode) _addBlockPicker(),
      ],
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Text(
          'لوحة التحكم',
          style: TextStyle(
            color: AC.tp,
            fontSize: AppFontSize.xl,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          icon: Icon(_editMode ? Icons.check : Icons.edit),
          label: Text(_editMode ? 'حفظ' : 'تعديل'),
          onPressed: () => setState(() => _editMode = !_editMode),
        ),
      ],
    );
  }

  Widget _blockFrame(
    DashboardBlock block,
    DashboardWidgetDef? def,
    int span,
    int totalColumns,
    int index,
  ) {
    return Container(
      constraints: BoxConstraints(
        minHeight: 140,
      ),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _editMode ? AC.gold.withValues(alpha: 0.6) : AC.navy4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editMode) _editHeader(block, def, span, index),
          Expanded(
            child: def == null
                ? Center(
                    child: Text(
                      'widget غير معروف: ${block.widgetId}',
                      style: TextStyle(color: AC.err),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: def.builder(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _editHeader(DashboardBlock block, DashboardWidgetDef? def, int span, int index) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: AC.ts, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            def?.title ?? block.widgetId,
            style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.remove, size: 16, color: AC.ts),
            tooltip: 'تصغير',
            onPressed: () => _resize(block.id, span - 1),
          ),
          Text('$span/12', style: TextStyle(color: AC.td, fontSize: AppFontSize.sm)),
          IconButton(
            icon: Icon(Icons.add, size: 16, color: AC.ts),
            tooltip: 'توسيع',
            onPressed: () => _resize(block.id, span + 1),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: AC.err),
            tooltip: 'إزالة',
            onPressed: () => _remove(block.id),
          ),
        ],
      ),
    );
  }

  Widget _addBlockPicker() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AC.gold.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إضافة ودجت',
            style: TextStyle(
              color: AC.gold,
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: widget.widgetRegistry.map((def) {
              return InkWell(
                onTap: () => _add(def),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AC.navy3,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AC.navy4),
                  ),
                  child: Row(
                    children: [
                      Icon(def.icon, color: AC.gold, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              def.title,
                              style: TextStyle(
                                color: AC.tp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (def.subtitle != null)
                              Text(
                                def.subtitle!,
                                style: TextStyle(
                                  color: AC.td,
                                  fontSize: AppFontSize.sm,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.add_circle_outline, color: AC.gold, size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
