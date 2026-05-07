/// Public projection of the Quick Access pin list, kept in a tiny
/// standalone file so it can be imported by the routing validator and
/// unit tests without pulling in `apex_v5_service_shell.dart` (which
/// uses `dart:html` and therefore can't load on the Dart VM that runs
/// `flutter test`).
///
/// `apex_v5_service_shell.dart` defines the actual `_Pin` list used by
/// the UI. This file mirrors it for validation only — id + route. Any
/// pin add/remove/edit must update both lists; the unit test in
/// `test/v5_routing_test.dart` flags broken routes here.
///
/// See `UAT_FORENSIC_FULL_2026-05-06.md`.
library;

class V5PinRoute {
  final String id;
  final String route;
  const V5PinRoute({required this.id, required this.route});
}

const List<V5PinRoute> kAllPinsForValidation = <V5PinRoute>[
  V5PinRoute(id: 'coa', route: '/app/erp/finance/coa-editor'),
  V5PinRoute(id: 'je', route: '/app/erp/finance/je-builder'),
  V5PinRoute(id: 'tb', route: '/app/erp/finance/statements'),
  V5PinRoute(id: 'financial_reports', route: '/app/erp/finance/statements'),
  V5PinRoute(id: 'journal', route: '/app/erp/finance/statements'),
  V5PinRoute(id: 'vat', route: '/app/erp/finance/vat'),
  V5PinRoute(id: 'fixed_assets', route: '/app/erp/finance/fixed-assets'),
  V5PinRoute(id: 'budgets', route: '/app/erp/finance/budgets'),
  V5PinRoute(id: 'clients', route: '/app/erp/finance/sales-customers'),
  V5PinRoute(id: 'vendors', route: '/app/erp/purchasing/suppliers'),
];
