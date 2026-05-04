# V4 Archive Audit — 2026-05-04

> **Source for Stage 4b–4f sub-PRs.** Each concept section becomes one PR.
> **Cross-ref:** file 38 (Real Routes Flowchart), file 39 § 3.1 (Canonical
> Journey & Archive Mandate), file 40 Stage 4 (Execution Plan).
>
> **This is a docs-only audit. Zero V4 routes are deleted in the
> Stage 4a PR — deletion happens in 4b–4f, one concept per PR.**

---

## Summary

| Metric | Count |
|---|---|
| **Total V4 routes audited** | **92** (in `apex_finance/lib/core/router.dart`) |
| - V4 routes with `pageBuilder` (real handlers) | 69 |
| - V4 routes with `redirect:` (legacy aliases) | 23 |
| **V5 equivalents identified** | 67 (existing V5 wired-screen entries) |
| **V4 routes with no clear V5 equivalent** | 25 (need new V5 wiring or "delete entirely" decision) |
| **Total internal references requiring update** | **~720** across `apex_finance/lib/` |
| **Concepts requiring sub-PRs** | 5 (4b through 4f) |
| **Estimated total effort** | ~8–11 days across 5 sub-PRs |

The internal-references count (~720) is the dominant work driver — the
route deletions themselves are trivial (one line each in router.dart).
The bulk of each Stage 4b–4f PR is updating sidebar / launchpad /
service-hub / Cmd+K command-palette / saved-view config so they point
at the V5 equivalents BEFORE the V4 routes are removed.

---

## V4 Routes Inventory (full table)

Reference counts measured 2026-05-04 via `grep -rE "['\"]<path>" apex_finance/lib/ --include="*.dart"`. Counts include the `router.dart` line itself.

### Stage 4b — Journal Entries (5 routes, ~50 refs, ~1 day)

| V4 path | Type | Screen class | V5 equivalent | Refs | PR |
|---|---|---|---|---|---|
| `/accounting/je-list` | pageBuilder | `JeListScreen` | `/app/erp/finance/je-builder` (LIST) | 32 | 4b |
| `/compliance/journal-entry-builder` | pageBuilder | `JournalEntryBuilderScreen` | `/app/erp/finance/je-builder/new` | 13 | 4b |
| `/compliance/journal-entry/:id` | pageBuilder | `JeBuilderLiveV52Screen(jeId)` | `/app/erp/finance/je-builder/:id` | 5 | 4b |
| `/compliance/journal-entries` | redirect → `/accounting/je-list` | — | `/app/erp/finance/je-builder` | 1 | 4b |
| `/operations/je-creator` | redirect → `/compliance/journal-entry-builder` | — | `/app/erp/finance/je-builder/new` | 1 | 4b |
| `/accounting/journal-entries` | redirect → `/compliance/journal-entries` | — | `/app/erp/finance/je-builder` | 1 | 4b |

**Notes:** the chain redirect `/accounting/journal-entries` → `/compliance/journal-entries` → `/accounting/je-list` should collapse to a single direct redirect during cleanup. The screen files (`je_list_screen.dart`, `journal_entry_builder_screen.dart`) are still referenced via the V5 wired chip `erp/finance/je-builder` → `JeBuilderScreen`, so screen archival is OPTIONAL pending a deeper review.

---

### Stage 4c — Sales (8 routes, ~110 refs, ~1.5 days)

| V4 path | Type | Screen class | V5 equivalent | Refs |
|---|---|---|---|---|
| `/sales/customers` | pageBuilder | `CustomersListScreen` | `/app/erp/sales/customers` (V5 chip → same screen) | 15 |
| `/sales/invoices` | pageBuilder | `InvoicesListScreen` | `/app/erp/sales/invoices` → `InvoicesV52Screen` | 27 |
| `/sales/invoices/new` | pageBuilder | `SalesInvoiceCreateScreen` | `/app/erp/sales/invoices` (modal/route TBD) | included above |
| `/sales/aging` | pageBuilder | `ArAgingScreen` | `/app/erp/sales/ar-aging` (no V5 chip yet — needs wiring) | 16 |
| `/sales/recurring` | pageBuilder | `RecurringInvoicesScreen` | `/app/erp/finance/recurring-entries` → `RecurringEntriesV52Screen` | 6 |
| `/sales/quotes` | pageBuilder | `QuotesListScreen` | (no V5 yet — propose `/app/erp/sales/quotes`) | 9 |
| `/sales/memos` | pageBuilder | `CreditMemosScreen` | (no V5 yet — propose `/app/erp/sales/credit-memos`) | 7 |
| `/sales/payment/:invoiceId` | pageBuilder | `CustomerPaymentScreen(invoiceId)` | (no V5 yet — propose `/app/erp/sales/payment/:id`) | 1 |
| `/compliance/aging` | redirect → `/sales/aging` | — | `/app/erp/sales/ar-aging` | 1 |

