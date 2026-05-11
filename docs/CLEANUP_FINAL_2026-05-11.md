# G-CLEANUP-FINAL — Four polish fixes bundled

**Date:** 2026-05-11
**Severity:** low (no user-visible regressions, mixed correctness + maintainability)
**Branch:** `feat/g-cleanup-final`

## Problem

QA review of recent invoice-details work flagged four small but real issues that bundled nicely into a single polish PR:

1. **ZATCA QR rendered on cancelled sales invoices.** The gate `(inv['status'] ?? '') != 'draft'` accepted `cancelled` as a "post-issuance" state, so a QR was rendered for an invoice that had been reversed. A ZATCA QR claims a transaction occurred, so showing one on a cancelled invoice is misleading.
2. **Unconditional `dart:html` import broke non-web builds.** Both `sales_invoice_details_screen.dart` and `purchase_invoice_details_screen.dart` had `import 'dart:html' as html;` at the top of the file. The `if (kIsWeb)` guard at the call site is too late — the import itself fails to compile on non-web targets. Today the project only ships a web bundle, but native builds (mobile, desktop) cannot even start the analyzer.
3. **Duplicate `/setup` GoRoute registration.** `lib/core/router.dart` registered `GoRoute(path: '/setup', redirect: ...)` twice (lines ~279 and ~689) pointing to the same target. Functionally harmless (go_router uses the first match) but dead code that confuses readers.
4. **`pilotPostPosToGL` orphan.** `lib/api_service.dart` defines `pilotPostPosToGL` but no code in `lib/screens/` calls it. Sibling work on `feat/g-pos-backend-integration-v2` will wire it up — without a doc-comment, a future reader could reasonably delete it.

## Solution

### Fix 1 — Status-aware ZATCA QR gate

`apex_finance/lib/screens/operations/sales_invoice_details_screen.dart` → `_buildQrCode`:

Before:

```dart
final issued = (inv['status'] ?? '') != 'draft';
```

After:

```dart
final status = (inv['status'] ?? '').toString();
final issued = status == 'issued' ||
               status == 'partially_paid' ||
               status == 'paid';
```

The hint shown for non-issued states is now status-aware. Cancelled invoices show `(فاتورة ملغاة)` instead of `(بعد الإصدار)` so the user immediately understands why no QR is rendered. All other non-issued statuses (draft, etc.) keep the original `(بعد الإصدار)` hint.

### Fix 2 — Conditional `dart:html` import

The standard Dart conditional-import-by-library pattern moves the platform branch from the call site (too late — the import has already failed) to the import statement itself.

New file `apex_finance/lib/core/browser_print.dart` (default, non-web stub):

```dart
void triggerBrowserPrint() {
  // No-op on non-web platforms.
}
```

New file `apex_finance/lib/core/browser_print_web.dart` (web-only, selected when `dart.library.html` resolves):

```dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerBrowserPrint() {
  // ignore: deprecated_member_use
  html.window.print();
}
```

Both invoice details screens replaced the direct `import 'dart:html' as html;` with:

```dart
import '../../core/browser_print.dart'
    if (dart.library.html) '../../core/browser_print_web.dart';
```

…and the call site changed from `html.window.print()` to `triggerBrowserPrint()`. The `kIsWeb` guard is retained as defence-in-depth even though the stub is already a no-op on non-web.

### Fix 3 — Single canonical `/setup` route

`apex_finance/lib/core/router.dart`:

- The first registration (around line 280, kept) now carries the breadcrumb comment `// Single canonical /setup → /settings/entities redirect. A duplicate at line ~689 was removed in G-CLEANUP-FINAL (2026-05-11).`
- The duplicate at line ~689 is deleted, replaced with the breadcrumb `// G-CLEANUP-FINAL (2026-05-11): duplicate /setup GoRoute removed — see line ~280 for the canonical one.`
- `/setup/entity` (a different route, redirecting to the same target) is untouched.

### Fix 4 — Document `pilotPostPosToGL` rather than remove

`apex_finance/lib/api_service.dart` adds a doc-comment above `pilotPostPosToGL` explaining it is deliberately kept for the in-flight `G-POS-BACKEND-INTEGRATION-V2` work, which will alias it as `pilotPostPosTransactionToGl`. Removal would create avoidable churn between this branch and the sibling branch.

## Files Touched

| File | Change |
| --- | --- |
| `apex_finance/lib/screens/operations/sales_invoice_details_screen.dart` | QR whitelist gate + cancelled hint + conditional import + `triggerBrowserPrint()` |
| `apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart` | Conditional import + `triggerBrowserPrint()` |
| `apex_finance/lib/core/router.dart` | Duplicate `/setup` GoRoute removed + breadcrumb |
| `apex_finance/lib/api_service.dart` | Doc-comment above `pilotPostPosToGL` |
| `apex_finance/lib/core/browser_print.dart` | **NEW** — non-web stub |
| `apex_finance/lib/core/browser_print_web.dart` | **NEW** — web implementation |
| `apex_finance/test/screens/cleanup_final_test.dart` | **NEW** — 11 source-grep regression tests |
| `apex_finance/test/screens/sales_invoice_ux_followup_test.dart` | Updated `test_print_button_uses_kIsWeb_guard` to expect `triggerBrowserPrint()` |

## Verification

- `flutter analyze lib/screens/operations/sales_invoice_details_screen.dart lib/screens/operations/purchase_invoice_details_screen.dart lib/core/router.dart lib/core/browser_print.dart lib/core/browser_print_web.dart lib/api_service.dart` — clean, 0 issues.
- `flutter test test/screens/cleanup_final_test.dart` — 11/11 pass.
- `flutter test test/screens/` — 195/195 pass (no regressions, including `sales_invoice_ux_test.dart`, `purchase_invoice_multiline_parity_test.dart`, `entity_seller_info_test.dart`).

## Out of Scope

- POS files (only the doc-comment on `pilotPostPosToGL` was touched).
- Sales/purchase CREATE screens.
- Payment modals.
- Backend routes/schemas.
- The `pilotPostPosToGL` method is intentionally kept — the sibling task on `feat/g-pos-backend-integration-v2` will wire it.
