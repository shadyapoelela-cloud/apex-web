import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/copilot/copilot_screen.dart';
import '../screens/showcase/apex_showcase_screen.dart';
import '../screens/whats_new/apex_whats_new_hub.dart';
import '../screens/whats_new/uae_corp_tax_screen.dart';
import '../screens/whats_new/startup_metrics_screen.dart';
import '../screens/whats_new/industry_packs_screen.dart';
import '../screens/whats_new/feature_demos_screen.dart';
import '../screens/whats_new/onboarding_wizard_screen.dart';
import '../screens/whats_new/sprint35_foundation_screen.dart';
import '../screens/whats_new/sprint37_experience_screen.dart';
import '../screens/whats_new/sprint38_composable_screen.dart';
import '../screens/whats_new/sprint39_erp_screen.dart';
import '../screens/whats_new/sprint40_payroll_reports_screen.dart';
import '../screens/whats_new/sprint41_procurement_screen.dart';
import '../screens/whats_new/sprint42_longterm_screen.dart';
import '../screens/whats_new/sprint43_platform_screen.dart';
import '../screens/whats_new/sprint44_operations_screen.dart';
import '../screens/whats_new/apex_map_screen.dart';
import '../screens/whats_new/theme_generator_screen.dart';
import '../screens/whats_new/white_label_settings_screen.dart';
import '../screens/whats_new/syncfusion_grid_demo_screen.dart';
import '../screens/financial/financial_ops_screen.dart';
import '../screens/knowledge/knowledge_brain_screen.dart';
import '../screens/audit/audit_workflow_screen.dart';
import '../screens/dashboard/enhanced_dashboard.dart';
import '../screens/providers/provider_kanban_screen.dart';
import '../screens/settings/enhanced_settings_screen.dart';
import '../screens/coa/coa_tree_screen.dart';
import '../screens/legal/legal_acceptance_screen.dart';
import '../screens/compliance/provider_compliance_detail.dart';
import '../screens/clients/client_detail_screen.dart';
import '../screens/marketplace/service_request_detail.dart';
import '../screens/providers/provider_profile_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../main.dart' show MainNav, RegScreen, UpgradePlanScreen, KnowledgeFeedbackScreen, NewServiceRequestScreen;
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
import '../screens/onboarding/onboarding_wizard_screen.dart' as onboarding_ai;
import '../screens/admin/audit_chain_viewer_screen.dart';
// Operations duplicates kept as files for reference but unmounted —
// their routes now redirect to the pre-existing /compliance/* + /financial-ops screens.
// import '../screens/operations/financial_ops_hub_screen.dart';
// import '../screens/operations/je_creator_screen.dart';
// import '../screens/operations/financial_statements_formatted_screen.dart';
// import '../screens/operations/financial_analysis_screen.dart';
import '../screens/operations/universal_journal_screen.dart';
import '../screens/operations/period_close_screen.dart';
import '../screens/operations/pos_session_screen.dart';
import '../screens/operations/purchase_cycle_screen.dart';
import '../screens/operations/consolidation_ui_screen.dart';
import '../screens/operations/live_sales_cycle_screen.dart';
import '../screens/home/today_dashboard_screen.dart';
import '../screens/operations/customer_360_screen.dart';
import '../screens/compliance/journal_entry_detail_screen.dart' as je_detail_v2;
import '../screens/audit/audit_engagement_workspace_screen.dart';
import '../screens/operations/vendor_360_screen.dart';
import '../screens/operations/receipt_capture_screen.dart';
import '../screens/settings/unified_settings_screen.dart';
import '../screens/operations/customers_list_screen.dart';
import '../screens/operations/vendors_list_screen.dart';
import '../screens/operations/invoices_list_screen.dart';
import '../screens/operations/ar_aging_screen.dart';
import '../screens/operations/bills_list_screen.dart';
import '../screens/operations/ap_aging_screen.dart';
import '../screens/notifications/notifications_panel_screen.dart';
import '../screens/operations/pos_quick_sale_screen.dart';
import '../screens/operations/customer_payment_screen.dart';
import '../screens/analytics/cash_flow_forecast_screen.dart';
import '../screens/operations/vendor_payment_screen.dart';
import '../screens/compliance/tax_calendar_screen.dart';
import '../screens/accounting/je_list_screen.dart';
import '../screens/accounting/coa_tree_v2_screen.dart';
import '../screens/hr/employees_list_screen.dart';
import '../screens/accounting/bank_rec_v2_screen.dart';
import '../screens/reports/reports_hub_screen.dart';
import '../screens/compliance/zatca_invoice_viewer_screen.dart';
import '../screens/hr/payroll_run_screen.dart';
import '../screens/operations/inventory_v2_screen.dart';
import '../screens/operations/fixed_assets_v2_screen.dart';
import '../screens/analytics/budget_variance_v2_screen.dart';
import '../screens/analytics/multi_currency_v2_screen.dart';
import '../screens/analytics/health_score_v2_screen.dart';
import '../screens/compliance/lease_schedule_v2_screen.dart';
import '../screens/compliance/zatca_status_center_screen.dart';
import '../screens/compliance/consolidation_v2_screen.dart';
import '../screens/admin/ai_suggestions_queue_v2_screen.dart';
import '../screens/analytics/investment_portfolio_v2_screen.dart';
import '../screens/analytics/project_profitability_screen.dart';
import '../screens/settings/bank_feed_setup_screen.dart';
import '../screens/compliance/activity_log_v2_screen.dart';
import '../screens/sales/recurring_invoices_screen.dart';
import '../screens/knowledge/knowledge_search_v2_screen.dart';
import '../screens/sales/quotes_list_screen.dart';
import '../screens/sales/credit_memos_screen.dart';
import '../screens/hr/expense_reports_screen.dart';
import '../screens/analytics/cost_variance_v2_screen.dart';
import '../screens/compliance/wht_v2_screen.dart';
import '../screens/hr/timesheet_screen.dart';
import '../screens/operations/petty_cash_screen.dart';
import '../screens/operations/stock_card_screen.dart';
import '../screens/audit/anomaly_detail_screen.dart';
import '../screens/workflow/approvals_inbox_screen.dart';
import '../screens/accounting/coa_editor_screen.dart';
import '../screens/compliance/risk_register_screen.dart';
import '../screens/analytics/budget_builder_screen.dart';
import '../screens/compliance/kyc_aml_screen.dart';
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
import '../screens/tasks/audit_service_screen.dart' as audit;
import '../core/session.dart' show S;
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
import '../screens/compliance/executive_dashboard_screen.dart';
import '../screens/compliance/ocr_screen.dart';
import '../screens/compliance/dscr_screen.dart';
import '../screens/compliance/valuation_screen.dart';
import '../screens/compliance/journal_entry_builder_screen.dart';
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
import 'v4/v4_routes.dart';
import 'v5/v5_routes.dart';
import '../widgets/hybrid_sidebar.dart';
import 'apex_bottom_nav.dart';
import '../screens/settings/entity_setup_screen.dart';
import '../screens/account/mfa_screen.dart';

