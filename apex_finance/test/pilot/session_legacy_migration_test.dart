/// G-LEGACY-KEY-AUDIT — regression tests for the legacy/pilot
/// localStorage key drift fix.
///
/// Why source-grep tests
/// ─────────────────────
/// `pilot/session.dart` and `core/session.dart` both import
/// `dart:html`. Loading either in a Dart-VM test pulls in the
/// G-T1.1 SDK mismatch on `package:web` 1.1.1 → load fails. So the
/// contract is pinned via source-grep against the file text. A
/// widget test would let us actually flip values in a mocked
/// localStorage and watch the migration helper run, but the contract
/// these tests pin is the more important one: a future
/// "simplification" that rips out the migration helper, the dual-key
/// setter sync, or the PilotSession.clear() inside S.clear() will
/// re-introduce one of the three drift scenarios — and these tests
/// catch each independently.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-LEGACY-KEY-AUDIT — PilotSession setter / clear contract', () {
    late String src;

    setUpAll(() {
      final f = File('lib/pilot/session.dart');
      expect(f.existsSync(), isTrue, reason: 'pilot/session.dart missing');
      src = f.readAsStringSync();
    });

    test('test_setter_writes_both_keys', () {
      // PilotSession.tenantId setter must write BOTH the canonical
      // `pilot.tenant_id` key AND the legacy `apex_tenant_id` key.
      // Pre-fix, only the canonical key was written, so 20+ screens
      // still reading via S.tenantId / S.savedTenantId saw stale or
      // missing data after a tenant change.
      final setterIdx = src.indexOf('static set tenantId(String? v)');
      expect(setterIdx, greaterThan(0),
          reason: 'PilotSession.tenantId setter must exist');
      // Body runs from the setter to the next `static` declaration.
      final bodyEnd = src.indexOf('static ', setterIdx + 30);
      final body = src.substring(setterIdx, bodyEnd);
      expect(
        body.contains('_set(_tenantKey, v)'),
        isTrue,
        reason: 'setter must write the canonical pilot.tenant_id key',
      );
      expect(
        body.contains('_set(_legacyTenantKey, v)'),
        isTrue,
        reason:
            'setter must ALSO write the legacy apex_tenant_id key — '
            'pre-fix it didn\'t, so S.savedTenantId via the legacy key '
            'returned stale values for any screen still on S.tenantId.',
      );
    });

    test('test_clear_wipes_both_keys', () {
      // PilotSession.clear() must wipe BOTH the canonical pilot.* keys
      // AND the legacy apex_tenant_id / apex_entity_id. Pre-fix logout
      // was asymmetric: S.clear() removed only the legacy keys, leaving
      // pilot.* dirty → next user inherited previous user's tenantId,
      // bypassing tenant-isolation guards.
      final clearIdx = src.indexOf('static void clear()');
      expect(clearIdx, greaterThan(0),
          reason: 'PilotSession.clear() must exist');
      final clearEnd = src.indexOf('static ', clearIdx + 20);
      final body = src.substring(clearIdx, clearEnd);
      // Confirm all four key constants are wiped.
      for (final key in [
        '_tenantKey',
        '_entityKey',
        '_branchKey',
        '_legacyTenantKey',
        '_legacyEntityKey',
      ]) {
        expect(
          body.contains(key),
          isTrue,
          reason: 'clear() must wipe $key — missing it leaves dirty state '
              'that the next user inherits.',
        );
      }
    });

    test('test_drift_migration_on_load', () {
      // The migrateLegacyKey() helper must handle the "both exist but
      // differ" scenario: trust pilot (canonical), sync legacy → pilot
      // value. Pre-fix this drift could exist when S.setActiveScope
      // wrote only the legacy key while a different value sat in pilot
      // from an earlier session. A console.warn is required so devs
      // notice during pre-prod testing.
      final migrateIdx = src.indexOf('static void migrateLegacyKey()');
      expect(migrateIdx, greaterThan(0),
          reason: 'migrateLegacyKey() helper must exist');
      final endIdx = src.indexOf('// ──', migrateIdx);
      final body =
          endIdx > migrateIdx ? src.substring(migrateIdx, endIdx) : src.substring(migrateIdx);
      // The drift branch: pilot is non-empty AND legacy != pilot.
      expect(
        body.contains('legacy != pilot'),
        isTrue,
        reason: 'migration helper must detect drift between the two keys',
      );
      // On drift, sync legacy ← pilot (trust pilot).
      expect(
        body.contains('localStorage[_legacyTenantKey] = pilot'),
        isTrue,
        reason: 'on drift, legacy must be synced to the canonical pilot value',
      );
      // Console warn on drift so devs notice during pre-prod.
      expect(
        body.contains('G-LEGACY-KEY-AUDIT'),
        isTrue,
        reason: 'drift detection must console-warn with the audit marker',
      );
      expect(
        body.contains('drift detected'),
        isTrue,
        reason: 'drift warn message must say "drift detected"',
      );
    });

    test('test_legacy_only_migration', () {
      // The migrateLegacyKey() helper must handle the "only legacy
      // exists" scenario: a session from before the pilot keys
      // existed. Migrate up so PilotSession.hasTenant returns true and
      // the wizard's `if (PilotSession.hasTenant)` branch fires.
      final migrateIdx = src.indexOf('static void migrateLegacyKey()');
      expect(migrateIdx, greaterThan(0),
          reason: 'migrateLegacyKey() helper must exist');
      final endIdx = src.indexOf('// ──', migrateIdx);
      final body =
          endIdx > migrateIdx ? src.substring(migrateIdx, endIdx) : src.substring(migrateIdx);
      // The legacy-only branch: pilot is null/empty AND legacy is non-empty.
      // (else branch on `pilot != null && pilot.isNotEmpty`)
      expect(
        body.contains('localStorage[_tenantKey] = legacy'),
        isTrue,
        reason: 'legacy-only sessions must migrate up to pilot.tenant_id',
      );
      // Idempotent — guard flag.
      expect(
        body.contains('_legacyMigrated'),
        isTrue,
        reason: 'helper must be idempotent via the _legacyMigrated guard',
      );
    });

    test('test_lazy_migration_on_first_read', () {
      // The tenantId getter must trigger the migration on first read
      // (before returning the value). Pre-fix nothing called the
      // helper, so drift sat undetected until logout. Lazy invocation
      // means the first read after page load — typically the wizard's
      // hasTenant check or the API tenant_id injection — fixes drift
      // before any decision is made on it.
      final getterIdx = src.indexOf('static String? get tenantId');
      expect(getterIdx, greaterThan(0),
          reason: 'PilotSession.tenantId getter must exist');
      final endIdx = src.indexOf('static ', getterIdx + 30);
      final body = src.substring(getterIdx, endIdx);
      expect(
        body.contains('migrateLegacyKey()'),
        isTrue,
        reason: 'tenantId getter must call migrateLegacyKey() lazily — '
            'first read of the session reconciles drift before any '
            'caller acts on the value.',
      );
      expect(
        body.contains('_legacyMigrated'),
        isTrue,
        reason: 'lazy invocation must guard on _legacyMigrated to avoid '
            'running the helper on every read.',
      );
    });
  });

  group('G-LEGACY-KEY-AUDIT — S.clear / setActiveScope contract', () {
    late String src;

    setUpAll(() {
      final f = File('lib/core/session.dart');
      expect(f.existsSync(), isTrue, reason: 'core/session.dart missing');
      src = f.readAsStringSync();
    });

    test('test_logout_clears_pilot_session', () {
      // S.clear() (called from app_providers.logout AND the 401
      // interceptor in api_service.dart) must call PilotSession.clear()
      // at the end. Pre-fix logout was asymmetric: only the legacy
      // apex_tenant_id was wiped, leaving pilot.tenant_id dirty → next
      // user inherits previous user's tenantId, silently bypassing
      // tenant-isolation guards on every pilot route.
      final clearIdx = src.indexOf('static void clear()');
      expect(clearIdx, greaterThan(0),
          reason: 'S.clear() must exist in core/session.dart');
      final clearEnd = src.indexOf('static String planAr()', clearIdx);
      final body = src.substring(clearIdx, clearEnd);
      expect(
        body.contains('PilotSession.clear()'),
        isTrue,
        reason: 'S.clear() must call PilotSession.clear() — every clear path '
            '(logout, 401 interceptor, future code) is correct without '
            'each caller having to remember.',
      );
    });

    test('test_set_active_scope_routes_through_pilot_session', () {
      // S.setActiveScope must route through PilotSession.tenantId /
      // entityId setters, NOT write localStorage directly. Pre-fix it
      // wrote only the legacy keys, bypassing the dual-key sync and
      // creating drift the moment the screens reading pilot.* were
      // touched.
      final setIdx = src.indexOf('static void setActiveScope(');
      expect(setIdx, greaterThan(0),
          reason: 'S.setActiveScope must exist');
      final endIdx = src.indexOf('static String? get token', setIdx);
      final body = src.substring(setIdx, endIdx);
      expect(
        body.contains('PilotSession.tenantId = tenant'),
        isTrue,
        reason: 'setActiveScope must write through PilotSession.tenantId '
            'setter so both keys stay in sync.',
      );
      expect(
        body.contains('PilotSession.entityId = entity'),
        isTrue,
        reason: 'setActiveScope must write through PilotSession.entityId '
            'setter for the same dual-key sync invariant.',
      );
    });

    test('test_saved_tenant_id_falls_back_to_pilot_key', () {
      // S.savedTenantId must read pilot.tenant_id BEFORE
      // apex_tenant_id. Pre-fix it read only the legacy key, so any
      // value written exclusively to pilot.* (e.g. by a setter that
      // hadn't yet propagated to the legacy mirror) was invisible to
      // the 20+ screens still on S.tenantId.
      final getterIdx = src.indexOf('static String? get savedTenantId');
      expect(getterIdx, greaterThan(0),
          reason: 'S.savedTenantId getter must exist');
      final endIdx =
          src.indexOf('static String? get savedEntityId', getterIdx);
      final body = src.substring(getterIdx, endIdx);
      expect(
        body.contains("'pilot.tenant_id'"),
        isTrue,
        reason: 'savedTenantId must check pilot.tenant_id first',
      );
      expect(
        body.contains("'apex_tenant_id'"),
        isTrue,
        reason: 'savedTenantId must still fall back to apex_tenant_id for '
            'pre-pilot sessions that wrote only the legacy key.',
      );
      // Verify pilot key appears BEFORE legacy key in the fallback chain.
      final pilotPos = body.indexOf("'pilot.tenant_id'");
      final legacyPos = body.indexOf("'apex_tenant_id'");
      expect(pilotPos < legacyPos, isTrue,
          reason: 'pilot.tenant_id must be checked BEFORE apex_tenant_id');
    });
  });
}
