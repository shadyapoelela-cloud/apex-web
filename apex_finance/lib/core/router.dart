import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/copilot/copilot_screen.dart';
import '../screens/financial/financial_ops_screen.dart';
import '../screens/knowledge/knowledge_brain_screen.dart';
import '../main.dart' hide S;
import '../screens/extracted/subscription_screens.dart';
import '../screens/extracted/notification_screens_v2.dart';
import '../screens/extracted/legal_screens_v2.dart';
import '../screens/extracted/client_screens.dart';
import '../screens/extracted/coa_screens.dart';
import '../screens/auth/forgot_password_flow.dart';
import '../screens/clients/client_onboarding_wizard.dart' as wizard;
import '../screens/marketplace/service_catalog_screen.dart' as catalog;
import '../screens/account/archive_screen.dart' as archive;
import '../screens/tasks/audit_service_screen.dart' as audit;
import '../core/session.dart' show S;

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
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
    GoRoute(path: '/knowledge-brain', builder: (c, s) => const KnowledgeBrainScreen()),
    GoRoute(path: '/financial-ops', builder: (c, s) => const FinancialOpsScreen()),
    GoRoute(path: '/copilot', builder: (c, s) => const CopilotScreen()),
    GoRoute(path: '/admin/audit', builder: (c, s) => const AuditLogScreen()),
  ],
);

