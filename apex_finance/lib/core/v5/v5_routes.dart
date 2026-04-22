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
import '../theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

import '../../screens/v5_showcase/v5_showcase_screen.dart';
import 'apex_v5_service_shell.dart';
import 'apex_v5_service_switcher.dart';
import 'apex_v5_workspace_selector.dart';
import 'apps_hub_screen.dart';
import 'v5_data.dart';
import 'v5_models.dart';
import 'v5_wired_screens.dart';

/// List of routes to be spread into the top-level GoRouter.routes.
List<RouteBase> v5Routes() => [
      // Root redirects to launchpad (POC has no auth)
      GoRoute(path: '/', redirect: (ctx, state) => '/app'),
      GoRoute(path: '/login', redirect: (ctx, state) => '/app'),
      GoRoute(path: '/home', redirect: (ctx, state) => '/app'),
      GoRoute(
        path: '/app',
        builder: (ctx, state) => const V5Launchpad(),
      ),
      GoRoute(
        path: '/showcase',
        builder: (ctx, state) => const V5ShowcaseScreen(),
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
                ],
              ),
              const SizedBox(height: 20),

              // Showcase CTA banner
              GestureDetector(
                onTap: () => context.go('/showcase'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [core_theme.AC.gold, Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معرض V5.1 — 18 تحسين تستبدل 18 منصّة عالمية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'قيمة سنوية مُدمجة ~\$400K · اضغط للاستكشاف',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'استكشف',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_back, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Services grid
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

              const SizedBox(height: 32),

              // Workspaces
              Text(
                'بيئات العمل (Workspaces)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختصارات مجمّعة حسب دورك',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;
                  return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: cols,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final w in v5Workspaces)
                        _WorkspaceCard(workspace: w),
                    ],
                  );
                },
              ),
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
            color: _hover ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(_hover ? 0.4 : 0.15),
              width: _hover ? 2 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
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
                      color: color.withOpacity(0.15),
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
                          color: color.withOpacity(0.1),
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
                    color: color.withOpacity(0.12),
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

class _WorkspaceCard extends StatefulWidget {
  final V5Workspace workspace;

  const _WorkspaceCard({required this.workspace});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.workspace.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/workspace/${widget.workspace.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(_hover ? 0.3 : 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.workspace.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.workspace.labelAr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.workspace.shortcuts.length} اختصارات',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

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
