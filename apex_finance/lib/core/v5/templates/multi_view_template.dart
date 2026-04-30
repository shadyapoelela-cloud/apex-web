/// APEX V5.2 — Multi-View List Template (T1 from 10-round synthesis).
///
/// Unified list screen that switches between 5 views:
///   📋 List      — table with inline editing
///   🗂️ Kanban    — drag-drop columns by status
///   📅 Calendar  — time-based view (Tax Calendar, Leaves)
///   📊 Pivot     — drilldown matrix (Budget vs Actual)
///   📈 Chart     — visual summary
///
/// Includes:
///   - Smart Filter Bar (multi-select chips + saved views)
///   - Saved Views dropdown (shared across team)
///   - Bulk actions on selection
///   - Quick Create slide-out
///
/// Inspired by:
///   - Odoo (List/Kanban/Gantt/Calendar/Pivot — 6-view switcher)
///   - NetSuite Saved Searches (shareable filters)
///   - Linear (keyboard-first inline editing)
library;

import 'package:flutter/material.dart';
import '../../theme.dart' as core_theme;

enum ViewMode { list, kanban, calendar, pivot, chart }

extension ViewModeX on ViewMode {
  String get labelAr {
    switch (this) {
      case ViewMode.list:
        return 'قائمة';
      case ViewMode.kanban:
        return 'كانبان';
      case ViewMode.calendar:
        return 'تقويم';
      case ViewMode.pivot:
        return 'محور';
      case ViewMode.chart:
        return 'مخطط';
    }
  }

  IconData get icon {
    switch (this) {
      case ViewMode.list:
        return Icons.list;
      case ViewMode.kanban:
        return Icons.view_kanban;
      case ViewMode.calendar:
        return Icons.calendar_month;
      case ViewMode.pivot:
        return Icons.grid_view;
      case ViewMode.chart:
        return Icons.bar_chart;
    }
  }
}

/// A saved view (filter + sort + view mode preset).
class SavedView {
  final String id;
  final String labelAr;
  final IconData icon;
  final bool isShared;
  final ViewMode defaultViewMode;
  const SavedView({
    required this.id,
    required this.labelAr,
    required this.icon,
    required this.defaultViewMode,
    this.isShared = false,
  });
}

/// A filter chip in the smart filter bar.
class FilterChipDef {
  final String id;
  final String labelAr;
  final IconData? icon;
  final Color? color;
  final int? count;
  final bool active;
  const FilterChipDef({
    required this.id,
    required this.labelAr,
    this.icon,
    this.color,
    this.count,
    this.active = false,
  });
}

class MultiViewTemplate extends StatefulWidget {
  final String titleAr;
  final String? subtitleAr;

  /// Which views to enable (subset of all 5).
  final Set<ViewMode> enabledViews;

  final ViewMode initialView;

  /// Render each view. Only views in [enabledViews] are called.
  final Widget Function(BuildContext) listBuilder;
  final Widget Function(BuildContext)? kanbanBuilder;
  final Widget Function(BuildContext)? calendarBuilder;
  final Widget Function(BuildContext)? pivotBuilder;
  final Widget Function(BuildContext)? chartBuilder;

  /// Saved views (empty = no saved views UI).
  final List<SavedView> savedViews;

  /// Filter chips (top of the list, above view-mode switcher).
  final List<FilterChipDef> filterChips;
  final ValueChanged<String>? onFilterToggle;

  /// "+ New" action.
  final VoidCallback? onCreateNew;
  final String createLabelAr;

  /// Primary header actions (Import, Export, Refresh, ...).
  final List<Widget>? headerActions;

  /// Fired whenever the search field changes. When null the search box
  /// stays decorative (no filtering side-effect).
  final ValueChanged<String>? onSearchChanged;

  const MultiViewTemplate({
    super.key,
    required this.titleAr,
    required this.listBuilder,
    this.subtitleAr,
    this.enabledViews = const {ViewMode.list},
    this.initialView = ViewMode.list,
    this.kanbanBuilder,
    this.calendarBuilder,
    this.pivotBuilder,
    this.chartBuilder,
    this.savedViews = const [],
    this.filterChips = const [],
    this.onFilterToggle,
    this.onCreateNew,
    this.createLabelAr = 'جديد',
    this.headerActions,
    this.onSearchChanged,
  });

  @override
  State<MultiViewTemplate> createState() => _MultiViewTemplateState();
}

