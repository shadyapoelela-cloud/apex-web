/// APEX Platform — Hybrid Navigation Sidebar (v2 — 10-round research)
/// ════════════════════════════════════════════════════════════════════
/// Synthesis of 10 rounds of research on leading enterprise platforms:
///   • Microsoft Fluent 2   → inline vs overlay breakpoint (900px)
///   • SAP Fiori 3          → embedded/overlay modes + active stripe
///   • Material 3 Adaptive  → rail/drawer responsive switch
///   • Linear + Notion      → active-route auto-expand, leading 3px stripe
///   • Stripe + Xero (2026) → 260–280px width, task-grouped labels
///   • QuickBooks Online    → + New quick action, Ctrl+K palette
///   • HubSpot (anti-pat.)  → NO hover auto-expand (explicit click only)
///   • Odoo                 → per-user collapse preference
///
/// Three display modes, chosen by viewport width:
///   ≥ 1200px → inline expanded (264px) OR inline rail (72px) — user toggle
///    900–1199 → inline rail (72px) by default; "expand" opens OVERLAY
///   < 900px  → compact rail (56px) + hamburger → OVERLAY drawer
///
/// Color tokens are fully theme-aware (all 12 themes via AC.sidebar*).
/// Active route is auto-detected via GoRouterState → leading stripe +
/// selected bg + auto-expand of parent group.
/// ════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// ── Data model ───────────────────────────────────────────────────────
class _NavGroup {
  final String label;
  final IconData icon;
  final List<_NavItem> items;
  bool expanded;
  /// If non-empty, only users whose `S.roles` intersects this list see the
  /// group. Empty (default) = visible to everyone. Useful for hiding a
  /// whole admin-only section.
  final List<String> requiredRoles;
  _NavGroup(
    this.label,
    this.icon,
    this.items, {
    this.expanded = false,
    this.requiredRoles = const [],
  });
}

class _NavItem {
  final String label;
  final String route;
  final IconData icon;
  final List<String> keywords;

  /// Same semantics as `_NavGroup.requiredRoles`: empty = visible to all.
  /// When set, the item is filtered out if `S.roles` doesn't intersect.
  final List<String> requiredRoles;
  const _NavItem(
    this.label,
    this.route,
    this.icon, {
    this.keywords = const [],
    this.requiredRoles = const [],
  });
}

/// ── Display modes ────────────────────────────────────────────────────
enum _Mode { expanded, rail }

class HybridSidebar extends StatefulWidget {
  final Widget child;
  final bool showSearch;
  const HybridSidebar({
    super.key,
    required this.child,
    this.showSearch = true,
  });

  @override
  State<HybridSidebar> createState() => _HybridSidebarState();
}

class _HybridSidebarState extends State<HybridSidebar> {
  // User-controlled collapse (applies only at ≥1200px).
  bool _userCollapsed = false;
  // Drawer open state (used for overlay mode on narrow/medium screens).
  bool _drawerOpen = false;

