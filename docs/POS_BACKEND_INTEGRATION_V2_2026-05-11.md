# G-POS-BACKEND-INTEGRATION-V2 — POS Quick Sale Architectural Fix

**Date:** 2026-05-11
**Branch:** `feat/g-pos-backend-integration-v2`
**Prior attempt:** PR #196 (`feat/g-pos-backend-integration`) — REJECTED for forcing `variant_id` as REQUIRED on every line, which broke ad-hoc cash sales.

## The architectural problem

Pre-fix, `pos_quick_sale_screen.dart::_submit` called the **B2B sales-invoice pipeline**:

  1. `POST /pilot/sales-invoices` — creates a draft B2B invoice
  2. `POST /pilot/sales-invoices/{id}/issue` — issues + posts a JE

This produced four serious accounting + compliance defects:

| Defect | Root cause | Impact |
|---|---|---|
| **Ghost AR / JE doubling** | B2B JE posts `Dr AR / Cr Sales+VAT` but POS never recorded a customer payment | Phantom A/R balance grows on every cash sale; trial balance no longer reflects reality. |
| **No stock deduction** | Sales-invoice flow doesn't touch `pilot_stock_movements` | Inventory on hand stays unchanged after a POS sale → reorder logic + stock card go stale. |
| **Empty Z-Report** | POS Quick Sale never attached to a `pilot_pos_sessions` row | `/pilot/pos-sessions/{sid}/z-report` returns zero sales even after a full day of POS rings. |
| **Wrong ZATCA document type** | B2B invoice carries `invoice_number` (INV-…) + B2B QR fields | ZATCA scanner reads the wrong document subtype (B2B vs B2C simplified). |
| **No session lock** | Any cashier could keep ringing after Z-close | Audit trail broken — sales after close go to the next day's batch. |

The backend already has the right endpoints — frontend just had to call them.

## The fix — POS endpoint flow

### Backend

`POST /pilot/pos-transactions` (`app/pilot/routes/pos_routes.py:498`) already:

  * locks an open `pilot_pos_sessions` row
  * for each catalogued line, runs price-lookup + writes a signed `pilot_stock_movements` row
  * posts a single JE through `auto_post_pos_sale` (`Dr Cash / Cr Sales / Cr VAT`)
  * updates the session roll-up (transaction_count, gross_sales, vat_total, net_sales)
  * generates a `RCT-...` receipt number + ZATCA QR placeholder

The catch: `PosLineInput.variant_id` was **required**. That works for catalogued SKUs but breaks the cashier's most common workflow:

  * a service charge ("Car-park fee 20 SAR")
  * a custom item with no barcode ("Gift wrap")
  * a quick ring without scanning ("بيع نقدي" / "Cash sale")

### Soft variant_id pattern

This PR introduces a **discriminator** on `PosLineInput`:

```python
class PosLineInput(BaseModel):
    variant_id: Optional[str] = None
    qty: Decimal
    is_misc: bool = False               # ← discriminator
    description: Optional[str] = None
    unit_price_override: Optional[Decimal] = None
    vat_rate_override: Optional[Decimal] = None
    # ... other fields ...

    @model_validator(mode="after")
    def _check_variant_vs_misc(self) -> "PosLineInput":
        if not self.is_misc:
            if not self.variant_id:
                raise ValueError("variant_id مطلوب للبنود المُفهرَسة")
        else:
            if not self.description or not self.description.strip():
                raise ValueError("description مطلوب للبنود المتنوّعة")
            if self.unit_price_override is None:
                raise ValueError("unit_price_override مطلوب للبنود المتنوّعة")
        return self
```

Route-handler branches in `app/pilot/routes/pos_routes.py::create_transaction`:

  * `is_misc=False` (default) → original behaviour: variant lookup, price-lookup, StockMovement, JE.
  * `is_misc=True` → skip StockMovement (no inventory to deduct), use the supplied `description` + `unit_price_override`, compute VAT from `vat_rate_override` or `CompanySettings.default_vat_rate`.

Model changes in `app/pilot/models/pos.py::PosTransactionLine`:

  * `variant_id`: `NOT NULL` → `NULL` (misc rows omit it)
  * `sku`: `NOT NULL` → `NULL`
  * new column `is_misc: Boolean NOT NULL DEFAULT False`

Migration: `alembic/versions/k9a1b3d5e7f2_pos_line_soft_variant.py` — idempotent batch-alter (same pattern as the j7e2 hand-written sibling migrations).

### Frontend

Three new `ApiService` methods in `apex_finance/lib/api_service.dart`:

```dart
pilotCreatePosTransaction(payload)        // POST /pilot/pos-transactions
pilotPostPosTransactionToGl(id)           // POST /pilot/pos-transactions/{id}/post-to-gl
pilotListOpenPosSessions(branchId)        // GET  /pilot/branches/{bid}/pos-sessions?status=open&limit=1
pilotListBranchesForEntity(entityId)      // GET  /pilot/entities/{eid}/branches
```

`S.savedBranchId` getter/setter in `apex_finance/lib/core/session.dart` persists the resolved branch to `pilot.branch_id` localStorage key so subsequent sales skip the lookup. Cleared by `S.clear()`.

