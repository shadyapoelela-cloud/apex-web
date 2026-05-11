/// G-PAYMENT-METHOD-VALIDATION — regression tests for the type-safety
/// asymmetry on the customer payment endpoint. VendorPaymentCreate had a
/// strict pattern; CustomerPaymentInput.method was a plain str accepting
/// any string. Pinned to ^(cash|bank_transfer|cheque|card|mada)$ matching
/// what customer_payment_modal.dart actually sends.
///
/// 7 contracts pinned across:
///   * Backend CustomerPaymentInput pattern presence (1)
///   * Pattern includes all 5 modal-sent values (1)
///   * Customer modal dropdown still offers the same 5 values — parity (1)
///   * Vendor modal continues to use its own pattern — no collateral damage (1)
///   * _post_customer_payment_je still routes cash → 1110, cheque → 1310 (2)
///   * _post_customer_payment_je else-branch routes everything else → 1120 (1)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String customerRoutesSrc;
  late String purchasingSchemasSrc;
  late String customerModalSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    customerRoutesSrc = read('../app/pilot/routes/customer_routes.py');
    purchasingSchemasSrc = read('../app/pilot/schemas/purchasing.py');
    customerModalSrc = read('lib/screens/operations/customer_payment_modal.dart');
  });

  group('G-PAYMENT-METHOD-VALIDATION — Backend strict pattern', () {
    test('test_customer_payment_input_method_has_pattern_validator', () {
      // CustomerPaymentInput.method must use Field(pattern=...) — not a
      // plain str. Use RegExp (not literal \n) to be CRLF-safe on Windows.
      final classBlock = RegExp(
        r'class\s+CustomerPaymentInput\s*\(\s*BaseModel\s*\)\s*:[\s\S]*?'
        r'method\s*:\s*str\s*=\s*Field\s*\(',
      );
      expect(
        classBlock.hasMatch(customerRoutesSrc),
        isTrue,
        reason: 'CustomerPaymentInput.method must use Field(...) — '
            'not a plain `method: str = "..."`',
      );
      expect(
        customerRoutesSrc.contains('pattern="^(cash|bank_transfer|cheque|card|mada)\$"'),
        isTrue,
        reason: 'CustomerPaymentInput.method must declare a strict '
            'pattern matching the modal\'s 5 dropdown values',
      );
    });

    test('test_pattern_includes_all_five_modal_values', () {
      // The pattern must contain each of the 5 modal-sent values as a
      // literal token. Validate one-by-one so a failure tells us which
      // method is missing rather than just "pattern mismatch".
      final pattern = RegExp(
        r'pattern="\^\((?<body>[^"]+)\)\$"',
      ).firstMatch(customerRoutesSrc);
      expect(pattern, isNotNull,
          reason: 'must have a pydantic pattern="^(...)\$" on method');
      final body = pattern!.namedGroup('body')!;
      final tokens = body.split('|');
      for (final v in ['cash', 'bank_transfer', 'cheque', 'card', 'mada']) {
        expect(tokens, contains(v),
            reason: 'modal-sent value "$v" must be in the pattern');
      }
    });
  });

  group('G-PAYMENT-METHOD-VALIDATION — Modal parity', () {
    test('test_customer_modal_dropdown_offers_same_five_values', () {
      // The dropdown is the spec; the backend must match it. Confirm
      // each value still appears as a dropdown key so a future modal
      // refactor doesn't silently diverge from the backend pattern.
      for (final v in ['cash', 'bank_transfer', 'cheque', 'card', 'mada']) {
        expect(
          customerModalSrc.contains("'$v':"),
          isTrue,
          reason: 'customer_payment_modal dropdown must still offer "$v"',
        );
      }
    });
  });

  group('G-PAYMENT-METHOD-VALIDATION — Vendor flow', () {
    test('test_vendor_payment_pattern_includes_card_and_mada', () {
      // G-PURCHASE-FIXES (PR #198, 2026-05-11) widened the vendor
      // pattern to include `card` and `mada` for Saudi-market parity
      // with the customer side. Legacy `credit_card` + `other` are
      // retained for back-compat. The two patterns no longer diverge
      // intentionally — the goal is now consistent Saudi vocabulary
      // on both flows, with the vendor side keeping extra back-compat
      // entries that customer-side never had.
      expect(
        RegExp(
                r'pattern\s*=\s*"\^\(cash\|bank_transfer\|cheque\|credit_card\|card\|mada\|other\)\$"')
            .hasMatch(purchasingSchemasSrc),
        isTrue,
        reason: 'VendorPaymentCreate.method must include card + mada after PR #198',
      );
    });
  });

  group('G-PAYMENT-METHOD-VALIDATION — JE routing pinned', () {
    test('test_je_routes_cash_to_1110', () {
      // method_lower == "cash" → code "1110" sub "cash"
      final cashBlock = RegExp(
        r'method_lower\s*==\s*"cash"[\s\S]{0,120}'
        r'cash_code,\s*cash_sub\s*=\s*"1110",\s*"cash"',
      );
      expect(
        cashBlock.hasMatch(customerRoutesSrc),
        isTrue,
        reason: 'cash must route to 1110/cash — pinned to catch refactors',
      );
    });

    test('test_je_routes_cheque_to_1310', () {
      final chequeBlock = RegExp(
        r'method_lower\s*in\s*\(\s*"cheque"\s*,\s*"check"\s*\)[\s\S]{0,120}'
        r'cash_code,\s*cash_sub\s*=\s*"1310",\s*"cash_equivalent"',
      );
      expect(
        chequeBlock.hasMatch(customerRoutesSrc),
        isTrue,
        reason: 'cheque/check must route to 1310/cash_equivalent',
      );
    });

    test('test_je_else_branch_routes_card_and_mada_to_1120', () {
      // Pattern is strict so the else-branch now only sees
      // bank_transfer / card / mada. All three settle to 1120.
      final elseBlock = RegExp(
        r'else:[\s\S]{0,200}'
        r'cash_code,\s*cash_sub\s*=\s*"1120",\s*"bank"',
      );
      expect(
        elseBlock.hasMatch(customerRoutesSrc),
        isTrue,
        reason: 'else-branch must route bank_transfer/card/mada to 1120/bank',
      );
    });
  });
}
