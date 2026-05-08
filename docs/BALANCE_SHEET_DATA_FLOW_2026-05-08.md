# Balance Sheet — Data Flow + Balance-Equation Invariant

**Status:** in force as of 2026-05-08 (G-FIN-BS-1).
**Endpoint:** `GET /pilot/entities/{entity_id}/reports/balance-sheet`
**Service:** `app/pilot/services/gl_engine.py::compute_balance_sheet`
**Screen:** `apex_finance/lib/screens/finance/balance_sheet_screen.dart`

---

## TL;DR — every value real, equation enforced

> **Every value the BS screen displays came from `pilot_gl_postings`.**
> No mocks, no fallbacks, no caching, no demo seeds, no placeholder
> amounts. AND the accounting equation
> **Assets = Liabilities + Equity** is verified after summation; an
> imbalance is surfaced (never silenced).

This document walks the full path so an auditor can verify the
guarantee + the equation invariant end-to-end.

---

## Layer 1 — Data source

`pilot_gl_postings` is the immutable GL ledger. Same single writer as
the IS / TB pipelines: `app/pilot/services/gl_engine.py::post_journal_entry`.
Drafts have no posting rows → inherently excluded by the SQL.

The demo-data seeder explicitly writes `"journal_entries": 0` (see
`demo_data_seeder.py:265`). So a freshly-onboarded tenant has master
data only — no postings — until its operators create + post real JEs.

---

## Layer 2 — Service query (snapshot)

`compute_balance_sheet` builds a snapshot at a specific date by
calling `compute_trial_balance` (the existing, real-data TB query in
`gl_engine.py:720`) and aggregating its rows into asset / liability /
equity buckets.

```python
tb = compute_trial_balance(
    db,
    entity_id=entity_id,
    as_of_date=as_of_date,
    include_zero=include_zero,
)
# `tb` is a list of {account_id, code, name_ar, category,
# subcategory, normal_balance, balance, …} rows where each `balance`
# is the natural-balance amount: sum of (debit - credit) for assets/
# expenses, (credit - debit) for liabilities/equity/revenue.
```

Then we partition:

```python
for r in tb:
    if r['category'] == 'asset':         assets.append(...)
    elif r['category'] == 'liability':   liabilities.append(...)
    elif r['category'] == 'equity':
        # Skip the closing-balance current_earnings account so we
        # don't double-count alongside the IS-derived running figure.
        if r['subcategory'] != 'current_earnings':
            equity.append(...)
```

The asset rows are bucketed into "current" / "fixed" / "other" via
the subcategory list:

```python
_CURRENT_ASSET_SUBCATS = {"cash", "bank", "receivables", "inventory", "vat", "prepaid"}
_FIXED_ASSET_SUBCATS   = {"fixed_assets", "accumulated_dep"}
```

Liabilities into "current" / "long-term" / "other":

```python
_CURRENT_LIAB_SUBCATS  = {"payables", "vat", "payroll", "zakat"}
_LONG_TERM_LIAB_SUBCATS = {"loans", "eosb"}
```

These lists match the default SOCPA CoA seeded by `seed_default_coa`.
Custom subcategories outside the lists fall into "other" (still
visible as rows; just not rolled into a named subtotal).

---

## Layer 3 — Synthetic Current-Year Earnings

The default CoA seeds an equity account with
`subcategory='current_earnings'` (code 3300, "أرباح العام الحالي").
That's the **closing-balance container** — populated at year-end when
the closing entry transfers net income to retained earnings.

Between closings, the running current-year earnings come from
`compute_income_statement([Jan 1 .. as_of_date])`. To avoid
double-counting, we:

1. **Drop** any account with `subcategory='current_earnings'` from
   the equity rows summation.
