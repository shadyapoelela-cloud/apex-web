# Sales Invoice UX — G-SALES-INVOICE-UX-COMPLETE

**Status:** in force as of 2026-05-10.
**Closes:** 4 user-reported issues from the live UAT walkthrough on
[the deployed bundle](https://shadyapoelela-cloud.github.io/apex-web/).

---

## TL;DR

A user-reported audit on the live invoice flow surfaced four issues:

| # | Severity | Issue | Resolution |
|---|---|---|---|
| 1 | 🔴 Bug | List-row click jumped to JE-builder, skipping the invoice | New `SalesInvoiceDetailsScreen` + GoRoute; row click → `/sales-invoices/:id` |
| 2 | 🟠 UX | Line was a free-text box with no product link or barcode | `ProductPickerOrCreate` integrated; auto-fills description + price + VAT |
| 3 | 🟢 Feature | No way to record a payment from the invoice | New `CustomerPaymentModal` + backend auto-JE |
| 4 | 🟢 Feature | No invoice barcode / QR for ZATCA Phase 1 | TLV helper + `qr_flutter` rendering on details screen |

---

## Architecture changes

### Backend

| File | Change |
|---|---|
| [`app/pilot/routes/customer_routes.py`](../app/pilot/routes/customer_routes.py) | Added `GET /sales-invoices/{id}` (full detail + lines + payments). Added `_post_customer_payment_je` helper. Updated `record_customer_payment` to auto-build + post the payment JE and reject overpayments (409). |
| [`app/pilot/services/gl_engine.py`](../app/pilot/services/gl_engine.py) | Added `1310 — Cheques on Hand` to the seeded SOCPA CoA so cheque payments have a real settlement-pending account. |

### Frontend

| File | Change |
|---|---|
| [`apex_finance/lib/screens/operations/sales_invoice_details_screen.dart`](../apex_finance/lib/screens/operations/sales_invoice_details_screen.dart) | NEW — header + KPIs + lines table + totals + JE-link banner + payment history + ZATCA QR + action row. |
| [`apex_finance/lib/screens/operations/customer_payment_modal.dart`](../apex_finance/lib/screens/operations/customer_payment_modal.dart) | NEW — payment dialog (cash / bank / cheque / card / mada). Validates client-side overpayment. |
| [`apex_finance/lib/core/zatca_tlv.dart`](../apex_finance/lib/core/zatca_tlv.dart) | NEW — pure-Dart Phase 1 TLV byte builder + base64 wrapper. |
| [`apex_finance/lib/screens/operations/sales_invoices_screen.dart`](../apex_finance/lib/screens/operations/sales_invoices_screen.dart) | `_openInvoice` rewired from `/je-builder/{jeId}` to `/sales-invoices/{id}`. |
| [`apex_finance/lib/screens/operations/sales_invoice_create_screen.dart`](../apex_finance/lib/screens/operations/sales_invoice_create_screen.dart) | Added `ProductPickerOrCreate` above the description field; selecting a product auto-fills description, unit_price (from variant.list_price), and vat_rate (0 for zero_rated/exempt, else 15). Persists `product_id` + `variant_id` on the line payload. |
| [`apex_finance/lib/api_service.dart`](../apex_finance/lib/api_service.dart) | New method `pilotGetSalesInvoice(id)`. |
| [`apex_finance/lib/core/router.dart`](../apex_finance/lib/core/router.dart) | New GoRoute `/app/erp/finance/sales-invoices/:invoiceId`. |

---

## Sales Invoice flow (after this PR)

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  /app/erp/finance/sales-invoices                                 │
│  ──────────────────────────                                      │
│      │                                                           │
│      ├──[+ جديد]──▶ /app/erp/sales/invoice-create                │
│      │                                                           │
│      │             [CustomerPicker] [ProductPicker]              │
│      │             [حفظ كمسودة] [إنشاء وإصدار]                  │
│      │             ─────────────────────                         │
│      │                       │                                   │
│      │                       ▼                                   │
│      │             POST /sales-invoices                          │
│      │             POST /sales-invoices/{id}/issue               │
│      │             → JE auto-post (3-leg)                        │
│      │             → snackbar with [عرض القيد]                  │
│      │                                                           │
│      └──[row tap]──▶ /sales-invoices/{id}  ◀── BUG #1 FIX        │
│                                                                  │
│           SalesInvoiceDetailsScreen                              │
│           ─────────────────────                                  │
│           Header: invoice# + status + customer + dates           │
│                   + ZATCA QR (Phase 1 TLV → base64)              │
│           [قيد اليومية #JE-X — عرض القيد]                       │
│           Lines table | Totals | Payment history                │
│                                                                  │
│           Actions:                                               │
│             draft     → [إصدار]                                  │
│             issued    → [+ تسجيل دفع] ──▶ CustomerPaymentModal   │
│             paid      → "✓ مدفوعة بالكامل"                       │
│                                                                  │
│           [+ تسجيل دفع]                                          │
│                │                                                 │
│                ▼                                                 │
│           POST /sales-invoices/{id}/payment                     │
│           ↓ auto-builds payment JE                              │
│           ↓ DR Cash(1110)/Bank(1120)/Cheque(1310)               │
│           ↓ CR AR(1130)                                          │
│           → snackbar with [عرض القيد] for the new JE             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## ZATCA QR — Phase 1 TLV

The QR data is built client-side using a pure-Dart helper
([`zatca_tlv.dart`](../apex_finance/lib/core/zatca_tlv.dart)). 5 tags,
1-byte length per Phase 1 spec:

| Tag | Field | Source |
|----|---|---|
| 1 | Seller name (UTF-8) | tenant legal name |
| 2 | VAT registration number | customer.vat_number (placeholder until tenant.vat_number persists) |
| 3 | Invoice timestamp (ISO-8601, UTC) | invoice.issue_date |
| 4 | Invoice total (with VAT) | invoice.total |
| 5 | VAT total | invoice.vat_amount |

Drafts show a "after issuance" placeholder — the QR is meaningful
only once issue_date and totals are committed.

Phase 2 fields (Tag 6+: signature, CSID, hash chain) are added by the
ZATCA submission service server-side and are out of scope here.

## Payment method routing

The `_post_customer_payment_je` helper picks the debit account by
method:

| `method` | Debit account | Why |
|---|---|---|
| `cash` | 1110 — Cash on hand | direct cash receipt |
| `bank_transfer` | 1120 — Bank | wire / direct deposit |
| `card` / `mada` | 1120 — Bank | settles via merchant gateway, posts to bank within ~24h |
| `cheque` (`check`) | 1310 — Cheques on Hand (NEW) | float account — bank deposit happens later, then a separate JE moves it from 1310 to 1120 |
| (anything else) | 1120 — Bank | conservative fallback |

The credit leg is always `1130 — Accounts Receivable` (or whichever
account is at `subcategory='receivables'` if 1130 is missing).

## Test coverage

### Frontend — 16 tests in [`sales_invoice_ux_test.dart`](../apex_finance/test/screens/sales_invoice_ux_test.dart)

| Group | Tests |
|---|---|
| Bug #1 fix | 2 (list rewire + GoRoute) |
| Details screen contract | 4 (endpoint, JE link, QR conditional render, payment-button gate) |
| Product picker | 3 (import, auto-fill, payload includes product_id) |
| Payment modal | 3 (return type, overpayment client-validation, calls record-payment) |
| ZATCA TLV | 4 real unit tests (5-tag layout, Arabic UTF-8 byte length, 256-byte rejection, base64 round-trip) |

### Backend — 5 tests in [`tests/test_invoice_payment_je.py`](../tests/test_invoice_payment_je.py)

1. `test_payment_creates_je_balanced` — DR == CR == 1150
2. `test_full_payment_marks_invoice_paid`
3. `test_partial_payment_marks_partially_paid`
4. `test_payment_method_routes_to_correct_account` — cash→1110, bank→1120, cheque→1310
5. `test_overpayment_rejected` — 2000 > 1150 → 409

All pass: 16/16 + 5/5 = **21/21**.

## Manual UAT (10-step script)

Pre-conditions: a fresh user with seeded entity + branch + CoA + fiscal periods + at least one customer and one product (the
[Sprint 1-7 audit's UAT user `uat-2026-05-09@apex.test`](#) qualifies).

1. **Navigate** to `/app/erp/finance/sales-invoices`.
2. **Click `+ جديد`** → land on `/app/erp/sales/invoice-create`.
3. **Customer picker**: type "عميل" → see existing matches → pick one. Or click `+` to inline-create.
4. **Product picker (NEW)**: type the first letters of an existing product, OR click the QR icon and scan/type a barcode. On selection: description, unit_price, vat_rate auto-fill.
5. **Issue**: click "إنشاء وإصدار". Snackbar: "تم إصدار الفاتورة #INV-X — قيد اليومية #JE-X" with `[عرض القيد]` action.
6. **List**: navigate back to `/sales-invoices`. Click the row.
7. **Expect**: `/app/erp/finance/sales-invoices/{id}` opens — NOT the JE-builder. **This is the Bug #1 fix.**
8. **Verify** the QR code renders top-right of the header.
9. **Click `+ تسجيل دفع`** → modal opens with the remaining balance pre-filled. Pick method=cash, click "حفظ".
10. **Expect**: snackbar "تم تسجيل الدفع — قيد اليومية #JE-Y" with `[عرض القيد]`. Status changes to "مدفوعة" (or "مدفوعة جزئياً" if the amount was partial). Payment appears in the "سجل المدفوعات" section. Trial Balance reflects the new JE (`Cash ↑`, `AR ↓`).

## Roadmap notes

This PR completes the user-reported invoice UX. Out of scope (deferred):

- **Multi-line invoices**: still single-line. The picker integration is per-line-ready — the next sprint can wrap it in a list and add an "+ بند" button.
- **Cheque clearing JE**: when the cheque settles in the bank, a follow-up JE moves `1310 → 1120`. Today this is a manual JE; auto-posting it on a "mark cleared" action is a future feature.
- **Print-preview view**: the QR renders inline on the details screen but there is no dedicated print layout yet. The QR data is already produced by `zatcaQrBase64` so a print template can render it directly.
