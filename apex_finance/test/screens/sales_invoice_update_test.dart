/// G-SALES-INVOICE-UPDATE + G-CUSTOMER-PAYMENT-NOTES — source-grep
/// regression contracts for:
///
///   1) The Edit-creates-duplicate bug: clicking Save on a prefilled
///      draft used to POST `/sales-invoices` and produce a second
///      INV-XXX. The fix is a new PATCH endpoint + a branch in
///      `_submit` / `_saveDraft` that calls it when prefilled.
///
///   2) The CustomerPayment notes-column asymmetry with VendorPayment:
///      customer modal used to merge notes into `reference` only.
///      The fix adds a `notes` column to the SQLAlchemy model, a
///      `notes` field on CustomerPaymentInput/Read, and threads it
///      end-to-end (modal → route → response → details rendering).
///
/// 10 contracts pinned across: backend route + schema + model, dart
/// api_service, create screen submit branch, customer payment modal
/// payload, payments-history rendering.
///
/// CRITICAL: this file uses `RegExp` (not literal `\n`) for any
/// multiline pattern — git-checkout on Windows converts to CRLF and
/// breaks naive substring matches. See
/// purchase_invoice_multiline_parity_test.dart:160 for the pattern.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String routesSrc;
  late String modelSrc;
  late String apiSrc;
  late String createSrc;
  late String modalSrc;
  late String detailsSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    routesSrc = read('../app/pilot/routes/customer_routes.py');
    modelSrc = read('../app/pilot/models/customer.py');
    apiSrc = read('lib/api_service.dart');
    createSrc =
        read('lib/screens/operations/sales_invoice_create_screen.dart');
    modalSrc = read('lib/screens/operations/customer_payment_modal.dart');
    detailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
  });

  group('G-SALES-INVOICE-UPDATE — Backend PATCH endpoint', () {
    test('test_backend_has_patch_route_for_sales_invoices', () {
      // Decorator + path must both be present. Use a regex so a
      // future linter that line-wraps the @router.patch(...) call
      // still passes.
      expect(
        RegExp(r'@router\.patch\(\s*"/sales-invoices/\{invoice_id\}"')
            .hasMatch(routesSrc),
        isTrue,
        reason: 'PATCH /sales-invoices/{invoice_id} must exist',
      );
    });

    test('test_patch_endpoint_refuses_non_draft_with_409', () {
      // 409 + a message explaining only-drafts-editable.
      expect(
        routesSrc.contains('status_code=409'),
        isTrue,
        reason: 'non-draft must 409',
      );
      expect(
        RegExp(r'only drafts editable').hasMatch(routesSrc),
        isTrue,
        reason: 'error detail must say only drafts editable',
      );
    });

    test('test_sales_invoice_update_schema_exists', () {
      // SalesInvoiceUpdate pydantic model — all optional. Use a
      // regex so attribute lines on either CRLF or LF still match.
      expect(
        RegExp(r'class\s+SalesInvoiceUpdate\(BaseModel\)').hasMatch(routesSrc),
        isTrue,
        reason: 'SalesInvoiceUpdate(BaseModel) must be defined',
      );
      expect(
        RegExp(r'lines:\s*Optional\[list\[SalesInvoiceLineInput\]\]')
            .hasMatch(routesSrc),
        isTrue,
        reason: 'lines must be Optional[list[SalesInvoiceLineInput]]',
      );
    });

    test('test_patch_endpoint_replaces_lines_and_recomputes_totals', () {
      // delete + insert pattern + recompute totals server-side.
      expect(
        RegExp(r'SalesInvoiceLine\.invoice_id\s*==\s*inv\.id').hasMatch(routesSrc),
        isTrue,
        reason: 'PATCH must filter SalesInvoiceLine by invoice id',
      );
      expect(
        routesSrc.contains('.delete(synchronize_session=False)'),
        isTrue,
        reason: 'PATCH must delete existing lines before re-inserting',
      );
      expect(
        RegExp(r'inv\.subtotal\s*=\s*subtotal').hasMatch(routesSrc),
        isTrue,
        reason: 'PATCH must recompute inv.subtotal server-side',
      );
    });
  });

  group('G-CUSTOMER-PAYMENT-NOTES — Backend schema + model', () {
    test('test_customer_payment_input_has_notes_optional_str', () {
      // Pydantic CustomerPaymentInput must expose a notes: Optional[str].
      final inputIdx = routesSrc.indexOf('class CustomerPaymentInput');
      expect(inputIdx, greaterThan(0),
          reason: 'CustomerPaymentInput class must exist');
      final block = routesSrc.substring(
          inputIdx, (inputIdx + 1500).clamp(0, routesSrc.length));
      expect(
        RegExp(r'notes:\s*Optional\[str\]\s*=\s*None').hasMatch(block),
        isTrue,
        reason:
            'CustomerPaymentInput must declare notes: Optional[str] = None',
      );
    });

    test('test_customer_payment_model_has_notes_column', () {
      // SQLAlchemy Column on CustomerPayment. Use `class CustomerPayment(`
      // (with the opening paren) so we don't accidentally match
      // `class CustomerPaymentTerms` which is defined earlier in the file.
      final modelIdx = modelSrc.indexOf('class CustomerPayment(Base)');
      expect(modelIdx, greaterThan(0),
          reason: 'class CustomerPayment(Base) must exist');
      final block = modelSrc.substring(
          modelIdx, (modelIdx + 2000).clamp(0, modelSrc.length));
      expect(
        RegExp(r'notes\s*=\s*Column\(String\(\d+\),\s*nullable=True\)')
            .hasMatch(block),
        isTrue,
        reason: 'CustomerPayment model must declare a notes Column',
      );
    });
  });

  group('G-SALES-INVOICE-UPDATE — Frontend api_service + submit branch', () {
    test('test_api_service_exposes_pilotUpdateSalesInvoice', () {
      // The new _patch wrapper for the Edit flow.
      expect(
        RegExp(
                r'pilotUpdateSalesInvoice\s*\(\s*\n?\s*String\s+invoiceId,\s*Map<String,\s*dynamic>\s+payload\s*\)')
            .hasMatch(apiSrc),
        isTrue,
        reason:
            'pilotUpdateSalesInvoice(String, Map) must exist in api_service',
      );
      expect(
        apiSrc.contains("_patch('/api/v1/pilot/sales-invoices/\$invoiceId'"),
        isTrue,
        reason: 'helper must route through _patch on the right path',
      );
    });

    test('test_submit_branches_to_patch_when_prefilled', () {
      // Locate _submit. Use a tolerant slice — 3000 chars covers the
      // full branched submit body without depending on line count.
      final idx = createSrc.indexOf('Future<void> _submit()');
      expect(idx, greaterThan(0), reason: '_submit() must exist');
      final end = (idx + 3500).clamp(0, createSrc.length);
      final body = createSrc.substring(idx, end);

      // 1. The branch on prefillInvoiceId.
      expect(
        RegExp(r'widget\.prefillInvoiceId').hasMatch(body),
        isTrue,
        reason: '_submit must read widget.prefillInvoiceId',
      );
      // 2. Calls PATCH helper on the prefilled path.
      expect(
        RegExp(r'ApiService\.pilotUpdateSalesInvoice\(').hasMatch(body),
        isTrue,
        reason: '_submit must call pilotUpdateSalesInvoice when prefilled',
      );
      // 3. POST path also still present (the non-prefilled branch).
      expect(
        RegExp(r'ApiService\.pilotCreateSalesInvoice\(').hasMatch(body),
        isTrue,
        reason: '_submit must still POST when prefillInvoiceId is null',
      );
      // 4. CRITICAL: no fallback from PATCH to POST — that fallback
      //    is the duplicate-create bug. After a PATCH failure, the
      //    flow must surface the error and return; it must not
      //    continue down to pilotCreateSalesInvoice.
      final patchIdx = body.indexOf('pilotUpdateSalesInvoice');
      final returnAfterPatch = body.indexOf('return', patchIdx);
      final createAfterPatch = body.indexOf('pilotCreateSalesInvoice', patchIdx);
      expect(
        returnAfterPatch > 0 && returnAfterPatch < createAfterPatch,
        isTrue,
        reason:
            'after a failed PATCH the flow must return, not fall through to POST',
      );
    });
  });

  group('G-CUSTOMER-PAYMENT-NOTES — Frontend modal + history', () {
    test('test_customer_modal_sends_notes_field_in_payload', () {
      // The new payload key — parity with vendor_payment_modal.dart:141.
      // Allow the conditional spread form so either ordering passes.
      expect(
        RegExp(r"if\s*\(notes\.isNotEmpty\)\s*'notes':\s*notes")
            .hasMatch(modalSrc),
        isTrue,
        reason:
            "customer modal must send 'notes': notes when notes is non-empty",
      );
      // The combinedReference field must NOT have been dropped — both
      // serve different audit purposes (merchant-visible vs internal).
      expect(
        RegExp(r"'reference':\s*combinedReference").hasMatch(modalSrc),
        isTrue,
        reason:
            "modal must keep 'reference': combinedReference — different audit field",
      );
    });

    test('test_details_renders_notes_when_non_empty', () {
      // _buildPayments must read p['notes'] and render it conditionally.
      final idx = detailsSrc.indexOf("Widget _buildPayments()");
      expect(idx, greaterThan(0));
      final end = (idx + 2500).clamp(0, detailsSrc.length);
      final body = detailsSrc.substring(idx, end);
      expect(
        RegExp(r"p\['notes'\]").hasMatch(body),
        isTrue,
        reason: '_buildPayments must read the notes field',
      );
      expect(
        RegExp(r"\(p\['notes'\]\s*\?\?\s*''\)\.toString\(\)\.isNotEmpty")
            .hasMatch(body),
        isTrue,
        reason: 'notes must render only when non-empty',
      );
    });
  });
}
