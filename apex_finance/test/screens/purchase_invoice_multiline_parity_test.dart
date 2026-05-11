/// G-PURCHASE-MULTILINE-PARITY — regression tests for the purchase
/// side of the invoice flow. Mirrors `sales_invoice_multiline_prefill_test.dart`
/// from PR #189 — the same source-grep approach because the create
/// screen transitively loads `package:web` which fails the SDK gate
/// under flutter_test (G-T1.1).
///
/// 12 contracts pinned across:
///   * Multi-line refactor (4)
///   * Edit prefill via `?bill_id=` (3)
///   * Row-click → details screen (Bug-#1 parity) (2)
///   * Details screen exists + Cancel/Edit/Print + JE link (2)
///   * Backend cancel route (1)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String createSrc;
  late String detailsSrc;
  late String listSrc;
  late String apiSrc;
  late String routerSrc;
  late String routesSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    createSrc =
        read('lib/screens/operations/purchase_invoice_create_screen.dart');
    detailsSrc =
        read('lib/screens/operations/purchase_invoice_details_screen.dart');
    listSrc = read('lib/screens/operations/purchase_invoices_screen.dart');
    apiSrc = read('lib/api_service.dart');
    routerSrc = read('lib/core/router.dart');
    // Backend route lives in the parent repo, not under apex_finance/.
    routesSrc = read('../app/pilot/routes/purchasing_routes.py');
    // Touch apiSrc so analyzer doesn't flag it as unused. The new api
    // methods are validated in the dedicated assertion below.
    expect(apiSrc, contains('pilotGetPurchaseInvoice'),
        reason: 'api_service must declare pilotGetPurchaseInvoice');
    expect(apiSrc, contains('pilotCancelPurchaseInvoice'),
        reason: 'api_service must declare pilotCancelPurchaseInvoice');
  });

  group('G-PURCHASE-MULTILINE-PARITY — Multi-line refactor', () {
    test('test_pi_line_draft_class_with_per_line_controllers', () {
      expect(createSrc.contains('class _PiLineDraft'), isTrue);
      // Each line MUST own its 4 controllers + a product slot so
      // independent editing + product-picker selection works per line.
      expect(createSrc.contains('TextEditingController desc'), isTrue);
      expect(createSrc.contains('TextEditingController qty'), isTrue);
      expect(createSrc.contains('TextEditingController unitCost'), isTrue);
      expect(createSrc.contains('TextEditingController vatRate'), isTrue);
      expect(createSrc.contains('? product'), isTrue,
          reason: '_PiLineDraft must expose `product` slot');
    });

    test('test_lines_collection_starts_with_one_draft', () {
      expect(
        createSrc.contains('final List<_PiLineDraft> _lines = [_PiLineDraft()]'),
        isTrue,
        reason: 'screen must initialise with exactly one empty line draft',
      );
    });

    test('test_add_and_remove_line_methods_exist_with_guard', () {
      expect(createSrc.contains('void _addLine()'), isTrue);
      expect(createSrc.contains('void _removeLine(int index)'), isTrue);
      expect(createSrc.contains('if (_lines.length <= 1) return;'), isTrue,
          reason: 'remove must guard against emptying the lines list');
    });

    test('test_payload_serialises_all_lines_with_qty_unit_cost', () {
      expect(createSrc.contains('linesPayload.add({'), isTrue,
          reason: 'payload must loop over _lines and serialise each');
      expect(createSrc.contains("'lines': linesPayload"), isTrue);
      // Purchase uses `qty` + `unit_cost` (NOT quantity/unit_price like sales)
      // — matches PiLineInput in app/pilot/schemas/purchasing.py.
      expect(createSrc.contains("'qty': l.quantityValue"), isTrue);
      expect(createSrc.contains("'unit_cost': l.unitCostValue"), isTrue);
      expect(createSrc.contains("'vat_rate_pct': l.vatRateValue"), isTrue);
    });
  });

  group('G-PURCHASE-MULTILINE-PARITY — Edit pre-fill', () {
    test('test_prefill_bill_id_param_exists_on_widget', () {
      expect(createSrc.contains('final String? prefillBillId'), isTrue);
      expect(
        createSrc.contains(
            'const PurchaseInvoiceCreateScreen({super.key, this.prefillBillId})'),
        isTrue,
      );
    });

    test('test_router_passes_query_param_to_screen', () {
      expect(
        routerSrc.contains("'/app/erp/finance/purchase-invoice-create'"),
        isTrue,
        reason: 'router must declare the explicit GoRoute for the '
            'create screen so query params reach the widget',
      );
      expect(
        routerSrc.contains("s.uri.queryParameters['bill_id']"),
        isTrue,
        reason: 'route must read bill_id from query params',
      );
    });

    test('test_prefill_locks_form_on_non_draft', () {
      expect(createSrc.contains('_editLocked = !isDraft'), isTrue,
          reason: 'edit must lock when bill is not draft');
      expect(createSrc.contains('_readOnlyBanner()'), isTrue);
      expect(createSrc.contains('AbsorbPointer'), isTrue,
          reason: 'inputs must be wrapped in AbsorbPointer when locked');
    });
  });

  group('G-PURCHASE-MULTILINE-PARITY — Row click opens details (Bug-#1 parity)', () {
    test('test_list_row_routes_to_details_not_je_builder', () {
      // Pre-fix the list row jumped to /je-builder/{jeId}. The fix
      // routes to the details screen. The JE-builder is reachable
      // only via the explicit "عرض القيد" button on details.
      expect(
        listSrc.contains("context.go('/app/erp/finance/purchase-bills/\$id')"),
        isTrue,
        reason: 'row click must open details screen',
      );
      // The old behaviour must be gone — confirm no remnant of
      // navigating to /je-builder from _openInvoice.
      final openIdx = listSrc.indexOf('void _openInvoice');
      expect(openIdx, greaterThan(0));
      final end = (openIdx + 800).clamp(0, listSrc.length);
      final body = listSrc.substring(openIdx, end);
      expect(body.contains('je-builder'), isFalse,
          reason: '_openInvoice must NOT navigate to je-builder directly');
    });

    test('test_router_has_details_route_for_billId', () {
      expect(
        routerSrc.contains("'/app/erp/finance/purchase-bills/:billId'"),
        isTrue,
        reason: 'router must declare a GoRoute for the details screen',
      );
      expect(routerSrc.contains('PurchaseInvoiceDetailsScreen'), isTrue);
    });
  });

  group('G-PURCHASE-MULTILINE-PARITY — Details screen', () {
    test('test_details_has_cancel_edit_print_and_je_link', () {
      // Action buttons mirror sales.
      expect(detailsSrc.contains('Future<void> _cancel()'), isTrue);
      expect(detailsSrc.contains('void _print()'), isTrue);
      // Edit button routes to create with ?bill_id query.
      // G-POS-MULTILINE-CLEANUP (2026-05-11) closes GAP-11: pre-fix
      // this assertion used a literal `\n` separator which broke on
      // Windows where git checkout converts to CRLF. Use a multiline
      // regex so the test passes on both line-ending conventions.
      expect(
        RegExp(
                r"'/app/erp/finance/purchase-invoice-create'\s*'\?bill_id=")
            .hasMatch(detailsSrc),
        isTrue,
        reason: 'Edit button must route to create with ?bill_id query',
      );
      // JE banner links to the JE builder.
      expect(
        detailsSrc.contains("/app/erp/finance/je-builder/\$jeId"),
        isTrue,
        reason: 'JE banner must link to the je-builder',
      );
    });

    test('test_details_has_scroll_fix_pattern_matching_sales', () {
      // Same Bug-A scroll pattern as sales: explicit controller +
      // PrimaryScrollController.none + AlwaysScrollableScrollPhysics.
      expect(detailsSrc.contains('ScrollController _scrollCtrl'), isTrue);
      expect(detailsSrc.contains('PrimaryScrollController.none'), isTrue);
      expect(RegExp(r'Scrollbar\(').hasMatch(detailsSrc), isTrue);
      expect(detailsSrc.contains('AlwaysScrollableScrollPhysics'), isTrue);
    });
  });

  group('G-PURCHASE-MULTILINE-PARITY — Backend cancel route', () {
    test('test_backend_cancel_route_with_je_reversal', () {
      expect(
        routesSrc.contains('@router.post("/purchase-invoices/{pi_id}/cancel"'),
        isTrue,
        reason: 'cancel endpoint must exist mirroring sales',
      );
      expect(
        routesSrc.contains('reverse_journal_entry'),
        isTrue,
        reason: 'cancel must reverse the JE if posted',
      );
      // Must refuse when paid_amount > 0 — same guard as sales.
      expect(
        routesSrc.contains('invoice has applied payments'),
        isTrue,
        reason: 'cancel must refuse when payments applied',
      );
    });
  });
}
