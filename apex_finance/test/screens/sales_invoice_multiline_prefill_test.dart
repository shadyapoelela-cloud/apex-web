/// G-SALES-INVOICE-MULTILINE-PREFILL — regression tests for the
/// multi-line invoice refactor, the `?invoice_id=` pre-fill flow,
/// the picker's debounced server-side search, the stock badge in
/// the dropdown, and the qty>stock warning on the line card.
///
/// Same source-grep approach as prior sprints — the create screen
/// transitively loads `package:web` which fails the SDK gate under
/// flutter_test (G-T1.1).
///
/// 11 contracts pinned.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String createSrc;
  late String pickerSrc;
  late String apiSrc;
  late String routerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    createSrc = read('lib/screens/operations/sales_invoice_create_screen.dart');
    pickerSrc = read('lib/widgets/forms/product_picker_or_create.dart');
    apiSrc = read('lib/api_service.dart');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-SALES-INVOICE-MULTILINE-PREFILL — Multi-line invoice', () {
    test('test_line_draft_class_exists_with_per_line_controllers', () {
      // Each line MUST own its 4 controllers (desc/qty/unitPrice/vatRate)
      // so the user can edit lines independently without one row
      // overwriting another.
      expect(createSrc.contains('class _LineDraft'), isTrue);
      const required = ['desc', 'qty', 'unitPrice', 'vatRate', 'product'];
      for (final f in required) {
        expect(createSrc.contains('  $f'), isTrue,
            reason: '_LineDraft must expose `$f`');
      }
    });

    test('test_lines_collection_starts_with_one_draft', () {
      // Initial state must be one empty line so the form is usable
      // immediately without clicking "+ بند".
      expect(createSrc.contains('final List<_LineDraft> _lines = [_LineDraft()]'),
          isTrue,
          reason: 'screen must initialise with exactly one empty line draft');
    });

    test('test_add_and_remove_line_methods_exist_with_guard', () {
      expect(createSrc.contains('void _addLine()'), isTrue);
      expect(createSrc.contains('void _removeLine(int index)'), isTrue);
      // Removing the last line must be impossible — otherwise the
      // form has no lines and the payload validator fails the user
      // with a confusing "add a line" message.
      expect(createSrc.contains('if (_lines.length <= 1) return;'),
          isTrue,
          reason: 'remove must guard against emptying the lines list');
    });

    test('test_payload_serialises_all_lines', () {
      expect(createSrc.contains('linesPayload.add({'), isTrue,
          reason: 'payload must loop over _lines and serialise each');
      expect(createSrc.contains("'lines': linesPayload"), isTrue);
      // Per-line totals are computed client-side AND sent unit_price
      // — the backend re-computes the line subtotal from those.
      expect(createSrc.contains("'quantity': l.quantityValue"), isTrue);
      expect(createSrc.contains("'unit_price': l.unitPriceValue"), isTrue);
      expect(createSrc.contains("'vat_rate': l.vatRateValue"), isTrue);
    });
  });

  group('G-SALES-INVOICE-MULTILINE-PREFILL — Edit pre-fill', () {
    test('test_prefill_invoice_id_param_exists_on_widget', () {
      // The screen takes prefillInvoiceId from the router; without
      // this hook, the Edit button on details can't deep-link in.
      expect(createSrc.contains('final String? prefillInvoiceId'), isTrue);
      expect(
        createSrc.contains('const SalesInvoiceCreateScreen({super.key, this.prefillInvoiceId})'),
        isTrue,
      );
    });

    test('test_router_passes_query_param_to_screen', () {
      expect(
        routerSrc.contains("'/app/erp/sales/invoice-create'"),
        isTrue,
        reason: 'router must declare the explicit GoRoute for the '
            'create screen so query params reach the widget',
      );
      expect(
        routerSrc.contains("s.uri.queryParameters['invoice_id']"),
        isTrue,
        reason: 'route must read invoice_id from query params',
      );
    });

    test('test_prefill_locks_form_on_non_draft', () {
      // Editing a posted invoice mid-flight would diverge from the
      // ledger. The screen must lock itself + show a banner directing
      // the user back to details.
      expect(createSrc.contains('_editLocked = !isDraft'), isTrue,
          reason: 'edit must lock when invoice is not draft');
      expect(createSrc.contains('_readOnlyBanner()'), isTrue);
      expect(createSrc.contains('AbsorbPointer'), isTrue,
          reason: 'inputs must be wrapped in AbsorbPointer when locked');
    });
  });

  group('G-SALES-INVOICE-MULTILINE-PREFILL — Picker server search', () {
    test('test_api_service_pilotListProducts_accepts_q', () {
      expect(
        apiSrc.contains('pilotListProducts(String tenantId, {int limit=100, String? q})'),
        isTrue,
        reason: 'pilotListProducts must accept `q` for server search',
      );
      expect(apiSrc.contains("'q=\${Uri.encodeQueryComponent(q.trim())}'"),
          isTrue,
          reason: 'query param must be URL-encoded');
    });

    test('test_picker_debounces_300ms_with_seq_token', () {
      // Each keystroke schedules a 300ms timer; if another keystroke
      // arrives, the older request must be cancelled by sequence-
      // number comparison.
      expect(pickerSrc.contains('Duration(milliseconds: 300)'), isTrue,
          reason: 'must use 300ms debounce window');
      expect(pickerSrc.contains('++_searchSeq'), isTrue,
          reason: 'must use a sequence token to cancel stale fetches');
      expect(pickerSrc.contains('mySeq != _searchSeq'), isTrue,
          reason: 'must abort when token changed mid-fetch');
    });
  });

  group('G-SALES-INVOICE-MULTILINE-PREFILL — Stock badge + warning', () {
    test('test_stock_badge_color_logic_present', () {
      // Green = in stock, red = out, grey = service. All three must
      // be reachable so the dropdown is informative.
      expect(pickerSrc.contains('stockable = p[\'is_stockable\'] != false'),
          isTrue);
      expect(pickerSrc.contains("'خدمة'"), isTrue,
          reason: 'service label must appear in stock badge logic');
      expect(pickerSrc.contains("'نفد'"), isTrue,
          reason: 'out-of-stock label must appear');
      expect(pickerSrc.contains('متوفر'), isTrue,
          reason: 'in-stock label must appear');
    });

    test('test_qty_over_stock_warning_helper', () {
      expect(createSrc.contains('String? _stockWarning('), isTrue);
      expect(
        createSrc.contains("if (p['is_stockable'] == false) return null;"),
        isTrue,
        reason: 'service products must skip the warning',
      );
      expect(createSrc.contains('تتجاوز المخزون المتوفر'), isTrue);
    });

    test('test_stock_warning_is_non_blocking', () {
      // The warning is informational only — the user can still
      // submit. Backend enforces negative-stock policy.
      expect(createSrc.contains('Icons.warning_amber_rounded'), isTrue);
      // Submit button must NOT check _stockWarning — pin that.
      final submitIdx = createSrc.indexOf('Future<void> _submit()');
      expect(submitIdx, greaterThan(0));
      final end = (submitIdx + 1500).clamp(0, createSrc.length);
      final body = createSrc.substring(submitIdx, end);
      expect(body.contains('_stockWarning'), isFalse,
          reason: '_submit must not gate on stock — backend is the SOT');
    });
  });
}
