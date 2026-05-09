/// G-ERP-UNIFICATION — regression tests for the localStorage →
/// pilot ERP migration path in `entity_setup_screen.dart`.
///
/// Why source-grep tests
/// ─────────────────────
/// `entity_setup_screen.dart` imports `entity_store.dart`, which
/// imports `dart:html` for localStorage access — the same SDK
/// mismatch (G-T1.1) that blocks every other widget-driven test on
/// the Dart VM.
///
/// The contract this file pins is the *shape* of the migration code
/// in entity_setup_screen.dart: the banner widget exists, the
/// migration calls go through PilotClient (not localStorage), the
/// confirm dialog gates the destructive "delete legacy" path, and
/// post-completion the user is sent to the unified onboarding
/// wizard — never back to the legacy screen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-ERP-UNIFICATION — migration banner + logic', () {
    late String src;

    setUpAll(() {
      final f = File('lib/screens/settings/entity_setup_screen.dart');
      expect(f.existsSync(), isTrue,
          reason: 'screen file missing — was it moved?');
      src = f.readAsStringSync();
    });

    test('test_empty_localstorage_redirect_path_documented', () {
      // The redirect is in router.dart, but entity_setup_screen.dart
      // must coordinate: when the banner triggers + completes, the
      // user is sent to the unified onboarding wizard rather than
      // staying on the legacy screen.
      expect(
        src.contains("context.go('/app/erp/finance/onboarding')"),
        isTrue,
        reason:
            'after migration completes (or after "ignore + delete"), '
            'the user must land on the unified PilotOnboardingWizard '
            '— going back to /settings/entities would loop because '
            'the empty-store guard would just redirect again.',
      );
    });

    test('test_banner_renders_with_legacy_data', () {
      // _buildMigrationBanner is the entry point. The build() method
      // gates it on `if (hasAny)`, where hasAny = entities OR
      // companies OR branches in localStorage. Pin the conditional
      // render + the banner widget itself.
      expect(
        src.contains('_buildMigrationBanner'),
        isTrue,
        reason:
            'entity_setup_screen.dart must keep _buildMigrationBanner — '
            'it is the user-facing entry to the migration path.',
      );
      expect(
        src.contains('if (hasAny) _buildMigrationBanner()'),
        isTrue,
        reason:
            'banner must render conditional on hasAny (any localStorage '
            'data) so empty-store accounts are not bothered with it.',
      );
      // Both buttons surfaced.
      expect(
        src.contains('نعم، انقلها'),
        isTrue,
        reason: 'banner must offer "نعم، انقلها" (yes, migrate) action',
      );
      expect(
        src.contains('لا، تجاهل واحذف'),
        isTrue,
        reason: 'banner must offer "لا، تجاهل واحذف" (no, ignore) action',
      );
    });

    test('test_migration_calls_pilot_client_not_localstorage', () {
      // The "yes" path must POST through PilotClient — without that
      // the migrated rows wouldn't be visible in /reports/* (since
      // those endpoints query pilot_gl_postings only). Source-pin
      // the createEntity + createBranch calls.
      expect(
        src.contains('client.createEntity(tid,'),
        isTrue,
        reason:
            '_runMigration must POST companies via '
            'pilotClient.createEntity(tid, body) — without it the '
            'migrated rows never reach pilot_entities.',
      );
      expect(
        src.contains('client.createBranch(newEntityId,'),
        isTrue,
        reason:
            '_runMigration must POST branches via '
            'pilotClient.createBranch(eid, body) — without it the '
            'migrated branches never reach pilot_branches.',
      );
      // The legacy → new id mapping ensures branches link to the
      // right migrated parent.
      expect(
        src.contains('entityMapping[c.id] = newId') &&
            src.contains('entityMapping[b.companyId]'),
        isTrue,
        reason:
            'migration must build a legacy_company_id → new_entity_id '
            'mapping so branches POST to the correct parent. Missing '
            'this mapping would 404 every branch.',
      );
    });

    test('test_partial_failure_recorded_not_silent', () {
      // _MigrationResult tracks per-record failures. If a record
      // fails, the user must see WHY in the result dialog so they
      // can re-create the row in the wizard. Pin that the failure
      // list is populated AND surfaced in a dialog.
      expect(
        src.contains('class _MigrationResult'),
        isTrue,
        reason:
            'migration result class must exist — without it failures '
            'are silently swallowed.',
      );
      expect(
        src.contains('result.failures.add('),
        isTrue,
        reason:
            'each failed company/branch must be recorded in '
            'result.failures so the user sees it in the dialog.',
      );
      expect(
        src.contains('_showMigrationResultDialog(result)'),
        isTrue,
        reason:
            'after migration completes, _showMigrationResultDialog '
            'must surface the result (success + failures) before the '
            'redirect.',
      );
      // Branches whose parent didn't migrate are explicitly skipped
      // with a recorded failure (rather than silently dropped).
      expect(
        src.contains('لم تُهاجَر الشركة الأم'),
        isTrue,
        reason:
            'branches with un-migrated parents must record a specific '
            'failure message — silently dropping them would be a hidden '
            'data-loss path.',
      );
    });

    test('test_localstorage_cleared_after_migration', () {
      // Both the "yes" and "no" paths end with EntityStore.clearAll()
      // (via the _clearLocalStorage helper) so the legacy data is
      // gone. Subsequent visits hit the empty-store redirect in
      // router.dart and bypass this screen entirely.
      expect(
        src.contains('EntityStore.clearAll()'),
        isTrue,
        reason:
            '_clearLocalStorage must call EntityStore.clearAll() to '
            'wipe the apex_entities_v1 / apex_companies_v2 / '
            'apex_branches_v1 keys after migration.',
      );
      expect(
        src.contains('void _clearLocalStorage()'),
        isTrue,
        reason: '_clearLocalStorage helper must exist',
      );
      // The "ignore" path must show a confirm dialog before wiping
      // — destructive operations should never one-click.
      expect(
        src.contains('_confirmIgnoreAndDelete'),
        isTrue,
        reason:
            'the "no, ignore" path must route through '
            '_confirmIgnoreAndDelete so the user explicitly '
            'acknowledges the destructive wipe.',
      );
    });

    test('test_no_tenant_blocks_migration_with_clear_message', () {
      // PilotSession.tenantId is set at registration (post-PR #169).
      // If it's missing, the migration cannot complete — the call
      // sites that POST to /tenants/{tid}/... would fail. Pin that
      // the banner gates the "yes" button on hasTenant AND surfaces
      // a clear error message.
      expect(
        src.contains('PilotSession.hasTenant'),
        isTrue,
        reason:
            'banner must read PilotSession.hasTenant to gate the '
            'migrate button — calling _runMigration without a tenant '
            'would fail every createEntity call.',
      );
      expect(
        src.contains('(_migrating || !hasTenant) ? null : _runMigration'),
        isTrue,
        reason:
            'the migrate button must be disabled when hasTenant is '
            'false — clicking it would surface a generic 422 / 404 '
            'instead of a clear "open the ERP first" message.',
      );
    });

    test('test_legacy_code_synthesis_for_pilot_schema', () {
      // The pilot schema requires `code` matching ^[A-Z0-9_-]+$ with
      // min_length=2. Legacy CompanyRecord / BranchRecord don't
      // carry a `code` field — the migration synthesizes one from
      // the id. Pin both helpers exist + the prefix convention.
      expect(
        src.contains('_legacyCompanyCode'),
        isTrue,
        reason:
            '_legacyCompanyCode helper must exist to synthesize a '
            'pilot-schema-valid code from a legacy company id.',
      );
      expect(
        src.contains('_legacyBranchCode'),
        isTrue,
        reason: '_legacyBranchCode helper must exist for branches.',
      );
      // Prefixes make migrated records traceable in the GL report.
      expect(
        src.contains("'MIG-"),
        isTrue,
        reason:
            'company codes must use the MIG- prefix so migrated rows '
            'are easy to find in the entity list post-migration.',
      );
      expect(
        src.contains("'BR-"),
        isTrue,
        reason: 'branch codes must use the BR- prefix.',
      );
    });
  });
}
