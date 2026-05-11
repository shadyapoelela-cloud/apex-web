# Sales Invoice — Edit-draft PATCH + Customer Payment Notes

**Date:** 2026-05-11
**Branch:** `feat/g-sales-invoice-update`
**Tickets:** `G-SALES-INVOICE-UPDATE`, `G-CUSTOMER-PAYMENT-NOTES`

## Summary

Two related fixes shipping together:

1. The Sales Edit flow was creating duplicate drafts every time the
   user clicked Save on a prefilled draft (the create screen always
   POSTed `/sales-invoices` regardless of `?invoice_id=`).
2. The customer payment modal was merging the user's free-text notes
   into the `reference` field — the vendor side has a dedicated
   `notes` column and audit memo, so the sales side was an asymmetry
   gap.

Both are addressed in the same PR because both sit on the same
backend route file (`customer_routes.py`) and the same frontend
sub-tree (`screens/operations/*`).

---

## 1. Edit-draft duplicate-create bug

### The bug

`PR #189` introduced an Edit flow: clicking Edit on a draft invoice
opens `/app/erp/sales/invoice-create?invoice_id={id}`. The screen
correctly prefilled from the existing invoice via
`GET /sales-invoices/{id}`, but the Save buttons (`_saveDraft` and
`_submit`) always called `ApiService.pilotCreateSalesInvoice(payload)`
— which is a POST to `/sales-invoices`. The backend happily allocated
a new `INV-XXX` and the user ended up with two drafts.

### The fix

**Backend** — new endpoint:

```python
@router.patch("/sales-invoices/{invoice_id}", response_model=SalesInvoiceRead)
def update_sales_invoice(
    invoice_id: str = Path(...),
    payload: SalesInvoiceUpdate = Body(...),
    current_user: dict = Depends(get_current_user),
):
    ...
    if inv.status != SalesInvoiceStatus.draft.value:
        raise HTTPException(
            status_code=409,
            detail=f"cannot edit invoice in status {inv.status!r} — only drafts editable",
        )
    # delete existing lines + re-insert from payload.lines (same
    # arithmetic as create_sales_invoice). Recompute subtotal,
    # vat_amount, total. invoice_number is NEVER changed.
```

Refusal matrix:

| Status            | PATCH result |
|-------------------|--------------|
| `draft`           | 200 — updates fields + replaces lines |
| `issued`          | 409 |
| `partially_paid`  | 409 |
| `paid`            | 409 |
| `cancelled`       | 409 |

**Frontend** — `ApiService.pilotUpdateSalesInvoice(invoiceId, payload)`
wraps the new endpoint; `_submit` and `_saveDraft` in
`sales_invoice_create_screen.dart` now branch on
`widget.prefillInvoiceId`:

```dart
final editId = widget.prefillInvoiceId;
if (editId != null && editId.isNotEmpty) {
  final upd = await ApiService.pilotUpdateSalesInvoice(editId, payload);
  // ... show "تم تحديث الفاتورة #..." snackbar, navigate to details
  return; // NO fallback to POST
}
// non-prefilled path: keep existing create + issue flow
```

On PATCH failure the flow surfaces the backend error and stops —
there is no fallback to POST, because the fallback IS the bug.

### Manual UAT

1. Open an existing draft (any one with status = `draft`).
2. Click Edit — confirm URL is `?invoice_id={the-id}`.
3. Change the memo or a line amount.
4. Click "Save Draft" (or "إنشاء وإصدار").
5. The snackbar should say "تم تحديث الفاتورة #INV-2026-NNNN".
6. Go back to the invoice list — there should be **one** row for
   this invoice (same `INV-NNNN`), not two.
7. Open it again — the new values should be persisted, and the
   `invoice_number` should be unchanged.

### API examples

