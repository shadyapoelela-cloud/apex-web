# Pilot Multi-Tenancy Isolation — Final Audit Summary

**Date:** 2026-05-08
**Status:** ✅ Issue #3 FULLY CLOSED
**Surface covered:** 117 pilot routes across 9 route files

---

## Three audits, one closure

This document summarises the three sequential audits that closed the
multi-tenancy isolation gap on the pilot route surface.

### Audit 1 — G-TB-REAL-DATA-AUDIT (PR #174)

**Discovered the gap.** The trial-balance endpoint
(`GET /pilot/entities/{eid}/reports/trial-balance`) returned tenant
B's TB rows when called with tenant A's JWT and tenant B's entity id.
Root cause: pilot models (`Entity`, `JournalEntry`, `GLPosting`, …)
declare `tenant_id` as a plain column rather than inheriting
`TenantMixin`, so the global `attach_tenant_guard` SQLAlchemy hook
silently skipped them.

**Scope of fix:** `_entity_or_404` in `gl_routes.py` was patched to
accept `current_user` and 403 on cross-tenant. Local helper, single
route. 11 tests.

### Audit 2 — G-PILOT-REPORTS-TENANT-AUDIT (PR #175)

**Generalised the fix.** The same helper pattern was extracted to
`app/pilot/security/tenant_guards.py::assert_entity_in_tenant`, then
rolled out to **all 32 pilot routes** that take `entity_id` (path or
payload). Switched the response code from **403 → 404** for
anti-enumeration: cross-tenant probes now return the same body as a
genuinely missing id, so status codes leak no existence signal.
Added structured `TENANT_GUARD_VIOLATION` warning logs for SOC.
28 parameterized matrix tests.

### Audit 3 — G-PILOT-TENANT-AUDIT-FINAL (this PR)

**Closed the remaining two shapes:**

1. **Tenant-shaped routes** (`/tenants/{tenant_id}/...`) — 37 routes
   across `pilot_routes.py`, `catalog_routes.py`, `customer_routes.py`,
   `purchasing_routes.py`, `pricing_routes.py`. Each had only checked
   "does this tenant exist?" via `_tenant_or_404`, never "does this
   tenant belong to the JWT's user?". Closed by a new helper
   `assert_tenant_matches_user(tenant_id, current_user)` that does a
   pure JWT-vs-URL compare (no DB hit).
2. **ID-based routes** — 48 routes that resolve a non-entity
   resource directly by primary key (PO, PI, JE, Customer, Vendor,
   Product, Branch, Warehouse, Attachment, GosiRegistration,
   WpsBatch, PosTransaction, …). Each had only checked "does this
   row exist?". Closed by a new generic helper
   `assert_resource_in_tenant(db, Model, resource_id, current_user)`
   that defaults to reading the `tenant_id` column off the loaded
   row. ~95% of pilot tables carry `tenant_id` directly, so the
   helper is one-line for most routes; the few that don't (e.g.,
   `ProductAttributeValue`, scoped via `attribute_id → ProductAttribute.tenant_id`)
   pass a `tenant_resolver` callback.

29 parameterized matrix tests + 4 dedicated tests.

---

## Coverage matrix — by route file

| File | Audit 1 (G-TB) | Audit 2 (entity_id) | Audit 3 (tenant_id + ID) | Total |
|---|---:|---:|---:|---:|
| `gl_routes.py` | 1 | 4 | 7 | 12 |
| `pilot_routes.py` | 0 | 5 | 27 (22 tenant + 5 ID) | 32 |
| `compliance_routes.py` | 0 | 11 | 3 | 14 |
| `purchasing_routes.py` | 0 | 6 | 12 (2 tenant + 10 ID) | 18 |
| `customer_routes.py` | 0 | 1 | 7 (2 tenant + 5 ID) | 8 |
| `catalog_routes.py` | 0 | 0 | 23 (9 tenant + 14 ID) | 23 |
| `attachment_routes.py` | 0 | 0 | 4 | 4 |
| `pos_routes.py` | 0 | 0 | 2 | 2 |
| `pricing_routes.py` | 0 | 0 | 2 | 2 |
| `ai_routes.py` + `ai_je_routes.py` | 0 | 5 | 0 | 5 |
| **Total** | **1** | **32** | **85** | **117** |

