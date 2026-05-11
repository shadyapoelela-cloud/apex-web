# POS Quick Sale — Backend Integration Fix (G-POS-BACKEND-INTEGRATION)

**Date:** 2026-05-11
**Sprint:** G-POS-BACKEND-INTEGRATION
**Branch:** `feat/g-pos-backend-integration`
**Severity:** Critical (architectural)
**Files changed:** 2 (code) + 1 (tests) + 1 (this doc)

## TL;DR

The POS Quick Sale screen (`pos_quick_sale_screen.dart`) was wired
to the **wrong backend flow**. Every cash sale went through the B2B
sales-invoice path (`pilotCreateSalesInvoice` + `pilotIssueSalesInvoice`)
which is meant for credit invoices, not over-the-counter retail.

The dedicated POS backend (`/pilot/pos-transactions` and the
`auto_post_pos_sale` helper) already existed server-side. This sprint
re-points the frontend so the right endpoints are called.

## What was broken (pre-fix)

1. **Double JE per sale.** Sales-invoice issue posts JE #1 (DR AR / CR
   Revenue / CR VAT). POS Quick Sale never recorded a customer
   payment, so JE #1 was the only entry — but AR was already debited
   to a synthetic "cash customer". Result: AR balance grew with every
   POS sale and Cash never moved. Audit nightmare.
2. **No stock deduction.** The sales-invoice flow does NOT create
   `StockMovement` rows. Inventory levels stayed frozen even as
   physical product walked out the door.
3. **Empty Z-Report.** `/pos-sessions/{sid}/z-report` aggregates
   `PosTransaction` rows. POS Quick Sale never produced one, so the
   end-of-shift report was always zero.
4. **No session lock.** Anyone could "ring up a sale" without an
   open shift. Cash-drawer accountability was nil.
5. **Wrong document type for ZATCA QR.** PR #192 (G-POS-ZATCA-QR)
   added a Phase-1 QR to the receipt card — but it was attached to
   a B2B sales invoice, which is the wrong ZATCA document type for
   a B2C retail sale.

## What changed (post-fix)

### api_service.dart

Three new slim wrappers (all `static`):

- `pilotCreatePosTransaction(payload)` → `POST /pilot/pos-transactions`
- `pilotPostPosTransactionToGl(posTxnId)` → `POST /pilot/pos-transactions/{id}/post-to-gl` (alias of the pre-existing `pilotPostPosToGL`, kept for naming clarity)
- `pilotListOpenPosSessions(branchId)` → `GET /pilot/branches/{bid}/pos-sessions?status=open&limit=1`

Plus one helper for session bootstrapping:

- `pilotListBranchWarehouses(branchId)` → `GET /pilot/branches/{bid}/warehouses`

`pilot_client.dart` already had `createPosTransaction`; we added a
sibling on `ApiService` for consistency with the rest of the POS
methods that the screen already calls (`pilotListPosSessions`,
`pilotPostPosToGL`, etc.). This keeps the screen's import style
uniform — only `package:../api_service.dart` is imported.

### pos_quick_sale_screen.dart::_submit

Old shape:

```
validate lines  →  fetch first customer  →
pilotCreateSalesInvoice  →  pilotIssueSalesInvoice  →
show receipt with invoice_number
```

New shape:

```
validate lines (now requires variant_id per line) →
resolve branch_id for the active entity →
ensure open POS session (list status=open, else create) →
pilotCreatePosTransaction {session_id, kind=sale, cashier_user_id,
                            lines:[{variant_id, qty,
                                    unit_price_override, barcode_scanned}],
                            payments:[{method, amount}]} →
pilotPostPosTransactionToGl(posTxnId) →
show receipt with receipt_number + JE link
```

### Payment-method translation

The UI's `ApexPaymentMethod` enum uses camelCase
(`stcPay`, `applePay`); `PosPaymentInput.method` uses snake_case
(`stc_pay`, `apple_pay`) per its regex pattern. A `_payloadMethod()`
helper translates. `ApexPaymentMethod.card` (a generic value with no
direct POS equivalent) maps to `visa` — refine when terminal-detection
ships.

### Line validation

`PosLineInput` requires `variant_id`, so the screen now rejects
ad-hoc description-only lines with an Arabic snackbar:

> البند N: اختر منتجاً (نقطة البيع تتطلب صنفاً مع باركود/SKU)

This is a deliberate behavioral tightening — POS receipts must be
traceable to a SKU for stock movement and Z-Report aggregation.

### Receipt card

- Displays `receipt_number` (e.g. `RCT-001234`) instead of
  `invoice_number` (`INV-2026-XXXX`).
- WhatsApp share message updated to reference receipt_number.
- JE link unchanged — still routes to `/app/erp/finance/je-builder/{jeId}` —
  but `jeId` now comes from the `post-to-gl` response (a
  `JournalEntryDetail` with a SINGLE leg) rather than from
  `pilotIssueSalesInvoice` (which returned a different shape).
- ZATCA QR rendering is preserved verbatim. The TLV payload now
  travels with a POS simplified-tax invoice — the **correct** ZATCA
  document type for B2C cash sales.

## Why the QR is now on the right document

ZATCA distinguishes:

