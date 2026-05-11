# Purchase Invoice — Multi-line + Details Screen + Row-Click Fix

**Status:** in force as of 2026-05-11.
**Closes:** GAP-1, GAP-3, GAP-6 (and partially GAP-2 — see below) from the
post-PR-#189 QA integration audit.

---

## Why this PR exists

The QA report on PR #189 flagged that the multi-line + prefill + ProductPicker
+ stock-badge improvements shipped only on the **sales** side. The purchase
side was left behind with:

- Single-line invoice (hard-coded `qty=1`, no per-line variant tracking, plain
  text description)
- No `ProductPickerOrCreate` integration (so server-side product search +
  stock badge + barcode lookup were not reachable from the purchase flow)
- No purchase-invoice details screen — clicking a bill row jumped straight to
  the JE-builder (the exact Bug-#1 pattern that was already fixed for sales)
- No cancel endpoint backend-side, no Edit/Cancel/Print buttons frontend-side

This PR ports the sales pattern to purchase with the same shape so the two
flows behave identically.

## What this PR ships

### 🟢 Multi-line purchase invoices

`PurchaseInvoiceCreateScreen` is rewritten from a single-line form to a list
of `_PiLineDraft` objects. Each line carries its own controllers (`desc`,
`qty`, `unitCost`, `vatRate`), a product slot, and a remove button (disabled
when only one line remains so the form is never empty).

Live per-line totals are computed reactively; the screen footer shows
subtotal / VAT / shipping / grand-total across all lines.

The payload now sends `lines: [{description, qty, unit_cost, vat_rate_pct,
vat_code, [variant_id], [sku]}]` matching `PiLineInput` in
`app/pilot/schemas/purchasing.py:247`.

### 🟢 Edit pre-fill

The screen now takes a `prefillBillId` constructor param. When set (via
`?bill_id=` query param on the route), the screen fetches
`GET /pilot/purchase-invoices/{id}` on init and hydrates vendor + dates +
lines.

For non-draft bills the form **locks** (`AbsorbPointer` wrapping inputs) and
shows a banner directing the user to the details screen — editing a posted
bill mid-flight would diverge from the GL.

Router-side: a new `GoRoute('/app/erp/finance/purchase-invoice-create')`
reads `s.uri.queryParameters['bill_id']`. The existing
`/app/erp/finance/purchase-bills/new` still handles the fresh-create case.

### 🟢 ProductPickerOrCreate now reachable from purchase

Each line card embeds `ProductPickerOrCreate`. The picker auto-fills the
line's description and unit-cost (from `default_cost` or `list_price`) when
a product is selected. All the benefits that sales got in PR #189 — server-
side debounced search, sequence-token cancellation, stock badge in dropdown,
barcode-scan path — are now available on purchase too.

### 🟢 Purchase Invoice Details Screen

Brand-new `PurchaseInvoiceDetailsScreen` mirrors the sales version. Header
with PI number + status badge + vendor + dates, lines table, totals footer
(subtotal / VAT / shipping / total / paid / remaining), JE banner with
"عرض القيد" link, and an action row with Edit (draft only) / Cancel /
Print buttons.

Same Bug-A scroll fix as sales: explicit `ScrollController` +
`PrimaryScrollController.none` + `AlwaysScrollableScrollPhysics` so the inner
scroll never competes with the outer `ApexMagneticShell` scroll system.

### 🟢 Bug-#1 parity — row click opens details

`_openInvoice` in `purchase_invoices_screen.dart` previously did:

```dart
final jeId = inv['journal_entry_id'] as String?;
if (jeId != null) {
  context.go('/app/erp/finance/je-builder/$jeId');
}
```

That's the exact pattern Bug-#1 on the sales side flagged in the UAT report —
the user lost access to lines / totals / payments by being routed straight
to the JE-builder. The fix routes to the new details screen instead. The
JE-builder is reachable only via the explicit "عرض القيد" button on details.

### 🟢 Backend `/pilot/purchase-invoices/{id}/cancel`

Mirrors the sales cancel endpoint. Moves PI → `cancelled`. If a JE was
already posted (status=`posted`), reverses it via
`gl_engine.reverse_journal_entry` so the GL stays balanced. Refuses (409)
when any vendor payment was applied or when the PI is already paid.

### What's still deferred to G-POS-MULTILINE-ZATCA

| Item | Why |
|---|---|
| POS Quick Sale multi-line | bigger refactor — POS receipt UX is its own surface |
| ZATCA QR on POS receipts | depends on POS multi-line landing first |
| VendorPaymentScreen modal parity | separate sprint G-VENDOR-PAYMENT-PARITY |

---

## Files changed

| File | Change |
|---|---|
| [`apex_finance/lib/screens/operations/purchase_invoice_create_screen.dart`](../apex_finance/lib/screens/operations/purchase_invoice_create_screen.dart) | Full rewrite — `_PiLineDraft` class, list-based UI, ProductPicker per line, pre-fill flow, lock-on-non-draft |
| [`apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart`](../apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart) | **NEW** — mirrors sales details (header / lines / totals / JE banner / actions) |
| [`apex_finance/lib/screens/operations/purchase_invoices_screen.dart`](../apex_finance/lib/screens/operations/purchase_invoices_screen.dart) | `_openInvoice` routes to details, not je-builder (Bug-#1 parity) |
| [`apex_finance/lib/api_service.dart`](../apex_finance/lib/api_service.dart) | `pilotGetPurchaseInvoice` + `pilotCancelPurchaseInvoice` methods |
| [`apex_finance/lib/core/router.dart`](../apex_finance/lib/core/router.dart) | `/purchase-invoice-create` (with `?bill_id=`) + `/purchase-bills/:billId` routes |
| [`app/pilot/routes/purchasing_routes.py`](../app/pilot/routes/purchasing_routes.py) | `POST /pilot/purchase-invoices/{pi_id}/cancel` endpoint with JE reversal |
| [`apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart`](../apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart) | 12 source-grep contracts |

## Test coverage

12 tests in [`purchase_invoice_multiline_parity_test.dart`](../apex_finance/test/screens/purchase_invoice_multiline_parity_test.dart):

| Group | Tests |
|---|---|
| Multi-line refactor | 4 (`_PiLineDraft` class, init with one line, add/remove with guard, payload uses `qty`+`unit_cost`) |
| Edit pre-fill | 3 (widget param, router query param, lock-on-non-draft) |
| Row click → details (Bug-#1 parity) | 2 (list routes to details, router has details route) |
| Details screen | 2 (Cancel/Edit/Print + JE link, scroll-fix pattern) |
| Backend cancel route | 1 (route exists + JE reversal + payment guard) |

All 12 pass. `flutter analyze` clean on touched files.

## Manual UAT (after deploy)

Pre-conditions: existing vendor (VND-001), product PRD-001.

1. Navigate to `/app/erp/finance/purchase-bills/new`. **Expect**: single empty
   line card with picker + qty=1 + empty cost.
2. Pick PRD-001 → **expect**: description + cost auto-fill; stock badge in
   dropdown.
3. Click **+ إضافة بند** → **expect**: a second empty line appears.
4. Pick a different product on line 2 → totals footer updates live.
5. Remove line 2 with the 🗑 icon → only one line remains, button disabled.
6. Save as draft → PI-2026-NNNN created → redirect to bills list.
7. Click the new bill row → **expect**: lands on the new details screen (not
   JE builder), with line(s), totals, action buttons.
8. Click **Edit** on a draft bill → **expect**: lands on
   `/app/erp/finance/purchase-invoice-create?bill_id=<id>` with line(s)
   pre-filled.
9. For a non-draft (posted) bill: **expect** the read-only banner
   ("هذه الفاتورة في حالة 'posted' — لا يمكن تعديلها") with a
   "فتح التفاصيل" button.
10. From details on a posted bill click **إلغاء الفاتورة** → confirm dialog
    → **expect**: status flips to `cancelled`, JE banner remains (now the
    reversed JE entry), no error.
11. Try to cancel a bill with a payment applied → **expect**: 409 with
    Arabic error in snackbar.

## Roadmap context

This PR closes 3 of the 6 integration gaps flagged in the QA audit
following PR #189. The remaining 3 (POS multi-line + POS ZATCA QR +
VendorPaymentScreen modal parity) are bookmarked for the next sprint
(G-POS-MULTILINE-ZATCA + G-VENDOR-PAYMENT-PARITY).
