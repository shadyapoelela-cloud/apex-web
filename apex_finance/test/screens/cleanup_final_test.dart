/// G-CLEANUP-FINAL (2026-05-11) — regression tests for the 4 small
/// polish fixes:
///
///   1. ZATCA QR no longer renders on cancelled sales invoices
///      (status-whitelist gate instead of `!= 'draft'`).
///   2. `dart:html` import is now conditional via
///      `core/browser_print.dart` + `core/browser_print_web.dart`
///      so non-web builds compile.
///   3. Duplicate `/setup` GoRoute registration removed from
///      `core/router.dart` (kept exactly one canonical instance).
///   4. `pilotPostPosToGL` in `api_service.dart` now carries a
///      doc-comment explaining why it's kept despite zero callers
///      in `lib/screens/`.
///
/// Same source-grep strategy as prior sprints: the screens transitively
/// import `package:web` which fails the flutter_test SDK gate, so we
/// assert on file contents instead of widget rendering. RegExp is used
/// for any multi-line assertion to be CRLF/LF safe.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String salesDetailsSrc;
  late String purchaseDetailsSrc;
  late String routerSrc;
  late String apiSrc;
  late String browserPrintStubSrc;
  late String browserPrintWebSrc;

  setUpAll(() {
    String read(String p) {
      final f = File(p);
      expect(f.existsSync(), isTrue, reason: '$p missing');
      return f.readAsStringSync();
    }

    salesDetailsSrc =
        read('lib/screens/operations/sales_invoice_details_screen.dart');
    purchaseDetailsSrc =
        read('lib/screens/operations/purchase_invoice_details_screen.dart');
    routerSrc = read('lib/core/router.dart');
    apiSrc = read('lib/api_service.dart');
    browserPrintStubSrc = read('lib/core/browser_print.dart');
    browserPrintWebSrc = read('lib/core/browser_print_web.dart');
  });

  group('Fix #1: ZATCA QR status awareness', () {
    test('test_sales_qr_uses_status_whitelist_not_blacklist', () {
      // Whitelist of legitimate post-issuance statuses must be present.
      expect(
        salesDetailsSrc.contains("status == 'issued'"),
        isTrue,
        reason: 'QR gate must include `issued` status',
      );
      expect(
        salesDetailsSrc.contains("status == 'partially_paid'"),
        isTrue,
        reason: 'QR gate must include `partially_paid` status',
      );
      expect(
        salesDetailsSrc.contains("status == 'paid'"),
        isTrue,
        reason: 'QR gate must include `paid` status',
      );

      // The legacy blacklist (`!= 'draft'`) must NOT be present any
      // longer. Use a regex anchored to the assignment of `issued`
      // to avoid false matches from unrelated comments.
      final legacyGate = RegExp(
        r"final\s+issued\s*=\s*\(\s*inv\[\s*'status'\s*\]\s*\?\?\s*''\s*\)\s*!=\s*'draft'",
      );
      expect(
        legacyGate.hasMatch(salesDetailsSrc),
        isFalse,
        reason:
            'legacy `!= draft` gate must be replaced with status whitelist',
      );
    });

    test('test_sales_qr_shows_cancelled_hint', () {
      // The Arabic hint for a cancelled invoice must appear in source.
      expect(
        salesDetailsSrc.contains('فاتورة ملغاة'),
        isTrue,
        reason: 'cancelled invoices must show "فاتورة ملغاة" hint',
      );
      // And it must be conditional on the cancelled status.
      final conditional = RegExp(
        r"status\s*==\s*'cancelled'",
      );
      expect(
        conditional.hasMatch(salesDetailsSrc),
        isTrue,
        reason: 'cancelled-hint must branch on status == cancelled',
      );
    });
  });

  group('Fix #2: Conditional dart:html import', () {
    test('test_browser_print_stub_exists_with_function', () {
      // Default (non-web) stub must declare triggerBrowserPrint.
      expect(
        browserPrintStubSrc.contains('void triggerBrowserPrint()'),
        isTrue,
        reason: 'browser_print.dart must declare triggerBrowserPrint()',
      );
      // It must NOT import dart:html (it's the non-web fallback).
      expect(
        browserPrintStubSrc.contains("import 'dart:html'"),
        isFalse,
        reason: 'the stub must not import dart:html',
      );
    });

    test('test_browser_print_web_imports_dart_html', () {
      expect(
        browserPrintWebSrc.contains("import 'dart:html'"),
        isTrue,
        reason: 'browser_print_web.dart must import dart:html',
      );
      expect(
        browserPrintWebSrc.contains('void triggerBrowserPrint()'),
        isTrue,
        reason: 'browser_print_web.dart must define triggerBrowserPrint()',
      );
      expect(
        browserPrintWebSrc.contains('html.window.print()'),
        isTrue,
        reason: 'the web implementation must call html.window.print()',
      );
    });

    test('test_sales_details_no_direct_dart_html_import', () {
      // The unconditional import must be gone.
      final directImport = RegExp(r"^\s*import\s+'dart:html'", multiLine: true);
      expect(
        directImport.hasMatch(salesDetailsSrc),
        isFalse,
        reason:
            'sales details must not import dart:html directly — use the '
            'conditional browser_print indirection',
      );
    });

    test('test_sales_details_uses_conditional_browser_print_import', () {
      // The conditional import must be present.
      final conditional = RegExp(
        r"import\s+'\.\./\.\./core/browser_print\.dart'\s*\r?\n?\s*if\s*\(\s*dart\.library\.html\s*\)\s*'\.\./\.\./core/browser_print_web\.dart'",
      );
      expect(
        conditional.hasMatch(salesDetailsSrc),
        isTrue,
        reason:
            'sales details must use conditional-import-by-library for '
            'browser_print',
      );
      // Call site must use triggerBrowserPrint() not html.window.print().
      expect(
        salesDetailsSrc.contains('triggerBrowserPrint()'),
        isTrue,
        reason: 'sales details must call triggerBrowserPrint()',
      );
    });

    test('test_purchase_details_no_direct_dart_html_import', () {
      final directImport = RegExp(r"^\s*import\s+'dart:html'", multiLine: true);
      expect(
        directImport.hasMatch(purchaseDetailsSrc),
        isFalse,
        reason:
            'purchase details must not import dart:html directly — use '
            'the conditional browser_print indirection',
      );
    });

    test('test_purchase_details_uses_conditional_browser_print_import', () {
      final conditional = RegExp(
        r"import\s+'\.\./\.\./core/browser_print\.dart'\s*\r?\n?\s*if\s*\(\s*dart\.library\.html\s*\)\s*'\.\./\.\./core/browser_print_web\.dart'",
      );
      expect(
        conditional.hasMatch(purchaseDetailsSrc),
        isTrue,
        reason:
            'purchase details must use conditional-import-by-library for '
            'browser_print',
      );
      expect(
        purchaseDetailsSrc.contains('triggerBrowserPrint()'),
        isTrue,
        reason: 'purchase details must call triggerBrowserPrint()',
      );
    });
  });

  group('Fix #3: /setup route registered exactly once', () {
    test('test_setup_route_registered_exactly_once', () {
      // Count GoRoute registrations for path '/setup' (not /setup/entity).
      // Use a regex that matches GoRoute(path: '/setup', ...) but NOT
      // GoRoute(path: '/setup/entity', ...).
      final setupRouteRe =
          RegExp(r"GoRoute\s*\(\s*path:\s*'/setup'\s*,");
      final matches = setupRouteRe.allMatches(routerSrc).length;
      expect(
        matches,
        equals(1),
        reason:
            "expected exactly one GoRoute(path: '/setup', ...) — "
            'found $matches. The duplicate at line ~689 should have '
            'been removed in G-CLEANUP-FINAL.',
      );
    });

    test('test_setup_entity_route_still_present', () {
      // We did NOT remove /setup/entity. Make sure it's still there.
      final setupEntityRe =
          RegExp(r"GoRoute\s*\(\s*path:\s*'/setup/entity'\s*,");
      expect(
        setupEntityRe.hasMatch(routerSrc),
        isTrue,
        reason: '/setup/entity redirect must still be registered',
      );
    });
  });

  group('Fix #4: pilotPostPosToGL doc-comment', () {
    test('test_pilot_post_pos_to_gl_has_doc_comment', () {
      // The doc-comment must appear immediately above the method
      // declaration. We use a multi-line regex with [\s\S]*? to bridge
      // any line endings safely.
      final commentedMethod = RegExp(
        r"///[^\n]*G-POS-BACKEND-INTEGRATION-V2[\s\S]*?static\s+Future<ApiResult>\s+pilotPostPosToGL",
      );
      expect(
        commentedMethod.hasMatch(apiSrc),
        isTrue,
        reason:
            'pilotPostPosToGL must have a doc-comment referencing the '
            'G-POS-BACKEND-INTEGRATION-V2 sibling task explaining why '
            'it is kept despite zero lib/screens/ callers',
      );

      // The method itself must still exist (we documented, didn't remove).
      expect(
        apiSrc.contains(
            'static Future<ApiResult> pilotPostPosToGL(String posTxnId)'),
        isTrue,
        reason: 'pilotPostPosToGL must still be defined',
      );
    });
  });
}