2. **Add** a synthetic row at the bottom of the equity section with
   the IS-derived figure:
   ```python
   {
       "account_id": "_current_year_earnings",
       "code": "_CYE",
       "name_ar": "أرباح السنة الحالية (مشتقة من قائمة الدخل)",
       "subcategory": "current_earnings",
       "normal_balance": "credit",
       "balance": <IS net_income for [Jan 1 .. as_of_date]>,
       "is_synthetic": True,  # frontend can style it differently
   }
   ```

The frontend renders the synthetic row in italic + a faint gold
background so it's visually distinguishable from real CoA rows.

This invariant is pinned by
`tests/test_balance_sheet_real_data.py::TestBalanceEquation::test_cye_in_equity_equals_is_net_income`:

```python
cye_row["balance"] == is_body["net_income"]
```

---

## Layer 4 — Balance equation

After summation:

```python
total_assets       = sum(asset rows)
total_liabilities  = sum(liability rows)
total_equity       = sum(equity rows + synthetic CYE)
total_liab_and_equity = total_liabilities + total_equity
balance_difference = (total_assets - total_liab_and_equity).quantize(Q2)
is_balanced        = balance_difference == Decimal("0.00")
```

`Q2` is `Decimal("0.01")` — standard accounting tolerance. Anything
≥ 1 cent off counts as unbalanced.

**Pinned by `TestBalanceEquation::test_complex_multi_je_equation_holds`** —
five JEs across asset/liability/equity/revenue/expense, manual sum
verified, equation holds.

### When the equation breaks

If a JE slipped into the GL with `total_debit != total_credit` (data
integrity issue — usually a rounding bug or a bypassed validation),
`is_balanced=False` and `balance_difference != 0`. The endpoint:

- **Returns HTTP 200** (not 422) — the operator needs to see the
  imbalance to fix the underlying JE. Failing the request would just
  hide the problem.
- **Logs a structured warning**:
  ```
  BS_IMBALANCE entity_id=<id> as_of=<date> assets=<a>
    liab+equity=<l+e> diff=<d>
  ```
  SOC dashboards can alert on `BS_IMBALANCE` over a threshold.
- **Emits the `is_balanced=False` flag** in the response. The
  frontend renders a red top banner: ⚠️ "تحذير: الميزانية غير متوازنة — فرق
  X SAR" and a red "غير متوازنة" status card.

The frontend never silences `is_balanced` (pinned by
`balance_sheet_test.dart::unbalanced response triggers a visible warning in the screen`,
which asserts the `_buildBalanceBanner()` call appears *before*
`_buildSummaryCards()` and `_buildStatementTable()` in `build()` —
an imbalance message buried below the table is easy to miss).

---

## Layer 5 — Comparison branch

When `compare_as_of != None`:

```python
prior = _bs_compute_snapshot(db, entity_id=entity_id,
                              as_of_date=compare_as_of, include_zero=...)
```

Same anti-mock guarantees apply — the prior snapshot is also a real
query. Variances:

```python
variances = {
    "total_assets_change_pct":     pct(current.total_assets, prior.total_assets),
    "total_liabilities_change_pct": pct(current.total_liabilities, prior.total_liabilities),
    "total_equity_change_pct":      pct(current.total_equity, prior.total_equity),
}
```

`None` for variances when prior is 0 (genuine division by zero, not
a fallback). `compare_as_of >= as_of` is rejected with HTTP 400.

---

## Layer 6 — Endpoint

```
GET /pilot/entities/{entity_id}/reports/balance-sheet
    ?as_of=YYYY-MM-DD          (default: today)
    &compare_as_of=YYYY-MM-DD  (optional, must be < as_of)
    &include_zero=false
```

Response headers:

```
X-Data-Source: real-time-from-postings
```

Response body — full schema in `app/pilot/schemas/gl.py::BalanceSheetResponse`:

