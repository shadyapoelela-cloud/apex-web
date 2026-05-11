# POS Multi-line + Legacy Vendor Payment Cleanup

**Status:** in force as of 2026-05-11.
**Closes:** GAP-2, GAP-11, GAP-12 — the **last three** items from the
Finance Module integration audit. With this PR landed, the original
6-gap audit + 6 follow-up gaps are all resolved.

---

## What this PR ships

### 🟢 GAP-2 — POS Quick Sale multi-line (`pos_quick_sale_screen.dart`)

Pre-fix: `'lines': [{...}]` was hard-coded to a single line with
`quantity: 1` and a free-text description field. The cashier could
ring up only one item per sale and lost all inventory deduction
tracking because no product reference was sent.

Now: `_PosLineDraft` class (mirroring `_LineDraft` from sales and
`_PiLineDraft` from purchase) — `desc` / `qty` / `unitPrice` /
`vatRate` per-line controllers + a `product` slot for picker
selections. `List<_PosLineDraft> _lines = [_PosLineDraft()]` starts
with one empty line; `_addLine()` and `_removeLine(index)` mirror the
sales/purchase patterns with `if (_lines.length <= 1) return;` guard.

Each line card embeds `ProductPickerOrCreate`, auto-filling
description + unit price from the picker selection (`list_price` or
`default_price`). Live per-line totals on each card, a separate
totals card below the line list (subtotal / VAT / grand-total), all
computed reactively via `_lines.fold`.

Payload now serialises every line: `quantity` / `unit_price` /
`vat_rate` + optional `product_id` / `sku` references when a product
was picked. Matches the existing sales-invoice line shape since POS
posts through `pilotCreateSalesInvoice` + `pilotIssueSalesInvoice`.

After a successful sale the form resets to a single empty line so the
cashier can start the next sale without manually clearing fields.
The receipt card (with ZATCA QR from PR #192) keeps working — it
reads pre-captured `capturedSubtotal` / `capturedVat` / `capturedTotal`
from `_lastReceipt` and now also displays the line count
(`${r['line_count']} بند`).

### 🟢 GAP-11 — Test brittleness from PR #190 fixed

`test_details_has_cancel_edit_print_and_je_link` in
[`purchase_invoice_multiline_parity_test.dart`](../apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart)
used a literal `\n` in its substring assertion. On Windows, `git
checkout`'s autocrlf converts the file to CRLF, so the substring no
longer matched. The test now uses `RegExp(... r'\s*' ...)` so it
passes regardless of line-ending convention.

This was a bug I introduced in PR #190. The fix is one regex
substitution; functionality was never affected.

### 🟢 GAP-12 — Legacy `VendorPaymentScreen` archived

The old `VendorPaymentScreen` at `/purchase/payment/:billId` had been
superseded by the `VendorPaymentModal` flow in PR #191 (modal opened
from the purchase-invoice details screen). The legacy screen wasn't
reachable via `context.go(...)` anywhere in the codebase but still
existed in:
- The router (`/purchase/payment/:billId` GoRoute)
- The V5 chip mapping (`erp/purchasing/payment` → `VendorPaymentScreen(billId: '')`)

Both pointed at a screen that, when reached via the V5 chip with an
empty `billId`, would attempt a payment against no invoice and fail
silently.

This PR:
- `git mv`'s the file to `apex_finance/_archive/2026-05-11/legacy_vendor_payment_screen/` so blame + history are preserved.
- Comments-out the router import + removes the GoRoute, leaving a breadcrumb that explains where the file went and why.
- Retargets the V5 chip to `PurchaseInvoicesScreen` (the bills list) — tapping a bill row now opens its details, where the user records a payment via the modal.

---

## Files changed

