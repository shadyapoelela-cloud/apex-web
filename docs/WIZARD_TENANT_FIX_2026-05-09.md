# Onboarding Wizard — Tenant Reuse Fix

**Status:** in force as of 2026-05-09 (G-WIZARD-TENANT-FIX).
**File:** `apex_finance/lib/pilot/screens/setup/pilot_onboarding_wizard.dart`
**Hotfix for:** G-PILOT-TENANT-AUDIT-FINAL (PR #176) regression in
the onboarding flow.

---

## Root cause — three independent decisions collided

The bug surfaces when a freshly-registered user opens the
onboarding wizard. Three previously-shipped decisions, each correct
in isolation, combined to break the flow:

### 1. ERR-2 Phase 3 (PR #169) — every user gets a tenant at registration
Auto-creates a `pilot_tenants` row in `auth_service.register()`,
owned via `Tenant.created_by_user_id`. The JWT carries the id in a
`tenant_id` claim added by `create_access_token(..., tenant_id=…)`.

**Result post-PR #169:** every freshly-registered user has a
JWT-bound tenant from day one.

### 2. G-PILOT-TENANT-AUDIT-FINAL (PR #176) — every pilot route enforces tenant isolation
`assert_tenant_matches_user(tenant_id, current_user)` is called on
every route shaped `/tenants/{tid}/...` and `assert_entity_in_tenant`
on every route taking `entity_id`. Cross-tenant probes return
**404 with the generic "Resource not found" body**
(anti-enumeration).

**Result post-PR #176:** *any* tenant id passed in a URL must match
the JWT's `tenant_id` claim.

### 3. The wizard always called `createTenant` in step 1
The wizard predates both PR #169 and PR #176. It was written when
users had no auto-tenant and explicitly created one as the first
onboarding step.

**Result, post-both-PRs:** step 1 creates a *second* tenant with a
different id; the JWT still holds the auto-created tenant from
registration; step 2 calls `/tenants/{new_id}/entities` →
`assert_tenant_matches_user(new_id, jwt)` → **404**. The
onboarding flow fails with "Entity not found" on what looks like
a valid tenant the user just created.

---

## The fix

In `_doStep1`, branch on `PilotSession.hasTenant`:

```dart
if (PilotSession.hasTenant) {
  // Update path. The JWT tenant exists from registration —
  // PATCH it instead of POSTing a new one.
  _tenantId = PilotSession.tenantId;
  final r = await _client.updateTenant(_tenantId!, { … });
  if (!r.success) throw r.error ?? 'فشل تحديث بيانات المستأجر';
} else {
  // Fallback: legacy user without a JWT tenant claim
  // (registered before ERR-2 Phase 3 / PR #169 and never got
  // migrated by G-LEGACY-TENANT-MIGRATION / PR #170).
  final r = await _client.createTenant({ … });
  if (!r.success) throw r.error ?? 'فشل إنشاء المستأجر';
  _tenantId = (r.data as Map)['id'];
  PilotSession.tenantId = _tenantId;
}
```

After this, **`_tenantId` always equals the JWT-bound tenant id**.
Step 2's `createEntity(_tenantId, ...)` routes to
`/tenants/{matching_tid}/entities` and the assert passes.

---

## Design decision — 1 user = 1 tenant

ERR-2 Phase 3 made an explicit choice: every registration creates
exactly one tenant. There is no "user without a tenant" state in
the post-PR-#169 system. The wizard's fix encodes that:

- **`hasTenant=true`** is the normal path. The wizard *configures*
  the existing tenant (fills in business details), it doesn't
  create a new container.
- **`hasTenant=false`** is the legacy fallback. Pre-PR-#169 users
  who never logged in again still need the wizard to work for them.
  After they hit the fallback once, `PilotSession.tenantId` is
  populated and subsequent visits go through the update path.

A user who genuinely needs *a second* tenant (separate company)
should register a separate account. Multi-tenant users with a
tenant-switcher are explicitly **out of scope** for this fix.

---

## Schema mismatch — immutable fields

`TenantUpdate` is more restrictive than `TenantCreate`:

| Field | Create | Update |
|---|---|---|
| `slug` | required | **not accepted** |
| `primary_email` | required | **not accepted** |
| `primary_country` | default 'SA' | **not accepted** |
| `legal_name_ar` | required | optional |
| `legal_name_en` | optional | optional |
| `trade_name` | optional | optional |
| `primary_cr_number` | optional | optional |
| `primary_vat_number` | optional | optional |
| `primary_phone` | optional | optional |
| `tier` | default 'starter' | optional |

`slug` is the URL-safe tenant id and must not change after creation
— external integrations may have linked to it. `primary_email`
was set to the registering user's address by ERR-2 Phase 3 and
shouldn't drift from the auth identity. `primary_country` is
structurally important (compliance routing depends on it; changing
mid-flight would orphan ZATCA / GOSI / etc. records).

The fix sends only the mutable fields in the PATCH path. Pydantic
v2's default behavior is to silently ignore extra fields, so even
if a future contributor accidentally adds `slug` to the update
payload it would be dropped — but being explicit here makes the
contract obvious.

---

## Tests

`apex_finance/test/pilot/screens/setup/pilot_onboarding_wizard_test.dart`
— 4 source-grep regression tests (widget tests blocked by G-T1.1
`session.dart → dart:html` SDK mismatch):

1. **`test_step1_uses_existing_tenant_when_session_has_tenant`** —
   pins the `if (PilotSession.hasTenant)` check, the
   `_tenantId = PilotSession.tenantId` assignment, and the
   `_client.updateTenant(_tenantId!, …)` call.
2. **`test_step1_creates_new_tenant_when_no_session_tenant`** —
   pins the `else` fallback retains `_client.createTenant(…)` and
   sets `PilotSession.tenantId = _tenantId` after.
3. **`test_step2_uses_correct_tenant_id_after_step1`** — pins step
   2 still uses `_tenantId` (set in step 1) and that the
   update-branch assignment happens *before* the API call so a
   failed PATCH still leaves `_tenantId` pointing at the JWT tenant.
4. **`test_marker_comment_preserved_for_future_archaeology`** —
   the `G-WIZARD-TENANT-FIX` marker comment in `_doStep1` documents
   the ERR-2 → audit-final → this-fix chain. Removing the marker
   would let a future "simplification" rip the branching out
   without realizing it's load-bearing.

---

## Manual UAT

1. Register a fresh user (any email, any password) on `/register`.
2. Login. JWT now carries `tenant_id` (decode at jwt.io to verify;
   it's a UUID, not empty).
3. Open `/app/erp/finance/onboarding`.
4. **Step 1:** fill the slug + Arabic name + email. Click Continue.
   - Network call should be **PATCH /pilot/tenants/{tid}** (not
     POST /pilot/tenants). DevTools → Network → filter "tenant".
   - Response: 200 with the updated tenant body.
5. **Step 2:** add an entity. Click Continue.
   - Network call: **POST /pilot/tenants/{tid}/entities**
     (same `tid` as step 1's PATCH).
   - Response: 201 with the new entity. **No 404.**
6. **Step 3+:** complete the rest of the wizard (branches, etc.).
7. Open `/app/erp/finance/balance-sheet`. Should render with no
   data (genuine empty state) and the green-dot "بيانات حقيقية"
   footer. **No "Resource not found" error.**

If step 4 returns 404 — the fix didn't apply or the JWT doesn't
carry `tenant_id`. Check the JWT payload at jwt.io.

---

## Sibling regressions to watch for

The same anti-pattern (create-when-update-needed) might exist in
other onboarding-style flows. None spotted in this audit, but
worth a periodic re-grep. A canary signal: any
`createX` call in a wizard step that doesn't first check
`hasX` — if the JWT carries an `X_id`, that flow has the same
bug shape.

---

## References

- ERR-2 Phase 3 (PR #169) — auto-tenant at registration.
- G-LEGACY-TENANT-MIGRATION (PR #170) — re-issued tokens for legacy users.
- G-PILOT-TENANT-AUDIT-FINAL (PR #176) — `assert_tenant_matches_user`
  on every pilot route.
- `docs/PILOT_TENANT_GUARD_PATTERN.md` — the canonical pattern.
- `apex_finance/lib/pilot/api/pilot_client.dart::updateTenant` —
  the existing PATCH client method (line 136).
- `app/pilot/routes/pilot_routes.py::update_tenant` — the route
  (line 242), gated by `assert_tenant_matches_user`.
- `app/pilot/schemas/tenant.py::TenantUpdate` — the restricted
  update schema (line 46).
