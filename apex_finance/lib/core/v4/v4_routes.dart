/// APEX V4 — GoRoute definitions (Wave 1.5).
///
/// New routes are added under `/app/...` and coexist with the existing
/// 99 routes in router.dart. Nothing is removed in this PR; the V4
/// shell is opt-in until sub-modules are fully migrated. See
/// blueprints/APEX_V4_Module_Hierarchy.txt for the target IA.
///
/// Route tree:
///   /app                        → Launchpad
///   /app/{group}                → first sub-module of group
///   /app/{group}/{sub}          → first visible tab of sub-module
///   /app/{group}/{sub}/{screen} → specific screen
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/v4_compliance/compliance_status_screen.dart';
import '../../screens/v4_compliance/zatca_queue_screen.dart';
import '../../screens/v4_erp/sales_customers_screen.dart';
import 'apex_launchpad.dart';
import 'apex_screen_host.dart';
import 'apex_sub_module_shell.dart';
import 'v4_groups.dart';

/// Public list of routes — imported from router.dart and spread into
/// the top-level GoRouter.routes array.
List<RouteBase> v4Routes() => [
      GoRoute(
        path: '/app',
        builder: (ctx, state) => const ApexLaunchpad(),
      ),
      GoRoute(
        path: '/app/:group',
        redirect: (ctx, state) {
          final group = v4GroupById(state.pathParameters['group']!);
          if (group == null || group.subModules.isEmpty) return '/app';
          final firstSub = group.subModules.first;
          final firstScreen = firstSub.visibleTabs.isNotEmpty
              ? firstSub.visibleTabs.first
              : (firstSub.overflow.isNotEmpty ? firstSub.overflow.first : null);
          if (firstScreen == null) return '/app';
          return '/app/${group.id}/${firstSub.id}/${_slug(firstScreen.id)}';
        },
      ),
      GoRoute(
        path: '/app/:group/:sub',
        redirect: (ctx, state) {
          final group = v4GroupById(state.pathParameters['group']!);
          final sub = group?.subModuleById(state.pathParameters['sub']!);
          if (group == null || sub == null) return '/app';
          final first = sub.visibleTabs.isNotEmpty
              ? sub.visibleTabs.first
              : (sub.overflow.isNotEmpty ? sub.overflow.first : null);
          if (first == null) return '/app';
          return '/app/${group.id}/${sub.id}/${_slug(first.id)}';
        },
      ),
      GoRoute(
        path: '/app/:group/:sub/:screen',
        builder: (ctx, state) {
          final groupId = state.pathParameters['group']!;
          final subId = state.pathParameters['sub']!;
          final screenSlug = state.pathParameters['screen']!;

          final group = v4GroupById(groupId);
          final sub = group?.subModuleById(subId);
          if (group == null || sub == null) {
            return const _NotFound();
          }

          final fullScreenId = '$groupId-$subId-$screenSlug';
          final screen = sub.allScreens.firstWhere(
            (s) => s.id == fullScreenId,
            orElse: () => sub.visibleTabs.isNotEmpty
                ? sub.visibleTabs.first
                : sub.overflow.first,
          );

          return ApexSubModuleShell(
            group: group,
            subModule: sub,
            activeScreen: screen,
            screenBuilder: (ctx, scr) => _defaultScreenHost(ctx, scr),
          );
        },
      ),
    ];

String _slug(String id) {
  final parts = id.split('-');
  return parts.length > 2 ? parts.sublist(2).join('-') : id;
}

/// Maps a V4Screen.id to its real Flutter widget. Screens not yet
/// wired fall through to the default "defined-but-not-implemented"
/// state host — a deliberate scaffolding that makes coverage gaps
/// visible rather than hiding them behind a generic "coming soon".
Widget _defaultScreenHost(BuildContext ctx, V4Screen screen) {
  final wired = _wiredScreens[screen.id];
  if (wired != null) return wired(ctx);
  return ApexScreenHost(
    state: ApexScreenState.emptyFirstTime,
    title: screen.labelAr,
    description:
        'هذه الشاشة تم تعريفها في هيكل V4 ولم تُربط بواجهة تفصيلية بعد. '
        'ستنضم إلى التنفيذ ضمن الموجة المخصصة لهذه الوحدة.',
  );
}

/// Registry of wired V4 screens. Add an entry when a screen's widget
/// is ready — the shell picks it up automatically via its screen id.
final Map<String, Widget Function(BuildContext)> _wiredScreens = {
  'erp-sales-customers': (ctx) => const SalesCustomersScreen(),
  // Wave 4 PR#2: first non-ERP V4 screen. Uses the status dashboard
  // pattern — KPI cards + hero score band. Data placeholder until the
  // Wave 5 backend exposes /compliance/status.
  'compliance-dashboard-status': (ctx) => const ComplianceStatusScreen(),
  // Wave 6: the ZATCA retry queue UI consumes the Wave 5 backend
  // endpoints (/zatca/queue, /stats, /{id}). Surfaced under the
  // Compliance > ZATCA sub-module's "Clearance Log" tab.
  'compliance-zatca-log': (ctx) => const ZatcaQueueScreen(),
};

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('غير موجود')),
      );
}