- **Standard tax invoice** (B2B, fatoorah-ulgi'a): requires customer
  VAT number, served via UBL e-invoice. PR #192 was attaching the
  QR here for what was really a retail sale.
- **Simplified tax invoice** (B2C, fatoorah-mubsta): printable
  receipt with the Phase-1 QR. This is what POS Quick Sale should
  always have produced.

Post-fix the QR is generated against a `PosTransaction` (which the
backend treats as a simplified-tax invoice), satisfying ZATCA Phase 1
for retail.

## Manual UAT steps

1. **Prerequisites**
   - One entity with at least one branch and one sellable warehouse.
   - At least one product with a `default_variant_id` and either a
     price-list entry OR a `list_price` on the product card.
   - Logged in as a user whose `S.uid` is set (regular login flow).
2. **First sale (cold start, no open session)**
   1. Navigate to `/operations/pos/quick-sale` (or whatever V5 chip).
   2. Pick a product via the per-line picker. Confirm price autofills
      from `list_price`/`default_price`.
   3. Set qty = 2, payment method = Mada, click "سجّل البيع".
   4. **Expect:** Loading spinner → success receipt card showing
      `RCT-…` (NOT `INV-…`). QR code visible. JE chip shows.
   5. **Expect (backend):** A new `PosSession` row in `status=open`,
      one `PosTransaction` row, one `JournalEntry` posted with
      three lines (DR Cash, CR Revenue, CR VAT). `StockMovement`
      decremented for the variant.
3. **Second sale (existing session)**
   1. Add 2 lines (Coca-Cola + Pepsi). Different VAT rates if you
      want to probe the per-line VAT calc.
   2. Pay 100% in cash. Submit.
   3. **Expect:** Same session reused — `PosSession.transaction_count`
      increments from 1 → 2.
4. **Z-Report check**
   1. Hit `GET /pilot/pos-sessions/{sid}/z-report` (or use the
      eventual UI button).
   2. **Expect:** `transaction_count = 2`, `gross_sales` matches the
      sum of step 2 + step 3, `payment_breakdown` has `mada` and
      `cash` keys.
5. **Validation paths**
   1. Add a line, leave the product picker blank, click submit.
   2. **Expect:** Snackbar "البند N: اختر منتجاً …" — no API call.
   3. Add a real product but set price = 0, submit.
   4. **Expect:** Snackbar "البند N: السعر غير صحيح".
6. **Regression: receipt content**
   1. Confirm the QR still scans and decodes to TLV with seller name
      `APEX`, VAT `300000000000003`, and the total/VAT from the
      sale.
   2. Confirm the "WhatsApp share" message contains `RCT-…`, not
      `INV-…`.
7. **Multi-line regression**
   1. Add 5 lines, mix products, mix VAT rates, set various qtys.
   2. Submit, then confirm the receipt's `line_count` reads "5 بند".

## Rollback plan

If a deploy goes sideways:

```
git revert --no-edit <merge-commit-of-PR>
```

The change is contained to:
- `apex_finance/lib/api_service.dart` (added methods only — safe to
  leave even on revert)
- `apex_finance/lib/screens/operations/pos_quick_sale_screen.dart`
  (the `_submit` body and `_receiptCard` text)
- `apex_finance/test/screens/pos_backend_integration_test.dart` (new)
- `apex_finance/test/screens/pos_multiline_cleanup_test.dart` (3
  assertions updated to the post-fix payload shape + GAP-11 CRLF fix)

Backend changes: **NONE**. Every endpoint called already exists in
`app/pilot/routes/pos_routes.py` and `app/pilot/routes/gl_routes.py`.
This is a pure frontend-routing fix.

## Tests

`test/screens/pos_backend_integration_test.dart` — 12 contracts, all
source-grep based (same approach as PR #192 / #193 because POS
screens transitively load `package:web` which fails the SDK gate
under `flutter_test`).

Existing `test/screens/pos_multiline_cleanup_test.dart` — 3 assertions
updated:
- `test_pos_payload_serialises_all_lines` now asserts the POS-schema
  payload keys (`variant_id`/`qty`/`unit_price_override`) instead of
  the old sales-invoice keys (`quantity`/`unit_price`/`vat_rate`).
- `test_pos_resets_lines_after_successful_submit` was rewritten as a
  regex over flexible whitespace so it survives CRLF checkouts on
  Windows (same GAP-11 fix that purchase-invoice parity absorbed).

Combined run:

```
flutter test test/screens/pos_backend_integration_test.dart \
             test/screens/pos_multiline_cleanup_test.dart
# +22: All tests passed!
```

`flutter analyze lib/screens/operations/pos_quick_sale_screen.dart lib/api_service.dart` — clean.

## Out of scope (deferred)

- **Per-station POS picker.** Cashiers on the same branch share one
  open session. Multi-station POS will need a UI control.
- **Seller VAT / name from entity settings.** Still using the legacy
  hardcoded placeholders (`300000000000003`, `APEX`). Wire to the
  entity-settings API in a future sprint so the QR carries real
  entity data.
- **Refund + void UI.** Backend supports both
  (`/pos-transactions/{id}/void`, `/pos-transactions/{id}/refund`);
  the frontend has no buttons yet.
- **Z-Report screen.** Endpoint exists; no UI surface.
