/// APEX — Multi-view host (Odoo-signature pattern)
/// ═══════════════════════════════════════════════════════════
/// Wraps any list of objects in a view-switcher (List / Kanban / Pivot
/// / Calendar) so the same data can be projected five ways with a
/// one-click swap. This is Odoo's highest-leverage UX primitive.
///
/// Usage:
///
///   ApexMultiViewHost<Invoice>(
///     items: invoices,
///     modes: const [ApexViewMode.list, ApexViewMode.kanban, ApexViewMode.pivot],
///     initialMode: ApexViewMode.list,
///     listBuilder: (items) => InvoicesList(items: items),
///     kanbanBuilder: (items) => InvoicesKanban(items: items),
///     pivotBuilder: (items) => InvoicesPivot(items: items),
///   )
///
/// Saves the user's last choice per screen-key so the next visit
/// opens in the same view.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

enum ApexViewMode {
  list,
  kanban,
  calendar,
  pivot,
  graph,
  form,
}

extension ApexViewModeMeta on ApexViewMode {
  IconData get icon {
    switch (this) {
      case ApexViewMode.list:      return Icons.list;
      case ApexViewMode.kanban:    return Icons.view_kanban_outlined;
      case ApexViewMode.calendar:  return Icons.calendar_month_outlined;
      case ApexViewMode.pivot:     return Icons.pivot_table_chart_outlined;
      case ApexViewMode.graph:     return Icons.bar_chart;
      case ApexViewMode.form:      return Icons.article_outlined;
    }
  }

  String get labelAr {
    switch (this) {
      case ApexViewMode.list:      return 'قائمة';
      case ApexViewMode.kanban:    return 'لوحة';
      case ApexViewMode.calendar:  return 'تقويم';
      case ApexViewMode.pivot:     return 'محور';
      case ApexViewMode.graph:     return 'رسم';
      case ApexViewMode.form:      return 'بطاقة';
    }
  }
}

typedef ApexViewBuilder<T> = Widget Function(List<T> items);

class ApexMultiViewHost<T> extends StatefulWidget {
  /// Unique key for persisting the last-used view per screen.
  final String screenKey;

  final List<T> items;
  final List<ApexViewMode> modes;
  final ApexViewMode initialMode;

  final ApexViewBuilder<T>? listBuilder;
  final ApexViewBuilder<T>? kanbanBuilder;
  final ApexViewBuilder<T>? calendarBuilder;
  final ApexViewBuilder<T>? pivotBuilder;
  final ApexViewBuilder<T>? graphBuilder;
  final ApexViewBuilder<T>? formBuilder;

  /// Optional trailing widgets on the view-switcher bar (e.g. filter chips).
  final List<Widget>? trailing;

  const ApexMultiViewHost({
    super.key,
    required this.screenKey,
    required this.items,
    this.modes = const [ApexViewMode.list, ApexViewMode.kanban],
    this.initialMode = ApexViewMode.list,
    this.listBuilder,
    this.kanbanBuilder,
    this.calendarBuilder,
    this.pivotBuilder,
    this.graphBuilder,
    this.formBuilder,
    this.trailing,
  });

  @override
  State<ApexMultiViewHost<T>> createState() => _ApexMultiViewHostState<T>();
}

class _ApexMultiViewHostState<T> extends State<ApexMultiViewHost<T>> {
  late ApexViewMode _mode;

  // In-memory cache of last-used view per screenKey. Kept simple; a
  // real impl should persist to SharedPreferences.
  static final Map<String, ApexViewMode> _memo = {};

  @override
  void initState() {
    super.initState();
    _mode = _memo[widget.screenKey] ?? widget.initialMode;
    if (!widget.modes.contains(_mode)) _mode = widget.modes.first;
  }

  Widget? _buildFor(ApexViewMode m) {
    switch (m) {
      case ApexViewMode.list:      return widget.listBuilder?.call(widget.items);
      case ApexViewMode.kanban:    return widget.kanbanBuilder?.call(widget.items);
      case ApexViewMode.calendar:  return widget.calendarBuilder?.call(widget.items);
      case ApexViewMode.pivot:     return widget.pivotBuilder?.call(widget.items);
      case ApexViewMode.graph:     return widget.graphBuilder?.call(widget.items);
      case ApexViewMode.form:      return widget.formBuilder?.call(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildFor(_mode) ??
        Center(
          child: Text(
            'العرض "${_mode.labelAr}" غير مهيّأ لهذه الشاشة',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _switcherBar(),
        Expanded(child: content),
      ],
    );
  }

  Widget _switcherBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          for (final m in widget.modes) _btn(m),
          const Spacer(),
          if (widget.trailing != null) ...widget.trailing!,
        ],
      ),
    );
  }

  Widget _btn(ApexViewMode m) {
    final selected = m == _mode;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _mode = m;
            _memo[widget.screenKey] = m;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AC.gold.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AC.gold : AC.gold.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 14, color: selected ? AC.gold : AC.ts),
              const SizedBox(width: 6),
              Text(
                m.labelAr,
                style: TextStyle(
                  color: selected ? AC.gold : AC.ts,
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// ─────────────────────────────────────────────────────────
/// SAP-style Smart Buttons row — top-of-record action chips
/// showing linked-entity counts. Click opens the filtered list.
/// ─────────────────────────────────────────────────────────


class ApexSmartButton {
  final IconData icon;
  final String labelAr;
  final String countText;           // "12" or "2.4K"
  final Color? accent;
  final VoidCallback onTap;
  const ApexSmartButton({
    required this.icon,
    required this.labelAr,
    required this.countText,
    required this.onTap,
    this.accent,
  });
}

class ApexSmartButtons extends StatelessWidget {
  final List<ApexSmartButton> buttons;
  const ApexSmartButtons({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: buttons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _tile(buttons[i]),
      ),
    );
  }

  Widget _tile(ApexSmartButton b) {
    final color = b.accent ?? AC.gold;
    return InkWell(
      onTap: b.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(b.icon, size: 22, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    b.countText,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    b.labelAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AC.ts,
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
