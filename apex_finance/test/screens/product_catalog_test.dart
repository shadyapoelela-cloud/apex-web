/// G-FIN-PRODUCT-CATALOG — tests for the Sprint 4 product modal,
/// picker, and EAN-13 helper.
///
/// Two layers:
///   * **Pure-Dart tests** for `ean13CheckDigit` and `generateEan13`
///     (no Flutter import, no SDK-mismatch issues).
///   * **Source-grep tests** for the modal + picker, same reason as
///     prior sprints — the screens transitively pull in `package:web`.
///
/// 12 contracts pinned.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apex_finance/core/barcode_utils.dart';

void main() {
  group('G-FIN-PRODUCT-CATALOG — EAN-13 check digit', () {
    test('test_known_vector_4006381333931', () {
      // Standard reference: barcode "4006381333931" (a real beverage
      // EAN-13 used in EAN documentation). Prefix 400638133393 →
      // check digit 1.
      expect(ean13CheckDigit('400638133393'), 1);
    });

    test('test_known_vector_zeros', () {
      // 12 zeros → check digit 0 (sum is 0, mod 10 is 0, so result
      // stays 0, never wraps to 10).
      expect(ean13CheckDigit('000000000000'), 0);
    });

    test('test_known_vector_5901234123457', () {
      // Another canonical reference from EAN-13 wiki: 590123412345 → 7.
      expect(ean13CheckDigit('590123412345'), 7);
    });

    test('test_rejects_wrong_length', () {
      expect(() => ean13CheckDigit('12345'), throwsArgumentError);
      expect(() => ean13CheckDigit('1234567890123'), throwsArgumentError,
          reason: 'must reject 13-char inputs (caller passed full code by mistake)');
    });

    test('test_rejects_non_digits', () {
      expect(() => ean13CheckDigit('40063813A393'), throwsArgumentError);
    });

    test('test_generate_produces_13_digit_string', () {
      final code = generateEan13('123456789');
      expect(code.length, 13);
      // Last digit must be the valid check digit for the first 12.
      final expected = ean13CheckDigit(code.substring(0, 12));
      expect(int.parse(code[12]), expected,
          reason:
              'generated code must end with the correct check digit');
    });

    test('test_generate_rejects_wrong_prefix_length', () {
      expect(() => generateEan13('1234'), throwsArgumentError);
      expect(() => generateEan13('1234567890'), throwsArgumentError);
    });
  });

  late String modalSrc;
  late String pickerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    modalSrc = read('lib/screens/inventory/product_create_modal.dart');
    pickerSrc = read('lib/widgets/forms/product_picker_or_create.dart');
  });

  group('G-FIN-PRODUCT-CATALOG — ProductCreateModal contract', () {
    test('test_show_returns_future_map', () {
      expect(
        modalSrc.contains('Future<Map<String, dynamic>?> show('),
        isTrue,
        reason: 'show must return Future<Map<String, dynamic>?>',
      );
    });

    test('test_inline_variant_attached', () {
      // The fast-path modal POSTs the product with a single inline
      // variant so the product is invoice-ready immediately. Without
      // this, the caller would need a second round-trip to create a
      // variant before the product can appear in an invoice line.
      expect(modalSrc.contains("'variants': ["), isTrue,
          reason: 'POST payload must include inline variants list');
      expect(modalSrc.contains("'list_price'"), isTrue);
      expect(modalSrc.contains("'sku'"), isTrue);
    });

    test('test_pending_barcode_stashed_for_caller', () {
      // When the user types a barcode in the modal's barcode field,
      // we stash it on the returned map at `_pending_barcode` so the
      // picker (or the invoice line) can POST it to
      // /variants/{vid}/barcodes after the create succeeds. This
      // contract is what lets the barcode-miss flow actually attach
      // the typed barcode to the new product.
      expect(modalSrc.contains("'_pending_barcode'"), isTrue,
          reason: '_pending_barcode key must remain on the return map');
    });
  });

  group('G-FIN-PRODUCT-CATALOG — ProductPickerOrCreate', () {
    test('test_picker_supports_barcode_lookup', () {
      // The picker must call /pilot/tenants/{tid}/barcode/{value} on
      // either the dedicated barcode button or on Enter for numeric
      // input. Without this the scanner-equipped POS use case dies.
      expect(pickerSrc.contains('pilotBarcodeLookup'), isTrue,
          reason: 'picker must use the barcode lookup endpoint');
      expect(pickerSrc.contains('onSubmitted: (v)'), isTrue,
          reason: 'picker must intercept Enter for numeric values');
    });

    test('test_picker_falls_back_to_create_on_barcode_miss', () {
      // Barcode miss must NOT silently fail — it must offer to create
      // with the barcode pre-filled. This is the user-visible promise
      // of the scanner flow.
      expect(
          pickerSrc.contains('initialBarcode: v'), isTrue,
          reason: 'barcode miss must open ProductCreateModal with '
              'initialBarcode pre-filled');
    });
  });
}
