# G-PAYMENT-METHOD-VALIDATION — Strict method pattern on customer payment endpoint

**Date:** 2026-05-11
**Branch:** `fix/g-payment-method-validation`
**Severity:** 🟢 small — type safety

## The gap

Backend type-safety asymmetry between customer and vendor payment endpoints:

| Endpoint | Schema field | Pattern? |
|---|---|---|
| `VendorPaymentCreate.method` | `purchasing.py:337` | strict `^(cash|bank_transfer|cheque|credit_card|other)$` |
| `CustomerPaymentInput.method` | `customer_routes.py:162` (before) | plain `str`, default `"bank_transfer"` |

The customer endpoint silently accepted **any** string the client sent. A typo (`bnak_transfer`) or a junk value (`bitcoin`) would round-trip to the database and into the JE routing logic, which then fell into the else-branch and booked the payment as a `1120` (bank) entry — wrong account, but no error.

The Flutter modal at `apex_finance/lib/screens/operations/customer_payment_modal.dart` only ever sends one of five values: `cash`, `bank_transfer`, `cheque`, `card`, `mada`. The backend should match the modal contract.

## The fix

Single-line schema change at `app/pilot/routes/customer_routes.py`:

```python
# Before
method: str = "bank_transfer"

# After
method: str = Field(default="bank_transfer", pattern="^(cash|bank_transfer|cheque|card|mada)$")
```

Also added `Field` to the pydantic import on line 24.

### Why these five values?

They are exactly what the customer payment modal dropdown offers (Saudi-localized — `mada` is the local debit network, `card` is generic credit/debit). The vendor flow uses `credit_card` and `other` because the AP side is internal-facing and a clerk may need to record a wire from an unusual source. The two flows are intentionally different.

## JE routing — pre-existing behavior, now type-safe

`_post_customer_payment_je()` (`customer_routes.py:829`) routes the GL debit account by method:

| Method | Account code | Subcategory |
|---|---|---|
| `cash` | 1110 | cash |
| `cheque` (or `check`) | 1310 | cash_equivalent |
| `bank_transfer` | 1120 | bank (via else) |
| `card` | 1120 | bank (via else) |
| `mada` | 1120 | bank (via else) |

`card` and `mada` were already handled correctly by the else-branch comment: `# bank_transfer / card / mada / etc → bank`. The strict pattern now removes the "etc" — only the five allowed values can ever reach this routing logic.

## User-facing change

Before: posting `{ "method": "bitcoin" }` to `POST /sales-invoices/{id}/payment` returned 200 OK and booked the payment to 1120.

After: posting `{ "method": "bitcoin" }` returns:

```http
HTTP/1.1 422 Unprocessable Entity
{"detail":[{"type":"string_pattern_mismatch","loc":["body","method"], ...}]}
```

(Pydantic's standard validation error.)

## UAT steps

1. **Happy path — modal-sent values still work.** From the Flutter app, open a sales invoice with a remaining balance, tap "+ تسجيل دفع", pick each of cash / bank_transfer / cheque / card / mada, enter an amount, submit. Expect 200 OK and a payment row in the invoice's payments list.

2. **Invalid method via curl.** Bypassing the modal:
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"payment_date":"2026-05-11","amount":100,"method":"bitcoin"}' \
     https://<host>/pilot/sales-invoices/<id>/payment
   ```
   Expect 422 with `string_pattern_mismatch` in the response body. No payment row created.

3. **Typo via curl.**
   ```bash
   curl -X POST ... -d '{... ,"method":"bnak_transfer"}'
   ```
   Expect 422. Previously this would have silently posted as a bank payment.

4. **Vendor flow regression check.** Confirm vendor payment modal (purchase-invoice details screen, "+ تسجيل دفع") still works with `credit_card` — that endpoint uses a different schema with a different pattern; this change does not touch it.

5. **GL accounts.** After a successful `mada` payment, inspect the journal entry: the DR side should be account 1120 (bank). After a `cash` payment, DR should be 1110.

## Test contracts

`apex_finance/test/screens/payment_method_validation_test.dart` pins 7 source-grep contracts:

1. `CustomerPaymentInput.method` uses `Field(...)` with a pattern (CRLF-safe RegExp).
2. The pattern contains each of the 5 modal-sent values as a token.
3. The customer modal dropdown still offers the same 5 values (parity).
4. `VendorPaymentCreate` continues to use its own `^(cash|bank_transfer|cheque|credit_card|other)$` pattern (no collateral damage).
5. `_post_customer_payment_je` still routes `cash` → 1110/cash.
6. Same, for `cheque`/`check` → 1310/cash_equivalent.
7. Else-branch routes the remaining strict-pattern values (bank_transfer/card/mada) → 1120/bank.

All `\n` matches use `RegExp` rather than literal newlines — Windows CRLF safe.

## Files touched

- `app/pilot/routes/customer_routes.py` (2 lines: pydantic import + Field pattern)
- `apex_finance/test/screens/payment_method_validation_test.dart` (new, 7 tests)
- `docs/PAYMENT_METHOD_VALIDATION_2026-05-11.md` (this file)

## Files explicitly NOT touched

- `apex_finance/lib/screens/operations/customer_payment_modal.dart` — the modal is the spec; the backend was the laggard.
- `app/pilot/schemas/purchasing.py` — vendor schema is already correct; do not unify the two patterns, they are intentionally different.
