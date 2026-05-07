/// ERR-1 (2026-05-07) — Session redirect on 401.
///
/// Tests for the pure auth-guard logic and the post-login destination
/// resolver. Both functions in `auth_guard.dart` are deliberately
/// dart:html-free, so this file runs cleanly on the Dart VM
/// (`flutter test`) without the package:web SDK-mismatch blocker that
/// affects screen-level widget tests.
///
/// What is NOT tested here (deliberately):
///   - `_SessionExpiryHandler` lives in `api_service.dart`, which
///     transitively imports `dart:html` via `session.dart`. That
///     handler is exercised through integration tests and live UAT
///     instead.
///   - `apexAuthRefresh` notifier wiring — verified by router smoke
///     tests in production builds.
library;

import 'package:apex_finance/core/auth_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ERR-1 authGuardRedirect — auth-flow paths bypass', () {
    test('null token allows /login to render', () {
      expect(authGuardRedirect(path: '/login', token: null), isNull);
    });

    test('null token allows /register to render', () {
      expect(authGuardRedirect(path: '/register', token: null), isNull);
    });

    test('null token allows /forgot-password to render', () {
      expect(authGuardRedirect(path: '/forgot-password', token: null), isNull);
    });

    test('null token allows /forgot-password/reset (subpath) to render', () {
      expect(
        authGuardRedirect(path: '/forgot-password/reset', token: null),
        isNull,
      );
    });

    test('valid token also leaves auth paths alone (no /login bounce loop)', () {
      // Critical: if this redirected, we'd ping-pong between /login and
      // /app forever after a successful login. SlideAuthScreen handles
      // post-login navigation explicitly.
      expect(
        authGuardRedirect(path: '/login', token: 'eyJ0eXAi…'),
        isNull,
      );
    });
  });

  group('ERR-1 authGuardRedirect — protected paths', () {
    test('null token on /app/erp/finance/ar-aging redirects with return_to', () {
      final r = authGuardRedirect(
        path: '/app/erp/finance/ar-aging',
        token: null,
      );
      expect(r, isNotNull);
      expect(r, startsWith('/login?return_to='));
      // The encoded path must round-trip cleanly back to the original.
      final encoded = r!.substring('/login?return_to='.length);
      expect(Uri.decodeComponent(encoded), '/app/erp/finance/ar-aging');
    });

    test('empty-string token treated as no token', () {
      final r = authGuardRedirect(path: '/app', token: '');
      expect(r, '/login?return_to=%2Fapp');
    });

    test('valid token allows protected path through', () {
      expect(
        authGuardRedirect(
          path: '/app/erp/finance/vat-return',
          token: 'eyJ0eXAi…',
        ),
        isNull,
      );
    });

    test('special chars in path are percent-encoded in return_to', () {
      // Slashes and the quirky chars an in-app path can contain.
      final r = authGuardRedirect(
        path: '/app/erp/finance/sales-customers',
        token: null,
      );
      expect(r, '/login?return_to=%2Fapp%2Ferp%2Ffinance%2Fsales-customers');
    });
  });

  group('ERR-1 resolvePostLoginDestination', () {
    test('null return_to falls back to /home', () {
      expect(resolvePostLoginDestination(null), '/home');
    });

    test('empty return_to falls back to /home', () {
      expect(resolvePostLoginDestination(''), '/home');
    });

    test('valid percent-encoded in-app path is decoded and returned', () {
      expect(
        resolvePostLoginDestination('%2Fapp%2Ferp%2Ffinance%2Far-aging'),
        '/app/erp/finance/ar-aging',
      );
    });

    test('protocol-relative URL (open-redirect attempt) is rejected', () {
      // `//evil.example` would be parsed as a protocol-relative URL by
      // the browser, sending the user offsite. Must fall back to /home.
      expect(resolvePostLoginDestination('//evil.example/x'), '/home');
      expect(
        resolvePostLoginDestination(Uri.encodeComponent('//evil.example/x')),
        '/home',
      );
    });

    test('absolute URL (open-redirect attempt) is rejected', () {
      expect(
        resolvePostLoginDestination(Uri.encodeComponent('https://evil.example/')),
        '/home',
      );
    });

    test('path without leading slash is rejected', () {
      expect(resolvePostLoginDestination('app/foo'), '/home');
      expect(resolvePostLoginDestination(Uri.encodeComponent('app/foo')), '/home');
    });

    test('round-trips with authGuardRedirect output', () {
      // Whatever authGuardRedirect emits as return_to must be
      // accepted by resolvePostLoginDestination — this is the ERR-1
      // contract that closes the user-visible loop.
      final r = authGuardRedirect(
        path: '/app/erp/finance/vat-return',
        token: null,
      )!;
      final encoded = r.substring('/login?return_to='.length);
      expect(
        resolvePostLoginDestination(encoded),
        '/app/erp/finance/vat-return',
      );
    });
  });

  group('ERR-1 cross-cutting hooks', () {
    test('apexAuthRefresh notifier exists and starts at 0', () {
      expect(apexAuthRefresh.value, 0);
    });

    test('apexScaffoldMessengerKey is a valid GlobalKey instance', () {
      // currentState is null until the MaterialApp mounts in a real
      // app, but the key itself must exist for api_service to import.
      expect(apexScaffoldMessengerKey, isNotNull);
    });
  });
}
