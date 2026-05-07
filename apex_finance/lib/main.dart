import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'core/session.dart';
import 'core/v5/v5_routing_validator.dart';
import 'core/v5/v5_wired_screens.dart'
    show v5WiredKeepAliveBaseline, v5WiredKeepAliveTouch;

// Sprint-1 refactor: the root widget now lives in app/apex_app.dart.
// Re-exported so existing imports of `package:apex_finance/main.dart`
// that rely on `ApexApp` still resolve without source-level churn.
export 'app/apex_app.dart' show ApexApp;
import 'app/apex_app.dart' show ApexApp;

Future<void> main() async {
  // G-CLEANUP-2 (Sprint 15): main is now async because we await a
  // backend round-trip to validate any restored token before trusting
  // it. WidgetsFlutterBinding.ensureInitialized() is required when
  // main is async per Flutter convention.
  WidgetsFlutterBinding.ensureInitialized();

  // Restore session from localStorage.
  if (S.token == null) {
    final restored = S.restore();
    if (restored && S.token != null) {
      ApiService.setToken(S.token!);

      // G-CLEANUP-2 (Sprint 15): a non-null token in localStorage from
      // a previous session is NOT enough — it might be expired (60-min
      // access-token lifetime per app/phase1/services/auth_service.py:46)
      // or signed by a rotated JWT_SECRET. Validate against the backend
      // before trusting it. On any failure, clear the token so the
      // GoRouter auth guard (lib/core/auth_guard.dart) redirects the
      // user to /login.
      //
      // The operator's directive (file 39 § 5): bare-URL visitors must
      // land on /login, not on /app with a stale session. This async
      // probe is the mechanism that delivers that promise.
      //
      // Fail-closed: if validation can't reach the backend (network
      // error, timeout, etc.), we treat the token as invalid and
      // redirect to /login. Better to over-redirect than to under-
      // redirect.
      //
      // See APEX_BLUEPRINT/09 § 20.1 G-CLEANUP-2.
      final isValid = await ApiService.validateToken();
      if (!isValid) {
        S.clear();
        ApiService.clearToken();
      }
    }
  }

  if (kDebugMode) validatePins();

  // G-TREESHAKE-FIX (2026-05-07): touch every widget class that's
  // reachable only through the v5WiredScreens Map. The runtime index
  // (`DateTime.now().microsecond % baseline`) ensures dart2js cannot
  // prove which switch arm in `v5WiredKeepAliveTouch` is taken, so it
  // must keep all 12 widget classes. The print of `runtimeType`
  // consumes the return value so the call itself is not elidable.
  // See v5_wired_screens.dart for the full bug history.
  final keepAliveIdx =
      DateTime.now().microsecond % v5WiredKeepAliveBaseline;
  final keepAlive = v5WiredKeepAliveTouch(keepAliveIdx);
  // ignore: avoid_print
  print('apex: V5 keep-alive ${keepAlive.runtimeType}');

  runApp(const ProviderScope(child: ApexApp()));
}
