/// APEX Tabs Shell — alternative top-down navigation chrome.
///
/// Layout from top to bottom:
///   - 56px Top bar     (logo, breadcrumb, search, actions)
///   - 50px Tabs strip  (9 apps as horizontal tabs; the active tab "rises"
///                       and merges seamlessly into the context bar below)
///   - 44px Context bar (per-app quick actions for the most-used categories)
///   -      Content area (whatever the route renders)
///
/// Coexists with [ApexMagneticShell] — the user can flip between them at
/// runtime via the [ApexShellMode] toggle. This file deliberately reuses
/// the same taxonomy/route definitions imported from the magnetic shell so
/// behaviour stays identical regardless of which chrome is active.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'apex_magnetic_shell.dart'
    show
        ApexAppEntry,
        ApexShellMode,
        ApexSubItemRef,
        kApexApps,
        showApexQuickSearch;
import 'apex_responsive.dart';
import 'theme.dart';

const double _kTopBarHeight = 56.0;
const double _kTabsHeight = 50.0;
const double _kContextHeight = 44.0;
const double _kTabRiseOverlap = 6.0; // active tab pokes into context bar

class ApexTabsShell extends StatefulWidget {
  final Widget child;
  const ApexTabsShell({super.key, required this.child});

  @override
  State<ApexTabsShell> createState() => _ApexTabsShellState();
}

class _ApexTabsShellState extends State<ApexTabsShell> {
  final ScrollController _tabsScroll = ScrollController();

  String _currentRoute() {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return '/';
    }
  }

  ApexAppEntry? _activeApp(String current) {
    for (final app in kApexApps) {
      if (current == app.homeRoute ||
          current.startsWith('${app.routePrefix}/')) {
        return app;
      }
    }
    return kApexApps.first;
  }

  void _go(String route) => context.go(route);

  void _showQuickSearch() {
    showApexQuickSearch(context);
  }

  @override
  void dispose() {
    _tabsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ApexResponsive.isMobile(context);
    final current = _currentRoute();
    final activeApp = _activeApp(current);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showQuickSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showQuickSearch,
      },
      child: Focus(
        autofocus: true,
        child: Column(children: [
          _TopBar(
            activeApp: activeApp,
            current: current,
            onSearch: _showQuickSearch,
          ),
          // ── Tabs + context bar wrapped together so the rising tab can
          // bleed into the context bar visually.
          if (!isMobile)
            _TabsAndContext(
              activeApp: activeApp,
              current: current,
              tabsScroll: _tabsScroll,
              onTabTap: (app) => _go(app.homeRoute),
              onContextTap: _go,
            ),
          // ── Content fills the remaining viewport.
          Expanded(child: widget.child),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Top bar (56px)
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final ApexAppEntry? activeApp;
  final String current;
  final VoidCallback onSearch;
  const _TopBar({
    required this.activeApp,
    required this.current,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeApp?.accent ?? AC.gold;
    return Container(
      height: _kTopBarHeight,
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(
            bottom: BorderSide(
                color: AC.bdr.withValues(alpha: 0.6), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
        child: Row(children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold, AC.goldLight]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AC.gold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.bolt_rounded, color: AC.btnFg, size: 18),
          ),
          const SizedBox(width: 10),
          Text('APEX',
              style: TextStyle(
                color: AC.tp,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              )),
          const SizedBox(width: 14),
          Container(
              width: 1, height: 22, color: AC.bdr.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          // Breadcrumb / active app name
          if (activeApp != null) ...[
            Icon(activeApp!.icon, color: accent, size: 16),
            const SizedBox(width: 6),
            Text(activeApp!.label,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
          const Spacer(),
          // Search
          _TopBarButton(
            icon: Icons.search_rounded,
            tooltip: 'بحث سريع (Ctrl+K)',
            onTap: onSearch,
          ),
          _TopBarButton(
            icon: Icons.notifications_outlined,
            tooltip: 'الإشعارات',
            badge: '3',
            onTap: () => context.go('/notifications'),
          ),
          _TopBarButton(
            icon: Icons.science_outlined,
            tooltip: 'مختبر الابتكار',
            onTap: () => context.go('/lab'),
          ),
          // Shell toggle
          _TopBarButton(
            icon: Icons.swap_horiz_rounded,
            tooltip: 'تبديل: قائمة جانبية',
            onTap: () => ApexShellMode.useTabs.value = false,
          ),
          const SizedBox(width: 8),
          _UserMenu(),
        ]),
      ),
    );
  }
}

class _TopBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final String? badge;
  final VoidCallback onTap;
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hover
                  ? AC.gold.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(widget.icon,
                  color: _hover ? AC.gold : AC.tp, size: 18),
              if (widget.badge != null)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AC.err,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AC.navy2, width: 1.2),
                    ),
                    child: Text(widget.badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.0)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/account/sessions'),
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 6),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AC.gold, width: 1.5),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: AC.gold.withValues(alpha: 0.18),
          child: Icon(Icons.person_rounded, color: AC.gold, size: 16),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tabs strip (50px) + Context bar (44px) — drawn together so the active
