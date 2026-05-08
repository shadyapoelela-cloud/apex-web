# Pilot Tenant Guard Pattern

**Status:** in force as of 2026-05-08 (G-PILOT-TENANT-AUDIT-FINAL).
**Helpers:** `app.pilot.security.{assert_entity_in_tenant,
assert_tenant_matches_user, assert_resource_in_tenant}`.

This is the canonical pattern every pilot route uses to enforce
tenant isolation. **Three helpers, one per route shape** — the
decision table below picks the right one.

## Three patterns — decision table

| Route shape | Example URL | Helper | Notes |
|---|---|---|---|
| `entity_id` in path or payload | `/pilot/entities/{eid}/reports/balance-sheet`, `POST /pilot/purchase-orders` (`payload.entity_id`) | `assert_entity_in_tenant(db, entity_id, current_user)` | Loads the Entity, checks `entity.tenant_id == JWT.tenant_id`. Returns the Entity. |
| `tenant_id` in path | `/pilot/tenants/{tid}/products`, `/pilot/tenants/{tid}/members/{uid}` | `assert_tenant_matches_user(tenant_id, current_user)` | Pure JWT-vs-URL compare. No DB hit. Returns the validated tenant id. |
| Resource id in path (PO, PI, JE, Customer, Vendor, Product, Branch, …) | `/pilot/purchase-orders/{po_id}`, `/pilot/customers/{id}`, `/pilot/branches/{id}` | `assert_resource_in_tenant(db, Model, resource_id, current_user)` | Generic. Default reads `tenant_id` column off the loaded row (works for ~95% of pilot tables). For models without a tenant column (e.g., `ProductAttributeValue`), pass a `tenant_resolver` callback. |

All three return the same anti-enumeration shape on rejection: HTTP
**404** with the generic ``"Entity not found"`` / ``"Resource not
found"`` body. The violation is recorded server-side via
`logger.warning("TENANT_GUARD_VIOLATION ...")`.

---

## Why this exists

The platform has a global SQLAlchemy hook —
`attach_tenant_guard(engine)` in `app/main.py:686` — that injects
`WHERE tenant_id = :current_tenant` into every query against any
model inheriting from `app.core.tenant_mixin.TenantMixin`. That
covers the bulk of the schema (97 tables as of 2026-05-07; see
`docs/TENANT_TABLES_AUDIT_2026-05-07.md`).

**Pilot models bypass this.** `pilot_entities`, `pilot_journal_entries`,
`pilot_gl_postings`, `pilot_gl_accounts`, `pilot_fiscal_periods`,
`pilot_tenants`, and the rest of the pilot tables declare
`tenant_id` as a plain `Column(String(36))` — they do **not** inherit
`TenantMixin`. The hook never sees their compiles, so there's no
auto-filter. The protection has to live in the route handler.

Before G-PILOT-REPORTS-TENANT-AUDIT, no central helper existed and
each route file rolled its own `_entity_or_404` — which checked
`Entity.id == eid` only. **Result: 32 pilot routes were cross-tenant
readable / writable** (see the closure history below). All 32 are
fixed in this PR; the helper is now the only blessed way to resolve
an entity.

---

## The pattern

```python
from app.pilot.security import assert_entity_in_tenant

@router.get("/entities/{entity_id}/reports/balance-sheet")
def balance_sheet(
    entity_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    entity = assert_entity_in_tenant(db, entity_id, current_user)
    ...
```

Three things matter:

1. **`current_user` must be in the function signature.** Even though
   the router has `dependencies=[Depends(get_current_user)]` at the
   APIRouter level (which authenticates the request), that form does
   *not* expose the JWT payload to the handler. The function-level
   `Depends(get_current_user)` is the one that gives you the dict.
2. **Pass it through to the helper.** Never call the helper with
   `None` from a public route. `None` is for internal call-sites
   (worker scripts, migrations) only.
3. **Use the helper's return value.** Don't re-query the entity by id
   afterwards — that re-opens the gap. The helper has already loaded
   the row.

### Payload-shaped routes

Some routes (POST /purchase-orders, /vat-returns/generate, etc.) take
`entity_id` from the JSON body, not the URL. Same helper, same call:

```python
@router.post("/purchase-orders", response_model=PoDetail, status_code=201)
def create_po_endpoint(
    payload: PoCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    entity = assert_entity_in_tenant(db, payload.entity_id, current_user)
    ...
```

---

## Anti-enumeration: why 404, not 403

The helper returns **HTTP 404 with body `{"detail": "Entity not found"}`**
for **both** "id doesn't exist" and "id exists but belongs to another
tenant." Same status, same body.

