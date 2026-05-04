/// APEX Magnetic Shell — global navigation chrome.
///
/// One wrapper that gives every screen the same 3-level navigation:
///   Level 1 (App)        — vertical icon rail at the leading edge
///   Level 2 (Category)   — flyout panel that opens on hover / tap
///   Level 3 (Sub-item)   — items inside each category, click → navigate
///
/// Plus a translucent floating action button at the trailing-bottom corner
/// for "+ create" actions. The FAB uses a backdrop blur so the screen
/// content remains readable underneath without visual blockage.
///
/// Usage (in router.dart's _apexPage):
///   ApexMagneticShell(child: yourScreen)
///
/// On mobile (< 768px) the rail collapses to nothing and the bottom nav
/// (ApexBottomNav) takes over — the FAB stays, lifted above the bottom nav.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'apex_responsive.dart';
import 'theme.dart';

// ── Shell mode toggle ────────────────────────────────────────────────────
// Switches between this magnetic side-panel chrome and the alternative
// horizontal tabs chrome (apex_tabs_shell.dart). Stored as a ValueNotifier
// so any widget can flip it at runtime.

class ApexShellMode {
  ApexShellMode._();
  // Default to the new tabs shell so the latest design is what users see
  // first. Toggle back to the magnetic sidebar via the swap icon in either
  // shell.
  static final ValueNotifier<bool> useTabs = ValueNotifier<bool>(true);
}

/// Public entry point to open the quick-search palette over any context.
void showApexQuickSearch(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _QuickSearchDialog(),
  );
}

// ── 3-level taxonomy ─────────────────────────────────────────────────────

class ApexSubItemRef {
  final String label;
  final String route;
  final IconData icon;
  /// Optional live state shown after the label as a small chip — e.g.
  /// "12", "AI", "جديد". Null hides the chip entirely.
  final String? badge;
  /// Override for the badge tint. Defaults to a neutral grey.
  final Color? badgeColor;
  const ApexSubItemRef(this.label, this.route, this.icon, {this.badge, this.badgeColor});
}

class ApexCategory {
  final String label;
  final IconData icon;
  final List<ApexSubItemRef> items;
  const ApexCategory(this.label, this.icon, this.items);
}

class ApexAppEntry {
  final String id;
  final String label;
  final IconData icon;
  final Color accent;
  final String homeRoute;
  final String routePrefix; // matched against current route to mark active
  final List<ApexCategory> categories;
  const ApexAppEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    required this.homeRoute,
    required this.routePrefix,
    required this.categories,
  });
}

