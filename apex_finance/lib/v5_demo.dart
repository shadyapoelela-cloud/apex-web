/// APEX V5.1 POC — standalone entry point.
///
/// Run: flutter run -t lib/v5_demo.dart -d chrome
///
/// Demonstrates:
///   - Service Switcher (9-dots)
///   - Workspace Selector
///   - 5 Services × 15 Main Modules × 70 Chips
///   - Action-Oriented Dashboards (enhancement #3)
///   - Regulatory News Ticker (enhancement #13)
///   - Hierarchical Shortcuts (Alt+1..5 via dialog hint)
///   - Arabic RTL layout
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/v5/apex_v5_shortcuts.dart';
import 'core/v5/apex_v5_undo_toast.dart';
import 'core/v5/v5_routes.dart';

void main() {
  runApp(const V5DemoApp());
}

class V5DemoApp extends StatelessWidget {
  const V5DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/app',
      routes: v5Routes(),
      errorBuilder: (ctx, state) => Scaffold(
        body: Center(
          child: Text('Error: ${state.error}'),
        ),
      ),
    );

    return MaterialApp.router(
      title: 'APEX V5.1 POC',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: ApexV5GlobalShortcuts(
          child: ApexV5UndoShortcutListener(
            child: child!,
          ),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.light,
        ),
        fontFamily: 'Tajawal',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 15),
          bodyMedium: TextStyle(fontSize: 13),
          bodySmall: TextStyle(fontSize: 12),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          iconTheme: const IconThemeData(color: Colors.black54),
          titleTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
