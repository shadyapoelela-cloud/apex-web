/// G-FIN-VENDORS-COMPLETE — source-grep regression tests for the
/// Vendor Create Modal + Details Screen + PickerOrCreate widget.
///
/// Mirror of customers_complete_test.dart with vendor-specific
/// invariants (KSA IBAN format, default payment_terms=net_60,
/// purchase-invoice tab instead of sales-invoice tab).
///
/// 8 contracts pinned.
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

    modalSrc = read('lib/screens/operations/vendor_create_modal.dart');
    listSrc = read('lib/screens/operations/vendors_list_screen.dart');
    detailsSrc = read('lib/screens/operations/vendor_details_screen.dart');
    pickerSrc = read('lib/widgets/forms/vendor_picker_or_create.dart');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-FIN-VENDORS-COMPLETE — VendorCreateModal contract', () {
    test('test_show_returns_future_map', () {
      expect(
        modalSrc.contains('Future<Map<String, dynamic>?> show('),
        isTrue,
        reason: 'VendorCreateModal.show must return '
            'Future<Map<String, dynamic>?>',
      );
    });

    test('test_post_payload_contains_vendor_specific_fields', () {
      // Vendor schema differs from customer in key ways: legal_name_ar
      // (not name_ar), bank_iban / bank_swift / bank_name (no customer
      // analog), default_currency (vs currency), is_preferred flag.
      const required = [
        "'legal_name_ar'",
        "'legal_name_en'",
        "'trade_name'",
        "'kind'",
        "'country'",
        "'cr_number'",
        "'vat_number'",
        "'default_currency'",
        "'payment_terms'",
        "'bank_name'",
        "'bank_iban'",
        "'bank_swift'",
        "'contact_name'",
        "'email'",
        "'phone'",
        "'is_preferred'",
      ];
      for (final f in required) {
        expect(modalSrc.contains(f), isTrue,
            reason: 'modal payload must include $f');
      }
    });

    test('test_ksa_iban_validator_24_chars_starting_with_sa', () {
      // KSA IBAN: SA + 2 check + 4 bank + 18 BBAN = 24 chars total.
      // The validator must enforce this when country == 'SA' but
      // accept other-country IBANs as-is.
      expect(modalSrc.contains("t.length != 24"), isTrue,
          reason: 'KSA IBAN must be 24 chars total');
      expect(modalSrc.contains("t.startsWith('SA')"), isTrue,
          reason: 'KSA IBAN must start with SA');
      expect(modalSrc.contains("if (_country == 'SA')"), isTrue,
          reason: 'IBAN rule must be conditional on country=SA');
    });

    test('test_default_payment_terms_is_net_60', () {
      // Vendors default to net_60 (vs net_30 for customers) — that's
      // the typical asymmetry in working-capital management. Pin it
      // so a future copy-paste from CustomerCreateModal can't silently
      // shorten the default.
      expect(
        modalSrc.contains("String _paymentTerms = 'net_60';"),
        isTrue,
        reason: 'default vendor payment_terms must be net_60',
      );
    });
  });

  group('G-FIN-VENDORS-COMPLETE — list integration', () {
    test('test_list_on_create_opens_modal_then_reloads_inline', () {
      expect(listSrc.contains('VendorCreateModal.show(context)'), isTrue,
          reason: 'list `+ جديد` must open the modal');
      final onCreateIdx = listSrc.indexOf('Future<void> _onCreate()');
      expect(onCreateIdx, greaterThan(0));
      final body = listSrc.substring(onCreateIdx, onCreateIdx + 600);
      expect(body.contains('await _load()'), isTrue,
          reason: '_onCreate must reload the list after save');
    });

    test('test_row_tap_uses_new_finance_vendor_route', () {
      expect(
        listSrc.contains("/app/erp/finance/vendors/\${v['id']}"),
        isTrue,
        reason: 'list row tap must use the new '
            '/app/erp/finance/vendors/:id route',
      );
      expect(
        listSrc.contains("/operations/vendor-360/\${v['id']}"),
        isFalse,
        reason: 'the archived /operations/vendor-360/:id route '
            'must not be used by the list',
      );
    });
  });

  group('G-FIN-VENDORS-COMPLETE — details + router', () {
    test('test_details_has_three_tabs_with_real_endpoints', () {
      expect(detailsSrc.contains('TabController(length: 3'), isTrue);
      expect(detailsSrc.contains('pilotGetVendor'), isTrue,
          reason: 'tab 1 backed by GET /pilot/vendors/{id}');
      expect(detailsSrc.contains('pilotVendorLedger'), isTrue,
          reason: 'tab 2 backed by GET /pilot/vendors/{id}/ledger');
      expect(detailsSrc.contains('pilotListPurchaseInvoices'), isTrue,
          reason:
              'tab 3 lists purchase invoices via /pilot/entities/{eid}/purchase-invoices');
      expect(detailsSrc.contains("inv['vendor_id']"), isTrue,
          reason: 'tab 3 must filter purchase-invoices by vendor_id');
    });

    test('test_router_has_vendor_details_route', () {
      expect(
        routerSrc.contains("'/app/erp/finance/vendors/:vendorId'"),
        isTrue,
        reason: 'router must declare GoRoute for vendor details',
      );
      expect(routerSrc.contains('VendorDetailsScreen('), isTrue);
    });
  });

  group('G-FIN-VENDORS-COMPLETE — picker', () {
    test('test_picker_inline_create_passes_typed_query', () {
      expect(pickerSrc.contains('initialNameAr: prefilledName'), isTrue);
      expect(pickerSrc.contains('VendorCreateModal.show'), isTrue,
          reason: 'picker must open VendorCreateModal');
    });
  });
}
