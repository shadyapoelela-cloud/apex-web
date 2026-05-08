/// APEX V5.1 — Route definitions.
///
/// URL structure:
///   /app                               → Service Switcher (Launchpad)
///   /app/:service                      → Service Home (first main module)
///   /app/:service/:main                → Main Module (first chip = dashboard)
///   /app/:service/:main/:chip          → Specific chip
///   /app/:service/:main/:chip?t=tab   → Chip with active tab
///
///   /workspace/:id                     → Workspace home (role-based)
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../apex_ask_panel.dart';
import '../apex_news_ticker.dart';
import '../theme.dart' as core_theme;
import '../../screens/coming_soon_screen.dart';
import '../../screens/finance/balance_sheet_screen.dart';
import '../../screens/finance/cash_flow_screen.dart';
import '../../screens/finance/income_statement_screen.dart';
import '../../screens/finance/trial_balance_screen.dart';
import '../../screens/v5_showcase/v5_showcase_screen.dart';
import '../../pilot/screens/setup/je_builder_live_v52.dart';
import 'apex_v5_service_shell.dart';
import 'apex_v5_service_switcher.dart';
import 'apex_v5_workspace_selector.dart';
import 'apps_hub_screen.dart';
import 'v5_data.dart';
import 'v5_models.dart';
import 'v5_wired_screens.dart';


