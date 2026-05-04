import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../screens/dashboard/enhanced_dashboard.dart';
import '../screens/settings/enhanced_settings_screen.dart';
import '../screens/coa/coa_tree_screen.dart';
import '../screens/legal/legal_acceptance_screen.dart';
import '../screens/compliance/provider_compliance_detail.dart';
import '../screens/clients/client_detail_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../screens/auth/register_screen.dart' show RegScreen;
import '../screens/upgrade_plan_screen.dart' show UpgradePlanScreen;
import '../widgets/forms/knowledge_feedback_screen.dart' show KnowledgeFeedbackScreen;
import '../widgets/forms/new_service_request_screen.dart' show NewServiceRequestScreen;
import '../widgets/main_nav.dart' show MainNav;
import '../screens/account/account_sub_screens.dart' show EditProfileScreen, ChangePasswordScreen, CloseAccountScreen, SessionsScreen;
import '../screens/admin/admin_sub_screens.dart' show ReviewerConsoleScreen, ProviderVerificationScreen, ProviderDocumentUploadScreen, ProviderComplianceScreen, PolicyManagementScreen, ActivityHistoryScreen, AuditLogScreen, KnowledgeDeveloperConsole, TaskTypesBrowserScreen;
import '../screens/admin/ai_suggestions_inbox_screen.dart';
import '../screens/admin/ai_console_screen.dart';
import '../screens/compliance/tax_timeline_screen.dart';
// import '../screens/compliance/bank_rec_ai_screen.dart'; // deduplicated → /accounting/bank-rec-v2
import '../screens/compliance/audit_workflow_screen.dart' show AiAuditWorkflowScreen;
import '../screens/compliance/islamic_finance_screen.dart';
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
import '../screens/operations/period_close_screen.dart';
import '../screens/operations/pos_session_screen.dart';
import '../screens/operations/purchase_cycle_screen.dart';
import '../screens/operations/live_sales_cycle_screen.dart';
import '../screens/home/today_dashboard_screen.dart';
import '../screens/home/apex_launchpad_screen.dart';
import '../screens/home/apex_service_hub_screen.dart';
import '../screens/home/apex_services_screen.dart';
import '../screens/operations/customer_360_screen.dart';
// G-CLEANUP-1 Stage 4b (Sprint 15, 2026-05-04): je_builder_live_v52 prefix
// import deleted alongside the V4 /compliance/journal-entry/:id route.
// V5 routes for the JE Builder (under /app/erp/finance/je-builder/...)
// are wired in lib/core/v5/v5_routes.dart, not here.
import '../screens/audit/audit_engagement_workspace_screen.dart';
import '../screens/operations/vendor_360_screen.dart';
import '../screens/operations/receipt_capture_screen.dart';
import '../screens/settings/unified_settings_screen.dart';
import '../screens/notifications/notifications_panel_screen.dart';
import '../screens/operations/pos_quick_sale_screen.dart';
import '../screens/operations/customer_payment_screen.dart';
import '../screens/analytics/cash_flow_forecast_screen.dart';
import '../screens/operations/vendor_payment_screen.dart';
import '../screens/compliance/tax_calendar_screen.dart';
// G-CLEANUP-1 Stage 4b: JeListScreen archived to _archive/2026-05-04/v4-routes/.
// Replaced by V5 list at /app/erp/finance/je-builder.
import '../screens/hr/employees_list_screen.dart';
import '../screens/reports/reports_hub_screen.dart';
import '../screens/compliance/zatca_invoice_viewer_screen.dart';
import '../screens/hr/payroll_run_screen.dart';
import '../screens/compliance/zatca_status_center_screen.dart';
import '../screens/compliance/consolidation_v2_screen.dart';
import '../screens/admin/ai_suggestions_queue_v2_screen.dart';
import '../screens/analytics/project_profitability_screen.dart';
import '../screens/settings/bank_feed_setup_screen.dart';
import '../screens/knowledge/knowledge_search_v2_screen.dart';
import '../screens/hr/expense_reports_screen.dart';
import '../screens/compliance/wht_v2_screen.dart';
import '../screens/workflow/approvals_inbox_screen.dart';
import '../screens/accounting/coa_editor_screen.dart';
import '../screens/compliance/risk_register_screen.dart';
import '../screens/extracted/subscription_screens.dart';
import '../screens/extracted/notification_screens_v2.dart';
import '../screens/extracted/legal_screens_v2.dart';
import '../screens/extracted/client_screens.dart';
import '../screens/coa_v2/coa_journey_screen.dart';
import '../screens/auth/forgot_password_flow.dart';
import '../screens/auth/slide_auth_screen.dart';
// client_onboarding_wizard removed — redirected to unified /settings/entities
import '../screens/marketplace/service_catalog_screen.dart' as catalog;
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
import '../screens/compliance/audit_trail_screen.dart';
import '../screens/compliance/zatca_invoice_builder_screen.dart';
import '../screens/compliance/compliance_hub_screen.dart';
import '../screens/compliance/zakat_calculator_screen.dart';
import '../screens/compliance/vat_return_screen.dart';
import '../screens/compliance/financial_ratios_screen.dart';
import '../screens/compliance/depreciation_screen.dart';
import '../screens/compliance/cashflow_screen.dart';
import '../screens/compliance/amortization_screen.dart';
import '../screens/compliance/payroll_screen.dart';
import '../screens/compliance/breakeven_screen.dart';
import '../screens/compliance/investment_screen.dart';
// Legacy screens deduplicated to canonical paths (Phase 26):
// import '../screens/compliance/budget_variance_screen.dart'; // → /analytics/budget-variance-v2
// import '../screens/compliance/bank_rec_screen.dart';        // → /accounting/bank-rec-v2
// import '../screens/compliance/inventory_screen.dart';       // → /operations/inventory-v2
// import '../screens/compliance/aging_screen.dart';           // → /sales/aging
import '../screens/compliance/working_capital_screen.dart';
// import '../screens/compliance/health_score_screen.dart'; // deduplicated → /analytics/health-score-v2
import '../screens/compliance/ocr_screen.dart';
import '../screens/compliance/dscr_screen.dart';
import '../screens/compliance/valuation_screen.dart';
// G-CLEANUP-1 Stage 4b: JournalEntryBuilderScreen archived to
// _archive/2026-05-04/v4-routes/. Replaced by V5.2 builder at
// /app/erp/finance/je-builder/new (lib/core/v5/v5_routes.dart).
import '../screens/compliance/fx_converter_screen.dart';
// import '../screens/compliance/cost_variance_screen.dart'; // deduplicated → /analytics/cost-variance-v2
import '../screens/compliance/fin_statements_screen.dart';
import '../screens/compliance/cashflow_statement_screen.dart';
// import '../screens/compliance/wht_screen.dart';         // deduplicated → /compliance/wht-v2
// import '../screens/compliance/consolidation_screen.dart'; // deduplicated → /compliance/consolidation-v2
import '../screens/compliance/deferred_tax_screen.dart';
// import '../screens/compliance/lease_screen.dart'; // deduplicated → /compliance/lease-v2
import '../screens/compliance/ifrs_tools_screen.dart';
// import '../screens/compliance/fixed_assets_screen.dart'; // deduplicated → /operations/fixed-assets-v2
import '../screens/compliance/transfer_pricing_screen.dart';
import '../screens/compliance/extras_tools_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'v5/v5_routes.dart';
import 'apex_bottom_nav.dart';
import 'apex_magnetic_shell.dart';
import 'apex_tabs_shell.dart';
import '../screens/lab/innovation_lab_screen.dart';
import '../screens/settings/entity_setup_screen.dart';
import '../screens/account/mfa_screen.dart';

