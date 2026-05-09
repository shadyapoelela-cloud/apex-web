# Product Catalog — G-FIN-PRODUCT-CATALOG

**Status:** in force as of 2026-05-09 (Sprint 4 of the 7-sprint plan).
**Closes:** Sprint 1 audit Gap §3 row 4 ("Products — no UI to create
a product with variants/barcodes for use in invoices").

---

## Scope

This sprint delivers the **fast-path** invoice-line entry: a focused
modal + picker so users can add a product on the fly while creating
an invoice. The full multi-tab catalog management UI (categories,
brands, attribute matrices, multi-variant products) **already exists**
at [products_screen.dart](../apex_finance/lib/pilot/screens/setup/products_screen.dart) (2179 lines, 5 tabs) and is unchanged.

**What's new in this sprint:**

| File | Purpose |
|---|---|
| [product_create_modal.dart](../apex_finance/lib/screens/inventory/product_create_modal.dart) | Focused single-page modal, POSTs `/pilot/tenants/{id}/products` with one inline variant so the product is invoice-ready immediately. Stashes typed barcode on `_pending_barcode` for the caller to attach. |
| [product_picker_or_create.dart](../apex_finance/lib/widgets/forms/product_picker_or_create.dart) | Autocomplete picker with **3 input modes**: type-to-search, barcode lookup (Enter on numeric input or dedicated 🔲 button), inline `+ منتج جديد`. Used by Sprints 5/6 invoice line tables. |
| [barcode_utils.dart](../apex_finance/lib/core/barcode_utils.dart) | Pure-Dart EAN-13 helpers: `ean13CheckDigit(prefix12)` returns the standard mod-10 weighted-sum check digit; `generateEan13(prefix9)` produces a candidate full code. |
| [api_service.dart](../apex_finance/lib/api_service.dart) | New methods: `pilotGetProduct`, `pilotListProductVariants`, `pilotCreateProductVariant`, `pilotBarcodeLookup`, `pilotListCategories`, `pilotListBrands`. |

## Picker behavior

```
┌────────── ProductPickerOrCreate ──────────┐
│                                           │
│  [QR icon] [أدخل الاسم أو الباركود…] [📷] │
│                                           │
│  Type-to-search (text matches code, name):│
│    showing 10 hits                        │
│    ┌────────────────────────┐             │
│    │ منتج 1                 │             │
│    │ منتج 2                 │             │
│    │ ──────────────────     │             │
│    │ + منتج جديد           │── opens modal│
│    └────────────────────────┘             │
│                                           │
│  Numeric Enter / 🔲 button:               │
│    GET /pilot/tenants/{tid}/barcode/{v}   │
│       ├─ HIT → auto-select (snackbar)     │
│       └─ MISS → opens modal with          │
│                 initialBarcode pre-filled │
│                                           │
└───────────────────────────────────────────┘
```

## Test coverage

[product_catalog_test.dart](../apex_finance/test/screens/product_catalog_test.dart) — 12 tests, 12/12 pass:

| Group | Tests |
|---|---|
| EAN-13 check digit | 7 (known vectors `4006381333931`, `5901234123457`, all-zeros; rejects wrong length / non-digits; generator round-trip) |
| Modal contract | 3 (return type, inline variant in payload, `_pending_barcode` stashed on return) |
| Picker behavior | 2 (barcode lookup endpoint used, miss falls back to create with `initialBarcode`) |

## What's deferred to a future sprint

- **Multi-step wizard.** The audit asked for a 6-step wizard (basic /
  attributes / variants / barcodes / pricing / stock). The full
  catalog screen at `pilot/screens/setup/products_screen.dart`
  already covers most of this in a tab-based layout. A wizard
  redesign is a UX project that doesn't move the JE auto-post
  needle — bookmarked as future work.
- **Camera-based barcode scanner.** The picker accepts barcode input
  via keyboard (USB scanners emit keystrokes, so this works for the
  most common KSA POS hardware today). A web-based camera scanner
  using `getUserMedia` is bookmarked separately.
- **Auto-attachment of `_pending_barcode`.** The modal stashes the
  typed barcode on the return map, but no consumer in this sprint
  POSTs it to `/variants/{vid}/barcodes`. Sprints 5/6 invoice
  pickers will read the stash and run the second call when needed.
