import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'core/session.dart';

// Sprint-1 refactor: the root widget now lives in app/apex_app.dart.
// Re-exported so existing imports of `package:apex_finance/main.dart`
// that rely on `ApexApp` still resolve without source-level churn.
export 'app/apex_app.dart' show ApexApp;
import 'app/apex_app.dart' show ApexApp;

void main() {
  // Restore session from localStorage
  if (S.token == null) {
    final restored = S.restore();
    if (restored && S.token != null) {
      ApiService.setToken(S.token!);
    }
  }
  runApp(const ProviderScope(child: ApexApp()));
}
