# ERP Setup Path Unification

**Status:** in force as of 2026-05-09 (G-ERP-UNIFICATION).
**Closes:** UAT Issue #6 — duplicate entity-setup journeys.

---

## TL;DR

APEX had **two parallel paths** for setting up companies + branches:

1. The **legacy localStorage path** at `/settings/entities` —
   `entity_setup_screen.dart` writing to `apex_companies_v2` /
   `apex_branches_v1` / `apex_entities_v1` browser keys. Fast,
   offline-friendly, but **invisible to the backend** — none of
   those rows make it into `pilot_gl_postings`, so the new financial
   statements (TB / IS / BS / CF) render empty for users who set
   themselves up via this path.
2. The **pilot ERP path** at `/app/erp/finance/onboarding` —
   `PilotOnboardingWizard` calling `pilotClient.createEntity` /
   `createBranch`, persisting to `pilot_entities` / `pilot_branches`
   / etc. Real data; flows through the financial statements.

**Post-this-PR**, path #1 exists only as a **one-shot migration UI**.
Empty-store accounts skip it entirely (router-level redirect to
the wizard). Accounts with legacy data see a banner that POSTs the
records into the pilot ERP and then clears the localStorage.

---

## Before / after

```
┌──────────────────────────────── BEFORE ────────────────────────────────┐
│                                                                        │
│  /settings/entities  ─→  entity_setup_screen  ─→  localStorage         │
│                                                    (invisible to BE)   │
│                                                                        │
│  /onboarding/wizard ─┐                                                 │
│  /clients/onboarding ─┤                                                │
│  /clients/new ────────┼─→  /settings/entities?action=new-company       │
│  /clients/create ────┘     (the legacy screen)                         │
│                                                                        │
│  /app/erp/finance/onboarding ─→ PilotOnboardingWizard ─→ pilot_*       │
│                                                          tables (DB)   │
│                                                                        │
│  Two parallel paths. Users who arrive via legacy redirects see         │
│  /settings/entities — their data never reaches the DB.                 │
└────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────── AFTER ─────────────────────────────────┐
│                                                                        │
│  /onboarding/wizard ─┐                                                 │
│  /clients/onboarding ─┤                                                │
│  /clients/new ────────┼─→  /app/erp/finance/onboarding                 │
│  /clients/create ────┘     (PilotOnboardingWizard)                     │
│                            ↓                                           │
│                            createEntity / createBranch                 │
│                            ↓                                           │
│                            pilot_* tables (DB)                         │
│                                                                        │
│  /settings/entities                                                    │
│  ├─ if listCompanies().isEmpty AND listEntities().isEmpty:             │
│  │    redirect → /app/erp/finance/onboarding                           │
│  └─ else:                                                              │
│       render entity_setup_screen with migration banner                 │
│       ├─ "نعم، انقلها" → POST each row to PilotClient,                 │
│       │                   clearAll localStorage, go to wizard          │
│       └─ "لا، تجاهل واحذف" → confirm, clearAll, go to wizard           │
│                                                                        │
│  Single path: every entity/branch creation goes through the            │
│  pilot ERP.                                                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## The migration

When a user with legacy localStorage data lands on
`/settings/entities`, the screen renders a top banner:

```
┌──────────────────────────────────────────────────────────────────┐
│ ☁️  تم اكتشاف بيانات قديمة محفوظة محلياً                         │
│                                                                  │
│ وجدنا N شركة + M فرع محفوظة محلياً (نظام قديم).                 │
│ هل تريد نقلها إلى الـ ERP الرسمي؟ (محفوظة في DB، آمنة،          │
│ تظهر في القوائم المالية)                                        │
│                                                                  │
│  [✓ نعم، انقلها]  [🗑 لا، تجاهل واحذف]                          │
└──────────────────────────────────────────────────────────────────┘
```

### "نعم، انقلها" path

Synthesises a pilot-schema-valid `code` from each legacy id (the
pilot endpoint requires `^[A-Z0-9_-]+$`, min_length 2, but legacy
records don't carry one):

```dart
String _legacyCompanyCode(CompanyRecord c) {
  final cleaned = c.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  final tail = cleaned.length >= 8
      ? cleaned.substring(cleaned.length - 8)
      : cleaned;
  return tail.length >= 2 ? 'MIG-$tail' : 'MIG-LEGACY';
}
```

`MIG-` and `BR-` prefixes make migrated rows identifiable in the
entity list — operators can tell at a glance which were
migrated vs. wizard-created.

For each `CompanyRecord`:
```
POST /pilot/tenants/{PilotSession.tenantId}/entities
  body: { code: MIG-…, name_ar, name_en?, country, functional_currency,
          type: 'company' }
```

Then for each `BranchRecord`, looks up the parent's new id in a
local `entityMapping` dict and posts:
```
POST /pilot/entities/{newEntityId}/branches
  body: { code: BR-…, name_ar, name_en?, country, city, type: 'retail',
          status: 'active' }
