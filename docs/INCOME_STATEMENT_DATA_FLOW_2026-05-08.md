# Income Statement (P&L) — Data Flow

**Status:** in force as of 2026-05-08 (G-FIN-IS-1).
**Endpoint:** `GET /pilot/entities/{entity_id}/reports/income-statement`
**Service:** `app/pilot/services/gl_engine.py::compute_income_statement`
**Screen:** `apex_finance/lib/screens/finance/income_statement_screen.dart`

---

## TL;DR — every value is real

> **Every value the IS screen displays came from `pilot_gl_postings`.**
> No mocks, no fallbacks, no cached fallbacks, no demo seeds, no
> placeholder amounts.

This document walks the full path so an auditor can verify the
guarantee end-to-end.

---

## Layer 1 — Data source

`pilot_gl_postings` is the immutable GL ledger. It is written by
**exactly one** code path:

```python
# app/pilot/services/gl_engine.py::post_journal_entry
```

When a JE transitions from `approved` → `posted`, this function
inserts one `GLPosting` row per `JournalLine`. Drafts and submitted
JEs have **zero** `pilot_gl_postings` rows.

There is no other writer. Confirmed by:

```bash
grep -rn "GLPosting(" app/ | grep -v "tests/"
# → only post_journal_entry produces GLPosting() in non-test code
```

The demo-data seeder explicitly skips this:

```python
# app/phase1/services/demo_data_seeder.py
"deferred": {
    "journal_entries": 0,           # ← zero
    "sales_invoices": 0,
    "purchase_invoices": 0,
    "payments": 0,
    "_note": "GL + invoice + payment seeding is deferred to G-DEMO-DATA-SEEDER-V2",
}
```

So a freshly-onboarded tenant with `seed_demo_data=true` has master
data (customers, vendors, products) but **no postings at all** until
its operators create + post real journal entries.

---

## Layer 2 — Service query

`compute_income_statement` is the only function that reads postings
for the IS endpoint. The query — verbatim from the source:

```python
db.query(
    GLAccount.id.label("account_id"),
    GLAccount.code,
    GLAccount.name_ar,
    GLAccount.name_en,
    GLAccount.category,
    GLAccount.subcategory,
    GLAccount.normal_balance,
    func.coalesce(func.sum(GLPosting.debit_amount), 0).label("total_debit"),
    func.coalesce(func.sum(GLPosting.credit_amount), 0).label("total_credit"),
)
.outerjoin(
    GLPosting,
    and_(
        GLPosting.account_id == GLAccount.id,
        GLPosting.entity_id == entity_id,
        GLPosting.posting_date >= start_date,
        GLPosting.posting_date <= end_date,
    ),
)
.filter(
    GLAccount.entity_id == entity_id,
    GLAccount.is_active == True,
    GLAccount.type == AccountType.detail.value,
    GLAccount.category.in_(
        [AccountCategory.revenue.value, AccountCategory.expense.value]
    ),
)
.group_by(
    GLAccount.id, GLAccount.code, GLAccount.name_ar, GLAccount.name_en,
    GLAccount.category, GLAccount.subcategory, GLAccount.normal_balance,
)
.order_by(GLAccount.code)
.all()
```

Notes:

- `outerjoin` on `GLPosting` so accounts with no postings yield
  `total_debit=0, total_credit=0` rather than dropping out — this
  preserves `include_zero=true` semantics without a second query.
- `entity_id` filter is applied on **both** sides of the join:
  `GLPosting.entity_id` (defense in depth) and `GLAccount.entity_id`
  (the natural anchor since CoA is per-entity).
- The route already enforces tenant isolation via
  `assert_entity_in_tenant`, so a cross-tenant entity_id is rejected
  before this query runs.

After the query, totals are computed using natural balance:

```python
if r.category == 'revenue':
    amount = cr - dr        # revenue is naturally credit
else:
    amount = dr - cr        # expense is naturally debit
```

`net_income = revenue_total - expense_total`. No rounding,
no clamping, no defaults.

---

## Layer 3 — Comparison branch

When `compare_period != 'none'`, the same query runs again with a
shifted window:

| compare_period | prior_start | prior_end |
|---|---|---|
| `previous_year` | `start.replace(year=year-1)` | `end.replace(year=year-1)` |
| `previous_period` | `start - (end - start) - 1d` | `start - 1d` |

The same anti-mock guarantees apply — the prior window is also a
real query against `pilot_gl_postings`. Variances are computed as:

```python
revenue_variance_pct = (current - prior) / prior * 100   # if prior != 0
```

`None` for variances when the prior window has 0 in the denominator
(genuine division by zero, not a fallback).

---

## Layer 4 — Endpoint contract

```
GET /pilot/entities/{entity_id}/reports/income-statement
    ?start_date=YYYY-MM-DD
    &end_date=YYYY-MM-DD
    &include_zero=false
    &compare_period=none|previous_year|previous_period
```

Response headers:

```
X-Data-Source: real-time-from-postings
```

Response body:

