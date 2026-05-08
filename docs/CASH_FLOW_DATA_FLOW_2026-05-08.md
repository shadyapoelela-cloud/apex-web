# Cash Flow Statement — Data Flow + Reconciliation Invariant

**Status:** in force as of 2026-05-08 (G-FIN-CF-1).
**Endpoint:** `GET /pilot/entities/{entity_id}/reports/cash-flow`
**Service:** `app/pilot/services/gl_engine.py::compute_cash_flow`
**Screen:** `apex_finance/lib/screens/finance/cash_flow_screen.dart`
**Method:** Indirect (Direct method returns 422 — قريباً).

---

## TL;DR

> **Every value the CF screen displays came from `pilot_gl_postings`.**
> Net income from the IS path; per-account balance changes from BS
> snapshots at `period_start - 1` and `period_end`. AND the
> reconciliation invariant
>
>     opening_cash + (CFO + CFI + CFF) == closing_cash
>
> is verified server-side. When it breaks, `is_reconciled=False` is
> returned (never silenced). The frontend renders a red banner and
> the backend logs `CF_RECONCILIATION_FAILURE`.

This is the third and final statement in UAT Issue #5. With this PR
**Issue #5 (Financial Statements) is FULLY CLOSED**: Trial Balance ✅
+ Income Statement ✅ + Balance Sheet ✅ + **Cash Flow ✅**.

---

## Layer 1 — What changed from the prior implementation

The prior `compute_cash_flow` had three distinct anti-mock concerns:

1. **Hardcoded zeros** for CFI and CFF with comment `"v2: سنضيف
   تصنيف"`. Production was returning genuinely-zero investing/financing
   sections regardless of the underlying data.
2. **`try/except: Decimal("0")` fallback** that silently swallowed
   every exception. A failing TB query would surface as `0` AR/AP
   change — looks like genuine 0 but was a fallback hiding errors.
3. **Fragile cash detection** via `code.startswith(("111", "112"))` —
   tied to SOCPA prefixes; broke any custom CoA.

**G-FIN-CF-1 removed all three.** The new implementation:

1. Computes per-account changes between two BS snapshots and classifies
   by `(category, subcategory)` via the explicit `_CF_SECTION_MAP` —
   so CFI/CFF reflect real fixed-asset/loan/equity activity.
2. **No exception fallback.** A TB query failure propagates as a 5xx —
   the operator sees something is wrong with the data path.
3. Cash detection by `subcategory IN ('cash', 'bank')` — works for
   any CoA that marks cash accounts correctly.

---

## Layer 2 — Subcategory map

```python
_CF_SECTION_MAP = {
    # Operating — working capital
    "receivables":    "operating_wc",
    "inventory":      "operating_wc",
    "vat":            "operating_wc",
    "prepaid":        "operating_wc",
    "payables":       "operating_wc",
    "payroll":        "operating_wc",
    "zakat":          "operating_wc",
    "eosb":           "operating_wc",
    "accrued":        "operating_wc",
    # Operating — non-cash
    "accumulated_dep": "operating_noncash_skip",  # paired with depreciation expense
    # Investing
    "fixed_assets":   "investing",
    "intangibles":    "investing",
    "investments":    "investing",
    # Financing
    "loans":          "financing",
    "long_term_debt": "financing",
    "capital":        "financing",
    "retained":       "financing",
    "dividends":      "financing",
    # Cash itself — excluded from sections
    "cash":           "cash",
    "bank":           "cash",
    # Closing-balance container — already absorbed via IS
    "current_earnings": "current_earnings_skip",
}
```

Custom subcategories not in the map surface in the response's
`unmapped_subcategories` list with a Arabic warning. The frontend
shows them in an orange warning bar so admins know to map them.

### Sign convention

```
asset increase           →  cf_impact = -change   (cash tied up)
asset decrease           →  cf_impact = +change   (cash freed)
liability/equity increase →  cf_impact = +change   (cash inflow)
liability/equity decrease →  cf_impact = -change   (cash outflow)
```