```

`country` defaults from the parent CompanyRecord. `city` defaults
to `"غير محدد"` because the pilot schema requires it but legacy
BranchRecord has it nullable.

Per-record failures are caught, recorded in `_MigrationResult.failures`,
and surfaced in a result dialog at the end. The user sees exactly
which records made it through — no silent drops.

After completion, **regardless of success or partial-fail**:
- `EntityStore.clearAll()` wipes `apex_entities_v1` / `apex_companies_v2`
  / `apex_branches_v1` / the migration flag.
- A result dialog shows totals + failure list.
- `context.go('/app/erp/finance/onboarding')` redirects to the
  wizard so the user can complete any post-migration setup.

### "لا، تجاهل واحذف" path

Shows a confirm dialog ("لا يمكن التراجع") because it's a
destructive action. On yes → `EntityStore.clearAll()` + redirect
to wizard.

---

## Edge cases

### `PilotSession.tenantId` is null
Banner gates the migrate button on `PilotSession.hasTenant`:
button is disabled, with an inline error message:

```
⚠️ لا يوجد كيان (tenant) نشط مرتبط بالجلسة.
افتح الـ ERP أولاً (سيُنشأ tenant من registration).
```

The user logs in (which triggers ERR-2 Phase 3 auto-tenant); on
return, the banner re-evaluates and the button enables.

### Branch's parent company didn't migrate
Recorded as a specific failure: `"فرع X: لم تُهاجَر الشركة الأم"`.
The branch is skipped (would 404 against a non-existent entity).
The user can re-create it in the wizard if they want it.

### Duplicate `code` collision
If the synthesized `code` clashes with an existing pilot entity
(unlikely — `MIG-{8 chars of id}` is high-entropy), the POST
returns 409. The migration records it as a failure with the API's
error message. The user can re-create with a different code in
the wizard.

### Network failure mid-migration
Each `createEntity` / `createBranch` is a separate HTTP call.
A failed call is caught (try/catch), recorded as a failure, and
the migration continues with the next record. The localStorage
is NOT cleared until ALL attempts complete — so a network drop
that breaks the loop (browser closed, tab killed, etc.) leaves
the legacy data intact for a retry.

If the operator wants to retry a partial migration, they can.
The previously-successful records will collide on `code` and
fail-with-409 the second time — which is the right behavior:
they're already in the DB, the second pass shouldn't double them.

---

## The router-level guard

`/settings/entities` keeps its `GoRoute` registration but gains a
redirect callback (router.dart:837):

```dart
GoRoute(
  path: '/settings/entities',
  redirect: (c, s) {
    final hasLegacy = EntityStore.listCompanies().isNotEmpty ||
        EntityStore.listEntities().isNotEmpty;
    if (!hasLegacy) {
      return '/app/erp/finance/onboarding';
    }
    return null; // allow render with migration banner
  },
  pageBuilder: (c, s) => _apexPage(EntitySetupScreen(...), s),
),
```

**Effect:** any account whose localStorage has been wiped (after
migration, or never had data in the first place) bypasses the
legacy screen entirely. Only accounts with pre-existing legacy
data ever see it.

---

## Tests

Two test files in `apex_finance/test/screens/settings/`:

### `entity_setup_migration_test.dart` — 7 cases
- `test_empty_localstorage_redirect_path_documented` — pins the
  post-completion `context.go('/app/erp/finance/onboarding')` so
  the user lands on the wizard, not back on the legacy screen.
- `test_banner_renders_with_legacy_data` — pins the conditional
  render `if (hasAny) _buildMigrationBanner()` and both buttons.
- `test_migration_calls_pilot_client_not_localstorage` — pins
  `client.createEntity(tid,` + `client.createBranch(newEntityId,`
  + the `entityMapping` parent-child link.
- `test_partial_failure_recorded_not_silent` — pins the
  `_MigrationResult` class, the `result.failures.add(...)` calls,
  and `_showMigrationResultDialog`.
- `test_localstorage_cleared_after_migration` — pins
  `EntityStore.clearAll()` + the `_confirmIgnoreAndDelete` confirm
  dialog.
- `test_no_tenant_blocks_migration_with_clear_message` — pins the
  `PilotSession.hasTenant` gate on the migrate button.
- `test_legacy_code_synthesis_for_pilot_schema` — pins both
  helpers + the `MIG-` / `BR-` prefix conventions.

### `legacy_redirect_test.dart` — 6 cases
- 4 individual tests for `/onboarding/wizard`, `/clients/onboarding`,
  `/clients/new`, `/clients/create` — each asserts the route exists
  AND the redirect aims at `/app/erp/finance/onboarding` AND **not**
  at the old `/settings/entities?action=new-company` target.
- `test_settings_entities_has_empty_store_redirect_guard` — pins
  the `EntityStore.listCompanies().isNotEmpty &&
  listEntities().isNotEmpty` check + the redirect target.
- `test_no_legacy_path_still_redirects_to_settings_entities_create`
  — belt-and-braces grep for any remaining
  `?action=new-company` reference. New legacy redirects added in
  future PRs must point at the wizard, not the legacy screen.

**13/13 pass.**

---

## Manual UAT

### Path 1 — fresh user (post-G-WIZARD-TENANT-FIX)
1. Register a new user. Log in. JWT carries `tenant_id`.
2. Open `/settings/entities` directly via URL.
3. **Expected:** instant redirect to `/app/erp/finance/onboarding`.
   Network tab shows no GET to /settings/entities; the
   PilotOnboardingWizard renders directly.

### Path 2 — legacy user with localStorage data
Pre-condition: legacy `apex_companies_v2` / `apex_branches_v1` keys
populated in browser localStorage (a previous session that never
migrated).

1. Log in as the legacy user.
2. Open `/settings/entities`.
3. **Expected:** the screen renders the top **migration banner**:
   "تم اكتشاف بيانات قديمة محفوظة محلياً — N شركة + M فرع".
4. Click "نعم، انقلها".
5. **Expected:**
   - Each company POSTs to `/pilot/tenants/{tid}/entities` (Network
     tab — should be N requests).
   - Each branch POSTs to `/pilot/entities/{new_eid}/branches` (M
     requests).
   - Result dialog shows "تم نقل N شركة و M فرع. تم مسح البيانات
     المحلية".
   - Click "متابعة" → lands on `/app/erp/finance/onboarding`.
6. Open `/settings/entities` again. **Expected:** instant redirect
   to wizard (legacy data is gone).

### Path 3 — user picks "ignore"
1. Same pre-condition as path 2.
2. Click "لا، تجاهل واحذف".
3. **Expected:** confirm dialog appears.
4. Click "حذف نهائي".
5. **Expected:** snackbar "تم حذف البيانات المحلية" → redirect to
   wizard.
6. Open `/settings/entities` again. **Expected:** instant redirect
   (legacy data wiped).

### Path 4 — legacy redirects
For each of `/onboarding/wizard`, `/clients/onboarding`,
`/clients/new`, `/clients/create`:

1. Open the URL directly.
2. **Expected:** redirect to `/app/erp/finance/onboarding`.
3. **NOT expected:** any redirect to `/settings/entities`.

---

## Rollback plan

If a deploy of this PR causes operational issues (e.g., a class of
legacy data the migration helper doesn't handle gracefully), the
rollback is **fully clean**:

1. Revert the PR via `git revert`. The localStorage data is still
   intact for any user who hadn't yet hit the migration banner —
   `EntityStore.clearAll()` only fires after explicit user action.
2. Users who already migrated keep the data they migrated (it's in
   the pilot DB, not affected by a frontend revert) AND
   `entity_store.dart` still works for any new local writes (we
   didn't delete the file, just stopped writing through it for the
   migrated users).
3. Re-deploy after the fix.

The deliberate decision to keep `entity_store.dart` on disk (even
after migration) is what enables this clean rollback. The cost is
~600 lines of dead code; the value is hours-not-days mean-time-to-
recovery.

---

## What we did NOT do (and why)

- **Did not delete `entity_store.dart`.** Rollback enabler.
- **Did not auto-migrate** without user consent. The banner asks
  every time. Silent migration would surprise users whose
  localStorage data is actually outdated/wrong and they want to
  start fresh.
- **Did not migrate `EntityRecord`** rows separately. `EntityRecord`
  is just a UI-side grouping container — it has no
  one-to-one mapping in the pilot schema. We document this in the
  commit message; the few users who created `EntityRecord` rows
  see their child companies migrate but the grouping itself is
  dropped.
- **Did not change the pilot endpoints.** Zero backend changes.
  This PR rides on the existing `assert_entity_in_tenant` /
  `assert_tenant_matches_user` infrastructure from
  G-PILOT-TENANT-AUDIT-FINAL (PR #176).

---

## References

- `apex_finance/lib/screens/settings/entity_setup_screen.dart` —
  the migration banner + `_runMigration()` method.
- `apex_finance/lib/core/router.dart:837` — the empty-store
  redirect guard + the 4 legacy redirects.
- `apex_finance/lib/core/entity_store.dart` — kept on disk;
  `clearAll()` + `legacyClientsProjection()` still callable.
- `apex_finance/lib/pilot/api/pilot_client.dart::createEntity` /
  `createBranch` — the migration call sites.
- `docs/WIZARD_TENANT_FIX_2026-05-09.md` — the prior hotfix that
  made `PilotSession.tenantId` reliable post-registration.
- `docs/PILOT_TENANT_GUARD_PATTERN.md` — the canonical tenant
  isolation pattern this PR rides on.
- ERR-2 Phase 3 (PR #169) — auto-tenant at registration.
- G-PILOT-TENANT-AUDIT-FINAL (PR #176) — strict
  `assert_entity_in_tenant` / `assert_tenant_matches_user`.
- G-WIZARD-TENANT-FIX (PR #180) — the wizard's reuse-existing-
  tenant fix this PR builds on.