| File | Change |
|---|---|
| [`apex_finance/lib/screens/operations/pos_quick_sale_screen.dart`](../apex_finance/lib/screens/operations/pos_quick_sale_screen.dart) | Full rewrite — `_PosLineDraft`, list-based UI, `ProductPickerOrCreate` per line, live totals, multi-line payload, form reset on submit |
| [`apex_finance/lib/core/router.dart`](../apex_finance/lib/core/router.dart) | Removed `/purchase/payment/:billId` route + VendorPaymentScreen import |
| [`apex_finance/lib/core/v5/v5_wired_screens.dart`](../apex_finance/lib/core/v5/v5_wired_screens.dart) | Retargeted `erp/purchasing/payment` chip to `PurchaseInvoicesScreen` |
| `apex_finance/lib/screens/operations/vendor_payment_screen.dart` → `apex_finance/_archive/2026-05-11/legacy_vendor_payment_screen/vendor_payment_screen.dart` | `git mv` archive |
| [`apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart`](../apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart) | GAP-11 — RegExp instead of literal `\n` for CRLF compat |
| [`apex_finance/test/screens/pos_zatca_qr_test.dart`](../apex_finance/test/screens/pos_zatca_qr_test.dart) | Adapted to renamed `capturedVat`/`capturedTotal` variables |
| [`apex_finance/test/screens/pos_multiline_cleanup_test.dart`](../apex_finance/test/screens/pos_multiline_cleanup_test.dart) | **NEW** — 10 source-grep contracts |

## Test coverage

10 tests in [`pos_multiline_cleanup_test.dart`](../apex_finance/test/screens/pos_multiline_cleanup_test.dart):

| Group | Tests |
|---|---|
| GAP-2 POS multi-line | 7 (`_PosLineDraft` class, one-line init, add/remove guard, payload serialisation, ProductPicker integration, grand totals fold, form reset) |
| GAP-12 Legacy cleanup | 3 (file archived, router no longer imports/routes, V5 chip retargeted) |

All 10 pass. Combined with the four prior finance test suites
(`sales_invoice_multiline_prefill_test`,
`purchase_invoice_multiline_parity_test`,
`purchase_payment_completion_test`, `pos_zatca_qr_test`) the entire
finance regression suite is **51/51** with `flutter analyze` clean on
touched files.

## Manual UAT (after deploy)

Pre-conditions: existing customer (CUST-001), product PRD-001.

1. Navigate to `/pos/quick-sale`. **Expect**: empty line card with
   picker / desc / qty=1 / empty price / VAT=15%.
2. Pick PRD-001 → **expect**: description + price auto-fill; line
   total computes; subtotal/VAT/grand-total card below updates.
3. Click **+ إضافة بند** → second empty card appears.
4. Pick a different product on line 2 → totals card updates.
5. Remove line 2 with 🗑 → only one line remains, button disabled.
6. Choose payment method (e.g. مدى).
7. Click **سجّل البيع** → success snackbar + receipt card appears with
   ZATCA QR (Phase 1) + invoice number + line count + JE link.
8. Form auto-resets to one empty line for the next sale.
9. Navigate to `/app/erp/finance/purchase-bills` → click a posted
   bill row → in the details screen, click **+ تسجيل دفع** → modal
   opens (PR #191). **Expect**: `/purchase/payment/:billId` no longer
   reachable — that legacy route is gone.

## End of Finance Module integration audit

This PR closes the last three items from the QA tester's reports.
Final tally:

| Original audit (6 gaps) | Status |
|---|---|
| GAP-1 Purchase multi-line | ✅ PR #190 |
| GAP-2 POS multi-line | ✅ **This PR** |
| GAP-3 Purchase Details Screen | ✅ PR #190 |
| GAP-4 POS ZATCA QR | ✅ PR #192 |
| GAP-5 Vendor Payment parity | ✅ PR #191 |
| GAP-6 ProductPicker on purchase | ✅ PR #190 |

| Follow-up gaps (6 discovered during testing) | Status |
|---|---|
| GAP-7 No "+ تسجيل دفع" on purchase details | ✅ PR #191 |
| GAP-8 No payment history on purchase details | ✅ PR #191 |
| GAP-9 Backend `get_pi` missing `payments[]` | ✅ PR #191 |
| GAP-10 VendorPayment `notes` field unused | ✅ PR #191 |
| GAP-11 CRLF/LF test brittleness | ✅ **This PR** |
| GAP-12 Legacy VendorPaymentScreen still wired | ✅ **This PR** |

| Bookmarked for future sprints | Status |
|---|---|
| GAP-DEFER-1 Real seller VAT from entity settings API | bookmarked → G-ENTITY-SELLER-INFO |
| Camera barcode scanner | bookmarked → hardware sprint |
| CODE128 internal barcode | bookmarked → hardware sprint |
| Dedicated print template | bookmarked (low priority) |
