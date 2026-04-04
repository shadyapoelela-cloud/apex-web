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
import '../widgets/copilot_widgets.dart';
import '../screens/clients/client_detail_screen.dart';
import '../screens/marketplace/service_request_detail.dart';
import '../screens/providers/provider_profile_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../screens/shared/result_detail_panel.dart';
import '../main.dart' hide S;
import '../screens/extracted/subscription_screens.dart';
import '../screens/extracted/notification_screens_v2.dart';
import '../screens/extracted/legal_screens_v2.dart';
import '../screens/extracted/client_screens.dart';
import '../screens/extracted/coa_screens.dart';
import '../screens/auth/forgot_password_flow.dart';
import '../screens/auth/slide_auth_screen.dart';
import '../screens/clients/client_onboarding_wizard.dart' as wizard;
import '../screens/marketplace/service_catalog_screen.dart' as catalog;
import '../screens/account/archive_screen.dart' as archive;
import '../screens/tasks/audit_service_screen.dart' as audit;
import '../core/session.dart' show S;

class AuthNotifier extends ChangeNotifier { void notify() => notifyListeners(); }
final authNotifier = AuthNotifier();

final appRouter = GoRouter(
  refreshListenable: authNotifier,
  initialLocation: '/login',
  // redirect: disabled for now - auth handled in login screen,
    routes: [
    // Auth
    GoRoute(path: '/login', builder: (c, s) => const SlideAuthScreen()),
    // GoRoute(path: '/login-old', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (c, s) => const RegScreen()),
    GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),

    // Main app (with bottom nav)
    GoRoute(path: '/home', builder: (c, s) => const MainNav()),

    // Account
    GoRoute(path: '/profile/edit', builder: (c, s) => EditProfileScreen(profile: s.extra as Map<String, dynamic>? ?? {})),
    GoRoute(path: '/password/change', builder: (c, s) => const ChangePasswordScreen()),
    GoRoute(path: '/account/close', builder: (c, s) => const CloseAccountScreen()),
    GoRoute(path: '/account/sessions', builder: (c, s) => const SessionsScreen()),
    GoRoute(path: '/account/activity', builder: (c, s) => const ActivityHistoryScreen()),

    // Subscription
    GoRoute(path: '/subscription', builder: (c, s) => const SubscriptionScreen()),
    GoRoute(path: '/plans/compare', builder: (c, s) => const PlanComparisonScreen()),

    // Notifications
    GoRoute(path: '/notifications', builder: (c, s) => const NotificationCenterScreenV2()),
    GoRoute(path: '/notifications/prefs', builder: (c, s) => const NotificationPrefsScreen()),

    // Legal
    GoRoute(path: '/legal', builder: (c, s) => LegalDocumentsScreenV2()),

    // Clients
    GoRoute(path: '/clients', builder: (c, s) => const ClientListScreen()),

    // Archive
    GoRoute(path: '/archive', builder: (c, s) => archive.ArchiveScreen(token: S.token ?? '')),

    // Knowledge
    GoRoute(path: '/knowledge/feedback', builder: (c, s) => const KnowledgeFeedbackScreen()),
    GoRoute(path: '/knowledge/console', builder: (c, s) => const KnowledgeDeveloperConsole()),

    // Tasks
    GoRoute(path: '/tasks/types', builder: (c, s) => const TaskTypesBrowserScreen()),

    // Admin
    GoRoute(path: '/admin/reviewer', builder: (c, s) => const ReviewerConsoleScreen()),
    GoRoute(path: '/admin/providers/verify', builder: (c, s) => const ProviderVerificationScreen()),
    GoRoute(path: '/admin/providers/documents', builder: (c, s) => const ProviderDocumentUploadScreen()),
    GoRoute(path: '/admin/providers/compliance', builder: (c, s) => const ProviderComplianceScreen()),
    GoRoute(path: '/admin/policies', builder: (c, s) => const PolicyManagementScreen()),
    GoRoute(path: '/provider-kanban', builder: (c, s) => const ProviderKanbanScreen()),
    GoRoute(path: '/client-detail', builder: (c, s) { final args = s.extra as Map<String,dynamic>? ?? {}; return ClientDetailScreen(clientId: args['id'] ?? '', clientName: args['name'] ?? ''); }),
    GoRoute(path: '/legal-acceptance', builder: (c, s) => const LegalAcceptanceLogger()),
    GoRoute(path: '/compliance-detail', builder: (c, s) => const ProviderComplianceDetailScreen()),
    GoRoute(path: '/coa-tree', builder: (c, s) => const CoaTreeScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const EnhancedSettingsScreen()),
    GoRoute(path: '/dashboard', builder: (c, s) => const EnhancedDashboard()),
    GoRoute(path: '/audit-workflow', builder: (c, s) => const AuditWorkflowScreen()),
    GoRoute(path: '/knowledge-brain', builder: (c, s) => const KnowledgeBrainScreen()),
    GoRoute(path: '/financial-ops', builder: (c, s) => const FinancialOpsScreen()),
    GoRoute(path: '/copilot', builder: (c, s) => const CopilotScreen()),
    GoRoute(path: '/admin/audit', builder: (c, s) => const AuditLogScreen()),
  ],
);

