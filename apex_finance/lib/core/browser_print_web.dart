/// Web-only implementation of [triggerBrowserPrint]. Selected by the
/// conditional import in `browser_print.dart` consumers when
/// `dart.library.html` is available (i.e. the Flutter web bundle).
///
/// G-CLEANUP-FINAL (2026-05-11): see `browser_print.dart` for rationale.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerBrowserPrint() {
  // ignore: deprecated_member_use
  html.window.print();
}
