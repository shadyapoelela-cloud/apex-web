# Purchase-side fixes bundle — G-PURCHASE-FIXES (2026-05-11)

QA-flagged grab-bag of 5 purchase-side issues, bundled into a single
PR because each fix is small and the surface area overlaps
(`purchasing_routes.py`, `purchasing.py` schema, vendor payment modal,
purchase + sales details screens).

---

## Fix #1 — Cheque routing 1310 wrong for outgoing vendor cheques

### Before

```
method == "cheque"  →  paid_from = "1310"
```

Account 1310 = "Cheques on Hand" is an **asset** account that tracks
cheques the company has **received** from customers and not yet
deposited. Crediting 1310 on an outgoing cheque to a vendor pushes
this asset balance the wrong way — it would say the company is owed
*more* by customers because they paid a vendor.

### After

```
method == "cash"   →  paid_from = "1110"   (Petty cash)
method == anything else → paid_from = "1120"   (Bank)
```

Outgoing cheques settle through the bank: the bank decrements when
the cheque is cashed, so 1120 (Bank) is the correct credit side. A
follow-up may introduce a dedicated "Cheques Issued / Outstanding"
liability account for the float between issue and clearing, but the
current bundle keeps the GL coherent without adding new accounts.

### GL routing diagram

```
+----------------+----------------+--------------------+
| Method         | Old paid_from  | New paid_from      |
+----------------+----------------+--------------------+
| cash           | 1110           | 1110               |
| bank_transfer  | 1120           | 1120               |
| cheque         | 1310 (WRONG)   | 1120 (CORRECT)     |
| credit_card    | 1120           | 1120               |
| card           | (rejected)     | 1120               |
| mada           | (rejected)     | 1120               |
| other          | 1120           | 1120               |
+----------------+----------------+--------------------+
```

`app/pilot/routes/purchasing_routes.py` —
`record_vendor_payment_endpoint` (the slim modal-friendly
`POST /purchase-invoices/{id}/payment` shim).

---

## Fix #2 — Vendor payment lacks card / mada (Saudi market gap)

### Before

Schema `purchasing.py:VendorPaymentCreate.method` pattern accepted
only `cash | bank_transfer | cheque | credit_card | other`. The
vendor modal dropdown exposed the same set minus mada. Saudi
merchants frequently pay vendors via mada (local debit network) and
generic POS card terminals — those payments had to be miscategorised
as `credit_card` or `other`.

### After

Allow-list extended on **three** surfaces:

1. **Schema** (`purchasing.py:VendorPaymentCreate.method`):
   ```python
   pattern="^(cash|bank_transfer|cheque|credit_card|card|mada|other)$"
   ```
2. **Slim endpoint** (`purchasing_routes.py:record_vendor_payment_endpoint`):
   ```python
   if method not in ("cash", "bank_transfer", "cheque",
                     "credit_card", "card", "mada", "other"):
       raise HTTPException(400, ...)
   ```
3. **Vendor modal dropdown** (`vendor_payment_modal.dart`):
   `card → بطاقة ائتمان`, `mada → مدى` added; `credit_card` + `other`
   retained for backward compatibility with already-stored records.

### Method allow-list (Saudi-aware)

```
+----------------+-----------------------+----------+
| Wire value     | Arabic label          | Origin   |
+----------------+-----------------------+----------+
| cash           | نقداً                 | core     |
| bank_transfer  | تحويل بنكي            | core     |
| cheque         | شيك                   | core     |
| card           | بطاقة ائتمان          | NEW      |
| mada           | مدى                   | NEW (SA) |
| credit_card    | بطاقة ائتمان          | legacy   |
| other          | أخرى                  | core     |
+----------------+-----------------------+----------+
```

---

## Fix #3 — Cancel guard threshold mismatch

### Before

Purchase details UI: `paid <= 0.001` → showed Cancel button.
Backend: `if (inv.amount_paid or Decimal(0)) > 0: raise 409`.

A floating-point edge (e.g. `paid == 0.0005` from a rounding artefact)
let the UI display Cancel, but the backend refused. Sales side had
the same mismatch.

### After