```json
{
  "entity_id": "...",
  "start_date": "2026-03-01",
  "end_date": "2026-03-31",
  "revenue_total": 12345.67,
  "expense_total": 4500.00,
  "net_income": 7845.67,
  "revenue_by_subcat": {"sales": 12345.67},
  "expense_by_subcat": {"cogs": 4000.0, "rent": 500.0},
  "accounts": [
    {
      "account_id": "...",
      "code": "4101",
      "name_ar": "إيرادات المبيعات",
      "name_en": "Sales Revenue",
      "category": "revenue",
      "subcategory": "sales",
      "normal_balance": "credit",
      "total_debit": 0.0,
      "total_credit": 12345.67,
      "amount": 12345.67
    }
    // ...
  ],
  "posted_je_count": 3,
  "compare_period": "none",
  "comparison": null
}
```

The `comparison` field is `null` when `compare_period='none'`, and
otherwise carries `revenue_total`, `expense_total`, `net_income`,
plus the three variance percentages.

---

## Layer 5 — Frontend rendering

`apex_finance/lib/screens/finance/income_statement_screen.dart` reads
the response and renders:

- 3 summary cards (revenue / expenses / net profit) with optional
  variance percentages from `comparison`.
- A statement table grouped into Revenue / Expenses sections, with
  per-account rows and section subtotals.
- A net-income row at the bottom (gold if positive, red if loss).
- Footer: `"المصدر: pilot_journal_lines — N قيد مرحّل"` reading
  `posted_je_count` directly. If the field is absent (older backend),
  shows an em-dash instead of misleading `0`.
- A "بيانات حقيقية — لا توجد قيم وهمية" badge in the footer to make
  the guarantee user-visible.
- An empty-state with CTA → JE Builder when the period has zero
  posted JEs.
- A `kDebugMode`-only debug panel showing the raw entity_id, period
  range, account counts, posted_je_count, and comparison — for
  field-level verification during dev / staging.

The screen has **no** local state initialised with values:

```dart
Map<String, dynamic>? _data;        // null until first fetch
DateTime? _lastFetchedAt;           // null until first fetch
```

No `_demoRows`, no `_seedRows`, no `_defaultRows`, no
`placeholderAmount`. This is pinned by
`test/screens/finance/income_statement_test.dart::IS source — anti-mock guarantee`.

---

## Layer 6 — Tests pinning the guarantee

Two anti-mock tests in `tests/test_income_statement_real_data.py`:

### `test_no_hardcoded_values_in_response`
Creates an entity with **zero** JEs, hits the endpoint, asserts:

```python
body["revenue_total"] == 0
body["expense_total"] == 0
body["net_income"] == 0
body["accounts"] == []
body["posted_je_count"] == 0
body["revenue_by_subcat"] == {}
body["expense_by_subcat"] == {}
```

If any default seed / cached fallback / mock pre-fill existed, this
would surface non-zero values. It doesn't, so the guarantee holds.

### `test_response_reflects_actual_postings_exactly`
Posts a JE with amount **12345.67** (specific decimal, not a round
number). Asserts the response returns `12345.67` byte-for-byte in
all relevant fields. If any rounding mock / caching layer existed,
the round-trip would drift. It doesn't.

Plus 13 more cases covering happy path, draft exclusion, mixed
posted+draft, comparison branches, period validation, only-revenue,
only-expenses, cross-tenant 404 + log emission. **15/15 pass.**

---

## Manual UAT path

1. Login as a registered user (token must carry `tenant_id`).
2. Open `/app/erp/finance/je-builder` → create a balanced JE:
   - Line 1: account `1101` (نقدية) — debit `5000.00`
   - Line 2: account `4101` (إيرادات المبيعات) — credit `5000.00`
3. Submit → approve → **post**.
4. Open `/app/erp/finance/income-statement`.
5. Expected:
   - Header shows "قائمة الدخل" and "البيانات حقيقية من القيود المرحّلة".
   - Freshness badge shows "آخر تحديث: HH:MM:SS".
   - Revenue card: `5,000.00`.
   - Expenses card: `0.00`.
   - Net Profit card: `5,000.00` (gold).
   - Statement table shows row `4101 إيرادات المبيعات 5,000.00`.
   - Footer reads "المصدر: pilot_journal_lines — 1 قيد مرحّل" +
     "بيانات حقيقية — لا توجد قيم وهمية".
6. Curl smoke (cross-tenant probe must 404):
   ```bash
   TOKEN_A=...   # tenant A
   ENTITY_B=...  # tenant B's entity
   curl -i -H "Authorization: Bearer $TOKEN_A" \
     "$API_BASE/pilot/entities/$ENTITY_B/reports/income-statement?start_date=2026-01-01&end_date=2026-12-31"
   # → HTTP 404 + "Entity not found"
   ```

---

## What's deliberately out of scope

- **Period-split** (opening / period / closing per account) —
  different report shape; tracked separately.
- **Cash-flow statement** — separate endpoint
  (`/reports/cash-flow`), separate ticket (G-FIN-CF-1).
- **Excel / PDF export** — placeholder SnackBars in the UI today.
- **Hierarchical indenting** by `GLAccount.level` — current rendering
  is flat per category.

## References

- `app/pilot/services/gl_engine.py::compute_income_statement`
- `app/pilot/routes/gl_routes.py::income_statement` (line 473)
- `app/pilot/schemas/gl.py::IncomeStatementResponse`
- `apex_finance/lib/screens/finance/income_statement_screen.dart`
- `tests/test_income_statement_real_data.py`
- `apex_finance/test/screens/finance/income_statement_test.dart`
- Pattern doc: `docs/PILOT_TENANT_GUARD_PATTERN.md`
- Sibling audit: `docs/TB_DATA_FLOW_AUDIT_2026-05-08.md`