**Notes:** `CustomersListScreen` is wired to BOTH `/sales/customers` V4 AND `erp/finance/sales-customers` V5. Same screen file — only the V4 path mapping is removed. Same for `InvoicesV52Screen` (V5) vs the V4 `/sales/invoices` route.

**3 NEW V5 wirings needed** (aging, quotes, memos) before V4 deletion.

---

### Stage 4d — Purchase (6 routes, ~60 refs, ~1 day)

| V4 path | Type | Screen class | V5 equivalent | Refs |
|---|---|---|---|---|
| `/purchase/vendors` | pageBuilder | `VendorsListScreen` | `/app/erp/purchasing/suppliers` (V5 → same screen) | 10 |
| `/purchase/bills` | pageBuilder | `BillsListScreen` | `/app/erp/finance/purchase-bills` → `PurchaseInvoicesScreen` | 20 |
| `/purchase/bills/new` | redirect → `/purchase` | — | (V5 modal/route TBD) | 0 |
| `/purchase/aging` | pageBuilder | `ApAgingScreen` | (no V5 yet — propose `/app/erp/purchasing/ap-aging`) | 11 |
| `/purchase/payment/:billId` | pageBuilder | `VendorPaymentScreen(billId)` | (no V5 yet — propose `/app/erp/purchasing/payment/:id`) | 1 |

**Notes:** the V5 service hub `/app/erp/purchasing/*` is the canonical home for these. `VendorsListScreen` is dual-wired (V4 + V5) like Customers.

**2 NEW V5 wirings needed** (ap-aging, payment).

---

### Stage 4e — Compliance (large; split into 4e.1 + 4e.2 if needed) (~32 routes, ~320 refs, ~3–4 days)

#### 4e.1 — ZATCA / Tax / VAT / Zakat (10 routes)

| V4 path | Type | Screen class | V5 equivalent | Refs |
|---|---|---|---|---|
| `/compliance/zatca-invoice` | pageBuilder | `ZatcaInvoiceBuilderScreen` | `/app/compliance/zatca/invoice` (TBD wiring) | 14 |
| `/compliance/zatca-invoice/:id` | pageBuilder | `ZatcaInvoiceViewerScreen(id)` | TBD | 1 |
| `/compliance/zatca-status` | pageBuilder | `ZatcaStatusCenterScreen` | `/app/erp/finance/zatca-status` (V5 chip exists) | 9 |
| `/compliance/vat-return` | pageBuilder | `VatReturnScreen` | `/app/erp/finance/vat-return` | 26 |
| `/compliance/zakat` | pageBuilder | `ZakatCalculatorScreen` | `/app/erp/finance/zakat` | 16 |
| `/compliance/wht-v2` | pageBuilder | `WhtV2Screen` | `/app/erp/finance/wht` | 11 |
| `/compliance/wht` | redirect → `/compliance/wht-v2` | — | same | 1 |
| `/compliance/tax-calendar` | pageBuilder | `TaxCalendarScreen` | `/app/erp/finance/tax-calendar` | 12 |
| `/compliance/tax-timeline` | pageBuilder | `TaxTimelineScreen` | (V5 path TBD) | 4 |

#### 4e.2 — IFRS / Financial Statements / Ratios (8 routes)

