import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// G-ERP-UNIFICATION (2026-05-09): the /settings/entities redirect
// guard reads the legacy localStorage to decide whether to bypass
// the screen entirely.
import 'entity_store.dart';
import '../screens/copilot/copilot_screen.dart';
import '../screens/showcase/apex_showcase_screen.dart';
import '../screens/whats_new/apex_whats_new_hub.dart';
import '../screens/whats_new/uae_corp_tax_screen.dart';
import '../screens/whats_new/startup_metrics_screen.dart';
import '../screens/whats_new/industry_packs_screen.dart';
import '../screens/whats_new/feature_demos_screen.dart';
// Onboarding wizard variants deprecated — all routes redirect to the
// unified /app/erp/finance/onboarding (PilotOnboardingWizard).
// Files archived to _archive/2026-04-29/ (Stage 5a, 2026-04-29).
import '../screens/whats_new/sprint35_foundation_screen.dart';
import '../screens/whats_new/sprint37_experience_screen.dart';
import '../screens/whats_new/sprint38_composable_screen.dart';
import '../screens/whats_new/sprint39_erp_screen.dart';
// sprint40_payroll_reports_screen.dart archived (Stage 5e) — /sprint40-payroll redirects to /app/erp/hr/payroll.
import '../screens/whats_new/sprint41_procurement_screen.dart';
// sprint42_longterm_screen.dart archived (Stage 5e) — /sprint42-longterm redirects to /app/erp/treasury/cashflow.
import '../screens/whats_new/sprint43_platform_screen.dart';
import '../screens/whats_new/sprint44_operations_screen.dart';
import '../screens/whats_new/apex_map_screen.dart';
import '../screens/whats_new/theme_generator_screen.dart';
import '../screens/whats_new/white_label_settings_screen.dart';
import '../screens/whats_new/syncfusion_grid_demo_screen.dart';
import '../screens/financial/financial_ops_screen.dart';
import '../screens/knowledge/knowledge_brain_screen.dart';
// DASH-1.1: enhanced_dashboard.dart archived to lib/_archive/dashboards_v1/.
// /dashboard now resolves to CustomizableDashboard.
import '../screens/dashboard/customizable_dashboard.dart';
import '../screens/dashboard/dashboard_hooks_default.dart';
import '../screens/dashboard/role_layouts_admin.dart';
import '../screens/settings/enhanced_settings_screen.dart';
import '../screens/coa/coa_tree_screen.dart';
import '../screens/legal/legal_acceptance_screen.dart';
import '../screens/compliance/provider_compliance_detail.dart';
import '../screens/clients/client_detail_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../screens/auth/register_screen.dart' show RegScreen;
import '../screens/upgrade_plan_screen.dart' show UpgradePlanScreen;
import '../widgets/forms/knowledge_feedback_screen.dart' show KnowledgeFeedbackScreen;
// Stage 4f: V4 /marketplace/new-request archived → V5 /app/marketplace/browse/new-request — NewServiceRequestScreen import removed.
import '../widgets/main_nav.dart' show MainNav;
import '../screens/account/account_sub_screens.dart' show EditProfileScreen, ChangePasswordScreen, CloseAccountScreen, SessionsScreen;
import '../screens/admin/admin_sub_screens.dart' show ReviewerConsoleScreen, ProviderVerificationScreen, ProviderDocumentUploadScreen, ProviderComplianceScreen, PolicyManagementScreen, ActivityHistoryScreen, AuditLogScreen, KnowledgeDeveloperConsole, TaskTypesBrowserScreen;
import '../screens/admin/ai_suggestions_inbox_screen.dart';
import '../screens/admin/ai_console_screen.dart';
// import '../screens/compliance/bank_rec_ai_screen.dart'; // deduplicated → /accounting/bank-rec-v2
// import '../screens/compliance/depreciation_ai_screen.dart';  // redirects to existing /compliance/depreciation
// import '../screens/compliance/multi_currency_screen.dart'; // deduplicated → /analytics/multi-currency-v2
// onboarding_wizard_screen.dart archived to _archive/2026-04-29/ (Stage 5a).
import '../screens/admin/audit_chain_viewer_screen.dart';
import '../screens/admin/workflow_templates_screen.dart';
import '../screens/admin/workflow_rules_screen.dart';
import '../screens/admin/module_manager_screen.dart';
import '../screens/admin/webhooks_screen.dart';
import '../screens/admin/api_keys_screen.dart';
import '../screens/admin/suggestions_inbox_screen.dart';
import '../screens/admin/events_browser_screen.dart';
import '../screens/admin/custom_roles_screen.dart';
import '../screens/admin/admin_health_dashboard.dart';
import '../screens/admin/approvals_admin_screen.dart';
import '../screens/admin/anomaly_monitor_screen.dart';
import '../screens/admin/email_inbox_screen.dart';
import '../screens/admin/industry_packs_screen.dart';
import '../screens/admin/workflow_rule_builder_screen.dart';
import '../screens/admin/tenant_onboarding_screen.dart';
import '../screens/admin/tenants_directory_screen.dart';
import '../screens/admin/workflow_runs_screen.dart';
import '../screens/activity_feed_screen.dart';
// Operations duplicates kept as files for reference but unmounted —
// their routes now redirect to the pre-existing /compliance/* + /financial-ops screens.
// import '../screens/operations/financial_ops_hub_screen.dart';
// import '../screens/operations/je_creator_screen.dart';
// import '../screens/operations/financial_statements_formatted_screen.dart';
// import '../screens/operations/financial_analysis_screen.dart';
// DASH-1.1: today_dashboard_screen.dart archived to lib/_archive/dashboards_v1/.
// /today now resolves to CustomizableDashboard (same screen as /dashboard).
// Stage 4g: V4 /launchpad/full now redirects to /app — apex_launchpad_screen.dart kept in lib/screens/home/ but unmounted from router.
import '../screens/home/apex_service_hub_screen.dart';
import '../screens/home/apex_services_screen.dart';
// G-CLEANUP-1 Stage 4b (Sprint 15, 2026-05-04): je_builder_live_v52 prefix
// import deleted alongside the V4 /compliance/journal-entry/:id route.
// V5 routes for the JE Builder (under /app/erp/finance/je-builder/...)
// are wired in lib/core/v5/v5_routes.dart, not here.
import '../screens/operations/receipt_capture_screen.dart';
import '../screens/settings/unified_settings_screen.dart';
import '../screens/notifications/notifications_panel_screen.dart';
import '../screens/operations/pos_quick_sale_screen.dart';
import '../screens/operations/customer_payment_screen.dart';
// G-FIN-CUSTOMERS-COMPLETE (Sprint 2, 2026-05-09): customer details
// (3-tab screen with details / ledger / invoices) lives here.
import '../screens/operations/customer_details_screen.dart';
// G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09): vendor details
// (3-tab screen with details / ledger / purchase-invoices) lives here.
import '../screens/operations/vendor_details_screen.dart';
// G-FIN-PURCHASE-INVOICE-JE-AUTOPOST (Sprint 6, 2026-05-09): dedicated
// purchase invoice create screen with vendor picker + save-draft +
// JE-link snackbar.
import '../screens/operations/purchase_invoice_create_screen.dart';
// G-SALES-INVOICE-UX-COMPLETE (2026-05-10): sales-invoice details screen.
// Closes the Bug-#1 (row click was opening JE-builder instead of details).
import '../screens/operations/sales_invoice_details_screen.dart';
import '../screens/operations/vendor_payment_screen.dart';
// G-CLEANUP-1 Stage 4b: JeListScreen archived to _archive/2026-05-04/v4-routes/.
// Replaced by V5 list at /app/erp/finance/je-builder.
import '../screens/reports/reports_hub_screen.dart';
import '../screens/admin/ai_suggestions_queue_v2_screen.dart';
import '../screens/settings/bank_feed_setup_screen.dart';
import '../screens/knowledge/knowledge_search_v2_screen.dart';
import '../screens/workflow/approvals_inbox_screen.dart';
import '../screens/compliance/risk_register_screen.dart';
import '../screens/extracted/subscription_screens.dart';
import '../screens/extracted/notification_screens_v2.dart';
import '../screens/extracted/legal_screens_v2.dart';
import '../screens/extracted/client_screens.dart';
import '../screens/coa_v2/coa_journey_screen.dart';
import '../screens/auth/forgot_password_flow.dart';
import '../screens/auth/slide_auth_screen.dart';
// client_onboarding_wizard removed — redirected to unified /settings/entities
import '../screens/account/archive_screen.dart' as archive;
// G-CLEANUP-1 Stage 4c-prep: AuditServiceScreen archived to _archive/2026-05-04/v4-routes/audit/.
// V4 /audit/service redirects to /app/marketplace/dashboard.
import '../core/session.dart' show S;
import 'auth_guard.dart';
// client_create.dart import removed — redirected to unified /settings/entities
import '../upload_screen.dart';
import '../analysis_full_screen.dart';
import '../analysis_result_screen.dart';
import '../coa_upload_screen.dart';
import '../coa_mapping_screen.dart';
import '../coa_quality_screen.dart';
import '../coa_review_screen.dart';
import '../screens/simulation/financial_simulation_screen.dart';
import '../screens/simulation/compliance_check_screen.dart';
import '../screens/simulation/roadmap_screen.dart';
import '../screens/simulation/trial_balance_screen.dart';
import '../tb_binding_screen.dart';
import '../financial_statements_screen.dart';
// import '../screens/compliance/journal_entries_screen.dart'; // deduplicated → /accounting/je-list
// Stage 4g: V4 /compliance hub now redirects to /app/compliance/dashboard — ComplianceHubScreen kept on disk for V5 chip wiring elsewhere.
// Legacy screens deduplicated to canonical paths (Phase 26):
// import '../screens/compliance/budget_variance_screen.dart'; // → /analytics/budget-variance-v2
// import '../screens/compliance/bank_rec_screen.dart';        // → /accounting/bank-rec-v2
// import '../screens/compliance/inventory_screen.dart';       // → /operations/inventory-v2
// import '../screens/compliance/aging_screen.dart';           // → /sales/aging
// import '../screens/compliance/health_score_screen.dart'; // deduplicated → /analytics/health-score-v2
// G-CLEANUP-1 Stage 4b: JournalEntryBuilderScreen archived to
// _archive/2026-05-04/v4-routes/. Replaced by V5.2 builder at
// /app/erp/finance/je-builder/new (lib/core/v5/v5_routes.dart).
// import '../screens/compliance/cost_variance_screen.dart'; // deduplicated → /analytics/cost-variance-v2
// import '../screens/compliance/wht_screen.dart';         // deduplicated → /compliance/wht-v2
// import '../screens/compliance/consolidation_screen.dart'; // deduplicated → /compliance/consolidation-v2
// import '../screens/compliance/lease_screen.dart'; // deduplicated → /compliance/lease-v2
// import '../screens/compliance/fixed_assets_screen.dart'; // deduplicated → /operations/fixed-assets-v2
import 'package:file_picker/file_picker.dart';
import 'v5/v5_routes.dart';
import 'apex_bottom_nav.dart';
import 'apex_magnetic_shell.dart';
import 'apex_tabs_shell.dart';
import '../screens/lab/innovation_lab_screen.dart';
import '../screens/settings/entity_setup_screen.dart';
import '../screens/account/mfa_screen.dart';

