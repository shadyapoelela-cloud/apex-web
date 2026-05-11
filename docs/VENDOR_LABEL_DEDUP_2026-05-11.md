# Vendor Payment Method Label Dedup (G-VENDOR-PAYMENT-LABEL-DEDUP)

Date: 2026-05-11
Scope: UX polish — frontend only, no backend/data migration.

## Background

PR #198 (G-PURCHASE-FIXES) widened the vendor `payment_method` schema
pattern to include the Saudi-market `card|mada` keys, achieving parity
with the customer side. The legacy `credit_card|other` entries were
kept for back-compat with existing records.

That shipped a regression in the vendor-payment modal dropdown
(`apex_finance/lib/screens/operations/vendor_payment_modal.dart`):
both `card` and `credit_card` rendered with the same Arabic label
"بطاقة ائتمان". The cashier sees what looks like a duplicate row.

## Fix

**Relabel only — no value/schema/data changes.**

| Key            | Old label          | New label                |
|----------------|--------------------|--------------------------|
| `card`         | "بطاقة ائتمان"     | "بطاقة"                  |
| `credit_card`  | "بطاقة ائتمان"     | "بطاقة ائتمان (قديم)"    |

Both rows remain functional. Existing records carrying `credit_card`
continue to round-trip unchanged (UI labels them with the legacy
"(قديم)" marker; backend regex still accepts the value).

Also corrected a stale doc-comment in the same modal that referenced
GL account 1310 (Cheques on Hand) on the vendor side. That was wrong:
1310 is the **customer-side** asset; outgoing vendor cheques settle
through Bank (1120). G-PURCHASE-FIXES (PR #198) already fixed the
backend routing; this PR just brings the modal's narration in line.

## What did NOT change

- Backend `payment_method` regex (`app/pilot/schemas/purchasing.py`)
- Backend GL routing (cash → 1110, everything else → 1120)
- Dropdown VALUE semantics — selecting "بطاقة ائتمان (قديم)" still
  posts `method=credit_card` to the API
- Existing `vendor_payments` rows in the DB — no migration needed

## UAT

1. Open any posted purchase invoice with a remaining balance.
2. Click "+ تسجيل دفع" to open the vendor payment modal.
3. Open the "طريقة الدفع" dropdown. Confirm:
   - "بطاقة" (the new short label) appears as one row
   - "بطاقة ائتمان (قديم)" appears as a distinct row below
   - All 7 methods are present:
     نقداً / تحويل بنكي / شيك / بطاقة / مدى / بطاقة ائتمان (قديم) / أخرى

## Tests

5 source-grep contracts in
`apex_finance/test/screens/vendor_label_dedup_test.dart`:

1. `card` label is the short form "بطاقة"
2. `credit_card` label carries the "(قديم)" legacy marker
3. The two cashier-facing labels are distinct strings (regex-extracted)
4. The stale `|1310` mention is gone from the modal docstring
5. All 7 method keys are still wired (regression guard)

Suite count: 251 → 256 in `apex_finance/test/screens/`.
