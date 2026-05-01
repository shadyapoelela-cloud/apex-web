/// G-S2: tests for the global auth-guard redirect logic.
///
/// We test `authGuardRedirect` directly (a pure function) instead of
/// driving GoRouter end-to-end, because GoRouter pulls `router.dart` →
/// `session.dart` → `dart:html`, which is the same blocker that prevents
/// screen-level widget tests today (tracked as G-T1.1). The guard logic
/// itself lives in `lib/core/auth_guard.dart` for exactly this reason.
///
/// Cases covered (matches the gap acceptance criteria):
///   1. Visit /app with no token → redirected to /login.
///   2. Visit /login with no token → no redirect (no /login ⇄ /app loop,
///      which was the v5_routes.dart sub-bug).
///   3. Visit /app with a token in session → no redirect (stays on /app).
///   plus a few belt-and-suspenders cases for /register, /forgot-password,
///   nested protected paths, and empty-string tokens.
library;

import 'package:apex_finance/core/auth_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authGuardRedirect (G-S2)', () {
    test('protected path with no token → /login', () {
      final r = authGuardRedirect(path: '/app', token: null);
      expect(r, '/login',
          reason: 'an anonymous visit to /app must be forced to login');
    });

    test('/login with no token → no redirect (no loop)', () {
      final r = authGuardRedirect(path: '/login', token: null);
      expect(r, isNull,
          reason: 'the v5_routes.dart /login → /app override produced a loop; '
              'the guard must let /login render so SlideAuthScreen can show.');
    });

    test('protected path with token → no redirect (stays)', () {
      final r = authGuardRedirect(path: '/app', token: 'fake-jwt-xyz');
      expect(r, isNull,
          reason: 'logged-in users must stay on the path they navigated to');
    });

    test('/register and /forgot-password are always allowed', () {
      expect(authGuardRedirect(path: '/register', token: null), isNull);
      expect(authGuardRedirect(path: '/forgot-password', token: null), isNull);
      expect(
          authGuardRedirect(path: '/forgot-password/reset', token: null), isNull,
          reason: 'sub-paths under /forgot-password (e.g. reset confirm) '
              'must also bypass the guard');
    });

    test('logged-in users on auth paths are NOT bounced (deliberate)', () {
      // SlideAuthScreen does its own post-login navigation; bouncing here
      // would collide with that. See auth_guard.dart docstring.
      expect(authGuardRedirect(path: '/login', token: 'fake-jwt'), isNull);
      expect(authGuardRedirect(path: '/register', token: 'fake-jwt'), isNull);
    });

    test('empty-string token is treated as unauthenticated', () {
      // session.dart's `S.token` getter returns null when the localStorage
      // value is an empty string, but defending here too prevents future
      // refactors from silently breaking the guard.
      expect(authGuardRedirect(path: '/app', token: ''), '/login');
    });

    test('nested protected paths also redirect', () {
      expect(authGuardRedirect(path: '/app/dashboard', token: null), '/login');
      expect(
          authGuardRedirect(path: '/settings/entities', token: null), '/login');
    });
  });
}
