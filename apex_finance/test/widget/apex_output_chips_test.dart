/// G-T1: structural widget tests for ApexOutputChips — the cross-link
/// footer that lives at the bottom of every INPUT screen.
///
/// Pure UI widget (only flutter/material + go_router + theme), so it
/// compiles cleanly on the Dart VM. Tests for screens that pull
/// `api_service.dart` are blocked by a pre-existing test infra issue
/// (`package:web` 1.1.1 vs Flutter 3.27.4). See G-T1.1 for the fix plan.
library;

import 'package:apex_finance/widgets/apex_output_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _hosted(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('ApexOutputChips', () {
    testWidgets('renders the default title', (tester) async {
      await tester.pumpWidget(_hosted(ApexOutputChips(items: const [
        ApexChipLink('VAT Return', '/compliance/vat-return', Icons.receipt_long),
      ])));
      expect(find.text('مخرجات مرتبطة'), findsOneWidget);
    });

    testWidgets('respects a custom title', (tester) async {
      await tester.pumpWidget(_hosted(const ApexOutputChips(
        title: 'تقارير ذات صلة',
        items: [ApexChipLink('VAT', '/compliance/vat', Icons.receipt)],
      )));
      expect(find.text('تقارير ذات صلة'), findsOneWidget);
    });

    testWidgets('renders one chip per ApexChipLink', (tester) async {
      await tester.pumpWidget(_hosted(ApexOutputChips(items: const [
        ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
        ApexChipLink('VAT Return', '/compliance/vat-return', Icons.receipt_long),
        ApexChipLink('Cash Flow', '/analytics/cash-flow', Icons.show_chart),
      ])));
      expect(find.text('أعمار AR'), findsOneWidget);
      expect(find.text('VAT Return'), findsOneWidget);
      expect(find.text('Cash Flow'), findsOneWidget);
      expect(find.byIcon(Icons.timeline), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('collapses to nothing when items list is empty', (tester) async {
      await tester.pumpWidget(_hosted(const ApexOutputChips(items: [])));
      // Empty list -> SizedBox.shrink(), so neither title nor any chip text appears.
      expect(find.text('مخرجات مرتبطة'), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('chips are tappable (InkWell present)', (tester) async {
      await tester.pumpWidget(_hosted(ApexOutputChips(items: const [
        ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
      ])));
      // One InkWell per chip — confirms onTap wiring exists. We don't
      // tap it: that would invoke context.go(...) and need a GoRouter.
      expect(find.byType(InkWell), findsOneWidget);
    });
  });
}