// tab can rise and fuse with the context bar.
// ═══════════════════════════════════════════════════════════════════════════

class _TabsAndContext extends StatelessWidget {
  final ApexAppEntry? activeApp;
  final String current;
  final ScrollController tabsScroll;
  final void Function(ApexAppEntry app) onTabTap;
  final void Function(String route) onContextTap;

  const _TabsAndContext({
    required this.activeApp,
    required this.current,
    required this.tabsScroll,
    required this.onTabTap,
    required this.onContextTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeApp?.accent ?? AC.gold;
    return SizedBox(
      height: _kTabsHeight + _kContextHeight,
      child: Stack(children: [
        // Context bar (full width) sits at the bottom — its background is
        // tinted by the active app's accent so the rising tab merges into
        // it as one cohesive surface.
        Positioned(
          left: 0, right: 0, bottom: 0, height: _kContextHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  accent.withValues(alpha: 0.10), AC.navy2),
              border: Border(
                  bottom: BorderSide(
                      color: AC.bdr.withValues(alpha: 0.5))),
            ),
            child: _ContextBar(
              activeApp: activeApp,
              current: current,
              onTap: onContextTap,
            ),
          ),
        ),
        // Tabs strip on top
        Positioned(
          left: 0, right: 0, top: 0, height: _kTabsHeight,
          child: Container(
            color: AC.navy3,
            child: Row(children: [
              const SizedBox(width: 14),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView(
                    controller: tabsScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 6),
                    children: [
                      for (final app in kApexApps)
                        _AppTab(
                          app: app,
                          active: app.id == activeApp?.id,
                          onTap: () => onTabTap(app),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _AppTab extends StatefulWidget {
  final ApexAppEntry app;
  final bool active;
  final VoidCallback onTap;
  const _AppTab({
    required this.app,
    required this.active,
    required this.onTap,
  });

  @override
  State<_AppTab> createState() => _AppTabState();
}

class _AppTabState extends State<_AppTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.app.accent;
    final tabHeight = widget.active
        ? _kTabsHeight - 6 + _kTabRiseOverlap // rises into context bar
        : _kTabsHeight - 14;
    final tabBg = widget.active
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), AC.navy2)
        : (_hover ? accent.withValues(alpha: 0.06) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          height: tabHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tabBg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10)),
            border: widget.active
                ? Border(
                    top: BorderSide(color: accent, width: 2.5),
                    left: BorderSide(
                        color: AC.bdr.withValues(alpha: 0.6)),
                    right: BorderSide(
                        color: AC.bdr.withValues(alpha: 0.6)),
                  )
                : null,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, -3),
                    ),
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.app.icon,
                color: widget.active || _hover ? accent : AC.tp,
                size: 16),
            const SizedBox(width: 8),
            Text(
              widget.app.label,
              style: TextStyle(
                color: widget.active || _hover ? accent : AC.tp,
                fontSize: 13,
                fontWeight:
                    widget.active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Context bar (44px) — quick-actions for the active app
// ═══════════════════════════════════════════════════════════════════════════

class _ContextBar extends StatelessWidget {
  final ApexAppEntry? activeApp;
  final String current;
  final void Function(String route) onTap;
  const _ContextBar({
    required this.activeApp,
    required this.current,
    required this.onTap,
  });

  bool _isItemActive(String route) {
    if (route == current) return true;
    if (route.length > 3 && current.startsWith('$route/')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final app = activeApp;
    if (app == null) return const SizedBox.shrink();
    // Flatten the app's categories into a single horizontal row of items.
    // For wider screens we show all leaves; on narrower viewports the row
    // scrolls horizontally.
    final items = [
      for (final cat in app.categories) ...cat.items,
    ];
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final it in items)
            _ContextChip(
              item: it,
              accent: app.accent,
              active: _isItemActive(it.route),
              onTap: () => onTap(it.route),
            ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatefulWidget {
  final ApexSubItemRef item;
  final Color accent;
  final bool active;
  final VoidCallback onTap;
  const _ContextChip({
    required this.item,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ContextChip> createState() => _ContextChipState();
}

class _ContextChipState extends State<_ContextChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsetsDirectional.only(end: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.accent.withValues(alpha: 0.18)
                : (_hover
                    ? widget.accent.withValues(alpha: 0.08)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.active
                  ? widget.accent.withValues(alpha: 0.55)
                  : AC.bdr.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.item.icon,
                color: highlighted ? widget.accent : AC.tp, size: 13),
            const SizedBox(width: 6),
            Text(widget.item.label,
                style: TextStyle(
                  color: highlighted ? widget.accent : AC.tp,
                  fontSize: 11.5,
                  fontWeight:
                      widget.active ? FontWeight.w700 : FontWeight.w500,
                )),
            if (widget.item.badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (widget.item.badgeColor ?? widget.accent)
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.item.badge!,
                    style: TextStyle(
                      color: widget.item.badgeColor ?? widget.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    )),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// Simple wrapper around ImageFilter (kept here so this file's imports stay
// self-explanatory and the helper isn't shared globally).
// ignore: unused_element
ImageFilter _blur(double s) => ImageFilter.blur(sigmaX: s, sigmaY: s);
