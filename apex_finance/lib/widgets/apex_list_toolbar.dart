/// APEX — ApexListToolbar (Odoo-inspired ribbon for list screens).
///
/// Shared widget used across فواتير المبيعات / فواتير المشتريات /
/// قيود اليومية and any future list-style chip body. RTL-first.
///
/// Visual layout (right-to-left):
///   ┌─────────────────────────────────────────────────────────────────┐
///   │ [TITLE]               🔍 search ⚙ ▼   ‹ 1-N/M ›   ☰▾   ?       │
///   │ [✨ ذكاء][+ جديد]                                                │
///   └─────────────────────────────────────────────────────────────────┘
///
/// Right column (vertical stack):
///   • Title (flexible width — full screen name regardless of length)
///   • Two CTAs side-by-side: AI (filled, theme purple) + Create (gold outlined)
///
/// Middle (Expanded):
///   • Single search field with `⚙` settings icon and `▼` chevron that
///     opens a 3-column Odoo-style panel: Filters · Group-by · Favorites.
///   • Filter and group-by labels are removed from the toolbar surface
///     and live entirely inside this panel (cleaner, fewer chrome pills).
///
/// Left cluster:
///   • Pagination: `‹ 1-32 / 32 ›` text + nav arrows
///   • View-mode menu (List / Cards / Kanban / Activity — per screen)
///   • Help button (`?`) — opens a screen-specific shortcuts dialog
///
/// Theme: button colors come from AC tokens, so each apex theme paints
/// the AI button in its own purple/violet/pink and the create button in
/// its own gold/honey. Container uses navy2 → 5% gold gradient (matches
/// JE Builder header for visual continuity).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────
// Public data classes — describe per-screen content for the dropdown panels.
// ─────────────────────────────────────────────────────────────────────────

/// One option inside the filter panel (e.g. a status, a date preset).
class ApexFilterOption {
  final String key;
  final String labelAr;
  final IconData? icon;
  final Color? color;
  const ApexFilterOption({
    required this.key,
    required this.labelAr,
    this.icon,
    this.color,
  });
}

/// A group of filter options that render together with a header.
/// `multi: true` → user can tick multiple options at once (status, customer).
/// `multi: false` → radio-style (date preset, amount bucket).
class ApexFilterGroup {
  final String labelAr;
  final IconData? icon;
  final List<ApexFilterOption> options;
  final bool multi;
  /// Currently active keys (subset of `options[*].key`).
  final Set<String> selected;
  /// Toggle handler: receives the key the user clicked.
  final void Function(String key) onToggle;
  const ApexFilterGroup({
    required this.labelAr,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.icon,
    this.multi = true,
  });
}

/// Group-by option (radio — only one active at a time).
class ApexGroupOption {
  final String key;
  final String labelAr;
  final IconData? icon;
  const ApexGroupOption({
    required this.key,
    required this.labelAr,
    this.icon,
  });
}

/// Saved search / quick filter preset.
class ApexFavorite {
  final String key;
  final String labelAr;
  final VoidCallback onApply;
  final VoidCallback? onDelete;
  const ApexFavorite({
    required this.key,
    required this.labelAr,
    required this.onApply,
    this.onDelete,
  });
}

/// View mode (List / Kanban / Cards / Activity / etc.).
class ApexViewMode {
  final String key;
  final String labelAr;
  final IconData icon;
  const ApexViewMode({
    required this.key,
    required this.labelAr,
    required this.icon,
  });
}

/// Keyboard shortcut row in the help dialog.
class ApexShortcut {
  final String key;
  final String labelAr;
  const ApexShortcut(this.key, this.labelAr);
}

/// One usage tip / how-to bullet shown in the help dialog. Renders
/// alongside keyboard shortcuts so the user can discover *what* the
/// screen can do, not just *how* to use the keyboard.
class ApexTip {
  final String titleAr;
  final String bodyAr;
  final IconData icon;
  const ApexTip({
    required this.titleAr,
    required this.bodyAr,
    this.icon = Icons.lightbulb_outline_rounded,
  });
}