Returning 403 on cross-tenant would leak existence — an attacker
iterating UUIDs would observe "403 → exists, 404 → doesn't exist"
and could enumerate every entity id in the database. Same body keeps
the two cases indistinguishable on the client side.

Server-side, the helper still records a structured warning log so
SOC dashboards can detect probing:

```
TENANT_GUARD_VIOLATION user_id=<sub> user_tenant=<jwt_tenant>
requested_entity=<eid> entity_tenant=<actual_tenant>
```

Tail this log line in production. A spike of these usually means a
malicious user iterating ids, or a buggy frontend that lost the
selected-entity context.

History note: G-TB-REAL-DATA-AUDIT (PR #174) used 403 in its initial
fix. G-PILOT-REPORTS-TENANT-AUDIT migrated to 404. The
`tests/test_tb_real_data_flow.py` cross-tenant assertions were
updated accordingly.

---

## Backward-compat shims

To keep the diff small in this PR, each route file's old
`_entity_or_404` helper was kept as a thin shim that delegates to
`assert_entity_in_tenant`. That means existing call-sites continued
to work without churn while we fixed the dozens of route signatures.
**New code should call `assert_entity_in_tenant` directly** —
treat the shims as deprecated.

---

## When NOT to use any of the helpers

Two narrow categories:

1. **Endpoints that don't touch tenant-scoped data.** Health checks
   (`/ai/health`, `/gosi/rates`), pure calculators
   (`/gosi/calculate`, `/uae-ct/calculate`), QR decoders
   (`/zatca/decode-qr`).
2. **Internal callers without a JWT context.** Worker scripts,
   migration code, system-generated postings. Pass `current_user=None`
   explicitly; `assert_entity_in_tenant` and
   `assert_resource_in_tenant` will then raise 404 (defensive).
   **Never** ship that pattern in a public route.

---

## When you add a new pilot route

Mental checklist:

1. **Does the route take a `tenant_id` in the URL?**
   → `assert_tenant_matches_user(tenant_id, current_user)` first thing in the body.
2. **Does it take an `entity_id` (path or payload)?**
   → `assert_entity_in_tenant(db, entity_id, current_user)`.
3. **Does it resolve a non-entity resource by id (PO, PI, JE,
   Customer, Vendor, Product, Branch, …)?**
   → `assert_resource_in_tenant(db, Model, resource_id, current_user)`.
   For a model without a `tenant_id` column, pass a `tenant_resolver`
   callback (`ProductAttributeValue` is the example case).

For all three:

- [ ] Add `current_user: dict = Depends(get_current_user)` to the
      handler signature (the router-level `dependencies=[...]` only
      authenticates — it doesn't expose the JWT to the body).
- [ ] First line of the body: the helper call.
- [ ] Add a row to the appropriate matrix in
      `tests/test_pilot_tenant_isolation_full.py` (entity_id) or
      `tests/test_pilot_tenant_isolation_v2.py` (tenant_id /
      resource_id).

The matrix tests run three assertions per row: own-tenant passes the
guard, cross-tenant → 404 + generic body, missing-id → 404 + generic
body. Symmetric coverage (user B reads their own resource) lives in
the dedicated tests.

---

## History (closure log)

| Date | Ticket | Routes closed | Cumulative |
|---|---|---|---|
| 2026-05-08 | G-TB-REAL-DATA-AUDIT (PR #174) | 1 (TB only) | 1 |
| 2026-05-08 | G-PILOT-REPORTS-TENANT-AUDIT (PR #175) | 32 (entity_id-shaped) | 33 |
| 2026-05-08 | G-PILOT-TENANT-AUDIT-FINAL (this PR) | 85 (37 tenant_id + 48 id-based) | **118** |

Open follow-ups (not closed by this PR):

- **`G-PILOT-CATALOG-TENANT-AUDIT`** — `catalog_routes.py` exposes
  ~20 routes shaped `/tenants/{tenant_id}/...` that take `tenant_id`
  straight from the URL. Same problem class, different shape — needs
  a sibling helper `assert_tenant_matches_user`. **Closed in
  G-PILOT-TENANT-AUDIT-FINAL.**
- **`G-PILOT-PO-PI-TENANT-AUDIT`** — endpoints that resolve a PO /
  PI / payment / sales-invoice directly by id (`/purchase-orders/{po_id}`,
  `/sales-invoices/{id}`, etc.). **Closed in
  G-PILOT-TENANT-AUDIT-FINAL** via `assert_resource_in_tenant`.

The pilot route surface is now considered fully covered for tenant
isolation. **Issue #3 (Multi-Tenancy Isolation) is fully closed
across 117 routes.**
