# Purchase Invoice → Auto-Post JE — Sprint 6

**Status:** in force as of 2026-05-09 (G-FIN-PURCHASE-INVOICE-JE-AUTOPOST).
**Closes:** Sprint 1 audit Gap §3 row 6 ("Purchase Invoice create
screen — backend posts JE on `/post`, frontend has no creation flow").

---

## TL;DR

Mirror of [Sprint 5's sales invoice flow](SALES_INVOICE_JE_FLOW_2026-05-09.md)
on the inbound side. The backend
[`post_purchase_invoice_to_gl`](../app/pilot/services/purchasing_engine.py)
auto-builds the standard 3-leg purchase JE on
`POST /pilot/purchase-invoices/{id}/post`:

```
DR Inventory (1140) or Expense  subtotal     ← to AR-side this is "what we got"
DR VAT Input Receivable (1150)  vat_total    ← reclaimable input VAT
CR Vendor Payable (subcategory='payables')   total ← what we owe
```

What was missing: the **frontend create screen**. The previous
list-page `+ جديد` button routed to a `/purchase` placeholder.

## What's new

| File | Purpose |
|---|---|
| [purchase_invoice_create_screen.dart](../apex_finance/lib/screens/operations/purchase_invoice_create_screen.dart) | Dedicated create form. Vendor picker via `VendorPickerOrCreate` (Sprint 3). Two save buttons: حفظ كمسودة (no JE) + حفظ وترحيل (3-leg JE auto-post). Success snackbar surfaces `journal_entry_id` with action button to JE list. |
| [purchase_invoices_screen.dart](../apex_finance/lib/screens/operations/purchase_invoices_screen.dart) | `_onCreate` rewired from `/purchase` placeholder to the new create screen. Closes the wave-4 TODO. |
| [router.dart](../apex_finance/lib/core/router.dart) | New GoRoute `/app/erp/finance/purchase-bills/new` → `PurchaseInvoiceCreateScreen`. |
| [api_service.dart](../apex_finance/lib/api_service.dart) | New method `pilotCreatePurchaseInvoice(payload)` posting to `/pilot/purchase-invoices`. |

## Sales vs Purchase asymmetries

| Aspect | Sales (Sprint 5) | Purchase (Sprint 6) |
|---|---|---|
| Picker widget | CustomerPickerOrCreate | VendorPickerOrCreate |
| Default due-date offset | 30 days | **60 days** (working-capital asymmetry — pay vendors slower than customers pay you) |
| Create endpoint | `POST /sales-invoices` | `POST /purchase-invoices` |
| Auto-post endpoint | `POST /sales-invoices/{id}/issue` | `POST /purchase-invoices/{id}/post` |
| JE pattern | DR AR / CR Revenue / CR VAT Output | DR Inventory or Expense / DR VAT Input / CR Payable |
| Has shipping field | no | yes |
| Has vendor invoice number | no | yes (`vendor_invoice_number` — vendor's own ref) |

## Test coverage

[purchase_invoice_je_autopost_test.dart](../apex_finance/test/screens/purchase_invoice_je_autopost_test.dart) — 7 source-grep contracts, 7/7 pass.

## What's deferred

Same as Sprint 5: multi-line invoices and product-line picker
integration. The current screen builds a single-element `lines: [{...}]`
payload. When Sprint 5/6 line tables land in a future sprint that
bundles them with Sprint 4 product picker work, both screens will
gain multi-line entry simultaneously.