/// One bulk action button shown in the selection bar.
/// `destructive: true` paints in `AC.err` to signal data-loss risk.
class ApexBulkAction {
  final String labelAr;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const ApexBulkAction({
    required this.labelAr,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Defaults — most screens won't customize these.
// ─────────────────────────────────────────────────────────────────────────

const List<ApexViewMode> kDefaultViewModes = [
  ApexViewMode(key: 'list', labelAr: 'قائمة', icon: Icons.view_list_rounded),
  ApexViewMode(key: 'cards', labelAr: 'بطاقات', icon: Icons.grid_view_rounded),
  ApexViewMode(
      key: 'kanban', labelAr: 'كانبان', icon: Icons.view_kanban_rounded),
  ApexViewMode(
      key: 'activity', labelAr: 'النشاط', icon: Icons.timeline_rounded),
];

// ─────────────────────────────────────────────────────────────────────────
// The widget.
// ─────────────────────────────────────────────────────────────────────────

class ApexListToolbar extends StatelessWidget {
  // ── Title block ────────────────────────────────────────────────────
  /// Screen name (e.g. "فواتير المبيعات"). Renders above the CTA buttons.
  final String titleAr;

  /// Optional pill icon next to the title (e.g. Icons.receipt_long_rounded).
  final IconData? titleIcon;

  /// Total record count loaded.
  final int totalCount;

  /// Records visible after filters/search.
  final int visibleCount;

  /// Singular noun for the counter (e.g. "فاتورة" → "32 فاتورة").
  final String itemNounAr;

  // ── Search ─────────────────────────────────────────────────────────
  final TextEditingController searchCtl;
  final FocusNode? searchFocus;
  final String searchHint;
  final VoidCallback? onSearchChanged;

  // ── Filter panel content ───────────────────────────────────────────
  final List<ApexFilterGroup> filterGroups;
  final List<ApexGroupOption> groupOptions;
  final String activeGroupKey;
  final void Function(String key) onChangeGroup;

  /// Optional sort options (radio-style).
  final List<ApexFilterOption> sortOptions;
  final String activeSortKey;
  final void Function(String key) onChangeSort;

  /// Saved searches (user-curated views).
  final List<ApexFavorite> favorites;
  final VoidCallback? onSaveFavorite;

  /// Clear-all callback (only shown if any filters are active).
  final VoidCallback? onClearAllFilters;

  // ── View modes ─────────────────────────────────────────────────────
  final List<ApexViewMode> viewModes;
  final String activeViewKey;
  final void Function(String key) onChangeView;

  // ── Pagination ─────────────────────────────────────────────────────
  /// Optional. When null, the pagination cluster is hidden.
  final int? currentPage;
  final int? pageSize;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  // ── CTAs ───────────────────────────────────────────────────────────
  final VoidCallback? onCreate;
  final String createLabelAr;
  final IconData createIcon;

  final VoidCallback? onAiCreate;
  final String aiCreateLabelAr;

  // ── Help dialog ────────────────────────────────────────────────────
  /// Shortcut rows displayed in the help dialog. If empty, the help
  /// button is hidden.
  final List<ApexShortcut> shortcuts;

  /// Optional usage tips ("how do I…") shown alongside the shortcuts in
  /// the help dialog. Empty list = section is omitted.
  final List<ApexTip> tips;

  // ── Theme override ─────────────────────────────────────────────────
  /// Background color of the AI button. Defaults to AC.purple (theme-aware).
  final Color? aiButtonColor;

  /// Optional max width for the search-pill (the bar that holds the search
  /// input + filter/group chips). When null the pill stretches to fill the
  /// remaining row space (current sales-invoices behaviour). When set, the
  /// pill is capped at the given width so it never feels oversized.
  final double? searchPillMaxWidth;

  // ── Bulk-select (A2) ───────────────────────────────────────────────
  /// Number of currently selected rows. When > 0 the toolbar swaps to
  /// a "selection bar" that exposes bulk actions instead of the normal
  /// title/search/CTAs. Set to 0 (default) to keep the regular toolbar.
  final int selectedCount;

  /// Bulk operations available when one or more rows are selected.
  /// Rendered on the LEFT of the selection bar.
  final List<ApexBulkAction> bulkActions;

  /// Clears the selection (typically resets the screen's selected-IDs Set).
  /// Required when `selectedCount > 0`.
  final VoidCallback? onClearSelection;

  const ApexListToolbar({
    super.key,
    required this.titleAr,
    required this.totalCount,
    required this.visibleCount,
    required this.itemNounAr,
    required this.searchCtl,
    required this.searchHint,
    required this.filterGroups,
    required this.groupOptions,
    required this.activeGroupKey,
    required this.onChangeGroup,
    required this.viewModes,
    required this.activeViewKey,
    required this.onChangeView,
    this.titleIcon,
    this.searchFocus,
    this.onSearchChanged,
    this.sortOptions = const [],
    this.activeSortKey = '',
    this.onChangeSort = _noop,
    this.favorites = const [],
    this.onSaveFavorite,
    this.onClearAllFilters,
    this.currentPage,
    this.pageSize,
    this.onPrevPage,
    this.onNextPage,
    this.onCreate,
    this.createLabelAr = 'جديد',
    this.createIcon = Icons.add_rounded,
    this.onAiCreate,
    this.aiCreateLabelAr = 'ذكاء',
    this.shortcuts = const [],
    this.tips = const [],
    this.aiButtonColor,
    this.selectedCount = 0,
    this.bulkActions = const [],
    this.onClearSelection,
    this.searchPillMaxWidth,
  });

  static void _noop(String _) {}

  // ── Active filter counter (drives the chevron badge) ───────────────
  int get _activeFilterCount {
    var n = 0;
    for (final g in filterGroups) {
      n += g.selected.length;
    }
    if (searchCtl.text.trim().isNotEmpty) n++;
    return n;
  }

  // ─────────────────────────────────────────────────────────────────
  //  Build
  //  Wrapped in Directionality.rtl so the Row's children render in the
  //  user-specified order regardless of ambient direction (some shells
  //  render this widget inside an LTR Material context, which flipped
  //  right ↔ left in the user's earlier reports).
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // When rows are selected, swap the toolbar for a selection bar
    // (Material 3 / Odoo pattern). The bar shows count + bulk actions
    // and an X to clear the selection. Animated swap (180ms cross-fade).
    final inSelectionMode = selectedCount > 0 && onClearSelection != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: inSelectionMode
            ? _buildSelectionBar(context)
            : _buildNormalToolbar(context),
      ),
    );
  }

