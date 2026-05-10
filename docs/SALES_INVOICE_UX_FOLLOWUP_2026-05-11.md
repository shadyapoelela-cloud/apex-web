# Sales Invoice UX — Follow-up (G-SALES-INVOICE-UX-FOLLOWUP)

**Status:** in force as of 2026-05-11.
**Closes:** 2 bugs + 4 spec gaps surfaced in the QA report on PR #187.

---

## What this PR ships

### 🔴 Bug fixes

| Bug | Symptom | Root cause | Fix |
|---|---|---|---|
| **A** | Details screen rendered correctly above the fold but mouse-wheel / Page_Down / touch-scroll never reached the totals / payments / "+ تسجيل دفع" button | `SingleChildScrollView` attached to the outer ApexMagneticShell's PrimaryScrollController and silently lost wheel events | Explicit `ScrollController` + `Scrollbar(thumbVisibility:true)` + `PrimaryScrollController.none` wrapper + `AlwaysScrollableScrollPhysics` |
| **B** | Selecting a product in the create-invoice picker filled description but left "المبلغ (قبل VAT)" empty | `pilotListProducts` returns `ProductRead` (no `variants`); handler read `p['variants']?.first?['list_price']` and always saw null | `_onProductSelected` now branches: use inline variants when present (modal-create path), else fetch `/pilot/products/{id}` for `ProductDetail` and read `list_price` |

### 🟢 Spec compliance

| Gap | What spec asked | What this PR ships |
|---|---|---|
| **Edit** on details (draft only) | Open create-screen with prefill | Edit button gated on `isDraft`, routes to `/invoice-create?invoice_id=...`. Prefill flow itself bookmarked for next sprint. |
| **Cancel** on details | Cancel if not paid | Cancel button gated on `!isPaid && !isCancelled && paid≤0.001`. Opens confirmation dialog. Backend `POST /sales-invoices/{id}/cancel` reverses any posted JE via `reverse_journal_entry`. |
| **Print** on details | Print invoice + QR + barcode | Print button gated on `!isDraft`. Calls `html.window.print()` via `kIsWeb`. Current viewport (QR + invoice payload) prints as a one-page copy. |
| **`notes`** in PaymentModal | Free-text note | Always-visible 2-line field. |
| **`bank_account`** in PaymentModal | Dropdown when method=transfer | Text field, conditional on `method=='bank_transfer'`. |

Both extra payment fields merge into the existing `reference` wire field with Arabic labels (`بنك:` / `ملاحظات:`) since the backend `CustomerPayment` model has no separate columns. The audit trail (JE memo + AR ledger) captures the full context.

### What's still deferred

| Item | Status |
|---|---|
| Multi-line invoices (`+ بند` button + per-line table) | next sprint |
| Edit pre-fill flow (read `?invoice_id=` and populate fields) | next sprint |
| Server-side debounced product search | next sprint |
| Camera-based barcode scanner (`getUserMedia`) | future |
| Stock-warning badge in picker | future |
| CODE128 internal barcode | future |
| Dedicated print template (vs current `window.print()`) | future |

## Backend changes

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v1/pilot/sales-invoices/{id}/cancel` | POST | New — moves invoice → cancelled; reverses any posted JE; rejects 409 if paid_amount > 0 |

`reverse_journal_entry()` (existing in `gl_engine.py`) is the workhorse — sets `source_type='je_reversal'` on the new JE and `status='reversed'` on the original.

## Test coverage

### Frontend — 12 tests in [`sales_invoice_ux_followup_test.dart`](../apex_finance/test/screens/sales_invoice_ux_followup_test.dart)

| Group | Tests |
|---|---|
| Bug A scroll | 2 (explicit ScrollController + dispose) |
| Bug B unit_price | 2 (Future return + inline-variant short-circuit) |
| Cancel action | 3 (backend endpoint, api method, confirmation dialog) |
| Edit + Print | 2 (Edit gated on isDraft, Print uses kIsWeb + html.window.print) |
| Payment modal | 3 (notes always visible, bank_account conditional, payload merge) |

### Backend — 3 tests in [`tests/test_sales_invoice_cancel.py`](../tests/test_sales_invoice_cancel.py)

1. `test_cancel_draft_invoice_succeeds` — no JE to reverse → status=cancelled
2. `test_cancel_issued_invoice_reverses_je` — reversal JE created, original marked `reversed`
3. `test_cancel_invoice_with_payment_is_rejected` — 409 with "applied payments" message

All pass: **12/12 + 3/3 = 15/15**.

## Manual UAT (after deploy)

The user that wrote the QA report can re-test with the same account (`uat-2026-05-09@apex.test` / `UatTest9876!`) and invoice **INV-2026-0002** (still issued, remaining=1150):

1. List → tap INV-2026-0002 → details screen opens.
2. **Bug A check**: scroll down with mouse wheel → expect to see Totals + "+ تسجيل دفع" button.
3. Click "+ تسجيل دفع" → modal opens.
4. Pick method=bank_transfer → **bank_account field appears**.
5. Fill amount=500, bank="بنك الراجحي", notes="دفعة جزئية" → save.
6. Expect snackbar with JE id. Invoice status → partially_paid.
7. Back to details. Click **Cancel** button → confirmation dialog → confirm.
8. Expect 409: "cannot cancel: invoice has applied payments" (Bug-A confirms because payment exists).
9. Navigate to `/invoice-create` to create a fresh **draft**.
10. Pick product PRD-001 from picker → **Bug B check**: "المبلغ (قبل VAT)" auto-fills to 150.
11. Save as draft. Open it. Click **Edit** → should route to `/invoice-create?invoice_id=...`.
12. Click **Cancel** on a fresh draft → confirm → status=cancelled (no JE since draft never issued).
13. Click **Print** on any non-draft invoice → browser print dialog.