```json
{
  "entity_id": "...",
  "as_of_date": "2026-05-08",
  "currency": "SAR",
  // Legacy scalar fields (backward-compat with compute_comparative_report)
  "assets": 250000.00,
  "liabilities": 30000.00,
  "equity": 100000.00,
  "current_earnings": 120000.00,
  "total_equity": 220000.00,
  "balanced": true,
  "difference": 0.00,
  // New rich shape
  "current_period": {
    "as_of_date": "2026-05-08",
    "assets": [
      {"account_id": "...", "code": "1101", "name_ar": "نقدية",
       "subcategory": "cash", "normal_balance": "debit",
       "balance": 50000.00, "is_synthetic": false}
      // ...
    ],
    "liabilities": [...],
    "equity": [
      ...,
      {"account_id": "_current_year_earnings", "code": "_CYE",
       "name_ar": "أرباح السنة الحالية (مشتقة من قائمة الدخل)",
       "subcategory": "current_earnings", "normal_balance": "credit",
       "balance": 120000.00, "is_synthetic": true}
    ],
    "current_earnings": 120000.00,
    "totals": {
      "total_current_assets": 50000.00,
      "total_fixed_assets": 200000.00,
      "total_other_assets": 0.00,
      "total_assets": 250000.00,
      "total_current_liabilities": 30000.00,
      "total_long_term_liabilities": 0.00,
      "total_other_liabilities": 0.00,
      "total_liabilities": 30000.00,
      "total_equity": 220000.00,
      "total_liab_and_equity": 250000.00,
      "is_balanced": true,
      "balance_difference": 0.00
    }
  },
  "comparison_period": null,    // or same shape as current_period
  "variances": null,            // or {total_assets_change_pct: …, …}
  "posted_je_count": 47
}
```

---

## Layer 7 — Frontend rendering

`apex_finance/lib/screens/finance/balance_sheet_screen.dart` reads
the response and renders:

- **Balance banner** (top of body): green ✅ "الميزانية متوازنة" or
  red ⚠️ "تحذير: الميزانية غير متوازنة — فرق X SAR".
- **4 summary cards**: Assets / Liabilities / Equity / Balance Status.
  The first three carry variance % when `comparison_period` is
  present; the fourth is green when balanced, red with the diff
  amount when not.
- **Statement table** with three sections, each grouped by
  subcategory subtotal:
  - الأصول → الأصول المتداولة + الأصول الثابتة + إجمالي الأصول
  - الالتزامات → المتداولة + طويلة الأجل + إجمالي الالتزامات
  - حقوق الملكية → per-account rows (capital, retained, synthetic CYE in italic) + إجمالي حقوق الملكية
  - إجمالي الالتزامات وحقوق الملكية (gold total bar)
  When `comparison_period` is present, each subtotal/total row also
  shows the prior value in dimmed text.
- **Footer**: "المصدر: pilot_journal_lines — N قيد مرحّل" + green-dot
  "بيانات حقيقية — لا توجد قيم وهمية".
- **Empty state**: "لا توجد قيود مرحّلة حتى هذا التاريخ" + CTA → JE Builder.
- **`kDebugMode` panel**: entity_id, as_of, compare_as_of, account
  counts, posted_je_count, is_balanced + diff, currency, comparison
  date — for field-level verification during dev / staging.

The screen's `_data` starts as `null` (not an empty Map with seeded
keys). `_lastFetchedAt` starts as `null`. Zero `List<X>`s initialised
with values. No fallback `'0.00'` strings — backend always returns
real numbers (genuine 0 for empty periods).

---

## Layer 8 — Tests pinning the guarantees

Five test classes in `tests/test_balance_sheet_real_data.py`,
**15 cases**:

### `TestRealDataFlow` (8)
- happy path balanced capital injection
- empty period → all zeros, is_balanced=true, no seed
- balanced after partial period (capital + revenue → CYE row)
- include_zero toggle exposes/hides zero-activity accounts
- compare_as_of returns comparison + variances
- compare_as_of=None → comparison/variances null
- compare_as_of >= as_of → 400
- only posted JEs counted (drafts excluded)

### `TestTenantIsolation` (3)
- cross-tenant 404 + body
- cross-tenant emits TENANT_GUARD_VIOLATION log
- own-tenant returns own data only

