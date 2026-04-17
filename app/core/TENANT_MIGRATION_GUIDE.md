# Tenant Migration Pattern

> How to migrate a legacy (pre-tenant) table to multi-tenant isolation.

The app already ships a `TenantMixin` + query guard (see `tenant_guard.py`).
New tables (HR, AP Agent) inherit from it and are automatically isolated.

Legacy tables from Phases 1-11 don't use the mixin yet. Migrating them
requires three careful steps so production data isn't lost or leaked.

---

## The 3-step migration

### Step 1 — Make the model tenant-aware (non-breaking)

```python
# Before
class Client(Base):
    __tablename__ = "clients"
    id = Column(String(36), primary_key=True)
    name = Column(String, nullable=False)

# After
from app.core.tenant_guard import TenantMixin

class Client(Base, TenantMixin):   # ← add mixin
    __tablename__ = "clients"
    id = Column(String(36), primary_key=True)
    name = Column(String, nullable=False)
```

The mixin adds `tenant_id = Column(String(36), nullable=True, index=True)`.
Because it's nullable, existing rows keep working — they're treated as
"shared" until backfilled.

### Step 2 — Generate the Alembic migration

```bash
alembic revision --autogenerate -m "add tenant_id to clients"
```

Review the generated migration — it should contain ONLY:

```python
op.add_column("clients", sa.Column("tenant_id", sa.String(36), nullable=True))
op.create_index("ix_clients_tenant_id", "clients", ["tenant_id"])
```

Don't apply any other changes autogenerate suggests — those are drift
from unrelated models.

### Step 3 — Backfill + enforce (stepped rollout)

Do NOT flip strict mode globally. Instead:

1. **Deploy step 1+2 to production.** All new inserts pick up tenant_id
   from the ContextVar. Old rows stay NULL and remain visible to all.

2. **Backfill existing rows.** For each existing row, decide which tenant
   owns it (usually from `created_by_user.tenant_id`). Example:

   ```sql
   UPDATE clients c
   SET tenant_id = (
     SELECT u.tenant_id FROM users u WHERE u.id = c.owner_user_id
   )
   WHERE c.tenant_id IS NULL;
   ```

3. **Enforce NOT NULL (after the backfill).** Create a follow-up migration:

   ```python
   op.alter_column("clients", "tenant_id", nullable=False)
   ```

4. **Turn on TENANT_STRICT=true** for the deployment. The guard now
   rejects any query without a bound tenant.

---

## Critical tables in priority order

| Priority | Table | Why |
|----------|-------|-----|
| **P0** | users | Root identity; leak here cascades everywhere |
| **P0** | clients | PII (email, phone, name) |
| **P0** | user_sessions | Cross-tenant session hijack |
| **P0** | subscriptions | Billing data |
| **P1** | invoices, journal_entries | Financial data |
| **P1** | payments, payment_transactions | Money movement |
| **P1** | api_keys (if any) | Credential leak |
| **P2** | everything else (audit, notifications, ...) |

---

## Testing tenant isolation

Every migrated table needs a regression test in `tests/test_tenant_guard.py`
that follows the pattern in `test_tenant_a_cannot_see_tenant_b_rows`. No
exceptions — these tests are what stops cross-tenant leaks in CI.

```python
def test_clients_are_tenant_isolated():
    from app.core.tenant_context import set_tenant
    from app.core.tenant_guard import with_system_context
    from app.phase2.models.phase2_models import Client

    db = _new_session()
    with with_system_context():
        # Create rows for two tenants as system
        _make_client(db, "tenant-A", "Acme")
        _make_client(db, "tenant-B", "Beta")

    set_tenant("tenant-A")
    names = [c.name for c in db.query(Client).all()]
    assert "Acme" in names
    assert "Beta" not in names
```

---

## When NOT to use TenantMixin

Some tables are genuinely shared across all tenants:

- **Static reference data**: country codes, currency rates, IFRS standards
- **Application configuration**: feature flags, A/B tests (if not per-tenant)
- **System logs that never reference tenant data**

For these, leave them as-is. The guard is a no-op on non-mixin tables.

---

## Running the guard

Already wired at startup in `app/main.py`:

```python
from app.core.tenant_guard import attach_tenant_guard
from app.phase1.models.platform_models import engine as _tenant_engine
attach_tenant_guard(_tenant_engine)
```

Enable strict mode per environment:

```bash
export TENANT_STRICT=true   # production
```

Admin tools bypass with `with_system_context()`:

```python
from app.core.tenant_guard import with_system_context

with with_system_context():
    all_clients = db.query(Client).all()   # sees ALL tenants
```