| V4 path | Type | Screen class | V5 equivalent | Refs |
|---|---|---|---|---|
| `/compliance/financial-statements` | pageBuilder | `FinStatementsScreen` | `/app/erp/finance/statements` | 45 |
| `/compliance/cashflow` | pageBuilder | `CashFlowScreen` | `/app/erp/treasury/cashflow` | 12 |
| `/compliance/cashflow-statement` | pageBuilder | `CashflowStatementScreen` | (V5 same as above? — confirm) | 7 |
| `/compliance/ratios` | pageBuilder | `FinancialRatiosScreen` | (no V5 yet — propose `/app/erp/finance/ratios`) | 12 |
| `/compliance/depreciation` | pageBuilder | `DepreciationScreen` | (no V5 yet — propose `/app/erp/finance/depreciation`) | 9 |
| `/compliance/lease-v2` | pageBuilder | `LeaseScheduleV2Screen` | (no V5 yet — propose `/app/compliance/ifrs/lease`) | 8 |
| `/compliance/lease` | redirect → `/compliance/lease-v2` | — | same | 1 |
| `/compliance/ifrs-tools` | pageBuilder | `IfrsToolsScreen` | (no V5 yet — propose `/app/compliance/ifrs/tools`) | 6 |
| `/compliance/deferred-tax` | pageBuilder | `DeferredTaxScreen` | (no V5 yet) | 5 |
| `/compliance/transfer-pricing` | pageBuilder | `TransferPricingScreen` | (no V5 yet) | 6 |
| `/compliance/extras-tools` | pageBuilder | `ExtrasToolsScreen` | (no V5 yet) | 4 |
| `/compliance/amortization` | pageBuilder | `AmortizationScreen` | (no V5 yet) | 5 |
| `/compliance/breakeven` | pageBuilder | `BreakevenScreen` | (no V5 yet — but `breakeven` chip ID exists in v5_data.dart finance) | 6 |

#### 4e.3 — Compliance Misc / KYC / Risk (8 routes)

| V4 path | Type | Screen class | V5 equivalent | Refs |
|---|---|---|---|---|
| `/compliance/kyc-aml` | pageBuilder | `KycAmlScreen` | `/app/compliance/aml` (TBD) | 7 |
| `/compliance/risk-register` | pageBuilder | `RiskRegisterScreen` | `/app/compliance/governance-risk/risk-register` (TBD) | 8 |
| `/compliance/audit-trail` | pageBuilder | `AuditTrailScreen` | `/app/audit/trail` (TBD) | 8 |
| `/compliance/activity-log-v2` | pageBuilder | `ActivityLogV2Screen` | `/app/erp/finance/activity-log` | 20 |
| `/compliance/working-capital` | pageBuilder | `WorkingCapitalScreen` | (no V5 yet) | 6 |
| `/compliance/executive` | pageBuilder | `ExecutiveDashboardScreen` | (no V5 yet) | 8 |
| `/compliance/ocr` | pageBuilder | `OcrScreen` | `/app/erp/finance/receipt-capture` (V5 chip) | 4 |
| `/compliance/dscr` | pageBuilder | `DscrScreen` | (no V5 yet) | 4 |
| `/compliance/valuation` | pageBuilder | `ValuationScreen` | `/app/advisory/valuation/...` (TBD) | 5 |
| `/compliance/fx-converter` | pageBuilder | `FxConverterScreen` | (no V5 yet) | 5 |
| `/compliance/payroll` | pageBuilder | `PayrollScreen` | `/app/erp/hr/payroll` | 14 |
| `/compliance/investment` | pageBuilder | `InvestmentScreen` | (no V5 yet) | 6 |
| `/compliance/consolidation-v2` | pageBuilder | `ConsolidationV2Screen` | `/app/erp/consolidation/dashboard` | 7 |
| `/compliance/consolidation` | redirect → v2 | — | same | 1 |
| `/compliance/audit-workflow-ai` | pageBuilder | `AiAuditWorkflowScreen` | (V5 path TBD) | 2 |
| `/compliance/islamic-finance` | pageBuilder | `IslamicFinanceScreen` | (V5 path TBD) | 4 |
| `/compliance/depreciation-ai` | redirect → `/compliance/depreciation` | — | propose `/app/erp/finance/depreciation` | 1 |
| `/compliance/multi-currency` | redirect → `/analytics/multi-currency-v2` | — | TBD | 1 |
| `/compliance/budget-variance` | redirect → `/analytics/budget-variance-v2` | — | TBD | 1 |
| `/compliance/bank-rec` | redirect → `/accounting/bank-rec-v2` | — | `/app/erp/treasury/recon` | 1 |
| `/compliance/bank-rec-ai` | redirect → `/accounting/bank-rec-v2` | — | same | 1 |
| `/compliance/inventory` | redirect → `/operations/inventory-v2` | — | `/app/erp/inventory/inventory` | 1 |
| `/compliance/health-score` | redirect → `/analytics/health-score-v2` | — | TBD | 1 |
| `/compliance/cost-variance` | redirect → `/analytics/cost-variance-v2` | — | TBD | 1 |
| `/compliance/fixed-assets` | redirect → `/operations/fixed-assets-v2` | — | `/app/erp/finance/fixed-assets` | 1 |