```bash
# Update memo + a single line (replace-all semantics)
curl -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "memo": "خصم نهائي 5%",
        "lines": [
          {"description": "خدمة استشارية", "quantity": 1, "unit_price": 1000, "vat_rate": 15}
        ]
      }' \
  https://api.apex.example/api/v1/pilot/sales-invoices/$INV_ID

# 200 — returns the same SalesInvoiceRead the create endpoint does.
# invoice_number unchanged; subtotal/vat_amount/total recomputed.

# Attempt to PATCH an issued invoice → 409
curl -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"memo": "x"}' \
  https://api.apex.example/api/v1/pilot/sales-invoices/$ISSUED_INV_ID
# {"detail":"cannot edit invoice in status 'issued' — only drafts editable"}
```

---

## 2. CustomerPayment `notes` column

### The asymmetry

`VendorPayment` already had:
- `notes` Column on the SQLAlchemy model
- `notes: Optional[str]` on `VendorPaymentInput`
- A `'notes': notes` key in the vendor modal payload

`CustomerPayment` was missing all three. The customer modal merged
the teller's free-text notes into the `reference` field along with
the bank account name — readable, but the AR ledger lost the
distinction between "merchant-visible reference" and "internal
audit note".

### The fix

- `CustomerPayment.notes = Column(String(500), nullable=True)` —
  no migration needed, SQLAlchemy auto-create handles it.
- `CustomerPaymentInput.notes: Optional[str] = None`
- `CustomerPaymentRead.notes: Optional[str] = None`
- `record_customer_payment` passes `notes=payload.notes` to the
  `CustomerPayment(...)` constructor.
- `get_sales_invoice_detail` serialises `notes=getattr(p, "notes", None)`
  into the per-payment row.
- `customer_payment_modal.dart` sends `'notes': notes` when notes is
  non-empty (parity with `vendor_payment_modal.dart:141`). KEEPS the
  `combinedReference` field — it remains the merchant-visible
  reference.
- `sales_invoice_details_screen.dart::_buildPayments` renders the
  notes line in a subtle italic style below the payment date when
  `p['notes']` is non-empty.

### API example

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "payment_date": "2026-05-11",
        "amount": 1150.00,
        "method": "bank_transfer",
        "reference": "TX-2026-9921",
        "notes": "العميل اتصل لتأكيد التحويل — تم"
      }' \
  https://api.apex.example/api/v1/pilot/sales-invoices/$INV_ID/payment

# Subsequent GET /sales-invoices/$INV_ID returns the payment with
# notes set, which the details screen now renders below the date.
```

---

## Files touched

Backend:
- `app/pilot/routes/customer_routes.py` — new PATCH endpoint,
  `SalesInvoiceUpdate` schema, `notes` on input/read schemas,
  `notes` threaded into `record_customer_payment` and
  `get_sales_invoice_detail`.
- `app/pilot/models/customer.py` — `CustomerPayment.notes` column.

Frontend:
- `apex_finance/lib/api_service.dart` — `pilotUpdateSalesInvoice`.
- `apex_finance/lib/screens/operations/sales_invoice_create_screen.dart`
  — `_submit` / `_saveDraft` branch on `prefillInvoiceId`.
- `apex_finance/lib/screens/operations/customer_payment_modal.dart`
  — payload sends `notes` separately.
- `apex_finance/lib/screens/operations/sales_invoice_details_screen.dart`
  — `_buildPayments` renders the notes line.

Tests:
- `apex_finance/test/screens/sales_invoice_update_test.dart` — 10
  source-grep contracts pinning all of the above.

## Verification

```bash
# Backend Python syntax
py -c "import ast; ast.parse(open(r'C:\apex_app\app\pilot\routes\customer_routes.py', encoding='utf-8').read()); print('OK')"

# Flutter analyze (4 touched files, clean)
cd apex_finance && flutter analyze \
  lib/api_service.dart \
  lib/screens/operations/sales_invoice_create_screen.dart \
  lib/screens/operations/customer_payment_modal.dart \
  lib/screens/operations/sales_invoice_details_screen.dart

# New tests
flutter test test/screens/sales_invoice_update_test.dart    # 10/10

# Pre-existing sales tests still green
flutter test \
  test/screens/sales_invoice_multiline_prefill_test.dart \
  test/screens/sales_invoice_ux_test.dart
```
