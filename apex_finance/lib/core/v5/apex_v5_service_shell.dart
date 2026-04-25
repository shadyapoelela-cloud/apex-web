/// APEX V5.1 — Service Shell (main layout).
///
/// This is the top-level wrapper when the user is inside a service.
/// Structure:
///   ┌────────────────────────────────────────────────────────────┐
///   │ [9-dots] APEX • ERP > Finance    [News Ticker]   [🔔 👤]  │ ← top bar
///   ├───────────┬────────────────────────────────────────────────┤
///   │ ⓘ CFO ▼   │ Chips: [📊 لوحة] | GL | AR | AP | Budgets | ...│ ← chip row
///   │           ├────────────────────────────────────────────────┤
///   │ 📊 Finance│                                                │
///   │ 👥 HR     │                                                │
///   │ 📦 Ops    │   Dashboard widgets / Tabs content             │
///   │ 🏦 Treas. │                                                │
///   └───────────┴────────────────────────────────────────────────┘
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart' as core_theme;
import '../../providers/app_providers.dart';
import '../../screens/extracted/client_screens.dart' show ClientListScreen;
import '../../screens/settings/entity_setup_screen.dart'
    show EntitySetupScreen;
import 'apex_v5_action_dashboard.dart';
import 'apex_v5_news_ticker.dart';
import 'apex_v5_workspace_selector.dart';
import 'cmd_k_palette.dart';
import '../../pilot/tenant_chip.dart';
import 'templates/quick_create.dart';
import 'templates/unified_inbox.dart';
import 'v5_models.dart';

/// Sidebar collapse preference — مخزَّنة في localStorage عبر التنقل.
class SidebarPrefs {
  static const _key = 'sidebar_collapsed';
  static final ValueNotifier<bool> collapsed = ValueNotifier<bool>(_load());

  static bool _load() {
    try {
      return html.window.localStorage[_key] == '1';
    } catch (_) {
      return false;
    }
  }

  static void toggle() {
    collapsed.value = !collapsed.value;
    try {
      html.window.localStorage[_key] = collapsed.value ? '1' : '0';
    } catch (_) {}
  }
}

class ApexV5ServiceShell extends ConsumerWidget {
  final V5Service service;
  /// Active main module — null when the shell wraps the Apps Hub.
  final V5MainModule? mainModule;
  /// Active chip — null when in Apps Hub mode.
  final V5Chip? activeChip;

  /// Body builder for non-dashboard chips. If null and chip has a
  /// V4SubModule, defaults to ApexSubModuleShell. If null and no
  /// sub-module, shows "coming soon" host.
  final Widget Function(BuildContext ctx, V5Chip chip)? chipBodyBuilder;

  /// Override body entirely (used for Apps Hub). When provided, overrides
  /// the chip-based body logic.
  final Widget? bodyOverride;

