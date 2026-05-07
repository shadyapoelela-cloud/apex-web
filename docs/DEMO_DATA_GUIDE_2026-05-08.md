# Demo Data Seeder Guide (v1 — master-data tier)

After ERR-2 Phase 3 + the legacy-tenant migration shipped, every tenant
starts empty. The customer / vendor / product chips wired in PR #161
work but have nothing to render. This endpoint backfills a tenant with
realistic Saudi-retail master data so stakeholder demos look alive.

## What gets seeded

| Table              | Rows | Examples                                 |
|--------------------|------|------------------------------------------|
| `pilot_customers`  | 5    | شركة الراجحي للتجارة (RTC-001), …        |
| `pilot_vendors`    | 5    | شركة المعدن للأدوات الصناعية (MTL-001), … |
| `pilot_products`   | 15   | ورق طباعة A4 — 80 جم (PAP-A4-80), …       |

All rows are tenant-scoped. The existing `TenantContextMiddleware` +
`attach_tenant_guard` continue to filter cross-tenant queries — seeding
tenant A never appears in tenant B.

## What the seeder does NOT touch (deferred)

The original spec asked for journal entries, sales / purchase invoices,
and payments too. Those need a curated FK chain that this codebase
doesn't yet have a packaged seeder for: `pilot_entities`,
`pilot_fiscal_periods`, ~8 `pilot_gl_accounts` rows for the JE side,
AR/AP control accounts, running invoice numbers. **Tracked as
`G-DEMO-DATA-SEEDER-V2`**, separate PR.

The summary dict surfaces the deferred record types as zeros with an
explicit `_note` so a UI consumer can render a "demo ready (basic
tier)" badge today and switch to the V2 endpoint when it lands.

## How to use

### As an authenticated user (recommended)

Every authenticated user can populate **their own** tenant — admin
secret is NOT required because the tenant id comes from the user's own
JWT (`tenant_id` claim added in ERR-2 Phase 3 / PR #169). Future "Try
with demo data" UI button hits this endpoint.

```bash
curl -X POST https://apex-api-ootk.onrender.com/api/v1/account/seed-demo-data \
  -H "Authorization: Bearer $JWT"
```

Response (success path):

```json
{
  "success": true,
  "data": {
    "success": true,
    "skipped": false,
    "tenant_id": "…",
    "summary": {
      "master_data": { "customers": 5, "vendors": 5, "products": 15 },
      "deferred": {
        "journal_entries": 0,
        "sales_invoices": 0,
        "purchase_invoices": 0,
        "payments": 0,
        "_note": "GL + invoice + payment seeding is deferred to G-DEMO-DATA-SEEDER-V2 — see service docstring."
      }
    }
  }
}
```

If the JWT has no `tenant_id` claim (legacy session predating ERR-2
Phase 3 for that user), the endpoint returns **400** with a pointer to
`/admin/migrate-legacy-tenants` — closes the loop with the legacy
backfill PR (#170).

### As an admin (for ops onboarding)

Used to populate a tenant before handing it over to a customer. Admin
secret required.

```bash
curl -X POST "https://apex-api-ootk.onrender.com/admin/seed-demo-data?tenant_id=$TID" \
  -H "X-Admin-Secret: $ADMIN_SECRET"
```

Returns the same shape. Returns **404** if `tenant_id` doesn't match
any row in `pilot_tenants`.

### Force re-seed (diagnostic)

```bash
curl -X POST "…/seed-demo-data?force=true" -H "…"
```

`force=true` does NOT delete existing rows. It appends another batch
with codes that have a fresh 6-hex-char suffix so the
`uq_pilot_*_tenant_code` unique constraints don't fire. Useful for
testing a clean state on an already-seeded tenant; not the recommended
"reset and reseed" flow (there is no such flow yet).

## Idempotency contract

Sentinel: any `pilot_customers` row owned by the tenant. Without
`force=true`, a second invocation returns:

```json
{
  "success": true,
  "skipped": true,
  "tenant_id": "…",
  "reason": "Tenant already has seeded master data. Pass force=true to append another batch."
}
```

Re-running is safe — admins can click the button twice without
double-creating data.

## Risk profile

- **No schema changes.** Uses the existing `pilot_customers`,
  `pilot_vendors`, `pilot_products` tables exactly as ERR-2 Phase 3 +
  the rest of the platform expect them.
- **No frontend changes.** The endpoints are dormant until called.
- **Tenant-scoped.** Every insert carries `tenant_id`; the existing
  guard filters cross-tenant access.
- **Idempotent.** Repeat calls without `force` are no-ops.
- **Bounded blast radius.** ~25 records per call, all in ONE tenant.

## Out of scope

- POS sessions / shifts (separate flow with hardware)
- HR / payroll / employees
- Bank accounts + reconciliation
- Multi-currency transactions
- Approval workflows
- Inventory levels (products are seeded with `total_stock_on_hand=0`)

These remain empty by design — they're not part of the master-data
demo path.
