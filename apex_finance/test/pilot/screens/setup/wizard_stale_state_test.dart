/// G-WIZARD-STALE-STATE — regression tests for the wizard's
/// defensive init + null-safety guards.
///
/// Why source-grep tests
/// ─────────────────────
/// The wizard imports `package:flutter/material.dart` and transitively
/// `dart:html` via `pilot/session.dart`. Loading it in a Dart-VM test
/// pulls in the G-T1.1 SDK mismatch on `package:web` 1.1.1 → load
/// fails. Source-grep pins the contract that matters: the shape of
/// each defensive layer must not regress under future refactors.
///
/// The eight tests below pin the four structural changes:
///
///   1. initState exists and runs migrateLegacyKey() up-front.
///   2. initState hydrates `_tenantId` from PilotSession.
///   3. initState clears orphan entityId/branchId.
///   4. _doStep3 guards `_tenantId == null` and `_createdEntityIds.isEmpty`.
///   5. _doStep4 guards `_tenantId == null` and `_createdBranchIds.isEmpty`.
///   6. _doStep5 guards `_tenantId == null`.
///   7. _doStep6 / _doStep7 surface "no entities" as a clear error.
///   8. The G-WIZARD-STALE-STATE marker comment is preserved for future
///      archaeology.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    final f = File('lib/pilot/screens/setup/pilot_onboarding_wizard.dart');
    expect(f.existsSync(), isTrue, reason: 'wizard file missing');
    src = f.readAsStringSync();
  });

  group('G-WIZARD-STALE-STATE — initState contract', () {
    test('test_init_state_exists_and_calls_migrate_legacy_key', () {
      // The wizard's first API call (step 1's updateTenant) must run
      // against a drift-free PilotSession. Pre-fix migrateLegacyKey()
      // ran transitively only via the hasTenant getter on line 1086;
      // an explicit call in initState makes the timing deterministic
      // and survives future code paths that bypass the getter.
      final initIdx = src.indexOf('void initState()');
      expect(initIdx, greaterThan(0),
          reason: 'wizard must override initState — pre-fix it had none');
      final endIdx = src.indexOf('Widget build(', initIdx);
      final body = src.substring(initIdx, endIdx);
      expect(
        body.contains('PilotSession.migrateLegacyKey()'),
        isTrue,
        reason:
            'initState must explicitly invoke migrateLegacyKey() — '
            'lazy invocation via the getter is correct but fragile to '
            'refactors that bypass the getter.',
      );
      // super.initState() before any side-effecting call.
      expect(
        body.contains('super.initState()'),
        isTrue,
        reason: 'initState must call super.initState() first',
      );
    });

    test('test_init_state_hydrates_tenant_id_from_pilot_session', () {
      // _tenantId starts null. A reload on step ≥ 2 wipes the in-memory
      // value — every `_tenantId!` bang in steps 3-8 then bombs unless
      // we hydrate from PilotSession at construction time.
      final initIdx = src.indexOf('void initState()');
      final endIdx = src.indexOf('Widget build(', initIdx);
      final body = src.substring(initIdx, endIdx);
      expect(
        body.contains('_tenantId = PilotSession.tenantId'),
        isTrue,
        reason:
            'initState must hydrate _tenantId from PilotSession so a '
            'reload mid-wizard doesn\'t null-bang on the next step.',
      );
    });

    test('test_init_state_clears_orphan_entity_id', () {
      // Pre-fix, a session that had `pilot.entity_id` set but
      // `pilot.tenant_id` cleared (orphan from pre-pilot-key migration)
      // polluted other screens reading PilotSession during wizard use
      // — they 404'd against pilot routes because the entity belonged
      // to a tenant the user no longer had access to.
      final initIdx = src.indexOf('void initState()');
      final endIdx = src.indexOf('Widget build(', initIdx);
      final body = src.substring(initIdx, endIdx);
      expect(
        body.contains('!PilotSession.hasTenant') &&
            body.contains('PilotSession.hasEntity') &&
            body.contains('clearEntityAndBranch()'),
        isTrue,
        reason:
            'initState must detect the orphan condition (entity without '
            'tenant) and call clearEntityAndBranch() — by design every '
            'user has a tenant post-ERR-2 Phase 3 (PR #169).',
      );
    });
  });

  group('G-WIZARD-STALE-STATE — null-safety guards', () {
    test('test_step3_guards_tenant_id_and_empty_entity_map', () {
      final stepIdx = src.indexOf('Future<void> _doStep3()');
      expect(stepIdx, greaterThan(0), reason: '_doStep3 must exist');
      final endIdx = src.indexOf('Future<void> _doStep4()', stepIdx);
      final body = src.substring(stepIdx, endIdx);
      expect(
        body.contains("_tenantId == null") &&
            body.contains("ارجع للخطوة 1"),
        isTrue,
        reason: '_doStep3 must guard _tenantId == null with a user-facing '
            'message that points back to step 1.',
      );
      expect(
        body.contains('_createdEntityIds.isEmpty'),
        isTrue,
        reason: '_doStep3 must guard _createdEntityIds.isEmpty — pre-fix '
            'a reload-on-step-3 bombed on the `_createdEntityIds[..]!` '
            'bang at the first iteration.',
      );
      // The bang on the lookup is replaced with a null check + throw.
      expect(
        body.contains("_createdEntityIds[b['_entity_code']]!"),
        isFalse,
        reason: '_doStep3 must NOT use the null-bang operator on the '
            'entity lookup — it must check explicitly and throw a '
            'translated message instead.',
      );
    });

    test('test_step4_guards_tenant_id_and_empty_branch_map', () {
      final stepIdx = src.indexOf('Future<void> _doStep4()');
      expect(stepIdx, greaterThan(0), reason: '_doStep4 must exist');
      final endIdx = src.indexOf('Future<void> _doStep5()', stepIdx);
      final body = src.substring(stepIdx, endIdx);
      expect(
        body.contains('_tenantId == null'),
        isTrue,
        reason: '_doStep4 must guard _tenantId == null',
      );
      expect(
        body.contains('_createdBranchIds.isEmpty'),
        isTrue,
        reason: '_doStep4 must guard _createdBranchIds.isEmpty — same '
            'reload-bang risk as step 3.',
      );
      expect(
        body.contains("_createdBranchIds[b['code']]!"),
        isFalse,
        reason: '_doStep4 must NOT use the null-bang on branch lookup.',
      );
    });

    test('test_step5_guards_tenant_id', () {
      final stepIdx = src.indexOf('Future<void> _doStep5()');
      expect(stepIdx, greaterThan(0), reason: '_doStep5 must exist');
      final endIdx = src.indexOf('Future<void> _doStep6()', stepIdx);
      final body = src.substring(stepIdx, endIdx);
      expect(
        body.contains('_tenantId == null'),
        isTrue,
        reason: '_doStep5 must guard _tenantId == null — pre-fix the '
            '`_tenantId!` bang in createCurrency exploded if the user '
            'reached step 5 without a populated tenantId.',
      );
    });

    test('test_step6_step7_surface_empty_entity_map', () {
      // Pre-fix steps 6 and 7 silently did nothing when
      // _createdEntityIds was empty — the loop iterated zero times,
      // _step incremented, and the user reached step 8 thinking CoA
      // and fiscal periods had been seeded.
      final s6 = src.indexOf('Future<void> _doStep6()');
      final s7 = src.indexOf('Future<void> _doStep7()');
      final s8 = src.indexOf('Future<void> _doStep8()');
      expect(s6 > 0 && s7 > 0 && s8 > 0,
          isTrue, reason: '_doStep6/7/8 must exist');
      final body6 = src.substring(s6, s7);
      final body7 = src.substring(s7, s8);
      for (final body in [body6, body7]) {
        expect(
          body.contains('_createdEntityIds.isEmpty'),
          isTrue,
          reason: 'steps 6 and 7 must surface empty entity map as a '
              'thrown error instead of silently doing nothing.',
        );
      }
    });
  });

  group('G-WIZARD-STALE-STATE — institutional memory', () {
    test('test_marker_comment_preserved_for_future_archaeology', () {
      // The G-WIZARD-STALE-STATE marker links every defensive line in
      // this PR to the bug it closes. A future "simplification" that
      // rips out the initState or the null guards must trip on these
      // markers and read the why before deleting the what.
      expect(
        src.contains('G-WIZARD-STALE-STATE'),
        isTrue,
        reason: 'wizard must retain the G-WIZARD-STALE-STATE marker '
            'so a future refactor can\'t silently remove the '
            'defensive layer without seeing the institutional memory.',
      );
      // At least 5 marker mentions: initState block + 4 step guards.
      final markerCount =
          'G-WIZARD-STALE-STATE'.allMatches(src).length;
      expect(markerCount >= 5, isTrue,
          reason: 'expected ≥5 G-WIZARD-STALE-STATE markers, '
              'found $markerCount');
    });
  });
}