**Compliance is the largest concept by far** — 32 V4 routes + ~320 internal references. Recommend splitting Stage 4e into **4e.1 (ZATCA/Tax)**, **4e.2 (IFRS/Statements)**, **4e.3 (Misc)** if a single PR feels too large. Many of these are redirect-only, which makes them quick wins.

---

### Stage 4f — Remaining (Audit + Analytics + HR + Operations + Marketplace) (~28 routes, ~190 refs, ~2–3 days)

#### 4f.1 — Audit (6 routes)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/audit/engagements` | pageBuilder | `AuditEngagementWorkspaceScreen` | `/app/audit/engagement/dashboard` (TBD) | 10 |
| `/audit/engagement-workspace` | pageBuilder | same screen | same | 0 |
| `/audit/benford` | pageBuilder | same screen (different chip) | `/app/audit/engagement/benford` (TBD) | 6 |
| `/audit/sampling` | pageBuilder | same screen | `/app/audit/engagement/sampling` (TBD) | 7 |
| `/audit/workpapers` | pageBuilder | same screen | `/app/audit/workpapers/...` (TBD) | 5 |
| `/audit/anomaly/:id` | pageBuilder | `AnomalyDetailScreen(id)` | (V5 path TBD) | 1 |
| `/audit/service` | pageBuilder | `AuditServiceScreen(...)` | TBD | 1 |
| `/audit-workflow` | pageBuilder | `AuditWorkflowScreen` | (root-level legacy) | 3 |

#### 4f.2 — Analytics → Advisory (8 routes)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/analytics/cash-flow-forecast` | pageBuilder | `CashFlowForecastScreen` | `/app/erp/finance/cash-flow-forecast` (V5 chip) | 18 |
| `/analytics/budget-variance-v2` | pageBuilder | `BudgetVarianceV2Screen` | `/app/erp/finance/budget-actual` | 11 |
| `/analytics/budget-builder` | pageBuilder | `BudgetBuilderScreen` | `/app/erp/finance/budget-planning` | 12 |
| `/analytics/cost-variance-v2` | pageBuilder | `CostVarianceV2Screen` | (V5 path TBD) | 9 |
| `/analytics/multi-currency-v2` | pageBuilder | `MultiCurrencyV2Screen` | (V5 path TBD) | 9 |
| `/analytics/health-score-v2` | pageBuilder | `HealthScoreV2Screen` | `/app/erp/finance/health-score` | 13 |
| `/analytics/investment-portfolio-v2` | pageBuilder | `InvestmentPortfolioV2Screen` | TBD | 6 |
| `/analytics/project-profitability` | pageBuilder | `ProjectProfitabilityScreen` | `/app/erp/projects/project-pnl` (V5 chip; but `projects` module disabled by G-CLEANUP-4) | 7 |

#### 4f.3 — HR (6 routes)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/hr/employees` | pageBuilder | `EmployeesListScreen` | `/app/erp/hr/employees` (V5 chip → same screen) | 9 |
| `/hr/payroll-run` | pageBuilder | `PayrollRunScreen` | `/app/erp/hr/payroll` (V5.2 → `PayrollRunV52Screen`) | 8 |
| `/hr/expense-reports` | pageBuilder | `ExpenseReportsScreen` | `/app/erp/expenses/expenses` | 12 |
| `/hr/timesheet` | pageBuilder | `TimesheetScreen` | `/app/erp/hr/timesheet` (TBD wiring) | 8 |
| `/hr/gosi` | pageBuilder | `GosiCalcScreen` | `/app/erp/hr/gosi` (TBD wiring) | 7 |
| `/hr/eosb` | pageBuilder | `EosbCalcScreen` | `/app/erp/hr/eosb` (TBD wiring) | 7 |
| `/gosi-demo` | redirect → `/hr/gosi` | — | same | 1 |
| `/eosb-demo` | redirect → `/hr/eosb` | — | same | 1 |

**HR module is currently disabled by G-CLEANUP-4** (Sprint 15 Stage 3) — its launcher tile is hidden, but individual chip routes remain reachable. The HR V4 routes can still be cleaned up; just point internal references at the V5 paths.