final authRefresh = ValueNotifier<int>(0);

/// Routes that should be auto-wrapped with the unified [HybridSidebar]
/// so every compliance screen shares the same 10-round-researched nav
/// experience (journal-entries, ZATCA, ratios, etc.).
bool _shouldWrapCompliance(GoRouterState state) {
  final path = state.uri.path;
  return path == '/compliance' || path.startsWith('/compliance/');
}

/// Smooth page transition — fade + subtle slide.
/// Auto-wraps compliance routes with [HybridSidebar] for a consistent
/// left navigation + theme-aware colors + active-stripe indicator.
/// Routes that get the mobile bottom navigation wrapped around them.
/// (The widget self-hides on tablet/desktop breakpoints.)
bool _shouldShowBottomNav(GoRouterState state) {
  final p = state.uri.path;
  if (p == '/login' || p == '/register' || p.startsWith('/forgot-password')) return false;
  if (p == '/onboarding' || p.startsWith('/onboarding/')) return false;
  return true;
}

CustomTransitionPage<void> _apexPage(Widget child, GoRouterState state) {
  Widget wrapped = _shouldWrapCompliance(state)
      ? HybridSidebar(child: child)
      : child;
  if (_shouldShowBottomNav(state)) {
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
  initialLocation: '/app',
  // redirect: disabled for now - auth handled in login screen,
    routes: [
    // ── New IA aliases (Blueprint v1.0) — registered BEFORE v5/v4 ──
    // so /sales /purchase /accounting /audit win over any catch-all
    // patterns the older shells might have. These are simple redirects
    // and forward into the canonical screens registered later in this
    // routes list.
    GoRoute(path: '/sales', redirect: (c, s) => '/operations/live-sales-cycle'),
    GoRoute(path: '/purchase', redirect: (c, s) => '/operations/purchase-cycle'),
    GoRoute(path: '/accounting', redirect: (c, s) => '/compliance/journal-entries'),
    GoRoute(path: '/audit', redirect: (c, s) => '/audit/engagements'),
    GoRoute(path: '/setup', redirect: (c, s) => '/settings/entities'),
    GoRoute(path: '/reports', pageBuilder: (c, s) => _apexPage(const ReportsHubScreen(), s)),
    GoRoute(path: '/today', pageBuilder: (c, s) => _apexPage(const TodayDashboardScreen(), s)),

    // ── V5.1 shell (16-app ERP + Cmd+K palette + Entity Scope) ──
    // Registered FIRST so /app/* routes win over legacy paths.
    ...v5Routes(),
    // ── V4 shell (Wave 1.5) ──
    // Coexists with V5; nothing is removed.
    ...v4Routes(),

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
    GoRoute(
      path: '/sprint40-payroll',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint40PayrollReportsScreen(), s),
    ),
    GoRoute(
      path: '/sprint41-procurement',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint41ProcurementScreen(), s),
    ),
    GoRoute(
      path: '/sprint42-longterm',
      pageBuilder: (c, s) =>
          _apexPage(const Sprint42LongTermScreen(), s),
    ),
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
      pageBuilder: (c, s) => _apexPage(const ApexMapScreen(), s),
    ),
    GoRoute(
      path: '/theme-generator',
      pageBuilder: (c, s) => _apexPage(const ThemeGeneratorScreen(), s),
    ),
    GoRoute(
      path: '/white-label',
      pageBuilder: (c, s) => _apexPage(const WhiteLabelSettingsScreen(), s),
    ),
    GoRoute(
      path: '/syncfusion-grid',
      pageBuilder: (c, s) => _apexPage(const SyncfusionGridDemoScreen(), s),
    ),
    GoRoute(
      path: '/startup-metrics',
      pageBuilder: (c, s) => _apexPage(const StartupMetricsScreen(), s),
    ),
    GoRoute(
      path: '/industry-packs',
      pageBuilder: (c, s) => _apexPage(const IndustryPacksScreen(), s),
    ),
    GoRoute(
      path: '/payments-playground',
      pageBuilder: (c, s) => _apexPage(const PaymentsPlaygroundScreen(), s),
    ),
    GoRoute(
      path: '/ap-pipeline-demo',
      pageBuilder: (c, s) => _apexPage(const ApPipelineScreen(), s),
    ),
    GoRoute(
      path: '/bank-ocr-demo',
      pageBuilder: (c, s) => _apexPage(const BankOcrDemoScreen(), s),
    ),
    GoRoute(
      path: '/gosi-demo',
      pageBuilder: (c, s) => _apexPage(const GosiCalcScreen(), s),
    ),
    GoRoute(
      path: '/eosb-demo',
      pageBuilder: (c, s) => _apexPage(const EosbCalcScreen(), s),
    ),
    GoRoute(
      path: '/whatsapp-demo',
      pageBuilder: (c, s) => _apexPage(const WhatsAppDemoScreen(), s),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (c, s) => _apexPage(const OnboardingWizardScreen(), s),
    ),

    // ── Compliance (ZATCA / IFRS / SOCPA) ──
    GoRoute(
      path: '/compliance',
      pageBuilder: (c, s) => _apexPage(const ComplianceHubScreen(), s),
    ),
    // Legacy → canonical (Phase 26 dedup)
    GoRoute(path: '/compliance/journal-entries', redirect: (c, s) => '/accounting/je-list'),
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
    GoRoute(path: '/compliance/aging', redirect: (c, s) => '/sales/aging'),
    GoRoute(
      path: '/compliance/working-capital',
      pageBuilder: (c, s) => _apexPage(const WorkingCapitalScreen(), s),
    ),
    GoRoute(path: '/compliance/health-score', redirect: (c, s) => '/analytics/health-score-v2'),
    GoRoute(
      path: '/compliance/executive',
      pageBuilder: (c, s) => _apexPage(const ExecutiveDashboardScreen(), s),
    ),
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
    GoRoute(
      path: '/compliance/journal-entry-builder',
      pageBuilder: (c, s) => _apexPage(const JournalEntryBuilderScreen(), s),
    ),
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
    GoRoute(path: '/provider-kanban', pageBuilder: (c, s) => _apexPage(const ProviderKanbanScreen(), s)),
    GoRoute(path: '/client-detail', pageBuilder: (c, s) { final args = s.extra as Map<String,dynamic>? ?? {}; return _apexPage(ClientDetailScreen(clientId: args['id'] ?? '', clientName: args['name'] ?? ''), s); }),
    GoRoute(path: '/legal-acceptance', pageBuilder: (c, s) => _apexPage(const LegalAcceptanceLogger(), s)),
    GoRoute(path: '/compliance-detail', pageBuilder: (c, s) => _apexPage(const ProviderComplianceDetailScreen(), s)),
    GoRoute(path: '/coa-tree', pageBuilder: (c, s) => _apexPage(const CoaTreeScreen(), s)),
    GoRoute(path: '/settings', pageBuilder: (c, s) => _apexPage(const EnhancedSettingsScreen(), s)),
    GoRoute(path: '/dashboard', pageBuilder: (c, s) => _apexPage(const EnhancedDashboard(), s)),
    GoRoute(path: '/audit-workflow', pageBuilder: (c, s) => _apexPage(const AuditWorkflowScreen(), s)),
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
    GoRoute(path: '/onboarding/wizard', pageBuilder: (c, s) => _apexPage(const onboarding_ai.OnboardingWizardScreen(), s)),
    GoRoute(path: '/admin/audit-chain', pageBuilder: (c, s) => _apexPage(const AuditChainViewerScreen(), s)),
    // ── Operations routes redirect to pre-existing screens (avoid duplication) ──
    GoRoute(path: '/operations/hub', redirect: (c, s) => '/financial-ops'),
    GoRoute(path: '/operations/je-creator', redirect: (c, s) => '/compliance/journal-entry-builder'),
    GoRoute(path: '/operations/financial-statements', redirect: (c, s) => '/compliance/financial-statements'),
    GoRoute(path: '/operations/financial-analysis', redirect: (c, s) => '/compliance/ratios'),
    GoRoute(path: '/operations/universal-journal', pageBuilder: (c, s) => _apexPage(const UniversalJournalScreen(), s)),
    GoRoute(path: '/operations/period-close', pageBuilder: (c, s) => _apexPage(const PeriodCloseScreen(), s)),
    GoRoute(path: '/operations/pos-sessions', pageBuilder: (c, s) => _apexPage(const PosSessionScreen(), s)),
    GoRoute(path: '/operations/purchase-cycle', pageBuilder: (c, s) => _apexPage(const PurchaseCycleScreen(), s)),
    GoRoute(path: '/operations/consolidation-ui', pageBuilder: (c, s) => _apexPage(const ConsolidationUiScreen(), s)),
    GoRoute(path: '/operations/live-sales-cycle', pageBuilder: (c, s) => _apexPage(const LiveSalesCycleScreen(), s)),
    // /today and /sales etc. moved to top of routes list — see above
    GoRoute(path: '/accounting/coa', redirect: (c, s) => '/coa-tree'),
    GoRoute(path: '/accounting/journal-entries', redirect: (c, s) => '/compliance/journal-entries'),
    GoRoute(path: '/accounting/trial-balance', redirect: (c, s) => '/compliance/financial-statements'),
    GoRoute(path: '/accounting/period-close', redirect: (c, s) => '/operations/period-close'),
    GoRoute(path: '/financial-statements', redirect: (c, s) => '/compliance/financial-statements'),
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
    GoRoute(path: '/sales/customers', pageBuilder: (c, s) => _apexPage(const CustomersListScreen(), s)),
    GoRoute(path: '/sales/invoices', pageBuilder: (c, s) => _apexPage(const InvoicesListScreen(), s)),
    GoRoute(path: '/sales/aging', pageBuilder: (c, s) => _apexPage(const ArAgingScreen(), s)),
    GoRoute(path: '/purchase/vendors', pageBuilder: (c, s) => _apexPage(const VendorsListScreen(), s)),
    GoRoute(path: '/purchase/bills', pageBuilder: (c, s) => _apexPage(const BillsListScreen(), s)),
    GoRoute(path: '/purchase/aging', pageBuilder: (c, s) => _apexPage(const ApAgingScreen(), s)),
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
    GoRoute(path: '/accounting/je-list', pageBuilder: (c, s) => _apexPage(const JeListScreen(), s)),
    GoRoute(path: '/accounting/coa-v2', pageBuilder: (c, s) => _apexPage(const CoaTreeV2Screen(), s)),
    GoRoute(path: '/hr/employees', pageBuilder: (c, s) => _apexPage(const EmployeesListScreen(), s)),
    GoRoute(path: '/hr', redirect: (c, s) => '/hr/employees'),
    GoRoute(path: '/accounting/bank-rec-v2', pageBuilder: (c, s) => _apexPage(const BankRecV2Screen(), s)),
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
    GoRoute(path: '/operations/inventory-v2', pageBuilder: (c, s) => _apexPage(const InventoryV2Screen(), s)),
    GoRoute(path: '/operations/fixed-assets-v2', pageBuilder: (c, s) => _apexPage(const FixedAssetsV2Screen(), s)),
    GoRoute(path: '/analytics/budget-variance-v2', pageBuilder: (c, s) => _apexPage(const BudgetVarianceV2Screen(), s)),
    GoRoute(path: '/analytics/multi-currency-v2', pageBuilder: (c, s) => _apexPage(const MultiCurrencyV2Screen(), s)),
    GoRoute(path: '/analytics/health-score-v2', pageBuilder: (c, s) => _apexPage(const HealthScoreV2Screen(), s)),
    GoRoute(path: '/compliance/lease-v2', pageBuilder: (c, s) => _apexPage(const LeaseScheduleV2Screen(), s)),
    GoRoute(path: '/compliance/zatca-status', pageBuilder: (c, s) => _apexPage(const ZatcaStatusCenterScreen(), s)),
    GoRoute(path: '/compliance/consolidation-v2', pageBuilder: (c, s) => _apexPage(const ConsolidationV2Screen(), s)),
    GoRoute(path: '/admin/ai-suggestions-v2', pageBuilder: (c, s) => _apexPage(const AiSuggestionsQueueV2Screen(), s)),
    GoRoute(path: '/analytics/investment-portfolio-v2', pageBuilder: (c, s) => _apexPage(const InvestmentPortfolioV2Screen(), s)),
    GoRoute(path: '/analytics/project-profitability', pageBuilder: (c, s) => _apexPage(const ProjectProfitabilityScreen(), s)),
    GoRoute(path: '/settings/bank-feeds', pageBuilder: (c, s) => _apexPage(const BankFeedSetupScreen(), s)),
    GoRoute(path: '/compliance/activity-log-v2', pageBuilder: (c, s) => _apexPage(const ActivityLogV2Screen(), s)),
    GoRoute(path: '/sales/recurring', pageBuilder: (c, s) => _apexPage(const RecurringInvoicesScreen(), s)),
    GoRoute(path: '/knowledge/search', pageBuilder: (c, s) => _apexPage(const KnowledgeSearchV2Screen(), s)),
    GoRoute(path: '/sales/quotes', pageBuilder: (c, s) => _apexPage(const QuotesListScreen(), s)),
    GoRoute(path: '/sales/memos', pageBuilder: (c, s) => _apexPage(const CreditMemosScreen(), s)),
    GoRoute(path: '/hr/expense-reports', pageBuilder: (c, s) => _apexPage(const ExpenseReportsScreen(), s)),
    GoRoute(path: '/analytics/cost-variance-v2', pageBuilder: (c, s) => _apexPage(const CostVarianceV2Screen(), s)),
    GoRoute(path: '/compliance/wht-v2', pageBuilder: (c, s) => _apexPage(const WhtV2Screen(), s)),
    GoRoute(path: '/hr/timesheet', pageBuilder: (c, s) => _apexPage(const TimesheetScreen(), s)),
    GoRoute(path: '/operations/petty-cash', pageBuilder: (c, s) => _apexPage(const PettyCashScreen(), s)),
    GoRoute(path: '/operations/stock-card', pageBuilder: (c, s) => _apexPage(const StockCardScreen(), s)),
    GoRoute(
      path: '/operations/stock-card/:sku',
      pageBuilder: (c, s) => _apexPage(StockCardScreen(sku: s.pathParameters['sku']!), s),
    ),
    GoRoute(
      path: '/audit/anomaly/:id',
      pageBuilder: (c, s) => _apexPage(
        AnomalyDetailScreen(anomalyId: s.pathParameters['id']!),
        s,
      ),
    ),
    GoRoute(path: '/workflow/approvals', pageBuilder: (c, s) => _apexPage(const ApprovalsInboxScreen(), s)),
    GoRoute(path: '/accounting/coa/edit', pageBuilder: (c, s) => _apexPage(const CoaEditorScreen(), s)),
    GoRoute(path: '/compliance/risk-register', pageBuilder: (c, s) => _apexPage(const RiskRegisterScreen(), s)),
    GoRoute(path: '/analytics/budget-builder', pageBuilder: (c, s) => _apexPage(const BudgetBuilderScreen(), s)),
    GoRoute(path: '/compliance/kyc-aml', pageBuilder: (c, s) => _apexPage(const KycAmlScreen(), s)),
    GoRoute(path: '/account', redirect: (c, s) => '/settings/unified'),
    GoRoute(path: '/integrations', redirect: (c, s) => '/settings/unified'),
    GoRoute(
      path: '/compliance/journal-entry/:id',
      pageBuilder: (c, s) => _apexPage(
        je_detail_v2.JournalEntryDetailScreen(jeId: s.pathParameters['id']!),
        s,
      ),
    ),

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
    GoRoute(path: '/service-request/detail', pageBuilder: (c, s) {
      return _apexPage(ServiceRequestDetail(request: s.extra as Map<String, dynamic>? ?? {}), s);
    }),
    GoRoute(path: '/notification/detail', pageBuilder: (c, s) {
      return _apexPage(NotificationDetailScreen(notification: s.extra as Map<String, dynamic>? ?? {}), s);
    }),
    GoRoute(path: '/provider/profile', pageBuilder: (c, s) {
      return _apexPage(ProviderProfileScreen(provider: s.extra as Map<String, dynamic>? ?? {}), s);
    }),
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
    GoRoute(path: '/audit/service', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>? ?? {};
      return _apexPage(audit.AuditServiceScreen(
        caseId: args['caseId'] ?? '',
        clientName: args['clientName'] ?? '',
        token: args['token'] as String?,
      ), s);
    }),
  ],
);

