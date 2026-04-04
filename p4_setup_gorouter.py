import os

base = r'C:\apex_app\apex_finance\lib'

# Step 1: Build the full router.dart with go_router
router_path = os.path.join(base, 'core', 'router.dart')
router_content = r"""import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
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
import '../core/session.dart';

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
    GoRoute(path: '/admin/audit', builder: (c, s) => const AuditLogScreen()),
  ],
);
"""

with open(router_path, 'w', encoding='utf-8') as f:
    f.write(router_content)
print('CREATED core/router.dart with %d routes' % router_content.count('GoRoute('))

# Step 2: Update ApexApp in main.dart to use MaterialApp.router
main_path = os.path.join(base, 'main.dart')
with open(main_path, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Add go_router import if missing
if 'go_router' not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';",
        1
    )
    print('Added go_router import to main.dart')

# Add router.dart import if missing
if 'core/router.dart' not in content:
    content = content.replace(
        "import 'package:go_router/go_router.dart';",
        "import 'package:go_router/go_router.dart';\nimport 'core/router.dart';",
        1
    )
    print('Added core/router.dart import to main.dart')

# Replace the ApexApp class to use MaterialApp.router
old_app = """class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'APEX', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy,  
      appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    home: const LoginScreen());     
}"""

new_app = """class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp.router(
    title: 'APEX', debugShowCheckedModeBanner: false,
    routerConfig: appRouter,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: AC.navy,
      appBarTheme: const AppBarTheme(backgroundColor: AC.navy2, elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AC.gold, foregroundColor: AC.navy,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))));
}"""

if old_app in content:
    content = content.replace(old_app, new_app)
    print('Updated ApexApp to MaterialApp.router')
else:
    # Try a more flexible match
    print('WARNING: Could not find exact ApexApp pattern. Trying flexible match...')
    lines = content.split('\n')
    start = None
    end = None
    for i, line in enumerate(lines):
        if 'class ApexApp extends StatelessWidget' in line:
            start = i
        if start is not None and line.strip() == '}' and i > start + 3:
            end = i
            break
    
    if start is not None and end is not None:
        new_app_lines = new_app.split('\n')
        lines[start:end+1] = new_app_lines
        content = '\n'.join(lines)
        print('Updated ApexApp via flexible match (L%d-L%d)' % (start+1, end+1))
    else:
        print('ERROR: Could not locate ApexApp class')

with open(main_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('')
print('DONE')
print('go_router is now active with MaterialApp.router')
print('All existing Navigator.push calls still work (go_router supports both)')
print('')
print('Run: flutter analyze 2>&1 | Select-String "error" | Measure-Object')
