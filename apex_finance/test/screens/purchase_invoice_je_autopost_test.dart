/// G-FIN-PURCHASE-INVOICE-JE-AUTOPOST — source-grep regression
/// tests for the Sprint 6 PurchaseInvoiceCreateScreen.
///
/// Mirror of sales_invoice_je_autopost_test.dart with purchase-side
/// invariants (vendor picker, post endpoint instead of issue, default
/// due date 60 days vs 30).
///
/// 7 contracts pinned.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;
  late String listSrc;
  late String routerSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    src = read('lib/screens/operations/purchase_invoice_create_screen.dart');
    listSrc = read('lib/screens/operations/purchase_invoices_screen.dart');
    routerSrc = read('lib/core/router.dart');
  });

  group('G-FIN-PURCHASE-INVOICE-JE-AUTOPOST — picker integration', () {
    test('test_uses_vendor_picker_or_create', () {
      expect(
        src.contains(
            "import '../../widgets/forms/vendor_picker_or_create.dart';"),
        isTrue,
        reason: 'must import VendorPickerOrCreate',
      );
      expect(src.contains('VendorPickerOrCreate('), isTrue,
          reason: 'must build VendorPickerOrCreate (not a vendor dropdown)');
    });
  });

  group('G-FIN-PURCHASE-INVOICE-JE-AUTOPOST — save flows', () {
    test('test_save_draft_skips_post_endpoint', () {
      final saveIdx = src.indexOf('Future<void> _saveDraft()');
      expect(saveIdx, greaterThan(0));
      final nextIdx = src.indexOf('Future<void> _submit()', saveIdx);
      expect(nextIdx, greaterThan(saveIdx));
      final body = src.substring(saveIdx, nextIdx);
      expect(body.contains('pilotCreatePurchaseInvoice'), isTrue,
          reason: '_saveDraft must call pilotCreatePurchaseInvoice');
      expect(body.contains('pilotPostPurchaseInvoice'), isFalse,
          reason:
              '_saveDraft must NOT call /post — drafts must not auto-post JEs');
    });

    test('test_submit_creates_then_posts_in_order', () {
      final submitIdx = src.indexOf('Future<void> _submit()');
      expect(submitIdx, greaterThan(0));
      final body = src.substring(submitIdx, submitIdx + 4000);
      final createIdx = body.indexOf('pilotCreatePurchaseInvoice');
      final postIdx = body.indexOf('pilotPostPurchaseInvoice');
      expect(createIdx, greaterThan(0));
      expect(postIdx, greaterThan(createIdx),
          reason:
              'pilotPostPurchaseInvoice must run AFTER pilotCreatePurchaseInvoice');
    });

    test('test_default_due_date_is_60_days_out', () {
      // Vendors typically have net_60 payment terms (vs net_30 for
      // customers). Default the due date 60 days out so the user
      // doesn't have to adjust it for the typical case.
      expect(
        src.contains(
            'DateTime.now().add(const Duration(days: 60))'),
        isTrue,
        reason:
            'default due date must be 60 days out (vendor working-capital asymmetry)',
      );
    });
  });

  group('G-FIN-PURCHASE-INVOICE-JE-AUTOPOST — success snackbar', () {
    test('test_success_snackbar_surfaces_je_id_with_action', () {
      expect(src.contains("postData['journal_entry_id']"), isTrue,
          reason: 'must read journal_entry_id from /post response');
      expect(src.contains('قيد اليومية'), isTrue);
      expect(src.contains('عرض القيد'), isTrue);
      expect(src.contains("'/app/erp/finance/je-builder'"), isTrue);
    });
  });

  group('G-FIN-PURCHASE-INVOICE-JE-AUTOPOST — list + router', () {
    test('test_list_create_routes_to_new_screen', () {
      expect(
        listSrc.contains("'/app/erp/finance/purchase-bills/new'"),
        isTrue,
        reason: 'list `+ جديد` must route to the new create screen',
      );
      expect(
        listSrc.contains("context.go('/purchase')"),
        isFalse,
        reason: 'old /purchase placeholder route must be gone',
      );
    });

    test('test_router_has_create_route', () {
      expect(
        routerSrc.contains("'/app/erp/finance/purchase-bills/new'"),
        isTrue,
        reason: 'router must declare GoRoute for the create screen',
      );
      expect(routerSrc.contains('PurchaseInvoiceCreateScreen('), isTrue);
    });
  });
}