  // ── Taxonomy (CoWork hybrid nav spec, ordered by task frequency) ────
  final List<_NavGroup> _groups = [
    _NavGroup('لوحات القيادة', Icons.dashboard_rounded, [
      _NavItem('الرئيسية', '/dashboard', Icons.home_rounded,
          keywords: ['home', 'start', 'landing']),
      _NavItem('لوحة CFO', '/compliance/executive',
          Icons.admin_panel_settings_rounded),
      _NavItem('مركز الامتثال', '/compliance', Icons.shield_rounded),
    ], expanded: true),
    _NavGroup('الشركات والعقود', Icons.apartment_rounded, [
      _NavItem('إعداد الكيانات', '/settings/entities',
          Icons.corporate_fare_rounded,
          keywords: ['entity', 'setup', 'hierarchy', 'كيان', 'فروع']),
      _NavItem('الشركات', '/clients', Icons.apartment_rounded,
          keywords: ['companies', 'clients', 'شركات', 'عملاء']),
      _NavItem('خدمات الشركات', '/marketplace', Icons.store_rounded),
    ]),
    _NavGroup('القوائم المالية', Icons.auto_graph_rounded, [
      _NavItem('القوائم (TB/IS/BS)', '/compliance/financial-statements',
          Icons.auto_graph_rounded),
      _NavItem('قائمة التدفقات', '/compliance/cashflow-statement',
          Icons.water_drop_rounded),
      _NavItem('التوحيد', '/compliance/consolidation', Icons.merge_type_rounded),
      _NavItem('المؤشرات المالية', '/compliance/ratios',
          Icons.analytics_rounded),
    ]),
    _NavGroup('القيود والتدقيق', Icons.edit_note_rounded, [
      _NavItem('بنّاء القيود', '/compliance/journal-entry-builder',
          Icons.edit_note_rounded),
      _NavItem('أرقام القيود', '/compliance/journal-entries',
          Icons.confirmation_number_rounded),
      _NavItem('سجل التدقيق', '/compliance/audit-trail',
          Icons.lock_outline_rounded),
    ]),
    _NavGroup('الضرائب والامتثال', Icons.receipt_long_rounded, [
      _NavItem('فاتورة ZATCA', '/compliance/zatca-invoice',
          Icons.receipt_long_rounded),
      _NavItem('الزكاة', '/compliance/zakat', Icons.savings_rounded),
      _NavItem('إقرار VAT', '/compliance/vat-return', Icons.receipt_rounded),
      _NavItem('ضريبة الاستقطاع', '/compliance/wht', Icons.gavel_rounded),
      _NavItem('الضرائب المؤجّلة', '/compliance/deferred-tax',
          Icons.schedule_send_rounded),
      _NavItem('تسعير التحويل', '/compliance/transfer-pricing',
          Icons.compare_rounded),
    ]),
    _NavGroup('الأصول والإيجار', Icons.inventory_rounded, [
      _NavItem('سجل الأصول', '/compliance/fixed-assets', Icons.inventory),
      _NavItem('محاسبة الإيجار', '/compliance/lease', Icons.timeline_rounded),
      _NavItem('الإهلاك', '/compliance/depreciation', Icons.auto_graph_rounded),
    ]),
    _NavGroup('العمليات', Icons.settings_rounded, [
      _NavItem('الرواتب + GOSI', '/compliance/payroll', Icons.badge_rounded),
      _NavItem('التسوية البنكية', '/compliance/bank-rec',
          Icons.account_balance_rounded),
      _NavItem('المخزون', '/compliance/inventory', Icons.inventory_2_rounded),
      _NavItem('أعمار الذمم', '/compliance/aging', Icons.bar_chart_rounded),
      _NavItem('الأقساط', '/compliance/amortization', Icons.schedule_rounded),
    ]),
    _NavGroup('التقييم والتمويل', Icons.trending_up_rounded, [
      _NavItem('تغطية الدين (DSCR)', '/compliance/dscr',
          Icons.account_balance_rounded),
      _NavItem('التقييم (WACC/DCF)', '/compliance/valuation',
          Icons.query_stats_rounded),
      _NavItem('NPV/IRR', '/compliance/investment', Icons.insights_rounded),
      _NavItem('نقطة التعادل', '/compliance/breakeven', Icons.balance_rounded),
    ]),
    _NavGroup('أدوات متقدمة', Icons.all_inclusive_rounded, [
      _NavItem('IFRS (5-in-1)', '/compliance/ifrs-tools', Icons.style_rounded),
      _NavItem('Extras (7-in-1)', '/compliance/extras-tools',
          Icons.all_inclusive_rounded),
      _NavItem('انحرافات التكاليف', '/compliance/cost-variance',
          Icons.analytics_rounded),
      _NavItem('محوّل العملات', '/compliance/fx-converter',
          Icons.swap_horiz_rounded),
      _NavItem('OCR الفواتير', '/compliance/ocr', Icons.document_scanner_rounded),
    ]),
    // Admin-only group — visible only to platform_admin / super_admin.
    // See architecture/diagrams/02-target-state.md §5 (Adaptive Navigation).
    _NavGroup(
      'الإدارة',
      Icons.admin_panel_settings_rounded,
      [
        _NavItem(
          'لوحة المراجع',
          '/admin/reviewer',
          Icons.fact_check_rounded,
          requiredRoles: ['platform_admin', 'super_admin', 'reviewer'],
        ),
        _NavItem(
          'اعتماد المزوّدين',
          '/admin/providers/verify',
          Icons.verified_user_rounded,
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'سياسات + قانوني',
          '/admin/policies',
          Icons.gavel_rounded,
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'سجل التدقيق الكامل',
          '/admin/audit',
          Icons.history_rounded,
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'AI Console',
          '/admin/ai-console',
          Icons.psychology_rounded,
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'محرّك الأتمتة',
          '/admin/workflow/rules',
          Icons.auto_awesome_motion_rounded,
          keywords: ['workflow', 'rules', 'automation', 'قواعد', 'أتمتة'],
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'قوالب الأتمتة',
          '/admin/workflow/templates',
          Icons.auto_awesome_rounded,
          keywords: ['templates', 'قوالب'],
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'إدارة الوحدات',
          '/admin/modules',
          Icons.extension_rounded,
          keywords: ['modules', 'وحدات', 'tenant'],
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'اشتراكات Webhooks',
          '/admin/webhooks',
          Icons.webhook_rounded,
          keywords: ['webhooks', 'اشتراكات', 'integrations'],
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
        _NavItem(
          'مفاتيح API',
          '/admin/api-keys',
          Icons.vpn_key_rounded,
          keywords: ['api', 'keys', 'مفاتيح'],
          requiredRoles: ['platform_admin', 'super_admin'],
        ),
      ],
      requiredRoles: ['platform_admin', 'super_admin', 'reviewer'],
    ),
  ];

  /// True when `userRoles` intersects `required` — empty `required` means
  /// "no role gate, visible to everyone".
  bool _hasAnyRole(List<String> required) {
    if (required.isEmpty) return true;
    final userRoles = S.roles;
    if (userRoles.isEmpty) return false;
    for (final r in required) {
      if (userRoles.contains(r)) return true;
    }
    return false;
  }

  /// Returns the role-filtered groups: items hidden if user lacks role,
  /// whole groups hidden if all their items are filtered out.
  List<_NavGroup> _visibleGroups() {
    final out = <_NavGroup>[];
    for (final g in _groups) {
      if (!_hasAnyRole(g.requiredRoles)) continue;
      final visibleItems = g.items.where((i) => _hasAnyRole(i.requiredRoles)).toList();
      if (visibleItems.isEmpty) continue;
      // Build a new group instance so the filter is non-destructive.
      out.add(_NavGroup(
        g.label,
        g.icon,
        visibleItems,
        expanded: g.expanded,
        requiredRoles: g.requiredRoles,
      ));
    }
    return out;
  }

  // ── Active-state helpers ────────────────────────────────────────────
  String _currentRoute(BuildContext context) {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return '/';
    }
  }