class _MultiViewTemplateState extends State<MultiViewTemplate> {
  late ViewMode _view;
  final _searchCtrl = TextEditingController();
  String _savedViewId = '';

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _view = widget.enabledViews.contains(widget.initialView)
        ? widget.initialView
        : widget.enabledViews.first;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(),
            _buildViewSwitcher(),
            const Divider(height: 1),
            Expanded(child: _buildCurrentView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titleAr,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                if (widget.subtitleAr != null)
                  Text(widget.subtitleAr!,
                      style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
              ],
            ),
          ),
          // Search
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'بحث...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: core_theme.AC.navy3,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: core_theme.AC.bdr),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (widget.headerActions != null) ...widget.headerActions!,
          if (widget.onCreateNew != null) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: widget.onCreateNew,
              style: FilledButton.styleFrom(backgroundColor: _gold),
              icon: const Icon(Icons.add, size: 16),
              label: Text(widget.createLabelAr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    if (widget.filterChips.isEmpty && widget.savedViews.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Saved Views dropdown
            if (widget.savedViews.isNotEmpty) ...[
              PopupMenuButton<String>(
                initialValue: _savedViewId,
                tooltip: 'العروض المحفوظة',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _navy.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 14, color: _navy),
                      const SizedBox(width: 4),
                      Text(
                        _savedViewId.isEmpty
                            ? 'كل السجلات'
                            : widget.savedViews
                                .firstWhere((v) => v.id == _savedViewId,
                                    orElse: () => widget.savedViews.first)
                                .labelAr,
                        style: TextStyle(
                            fontSize: 12, color: _navy, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: _navy),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: '', child: Text('كل السجلات')),
                  const PopupMenuDivider(),
                  ...widget.savedViews.map((v) => PopupMenuItem(
                        value: v.id,
                        child: Row(
                          children: [
                            Icon(v.icon, size: 14),
                            const SizedBox(width: 8),
                            Text(v.labelAr),
                            if (v.isShared) ...[
                              const Spacer(),
                              Icon(Icons.group, size: 12, color: core_theme.AC.td),
                            ],
                          ],
                        ),
                      )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: '__save__', child: Text('💾 حفظ عرض جديد...')),
                ],
                onSelected: (v) {
                  if (v != '__save__') {
                    setState(() => _savedViewId = v);
                  }
                },
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 20,
                color: core_theme.AC.bdr,
              ),
              const SizedBox(width: 10),
            ],
            // Filter chips
            ...widget.filterChips.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => widget.onFilterToggle?.call(c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.active
                            ? (c.color ?? _gold).withValues(alpha: 0.12)
                            : core_theme.AC.navy3,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: c.active
                                ? (c.color ?? _gold)
                                : core_theme.AC.bdr),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.icon != null) ...[
                            Icon(c.icon,
                                size: 12,
                                color: c.active
                                    ? (c.color ?? _gold)
                                    : core_theme.AC.ts),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            c.labelAr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.active
                                  ? (c.color ?? _gold)
                                  : core_theme.AC.tp,
                            ),
                          ),
                          if (c.count != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (c.color ?? _gold).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${c.count}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: c.color ?? _gold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    if (widget.enabledViews.length < 2) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: core_theme.AC.navy3,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ViewMode.values.where((v) => widget.enabledViews.contains(v)).map((v) {
                final active = v == _view;
                return InkWell(
                  onTap: () => setState(() => _view = v),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: core_theme.AC.tp.withValues(alpha: 0.06),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(v.icon,
                            size: 14, color: active ? _gold : core_theme.AC.ts),
                        const SizedBox(width: 4),
                        Text(
                          v.labelAr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? _navy : core_theme.AC.ts,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Spacer(),
          // Sort / Group / Export buttons
          _MiniBtn(icon: Icons.sort, tooltip: 'فرز', onTap: () {}),
          const SizedBox(width: 6),
          _MiniBtn(icon: Icons.workspaces_outline, tooltip: 'تجميع', onTap: () {}),
          const SizedBox(width: 6),
          _MiniBtn(icon: Icons.download, tooltip: 'تصدير', onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case ViewMode.list:
        return widget.listBuilder(context);
      case ViewMode.kanban:
        return widget.kanbanBuilder?.call(context) ?? _notImplemented();
      case ViewMode.calendar:
        return widget.calendarBuilder?.call(context) ?? _notImplemented();
      case ViewMode.pivot:
        return widget.pivotBuilder?.call(context) ?? _notImplemented();
      case ViewMode.chart:
        return widget.chartBuilder?.call(context) ?? _notImplemented();
    }
  }

  Widget _notImplemented() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_view.icon, size: 64, color: core_theme.AC.bdr),
          const SizedBox(height: 16),
          Text('عرض ${_view.labelAr} قيد التطوير',
              style: TextStyle(color: core_theme.AC.ts)),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: core_theme.AC.navy3,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: core_theme.AC.ts),
        ),
      ),
    );
  }
}