final authRefresh = ValueNotifier<int>(0);

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
    GoRoute(path: '/sales', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'sales'), s)),
    GoRoute(path: '/purchase', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'purchase'), s)),
    GoRoute(path: '/accounting', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'accounting'), s)),
    GoRoute(path: '/operations', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'operations'), s)),
    GoRoute(path: '/compliance-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'compliance-hub'), s)),
    GoRoute(path: '/audit-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'audit-hub'), s)),
    GoRoute(path: '/audit', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'audit-hub'), s)),
    GoRoute(path: '/analytics', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'analytics'), s)),
    GoRoute(path: '/hr', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'hr-hub'), s)),
    GoRoute(path: '/hr-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'hr-hub'), s)),
    GoRoute(path: '/workflow', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'workflow-hub'), s)),
    GoRoute(path: '/workflow-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'workflow-hub'), s)),
    GoRoute(path: '/settings-hub', pageBuilder: (c, s) => _apexPage(const ApexServiceHubScreen(serviceId: 'settings-hub'), s)),

    // Setup alias — keep simple redirect.
    GoRoute(path: '/setup', redirect: (c, s) => '/settings/entities'),
    GoRoute(path: '/reports', pageBuilder: (c, s) => _apexPage(const ReportsHubScreen(), s)),
    GoRoute(path: '/today', pageBuilder: (c, s) => _apexPage(const TodayDashboardScreen(), s)),
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
    GoRoute(path: '/launchpad/full', pageBuilder: (c, s) => _apexPage(const ApexLaunchpadScreen(), s)),

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

    // ── Compliance (ZATCA / IFRS / SOCPA) ──
    GoRoute(
      path: '/compliance',
      pageBuilder: (c, s) => _apexPage(const ComplianceHubScreen(), s),
    ),
    // Legacy → canonical (Phase 26 dedup)
    // G-CLEANUP-1 Stage 4b: V4 /compliance/journal-entries redirect deleted.
    // V5: /app/erp/finance/je-builder (LIST).
    GoRoute(
      path: '/compliance/audit-trail',
      pageBuilder: (c, s) => _apexPage(const AuditTrailScreen(), s),
    ),
    GoRoute(
      path: '/compliance/zatca-invoice',
      pageBuilder: (c, s) => _apexPage(const ZatcaInvoiceBuilderScreen(), s),
    ),
    GoRoute(
      path: '/compliance/zakat',
      pageBuilder: (c, s) => _apexPage(const ZakatCalculatorScreen(), s),
    ),
    GoRoute(
      path: '/compliance/vat-return',
      pageBuilder: (c, s) => _apexPage(const VatReturnScreen(), s),
    ),
    GoRoute(
      path: '/compliance/ratios',
      pageBuilder: (c, s) => _apexPage(const FinancialRatiosScreen(), s),
    ),
    GoRoute(
      path: '/compliance/depreciation',
      pageBuilder: (c, s) => _apexPage(const DepreciationScreen(), s),
    ),
    GoRoute(
      path: '/compliance/cashflow',
      pageBuilder: (c, s) => _apexPage(const CashFlowScreen(), s),
    ),
    GoRoute(
      path: '/compliance/amortization',
      pageBuilder: (c, s) => _apexPage(const AmortizationScreen(), s),
    ),
    GoRoute(
      path: '/compliance/payroll',
      pageBuilder: (c, s) => _apexPage(const PayrollScreen(), s),
    ),
    GoRoute(
      path: '/compliance/breakeven',
      pageBuilder: (c, s) => _apexPage(const BreakevenScreen(), s),
    ),
    GoRoute(
      path: '/compliance/investment',
      pageBuilder: (c, s) => _apexPage(const InvestmentScreen(), s),
    ),
    GoRoute(path: '/compliance/budget-variance', redirect: (c, s) => '/analytics/budget-variance-v2'),
    GoRoute(path: '/compliance/bank-rec', redirect: (c, s) => '/accounting/bank-rec-v2'),
    GoRoute(path: '/compliance/inventory', redirect: (c, s) => '/operations/inventory-v2'),
        // Sprint 15 Stage 4c: V4 /compliance/aging archived → V5 /app/erp/sales/ar-aging
    GoRoute(
      path: '/compliance/working-capital',
      pageBuilder: (c, s) => _apexPage(const WorkingCapitalScreen(), s),
    ),
    GoRoute(path: '/compliance/health-score', redirect: (c, s) => '/analytics/health-score-v2'),
    GoRoute(path: '/compliance/executive', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived (V4 screen has zero backend; redirected to V5 home)
    GoRoute(
      path: '/compliance/ocr',
      pageBuilder: (c, s) => _apexPage(const OcrScreen(), s),
    ),
    GoRoute(
      path: '/compliance/dscr',
      pageBuilder: (c, s) => _apexPage(const DscrScreen(), s),
    ),
    GoRoute(
      path: '/compliance/valuation',
      pageBuilder: (c, s) => _apexPage(const ValuationScreen(), s),
    ),
    // G-CLEANUP-1 Stage 4b: V4 /compliance/journal-entry-builder pageBuilder
    // deleted. JournalEntryBuilderScreen archived to
    // _archive/2026-05-04/v4-routes/. V5: /app/erp/finance/je-builder/new
    // (JeBuilderLiveV52Screen, wired in lib/core/v5/v5_routes.dart).
    GoRoute(
      path: '/compliance/fx-converter',
      pageBuilder: (c, s) => _apexPage(const FxConverterScreen(), s),
    ),
    GoRoute(path: '/compliance/cost-variance', redirect: (c, s) => '/analytics/cost-variance-v2'),
    GoRoute(
      path: '/compliance/financial-statements',
      pageBuilder: (c, s) => _apexPage(const FinStatementsScreen(), s),
    ),
    GoRoute(
      path: '/compliance/cashflow-statement',
      pageBuilder: (c, s) => _apexPage(const CashflowStatementScreen(), s),
    ),
    GoRoute(path: '/compliance/wht', redirect: (c, s) => '/compliance/wht-v2'),
    GoRoute(path: '/compliance/consolidation', redirect: (c, s) => '/compliance/consolidation-v2'),
    GoRoute(
      path: '/compliance/deferred-tax',
      pageBuilder: (c, s) => _apexPage(const DeferredTaxScreen(), s),
    ),
    GoRoute(path: '/compliance/lease', redirect: (c, s) => '/compliance/lease-v2'),
    GoRoute(
      path: '/compliance/ifrs-tools',
      pageBuilder: (c, s) => _apexPage(const IfrsToolsScreen(), s),
    ),
    GoRoute(path: '/compliance/fixed-assets', redirect: (c, s) => '/operations/fixed-assets-v2'),
    GoRoute(
      path: '/compliance/transfer-pricing',
      pageBuilder: (c, s) => _apexPage(const TransferPricingScreen(), s),
    ),
    GoRoute(
      path: '/compliance/extras-tools',
      pageBuilder: (c, s) => _apexPage(const ExtrasToolsScreen(), s),
    ),

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
    GoRoute(path: '/dashboard', pageBuilder: (c, s) => _apexPage(const EnhancedDashboard(), s)),
    GoRoute(path: '/audit-workflow', redirect: (c, s) => '/app/audit/engagement/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/knowledge-brain', pageBuilder: (c, s) => _apexPage(const KnowledgeBrainScreen(), s)),
    GoRoute(path: '/financial-ops', pageBuilder: (c, s) => _apexPage(const FinancialOpsScreen(), s)),
    GoRoute(path: '/copilot', pageBuilder: (c, s) => _apexPage(const CopilotScreen(), s)),
    GoRoute(path: '/admin/audit', pageBuilder: (c, s) => _apexPage(const AuditLogScreen(), s)),
    GoRoute(path: '/admin/ai-suggestions', pageBuilder: (c, s) => _apexPage(const AiSuggestionsInboxScreen(), s)),
    GoRoute(path: '/admin/ai-console', pageBuilder: (c, s) => _apexPage(const AiConsoleScreen(), s)),
    GoRoute(path: '/compliance/tax-timeline', pageBuilder: (c, s) => _apexPage(const TaxTimelineScreen(), s)),
    GoRoute(path: '/compliance/bank-rec-ai', redirect: (c, s) => '/accounting/bank-rec-v2'),
    GoRoute(path: '/compliance/audit-workflow-ai', pageBuilder: (c, s) => _apexPage(const AiAuditWorkflowScreen(), s)),
    GoRoute(path: '/compliance/islamic-finance', pageBuilder: (c, s) => _apexPage(const IslamicFinanceScreen(), s)),
    // ── My new "AI-assisted" depreciation was a duplicate — redirect to the
    //    pre-existing /compliance/depreciation + /compliance/fixed-assets screens.
    GoRoute(path: '/compliance/depreciation-ai', redirect: (c, s) => '/compliance/depreciation'),
    GoRoute(path: '/compliance/multi-currency', redirect: (c, s) => '/analytics/multi-currency-v2'),
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
    GoRoute(path: '/operations/period-close', pageBuilder: (c, s) => _apexPage(const PeriodCloseScreen(), s)),
    GoRoute(path: '/operations/pos-sessions', pageBuilder: (c, s) => _apexPage(const PosSessionScreen(), s)),
    GoRoute(path: '/operations/purchase-cycle', pageBuilder: (c, s) => _apexPage(const PurchaseCycleScreen(), s)),
    GoRoute(path: '/operations/consolidation-ui', redirect: (c, s) => '/app/erp/consolidation/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/live-sales-cycle', pageBuilder: (c, s) => _apexPage(const LiveSalesCycleScreen(), s)),
    // /today and /sales etc. moved to top of routes list — see above
        // Sprint 15 Stage 4d: V4 /accounting/coa archived → V5 /app/erp/finance/coa-editor
    // G-CLEANUP-1 Stage 4b: V4 /accounting/journal-entries redirect deleted.
    // V5: /app/erp/finance/je-builder.
        // Sprint 15 Stage 4d: V4 /accounting/trial-balance archived → V5 /app/erp/finance/statements
        // Sprint 15 Stage 4d: V4 /accounting/period-close archived → V5 /app/erp/finance/period-close
    // /financial-statements canonical (with optional apiData/pickedFile) defined below at line ~805 — duplicate redirect removed (Stage 1 bugfix 2026-04-29).
    GoRoute(path: '/audit/engagements', pageBuilder: (c, s) => _apexPage(const AuditEngagementWorkspaceScreen(), s)),
    GoRoute(path: '/audit/engagement-workspace', pageBuilder: (c, s) => _apexPage(const AuditEngagementWorkspaceScreen(), s)),
    GoRoute(path: '/audit/benford', pageBuilder: (c, s) => _apexPage(const AuditEngagementWorkspaceScreen(), s)),
    GoRoute(path: '/audit/sampling', pageBuilder: (c, s) => _apexPage(const AuditEngagementWorkspaceScreen(), s)),
    GoRoute(path: '/audit/workpapers', pageBuilder: (c, s) => _apexPage(const AuditEngagementWorkspaceScreen(), s)),
    GoRoute(path: '/setup', redirect: (c, s) => '/settings/entities'),
    GoRoute(path: '/setup/entity', redirect: (c, s) => '/settings/entities'),
    GoRoute(
      path: '/operations/customer-360/:id',
      pageBuilder: (c, s) => _apexPage(
        Customer360Screen(customerId: s.pathParameters['id']!),
        s,
      ),
    ),
    GoRoute(
      path: '/operations/vendor-360/:id',
      pageBuilder: (c, s) => _apexPage(
        Vendor360Screen(vendorId: s.pathParameters['id']!),
        s,
      ),
    ),
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
    GoRoute(path: '/analytics/cash-flow-forecast', pageBuilder: (c, s) => _apexPage(const CashFlowForecastScreen(), s)),
    GoRoute(
      path: '/purchase/payment/:billId',
      pageBuilder: (c, s) => _apexPage(
        VendorPaymentScreen(billId: s.pathParameters['billId']!),
        s,
      ),
    ),
    GoRoute(path: '/compliance/tax-calendar', pageBuilder: (c, s) => _apexPage(const TaxCalendarScreen(), s)),
    // G-CLEANUP-1 Stage 4b: V4 /accounting/je-list pageBuilder deleted.
    // JeListScreen archived to _archive/2026-05-04/v4-routes/.
    // V5: /app/erp/finance/je-builder (JeBuilderScreen via v5_wired_screens).
        // Sprint 15 Stage 4d: V4 /accounting/coa-v2 archived → V5 /app/erp/finance/coa-editor
    GoRoute(path: '/hr/employees', pageBuilder: (c, s) => _apexPage(const EmployeesListScreen(), s)),
    // /hr now serves the HR Hub (registered earlier at top of routes)
        // Sprint 15 Stage 4d: V4 /accounting/bank-rec-v2 archived → V5 /app/erp/treasury/recon
    // /reports moved to top of routes list — see above
    GoRoute(path: '/reports/hub', redirect: (c, s) => '/reports'),
    GoRoute(
      path: '/compliance/zatca-invoice/:id',
      pageBuilder: (c, s) => _apexPage(
        ZatcaInvoiceViewerScreen(invoiceId: s.pathParameters['id']!),
        s,
      ),
    ),
    GoRoute(path: '/hr/payroll-run', pageBuilder: (c, s) => _apexPage(const PayrollRunScreen(), s)),
    GoRoute(path: '/operations/inventory-v2', redirect: (c, s) => '/app/erp/inventory/inventory'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/fixed-assets-v2', redirect: (c, s) => '/app/erp/finance/fixed-assets'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/budget-variance-v2', redirect: (c, s) => '/app/erp/finance/budget-actual'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/multi-currency-v2', redirect: (c, s) => '/app/erp/treasury/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/health-score-v2', redirect: (c, s) => '/app/erp/finance/health-score'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/compliance/lease-v2', redirect: (c, s) => '/app/compliance/ifrs/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/compliance/zatca-status', pageBuilder: (c, s) => _apexPage(const ZatcaStatusCenterScreen(), s)),
    GoRoute(path: '/compliance/consolidation-v2', pageBuilder: (c, s) => _apexPage(const ConsolidationV2Screen(), s)),
    GoRoute(path: '/admin/ai-suggestions-v2', pageBuilder: (c, s) => _apexPage(const AiSuggestionsQueueV2Screen(), s)),
    GoRoute(path: '/analytics/investment-portfolio-v2', redirect: (c, s) => '/app/advisory/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/analytics/project-profitability', pageBuilder: (c, s) => _apexPage(const ProjectProfitabilityScreen(), s)),
    GoRoute(path: '/settings/bank-feeds', pageBuilder: (c, s) => _apexPage(const BankFeedSetupScreen(), s)),
    GoRoute(path: '/compliance/activity-log-v2', redirect: (c, s) => '/app/erp/finance/activity-log'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
        // Sprint 15 Stage 4c: V4 /sales/recurring archived → V5 /app/erp/finance/recurring-entries
    GoRoute(path: '/knowledge/search', pageBuilder: (c, s) => _apexPage(const KnowledgeSearchV2Screen(), s)),
        // Sprint 15 Stage 4c: V4 /sales/quotes archived → V5 /app/erp/sales/dashboard
        // Sprint 15 Stage 4c: V4 /sales/memos archived → V5 /app/erp/sales/credit-notes
    GoRoute(path: '/hr/expense-reports', pageBuilder: (c, s) => _apexPage(const ExpenseReportsScreen(), s)),
    GoRoute(path: '/analytics/cost-variance-v2', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/compliance/wht-v2', pageBuilder: (c, s) => _apexPage(const WhtV2Screen(), s)),
    GoRoute(path: '/hr/timesheet', redirect: (c, s) => '/app/erp/hr/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/petty-cash', redirect: (c, s) => '/app/erp/finance/dashboard'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    GoRoute(path: '/operations/stock-card', redirect: (c, s) => '/app/erp/inventory/stock-movements'),  // G-CLEANUP-1 Stage 4c-prep: SHELL archived; V4 screen had zero backend
    // G-CLEANUP-1 Stage 4c-prep: V4 /operations/stock-card/:sku SHELL archived alongside its non-keyed variant.
    GoRoute(path: '/operations/stock-card/:sku', redirect: (c, s) => '/app/erp/inventory/stock-movements'),
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
    GoRoute(path: '/service-request/detail', redirect: (c, s) => '/app/marketplace/dashboard'),
    GoRoute(path: '/notification/detail', pageBuilder: (c, s) {
      return _apexPage(NotificationDetailScreen(notification: s.extra as Map<String, dynamic>? ?? {}), s);
    }),
    // G-CLEANUP-1 Stage 4c-prep: V4 /provider/profile SHELL archived (zero backend).
    GoRoute(path: '/provider/profile', redirect: (c, s) => '/app/marketplace/provider/dashboard'),
    // Unified entity/company/branch setup (single source of truth).
    // Old onboarding paths below all redirect here to eliminate the
    // duplicate setup journeys the user reported.
    GoRoute(
      path: '/settings/entities',
      pageBuilder: (c, s) {
        final q = s.uri.queryParameters['action'];
        return _apexPage(EntitySetupScreen(initialAction: q), s);
      },
    ),
    GoRoute(
      path: '/onboarding/wizard',
      redirect: (c, s) => '/settings/entities?action=new-company',
    ),
    GoRoute(
      path: '/clients/onboarding',
      redirect: (c, s) => '/settings/entities?action=new-company',
    ),
    GoRoute(
      path: '/clients/new',
      redirect: (c, s) => '/settings/entities?action=new-company',
    ),
    GoRoute(path: '/coa/journey', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(CoaJourneyV2Screen(clientId: args['clientId'] ?? '', clientName: args['clientName'] ?? ''), s);
    }),
    GoRoute(path: '/service-catalog', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(catalog.ServiceCatalogScreen(clientId: args?['clientId'] as String?, token: args?['token'] as String?), s);
    }),
    GoRoute(path: '/upgrade-plan', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(UpgradePlanScreen(plans: args['plans'] as List? ?? [], currentPlan: args['currentPlan'] as String?), s);
    }),
    GoRoute(path: '/knowledge/feedback-form', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(KnowledgeFeedbackScreen(resultId: args?['resultId'] as String?), s);
    }),
    GoRoute(path: '/marketplace/new-request', pageBuilder: (c, s) => _apexPage(const NewServiceRequestScreen(), s)),
    // /clients/create — legacy path; redirect to the unified setup.
    GoRoute(
      path: '/clients/create',
      redirect: (c, s) => '/settings/entities?action=new-company',
    ),
    // G-CLEANUP-1 Stage 4c-prep: V4 /audit/service SHELL archived (marketplace audit-tier wrapper, no ownership).
    GoRoute(path: '/audit/service', redirect: (c, s) => '/app/marketplace/dashboard'),
  ],
);

