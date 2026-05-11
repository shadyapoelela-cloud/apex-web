/// Cross-platform browser print stub. The real implementation is in
/// `browser_print_web.dart` (selected via conditional import on web).
///
/// G-CLEANUP-FINAL (2026-05-11): introduced to remove the unconditional
/// `dart:html` imports from sales/purchase invoice details screens.
/// Those imports broke non-web builds because the `if (kIsWeb)` guard
/// at the call site is too late — the import itself fails to compile
/// on non-web targets. The conditional-import-by-library pattern moves
/// the platform branch to the import statement so this stub is the
/// non-web fallback.
library;

void triggerBrowserPrint() {
  // No-op on non-web platforms. The web bundle gets the real
  // implementation via the conditional import below.
}
