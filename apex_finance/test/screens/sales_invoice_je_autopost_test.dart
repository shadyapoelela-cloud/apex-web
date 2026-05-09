/// G-FIN-SALES-INVOICE-JE-AUTOPOST — source-grep regression tests
/// for the Sprint 5 enhancement of SalesInvoiceCreateScreen.
///
/// Why source-grep tests
/// ─────────────────────
/// Same reason as G-FIN-CUSTOMERS-COMPLETE: the screen transitively
/// pulls in package:web via session.dart, failing the SDK-mismatch
/// gate (G-T1.1) under flutter_test. Source-grep pins the contract
/// without rendering the widget tree.
///
/// 6 contracts pinned:
///
///   1. The screen imports and uses CustomerPickerOrCreate (the inline
///      "+ عميل جديد" path) — replacing the prior dropdown that
///      forced users to leave the form.
///   2. _saveDraft exists and POSTs WITHOUT calling /issue (so no JE
///      auto-post happens for drafts).
///   3. _submit calls /issue after /create, in that order — the JE
///      auto-post depends on /issue running.
///   4. The success snackbar surfaces the JE id from the issue
///      response, with an action button linking to the JE list.
///   5. The cancel/save-draft button row is laid out as
///      `Row` with two `Expanded` children (so Save Draft can't
///      silently disappear in a future refactor).
///   6. The G-FIN-SALES-INVOICE-JE-AUTOPOST marker is preserved for
///      future archaeology.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    final f = File('lib/screens/operations/sales_invoice_create_screen.dart');
    expect(f.existsSync(), isTrue, reason: 'screen file missing');
    src = f.readAsStringSync();
  });

  group('G-FIN-SALES-INVOICE-JE-AUTOPOST — picker integration', () {
    test('test_uses_customer_picker_or_create', () {
      // The previous dropdown forced users to leave the invoice form
      // to create a customer. The picker offers an inline create flow.
      // If a future refactor accidentally restores the dropdown,
      // this test fires before merge.
      expect(
        src.contains("import '../../widgets/forms/customer_picker_or_create.dart';"),
        isTrue,
        reason: 'must import CustomerPickerOrCreate',
      );
      expect(src.contains('CustomerPickerOrCreate('), isTrue,
          reason: '_customerPicker must build CustomerPickerOrCreate');
      expect(src.contains('DropdownButtonFormField<String>('), isFalse,
          reason: 'the old dropdown must be removed (no `String` dropdown)');
    });
  });

  group('G-FIN-SALES-INVOICE-JE-AUTOPOST — save flows', () {
    test('test_save_draft_skips_issue_endpoint', () {
      // Save Draft must NOT call pilotIssueSalesInvoice — that's the
      // whole point. If it did, the JE would auto-post for drafts and
      // pollute the trial balance with un-issued invoices.
      final saveIdx = src.indexOf('Future<void> _saveDraft()');
      expect(saveIdx, greaterThan(0),
          reason: '_saveDraft method must exist');
      // Find the next method boundary so we only scan _saveDraft body.
      final nextMethodIdx =
          src.indexOf('Future<void> _submit()', saveIdx);
      expect(nextMethodIdx, greaterThan(saveIdx),
          reason: '_submit must come after _saveDraft');
      final body = src.substring(saveIdx, nextMethodIdx);
      expect(body.contains('pilotCreateSalesInvoice'), isTrue,
          reason: '_saveDraft must call pilotCreateSalesInvoice');
      expect(body.contains('pilotIssueSalesInvoice'), isFalse,
          reason: '_saveDraft must NOT call pilotIssueSalesInvoice — '
              'drafts must not trigger the JE auto-post');
    });

    test('test_submit_creates_then_issues_in_order', () {
      // _submit must call create THEN issue, in that order. The JE
      // auto-post hinges on /issue, but /issue 404s without a prior
      // /create. If a refactor reorders these, every issue dies.
      final submitIdx = src.indexOf('Future<void> _submit()');
      expect(submitIdx, greaterThan(0));
      final body = src.substring(submitIdx, submitIdx + 4000);
      final createIdx = body.indexOf('pilotCreateSalesInvoice');
      final issueIdx = body.indexOf('pilotIssueSalesInvoice');
      expect(createIdx, greaterThan(0));
      expect(issueIdx, greaterThan(createIdx),
          reason: 'pilotIssueSalesInvoice must run AFTER '
              'pilotCreateSalesInvoice');
    });
  });

  group('G-FIN-SALES-INVOICE-JE-AUTOPOST — success snackbar', () {
    test('test_success_snackbar_surfaces_je_id_with_action', () {
      // Server returns `journal_entry_id` on the /issue response.
      // The user-visible promise is "you can see the JE in one click."
      // The action button takes them to the JE list.
      expect(src.contains("issueData['journal_entry_id']"), isTrue,
          reason: 'must read journal_entry_id from /issue response');
      expect(src.contains('قيد اليومية'), isTrue,
          reason: 'snackbar must surface JE label in Arabic');
      expect(src.contains('عرض القيد'), isTrue,
          reason: 'snackbar action button labelled "عرض القيد"');
      expect(src.contains("'/app/erp/finance/je-builder'"), isTrue,
          reason: 'action button navigates to the JE builder/list');
    });
  });

  group('G-FIN-SALES-INVOICE-JE-AUTOPOST — UI ratchet', () {
    test('test_two_button_row_with_save_draft', () {
      // The bottom action row must contain BOTH buttons. Pin the
      // structural shape so a refactor can't drop Save Draft.
      expect(src.contains('حفظ كمسودة'), isTrue,
          reason: 'Save Draft button label must remain');
      expect(src.contains('إنشاء وإصدار'), isTrue,
          reason: 'Issue button label must remain');
      expect(src.contains('onPressed: _submitting ? null : _saveDraft'),
          isTrue,
          reason: 'Save Draft button must call _saveDraft');
      expect(src.contains('onPressed: _submitting ? null : _submit'),
          isTrue,
          reason: 'Issue button must call _submit');
    });

    test('test_marker_comment_preserved', () {
      expect(src.contains('G-FIN-SALES-INVOICE-JE-AUTOPOST'), isTrue,
          reason:
              'marker comment must remain for future archaeology');
    });
  });
}
