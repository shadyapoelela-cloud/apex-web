# Pilot Tenant Guard Pattern

**Status:** in force as of 2026-05-08 (G-PILOT-REPORTS-TENANT-AUDIT).
**Helper:** `app.pilot.security.assert_entity_in_tenant`.

This is the canonical pattern every pilot route uses to enforce
tenant isolation. New pilot routes that resolve an entity by id
**must** follow it.

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

## When NOT to use the helper

There are three categories of pilot endpoints that don't need it:

1. **Endpoints that don't touch an entity at all.** Health checks
   (`/ai/health`, `/gosi/rates`), pure calculators
   (`/gosi/calculate`, `/uae-ct/calculate`), QR decoders
   (`/zatca/decode-qr`).
2. **Endpoints that resolve a different anchor.** A path like
   `/purchase-orders/{po_id}` resolves a PO directly — it doesn't take
   an entity id. These endpoints have their own gap (cross-tenant by
   PO id) and need a sibling helper, not this one. Tracked as
   `G-PILOT-PO-PI-TENANT-AUDIT`.
3. **Internal callers without a JWT context.** Worker scripts,
   migration code, system-generated postings. Pass `current_user=None`
   explicitly; the helper will skip the tenant check. **Never** ship
   this in a public route.

---

## When you add a new pilot route

Mental checklist:

- [ ] Does the route accept an `entity_id` (path or payload)?
  → Yes: helper required.
- [ ] Add `current_user: dict = Depends(get_current_user)` to the
      handler signature.
- [ ] First line of the body: `assert_entity_in_tenant(db, entity_id, current_user)`.
- [ ] Add a row to `tests/test_pilot_tenant_isolation_full.py`'s
      `ROUTE_MATRIX` (or `PAYLOAD_ROUTE_MATRIX`) so the matrix tests
      cover it on the next CI run.

The matrix test runs four assertions per row:

1. user A → entity A → not rejected by tenant guard
2. user A → entity B → 404 + "Entity not found"
3. user A → never-existed-uuid → 404 + "Entity not found"
4. user B → entity B → 200 (in the dedicated symmetric test)

---

## History (closure log)

| Date | Ticket | Scope |
|---|---|---|
| 2026-05-08 | G-TB-REAL-DATA-AUDIT (PR #174) | Discovered the gap. Fixed in `gl_routes.py` only — local helper, 403 cross-tenant. Tests: 11 cases. |
| 2026-05-08 | G-PILOT-REPORTS-TENANT-AUDIT (this PR) | Extracted helper to `app/pilot/security/tenant_guards.py`; rolled out to all 32 vulnerable pilot routes; switched to **404 anti-enumeration**; added structured violation logging; 28 parameterized matrix tests. |

Open follow-ups (not closed by this PR):

- **`G-PILOT-CATALOG-TENANT-AUDIT`** — `catalog_routes.py` exposes
  ~20 routes shaped `/tenants/{tenant_id}/...` that take `tenant_id`
  straight from the URL. Same problem class, different shape — needs
  a sibling helper `assert_tenant_matches_user`.
- **`G-PILOT-PO-PI-TENANT-AUDIT`** — endpoints that resolve a PO /
  PI / payment / sales-invoice directly by id (`/purchase-orders/{po_id}`,
  `/sales-invoices/{id}`, etc.) bypass entity resolution and are
  cross-tenant readable today.
