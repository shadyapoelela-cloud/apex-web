# Sales Invoice → Auto-Post JE — Sprint 5

**Status:** in force as of 2026-05-09 (G-FIN-SALES-INVOICE-JE-AUTOPOST).
**Closes:** Sprint 1 audit Gap §3 row 5 ("Sales Invoice create screen
— `SalesInvoicesScreen` lists; no create form, the auto-post-JE logic
backend-side already exists").

---

## TL;DR

The backend has shipped the JE auto-post engine for sales invoices
since well before this sprint —
[`_post_sales_invoice_je`](../app/pilot/routes/customer_routes.py)
at `customer_routes.py:364` is called by the
`POST /sales-invoices/{id}/issue` route at `customer_routes.py:597`
and produces the standard 3-leg journal entry:

```
DR Customer Receivable (subcategory='receivables')   total
CR Sales Revenue (subcategory='sales')               subtotal
CR VAT Output Payable (code='2120')                  vat_amount
```

What was missing was a **frontend that told the user this happened**.
The pre-Sprint-5 screen had:

- a customer **dropdown** that forced users to leave the form to create
  customers that didn't exist yet;
- only an "Issue" button (no draft-save), so a half-finished invoice
  immediately auto-posted a JE if the user clicked save;
- a generic success snackbar that quietly mentioned the JE id but
  gave no link to verify it.

Sprint 5 fixes all three:

```
┌──────────────── Sales Invoice Create (Sprint 5) ────────────────┐
│                                                                 │
│  /app/erp/sales/invoice-create                                  │
│  ────────────────────────────────                               │
│                                                                 │
│  Customer:  [CustomerPickerOrCreate ────┐                       │
│             autocompletes               │                       │
│             "+ عميل جديد" ──▶ CustomerCreateModal              │
│                                          (auto-selects on save) │
│                                                                 │
│  Description, Amount, VAT %, dates                              │
│                                                                 │
│  [حفظ كمسودة] [إنشاء وإصدار — يرحَّل القيد تلقائياً]            │
│       │              │                                          │
│       │              ↓ POST /sales-invoices                     │
│       │              ↓ POST /sales-invoices/{id}/issue          │
│       │              ↓ TRIGGERS _post_sales_invoice_je           │
│       │              ↓ 3-leg JE posted                          │
│       │                                                         │
│       │              SnackBar: "تم إصدار الفاتورة #INV-001 —    │
│       │                         قيد اليومية #JE-XXX"            │
│       │                         [عرض القيد] ──▶ /je-builder      │
│       │                                                         │
│       └─ POST /sales-invoices (status=draft)                    │
│          NO /issue call → NO JE auto-post                       │
│          SnackBar: "تم حفظ المسودة #INV-001 — لم يُرحَّل القيد"  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Files

| File | Change |
|---|---|
| [sales_invoice_create_screen.dart](../apex_finance/lib/screens/operations/sales_invoice_create_screen.dart) | Replaced dropdown with `CustomerPickerOrCreate`, split `_submit` into `_buildPayload` + `_saveDraft` + `_submit`, success snackbar surfaces `journal_entry_id` with action button. |
| [sales_invoice_je_autopost_test.dart](../apex_finance/test/screens/sales_invoice_je_autopost_test.dart) | 6 source-grep contracts pinning the picker import, the draft-skips-issue rule, the create-then-issue order, the snackbar JE-link, and the 2-button ratchet. |

## What's NOT in this sprint

This sprint does not deliver:

- **Multi-line invoices.** The screen still has a single description
  + amount + VAT-rate triplet. The backend's `SalesInvoiceCreate`
  schema accepts a `lines: list[SalesInvoiceLineInput]` but the
  current UI builds a single-element list. Multi-line support
  (with per-line product picker + barcode scan) is deferred to a
  future sprint that bundles it with the Product Catalog work
  (Sprint 4). Single-line covers the common case for service-type
  invoices and is sufficient for the JE auto-post flow this sprint
  pins.
- **Inventory / COGS JE.** The optional second JE
  (`DR COGS / CR Inventory`) for product lines is also deferred —
  it lives at the line-level and only fires when `product_id` is set.
  The current screen never sets `product_id`, so the COGS JE never
  runs today. When multi-line + product picker land, the COGS leg
  becomes meaningful.

## Verification — manual UAT

Pre-conditions: a tenant with at least 1 entity + branch + the seeded
SOCPA chart of accounts (achievable via the demo-data seeder at
`POST /api/v1/account/seed-demo-data`).

1. Navigate to `/app/erp/sales/invoice-create`.
2. In the customer field, type "احمد" (no existing match).
3. Click `+ عميل جديد` from the dropdown bottom row → modal opens
   pre-filled with `name_ar=احمد`.
4. Fill VAT="300123456789012" (15 digits), save the modal.
5. Picker auto-selects the new customer.
6. Description: "خدمات استشارية", amount: "1000", VAT: "15".
7. Click "حفظ كمسودة".
8. Expected: SnackBar "تم حفظ المسودة #INV-XXX — لم يُرحَّل القيد بعد".
9. Navigate to `/app/erp/finance/je-builder` — expect NO new JE.
10. Navigate to `/app/erp/finance/sales-invoices` — see the draft.
11. Click the draft → from the existing list screen, issue it.
12. Navigate back to `/app/erp/finance/je-builder` — expect a new
    JE with 3 lines:
    - DR Customer Receivable: 1150
    - CR Sales Revenue: 1000
    - CR VAT Output: 150
13. Trial Balance should now show the AR balance increase, the
    revenue credit, and the VAT-output credit.

## Test coverage

[sales_invoice_je_autopost_test.dart](../apex_finance/test/screens/sales_invoice_je_autopost_test.dart) — 6 source-grep tests:

1. The screen imports `CustomerPickerOrCreate` and uses it instead
   of a `DropdownButtonFormField<String>`.
2. `_saveDraft` calls `pilotCreateSalesInvoice` but NEVER
   `pilotIssueSalesInvoice` (so drafts don't auto-post JEs).
3. `_submit` calls create THEN issue, in that order.
4. Success snackbar reads `journal_entry_id` from the response,
   shows it in Arabic, and offers an action button labelled
   "عرض القيد" linking to `/app/erp/finance/je-builder`.
5. The bottom action row has BOTH buttons: "حفظ كمسودة" and
   "إنشاء وإصدار".
6. The G-FIN-SALES-INVOICE-JE-AUTOPOST marker comment is preserved.

Why source-grep instead of WidgetTester: same as Sprints 1+2 —
the screen transitively loads `package:web` which fails the
SDK-mismatch gate in Dart-VM tests (G-T1.1). Source-grep pins the
structural contract without needing to render the widget tree.
