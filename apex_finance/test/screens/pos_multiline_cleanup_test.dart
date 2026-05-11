/// G-POS-MULTILINE-CLEANUP — regression tests for the final pieces
/// of the Finance Module parity work:
///
///   * GAP-2  POS Quick Sale single-line → multi-line with
///            ProductPickerOrCreate per line, matching sales/purchase.
///   * GAP-12 Legacy VendorPaymentScreen archived; router + V5 chip
///            no longer point at it.
///
/// 10 contracts pinned. Same source-grep approach as prior sprints
/// because the screens transitively load `package:web` which fails
/// the SDK gate under flutter_test (G-T1.1).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String posSrc;
  late String routerSrc;
  late String chipsSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
    routerSrc = read('lib/core/router.dart');
    chipsSrc = read('lib/core/v5/v5_wired_screens.dart');
  });

  group('G-POS-MULTILINE-CLEANUP — POS multi-line (GAP-2)', () {
    test('test_pos_line_draft_class_with_per_line_controllers', () {
      expect(posSrc.contains('class _PosLineDraft'), isTrue);
      // Each line MUST own its 4 controllers + a product slot so
      // independent editing + product-picker selection works per line.
      expect(posSrc.contains('TextEditingController desc'), isTrue);
      expect(posSrc.contains('TextEditingController qty'), isTrue);
      expect(posSrc.contains('TextEditingController unitPrice'), isTrue);
      expect(posSrc.contains('TextEditingController vatRate'), isTrue);
      expect(posSrc.contains('? product'), isTrue,
          reason: '_PosLineDraft must expose `product` slot');
    });

    test('test_pos_lines_starts_with_one_draft', () {
      expect(
        posSrc.contains(
            'final List<_PosLineDraft> _lines = [_PosLineDraft()]'),
        isTrue,
        reason: 'POS must initialise with exactly one empty line draft',
      );
    });

    test('test_pos_add_remove_with_guard', () {
      expect(posSrc.contains('void _addLine()'), isTrue);
      expect(posSrc.contains('void _removeLine(int index)'), isTrue);
      expect(posSrc.contains('if (_lines.length <= 1) return;'), isTrue,
          reason: 'remove must guard against emptying the list');
    });

    test('test_pos_payload_serialises_all_lines', () {
      expect(posSrc.contains('linesPayload.add({'), isTrue,
          reason: 'payload must loop over _lines and serialise each');
      expect(posSrc.contains("'lines': linesPayload"), isTrue);
      // G-POS-BACKEND-INTEGRATION-V2 (2026-05-11): POS no longer
      // routes through the sales-invoice endpoint — it now calls
      // `POST /pilot/pos-transactions` directly. The PosLineInput
      // schema uses `qty` + `unit_price_override` + `vat_rate_override`
      // (NOT the sales-side `quantity`/`unit_price`/`vat_rate`).
      expect(posSrc.contains("'qty': l.quantityValue"), isTrue,
          reason: 'POS payload must serialise qty (PosLineInput shape)');
      expect(posSrc.contains("'unit_price_override': l.unitPriceValue"), isTrue,
          reason: 'POS payload must serialise unit_price_override');
      expect(posSrc.contains("'vat_rate_override': l.vatRateValue"), isTrue,
          reason: 'POS payload must serialise vat_rate_override');
    });

    test('test_pos_uses_product_picker_in_line_card', () {
      expect(
        posSrc.contains("import '../../widgets/forms/product_picker_or_create.dart';"),
        isTrue,
        reason: 'POS must import ProductPickerOrCreate',
      );
      expect(posSrc.contains('ProductPickerOrCreate('), isTrue,
          reason: 'each line must embed the picker');
    });

    test('test_pos_grand_totals_computed_from_lines', () {
      // _grandSubtotal / _grandVat / _grandTotal must fold over _lines
      // so the totals card stays accurate as the cashier edits any line.
      expect(posSrc.contains('double get _grandSubtotal'), isTrue);
      expect(posSrc.contains('double get _grandVat'), isTrue);
      expect(posSrc.contains('double get _grandTotal'), isTrue);
      expect(posSrc.contains('_lines.fold'), isTrue,
          reason: 'totals must be a fold over the lines list');
    });

    test('test_pos_resets_lines_after_successful_submit', () {
      // After a sale is recorded, the form should reset to a single
      // empty line so the cashier can start the next sale without
      // manually clearing fields.
      // Hotfix: use RegExp instead of literal `\n` so Windows-CRLF
      // checkouts still pass (same root cause as GAP-11 in PR #193).
      expect(
        RegExp(r'_lines\s+\.\.clear\(\)\s+\.\.add\(_PosLineDraft\(\)\)')
            .hasMatch(posSrc),
        isTrue,
        reason: 'submit success must reset _lines to one empty draft',
      );
    });
  });

  group('G-POS-MULTILINE-CLEANUP — Legacy VendorPaymentScreen cleanup (GAP-12)', () {
    test('test_legacy_vendor_payment_screen_archived', () {
      // The file must no longer exist under lib/screens/operations/.
      // It was moved to _archive/2026-05-11/ via git mv so blame +
      // history are preserved.
      final live =
          File('lib/screens/operations/vendor_payment_screen.dart');
      expect(live.existsSync(), isFalse,
          reason: 'live copy must be archived');
      final archived = File(
          '_archive/2026-05-11/legacy_vendor_payment_screen/vendor_payment_screen.dart');
      expect(archived.existsSync(), isTrue,
          reason: 'archive copy must exist for git history continuity');
    });

    test('test_router_no_longer_imports_or_routes_to_vendor_payment_screen', () {
      // The original import line should be commented out (kept as a
      // breadcrumb explaining the cleanup).
      expect(
        RegExp(r"^import '[^']*vendor_payment_screen\.dart';", multiLine: true)
            .hasMatch(routerSrc),
        isFalse,
        reason: 'router must not import the archived screen',
      );
      // The route registration must be gone — no live GoRoute should
      // reference VendorPaymentScreen.
      expect(
        RegExp(r'GoRoute\([^)]*VendorPaymentScreen', multiLine: true, dotAll: true)
            .hasMatch(routerSrc),
        isFalse,
        reason: 'router must not register VendorPaymentScreen',
      );
    });

    test('test_v5_chip_retargeted_to_purchase_bills_list', () {
      // The chip should still exist (V5 nav hubs may reference it)
      // but it must point at PurchaseInvoicesScreen — payments are now
      // recorded via VendorPaymentModal from the bill details page.
      expect(
        RegExp(r"'erp/purchasing/payment':\s*\(ctx\)\s*=>\s*const\s+PurchaseInvoicesScreen\(\)")
            .hasMatch(chipsSrc),
        isTrue,
        reason:
            "chip must point at PurchaseInvoicesScreen, not VendorPaymentScreen",
      );
    });
  });
}