Both `purchase_invoice_details_screen.dart` and
`sales_invoice_details_screen.dart` now gate Cancel on
`paid <= 0` — matching the strict backend contract. No more dead
buttons.

---

## Fix #4 — Legacy `paid_from_account_code` default `"1110"` ignores method

### Before

Schema default:
```python
paid_from_account_code: str = Field("1110")   # 1110 cash, 1120 bank
```

A client POSTing to `/vendor-payments` with
`{"method": "bank_transfer"}` and no `paid_from_account_code` got
the cash account credited instead of bank. The slim `/payment`
endpoint handled this correctly; the legacy endpoint did not.

### After

`create_vp_endpoint` derives the correct account when the schema
default is present alongside a non-cash method:

```python
paid_from = payload.paid_from_account_code
if paid_from == "1110" and payload.method != "cash":
    paid_from = "1120"   # mirror the /payment endpoint mapping
```

Schema default left at `"1110"` for backward compatibility with
existing callers that explicitly pass cash. Explicit values from
the client always win — the override only kicks in for the
schema-supplied default.

---

## Fix #5 — Print preview on draft sales + purchase

### Before

Both details screens gated the Print button on `if (!isDraft)`.
A draft author had no way to get a print preview before posting.

### After

Both gates switched to `if (!isCancelled)`. Drafts get print
preview; only cancelled invoices skip it (no reason to print a void).
This brings purchase and sales gates into alignment and matches
common ERP behaviour (Odoo, Zoho, SAP all allow draft print).

---

## UAT steps

1. **Cheque routing — vendor**:
   - Create a vendor invoice (PI), post it.
   - Record payment via modal → method = "شيك" (cheque), amount = full.
   - Inspect the JE: Debit AP (2010), Credit Bank (1120). NOT 1310.

2. **mada card on vendor side**:
   - In vendor payment modal, dropdown should list "مدى" alongside "بطاقة ائتمان".
   - Submitting with `method=mada` returns 201, JE credits 1120.

3. **Cancel guard alignment**:
   - With a draft PI (no payments), Cancel button appears.
   - Once any payment is applied (even partial), Cancel disappears
     (UI matches backend's 409).

4. **Legacy `/vendor-payments` endpoint**:
   - `curl POST /pilot/vendor-payments` with body
     `{ "entity_id": ..., "vendor_id": ..., "amount": 100,
        "payment_date": "2026-05-11", "method": "bank_transfer" }`
     (no `paid_from_account_code`).
   - Resulting JE credits 1120 (bank), not 1110 (cash).
   - Same call with `"method": "cash"` still credits 1110.

5. **Print on drafts**:
   - Open a draft PI/SI in details screen.
   - "طباعة" (Print) button appears in the secondary action row.
   - Open a cancelled invoice → Print button gone.

---

## Verification

- `flutter test test/screens/purchase_fixes_test.dart` — 12 new contracts green.
- `flutter test test/screens/purchase_payment_completion_test.dart` — pinned to new routing.
- `flutter test test/screens/sales_invoice_ux_test.dart` — green.
- `flutter test test/screens/purchase_invoice_multiline_parity_test.dart` — green.
- `flutter test test/screens/purchase_invoice_je_autopost_test.dart` — green.
- `flutter analyze` — no new issues in touched files.
- Python AST validation — `app/pilot/routes/purchasing_routes.py` and
  `app/pilot/schemas/purchasing.py` parse cleanly.

---

## Files touched

```
app/pilot/routes/purchasing_routes.py            (fixes #1, #2 server, #4)
app/pilot/schemas/purchasing.py                  (fix #2 schema)
apex_finance/lib/screens/operations/vendor_payment_modal.dart           (fix #2 UI)
apex_finance/lib/screens/operations/purchase_invoice_details_screen.dart (fixes #3, #5)
apex_finance/lib/screens/operations/sales_invoice_details_screen.dart    (fixes #3, #5)
apex_finance/test/screens/purchase_fixes_test.dart                       (NEW — 12 contracts)
apex_finance/test/screens/purchase_payment_completion_test.dart          (pin updated)
docs/PURCHASE_FIXES_2026-05-11.md                                        (this doc)
```
