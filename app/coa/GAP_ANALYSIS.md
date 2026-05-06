# CoA-1 — Gap Analysis (2026-05-06)

What exists today vs what CoA-1 needs.

## Existing infrastructure

### `app/coa_engine/` (pre-CoA-1)

11 Python modules, ~9.6k LOC. **Scope: bulk import + classification + governance** of customer-uploaded charts of accounts, NOT day-to-day CRUD.

What it does:
- `engine.py` — main classifier; takes an Excel/CSV upload and assigns each row to APEX's canonical taxonomy.
- `error_checks.py` + `error_checks_wave2.py` — 2k+ lines of validation (orphans, dup codes, mis-classified categories, missing required accounts).
- `lexicon_loader.py` — reads `APEX_COA_Names_Lexicon_v4_4.xlsx` (5 standards × hundreds of canonical names).
- `governance.py` — approval workflow for proposed account assignments.
- `migration_bridge.py` — pushes approved CoA into the runtime tables.
- `api_routes.py` — 10 endpoints for `upload → classify → review → approve` flow.

**Gap:** there is no day-to-day "create / edit / deactivate / merge an account" surface. Once the upload-and-approve flow lands a chart, users cannot evolve it.

### `app/pilot/models/gl.py::GLAccount`

The runtime account table for the pilot multi-tenant retail ERP. Fields:
- `id, tenant_id, entity_id, parent_account_id, code, name_ar, name_en`
- `category, subcategory, type, normal_balance, level`
- `is_system, is_active, is_control`
- `currency, require_cost_center, require_profit_center, default_vat_code`
- `created_at, updated_at`

**What it has** that overlaps with CoA-1's requested schema: tenant scoping, parent linkage, level, category/subcategory, normal_balance, is_system/active flags, currency, cost-center / profit-center toggles.

**What it lacks** vs CoA-1's spec:
- No `full_path` denormalisation → tree queries are recursive at read time.
- No separate `account_class` from `account_type` (pilot conflates them under `category`).
- No `is_postable` flag → callers can't easily distinguish "header / aggregator" rows from leaf postable accounts.
- No `is_reconcilable` flag → AR/AP/Bank handling is implicit.
- No `requires_project` / `requires_partner` → only cost/profit centre.
- No `tags` / `custom_fields` JSON metadata.
- No `standard_ref` (for IFRS / SOCPA cross-references).
- No `created_by` audit field.

### `app/sprint4_tb/models/tb_models.py`

Trial balance models — out of scope for CoA-1. Useful only for the "where is this account used" badge later.

### `app/dashboard/` (DASH-1, merged 2026-05-06)

Per-user / per-role dashboards. CoA-1 will surface a dashboard widget
`list.recent_account_changes` that reads from the new
`coa_change_log` table.

## CoA-1 scope (what this PR adds)

| layer | net new | reuses |
| ----- | ------- | ------ |
| **Schema** | 3 tables: `chart_of_accounts`, `coa_templates`, `coa_change_log` | — |
| **Permissions** | 8 new entries in `app.core.custom_roles` | — |
| **Service** | full CRUD + tree builder + merge + import-template + audit logger | `app.core.tenant_guard`, `app.core.cache`, `app.core.event_bus` |
| **API** | 14 endpoints under `/api/v1/coa` | `auth_utils.get_current_user`, `{success, data}` envelope |
| **Seeds** | 3 standard templates: SOCPA-Retail, IFRS-Services, IFRS-Manufacturing | — |
| **Migration** | `i3d9f6c2e8a5` hand-written, idempotent | the pattern from DASH-1 hotfix `h2c5e8f1a4b7` |
| **Frontend** | Three-pane screen + 7 dialogs + drag-drop reparent + live search + CSV/Excel I/O | `apex_dashboard_builder.dart`-style widget patterns; `AC` colour singleton; `apex_responsive` |
| **Tests** | 25+ API + 25+ widget | conftest patterns |
| **Dashboard hook** | 1 new resolver `coa.changelog.recent` | DASH-1 widget catalog |

## Why a NEW table (`chart_of_accounts`) and not extend `pilot_gl_accounts`?

`pilot_gl_accounts` is namespaced for the pilot retail ERP. CoA-1 is
intended to be the **canonical** chart-of-accounts surface across the
whole platform — including non-pilot tenants (audit firms, accounting
firms, services). Extending the pilot table would couple every CoA
consumer to the pilot package.

A separate `chart_of_accounts` table:
- Lets the pilot keep its existing schema unchanged (zero migration risk
  for the pilot).
- Gives the new screen a clean schema designed for the 4-level
  hierarchy + standard cross-references + tags + custom fields.
- Lets future migration-bridge work copy from the canonical to the
  pilot (or vice-versa) without circular constraints.

Backfill from `pilot_gl_accounts` → `chart_of_accounts` is tracked as
a follow-up (CoA-1.1).

## Out of scope for this PR

- **Backfilling existing pilot accounts** into the new table — CoA-1.1.
- **Multi-currency revaluation hooks** — orthogonal feature.
- **GL posting validation** that consults `is_postable` — wire when GL
  posting routes need it.
- **Approval workflow** (`approve:coa_changes` permission added but the
  workflow is staged; PR establishes the perm so approvers can be
  assigned).
- **Frontend drag-drop reparent UI** — implemented as basic move-via-
  dialog in this PR; native drag-drop tracked as CoA-1.2.

Status field at PR description tracks which phases shipped fully vs
deferred.
