/// APEX Filter Bar — horizontal filter strip above tables.
///
/// Source: Xero saved filter views + Odoo 19 faceted filters + SAP Fiori
/// adapt filters. Emits onFilterChanged whenever any filter mutates.
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'theme.dart';

/// Toggleable filter chip definition.
class ApexFilterChip {
  final String key;
  final String label;
  final IconData? icon;
  final int? badgeCount;

  const ApexFilterChip({
    required this.key,
    required this.label,
    this.icon,
    this.badgeCount,
  });
}

/// Immutable snapshot of the current filter state.
class ApexFilterState {
  final String searchText;
  final DateTimeRange? dateRange;
  final Set<String> activeChipKeys;

  const ApexFilterState({
    this.searchText = '',
    this.dateRange,
    this.activeChipKeys = const {},
  });

  ApexFilterState copyWith({
    String? searchText,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    Set<String>? activeChipKeys,
  }) {
    return ApexFilterState(
      searchText: searchText ?? this.searchText,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      activeChipKeys: activeChipKeys ?? this.activeChipKeys,
    );
  }

  bool get isEmpty =>
      searchText.isEmpty && dateRange == null && activeChipKeys.isEmpty;
}

class ApexFilterBar extends StatefulWidget {
  final List<ApexFilterChip> chips;
  final bool showSearch;
  final bool showDateRange;
  final String searchHint;
  final ValueChanged<ApexFilterState> onFilterChanged;
  final List<Widget>? trailing;

  const ApexFilterBar({
    super.key,
    this.chips = const [],
    this.showSearch = true,
    this.showDateRange = false,
    this.searchHint = 'بحث...',
    required this.onFilterChanged,
    this.trailing,
  });

  @override
  State<ApexFilterBar> createState() => _ApexFilterBarState();
}

class _ApexFilterBarState extends State<ApexFilterBar> {
  final TextEditingController _searchCtrl = TextEditingController();
  ApexFilterState _state = const ApexFilterState();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _emit(ApexFilterState next) {
    setState(() => _state = next);
    widget.onFilterChanged(next);
  }

  void _toggleChip(String key) {
    final active = Set<String>.from(_state.activeChipKeys);
    if (!active.remove(key)) active.add(key);
    _emit(_state.copyWith(activeChipKeys: active));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _state.dateRange,
    );
    if (range != null) _emit(_state.copyWith(dateRange: range));
  }

  @override
  Widget build(BuildContext context) {
    final chipCount = _state.activeChipKeys.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        children: [
          if (widget.showSearch)
            SizedBox(
              width: 280,
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => _emit(_state.copyWith(searchText: v)),
                style: TextStyle(color: AC.tp, fontSize: AppFontSize.md),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(color: AC.td, fontSize: AppFontSize.md),
                  prefixIcon: Icon(Icons.search, size: 16, color: AC.td),
                  filled: true,
                  fillColor: AC.navy,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AC.navy4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AC.navy4),
                  ),
                ),
              ),
            ),
          if (widget.showDateRange) ...[
            const SizedBox(width: AppSpacing.md),
            _DateRangeButton(
              range: _state.dateRange,
              onPick: _pickDate,
              onClear: () => _emit(_state.copyWith(clearDateRange: true)),
            ),
          ],
          if (widget.chips.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in widget.chips)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _Chip(
                          chip: c,
                          active: _state.activeChipKeys.contains(c.key),
                          onTap: () => _toggleChip(c.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (chipCount > 0)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AC.gold,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$chipCount',
                style: TextStyle(
                  color: AC.navy,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.trailing != null) ...widget.trailing!,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final ApexFilterChip chip;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.chip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AC.gold.withValues(alpha: 0.2) : AC.navy3,
          border: Border.all(color: active ? AC.gold : AC.navy4),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chip.icon != null) ...[
              Icon(chip.icon, size: 14, color: active ? AC.gold : AC.ts),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              chip.label,
              style: TextStyle(
                color: active ? AC.gold : AC.tp,
                fontSize: AppFontSize.md,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (chip.badgeCount != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(${chip.badgeCount})',
                style: TextStyle(color: AC.td, fontSize: AppFontSize.sm),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateRangeButton({
    required this.range,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = range == null
        ? 'اختر الفترة'
        : '${_fmt(range!.start)} → ${_fmt(range!.end)}';
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AC.navy,
          border: Border.all(color: AC.navy4),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: AC.td),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(color: AC.tp, fontSize: AppFontSize.md),
            ),
            if (range != null) ...[
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: AC.td),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