---

## Anti-enumeration design (constant across all three helpers)

All three helpers share the same response contract on rejection:

- **HTTP 404** with body `{"detail": "Entity not found"}` (entity
  helper) or `{"detail": "Resource not found"}` (other two helpers).
- **Identical** body whether the id is missing or cross-tenant —
  so an attacker iterating UUIDs cannot distinguish "exists in
  another tenant" from "doesn't exist."
- **Server-side log line** with the `TENANT_GUARD_VIOLATION` prefix
  + structured fields (`user_id`, `user_tenant`, target id, target
  tenant, model name where applicable). SOC dashboards key on the
  prefix; a spike means probing.

The 403 contract from Audit 1 was migrated to 404 in Audit 2; the
prior PR's tests were updated accordingly. All 11 prior cases still
pass under the 404 contract.

---

## Test coverage

| Suite | Cases | Audit |
|---|---:|---|
| `tests/test_tb_real_data_flow.py` | 11 | Audit 1 |
| `tests/test_pilot_tenant_isolation_full.py` | 28 + 2 dedicated | Audit 2 |
| `tests/test_pilot_tenant_isolation_v2.py` | 29 + 4 dedicated | Audit 3 (this PR) |
| **Total** | **74 cases** | |

All three suites run on a single SQLite test DB via the existing
FastAPI `client` fixture and JWT minting via `create_access_token`.
Each parameterized row asserts three things: own-tenant passes the
guard, cross-tenant returns 404 + generic body, missing-id returns
404 + generic body.

Final regression sweep (this PR + Audit 1+2 + adjacent compliance/
reports/dimensions/AI suites): **176 / 176 pass.**

---

## Helpers reference

```python
from app.pilot.security import (
    assert_entity_in_tenant,        # Audit 2
    assert_tenant_matches_user,     # Audit 3
    assert_resource_in_tenant,      # Audit 3
)
```

Decision table:

| Route shape | Helper |
|---|---|
| `entity_id` in path or payload | `assert_entity_in_tenant(db, entity_id, current_user)` |
| `tenant_id` in path | `assert_tenant_matches_user(tenant_id, current_user)` |
| Resource id in path (PO, PI, JE, Customer, Vendor, Product, Branch, …) | `assert_resource_in_tenant(db, Model, resource_id, current_user)` |

Full pattern doc: `docs/PILOT_TENANT_GUARD_PATTERN.md`.

---

## Production monitoring

After deploy, tail the production log shipper for the prefix:

```
TENANT_GUARD_VIOLATION
```

Both helper variants emit the line with structured key=value fields:

```
TENANT_GUARD_VIOLATION user_id=<sub> user_tenant=<jwt_tenant>
  requested_entity=<eid> entity_tenant=<actual>
TENANT_GUARD_VIOLATION user_id=<sub> user_tenant=<jwt_tenant>
  requested_tenant=<url_tenant>
TENANT_GUARD_VIOLATION user_id=<sub> user_tenant=<jwt_tenant>
  model=<ClassName> resource_id=<id> resource_tenant=<actual>
```

Recommended alert: rate ≥ 10 / minute from a single `user_id` over a
10-minute window typically indicates either (a) a malicious user
iterating UUIDs to probe existence, or (b) a buggy frontend that
lost the selected-entity context. Either way, worth a look.

The line is at WARNING level; INFO is enough to capture it
(structured logging shippers usually ship WARNING+).

---

## Open items

None for the pilot route surface.

Out-of-scope (different layer, separate ticket if/when needed):

- **DB-layer RLS** — the pilot tables still have no Postgres RLS
  policies. Today the application-layer helpers are the only
  enforcement. RLS rollout is tracked as `G-RLS-MIGRATION` and must
  follow the table-by-table staging pattern in CLAUDE.md G-A3.1 —
  never enable in bulk on production startup.
- **Phase1 routes** (auth, account, admin) — different surface, used
  to be the only auth-handling code; not part of this audit.
- **Catalog tenant route bodies** that internally do `db.query(...filter(tenant_id==...)).first()`
  with a payload-supplied `tenant_id` — already covered by the new
  helper, but if a future route shape adds a third tenant_id source
  (cookie? header?), it would need its own gate.