#### 4f.4 — Operations (12 routes)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/operations/inventory-v2` | pageBuilder | `InventoryV2Screen` | `/app/erp/inventory/inventory` | 11 |
| `/operations/fixed-assets-v2` | pageBuilder | `FixedAssetsV2Screen` | `/app/erp/finance/fixed-assets` (V5.2) | 8 |
| `/operations/petty-cash` | pageBuilder | `PettyCashScreen` | (V5 path TBD) | 6 |
| `/operations/stock-card` | pageBuilder | `StockCardScreen` | (V5 path TBD — V5 has `erp/inventory/stock-movements`) | 10 |
| `/operations/stock-card/:sku` | pageBuilder | `StockCardScreen(sku)` | TBD | 0 |
| `/operations/customer-360/:id` | pageBuilder | `Customer360Screen(id)` | (V5 path TBD) | 4 |
| `/operations/vendor-360/:id` | pageBuilder | `Vendor360Screen(id)` | (V5 path TBD) | 3 |
| `/operations/universal-journal` | pageBuilder | `UniversalJournalScreen` | (deletion candidate per G-CLEANUP-3 banner removal) | 3 |
| `/operations/period-close` | pageBuilder | `PeriodCloseScreen` | `/app/erp/finance/period-close` | 14 |
| `/operations/pos-sessions` | pageBuilder | `PosSessionScreen` | `/app/erp/pos/sessions` (TBD wiring) | 3 |
| `/operations/purchase-cycle` | pageBuilder | `PurchaseCycleScreen` | (no V5 yet — propose `/app/erp/purchasing/cycle`) | 5 |
| `/operations/consolidation-ui` | pageBuilder | `ConsolidationUiScreen` | `/app/erp/consolidation/dashboard` | 3 |
| `/operations/live-sales-cycle` | pageBuilder | `LiveSalesCycleScreen` | (no V5 yet) | 7 |
| `/operations/hub` | redirect → `/financial-ops` | — | TBD | 1 |
| `/operations/je-creator` | redirect → `/compliance/journal-entry-builder` | — | (covered by 4b) | 1 |
| `/operations/financial-statements` | redirect → `/compliance/financial-statements` | — | (covered by 4e) | 0 |
| `/operations/financial-analysis` | redirect → `/compliance/ratios` | — | TBD | 0 |

#### 4f.5 — Marketplace + Provider + Service-* (5 routes)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/service-catalog` | pageBuilder | `catalog.ServiceCatalogScreen` | `/app/marketplace/catalog` (TBD) | 2 |
| `/service-request/detail` | pageBuilder | `ServiceRequestDetail` | `/app/marketplace/request/:id` (TBD) | 1 |
| `/marketplace/new-request` | pageBuilder | `NewServiceRequestScreen` | `/app/marketplace/new-request` (V5 chip TBD) | 2 |
| `/provider-kanban` | pageBuilder | `ProviderKanbanScreen` | `/app/marketplace/provider-board` (TBD) | 3 |
| `/provider/profile` | pageBuilder | `ProviderProfileScreen` | TBD | 1 |

#### 4f.6 — Accounting (3 routes — small, can fold into 4b or 4e)

| V4 path | Type | Screen | V5 equivalent | Refs |
|---|---|---|---|---|
| `/accounting/coa-v2` | pageBuilder | `CoaTreeV2Screen` | `/app/erp/finance/coa-editor` (V5 → `CoaEditorScreen`) | 12 |
| `/accounting/coa/edit` | pageBuilder | `CoaEditorScreen` | same | 7 |
| `/accounting/coa` | redirect → `/coa-tree` | — | TBD | 1 |
| `/accounting/bank-rec-v2` | pageBuilder | `BankRecV2Screen` | `/app/erp/treasury/recon` (V5 chip exists) | 8 |
| `/accounting/trial-balance` | redirect → `/compliance/financial-statements` | — | (covered by 4e) | 0 |
| `/accounting/period-close` | redirect → `/operations/period-close` | — | (covered by 4f.4) | 0 |

---

## V4 routes with no clear V5 equivalent (decision required)

These 25 routes don't have a V5 wiring target identified during the audit. Decision needed: **(a) wire to a V5 path during cleanup**, **(b) delete entirely if dead**, or **(c) defer to a future "Coming Soon" tile under G-CLEANUP-4 / G-MOD-* track**.

