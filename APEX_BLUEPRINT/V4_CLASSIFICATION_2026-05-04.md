# V4 Classification Matrix — 2026-05-04 (operator-approved)

> **Status:** Operator approved with 5 reclassifications + V5 naming-convention
> overrides on 2026-05-05. Matrix below is the source of truth for the
> Stage 4c-prep PR + the follow-up Stage 4c-4g final PR.
>
> **Cross-ref:** `V4_ARCHIVE_AUDIT_2026-05-04.md` (route inventory),
> `09 § 20.1 G-CLEANUP-1`, file 39 § 3.1, file 40 Stage 4.

## Buckets

| Bucket | Definition | Action in 4c-prep | Action in 4c-4g final |
|---|---|---|---|
| 🟢 **HAS_V5** | V5 chip already wired; V4 path is a pure duplicate. | none | bulk-delete V4 route + update internal refs to V5 path |
| 🔵 **REAL_NEW_V5** | V4 screen makes real backend calls; V5 chip needs to be added. | add new V5 chip in `v5_data.dart` + wire in `v5_wired_screens.dart` (V4 screen reused as chip implementation) | bulk-delete V4 route + redirect refs to new V5 chip path |
| 🟡 **SHELL** | V4 screen has zero backend / mock-only / no roadmap. | `git mv` to `_archive/2026-05-04/v4-routes/` + delete V4 route + update refs | already archived |
| ⚪ **DEFERRED** | Concept tracked under G-MOD-* with active roadmap intent OR shared-file edge case. | leave V4 route as redirect to V5 dashboard with comment linking the gap | revisit after gap closes |

## Operator-approved changes (2026-05-05)

### 5 reclassifications: DEFERRED → SHELL

Each was previously parked under a G-MOD-* track with no roadmap timeline. Operator decided to archive rather than wait:

- `/compliance/executive` (was G-MOD-BI-1 deferred) → **SHELL**
- `/operations/universal-journal` (was deferred) → **SHELL** — home banner already removed by G-CLEANUP-3 Stage 2; screen has no live entry point
- `/audit/service` (was deferred) → **SHELL** — marketplace audit-tier wrapper, no ownership
- `/analytics/investment-portfolio-v2` (was G-MOD-PM-1 deferred) → **SHELL**
- `/analytics/project-profitability` (was G-MOD-PM-1 deferred) → **SHELL**

### V5 naming convention (applied to all REAL_NEW_V5 entries below)

| Concept | V5 home pattern |
|---|---|
| Sales / AR / customer payments | `/app/erp/sales/...` |
| Purchase / AP / vendor payments | `/app/erp/purchasing/...` |
| GL / accounting / fixed assets / cashflow / depreciation | `/app/erp/finance/...` |
| Treasury / FX / multi-currency | `/app/erp/treasury/...` |
| ZATCA / Tax / VAT / Zakat / WHT | `/app/compliance/tax/...` and `/app/compliance/zatca/...` |
| IFRS / lease / revenue / Islamic finance | `/app/compliance/ifrs/...` |
| AML / KYC / governance / risk | `/app/compliance/aml-ethics/...` and `/app/compliance/governance-risk/...` |
| Audit / workpapers / engagements | `/app/audit/...` |
| Ratios / valuation / investment / forecasting | `/app/advisory/...` |
| Marketplace / service catalog | `/app/marketplace/...` |

### Specific path overrides (operator-stated)

