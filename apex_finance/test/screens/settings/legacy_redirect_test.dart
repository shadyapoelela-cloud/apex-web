/// G-ERP-UNIFICATION — regression tests for the legacy-route
/// redirects in `apex_finance/lib/core/router.dart`.
///
/// Pre-fix, the four legacy paths (/onboarding/wizard,
/// /clients/onboarding, /clients/new, /clients/create) all
/// redirected to /settings/entities?action=new-company — landing
/// the user on the legacy localStorage screen and bypassing the
/// pilot ERP entirely. Post-fix, every one of them goes to
/// /app/erp/finance/onboarding (PilotOnboardingWizard).
///
/// Source-grep tests because the router is wired into bootstrap +
/// session — instantiating it for a real navigation test would
/// pull in dart:html (G-T1.1).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-ERP-UNIFICATION — legacy redirects → unified wizard', () {
    late String src;

    setUpAll(() {
      final f = File('lib/core/router.dart');
      expect(f.existsSync(), isTrue, reason: 'router.dart missing');
      src = f.readAsStringSync();
    });

    /// Each test asserts the legacy GoRoute exists AND its redirect
    /// target is the unified wizard. The order of assertions matters:
    /// missing the route altogether is a different bug class than
    /// pointing at the wrong target.

    void _expectRedirectsToWizard(
      String path, {
      required String reason,
    }) {
      // The route block always opens with `path: '<path>'`, then has
      // `redirect: (c, s) => '...'`. Find the path declaration and
      // assert the next redirect line aims at the wizard.
      final pathDecl = "path: '$path'";
      final pathIdx = src.indexOf(pathDecl);
      expect(
        pathIdx,
        greaterThan(0),
        reason: 'route $path missing entirely from router.dart — $reason',
      );
      // Clamp the tail to the file length — the last legacy route in
      // the file is /clients/create; without the clamp `pathIdx + 400`
      // overshoots and throws RangeError.
      final endIdx =
          (pathIdx + 400) > src.length ? src.length : (pathIdx + 400);
      final tail = src.substring(pathIdx, endIdx);
      expect(
        tail.contains("'/app/erp/finance/onboarding'"),
        isTrue,
        reason:
            'route $path must redirect to /app/erp/finance/onboarding '
            '(the unified PilotOnboardingWizard) — found different '
            'target. $reason',
      );
      // And specifically NOT the old /settings/entities target.
      expect(
        tail.contains("'/settings/entities?action=new-company'"),
        isFalse,
        reason:
            'route $path still redirects to /settings/entities — the '
            'pre-G-ERP-UNIFICATION target. The legacy screen now exists '
            'only as a one-shot migration UI, not as a creation entry '
            'point. $reason',
      );
    }

    test('test_onboarding_wizard_redirects_to_unified_wizard', () {
      _expectRedirectsToWizard(
        '/onboarding/wizard',
        reason: 'pre-fix: pointed at the localStorage-only entity setup',
      );
    });

    test('test_clients_onboarding_redirects_to_unified_wizard', () {
      _expectRedirectsToWizard(
        '/clients/onboarding',
        reason: 'legacy "create client" entry point',
      );
    });

    test('test_clients_new_redirects_to_unified_wizard', () {
      _expectRedirectsToWizard(
        '/clients/new',
        reason: 'legacy "new client" entry point',
      );
    });

    test('test_clients_create_redirects_to_unified_wizard', () {
      _expectRedirectsToWizard(
        '/clients/create',
        reason: 'legacy "create client" entry point (alternate spelling)',
      );
    });

    test(
      'test_settings_entities_has_empty_store_redirect_guard',
      () {
        // The /settings/entities route gains a redirect callback
        // that bypasses the screen entirely when the local store is
        // empty. Pin the EntityStore-conditional branch so a future
        // refactor can't silently turn the screen back into a
        // primary entry point.
        expect(
          src.contains("path: '/settings/entities'"),
          isTrue,
          reason: '/settings/entities GoRoute must remain registered '
              'to handle migration; only the redirect guard changes',
        );
        expect(
          src.contains('EntityStore.listCompanies().isNotEmpty') &&
              src.contains('EntityStore.listEntities().isNotEmpty'),
          isTrue,
          reason:
              '/settings/entities redirect guard must read both '
              'EntityStore.listCompanies AND listEntities — without '
              'either, an account with only entities (no companies) '
              'would skip the migration banner and lose data.',
        );
        expect(
          src.contains("return '/app/erp/finance/onboarding'"),
          isTrue,
          reason:
              'empty-store redirect must aim at the unified wizard',
        );
      },
    );

    test(
      'test_no_legacy_path_still_redirects_to_settings_entities_create',
      () {
        // Belt-and-braces — scan the full file for any remaining
        // redirect pointing at the old /settings/entities?action=new
        // target. Future PRs that add a new legacy redirect MUST
        // update it to the new target; this test catches the lapse.
        final occurrences =
            "?action=new-company".allMatches(src).length;
        expect(
          occurrences,
          0,
          reason:
              'no router redirect should still point at '
              '/settings/entities?action=new-company — the migration '
              'screen exists only for legacy data, not as a creation '
              'entry point. Found $occurrences occurrence(s).',
        );
      },
    );
  });
}
