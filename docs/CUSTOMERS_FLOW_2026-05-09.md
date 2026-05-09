# Customers Flow — G-FIN-CUSTOMERS-COMPLETE

**Status:** in force as of 2026-05-09 (Sprint 2 of the Finance Module
7-sprint plan).
**Closes:** Sprint 1 audit Gap §3 row 1 ("Customer creation form
missing") + row 2 ("Customer details screen — clicking a customer
goes nowhere").

---

## TL;DR

Pre-Sprint-2, the Customers chip rendered a list. Clicking the
`+ جديد` button routed to `/sales` (a placeholder). Clicking a
customer routed to `/operations/customer-360/:id` — a route that
was archived in Sprint 15 Stage 4f, so users hit the "coming soon"
banner.

Post-Sprint-2:

```
┌────────────── Customers Flow (Sprint 2) ──────────────┐
│                                                       │
│  /app/erp/finance/sales-customers                     │
│       │                                               │
│       ├──[+ جديد]──▶ CustomerCreateModal              │
│       │              (POST /pilot/tenants/{tid}/customers) │
│       │              ↓ on success                     │
│       │              SnackBar + _load() inline        │
│       │                                               │
│       └──[row tap]──▶ /app/erp/finance/customers/:id  │
│                       │                               │
│                       ├─ tab 1: تفاصيل                │
│                       │  GET /pilot/customers/{id}    │
│                       │                               │
│                       ├─ tab 2: السجل المالي          │
│                       │  GET /pilot/customers/{id}/ledger │
│                       │                               │
│                       └─ tab 3: الفواتير              │
│                          GET /pilot/entities/{eid}/sales-invoices │
│                          filtered by customer_id      │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## Files

| File | Purpose |
|---|---|
| [customer_create_modal.dart](../apex_finance/lib/screens/operations/customer_create_modal.dart) | Modal dialog. 14 fields (incl. KSA-15-digit VAT validator + auto code generation). `show(context, initialNameAr: ...)` returns the created customer Map. |
| [customer_details_screen.dart](../apex_finance/lib/screens/operations/customer_details_screen.dart) | 3-tab details screen. Each tab has its own loader + empty state. |
| [customer_picker_or_create.dart](../apex_finance/lib/widgets/forms/customer_picker_or_create.dart) | Reusable autocomplete picker with inline `+ عميل جديد` that opens the modal pre-filled with the typed query. Used in this sprint by the picker only; consumed by Sprint 5's Sales Invoice line picker. |
| [customers_list_screen.dart](../apex_finance/lib/screens/operations/customers_list_screen.dart) | `_onCreate` rewritten to open the modal + refresh inline; row tap routes to the new finance details path. |
| [router.dart](../apex_finance/lib/core/router.dart) | New GoRoute `/app/erp/finance/customers/:customerId` → `CustomerDetailsScreen`. |

## API endpoints

All exist server-side already; this sprint adds zero backend code.

| Endpoint | Used by |
|---|---|
| `GET /pilot/tenants/{tid}/customers` | list + picker autocomplete |
| `POST /pilot/tenants/{tid}/customers` | modal save |
| `GET /pilot/customers/{id}` | details tab 1 |
| `GET /pilot/customers/{id}/ledger` | details tab 2 |
| `GET /pilot/entities/{eid}/sales-invoices` | details tab 3 (filtered client-side by `customer_id`) |

## Validation rules

- `name_ar` — required (the only required field).
- `code` — auto-generated as `CUST-001`, `CUST-002`, ... when blank;
  uses `pilotListCustomers` to find the highest existing code and
  increments. Manual override accepted.
- `vat_number` — when provided, must be exactly 15 digits (KSA TIN).
- `email` — when provided, must contain `@` and `.`.
- All other fields optional.

## Test coverage

[customers_complete_test.dart](../apex_finance/test/screens/customers_complete_test.dart) — 8 source-grep contracts:

1. `CustomerCreateModal.show` returns `Future<Map<String, dynamic>?>`.
2. The modal payload includes the 13 documented fields.
3. The 15-digit VAT validator is in place.
4. List `+ جديد` opens the modal and refreshes inline (no `/sales`
   redirect).
5. List row tap uses the new `/app/erp/finance/customers/:id` route
   (not the archived `/operations/customer-360/:id`).
6. Details screen has 3 tabs each backed by the right pilot endpoint.
7. Details screen filters tab 3 by `customer_id`.
8. Router declares the new GoRoute and builds `CustomerDetailsScreen`.

Why source-grep instead of WidgetTester: the customer screens
transitively load `package:web` which fails the SDK-mismatch gate in
Dart-VM tests (G-T1.1). Source-grep pins the structural contract
without needing to render the widget tree.

## Verification — manual UAT

1. Navigate to `/app/erp/finance/sales-customers`.
2. Click `+ جديد` → modal opens.
3. Fill name "عميل اختبار", VAT "300123456789012" (15 digits), city "الرياض".
4. Click "حفظ" → modal closes, SnackBar shows "تم إنشاء العميل عميل اختبار (CUST-XXX)".
5. New row appears at the top of the list.
6. Click the new row → `/app/erp/finance/customers/{id}` opens.
7. Tab 1 shows the basic info; Tab 2 is empty (no ledger entries yet);
   Tab 3 is empty (no invoices yet).
8. Try the same flow with VAT "12345" (5 digits) → modal shows
   "الرقم الضريبي 15 رقماً" inline error and refuses to save.

## Roadmap context

| Sprint | Status | Headline |
|---|---|---|
| 1 (G-FIN-AUDIT-CLEANUP) | ✅ merged | Audit doc, V52 banners, routing test pin |
| **2 (G-FIN-CUSTOMERS-COMPLETE)** | **this PR** | **Customer create modal + details + picker** |
| 3 (G-FIN-VENDORS-COMPLETE) | next | Same pattern for vendors (IBAN, payment_terms=net_60) |
| 4 (G-FIN-PRODUCT-CATALOG) | future | Wizard, EAN13, scanner |
| 5 (G-FIN-SALES-INVOICE-JE) | future | Sales invoice create screen — backend already auto-posts JE |
| 6 (G-FIN-PURCHASE-INVOICE-JE) | future | Purchase invoice create screen |
| 7 (G-FIN-POS-JE) | future | POS daily summary |
