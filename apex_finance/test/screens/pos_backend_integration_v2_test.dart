/// G-POS-BACKEND-INTEGRATION-V2 — source-grep regression tests for
/// the do-over of PR #196.
///
/// PR #196 was rejected because it forced `variant_id` as REQUIRED on
/// every PosLineInput, which broke ad-hoc cash sales (services,
/// custom items, quick rings without a barcode). This rewrite
/// introduces a SOFT discriminator (`is_misc`) so misc lines work
/// end-to-end while catalogued SKUs still flow through the normal
/// variant / price-lookup / StockMovement path.
///
/// 15 contracts pinned. Source-grep (read files as strings + assert
/// substrings) — same gate as the prior POS sprints, because the POS
/// screen transitively imports `package:web` which fails the SDK gate
/// under `flutter_test` (G-T1.1).
///
/// Files under test:
///   * app/pilot/schemas/pos.py            ← PosLineInput soft variant
///   * app/pilot/models/pos.py             ← PosTransactionLine.is_misc
///   * apex_finance/lib/api_service.dart   ← new POS endpoint methods
///   * apex_finance/lib/screens/operations/pos_quick_sale_screen.dart
///     ← _submit refactored to call /pos-transactions (NOT
///       /sales-invoices) + ensure-session + chain post-to-gl
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String schemaSrc;
  late String modelSrc;
  late String apiSrc;
  late String posSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    // The flutter test runs from `apex_finance/`, so paths reaching
    // back into the Python backend climb out two levels.
    schemaSrc = read('../app/pilot/schemas/pos.py');
    modelSrc = read('../app/pilot/models/pos.py');
    apiSrc = read('lib/api_service.dart');
    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
  });

  group('G-POS-BACKEND-INTEGRATION-V2 — Backend schema (soft variant_id)', () {
    test('test_backend_PosLineInput_variant_id_is_optional', () {
      // The previous shape `variant_id: str` (required) is what made
      // PR #196 break ad-hoc cash sales. The new shape MUST mark it
      // Optional so misc lines parse without it.
      expect(
        RegExp(r'class\s+PosLineInput\b[\s\S]*?variant_id\s*:\s*Optional\[str\]')
            .hasMatch(schemaSrc),
        isTrue,
        reason: 'PosLineInput.variant_id must be Optional[str]',
      );
    });

    test('test_backend_PosLineInput_has_is_misc_bool_field', () {
      // `is_misc` is the discriminator that branches catalogued vs
      // ad-hoc. Default False so existing callers (catalogued SKU
      // flows) keep working without changes.
      expect(
        RegExp(r'class\s+PosLineInput\b[\s\S]*?is_misc\s*:\s*bool')
            .hasMatch(schemaSrc),
        isTrue,
        reason: 'PosLineInput must declare `is_misc: bool` field',
      );
    });

    test('test_backend_PosLineInput_validator_requires_variant_when_not_misc', () {
      // The pydantic `model_validator` MUST enforce variant_id
      // presence when is_misc is False. Pin both the validator
      // decorator and the branch.
      expect(schemaSrc.contains('@model_validator'), isTrue,
          reason: 'a pydantic model_validator must exist');
      expect(
        RegExp(r'if\s+not\s+self\.is_misc[\s\S]{0,200}?variant_id')
            .hasMatch(schemaSrc),
        isTrue,
        reason: 'validator must require variant_id when !is_misc',
      );
    });

    test('test_backend_PosLineInput_validator_requires_description_and_price_when_misc', () {
      // Misc lines have no variant ⇒ no price-lookup is possible. The
      // validator MUST refuse the request without description AND
      // unit_price_override so the cashier gets a clear 422 instead of
      // a phantom $0 line.
      expect(
        RegExp(r'self\.is_misc[\s\S]{0,400}?description[\s\S]{0,400}?unit_price_override')
            .hasMatch(schemaSrc),
        isTrue,
        reason:
            'validator must require both description and unit_price_override when is_misc=True',
      );
    });

    test('test_backend_PosTransactionLine_model_has_is_misc_column', () {
      // The SQLAlchemy model needs the column too so misc lines can
      // be persisted + queried.
      expect(modelSrc.contains('is_misc'), isTrue,
          reason: 'PosTransactionLine model must declare is_misc');
      expect(
        RegExp(r'is_misc\s*=\s*Column\(\s*Boolean').hasMatch(modelSrc),
        isTrue,
        reason: 'is_misc must be a Boolean column',
      );
      // variant_id is the FK that previously was NOT NULL. Now it must
      // be nullable so misc rows can omit it.
      expect(
        RegExp(r'variant_id\s*=\s*Column[\s\S]{0,400}?nullable\s*=\s*True')
            .hasMatch(modelSrc),
        isTrue,
        reason: 'PosTransactionLine.variant_id column must be nullable',
      );
    });
  });

  group('G-POS-BACKEND-INTEGRATION-V2 — Frontend api_service', () {
    test('test_api_service_pilotCreatePosTransaction_added', () {
      // The new V2 entry point. POST /pilot/pos-transactions —
      // returns the receipt + JE + lines/payments in one call.
      expect(apiSrc.contains('pilotCreatePosTransaction'), isTrue,
          reason: 'api_service must declare pilotCreatePosTransaction');
      expect(
        RegExp(r"pilotCreatePosTransaction[\s\S]{0,200}?'/pilot/pos-transactions'")
            .hasMatch(apiSrc),
        isTrue,
        reason: "method must POST to '/pilot/pos-transactions'",
      );
    });

    test('test_api_service_pilotPostPosTransactionToGl_added', () {
      // Chains JE auto-post. Route lives in gl_routes.py under the
      // same /pilot prefix.
      expect(apiSrc.contains('pilotPostPosTransactionToGl'), isTrue,
          reason: 'api_service must declare pilotPostPosTransactionToGl');
      expect(
        RegExp(r"pilotPostPosTransactionToGl[\s\S]{0,300}?'/pilot/pos-transactions/[^']+/post-to-gl'")
            .hasMatch(apiSrc),
        isTrue,
        reason: "method must POST to '/pilot/pos-transactions/{id}/post-to-gl'",
      );
    });

    test('test_api_service_pilotListOpenPosSessions_filters_status_open', () {
      // Pre-submit hook: find the cashier's open shift. status=open
      // filter MUST be in the URL or backend returns mixed-status
      // results.
      expect(apiSrc.contains('pilotListOpenPosSessions'), isTrue,
          reason: 'api_service must declare pilotListOpenPosSessions');
      expect(
        RegExp(r"pilotListOpenPosSessions[\s\S]{0,300}?status=open")
            .hasMatch(apiSrc),
        isTrue,
        reason: 'must include status=open in the query string',
      );
    });
  });

  group('G-POS-BACKEND-INTEGRATION-V2 — POS Quick Sale rewire', () {
    test('test_submit_calls_pos_transactions_endpoint_not_sales_invoices', () {
      // THE CORE ASSERTION. PR #196's predecessor flow routed POS
      // through `pilotCreateSalesInvoice` (B2B sales-invoice). The
      // new flow MUST call `pilotCreatePosTransaction` instead.
      expect(posSrc.contains('pilotCreatePosTransaction'), isTrue,
          reason: 'POS submit must call pilotCreatePosTransaction');
      // The OLD calls must be gone — otherwise we'd double-post.
      expect(posSrc.contains('pilotCreateSalesInvoice('), isFalse,
          reason:
              'POS submit must NOT call the B2B pilotCreateSalesInvoice anymore');
      expect(posSrc.contains('pilotIssueSalesInvoice('), isFalse,
          reason:
              'POS submit must NOT call the B2B pilotIssueSalesInvoice anymore');
    });

    test('test_submit_ensures_open_session_before_submitting', () {
      // Pre-submit hook so the POS sale attaches to a session and
      // shows up on the Z-report. Without this, every POS sale would
      // be orphaned (the bug the V2 PR is fixing).
      expect(posSrc.contains('pilotListOpenPosSessions'), isTrue,
          reason: 'submit must list open sessions for the branch');
      expect(posSrc.contains('pilotCreatePosSession'), isTrue,
          reason: 'submit must open a new session if none is open');
    });

    test('test_submit_chains_post_to_gl_after_create', () {
      // The single-JE guarantee. After create, the frontend MUST hit
      // post-to-gl so the JE is posted even if the backend's auto-post
      // is gated off in some env.
      expect(posSrc.contains('pilotPostPosTransactionToGl'), isTrue,
          reason: 'submit must chain pilotPostPosTransactionToGl');
    });

    test('test_receipt_displays_receipt_number_not_invoice_number', () {
      // B2C receipts use RCT-… not INV-…. Pin both the key in the
      // receipt map and the Arabic label change ("إيصال" not "فاتورة").
      expect(posSrc.contains("'receipt_number'"), isTrue,
          reason: '_lastReceipt must carry the receipt_number key');
      // Hotfix: use RegExp so CRLF/LF line endings don't break the
      // match (same root cause as GAP-11 in PR #193).
      expect(
        RegExp(r"إيصال\s*#").hasMatch(posSrc),
        isTrue,
        reason: 'receipt card must label the document as "إيصال" not "فاتورة"',
      );
    });

    test('test_misc_line_payload_when_no_product_selected', () {
      // The ad-hoc cash-sale path. When the cashier doesn't pick a
      // product, the line MUST be sent with is_misc=true, description,
      // unit_price_override.
      expect(
        RegExp(r"'is_misc'\s*:\s*true", multiLine: true).hasMatch(posSrc),
        isTrue,
        reason: 'misc-line branch must send is_misc: true',
      );
      expect(posSrc.contains("'description'"), isTrue,
          reason: 'misc-line branch must include description');
      expect(posSrc.contains("'unit_price_override'"), isTrue,
          reason:
              'misc-line branch must include unit_price_override (required by validator)');
    });

    test('test_variant_line_payload_when_product_selected', () {
      // The catalogued-SKU path. When the cashier picks a product
      // with a default_variant_id, send variant_id + is_misc=false so
      // the backend runs price-lookup + StockMovement.
      expect(posSrc.contains("'variant_id'"), isTrue,
          reason: 'variant-line branch must include variant_id');
      expect(
        RegExp(r"'is_misc'\s*:\s*false", multiLine: true).hasMatch(posSrc),
        isTrue,
        reason: 'variant-line branch must send is_misc: false',
      );
      // The discriminator is the presence of `default_variant_id` on
      // the picked product — pin the branch.
      expect(posSrc.contains("default_variant_id"), isTrue,
          reason:
              'submit must branch on product.default_variant_id to decide catalogued vs misc');
    });

    test('test_zatca_qr_still_rendered_after_refactor', () {
      // Preserve PR #192 — ZATCA Phase-1 QR was wired into the receipt
      // card. The V2 refactor MUST keep that intact.
      expect(posSrc.contains('zatcaQrBase64'), isTrue,
          reason: 'ZATCA QR helper must still be called');
      expect(posSrc.contains('QrImageView'), isTrue,
          reason: 'QR widget must still be rendered');
      // All 5 Phase-1 tags must still be passed.
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

    test('test_multi_line_preserved_after_refactor', () {
      // Preserve PR #193 — POS went from single-line to multi-line
      // with `_PosLineDraft` + ProductPickerOrCreate per line. The V2
      // refactor MUST keep that intact.
      expect(posSrc.contains('class _PosLineDraft'), isTrue,
          reason: 'multi-line draft class must remain');
      expect(
        posSrc.contains(
            'final List<_PosLineDraft> _lines = [_PosLineDraft()]'),
        isTrue,
        reason: 'must initialise with exactly one empty line draft',
      );
      // Reset-after-submit pattern (Windows CRLF safety via RegExp).
      expect(
        RegExp(r'_lines\s+\.\.clear\(\)\s+\.\.add\(_PosLineDraft\(\)\)')
            .hasMatch(posSrc),
        isTrue,
        reason: 'submit success must reset _lines to one empty draft',
      );
    });
  });
}
