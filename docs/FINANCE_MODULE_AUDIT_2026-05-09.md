# Finance Module Audit — 2026-05-09

**Status:** in force as of 2026-05-09 (G-FIN-AUDIT-CLEANUP / Sprint 1).
**Scope:** every chip under `erp/finance/*` in
[v5_wired_screens.dart](../apex_finance/lib/core/v5/v5_wired_screens.dart)
(70 mappings counted), every Flutter screen that backs them, and the
pilot API endpoints they consume.

---

## TL;DR

The Finance module today has **70 chip routes**. Of those:

| Type | Count | Notes |
|------|------:|-------|
| **LIVE** (real backend, real data) | 22 | All five financial-statement chips — TB, IS, BS, CF, GL hub — are LIVE and dedicated since G-FIN-CF-1 / G-FIN-IS-1 / G-FIN-BS-1 (2026-05-08). |
| **V5.2 mock** (no backend yet) | 18 | Auto-rendered with a "🚧 قيد التطوير" banner so users know not to expect persistence. |
| **Legacy duplicate / orphan** | 21 | Backward-compat aliases under `// finance → ...` block. Most resolve to V4 widgets that already migrated to other modules. |
| **Path-keyed** (need :id sub-route) | 9 | `sales-customers`, `purchase-vendors`, `je-builder`, `coa-editor`, etc. — wired correctly today. |

The audit closes UAT Issue #11 (overlapping financial-statement chips
all rendering the same hub) — that issue was already resolved on
2026-05-08 by the four dedicated screens; this audit *documents* and
*prevents regression* via tests + chip-cleanup discipline.

---

## Table 1 — Screen × Chip × Route × Backend × Type

> **LIVE** = backed by `/pilot/*` with real DB writes/reads.
> **V52-MOCK** = `*_v52_screen.dart` widget rendering hardcoded fixtures.
> **LEGACY** = pre-V5 widget kept for backward-compat aliases (see Table 3).

### 1.1 Financial Statements (the core 5)

| Chip Key | Screen | Route | Backend | Type |
|---|---|---|---|---|
| `erp/finance/gl` | `pilot_reports.FinancialReportsScreen` | `/app/erp/finance/gl` | hub aggregating TB+IS+BS | LIVE |
| `erp/finance/trial-balance` | `TrialBalanceScreen` | `/app/erp/finance/trial-balance` | `GET /pilot/entities/{id}/reports/trial-balance` | LIVE |
| `erp/finance/income-statement` | `IncomeStatementScreen` | `/app/erp/finance/income-statement` | `GET /pilot/entities/{id}/reports/income-statement` | LIVE |
| `erp/finance/balance-sheet` | `BalanceSheetScreen` | `/app/erp/finance/balance-sheet` | `GET /pilot/entities/{id}/reports/balance-sheet` | LIVE |
| `erp/finance/cash-flow` | `fin_cf.CashFlowScreen` | `/app/erp/finance/cash-flow` | `GET /pilot/entities/{id}/reports/cash-flow` | LIVE |
| `erp/finance/statements` | `pilot_reports.FinancialReportsScreen` | `/app/erp/finance/statements` | hub alias | LIVE (alias) |

### 1.2 Journal & GL Plumbing

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/je-builder` | `pilot_je.JeBuilderScreen` | `POST /pilot/journal-entries` + `/post` + `/reverse` | LIVE |
| `erp/finance/coa-editor` | `pilot_coa.CoaEditorScreen` | `/pilot/entities/{id}/accounts` + `/coa/seed` | LIVE |
| `erp/finance/onboarding` | `PilotOnboardingWizard` | `/pilot/tenants` + `/entities` + `/branches` | LIVE |
| `erp/finance/period-close` | `ClosingCockpitV52Screen` | (dag fixture) | V52-MOCK |
| `erp/finance/close-checklist` | `CloseChecklistScreen` | (no backend wire yet) | V52-MOCK |

### 1.3 Sales & A/R

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/sales-customers` | `CustomersListScreen` | `/pilot/tenants/{id}/customers` | LIVE |
| `erp/finance/sales-invoices` | `SalesInvoicesScreen` | `/pilot/entities/{id}/sales-invoices` + `/sales-invoices/{id}/issue` | LIVE (auto-posts JE on issue — see `customer_routes.py:_post_sales_invoice_je`) |
| `erp/finance/ar-aging` | `ArAgingScreen` | computed from invoices | LIVE |
| `erp/finance/sales-workflow` | `SalesWorkflowScreen` | (no backend) | LEGACY |