This convention applies uniformly to all rows; the standard
"AR up = -CF, AP up = +CF, fixed asset up = -CF, loan up = +CF,
dividend declared = -CF" results all fall out of it.

---

## Layer 3 — Algorithm (Indirect Method)

```
1. Net income = compute_income_statement([period_start, period_end]).net_income
2. Depreciation = expense_by_subcat['depreciation']  (from same IS aggregate)
3. opening_snap = _bs_compute_snapshot(period_start - 1, include_zero=True)
4. closing_snap = _bs_compute_snapshot(period_end,        include_zero=True)
5. For each account in opening ∪ closing:
     change = closing.balance - opening.balance
     section = classify_for_cf(subcategory)
     if section == 'cash':
        opening_cash += opening.balance
        closing_cash += closing.balance
        continue
     if section in ('current_earnings_skip', 'operating_noncash_skip'):
        continue                      # already counted elsewhere
     if section == 'unmapped':
        unmapped_items.append(...)    # surfaces in warning
        continue
     cf_impact = -change if asset else +change
     append to operating_wc / investing / financing items
6. CFO = net_income + depreciation + sum(operating_wc cf_impact)
   CFI = sum(investing cf_impact)
   CFF = sum(financing cf_impact)
   net_change = CFO + CFI + CFF
7. is_reconciled = (net_change == closing_cash - opening_cash)  [tolerance 0.01]
8. If not is_reconciled: log CF_RECONCILIATION_FAILURE, surface warning
```

---

## Layer 4 — Why AR increase = -CF

The indirect method starts from accrual-basis net income and adjusts
to cash-basis. When AR goes up by 1,000:

- The matching credit was to *revenue* — already in net_income.
- But the customer hasn't paid yet, so cash didn't actually arrive.
- We back out the non-cash portion: `cf_impact = -1,000`.

When AR comes down (customer pays):

- No new revenue was recognised.
- But cash arrived for prior-period sales.
- We add it back: `cf_impact = +1,000`.

Same logic for AP (in reverse — increase = cash conserved by
deferring payment), inventory (increase = cash spent on stock not
yet sold), prepaid (increase = cash paid for future expense).

---

## Layer 5 — Endpoint contract

```
GET /pilot/entities/{entity_id}/reports/cash-flow
    ?start_date=YYYY-MM-DD
    &end_date=YYYY-MM-DD
    &method=indirect       (default; 'direct' returns 422)
    &compare_period=none|previous_year|previous_period
    &include_zero=false
```

Response headers:

```
X-Data-Source: real-time-from-postings
```

Response body — full schema in `app/pilot/schemas/gl.py::CashFlowResponse`:

```json
{
  "entity_id": "...",
  "period_start": "2026-01-01",
  "period_end": "2026-04-30",
  "method": "indirect",
  "currency": "SAR",
  "current_period": {
    "operating_activities": {
      "net_income": 120000.00,
      "noncash_adjustments": [
        {"code": "_DEPR", "name_ar": "إهلاك (مشتق من قائمة الدخل)",
         "subcategory": "depreciation", "amount": 5000.00,
         "is_synthetic": true}
      ],
      "working_capital_changes": [
        {"account_id": "...", "code": "1130", "name_ar": "ذمم مدينة",
         "subcategory": "receivables", "category": "asset",
         "opening_balance": 0, "closing_balance": 15000,
         "change": 15000, "cf_impact": -15000,
         "note": "زيادة في receivables → نقدية مستخدمة"}
      ],
      "subtotal_cfo": 110000.00
    },
    "investing_activities": {
      "items": [...],
      "subtotal_cfi": -50000.00
    },
    "financing_activities": {
      "items": [...],
      "subtotal_cff": 20000.00
    },
    "totals": {
      "total_cfo": 110000.00,
      "total_cfi": -50000.00,
      "total_cff": 20000.00,
      "net_change_in_cash": 80000.00,
      "opening_cash": 50000.00,
      "closing_cash": 130000.00,
      "reconciliation_check": 130000.00,
      "is_reconciled": true,
      "reconciliation_difference": 0.00
    },
    "unmapped_items": []
  },
  "comparison_period": null,
  "variances": null,
  "unmapped_subcategories": [],
  "warnings": [],
  "posted_je_count": 47
}
```