### `TestAntiMock` (2)
- **`test_no_hardcoded_values_in_response`**: empty entity →
  every numeric field is genuine 0 (no defaults).
- **`test_response_reflects_actual_postings_exactly`**: 12345.67 JE
  round-trips byte-for-byte.

### `TestBalanceEquation` (2)
- **`test_complex_multi_je_equation_holds`**: 5 JEs across
  asset/liability/equity/revenue/expense → manual sum verified;
  Assets = Liab + Equity exactly.
- **`test_cye_in_equity_equals_is_net_income`**: synthetic
  `_current_year_earnings` row balance equals
  `compute_income_statement` net_income for the matching window.

Frontend tests (`apex_finance/test/screens/finance/balance_sheet_test.dart`,
**6 cases**):
- chip declaration / wired-keys / validator reachability
- source-grep anti-mock (incl. BS-specific `forceBalanced` /
  `overrideBalanced` tokens)
- ApiService kwargs contract
- balance-banner-renders-before-table contract

---

## Manual UAT path

1. Login as a registered user (token must carry `tenant_id`).
2. Open `/app/erp/finance/je-builder` → create a balanced JE:
   - Line 1: account `1101` (نقدية) — debit `10000.00`
   - Line 2: account `3101` (رأس المال) — credit `10000.00`
3. Submit → approve → **post**.
4. Open `/app/erp/finance/balance-sheet`.
5. Expected:
   - Top banner: green ✅ "الميزانية متوازنة".
   - Assets card: `10,000.00`. Liabilities: `0.00`. Equity: `10,000.00`. Balance status: `متوازنة`.
   - Assets section: row `1101 نقدية 10,000.00`. Subtotal Current Assets: `10,000.00`. Total Assets: `10,000.00`.
   - Liabilities section: empty (or all zero rows hidden).
   - Equity section: row `3101 رأس المال 10,000.00`. Total Equity: `10,000.00`.
   - Total L+E: `10,000.00`.
   - Footer: "المصدر: pilot_journal_lines — 1 قيد مرحّل" + "بيانات حقيقية — لا توجد قيم وهمية".

### Imbalance UAT
To exercise the unbalanced banner, you'd need to bypass the JE balance
validation (which production rejects). The contract is verified by
`TestBalanceEquation` tests — manual reproduction in the UI requires
seeding a deliberately-broken posting row in the DB, which is out of
scope for normal UAT.

---

## What's deliberately out of scope

- **Period-end closing entries** (auto-transfer of CYE to retained
  earnings on Dec 31) — separate ticket.
- **Non-Jan-1 fiscal year start** (Hijri year, April-March, …) — the
  current implementation derives `current_earnings` from
  `[date(as_of.year, 1, 1) .. as_of]`. Custom fiscal-year support
  needs an entity-level `fiscal_year_start` setting.
- **Cash-flow statement** — separate endpoint and ticket
  (`G-FIN-CF-1`).
- **Excel / PDF export** — placeholder SnackBars today.
- **Sub-account drill-down** — clicking an account row to see its
  ledger detail. The `/accounts/{id}/ledger` endpoint exists; UI
  drill-down is a follow-up.

## References

- `app/pilot/services/gl_engine.py::compute_balance_sheet`
- `app/pilot/services/gl_engine.py::_bs_compute_snapshot` (helper)
- `app/pilot/routes/gl_routes.py::balance_sheet`
- `app/pilot/schemas/gl.py::BalanceSheetResponse` + nested classes
- `apex_finance/lib/screens/finance/balance_sheet_screen.dart`
- `tests/test_balance_sheet_real_data.py`
- `apex_finance/test/screens/finance/balance_sheet_test.dart`
- Sibling: `docs/INCOME_STATEMENT_DATA_FLOW_2026-05-08.md`
- Sibling: `docs/TB_DATA_FLOW_AUDIT_2026-05-08.md`