  const ApexV5ServiceShell({
    super.key,
    required this.service,
    this.mainModule,
    this.activeChip,
    this.chipBodyBuilder,
    this.bodyOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsProvider); // rebuild on theme/mode switch
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 900;
    final isMedium = width < 1024; // نُخفي Quick-Access rail أقل من هذا

    // Apps Hub mode = bare chrome (SystemBar + ScreenBar only).
    // Module screens get the full experience: + ticker + sidebar + rail.
    final isAppsHub = mainModule == null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            CmdKPalette.show(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            CmdKPalette.show(context),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          // Close expanded sidebar if it's open as overlay.
          if (!SidebarPrefs.collapsed.value) {
            SidebarPrefs.collapsed.value = true;
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(children: [
            // ── UNIFIED TOP BAR (56px) — 10R research synthesis ────────
            // Consolidates the old 3-layer stack (SystemBar 40 +
            // NewsTicker 32 + ScreenBar 48 = 120px) into a single
            // horizontal bar, matching SAP Fiori / Microsoft 365 /
            // Zoho One / Salesforce Lightning / Linear patterns.
            // News ticker reachable via notification bell "announcements"
            // section on demand.
            _UnifiedTopBar(
              service: service,
              mainModule: mainModule,
              activeChip: activeChip,
              unreadCount: _getUnreadCount(ref),
            ),
            const Divider(height: 1),
            // ── Layer 4: Body ──────────────────────────────────────────
            // 10R research: sidebar uses OVERLAY mode when expanded, not
            // inline-push. This fixes the user-reported "expanded sidebar
            // covers content" issue. Patterns applied:
            //   • Fluent 2 inline-drawer → overlay on <640px breakpoint
            //   • Material 3 modal navigation rail
            //   • Linear / Notion drawer-over-content on expand
            // Inline: always a compact 64px rail (persistent quick-nav).
            // Expanded: floats as drawer over content + scrim.
            Expanded(
              // Sidebar is always INLINE — collapses/expands in place and
              // the body area auto-grows/shrinks via Expanded. No overlay,
              // no scrim, no dual-layer. The toggle (طيّ/توسيع) at the
              // bottom of the sidebar is the only collapse control.
              child: isAppsHub || isNarrow
                  ? Column(children: [Expanded(child: _buildBody(context))])
                  : ValueListenableBuilder<bool>(
                      valueListenable: SidebarPrefs.collapsed,
                      builder: (_, collapsed, __) => Row(children: [
                        AnimatedContainer(
                          duration: core_theme.DS.motionMed,
                          curve: Curves.easeInOutCubic,
                          width: collapsed ? 64 : 264,
                          child: _Sidebar(
                            service: service,
                            activeMainId: mainModule?.id ?? '',
                            isCollapsed: collapsed,
                          ),
                        ),
                        VerticalDivider(
                            width: 1, color: core_theme.AC.sidebarBorder),
                        Expanded(child: _buildBody(context)),
                        if (!isMedium)
                          VerticalDivider(
                              width: 1, color: core_theme.AC.sidebarBorder),
                        if (!isMedium) const _QuickAccessRail(),
                      ]),
                    ),
            ),
          ]),
          drawer: (!isAppsHub && isNarrow)
              ? Drawer(
                  child: _Sidebar(
                    service: service,
                    activeMainId: mainModule?.id ?? '',
                    isCollapsed: false,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  int _getUnreadCount(WidgetRef ref) => 8; // TODO: wire to real provider

  /// Router that picks between body override (Apps Hub) and chip-based body.
  Widget _buildBody(BuildContext context) {
    // Apps Hub / custom override mode — render the caller-provided body.
    if (bodyOverride != null) return bodyOverride!;
    if (activeChip == null || mainModule == null) {
      // Defensive: without both we have nothing to render.
      return const SizedBox.shrink();
    }
    return _buildChipBody(context);
  }

  Widget _buildChipBody(BuildContext context) {
    final chip = activeChip!;
    final main = mainModule!;
    // Dashboard chip — render action dashboard
    if (chip.isDashboard) {
      if (chip.dashboardWidgets == null ||
          chip.dashboardWidgets!.isEmpty) {
        return _ComingSoonBanner(
          titleAr: chip.labelAr,
          subtitleAr: 'لوحة المعلومات قيد البناء — سترى KPIs حية قريباً',
          icon: Icons.dashboard,
        );
      }
      return ApexV5ActionDashboard(
        titleAr: chip.labelAr,
        subtitleAr: '${service.labelAr} · ${main.labelAr}',
        widgets: chip.dashboardWidgets!,
      );
    }

    // Caller-provided builder
    if (chipBodyBuilder != null) {
      return chipBodyBuilder!(context, chip);
    }

    // Standalone screen wiring — known chips that link to existing
    // standalone screens outside the V5 chip tree. Keeps a single
    // source of truth for these screens instead of duplicating logic.
    switch (chip.id) {
      case 'crm':
      case 'customers-360':
        // إدارة العملاء / العميل 360 → الشاشة الموحّدة للعملاء
        return const ClientListScreen();
      case 'entity-setup':
      case 'onboarding':
        // إعداد الكيانات/الشركات/الفروع + رحلة الإعداد (موحّدتان)
        return const EntitySetupScreen();
    }

    // V4 sub-module reuse — if chip has sub-module, render existing tabs
    final sub = chip.subModule;
    if (sub != null) {
      final firstScreen = sub.visibleTabs.isNotEmpty
          ? sub.visibleTabs.first
          : (sub.overflow.isNotEmpty ? sub.overflow.first : null);
      if (firstScreen != null) {
        // Find V4 group that contains this sub. Search by matching sub.id.
        return _V4SubModuleHost(
          subModule: sub,
          activeScreen: firstScreen,
        );
      }
    }

    // Fallback — coming soon banner
    return _ComingSoonBanner(
      titleAr: chip.labelAr,
      subtitleAr: 'هذه الشاشة قيد التطوير',
      icon: chip.icon,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Top Bar
// ──────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════
// _TB — Top Bar Design Tokens (Batch A: 20 color/size/motion tokens)
// مصدر واحد للحقيقة لكل ألوان وأبعاد الشريط العلوي — يمنع التناقض.
// ══════════════════════════════════════════════════════════════════════════

// ignore_for_file: unused_element, unused_field
class _TB {
  _TB._();
  // ── Colors (WCAG AA compliant) ───────────────────────────────────────
  static Color get bg => core_theme.AC.topBarBg;
  static Color get fgPrimary => core_theme.AC.topBarFg;
  static Color get fgSecondary => core_theme.AC.topBarFgDim;
  static Color get fgMuted => core_theme.AC.topBarFgDim.withValues(alpha: 0.7);
  static Color get accent => core_theme.AC.topBarAccent;
  static Color get border => core_theme.AC.topBarBorder;
  static Color get surfaceElevated => core_theme.AC.navy2;
  static Color get surfaceRaised => core_theme.AC.navy3;
  static Color get danger => core_theme.AC.err;
  static Color get success => core_theme.AC.ok;
  static Color get warn => core_theme.AC.warn;

  // Hover / active overlays (alpha on white for dark surfaces)
  static Color get hoverOverlay => Colors.white.withValues(alpha: 0.06);
  static Color get pressOverlay => Colors.white.withValues(alpha: 0.10);
  static Color get accentHoverBg => accent.withValues(alpha: 0.10);
  static Color get accentActiveBg => accent.withValues(alpha: 0.15);

  // ── G-11..G-20: tokens rewired to DS (Design System) for harmony ─────
  // Single source of truth for all size/space/motion tokens is core_theme.DS.
  // _TB.* are now aliases to DS, so topbar stays in sync with the rest of
  // the shell (sidebar/rail/tabs) automatically.
  static const double barHeight = core_theme.DS.sidebarRow + 12;        // legacy (topbar+ticker combined)
  static const double tapTarget = core_theme.DS.barSystem;               // 40 (WCAG min + room)
  static const double iconSm = core_theme.DS.iconSm;                     // 14
  static const double iconMd = core_theme.DS.iconLg;                     // 20 (was 18 — aligned to DS.iconLg)

  // Spacing — DS grid (aliased)
  static const double sp1 = core_theme.DS.s1;  // 4
  static const double sp2 = 6;                  // kept for micro-rhythm (e.g. badge offsets)
  static const double sp3 = core_theme.DS.s2;  // 8
  static const double sp4 = 10;                 // kept for label gaps
  static const double sp5 = core_theme.DS.s3;  // 12
  static const double sp6 = core_theme.DS.s4;  // 16

  // Border radii — DS (aligned)
  static const double rSm = core_theme.DS.rSm;    // 4 (was 6)
  static const double rMd = core_theme.DS.rMd;    // 8
  static const double rLg = core_theme.DS.rLg;    // 12 (was 10 — M3 standard)
  static const double rPill = core_theme.DS.rPill; // 999 (was 20 — true pill)
  static BorderRadius get brSm => BorderRadius.circular(rSm);
  static BorderRadius get brMd => BorderRadius.circular(rMd);
  static BorderRadius get brLg => BorderRadius.circular(rLg);
  static BorderRadius get brPill => BorderRadius.circular(rPill);

  // Typography scale — aligned to DS
  static const double fs10 = core_theme.DS.fsXs;  // 10
  static const double fs11 = core_theme.DS.fsSm;  // 11
  static const double fs12 = core_theme.DS.fsMd;  // 12.5 (was 12 — half-pixel for crispness)
  static const double fs13 = core_theme.DS.fsLg;  // 14 (was 13 — standard body)
  static const double fs16 = core_theme.DS.fsXl;  // 16

  // Motion — DS (Material 3)
  static const Duration motionFast = core_theme.DS.motionFast;  // 120
  static const Duration motionMed = core_theme.DS.motionMed;    // 200 (was 180)
  static const Duration motionSlow = core_theme.DS.motionSlow;  // 320 (was 240 — for longer state changes)
  static const Duration pulseDur = Duration(milliseconds: 1200);
  static const Duration tooltipWait = core_theme.DS.tooltipWait;

  // Shadows
  static List<BoxShadow> get barShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
  static List<BoxShadow> get menuShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // Common text styles
  static TextStyle get tsNav => TextStyle(
      fontSize: fs12, fontWeight: FontWeight.w600, color: fgPrimary);
  static TextStyle get tsMuted =>
      TextStyle(fontSize: fs11, color: fgSecondary);
  static TextStyle get tsBadge => const TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w800);

  // Common MenuStyle used everywhere
  static MenuStyle menuStyle() => MenuStyle(
        backgroundColor: WidgetStateProperty.all(surfaceElevated),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: brLg,
          side: BorderSide(color: border),
        )),
        padding: WidgetStateProperty.all(
            const EdgeInsetsDirectional.symmetric(vertical: 4)),
        elevation: WidgetStateProperty.all(8),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// TopBar — ٥٠ تحسيناً على شريط العنوان
//
// Wave 1 — البنية (#1-10): استخراج مكوّنات (_TopBarIconBtn, _NotifBadge,
//   _BrandLogo, _TopBarDivider, _AvatarMenu, _ThemeBtn, _LangBtn,
//   _OnlineDot, _HomeBtn) + تقليل الـ Builder + كسر build لدوال أصغر.
// Wave 2 — Accessibility (#11-20): Semantics لكل زر + min tap 48×48 +
//   tooltip مستمر 500ms + focus highlight + Escape handler + ARIA header.
// Wave 3 — Visual (#21-30): Hover scale + ripple + badge pulse + active
//   indicator + gradient logo + shadow + rounded + icon-size grid +
//   spacing grid + transitions.
// Wave 4 — Responsive (#31-40): Breakpoints sm/md/lg + TextScaler clamp +
//   "9+" badge + sticky shadow + Home button + compact mode + breadcrumb
//   menu على الشاشات الضيقة + text truncation + DPI-aware logo.
// Wave 5 — Features (#41-50): Profile popover + notifications popover +
//   theme toggle + language switcher + online indicator + recent items +
//   platform-aware shortcut (⌘/Ctrl) + quick actions + help link.
// ══════════════════════════════════════════════════════════════════════════


// ══════════════════════════════════════════════════════════════════════════
// Layer 1 — _SystemBar (40px) — branded, system-level tools
// إلهام: SAP Fiori Shell, Odoo 17, Microsoft 365 app bar
// يحتوي: Brand + Global search + Theme/Lang + Help + PWA install +
//        Notifications + Avatar
// ══════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════
// _UnifiedTopBar — single-bar consolidation (10R research)
// Replaces _SystemBar + _ScreenBar (and the standalone NewsTicker) with
// ONE 56px horizontal bar, following SAP Fiori Shell Bar + Zoho One
// unified launcher patterns.
//
// Layout (RTL):
//   [app-switcher] [logo] [breadcrumb ...]          [+ create] [tenant]
//                                                   [⌘K] [🌐] [🌙] [🔔] [👤]
//
// Responsive collapse:
//   < 720px  → hide app-switcher, compact breadcrumb, tenant-icon-only
//   < 900px  → hide language/theme toggles (accessible via avatar menu)
// ══════════════════════════════════════════════════════════════════════════
class _UnifiedTopBar extends StatelessWidget {
  final V5Service service;
  final V5MainModule? mainModule;
  final V5Chip? activeChip;
  final int unreadCount;

  const _UnifiedTopBar({
    required this.service,
    required this.unreadCount,
    this.mainModule,
    this.activeChip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;
    final isMedium = width < 900;
    final isAppsHub = mainModule == null;

    final parts = <_BreadcrumbPart>[
      _BreadcrumbPart(
          label: service.labelAr,
          route: '/app/${service.id}',
          icon: service.icon,
          color: _TB.accent),
      if (isAppsHub)
        _BreadcrumbPart(
            label: '${service.mainModules.length} تطبيق',
            route: null,
            icon: Icons.apps_rounded)
      else ...[
        _BreadcrumbPart(
            label: mainModule!.labelAr,
            route: '/app/${service.id}/${mainModule!.id}',
            icon: mainModule!.icon),
        if (activeChip != null)
          _BreadcrumbPart(
              label: activeChip!.labelAr,
              route: null,
              icon: activeChip!.icon),
      ],
    ];

    return Semantics(
      container: true,
      label: 'الشريط العلوي الموحّد',
      child: Container(
        height: 56,
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: _TB.sp3),
        decoration: BoxDecoration(
          color: _TB.bg,
          border: Border(bottom: BorderSide(color: _TB.border)),
          boxShadow: _TB.barShadow,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: _TB.fgPrimary, size: _TB.iconMd),
          child: DefaultTextStyle.merge(
            style: _TB.tsNav,
            child: FocusTraversalGroup(
              child: Row(children: [
                // ── Leading: app-switcher + logo ──────────────
                if (!isCompact) const _AppSwitcherButton(),
                if (!isCompact) const SizedBox(width: _TB.sp2),
                const _BrandLogo(),
                const SizedBox(width: _TB.sp3),
                // subtle divider between brand and breadcrumb
                Container(
                    width: 1,
                    height: 24,
                    color: _TB.border.withValues(alpha: 0.7)),
                const SizedBox(width: _TB.sp3),
                // ── Center: breadcrumb (flex) ─────────────────
                Flexible(
                  fit: FlexFit.loose,
                  child: isCompact
                      ? _CompactBreadcrumb(parts: parts)
                      : _Breadcrumb(parts: parts),
                ),
                const SizedBox(width: _TB.sp3),
                const Spacer(),
                // ── Trailing: actions cluster ─────────────────
                if (!isCompact) const QuickCreateButton(),
                if (!isCompact) const SizedBox(width: _TB.sp2),
                const TenantChip(),
                const SizedBox(width: _TB.sp2),
                if (width >= 1024) const ApexV5WorkspaceSelector(),
                if (width >= 1024) const SizedBox(width: _TB.sp2),
                Container(
                    width: 1,
                    height: 24,
                    color: _TB.border.withValues(alpha: 0.7)),
                const SizedBox(width: _TB.sp2),
                const _CmdKButton(),
                if (!isMedium) const SizedBox(width: _TB.sp1),
                if (!isMedium) const _LangToggleBtn(),
                if (!isMedium) const _ThemeToggleBtn(),
                if (!isCompact)
                  _TopBarIconBtn(
                    icon: Icons.help_outline,
                    tooltip: 'المساعدة (Shift+/)',
                    semanticLabel: 'فتح المساعدة',
                    onPressed: (ctx) => _SystemBar._showHelpDialog(ctx),
                  ),
                const _PwaInstallBtn(),
                _NotifBellButton(count: unreadCount),
                const _AvatarMenu(online: true),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemBar extends StatelessWidget {
  final int unreadCount;
  const _SystemBar({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;
    return Semantics(
      container: true,
      label: 'شريط النظام',
      child: Container(
        height: 40,
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: _TB.sp3),
        decoration: BoxDecoration(
          color: _TB.bg,
          border: Border(bottom: BorderSide(color: _TB.border)),
          boxShadow: _TB.barShadow,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: _TB.fgPrimary, size: _TB.iconMd),
          child: DefaultTextStyle.merge(
            style: _TB.tsNav,
            child: FocusTraversalGroup(
              child: Row(children: [
                // App-switcher (9-dots)
                if (!isCompact)
                  const _AppSwitcherButton(),
                const SizedBox(width: _TB.sp3),
                const _BrandLogo(),
                const Spacer(),
                // Right cluster (ends)
                const _CmdKButton(),
                const SizedBox(width: _TB.sp1),
                const _LangToggleBtn(),
                const _ThemeToggleBtn(),
                if (!isCompact)
                  _TopBarIconBtn(
                    icon: Icons.help_outline,
                    tooltip: 'المساعدة (Shift+/)',
                    semanticLabel: 'فتح المساعدة',
                    onPressed: (ctx) => _showHelpDialog(ctx),
                  ),
                const _PwaInstallBtn(),
                _NotifBellButton(count: unreadCount),
                const _AvatarMenu(online: true),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  static void _showHelpDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختصارات لوحة المفاتيح',
              style: TextStyle(fontSize: _TB.fs16, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _HelpRow(keys: 'Ctrl+K', desc: 'فتح مستكشف الأوامر'),
                _HelpRow(keys: 'Ctrl+\\', desc: 'طي/توسيع الشريط الجانبي'),
                _HelpRow(keys: 'Esc', desc: 'إغلاق القائمة/الحوار المفتوح'),
                _HelpRow(keys: 'E', desc: 'تعديل الاسم (في شجرة الحسابات)'),
                _HelpRow(keys: 'C', desc: 'تعديل الكود'),
                _HelpRow(keys: '/', desc: 'التركيز على حقل البحث'),
                _HelpRow(keys: 'Shift+/', desc: 'فتح هذه القائمة'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }
}

/// 9-dots app-switcher button.
class _AppSwitcherButton extends StatelessWidget {
  const _AppSwitcherButton();
  @override
  Widget build(BuildContext context) => _TopBarIconBtn(
        icon: Icons.apps,
        tooltip: 'مبدّل التطبيقات',
        semanticLabel: 'فتح مبدّل التطبيقات',
        onPressed: (ctx) => ctx.go('/app'),
      );
}

/// PWA install button — يظهر فقط حين يكون التطبيق قابلاً للتثبيت.
class _PwaInstallBtn extends StatefulWidget {
  const _PwaInstallBtn();
  @override
  State<_PwaInstallBtn> createState() => _PwaInstallBtnState();
}

class _PwaInstallBtnState extends State<_PwaInstallBtn> {
  bool _canInstall = false;
  bool _isStandalone = false;

  @override
  void initState() {
    super.initState();
    // استخدم microtask + عدة محاولات لأن beforeinstallprompt قد يكون أُطلق قبل mount
    Future.microtask(_syncFromJs);
    Future.delayed(const Duration(milliseconds: 500), _syncFromJs);
    Future.delayed(const Duration(seconds: 2), _syncFromJs);
    html.window.addEventListener('apex:pwa-changed', _onPwaChanged);
  }

  @override
  void dispose() {
    html.window.removeEventListener('apex:pwa-changed', _onPwaChanged);
    super.dispose();
  }

  void _onPwaChanged(html.Event _) => _syncFromJs();

  void _syncFromJs() {
    try {
      final canInstall =
          js_util.callMethod(html.window, 'apexCanInstall', []) == true;
      final isStandalone =
          js_util.callMethod(html.window, 'apexIsStandalone', []) == true;
      if (mounted &&
          (_canInstall != canInstall || _isStandalone != isStandalone)) {
        setState(() {
          _canInstall = canInstall;
          _isStandalone = isStandalone;
        });
      }
    } catch (e) {
      debugPrint('[APEX] PWA sync error: $e');
    }
  }

  void _triggerInstall() {
    try {
      final result =
          js_util.callMethod(html.window, 'apexPromptInstall', []);
      debugPrint('[APEX] apexPromptInstall result: $result');
      if (result != 'prompted') {
        // beforeinstallprompt لم يُلتقط → نعرض تعليمات يدوية
        _showManualHint();
      }
    } catch (e) {
      debugPrint('[APEX] install error: $e');
      _showManualHint();
    }
  }

  void _showManualHint() {
    if (!mounted) return;
    // نستخدم ألوان الـ Theme الحالي (وليس _TB الخاص بالشريط الداكن) —
    // الحوار يظهر فوق خلفية الشاشة، سواء light أو dark.
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final onSurface = theme.colorScheme.onSurface;
        final muted = onSurface.withValues(alpha: 0.72);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(children: [
              Icon(Icons.install_desktop,
                  color: _TB.accent, size: 22),
              const SizedBox(width: 10),
              Text('تثبيت APEX كتطبيق سطح مكتب',
                  style: TextStyle(
                      color: onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ]),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لم يُطلق المتصفح حدث التثبيت التلقائي. هذا يحدث عادةً عندما:',
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Text('• فتحت الصفحة للتو — جرّب تحديث الصفحة (F5)',
                      style: TextStyle(color: muted, fontSize: 12)),
                  Text('• التطبيق مُثبَّت بالفعل من جلسة سابقة',
                      style: TextStyle(color: muted, fontSize: 12)),
                  Text('• رفضت التثبيت سابقاً في هذه الجلسة',
                      style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _TB.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _TB.accent.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.check_circle,
                              size: 16, color: _TB.accent),
                          const SizedBox(width: 6),
                          Text('الطريقة الأسهل:',
                              style: TextStyle(
                                  color: _TB.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                            '١. انظر إلى يسار شريط العنوان (بجانب النجمة ⭐)\n'
                            '٢. ستجد أيقونة تثبيت 💻 أو سهم ⬇️ — اضغطها\n'
                            '٣. اضغط "تثبيت" في النافذة المنبثقة',
                            style: TextStyle(
                                color: onSurface,
                                fontSize: 12.5,
                                height: 1.7)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('أو: ⋯ → "التطبيقات" → "تثبيت هذا الموقع كتطبيق"',
                      style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  html.window.location.reload();
                },
                child: const Text('إعادة تحميل الصفحة'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                    backgroundColor: _TB.accent,
                    foregroundColor: Colors.black),
                child: const Text('فهمت'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // لا نُظهر الزر إن كنا بالفعل في وضع standalone (مثبّت)
    if (_isStandalone) return const SizedBox.shrink();
    // نُظهر الزر دائماً (حتى لو canInstall=false) — عند الضغط نوجّه للتثبيت اليدوي
    return _TopBarIconBtn(
      icon: Icons.install_desktop,
      tooltip: _canInstall
          ? 'تثبيت APEX كتطبيق سطح مكتب'
          : 'تثبيت APEX (عبر قائمة المتصفح)',
      semanticLabel: 'تثبيت التطبيق',
      color: _canInstall ? _TB.accent : _TB.fgPrimary,
      onPressed: (_) => _triggerInstall(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Layer 3 — _ScreenBar (48px) — screen context + actions
// يحتوي: Breadcrumb + QuickCreate + Company (TenantChip) + Workspace
// ══════════════════════════════════════════════════════════════════════════

class _ScreenBar extends StatelessWidget {
  final V5Service service;
  final V5MainModule? mainModule;
  final V5Chip? activeChip;

  const _ScreenBar({
    required this.service,
    this.mainModule,
    this.activeChip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;
    // Apps Hub mode: only service → "التطبيقات" (no module/chip yet).
    final isAppsHub = mainModule == null;
    final parts = <_BreadcrumbPart>[
      _BreadcrumbPart(
          label: service.labelAr,
          route: '/app/${service.id}',
          icon: service.icon,
          color: _TB.accent),
      if (isAppsHub)
        _BreadcrumbPart(
            label: '${service.mainModules.length} تطبيق',
            route: null,
            icon: Icons.apps_rounded)
      else ...[
        _BreadcrumbPart(
            label: mainModule!.labelAr,
            route: '/app/${service.id}/${mainModule!.id}',
            icon: mainModule!.icon),
        if (activeChip != null)
          _BreadcrumbPart(
              label: activeChip!.labelAr,
              route: null,
              icon: activeChip!.icon),
      ],
    ];
    return Container(
      height: 48,
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: _TB.sp3),
      decoration: BoxDecoration(
        color: _TB.surfaceElevated,
        border: Border(bottom: BorderSide(color: _TB.border)),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: _TB.fgPrimary, size: _TB.iconMd),
        child: DefaultTextStyle.merge(
          style: _TB.tsNav,
          child: Row(children: [
            if (isCompact)
              Flexible(child: _CompactBreadcrumb(parts: parts))
            else
              Flexible(child: _Breadcrumb(parts: parts)),
            const Spacer(),
            if (!isCompact) const QuickCreateButton(),
            if (!isCompact) const SizedBox(width: _TB.sp3),
            const TenantChip(),
            const SizedBox(width: _TB.sp3),
            if (width >= 1024) const ApexV5WorkspaceSelector(),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Layer 4 (right rail) — _QuickAccessRail
// اختصارات للشاشات الأكثر استخداماً للمستخدم — تُحفظ في localStorage
// ══════════════════════════════════════════════════════════════════════════

/// Pinned shortcut entry.
class _Pin {
  final String id;
  final String labelAr;
  final IconData icon;
  final String route;
  const _Pin({
    required this.id,
    required this.labelAr,
    required this.icon,
    required this.route,
  });
}

class QuickAccessPrefs {
  static const _key = 'apex_quick_access_v1';
  static final ValueNotifier<List<String>> pinnedIds = ValueNotifier(_load());

  static List<String> _load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return _defaultPins;
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return _defaultPins;
    }
  }

  static void setPins(List<String> ids) {
    pinnedIds.value = List.of(ids);
    try {
      html.window.localStorage[_key] = ids.join(',');
    } catch (_) {/* silent */}
  }

  static void toggle(String id) {
    final list = List<String>.of(pinnedIds.value);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    setPins(list);
  }

  static const _defaultPins = [
    'coa',
    'je',
    'tb',
    'financial_reports',
    'journal',
  ];
}

const _kAllPins = <_Pin>[
  _Pin(
      id: 'coa',
      labelAr: 'شجرة الحسابات',
      icon: Icons.account_tree,
      route: '/app/erp/finance/coa-editor'),
  _Pin(
      id: 'je',
      labelAr: 'قيد يومي',
      icon: Icons.edit_note,
      route: '/app/erp/finance/je-builder'),
  _Pin(
      id: 'tb',
      labelAr: 'ميزان المراجعة',
      icon: Icons.table_chart,
      route: '/app/erp/finance/trial-balance'),
  _Pin(
      id: 'financial_reports',
      labelAr: 'القوائم المالية',
      icon: Icons.bar_chart,
      route: '/app/erp/finance/statements'),
  _Pin(
      id: 'journal',
      labelAr: 'دفتر الأستاذ',
      icon: Icons.menu_book,
      route: '/app/erp/finance/gl'),
  _Pin(
      id: 'vat',
      labelAr: 'ضريبة القيمة المضافة',
      icon: Icons.receipt_long,
      route: '/app/erp/finance/vat'),
  _Pin(
      id: 'fixed_assets',
      labelAr: 'الأصول الثابتة',
      icon: Icons.apartment,
      route: '/app/erp/finance/fixed-assets'),
  _Pin(
      id: 'budgets',
      labelAr: 'الموازنات',
      icon: Icons.savings,
      route: '/app/erp/finance/budgets'),
  _Pin(
      id: 'clients',
      labelAr: 'العملاء',
      icon: Icons.groups,
      route: '/app/erp/sales/customers'),
  _Pin(
      id: 'vendors',
      labelAr: 'الموردون',
      icon: Icons.local_shipping,
      route: '/app/erp/purchase/vendors'),
];

class _QuickAccessRail extends StatefulWidget {
  const _QuickAccessRail();
  @override
  State<_QuickAccessRail> createState() => _QuickAccessRailState();
}

class _QuickAccessRailState extends State<_QuickAccessRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _TB.motionMed,
      curve: Curves.easeOutCubic,
      width: _expanded ? 220 : 56,
      decoration: BoxDecoration(
        color: _TB.surfaceElevated,
        border: Border(
          // End side = left in LTR, right in RTL → we want separator on CONTENT side.
          // In RTL شريط على اليمين، الفاصل على شماله (start).
          left: BorderSide(color: _TB.border),
          right: BorderSide(color: _TB.border),
        ),
      ),
      child: ValueListenableBuilder<List<String>>(
        valueListenable: QuickAccessPrefs.pinnedIds,
        builder: (_, pinIds, __) {
          final pins = pinIds
              .map((id) => _kAllPins.firstWhere((p) => p.id == id,
                  orElse: () => const _Pin(
                      id: '',
                      labelAr: '',
                      icon: Icons.help,
                      route: '')))
              .where((p) => p.id.isNotEmpty)
              .toList();
          return Column(children: [
            _toggleButton(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final p in pins) _pinTile(p),
                  const Divider(height: 16),
                  _addPinMenu(),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _toggleButton() {
    return Tooltip(
      message: _expanded ? 'طي الوصول السريع' : 'توسيع الوصول السريع',
      waitDuration: _TB.tooltipWait,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          height: 44,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: _expanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              Icon(Icons.push_pin_outlined,
                  size: _TB.iconMd, color: core_theme.AC.gold),
              if (_expanded) ...[
                const SizedBox(width: _TB.sp2),
                Expanded(
                  child: Text('الوصول السريع',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: core_theme.AC.tp,
                          fontSize: _TB.fs12,
                          fontWeight: FontWeight.w800)),
                ),
                Icon(Icons.chevron_right,
                    size: _TB.iconSm, color: core_theme.AC.ts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pinTile(_Pin p) {
    return Tooltip(
      message: _expanded ? '' : p.labelAr,
      waitDuration: _TB.tooltipWait,
      child: InkWell(
        onTap: () => context.go(p.route),
        onLongPress: () => QuickAccessPrefs.toggle(p.id),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: _expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(p.icon, size: _TB.iconMd, color: core_theme.AC.ts),
              if (_expanded) ...[
                const SizedBox(width: _TB.sp3),
                Expanded(
                  child: Text(p.labelAr,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          color: core_theme.AC.tp,
                          fontSize: _TB.fs12,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPinMenu() {
    return MenuAnchor(
      style: _TB.menuStyle(),
      alignmentOffset: const Offset(_TB.sp3, 0),
      builder: (_, ctrl, __) => Tooltip(
        message: 'إضافة اختصار',
        waitDuration: _TB.tooltipWait,
        child: InkWell(
          onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: _expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: _TB.iconMd, color: _TB.accent),
                if (_expanded) ...[
                  const SizedBox(width: _TB.sp3),
                  Expanded(
                    child: Text('إضافة اختصار',
                        style: TextStyle(
                            color: _TB.accent,
                            fontSize: _TB.fs12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      menuChildren: [
        for (final p in _kAllPins)
          ValueListenableBuilder<List<String>>(
            valueListenable: QuickAccessPrefs.pinnedIds,
            builder: (_, pinIds, __) {
              final pinned = pinIds.contains(p.id);
              return MenuItemButton(
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(220, 36)),
                ),
                leadingIcon: Icon(p.icon,
                    size: _TB.iconSm,
                    color: pinned ? _TB.accent : _TB.fgSecondary),
                trailingIcon: pinned
                    ? Icon(Icons.check, size: _TB.iconSm, color: _TB.accent)
                    : null,
                onPressed: () => QuickAccessPrefs.toggle(p.id),
                child: Text(p.labelAr,
                    style: TextStyle(
                        color: pinned ? _TB.accent : _TB.fgPrimary,
                        fontWeight:
                            pinned ? FontWeight.w700 : FontWeight.w500,
                        fontSize: _TB.fs12)),
              );
            },
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TopBar — Extracted widgets (reused by SystemBar + ScreenBar)
// ══════════════════════════════════════════════════════════════════════════

/// Brand logo with hover + gradient + ripple.
class _BrandLogo extends StatefulWidget {
  const _BrandLogo();
  @override
  State<_BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<_BrandLogo> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'شعار APEX — الرجوع للصفحة الرئيسية',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => context.go('/app'),
          borderRadius: _TB.brMd,
          child: AnimatedContainer(
            duration: _TB.motionMed,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: _TB.sp2, vertical: _TB.sp1),
            decoration: BoxDecoration(
              color: _hover ? _TB.accentHoverBg : Colors.transparent,
              borderRadius: _TB.brMd,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                scale: _hover ? 1.10 : 1.0,
                duration: _TB.motionMed,
                child: Icon(Icons.bolt, size: _TB.iconMd, color: _TB.accent),
              ),
              const SizedBox(width: _TB.sp2),
              ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: [_TB.accent, _TB.accent.withValues(alpha: 0.85)],
                ).createShader(r),
                child: Text(
                  'APEX',
                  style: TextStyle(
                      fontSize: _TB.fs16,
                      fontWeight: FontWeight.w800,
                      color: _TB.fgPrimary,
                      letterSpacing: 0.5),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Vertical divider used throughout the top bar.
class _TopBarDivider extends StatelessWidget {
  const _TopBarDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 24, width: 1, color: _TB.border);
}

/// Shared icon button — tooltip + semantics + hover + token-based sizing.
class _TopBarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final void Function(BuildContext) onPressed;
  final Color? color;
  final bool active;
  const _TopBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.active = false,
  });
  @override
  State<_TopBarIconBtn> createState() => _TopBarIconBtnState();
}

class _TopBarIconBtnState extends State<_TopBarIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final activeBg = widget.active ? _TB.accentActiveBg : null;
    final hoverBg = _hover ? _TB.hoverOverlay : activeBg;
    return Builder(
      builder: (ctx) => Semantics(
        button: true,
        label: widget.semanticLabel,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: _TB.tooltipWait,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: () => widget.onPressed(ctx),
              borderRadius: _TB.brMd,
              child: AnimatedContainer(
                duration: _TB.motionFast,
                width: _TB.tapTarget,
                height: _TB.tapTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hoverBg ?? Colors.transparent,
                  borderRadius: _TB.brMd,
                ),
                child: AnimatedScale(
                  scale: _hover ? 1.08 : 1.0,
                  duration: _TB.motionFast,
                  child: Icon(widget.icon,
                      size: _TB.iconMd,
                      color: widget.active
                          ? _TB.accent
                          : (widget.color ?? _TB.fgPrimary)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Notifications bell + animated badge + popover.
class _NotifBellButton extends StatefulWidget {
  final int count;
  const _NotifBellButton({required this.count});
  @override
  State<_NotifBellButton> createState() => _NotifBellButtonState();
}

class _NotifBellButtonState extends State<_NotifBellButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: _TB.pulseDur)
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCount = widget.count > 0;
    final label = widget.count > 9 ? '9+' : '${widget.count}';
    return Builder(
      builder: (ctx) => Semantics(
        button: true,
        label: 'الإشعارات — ${widget.count} غير مقروءة',
        child: Tooltip(
          message: 'صندوق الوارد (${widget.count})',
          waitDuration: _TB.tooltipWait,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: SystemMouseCursors.click,
            child: InkWell(
              borderRadius: _TB.brMd,
              onTap: () => UnifiedInbox.show(ctx),
              child: AnimatedContainer(
                duration: _TB.motionFast,
                width: _TB.tapTarget,
                height: _TB.tapTarget,
                decoration: BoxDecoration(
                  color: _hover ? _TB.hoverOverlay : Colors.transparent,
                  borderRadius: _TB.brMd,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(Icons.notifications_outlined,
                      size: _TB.iconMd, color: _TB.fgPrimary),
                  if (hasCount)
                    PositionedDirectional(
                      end: _TB.sp2,
                      top: _TB.sp2,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + _pulse.value * 0.08,
                          child: Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _TB.danger,
                              borderRadius: BorderRadius.circular(9),
                              border:
                                  Border.all(color: _TB.bg, width: 1.5),
                            ),
                            child: Text(label, style: _TB.tsBadge),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar with online dot + profile popover.
class _AvatarMenu extends StatelessWidget {
  final bool online;
  const _AvatarMenu({required this.online});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: _TB.menuStyle(),
      alignmentOffset: const Offset(0, _TB.sp1),
      builder: (ctx, ctrl, _) => Semantics(
        button: true,
        label: 'قائمة المستخدم',
        child: Tooltip(
          message: 'الحساب والإعدادات',
          waitDuration: _TB.tooltipWait,
          child: InkWell(
            borderRadius: BorderRadius.circular(_TB.rPill),
            onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: _TB.sp3, vertical: _TB.sp1),
              child: Stack(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _TB.accent.withValues(alpha: 0.20),
                  child:
                      Icon(Icons.person, color: _TB.accent, size: _TB.iconMd),
                ),
                if (online)
                  PositionedDirectional(
                    bottom: 0,
                    end: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _TB.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: _TB.bg, width: 2),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
      menuChildren: [
        _menuRow(Icons.person_outline, 'الملف الشخصي',
            () => context.go('/profile')),
        _menuRow(Icons.settings_outlined, 'الإعدادات',
            () => context.go('/settings')),
        _menuRow(Icons.history, 'النشاط الأخير', () {}),
        const PopupMenuDivider(height: 8),
        _menuRow(Icons.logout, 'تسجيل الخروج', () {}, color: _TB.danger),
      ],
    );
  }

  MenuItemButton _menuRow(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? _TB.fgSecondary;
    return MenuItemButton(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(200, 36)),
        padding: WidgetStateProperty.all(
            const EdgeInsetsDirectional.symmetric(
                horizontal: _TB.sp5, vertical: _TB.sp1)),
      ),
      leadingIcon: Icon(icon, size: 15, color: c),
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: _TB.fs12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Theme toggle (light/dark).
class _ThemeToggleBtn extends ConsumerWidget {
  const _ThemeToggleBtn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeId.endsWith('_dark');
    return _TopBarIconBtn(
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: isDark ? 'وضع الإضاءة' : 'الوضع الداكن',
      semanticLabel:
          isDark ? 'تبديل إلى الوضع الفاتح' : 'تبديل إلى الوضع الداكن',
      onPressed: (_) =>
          ref.read(appSettingsProvider.notifier).toggleDarkMode(!isDark),
    );
  }
}

/// Language toggle AR / EN.
class _LangToggleBtn extends ConsumerWidget {
  const _LangToggleBtn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isAr = settings.language == 'ar';
    return Semantics(
      button: true,
      label: isAr ? 'تبديل إلى الإنجليزية' : 'Switch to Arabic',
      child: Tooltip(
        message: isAr ? 'English' : 'العربية',
        waitDuration: _TB.tooltipWait,
        child: InkWell(
          borderRadius: _TB.brMd,
          onTap: () => ref
              .read(appSettingsProvider.notifier)
              .setLanguage(isAr ? 'en' : 'ar'),
          child: Container(
            width: _TB.tapTarget,
            height: _TB.tapTarget,
            alignment: Alignment.center,
            child: Text(isAr ? 'EN' : 'ع',
                style: TextStyle(
                    color: _TB.fgPrimary,
                    fontSize: _TB.fs12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

/// Cmd+K button — platform-aware shortcut (⌘K / Ctrl+K).
class _CmdKButton extends StatelessWidget {
  const _CmdKButton();
  @override
  Widget build(BuildContext context) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final shortcut = isMac ? '⌘K' : 'Ctrl+K';
    return Builder(
      builder: (ctx) => Semantics(
        button: true,
        label: 'فتح مستكشف الأوامر ($shortcut)',
        child: Tooltip(
          message: 'بحث / أوامر ($shortcut)',
          waitDuration: _TB.tooltipWait,
          child: InkWell(
            onTap: () => CmdKPalette.show(ctx),
            borderRadius: _TB.brSm,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: _TB.sp4, vertical: _TB.sp2),
              decoration: BoxDecoration(
                color: _TB.surfaceRaised,
                borderRadius: _TB.brSm,
                border: Border.all(color: _TB.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search,
                    size: _TB.iconSm, color: _TB.fgSecondary),
                const SizedBox(width: _TB.sp2),
                Text('بحث',
                    style: TextStyle(
                        fontSize: _TB.fs12, color: _TB.fgSecondary)),
                const SizedBox(width: _TB.sp3),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: _TB.sp1, vertical: 1),
                  decoration: BoxDecoration(
                    color: _TB.surfaceElevated,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _TB.border),
                  ),
                  child: Text(shortcut,
                      style: TextStyle(
                          fontSize: _TB.fs10,
                          fontWeight: FontWeight.w600,
                          color: _TB.fgSecondary)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact breadcrumb — dropdown menu for narrow screens.
class _CompactBreadcrumb extends StatelessWidget {
  final List<_BreadcrumbPart> parts;
  const _CompactBreadcrumb({required this.parts});
  @override
  Widget build(BuildContext context) {
    final last = parts.isNotEmpty ? parts.last : null;
    if (last == null) return const SizedBox.shrink();
    return MenuAnchor(
      style: _TB.menuStyle(),
      alignmentOffset: const Offset(0, _TB.sp1),
      builder: (ctx, ctrl, _) => InkWell(
        borderRadius: _TB.brSm,
        onTap: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _TB.sp2, vertical: _TB.sp1),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(last.icon, size: _TB.iconSm, color: _TB.accent),
            const SizedBox(width: _TB.sp1),
            Flexible(
              child: Text(last.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: _TB.fs12,
                      fontWeight: FontWeight.w700,
                      color: _TB.fgPrimary)),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: _TB.iconSm, color: _TB.fgSecondary),
          ]),
        ),
      ),
      menuChildren: [
        for (int i = 0; i < parts.length; i++)
          MenuItemButton(
            onPressed: parts[i].route != null
                ? () => context.go(parts[i].route!)
                : null,
            leadingIcon: Icon(parts[i].icon,
                size: _TB.iconSm,
                color: i == parts.length - 1
                    ? _TB.accent
                    : _TB.fgSecondary),
            trailingIcon: i == parts.length - 1
                ? Icon(Icons.check, size: _TB.iconSm, color: _TB.accent)
                : null,
            child: Text(parts[i].label,
                style: TextStyle(
                    color: _TB.fgPrimary,
                    fontSize: _TB.fs12,
                    fontWeight: i == parts.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ),
      ],
    );
  }
}

/// Help row for keyboard shortcuts cheatsheet.
class _HelpRow extends StatelessWidget {
  final String keys;
  final String desc;
  const _HelpRow({required this.keys, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: _TB.sp2),
      child: Row(children: [
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _TB.sp3, vertical: 3),
          decoration: BoxDecoration(
            color: _TB.surfaceRaised,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _TB.border),
          ),
          child: Text(keys,
              style: const TextStyle(
                  fontSize: _TB.fs11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(width: _TB.sp5),
        Expanded(
            child: Text(desc, style: const TextStyle(fontSize: _TB.fs12))),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _TB.accent.withValues(alpha: 0.15),
        child: Icon(icon, color: _TB.accent, size: _TB.iconMd),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: _TB.fs13, fontWeight: FontWeight.w700)),
      subtitle: Text(sub, style: const TextStyle(fontSize: _TB.fs11)),
      trailing: const Icon(Icons.chevron_left, size: _TB.iconMd),
      onTap: onTap,
    );
  }
}


class _BreadcrumbPart {
  final String label;
  final String? route;
  final IconData icon;
  final Color? color;

  _BreadcrumbPart({
    required this.label,
    required this.route,
    required this.icon,
    this.color,
  });
}

class _Breadcrumb extends StatelessWidget {
  final List<_BreadcrumbPart> parts;

  const _Breadcrumb({required this.parts});

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i];
      final isLast = i == parts.length - 1;
      final color = p.color ?? (isLast ? _TB.accent : _TB.fgSecondary);
      widgets.add(
        Semantics(
          button: p.route != null,
          label: p.label,
          child: InkWell(
            borderRadius: _TB.brSm,
            onTap: p.route != null ? () => context.go(p.route!) : null,
            hoverColor: _TB.hoverOverlay,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: _TB.sp1, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icon, size: _TB.iconSm, color: color),
                  const SizedBox(width: _TB.sp1),
                  Text(
                    p.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _TB.fs12,
                      fontWeight:
                          isLast ? FontWeight.w700 : FontWeight.w500,
                      color: isLast ? _TB.fgPrimary : _TB.fgSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: _TB.sp1),
            child: Icon(Icons.chevron_left,
                size: _TB.iconSm, color: _TB.fgSecondary),
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Sidebar — main modules within current service
// ──────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final V5Service service;
  final String activeMainId;
  final bool isCollapsed;

  const _Sidebar({
    required this.service,
    required this.activeMainId,
    this.isCollapsed = false,
  });

  V5MainModule? get _activeModule {
    for (final m in service.mainModules) {
      if (m.id == activeMainId) return m;
    }
    return service.mainModules.isNotEmpty ? service.mainModules.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final activeMod = _activeModule;
    if (activeMod == null) {
      return Container(
          width: isCollapsed ? 64 : 260,
          color: core_theme.AC.gold.withValues(alpha: 0.03));
    }
    return AnimatedContainer(
      duration: core_theme.DS.motionMed,
      curve: core_theme.DS.easeEmphasized,
      width: isCollapsed ? 64 : 264,
      decoration: BoxDecoration(color: core_theme.AC.sidebarBg),
      // Theme-identity: 3px accent on the leading edge reflects the
      // selected theme's primary color, making each of the 12 themes
      // visually distinct at a glance (per user feedback).
      child: Stack(children: [
        PositionedDirectional(
          start: 0, top: 0, bottom: 0,
          width: 3,
          child: Container(color: core_theme.AC.sidebarAccentEdge),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 3),
          child: Column(
        children: [
          _activeModuleHeader(context, activeMod),
          Container(
            height: 1,
            color: core_theme.AC.sidebarBorder,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildChipsOfActiveModule(context, activeMod),
            ),
          ),
          Container(
            height: 1,
            color: core_theme.AC.sidebarBorder,
          ),
          _otherModulesButton(context),
          // Collapse toggle
          _collapseToggle(),
        ],
      ),
        ),
      ]),
    );
  }

  Widget _collapseToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => SidebarPrefs.toggle(),
        hoverColor: core_theme.AC.sidebarItemHoverBg,
        splashColor: core_theme.AC.sidebarItemSelectedBg,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: core_theme.AC.sidebarBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: isCollapsed ? 'توسيع القائمة' : 'طيّ القائمة',
                child: Icon(
                  // RTL: collapsed = expand-arrow points LEFT (toward content),
                  //      expanded  = collapse-arrow points RIGHT (toward edge)
                  isCollapsed
                      ? Icons.keyboard_double_arrow_left
                      : Icons.keyboard_double_arrow_right,
                  color: core_theme.AC.gold.withValues(alpha: 0.75),
                  size: 18,
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 6),
                Text(
                  'طيّ',
                  style: TextStyle(
                    color: core_theme.AC.gold.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeModuleHeader(BuildContext context, V5MainModule m) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/app/${service.id}/${m.id}'),
        hoverColor: core_theme.AC.gold.withValues(alpha: 0.06),
        splashColor: core_theme.AC.gold.withValues(alpha: 0.12),
        child: Container(
          padding: isCollapsed
              ? const EdgeInsets.fromLTRB(8, 14, 8, 14)
              : const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(gradient: core_theme.AC.sidebarHeaderGradient),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Tooltip(
                message: isCollapsed ? '${m.labelAr} • ${service.labelAr}' : '',
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: core_theme.AC.sidebarItemSelectedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: core_theme.AC.sidebarBorder),
                  ),
                  child: Icon(m.icon, color: core_theme.AC.gold, size: 18),
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.labelAr,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: core_theme.AC.gold,
                              height: 1.15,
                              letterSpacing: 0.2),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(service.labelAr,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: core_theme.AC.ts,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Renders the chip list of a module's sidebar.
  ///
  /// Two grouping modes:
  ///   • New: when chips have `category`, group by 9-category daily-workflow
  ///     taxonomy (my-work → command → operations → reconciliation → tax →
  ///     reports → intelligence → close → foundation). Used by /accounting.
  ///   • Legacy: chips without `category` fall back to 4-phase grouping
  ///     (Setup/Capture/Process/Report). Used by other modules.
  List<Widget> _buildChipsOfActiveModule(
      BuildContext context, V5MainModule m) {
    if (m.chips.isEmpty) return const [];
    final usingCategories = m.chips.any((c) => c.category != null);
    if (usingCategories) {
      return _buildByCategory(context, m);
    }
    return _buildByPhase(context, m);
  }

  /// Modern 9-category sidebar — accountant's daily workflow.
  List<Widget> _buildByCategory(BuildContext context, V5MainModule m) {
    // Preserve insertion order in the source; one category per chip.
    const order = [
      'my-work', 'command', 'operations', 'reconciliation',
      'tax', 'reports', 'intelligence', 'close', 'foundation',
    ];
    final byCat = <String, List<V5Chip>>{};
    for (final c in m.chips) {
      final cat = c.category ?? 'foundation';
      byCat.putIfAbsent(cat, () => []).add(c);
    }
    final currentPath = GoRouterState.of(context).matchedLocation;
    final widgets = <Widget>[];
    bool firstCat = true;
    for (final cat in order) {
      final chips = byCat[cat];
      if (chips == null || chips.isEmpty) continue;
      if (isCollapsed && !firstCat) {
        widgets.add(_collapsedPhaseDivider());
      } else if (!isCollapsed) {
        widgets.add(_categoryHeader(cat));
      }
      firstCat = false;
      // Foundation category preserves the legacy 7-phase setup sub-grouping
      // (Foundation → Backbone → Dimensions → Documents → Integrations → Go-Live).
      if (cat == 'foundation' && !isCollapsed) {
        String? lastGroup;
        for (final c in chips) {
          final g = c.setupGroup;
          if (g != null && g != lastGroup) {
            widgets.add(_setupGroupHeader(g));
            lastGroup = g;
          }
          widgets.add(_ChipSubItem(
            chip: c,
            moduleId: m.id,
            serviceColor: core_theme.AC.gold,
            isActive: currentPath.endsWith('/${c.id}'),
            isCollapsed: isCollapsed,
          ));
        }
      } else {
        for (final c in chips) {
          widgets.add(_ChipSubItem(
            chip: c,
            moduleId: m.id,
            serviceColor: core_theme.AC.gold,
            isActive: currentPath.endsWith('/${c.id}'),
            isCollapsed: isCollapsed,
          ));
        }
      }
    }
    return widgets;
  }

  /// Legacy 4-phase grouping (Setup/Capture/Process/Report).
  List<Widget> _buildByPhase(BuildContext context, V5MainModule m) {
    final byPhase = <ChipPhase, List<V5Chip>>{};
    for (final c in m.chips) {
      byPhase.putIfAbsent(c.phase ?? ChipPhase.capture, () => []).add(c);
    }
    final currentPath = GoRouterState.of(context).matchedLocation;
    final widgets = <Widget>[];
    bool firstPhase = true;
    for (final phase in ChipPhase.values) {
      final chips = byPhase[phase];
      if (chips == null || chips.isEmpty) continue;
      if (isCollapsed && !firstPhase) {
        widgets.add(_collapsedPhaseDivider());
      } else if (!isCollapsed) {
        widgets.add(_phaseHeader(phase));
      }
      firstPhase = false;
      if (phase == ChipPhase.setup && !isCollapsed) {
        String? lastGroup;
        for (final c in chips) {
          final g = c.setupGroup;
          if (g != null && g != lastGroup) {
            widgets.add(_setupGroupHeader(g));
            lastGroup = g;
          }
          widgets.add(_ChipSubItem(
            chip: c,
            moduleId: m.id,
            serviceColor: core_theme.AC.gold,
            isActive: currentPath.endsWith('/${c.id}'),
            isCollapsed: isCollapsed,
          ));
        }
      } else {
        for (final c in chips) {
          widgets.add(_ChipSubItem(
            chip: c,
            moduleId: m.id,
            serviceColor: core_theme.AC.gold,
            isActive: currentPath.endsWith('/${c.id}'),
            isCollapsed: isCollapsed,
          ));
        }
      }
    }
    return widgets;
  }

  /// Top-level category header for the 9-category sidebar.
  Widget _categoryHeader(String catId) {
    final (label, icon, color) = switch (catId) {
      'my-work'        => ('1️⃣ مهامي اليوم',          Icons.inbox_outlined,           const Color(0xFFE91E63)),
      'command'        => ('2️⃣ مركز القيادة',          Icons.dashboard_outlined,       const Color(0xFFFFC107)),
      'operations'     => ('3️⃣ العمليات اليومية',      Icons.fact_check_outlined,      const Color(0xFF4CAF50)),
      'reconciliation' => ('4️⃣ مركز المطابقات',         Icons.compare_arrows,           const Color(0xFF9C27B0)),
      'tax'            => ('5️⃣ الضرائب والامتثال',     Icons.gavel,                    const Color(0xFFFF5722)),
      'reports'        => ('6️⃣ التقارير المالية',       Icons.assessment_outlined,      const Color(0xFF2196F3)),
      'intelligence'   => ('7️⃣ الذكاء المالي ✨',       Icons.psychology_outlined,      const Color(0xFF00BCD4)),
      'close'          => ('8️⃣ الإقفال والرقابة',       Icons.lock_clock_outlined,      const Color(0xFF607D8B)),
      'foundation'     => ('9️⃣ التأسيس (Setup)',       Icons.settings_outlined,        const Color(0xFF795548)),
      _                => (catId, Icons.label_outline, core_theme.AC.gold),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 6),
      child: Row(children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.4)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.6,
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.20),
                color.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _setupGroupHeader(String groupId) {
    final (label, icon, color) = switch (groupId) {
      'foundation'   => ('١ — تأسيس الكيان',     Icons.foundation,     const Color(0xFF4CAF50)),
      'backbone'     => ('٢ — الهيكل المحاسبي',  Icons.account_tree,   const Color(0xFF9C27B0)),
      'dimensions'   => ('٣ — الأبعاد التحليلية', Icons.view_in_ar,     const Color(0xFF2196F3)),
      'documents'    => ('٤ — المستندات',         Icons.description,    const Color(0xFFFFC107)),
      'operations'   => ('٥ — قواعد التشغيل',     Icons.settings_applications, const Color(0xFFFF5722)),
      'integrations' => ('٦ — التكاملات',         Icons.hub,            const Color(0xFF00BCD4)),
      'golive'       => ('٧ — الإطلاق',           Icons.rocket_launch,  const Color(0xFFE91E63)),
      _              => (groupId, Icons.label, core_theme.AC.gold),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 4),
      child: Row(children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            )),
      ]),
    );
  }

  Widget _collapsedPhaseDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(height: 1, color: core_theme.AC.sidebarBorder),
    );
  }

  Widget _phaseHeader(ChipPhase p) {
    final (label, icon) = switch (p) {
      ChipPhase.setup => ('الإعداد', Icons.settings_outlined),
      ChipPhase.capture => ('العمليات', Icons.fact_check_outlined),
      ChipPhase.process => ('المعالجة', Icons.precision_manufacturing_outlined),
      ChipPhase.report => ('التقارير', Icons.analytics_outlined),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 6),
      child: Row(children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                core_theme.AC.gold,
                core_theme.AC.gold.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon,
            size: 11, color: core_theme.AC.gold.withValues(alpha: 0.65)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: core_theme.AC.gold.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  core_theme.AC.gold.withValues(alpha: 0.15),
                  core_theme.AC.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _otherModulesButton(BuildContext context) {
    final others =
        service.mainModules.where((m) => m.id != activeMainId).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'التنقّل إلى تطبيق آخر',
      color: core_theme.AC.navy2,
      offset: const Offset(0, -240),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: core_theme.AC.bdr),
      ),
      elevation: 12,
      onSelected: (mid) => context.go('/app/${service.id}/$mid'),
      itemBuilder: (_) => _buildOtherModulesMenu(others),
      child: Container(
        padding: isCollapsed
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: core_theme.AC.sidebarBgElevated,
        ),
        child: Row(
          mainAxisAlignment: isCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Tooltip(
              message: isCollapsed
                  ? 'تطبيقات أخرى (${others.length})'
                  : '',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: core_theme.AC.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.apps, color: core_theme.AC.gold, size: 14),
                  ),
                  if (isCollapsed)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: core_theme.AC.gold,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: core_theme.AC.navy2, width: 1),
                        ),
                        child: Text('${others.length}',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: core_theme.AC
                                    .bestOn(core_theme.AC.gold))),
                      ),
                    ),
                ],
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text('تطبيقات أخرى في ${service.labelAr}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: core_theme.AC.gold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: core_theme.AC.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${others.length}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: core_theme.AC.bestOn(core_theme.AC.gold))),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up,
                  color: core_theme.AC.gold.withValues(alpha: 0.85),
                  size: 16),
            ],
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildOtherModulesMenu(List<V5MainModule> others) {
    // Group by AppGroup if set
    final groups = <AppGroup, List<V5MainModule>>{};
    final ungrouped = <V5MainModule>[];
    for (final m in others) {
      if (m.group != null) {
        groups.putIfAbsent(m.group!, () => []).add(m);
      } else {
        ungrouped.add(m);
      }
    }
    final items = <PopupMenuEntry<String>>[];
    for (final g in AppGroup.values) {
      final mods = groups[g];
      if (mods == null || mods.isEmpty) continue;
      items.add(PopupMenuItem<String>(
        enabled: false,
        height: 24,
        child: Row(children: [
          Icon(g.icon, size: 11, color: g.color),
          const SizedBox(width: 6),
          Text(g.labelAr,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: g.color)),
        ]),
      ));
      for (final m in mods) {
        items.add(PopupMenuItem<String>(
          value: m.id,
          height: 40,
          child: Row(children: [
            Icon(m.icon, size: 16, color: g.color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(m.labelAr,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ]),
        ));
      }
      items.add(const PopupMenuDivider());
    }
    if (ungrouped.isNotEmpty) {
      for (final m in ungrouped) {
        items.add(PopupMenuItem<String>(
          value: m.id,
          height: 40,
          child: Row(children: [
            Icon(m.icon, size: 16, color: core_theme.AC.gold),
            const SizedBox(width: 10),
            Flexible(
              child: Text(m.labelAr,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ]),
        ));
      }
    }
    if (items.isNotEmpty && items.last is PopupMenuDivider) {
      items.removeLast();
    }
    return items;
  }

}

// H-28: Keyboard shortcut chip (kbd-like — GitHub Primer / Linear style)
class _ShortcutChip extends StatelessWidget {
  final String label;
  const _ShortcutChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: core_theme.DS.s1 + 2, vertical: 1),
      decoration: BoxDecoration(
        color: core_theme.AC.bdr.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(core_theme.DS.rSm),
        border: Border.all(
          color: core_theme.AC.bdr.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: core_theme.DS.fs2xs,
          fontWeight: core_theme.DS.fwSemibold,
          color: core_theme.AC.td,
          fontFamilyFallback: const <String>['monospace', 'Menlo', 'Consolas'],
          height: 1.4,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final V5MainModule mainModule;
  final bool isActive;
  final int shortcutNumber;
  final Color serviceColor;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.mainModule,
    required this.isActive,
    required this.shortcutNumber,
    required this.serviceColor,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.serviceColor;
    final active = widget.isActive;
    // H-21..H-30: DS-aligned row (44px), leading indicator bar, AC state tokens
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: core_theme.DS.motionFast,
              margin: const EdgeInsetsDirectional.symmetric(
                  horizontal: core_theme.DS.s2, vertical: 1),
              constraints: const BoxConstraints(minHeight: core_theme.DS.sidebarRow),
              padding: const EdgeInsetsDirectional.only(
                start: core_theme.DS.s1, // leaves room for indicator bar
                end: core_theme.DS.s3,
                top: core_theme.DS.s2,
                bottom: core_theme.DS.s2,
              ),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.12)
                    : _hover
                        ? core_theme.AC.stateHover
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(core_theme.DS.rMd),
              ),
              child: Row(
                children: [
                  // H-22: leading active-indicator bar (SAP Fiori / Linear pattern)
                  AnimatedContainer(
                    duration: core_theme.DS.motionFast,
                    width: 3,
                    height: active ? 22 : 0,
                    margin: const EdgeInsetsDirectional.only(end: core_theme.DS.s2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(core_theme.DS.rSm),
                    ),
                  ),
                  Icon(
                    widget.mainModule.icon,
                    size: core_theme.DS.iconLg, // H-27: was 18, now 20
                    color: active ? color : core_theme.AC.ts,
                  ),
                  const SizedBox(width: core_theme.DS.s3),
                  Expanded(
                    child: Text(
                      widget.mainModule.labelAr,
                      style: TextStyle(
                        fontSize: core_theme.DS.fsLg, // H-25: was 13, now 14
                        fontWeight: active
                            ? core_theme.DS.fwBold
                            : core_theme.DS.fwMedium,
                        color: active ? color : core_theme.AC.tp,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (active && widget.mainModule.chips.isNotEmpty)
                    Icon(core_theme.AppIcons.chevronDown, // H-29: unified chevron
                        size: core_theme.DS.iconSm, color: color)
                  else if (_hover || active)
                    _ShortcutChip(label: 'Alt+⇧+${widget.shortcutNumber}'), // H-28
                ],
              ),
            ),
          ),
        ),
        // Context-aware: when this module is active, show its chips here.
        // This satisfies the user's request "show only options for the open app".
        if (widget.isActive && widget.mainModule.chips.isNotEmpty)
          _ActiveModuleChipsList(
            module: widget.mainModule,
            serviceColor: color,
          ),
      ],
    );
  }
}

/// Shows the chips of the currently-active module as indented sub-items in
/// the sidebar. Tapping a chip navigates to it. Grouped by ChipPhase.
class _ActiveModuleChipsList extends StatelessWidget {
  final V5MainModule module;
  final Color serviceColor;

  const _ActiveModuleChipsList({
    required this.module,
    required this.serviceColor,
  });

  @override
  Widget build(BuildContext context) {
    // Group chips by phase for readability — chips without phase go to "capture"
    final byPhase = <ChipPhase, List<V5Chip>>{};
    for (final c in module.chips) {
      byPhase.putIfAbsent(c.phase ?? ChipPhase.capture, () => []).add(c);
    }
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(
              color: serviceColor.withValues(alpha: 0.25), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final phase in ChipPhase.values)
            if (byPhase[phase] != null)
              ..._phaseSection(
                  context, phase, byPhase[phase]!, currentPath),
        ],
      ),
    );
  }

  List<Widget> _phaseSection(BuildContext context, ChipPhase phase,
      List<V5Chip> chips, String currentPath) {
    return [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 8, 2),
        child: Text(
          _phaseLabel(phase),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: core_theme.AC.ts,
            letterSpacing: 0.3,
          ),
        ),
      ),
      ...chips.map((chip) => _ChipSubItem(
            chip: chip,
            moduleId: module.id,
            serviceColor: serviceColor,
            isActive: currentPath.endsWith('/${chip.id}'),
          )),
    ];
  }

  String _phaseLabel(ChipPhase p) => switch (p) {
        ChipPhase.setup => 'الإعداد',
        ChipPhase.capture => 'العمليات',
        ChipPhase.process => 'المعالجة',
        ChipPhase.report => 'التقارير',
      };
}

class _ChipSubItem extends StatefulWidget {
  final V5Chip chip;
  final String moduleId;
  final Color serviceColor;
  final bool isActive;
  final bool isCollapsed;

  const _ChipSubItem({
    required this.chip,
    required this.moduleId,
    required this.serviceColor,
    required this.isActive,
    this.isCollapsed = false,
  });

  @override
  State<_ChipSubItem> createState() => _ChipSubItemState();
}

class _ChipSubItemState extends State<_ChipSubItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final parts = currentPath.split('/');
    final serviceId = parts.length > 2 ? parts[2] : 'erp';
    final c = widget.serviceColor;
    final isActive = widget.isActive;

    if (widget.isCollapsed) {
      return _buildCollapsed(context, c, isActive, serviceId);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(
            '/app/$serviceId/${widget.moduleId}/${widget.chip.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsetsDirectional.fromSTEB(10, 2, 6, 2),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: AlignmentDirectional.centerEnd,
                    end: AlignmentDirectional.centerStart,
                    colors: [
                      c.withValues(alpha: 0.20),
                      c.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            color: !isActive && _hover
                ? c.withValues(alpha: 0.07)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: c.withValues(alpha: 0.35))
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: c.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Active accent bar (right side in RTL)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: isActive ? 18 : 0,
                margin: const EdgeInsetsDirectional.only(end: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c, c.withValues(alpha: 0.5)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
              if (!isActive) const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isActive
                      ? c.withValues(alpha: 0.20)
                      : (_hover ? c.withValues(alpha: 0.10) : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.chip.icon,
                    size: 14,
                    color: isActive
                        ? c
                        : (_hover ? c.withValues(alpha: 0.85)
                            : core_theme.AC.ts)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(
                      widget.chip.labelAr,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : (_hover ? FontWeight.w600 : FontWeight.w500),
                        color: isActive
                            ? c
                            : (_hover ? core_theme.AC.tp : core_theme.AC.tp),
                        height: 1.15,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // ✨ AI badge — instantly identifies smart screens
                  if (widget.chip.aiPowered) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFF673AB7).withValues(alpha: 0.20),
                          const Color(0xFF00BCD4).withValues(alpha: 0.20),
                        ]),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFF673AB7).withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome,
                            size: 8, color: const Color(0xFF673AB7)),
                        const SizedBox(width: 2),
                        const Text('AI',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF673AB7),
                              letterSpacing: 0.3,
                            )),
                      ]),
                    ),
                  ],
                ]),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                )
              else if (_hover)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Icon(Icons.arrow_back_ios,
                      size: 9, color: c.withValues(alpha: 0.6)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(
      BuildContext context, Color c, bool isActive, String serviceId) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(
            '/app/$serviceId/${widget.moduleId}/${widget.chip.id}'),
        child: Tooltip(
          message: widget.chip.labelAr,
          waitDuration: const Duration(milliseconds: 250),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        c.withValues(alpha: 0.22),
                        c.withValues(alpha: 0.10),
                      ],
                    )
                  : null,
              color: !isActive && _hover
                  ? c.withValues(alpha: 0.08)
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: c.withValues(alpha: 0.4))
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.22),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                widget.chip.icon,
                size: 18,
                color: isActive
                    ? c
                    : (_hover
                        ? c.withValues(alpha: 0.85)
                        : core_theme.AC.ts),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Chip Row — dashboard first + specialized chips
// ──────────────────────────────────────────────────────────────────────

class _ChipRow extends StatefulWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final String activeChipId;

  const _ChipRow({
    required this.service,
    required this.mainModule,
    required this.activeChipId,
  });

  @override
  State<_ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<_ChipRow> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollCtrl.hasClients) return;
    final target = (_scrollCtrl.offset + delta)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  List<Widget> _buildChipItems(BuildContext context) {
    final chips = widget.mainModule.chips;
    // If no chips have phase tags, render flat (old behavior)
    final hasPhases = chips.any((c) => c.phase != null);
    if (!hasPhases) {
      return [
        for (final chip in chips)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ChipItem(
              chip: chip,
              isActive: chip.id == widget.activeChipId,
              serviceColor: core_theme.AC.gold,
              onTap: () => context.go('/app/${widget.service.id}/${widget.mainModule.id}/${chip.id}'),
            ),
          ),
      ];
    }

    // Phase-aware rendering with dividers
    final widgets = <Widget>[];
    ChipPhase? lastPhase;
    for (final chip in chips) {
      // Dashboard (first chip) gets no phase divider
      if (!chip.isDashboard && chip.phase != null && chip.phase != lastPhase) {
        widgets.add(_phaseDivider(chip.phase!));
        lastPhase = chip.phase;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _ChipItem(
          chip: chip,
          isActive: chip.id == widget.activeChipId,
          serviceColor: core_theme.AC.gold,
          onTap: () => context.go('/app/${widget.service.id}/${widget.mainModule.id}/${chip.id}'),
        ),
      ));
    }
    return widgets;
  }

  Widget _phaseDivider(ChipPhase phase) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 1,
            height: 24,
            color: core_theme.AC.bdr,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: phase.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: phase.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(phase.icon, size: 10, color: phase.color),
                const SizedBox(width: 4),
                Text(
                  phase.labelAr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: phase.color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: core_theme.AC.bdr,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      height: 48,
      color: surface,
      child: Row(
        children: [
          // Scroll-left arrow (visual order — works in both LTR/RTL).
          _ScrollArrow(
            icon: Icons.chevron_left,
            onTap: () => _scrollBy(-220),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: _buildChipItems(context),
              ),
            ),
          ),
          _ScrollArrow(
            icon: Icons.chevron_right,
            onTap: () => _scrollBy(220),
          ),
          // "All chips" dropdown — guaranteed way to reach any chip.
          _AllChipsMenu(
            service: widget.service,
            mainModule: widget.mainModule,
            activeChipId: widget.activeChipId,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: core_theme.AC.ts),
      onPressed: onTap,
      tooltip: 'تمرير',
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _AllChipsMenu extends StatelessWidget {
  final V5Service service;
  final V5MainModule mainModule;
  final String activeChipId;

  const _AllChipsMenu({
    required this.service,
    required this.mainModule,
    required this.activeChipId,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'كل الشاشات',
      position: PopupMenuPosition.under,
      onSelected: (chipId) => context.go(
        '/app/${service.id}/${mainModule.id}/$chipId',
      ),
      itemBuilder: (ctx) => [
        for (final chip in mainModule.chips)
          PopupMenuItem<String>(
            value: chip.id,
            child: Row(
              children: [
                Icon(
                  chip.icon,
                  size: 16,
                  color: chip.id == activeChipId
                      ? core_theme.AC.gold
                      : core_theme.AC.ts,
                ),
                const SizedBox(width: 10),
                Text(
                  chip.labelAr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: chip.id == activeChipId
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: chip.id == activeChipId
                        ? core_theme.AC.gold
                        : core_theme.AC.tp,
                  ),
                ),
                if (chip.id == activeChipId) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 14, color: core_theme.AC.gold),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: core_theme.AC.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: core_theme.AC.gold.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps, size: 14, color: core_theme.AC.gold),
            const SizedBox(width: 6),
            Text(
              'كل الشاشات (${mainModule.chips.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: core_theme.AC.gold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: core_theme.AC.gold),
          ],
        ),
      ),
    );
  }
}

class _ChipItem extends StatefulWidget {
  final V5Chip chip;
  final bool isActive;
  final Color serviceColor;
  final VoidCallback onTap;

  const _ChipItem({
    required this.chip,
    required this.isActive,
    required this.serviceColor,
    required this.onTap,
  });

  @override
  State<_ChipItem> createState() => _ChipItemState();
}

class _ChipItemState extends State<_ChipItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.serviceColor;
    final isDashboard = widget.chip.isDashboard;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? (isDashboard ? color.withValues(alpha: 0.16) : Colors.transparent)
                : _hover
                    ? color.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(isDashboard ? 10 : 6),
            border: widget.isActive && isDashboard
                ? Border.all(color: color.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.chip.icon,
                size: 14,
                color: widget.isActive ? color : core_theme.AC.ts,
              ),
              const SizedBox(width: 6),
              Text(
                widget.chip.labelAr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isActive || isDashboard
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isActive ? color : core_theme.AC.tp,
                ),
              ),
              if (widget.isActive && !isDashboard) ...[
                const SizedBox(width: 4),
                Container(
                  height: 3,
                  width: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// V4 sub-module host (reuses the existing tab shell)
// ──────────────────────────────────────────────────────────────────────

class _V4SubModuleHost extends StatelessWidget {
  final dynamic subModule; // V4SubModule
  final dynamic activeScreen; // V4Screen

  const _V4SubModuleHost({required this.subModule, required this.activeScreen});

  @override
  Widget build(BuildContext context) {
    // Placeholder — would wire into ApexSubModuleShell with the right
    // V4ModuleGroup context. For POC, show a clear reuse indicator.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, size: 48, color: core_theme.AC.td),
          const SizedBox(height: 12),
          Text(
            'إعادة استخدام شاشة V4: ${activeScreen.labelAr}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'هذه البطاقة تربط بـ ${subModule.id} من V4 — لا توجد شاشات مُعاد بناؤها',
            style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Coming-soon banner for chips without content yet
// ──────────────────────────────────────────────────────────────────────

class _ComingSoonBanner extends StatelessWidget {
  final String titleAr;
  final String subtitleAr;
  final IconData icon;

  const _ComingSoonBanner({
    required this.titleAr,
    required this.subtitleAr,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: core_theme.AC.td),
          const SizedBox(height: 16),
          Text(
            titleAr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitleAr,
            style: TextStyle(fontSize: 13, color: core_theme.AC.ts),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: core_theme.AC.warn.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: core_theme.AC.warn.withValues(alpha: 0.4)),
            ),
            child: Text(
              'قيد البناء',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
