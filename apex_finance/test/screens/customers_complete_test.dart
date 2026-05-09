/// G-FIN-CUSTOMERS-COMPLETE — source-grep regression tests for
/// the Customer Create Modal + Details Screen + PickerOrCreate widget.
///
/// Why source-grep tests
/// ─────────────────────
/// The customer screens import `package:flutter/material.dart` and
/// transitively load components that pull in `package:web` — loading
/// any of them via `flutter_test`'s WidgetTester surfaces the G-T1.1
/// SDK mismatch on `package:web` 1.1.1.  Source-grep pins the structural
/// contract instead: the shape of each guarantee survives future
/// refactors that might unintentionally break it.
///
/// 7 contracts pinned:
///
///   1. CustomerCreateModal.show returns Future of Map (the contract
///      every caller depends on for inline create + auto-select).
///   2. CustomerCreateModal POSTs to pilotCreateCustomer with the
///      14 documented fields.
///   3. CustomerCreateModal validates `vat_number` length == 15.
///   4. CustomersListScreen `_onCreate` opens the modal and refreshes
///      the list inline (no navigation away).
///   5. CustomersListScreen row tap navigates to the new
///      `/app/erp/finance/customers/{id}` route, not the archived
///      `/operations/customer-360/{id}` route.
///   6. CustomerDetailsScreen exposes 3 tabs (details / ledger /
///      invoices) backed by GET /pilot/customers/{id} +
///      /ledger + /entities/{id}/sales-invoices filtered by
///      customer_id.
///   7. CustomerPickerOrCreate exposes an inline "+ عميل جديد" flow
///      that opens CustomerCreateModal with the typed query as
///      `initialNameAr`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String modalSrc;
  late String listSrc;
  late String detailsSrc;
  late String pickerSrc;
  late String routerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    modalSrc = read('lib/screens/operations/customer_create_modal.dart');
    listSrc = read('lib/screens/operations/customers_list_screen.dart');
    detailsSrc = read('lib/screens/operations/customer_details_screen.dart');
    pickerSrc = read('lib/widgets/forms/customer_picker_or_create.dart');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-FIN-CUSTOMERS-COMPLETE — CustomerCreateModal contract', () {
    test('test_show_returns_future_map', () {
      // Every caller (CustomersListScreen._onCreate,
      // CustomerPickerOrCreate._openCreateModal,
      // future Sales-Invoice line picker in Sprint 5) depends on
      // CustomerCreateModal.show(...) returning a Future that resolves
      // to the created customer Map (or null on cancel). If the return
      // type ever changes, callers silently break.
      expect(
        modalSrc.contains('Future<Map<String, dynamic>?> show('),
        isTrue,
        reason: 'CustomerCreateModal.show must return '
            'Future<Map<String, dynamic>?>',
      );
    });

    test('test_post_payload_contains_documented_fields', () {
      // The audit doc + CustomerCreate Pydantic schema list these
      // fields. If the modal stops sending one of them, the user-
      // visible field is silently dead. Pin the 11 user-facing ones.
      const required = [
        "'name_ar'",
        "'name_en'",
        "'kind'",
        "'email'",
        "'phone'",
        "'vat_number'",
        "'cr_number'",
        "'address_street'",
        "'address_city'",
        "'currency'",
        "'payment_terms'",
        "'credit_limit'",
        "'notes'",
      ];
      for (final f in required) {
        expect(modalSrc.contains(f), isTrue,
            reason: 'modal payload must include $f');
      }
    });

    test('test_vat_validator_pins_15_digit_rule', () {
      // KSA TIN is exactly 15 digits. The schema doesn't enforce
      // this server-side (left as a string), so the client-side
      // validator is the only gate. Regression risk: a future
      // copy-paste might soften the rule.
      expect(modalSrc.contains('digits.length != 15'), isTrue,
          reason: 'vat_number must be validated as exactly 15 digits');
    });
  });

  group('G-FIN-CUSTOMERS-COMPLETE — list integration', () {
    test('test_list_on_create_opens_modal_then_reloads_inline', () {
      // The pre-Sprint-2 wiring routed `+ جديد` to `/sales` (a
      // placeholder). Post-fix it must:
      //   (a) await CustomerCreateModal.show(context)
      //   (b) call _load() to refresh the list inline
      // Pin both halves so a future refactor can't accidentally
      // restore the placeholder route.
      expect(listSrc.contains('CustomerCreateModal.show(context)'), isTrue,
          reason: 'list `+ جديد` must open the modal');
      final onCreateIdx = listSrc.indexOf('Future<void> _onCreate()');
      expect(onCreateIdx, greaterThan(0),
          reason: '_onCreate must be Future<void>, not void');
      // After the await, _load() must run.
      final onCreateBody =
          listSrc.substring(onCreateIdx, onCreateIdx + 600);
      expect(onCreateBody.contains('await _load()'), isTrue,
          reason: '_onCreate must await _load() to refresh the list');
    });

    test('test_row_tap_uses_new_finance_route', () {
      // The legacy /operations/customer-360/:id route was archived
      // in Sprint 15 Stage 4f; using it now would render the "coming
      // soon" banner. The new route lives at
      // /app/erp/finance/customers/{id} and is wired in router.dart
      // (test_router_has_customer_details_route below).
      expect(
        listSrc.contains("/app/erp/finance/customers/\${c['id']}"),
        isTrue,
        reason:
            'list row tap must use the new /app/erp/finance/customers/:id route',
      );
      expect(
        listSrc.contains("/operations/customer-360/\${c['id']}"),
        isFalse,
        reason: 'the archived /operations/customer-360/:id route '
            'must not be used by the list',
      );
    });
  });

  group('G-FIN-CUSTOMERS-COMPLETE — details screen + router', () {
    test('test_details_has_three_tabs_with_real_endpoints', () {
      // The 3-tab layout is the user-visible promise. Pin each tab's
      // backing call so a refactor can't silently kill one.
      expect(detailsSrc.contains('TabController(length: 3'), isTrue,
          reason: 'details screen must have exactly 3 tabs');
      expect(detailsSrc.contains('pilotGetCustomer'), isTrue,
          reason: 'tab 1 backed by GET /pilot/customers/{id}');
      expect(detailsSrc.contains('pilotCustomerLedger'), isTrue,
          reason: 'tab 2 backed by GET /pilot/customers/{id}/ledger');
      expect(detailsSrc.contains('pilotListSalesInvoices'), isTrue,
          reason: 'tab 3 lists invoices via '
              '/pilot/entities/{eid}/sales-invoices');
      expect(detailsSrc.contains("inv['customer_id']"), isTrue,
          reason: 'tab 3 must filter invoices by customer_id');
    });

    test('test_router_has_customer_details_route', () {
      // The list points at /app/erp/finance/customers/:customerId.
      // If the GoRoute is missing or path-keyed differently, every
      // row tap dead-ends in a 404.
      expect(
        routerSrc.contains("'/app/erp/finance/customers/:customerId'"),
        isTrue,
        reason:
            'router must declare GoRoute for /app/erp/finance/customers/:customerId',
      );
      expect(
        routerSrc.contains('CustomerDetailsScreen('),
        isTrue,
        reason: 'route must build CustomerDetailsScreen',
      );
    });
  });

  group('G-FIN-CUSTOMERS-COMPLETE — picker', () {
    test('test_picker_inline_create_passes_typed_query_as_initial_name', () {
      // When the user types a name that doesn't match any existing
      // customer and clicks "+ عميل جديد", the modal must open with
      // the typed text pre-filled in the name field. Skipping this
      // forces double-typing and is the single most-asked UX nit.
      expect(
        pickerSrc.contains('initialNameAr: prefilledName'),
        isTrue,
        reason:
            'picker must pass the typed query as initialNameAr to the modal',
      );
      expect(pickerSrc.contains('CustomerCreateModal.show'), isTrue,
          reason: 'picker must open CustomerCreateModal, not navigate');
    });
  });
}
