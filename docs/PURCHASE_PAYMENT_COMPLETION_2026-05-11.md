# Purchase Payment Completion — Sales Parity for Payment Flow

**Status:** in force as of 2026-05-11.
**Closes:** GAP-5, GAP-7, GAP-8, GAP-9 from the post-PR-#190 QA audit.

---

## Why this PR exists

The QA review of PR #190 (G-PURCHASE-MULTILINE-PARITY) flagged that the
purchase-invoice details screen I shipped was **incomplete** vs the sales
side:

- No `+ تسجيل دفع` primary action button (sales has it via
  `CustomerPaymentModal`)
- No `_buildPayments()` widget — the screen never rendered payment history
- Backend `GET /pilot/purchase-invoices/{id}` didn't return `payments[]`
  (`get_sales_invoice` returns them on the sales side)
- `VendorPaymentScreen` stuck on the old `ApexPaymentMethod`/grid pattern
  with no `notes` or `bank_account` fields → audit-trail asymmetry vs
  `CustomerPaymentModal`

That's a **regression of sales parity** introduced by PR #190 itself. This
PR closes it.

## What this PR ships

### 🟢 Backend `POST /pilot/purchase-invoices/{id}/payment`

Modal-friendly slim endpoint mirroring `POST /sales-invoices/{id}/payment`
on the sales side. Pre-existing `POST /pilot/vendor-payments` works but takes
a full payload including `entity_id`, `vendor_id`, and
`paid_from_account_code` — too much friction for a modal driven by the
invoice details screen.

Cash/bank/cheque routing happens server-side (matching the sales side's
`_post_customer_payment_je`):

| Method | Account code |
|---|---|
| `cash` | 1110 (Cash on hand) |
| `cheque` | 1310 (Cheques on hand) |
| anything else (bank_transfer/credit_card/other) | 1120 (Bank) |

Guards:
- Refuses when invoice is `cancelled` (409)
- Refuses when invoice already `paid` (409)
- Refuses overpayment (409) — `amount + amount_paid > grand_total`
- Validates `amount > 0` and `method` against the pattern allowlist

Delegates to the existing `create_vendor_payment()` service in
`purchasing_engine.py`, which already handles the JE auto-post (DR 2110 AP /
CR cash account), invoice paid_amount update, vendor balance update.

Response shape mirrors `record_customer_payment`:

```json
{
  "payment_id": "...",
  "payment_number": "PMT-...",
  "amount": 100.0,
  "method": "bank_transfer",
  "invoice_status": "partially_paid",
  "invoice_paid_amount": 100.0,
  "remaining_balance": 50.0,
  "journal_entry_id": "..."
}
```

### 🟢 `GET /pilot/purchase-invoices/{id}` includes `payments[]`

`PiDetail` schema gained a `payments: list[VendorPaymentRead]` field. The
route queries `VendorPayment.invoice_id == pi_id` ordered by `payment_date`
and serialises them into the response. The details screen now renders the
full history in a single round-trip.

### 🟢 `VendorPaymentModal`

Brand-new modal mirroring `CustomerPaymentModal`:

- `static show()` helper for one-line invocation from details
- Amount validator with overpayment guard against `remainingBalance`
- Date picker
- Method dropdown: cash / bank_transfer / cheque / credit_card / other
- `reference` field
- `_bankAccount` field conditional on `method == 'bank_transfer'`
- `_notes` field always visible
- Server reference is combined: `<ref> · بنك: <bank> · ملاحظات: <notes>` so
  the AP ledger + JE memo carry the full audit trail
- Returns the payment payload Map (includes `journal_entry_id`) on success

### 🟢 Details screen wired

`purchase_invoice_details_screen.dart`:

- Imports `vendor_payment_modal.dart`
- New `_recordPayment()` opens the modal, refreshes on success, surfaces the
  JE link in a snackbar via `SnackBarAction`
- New `_buildPayments()` widget renders the payments history table (each row:
  `payment_number` · `payment_date` · method label · JE link button ·
  amount)