  // ── Selection bar (visible when selectedCount > 0) ─────────────────
  Widget _buildSelectionBar(BuildContext context) {
    return Container(
      key: const ValueKey('selection-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AC.gold.withValues(alpha: 0.20),
            AC.gold.withValues(alpha: 0.10),
          ],
        ),
        border: Border(bottom: BorderSide(color: AC.gold)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // ── RIGHT: clear-selection X + count ────────────────────
          Tooltip(
            message: 'إلغاء التحديد',
            child: IconButton(
              onPressed: onClearSelection,
              icon: Icon(Icons.close_rounded, color: AC.gold, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AC.gold.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$selectedCount محدّد',
            style: TextStyle(
              color: AC.gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          // ── LEFT: bulk action buttons ───────────────────────────
          for (var i = 0; i < bulkActions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _bulkActionButton(bulkActions[i]),
          ],
        ],
      ),
    );
  }

  Widget _bulkActionButton(ApexBulkAction action) {
    final color = action.destructive ? AC.err : AC.tp;
    // A4: Semantics — destructive flagged so assistive tech can warn.
    return Semantics(
      label: action.labelAr,
      button: true,
      hint: action.destructive ? 'إجراء حذف لا يمكن التراجع عنه' : null,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: action.onTap,
        icon: Icon(action.icon, size: 15, color: color),
        label: Text(
          action.labelAr,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Normal toolbar (visible when no rows selected) ─────────────────
  Widget _buildNormalToolbar(BuildContext context) {
    return Container(
      key: const ValueKey('normal-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AC.navy2,
            Color.lerp(AC.navy2, AC.gold, 0.05) ?? AC.navy2,
          ],
        ),
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: IntrinsicHeight(
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── RIGHT: title above CTAs ─────────────────────────────
            _RightCluster(
              titleAr: titleAr,
              titleIcon: titleIcon,
              totalCount: totalCount,
              visibleCount: visibleCount,
              itemNounAr: itemNounAr,
              activeFilterCount: _activeFilterCount,
              onCreate: onCreate,
              createLabelAr: createLabelAr,
              createIcon: createIcon,
              onAiCreate: onAiCreate,
              aiCreateLabelAr: aiCreateLabelAr,
              aiButtonColor: aiButtonColor ?? AC.purple,
            ),
            const SizedBox(width: 16),
            // ── MIDDLE: search bar with embedded filter/group/favorites ─
            // When searchPillMaxWidth is set the pill is capped and centred
            // inside the remaining row space — so the search sits visually
            // in the middle of the toolbar instead of hugging the start.
            Expanded(
              child: searchPillMaxWidth != null
                  ? Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: searchPillMaxWidth!),
                        child: _SearchBarWithMenu(
                          searchCtl: searchCtl,
                          searchFocus: searchFocus,
                          searchHint: searchHint,
                          onSearchChanged: onSearchChanged,
                          filterGroups: filterGroups,
                          groupOptions: groupOptions,
                          activeGroupKey: activeGroupKey,
                          onChangeGroup: onChangeGroup,
                          sortOptions: sortOptions,
                          activeSortKey: activeSortKey,
                          onChangeSort: onChangeSort,
                          favorites: favorites,
                          onSaveFavorite: onSaveFavorite,
                          onClearAllFilters: onClearAllFilters,
                          activeFilterCount: _activeFilterCount,
                        ),
                      ),
                    )
                  : _SearchBarWithMenu(
                      searchCtl: searchCtl,
                      searchFocus: searchFocus,
                      searchHint: searchHint,
                      onSearchChanged: onSearchChanged,
                      filterGroups: filterGroups,
                      groupOptions: groupOptions,
                      activeGroupKey: activeGroupKey,
                      onChangeGroup: onChangeGroup,
                      sortOptions: sortOptions,
                      activeSortKey: activeSortKey,
                      onChangeSort: onChangeSort,
                      favorites: favorites,
                      onSaveFavorite: onSaveFavorite,
                      onClearAllFilters: onClearAllFilters,
                      activeFilterCount: _activeFilterCount,
                    ),
            ),
            const SizedBox(width: 12),
            // ── LEFT: pagination · view-mode · help ─────────────────
            if (currentPage != null && pageSize != null)
              _PaginationCluster(
                currentPage: currentPage!,
                pageSize: pageSize!,
                totalItems: totalCount,
                onPrev: onPrevPage,
                onNext: onNextPage,
              ),
            if (currentPage != null && pageSize != null)
              const SizedBox(width: 6),
            _ViewModeMenu(
              modes: viewModes,
              activeKey: activeViewKey,
              onChange: onChangeView,
            ),
            if (shortcuts.isNotEmpty || tips.isNotEmpty) ...[
              const SizedBox(width: 4),
              _HelpButton(
                titleAr: titleAr,
                shortcuts: shortcuts,
                tips: tips,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RIGHT CLUSTER — title + counter + 2-button CTAs (stacked)
// ═══════════════════════════════════════════════════════════════════════

class _RightCluster extends StatelessWidget {
  final String titleAr;
  final IconData? titleIcon;
  final int totalCount;
  final int visibleCount;
  final String itemNounAr;
  final int activeFilterCount;
  final VoidCallback? onCreate;
  final String createLabelAr;
  final IconData createIcon;
  final VoidCallback? onAiCreate;
  final String aiCreateLabelAr;
  final Color aiButtonColor;

  const _RightCluster({
    required this.titleAr,
    required this.totalCount,
    required this.visibleCount,
    required this.itemNounAr,
    required this.activeFilterCount,
    required this.createLabelAr,
    required this.createIcon,
    required this.aiCreateLabelAr,
    required this.aiButtonColor,
    this.titleIcon,
    this.onCreate,
    this.onAiCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end, // RTL — right-align
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: optional pill icon + title + counter
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titleIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AC.gold.withValues(alpha: 0.22),
                      AC.gold.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AC.gold.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: AC.gold.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(titleIcon, color: AC.gold, size: 18),
              ),
              const SizedBox(width: 10),
            ],
            // Title + counter — natural width (no Flexible, never collapses).
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleAr,
                  softWrap: false,
                  maxLines: 1,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeFilterCount > 0
                      ? '$visibleCount / $totalCount'
                      : '$totalCount $itemNounAr',
                  maxLines: 1,
                  style: TextStyle(color: AC.ts, fontSize: 11, height: 1.1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: AI (purple filled) + جديد (gold outlined)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAiCreate != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: aiButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: onAiCreate,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(aiCreateLabelAr),
              ),
            if (onAiCreate != null && onCreate != null)
              const SizedBox(width: 8),
            if (onCreate != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AC.tp,
                  side: BorderSide(color: AC.gold.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: onCreate,
                icon: Icon(createIcon, size: 16, color: AC.gold),
                label: Text(createLabelAr),
              ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SEARCH BAR + integrated 3-column dropdown panel
// ═══════════════════════════════════════════════════════════════════════

class _SearchBarWithMenu extends StatelessWidget {
  final TextEditingController searchCtl;
  final FocusNode? searchFocus;
  final String searchHint;
  final VoidCallback? onSearchChanged;
  final List<ApexFilterGroup> filterGroups;
  final List<ApexGroupOption> groupOptions;
  final String activeGroupKey;
  final void Function(String) onChangeGroup;
  final List<ApexFilterOption> sortOptions;
  final String activeSortKey;
  final void Function(String) onChangeSort;
  final List<ApexFavorite> favorites;
  final VoidCallback? onSaveFavorite;
  final VoidCallback? onClearAllFilters;
  final int activeFilterCount;

  const _SearchBarWithMenu({
    required this.searchCtl,
    required this.searchHint,
    required this.filterGroups,
    required this.groupOptions,
    required this.activeGroupKey,
    required this.onChangeGroup,
    required this.activeFilterCount,
    this.searchFocus,
    this.onSearchChanged,
    this.sortOptions = const [],
    this.activeSortKey = '',
    this.onChangeSort = _noop,
    this.favorites = const [],
    this.onSaveFavorite,
    this.onClearAllFilters,
  });

  static void _noop(String _) {}

  // ─── Build the active-filter chip list (Odoo-style).
  // Each filter dimension with an active selection becomes one chip:
  //   • Multi-select with N options → "{label}: opt1 أو opt2 أو …"
  //   • Single-select (radio) → "{label}: chosen-value" (skip if 'all')
  // The active group-by also appears as a chip (different accent color).
  // X removes the whole filter dimension at once.
  List<Widget> _buildActiveChips() {
    final chips = <Widget>[];

    // Filter chips (gold-tinted)
    for (final group in filterGroups) {
      final activeOpts = group.options
          .where((o) => group.selected.contains(o.key))
          .toList();
      if (activeOpts.isEmpty) continue;
      // Skip "all" radio default
      if (!group.multi &&
          activeOpts.length == 1 &&
          activeOpts.first.key == 'all') {
        continue;
      }
      final valueLabels =
          activeOpts.map((o) => o.labelAr).join(' أو ');
      chips.add(_chip(
        labelAr: '${group.labelAr}: $valueLabels',
        accentColor: AC.gold,
        onRemove: () {
          if (group.multi) {
            for (final opt in List.of(activeOpts)) {
              if (group.selected.contains(opt.key)) {
                group.onToggle(opt.key);
              }
            }
          } else {
            // Radio default = 'all' — pick that key explicitly.
            group.onToggle('all');
          }
        },
      ));
    }

    // Group-by chip (info-blue tinted, different accent so user can
    // distinguish "filter" vs "group" at a glance)
    if (activeGroupKey.isNotEmpty && activeGroupKey != 'none') {
      final opt = groupOptions.firstWhere(
        (o) => o.key == activeGroupKey,
        orElse: () => ApexGroupOption(
            key: activeGroupKey, labelAr: activeGroupKey),
      );
      chips.add(_chip(
        labelAr: 'تجميع: ${opt.labelAr}',
        accentColor: AC.info,
        onRemove: () => onChangeGroup('none'),
      ));
    }

    return chips;
  }

  Widget _chip({
    required String labelAr,
    required Color accentColor,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // X on RTL start (visual RIGHT… wait — chips are *small* so
          // X belongs at the visual LEFT. Use Material's Chip convention:
          // delete-icon on the END of the label. In RTL → visual LEFT.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              labelAr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded,
                  size: 12, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = _buildActiveChips();
    final hasChips = chips.isNotEmpty;
    return Directionality(
      // Defensive: previous attempt set textDirection on the Row only
      // and the chevron still rendered on the visual LEFT — Material's
      // ButtonStyleButton / Container sometimes inserts a Directionality
      // up the tree that overrides the Row-level parameter. Wrapping in
      // an explicit Directionality wins.
      textDirection: TextDirection.rtl,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // Container auto-grows in height as chips wrap. Min 38 keeps the
        // search bar at the same height as before when no chips exist.
        constraints: const BoxConstraints(minHeight: 38),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activeFilterCount > 0
                ? AC.gold.withValues(alpha: 0.6)
                : AC.bdr,
            width: activeFilterCount > 0 ? 1.4 : 1.0,
          ),
        ),
        // Force RTL on this Row. Order:
        //   children[0] (search icon)   → visual RIGHT (RTL start)
        //   children[Expanded](TextField + chips wrap) → MIDDLE
        //   children[last] (chevron)     → visual LEFT (RTL end)
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Search icon at RTL start (visual RIGHT) ────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child:
                    Icon(Icons.search_rounded, color: AC.ts, size: 16),
              ),
              // ── Chips + search input (Wrap — grows vertically) ────
              Expanded(
                child: Wrap(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    // Filter / group chips
                    ...chips,
                    // The text input — fixed width inside Wrap so it
                    // sits inline with chips. Shrinks when chips are
                    // present so they all fit visually.
                    SizedBox(
                      width: hasChips ? 140 : 220,
                      child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: searchCtl,
                          builder: (_, v, __) {
                            return TextField(
                              controller: searchCtl,
                              focusNode: searchFocus,
                              textDirection: TextDirection.rtl,
                              onChanged: (_) => onSearchChanged?.call(),
                              style: TextStyle(
                                  color: AC.tp, fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                // Show hint only when no chips active —
                                // otherwise chips already explain context.
                                hintText: hasChips ? '' : searchHint,
                                hintStyle: TextStyle(
                                    color: AC.td, fontSize: 12.5),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 6),
                                suffixIcon: v.text.isEmpty
                                    ? null
                                    : InkWell(
                                        onTap: () {
                                          searchCtl.clear();
                                          onSearchChanged?.call();
                                        },
                                        child: Icon(
                                            Icons.close_rounded,
                                            color: AC.td,
                                            size: 16),
                                      ),
                                suffixIconConstraints:
                                    const BoxConstraints(
                                        minWidth: 26,
                                        minHeight: 26),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              // ── Chevron at RTL end (visual LEFT) ───────────────────
              _PanelOpener(
                filterGroups: filterGroups,
                groupOptions: groupOptions,
                activeGroupKey: activeGroupKey,
                onChangeGroup: onChangeGroup,
                sortOptions: sortOptions,
                activeSortKey: activeSortKey,
                onChangeSort: onChangeSort,
                favorites: favorites,
                onSaveFavorite: onSaveFavorite,
                onClearAllFilters: onClearAllFilters,
                activeFilterCount: activeFilterCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// The chevron+filter+group+favorites panel (3-column, Odoo-style)
// ─────────────────────────────────────────────────────────────────────────

class _PanelOpener extends StatefulWidget {
  final List<ApexFilterGroup> filterGroups;
  final List<ApexGroupOption> groupOptions;
  final String activeGroupKey;
  final void Function(String) onChangeGroup;
  final List<ApexFilterOption> sortOptions;
  final String activeSortKey;
  final void Function(String) onChangeSort;
  final List<ApexFavorite> favorites;
  final VoidCallback? onSaveFavorite;
  final VoidCallback? onClearAllFilters;
  final int activeFilterCount;

  const _PanelOpener({
    required this.filterGroups,
    required this.groupOptions,
    required this.activeGroupKey,
    required this.onChangeGroup,
    required this.sortOptions,
    required this.activeSortKey,
    required this.onChangeSort,
    required this.favorites,
    required this.onSaveFavorite,
    required this.onClearAllFilters,
    required this.activeFilterCount,
  });

  @override
  State<_PanelOpener> createState() => _PanelOpenerState();
}

class _PanelOpenerState extends State<_PanelOpener> {
  // Owned controller so we can call `close()` from inside menuChildren
  // (option-tap closes the panel). Lives as long as the widget.
  final MenuController _menuCtrl = MenuController();

  @override
  Widget build(BuildContext context) {
    // Use MenuAnchor instead of PopupMenuButton because Material's
    // PopupMenu hardcodes maxWidth to 280px (5 * _kMenuWidthStep) which
    // squeezes our 3-column panel into a narrow strip and forces text
    // to wrap awkwardly. MenuAnchor respects the child's width.
    return MenuAnchor(
      controller: _menuCtrl,
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AC.navy2),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AC.bdr),
        )),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        // No upper bound on width — let the panel size itself.
        maximumSize: WidgetStateProperty.all(Size.infinite),
      ),
      alignmentOffset: const Offset(0, 6),
      builder: (ctx, controller, _) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Tooltip(
            message: 'فلاتر · تجميع · مفضلات',
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.activeFilterCount > 0
                    ? AC.gold.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.expand_more_rounded,
                      color: widget.activeFilterCount > 0 ? AC.gold : AC.ts,
                      size: 18),
                  if (widget.activeFilterCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AC.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.activeFilterCount}',
                        style: TextStyle(
                          color: AC.navy,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          // 620px — compact panel. With filter sections collapsed by
          // default (accordion), height stays ~280-320px when nothing is
          // expanded. Each column gets ~205px, enough for typical
          // labels without wrapping.
          width: 620,
          child: _FilterPanel(
            filterGroups: widget.filterGroups,
            groupOptions: widget.groupOptions,
            activeGroupKey: widget.activeGroupKey,
            onChangeGroup: (k) {
              widget.onChangeGroup(k);
              _menuCtrl.close();
            },
            sortOptions: widget.sortOptions,
            activeSortKey: widget.activeSortKey,
            onChangeSort: (k) {
              widget.onChangeSort(k);
              _menuCtrl.close();
            },
            favorites: widget.favorites,
            onSaveFavorite: widget.onSaveFavorite == null
                ? null
                : () {
                    widget.onSaveFavorite!();
                    _menuCtrl.close();
                  },
            onClearAllFilters: widget.onClearAllFilters == null
                ? null
                : () {
                    widget.onClearAllFilters!();
                    _menuCtrl.close();
                  },
          ),
        ),
      ],
    );
  }
}

class _FilterPanel extends StatefulWidget {
  final List<ApexFilterGroup> filterGroups;
  final List<ApexGroupOption> groupOptions;
  final String activeGroupKey;
  final void Function(String) onChangeGroup;
  final List<ApexFilterOption> sortOptions;
  final String activeSortKey;
  final void Function(String) onChangeSort;
  final List<ApexFavorite> favorites;
  final VoidCallback? onSaveFavorite;
  final VoidCallback? onClearAllFilters;

  const _FilterPanel({
    required this.filterGroups,
    required this.groupOptions,
    required this.activeGroupKey,
    required this.onChangeGroup,
    required this.sortOptions,
    required this.activeSortKey,
    required this.onChangeSort,
    required this.favorites,
    required this.onSaveFavorite,
    required this.onClearAllFilters,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  // Which filter sections are expanded right now. Sections collapse by
  // default — keeps the panel short. Tapping a header toggles its body.
  final Set<String> _expanded = <String>{};

  // Convenience aliases so the rest of the file (which referenced bare
  // field names when this was a StatelessWidget) keeps reading naturally.
  List<ApexFilterGroup> get filterGroups => widget.filterGroups;
  List<ApexGroupOption> get groupOptions => widget.groupOptions;
  String get activeGroupKey => widget.activeGroupKey;
  void Function(String) get onChangeGroup => widget.onChangeGroup;
  List<ApexFilterOption> get sortOptions => widget.sortOptions;
  String get activeSortKey => widget.activeSortKey;
  void Function(String) get onChangeSort => widget.onChangeSort;
  List<ApexFavorite> get favorites => widget.favorites;
  VoidCallback? get onSaveFavorite => widget.onSaveFavorite;
  VoidCallback? get onClearAllFilters => widget.onClearAllFilters;

  bool _isOpen(String key) => _expanded.contains(key);

  void _toggle(String key) {
    setState(() {
      if (!_expanded.add(key)) _expanded.remove(key);
    });
  }

  /// Compact summary shown beside the section header when the section
  /// is collapsed. For radio (single-select) groups it shows the
  /// selected option's label; for multi-select it shows a count.
  String _summary(ApexFilterGroup g) {
    if (!g.multi) {
      if (g.selected.isEmpty) return '—';
      final key = g.selected.first;
      if (key == 'all') return 'الكل';
      final opt = g.options.firstWhere(
        (o) => o.key == key,
        orElse: () => ApexFilterOption(key: key, labelAr: key),
      );
      return opt.labelAr;
    }
    if (g.selected.isEmpty) return 'الكل';
    return '${g.selected.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
      // 580-640px — much more compact now that filter sections are
      // collapsed by default (Odoo-style accordion). Each column gets
      // ~205px, enough for typical Arabic labels without wrapping.
      constraints: const BoxConstraints(
          minWidth: 580, maxWidth: 640, maxHeight: 480),
      child: SingleChildScrollView(
        child: IntrinsicHeight(
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Column order matches Odoo's filter panel (in RTL):
            //   RIGHT  → عوامل التصفية   (filters — most-used)
            //   MIDDLE → تجميع حسب       (group-by + sort)
            //   LEFT   → المفضلات         (saved searches)
            // First child in a textDirection.rtl Row is visually rightmost.
            children: [
              // ── RIGHT: Filters (first child in RTL = right edge)
              Expanded(
                child: _column(
                  context,
                  iconColor: AC.purple,
                  icon: Icons.filter_alt_rounded,
                  title: 'عوامل التصفية',
                  child: _filtersList(),
                ),
              ),
              VerticalDivider(width: 1, color: AC.bdr),
              // ── MIDDLE: Group-by + Sort
              Expanded(
                child: _column(
                  context,
                  iconColor: AC.info,
                  icon: Icons.layers_rounded,
                  title: 'تجميع حسب',
                  child: _groupList(),
                ),
              ),
              VerticalDivider(width: 1, color: AC.bdr),
              // ── LEFT: Favorites (last child in RTL = left edge)
              Expanded(
                child: _column(
                  context,
                  iconColor: AC.gold,
                  icon: Icons.star_rounded,
                  title: 'المفضلات',
                  child: _favoritesList(),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _column(
    BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          // RTL header: icon on the LEFT-side accent, title on the RIGHT.
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AC.bdr),
        child,
      ],
    );
  }

  // ─── Reusable section divider (between named groups in any column).
  Widget _sectionDivider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 1,
        color: AC.bdr.withValues(alpha: 0.5),
      );

  // ─── Reusable section header (group name + icon, RTL).
  // Used by every dropdown column so spacing/typography stay identical.
  // Tighter vertical padding (6/3) keeps section labels close to their
  // content and avoids unnecessary whitespace stacking up.
  Widget _sectionHeader({
    required String labelAr,
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AC.ts, size: 11),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              labelAr,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AC.ts,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reusable footer action row (e.g. "+ إضافة فلتر مخصّص").
  // RTL: icon LEFT, label RIGHT. Used for all "Add custom" placeholders
  // and the destructive "Clear all" action.
  Widget _footerActionRow({
    required IconData icon,
    required String labelAr,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                labelAr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Disabled "+ إضافة" placeholder. Shows a SnackBar when tapped so the
  // user knows the custom-filter builder is on the roadmap. This row
  // mirrors Odoo's "+ Add custom filter" affordance — the slot exists
  // even before the builder lands so the menu stays visually complete.
  Widget _addCustomPlaceholder({
    required IconData icon,
    required String labelAr,
    required String comingSoonMessage,
  }) {
    return Builder(
      builder: (ctx) => _footerActionRow(
        icon: icon,
        labelAr: labelAr,
        color: AC.gold,
        onTap: () {
          Navigator.of(ctx).maybePop();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            backgroundColor: AC.navy3,
            content: Text(
              comingSoonMessage,
              style: TextStyle(color: AC.tp),
              textAlign: TextAlign.right,
            ),
          ));
        },
      ),
    );
  }

  Widget _filtersList() {
    final hasActive = onClearAllFilters != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Each filter dimension as a collapsible accordion ───────
          for (int i = 0; i < filterGroups.length; i++) ...[
            if (i > 0) _sectionDivider(),
            _expandableFilterSection(filterGroups[i]),
          ],
          // ── "Add custom filter" placeholder (Odoo pattern) ─────────
          _sectionDivider(),
          _addCustomPlaceholder(
            icon: Icons.add_rounded,
            labelAr: 'إضافة عامل تصفية مخصّص',
            comingSoonMessage:
                'منشئ الفلاتر المخصّصة قيد التطوير — سيتوفر قريباً',
          ),
          // ── "Clear all filters" — only when something is active ────
          if (hasActive) ...[
            _sectionDivider(),
            _footerActionRow(
              icon: Icons.clear_all_rounded,
              labelAr: 'مسح كل الفلاتر',
              color: AC.warn,
              onTap: onClearAllFilters!,
            ),
          ],
        ],
      ),
    );
  }

  /// Collapsible accordion entry for one filter dimension.
  /// Header row (always visible): chevron + icon + label + summary badge.
  /// Body (visible only when this section is expanded): the options list.
  ///
  /// Default: ALL sections start collapsed. The user opens what they need —
  /// keeps the panel compact even with 4-5 filter dimensions.
  Widget _expandableFilterSection(ApexFilterGroup g) {
    final open = _isOpen(g.labelAr);
    final summary = _summary(g);
    final hasSelection = g.multi
        ? g.selected.isNotEmpty
        : (g.selected.isNotEmpty && g.selected.first != 'all');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header (clickable) ─────────────────────────────────────
        InkWell(
          onTap: () => _toggle(g.labelAr),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                // Chevron — rotates 90° when collapsed (points right)
                RotatedBox(
                  quarterTurns: open ? 0 : -1,
                  child: Icon(Icons.expand_more_rounded,
                      color: AC.ts, size: 16),
                ),
                const SizedBox(width: 6),
                if (g.icon != null) ...[
                  Icon(g.icon, color: AC.purple, size: 13),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    g.labelAr,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AC.tp,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Selection summary badge — shows current value (radio)
                // or count (multi). Hidden if section is "all" / empty.
                if (hasSelection) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AC.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AC.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Body (expanded options) ────────────────────────────────
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in g.options) _filterRow(g, opt),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filterRow(ApexFilterGroup g, ApexFilterOption o) {
    final selected = g.selected.contains(o.key);
    final tickIcon = g.multi
        ? (selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded)
        : (selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded);
    return InkWell(
      onTap: () => g.onToggle(o.key),
      child: Padding(
        // Indented from the section header (24px) so options visually
        // belong to their parent section. Vertical pad tightened to 4.
        padding: const EdgeInsets.fromLTRB(24, 4, 10, 4),
        // RTL row: check on the LEFT, optional type-icon next to it,
        // text label fills the rest with right alignment.
        child: Row(
          children: [
            Icon(tickIcon,
                color: selected ? (o.color ?? AC.gold) : AC.td, size: 13),
            const SizedBox(width: 6),
            if (o.icon != null) ...[
              Icon(o.icon, color: o.color ?? AC.ts, size: 12),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                o.labelAr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: selected ? AC.gold : AC.tp,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section 1: Group dimensions ────────────────────────────
          _sectionHeader(
            labelAr: 'المجموعات',
            icon: Icons.layers_rounded,
            iconColor: AC.info,
          ),
          for (final o in groupOptions)
            InkWell(
              onTap: () => onChangeGroup(o.key),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                // RTL row: radio left, optional icon, label right.
                child: Row(
                  children: [
                    Icon(
                      o.key == activeGroupKey
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: o.key == activeGroupKey ? AC.gold : AC.td,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    if (o.icon != null) ...[
                      Icon(o.icon,
                          color: o.key == activeGroupKey ? AC.gold : AC.ts,
                          size: 13),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        o.labelAr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: o.key == activeGroupKey ? AC.gold : AC.tp,
                          fontSize: 12.5,
                          fontWeight: o.key == activeGroupKey
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Section 2: Sort (when provided) ────────────────────────
          if (sortOptions.isNotEmpty) ...[
            _sectionDivider(),
            _sectionHeader(
              labelAr: 'الترتيب',
              icon: Icons.sort_rounded,
              iconColor: AC.info,
            ),
            for (final o in sortOptions)
              InkWell(
                onTap: () => onChangeSort(o.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  // RTL row: radio left, label right.
                  child: Row(
                    children: [
                      Icon(
                        o.key == activeSortKey
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: o.key == activeSortKey ? AC.gold : AC.td,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.labelAr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: o.key == activeSortKey ? AC.gold : AC.tp,
                            fontSize: 12.5,
                            fontWeight: o.key == activeSortKey
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          // ── Footer: "Add custom group" placeholder ─────────────────
          _sectionDivider(),
          _addCustomPlaceholder(
            icon: Icons.add_rounded,
            labelAr: 'إضافة مجموعة مخصّصة',
            comingSoonMessage:
                'منشئ التجميع المخصّص قيد التطوير — سيتوفر قريباً',
          ),
        ],
      ),
    );
  }

  Widget _favoritesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section: Saved searches ────────────────────────────────
          _sectionHeader(
            labelAr: 'البحوث المحفوظة',
            icon: Icons.bookmark_rounded,
            iconColor: AC.gold,
          ),
          if (favorites.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.bookmarks_outlined,
                      color: AC.td, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    'لا يوجد بحث محفوظ',
                    style: TextStyle(color: AC.td, fontSize: 11.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اضبط الفلتر/التجميع ثم احفظه',
                    style: TextStyle(color: AC.td, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final f in favorites)
              InkWell(
                onTap: f.onApply,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  // RTL row: delete-icon LEFT, dot, favorite name RIGHT.
                  child: Row(
                    children: [
                      if (f.onDelete != null)
                        InkWell(
                          onTap: f.onDelete,
                          child: Icon(Icons.delete_outline_rounded,
                              color: AC.td, size: 14),
                        )
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      Icon(Icons.circle, color: AC.gold, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.labelAr,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AC.tp, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          // ── Footer: Save current search action ─────────────────────
          if (onSaveFavorite != null) ...[
            _sectionDivider(),
            _footerActionRow(
              icon: Icons.bookmark_add_rounded,
              labelAr: 'حفظ البحث الحالي',
              color: AC.gold,
              onTap: onSaveFavorite!,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PAGINATION CLUSTER — "‹ 1-32 / 100 ›"
// ═══════════════════════════════════════════════════════════════════════

class _PaginationCluster extends StatelessWidget {
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _PaginationCluster({
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final from = totalItems == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final to = (currentPage * pageSize).clamp(0, totalItems);
    final canPrev = onPrev != null && currentPage > 1;
    final canNext = onNext != null && to < totalItems;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canNext ? onNext : null,
            icon: Icon(Icons.chevron_left_rounded,
                color: canNext ? AC.tp : AC.td, size: 18),
            tooltip: 'التالي',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$from-$to / $totalItems',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: canPrev ? onPrev : null,
            icon: Icon(Icons.chevron_right_rounded,
                color: canPrev ? AC.tp : AC.td, size: 18),
            tooltip: 'السابق',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  VIEW-MODE MENU — List / Cards / Kanban / Activity
// ═══════════════════════════════════════════════════════════════════════

class _ViewModeMenu extends StatelessWidget {
  final List<ApexViewMode> modes;
  final String activeKey;
  final void Function(String) onChange;
  const _ViewModeMenu({
    required this.modes,
    required this.activeKey,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final active = modes.firstWhere(
      (m) => m.key == activeKey,
      orElse: () => modes.isNotEmpty
          ? modes.first
          : const ApexViewMode(
              key: 'list',
              labelAr: 'قائمة',
              icon: Icons.view_list_rounded,
            ),
    );
    return PopupMenuButton<String>(
      tooltip: 'وضع العرض',
      offset: const Offset(0, 40),
      color: AC.navy2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AC.bdr),
      ),
      onSelected: onChange,
      itemBuilder: (ctx) => [
        for (final m in modes)
          PopupMenuItem<String>(
            value: m.key,
            child: Directionality(
              textDirection: TextDirection.rtl,
              // RTL row: mode icon LEFT, label text RIGHT, optional check
              // mark on the far LEFT (next to mode icon).
              child: Row(
                children: [
                  Icon(m.icon,
                      color: m.key == activeKey ? AC.gold : AC.ts, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.labelAr,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: m.key == activeKey ? AC.gold : AC.tp,
                        fontSize: 12.5,
                        fontWeight: m.key == activeKey
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (m.key == activeKey) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_rounded, color: AC.gold, size: 14),
                  ],
                ],
              ),
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active.icon, color: AC.tp, size: 16),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: AC.ts, size: 14),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HELP BUTTON — opens shortcuts dialog
// ═══════════════════════════════════════════════════════════════════════

class _HelpButton extends StatelessWidget {
  final String titleAr;
  final List<ApexShortcut> shortcuts;
  final List<ApexTip> tips;
  const _HelpButton({
    required this.titleAr,
    required this.shortcuts,
    this.tips = const [],
  });

  void _show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.navy2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AC.bdr),
          ),
          title: Row(children: [
            Icon(Icons.help_outline_rounded, color: AC.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('مساعدة — $titleAr',
                  style: TextStyle(
                    color: AC.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Tips section (when provided) ─────────────────
                  if (tips.isNotEmpty) ...[
                    _sectionLabel('نصائح وممارسات',
                        icon: Icons.lightbulb_outline_rounded,
                        iconColor: AC.purple),
                    const SizedBox(height: 4),
                    for (final t in tips) _tipRow(t),
                    const SizedBox(height: 12),
                  ],
                  // ── Shortcuts section ────────────────────────────
                  if (shortcuts.isNotEmpty) ...[
                    _sectionLabel('اختصارات لوحة المفاتيح',
                        icon: Icons.keyboard_rounded, iconColor: AC.gold),
                    const SizedBox(height: 4),
                    for (final s in shortcuts) _shortcutRow(s.key, s.labelAr),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق',
                  style: TextStyle(
                      color: AC.gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label,
      {required IconData icon, required Color iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: AC.ts,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            )),
      ]),
    );
  }

  Widget _tipRow(ApexTip t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AC.purple.withValues(alpha: 0.06),
          border: Border(
              right: BorderSide(color: AC.purple, width: 3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(t.icon, color: AC.purple, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.titleAr,
                      style: TextStyle(
                        color: AC.tp,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(t.bodyAr,
                      style: TextStyle(
                        color: AC.ts,
                        fontSize: 11.5,
                        height: 1.5,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcutRow(String k, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AC.navy3,
            border: Border.all(color: AC.bdr),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(k,
              style: TextStyle(
                color: AC.tp,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: AC.tp, fontSize: 13)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A4: Semantics so screen readers announce this control as
    // "Help and shortcuts button".
    return Semantics(
      label: 'مساعدة واختصارات',
      button: true,
      child: Tooltip(
        message: 'مساعدة',
        child: IconButton(
          onPressed: () => _show(context),
          icon: Icon(Icons.help_outline_rounded, color: AC.ts, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: AC.navy3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AC.bdr),
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }
}

// Keep the `services` import used (HardwareKeyboard hooks live in
// caller screens; importing here keeps the public API friendly).
// ignore: unused_element
const _kKeepServicesImportAlive = LogicalKeyboardKey.escape;