- `/sales/quotes`, `/sales/memos`, `/sales/aging`, `/sales/payment/:invoiceId`
- `/purchase/aging`, `/purchase/payment/:billId`, `/purchase/bills/new`
- `/compliance/working-capital`, `/compliance/executive`, `/compliance/ocr`, `/compliance/dscr`, `/compliance/valuation`, `/compliance/fx-converter`, `/compliance/cashflow-statement`, `/compliance/deferred-tax`, `/compliance/transfer-pricing`, `/compliance/extras-tools`, `/compliance/amortization`, `/compliance/audit-workflow-ai`, `/compliance/islamic-finance`
- `/operations/petty-cash`, `/operations/stock-card`, `/operations/customer-360/:id`, `/operations/vendor-360/:id`, `/operations/universal-journal`, `/operations/live-sales-cycle`
- `/audit/anomaly/:id`, `/audit/service`, `/audit/engagement-workspace`, `/audit-workflow`
- `/analytics/cost-variance-v2`, `/analytics/multi-currency-v2`, `/analytics/investment-portfolio-v2`
- `/hr/timesheet`
- All marketplace/provider routes (`/service-catalog`, `/service-request/detail`, `/marketplace/new-request`, `/provider-kanban`, `/provider/profile`)

Each Stage 4b–4f sub-PR's Verify-First step starts with: **for each "no V5" route, decide a/b/c**.

---

## Edge cases & flags

### 1. Same screen reachable from multiple paths (V4 + V5 dual-wired)

Many V4 screen widgets (`CustomersListScreen`, `VendorsListScreen`,
`InvoicesListScreen`, `JeListScreen`, `CoaEditorScreen`, etc.) are
ALREADY referenced from V5 wired-screens. The cleanup deletes the
**V4 path mapping** in `router.dart`, NOT the screen file. **Screen
archival is OPTIONAL and orthogonal to V4 route deletion** — track
unused screen files separately for a Stage 5 / 6 archive sweep.

### 2. Service Hub screens at `/sales`, `/purchase`, `/accounting`, etc.

`router.dart:293-305` registers 12 service-hub paths (`/sales`,
`/purchase`, `/accounting`, `/operations`, `/compliance-hub`, etc.)
that all map to `ApexServiceHubScreen(serviceId: '<...>')`. Each hub
screen contains internal-link tiles that point at V4 paths under that
service. **These hub screens are themselves V4-era IA** and should be
deleted alongside their V4 route children — but only after every V4
target route has been migrated. Recommend treating them as "Stage 4g"
or as the final cleanup item in 4f.

### 3. The V5 Workpaces remnant (already cleaned by G-CLEANUP-3)

G-CLEANUP-3 Stage 2 already removed the home-page `_WorkspaceCard`
section. The `v5Workspaces` data structure is still alive and used by
the `/workspace/:id` route → `V5WorkspaceShell`. Each workspace contains
"shortcuts" — many of which point at V4 paths. **Stage 4b–4f sub-PRs
must update workspace-shortcut config too** (in `v5_data.dart` near the
`v5Workspaces` definitions).

### 4. `apex_commands_registry.dart` (Cmd+K palette)

The Cmd+K command palette is the most-referenced internal config —
it has dedicated commands like `go('/sales/customers')` that need
updating. **Required for every Stage 4 sub-PR.**

### 5. `apex_magnetic_shell.dart` (sidebar / navigation)

Same pattern — sidebar items reference V4 paths. Update per concept.

### 6. `apex_saved_views_v2.dart` (saved views)

Saved-view definitions reference V4 paths via the `screen:` field.
Update per concept.

### 7. `apex_launchpad_screen.dart` (the `/launchpad/full` verbose launcher)

This screen — registered at `/launchpad/full` for power users —
contains tile definitions pointing at V4 paths. It's NOT the home
dashboard (that was cleaned in G-CLEANUP-3). Recommend **archiving
this screen** in Stage 4f.5 since it duplicates the 5-Pillar home
dashboard purpose with V4 navigation language.

### 8. `apex_service_hub_screen.dart` (the `/sales`, `/purchase` hubs)

