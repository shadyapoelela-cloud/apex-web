/// G-POS-ZATCA-QR — regression tests for the Phase-1 ZATCA QR on
/// POS receipts. Pre-fix the POS Quick Sale flow showed only invoice
/// number + JE link + WhatsApp share on the success card — no QR
/// code despite `core/zatca_tlv.dart` already shipping the helper.
/// That made every POS receipt non-compliant with ZATCA Phase 1 for
/// B2C simplified-tax invoices.
///
/// 6 contracts pinned:
///   * QR helper import + render call (3)
///   * Receipt captures the data needed to drive the helper (2)
///   * QR is rendered defensively (1)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String posSrc;
  late String tlvSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
    tlvSrc = read('lib/core/zatca_tlv.dart');
  });

  group('G-POS-ZATCA-QR — QR helper wired', () {
    test('test_pos_imports_zatca_helper_and_qr_widget', () {
      // The two imports needed for the QR to render — the TLV helper
      // and the qr_flutter view widget.
      expect(posSrc.contains("import '../../core/zatca_tlv.dart';"),
          isTrue,
          reason: 'POS must import the ZATCA TLV helper');
      expect(posSrc.contains("import 'package:qr_flutter/qr_flutter.dart';"),
          isTrue,
          reason: 'POS must import QrImageView');
    });

    test('test_pos_calls_zatcaQrBase64_with_all_five_phase1_tags', () {
      // zatcaQrBase64 requires all 5 Phase-1 fields. Missing any one
      // produces an invalid QR that ZATCA scanners will reject.
      expect(posSrc.contains('zatcaQrBase64('), isTrue);
      const required = [
        'sellerName:',
        'vatNumber:',
        'invoiceTimestampUtc:',
        'invoiceTotal:',
        'vatTotal:',
      ];
      for (final f in required) {
        expect(posSrc.contains(f), isTrue,
            reason: 'zatcaQrBase64 call must pass `$f`');
      }
    });

    test('test_pos_renders_QrImageView_in_receipt', () {
      // The QR widget must actually be in the receipt-card tree —
      // not just imported. Pin the widget instantiation pattern.
      expect(posSrc.contains('QrImageView('), isTrue,
          reason: 'POS receipt must render the QR widget');
      expect(posSrc.contains('QrVersions.auto'), isTrue);
    });
  });

  group('G-POS-ZATCA-QR — Receipt captures QR inputs', () {
    test('test_lastReceipt_captures_timestamp_seller_and_vat_total', () {
      // _lastReceipt MUST persist the five inputs the QR helper needs.
      // We pin the keys so a future change to the Map doesn't silently
      // drop the QR.
      expect(posSrc.contains("'issued_at_utc':"), isTrue);
      expect(posSrc.contains("'seller_vat_number':"), isTrue);
      expect(posSrc.contains("'seller_name':"), isTrue);
      // VAT amount + total captured on the receipt. G-POS-MULTILINE-
      // CLEANUP (2026-05-11) renamed `_vatAmount`/`_total` (single-
      // line) to `capturedVat`/`capturedTotal` (sum-of-lines). Pin
      // the keys but allow either variable name.
      expect(RegExp(r"'vat':\s*\w+").hasMatch(posSrc), isTrue,
          reason: "receipt must persist a 'vat' field");
      expect(RegExp(r"'total':\s*\w+").hasMatch(posSrc), isTrue,
          reason: "receipt must persist a 'total' field");
    });

    test('test_tlv_helper_phase1_tag_schedule_unchanged', () {
      // Pin the 5 Phase-1 tags so a refactor of the helper doesn't
      // break compliance. Tag 1=seller, 2=VAT#, 3=timestamp,
      // 4=invoice total, 5=VAT total.
      for (var tag = 1; tag <= 5; tag++) {
        expect(tlvSrc.contains('_TlvField($tag,'), isTrue,
            reason: 'TLV tag $tag must be emitted');
      }
    });
  });

  group('G-POS-ZATCA-QR — Defensive rendering', () {
    test('test_qr_render_wrapped_in_try_catch', () {
      // zatcaQrBase64 throws when a TLV value exceeds 255 bytes (e.g.
      // a malformed seller name). The receipt should still render —
      // only the QR hides.
      expect(posSrc.contains('try {'), isTrue);
      expect(posSrc.contains('qrData = zatcaQrBase64'), isTrue);
      expect(posSrc.contains('qrData = null'), isTrue,
          reason: 'fallback must null-out qrData on error');
      // Render guard so the row collapses gracefully.
      expect(posSrc.contains('if (qrData != null)'), isTrue);
    });
  });
}
