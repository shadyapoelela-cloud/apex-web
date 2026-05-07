# G-CHIPS-WIRE-FIN-1 — Reconnaissance Audit (2026-05-06)

Ground truth for the 13 finance chips reported as unreachable by the
runtime validator after HOTFIX-Routing landed. Every entry verified by
`Glob` + `Grep` against the actual codebase, **not** by trusting the
audit report.

Decision rule per chip:
- ✅ widget exists, `const Foo({super.key})` constructor → **WIRE**
- ⚠️ widget exists but constructor needs required params → **TODO**
- ❌ widget missing → **TODO** (don't create new screens)

| chip | shell switch fallback today | screen file (verified) | class name | const w/o args? | decision |
|------|------|------|------|------|------|
| `erp/finance/sales-invoices` | yes (line 232) | `screens/operations/sales_invoices_screen.dart` | `SalesInvoicesScreen` | yes (line 28) | **WIRE direct** (drop indirection) |
| `erp/finance/entity-setup` | yes (line 235) | `screens/settings/entity_setup_screen.dart` | `EntitySetupScreen` | yes — `const EntitySetupScreen({super.key, this.initialAction})` | **WIRE direct** |
| `erp/finance/ar-aging` | no | `screens/operations/ar_aging_screen.dart` | `ArAgingScreen` | yes | **WIRE** |
| `erp/finance/ap-aging` | no | `screens/operations/ap_aging_screen.dart` | `ApAgingScreen` | yes | **WIRE** |
| `erp/finance/vat-return` | no | `screens/v5_2/vat_return_v52_screen.dart` | `VatReturnV52Screen` | yes | **WIRE** |
| `erp/finance/cash-flow-forecast` | no | `screens/compliance/cashflow_screen.dart` | `CashFlowScreen` (note PascalCase F) | yes — already wired for chip `cashflow` at line 756 | **WIRE** (reuse same screen) |
| `erp/finance/tax-calendar` | no | `screens/compliance/tax_timeline_screen.dart` | `TaxTimelineScreen` | yes | **WIRE** |
| `erp/finance/wht` | no | `screens/compliance/wht_v2_screen.dart` | `WhtV2Screen` | yes | **WIRE** |
| `erp/finance/zakat` | no | `screens/compliance/zakat_calculator_screen.dart` | `ZakatCalculatorScreen` | yes | **WIRE** |
| `erp/finance/zatca-status` | no | `screens/compliance/zatca_status_center_screen.dart` | `ZatcaStatusCenterScreen` | yes | **WIRE** |
| `erp/finance/activity-log` | no | `screens/v4_erp/activity_log_screen.dart` | `ActivityLogScreen` | yes | **WIRE** |
| `erp/finance/receipt-capture` | no | `screens/operations/receipt_capture_screen.dart` | `ReceiptCaptureScreen` | yes | **WIRE** |
| `erp/finance/health-score` | no | (no file matches `*health_score*`) | — | — | **TODO** — needs new screen, out of scope |
| `erp/finance/inventory` | no | (no `*inventory*` widget under apex_finance/lib) | — | — | **TODO** — chip should arguably redirect to `erp/inventory/*`, out of scope |

## Wire summary
- **12 chips wireable now** (10 brand-new + 2 indirection-removal: sales-invoices, entity-setup).
- **2 chips deferred** as TODO (health-score, inventory) — no existing widget; building new screens is out of scope per the strict rules of this PR.

## Notes
- `compliance/cashflow_screen.dart` defines `CashFlowScreen` (PascalCase F), not `CashflowScreen`. The audit report's hint at "CashflowScreen" was wrong. The chip `cash-flow-forecast` will reuse the same widget as the existing `cashflow` wiring (line 756) — they both point at the forecasting calculator.
- Two `vat_return*` screens exist: `compliance/vat_return_screen.dart` and `v5_2/vat_return_v52_screen.dart`. Per the audit report we use the V5.2 variant.
- The shell switch removal (sales-invoices, entity-setup) only affects what the validator sees — runtime behavior is identical because the switch is checked AFTER the wired-builder lookup.
