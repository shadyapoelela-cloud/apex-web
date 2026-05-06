/// Widget tests for the 6 dashboard renderers.
///
/// Each renderer is exercised independently. We don't mock the network
/// — every renderer takes payload as a plain Map, so we just hand it
/// the JSON shape the backend would return.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apex_finance/widgets/dashboard/_base.dart';
import 'package:apex_finance/widgets/dashboard/action_widget_renderer.dart';
import 'package:apex_finance/widgets/dashboard/ai_widget_renderer.dart';
import 'package:apex_finance/widgets/dashboard/chart_widget_renderer.dart';
import 'package:apex_finance/widgets/dashboard/kpi_widget_renderer.dart';
import 'package:apex_finance/widgets/dashboard/list_widget_renderer.dart';
import 'package:apex_finance/widgets/dashboard/table_widget_renderer.dart';

DashboardCatalogEntry _entry({
  required String code,
  required String type,
  String? title,
  Map<String, dynamic>? schema,
}) =>
    DashboardCatalogEntry(
      code: code,
      titleAr: title ?? 'عنوان',
      titleEn: title ?? 'Title',
      category: 'finance',
      widgetType: type,
      configSchema: schema,
    );

/// Wraps the renderer's output in a Material app with a known size.
/// We render via Builder so each test can pass its widget at build
/// time without needing to extract a BuildContext from the test
/// element tree (the previous approach broke when Scaffold
/// introduced extra SizedBoxes into the tree).
Widget _renderInApp(
    Widget Function(BuildContext) builder) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            height: 600,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );

