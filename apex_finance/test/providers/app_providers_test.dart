/// G-AUTH-TENANT-PERSIST — regression tests for the tenant_id
/// persistence chain in `app_providers.dart` and the three auth
/// screens.
///
/// Why source-grep tests
/// ─────────────────────
/// `app_providers.dart` doesn't import `dart:html` directly, but
/// `core/session.dart` (and `pilot/session.dart`) do. Loading the
/// provider in a Dart-VM test would pull both transitively → the
/// G-T1.1 SDK mismatch on `package:web` 1.1.1 blocks the load.
/// Source-grep regression tests pin the contract that matters: the
/// shape of the persistence — `PilotSession.tenantId = …` reads
/// from `user['tenant_id']` and lives on the success branch of
/// every login + register call site.
///
/// A widget test would let us assert PilotSession.tenantId actually
/// updates after a mocked ApiService.login() — but the contract this
/// file pins is more important: the **persistence call** itself must
/// not regress. A dev who removes `PilotSession.tenantId = …` from
/// any auth flow re-introduces the original bug, and these tests
/// catch that.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-AUTH-TENANT-PERSIST — provider auth flows', () {
    late String src;

    setUpAll(() {
      final f = File('lib/providers/app_providers.dart');
      expect(f.existsSync(), isTrue, reason: 'provider file missing');
      src = f.readAsStringSync();
    });

    test('test_register_persists_tenant_id_to_pilot_session', () {
      // The register() method reads `user['tenant_id']` and assigns
      // it to PilotSession.tenantId. Removing this re-introduces the
      // bug chain: ERR-2 backend creates a tenant + JWT carries it,
      // but the wizard's hasTenant branch never fires → wizard falls
      // back to createTenant → second tenant → JWT mismatch → 404.
      final registerIdx = src.indexOf('Future<bool> register(');
      expect(registerIdx, greaterThan(0),
          reason: 'register() method must exist in app_providers.dart');
      final registerBody = src.substring(registerIdx, src.indexOf('void logout()', registerIdx));
      expect(
        registerBody.contains("user['tenant_id']"),
        isTrue,
        reason:
            'register() must read user[\'tenant_id\'] from the response. '
            'The backend (ERR-2 Phase 3, PR #169) auto-creates a '
            'tenant per registration and returns its id in the user blob.',
      );
      expect(
        registerBody.contains('PilotSession.tenantId = tenantId'),
        isTrue,
        reason:
            'register() must assign tenantId to PilotSession.tenantId. '
            'Without this the wizard\'s `if (PilotSession.hasTenant)` '
            'branch (G-WIZARD-TENANT-FIX, PR #180) never fires.',
      );
      expect(
        registerBody.contains('tenantId.isNotEmpty'),
        isTrue,
        reason:
            'persistence must be guarded by an isNotEmpty check — '
            'writing an empty string would set hasTenant=false (since '
            'PilotSession.hasTenant uses isNotEmpty) and silently '
            'break the wizard while LOOKING set.',
      );
    });

    test('test_login_persists_tenant_id_to_pilot_session', () {
      // Same contract as register, but for login. The legacy fallback
      // (a user who registered before ERR-2 Phase 3 and didn't get
      // migrated by PR #170) lands here without a tenant_id claim —
      // the `is String && isNotEmpty` guard handles it gracefully.
      final loginIdx = src.indexOf('Future<bool> login(');
      expect(loginIdx, greaterThan(0),
          reason: 'login() method must exist');
      final loginBody = src.substring(loginIdx, src.indexOf('Future<bool> register(', loginIdx));
      expect(
        loginBody.contains("user['tenant_id']"),
        isTrue,
        reason: 'login() must read user[\'tenant_id\']',
      );
      expect(
        loginBody.contains('PilotSession.tenantId = tenantId'),
        isTrue,
        reason: 'login() must persist tenantId to PilotSession',
      );
    });

    test('test_register_persists_roles', () {
      // Drift fix — login() set S.roles but register() didn't, so a
      // freshly-registered user had an empty role set until they
      // logged out and back in. This test catches re-introduction
      // of the same drift.
      final registerIdx = src.indexOf('Future<bool> register(');
      final registerBody = src.substring(registerIdx, src.indexOf('void logout()', registerIdx));
      expect(
        registerBody.contains("S.roles = List<String>.from(user['roles'] ?? [])"),
        isTrue,
        reason:
            'register() must set S.roles like login() does — the '
            'pre-fix drift bug let freshly-registered users walk '
            'around with empty roles until they re-logged.',
      );
    });

    test('test_logout_clears_pilot_session_tenant', () {
      // S.clear() wipes apex_tenant_id (legacy key) but leaves the
      // new pilot.tenant_id key untouched. Without
      // PilotSession.clear() the next user logging in on the same
      // browser inherits the previous user's tenantId — silently
      // bypassing tenant-isolation guards on every pilot route.
      final logoutIdx = src.indexOf('void logout()');
      expect(logoutIdx, greaterThan(0));
      final logoutBody = src.substring(
        logoutIdx,
        // logout() is short — read the next ~10 lines.
        (logoutIdx + 400) > src.length ? src.length : logoutIdx + 400,
      );
      expect(
        logoutBody.contains('S.clear()'),
        isTrue,
        reason: 'logout() must keep S.clear()',
      );
      expect(
        logoutBody.contains('PilotSession.clear()'),
        isTrue,
        reason:
            'logout() must call PilotSession.clear() — without it '
            'the new pilot.* localStorage keys persist across users '
            'and the next login inherits the previous tenantId.',
      );
    });

    test('test_marker_comment_preserved_for_future_archaeology', () {
      // The G-AUTH-TENANT-PERSIST comment block in app_providers.dart
      // documents the three-PR chain (ERR-2 → wizard-fix → this fix).
      // A future contributor tempted to "simplify" the persistence
      // must read this first.
      expect(
        src.contains('G-AUTH-TENANT-PERSIST'),
        isTrue,
        reason:
            'the rationale comment marker must remain in '
            'app_providers.dart — it links ERR-2 Phase 3 (the '
            'auto-tenant) → G-WIZARD-TENANT-FIX (the wizard\'s '
            'hasTenant branch) → this fix (the missing piece).',
      );
    });
  });

  group('G-AUTH-TENANT-PERSIST — auth screens', () {
    /// The same persistence logic must live in the three direct
    /// auth-screen call sites (the provider-level fix doesn't help
    /// users who land on these screens — the screens write S.*
    /// themselves rather than going through the provider).

    void _expectScreenPersistsTenant(String path, {required String name}) {
      final f = File(path);
      expect(
        f.existsSync(),
        isTrue,
        reason: '$name screen file missing — was it moved?',
      );
      final src = f.readAsStringSync();
      expect(
        src.contains('PilotSession'),
        isTrue,
        reason:
            '$name must import PilotSession to persist tenant_id — '
            'without it the screen writes S.* but skips PilotSession '
            'and the wizard\'s hasTenant branch never fires.',
      );
      expect(
        src.contains("['tenant_id']"),
        isTrue,
        reason:
            '$name must read [\'tenant_id\'] from the auth response',
      );
      expect(
        src.contains('PilotSession.tenantId = tenantId'),
        isTrue,
        reason:
            '$name must assign tenantId to PilotSession.tenantId on '
            'the auth-success branch.',
      );
      expect(
        src.contains('tenantId is String && tenantId.isNotEmpty'),
        isTrue,
        reason:
            '$name persistence must guard on `is String && isNotEmpty` — '
            'silent fallback for legacy users without a tenant_id claim, '
            'while still rejecting accidental empty strings.',
      );
      expect(
        src.contains('G-AUTH-TENANT-PERSIST'),
        isTrue,
        reason:
            '$name must keep the G-AUTH-TENANT-PERSIST marker comment '
            'so the rationale is visible to future readers.',
      );
    }

    test('test_login_screen_persists_tenant_id', () {
      _expectScreenPersistsTenant(
        'lib/screens/auth/login_screen.dart',
        name: 'login_screen.dart',
      );
    });

    test('test_register_screen_persists_tenant_id', () {
      _expectScreenPersistsTenant(
        'lib/screens/auth/register_screen.dart',
        name: 'register_screen.dart',
      );
    });

    test('test_slide_auth_screen_persists_tenant_id', () {
      _expectScreenPersistsTenant(
        'lib/screens/auth/slide_auth_screen.dart',
        name: 'slide_auth_screen.dart',
      );
    });
  });
}