  bool _itemActive(String route, String current) {
    if (route == current) return true;
    if (route.length > 3 && current.startsWith('$route/')) return true;
    return false;
  }

  // Auto-expand the group that contains the current route.
  void _maybeExpandActiveGroup(String current) {
    for (final g in _groups) {
      if (g.items.any((it) => _itemActive(it.route, current))) {
        if (!g.expanded) g.expanded = true;
      }
    }
  }

  /// Cache of the role-filtered groups so we don't rebuild on every paint.
  /// Cleared on `setState()` of the host widget naturally; re-derived in build.
  late List<_NavGroup> _filteredGroups;

  // ── Mode computation ────────────────────────────────────────────────
  _Mode _modeFor(double w) {
    if (w >= 1200) {
      return _userCollapsed ? _Mode.rail : _Mode.expanded;
    }
    return _Mode.rail; // tablets + phones ⇒ inline rail
  }

  double _inlineWidthFor(double w, _Mode m) {
    if (m == _Mode.expanded) return 264.0;
    return w < 900 ? 56.0 : 72.0; // 56 on phones, 72 on tablets/desktop
  }

  // ── Dialogs ─────────────────────────────────────────────────────────
  void _showQuickSearch() {
    // Use the role-filtered groups so users can't search to a route they
    // don't have permission for.
    final all = <_NavItem>[for (final g in _filteredGroups) ...g.items];
    showDialog(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (_) => _QuickSearchDialog(items: all),
    );
  }

  void _showNewMenu() => showDialog(
        context: context,
        barrierColor: AC.sidebarScrim,
        builder: (_) => const _NewMenuDialog(),
      );

