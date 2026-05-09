/// G-SALES-INVOICE-UX-COMPLETE — frontend regression tests for the
/// 4 UX fixes (BUG #1 row→details, picker integration, payment modal,
/// ZATCA QR). Same source-grep approach as prior sprints because the
/// screens transitively load `package:web` which fails the SDK gate
/// in `flutter test` (G-T1.1).
///
/// 8 contracts pinned + 4 ZATCA TLV unit tests = 12 tests total.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apex_finance/core/zatca_tlv.dart';

void main() {
  late String listSrc;
  late String detailsSrc;
  late String createSrc;
  late String modalSrc;
  late String routerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    listSrc = read('lib/screens/operations/sales_invoices_screen.dart');
    detailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
    createSrc = read('lib/screens/operations/sales_invoice_create_screen.dart');
    modalSrc = read('lib/screens/operations/customer_payment_modal.dart');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-SALES-INVOICE-UX-COMPLETE — Bug #1 fix', () {
    test('test_list_navigation_opens_details_not_je', () {
      // Pre-fix: _openInvoice routed straight to /je-builder/{jeId}.
      // Post-fix: routes to /sales-invoices/{id}. The latter is
      // verifiable in source; the former MUST be gone.
      expect(
        listSrc.contains("/app/erp/finance/sales-invoices/\$id"),
        isTrue,
        reason:
            '_openInvoice must navigate to the details screen by invoice id',
      );
      // Defensive: the old jeId-bypass must not survive in _openInvoice.
      final openIdx = listSrc.indexOf('void _openInvoice(');
      expect(openIdx, greaterThan(0), reason: '_openInvoice must exist');
      final endIdx = (openIdx + 500).clamp(0, listSrc.length);
      final body = listSrc.substring(openIdx, endIdx);
      expect(
        body.contains("'/app/erp/finance/je-builder/\$jeId'"),
        isFalse,
        reason: '_openInvoice must NOT route to je-builder anymore — '
            'the JE is reachable only via the explicit "عرض القيد" '
            'button on the details screen',
      );
    });

    test('test_router_has_invoice_details_route', () {
      expect(
        routerSrc.contains("'/app/erp/finance/sales-invoices/:invoiceId'"),
        isTrue,
        reason: 'router must declare GoRoute for invoice details',
      );
      expect(routerSrc.contains('SalesInvoiceDetailsScreen('), isTrue);
    });
  });

  group('G-SALES-INVOICE-UX-COMPLETE — Details screen contract', () {
    test('test_details_screen_calls_get_invoice_endpoint', () {
      expect(detailsSrc.contains('pilotGetSalesInvoice'), isTrue,
          reason: 'screen must call GET /sales-invoices/{id}');
    });

    test('test_details_shows_je_link_with_explicit_button', () {
      // The JE link is the ONLY way to reach the JE-builder from this
      // screen. If it disappears, the user has no path to verify the
      // auto-posted JE.
      expect(detailsSrc.contains('عرض القيد'), isTrue,
          reason: 'JE link button must remain on details screen');
      expect(
        detailsSrc.contains("'/app/erp/finance/je-builder/\$jeId'"),
        isTrue,
        reason: 'JE link must navigate to /je-builder/{jeId}',
      );
    });

    test('test_details_renders_qr_only_for_issued_invoices', () {
      // ZATCA QR is meaningful only after issuance — a draft has no
      // timestamp/total commitment yet. Pin both halves: the QR must
      // call the TLV helper for issued, and show the placeholder hint
      // for drafts.
      expect(detailsSrc.contains('zatcaQrBase64'), isTrue,
          reason: 'must use the TLV helper to build QR data');
      expect(detailsSrc.contains('QrImageView'), isTrue,
          reason: 'must render the QR via qr_flutter');
      expect(detailsSrc.contains('بعد الإصدار'), isTrue,
          reason: 'must show the post-issue hint for draft invoices');
    });

    test('test_details_has_payment_button_only_when_balance_remaining', () {
      // The "+ تسجيل دفع" button must NOT show on draft (no JE yet),
      // and must NOT show on fully-paid invoices. Pin both gates.
      expect(detailsSrc.contains('+ تسجيل دفع'), isTrue,
          reason: 'payment button label must remain');
      expect(detailsSrc.contains('canPay = isIssued && remaining > 0.001'),
          isTrue,
          reason: 'payment button must gate on issued + remaining > 0');
    });
  });

  group('G-SALES-INVOICE-UX-COMPLETE — Product picker integration', () {
    test('test_create_screen_imports_product_picker', () {
      expect(
        createSrc.contains(
            "import '../../widgets/forms/product_picker_or_create.dart';"),
        isTrue,
        reason: 'create screen must import the product picker',
      );
      expect(createSrc.contains('ProductPickerOrCreate('), isTrue);
    });

    test('test_product_pick_autofills_description_and_price', () {
      // The whole point of the picker is auto-fill. If a future
      // refactor breaks the on-pick handler, the picker becomes a
      // decorative dropdown.
      expect(createSrc.contains('_onProductSelected'), isTrue);
      expect(createSrc.contains('_descCtrl.text = desc'), isTrue,
          reason: 'on pick → fill description');
      expect(createSrc.contains("_amountCtrl.text = '\$price'"), isTrue,
          reason: 'on pick → fill unit_price from variant.list_price');
      expect(createSrc.contains("_vatRateCtrl.text = '0'"), isTrue,
          reason: 'on pick → vat=0 for zero_rated/exempt products');
    });

    test('test_payload_includes_product_and_variant_ids', () {
      // Backend later runs the COGS JE leg from product_id + variant_id
      // when the variant has a cost. Without persisting these on the
      // payload, COGS auto-post breaks even when a product was picked.
      expect(createSrc.contains("'product_id': productId"), isTrue);
      expect(createSrc.contains("'variant_id': variantId"), isTrue);
    });
  });

  group('G-SALES-INVOICE-UX-COMPLETE — Payment modal', () {
    test('test_payment_modal_show_returns_future_map', () {
      expect(
        modalSrc.contains('Future<Map<String, dynamic>?> show('),
        isTrue,
        reason: 'CustomerPaymentModal.show must return '
            'Future<Map<String, dynamic>?> for the snackbar to read '
            'journal_entry_id and link to it',
      );
    });

    test('test_payment_modal_validates_overpayment', () {
      // The backend now rejects overpayments (409). The modal must
      // catch this client-side too so the user sees the error
      // immediately, not after a network round-trip.
      expect(modalSrc.contains('widget.remainingBalance + 0.001'), isTrue,
          reason: 'modal must validate amount <= remaining balance');
    });

    test('test_payment_modal_calls_record_payment_endpoint', () {
      expect(modalSrc.contains('pilotRecordCustomerPayment'), isTrue);
    });
  });

  group('G-SALES-INVOICE-UX-COMPLETE — ZATCA TLV (real unit tests)', () {
    test('test_tlv_encodes_all_5_phase1_tags', () {
      final bytes = zatcaTlvBytes(
        sellerName: 'APEX',
        vatNumber: '300000000000003',
        invoiceTimestampUtc: DateTime.utc(2026, 5, 10, 12, 0, 0),
        invoiceTotal: '115.00',
        vatTotal: '15.00',
      );
      // Tag 1 → 'APEX' (4 bytes) → starts with 0x01, 0x04, 'A', 'P', 'E', 'X'
      expect(bytes[0], 1, reason: 'first tag must be 1 (seller name)');
      expect(bytes[1], 4, reason: 'tag-1 length must be 4 ("APEX")');
      // utf-8 'A' is 0x41
      expect(bytes[2], 0x41);
      // Walk through and confirm all 5 tags appear in order.
      var i = 0;
      final seen = <int>[];
      while (i < bytes.length) {
        seen.add(bytes[i]);
        final len = bytes[i + 1];
        i += 2 + len;
      }
      expect(seen, [1, 2, 3, 4, 5]);
    });

    test('test_tlv_handles_arabic_seller_utf8', () {
      // Arabic UTF-8 is multi-byte. Length must reflect byte length,
      // not character length, so a downstream QR scanner can decode.
      final bytes = zatcaTlvBytes(
        sellerName: 'أبكس',
        vatNumber: '300000000000003',
        invoiceTimestampUtc: DateTime.utc(2026, 5, 10),
        invoiceTotal: '115',
        vatTotal: '15',
      );
      expect(bytes[0], 1);
      final tag1Len = bytes[1];
      // 'أبكس' is 4 chars but encodes to 8 UTF-8 bytes.
      expect(tag1Len, 8,
          reason: 'tag-1 length must equal UTF-8 byte length, not char count');
    });

    test('test_tlv_rejects_oversized_value', () {
      expect(
        () => zatcaTlvBytes(
          sellerName: 'A' * 256,
          vatNumber: '300000000000003',
          invoiceTimestampUtc: DateTime.utc(2026, 5, 10),
          invoiceTotal: '0',
          vatTotal: '0',
        ),
        throwsArgumentError,
        reason: 'Phase 1 only supports 1-byte length encoding (max 255)',
      );
    });

    test('test_qr_base64_round_trip', () {
      final qr = zatcaQrBase64(
        sellerName: 'APEX',
        vatNumber: '300000000000003',
        invoiceTimestampUtc: DateTime.utc(2026, 5, 10, 12, 0, 0),
        invoiceTotal: '115.00',
        vatTotal: '15.00',
      );
      final decoded = base64Decode(qr);
      // Tag 1 = seller name = 'APEX' (4 bytes) → first 6 bytes are
      // 0x01 0x04 'A' 'P' 'E' 'X'.
      expect(decoded[0], 1);
      expect(decoded[1], 4);
      expect(String.fromCharCodes(decoded.sublist(2, 6)), 'APEX');
    });
  });
}