/// List of routes to be spread into the top-level GoRouter.routes.
List<RouteBase> v5Routes() => [
      // Phase 27.5: V5 Launchpad is the home again — user wants this as the
      // starting screen (Copilot hero + tile grid + news ticker + Ask APEX).
      // G-S2 (2026-05-01): the /login redirect was removed because it
      // overrode the top-level auth guard and produced /login ⇄ /app loops.
      // /login now resolves to the real SlideAuthScreen route in router.dart.
      GoRoute(path: '/', redirect: (ctx, state) => '/app'),
      GoRoute(path: '/home', redirect: (ctx, state) => '/app'),
      GoRoute(
        path: '/app',
        builder: (ctx, state) =>
            const V5Launchpad(),
      ),
      GoRoute(
        path: '/showcase',
        builder: (ctx, state) =>
            const V5ShowcaseScreen(),
      ),
      GoRoute(
        path: '/app/:service',
        redirect: (ctx, state) {
          final svc = v5ServiceById(state.pathParameters['service']!);
          if (svc == null || svc.mainModules.isEmpty) return '/app';
          // ERP with 16 apps — show the Apps Hub grid by default.
          // Other services with fewer apps jump straight to the first.
          if (svc.mainModules.length >= 6) {
            return '/app/${svc.id}/apps';
          }
          return '/app/${svc.id}/${svc.mainModules.first.id}';
        },
      ),
      // Apps Hub — Odoo-style grid of all apps in a service.
      // Wrapped in a trimmed shell: SystemBar + ScreenBar only.
      // (News ticker / Sidebar / Quick-Access rail are hidden in hub mode.)
      GoRoute(
        path: '/app/:service/apps',
        builder: (ctx, state) {
          final svc = v5ServiceById(state.pathParameters['service']!);
          if (svc == null) return const _V5NotFound();
          return ApexV5ServiceShell(
            service: svc,
            // mainModule + activeChip left null → Apps Hub mode
            bodyOverride: AppsHubScreen(service: svc, embedded: true),
          );
        },
      ),
      GoRoute(
        path: '/app/:service/:main',
        redirect: (ctx, state) {
          final svc = v5ServiceById(state.pathParameters['service']!);
          final main = svc?.mainModuleById(state.pathParameters['main']!);
          if (svc == null || main == null) return '/app';
          // Default to first chip (the dashboard)
          return '/app/${svc.id}/${main.id}/${main.dashboardChip.id}';
        },
      ),
      GoRoute(
        path: '/app/:service/:main/:chip',
        builder: (ctx, state) {
          final svc = v5ServiceById(state.pathParameters['service']!);
          if (svc == null) return const _V5NotFound();
          final main = svc.mainModuleById(state.pathParameters['main']!);
          if (main == null) return const _V5NotFound();
          final chip = main.chipById(state.pathParameters['chip']!);
          if (chip == null) return const _V5NotFound();
          // G-CLEANUP-4 (Sprint 15): if the parent main module is
          // marked `enabled: false`, render `ComingSoonScreen`
          // ("قيد البناء") inside the normal service shell instead
          // of the empty/broken default. The shell still provides the
          // header + breadcrumb so the user knows where they are; the
          // body becomes an honest placeholder with a button back to
          // the apps hub. Direct-URL access (bookmark, deep link,
          // typed URL) hits this branch — the launcher itself already
          // hides disabled modules per V5MainModule.enabled +
          // AppsHubScreen._filteredApps. See APEX_BLUEPRINT/09 § 20.1
          // G-CLEANUP-4.
          if (!main.enabled) {
            return ApexV5ServiceShell(
              service: svc,
              mainModule: main,
              activeChip: chip,
              bodyOverride: ComingSoonScreen(
                labelAr: main.labelAr,
                serviceId: svc.id,
                icon: main.icon,
              ),
            );
          }
          // Only provide builder if a wired screen exists for this chip;
          // otherwise let the shell fall through to dashboard / v4 / coming-soon.
          final wired = getWiredBuilder(svc.id, main.id, chip.id);
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            chipBodyBuilder: wired != null
                ? (ctx, _) => wired(ctx)
                : null,
          );
        },
      ),
      // G-TB-DISPLAY-1 (2026-05-08): explicit route for the dedicated
      // trial-balance ledger view. The chip id `trial-balance` isn't
      // declared as a `V5Chip(id:)` literal in v5_data.dart finance
      // chips list, so the parametric `/app/:service/:main/:chip`
      // handler above would 404 on the chip lookup. This explicit
      // route uses the existing `gl` chip for breadcrumb / activeChip
      // chrome (semantically the closest match — TB renders the GL
      // posting balances) and overrides the body with our screen.
      GoRoute(
        path: '/app/erp/finance/trial-balance',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          // Use the gl chip for chrome — TB is just one view of GL.
          final chip = main?.chipById('gl');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: const TrialBalanceScreen(),
          );
        },
      ),
      // G-FIN-IS-1 (2026-05-08): explicit route for the Income
      // Statement (P&L) screen. Same pattern as trial-balance —
      // the chip id `income-statement` is in v5_data.dart but
      // it's the dedicated screen we want to render, not a
      // parametric chip body. Uses the `gl` chip for chrome.
      GoRoute(
        path: '/app/erp/finance/income-statement',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          final chip = main?.chipById('gl');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: const IncomeStatementScreen(),
          );
        },
      ),
      // G-FIN-BS-1 (2026-05-08): explicit route for the Balance
      // Sheet screen. Same pattern as IS-1.
      GoRoute(
        path: '/app/erp/finance/balance-sheet',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          final chip = main?.chipById('gl');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: const BalanceSheetScreen(),
          );
        },
      ),
      // G-FIN-CF-1 (2026-05-08): explicit route for the Cash Flow
      // Statement (Indirect Method). Same pattern as IS-1 + BS-1.
      GoRoute(
        path: '/app/erp/finance/cash-flow',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          final chip = main?.chipById('gl');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: const CashFlowScreen(),
          );
        },
      ),
      // JE create — wraps the V5.2 ObjectPage builder with the unified
      // top bar (logo + breadcrumb + Cmd+K + actions) so it doesn't lose
      // the chrome when pushed from the JE list.
      GoRoute(
        path: '/app/erp/finance/je-builder/new',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          final chip = main?.chipById('je-builder');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: const JeBuilderLiveV52Screen(),
          );
        },
      ),
      // JE view/edit — same builder as create, but pre-loaded with the
      // entry data via jeId. Replaces the legacy modal _JeDetailDialog
      // that the list screen used to pop up on row click.
      GoRoute(
        path: '/app/erp/finance/je-builder/:id',
        builder: (ctx, state) {
          final svc = v5ServiceById('erp');
          final main = svc?.mainModuleById('finance');
          final chip = main?.chipById('je-builder');
          if (svc == null || main == null || chip == null) {
            return const _V5NotFound();
          }
          return ApexV5ServiceShell(
            service: svc,
            mainModule: main,
            activeChip: chip,
            bodyOverride: JeBuilderLiveV52Screen(
                jeId: state.pathParameters['id']),
          );
        },
      ),
      GoRoute(
        path: '/workspace/:id',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          V5Workspace? ws;
          for (final w in v5Workspaces) {
            if (w.id == id) {
              ws = w;
              break;
            }
          }
          if (ws == null) return const _V5NotFound();
          return V5WorkspaceShell(workspace: ws);
        },
      ),
    ];

// ──────────────────────────────────────────────────────────────────────
// Launchpad — grid of 5 services + workspace picker
// ──────────────────────────────────────────────────────────────────────