void main() {
  // ── KPI ────────────────────────────────────────────────

  group('KpiWidgetRenderer', () {
    testWidgets('shows trend up icon and percent when positive', (t) async {
      final def = _entry(code: 'kpi.cash', type: 'kpi', title: 'النقد');
      final payload = {
        'value': 100.0,
        'currency': 'SAR',
        'trend': [
          {'date': 'd1', 'value': 80},
          {'date': 'd2', 'value': 100},
        ],
      };
      await t.pumpWidget(_renderInApp(
        (ctx) => const KpiWidgetRenderer().render(ctx, def, payload),
      ));
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      // % chip text contains "25.0%" because (100-80)/80 = 25%.
      expect(find.textContaining('25.0%'), findsOneWidget);
    });

    testWidgets('shows error state when payload is null', (t) async {
      final def = _entry(code: 'kpi.cash', type: 'kpi');
      await t.pumpWidget(_renderInApp(
        (ctx) => const KpiWidgetRenderer().render(ctx, def, null),
      ));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('جارٍ تحميل'), findsOneWidget);
    });

    testWidgets('surfaces backend error message', (t) async {
      final def = _entry(code: 'kpi.cash', type: 'kpi', title: 'النقد');
      await t.pumpWidget(_renderInApp(
        (ctx) => const KpiWidgetRenderer().render(
          ctx,
          def,
          {'value': null, 'error': 'compute_failed'},
        ),
      ));
      expect(find.text('النقد'), findsOneWidget);
      expect(find.textContaining('compute_failed'), findsOneWidget);
    });
  });

  // ── Chart ──────────────────────────────────────────────

  group('ChartWidgetRenderer', () {
    testWidgets('renders fl_chart with single-series shape', (t) async {
      final def = _entry(code: 'chart.rev', type: 'chart', title: 'الإيرادات');
      final payload = {
        'series': [
          {'date': '2026-04-01', 'value': 1.0},
          {'date': '2026-04-02', 'value': 2.0},
          {'date': '2026-04-03', 'value': 3.0},
        ],
      };
      await t.pumpWidget(_renderInApp(
        (ctx) => const ChartWidgetRenderer().render(ctx, def, payload),
      ));
      expect(find.text('الإيرادات'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('shows empty state when series is missing', (t) async {
      final def = _entry(code: 'chart.rev', type: 'chart');
      await t.pumpWidget(_renderInApp(
        (ctx) =>
            const ChartWidgetRenderer().render(ctx, def, {'series': []}),
      ));
      expect(find.textContaining('لا توجد بيانات'), findsOneWidget);
    });
  });

  // ── Table ──────────────────────────────────────────────

  group('TableWidgetRenderer', () {
    testWidgets('paginates rows correctly when over 10', (t) async {
      final def = _entry(code: 'list.cust', type: 'table', title: 'العملاء');
      final rows = [
        for (var i = 0; i < 23; i++) {'id': i, 'name': 'C$i'},
      ];
      await t.pumpWidget(_renderInApp(
        (ctx) =>
            const TableWidgetRenderer().render(ctx, def, {'rows': rows}),
      ));
      expect(find.text('العملاء'), findsOneWidget);
      // Page label "1 / 3" because 23 / 10 = 3 pages.
      expect(find.textContaining('1 / 3'), findsOneWidget);
    });

    testWidgets('shows empty-rows message when rows is empty', (t) async {
      final def = _entry(code: 'list.cust', type: 'table', title: 'العملاء');
      await t.pumpWidget(_renderInApp(
        (ctx) =>
            const TableWidgetRenderer().render(ctx, def, {'rows': []}),
      ));
      expect(find.textContaining('لا توجد صفوف'), findsOneWidget);
    });
  });

  // ── List ───────────────────────────────────────────────

  group('ListWidgetRenderer', () {
    testWidgets('renders items with title + trailing total', (t) async {
      final def = _entry(code: 'list.recent', type: 'list', title: 'أحدث');
      final payload = {
        'items': [
          {'title': 'INV-001', 'subtitle': 'عميل أ', 'trailing': 100},
          {'title': 'INV-002', 'subtitle': 'عميل ب', 'trailing': 200},
        ],
      };
      await t.pumpWidget(_renderInApp(
        (ctx) => const ListWidgetRenderer().render(ctx, def, payload),
      ));
      expect(find.text('أحدث'), findsOneWidget);
      expect(find.text('INV-001'), findsOneWidget);
      expect(find.text('عميل أ'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('falls back to "rows" when "items" missing', (t) async {
      final def = _entry(code: 'list.recent', type: 'list', title: 'أحدث');
      final payload = {
        'rows': [
          {'name': 'الموافقة الأولى'},
        ],
      };
      await t.pumpWidget(_renderInApp(
        (ctx) => const ListWidgetRenderer().render(ctx, def, payload),
      ));
      expect(find.text('الموافقة الأولى'), findsOneWidget);
    });
  });

  // ── AI ─────────────────────────────────────────────────

  group('AiWidgetRenderer', () {
    testWidgets('shows green dot when confidence >= 0.7', (t) async {
      final def = _entry(code: 'widget.ai_pulse', type: 'ai', title: 'النبض');
      await t.pumpWidget(_renderInApp(
        (ctx) => const AiWidgetRenderer().render(
          ctx,
          def,
          {'headline_ar': 'كل شيء بخير', 'confidence': 0.9},
        ),
      ));
      expect(find.text('كل شيء بخير'), findsOneWidget);
      final dots = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final dec = w.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(dots, findsAtLeastNWidgets(1));
    });

    testWidgets('shows error state on null payload', (t) async {
      final def = _entry(code: 'widget.ai_pulse', type: 'ai');
      await t.pumpWidget(_renderInApp(
        (ctx) => const AiWidgetRenderer().render(ctx, def, null),
      ));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  // ── Action ─────────────────────────────────────────────

  group('ActionWidgetRenderer', () {
    testWidgets('plain CTA renders icon + label and is tappable', (t) async {
      final def = _entry(code: 'action.express', type: 'action', title: 'فاتورة سريعة');
      await t.pumpWidget(_renderInApp(
        (ctx) => const ActionWidgetRenderer().render(
          ctx,
          def,
          {'label_ar': 'فاتورة سريعة', 'icon': 'add_circle'},
        ),
      ));
      expect(find.text('فاتورة سريعة'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byType(InkWell), findsAtLeastNWidgets(1));
    });

    testWidgets('mini-form renders fields when configSchema declares them', (t) async {
      final def = _entry(
        code: 'action.express',
        type: 'action',
        title: 'فاتورة',
        schema: {
          'fields': [
            {'key': 'amount', 'type': 'number', 'label_ar': 'المبلغ'},
            {'key': 'note', 'type': 'text', 'label_ar': 'ملاحظة'},
          ],
        },
      );
      await t.pumpWidget(_renderInApp(
        (ctx) => const ActionWidgetRenderer().render(ctx, def, {}),
      ));
      expect(find.text('المبلغ'), findsOneWidget);
      expect(find.text('ملاحظة'), findsOneWidget);
      expect(find.text('إنشاء'), findsOneWidget);
    });
  });
}
