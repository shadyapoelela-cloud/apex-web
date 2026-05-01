/// G-S2 (2026-05-01): pure auth-guard logic, isolated from `session.dart`.
///
/// Why a separate file?
/// `session.dart` imports `dart:html` at the top level, so anything that
/// imports it transitively cannot be unit-tested on the Dart VM (flutter
/// test). G-T1.1 tracks the broader `package:web` 1.1.1 vs Flutter 3.27.4
/// blocker. To keep the auth guard testable today, we accept a `token`
/// argument here and let `router.dart` plug `S.token` in at the call site.
library;

/// Returns the path the navigator should redirect to, or `null` to stay
/// on the current path.
///
/// Rules (G-S2):
///   - `/login`, `/register`, `/forgot-password*` are always allowed,
///     regardless of token state. We deliberately do NOT bounce logged-in
///     users off these — `SlideAuthScreen` does its own post-login
///     navigation, and an extra bounce here would collide with it and
///     produce a `/login` ⇄ `/app` redirect loop (the v5_routes.dart
///     `/login → /app` override that this gap removed).
///   - Any other path with a null/empty token is forced to `/login`.
///
/// `token` is whatever the session layer reports right now.
/// `path` is `state.uri.path` from `GoRouterState`.
String? authGuardRedirect({required String path, required String? token}) {
  final isAuthPath = path == '/login' ||
      path == '/register' ||
      path.startsWith('/forgot-password');
  if (isAuthPath) return null;
  if (token == null || token.isEmpty) return '/login';
  return null;
}