// Real routes wired against router.dart. If a route is changed there, mirror
// it here.
final List<ApexAppEntry> kApexApps = [
  ApexAppEntry(
    id: 'today',
    label: 'اليوم',
    icon: Icons.today_rounded,
    accent: const Color(0xFF6C63FF),
    homeRoute: '/today',
    routePrefix: '/today',
    categories: [
      ApexCategory('نظرة عامة', Icons.dashboard_rounded, [
        ApexSubItemRef('اليوم', '/today', Icons.today_rounded),
        ApexSubItemRef('لوحة التحكم', '/dashboard', Icons.dashboard_rounded),
        ApexSubItemRef('لوحة CFO', '/compliance/executive',
            Icons.admin_panel_settings_rounded),
      ]),
      ApexCategory('الإطلاق السريع', Icons.rocket_launch_rounded, [
        ApexSubItemRef('Launchpad', '/app', Icons.apps_rounded),
        ApexSubItemRef('كل الخدمات', '/services', Icons.grid_view_rounded),
        ApexSubItemRef('ما الجديد', '/whats-new', Icons.fiber_new_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'sales',
    label: 'المبيعات',
    icon: Icons.point_of_sale_rounded,
    accent: const Color(0xFF2ECC8A),
    homeRoute: '/sales',
    routePrefix: '/sales',
    categories: [
      ApexCategory('العملاء', Icons.people_rounded, [
        ApexSubItemRef('قائمة العملاء', '/app/erp/finance/sales-customers', Icons.people_outline),
      ]),
      ApexCategory('الفواتير', Icons.receipt_long_rounded, [
        ApexSubItemRef('كل الفواتير', '/app/erp/sales/invoices', Icons.receipt_long_rounded,
            badge: '47'),
        ApexSubItemRef('فاتورة جديدة', '/app/erp/sales/invoice-create', Icons.add_rounded),
        ApexSubItemRef('فواتير دورية', '/app/erp/finance/recurring-entries', Icons.repeat_rounded,
            badge: '5'),
        ApexSubItemRef('عروض الأسعار', '/app/erp/sales/dashboard', Icons.request_quote_rounded),
        ApexSubItemRef('إشعارات دائنة', '/app/erp/sales/credit-notes', Icons.note_alt_rounded),
      ]),
      ApexCategory('التحصيل', Icons.account_balance_wallet_rounded, [
        ApexSubItemRef('أعمار الذمم', '/app/erp/sales/ar-aging', Icons.bar_chart_rounded,
            badge: '3 متأخرة', badgeColor: Color(0xFFE05050)),
        ApexSubItemRef('بيع سريع (POS)', '/pos/quick-sale', Icons.shopping_cart_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'purchase',
    label: 'المشتريات',
    icon: Icons.shopping_bag_rounded,
    accent: const Color(0xFFB97A3E),
    homeRoute: '/purchase',
    routePrefix: '/purchase',
    categories: [
      ApexCategory('الموردون', Icons.local_shipping_rounded, [
        ApexSubItemRef('قائمة الموردين', '/purchase/vendors', Icons.local_shipping_outlined),
      ]),
      ApexCategory('الفواتير الواردة', Icons.description_rounded, [
        ApexSubItemRef('كل الفواتير', '/purchase/bills', Icons.description_rounded),
        ApexSubItemRef('أعمار المستحقات', '/purchase/aging', Icons.bar_chart_outlined),
      ]),
      ApexCategory('دورة الشراء', Icons.sync_alt_rounded, [
        ApexSubItemRef('دورة الشراء الكاملة', '/operations/purchase-cycle',
            Icons.sync_alt_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'accounting',
    label: 'المحاسبة',
    icon: Icons.calculate_rounded,
    accent: const Color(0xFF4A6FA5),
    homeRoute: '/accounting',
    routePrefix: '/accounting',
    categories: [
      ApexCategory('شجرة الحسابات', Icons.account_tree_rounded, [
        ApexSubItemRef('شجرة الحسابات', '/accounting/coa-v2', Icons.account_tree_rounded),
        ApexSubItemRef('عرض شجري', '/coa-tree', Icons.account_tree_outlined),
        ApexSubItemRef('محرر COA', '/accounting/coa/edit', Icons.edit_rounded),
      ]),
      ApexCategory('قيود اليومية', Icons.edit_note_rounded, [
        ApexSubItemRef('سجل القيود', '/app/erp/finance/je-builder', Icons.list_alt_rounded,
            badge: '128'),
        ApexSubItemRef('بنّاء القيود', '/app/erp/finance/je-builder/new',
            Icons.edit_note_rounded),
        ApexSubItemRef('سجل التدقيق', '/compliance/audit-trail', Icons.lock_outline_rounded),
      ]),
      ApexCategory('التسوية البنكية', Icons.account_balance_rounded, [
        ApexSubItemRef('المطابقة الذكية', '/accounting/bank-rec-v2',
            Icons.compare_arrows_rounded),
        ApexSubItemRef('تغذية البنوك', '/settings/bank-feeds', Icons.cloud_sync_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'operations',
    label: 'العمليات',
    icon: Icons.settings_suggest_rounded,
    accent: const Color(0xFF6C63FF),
    homeRoute: '/operations',
    routePrefix: '/operations',
    categories: [
      ApexCategory('المخزون والأصول', Icons.inventory_2_rounded, [
        ApexSubItemRef('المخزون', '/operations/inventory-v2', Icons.inventory_2_rounded),
        ApexSubItemRef('بطاقة الصنف', '/operations/stock-card', Icons.qr_code_2_rounded),
        ApexSubItemRef('الأصول الثابتة', '/operations/fixed-assets-v2',
            Icons.business_rounded),
      ]),
      ApexCategory('إغلاق الفترة', Icons.event_available_rounded, [
        ApexSubItemRef('إغلاق الفترة', '/operations/period-close',
            Icons.event_available_rounded),
        ApexSubItemRef('قيد عمومي', '/operations/universal-journal',
            Icons.menu_book_rounded),
        ApexSubItemRef('التوحيد', '/operations/consolidation-ui', Icons.merge_type_rounded),
      ]),
      ApexCategory('نقاط البيع والصرف', Icons.point_of_sale_outlined, [
        ApexSubItemRef('جلسات POS', '/operations/pos-sessions', Icons.point_of_sale_rounded),
        ApexSubItemRef('عُهَد ومصاريف', '/operations/petty-cash',
            Icons.account_balance_wallet_outlined),
        ApexSubItemRef('التقاط إيصالات', '/receipt/capture', Icons.document_scanner_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'hr',
    label: 'الموارد البشرية',
    icon: Icons.badge_rounded,
    accent: const Color(0xFFB97A3E),
    homeRoute: '/hr',
    routePrefix: '/hr',
    categories: [
      ApexCategory('الموظفون', Icons.people_alt_rounded, [
        ApexSubItemRef('قائمة الموظفين', '/hr/employees', Icons.people_alt_rounded),
        ApexSubItemRef('الدوام (Timesheet)', '/hr/timesheet', Icons.schedule_rounded),
      ]),
      ApexCategory('الرواتب', Icons.payments_rounded, [
        ApexSubItemRef('تشغيل الرواتب', '/hr/payroll-run', Icons.payments_rounded),
        ApexSubItemRef('الرواتب + GOSI', '/compliance/payroll', Icons.badge_rounded),
        ApexSubItemRef('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'compliance',
    label: 'الامتثال',
    icon: Icons.shield_rounded,
    accent: const Color(0xFF2E75B6),
    homeRoute: '/compliance',
    routePrefix: '/compliance',
    categories: [
      ApexCategory('ضرائب وZATCA', Icons.receipt_long_rounded, [
        ApexSubItemRef('فاتورة ZATCA', '/compliance/zatca-invoice', Icons.receipt_long_rounded),
        ApexSubItemRef('مركز حالة ZATCA', '/compliance/zatca-status', Icons.verified_rounded),
        ApexSubItemRef('إقرار VAT', '/compliance/vat-return', Icons.receipt_rounded),
        ApexSubItemRef('الزكاة', '/compliance/zakat', Icons.savings_rounded),
        ApexSubItemRef('ضريبة الاستقطاع', '/compliance/wht-v2', Icons.gavel_rounded),
        ApexSubItemRef('التقويم الضريبي', '/compliance/tax-calendar',
            Icons.calendar_month_rounded),
        ApexSubItemRef('الجدول الزمني', '/compliance/tax-timeline', Icons.timeline_rounded),
      ]),
      ApexCategory('القوائم والتوحيد', Icons.auto_graph_rounded, [
        ApexSubItemRef('القوائم (TB/IS/BS)', '/compliance/financial-statements',
            Icons.auto_graph_rounded),
        ApexSubItemRef('قائمة التدفقات', '/compliance/cashflow-statement',
            Icons.water_drop_rounded),
        ApexSubItemRef('التوحيد', '/compliance/consolidation-v2', Icons.merge_type_rounded),
        ApexSubItemRef('المؤشرات المالية', '/compliance/ratios', Icons.analytics_rounded),
      ]),
      ApexCategory('المخاطر والامتثال', Icons.shield_outlined, [
        ApexSubItemRef('سجل المخاطر', '/compliance/risk-register', Icons.warning_amber_rounded),
        ApexSubItemRef('KYC / AML', '/compliance/kyc-aml', Icons.fingerprint_rounded),
        ApexSubItemRef('سجل النشاط', '/compliance/activity-log-v2', Icons.history_rounded),
      ]),
      ApexCategory('أصول وIFRS', Icons.style_rounded, [
        ApexSubItemRef('IFRS (5-in-1)', '/compliance/ifrs-tools', Icons.style_rounded),
        ApexSubItemRef('الإيجار (IFRS 16)', '/compliance/lease-v2', Icons.timeline_rounded),
        ApexSubItemRef('الضرائب المؤجّلة', '/compliance/deferred-tax',
            Icons.schedule_send_rounded),
        ApexSubItemRef('تسعير التحويل', '/compliance/transfer-pricing',
            Icons.compare_rounded),
        ApexSubItemRef('تمويل إسلامي', '/compliance/islamic-finance', Icons.mosque_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'analytics',
    label: 'التحليلات',
    icon: Icons.insights_rounded,
    accent: const Color(0xFFE74C3C),
    homeRoute: '/analytics',
    routePrefix: '/analytics',
    categories: [
      ApexCategory('السيولة والميزانية', Icons.show_chart_rounded, [
        ApexSubItemRef('تنبؤ التدفق النقدي', '/analytics/cash-flow-forecast',
            Icons.trending_up_rounded),
        ApexSubItemRef('انحراف الميزانية', '/analytics/budget-variance-v2',
            Icons.bar_chart_rounded),
        ApexSubItemRef('بنّاء الميزانية', '/analytics/budget-builder',
            Icons.architecture_rounded),
        ApexSubItemRef('انحرافات التكاليف', '/analytics/cost-variance-v2',
            Icons.compare_arrows_rounded),
      ]),
      ApexCategory('الأداء والصحة', Icons.health_and_safety_rounded, [
        ApexSubItemRef('درجة الصحة المالية', '/analytics/health-score-v2',
            Icons.health_and_safety_rounded),
        ApexSubItemRef('ربحية المشاريع', '/analytics/project-profitability',
            Icons.workspace_premium_rounded),
        ApexSubItemRef('عملات متعددة', '/analytics/multi-currency-v2',
            Icons.currency_exchange_rounded),
      ]),
      ApexCategory('الاستثمار', Icons.trending_up_rounded, [
        ApexSubItemRef('محفظة الاستثمار', '/analytics/investment-portfolio-v2',
            Icons.trending_up_rounded),
      ]),
    ],
  ),
  ApexAppEntry(
    id: 'ai',
    label: 'الذكاء والمعرفة',
    icon: Icons.auto_awesome_rounded,
    accent: const Color(0xFF7C3AED),
    homeRoute: '/copilot',
    routePrefix: '/copilot',
    categories: [
      ApexCategory('Copilot', Icons.psychology_rounded, [
        ApexSubItemRef('المساعد الذكي', '/copilot', Icons.psychology_rounded,
            badge: 'AI', badgeColor: Color(0xFF7C3AED)),
        ApexSubItemRef('وحدة AI', '/admin/ai-console', Icons.smart_toy_rounded),
        ApexSubItemRef('اقتراحات AI', '/admin/ai-suggestions-v2',
            Icons.lightbulb_outline_rounded, badge: '7'),
      ]),
      ApexCategory('قاعدة المعرفة', Icons.menu_book_rounded, [
        ApexSubItemRef('بحث المعرفة', '/knowledge/search', Icons.search_rounded),
        ApexSubItemRef('Knowledge Brain', '/knowledge-brain', Icons.psychology_alt_rounded),
        ApexSubItemRef('ملاحظات المعرفة', '/knowledge/feedback', Icons.feedback_rounded),
      ]),
    ],
  ),
];

// Bottom-pinned items (always visible at the foot of the rail).
final List<ApexSubItemRef> kApexPinned = [
  ApexSubItemRef('مختبر الابتكار', '/lab', Icons.science_rounded),
  ApexSubItemRef('تبديل: تبويبات علوية', '__toggleShell__', Icons.swap_horiz_rounded),
  ApexSubItemRef('الإعدادات', '/settings/unified', Icons.settings_rounded),
  ApexSubItemRef('الإشعارات', '/notifications', Icons.notifications_rounded),
  ApexSubItemRef('الحساب', '/account/sessions', Icons.person_rounded),
];

// Quick-create actions for the FAB.
const List<ApexSubItemRef> _kQuickCreate = [
  ApexSubItemRef('فاتورة مبيعات', '/app/erp/sales/invoice-create', Icons.receipt_long_rounded),
  ApexSubItemRef('قيد محاسبي', '/app/erp/finance/je-builder/new', Icons.edit_note_rounded),
  ApexSubItemRef('فاتورة ZATCA', '/compliance/zatca-invoice', Icons.qr_code_2_rounded),
  ApexSubItemRef('شركة جديدة', '/settings/entities?action=new-company',
      Icons.domain_add_rounded),
  ApexSubItemRef('بيع سريع POS', '/pos/quick-sale', Icons.shopping_cart_rounded),
  ApexSubItemRef('التقاط إيصال', '/receipt/capture', Icons.document_scanner_rounded),
];

// ── Constants ────────────────────────────────────────────────────────────

const double _kRailWidth = 64.0;
const double _kFlyoutWidth = 260.0;
const Duration _kCloseDelay = Duration(milliseconds: 220);

// ═══════════════════════════════════════════════════════════════════════════
// ApexMagneticShell — the shell widget
// ═══════════════════════════════════════════════════════════════════════════

class ApexMagneticShell extends StatefulWidget {
  final Widget child;
  const ApexMagneticShell({super.key, required this.child});

  @override
  State<ApexMagneticShell> createState() => _ApexMagneticShellState();
}

class _ApexMagneticShellState extends State<ApexMagneticShell> {
  /// Currently-flying-out app id (null = closed).
  String? _hoverAppId;

  /// Pinned app — flyout stays open until user clicks pin again or X.
  String? _pinnedAppId;

  /// FAB radial menu open state.
  bool _fabOpen = false;

  Timer? _closeTimer;

  // Active flyout = pinned > hovered.
  String? get _activeFlyout => _pinnedAppId ?? _hoverAppId;

  void _enterApp(String id) {
    _closeTimer?.cancel();
    if (_pinnedAppId != null) return; // pinned panel takes precedence
    setState(() => _hoverAppId = id);
  }

  void _exitApp() {
    _closeTimer?.cancel();
    _closeTimer = Timer(_kCloseDelay, () {
      if (!mounted) return;
      setState(() => _hoverAppId = null);
    });
  }

  void _enterFlyout() {
    _closeTimer?.cancel();
  }

  void _togglePin(String id) {
    setState(() {
      if (_pinnedAppId == id) {
        _pinnedAppId = null;
        _hoverAppId = null;
      } else {
        _pinnedAppId = id;
        _hoverAppId = null;
      }
    });
  }

  void _closeFlyout() {
    setState(() {
      _pinnedAppId = null;
      _hoverAppId = null;
    });
  }

  void _toggleFab() => setState(() => _fabOpen = !_fabOpen);

  String _currentRoute() {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return '/';
    }
  }

  bool _isAppActive(ApexAppEntry app, String current) {
    if (current == app.homeRoute) return true;
    return current.startsWith('${app.routePrefix}/');
  }

  bool _isItemActive(String route, String current) {
    if (route == current) return true;
    if (route.length > 3 && current.startsWith('$route/')) return true;
    return false;
  }

  void _go(String route) {
    if (route == '__toggleShell__') {
      ApexShellMode.useTabs.value = !ApexShellMode.useTabs.value;
      _closeFlyout();
      return;
    }
    _closeFlyout();
    setState(() => _fabOpen = false);
    context.go(route);
  }

  void _showQuickSearch() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const _QuickSearchDialog(),
    );
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ApexResponsive.isMobile(context);
    final railWidth = isMobile ? 0.0 : _kRailWidth;
    final current = _currentRoute();
    final flyoutId = _activeFlyout;
    final flyoutApp = flyoutId == null
        ? null
        : kApexApps.firstWhere(
            (a) => a.id == flyoutId,
            orElse: () => kApexApps.first,
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showQuickSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showQuickSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_fabOpen) {
            setState(() => _fabOpen = false);
          } else if (_activeFlyout != null) {
            _closeFlyout();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(children: [
          // Main content — pushed inward when the flyout opens so the
          // screen never gets covered. Uses an animated transition so
          // hover/pin opens feel like a single coordinated gesture.
          AnimatedPositionedDirectional(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            start: railWidth +
                (!isMobile && flyoutApp != null ? _kFlyoutWidth : 0.0),
            end: 0,
            top: 0,
            bottom: 0,
            child: widget.child,
          ),

          // ── Unified adaptive sidebar (icons + tree under one glass) ───
          // The single sidebar contracts to 64px (icons only) and expands
          // to 324px (icons + tree) — no separate fixed rail any more.
          if (!isMobile)
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              start: 0,
              top: 0,
              bottom: 0,
              width: railWidth +
                  (flyoutApp != null ? _kFlyoutWidth : 0.0),
              child: _AdaptiveSidebar(
                apps: kApexApps,
                pinned: kApexPinned,
                current: current,
                hoverAppId: _hoverAppId,
                pinnedAppId: _pinnedAppId,
                flyoutApp: flyoutApp,
                isAppActive: _isAppActive,
                isItemActive: _isItemActive,
                onAppEnter: _enterApp,
                onAppExit: _exitApp,
                onAppTap: (id) {
                  final app = kApexApps.firstWhere((a) => a.id == id);
                  _go(app.homeRoute);
                },
                onAppPin: _togglePin,
                onPinnedTap: _go,
                onSearchTap: _showQuickSearch,
                onItemTap: _go,
                onFlyoutPin: () =>
                    flyoutApp != null ? _togglePin(flyoutApp.id) : null,
                onFlyoutClose: _closeFlyout,
                onFlyoutMouseEnter: _enterFlyout,
                onFlyoutMouseExit: _exitApp,
              ),
            ),

          // Translucent FAB — placed on the START side (right in RTL) so it
          // never collides with screen-level Scaffold.floatingActionButton
          // which defaults to endFloat (left in RTL). Lifted above the
          // bottom nav on mobile + comfortable margin from the rail edge.
          PositionedDirectional(
            start: isMobile ? 12 : 18,
            bottom: isMobile ? 88 : 32,
            child: _TranslucentFab(
              isOpen: _fabOpen,
              actions: _kQuickCreate,
              onToggle: _toggleFab,
              onAction: _go,
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _AdaptiveSidebar — single panel that hosts BOTH the icon column and the
// expandable tree section under one shared glass background. Width is
// driven by the parent (animated): 64px collapsed, 324px expanded.
// ═══════════════════════════════════════════════════════════════════════════

class _AdaptiveSidebar extends StatelessWidget {
  final List<ApexAppEntry> apps;
  final List<ApexSubItemRef> pinned;
  final String current;
  final String? hoverAppId;
  final String? pinnedAppId;
  final ApexAppEntry? flyoutApp;

  final bool Function(ApexAppEntry, String) isAppActive;
  final bool Function(String, String) isItemActive;

  final void Function(String id) onAppEnter;
  final VoidCallback onAppExit;
  final void Function(String id) onAppTap;
  final void Function(String id) onAppPin;
  final void Function(String route) onPinnedTap;
  final VoidCallback onSearchTap;
  final void Function(String route) onItemTap;
  final VoidCallback onFlyoutPin;
  final VoidCallback onFlyoutClose;
  final VoidCallback onFlyoutMouseEnter;
  final VoidCallback onFlyoutMouseExit;

  const _AdaptiveSidebar({
    required this.apps,
    required this.pinned,
    required this.current,
    required this.hoverAppId,
    required this.pinnedAppId,
    required this.flyoutApp,
    required this.isAppActive,
    required this.isItemActive,
    required this.onAppEnter,
    required this.onAppExit,
    required this.onAppTap,
    required this.onAppPin,
    required this.onPinnedTap,
    required this.onSearchTap,
    required this.onItemTap,
    required this.onFlyoutPin,
    required this.onFlyoutClose,
    required this.onFlyoutMouseEnter,
    required this.onFlyoutMouseExit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AC.current.isDark;
    final accent = flyoutApp?.accent ?? AC.gold;
    return Material(
      elevation: 14,
      shadowColor: accent.withValues(alpha: 0.20),
      color: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Stack(children: [
            // Solid theme surface base — keeps every label crisp on any
            // underlying screen. Tinted at the top with the active app's
            // accent (or gold when collapsed) for the aurora effect.
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Color.alphaBlend(
                                accent.withValues(alpha: 0.20),
                                AC.navy2.withValues(alpha: 0.94)),
                            AC.navy2.withValues(alpha: 0.94),
                          ]
                        : [
                            Color.alphaBlend(
                                accent.withValues(alpha: 0.14),
                                AC.navy2.withValues(alpha: 0.96)),
                            AC.navy2.withValues(alpha: 0.96),
                          ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // Aurora orb — accent halo at the top trailing corner
            PositionedDirectional(
              top: -60,
              end: -50,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.28),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Aurora orb — gold warmth at bottom leading
            PositionedDirectional(
              bottom: -80,
              start: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AC.gold.withValues(alpha: 0.16),
                      AC.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Specular top edge — the "shine" of glass
            Positioned(
              top: 0, left: 0, right: 0, height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: isDark ? 0.18 : 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Trailing-edge gradient border — single luminous edge for the
            // whole panel (no internal divider between rail and tree).
            PositionedDirectional(
              top: 0, bottom: 0, end: 0, width: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.55),
                      AC.gold.withValues(alpha: 0.30),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                ),
              ),
            ),
            // ── Content row ─────────────────────────────────────────────
            // Icon column on start side; tree section unfolds to its
            // trailing side. ClipRect on the tree prevents content from
            // bleeding when the parent's animated width is contracting.
            Row(children: [
              SizedBox(
                width: _kRailWidth,
                child: _Rail(
                  apps: apps,
                  pinned: pinned,
                  current: current,
                  hoverAppId: hoverAppId,
                  pinnedAppId: pinnedAppId,
                  isAppActive: isAppActive,
                  onAppEnter: onAppEnter,
                  onAppExit: onAppExit,
                  onAppTap: onAppTap,
                  onAppPin: onAppPin,
                  onPinnedTap: onPinnedTap,
                  onSearchTap: onSearchTap,
                ),
              ),
              if (flyoutApp != null)
                Expanded(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: AlignmentDirectional.centerStart,
                      maxWidth: _kFlyoutWidth,
                      minWidth: 0,
                      child: SizedBox(
                        width: _kFlyoutWidth,
                        child: _Flyout(
                          app: flyoutApp!,
                          current: current,
                          isPinned: pinnedAppId == flyoutApp!.id,
                          isItemActive: isItemActive,
                          onItemTap: onItemTap,
                          onPin: onFlyoutPin,
                          onClose: onFlyoutClose,
                          onMouseEnter: onFlyoutMouseEnter,
                          onMouseExit: onFlyoutMouseExit,
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _Rail — vertical icon column at the leading edge
// ═══════════════════════════════════════════════════════════════════════════

class _Rail extends StatelessWidget {
  final List<ApexAppEntry> apps;
  final List<ApexSubItemRef> pinned;
  final String current;
  final String? hoverAppId;
  final String? pinnedAppId;
  final bool Function(ApexAppEntry, String) isAppActive;
  final void Function(String id) onAppEnter;
  final VoidCallback onAppExit;
  final void Function(String id) onAppTap;
  final void Function(String id) onAppPin;
  final void Function(String route) onPinnedTap;
  final VoidCallback onSearchTap;

  const _Rail({
    required this.apps,
    required this.pinned,
    required this.current,
    required this.hoverAppId,
    required this.pinnedAppId,
    required this.isAppActive,
    required this.onAppEnter,
    required this.onAppExit,
    required this.onAppTap,
    required this.onAppPin,
    required this.onPinnedTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    // Background/blur/border now provided by the parent _AdaptiveSidebar so
    // the icon column and the tree section share one cohesive glass panel.
    return Column(children: [
              // ── Brand mark + search (top group) ───────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AC.gold.withValues(alpha: 0.22),
                      AC.gold.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AC.gold.withValues(alpha: 0.45), width: 0.8),
                ),
                child: Icon(Icons.apartment_rounded, color: AC.gold, size: 22),
              ),
              _RailIconButton(
                icon: Icons.search_rounded,
                tooltip: 'بحث سريع (Ctrl+K)',
                active: false,
                accent: AC.gold,
                onTap: onSearchTap,
              ),
              const SizedBox(height: 6),
              _RailDivider(label: 'التطبيقات'),
              const SizedBox(height: 4),
              // ── Apps ──────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final app in apps)
                      _RailAppButton(
                        app: app,
                        active: isAppActive(app, current),
                        flyoutOpen:
                            hoverAppId == app.id || pinnedAppId == app.id,
                        pinned: pinnedAppId == app.id,
                        onEnter: () => onAppEnter(app.id),
                        onExit: onAppExit,
                        onTap: () => onAppTap(app.id),
                        onSecondaryTap: () => onAppPin(app.id),
                      ),
                  ],
                ),
              ),
              _RailDivider(label: 'مثبّت'),
              const SizedBox(height: 4),
              for (final p in pinned)
                _RailIconButton(
                  icon: p.icon,
                  tooltip: p.label,
                  active: current == p.route ||
                      (p.route.length > 3 && current.startsWith('${p.route}/')),
                  accent: AC.gold,
                  onTap: () => onPinnedTap(p.route),
                ),
              const SizedBox(height: 8),
    ]);
  }
}

/// Thin labelled divider used in the rail to separate the brand row,
/// the apps list, and the pinned items. The label is sized small enough
/// to feel like a section header without crowding the rail.
class _RailDivider extends StatelessWidget {
  final String label;
  const _RailDivider({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        Text(
          label,
          style: TextStyle(
            color: AC.ts,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AC.bdr.withValues(alpha: 0.0),
                AC.bdr.withValues(alpha: 0.6),
                AC.bdr.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _RailIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_RailIconButton> createState() => _RailIconButtonState();
}

class _RailIconButtonState extends State<_RailIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            height: 40,
            decoration: BoxDecoration(
              color: widget.active
                  ? widget.accent.withValues(alpha: 0.18)
                  : (_hover
                      ? widget.accent.withValues(alpha: 0.10)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: widget.active
                  ? Border.all(
                      color: widget.accent.withValues(alpha: 0.45),
                      width: 1)
                  : null,
            ),
            child: Stack(children: [
              if (widget.active)
                PositionedDirectional(
                  start: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Center(
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: widget.active ? widget.accent : AC.tp,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RailAppButton extends StatefulWidget {
  final ApexAppEntry app;
  final bool active;
  final bool flyoutOpen;
  final bool pinned;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  const _RailAppButton({
    required this.app,
    required this.active,
    required this.flyoutOpen,
    required this.pinned,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  State<_RailAppButton> createState() => _RailAppButtonState();
}

class _RailAppButtonState extends State<_RailAppButton> {
  @override
  Widget build(BuildContext context) {
    final highlight = widget.active || widget.flyoutOpen;
    return MouseRegion(
      onEnter: (_) => widget.onEnter(),
      onExit: (_) => widget.onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          height: 44,
          decoration: BoxDecoration(
            color: widget.active
                ? widget.app.accent.withValues(alpha: 0.20)
                : (highlight
                    ? widget.app.accent.withValues(alpha: 0.10)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: widget.active
                ? Border.all(
                    color: widget.app.accent.withValues(alpha: 0.50),
                    width: 1)
                : null,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.app.accent.withValues(alpha: 0.30),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(children: [
            // Active leading stripe — slightly thicker, glowing colour
            if (widget.active)
              PositionedDirectional(
                start: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.app.accent,
                        widget.app.accent.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.app.accent.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            Center(
              child: Icon(
                widget.app.icon,
                size: 22,
                color: highlight ? widget.app.accent : AC.tp,
              ),
            ),
            // Pin indicator (small dot top-end when pinned)
            if (widget.pinned)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AC.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _Flyout — second-level panel showing categories + sub-items
// ═══════════════════════════════════════════════════════════════════════════

class _Flyout extends StatefulWidget {
  final ApexAppEntry app;
  final String current;
  final bool isPinned;
  final bool Function(String, String) isItemActive;
  final void Function(String) onItemTap;
  final VoidCallback onPin;
  final VoidCallback onClose;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;

  const _Flyout({
    required this.app,
    required this.current,
    required this.isPinned,
    required this.isItemActive,
    required this.onItemTap,
    required this.onPin,
    required this.onClose,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  @override
  State<_Flyout> createState() => _FlyoutState();
}

class _FlyoutState extends State<_Flyout> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Returns the categories matching the search query, with their leaf
  /// items filtered. A category that has no matching leaves but matches by
  /// own label is kept with all its leaves intact.
  List<ApexCategory> _filtered() {
    if (_query.isEmpty) return widget.app.categories;
    final q = _query.toLowerCase();
    final out = <ApexCategory>[];
    for (final cat in widget.app.categories) {
      final catMatches = cat.label.toLowerCase().contains(q);
      final matchingItems = cat.items
          .where((it) => it.label.toLowerCase().contains(q))
          .toList();
      if (catMatches) {
        out.add(cat);
      } else if (matchingItems.isNotEmpty) {
        out.add(ApexCategory(cat.label, cat.icon, matchingItems));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cats = _filtered();
    // True when the active route is inside one of the visible branches —
    // in that case let auto-expand do its thing. Otherwise fall back to
    // opening only the first branch so the panel never feels empty.
    final hasActiveBranch = cats.any((c) =>
        c.items.any((it) => widget.isItemActive(it.route, widget.current)));
    // Background/blur/border now provided by the parent _AdaptiveSidebar
    // so the icon column and the tree section share one cohesive panel.
    return MouseRegion(
      onEnter: (_) => widget.onMouseEnter(),
      onExit: (_) => widget.onMouseExit(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Header ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.app.accent.withValues(alpha: 0.18),
                        widget.app.accent.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border(
                        bottom:
                            BorderSide(color: AC.sidebarBorder, width: 1)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.app.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.app.icon,
                          color: widget.app.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.app.label,
                        style: TextStyle(
                          color: AC.tp,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Tooltip(
                      message:
                          widget.isPinned ? 'إلغاء التثبيت' : 'تثبيت القائمة',
                      child: IconButton(
                        icon: Icon(
                          widget.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color:
                              widget.isPinned ? AC.gold : AC.sidebarItemDim,
                          size: 18,
                        ),
                        onPressed: widget.onPin,
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AC.sidebarItemDim, size: 18),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ]),
                ),
                // ── Inline search ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                  child: TextField(
                    controller: _searchCtl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: TextStyle(color: AC.sidebarItemFg, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'ابحث في ${widget.app.label}…',
                      hintStyle: TextStyle(
                          color: AC.sidebarItemDim, fontSize: 12),
                      isDense: true,
                      filled: true,
                      fillColor: AC.sidebarBg,
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AC.sidebarItemDim, size: 16),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: AC.sidebarItemDim, size: 14),
                              splashRadius: 14,
                              onPressed: () {
                                _searchCtl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                // ── Tree ─────────────────────────────────────────────────
                Expanded(
                  child: cats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('لا توجد نتائج',
                                style: TextStyle(
                                    color: AC.sidebarItemDim,
                                    fontSize: 12)),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            for (var i = 0; i < cats.length; i++)
                              ApexCategoryBlock(
                                key: ValueKey(
                                    '${widget.app.id}-${cats[i].label}-$_query'),
                                category: cats[i],
                                accent: widget.app.accent,
                                current: widget.current,
                                // Open the first branch when nothing else is
                                // active, OR open every branch while the
                                // user is filtering (since matches are
                                // sparse and they want to see them).
                                defaultOpen: _query.isNotEmpty ||
                                    (!hasActiveBranch && i == 0),
                                isItemActive: widget.isItemActive,
                                onItemTap: widget.onItemTap,
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
      ]),
    );
  }
}

class ApexCategoryBlock extends StatefulWidget {
  final ApexCategory category;
  final Color accent;
  final String current;
  final bool defaultOpen;
  final bool Function(String, String) isItemActive;
  final void Function(String) onItemTap;

  const ApexCategoryBlock({
    super.key,
    required this.category,
    required this.accent,
    required this.current,
    required this.defaultOpen,
    required this.isItemActive,
    required this.onItemTap,
  });

  @override
  State<ApexCategoryBlock> createState() => ApexCategoryBlockState();
}

class ApexCategoryBlockState extends State<ApexCategoryBlock> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Expand a branch only if (a) it contains the active route, OR (b) the
    // caller flagged it as the default-open branch (the first one when no
    // route inside the app is active). Other branches stay collapsed so the
    // tree reads like a real explorer instead of an exploded list.
    _expanded = widget.defaultOpen ||
        widget.category.items
            .any((it) => widget.isItemActive(it.route, widget.current));
  }

  @override
  void didUpdateWidget(covariant ApexCategoryBlock old) {
    super.didUpdateWidget(old);
    if (widget.category.items
        .any((it) => widget.isItemActive(it.route, widget.current))) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final hasActive = cat.items
        .any((it) => widget.isItemActive(it.route, widget.current));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Branch header (clickable to expand/collapse) ──────────────────
      _BranchHeader(
        category: cat,
        accent: widget.accent,
        expanded: _expanded,
        hasActive: hasActive,
        onTap: () => setState(() => _expanded = !_expanded),
      ),
      // ── Sub-items with tree connector lines ──────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _expanded
            ? _SubItemsTree(
                items: cat.items,
                accent: widget.accent,
                current: widget.current,
                isItemActive: widget.isItemActive,
                onItemTap: widget.onItemTap,
              )
            : const SizedBox(height: 0, width: double.infinity),
      ),
    ]);
  }
}

/// Branch header (formerly "category header") — clickable row with chevron
/// that rotates on expand. Highlighted when one of its leaves is the active
/// route so the user always knows which branch holds them.
class _BranchHeader extends StatefulWidget {
  final ApexCategory category;
  final Color accent;
  final bool expanded;
  final bool hasActive;
  final VoidCallback onTap;
  const _BranchHeader({
    required this.category,
    required this.accent,
    required this.expanded,
    required this.hasActive,
    required this.onTap,
  });

  @override
  State<_BranchHeader> createState() => _BranchHeaderState();
}

class _BranchHeaderState extends State<_BranchHeader> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final highlighted = widget.hasActive || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
          decoration: BoxDecoration(
            color: _hover
                ? widget.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            // Rotating chevron — clearly signals expandability
            AnimatedRotation(
              turns: widget.expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(Icons.expand_more_rounded,
                  color: highlighted ? widget.accent : AC.tp,
                  size: 18),
            ),
            const SizedBox(width: 4),
            Icon(cat.icon,
                color: highlighted ? widget.accent : AC.tp,
                size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cat.label,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
            ),
            // Aggregate count (number of sub-items in this branch)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: widget.accent.withValues(alpha: 0.45),
                    width: 0.8),
              ),
              child: Text('${cat.items.length}',
                  style: TextStyle(
                      color: widget.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Renders the sub-items of an expanded branch as a real tree, with a
/// vertical connector line + horizontal stubs joining each leaf to the
/// trunk. RTL-aware: the trunk sits on the start (right in RTL) edge.
class _SubItemsTree extends StatelessWidget {
  final List<ApexSubItemRef> items;
  final Color accent;
  final String current;
  final bool Function(String, String) isItemActive;
  final void Function(String) onItemTap;
  const _SubItemsTree({
    required this.items,
    required this.accent,
    required this.current,
    required this.isItemActive,
    required this.onItemTap,
  });

  // Position of the vertical trunk inside the branch — measured from the
  // start (right in RTL) edge of the flyout's content area. Lines align
  // visually with the chevron in the branch header above.
  static const double _trunkInsetStart = 24.0;
  static const double _stubWidth = 12.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Stack(children: [
        // Vertical trunk line connecting all leaves under the branch —
        // tinted with the app accent at low alpha so the tree feels
        // visually unified with the section's identity.
        PositionedDirectional(
          start: _trunkInsetStart,
          top: 0,
          bottom: 14, // stop before the last leaf's centre
          child: Container(
            width: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.45),
                  accent.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
        // Leaves
        Column(
          children: items
              .map((it) => _SubItemRow(
                    item: it,
                    accent: accent,
                    active: isItemActive(it.route, current),
                    trunkInsetStart: _trunkInsetStart,
                    stubWidth: _stubWidth,
                    onTap: () => onItemTap(it.route),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

class _SubItemRow extends StatefulWidget {
  final ApexSubItemRef item;
  final Color accent;
  final bool active;
  /// Horizontal position of the trunk (vertical line) — supplied by the
  /// parent so each leaf draws its stub aligned with the trunk.
  final double trunkInsetStart;
  final double stubWidth;
  final VoidCallback onTap;
  const _SubItemRow({
    required this.item,
    required this.accent,
    required this.active,
    required this.trunkInsetStart,
    required this.stubWidth,
    required this.onTap,
  });

  @override
  State<_SubItemRow> createState() => _SubItemRowState();
}

class _SubItemRowState extends State<_SubItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hover;
    // The leaf's tappable surface starts after the trunk + stub so the
    // tree connector remains visually intact even when a row is hovered.
    final startPad = widget.trunkInsetStart + widget.stubWidth + 6;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 32,
          child: Stack(children: [
            // Horizontal stub from trunk to leaf icon — tinted when the
            // branch is hovered/active so the path lights up end-to-end.
            PositionedDirectional(
              start: widget.trunkInsetStart,
              top: 16, // vertical centre of a 32px row
              child: Container(
                width: widget.stubWidth,
                height: 1.2,
                color: highlighted
                    ? widget.accent.withValues(alpha: 0.65)
                    : AC.sidebarBorder,
              ),
            ),
            // Hover/active pill (kept inside the leaf area so it doesn't
            // obscure the trunk line).
            PositionedDirectional(
              start: startPad - 4,
              end: 6,
              top: 2,
              bottom: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: widget.active
                      ? widget.accent.withValues(alpha: 0.14)
                      : (_hover ? AC.sidebarItemHoverBg : Colors.transparent),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            // Active stripe at the very leading edge of the leaf pill.
            if (widget.active)
              PositionedDirectional(
                start: startPad - 4,
                top: 6,
                bottom: 6,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Leaf content
            PositionedDirectional(
              start: startPad,
              end: 12,
              top: 0,
              bottom: 0,
              child: Row(children: [
                Icon(widget.item.icon,
                    size: 14,
                    color: highlighted ? widget.accent : AC.tp),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AC.tp,
                      fontSize: 12.5,
                      fontWeight:
                          widget.active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.item.badge != null) ...[
                  const SizedBox(width: 6),
                  _LeafBadge(
                    text: widget.item.badge!,
                    color: widget.item.badgeColor ?? AC.sidebarItemDim,
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LeafBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _LeafBadge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    // Glassmorphic chip — translucent base + thin gradient border + soft
    // outer glow tinted by the chip's own colour.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: color.withValues(alpha: 0.55), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TranslucentFab — translucent floating + radial of quick-create actions
// ═══════════════════════════════════════════════════════════════════════════

class _TranslucentFab extends StatelessWidget {
  final bool isOpen;
  final List<ApexSubItemRef> actions;
  final VoidCallback onToggle;
  final void Function(String) onAction;

  const _TranslucentFab({
    required this.isOpen,
    required this.actions,
    required this.onToggle,
    required this.onAction,
  });

  // Radius of the radial arc + FAB diameter + small buffer for the radial
  // item itself (44px) so nothing renders outside the SizedBox.
  static const double _radius = 96.0;
  static const double _fabSize = 56.0;
  static const double _itemSize = 44.0;
  // Total area we need: from the FAB centre we sweep an arc of _radius into
  // the upper-leading quadrant. We anchor the FAB at the bottom-end-corner
  // of the SizedBox and let the radial spray into the rest.
  static const double _areaSize = _radius + _fabSize + _itemSize;

  @override
  Widget build(BuildContext context) {
    // A real bounded box so Positioned children render fully — the previous
    // implementation used Stack(alignment: center) without explicit size,
    // which collapsed to FAB size and clipped the radial.
    return SizedBox(
      width: _areaSize,
      height: _areaSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // FAB anchored to start-bottom (right-bottom in RTL — matches the
          // PositionedDirectional(start: …, bottom: …) outer placement).
          PositionedDirectional(
            start: 0,
            bottom: 0,
            width: _fabSize,
            height: _fabSize,
            child: _FabButton(isOpen: isOpen, onTap: onToggle),
          ),
          // Radial actions sweep into the upper-trailing quadrant.
          if (isOpen) ..._buildRadial(),
        ],
      ),
    );
  }

  List<Widget> _buildRadial() {
    final n = actions.length;
    if (n == 0) return const [];
    final widgets = <Widget>[];
    // FAB centre in the SizedBox's local coords (using start/bottom logical
    // edges so it follows RTL).
    const fabHalf = _fabSize / 2;
    // Sweep angle: 180°→270° in Stack/screen coords, where 0°=+x(right) and
    // 90°=+y(down). 180°=straight-left, 270°=straight-up. This fans items
    // into the upper-trailing quadrant relative to the FAB centre.
    //
    // We use start/bottom offsets (in directional coords) so RTL flips
    // automatically: start = right in RTL, end = left in RTL.
    //   • dxStart  = horizontal distance from FAB centre toward the trailing
    //                edge (= toward the screen interior in RTL).
    //   • dyBottom = vertical distance upward from the FAB centre.
    final isMulti = n > 1;
    for (var i = 0; i < n; i++) {
      final t = isMulti ? (i / (n - 1)) : 0.5;
      final degrees = 180 + (t * 90);
      final rad = degrees * math.pi / 180.0;
      // cos(180..270) ∈ [-1, 0]  → distance into the trailing direction
      // sin(180..270) ∈ [0, -1]  → distance upward
      final dxStart = -math.cos(rad) * _radius; // 0 → _radius (trailing)
      final dyBottom = -math.sin(rad) * _radius; // 0 → _radius (upward)
      // Item centre in local coords from FAB centre.
      final start = fabHalf + dxStart - (_itemSize / 2);
      final bottom = fabHalf + dyBottom - (_itemSize / 2);
      widgets.add(
        PositionedDirectional(
          start: start,
          bottom: bottom,
          width: _itemSize,
          height: _itemSize,
          child: _RadialItem(
            item: actions[i],
            onTap: () => onAction(actions[i].route),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ── FAB button ──

class _FabButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _FabButton({required this.isOpen, required this.onTap});

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final baseAlpha = _hover ? 0.55 : 0.40;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Coloured glow underneath — bigger and softer than before so
            // the orb feels lit from within rather than stamped on.
            boxShadow: [
              BoxShadow(
                color: AC.gold.withValues(alpha: _hover ? 0.55 : 0.35),
                blurRadius: _hover ? 36 : 24,
                spreadRadius: _hover ? 2 : 1,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AC.purple.withValues(alpha: _hover ? 0.30 : 0.18),
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(-6, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(children: [
                // Base liquid glass — diagonal gradient, more transparent
                // than before so the underlying screen colour bleeds.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AC.gold.withValues(alpha: baseAlpha + 0.10),
                          AC.gold.withValues(alpha: baseAlpha - 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                // Specular highlight — the diagonal "shine" of a glass orb
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment(0.0, -0.2),
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Outer rim — thin gradient border (warm gold → purple shift)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                // Plus icon (rotates to X when open)
                Center(
                  child: AnimatedRotation(
                    turns: widget.isOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.add_rounded,
                      color: AC.btnFg,
                      size: 28,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialItem extends StatefulWidget {
  final ApexSubItemRef item;
  final VoidCallback onTap;
  const _RadialItem({required this.item, required this.onTap});

  @override
  State<_RadialItem> createState() => _RadialItemState();
}

class _RadialItemState extends State<_RadialItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _a;
  bool _hover = false;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..forward();
    _a = CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _a,
      child: FadeTransition(
        opacity: _a,
        child: Tooltip(
          message: widget.item.label,
          preferBelow: false,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hover
                          ? AC.gold.withValues(alpha: 0.78)
                          : AC.surface.withValues(alpha: 0.78),
                      border: Border.all(
                        color: AC.gold.withValues(alpha: 0.55),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.item.icon,
                      color: _hover ? AC.btnFg : AC.gold,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _QuickSearchDialog — tiny Cmd+K palette over all sub-items
// ═══════════════════════════════════════════════════════════════════════════

class _QuickSearchDialog extends StatefulWidget {
  const _QuickSearchDialog();

  @override
  State<_QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<_QuickSearchDialog> {
  final _ctl = TextEditingController();
  String _q = '';

  List<(String app, ApexSubItemRef item)> get _all {
    final out = <(String, ApexSubItemRef)>[];
    for (final app in kApexApps) {
      for (final cat in app.categories) {
        for (final it in cat.items) {
          out.add((app.label, it));
        }
      }
    }
    for (final p in kApexPinned) {
      out.add(('عام', p));
    }
    return out;
  }

  List<(String, ApexSubItemRef)> get _filtered {
    final all = _all;
    if (_q.isEmpty) return all;
    final q = _q.toLowerCase();
    return all.where((p) {
      return p.$2.label.toLowerCase().contains(q) ||
          p.$2.route.toLowerCase().contains(q) ||
          p.$1.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AC.sidebarBorder),
      ),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 540),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          TextField(
            controller: _ctl,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim()),
            style: TextStyle(color: AC.sidebarItemFg, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن أي شاشة، أداة، أو إجراء…',
              hintStyle:
                  TextStyle(color: AC.sidebarItemDim, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AC.gold),
              filled: true,
              fillColor: AC.sidebarBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
                            color: AC.sidebarItemDim, fontSize: 13)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final (appLabel, it) = list[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.go(it.route);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          margin:
                              const EdgeInsets.symmetric(vertical: 1),
                          child: Row(children: [
                            Icon(it.icon, color: AC.gold, size: 17),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(it.label,
                                      style: TextStyle(
                                          color: AC.sidebarItemFg,
                                          fontSize: 13)),
                                  Text(appLabel,
                                      style: TextStyle(
                                          color: AC.sidebarItemDim,
                                          fontSize: 10.5)),
                                ],
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
          Row(children: [
            Icon(Icons.keyboard_rounded,
                color: AC.sidebarItemDim, size: 13),
            const SizedBox(width: 6),
            Text('Ctrl+K / Cmd+K',
                style:
                    TextStyle(color: AC.sidebarItemDim, fontSize: 10)),
            const Spacer(),
            Text('${list.length} نتيجة',
                style:
                    TextStyle(color: AC.sidebarItemDim, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}