  void _toggleCollapsed() => setState(() => _userCollapsed = !_userCollapsed);
  void _toggleDrawer() => setState(() => _drawerOpen = !_drawerOpen);

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final current = _currentRoute(context);
    _maybeExpandActiveGroup(current);
    // Recompute role-filtered groups every build — cheap (small lists),
    // safe across login/logout transitions where S.roles changes.
    _filteredGroups = _visibleGroups();

    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final mode = _modeFor(w);
      final inlineW = _inlineWidthFor(w, mode);
      final showOverlay = _drawerOpen && mode != _Mode.expanded;
      const overlayW = 280.0;

      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _showQuickSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _showQuickSearch,
          const SingleActivator(LogicalKeyboardKey.backslash, control: true):
              _toggleCollapsed,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_drawerOpen) _toggleDrawer();
          },
          // Alt+1..9 to jump to the first 9 groups / sections (SAP Fiori
          // style numeric shortcuts — WCAG 2.2 keyboard navigation).
          const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
              _jumpToGroup(0),
          const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
              _jumpToGroup(1),
          const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
              _jumpToGroup(2),
          const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
              _jumpToGroup(3),
          const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () =>
              _jumpToGroup(4),
          const SingleActivator(LogicalKeyboardKey.digit6, alt: true): () =>
              _jumpToGroup(5),
          const SingleActivator(LogicalKeyboardKey.digit7, alt: true): () =>
              _jumpToGroup(6),
          const SingleActivator(LogicalKeyboardKey.digit8, alt: true): () =>
              _jumpToGroup(7),
          const SingleActivator(LogicalKeyboardKey.digit9, alt: true): () =>
              _jumpToGroup(8),
        },
        child: Focus(
          autofocus: true,
          child: Semantics(
            label: 'الشريط الجانبي الرئيسي',
            container: true,
            explicitChildNodes: true,
            child: Scaffold(
              backgroundColor: AC.navy,
              body: Stack(children: [
              // ── Main content (pushed by inline sidebar width) ─────
              PositionedDirectional(
                start: inlineW,
                end: 0,
                top: 0,
                bottom: 0,
                child: ClipRect(child: widget.child),
              ),

              // ── Inline sidebar (rail or expanded) ────────────────
              AnimatedPositionedDirectional(
                duration: DS.motionMed,
                curve: DS.easeEmphasized,
                start: 0,
                top: 0,
                bottom: 0,
                width: inlineW,
                child: Material(
                  color: AC.sidebarBg,
                  child: _buildSidebar(
                    mode == _Mode.expanded ? _Mode.expanded : _Mode.rail,
                    current,
                    isOverlay: false,
                    onToggle: mode == _Mode.expanded
                        ? _toggleCollapsed
                        : _toggleDrawer,
                  ),
                ),
              ),

              // ── Scrim when overlay drawer is open ────────────────
              if (showOverlay)
                PositionedDirectional(
                  start: inlineW,
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleDrawer,
                    child: AnimatedContainer(
                      duration: DS.motionMed,
                      color: AC.sidebarScrim,
                    ),
                  ),
                ),

              // ── Overlay drawer (slides in from leading edge) ─────
              AnimatedPositionedDirectional(
                duration: DS.motionMed,
                curve: DS.easeEmphasized,
                start: showOverlay ? inlineW : -(overlayW + 8),
                top: 0,
                bottom: 0,
                width: overlayW,
                child: Material(
                  color: AC.sidebarBg,
                  elevation: 18,
                  shadowColor: AC.overlay,
                  child: _buildSidebar(
                    _Mode.expanded,
                    current,
                    isOverlay: true,
                    onToggle: _toggleDrawer,
                  ),
                ),
              ),
              ]),
            ),
          ),
        ),
      );
    });
  }

  void _jumpToGroup(int index) {
    final groups = _filteredGroups;
    if (index < 0 || index >= groups.length) return;
    final group = groups[index];
    if (group.items.isEmpty) return;
    // Navigate to the group's first item.
    final first = group.items.first;
    if (_drawerOpen) _toggleDrawer();
    try {
      context.go(first.route);
    } catch (_) {}
  }

  // ── Sidebar body (shared between rail / expanded / overlay) ─────────
  Widget _buildSidebar(
    _Mode renderMode,
    String current, {
    required bool isOverlay,
    required VoidCallback onToggle,
  }) {
    final isRail = renderMode == _Mode.rail;
    return Container(
      decoration: BoxDecoration(
        color: AC.sidebarBg,
        border: BorderDirectional(
          end: BorderSide(color: AC.sidebarBorder, width: 1),
        ),
      ),
      child: Stack(children: [
        // Theme-identity accent on the leading edge
        PositionedDirectional(
          start: 0, top: 0, bottom: 0, width: 3,
          child: Container(color: AC.sidebarAccentEdge),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 3),
          child: Column(children: [
            _buildHeader(isRail, isOverlay, onToggle),
            _buildQuickActions(isRail),
            Divider(color: AC.sidebarBorder, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _filteredGroups.length,
                itemBuilder: (ctx, i) =>
                    _buildGroup(_filteredGroups[i], isRail, current, isOverlay),
              ),
            ),
            Divider(color: AC.sidebarBorder, height: 1),
            _buildBottomItem(Icons.person_rounded, 'الحساب',
                '/account/sessions', isRail, current, isOverlay),
            _buildBottomItem(Icons.settings_rounded, 'الإعدادات',
                '/admin/policies', isRail, current, isOverlay),
            _buildFooter(isRail),
          ]),
        ),
      ]),
    );
  }

  // ── Header (logo + collapse toggle) ─────────────────────────────────
  Widget _buildHeader(bool isRail, bool isOverlay, VoidCallback onToggle) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isRail ? 8 : 14, vertical: isRail ? 10 : 12),
      decoration: BoxDecoration(gradient: AC.sidebarHeaderGradient),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(DS.rMd),
          ),
          child: Icon(Icons.apartment_rounded, color: AC.gold, size: 20),
        ),
        if (!isRail) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'APEX',
              style: TextStyle(
                color: AC.gold,
                fontSize: 19,
                fontWeight: DS.fwBlack,
                letterSpacing: 0.6,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isOverlay ? Icons.close_rounded : Icons.chevron_right_rounded,
              color: AC.sidebarItemDim,
              size: DS.iconMd,
            ),
            onPressed: onToggle,
            tooltip: isOverlay ? 'إغلاق' : 'طيّ الشريط (Ctrl+\\)',
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
          ),
        ] else
          Expanded(
            child: Center(
              child: IconButton(
                icon: Icon(Icons.chevron_left_rounded,
                    color: AC.sidebarItemDim, size: DS.iconMd),
                onPressed: onToggle,
                tooltip: 'توسيع',
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
              ),
            ),
          ),
      ]),
    );
  }

  // ── Quick actions (New / Search) ────────────────────────────────────
  Widget _buildQuickActions(bool isRail) {
    if (isRail) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(children: [
          Tooltip(
            message: 'جديد',
            child: Material(
              color: AC.gold,
              borderRadius: BorderRadius.circular(DS.rMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(DS.rMd),
                onTap: _showNewMenu,
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: Icon(Icons.add_rounded,
                      color: AC.btnFg, size: DS.iconMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: 'بحث سريع (Ctrl+K)',
            child: InkWell(
              borderRadius: BorderRadius.circular(DS.rMd),
              onTap: _showQuickSearch,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Icon(Icons.search_rounded,
                      color: AC.sidebarItemDim, size: DS.iconMd),
                ),
              ),
            ),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showNewMenu,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('جديد'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
              ),
              textStyle: const TextStyle(
                  fontWeight: DS.fwSemibold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showQuickSearch,
            icon: const Icon(Icons.search_rounded, size: 15),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('بحث سريع', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AC.sidebarBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('⌘K',
                    style: TextStyle(
                        color: AC.sidebarItemDim,
                        fontSize: 9,
                        fontWeight: DS.fwBold)),
              ),
            ]),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
              side: BorderSide(color: AC.sidebarBorder),
              foregroundColor: AC.sidebarItemDim,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Group (collapsible with auto-expand when active) ────────────────
  Widget _buildGroup(
      _NavGroup g, bool isRail, String current, bool isOverlay) {
    if (isRail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: g.items
              .map((it) =>
                  _railItem(it, _itemActive(it.route, current), isOverlay))
              .toList(),
        ),
      );
    }
    final anyActive =
        g.items.any((it) => _itemActive(it.route, current));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => setState(() => g.expanded = !g.expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: Row(children: [
            Icon(
              g.icon,
              color: anyActive
                  ? AC.sidebarGroupFg
                  : AC.sidebarGroupFg.withValues(alpha: 0.75),
              size: DS.iconMd,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                g.label,
                style: TextStyle(
                  color: AC.sidebarItemFg,
                  fontSize: 12.5,
                  fontWeight: DS.fwBold,
                  letterSpacing: 0.15,
                ),
              ),
            ),
            AnimatedRotation(
              turns: g.expanded ? 0.0 : -0.25,
              duration: DS.motionFast,
              child: Icon(Icons.expand_more_rounded,
                  color: AC.sidebarItemDim, size: DS.iconMd),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: DS.motionMed,
        curve: DS.easeEmphasized,
        alignment: Alignment.topCenter,
        child: g.expanded
            ? Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  children: g.items
                      .map((it) => _expandedItem(
                          it, _itemActive(it.route, current), isOverlay))
                      .toList(),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  // ── Item (expanded row) ─────────────────────────────────────────────
  Widget _expandedItem(_NavItem it, bool isActive, bool isOverlay) {
    return InkWell(
      onTap: () {
        if (isOverlay) _toggleDrawer();
        context.go(it.route);
      },
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(8, 1, 8, 1),
        height: 36,
        decoration: BoxDecoration(
          color:
              isActive ? AC.sidebarItemSelectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(DS.rMd),
        ),
        child: Stack(children: [
          // Leading stripe (3px) when active
          if (isActive)
            PositionedDirectional(
              start: 0,
              top: 6,
              bottom: 6,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AC.sidebarActiveStripe,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding:
                const EdgeInsetsDirectional.fromSTEB(20, 0, 14, 0),
            child: Row(children: [
              Icon(
                it.icon,
                size: DS.iconSm,
                color: isActive
                    ? AC.sidebarGroupFg
                    : AC.sidebarItemDim,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  it.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? AC.sidebarItemFg
                        : AC.sidebarItemDim,
                    fontSize: 12.5,
                    fontWeight:
                        isActive ? DS.fwSemibold : DS.fwRegular,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Item (rail / collapsed) ─────────────────────────────────────────
  Widget _railItem(_NavItem it, bool isActive, bool isOverlay) {
    return Tooltip(
      message: it.label,
      waitDuration: DS.tooltipWait,
      preferBelow: false,
      child: InkWell(
        onTap: () {
          if (isOverlay) _toggleDrawer();
          context.go(it.route);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          height: 40,
          decoration: BoxDecoration(
            color:
                isActive ? AC.sidebarItemSelectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(DS.rMd),
          ),
          child: Stack(children: [
            if (isActive)
              PositionedDirectional(
                start: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AC.sidebarActiveStripe,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Center(
              child: Icon(
                it.icon,
                color: isActive
                    ? AC.sidebarGroupFg
                    : AC.sidebarItemDim,
                size: DS.iconMd + 2,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Bottom items (pinned account / settings) ────────────────────────
  Widget _buildBottomItem(IconData icon, String label, String route,
      bool isRail, String current, bool isOverlay) {
    final active = _itemActive(route, current);
    if (isRail) {
      return Tooltip(
        message: label,
        waitDuration: DS.tooltipWait,
        child: InkWell(
          onTap: () {
            if (isOverlay) _toggleDrawer();
            context.go(route);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
            height: 40,
            decoration: BoxDecoration(
              color:
                  active ? AC.sidebarItemSelectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(DS.rMd),
            ),
            child: Center(
              child: Icon(icon,
                  color: active
                      ? AC.sidebarGroupFg
                      : AC.sidebarItemDim,
                  size: DS.iconMd),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () {
        if (isOverlay) _toggleDrawer();
        context.go(route);
      },
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 2),
        height: 36,
        decoration: BoxDecoration(
          color: active ? AC.sidebarItemSelectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(DS.rMd),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(icon,
                color: active ? AC.sidebarGroupFg : AC.sidebarItemDim,
                size: DS.iconMd),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? AC.sidebarItemFg : AC.sidebarItemDim,
                fontSize: 12.5,
                fontWeight: active ? DS.fwSemibold : DS.fwRegular,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Footer (theme indicator) ────────────────────────────────────────
  Widget _buildFooter(bool isRail) {
    if (isRail) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: AC.ok, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'متصل • ${AC.current.nameAr}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AC.sidebarItemDim,
                fontSize: 10,
                fontWeight: DS.fwMedium),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Quick Search Dialog — Cmd+K palette
// ═══════════════════════════════════════════════════════════════════════
class _QuickSearchDialog extends StatefulWidget {
  final List<_NavItem> items;
  const _QuickSearchDialog({required this.items});

  @override
  State<_QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<_QuickSearchDialog> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<_NavItem> get _filtered {
    if (_q.isEmpty) return widget.items;
    final q = _q.toLowerCase();
    return widget.items.where((it) {
      if (it.label.toLowerCase().contains(q)) return true;
      for (final k in it.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.rLg),
        side: BorderSide(color: AC.sidebarBorder),
      ),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          TextField(
            controller: _ctl,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim()),
            style: TextStyle(color: AC.sidebarItemFg, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن أي أداة، شاشة، عميل…',
              hintStyle:
                  TextStyle(color: AC.sidebarItemDim, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AC.gold),
              filled: true,
              fillColor: AC.sidebarBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
                borderSide: BorderSide(color: AC.gold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('لا توجد نتائج',
                        style: TextStyle(
                            color: AC.sidebarItemDim, fontSize: 13)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final it = list[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(DS.rMd),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.go(it.route);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          margin:
                              const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DS.rMd),
                          ),
                          child: Row(children: [
                            Icon(it.icon, color: AC.gold, size: 17),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                it.label,
                                style: TextStyle(
                                    color: AC.sidebarItemFg,
                                    fontSize: 13),
                              ),
                            ),
                            Text(it.route,
                                style: TextStyle(
                                    color: AC.sidebarItemDim
                                        .withValues(alpha: 0.7),
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.keyboard_rounded,
                color: AC.sidebarItemDim, size: 13),
            const SizedBox(width: 6),
            Text('Cmd+K / Ctrl+K للبحث السريع',
                style: TextStyle(color: AC.sidebarItemDim, fontSize: 10)),
            const Spacer(),
            Text('${list.length} نتيجة',
                style: TextStyle(color: AC.sidebarItemDim, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// New Menu Dialog — "+ جديد" quick-create actions
// ═══════════════════════════════════════════════════════════════════════
class _NewMenuDialog extends StatelessWidget {
  const _NewMenuDialog();
  @override
  Widget build(BuildContext context) {
    final items = [
      ('شركة جديدة', Icons.domain_add_rounded,
          '/settings/entities?action=new-company'),
      ('كيان جديد', Icons.corporate_fare_rounded,
          '/settings/entities?action=new-entity'),
      ('فاتورة ZATCA', Icons.receipt_long_rounded, '/compliance/zatca-invoice'),
      ('قيد محاسبي', Icons.edit_note_rounded,
          '/compliance/journal-entry-builder'),
      ('قائمة مالية', Icons.auto_graph_rounded,
          '/compliance/financial-statements'),
      ('تحويل عملة', Icons.swap_horiz_rounded, '/compliance/fx-converter'),
      ('رفع ملف CSV', Icons.upload_file_rounded, '/upload'),
    ];
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.rLg),
        side: BorderSide(color: AC.sidebarBorder),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.add_circle_rounded, color: AC.gold, size: 20),
            const SizedBox(width: 10),
            Text('إنشاء جديد',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 15,
                    fontWeight: DS.fwBlack)),
          ]),
          const SizedBox(height: 14),
          ...items.map(
            (it) => InkWell(
              onTap: () {
                Navigator.of(context).pop();
                context.go(it.$3);
              },
              borderRadius: BorderRadius.circular(DS.rMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 11),
                child: Row(children: [
                  Icon(it.$2, color: AC.gold, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(it.$1,
                        style: TextStyle(
                            color: AC.sidebarItemFg, fontSize: 13)),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      color: AC.sidebarItemDim, size: 16),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
