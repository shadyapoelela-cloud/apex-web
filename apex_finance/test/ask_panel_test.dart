/// Widget tests for Ask APEX panel + related widgets.
///
/// These are structural smoke tests — they prove the widgets build,
/// render RTL, wire up correctly, and expose the expected buttons.
/// They do NOT exercise the HTTP layer (ApiService calls would require
/// a network stub and are better covered by the backend test suite).
library;

import 'package:apex_finance/core/apex_ai_usage_widget.dart';
import 'package:apex_finance/core/apex_ask_panel.dart';
import 'package:apex_finance/core/apex_omni_create.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget inside a MaterialApp so it has a Directionality +
/// ScaffoldMessenger, which production code relies on.
Widget _hosted(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}


void main() {
  group('ApexAskFab', () {
    testWidgets('renders Arabic label + sparkle icon', (tester) async {
      await tester.pumpWidget(_hosted(const ApexAskFab()));
      expect(find.text('اسأل أبكس'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('tapping the FAB opens the slide-over', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: const ApexAskFab(),
          body: const SizedBox.expand(),
        ),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      // Let the transition complete.
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      // The header text lives inside the panel.
      expect(find.text('اسأل أبكس'), findsWidgets);
      expect(find.text('مساعد ذكي يقرأ دفاترك ويجيب بالعربية'), findsOneWidget);
    });

    testWidgets('empty state shows 5 suggestion chips', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: const ApexAskFab(),
          body: const SizedBox.expand(),
        ),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('كم صرفنا على التسويق هذا الشهر؟'), findsOneWidget);
      expect(find.text('اعرض قائمة الدخل لهذا الشهر'), findsOneWidget);
      expect(find.text('ما رصيد النقدية؟'), findsOneWidget);
    });
  });

  group('ApexOmniCreateFab', () {
    testWidgets('renders "+ جديد" label', (tester) async {
      await tester.pumpWidget(_hosted(const ApexOmniCreateFab()));
      expect(find.text('جديد'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping shows the create menu', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: const ApexOmniCreateFab(),
          body: const SizedBox.expand(),
        ),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('ما الذي تريد إنشاءه؟'), findsOneWidget);
      expect(find.text('فاتورة ضريبية'), findsOneWidget);
      expect(find.text('قيد يومية'), findsOneWidget);
      expect(find.text('سؤال للمساعد'), findsOneWidget);
    });
  });

  group('ApexAiUsageCard', () {
    testWidgets('shows header labels while loading', (tester) async {
      await tester.pumpWidget(_hosted(const ApexAiUsageCard(tenantId: 't-test')));
      expect(find.text('استهلاك الذكاء الاصطناعي'), findsOneWidget);
      expect(find.text('الشهر الحالي'), findsOneWidget);
      // While loading, a progress spinner is visible.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ApexDualFab', () {
    testWidgets('renders both Ask and Create FABs', (tester) async {
      await tester.pumpWidget(_hosted(const ApexDualFab()));
      expect(find.byType(ApexAskFab), findsOneWidget);
      expect(find.byType(ApexOmniCreateFab), findsOneWidget);
    });
  });
}
