/// G-VENDOR-PAYMENT-LABEL-DEDUP — 2026-05-11.
///
/// Source-grep contracts pinning the vendor-payment modal's dropdown
/// label cleanup. PR #198 (G-PURCHASE-FIXES) widened the vendor
/// payment-method schema to include the Saudi-market `card|mada` keys
/// alongside legacy `credit_card|other`. That shipped a regression
/// where both `card` and `credit_card` rendered with the same Arabic
/// label "بطاقة ائتمان" — the cashier sees what looks like a duplicate
/// entry. This contract pins:
///
///   1. `card` is labeled "بطاقة" (canonical short form)
///   2. `credit_card` is labeled "بطاقة ائتمان (قديم)" (legacy marker)
///   3. The two labels are distinct strings
///   4. The stale `|1310` doc-comment was cleaned up
///   5. All 7 dropdown entries are still present (no accidental drop)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String modalSrc;

  setUpAll(() {
    final f = File('lib/screens/operations/vendor_payment_modal.dart');
    expect(f.existsSync(), isTrue, reason: 'modal file missing');
    modalSrc = f.readAsStringSync();
  });

  group('G-VENDOR-PAYMENT-LABEL-DEDUP — dropdown labels', () {
    test('test_card_uses_short_label', () {
      // `card` is the canonical new Saudi vocabulary — short label.
      expect(
        modalSrc.contains("'card': 'بطاقة'"),
        isTrue,
        reason: '`card` must be labeled with the short form "بطاقة" '
            '(not the long "بطاقة ائتمان" phrase — that would clash '
            'with the legacy credit_card entry).',
      );
    });

    test('test_credit_card_uses_legacy_marker_label', () {
      // `credit_card` is the back-compat entry — marked "(قديم)".
      expect(
        modalSrc.contains("'credit_card': 'بطاقة ائتمان (قديم)'"),
        isTrue,
        reason: '`credit_card` must carry the "(قديم)" legacy marker '
            'so the cashier can distinguish it from `card`.',
      );
    });

    test('test_card_and_credit_card_labels_are_distinct', () {
      // Belt-and-braces: assert the labels are actually different.
      // Use a multi-line-safe regex (CRLF/LF independent) to capture
      // each dropdown row and compare the rendered Arabic strings.
      final cardLabel = RegExp(r"'card':\s*'([^']+)'").firstMatch(modalSrc);
      final creditCardLabel =
          RegExp(r"'credit_card':\s*'([^']+)'").firstMatch(modalSrc);

      expect(cardLabel, isNotNull, reason: '`card` row not found');
      expect(creditCardLabel, isNotNull,
          reason: '`credit_card` row not found');

      final cardText = cardLabel!.group(1)!;
      final creditCardText = creditCardLabel!.group(1)!;

      expect(
        cardText == creditCardText,
        isFalse,
        reason: 'cashier-facing labels for `card` and `credit_card` '
            'must NOT be the same string. Got both = "$cardText".',
      );
    });

    test('test_doc_comment_no_longer_mentions_1310', () {
      // The original modal docstring claimed the backend posts
      // CR 1310 for vendor payments — that's wrong (1310 is the
      // customer-side Cheques-on-Hand asset). Outgoing vendor
      // cheques settle through Bank (1120). G-PURCHASE-FIXES
      // (PR #198) fixed the backend; this PR cleans up the modal's
      // stale comment.
      //
      // Multi-line-safe regex: search for `|1310` anywhere in the
      // first 20 lines (the docstring block) — CRLF/LF safe.
      final lines = modalSrc.split(RegExp(r'\r?\n')).take(20).join('\n');
      expect(
        lines.contains('|1310'),
        isFalse,
        reason: 'modal docstring must NOT mention `|1310` — outgoing '
            'vendor cheques no longer route to 1310 (customer-side '
            'asset). Comment should reference 1120 instead.',
      );
    });

    test('test_all_seven_methods_still_present', () {
      // Regression guard: the dedup is a pure relabel — all 7 method
      // values must still be wired so existing records render.
      const methods = <String>[
        'cash',
        'bank_transfer',
        'cheque',
        'card',
        'mada',
        'credit_card',
        'other',
      ];
      for (final m in methods) {
        expect(
          modalSrc.contains("'$m':"),
          isTrue,
          reason: 'method `$m` must remain in the dropdown map',
        );
      }
    });
  });
}