- `/sales/payment/:id` → `/app/erp/sales/payment/:id` (chip `payment`)
- `/compliance/valuation` → `/app/advisory/valuation/dashboard` (existing main module's dashboard chip)
- `/compliance/investment` → `/app/advisory/valuation/investment` (new chip under existing valuation module)
- `/compliance/dscr` → `/app/advisory/ratios/dscr` (new chip under existing `advisory/ratios` main module)
- `/compliance/working-capital` → `/app/advisory/ratios/working-capital` (same)
- `/compliance/breakeven` → `/app/advisory/ratios/breakeven` (was HAS_V5 in `erp/finance`; reclassified REAL_NEW_V5 with advisory home per convention)
- `/compliance/cashflow` → `/app/erp/finance/cashflow` (was HAS_V5 in `erp/treasury`; reclassified REAL_NEW_V5 with finance home per convention; collapses with cashflow-statement)
- `/compliance/cashflow-statement` → `/app/erp/finance/cashflow` (same path — both V4 routes collapse to one new chip)
- `/compliance/audit-trail` → `/app/audit/trail` (chip `trail` under `audit/engagement` parent — confirmed HAS_V5 in matrix)

> Operator's reference to "advisory/finance-ratios" main module reads as the existing `advisory/ratios` main module (conceptual label "finance-ratios"); chip homes use `advisory/ratios/...` per the verified V5 service tree.

### Updated totals

| Bucket | Count | Δ from initial |
|---|---:|---|
| 🟢 **HAS_V5** | **27** | -2 (`/compliance/breakeven` + `/compliance/cashflow` reclassified to REAL_NEW_V5 per operator's home overrides) |
| 🔵 **REAL_NEW_V5** | **31** | +2 (same two reclassifications) |
| 🟡 **SHELL** | **26** | +5 (the 5 DEFERRED → SHELL reclassifications) |
| ⚪ **DEFERRED** | **2** | -5 (only `/hr/gosi` + `/hr/eosb` remain; their screens are sub-classes of shared `feature_demos_screen.dart`) |
| **Total** | **86** | unchanged |

### Unique V5 chips to add (Step 3 scope)

The 31 REAL_NEW_V5 routes route to **27 unique new V5 chips** (cashflow shared by 2 routes; zatca/invoice shared by base + `:id` variant; advisory/valuation/dashboard and advisory/ratios/dashboard reused as defaults — not new chips).

Per existing V5 main module:

| Module | New chips (count) | Chip IDs |
|---|---:|---|
| `erp/sales` | 5 | `ar-aging`, `invoice-create`, `payment`, `customer-360`, `live-cycle` |
| `erp/purchasing` | 4 | `ap-aging`, `payment`, `vendor-360`, `cycle` |
| `erp/finance` | 3 | `cashflow`, `depreciation`, `amortization` |
| `erp/treasury` | 1 | `fx-converter` |
| `erp/pos` | 1 | `sessions` |
| `compliance/zatca` | 1 | `invoice` |
| `compliance/tax` | 1 | `timeline` (distinct from existing `calendar`) |
| `compliance/ifrs` | 4 | `tools`, `deferred-tax`, `extras`, `islamic` |
| `advisory/ratios` | 3 | `dscr`, `working-capital`, `breakeven` |
| `advisory/valuation` | 1 | `investment` |
| `audit/engagement` | 1 | `ai-workflow` |
| `marketplace/browse` | 2 | `catalog`, `new-request` |
| **Total** | **27** | |

---

## Per-route matrix (final, post-operator-edits)

### Sales (8 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/sales/customers` | 1 | 762 | 🟢 HAS_V5 | `/app/erp/finance/sales-customers` |
| `/sales/invoices` | 1 | 196 | 🟢 HAS_V5 | `/app/erp/sales/invoices` |
| `/sales/invoices/new` | 3 | 416 | 🔵 REAL_NEW_V5 | `/app/erp/sales/invoice-create` |
| `/sales/aging` | 1 | 224 | 🔵 REAL_NEW_V5 | `/app/erp/sales/ar-aging` |
| `/sales/recurring` | 0 | 203 | 🟢 HAS_V5 | `/app/erp/finance/recurring-entries` |
| `/sales/quotes` | 0 | 163 | 🟡 SHELL | redirect → `/app/erp/sales/dashboard` |
| `/sales/memos` | 0 | 105 | 🟡 SHELL | redirect → `/app/erp/sales/credit-notes` |
| `/sales/payment/:id` | 1 | 182 | 🔵 REAL_NEW_V5 | `/app/erp/sales/payment/:id` |

### Purchase + Accounting (7 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/purchase/vendors` | 1 | 758 | 🟢 HAS_V5 | `/app/erp/purchasing/suppliers` |
| `/purchase/bills` | 1 | 179 | 🟢 HAS_V5 | `/app/erp/finance/purchase-bills` |
| `/purchase/aging` | 1 | 209 | 🔵 REAL_NEW_V5 | `/app/erp/purchasing/ap-aging` |
| `/purchase/payment/:id` | 1 | 183 | 🔵 REAL_NEW_V5 | `/app/erp/purchasing/payment/:id` |
| `/accounting/coa-v2` | 2 | 164 | 🟢 HAS_V5 | `/app/erp/finance/coa-editor` |
| `/accounting/coa/edit` | 0 | 233 | 🟢 HAS_V5 | `/app/erp/finance/coa-editor` |
| `/accounting/bank-rec-v2` | 1 | 197 | 🟢 HAS_V5 | `/app/erp/treasury/recon` |

### Compliance — ZATCA / Tax / VAT / Zakat (8 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/compliance/zatca-invoice` | 2 | 642 | 🔵 REAL_NEW_V5 | `/app/compliance/zatca/invoice` |
| `/compliance/zatca-invoice/:id` | 0 | 315 | 🔵 REAL_NEW_V5 | `/app/compliance/zatca/invoice/:id` |
| `/compliance/zatca-status` | 0 | 242 | 🟢 HAS_V5 | `/app/erp/finance/zatca-status` |
| `/compliance/vat-return` | 1 | 392 | 🟢 HAS_V5 | `/app/compliance/tax/vat-return` |
| `/compliance/zakat` | 1 | 433 | 🟢 HAS_V5 | `/app/compliance/tax/zakat` |
| `/compliance/wht-v2` | 0 | 226 | 🟢 HAS_V5 | `/app/compliance/tax/wht` |
| `/compliance/tax-calendar` | 0 | 198 | 🟢 HAS_V5 | `/app/compliance/tax/calendar` |
| `/compliance/tax-timeline` | 1 | 306 | 🔵 REAL_NEW_V5 | `/app/compliance/tax/timeline` |

### Compliance — IFRS / Statements / Ratios (12 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/compliance/financial-statements` | 8 | 816 | 🟢 HAS_V5 | `/app/erp/finance/statements` |
| `/compliance/cashflow` | (real) | — | 🔵 REAL_NEW_V5 | `/app/erp/finance/cashflow` (operator override; was HAS_V5 in treasury) |
| `/compliance/cashflow-statement` | 1 | 389 | 🔵 REAL_NEW_V5 | `/app/erp/finance/cashflow` (same chip — both routes collapse) |
| `/compliance/ratios` | 1 | 442 | 🔵 REAL_NEW_V5 | `/app/advisory/ratios/dashboard` |
| `/compliance/depreciation` | 1 | 429 | 🔵 REAL_NEW_V5 | `/app/erp/finance/depreciation` |
| `/compliance/lease-v2` | 0 | 223 | 🟡 SHELL | redirect → `/app/compliance/ifrs/dashboard` |
| `/compliance/ifrs-tools` | 5 | 784 | 🔵 REAL_NEW_V5 | `/app/compliance/ifrs/tools` |
| `/compliance/deferred-tax` | 1 | 386 | 🔵 REAL_NEW_V5 | `/app/compliance/ifrs/deferred-tax` |
| `/compliance/transfer-pricing` | 1 | 307 | 🟢 HAS_V5 | `/app/compliance/tax/tp` |
| `/compliance/extras-tools` | 7 | 869 | 🔵 REAL_NEW_V5 | `/app/compliance/ifrs/extras` |
| `/compliance/amortization` | 1 | 341 | 🔵 REAL_NEW_V5 | `/app/erp/finance/amortization` |
| `/compliance/breakeven` | 1 | 321 | 🔵 REAL_NEW_V5 | `/app/advisory/ratios/breakeven` (operator override; was HAS_V5 in finance) |

### Compliance — Misc (16 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/compliance/kyc-aml` | 0 | 189 | 🟡 SHELL | redirect → `/app/compliance/aml-ethics/dashboard` |
| `/compliance/risk-register` | 0 | 184 | 🟡 SHELL | redirect → `/app/compliance/governance-risk/dashboard` |
| `/compliance/audit-trail` | 2 | 263 | 🟢 HAS_V5 | `/app/audit/trail` |
| `/compliance/activity-log-v2` | 0 | 132 | 🟡 SHELL | redirect → `/app/erp/finance/activity-log` |
| `/compliance/working-capital` | 1 | 272 | 🔵 REAL_NEW_V5 | `/app/advisory/ratios/working-capital` (operator override) |
| `/compliance/executive` | 1 | 323 | 🟡 SHELL (reclassified 2026-05-05) | redirect → `/app/erp/finance/dashboard` |
| `/compliance/ocr` | 1 | 291 | 🟢 HAS_V5 | `/app/erp/finance/receipt-capture` |
| `/compliance/dscr` | 1 | 244 | 🔵 REAL_NEW_V5 | `/app/advisory/ratios/dscr` (operator override) |
| `/compliance/valuation` | 1 | 317 | 🔵 REAL_NEW_V5 | `/app/advisory/valuation/dashboard` (operator override) |
| `/compliance/fx-converter` | 4 | 756 | 🔵 REAL_NEW_V5 | `/app/erp/treasury/fx-converter` |
| `/compliance/payroll` | 1 | 374 | 🟢 HAS_V5 | `/app/erp/hr/payroll` |
| `/compliance/investment` | 1 | 388 | 🔵 REAL_NEW_V5 | `/app/advisory/valuation/investment` (operator override) |
| `/compliance/consolidation-v2` | 0 | 237 | 🟢 HAS_V5 | `/app/erp/consolidation/dashboard` |
| `/compliance/audit-workflow-ai` | 4 | 444 | 🔵 REAL_NEW_V5 | `/app/audit/engagement/ai-workflow` |
| `/compliance/islamic-finance` | 2 | 342 | 🔵 REAL_NEW_V5 | `/app/compliance/ifrs/islamic` |

### Audit (4 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/audit/engagements` | 3 | 377 | 🟢 HAS_V5 | `/app/audit/engagement/dashboard` |
| `/audit/anomaly/:id` | 0 | 181 | 🟡 SHELL | redirect → `/app/erp/finance/anomalies` |
| `/audit/service` | (small) | — | 🟡 SHELL (reclassified 2026-05-05) | redirect → `/app/marketplace/dashboard` |
| `/audit-workflow` | 0 | 348 | 🟡 SHELL | redirect → `/app/audit/engagement/dashboard` |

### Analytics (8 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/analytics/cash-flow-forecast` | 1 | 456 | 🟢 HAS_V5 | `/app/erp/finance/cash-flow-forecast` |
| `/analytics/budget-variance-v2` | 0 | 259 | 🟡 SHELL | redirect → `/app/erp/finance/budget-actual` |
| `/analytics/budget-builder` | 0 | 238 | 🟡 SHELL | redirect → `/app/erp/finance/budget-planning` |
| `/analytics/cost-variance-v2` | 0 | 233 | 🟡 SHELL | redirect → `/app/erp/finance/dashboard` |
| `/analytics/multi-currency-v2` | 0 | 216 | 🟡 SHELL | redirect → `/app/erp/treasury/dashboard` |
| `/analytics/health-score-v2` | 0 | 247 | 🟡 SHELL | redirect → `/app/erp/finance/health-score` |
| `/analytics/investment-portfolio-v2` | 0 | 243 | 🟡 SHELL (reclassified 2026-05-05) | redirect → `/app/advisory/dashboard` |
| `/analytics/project-profitability` | 0 | 397 | 🟡 SHELL (reclassified 2026-05-05) | redirect → `/app/erp/projects/dashboard` |

### HR (6 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/hr/employees` | 1 | 218 | 🟢 HAS_V5 | `/app/erp/hr/employees` |
| `/hr/payroll-run` | 0 | 278 | 🟢 HAS_V5 | `/app/erp/hr/payroll` |
| `/hr/expense-reports` | 0 | 140 | 🟢 HAS_V5 | `/app/erp/expenses/expenses` |
| `/hr/timesheet` | 0 | 211 | 🟡 SHELL | redirect → `/app/erp/hr/dashboard` |
| `/hr/gosi` | (shared file) | — | ⚪ DEFERRED | leave V4 redirect; needs `feature_demos_screen.dart` split in follow-up |
| `/hr/eosb` | (shared file) | — | ⚪ DEFERRED | leave V4 redirect; same reason |

### Operations (12 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/operations/inventory-v2` | 0 | 200 | 🟡 SHELL | redirect → `/app/erp/inventory/inventory` |
| `/operations/fixed-assets-v2` | 0 | 207 | 🟡 SHELL | redirect → `/app/erp/finance/fixed-assets` |
| `/operations/petty-cash` | 0 | 130 | 🟡 SHELL | redirect → `/app/erp/finance/dashboard` |
| `/operations/stock-card` | 0 | 143 | 🟡 SHELL | redirect → `/app/erp/inventory/stock-movements` |
| `/operations/customer-360/:id` | 3 | 269 | 🔵 REAL_NEW_V5 | `/app/erp/sales/customer-360/:id` |
| `/operations/vendor-360/:id` | 2 | 252 | 🔵 REAL_NEW_V5 | `/app/erp/purchasing/vendor-360/:id` |
| `/operations/universal-journal` | 1 | 442 | 🟡 SHELL (reclassified 2026-05-05) | redirect → `/app/erp/finance/je-builder` |
| `/operations/period-close` | 4 | 380 | 🟢 HAS_V5 | `/app/erp/finance/period-close` |
| `/operations/pos-sessions` | 4 | 262 | 🔵 REAL_NEW_V5 | `/app/erp/pos/sessions` |
| `/operations/purchase-cycle` | 5 | 307 | 🔵 REAL_NEW_V5 | `/app/erp/purchasing/cycle` |
| `/operations/consolidation-ui` | 1 | 222 | 🟡 SHELL | redirect → `/app/erp/consolidation/dashboard` |
| `/operations/live-sales-cycle` | 5 | 550 | 🔵 REAL_NEW_V5 | `/app/erp/sales/live-cycle` |

### Marketplace + Provider + Service (5 routes)

| V4 path | api | loc | Bucket | V5 target |
|---|---|---|---|---|
| `/service-catalog` | (real) | — | 🔵 REAL_NEW_V5 | `/app/marketplace/browse/catalog` |
| `/service-request/detail` | 0 | 46 | 🟡 SHELL | redirect → `/app/marketplace/dashboard` |
| `/marketplace/new-request` | 2 | 68 | 🔵 REAL_NEW_V5 | `/app/marketplace/browse/new-request` |
| `/provider-kanban` | 0 | 134 | 🟡 SHELL | redirect → `/app/marketplace/provider-ops/dashboard` |
| `/provider/profile` | 0 | 48 | 🟡 SHELL | redirect → `/app/marketplace/provider/dashboard` |

---

## Effort estimate (post-edits)

| Bucket | Per-item | Total |
|---|---|---|
| HAS_V5 | 0 (deferred to PR 2) | 0 |
| REAL_NEW_V5 | ~4 min × 31 routes (27 unique chips × 2 lines each) | ~2 h |
| SHELL | ~2 min × 26 (`git mv` + delete route + update refs) | ~1 h |
| DEFERRED | ~2 min × 2 (redirect + comment) | ~5 min |
| Tests + analyze + build + bundle sanity + closure docs | | ~45 min |
| **Total active work** | | **~4 h** |

## Execution order (this PR)

1. **DEFERRED first** (2 redirects).
2. **SHELL second** (26 archives).
3. **REAL_NEW_V5 last** (27 new chip definitions + 27 wired_screens entries).
4. Tests, build, bundle sanity, closure, commit, push.
