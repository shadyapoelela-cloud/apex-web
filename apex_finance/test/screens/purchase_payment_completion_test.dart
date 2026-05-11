/// G-PURCHASE-PAYMENT-COMPLETION — regression tests for the
/// regression that PR #190 shipped (purchase details screen was
/// missing the payment button + payment history + backend payments
/// field). Mirrors customer-payment patterns from PR #187/#188.
///
/// 11 contracts pinned across:
///   * Backend payment endpoint (3)
///   * Backend get_pi includes payments[] (2)
///   * VendorPaymentModal exists + mirrors CustomerPaymentModal (3)
///   * Details screen wired with _buildPayments + _recordPayment + button (3)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String detailsSrc;
  late String modalSrc;
  late String apiSrc;
  late String routesSrc;
  late String schemasSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    detailsSrc =
        read('lib/screens/operations/purchase_invoice_details_screen.dart');
    modalSrc = read('lib/screens/operations/vendor_payment_modal.dart');
    apiSrc = read('lib/api_service.dart');
    routesSrc = read('../app/pilot/routes/purchasing_routes.py');
    schemasSrc = read('../app/pilot/schemas/purchasing.py');
  });

  group('G-PURCHASE-PAYMENT-COMPLETION — Backend payment endpoint', () {
    test('test_backend_payment_endpoint_exists', () {
      expect(
        routesSrc.contains(
            '@router.post("/purchase-invoices/{pi_id}/payment"'),
        isTrue,
        reason: 'modal-friendly endpoint must mirror sales path shape',
      );
    });

    test('test_backend_payment_routes_account_by_method', () {
      // cash → 1110, cheque → 1310, default (bank/card/other) → 1120
      // Mirror of _post_customer_payment_je on the sales side. Routing
      // belongs server-side so the modal stays slim.
      expect(routesSrc.contains('paid_from = "1110"'), isTrue,
          reason: 'cash must route to 1110');
      expect(routesSrc.contains('paid_from = "1310"'), isTrue,
          reason: 'cheque must route to 1310');
      expect(routesSrc.contains('paid_from = "1120"'), isTrue,
          reason: 'bank/default must route to 1120');
    });

    test('test_backend_payment_guards_overpayment_and_cancelled', () {
      // Sales side rejects overpayment + paying a cancelled invoice
      // — purchase MUST do the same so the GL stays consistent.
      expect(routesSrc.contains('overpayment'), isTrue,
          reason: 'overpayment must be rejected');
      expect(
        routesSrc.contains('cannot pay a cancelled invoice'),
        isTrue,
        reason: 'paying cancelled must 409',
      );
    });
  });

  group('G-PURCHASE-PAYMENT-COMPLETION — get_pi returns payments[]', () {
    test('test_pi_detail_schema_includes_payments_list', () {
      expect(
        schemasSrc.contains('payments: list["VendorPaymentRead"]'),
        isTrue,
        reason: 'PiDetail must declare a payments field so the '
            'details screen renders history without a 2nd round-trip',
      );
    });

    test('test_get_pi_route_queries_and_returns_payments', () {
      // VendorPayment query by invoice_id, ordered, passed as payments=
      expect(
        routesSrc.contains(
            'VendorPayment.invoice_id == pi_id'),
        isTrue,
        reason: 'get_pi must query VendorPayment by invoice_id',
      );
      expect(
        routesSrc.contains(
            'payments=[VendorPaymentRead.model_validate(p) for p in pays]'),
        isTrue,
        reason: 'get_pi must serialise payments into PiDetail',
      );
    });
  });

  group('G-PURCHASE-PAYMENT-COMPLETION — VendorPaymentModal', () {
    test('test_modal_exposes_show_helper_and_routes_to_endpoint', () {
      expect(modalSrc.contains('class VendorPaymentModal'), isTrue);
      expect(modalSrc.contains('static Future<Map<String, dynamic>?> show'),
          isTrue);
      expect(
        modalSrc.contains('ApiService.pilotRecordVendorPayment'),
        isTrue,
        reason: 'modal must POST to the new payment endpoint',
      );
    });

    test('test_modal_has_notes_and_conditional_bank_account_like_customer', () {
      // Field set must match customer modal so the AP/AR ledgers
      // present the same information.
      expect(modalSrc.contains('_notes'), isTrue);
      expect(modalSrc.contains('_bankAccount'), isTrue);
      // Bank-account row only visible when method == bank_transfer.
      expect(
        modalSrc.contains("if (_method == 'bank_transfer')"),
        isTrue,
        reason: 'bank_account field must be conditional on bank_transfer',
      );
    });

    test('test_modal_merges_reference_bank_notes_into_combined_reference', () {
      // Same audit-trail merge as customer modal — `ref · بنك: X · ملاحظات: Y`.
      expect(modalSrc.contains("'بنك: \$bank'"), isTrue);
      expect(modalSrc.contains("'ملاحظات: \$notes'"), isTrue);
      expect(modalSrc.contains("'reference': combinedReference"), isTrue);
    });
  });

  group('G-PURCHASE-PAYMENT-COMPLETION — Details screen wired', () {
    test('test_details_imports_vendor_payment_modal', () {
      expect(detailsSrc.contains("import 'vendor_payment_modal.dart';"),
          isTrue);
    });

    test('test_details_has_recordPayment_and_buildPayments', () {
      expect(detailsSrc.contains('Future<void> _recordPayment()'), isTrue,
          reason: 'details must expose the modal trigger');
      expect(detailsSrc.contains('Widget _buildPayments()'), isTrue,
          reason: 'details must render payment history');
      expect(detailsSrc.contains('VendorPaymentModal.show'), isTrue);
    });

    test('test_details_renders_pay_button_when_posted_with_balance', () {
      // canPay = posted (or partially_paid/approved/submitted) AND
      // remaining > 0.001. Primary action row uses the same wrap
      // pattern as sales.
      expect(detailsSrc.contains('final canPay = isPosted'), isTrue);
      expect(detailsSrc.contains('+ تسجيل دفع'), isTrue,
          reason: 'primary action label must match sales');
      // api_service surface must exist for the modal to call.
      expect(apiSrc.contains('pilotRecordVendorPayment'), isTrue,
          reason: 'api_service must expose pilotRecordVendorPayment');
    });
  });
}
