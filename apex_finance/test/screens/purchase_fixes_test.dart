/// G-PURCHASE-FIXES — source-grep regression tests for the 5
/// purchase-side gaps bundled in feat/g-purchase-fixes (2026-05-11):
///
///   1) Cheque routing 1310 wrong for vendor (outgoing) cheques.
///   2) Vendor payment lacks card/mada (Saudi market gap).
///   3) Cancel guard threshold mismatch (UI 0.001 vs backend >0).
///   4) Legacy `paid_from_account_code` default "1110" ignores method.
///   5) Print preview gated on `!isDraft` instead of `!isCancelled`.
///
/// Contracts pinned by reading the source bytes directly (not
/// flutter widget tests) — same pattern as
/// purchase_payment_completion_test.dart.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String purchaseDetailsSrc;
  late String salesDetailsSrc;
  late String modalSrc;
  late String routesSrc;
  late String schemasSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    purchaseDetailsSrc =
        read('lib/screens/operations/purchase_invoice_details_screen.dart');
    salesDetailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
    modalSrc = read('lib/screens/operations/vendor_payment_modal.dart');
    routesSrc = read('../app/pilot/routes/purchasing_routes.py');
    schemasSrc = read('../app/pilot/schemas/purchasing.py');
  });

  group('G-PURCHASE-FIXES #1 — Cheque routing (no more 1310 on vendor side)',
      () {
    test('test_payment_endpoint_no_longer_routes_to_1310', () {
      // Negative assertion — the buggy `paid_from = "1310"` must be
      // gone from the slim /payment endpoint. (We allow the literal
      // "1310" elsewhere in commentary/docstrings; what we forbid is
      // an assignment of paid_from to it.)
      expect(
        routesSrc.contains('paid_from = "1310"'),
        isFalse,
        reason:
            'outgoing vendor cheques must NOT debit 1310 (Cheques on '
            'Hand — customer-side asset). They settle through bank 1120.',
      );
    });

    test('test_payment_endpoint_routes_cash_to_1110_and_rest_to_1120', () {
      // Multiline assertion — match the new else-branch routing using
      // RegExp with dotAll for CRLF/LF safety.
      final r = RegExp(
        r'if method == "cash":\s+paid_from = "1110"\s+else:\s+'
        r'.*?paid_from = "1120"',
        dotAll: true,
      );
      expect(
        r.hasMatch(routesSrc),
        isTrue,
        reason:
            'new routing block must be: cash → 1110, else → 1120 '
            '(covering cheque/card/mada/credit_card/bank_transfer/other).',
      );
    });

    test('test_payment_endpoint_comment_explains_new_rule', () {
      // Doc comment update — the function header now mentions
      // G-PURCHASE-FIXES and the corrected 1310 reasoning.
      expect(
        routesSrc.contains('G-PURCHASE-FIXES'),
        isTrue,
        reason: 'header doc must reference the gap ticket.',
      );
    });
  });

  group('G-PURCHASE-FIXES #2 — Vendor payment card/mada support', () {
    test('test_schema_method_pattern_includes_card_and_mada', () {
      // Schema regex must accept both new methods.
      expect(
        schemasSrc.contains(
          'pattern="^(cash|bank_transfer|cheque|credit_card|card|mada|other)\$"',
        ),
        isTrue,
        reason: 'VendorPaymentCreate.method must accept card + mada',
      );
    });

    test('test_slim_endpoint_allow_list_includes_card_and_mada', () {
      // The /payment endpoint hand-validates method against a tuple.
      // RegExp with dotAll because the tuple may be split across lines.
      final r = RegExp(
        r'if method not in \(\s*"cash"[^)]*"card"[^)]*"mada"',
        dotAll: true,
      );
      expect(
        r.hasMatch(routesSrc),
        isTrue,
        reason: 'slim /payment allow-list must include card and mada',
      );
    });

    test('test_vendor_modal_dropdown_includes_card_and_mada_keys', () {
      // Dropdown values are Dart map literals; new keys must appear.
      expect(modalSrc.contains("'card':"), isTrue,
          reason: "modal dropdown must offer 'card'");
      expect(modalSrc.contains("'mada':"), isTrue,
          reason: "modal dropdown must offer 'mada'");
      // Backward-compat keys retained.
      expect(modalSrc.contains("'credit_card':"), isTrue,
          reason: "credit_card kept for existing records");
      expect(modalSrc.contains("'other':"), isTrue,
          reason: "other kept for existing records");
    });
  });

  group('G-PURCHASE-FIXES #3 — Cancel UI threshold aligned with backend',
      () {
    test('test_purchase_cancel_uses_strict_paid_le_zero', () {
      // The buggy 0.001 fuzz must be gone from the canCancel line.
      expect(
        purchaseDetailsSrc.contains('paid <= 0.001'),
        isFalse,
        reason:
            'purchase cancel UI must NOT use a 0.001 float fuzz — '
            'backend rejects > 0 strictly.',
      );
      expect(
        purchaseDetailsSrc.contains('paid <= 0'),
        isTrue,
        reason: 'purchase cancel guard must be paid <= 0',
      );
    });

    test('test_sales_cancel_uses_strict_paid_le_zero', () {
      // Sales side mirrored.
      expect(
        salesDetailsSrc.contains('paid <= 0.001'),
        isFalse,
        reason: 'sales cancel UI must not use a 0.001 float fuzz',
      );
      expect(
        salesDetailsSrc.contains('paid <= 0'),
        isTrue,
        reason: 'sales cancel guard must be paid <= 0',
      );
    });
  });

  group(
      'G-PURCHASE-FIXES #4 — Legacy /vendor-payments derives paid_from from method',
      () {
    test('test_legacy_endpoint_overrides_default_when_method_not_cash', () {
      // Match the override block across CRLF or LF using RegExp + dotAll.
      final r = RegExp(
        r'paid_from = payload\.paid_from_account_code\s+'
        r'if paid_from == "1110" and payload\.method != "cash":\s+'
        r'.*?paid_from = "1120"',
        dotAll: true,
      );
      expect(
        r.hasMatch(routesSrc),
        isTrue,
        reason:
            'create_vp_endpoint must override schema default "1110" '
            'when method != cash to derive the correct bank account.',
      );
    });

    test('test_legacy_endpoint_passes_derived_paid_from', () {
      // The call site uses the local `paid_from` variable, not the
      // raw payload field, so the override actually reaches
      // create_vendor_payment.
      expect(
        routesSrc.contains('paid_from_account_code=paid_from,'),
        isTrue,
        reason:
            'create_vendor_payment must receive the derived '
            'paid_from, not the raw schema field',
      );
    });
  });

  group('G-PURCHASE-FIXES #5 — Print button allowed on drafts', () {
    test('test_purchase_print_button_gated_on_not_cancelled', () {
      // The Print button must use !isCancelled instead of !isDraft.
      // We pin the exact condition via a small RegExp that allows
      // either inline or commented-around layouts.
      final r = RegExp(r'if \(!isCancelled\)\s*\n\s*OutlinedButton',
          dotAll: true);
      expect(
        r.hasMatch(purchaseDetailsSrc),
        isTrue,
        reason:
            'purchase Print must gate on !isCancelled so drafts get '
            'print preview.',
      );
      // Negative: the old `!isDraft` gate before an OutlinedButton
      // for Print must NOT exist.
      final old = RegExp(
        r'if \(!isDraft\)\s*\n\s*OutlinedButton\.icon\([^)]*_print',
        dotAll: true,
      );
      expect(
        old.hasMatch(purchaseDetailsSrc),
        isFalse,
        reason: 'old !isDraft → _print gate must be gone',
      );
    });

    test('test_sales_print_button_gated_on_not_cancelled', () {
      final r = RegExp(r'if \(!isCancelled\)\s*\n\s*OutlinedButton',
          dotAll: true);
      expect(
        r.hasMatch(salesDetailsSrc),
        isTrue,
        reason: 'sales Print must mirror purchase: gate on !isCancelled',
      );
      final old = RegExp(
        r'if \(!isDraft\)\s*\n\s*OutlinedButton\.icon\([^)]*_print',
        dotAll: true,
      );
      expect(
        old.hasMatch(salesDetailsSrc),
        isFalse,
        reason: 'old !isDraft → _print gate must be gone on sales side',
      );
    });
  });
}
