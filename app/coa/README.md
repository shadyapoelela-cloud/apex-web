# `app.coa` — Chart of Accounts

Canonical per-tenant / per-entity Chart of Accounts CRUD surface
(CoA-1, Sprint 17).

## How this differs from `app/coa_engine/`

| | `app/coa_engine/` | `app/coa/` (this module) |
| --- | --- | --- |
| **Scope** | Bulk import → classify → review → approve | Day-to-day CRUD on the running chart |
| **Entry** | `/api/v1/coa-engine/upload` then `/classify` | `/api/v1/coa/...` (14 endpoints) |
| **Storage** | Workflow tables (uploads, classifications, approvals) | `chart_of_accounts` (canonical) + `coa_templates` + `coa_change_log` |
| **Lifecycle** | One-time onboarding | Continuous |

## How this differs from `app/pilot/models/gl.py::GLAccount`

`pilot_gl_accounts` stays as the runtime account table for the pilot
multi-tenant retail ERP. `app.coa` adds a **canonical** chart-of-
accounts surface intended for cross-pilot use (audit firms,
accounting firms, services tenants). See `GAP_ANALYSIS.md` for the
full reasoning + the planned backfill (CoA-1.1).

## Schema

### `chart_of_accounts`

4-level hierarchy:

```
1. Class    (asset / liability / equity / revenue / expense)
└─ 11. Group         (current_asset, ...)
   └─ 110. Account   (cash, ...)
      └─ 1101. Sub   (Main Cash Box, NCB Current, ...)
```

`full_path` is denormalised dot-separated lineage (`1.11.110.1101`)
so tree fetches are O(log n). The service recomputes `full_path` for
the row + every descendant when `parent_id` changes.

Posting rules:
- `is_postable=False` → header / aggregator (no journal lines)
- `is_reconcilable=True` → AR / AP / Bank (used by reconciliation)
- `requires_*` (cost_center / project / partner) → dimensional
  tracking gates (when True, journal lines on this account MUST
  carry the matching dimension; wiring into the GL posting validator
  is a follow-up).

### `coa_templates`

Packaged standard charts. `accounts` is a JSON array of dicts with
the same field shapes as `ChartOfAccount` (minus tenant/entity/id).
The importer fills those at import time.

Three templates ship with CoA-1:

| code | accounts | what |
| --- | --- | --- |
| `socpa-retail-2024` | 104 | SOCPA + ZATCA-aware retail (cash, POS, AR/AP, VAT, GOSI/EOSB, fixed assets, sales returns, OPEX) |
| `ifrs-services-2024` | 41 | IFRS 15 contract assets/liabilities, project labour, subscription revenue |
| `ifrs-manufacturing-2024` | 50 | IAS 2 RM / WIP / FG split, direct labour, manufacturing overhead, variance |

### `coa_change_log`

Append-only audit log. Every write produces one row:

| field | value |
| --- | --- |
| `action` | `create` / `update` / `deactivate` / `reactivate` / `delete` / `merge` / `import_template` |
| `diff` | JSON object — for `update` rows: `{field: {"old": ..., "new": ...}}` |
| `user_id` | the JWT-resolved caller |
| `reason` | optional free-text reason (passed via `AccountUpdateIn.reason`) |

Indexed on `(account_id, timestamp)` so the per-account changelog
view fetches in O(log n).

## Permissions

| perm | who |
| --- | --- |
| `read:chart_of_accounts` | every authed finance user |
| `write:chart_of_accounts` | accountant, CFO |
| `delete:chart_of_accounts` | CFO (with usage check) |
| `merge:chart_of_accounts` | CFO |
| `import:coa_template` | CFO + accounting-firm admin |
| `export:chart_of_accounts` | CFO + auditor (read scope ext.) |
| `manage:coa_templates` | platform admin (custom-template authoring) |
| `approve:coa_changes` | CFO (workflow gate — workflow staged in this PR) |

## Endpoints

```
GET    /api/v1/coa/tree                         read:chart_of_accounts
GET    /api/v1/coa/list                         read:chart_of_accounts
GET    /api/v1/coa/templates                    read:chart_of_accounts
GET    /api/v1/coa/export?fmt=json|csv          export:chart_of_accounts
GET    /api/v1/coa/{id}                         read:chart_of_accounts
GET    /api/v1/coa/{id}/changelog               read:chart_of_accounts
GET    /api/v1/coa/{id}/usage                   read:chart_of_accounts
POST   /api/v1/coa/                             write:chart_of_accounts
PATCH  /api/v1/coa/{id}                         write:chart_of_accounts
POST   /api/v1/coa/{id}/deactivate              write:chart_of_accounts
POST   /api/v1/coa/{id}/reactivate              write:chart_of_accounts
DELETE /api/v1/coa/{id}                         delete:chart_of_accounts
POST   /api/v1/coa/merge                        merge:chart_of_accounts
POST   /api/v1/coa/templates/{code}/import      import:coa_template
```

All return the canonical `{success, data}` envelope (except `/export`
which streams `text/plain` for direct CSV download).

## How to add a new template

1. Add the account list in `app/coa/seeds.py` — define a `_my_chart_accounts()`
   function that returns the list of dicts, using the `_acct(...)`
   helper for consistency.
2. Append to `SYSTEM_TEMPLATES` with code, name_ar/en, standard,
   industry, accounts.
3. Run `python -c "from app.coa.seeds import seed_coa_templates; seed_coa_templates()"`
   to upsert.
4. Tenants then call `POST /api/v1/coa/templates/{code}/import` with
   `{"entity_id": "..."}` to instantiate the chart for an entity.

## How to add a new permission

Edit `app/core/custom_roles._PERMISSIONS` (alphabetical within the
`finance` or `admin` block). The 8 CoA permissions live there
prefixed `*:chart_of_accounts` or `*:coa_*`.

## Cross-references

- `app/coa/GAP_ANALYSIS.md` — why this is a new module
- `app/dashboard/resolvers.py::list_recent_account_changes` — the
  dashboard widget that surfaces this audit log
- `app/dashboard/seeds.py::SYSTEM_WIDGETS` — `list.recent_account_changes`
  catalog entry
- `app/core/saved_views.py` — same persistence pattern
- `app/core/tenant_guard.py::TenantMixin` — auto-filter on every
  read (the test fixture deliberately binds `set_tenant("t-coa")`
  for the test body so the just-created rows are visible)

## Coverage

```
pytest tests/test_coa_api.py --cov=app.coa
  app/coa/__init__.py        100%
  app/coa/models.py          100%
  app/coa/schemas.py          92%
  app/coa/seeds.py            99%
  app/coa/service.py          86%
  app/coa/router.py           67%   (admin-paths exercised by manual / Postman)
  TOTAL                       87.30%
  34 passed in 6.38s
```

## What's NOT in this PR (deferred follow-ups)

- **CoA-1.1** — backfill `pilot_gl_accounts` → `chart_of_accounts`
  for tenants on the pilot ERP.
- **CoA-1.2** — full Flutter UI: Three-Pane screen + 7 dialogs +
  drag-drop reparent + live search + Excel I/O. The api_service stubs
  (`coaTree`, `coaList`, `coaCreate`, ..., 14 methods) are wired in
  this PR so DASH-1.1-style hook injection works for the screen.
- **Approval workflow** — `approve:coa_changes` permission is added
  but the workflow itself (proposed-change → approver-decides →
  apply) is staged for a later PR.
- **GL posting validator** — `requires_cost_center` / `requires_project`
  / `requires_partner` flags are stored but not yet consulted by the
  GL posting routes.
- **Multi-currency revaluation hooks** — orthogonal feature.
