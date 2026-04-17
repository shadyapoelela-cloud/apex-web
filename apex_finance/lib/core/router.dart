import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/copilot/copilot_screen.dart';
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
import '../screens/extracted/subscription_screens.dart';
import '../screens/extracted/notification_screens_v2.dart';
import '../screens/extracted/legal_screens_v2.dart';
import '../screens/extracted/client_screens.dart';
import '../screens/coa_v2/coa_journey_screen.dart';
import '../screens/auth/forgot_password_flow.dart';
import '../screens/auth/slide_auth_screen.dart';
import '../screens/clients/client_onboarding_wizard.dart' as wizard;
import '../screens/marketplace/service_catalog_screen.dart' as catalog;
import '../screens/account/archive_screen.dart' as archive;
import '../screens/tasks/audit_service_screen.dart' as audit;
import '../core/session.dart' show S;
import '../client_create.dart';
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
import '../screens/compliance/journal_entries_screen.dart';
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
import '../screens/compliance/budget_variance_screen.dart';
import '../screens/compliance/bank_rec_screen.dart';
import '../screens/compliance/inventory_screen.dart';
import '../screens/compliance/aging_screen.dart';
import '../screens/compliance/working_capital_screen.dart';
import '../screens/compliance/health_score_screen.dart';
import '../screens/compliance/executive_dashboard_screen.dart';
import '../screens/compliance/ocr_screen.dart';
import 'package:file_picker/file_picker.dart';

final authRefresh = ValueNotifier<int>(0);

/// Smooth page transition — fade + subtle slide
CustomTransitionPage<void> _apexPage(Widget child, GoRouterState state) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
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

final appRouter = GoRouter(
  refreshListenable: authRefresh,
  initialLocation: '/login',
  // redirect: disabled for now - auth handled in login screen,
    routes: [
    // Auth
    GoRoute(path: '/login', pageBuilder: (c, s) => _apexPage(const SlideAuthScreen(), s)),
    // GoRoute(path: '/login-old', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', pageBuilder: (c, s) => _apexPage(const RegScreen(), s)),
    GoRoute(path: '/forgot-password', pageBuilder: (c, s) => _apexPage(const ForgotPasswordScreen(), s)),

    // Main app (with bottom nav)
    GoRoute(path: '/home', pageBuilder: (c, s) => _apexPage(const MainNav(), s)),

    // ── Compliance (ZATCA / IFRS / SOCPA) ──
    GoRoute(
      path: '/compliance',
      pageBuilder: (c, s) => _apexPage(const ComplianceHubScreen(), s),
    ),
    GoRoute(
      path: '/compliance/journal-entries',
      pageBuilder: (c, s) => _apexPage(const JournalEntriesScreen(), s),
    ),
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
    GoRoute(
      path: '/compliance/budget-variance',
      pageBuilder: (c, s) => _apexPage(const BudgetVarianceScreen(), s),
    ),
    GoRoute(
      path: '/compliance/bank-rec',
      pageBuilder: (c, s) => _apexPage(const BankRecScreen(), s),
    ),
    GoRoute(
      path: '/compliance/inventory',
      pageBuilder: (c, s) => _apexPage(const InventoryScreen(), s),
    ),
    GoRoute(
      path: '/compliance/aging',
      pageBuilder: (c, s) => _apexPage(const AgingScreen(), s),
    ),
    GoRoute(
      path: '/compliance/working-capital',
      pageBuilder: (c, s) => _apexPage(const WorkingCapitalScreen(), s),
    ),
    GoRoute(
      path: '/compliance/health-score',
      pageBuilder: (c, s) => _apexPage(const HealthScoreScreen(), s),
    ),
    GoRoute(
      path: '/compliance/executive',
      pageBuilder: (c, s) => _apexPage(const ExecutiveDashboardScreen(), s),
    ),
    GoRoute(
      path: '/compliance/ocr',
      pageBuilder: (c, s) => _apexPage(const OcrScreen(), s),
    ),

    // Account
    GoRoute(path: '/profile/edit', pageBuilder: (c, s) => _apexPage(EditProfileScreen(profile: s.extra as Map<String, dynamic>? ?? {}), s)),
    GoRoute(path: '/password/change', pageBuilder: (c, s) => _apexPage(const ChangePasswordScreen(), s)),
    GoRoute(path: '/account/close', pageBuilder: (c, s) => _apexPage(const CloseAccountScreen(), s)),
    GoRoute(path: '/account/sessions', pageBuilder: (c, s) => _apexPage(const SessionsScreen(), s)),
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
    GoRoute(path: '/onboarding/wizard', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(wizard.ClientOnboardingWizard(token: args?['token'] as String?), s);
    }),
    // Intuitive alias — many UIs linked to /clients/onboarding
    GoRoute(path: '/clients/onboarding', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(wizard.ClientOnboardingWizard(token: args?['token'] as String?), s);
    }),
    GoRoute(path: '/clients/new', pageBuilder: (c, s) {
      final args = s.extra as Map<String, dynamic>?;
      return _apexPage(wizard.ClientOnboardingWizard(token: args?['token'] as String?), s);
    }),
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
    GoRoute(path: '/clients/create', pageBuilder: (c, s) => _apexPage(const ClientCreateScreen2(), s)),
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

