/// APEX V5.1 — Multiple Views Pattern (Enhancement #4).
///
/// Inspired by Notion + Odoo + Linear: every list-type screen should
/// support multiple views on the same data — List, Kanban, Calendar,
/// Gantt, Pivot. User picks what fits their task.
///
/// Usage:
///   ApexV5MultiView<Invoice>(
///     items: invoices,
///     initialMode: V5ViewMode.list,
///     availableModes: [list, kanban, calendar],
///     listBuilder: (ctx, items) => MyTable(items),
///     kanbanBuilder: (ctx, items) => MyKanban(items),
///     ...
///   )
library;

import 'package:flutter/material.dart';

enum V5ViewMode { list, kanban, calendar, gantt, pivot, gallery, map }

class V5ViewModeInfo {
  final IconData icon;
  final String labelAr;
  final String labelEn;

  const V5ViewModeInfo(this.icon, this.labelAr, this.labelEn);
}

const Map<V5ViewMode, V5ViewModeInfo> v5ViewModeInfo = {
  V5ViewMode.list: V5ViewModeInfo(Icons.view_list, 'قائمة', 'List'),
  V5ViewMode.kanban: V5ViewModeInfo(Icons.view_kanban, 'كانبان', 'Kanban'),
  V5ViewMode.calendar: V5ViewModeInfo(Icons.calendar_month, 'تقويم', 'Calendar'),
  V5ViewMode.gantt: V5ViewModeInfo(Icons.timeline, 'جانت', 'Gantt'),
  V5ViewMode.pivot: V5ViewModeInfo(Icons.table_chart, 'محوري', 'Pivot'),
  V5ViewMode.gallery: V5ViewModeInfo(Icons.grid_view, 'معرض', 'Gallery'),
  V5ViewMode.map: V5ViewModeInfo(Icons.map, 'خريطة', 'Map'),
};

/// View Switcher widget — horizontal button row shown above content.
class ApexV5ViewSwitcher extends StatelessWidget {
  final V5ViewMode currentMode;
  final List<V5ViewMode> availableModes;
  final ValueChanged<V5ViewMode> onChanged;
  final Widget? trailing;

  const ApexV5ViewSwitcher({
    super.key,
    required this.currentMode,
    required this.availableModes,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          for (final mode in availableModes) ...[
            _ViewModeButton(
              mode: mode,
              isActive: mode == currentMode,
              onTap: () => onChanged(mode),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatefulWidget {
  final V5ViewMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ViewModeButton> createState() => _ViewModeButtonState();
}

class _ViewModeButtonState extends State<_ViewModeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final info = v5ViewModeInfo[widget.mode]!;
    final color = widget.isActive
        ? const Color(0xFFD4AF37)
        : _hover
            ? Colors.black87
            : Colors.black54;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFFD4AF37).withOpacity(0.12)
                : _hover
                    ? Colors.black.withOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                info.labelAr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full multi-view wrapper that handles state + renders the right view.
class ApexV5MultiView<T> extends StatefulWidget {
  final List<T> items;
  final V5ViewMode initialMode;
  final List<V5ViewMode> availableModes;

  final Widget Function(BuildContext ctx, List<T> items)? listBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? kanbanBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? calendarBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? ganttBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? pivotBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? galleryBuilder;
  final Widget Function(BuildContext ctx, List<T> items)? mapBuilder;

  final Widget? trailing;

  const ApexV5MultiView({
    super.key,
    required this.items,
    required this.initialMode,
    required this.availableModes,
    this.listBuilder,
    this.kanbanBuilder,
    this.calendarBuilder,
    this.ganttBuilder,
    this.pivotBuilder,
    this.galleryBuilder,
    this.mapBuilder,
    this.trailing,
  });

  @override
  State<ApexV5MultiView<T>> createState() => _ApexV5MultiViewState<T>();
}

class _ApexV5MultiViewState<T> extends State<ApexV5MultiView<T>> {
  late V5ViewMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Widget _buildView(BuildContext ctx) {
    Widget? Function(BuildContext, List<T>)? b;
    switch (_mode) {
      case V5ViewMode.list:
        b = widget.listBuilder;
        break;
      case V5ViewMode.kanban:
        b = widget.kanbanBuilder;
        break;
      case V5ViewMode.calendar:
        b = widget.calendarBuilder;
        break;
      case V5ViewMode.gantt:
        b = widget.ganttBuilder;
        break;
      case V5ViewMode.pivot:
        b = widget.pivotBuilder;
        break;
      case V5ViewMode.gallery:
        b = widget.galleryBuilder;
        break;
      case V5ViewMode.map:
        b = widget.mapBuilder;
        break;
    }
    if (b == null) {
      final info = v5ViewModeInfo[_mode]!;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, size: 48, color: Colors.black26),
            const SizedBox(height: 10),
            Text(
              'طريقة عرض "${info.labelAr}" غير مدعومة لهذه الشاشة',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }
    return b(ctx, widget.items) ?? const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ApexV5ViewSwitcher(
          currentMode: _mode,
          availableModes: widget.availableModes,
          onChanged: (m) => setState(() => _mode = m),
          trailing: widget.trailing,
        ),
        Expanded(child: _buildView(context)),
      ],
    );
  }
}
