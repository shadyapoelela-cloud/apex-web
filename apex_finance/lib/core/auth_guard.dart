/// G-S2 (2026-05-01) + ERR-1 (2026-05-07): pure auth-guard logic plus
/// the cross-layer events the app uses to react to session expiry.
///
/// Why a separate file?
/// `session.dart` imports `dart:html` at the top level, so anything
/// that imports it transitively cannot be unit-tested on the Dart VM
/// (flutter test). G-T1.1 tracks the broader `package:web` 1.1.1 vs
/// Flutter 3.27.4 blocker. To keep the auth guard testable today, we
/// accept a `token` argument here and let `router.dart` plug `S.token`
/// in at the call site.
///
/// The `apexAuthRefresh` ValueNotifier and `apexScaffoldMessengerKey`
/// declared here are the cross-cutting hooks the 401 interceptor in
/// `api_service.dart` uses to (a) re-trigger GoRouter's redirect
/// evaluation and (b) surface the "session expired" SnackBar from
/// outside the widget tree. Both are platform-agnostic
/// (`flutter/foundation` + `flutter/widgets`) and don't drag in
/// `dart:html`, so unit tests still load.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show ScaffoldMessengerState;

/// Bumped by the 401 interceptor (api_service.dart) after the session
/// is cleared. `appRouter` listens via `refreshListenable`, so a bump
/// causes GoRouter to re-evaluate `authGuardRedirect` immediately —
/// the user is bounced to `/login` without waiting for the next
/// navigation event.
final ValueNotifier<int> apexAuthRefresh = ValueNotifier<int>(0);

/// Global ScaffoldMessenger key, attached to MaterialApp.router in
/// `app/apex_app.dart`. Lets the 401 interceptor show a SnackBar from
/// `api_service.dart` without holding a BuildContext.
final GlobalKey<ScaffoldMessengerState> apexScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Returns the path the navigator should redirect to, or `null` to
/// stay on the current path.
///
/// Rules:
///   - `/login`, `/register`, `/forgot-password*` are always allowed,
///     regardless of token state. We deliberately do NOT bounce
///     logged-in users off these — `SlideAuthScreen` does its own
///     post-login navigation, and an extra bounce here would collide
///     with it and produce a `/login` ⇄ `/app` redirect loop (the
///     v5_routes.dart `/login → /app` override that this gap
///     removed).
///   - Any other path with a null/empty token is forced to
///     `/login?return_to=<encoded original path>` so the login
///     screen can send the user back where they were after auth
///     (ERR-1). The path is URL-encoded; the login screen
///     percent-decodes before navigating.
///
/// `token` is whatever the session layer reports right now.
/// `path` is `state.uri.path` from `GoRouterState`.
String? authGuardRedirect({required String path, required String? token}) {
  final isAuthPath = path == '/login' ||
      path == '/register' ||
      path.startsWith('/forgot-password');
  if (isAuthPath) return null;
  if (token == null || token.isEmpty) {
    final encoded = Uri.encodeComponent(path);
    return '/login?return_to=$encoded';
  }
  return null;
}

/// Returns the in-app path the login screen should navigate to after
/// a successful authentication, given the current URL's `return_to`
/// query parameter.
///
/// Defaults to `/home` when no parameter is present, when the
/// parameter is empty, or when the parameter looks unsafe (anything
/// not starting with a single `/`, including `//external.com` and
/// absolute URLs). The single-slash check is what blocks
/// open-redirect attacks via crafted `?return_to=https://evil.com`.
String resolvePostLoginDestination(String? rawReturnTo) {
  if (rawReturnTo == null || rawReturnTo.isEmpty) return '/home';
  final decoded = Uri.decodeComponent(rawReturnTo);
  // Must be an in-app path: starts with `/` and doesn't start with
  // `//` (which the URL parser would interpret as a protocol-relative
  // URL pointing at another host).
  if (!decoded.startsWith('/') || decoded.startsWith('//')) return '/home';
  return decoded;
}