class V5Launchpad extends StatelessWidget {
  const V5Launchpad({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const ApexNewsTicker(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'v5_ask_apex',
        onPressed: () => openApexAskPanel(context),
        backgroundColor: core_theme.AC.gold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('اسأل أبكس', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [core_theme.AC.gold, Color(0xFFE6C200)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APEX',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        'منصّة العمليات والامتثال والاستشارات المالية',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'اسأل أبكس (Ctrl+/)',
                    onPressed: () => openApexAskPanel(context),
                    icon: Icon(Icons.auto_awesome, color: core_theme.AC.gold, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Ask APEX banner — the signature AI entry point ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [core_theme.AC.gold, const Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: core_theme.AC.gold.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اسأل أبكس — Copilot ذكاء اصطناعي',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'جرّب: "كم صرفنا على التسويق؟" · "قائمة الدخل" · "توقّع السيولة 3 أشهر"',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Tajawal',
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => openApexAskPanel(context),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text(
                        'ابدأ الآن',
                        style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: core_theme.AC.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // G-CLEANUP-3 (Sprint 15): the home dashboard between this
              // banner and the 5 Service Pillars below previously held
              // five competing nav patterns — 12 AI quick-link cards,
              // a SAP ACDOCA / Odoo Multi-view banner, an Operations
              // Center banner, a V5.1 Showcase CTA banner, a "Quick
              // Shortcuts" 4-card grid, and a Workspaces section. All
              // deleted per file 39 § 2.2 / file 40 Stage 2 (operator
              // directive: keep ONLY 5 pillars on the home — every
              // other entry point lives one click deeper inside its
              // pillar). The deleted helper widgets `_AiQuickLink`,
              // `_LaunchpadQuickCard`, `_WorkspaceCard` were removed
              // from this file at the same time. See APEX_BLUEPRINT/09
              // § 20.1 G-CLEANUP-3 for the full closure.

              // ── 5 Service Pillars (Alt+1..5) ──
              Text(
                'الخدمات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 1100
                      ? 3
                      : constraints.maxWidth > 700
                          ? 2
                          : 1;
                  return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: cols,
                    childAspectRatio: 1.8,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (int i = 0; i < v5Services.length; i++)
                        _LaunchpadServiceCard(
                          service: v5Services[i],
                          shortcutNumber: i + 1,
                        ),
                    ],
                  );
                },
              ),

              // G-CLEANUP-3 (Sprint 15): Workspaces section deleted —
              // the home keeps only the 5 Pillars per file 39 § 2.2.
              // The `v5Workspaces` data structure stays in v5_data.dart
              // because /workspace/:id (V5WorkspaceShell) still uses it.
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchpadServiceCard extends StatefulWidget {
  final V5Service service;
  final int shortcutNumber;

  const _LaunchpadServiceCard({
    required this.service,
    required this.shortcutNumber,
  });

  @override
  State<_LaunchpadServiceCard> createState() => _LaunchpadServiceCardState();
}

class _LaunchpadServiceCardState extends State<_LaunchpadServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.service.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/app/${widget.service.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hover ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: _hover ? 0.4 : 0.15),
              width: _hover ? 2 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.service.icon, color: color, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.service.labelAr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _hover ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.service.descriptionAr,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.service.mainModules.length} وحدات',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_back, // RTL: forward
                        size: 16,
                        color: _hover ? color : Colors.black38,
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Alt+${widget.shortcutNumber}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// G-CLEANUP-3 (Sprint 15): `_WorkspaceCard` + `_AiQuickLink` helper
// classes were defined here and used only by the now-deleted home
// sections. Removed wholesale per file 39 § 2.2 / file 40 Stage 2.
// `V5Workspace` itself (the data class) is still alive in v5_data.dart
// because V5WorkspaceShell at /workspace/:id still uses it.

// ──────────────────────────────────────────────────────────────────────
// Workspace Shell
// ──────────────────────────────────────────────────────────────────────

class V5WorkspaceShell extends StatelessWidget {
  final V5Workspace workspace;

  const V5WorkspaceShell({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ApexV5ServiceSwitcher(currentServiceId: null),
        title: Row(
          children: [
            Icon(workspace.icon, color: workspace.color, size: 20),
            const SizedBox(width: 8),
            Text(workspace.labelAr),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 1),
          const Divider(height: 1),
          Expanded(child: ApexV5WorkspaceHome(workspace: workspace)),
        ],
      ),
    );
  }
}

// G-CLEANUP-3 (Sprint 15): `_LaunchpadQuickCard` helper deleted —
// it powered the "اختصارات سريعة" 4-card section that's no longer
// on the home. See file 39 § 2.2 / file 40 Stage 2 / 09 § 20.1
// G-CLEANUP-3.

// ──────────────────────────────────────────────────────────────────────
// 404
// ──────────────────────────────────────────────────────────────────────

class _V5NotFound extends StatelessWidget {
  const _V5NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            const Text(
              'المسار غير موجود',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/app'),
              child: const Text('العودة إلى Launchpad'),
            ),
          ],
        ),
      ),
    );
  }
}
