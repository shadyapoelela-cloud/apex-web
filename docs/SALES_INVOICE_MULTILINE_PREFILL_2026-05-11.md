# Sales Invoice — Multi-line + Edit Pre-fill + Picker UX

**Status:** in force as of 2026-05-11.
**Closes:** 5 of the 7 deferred spec items from the QA report on PR #188.

---

## What this PR ships

### 🟢 Multi-line invoices
The `SalesInvoiceCreateScreen` is rewritten from a single-line form to a list of line drafts. Each line carries its own controllers, picker, qty/price/VAT fields, and a remove button (disabled when only one line remains so the form is never empty).

`_LineDraft` is the value class — `desc`, `qty`, `unitPrice`, `vatRate`, `product` — with a `dispose()` helper that's called when the line is removed or the screen is disposed.

Line-level totals are computed reactively; the screen footer shows subtotal / VAT / grand-total across all lines.

### 🟢 Edit pre-fill
The screen now takes a `prefillInvoiceId` constructor param. When set (via `?invoice_id=` query param on the route), the screen fetches `GET /sales-invoices/{id}` on init and hydrates customer + dates + lines.

For non-draft invoices the form **locks** (`AbsorbPointer` wrapping inputs) and shows a banner directing the user to the details screen — editing a posted invoice mid-flight would diverge from the GL.

Router-side: a new `GoRoute('/app/erp/sales/invoice-create')` reads `s.uri.queryParameters['invoice_id']`. The existing chip-mapping at `erp/sales/invoice-create` still handles the fresh-create case.

### 🟢 Picker — server-side debounced search
`ProductPickerOrCreate` now hits `GET /pilot/tenants/{tid}/products?q=...&limit=20` on every keystroke with a **300ms debounce** and a **sequence-token cancellation** pattern so older fetches don't overwrite newer ones.

`pilotListProducts(tenantId, {limit, q})` got a `q` parameter that URL-encodes the search term.

Pre-PR the picker cached 500 products client-side. Tenants with thousands of SKUs hit the limit silently — the new flow scales to any catalogue size.

### 🟢 Stock badge
Each dropdown row now shows a stock badge — **green** when `total_stock_on_hand > 0`, **red** for "نفد", **grey** for services (`is_stockable=false`).

### 🟢 Qty>stock warning
Per-line, when `qty > total_stock_on_hand` on a stockable product, a non-blocking warning banner appears: "الكمية (N) تتجاوز المخزون المتوفر (M)". Submit is NOT gated on this — the backend is the source of truth for negative-stock policy, the UI is just informational.

### What's still deferred

| Item | Why |
|---|---|
| Camera-based barcode scanner (`getUserMedia`) | needs camera lib choice + permissions UI — separate sprint |
| CODE128 internal barcode | needs barcode-rendering library |
| Dedicated print template | current `window.print()` prints the visible viewport — acceptable interim |

---

## Files changed

| File | Change |
|---|---|
| [`apex_finance/lib/screens/operations/sales_invoice_create_screen.dart`](../apex_finance/lib/screens/operations/sales_invoice_create_screen.dart) | Full rewrite — `_LineDraft` class, list-based UI, pre-fill flow, stock warning, lock-on-non-draft |
| [`apex_finance/lib/widgets/forms/product_picker_or_create.dart`](../apex_finance/lib/widgets/forms/product_picker_or_create.dart) | Server-side debounced search + sequence-token cancellation + stock badge in dropdown |
| [`apex_finance/lib/api_service.dart`](../apex_finance/lib/api_service.dart) | `pilotListProducts` gains `q` parameter for server-side search |
| [`apex_finance/lib/core/router.dart`](../apex_finance/lib/core/router.dart) | New explicit GoRoute for `/app/erp/sales/invoice-create` reading `?invoice_id=` query param |
| [`apex_finance/test/screens/sales_invoice_multiline_prefill_test.dart`](../apex_finance/test/screens/sales_invoice_multiline_prefill_test.dart) | 12 source-grep contracts |

## Test coverage

12 tests in [`sales_invoice_multiline_prefill_test.dart`](../apex_finance/test/screens/sales_invoice_multiline_prefill_test.dart):

| Group | Tests |
|---|---|
| Multi-line | 4 (`_LineDraft` class, init with one line, add/remove with guard, payload serialisation) |
| Edit pre-fill | 3 (widget param, router query param, lock-on-non-draft) |
| Picker server search | 2 (API method signature, 300ms debounce + sequence token) |
| Stock badge + warning | 3 (color logic, `_stockWarning` helper, warning is non-blocking) |

All 12 pass.

## Manual UAT (after deploy)

Pre-conditions: `uat-2026-05-09@apex.test` / `UatTest9876!` with existing customer (CUST-001), product PRD-001 with stock.

1. Navigate to `/app/erp/sales/invoice-create`. **Expect**: a single empty line with product picker + qty=1 + empty price.
2. Pick PRD-001 from picker → **expect**: description + price + VAT auto-fill; stock badge shows "N متوفر" in green.
3. Set qty=999 → **expect**: warning banner "الكمية (999) تتجاوز المخزون المتوفر (N)".
4. Set qty back to 2 → warning disappears.
5. Click **+ إضافة بند** → **expect**: a second empty line appears.
6. Pick a different product on line 2 → totals footer updates.
7. Remove line 2 with the 🗑 icon → only one line remains.
8. Save as draft → INV-2026-NNNN created.
9. Open details screen → click **Edit** button.
10. **Expect**: lands on `/app/erp/sales/invoice-create?invoice_id=<id>` with line(s) pre-filled.
11. For a non-draft invoice: **expect** the read-only banner ("هذه الفاتورة في حالة 'issued' — لا يمكن تعديلها") with a "فتح التفاصيل" button.
12. Type "منت" in a fresh picker → **expect**: ~300ms after the last keystroke, the dropdown updates with server-side matches. Long lists scroll inside the dropdown.

## Roadmap context

This PR delivers 5 of the 7 items the QA report flagged as deferred. The remaining 2 (camera scanner + CODE128) are bookmarked for a future sprint that bundles them with hardware-integration work (printer + scanner drivers on KSA POS hardware).