`comparison_period` populated when `compare_period != 'none'`;
`unmapped_subcategories` lists distinct custom subcategories that
landed in any `unmapped_items`.

---

## Layer 6 — Frontend rendering

`apex_finance/lib/screens/finance/cash_flow_screen.dart` reads the
response and renders, **in this order** (pinned by the
`reconciliation banner renders before summary + table` test):

1. **Reconciliation banner** (first, top-of-body):
   - Green ✅ "التدفقات النقدية متطابقة" when `is_reconciled=true`.
   - Red ⚠️ "غير متطابق — فرق X SAR" otherwise.
2. **Unmapped warning bar** (when `unmapped_subcategories` is
   non-empty): orange strip listing the subcategories so admins know
   to map them.
3. **4 summary cards**: CFO / CFI / CFF / Net Change in Cash. CFO/
   CFI/CFF carry variance % from `comparison_period` when present.
4. **Statement table** with three sections:
   - Operating Activities: Net Income → Non-cash Adjustments →
     Working Capital Changes → Subtotal CFO.
   - Investing Activities: items → Subtotal CFI.
   - Financing Activities: items → Subtotal CFF.
   - Net Change in Cash (gold total bar).
   - Opening Cash row.
   - Closing Cash (cyan total bar).
5. **Footer**: "المصدر: pilot_journal_lines — N قيد مرحّل" + green-dot
   "بيانات حقيقية + reconciliation محقق".
6. **Empty state**: "لا توجد قيود في هذه الفترة" + CTA → JE Builder.
7. **`kDebugMode` panel**: entity_id, period, method, account counts,
   posted_je_count, is_reconciled+diff, opening/closing cash,
   unmapped_subcategories, warnings.

`_data` starts as `null`. Zero `List<X>`s initialised with values.
No fallback `'0.00'` strings.

---

## Layer 7 — Tests pinning the contracts

`tests/test_cash_flow_real_data.py` — **21 cases**:

### `TestRealDataFlow` (10)
- happy-path full-cycle scenario (capital + sale + AR + loan + fixed asset)
- empty period → all zeros, is_reconciled=true
- only operating activities
- AR increase reduces CFO
- AR decrease increases CFO
- AP increase increases CFO
- inventory increase reduces CFO
- depreciation added back to CFO (matches actual cash inflow)
- fixed asset purchase reduces CFI
- loan received increases CFF

### `TestReconciliation` (3)
- Complex 10-JE scenario reconciles exactly (capital, bank deposit,
  asset purchase, loan, sale on credit, AR collection, inventory on
  credit, cash expense, depreciation, AP payment).
- opening_cash + net_change == closing_cash invariant verified across
  multi-period scenario.
- Unmapped subcategory surfaces in warnings — reconciliation correctly
  reports broken when an unmapped row affected cash.

### `TestTenantAndValidation` (3)
- Cross-tenant 404 + body.
- `period_start > end_date` → 400.
- `method='fancy'` → 400; `method='direct'` → 422 with "قريباً".

### `TestAntiMock` (4)
- **Empty entity** → all numeric fields genuine zero.
- **12345.67 JE** round-trips byte-for-byte via CFO.
- **Unmapped subcategory detection** — custom asset with subcategory
  `'weird_subcat'` surfaces in `unmapped_subcategories`.
- **No reconciliation bypass** — deliberately broken scenario yields
  `is_reconciled=False`; we never silently force it true.

### Reconciliation logging
- Cross-tenant probe emits `CF_RECONCILIATION_FAILURE` log line on
  the deliberate-break scenario.

Frontend tests (`apex_finance/test/screens/finance/cash_flow_test.dart`,
**7 tests**):
- chip / wired-keys / validator reachability
- source-grep anti-mock (incl. CF-specific `forceReconciled` /
  `overrideReconciled` / `silentReconciliation`)
