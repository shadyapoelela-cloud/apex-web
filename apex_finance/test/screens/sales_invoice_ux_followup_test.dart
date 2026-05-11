/// G-SALES-INVOICE-UX-FOLLOWUP — regression tests for the 2 bugs +
/// 4 spec gaps closed in this PR.
///
/// Same source-grep approach as prior sprints (screens transitively
/// load package:web which fails the SDK gate under flutter_test).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String detailsSrc;
  late String createSrc;
  late String modalSrc;
  late String apiSrc;
  late String backendSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    detailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
    createSrc = read('lib/screens/operations/sales_invoice_create_screen.dart');
    modalSrc = read('lib/screens/operations/customer_payment_modal.dart');
    apiSrc = read('lib/api_service.dart');
    backendSrc =
        read('../app/pilot/routes/customer_routes.py');
  });

  group('G-SALES-INVOICE-UX-FOLLOWUP — Bug A: details screen scroll', () {
    test('test_details_uses_explicit_scroll_controller', () {
      // Pre-fix the SingleChildScrollView attached to the parent's
      // PrimaryScrollController and silently lost wheel events.
      // Post-fix: explicit ScrollController + Scrollbar wrapping +
      // PrimaryScrollController.none isolates it from the shell.
      expect(detailsSrc.contains('final ScrollController _scrollCtrl'),
          isTrue,
          reason: 'must declare own ScrollController');
      expect(detailsSrc.contains('PrimaryScrollController.none'), isTrue,
          reason: 'must detach from parent PrimaryScrollController');
      expect(detailsSrc.contains('AlwaysScrollableScrollPhysics'), isTrue,
          reason: 'must pin always-scrollable physics');
      expect(
        RegExp(r'Scrollbar\(').hasMatch(detailsSrc),
        isTrue,
        reason: 'must show a visible Scrollbar',
      );
      expect(detailsSrc.contains('thumbVisibility: true'), isTrue,
          reason: 'scrollbar thumb must always be visible');
    });

    test('test_scroll_controller_disposed', () {
      // Forgetting to dispose leaks the listener across navigation.
      expect(detailsSrc.contains('_scrollCtrl.dispose()'), isTrue,
          reason: 'scroll controller must be disposed in dispose()');
    });
  });

  group('G-SALES-INVOICE-UX-FOLLOWUP — Bug B: picker unit_price', () {
    test('test_on_product_selected_is_async_and_fetches_detail', () {
      // The list endpoint returns ProductRead without variants, so
      // the handler must fall back to pilotGetProduct for unit_price.
      expect(
        createSrc.contains('Future<void> _onProductSelected'),
        isTrue,
        reason: 'handler signature must be async to allow the '
            '/pilot/products/{id} fallback call',
      );
      expect(createSrc.contains('ApiService.pilotGetProduct'), isTrue,
          reason: 'must call pilotGetProduct as fallback for list_price');
    });

    test('test_inline_variants_used_first_when_present', () {
      // When the inline ProductCreateModal returns ProductDetail with
      // variants attached, the handler must NOT re-fetch — that's
      // a wasted round-trip.
      final idx = createSrc.indexOf('Future<void> _onProductSelected');
      expect(idx, greaterThan(0));
      final body = createSrc.substring(
        idx,
        (idx + 2500).clamp(0, createSrc.length),
      );
      // The inline-variants path must come BEFORE the fetch fallback.
      final inlineIdx = body.indexOf('inlineVariants.isNotEmpty');
      final fetchIdx = body.indexOf('pilotGetProduct');
      expect(inlineIdx, greaterThan(0));
      expect(fetchIdx, greaterThan(inlineIdx),
          reason: 'inline-variant branch must short-circuit before '
              'the fallback fetch — otherwise the modal-create flow '
              'pays for an extra request it does not need');
    });
  });

  group('G-SALES-INVOICE-UX-FOLLOWUP — Cancel action', () {
    test('test_backend_cancel_endpoint_exists', () {
      expect(
        backendSrc.contains('/sales-invoices/{invoice_id}/cancel'),
        isTrue,
        reason: 'backend must declare the cancel endpoint',
      );
      expect(backendSrc.contains('def cancel_sales_invoice('), isTrue);
      expect(backendSrc.contains('reverse_journal_entry'), isTrue,
          reason: 'cancel must reverse the posted JE when present');
      expect(
        backendSrc.contains('cannot cancel: invoice has applied payments'),
        isTrue,
        reason: 'cancel must refuse when paid_amount > 0',
      );
    });

    test('test_api_service_has_cancel_method', () {
      expect(apiSrc.contains('pilotCancelSalesInvoice'), isTrue);
      expect(
        apiSrc.contains('/api/v1/pilot/sales-invoices/\$id/cancel'),
        isTrue,
      );
    });

    test('test_details_screen_has_cancel_button_with_confirmation', () {
      expect(detailsSrc.contains('Future<void> _cancel('), isTrue);
      // Confirmation dialog is non-negotiable for a destructive action.
      expect(detailsSrc.contains('إلغاء الفاتورة؟'), isTrue,
          reason: 'cancel must show a confirmation dialog');
      expect(detailsSrc.contains('pilotCancelSalesInvoice'), isTrue);
      // Cancel button must be gated on no-payments + not-already-cancelled.
      expect(detailsSrc.contains('canCancel = !isCancelled && !isPaid'),
          isTrue,
          reason: 'cancel must be gated client-side too');
    });
  });

  group('G-SALES-INVOICE-UX-FOLLOWUP — Edit + Print actions', () {
    test('test_edit_button_only_for_draft', () {
      // Edit on a non-draft invoice is meaningless (the JE is posted
      // — edits would diverge from the ledger). Pin the gate.
      final actionsIdx = detailsSrc.indexOf('Widget _buildActions(');
      expect(actionsIdx, greaterThan(0));
      final end = (actionsIdx + 6000).clamp(0, detailsSrc.length);
      final body = detailsSrc.substring(actionsIdx, end);
      // The Edit button must appear inside `if (isDraft)`.
      final editIdx = body.indexOf('Icons.edit_outlined');
      expect(editIdx, greaterThan(0), reason: 'edit button must exist');
      // Find the nearest preceding `if (isDraft)` block.
      final beforeEdit = body.substring(0, editIdx);
      final lastIf = beforeEdit.lastIndexOf('if (');
      final guard = beforeEdit.substring(lastIf, lastIf + 30);
      expect(guard.contains('isDraft'), isTrue,
          reason: 'Edit button must be inside an isDraft guard');
    });

    test('test_print_button_uses_kIsWeb_guard', () {
      expect(detailsSrc.contains('kIsWeb'), isTrue,
          reason: 'print path must guard with kIsWeb');
      // G-CLEANUP-FINAL (2026-05-11): direct `html.window.print()` was
      // replaced by `triggerBrowserPrint()` from the conditional-import
      // helper at `core/browser_print.dart` / `core/browser_print_web.dart`.
      // The web implementation is what actually calls `html.window.print()`.
      expect(detailsSrc.contains('triggerBrowserPrint()'), isTrue,
          reason: 'print must call the conditional triggerBrowserPrint() helper');
      // Print button label
      expect(detailsSrc.contains('طباعة'), isTrue);
    });
  });

  group('G-SALES-INVOICE-UX-FOLLOWUP — Payment modal extra fields', () {
    test('test_notes_field_always_visible', () {
      expect(modalSrc.contains("_field('ملاحظات', _notes"), isTrue,
          reason: 'notes field must always be present');
      // notes controller must be disposed.
      expect(modalSrc.contains('_notes.dispose()'), isTrue);
    });

    test('test_bank_account_field_conditional_on_bank_transfer', () {
      expect(modalSrc.contains("_method == 'bank_transfer'"), isTrue,
          reason: 'bank_account field gated on method=bank_transfer');
      expect(modalSrc.contains('الحساب البنكي المستلِم'), isTrue);
      expect(modalSrc.contains('_bankAccount.dispose()'), isTrue);
    });

    test('test_payload_merges_notes_and_bank_into_reference', () {
      // The CustomerPayment model has no separate `notes` column on
      // the wire — we merge them into `reference` so the JE memo and
      // AR ledger capture the full context.
      expect(modalSrc.contains('combinedReference'), isTrue);
      expect(modalSrc.contains("'بنك: \$bank'"), isTrue,
          reason: 'bank value labelled in reference');
      expect(modalSrc.contains("'ملاحظات: \$notes'"), isTrue);
    });
  });
}
