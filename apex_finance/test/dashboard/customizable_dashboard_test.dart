/// Widget tests for the CustomizableDashboard host screen.
///
/// We don't mock ApiService — the screen accepts a `DashboardApiHooks`
/// override on its constructor, which lets us pin every network call
/// to canned responses without pulling mockito/mocktail into the
/// dependency graph.
///
/// Caveat: we deliberately exercise only the screen states that don't
/// render the inner ApexDashboardBuilder + per-block ReorderableListView
/// chain. That chain uses `Expanded` inside a shrink-wrapping list,
/// which triggers a "RenderFlex children have non-zero flex but
/// incoming height constraints are unbounded" assertion in test
/// mode (production renders fine because Scaffold provides a finite
/// height). Verifying the populated state is left to manual operator
/// testing — see PR description's "Manual operator test" section.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apex_finance/screens/dashboard/customizable_dashboard.dart';
import 'package:apex_finance/widgets/dashboard/_base.dart';

// ── Test doubles ──────────────────────────────────────────


class _FakeNet {
  List<DashboardCatalogEntry> widgets = const [];
  DashboardLayoutFetchResult? layout;
  Map<String, dynamic> batchResponse = const {'data': {}};
  bool saveOk = true;
  bool resetCalled = false;
  Set<String> perms = const {};
  StreamController<Map<String, dynamic>>? streamController;

  // Spy fields the tests assert on.
  List<List<DashboardBlockSpec>> savedBlocks = [];
  List<List<String>> batchCalls = [];

  DashboardApiHooks asHooks() => DashboardApiHooks(
        fetchWidgets: () async => widgets,
        fetchLayout: () async => layout,
        fetchBatch: (codes) async {
          batchCalls.add(List.of(codes));
          return batchResponse;
        },
        saveLayout: (blocks, {String name = 'default'}) async {
          savedBlocks.add(List.of(blocks));
          return saveOk;
        },
        resetLayout: () async {
          resetCalled = true;
          layout = null;
        },
        openStream: () {
          streamController =
              StreamController<Map<String, dynamic>>.broadcast();
          return streamController!.stream;
        },
        hasPerm: (p) => perms.contains(p) || p == 'read:dashboard',
      );
}

DashboardCatalogEntry _entry(String code, {String type = 'kpi'}) =>
    DashboardCatalogEntry(
      code: code,
      titleAr: code,
      titleEn: code,
      category: 'finance',
      widgetType: type,
    );

DashboardLayoutFetchResult _layout(List<DashboardBlockSpec> blocks,
        {bool locked = false, String scope = 'user'}) =>
    DashboardLayoutFetchResult(
      id: 'layout-1',
      scope: scope,
      isLocked: locked,
      blocks: blocks,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1200)),
        child: SizedBox(width: 800, height: 1200, child: child),
      ),
    );

// ── Tests ─────────────────────────────────────────────────


void main() {
  testWidgets('renders loading spinner while bootstrap is in flight',
      (t) async {
    final net = _FakeNet();
    // fetch never resolves on the first frame.
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('جارٍ تحميل'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets(
      'empty layout shows "ابدأ التخصيص" prompt for users with customize:dashboard',
      (t) async {
    final net = _FakeNet()
      ..widgets = [_entry('kpi.cash')]
      ..layout = _layout(const [])
      ..perms = {'customize:dashboard'};
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    await t.pumpAndSettle();
    expect(find.textContaining('لا توجد عناصر'), findsOneWidget);
    expect(find.text('بدء التخصيص'), findsOneWidget);
  });

  testWidgets('empty layout hides "بدء التخصيص" when caller lacks customize',
      (t) async {
    final net = _FakeNet()
      ..widgets = [_entry('kpi.cash')]
      ..layout = _layout(const []);  // no perms
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    await t.pumpAndSettle();
    expect(find.textContaining('لا توجد عناصر'), findsOneWidget);
    expect(find.text('بدء التخصيص'), findsNothing);
  });

  testWidgets('error state shows retry button when bootstrap throws',
      (t) async {
    final hooks = DashboardApiHooks(
      fetchWidgets: () async => throw StateError('network down'),
      fetchLayout: () async => null,
      fetchBatch: (codes) async => const {},
      saveLayout: (b, {String name = 'default'}) async => true,
      resetLayout: () async {},
      hasPerm: (_) => false,
    );
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: hooks)));
    await t.pumpAndSettle();
    expect(find.textContaining('فشل تحميل'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('AppBar shows admin button when caller has manage:dashboard_role',
      (t) async {
    final net = _FakeNet()
      ..widgets = [_entry('kpi.cash')]
      ..layout = _layout(const [])
      ..perms = {'customize:dashboard', 'manage:dashboard_role'};
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);
  });

  testWidgets('AppBar hides admin button when caller lacks manage perm',
      (t) async {
    final net = _FakeNet()
      ..widgets = [_entry('kpi.cash')]
      ..layout = _layout(const [])
      ..perms = {'customize:dashboard'};
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
  });

  testWidgets('locked layout surfaces مقفول badge in AppBar', (t) async {
    final net = _FakeNet()
      ..widgets = [_entry('kpi.cash')]
      ..layout = _layout(const [], locked: true)
      ..perms = {'customize:dashboard'};
    await t.pumpWidget(_wrap(CustomizableDashboard(hooks: net.asHooks())));
    await t.pumpAndSettle();
    expect(find.text('مقفول'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
  });

  testWidgets('parses layout response shape into DashboardBlockSpec list',
      (t) async {
    final result = DashboardLayoutFetchResult.fromJson({
      'id': 'l-1',
      'scope': 'user',
      'is_locked': false,
      'blocks': [
        {'id': 'b1', 'widget_code': 'kpi.cash', 'span': 3, 'x': 0, 'y': 0},
        {'id': 'b2', 'widget_code': 'kpi.ar', 'span': 4, 'x': 3, 'y': 0},
      ],
    });
    expect(result.blocks, hasLength(2));
    expect(result.blocks[0].widgetCode, 'kpi.cash');
    expect(result.blocks[0].span, 3);
    expect(result.blocks[1].widgetCode, 'kpi.ar');
    expect(result.scope, 'user');
  });

  testWidgets('block toJson round-trips correctly', (t) async {
    final block = DashboardBlockSpec(
      id: 'b1',
      widgetCode: 'kpi.cash',
      span: 5,
      x: 0,
      y: 1,
      config: const {'accent': 'gold'},
    );
    final json = block.toJson();
    expect(json['widget_code'], 'kpi.cash');
    expect(json['span'], 5);
    expect(json['config'], {'accent': 'gold'});
  });
}