- ApiService kwargs contract
- **reconciliation-banner-renders-before-table** structural assertion
- unmapped-warning conditional render assertion

---

## Manual UAT path

1. Login as registered user (token must carry `tenant_id`).
2. Open `/app/erp/finance/je-builder` and post these JEs:
   - **Capital injection**: cash 100,000 / capital 100,000.
   - **Fixed asset purchase**: land 30,000 / cash 30,000.
   - **Loan received**: cash 20,000 / loan 20,000.
   - **Cash sale**: cash 50,000 / sales 50,000.
   - **Cash expense**: rent_exp 10,000 / cash 10,000.
3. Open `/app/erp/finance/cash-flow`.
4. Expected:
   - Top banner: green ✅ "التدفقات النقدية متطابقة".
   - **CFO** = Net Income (40,000 = 50k sales - 10k rent) + 0 depr + 0 WC = `40,000.00`.
   - **CFI** = -30,000 (land purchase).
   - **CFF** = +120,000 (capital + loan).
   - **Net Change** = +130,000.
   - **Opening Cash** = 0.
   - **Closing Cash** = 130,000.
   - Footer: "المصدر: pilot_journal_lines — 5 قيد مرحّل" + "بيانات
     حقيقية + reconciliation محقق".

### Imbalance UAT
To exercise the red banner deliberately, post a JE through a custom
account with `subcategory='unmapped_xyz'`:
- Cash 1,000 / unmapped_account 1,000.
- The cash side captures, but the credit side doesn't fall into any
  CF section, so net_change=0 while closing_cash=1,000.
- Banner turns red with diff=1,000.
- Orange warning bar lists `unmapped_xyz` for the admin to map.

---

## What's deliberately out of scope

- **Direct method** — walks operating cash receipts/payments by
  tagging cash/bank journal lines. The `JournalLine` schema doesn't
  carry the per-line tag we need; the endpoint cleanly returns 422
  with "قريباً" until that's added. Separate ticket.
- **Asset disposal handling** — gain/loss on sale of fixed assets
  needs special treatment (the gain is non-cash, the proceeds are
  the investing inflow). Current implementation treats the whole
  fixed-asset change as the investing CF impact, which is correct
  for purchases only. Separate ticket.
- **Foreign exchange (FX) effect on cash** — when an entity holds
  cash in multiple currencies, FX revaluation creates a non-cash CF
  effect. Current implementation assumes single functional currency.
- **Reclassifications** — between current and long-term for the
  same account. Currently each subcategory is fixed in the map;
  reclassification needs accounting-period awareness.
- **Excel / PDF export** — placeholder SnackBars today.

## References

- `app/pilot/services/gl_engine.py::compute_cash_flow`
- `app/pilot/services/gl_engine.py::_cf_compute_snapshot`,
  `_cf_period_account_changes`, `_CF_SECTION_MAP`,
  `classify_for_cf`
- `app/pilot/routes/gl_routes.py::cash_flow`
- `app/pilot/schemas/gl.py::CashFlowResponse` + nested classes
- `apex_finance/lib/screens/finance/cash_flow_screen.dart`
- `tests/test_cash_flow_real_data.py`
- `apex_finance/test/screens/finance/cash_flow_test.dart`
- Sibling: `docs/BALANCE_SHEET_DATA_FLOW_2026-05-08.md`
- Sibling: `docs/INCOME_STATEMENT_DATA_FLOW_2026-05-08.md`
- Sibling: `docs/TB_DATA_FLOW_AUDIT_2026-05-08.md`

---

# 🎉 UAT Issue #5 — FULLY CLOSED

| # | Statement | Status | PR |
|---|---|---|---|
| 1 | Trial Balance | ✅ | #173 + #174 |
| 2 | Income Statement | ✅ | #177 |
| 3 | Balance Sheet | ✅ | #178 |
| 4 | **Cash Flow** | ✅ | **this PR** |

**All four backed by 100% real `pilot_gl_postings` data with
test-pinned anti-mock and reconciliation invariants.**
