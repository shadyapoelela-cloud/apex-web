/// APEX Platform — Shell Layout
/// Combines: top bar + collapsible sidebar + breadcrumb + content area
/// Pennylane/QuickBooks hybrid pattern
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'session.dart' show S;
import 'apex_sidebar.dart';
import '../main.dart' show ApexLogo, ApexIconButton, ApexGlowFAB, ApexSearch;

// ═══════════════════════════════════════════════════════════════
// ApexShell — Main app shell with sidebar navigation
// ═══════════════════════════════════════════════════════════════

class ApexShell extends ConsumerStatefulWidget {
  final Widget child;
  final String? activeItemId;
  final List<String> breadcrumb;

  const ApexShell({
    super.key,
    required this.child,
    this.activeItemId,
    this.breadcrumb = const [],
  });

  @override
  ConsumerState<ApexShell> createState() => _ApexShellState();
}

class _ApexShellState extends ConsumerState<ApexShell> {
  bool _sidebarCollapsed = false;
  List _cl = [];
  List<String> _activeClients = [];
  List _notifs = [];
  int _hovUserSection = 0;
  double _fabX = 20;
  double _fabY = 100;

  final _bizKey = GlobalKey();
  final _notifKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (S.token != null) {
        _loadData();
      }
    });
  }

  void _loadData() {
    // Import ApiService dynamically to avoid circular deps
    try {
      _loadClients();
      _loadNotifs();
    } catch (_) {}
  }

  Future<void> _loadClients() async {
    try {
      // Using dynamic import pattern compatible with the existing ApiService
      final dynamic apiService = _getApiService();
      if (apiService == null) return;
      final r = await apiService.listClients();
      if (r.success && mounted) {
        final d = r.data;
        setState(() => _cl = d is List ? d : []);
      }
    } catch (_) {}
  }

  Future<void> _loadNotifs() async {
    try {
      final dynamic apiService = _getApiService();
      if (apiService == null) return;
      final r = await apiService.getNotifications();
      if (r.success && mounted) {
        final d = r.data;
        setState(() => _notifs = d is List ? d : []);
      }
    } catch (_) {}
  }

  dynamic _getApiService() {
    // Will be wired in integration step
    return null;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Cmd+K / Ctrl+K handler
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyK &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
      ApexCommandPalette.show(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AC.navy,
        body: Column(children: [
          // ── Top bar ──
          _buildTopBar(),
          // ── Body: sidebar + content ──
          Expanded(
            child: Row(
              textDirection: TextDirection.rtl, // RTL: sidebar on right
              children: [
                // Sidebar
                ApexSidebar(
                  activeItemId: widget.activeItemId,
                  collapsed: _sidebarCollapsed,
                  onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  onItemSelected: (id) {
                    // Navigation handled by sidebar item routes
                  },
                ),
                // Content area
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Breadcrumb
                          if (widget.breadcrumb.isNotEmpty)
                            ApexBreadcrumb(path: widget.breadcrumb),
                          // Page content
                          Expanded(child: widget.child),
                        ],
                      ),
                      // Copilot FAB
                      Positioned(
                        left: _fabX, bottom: _fabY,
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(() {
                            _fabX = (_fabX + d.delta.dx).clamp(0, 300);
                            _fabY = (_fabY - d.delta.dy).clamp(0, 600);
                          }),
                          child: ApexGlowFAB(
                            icon: Icons.smart_toy,
                            tooltip: 'Apex Copilot \u2014 \u0627\u0644\u0645\u0633\u0627\u0639\u062f \u0627\u0644\u0630\u0643\u064a',
                            onPressed: () => context.go('/copilot'),
                          ),
                        ),
                      ),
                      // Quick action button
                      Positioned(
                        left: _fabX, bottom: _fabY + 64,
                        child: const ApexQuickActionButton(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Top bar (reused from MainNav) ──
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.navy2, AC.navy2.withValues(alpha: 0.95)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.12), width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        ApexLogo(fontSize: 18, onTap: () => context.go('/home')),
        _appBarDivider(),
        // Search + Client switcher + Notifications
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AC.navy3.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // Global search
            ApexIconButton(
              icon: Icons.search,
              tooltip: '\u0628\u062d\u062b \u0633\u0631\u064a\u0639 (Ctrl+K)',
              onPressed: () => ApexCommandPalette.show(context),
            ),
            // Client switcher
            Builder(key: _bizKey, builder: (btnCtx) => ApexIconButton(
              icon: Icons.business,
              tooltip: '\u062a\u0628\u062f\u064a\u0644 \u0627\u0644\u0639\u0645\u064a\u0644 \u0627\u0644\u0646\u0634\u0637',
              showBadge: _activeClients.isNotEmpty,
              badgeColor: AC.ok,
              onPressed: () => _showClientMenu(btnCtx),
            )),
            // Notifications
            Builder(key: _notifKey, builder: (notifCtx) => ApexIconButton(
              icon: Icons.notifications_outlined,
              tooltip: '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a',
              showBadge: _notifs.any((n) => n['is_read'] != true),
              badgeColor: AC.gold,
              onPressed: () => _showNotifMenu(notifCtx),
            )),
          ]),
        ),
        _appBarDivider(),
        // Keyboard shortcut hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AC.navy3.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AC.bdr.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.keyboard_command_key, color: AC.td, size: 12),
            const SizedBox(width: 2),
            Text('K', style: TextStyle(color: AC.td, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Spacer(),
        // User section
        _buildUserSection(),
      ]),
    );
  }

  Widget _appBarDivider() => Container(
    width: 1, height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AC.bdr.withValues(alpha: 0.0), AC.bdr.withValues(alpha: 0.4), AC.bdr.withValues(alpha: 0.0)],
      ),
    ),
  );

  Widget _buildUserSection() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovUserSection = 1),
      onExit: (_) => setState(() => _hovUserSection = 0),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/settings'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovUserSection == 1 ? AC.gold.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovUserSection == 1 ? AC.gold.withValues(alpha: 0.15) : Colors.transparent,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                S.dname?.isNotEmpty == true ? S.dname! : (S.uname ?? 'User'),
                style: TextStyle(
                  color: _hovUserSection == 1 ? AC.gold : AC.tp.withValues(alpha: 0.85),
                  fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _activeClients.isEmpty
                    ? '\u0644\u0645 \u064a\u062a\u0645 \u0627\u062e\u062a\u064a\u0627\u0631 \u0639\u0645\u064a\u0644'
                    : _activeClients.join(' , '),
                style: TextStyle(color: AC.ts.withValues(alpha: 0.7), fontSize: 10),
              ),
            ]),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: _hovUserSection == 1 ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(
                (S.dname?.isNotEmpty == true ? S.dname! : (S.uname ?? 'U'))[0].toUpperCase(),
                style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  void _showClientMenu(BuildContext btnCtx) {
    final RenderBox btn = btnCtx.findRenderObject() as RenderBox;
    final Offset pos = btn.localToGlobal(Offset.zero);
    final Size sz = btn.size;
    showMenu<String>(
      context: context,
      color: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AC.gold, width: 0.5)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 250, 0),
      items: _cl.isEmpty
          ? [PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0645\u0644\u0627\u0621', style: TextStyle(color: AC.ts, fontSize: 12)))]
          : _cl.take(10).map((cl) {
              final name = (cl['name_ar'] ?? cl['name'] ?? '') as String;
              final sel = _activeClients.contains(name);
              return PopupMenuItem<String>(
                value: name, height: 40,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(name, style: TextStyle(color: sel ? AC.gold : AC.tp, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  const SizedBox(width: 8),
                  Icon(sel ? Icons.check_box : Icons.check_box_outline_blank, color: sel ? AC.gold : AC.ts, size: 18),
                ]),
              );
            }).toList(),
    ).then((v) {
      if (v != null && v.isNotEmpty) {
        setState(() {
          if (_activeClients.contains(v)) _activeClients.remove(v); else _activeClients.add(v);
        });
      }
    });
  }

  void _showNotifMenu(BuildContext notifCtx) {
    final RenderBox btn = notifCtx.findRenderObject() as RenderBox;
    final Offset pos = btn.localToGlobal(Offset.zero);
    final Size sz = btn.size;
    showMenu<String>(
      context: context,
      color: AC.navy2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AC.gold, width: 0.5)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 300, 0),
      items: _notifs.isEmpty
          ? [PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0625\u0634\u0639\u0627\u0631\u0627\u062a', style: TextStyle(color: AC.ts, fontSize: 12)))]
          : [
              ..._notifs.take(8).map((n) {
                final unread = n['is_read'] != true;
                final title = (n['title'] ?? n['message'] ?? '') as String;
                return PopupMenuItem<String>(
                  value: n['id']?.toString() ?? '', height: 44,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Expanded(child: Text(title, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: unread ? AC.gold : AC.tp, fontSize: 11, fontWeight: unread ? FontWeight.bold : FontWeight.normal))),
                    const SizedBox(width: 8),
                    Icon(unread ? Icons.circle : Icons.circle_outlined, color: unread ? AC.gold : AC.ts, size: 8),
                  ]),
                );
              }),
              PopupMenuItem<String>(value: 'all', height: 36,
                child: Center(child: Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold)))),
            ],
    ).then((v) {
      if (v == 'all') context.go('/notifications');
    });
  }
}
