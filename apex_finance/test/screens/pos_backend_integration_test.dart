/// G-POS-BACKEND-INTEGRATION (2026-05-11): regression tests for the
/// architectural fix that swaps POS Quick Sale from the wrong
/// sales-invoice flow over to the dedicated POS endpoints.
///
/// Pre-fix behavior (QA-reported):
///   • Double JE per sale (sales-invoice JE + customer-payment JE)
///   • No stock deduction (sales-invoice path skips StockMovement)
///   • Empty Z-Report (POS Quick Sale never hit pos_routes)
///   • No session lock (cashiers could sell without an open shift)
///   • ZATCA QR on a B2B sales-invoice instead of the B2C POS
///     simplified-tax invoice
///
/// Post-fix contract:
///   • `_submit` calls /pilot/pos-transactions (NOT /sales-invoices)
///   • `_submit` resolves an open POS session first (open one on
///     the fly via pilotCreatePosSession when none is open)
///   • After create, `_submit` calls /pos-transactions/{id}/post-to-gl
///     so the cashier sees the JE link immediately
///   • Receipt card displays `receipt_number` (RCT-…), not
///     `invoice_number` (INV-…)
///   • api_service.dart exposes the 3 slim wrappers
///   • Pre-existing contracts (ZATCA QR — PR #192, multi-line —
///     PR #193) remain intact
///
/// Source-grep approach mirrors prior sprints because the screens
/// transitively load `package:web` which fails the SDK gate under
/// flutter_test (G-T1.1).
///
/// CRITICAL: every multi-line assertion uses RegExp (NOT literal `\n`)
/// so the test passes on both LF and CRLF checkouts. See
/// purchase_invoice_multiline_parity_test.dart:160 for the precedent.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String posSrc;
  late String apiSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    posSrc = read('lib/screens/operations/pos_quick_sale_screen.dart');
    apiSrc = read('lib/api_service.dart');
  });

  group('G-POS-BACKEND-INTEGRATION — api_service wrappers', () {
    test('test_api_service_exposes_pilotCreatePosTransaction', () {
      // POST /pilot/pos-transactions — dedicated POS create endpoint.
      // This is the keystone fix: every call must route here instead
      // of /sales-invoices.
      expect(
        RegExp(
                r"pilotCreatePosTransaction\([^)]*\)\s*=>\s*_post\(\s*'/pilot/pos-transactions'")
            .hasMatch(apiSrc),
        isTrue,
        reason:
            'api_service must expose pilotCreatePosTransaction → POST /pilot/pos-transactions',
      );
    });

    test('test_api_service_exposes_pilotPostPosTransactionToGl', () {
      // POST /pilot/pos-transactions/{id}/post-to-gl — auto-posts a
      // single-leg POS JE (DR Cash / CR Revenue / CR VAT).
      expect(
        RegExp(
                r"pilotPostPosTransactionToGl\([^)]*\)\s*=>\s*_post\(\s*'/pilot/pos-transactions/\$posTxnId/post-to-gl'")
            .hasMatch(apiSrc),
        isTrue,
        reason:
            'api_service must expose pilotPostPosTransactionToGl → POST .../{id}/post-to-gl',
      );
    });

    test('test_api_service_exposes_pilotListOpenPosSessions', () {
      // GET /pilot/branches/{bid}/pos-sessions?status=open&limit=1 —
      // POS rule is at most one open session per (branch, station).
      // Filter at the API layer so the screen doesn't have to.
      expect(
        RegExp(
                r"pilotListOpenPosSessions\([^)]*\)\s*=>\s*_get\(\s*'/pilot/branches/\$branchId/pos-sessions\?status=open&limit=1'")
            .hasMatch(apiSrc),
        isTrue,
        reason:
            'api_service must expose pilotListOpenPosSessions filtered to status=open',
      );
    });
  });

  group('G-POS-BACKEND-INTEGRATION — POS Quick Sale screen', () {
    test('test_submit_calls_pos_transactions_not_sales_invoices', () {
      // The keystone behavioral fix. Pre-fix the screen called
      // pilotCreateSalesInvoice + pilotIssueSalesInvoice which
      // produced TWO journal entries per sale, skipped stock
      // deduction, and left ZATCA QR on a B2B invoice. Post-fix it
      // must call pilotCreatePosTransaction directly.
      expect(
        posSrc.contains('ApiService.pilotCreatePosTransaction('),
        isTrue,
        reason:
            'POS Quick Sale must call pilotCreatePosTransaction (the dedicated POS endpoint)',
      );
      // And the old sales-invoice wrappers must be gone from this
      // screen (other screens may still legitimately use them).
      expect(
        posSrc.contains('pilotCreateSalesInvoice('),
        isFalse,
        reason:
            'POS Quick Sale must NOT call pilotCreateSalesInvoice (caused double-JE bug)',
      );
      expect(
        posSrc.contains('pilotIssueSalesInvoice('),
        isFalse,
        reason:
            'POS Quick Sale must NOT call pilotIssueSalesInvoice (sales-invoice flow)',
      );
    });

    test('test_submit_ensures_open_session_before_creating', () {
      // POS endpoint requires session_id and locks against open
      // sessions only. The screen must resolve / open a session
      // first.
      expect(
        posSrc.contains('_ensureOpenSession'),
        isTrue,
        reason:
            'POS Quick Sale must expose a session-ensuring helper',
      );
      expect(
        posSrc.contains('ApiService.pilotListOpenPosSessions('),
        isTrue,
        reason: 'POS Quick Sale must check for an open session first',
      );
      expect(
        posSrc.contains('ApiService.pilotCreatePosSession('),
        isTrue,
        reason:
            'POS Quick Sale must open a fresh session when none is open',
      );
      // session_id must end up in the payload — POS Quick Sale used
      // to ship customer_id; the new POS payload uses session_id.
      expect(
        RegExp(r"'session_id'\s*:\s*sessionId").hasMatch(posSrc),
        isTrue,
        reason:
            'POS create payload must include session_id from the resolved session',
      );
    });

    test('test_submit_posts_to_gl_after_creating', () {
      // Single-JE flow: create POS txn → post-to-gl. The screen must
      // chain both calls so the cashier sees the JE link in the
      // receipt card without a second action.
      expect(
        posSrc.contains('ApiService.pilotPostPosTransactionToGl('),
        isTrue,
        reason:
            'POS Quick Sale must auto-post the POS receipt to GL after create',
      );
      // The chain order matters — post must come after create. A
      // crude proxy is the create call appearing before the post call.
      final createIdx =
          posSrc.indexOf('ApiService.pilotCreatePosTransaction(');
      final postIdx =
          posSrc.indexOf('ApiService.pilotPostPosTransactionToGl(');
      expect(createIdx, greaterThan(0));
      expect(postIdx, greaterThan(createIdx),
          reason: 'post-to-gl must be invoked AFTER create');
    });

    test('test_payload_uses_pos_schema_keys', () {
      // PosLineInput in app/pilot/schemas/pos.py expects
      // variant_id + qty (not product_id + quantity). The price is
      // passed as unit_price_override so the route bypasses the
      // price-list lookup.
      expect(
        posSrc.contains("'variant_id': l.product!['default_variant_id']"),
        isTrue,
        reason:
            'POS line payload must use variant_id (PosLineInput contract)',
      );
      expect(
        RegExp(r"'qty'\s*:\s*l\.quantityValue").hasMatch(posSrc),
        isTrue,
        reason: 'POS line payload must use qty (not quantity)',
      );
      expect(
        RegExp(r"'unit_price_override'\s*:\s*l\.unitPriceValue")
            .hasMatch(posSrc),
        isTrue,
        reason:
            'POS line payload must pass unit_price_override (skip price-list lookup)',
      );
      // payments array is mandatory (min_length=1 on the schema).
      expect(
        RegExp(r"'payments'\s*:\s*\[").hasMatch(posSrc),
        isTrue,
        reason:
            'POS create payload must include payments (PosTransactionCreate min_length=1)',
      );
    });

    test('test_payment_method_mapping_matches_schema', () {
      // PosPaymentInput.method pattern allows
      //   cash|mada|visa|mastercard|amex|stc_pay|apple_pay|...
      // The UI's ApexPaymentMethod enum names (camelCase) don't
      // match — the screen needs a translator. Spot-check the
      // most common Saudi-payment values.
      expect(posSrc.contains("=> 'mada'"), isTrue,
          reason: 'mada is a canonical PosPayment method');
      expect(posSrc.contains("=> 'stc_pay'"), isTrue,
          reason: 'stc_pay is canonical (NOT stcPay)');
      expect(posSrc.contains("=> 'apple_pay'"), isTrue,
          reason: 'apple_pay is canonical (NOT applePay)');
      expect(posSrc.contains("=> 'cash'"), isTrue);
    });

    test('test_receipt_card_uses_receipt_number_not_invoice_number', () {
      // POS receipts have receipt_number (e.g. RCT-001234), NOT
      // invoice_number (INV-2026-XXXX). The receipt card must
      // surface the new identifier.
      expect(
        posSrc.contains("r['receipt_number']"),
        isTrue,
        reason:
            'Receipt card must display receipt_number from the POS response',
      );
      // The captured map saves it under receipt_number too.
      expect(
        RegExp(r"'receipt_number'\s*:\s*receiptNumber").hasMatch(posSrc),
        isTrue,
        reason:
            "Captured receipt map must store 'receipt_number' (not 'invoice_number')",
      );
    });

    test('test_je_link_still_uses_post_response_id', () {
      // The JE chip / link must still route to /je-builder/{jeId}
      // — the difference is the JE id now comes from the
      // post-to-gl response (not the sales-invoice issue response).
      expect(
        posSrc.contains("/app/erp/finance/je-builder/\${r['je_id']}"),
        isTrue,
        reason: 'JE link must still navigate to the je-builder',
      );
      // jeId is captured from the post-to-gl response.
      expect(
        RegExp(r"jeId\s*=\s*\(post\.data\s+as\s+Map\?\)\?\['id'\]")
            .hasMatch(posSrc),
        isTrue,
        reason:
            'JE id must be captured from the post-to-gl response (JournalEntryDetail.id)',
      );
    });
  });

  group('G-POS-BACKEND-INTEGRATION — preserved prior contracts', () {
    test('test_pr192_zatca_qr_still_rendered_on_receipt', () {
      // PR #192 (G-POS-ZATCA-QR) added a Phase-1 TLV QR to the
      // receipt card. Even though the source document is now a POS
      // simplified-tax invoice (which is actually the CORRECT
      // document type for B2C), the QR rendering must remain.
      expect(
        posSrc.contains("import '../../core/zatca_tlv.dart'"),
        isTrue,
        reason: 'ZATCA TLV helper import must remain',
      );
      expect(
        posSrc.contains('zatcaQrBase64('),
        isTrue,
        reason: 'zatcaQrBase64 call must remain on the receipt card',
      );
      expect(
        posSrc.contains('QrImageView('),
        isTrue,
        reason: 'QR image widget must remain on the receipt card',
      );
      // Seller VAT placeholder still wired so the QR has all 5 TLV
      // fields (a malformed TLV would render no QR).
      expect(
        posSrc.contains("'seller_vat_number': '300000000000003'"),
        isTrue,
        reason: 'Seller VAT placeholder must remain for TLV completeness',
      );
    });

    test('test_pr193_multiline_per_line_drafts_still_intact', () {
      // PR #193 (G-POS-MULTILINE-CLEANUP) introduced _PosLineDraft +
      // a list-of-lines model so cashiers can ring up multiple SKUs
      // per sale. The architecture must survive the backend refactor.
      expect(posSrc.contains('class _PosLineDraft'), isTrue);
      expect(
        posSrc.contains(
            'final List<_PosLineDraft> _lines = [_PosLineDraft()]'),
        isTrue,
        reason: 'multi-line list-of-drafts model must be preserved',
      );
      expect(posSrc.contains('void _addLine()'), isTrue);
      expect(posSrc.contains('void _removeLine(int index)'), isTrue);
      // CRLF-safe reset assertion — use a regex over flexible
      // whitespace rather than a literal `\n` block. This is the
      // pattern from GAP-11 (purchase_invoice_multiline_parity_test
      // :160) that previously bit the team on Windows checkouts.
      expect(
        RegExp(r'_lines\s*\.\.clear\(\)\s*\.\.add\(_PosLineDraft\(\)\)')
            .hasMatch(posSrc),
        isTrue,
        reason:
            'submit success must reset _lines to one empty draft (CRLF-safe match)',
      );
    });
  });
}
