/// @deprecated V4 module — kept temporarily because 6 screens still depend on
/// `apex_screen_host.dart` (the only file with external users). The other
/// widgets here are an internally-consistent dead zone (0 external users) but
/// removing them piecemeal would break `apex_launchpad`, `apex_sub_module_shell`,
/// `apex_command_palette`, and `apex_tab_bar` which all import `v4_groups.dart`.
///
/// Migration to V5 is tracked in G-A2.1 — see
/// `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md`. Do NOT add new usages.
/// APEX V4 — Sub-module shell (Wave 1.5).
///
/// Three-region layout for every sub-module screen:
///
///   ┌────────────────────────────────────────────────────────┐
///   │  Group ribbon  │  Breadcrumb  │  Back to Launchpad ▸   │
///   ├──────────┬─────────────────────────────────────────────┤
///   │          │  Top tabs (up to 5)        [More ▾]         │
///   │ Sidebar  ├─────────────────────────────────────────────┤
///   │ 11 sub-  │                                             │
///   │ modules  │      Active screen content                  │
///   │          │                                             │
///   └──────────┴─────────────────────────────────────────────┘
///
/// The shell is dumb — it receives the group + selected sub-module +
/// active screen and delegates rendering to the provided builder.
/// Routing + state live in the GoRouter layer (see v4_routes.dart).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_tokens.dart';
import '../theme.dart';
import 'apex_command_palette.dart';
import 'apex_screen_host.dart';
import 'apex_tab_bar.dart';
import 'v4_groups.dart';

typedef V4ScreenBuilder = Widget Function(
    BuildContext context, V4Screen screen);

class ApexSubModuleShell extends StatelessWidget {
  final V4ModuleGroup group;
  final V4SubModule subModule;
  final V4Screen activeScreen;

  /// Rendered inside [ApexScreenHost]. If the builder returns a state
  /// host itself, it takes over; otherwise the shell wraps the child
  /// in a default ready-state host.
  final V4ScreenBuilder screenBuilder;

  const ApexSubModuleShell({
    super.key,
    required this.group,
    required this.subModule,
    required this.activeScreen,
    required this.screenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return ApexCommandPaletteHost(
      child: Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          _GroupRibbon(group: group, subModule: subModule),
          Expanded(
            child: Row(
              children: [
                if (!isNarrow) _Sidebar(group: group, selected: subModule),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ApexTabBar(
                        screens: subModule.visibleTabs,
                        overflow: subModule.overflow,
                        activeScreenId: activeScreen.id,
                        accentColor: group.color,
                        onSelect: (scr) => context.go(
                          '/app/${group.id}/${subModule.id}/${_screenSlug(scr.id)}',
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: AC.navy,
                          child: screenBuilder(context, activeScreen),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isNarrow
          ? Drawer(
              backgroundColor: AC.navy2,
              child: _Sidebar(
                group: group,
                selected: subModule,
                fromDrawer: true,
              ),
            )
          : null,
      ),
    );
  }

  /// Convert `erp-sales-customers` → `customers` (the part after the
  /// second hyphen). Keeps URLs short while screen ids remain stable.
  static String _screenSlug(ScreenId id) {
    final parts = id.split('-');
    return parts.length > 2 ? parts.sublist(2).join('-') : id;
  }
}

class _GroupRibbon extends StatelessWidget {
  final V4ModuleGroup group;
  final V4SubModule subModule;
  const _GroupRibbon({required this.group, required this.subModule});

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    decoration: BoxDecoration(
      color: AC.navy2,
      border: Border(
        bottom: BorderSide(color: AC.navy3),
        top: BorderSide(color: group.color, width: 3),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'العودة إلى الصفحة الرئيسية',
          icon: Icon(Icons.apps, color: AC.ts),
          onPressed: () => context.go('/app'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(group.icon, color: group.color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          group.labelAr,
          style: TextStyle(
            color: AC.tp,
            fontSize: AppFontSize.base,
            fontWeight: FontWeight.w700,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(Icons.chevron_left, color: AC.ts, size: 16),
        ),
        Expanded(
          child: Text(
            subModule.labelAr,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AC.ts,
              fontSize: AppFontSize.base,
            ),
          ),
        ),
        // Tappable search opens the command palette; keyboard users
        // get the same overlay via Ctrl+K via ApexCommandPaletteHost.
        Tooltip(
          message: 'بحث سريع — Ctrl+K',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => showApexCommandPalette(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AC.ts, size: 18),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AC.navy3,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      'Ctrl K',
                      style: TextStyle(
                        color: AC.ts,
                        fontSize: AppFontSize.xs,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  final V4ModuleGroup group;
  final V4SubModule selected;
  final bool fromDrawer;

  const _Sidebar({
    required this.group,
    required this.selected,
    this.fromDrawer = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: fromDrawer ? null : 260,
    color: AC.navy2,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: group.subModules.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 2),
      itemBuilder: (ctx, i) {
        final s = group.subModules[i];
        final isSelected = s.id == selected.id;
        return InkWell(
          onTap: () {
            if (fromDrawer) Navigator.of(ctx).pop();
            final first = s.visibleTabs.isNotEmpty
                ? s.visibleTabs.first.id
                : (s.overflow.isNotEmpty ? s.overflow.first.id : null);
            if (first != null) {
              ctx.go('/app/${group.id}/${s.id}/${_slug(first)}');
            } else {
              ctx.go('/app/${group.id}/${s.id}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? group.color.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border(
                right: BorderSide(
                  color: isSelected ? group.color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  s.icon,
                  color: isSelected ? group.color : AC.ts,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    s.labelAr,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AC.tp : AC.ts,
                      fontSize: AppFontSize.base,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  static String _slug(ScreenId id) {
    final parts = id.split('-');
    return parts.length > 2 ? parts.sublist(2).join('-') : id;
  }
}