- New `_methodLabel()` helper for Arabic method names
- `_buildActions()` now computes `canPay = isPosted && remaining > 0.001`
  and adds a `+ تسجيل دفع` primary `ElevatedButton.icon` (green) when allowed

### 🟢 `pilotRecordVendorPayment` in `api_service.dart`

```dart
static Future<ApiResult> pilotRecordVendorPayment(
        String piId, Map<String, dynamic> payload) =>
    _post('/pilot/purchase-invoices/$piId/payment', payload);
```

---

## Files changed

| File | Change |
|---|---|
| [`app/pilot/routes/purchasing_routes.py`](../app/pilot/routes/purchasing_routes.py) | `POST /payment` endpoint + extended `get_pi` to return payments |
| [`app/pilot/schemas/purchasing.py`](../app/pilot/schemas/purchasing.py) | `PiDetail.payments: list[VendorPaymentRead]` |
| [`apex_finance/lib/screens/operations/vendor_payment_modal.dart`](../apex_finance/lib/screens/operations/vendor_payment_modal.dart) | **NEW** — mirrors `CustomerPaymentModal` |
| [`apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart`](../apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart) | `_recordPayment` + `_buildPayments` + `_methodLabel` + primary pay button |
| [`apex_finance/lib/api_service.dart`](../apex_finance/lib/api_service.dart) | `pilotRecordVendorPayment` method |
| [`apex_finance/test/screens/purchase_payment_completion_test.dart`](../apex_finance/test/screens/purchase_payment_completion_test.dart) | 11 source-grep contracts |

## Test coverage

11 tests in [`purchase_payment_completion_test.dart`](../apex_finance/test/screens/purchase_payment_completion_test.dart):

| Group | Tests |
|---|---|
| Backend payment endpoint | 3 (route exists, account routing by method, overpayment + cancelled guards) |
| `get_pi` returns payments | 2 (schema field, route query + serialisation) |
| `VendorPaymentModal` | 3 (show helper + endpoint wiring, notes + conditional bank field, reference merge) |
| Details screen wired | 3 (import, `_recordPayment` + `_buildPayments` + modal call, button + api_service surface) |

All 11 pass. `flutter analyze` clean on touched files.

## Manual UAT (after deploy)

Pre-conditions: existing posted purchase invoice (e.g. PB-2026-NNNN, status
`posted` with `amount_due > 0`).

1. Navigate to `/app/erp/finance/purchase-bills` — click a posted bill row.
2. **Expect**: lands on details screen, sees lines, totals, no payments
   history yet, **+ تسجيل دفع** button visible (green).
3. Click **+ تسجيل دفع** → modal opens.
4. Default amount = remaining balance; change method to `bank_transfer` →
   "الحساب البنكي المُرسِل" field appears.
5. Fill bank name + notes → click "حفظ — يرحَّل القيد تلقائياً".
6. **Expect**: snackbar "تم تسجيل الدفع — قيد اليومية #JE-..." with "عرض القيد"
   action → opens JE builder.
7. Page auto-refreshes → **expect**: "سجل المدفوعات (1)" section appears
   with the new row, status updates to `partially_paid` or `paid`, paid
   amount reflects + remaining decreases.
8. Try paying more than `remaining_balance` → frontend rejects in validator
   (before submit); even if bypassed, backend returns 409 overpayment.
9. Try paying a `cancelled` bill → button hidden; if route called directly
   → 409.

## Remaining gaps (next sprints)

| Gap | Sprint |
|---|---|
| POS Quick Sale multi-line | G-POS-MULTILINE |
| POS ZATCA QR on receipts | G-POS-ZATCA-QR (proposed next) |
| Camera barcode scanner | bundled with hardware-integration sprint |
| CODE128 internal barcode | same |
| Dedicated print template | low-priority |

`VendorPaymentScreen` (the legacy /purchase/payment/:billId route) remains
in place for backward compatibility but is now superseded by this modal flow.
It can be archived in a follow-up cleanup PR once we confirm no chip mapping
or external link points at it.