`pos_quick_sale_screen.dart::_submit` refactored:

  1. Resolve branch (`S.savedBranchId` → `pilotListBranchesForEntity` → first active).
  2. Ensure open session (`pilotListOpenPosSessions` → `pilotCreatePosSession` if empty).
  3. Auto-provision cash customer (`pilotListCustomers` → `pilotCreateCustomer({name_ar: 'العميل النقدي'})` if empty).
  4. Build `PosTransactionCreate` payload, per-line branch:
     * Product picked: `{variant_id, qty, unit_price_override, vat_rate_override, is_misc: false}`
     * No product:    `{description, qty, unit_price_override, vat_rate_override, is_misc: true}`
  5. `pilotCreatePosTransaction(payload)` → capture `id` + `receipt_number` + `journal_entry_id`.
  6. `pilotPostPosTransactionToGl(id)` → guarantee JE is posted.
  7. Receipt card shows `إيصال #RCT-...` (not `فاتورة #INV-...`).

### Method-code mapping

The `ApexPaymentMethod` enum maps to backend strings via `_methodCode`:

| UI enum | Backend `PosPaymentInput.method` |
|---|---|
| `cash` | `cash` |
| `mada` | `mada` |
| `stcPay` | `stc_pay` |
| `applePay` | `apple_pay` |
| `card` | `visa` (generic card → visa scheme) |
| `bankTransfer` | `bank_transfer` |

Backend regex: `^(cash|mada|visa|mastercard|amex|stc_pay|apple_pay|google_pay|samsung_pay|tamara|tabby|gift_card|store_credit|bank_transfer|other)$`.

## After-state guarantees

| Concern | After-state |
|---|---|
| **Single JE** | One JE posted per POS sale via `auto_post_pos_sale`. No phantom AR. |
| **Stock deduction** | Catalogued lines write `pilot_stock_movements` with `reason='pos_sale'`. Misc lines skip (nothing to deduct). |
| **Z-Report** | Every POS sale attaches to an open session — roll-up fields (`gross_sales`, `vat_total`, `net_sales`, `transaction_count`) update live. |
| **ZATCA QR** | Phase-1 TLV QR still rendered (preserved from PR #192). Document subtype now correctly B2C simplified. |
| **Session lock** | If session is `closed`/`force_closed`, backend returns 409. Cashier must explicitly open a new session. |

## Manual UAT

### A. Catalogued line path (variant)

  1. Onboard a tenant + entity + active branch.
  2. Create a product with `default_variant_id` set + a price-list entry.
  3. Open the POS Quick Sale screen.
  4. Pick the product in line 1 (price + description auto-fill).
  5. Pick `cash` payment, click "سجّل البيع".
  6. **Expect:** receipt card shows `إيصال #RCT-...`, JE link works, `pilot_stock_movements` has a new row with negative qty, Z-report shows the sale in the breakdown.

### B. Misc line path (ad-hoc cash sale)

  1. Same setup.
  2. Open POS Quick Sale. Do NOT pick a product.
  3. Type `بيع نقدي - رسوم موقف` in description.
  4. Enter qty=1, price=20, VAT=15.
  5. Pick `cash`, click "سجّل البيع".
  6. **Expect:** receipt card shows `إيصال #RCT-...`, JE link works, **NO** new `pilot_stock_movements` row (nothing to deduct), Z-report still shows the sale.

### C. Mixed line path

  1. Same setup.
  2. Line 1: pick product (variant path).
  3. Line 2: leave product empty, type description + price (misc path).
  4. Click "سجّل البيع".
  5. **Expect:** receipt has 2 lines, stock movement only for line 1, JE single-posts the combined total.

### D. Session lock

  1. Open POS Quick Sale, ring a sale.
  2. Close the session from the daily-report screen.
  3. Try to ring another sale.
  4. **Expect:** 409 from `_open_session_or_409` — frontend either auto-opens a new session or shows a clear error.

## Compatibility

  * `pilotCreateSalesInvoice` + `pilotIssueSalesInvoice` remain in `api_service.dart` — used by the **real** B2B sales-invoice screens. POS is the only caller that switched away.
  * `pilot_client.dart` (legacy v4 POS path) is **untouched** — soft constraint per the PR brief.
  * `ProductPickerOrCreate` behaviour is **untouched** — soft constraint per the PR brief.
  * `pilotPostPosToGL` (camelCase legacy alias) is preserved alongside the new `pilotPostPosTransactionToGl`.

## Files touched

```
app/pilot/schemas/pos.py                 ← PosLineInput soft variant + validator
app/pilot/models/pos.py                  ← PosTransactionLine.is_misc + nullable variant_id/sku
app/pilot/routes/pos_routes.py           ← branch on is_misc in create_transaction loop
alembic/versions/k9a1b3d5e7f2_pos_line_soft_variant.py
                                         ← idempotent migration

apex_finance/lib/api_service.dart        ← 4 new POS methods
apex_finance/lib/core/session.dart       ← savedBranchId getter/setter
apex_finance/lib/screens/operations/pos_quick_sale_screen.dart
                                         ← _submit refactored

apex_finance/test/screens/pos_backend_integration_v2_test.dart
                                         ← 16 source-grep contracts
apex_finance/test/screens/pos_multiline_cleanup_test.dart
                                         ← updated to assert new POS shape (qty / unit_price_override / vat_rate_override)
```
