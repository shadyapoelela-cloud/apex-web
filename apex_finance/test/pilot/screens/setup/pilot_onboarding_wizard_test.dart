/// G-WIZARD-TENANT-FIX — regression tests for the onboarding wizard's
/// step-1 tenant handling.
///
/// Why source-grep tests
/// ─────────────────────
/// `pilot_onboarding_wizard.dart` imports `pilot/session.dart`, which
/// imports `dart:html`, which transitively pulls `package:web` 1.1.1
/// — the same SDK mismatch (G-T1.1) that blocks every other widget-
/// driven test on the Dart VM. Until G-T1.1 is closed, source-grep
/// regression tests pin the contract that matters: the *shape* of
/// `_doStep1` and the branch on `PilotSession.hasTenant`.
///
/// A widget-driven test would let us assert the actual API call, but
/// the contract this file pins is more important: the **branching
/// logic** itself must not regress. A dev who removes the `hasTenant`
/// check or replaces `updateTenant` with `createTenant` reintroduces
/// the original bug, and these tests catch that.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-WIZARD-TENANT-FIX — onboarding wizard step 1', () {
    late String src;

    setUpAll(() {
      final f = File('lib/pilot/screens/setup/pilot_onboarding_wizard.dart');
      expect(
        f.existsSync(),
        isTrue,
        reason: 'wizard file missing — was it moved or deleted?',
      );
      src = f.readAsStringSync();
    });

    test(
      'test_step1_uses_existing_tenant_when_session_has_tenant',
      () {
        // _doStep1 must branch on PilotSession.hasTenant. The
        // hasTenant=true branch must call updateTenant with the
        // existing tenantId (PilotSession.tenantId) — never
        // createTenant. If a future contributor removes this branch,
        // the original G-PILOT-TENANT-AUDIT-FINAL regression returns:
        // a fresh user's JWT carries the auto-created tenant from
        // ERR-2 registration, but step 1 would create a second one
        // and step 2's createEntity would 404 against the new tid.
        expect(
          src.contains('PilotSession.hasTenant'),
          isTrue,
          reason:
              '_doStep1 must check PilotSession.hasTenant — without '
              'it the wizard always creates a new tenant and breaks '
              'the JWT-tenant invariant.',
        );
        // The hasTenant=true branch reuses PilotSession.tenantId.
        expect(
          src.contains('_tenantId = PilotSession.tenantId'),
          isTrue,
          reason:
              'hasTenant=true branch must reuse PilotSession.tenantId '
              '— assigning a new id from createTenant defeats the '
              'whole fix.',
        );
        // Specifically, the update branch calls updateTenant with
        // the bound tid.
        expect(
          src.contains('_client.updateTenant(_tenantId!,'),
          isTrue,
          reason:
              'update branch must call _client.updateTenant(_tenantId!, …) '
              '— see app/pilot/routes/pilot_routes.py PATCH '
              '/tenants/{tid}, gated by assert_tenant_matches_user.',
        );
      },
    );

    test(
      'test_step1_creates_new_tenant_when_no_session_tenant',
      () {
        // The fallback path (legacy user from before ERR-2 Phase 3
        // / PR #169 who never got migrated by PR #170) must keep
        // working — they don't have a JWT tenant claim, so
        // creating a new tenant is the correct flow. Pin the
        // fallback retains createTenant + sets PilotSession.tenantId
        // from the response body.
        expect(
          src.contains('_client.createTenant('),
          isTrue,
          reason:
              'fallback path must still call _client.createTenant(…) '
              'for legacy users without a JWT tenant claim. Removing '
              'it would break the onboarding flow for unmigrated '
              'pre-ERR-2 accounts.',
        );
        // The fallback writes the new id back to the session so
        // step 2+ can find it.
        expect(
          src.contains('PilotSession.tenantId = _tenantId'),
          isTrue,
          reason:
              'fallback path must set PilotSession.tenantId = _tenantId '
              'after createTenant — without it, hasTenant stays false '
              'and EntityResolver / the next step will 404.',
        );
        // The branch lives inside `if/else` on hasTenant.
        expect(
          src.contains('if (PilotSession.hasTenant) {') &&
              src.contains('} else {'),
          isTrue,
          reason:
              '_doStep1 must use a strict `if (PilotSession.hasTenant) '
              '{ … } else { … }` shape so the create-fallback only '
              'fires when the session is genuinely missing a tenant.',
        );
      },
    );

    test(
      'test_step2_uses_correct_tenant_id_after_step1',
      () {
        // Belt-and-braces — step 2 reads `_tenantId` (set by step 1)
        // and routes to /tenants/{_tenantId}/entities. After the fix,
        // the update path assigns `_tenantId = PilotSession.tenantId`,
        // so step 2's tenantId IS the JWT-bound tenant — and
        // assert_tenant_matches_user passes.
        //
        // Pin both sides:
        //   1. The update branch sets _tenantId from PilotSession.
        //   2. _doStep2 still reads _tenantId (not a fresh value).
        expect(
          src.contains('createEntity(_tenantId!,'),
          isTrue,
          reason:
              '_doStep2 must keep using _tenantId (set in step 1) '
              'when calling createEntity — switching to a different '
              'source would re-introduce the JWT/tenant mismatch.',
        );
        expect(
          src.contains("if (_tenantId == null) throw 'المستأجر لم يُنشأ'"),
          isTrue,
          reason:
              '_doStep2 must keep its null-guard on _tenantId so the '
              'wizard fails fast if step 1 silently no-op\'d (e.g. a '
              'future regression where neither branch sets _tenantId).',
        );
        // And the update branch writes _tenantId via the assignment
        // *before* the API call so a failed update still leaves
        // _tenantId pointing at the JWT-bound tenant.
        final stepIdx = src.indexOf('Future<void> _doStep1()');
        final updateAssignIdx =
            src.indexOf('_tenantId = PilotSession.tenantId', stepIdx);
        final updateCallIdx =
            src.indexOf('_client.updateTenant(_tenantId!,', stepIdx);
        expect(updateAssignIdx, greaterThan(0));
        expect(updateCallIdx, greaterThan(0));
        expect(
          updateAssignIdx < updateCallIdx,
          isTrue,
          reason:
              '_tenantId must be assigned from PilotSession BEFORE the '
              'updateTenant call so a failed PATCH still leaves the '
              'wizard pointing at the right tenant for retry.',
        );
      },
    );

    test(
      'test_marker_comment_preserved_for_future_archaeology',
      () {
        // The G-WIZARD-TENANT-FIX comment block in _doStep1 explains
        // *why* the branching exists (ERR-2 + tenant-audit-final
        // chain). A future dev tempted to "simplify" by always
        // creating must read this first. Pin the marker so refactors
        // don't lose it.
        expect(
          src.contains('G-WIZARD-TENANT-FIX'),
          isTrue,
          reason:
              'the rationale comment in _doStep1 must remain — it is '
              'the institutional memory linking ERR-2 Phase 3 (the '
              'auto-tenant) → G-PILOT-TENANT-AUDIT-FINAL (the assert) → '
              'this fix. Without it a future dev sees branching '
              'they don\'t understand and rips it out.',
        );
      },
    );
  });
}