// ERR-1 (2026-05-07): the cross-cutting auth-refresh notifier moved
// to `auth_guard.dart` so the 401 interceptor in api_service.dart can
// bump it without importing this file (which would cycle through 200+
// screen widgets). Re-export the canonical reference under the
// historical name for source-compat.
final authRefresh = apexAuthRefresh;

/// Redirect guard for demo / dev-tool / showcase routes.
/// Returns null (allow) when the current session has platform_admin or
/// super_admin; otherwise redirects to the launchpad.
/// Use as `redirect: _adminOnly` on any GoRoute that should not be visible
/// to end users (mock data, component demos, internal tooling).
String? _adminOnly(BuildContext c, GoRouterState s) {
  // In debug mode, allow all routes for easier dev testing.
  // Production builds still gate admin screens by role.
  if (kDebugMode) return null;
  return S.isPlatformAdmin ? null : '/app';
}

/// Routes that should NOT get the magnetic shell + bottom nav (auth, onboarding).
bool _isChromeRoute(GoRouterState state) {
  final p = state.uri.path;
  if (p == '/login' || p == '/register' || p.startsWith('/forgot-password')) return false;
  if (p == '/onboarding' || p.startsWith('/onboarding/')) return false;
  return true;
}

CustomTransitionPage<void> _apexPage(Widget child, GoRouterState state) {
  Widget wrapped = child;
  if (_isChromeRoute(state)) {
    // Pick the active shell at render time so flipping ApexShellMode
    // re-wraps the same screen in the chosen chrome instantly.
    wrapped = ValueListenableBuilder<bool>(
      valueListenable: ApexShellMode.useTabs,
      builder: (ctx, useTabs, kid) => useTabs
          ? ApexTabsShell(child: kid!)
          : ApexMagneticShell(child: kid!),
      child: wrapped,
    );
    wrapped = ApexBottomNav(currentPath: state.uri.path, child: wrapped);
  }
  return CustomTransitionPage(
    key: state.pageKey,
    child: wrapped,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 0.02), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  refreshListenable: authRefresh,
  // V5.1: /app is the new default landing. Shows the 5-service Launchpad
  // with 16-app ERP grid and horizontal layer (Cmd+K, Entity Scope, etc.)
  // Phase 27.5: V5 Launchpad is the entry point (per user request)
  initialLocation: '/app',
  // Global auth guard (G-S2 2026-05-01): if no token, force /login. The
  // logic itself lives in `auth_guard.dart` as a pure function so it can
  // be unit-tested without pulling `dart:html` from `session.dart` (the
  // same blocker tracked as G-T1.1). See `auth_guard.dart` for the
  // rationale on why auth-flow paths bypass the guard.
  redirect: (context, state) =>
      authGuardRedirect(path: state.uri.path, token: S.token),
    routes: [
    // ── New IA Service Hubs (Blueprint v1.0) — registered BEFORE v5/v4 ──
    // Each top-level service path now opens a Hub screen with featured
    // tiles + secondary tools, instead of redirecting blindly into one
    // sub-screen. This gives the user the proper hierarchical navigation:
    //   Launchpad → Service Hub → App → Detail screen
    // Sprint 15 Stage 4g: V4 service hubs redirect to V5 equivalents.
    // ApexServiceHubScreen kept in lib/screens/home/ for the launchpad fallback —
    // these specific URL bindings just funnel users into the V5 service tree.
    GoRoute(path: '/sales', redirect: (c, s) => '/app/erp/sales/dashboard'),
    GoRoute(path: '/purchase', redirect: (c, s) => '/app/erp/purchasing/dashboard'),
    GoRoute(path: '/accounting', redirect: (c, s) => '/app/erp/finance/dashboard'),
    GoRoute(path: '/operations', redirect: (c, s) => '/app/erp/finance/dashboard'),
    GoRoute(path: '/compliance-hub', redirect: (c, s) => '/app/compliance/dashboard'),
    GoRoute(path: '/audit-hub', redirect: (c, s) => '/app/audit/dashboard'),
    GoRoute(path: '/audit', redirect: (c, s) => '/app/audit/dashboard'),
    GoRoute(path: '/analytics', redirect: (c, s) => '/app/erp/finance/dashboard'),
    GoRoute(path: '/hr', redirect: (c, s) => '/app/erp/hr/dashboard'),
    GoRoute(path: '/hr-hub', redirect: (c, s) => '/app/erp/hr/dashboard'),
    GoRoute(path: '/workflow', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'workflow-hub'), s)),
    GoRoute(path: '/workflow-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'workflow-hub'), s)),
    GoRoute(path: '/settings-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'settings-hub'), s)),

    // Setup alias — keep simple redirect.
    GoRoute(path: '/setup', redirect: (c, s) => '/settings/entities'),
    GoRoute(path: '/reports', pageBuilder: (c, s) => _apexPage(const ReportsHubScreen(), s)),
    // DASH-1.1: /today now mounts CustomizableDashboard. The legacy TodayDashboardScreen is archived.
    GoRoute(path: '/today', pageBuilder: (c, s) => _apexPage(
      CustomizableDashboard(
        title: 'اليوم',
        hooks: defaultDashboardHooks(target: DashboardEditTarget.user),
      ),
      s,
    )),
    GoRoute(path: '/lab', pageBuilder: (c, s) => _apexPage(const InnovationLabScreen(), s)),

    // ── Services Page (Level 0) — clean entry point ──
    // The user's mental model: Services → Apps → Screen → Detail.
    // /services shows the 11 services as big tiles. Clicking one opens
    // its hub (e.g., /sales → SalesHub with apps tiles), and from there
    // you click an app to open its working screen.
    GoRoute(path: '/services', pageBuilder: (c, s) => _apexPage(const ApexServicesScreen(), s)),
    GoRoute(path: '/launchpad', redirect: (c, s) => '/app'),
    GoRoute(path: '/apps', redirect: (c, s) => '/app'),
    GoRoute(path: '/all', redirect: (c, s) => '/app'),
    // Old verbose Launchpad still accessible at /launchpad/full for power users
    // Sprint 15 Stage 4g: verbose V4 launchpad redirects to V5 launchpad.
    GoRoute(path: '/launchpad/full', redirect: (c, s) => '/app'),

    // ── V5.1 shell (16-app ERP + Cmd+K palette + Entity Scope) ──
    // V4 shell removed in G-A2 (2026-04-30). V5 owns the /app namespace.
    ...v5Routes(),

    // Auth
    GoRoute(path: '/login', pageBuilder: (c, s) => _apexPage(const SlideAuthScreen(), s)),
    // GoRoute(path: '/login-old', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', pageBuilder: (c, s) => _apexPage(const RegScreen(), s)),
    GoRoute(path: '/forgot-password', pageBuilder: (c, s) => _apexPage(const ForgotPasswordScreen(), s)),

    // Main app (with bottom nav)
    GoRoute(path: '/home', pageBuilder: (c, s) => _apexPage(const MainNav(), s)),

    // Apex Components Showcase — demos every new shared component.
    // Reachable via Cmd+K -> "Apex Showcase" or directly.
    GoRoute(
      path: '/showcase',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ApexShowcaseScreen(), s),
    ),
    // What's New Hub — landing page for every backend capability added.
    GoRoute(
      path: '/whats-new',
      pageBuilder: (c, s) => _apexPage(const ApexWhatsNewHub(), s),
    ),
    // Interactive demos of each new backend feature.
    GoRoute(
      path: '/uae-corp-tax',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const UaeCorpTaxScreen(), s),
    ),
    GoRoute(
      path: '/sprint35-foundation',
      pageBuilder: (c, s) => _apexPage(const Sprint35FoundationScreen(), s),
    ),
    GoRoute(
      path: '/sprint37-experience',
      pageBuilder: (c, s) => _apexPage(const Sprint37ExperienceScreen(), s),
    ),
    GoRoute(
      path: '/sprint38-composable',
      pageBuilder: (c, s) => _apexPage(const Sprint38ComposableScreen(), s),
    ),
    GoRoute(
      path: '/sprint39-erp',
      pageBuilder: (c, s) => _apexPage(const Sprint39ErpScreen(), s),
    ),
    // sprint40 features (Payroll + Reports) graduated to production:
    // /app/erp/hr/payroll + /app/erp/reports-bi/custom-reports.
    // Sprint screen archived to _archive/2026-04-29/orphans/whats_new/ (Stage 5e).
    GoRoute(path: '/sprint40-payroll', redirect: (c, s) => '/app/erp/hr/payroll'),
    GoRoute(
      path: '/sprint41-procurement',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint41ProcurementScreen(), s),
    ),
    // sprint42 features (Cashflow + Consolidation + BOM/MRP) all graduated to
    // production. Sprint screen archived to _archive/2026-04-29/ (Stage 5e).
    GoRoute(path: '/sprint42-longterm', redirect: (c, s) => '/app/erp/treasury/cashflow'),
    GoRoute(
      path: '/sprint43-platform',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint43PlatformScreen(), s),
    ),
    GoRoute(
      path: '/sprint44-operations',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint44OperationsScreen(), s),
    ),
    GoRoute(
      path: '/apex-map',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ApexMapScreen(), s),
    ),
    GoRoute(
      path: '/theme-generator',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ThemeGeneratorScreen(), s),
    ),
    GoRoute(
      path: '/white-label',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WhiteLabelSettingsScreen(), s),
    ),
    GoRoute(
      path: '/syncfusion-grid',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const SyncfusionGridDemoScreen(), s),
    ),
    GoRoute(
      path: '/startup-metrics',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const StartupMetricsScreen(), s),
    ),
    GoRoute(
      path: '/industry-packs',
      pageBuilder: (c, s) => _apexPage(const IndustryPacksScreen(), s),
    ),
    GoRoute(
      path: '/payments-playground',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const PaymentsPlaygroundScreen(), s),
    ),
    GoRoute(
      path: '/ap-pipeline-demo',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ApPipelineScreen(), s),
    ),
    GoRoute(
      path: '/bank-ocr-demo',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const BankOcrDemoScreen(), s),
    ),
    // GOSI + EOSB calculators promoted to production HR features (Stage 5b
    // follow-up, 2026-04-29). Old /*-demo paths kept as redirects for
    // backward compatibility with bookmarks and external links.
    // G-CLEANUP-1 Stage 4c-prep (Sprint 15): /hr/gosi + /hr/eosb routes
    // marked DEFERRED in V4_CLASSIFICATION_2026-05-04.md. Both screens
    // (GosiCalcScreen + EosbCalcScreen) live as sub-classes of the
    // larger screens/whats_new/feature_demos_screen.dart file alongside
    // ~10 other unrelated demo screens. Splitting that shared file into
    // per-screen modules is a separate cleanup (track G-CLEANUP-1.1)
    // that needs to land before these V4 routes can be archived. Until
    // then the V4 paths stay; the V5 home will be /app/erp/hr/gosi and
    // /app/erp/hr/eosb after the split.
    GoRoute(
      path: '/hr/gosi',
      pageBuilder: (c, s) => _apexPage(const GosiCalcScreen(), s),
    ),
    GoRoute(
      path: '/hr/eosb',
      pageBuilder: (c, s) => _apexPage(const EosbCalcScreen(), s),
    ),
    GoRoute(path: '/gosi-demo', redirect: (c, s) => '/hr/gosi'),
    GoRoute(path: '/eosb-demo', redirect: (c, s) => '/hr/eosb'),
    GoRoute(
      path: '/whatsapp-demo',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WhatsAppDemoScreen(), s),
    ),
    // Single canonical onboarding path — all variants redirect here.
    // The wizard at /app/erp/finance/onboarding (PilotOnboardingWizard)
    // is the only place users create new tenants/entities/branches.
    GoRoute(
      path: '/onboarding',
      redirect: (c, s) => '/app/erp/finance/onboarding',
    ),

    // Sprint 15 Stage 4g: V4 /compliance hub redirects to V5 compliance dashboard.
    // ComplianceHubScreen kept on disk — still imported by V5 chip wiring elsewhere.
    GoRoute(path: '/compliance', redirect: (c, s) => '/app/compliance/dashboard'),
    // Legacy → canonical (Phase 26 dedup)
    // G-CLEANUP-1 Stage 4b: V4 /compliance/journal-entries redirect deleted.
    // V5: /app/erp/finance/je-builder (LIST).
        // Sprint 15 Stage 4e: V4 /compliance/audit-trail archived → V5 /app/audit/trail
        // Sprint 15 Stage 4e: V4 /compliance/zatca-invoice archived → V5 /app/compliance/zatca/invoice
        // Sprint 15 Stage 4e: V4 /compliance/zakat archived → V5 /app/compliance/tax/zakat
        // Sprint 15 Stage 4e: V4 /compliance/vat-return archived → V5 /app/compliance/tax/vat-return
        // Sprint 15 Stage 4e: V4 /compliance/ratios archived → V5 /app/advisory/ratios/dashboard
        // Sprint 15 Stage 4e: V4 /compliance/depreciation archived → V5 /app/erp/finance/depreciation
        // Sprint 15 Stage 4e: V4 /compliance/cashflow archived → V5 /app/erp/finance/cashflow
        // Sprint 15 Stage 4e: V4 /compliance/amortization archived → V5 /app/erp/finance/amortization
        // Sprint 15 Stage 4e: V4 /compliance/payroll archived → V5 /app/erp/hr/payroll
        // Sprint 15 Stage 4e: V4 /compliance/breakeven archived → V5 /app/advisory/ratios/breakeven
        // Sprint 15 Stage 4e: V4 /compliance/investment archived → V5 /app/advisory/valuation/investment
        // Sprint 15 Stage 4e: V4 /compliance/budget-variance archived → V5 /app/erp/finance/budget-actual
        // Sprint 15 Stage 4e: V4 /compliance/bank-rec archived → V5 /app/erp/treasury/recon
        // Sprint 15 Stage 4e: V4 /compliance/inventory archived → V5 /app/erp/inventory/inventory
        // Sprint 15 Stage 4c: V4 /compliance/aging archived → V5 /app/erp/sales/ar-aging
        // Sprint 15 Stage 4e: V4 /compliance/working-capital archived → V5 /app/advisory/ratios/working-capital
        // Sprint 15 Stage 4e: V4 /compliance/health-score archived → V5 /app/erp/finance/health-score
    GoRoute(path: '/compliance/executive', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived (V4 screen has zero backend; redirected to V5 home)
        // Sprint 15 Stage 4e: V4 /compliance/ocr archived → V5 /app/erp/finance/receipt-capture
        // Sprint 15 Stage 4e: V4 /compliance/dscr archived → V5 /app/advisory/ratios/dscr
        // Sprint 15 Stage 4e: V4 /compliance/valuation archived → V5 /app/advisory/valuation/dashboard
    // G-CLEANUP-1 Stage 4b: V4 /compliance/journal-entry-builder pageBuilder
    // deleted. JournalEntryBuilderScreen archived to
    // _archive/2026-05-04/v4-routes/. V5: /app/erp/finance/je-builder/new
    // (JeBuilderLiveV52Screen, wired in lib/core/v5/v5_routes.dart).
        // Sprint 15 Stage 4e: V4 /compliance/fx-converter archived → V5 /app/erp/treasury/fx-converter
        // Sprint 15 Stage 4e: V4 /compliance/cost-variance archived → V5 /app/erp/finance/dashboard
        // Sprint 15 Stage 4e: V4 /compliance/financial-statements archived → V5 /app/erp/finance/statements
        // Sprint 15 Stage 4e: V4 /compliance/cashflow-statement archived → V5 /app/erp/finance/cashflow
        // Sprint 15 Stage 4e: V4 /compliance/wht archived → V5 /app/compliance/tax/wht
        // Sprint 15 Stage 4e: V4 /compliance/consolidation archived → V5 /app/erp/consolidation/dashboard
        // Sprint 15 Stage 4e: V4 /compliance/deferred-tax archived → V5 /app/compliance/ifrs/deferred-tax
        // Sprint 15 Stage 4e: V4 /compliance/lease archived → V5 /app/compliance/ifrs/dashboard
        // Sprint 15 Stage 4e: V4 /compliance/ifrs-tools archived → V5 /app/compliance/ifrs/tools
        // Sprint 15 Stage 4e: V4 /compliance/fixed-assets archived → V5 /app/erp/finance/fixed-assets
        // Sprint 15 Stage 4e: V4 /compliance/transfer-pricing archived → V5 /app/compliance/tax/tp
        // Sprint 15 Stage 4e: V4 /compliance/extras-tools archived → V5 /app/compliance/ifrs/extras
    // Account
    GoRoute(path: '/profile/edit', pageBuilder: (c, s) => _apexPage(EditProfileScreen(profile: s.extra as Map<String, dynamic>? ?? {}), s)),
    GoRoute(path: '/password/change', pageBuilder: (c, s) => _apexPage(const ChangePasswordScreen(), s)),
    GoRoute(path: '/account/close', pageBuilder: (c, s) => _apexPage(const CloseAccountScreen(), s)),
    GoRoute(path: '/account/sessions', pageBuilder: (c, s) => _apexPage(const SessionsScreen(), s)),
    GoRoute(
      path: '/account/mfa',
      pageBuilder: (c, s) => _apexPage(const MfaScreen(), s),
    ),
    GoRoute(path: '/account/activity', pageBuilder: (c, s) => _apexPage(const ActivityHistoryScreen(), s)),

    // Subscription
    GoRoute(path: '/subscription', pageBuilder: (c, s) => _apexPage(const SubscriptionScreen(), s)),
    GoRoute(path: '/plans/compare', pageBuilder: (c, s) => _apexPage(const PlanComparisonScreen(), s)),

    // Notifications
    GoRoute(path: '/notifications', pageBuilder: (c, s) => _apexPage(const NotificationCenterScreenV2(), s)),
    GoRoute(path: '/notifications/prefs', pageBuilder: (c, s) => _apexPage(const NotificationPrefsScreen(), s)),

    // Legal
    GoRoute(path: '/legal', pageBuilder: (c, s) => _apexPage(LegalDocumentsScreenV2(), s)),

    // Clients
    GoRoute(path: '/clients', pageBuilder: (c, s) => _apexPage(const ClientListScreen(), s)),

    // Archive
    GoRoute(path: '/archive', pageBuilder: (c, s) => _apexPage(archive.ArchiveScreen(token: S.token ?? ''), s)),

    // Knowledge
    GoRoute(path: '/knowledge/feedback', pageBuilder: (c, s) => _apexPage(const KnowledgeFeedbackScreen(), s)),
    GoRoute(path: '/knowledge/console', pageBuilder: (c, s) => _apexPage(const KnowledgeDeveloperConsole(), s)),

    // Tasks
    GoRoute(path: '/tasks/types', pageBuilder: (c, s) => _apexPage(const TaskTypesBrowserScreen(), s)),

    // Admin
    GoRoute(path: '/admin/reviewer', pageBuilder: (c, s) => _apexPage(const ReviewerConsoleScreen(), s)),
    GoRoute(path: '/admin/providers/verify', pageBuilder: (c, s) => _apexPage(const ProviderVerificationScreen(), s)),
    GoRoute(path: '/admin/providers/documents', pageBuilder: (c, s) => _apexPage(const ProviderDocumentUploadScreen(), s)),
    GoRoute(path: '/admin/providers/compliance', pageBuilder: (c, s) => _apexPage(const ProviderComplianceScreen(), s)),
    GoRoute(path: '/admin/policies', pageBuilder: (c, s) => _apexPage(const PolicyManagementScreen(), s)),
    GoRoute(path: '/provider-kanban', redirect: (c, s) => '/app/marketplace/provider-ops/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/client-detail', pageBuilder: (c, s) { final args = s.extra as Map<String,dynamic>? ?? {}; return _apexPage(ClientDetailScreen(clientId: args['id'] ?? '', clientName: args['name'] ?? ''), s); }),
    GoRoute(path: '/legal-acceptance', pageBuilder: (c, s) => _apexPage(const LegalAcceptanceLogger(), s)),
    GoRoute(path: '/compliance-detail', pageBuilder: (c, s) => _apexPage(const ProviderComplianceDetailScreen(), s)),
    GoRoute(path: '/coa-tree', pageBuilder: (c, s) => _apexPage(const CoaTreeScreen(), s)),
    GoRoute(path: '/settings', pageBuilder: (c, s) => _apexPage(const EnhancedSettingsScreen(), s)),
    // DASH-1.1 (2026-05-06): /dashboard now mounts CustomizableDashboard.
    // The v1 EnhancedDashboard is archived under apex_finance/_archive/2026-05-06/dashboards_v1/.
    GoRoute(path: '/dashboard', pageBuilder: (c, s) => _apexPage(
      CustomizableDashboard(
        hooks: defaultDashboardHooks(target: DashboardEditTarget.user),
      ),
      s,
    )),
    // DASH-1.1: admin-only — manage role-default layouts.
    // Permission gate (manage:dashboard_role) is enforced inside the screen.
    GoRoute(
      path: '/dashboard/admin/role-layouts',
      pageBuilder: (c, s) => _apexPage(const RoleLayoutsAdminScreen(), s),
    ),
    GoRoute(path: '/audit-workflow', redirect: (c, s) => '/app/audit/engagement/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/knowledge-brain', pageBuilder: (c, s) => _apexPage(const KnowledgeBrainScreen(), s)),
    GoRoute(path: '/financial-ops', pageBuilder: (c, s) => _apexPage(const FinancialOpsScreen(), s)),
    GoRoute(path: '/copilot', pageBuilder: (c, s) => _apexPage(const CopilotScreen(), s)),
    GoRoute(path: '/admin/audit', pageBuilder: (c, s) => _apexPage(const AuditLogScreen(), s)),
    GoRoute(path: '/admin/ai-suggestions', pageBuilder: (c, s) => _apexPage(const AiSuggestionsInboxScreen(), s)),
    GoRoute(path: '/admin/ai-console', pageBuilder: (c, s) => _apexPage(const AiConsoleScreen(), s)),
        // Sprint 15 Stage 4e: V4 /compliance/tax-timeline archived → V5 /app/compliance/tax/timeline
        // Sprint 15 Stage 4e: V4 /compliance/bank-rec-ai archived → V5 /app/erp/treasury/recon
        // Sprint 15 Stage 4e: V4 /compliance/audit-workflow-ai archived → V5 /app/audit/engagement/ai-workflow
        // Sprint 15 Stage 4e: V4 /compliance/islamic-finance archived → V5 /app/compliance/ifrs/islamic
    // ── My new "AI-assisted" depreciation was a duplicate — redirect to the
    //    pre-existing /compliance/depreciation + /compliance/fixed-assets screens.
        // Sprint 15 Stage 4e: V4 /compliance/depreciation-ai archived → V5 /app/erp/finance/depreciation
        // Sprint 15 Stage 4e: V4 /compliance/multi-currency archived → V5 /app/erp/treasury/dashboard
    GoRoute(path: '/onboarding/wizard', redirect: (c, s) => '/app/erp/finance/onboarding'),
    GoRoute(path: '/admin/audit-chain', pageBuilder: (c, s) => _apexPage(const AuditChainViewerScreen(), s)),
    // Workflow Engine admin UI (Wave 1A Phase G + Wave 1C Phase M).
    // Both gated behind admin role via the sidebar; the screens
    // themselves prompt for X-Admin-Secret on first visit.
    GoRoute(
      path: '/admin/workflow/rules',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WorkflowRulesScreen(), s),
    ),
    GoRoute(
      path: '/admin/workflow/templates',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WorkflowTemplatesScreen(), s),
    ),
    GoRoute(
      path: '/admin/modules',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ModuleManagerScreen(), s),
    ),
    GoRoute(
      path: '/admin/webhooks',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WebhooksScreen(), s),
    ),
    GoRoute(
      path: '/admin/api-keys',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ApiKeysScreen(), s),
    ),
    GoRoute(
      path: '/admin/suggestions',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const SuggestionsInboxScreen(), s),
    ),
    GoRoute(
      path: '/admin/events',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const EventsBrowserScreen(), s),
    ),
    GoRoute(
      path: '/admin/roles',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const CustomRolesScreen(), s),
    ),
    GoRoute(
      path: '/admin/dashboard-health',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const AdminHealthDashboard(), s),
    ),
    GoRoute(
      path: '/admin/approvals',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const ApprovalsAdminScreen(), s),
    ),
    GoRoute(
      path: '/admin/anomaly',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const AnomalyMonitorScreen(), s),
    ),
    GoRoute(
      path: '/admin/email-inbox',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const EmailInboxScreen(), s),
    ),
    GoRoute(
      path: '/admin/industry-packs',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const AdminIndustryPacksScreen(), s),
    ),
    GoRoute(
      path: '/admin/workflow/rules/new',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WorkflowRuleBuilderScreen(), s),
    ),
    GoRoute(
      path: '/admin/tenant-onboarding',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const TenantOnboardingScreen(), s),
    ),
    GoRoute(
      path: '/admin/tenants',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const TenantsDirectoryScreen(), s),
    ),
    GoRoute(
      path: '/admin/workflow/runs',
      redirect: _adminOnly,
      pageBuilder: (c, s) => _apexPage(const WorkflowRunsScreen(), s),
    ),
    GoRoute(
      path: '/activity',
      pageBuilder: (c, s) => _apexPage(const ActivityFeedScreen(), s),
    ),
    // ── Operations routes redirect to pre-existing screens (avoid duplication) ──
    GoRoute(path: '/operations/hub', redirect: (c, s) => '/financial-ops'),
    // G-CLEANUP-1 Stage 4b: V4 /operations/je-creator redirect deleted.
    // V5: /app/erp/finance/je-builder/new.
    GoRoute(path: '/operations/financial-statements', redirect: (c, s) => '/compliance/financial-statements'),
    GoRoute(path: '/operations/financial-analysis', redirect: (c, s) => '/compliance/ratios'),
    GoRoute(path: '/operations/universal-journal', redirect: (c, s) => '/app/erp/finance/je-builder'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    // Sprint 15 Stage 4f: V4 /operations/period-close archived (HAS_V5) -> V5 /app/erp/finance/period-close
    // Sprint 15 Stage 4f: V4 /operations/pos-sessions archived (REAL_NEW_V5) -> V5 /app/erp/pos/sessions
    // Sprint 15 Stage 4f: V4 /operations/purchase-cycle archived (REAL_NEW_V5) -> V5 /app/erp/purchasing/cycle
    GoRoute(path: '/operations/consolidation-ui', redirect: (c, s) => '/app/erp/consolidation/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    // Sprint 15 Stage 4f: V4 /operations/live-sales-cycle archived (REAL_NEW_V5) -> V5 /app/erp/sales/live-cycle
    // /today and /sales etc. moved to top of routes list — see above
        // Sprint 15 Stage 4d: V4 /accounting/coa archived → V5 /app/erp/finance/coa-editor
    // G-CLEANUP-1 Stage 4b: V4 /accounting/journal-entries redirect deleted.
    // V5: /app/erp/finance/je-builder.
        // Sprint 15 Stage 4d: V4 /accounting/trial-balance archived → V5 /app/erp/finance/statements
        // Sprint 15 Stage 4d: V4 /accounting/period-close archived → V5 /app/erp/finance/period-close
    // /financial-statements canonical (with optional apiData/pickedFile) defined below at line ~805 — duplicate redirect removed (Stage 1 bugfix 2026-04-29).
    // Sprint 15 Stage 4f: V4 /audit/engagements archived (HAS_V5) -> V5 /app/audit/engagement/dashboard
    // Sprint 15 Stage 4f: V4 /audit/engagement-workspace archived (alias) -> V5 /app/audit/engagement/dashboard
    // Sprint 15 Stage 4f: V4 /audit/benford archived (alias) -> V5 /app/audit/engagement/dashboard
    // Sprint 15 Stage 4f: V4 /audit/sampling archived (alias) -> V5 /app/audit/engagement/dashboard
    // Sprint 15 Stage 4f: V4 /audit/workpapers archived (alias) -> V5 /app/audit/engagement/dashboard
    GoRoute(path: '/setup', redirect: (c, s) => '/settings/entities'),
    GoRoute(path: '/setup/entity', redirect: (c, s) => '/settings/entities'),
    // Sprint 15 Stage 4f: V4 /operations/customer-360/:id archived (REAL_NEW_V5) -> V5 /app/erp/sales/customer-360/:id
    // Sprint 15 Stage 4f: V4 /operations/vendor-360/:id archived (REAL_NEW_V5) -> V5 /app/erp/purchasing/vendor-360/:id
    GoRoute(path: '/receipt/capture', pageBuilder: (c, s) => _apexPage(const ReceiptCaptureScreen(), s)),
    GoRoute(path: '/settings/unified', pageBuilder: (c, s) => _apexPage(const UnifiedSettingsScreen(), s)),
        // Sprint 15 Stage 4c: V4 /sales/customers archived → V5 /app/erp/finance/sales-customers
        // Sprint 15 Stage 4c: V4 /sales/invoices archived → V5 /app/erp/sales/invoices
        // Sprint 15 Stage 4c: V4 /sales/invoices/new archived → V5 /app/erp/sales/invoice-create
        // Sprint 15 Stage 4c: V4 /sales/aging archived → V5 /app/erp/sales/ar-aging
        // Sprint 15 Stage 4d: V4 /purchase/vendors archived → V5 /app/erp/purchasing/suppliers
        // Sprint 15 Stage 4d: V4 /purchase/bills archived → V5 /app/erp/finance/purchase-bills
    // /purchase/bills/new doesn't exist yet (no PurchaseBillCreateScreen
    // sibling to SalesInvoiceCreateScreen). Redirect to the purchase hub
    // so any old links the user (or another screen) navigates to don't
    // crash with GoException.
        // Sprint 15 Stage 4d: V4 /purchase/bills/new archived → V5 /app/erp/finance/purchase-bills
        // Sprint 15 Stage 4d: V4 /purchase/aging archived → V5 /app/erp/purchasing/ap-aging
    GoRoute(path: '/notifications/panel', pageBuilder: (c, s) => _apexPage(const NotificationsPanelScreen(), s)),
    GoRoute(path: '/pos/quick-sale', pageBuilder: (c, s) => _apexPage(const PosQuickSaleScreen(), s)),
    GoRoute(
      path: '/sales/payment/:invoiceId',
      pageBuilder: (c, s) => _apexPage(
        CustomerPaymentScreen(invoiceId: s.pathParameters['invoiceId']!),
        s,
      ),
    ),
    // G-FIN-CUSTOMERS-COMPLETE (Sprint 2, 2026-05-09): customer details
    // 3-tab screen (details / ledger / invoices). Path-keyed by customer id.
    GoRoute(
      path: '/app/erp/finance/customers/:customerId',
      pageBuilder: (c, s) => _apexPage(
        CustomerDetailsScreen(customerId: s.pathParameters['customerId']!),
        s,
      ),
    ),
    // G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09): vendor details
    // 3-tab screen (details / ledger / purchase-invoices).
    GoRoute(
      path: '/app/erp/finance/vendors/:vendorId',
      pageBuilder: (c, s) => _apexPage(
        VendorDetailsScreen(vendorId: s.pathParameters['vendorId']!),
        s,
      ),
    ),
    // G-FIN-PURCHASE-INVOICE-JE-AUTOPOST (Sprint 6, 2026-05-09): dedicated
    // create screen. Closes Sprint 1 audit Gap §3 row 6.
    GoRoute(
      path: '/app/erp/finance/purchase-bills/new',
      pageBuilder: (c, s) =>
          _apexPage(const PurchaseInvoiceCreateScreen(), s),
    ),
    // G-SALES-INVOICE-UX-COMPLETE (2026-05-10): sales invoice details.
    // Pre-fix the list-row click jumped straight to /je-builder/{jeId}.
    // Now it lands here, and the JE-builder is reachable only via the
    // explicit "عرض القيد" button on this screen.
    GoRoute(
      path: '/app/erp/finance/sales-invoices/:invoiceId',
      pageBuilder: (c, s) => _apexPage(
        SalesInvoiceDetailsScreen(invoiceId: s.pathParameters['invoiceId']!),
        s,
      ),
    ),
    // Sprint 15 Stage 4f: V4 /analytics/cash-flow-forecast archived (HAS_V5) -> V5 /app/erp/finance/cash-flow-forecast
    GoRoute(
      path: '/purchase/payment/:billId',
      pageBuilder: (c, s) => _apexPage(
        VendorPaymentScreen(billId: s.pathParameters['billId']!),
        s,
      ),
    ),
        // Sprint 15 Stage 4e: V4 /compliance/tax-calendar archived → V5 /app/compliance/tax/calendar
    // G-CLEANUP-1 Stage 4b: V4 /accounting/je-list pageBuilder deleted.
    // JeListScreen archived to _archive/2026-05-04/v4-routes/.
    // V5: /app/erp/finance/je-builder (JeBuilderScreen via v5_wired_screens).
        // Sprint 15 Stage 4d: V4 /accounting/coa-v2 archived → V5 /app/erp/finance/coa-editor
    // Sprint 15 Stage 4f: V4 /hr/employees archived (HAS_V5) -> V5 /app/erp/hr/employees
    // /hr now serves the HR Hub (registered earlier at top of routes)
        // Sprint 15 Stage 4d: V4 /accounting/bank-rec-v2 archived → V5 /app/erp/treasury/recon
    // /reports moved to top of routes list — see above
    GoRoute(path: '/reports/hub', redirect: (c, s) => '/reports'),
        // Sprint 15 Stage 4e: V4 /compliance/zatca-invoice/:id archived → V5 /app/compliance/zatca/invoice/:id
    // Sprint 15 Stage 4f: V4 /hr/payroll-run archived (HAS_V5) -> V5 /app/erp/hr/payroll
    GoRoute(path: '/operations/inventory-v2', redirect: (c, s) => '/app/erp/inventory/inventory'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/fixed-assets-v2', redirect: (c, s) => '/app/erp/finance/fixed-assets'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/budget-variance-v2', redirect: (c, s) => '/app/erp/finance/budget-actual'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/multi-currency-v2', redirect: (c, s) => '/app/erp/treasury/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/health-score-v2', redirect: (c, s) => '/app/erp/finance/health-score'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
        // Sprint 15 Stage 4e: V4 /compliance/lease-v2 archived → V5 /app/compliance/ifrs/dashboard
        // Sprint 15 Stage 4e: V4 /compliance/zatca-status archived → V5 /app/erp/finance/zatca-status
        // Sprint 15 Stage 4e: V4 /compliance/consolidation-v2 archived → V5 /app/erp/consolidation/dashboard
    GoRoute(path: '/admin/ai-suggestions-v2', pageBuilder: (c, s) => _apexPage(const AiSuggestionsQueueV2Screen(), s)),
    GoRoute(path: '/analytics/investment-portfolio-v2', redirect: (c, s) => '/app/advisory/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    // Sprint 15 Stage 4f: V4 /analytics/project-profitability archived (SHELL) -> V5 /app/erp/projects/dashboard
    GoRoute(path: '/settings/bank-feeds', pageBuilder: (c, s) => _apexPage(const BankFeedSetupScreen(), s)),
    GoRoute(path: '/compliance/activity-log-v2', redirect: (c, s) => '/app/erp/finance/activity-log'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
        // Sprint 15 Stage 4c: V4 /sales/recurring archived → V5 /app/erp/finance/recurring-entries
    GoRoute(path: '/knowledge/search', pageBuilder: (c, s) => _apexPage(const KnowledgeSearchV2Screen(), s)),
        // Sprint 15 Stage 4c: V4 /sales/quotes archived → V5 /app/erp/sales/dashboard
        // Sprint 15 Stage 4c: V4 /sales/memos archived → V5 /app/erp/sales/credit-notes
    // Sprint 15 Stage 4f: V4 /hr/expense-reports archived (HAS_V5) -> V5 /app/erp/expenses/expenses
    GoRoute(path: '/analytics/cost-variance-v2', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
        // Sprint 15 Stage 4e: V4 /compliance/wht-v2 archived → V5 /app/compliance/tax/wht
    GoRoute(path: '/hr/timesheet', redirect: (c, s) => '/app/erp/hr/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/petty-cash', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/stock-card', redirect: (c, s) => '/app/erp/inventory/stock-movements'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    // G-CLEANUP-1 Stage 4c-prep: V4 /operations/stock-card/:sku SHELL archived alongside its non-keyed variant.
    // Sprint 15 Stage 4f: V4 /operations/stock-card/:sku archived (SHELL-variant) -> V5 /app/erp/inventory/stock-movements
    GoRoute(path: '/audit/anomaly/:id', redirect: (c, s) => '/app/erp/finance/anomalies'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived (V4 screen has zero backend; redirected to V5 home)
    GoRoute(path: '/workflow/approvals', pageBuilder: (c, s) => _apexPage(const ApprovalsInboxScreen(), s)),
        // Sprint 15 Stage 4d: V4 /accounting/coa/edit archived → V5 /app/erp/finance/coa-editor
    GoRoute(path: '/compliance/risk-register', pageBuilder: (c, s) => _apexPage(const RiskRegisterScreen(), s)),
    GoRoute(path: '/analytics/budget-builder', redirect: (c, s) => '/app/erp/finance/budget-planning'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/compliance/kyc-aml', redirect: (c, s) => '/app/compliance/aml-ethics/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/account', redirect: (c, s) => '/settings/unified'),
    GoRoute(path: '/integrations', redirect: (c, s) => '/settings/unified'),
    // G-CLEANUP-1 Stage 4b: V4 /compliance/journal-entry/:id pageBuilder
    // deleted. The same V5.2 live builder it routed to lives at
    // /app/erp/finance/je-builder/:id (lib/core/v5/v5_routes.dart) and is
    // the canonical detail/edit route for journal entries. The
    // je_builder_live_v52 prefix import was removed alongside this route.

    // ─── COA Workflow ───
    GoRoute(path: '/upload', pageBuilder: (c, s) => _apexPage(const UploadScreen(), s)),
    GoRoute(path: '/coa/upload', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaUploadScreen(clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    GoRoute(path: '/coa/mapping', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaMappingScreen(
        uploadData: args['uploadData'] as Map<String, dynamic>? ?? {},
        clientId: args['clientId'] ?? '',
        clientName: args['clientName'] ?? '',
        pickedFile: args['pickedFile'] as PlatformFile,
      ), s);
    }),
    GoRoute(path: '/coa/quality', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaQualityScreen(
        uploadId: args['uploadId'] ?? '',
        clientId: args['clientId'] ?? '',
        clientName: args['clientName'] ?? '',
        assessData: args['assessData'] as Map<String, dynamic>? ?? {},
      ), s);
    }),
    GoRoute(path: '/coa/review', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaReviewScreen(
        uploadId: args['uploadId'] ?? '',
        clientId: args['clientId'] ?? '',
        clientName: args['clientName'] ?? '',
      ), s);
    }),

    // ─── Simulation ───
    GoRoute(path: '/coa/financial-simulation', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(FinancialSimulationScreen(uploadId: args['uploadId'] ?? '', clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    GoRoute(path: '/coa/compliance-check', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(ComplianceCheckScreen(uploadId: args['uploadId'] ?? '', clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    GoRoute(path: '/coa/roadmap', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(RoadmapScreen(uploadId: args['uploadId'] ?? '', clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    GoRoute(path: '/coa/trial-balance-check', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(TrialBalanceCheckScreen(uploadId: args['uploadId'] ?? '', clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),

    // ─── TB Binding ───
    GoRoute(path: '/tb/binding', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(TbBindingScreen(tbUploadId: args['tbUploadId'] ?? '', coaUploadId: args['coaUploadId']), s);
    }),

    // ─── Analysis & Statements ───
    GoRoute(path: '/analysis/full', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(AnalysisFullScreen(
        apiData: args?['apiData'] as Map<String, dynamic>?,
        pickedFile: args?['pickedFile'] as PlatformFile?,
      ), s);
    }),
    GoRoute(path: '/analysis/result', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(AnalysisResultScreen(
        apiData: args?['apiData'] as Map<String, dynamic>?,
        pickedFile: args?['pickedFile'],
      ), s);
    }),
    GoRoute(path: '/financial-statements', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(FinancialStatementsScreen(
        apiData: args?['apiData'] as Map<String, dynamic>?,
        pickedFile: args?['pickedFile'] as PlatformFile?,
      ), s);
    }),

    // ─── Detail Screens ───
    // G-CLEANUP-1 Stage 4c-prep: V4 /service-request/detail SHELL archived (zero backend).
    // Sprint 15 Stage 4f: V4 /service-request/detail archived (SHELL) -> V5 /app/marketplace/dashboard
    GoRoute(path: '/notification/detail', pageBuilder: (c, s) {
      return _apexPage(NotificationDetailScreen(notification: s.extra as Map<String, dynamic>? ?? {}), s);
    }),
    // G-CLEANUP-1 Stage 4c-prep: V4 /provider/profile SHELL archived (zero backend).
    // Sprint 15 Stage 4f: V4 /provider/profile archived (SHELL) -> V5 /app/marketplace/provider/dashboard
    // Unified entity/company/branch setup (single source of truth).
    // Old onboarding paths below all redirect here to eliminate the
    // duplicate setup journeys the user reported.
    // G-ERP-UNIFICATION (2026-05-09): the legacy /settings/entities
    // screen now exists ONLY to migrate localStorage data into the
    // pilot ERP. When the local store is empty (the common path for
    // any account post-G-WIZARD-TENANT-FIX), redirect straight to
    // the unified onboarding wizard. The screen itself still
    // renders — the migration banner inside it handles the legacy
    // payload before pushing the user to the wizard.
    GoRoute(
      path: '/settings/entities',
      redirect: (c, s) {
        final hasLegacy = EntityStore.listCompanies().isNotEmpty ||
            EntityStore.listEntities().isNotEmpty;
        if (!hasLegacy) {
          return '/app/erp/finance/onboarding';
        }
        return null; // allow the screen to render with the migration banner
      },
      pageBuilder: (c, s) {
        final q = s.uri.queryParameters['action'];
        return _apexPage(EntitySetupScreen(initialAction: q), s);
      },
    ),
    // G-ERP-UNIFICATION (2026-05-09): every legacy onboarding /
    // create-client path now redirects DIRECTLY to the unified
    // onboarding wizard (PilotOnboardingWizard at
    // /app/erp/finance/onboarding). Pre-fix these paths landed on
    // the legacy /settings/entities screen which created a parallel
    // localStorage path — the duplicate setup journey UAT Issue #6
    // is closing.
    GoRoute(
      path: '/onboarding/wizard',
      redirect: (c, s) => '/app/erp/finance/onboarding',
    ),
    GoRoute(
      path: '/clients/onboarding',
      redirect: (c, s) => '/app/erp/finance/onboarding',
    ),
    GoRoute(
      path: '/clients/new',
      redirect: (c, s) => '/app/erp/finance/onboarding',
    ),
    GoRoute(path: '/coa/journey', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaJourneyV2Screen(clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    // Sprint 15 Stage 4f: V4 /service-catalog archived (REAL_NEW_V5) -> V5 /app/marketplace/browse/catalog
    GoRoute(path: '/upgrade-plan', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(UpgradePlanScreen(plans: args['plans'] as List? ?? [], currentPlan: args['currentPlan'] as String?), s);
    }),
    GoRoute(path: '/knowledge/feedback-form', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(KnowledgeFeedbackScreen(resultId: args?['resultId'] as String?), s);
    }),
    // Sprint 15 Stage 4f: V4 /marketplace/new-request archived (REAL_NEW_V5) -> V5 /app/marketplace/browse/new-request
    // /clients/create — legacy path; redirect to the unified
    // PilotOnboardingWizard (G-ERP-UNIFICATION 2026-05-09).
    GoRoute(
      path: '/clients/create',
      redirect: (c, s) => '/app/erp/finance/onboarding',
    ),
    // G-CLEANUP-1 Stage 4c-prep: V4 /audit/service SHELL archived (marketplace audit-tier wrapper, no ownership).
    // Sprint 15 Stage 4f: V4 /audit/service archived (SHELL) -> V5 /app/marketplace/dashboard
  ],
);