Internal `flow:` lists reference V4 paths. Same fate as the hub routes
(see edge case #2): delete in final cleanup pass.

### 9. Test files referencing V4 paths

Some tests under `apex_finance/test/` may reference V4 paths as
fixtures. Each Stage 4 sub-PR must grep its concept's V4 paths
in `test/` and update.

### 10. Documentation (out-of-scope for Stage 4)

The blueprint chapters `04_SCREENS_AND_BUTTONS_CATALOG.md`,
`03_NAVIGATION_MAP.md`, `06_PERMISSIONS_AND_PLANS_MATRIX.md` reference
V4 paths in their per-route tables. Those updates are tracked under
**G-CLEANUP-5 (Sprint 17)** — NOT Stage 4. Do not bundle.

---

## Recommended order (lowest-risk first)

1. **Stage 4b — Journal Entries** (5 routes / ~50 refs / ~1 day)
   - Smallest, well-defined concept. Tests the workflow pattern.
   - Most chains are redirect-only; primary work is updating Cmd+K palette + sidebar refs.
2. **Stage 4c — Sales** (8 routes / ~110 refs / ~1.5 days)
   - Medium concept. 3 NEW V5 wirings needed (aging, quotes, memos).
3. **Stage 4d — Purchase** (6 routes / ~60 refs / ~1 day)
   - Similar shape to Sales; can run in parallel if reviewers allow.
4. **Stage 4e — Compliance** (32 routes / ~320 refs / ~3–4 days)
   - Largest. Recommend splitting into **4e.1 / 4e.2 / 4e.3** if a
     single PR feels too heavy.
5. **Stage 4f — Remaining** (Audit + Analytics + HR + Operations + Marketplace) (~28 routes / ~190 refs / ~2–3 days)
   - May further split into 4f.1–4f.5 by sub-concept.

**Total effort estimate: ~8–11 days across 5 PRs (or 7 if Compliance and
Remaining are split).**

---

## Internal references master list

For brevity, the full file:line list is captured by running
`grep -rE "['\"]/<v4-path>['\"]" apex_finance/lib/ --include="*.dart"`
in each sub-PR's Verify-First step. The reference COUNTS in the
tables above are the canonical scope estimate.

The most-referenced V4 paths (top 10) are:

| Path | Refs | Driver |
|---|---|---|
| `/compliance/financial-statements` | 45 | every Pillar 1 dashboard's "view statements" link |
| `/accounting/je-list` | 32 | sidebar + Cmd+K + every JE screen's "back to list" |
| `/sales/invoices` | 27 | sidebar + service-hub + invoice-detail back-nav |
| `/compliance/vat-return` | 26 | tax timeline references + dashboard widgets |
| `/compliance/activity-log-v2` | 20 | every screen's "audit log" link |
| `/purchase/bills` | 20 | sidebar + service-hub + AP screens |
| `/analytics/cash-flow-forecast` | 18 | dashboard widget + forecast back-nav |
| `/sales/aging` | 16 | dashboard + AR-aging back-nav |
| `/compliance/zakat` | 16 | tax dashboard + zakat back-nav |
| `/sales/customers` | 15 | sidebar + multiple sales screens |

These are the high-leverage targets — fixing the Cmd+K palette and
sidebar accounts for >50% of the internal-reference work in one
sweep, then individual screens get touched per concept.

---

## What this audit does NOT include

- **Per-screen-file archival decisions.** Many V4 screens are still
  used by V5 routes. Stage 4 deletes ROUTES not SCREENS. Screen
  archival is a Stage 5 / 6 sweep.
- **Backend / API route cleanup.** The Python backend is unchanged
  by G-CLEANUP-1; only Flutter routing.
- **Documentation cleanup.** Tracked under G-CLEANUP-5.
- **CRUD verification of remaining V5 routes.** That's G-CLEANUP-6
  (Sprint 16).

---

## Cross-references

- `APEX_BLUEPRINT/38_REAL_ROUTES_FLOWCHART_2026-05-04.md` § 2-3 — visualises the V4/V5 duplication.
- `APEX_BLUEPRINT/39_CANONICAL_JOURNEY_AND_ARCHIVE_MANDATE_2026-05-04.md` § 3.1 — the directive (~70 V4 routes; actual 92).
- `APEX_BLUEPRINT/40_CLAUDE_CODE_EXECUTION_PLAN_2026-05-04.md` Stage 4 — the execution plan this audit feeds.
- `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md` § 20.1 G-CLEANUP-1 — the registered gap.
- `apex_finance/lib/core/router.dart` — the canonical source.
- `apex_finance/lib/core/v5/v5_wired_screens.dart` — V5 chip → screen mappings.