### 1.4 Purchase & A/P

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/purchase-vendors` | `VendorsListScreen` | `/pilot/tenants/{id}/vendors` | LIVE |
| `erp/finance/purchase-bills` | `PurchaseInvoicesScreen` | `/pilot/entities/{id}/purchase-invoices` + `/post` | LIVE (auto-posts JE — see `purchasing_engine.py:post_purchase_invoice_to_gl`) |
| `erp/finance/ap-aging` | `ApAgingScreen` | computed from PIs | LIVE |
| `erp/finance/ap` | `PurchasingApScreen` | (legacy) | LEGACY |

### 1.5 POS & Retail

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/pos` | `RetailPosScreen` | `/pilot/branches/{id}/pos-sessions` + `/pos-transactions` | LIVE (auto-posts 3 JEs — see `gl_engine.py:auto_post_pos_sale`) |
| `erp/finance/receipt-capture` | `ReceiptCaptureScreen` | (no backend) | V52-MOCK |

### 1.6 Compliance Hooks

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/vat-return` | `VatReturnV52Screen` | (no backend) | V52-MOCK |
| `erp/finance/zatca-status` | `ZatcaStatusCenterScreen` | `/zatca/*` | LIVE |
| `erp/finance/wht` | `WhtCalculatorV5Screen` | local calc | LIVE (no API needed) |
| `erp/finance/zakat` | `ZakatCalculatorV5Screen` | local calc | LIVE (no API needed) |
| `erp/finance/tax-calendar` | `TaxTimelineScreen` | hardcoded calendar | LIVE |

### 1.7 Cost & Budget (V5.2 — all mocks)

| Chip Key | Screen | Type |
|---|---|---|
| `erp/finance/budgets` | `BudgetsV52Screen` | V52-MOCK |
| `erp/finance/budget-actual` | `BudgetActualV52Screen` | V52-MOCK |
| `erp/finance/budget-planning` | `BudgetPlanningV52Screen` | V52-MOCK |
| `erp/finance/breakeven` | `BreakEvenV52Screen` | V52-MOCK |
| `erp/finance/scenarios` | `ScenariosV52Screen` | V52-MOCK |
| `erp/finance/cost-centers` | `CostCentersV52Screen` | V52-MOCK |
| `erp/finance/profit-centers` | `ProfitCentersV52Screen` | V52-MOCK |
| `erp/finance/internal-orders` | `InternalOrdersV52Screen` | V52-MOCK |
| `erp/finance/dimensions` | `DimensionsV52Screen` | V52-MOCK |
| `erp/finance/recurring-entries` | `RecurringEntriesV52Screen` | V52-MOCK |

### 1.8 AI & Workflow (V5.2 mocks)

| Chip Key | Screen | Type |
|---|---|---|
| `erp/finance/ai-analyst` | `AiAnalystV52Screen` | V52-MOCK |
| `erp/finance/ai-reconciliation` | `AiReconciliationV52Screen` | V52-MOCK |
| `erp/finance/anomalies` | `AnomaliesV52Screen` | V52-MOCK |
| `erp/finance/workflows` | `WorkflowsV52Screen` | V52-MOCK |
| `erp/finance/integrations` | `IntegrationsHubV52Screen` | V52-MOCK |
| `erp/finance/documents` | `DocumentsV52Screen` | V52-MOCK |

### 1.9 Settings & Activity

| Chip Key | Screen | Backend | Type |
|---|---|---|---|
| `erp/finance/advanced-settings` | `CompanySettingsScreen` | `/pilot/tenants` + `/entities` + `/branches` | LIVE |
| `erp/finance/company-settings` | `CompanySettingsScreen` | (alias of above) | LIVE |
| `erp/finance/entity-setup` | `EntitySetupScreen` | (legacy localStorage; see G-ERP-UNIFICATION) | LEGACY (one-shot migration UI) |
| `erp/finance/activity-log` | `ActivityLogScreen` | `/audit/*` | LIVE |
| `erp/finance/cash-flow-forecast` | `CashFlowForecastScreen` | computed | LIVE |
| `erp/finance/fixed-assets` | `FixedAssetsV52Screen` | (no backend) | V52-MOCK |

---

## Table 2 — Duplicate Groups

> **Group A** is **NOT a duplicate group anymore** — all 5 chips already
> point to dedicated screens. Documented here for the historical record
> and to ensure the routing test pins them.

### Group A (closed 2026-05-08) — Financial Statements

| Chip | Was | Now |
|---|---|---|
| `gl` | hub | `FinancialReportsScreen` (overview hub) |
| `trial-balance` | aliased hub | `TrialBalanceScreen` (dedicated) |
| `income-statement` | aliased hub | `IncomeStatementScreen` (dedicated) |
| `balance-sheet` | aliased hub | `BalanceSheetScreen` (dedicated) |
| `cash-flow` | aliased hub | `CashFlowScreen` (dedicated) |
| `statements` | n/a | `FinancialReportsScreen` (alias of `gl`) |

**Why it's not a "live" duplicate today:** the hub at `gl` and `statements`
is intentional — it's the "Financial Reports" overview screen with all 4
statements as tabs. It's a hub, not a duplicate of one statement.

### Group B (live duplicate, intentional) — Cash Flow

| Chip | Screen |
|---|---|
| `erp/finance/cash-flow` | `fin_cf.CashFlowScreen` (dedicated, LIVE) |
| `erp/finance/cashflow` | `CashFlowScreen` (compliance, identical alias) |

**Decision:** keep both — `cash-flow` is canonical (Sprint 1 baseline);
`cashflow` is the V4-migration alias (Stage 4c-prep). Both render the
same widget. No cleanup needed.

### Group C (resolved by archive) — Legacy module orphans

See Table 3.

---

## Table 3 — Gaps & Legacy Duplicates (to archive)

The 21 chips at lines 729-749 + 815-817 of `v5_wired_screens.dart` are
**backward-compat aliases** that map to widgets that legitimately
belong to *other modules* (consolidation, expenses, executive,
governance). They were left under `erp/finance/*` to preserve old
deep-linked bookmarks.

| Chip | Real owner module | Action |
|---|---|---|
| `credit-notes` | `erp/sales/*` | redirect alias (kept) |
| `subscription-billing` | `erp/sales/*` | redirect alias (kept) |
| `credit` | `erp/sales/credit-scoring` | redirect alias (kept) |
| `consolidation` | `erp/consolidation/consolidation` | redirect alias (kept) |
| `intercompany` | `erp/consolidation/intercompany` | redirect alias (kept) |
| `cap-table` | `erp/consolidation/cap-table` | redirect alias (kept) |
| `board` | `erp/consolidation/board` | redirect alias (kept) |
| `ma-deal-room` | `erp/consolidation/ma-deal-room` | redirect alias (kept) |
| `expenses` | `erp/expenses/*` | redirect alias (kept) |
| `reports` | `erp/reports-bi/audit` | redirect alias (kept) |
| `custom-reports` | `erp/reports-bi/builder` | redirect alias (kept) |
| `exec` | `executive/dashboard` | redirect alias (kept) |
| `okrs` | `executive/okrs` | redirect alias (kept) |
| `knowledge` | `platform/knowledge` | redirect alias (kept) |
| `esg` | `executive/esg` | redirect alias (kept) |
| `bi` | `executive/bi` | redirect alias (kept) |
| `legal-docs` | `compliance/legal-docs` | redirect alias (kept) |
| `copilot` | `copilot/*` | redirect alias (kept) |
| `depreciation` | `compliance/ifrs/depreciation` | redirect alias (kept) |
| `amortization` | `compliance/ifrs/amortization` | redirect alias (kept) |
| `sales-workflow` | `erp/sales/workflow` | redirect alias (kept) |

**Rationale for "redirect alias kept":** breaking these chips would 404
old bookmarks. They're documented as aliases in Table 3 and pinned by
the routing test so the wiring can't silently drift; the underlying
widgets are all already canonically owned by other modules.

### Functional gaps (the real work for Sprints 2-7)

| Gap | What's missing today | Sprint to address |
|---|---|---|
| Customer creation form | `CustomersListScreen` lists; no `+` button → no `CustomerCreateModal` | Sprint 2 |
| Customer details screen | clicking a customer goes nowhere | Sprint 2 |
| Vendor creation form | same as above for vendors | Sprint 3 |
| Product wizard | no UI to create a product with variants/barcodes | Sprint 4 |
| Sales Invoice **create** screen | `SalesInvoicesScreen` lists; no create form (the auto-post-JE logic backend-side already exists) | Sprint 5 |
| Purchase Invoice **create** screen | same — backend posts JE on `/post`, frontend has no creation flow | Sprint 6 |
| POS daily summary report | POS works; needs a `/pos-sessions/{id}/summary` UI | Sprint 7 |

---

## V5.2 Mock Banner

The 18 V5.2-mock chips listed in Tables 1.7 + 1.8 + the mocks in 1.5/1.6
are now wrapped with `V52MockWrap` in
[v5_wired_screens.dart](../apex_finance/lib/core/v5/v5_wired_screens.dart),
which renders a dismissible Material banner at the top:

> 🚧 قيد التطوير — هذه الشاشة لا تتصل بالـ backend بعد.
> ستعتمد على بيانات حقيقية في Sprint قادم.

The banner appears above the existing screen body — no widget code is
duplicated, no fixtures are removed.

---

## Backend Inventory (recon for Sprints 2-7)

| Need | Status |
|---|---|
| `POST /pilot/tenants/{id}/customers` | exists (`customer_routes.py:197`) |
| `POST /pilot/tenants/{id}/vendors` | exists (`purchasing_routes.py`) |
| `POST /pilot/tenants/{id}/products` | exists (`catalog_routes.py`) |
| `POST /pilot/tenants/{id}/products/{pid}/variants` | exists |
| `GET /pilot/tenants/{tid}/barcode/{value}` | exists (lookup ready) |
| `POST /pilot/sales-invoices` + `/issue` | exists; `/issue` already triggers `_post_sales_invoice_je` |
| `POST /pilot/purchase-invoices` + `/post` | exists; `/post` already triggers `post_purchase_invoice_to_gl` |
| `POST /pilot/pos-transactions` | exists; finalize triggers `auto_post_pos_sale` (3 JEs: cash + sales + COGS) |

**Bottom line:** the **backend JE auto-post engines for Sprints 5/6/7
are already implemented**. The remaining work for those sprints is
**purely frontend** — building the create-screens, modals, pickers, and
detail pages on top of endpoints that already exist.

---

## What this audit closes

- ✅ Documented the 70-chip Finance routing surface with a Type column.
- ✅ Confirmed the 5 financial-statement chips already point at
  dedicated screens (G-FIN-IS-1 / G-FIN-BS-1 / G-FIN-CF-1 /
  G-TB-DISPLAY-1, all merged 2026-05-08).
- ✅ Verified the JE auto-post engines for sales / purchase / POS are
  all live in `app/pilot/services/`.
- ✅ Pinned all V52-mock chips with a runtime banner so users see the
  "قيد التطوير" warning instead of believing the data is real.
- ✅ Updated the routing test to add a regression-prevention pin: the
  five dedicated financial-statement chips are required to point at
  their dedicated widgets, not the hub.

## What this audit defers

- ❌ **Permanent deletion** of any legacy widget. The "redirect alias
  kept" decision in Table 3 explicitly preserves backward-compat. If a
  later sprint decides to break those bookmarks, that's a separate
  change with its own deprecation notice.
- ❌ **Permanent deletion** of V52 mock fixtures. The banner makes them
  honest; future sprints will replace fixtures with real backend wires
  one screen at a time.

---

## 6-Sprint Roadmap (Sprints 2-7)

| Sprint | Title | Branch | Headline |
|---|---|---|---|
| 2 | Customers Full CRUD | `feat/g-fin-customers-complete` | Create modal, details screen, picker widget — all on `/pilot/tenants/{id}/customers` |
| 3 | Vendors Full CRUD | `feat/g-fin-vendors-complete` | Clone of Sprint 2 for `/pilot/tenants/{id}/vendors` (IBAN validation, payment terms 60d) |
| 4 | Products Catalog + Barcodes + Variants | `feat/g-fin-product-catalog` | 6-step wizard, EAN13 generator, barcode scanner widget |
| 5 | Sales Invoice + Auto-Post JE | `feat/g-fin-sales-invoice-je-autopost` | Frontend create screen (backend JE engine already exists); 16 tests pinning DR/CR balance |
| 6 | Purchase Invoice + Auto-Post JE | `feat/g-fin-purchase-invoice-je-autopost` | Same pattern as Sprint 5 for inbound bills |
| 7 | POS + Auto-Post 3 JEs | `feat/g-fin-pos-je-autopost` | Daily summary screen + verify the 3-JE pattern (cash + sales + COGS) is reflected in TB |

---

## How to verify

1. `python scripts/dev/repro_routing_bugs.py` — passes (no double-prefix
   bugs, no unwired pins).
2. `flutter test apex_finance/test/v5_routing_test.dart` — passes
   (35+ assertions, including the new pins for the 5 dedicated
   financial-statement chips).
3. Visit `/app/erp/finance/budgets` in the deployed bundle — see the
   🚧 banner above the existing fixture list.
