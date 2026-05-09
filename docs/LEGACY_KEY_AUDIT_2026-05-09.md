# Legacy / Pilot Key Drift Audit + Hotfix

**Status:** in force as of 2026-05-09 (G-LEGACY-KEY-AUDIT).
**Closes:** the legacy/pilot localStorage key drift between
`apex_tenant_id` (legacy) and `pilot.tenant_id` (canonical).

---

## TL;DR

The frontend has been carrying two keys for the same value:

| Key | Origin | Used by |
|---|---|---|
| `apex_tenant_id` | The original `S` session (pre-pilot) | 20+ screens that still call `S.tenantId` / `S.savedTenantId` |
| `pilot.tenant_id` | The newer `PilotSession` (post-PR-#176) | Wizard, ERP-unification banner, every pilot route |

Three call sites wrote one key without writing the other:

1. **`S.setActiveScope`** wrote only `apex_tenant_id` directly via
   `localStorage[…] = …`, bypassing the dual-key sync that
   `PilotSession.tenantId`'s setter does.
2. **`S.clear`** removed only `apex_tenant_id` and left
   `pilot.tenant_id` dirty — the next user logging in on the same
   browser inherited the previous user's `tenantId`, silently
   bypassing tenant-isolation guards on every pilot route.
3. **`S.savedTenantId`** read only `apex_tenant_id`, blind to any
   value that was written exclusively to `pilot.tenant_id` (e.g.
   from `PilotSession.tenantId = …` set by an ERR-2-aware register
   flow before this fix layered the dual-key sync on top).

The hotfix consolidates writes under `PilotSession.tenantId`'s
setter, makes `S.savedTenantId` fall back through both keys, makes
`S.clear()` call `PilotSession.clear()`, and adds a one-shot
migration helper that reconciles drift on first read.

---

## Audit table — all writers and readers

### Writers (pre-fix)

| File | Line | What it did | Status |
|---|---|---|---|
| `lib/core/session.dart` | 41 | `localStorage['apex_tenant_id'] = tenant` directly in `setActiveScope` | ✅ replaced — now `PilotSession.tenantId = tenant` |
| `lib/pilot/session.dart` | setter | `_set(_tenantKey, v); _set(_legacyTenantKey, v);` (already correct) | ✅ kept — the canonical entry point |
| `lib/providers/app_providers.dart` | login/register | `PilotSession.tenantId = tenantId` (G-AUTH-TENANT-PERSIST, PR #182) | ✅ kept |
| `lib/screens/auth/*.dart` | _go / _login | `PilotSession.tenantId = tenantId` (G-AUTH-TENANT-PERSIST, PR #182) | ✅ kept |

After the fix there is exactly **one** writer of `pilot.tenant_id`
and `apex_tenant_id`: `PilotSession.tenantId`'s setter
(`lib/pilot/session.dart:92-96`). Every other call site goes through
it.

### Readers

| Reader | Reads via | Status |
|---|---|---|
| `S.tenantId` (in-memory, written by `S.setActiveScope`) | direct field | ✅ unchanged — fed by setter that now syncs both keys |
| `S.savedTenantId` | localStorage | ✅ now falls back: `pilot.tenant_id` → `apex_tenant_id` |
| `S.savedEntityId` | localStorage | ✅ now falls back: `pilot.entity_id` → `apex_entity_id` |
| `PilotSession.tenantId` | localStorage `pilot.tenant_id` | ✅ canonical; triggers `migrateLegacyKey()` lazily on first read |
| 20+ screens calling `S.tenantId` | indirect via `S` | ✅ unchanged — `S.tenantId` is fed by `setActiveScope` which now writes through `PilotSession` |

### 401 / logout sequence

| Call site | Path | Status |
|---|---|---|
| `lib/api_service.dart:51` (`_SessionExpiryHandler.handle`) | `S.clear()` | ✅ now wipes pilot.* via `S.clear()` → `PilotSession.clear()` |
| `lib/providers/app_providers.dart::logout()` | `S.clear()` then `PilotSession.clear()` (PR #182) | ✅ kept; the second call is redundant but cheap and serves as institutional memory |

---

## The drift scenarios the migration helper handles

`PilotSession.migrateLegacyKey()` runs once per session, lazily on
the first read of `PilotSession.tenantId`. Three scenarios:

```
        ┌─ pilot.tenant_id ─┐
        │                   │
   set ─┤ legacy === pilot  → no-op
        │                   │
        │ legacy !== pilot  → trust pilot
        │                     localStorage[apex_tenant_id] = pilot
        │                     console.warn drift detected
        │                   │
        │ legacy only       → migrate up
        │ (pilot null)        localStorage[pilot.tenant_id] = legacy
        │                   │
        │ both null         → no-op (fresh / logged-out)
        │                   │
        └───────────────────┘
```

The drift-detection branch logs to console (`[APEX][G-LEGACY-KEY-AUDIT]`)
so the situation is visible during pre-prod testing — drift means a
writer in the codebase is bypassing the canonical setter, and the
warn lets devs catch it before it gets to UAT.

The legacy-only branch handles a session from before the pilot keys
existed. Without this branch, `PilotSession.hasTenant` returned
`false` for those users → wizard fell into `createTenant` →
G-WIZARD-TENANT-FIX bug.

---

## Why a lazy + idempotent helper

The migration must run on every page load (not just on register or
login), because the drift can appear between sessions —
`localStorage` survives tab close, and a writer in an older bundle
could have set one key without the other.

Three options for *when* to run the helper:

1. **Eager init in `main.dart`** — adds a startup branch on every
   page load even when there's no drift. Couples session.dart to
   main.dart's init order.
2. **Lazy on first read of `tenantId`** — pays for itself only when
   someone reads. Decouples the helper from app startup. The first
   read is typically the wizard's `hasTenant` check or the
   API tenant_id injection — exactly when correctness matters.
3. **Eager in `PilotSession`'s static initializer** — Dart doesn't
   guarantee static init runs before any access, so this is a no-op
   in practice.

We chose **(2)**, with a `_legacyMigrated` flag to make it idempotent
within a session.

---

## The fix — three changes

### 1. `lib/pilot/session.dart` — add migration helper, lazy invocation

```dart
static bool _legacyMigrated = false;

static void migrateLegacyKey() {
  if (_legacyMigrated) return;
  _legacyMigrated = true;
  try {
    final pilot = html.window.localStorage[_tenantKey];
    final legacy = html.window.localStorage[_legacyTenantKey];

    if (pilot != null && pilot.isNotEmpty) {
      if (legacy != pilot) {
        html.window.localStorage[_legacyTenantKey] = pilot;
        if (legacy != null && legacy.isNotEmpty) {
          // ignore: avoid_print
          print(
            '[APEX][G-LEGACY-KEY-AUDIT] tenant_id drift detected '
            '(pilot=$pilot, legacy=$legacy). Synced legacy → pilot.',
          );
        }
      }
    } else if (legacy != null && legacy.isNotEmpty) {
      html.window.localStorage[_tenantKey] = legacy;
    }
  } catch (_) {/* localStorage unavailable */}
}

static String? get tenantId {
  if (!_legacyMigrated) migrateLegacyKey();
  return _get(_tenantKey);
}
```

### 2. `lib/core/session.dart` — route through PilotSession setter

```dart
// Before:
//   html.window.localStorage['apex_tenant_id'] = tenant;
//   html.window.localStorage['apex_entity_id'] = entity;

// After:
static void setActiveScope({required String tenant, required String entity}) {
  tenantId = tenant;
  entityId = entity;
  PilotSession.tenantId = tenant;  // setter writes BOTH keys
  PilotSession.entityId = entity;
}
```

### 3. `lib/core/session.dart` — make `S.clear()` symmetric

```dart
// Added at the end of S.clear():
PilotSession.clear();  // wipes both pilot.* AND legacy keys
```

`PilotSession.clear()` was already wiping all five keys
(`pilot.tenant_id`, `pilot.entity_id`, `pilot.branch_id`,
`apex_tenant_id`, `apex_entity_id`); we just hadn't been calling it
from `S.clear()`.

### 4. `lib/core/session.dart` — `savedTenantId` reader fallback

```dart
static String? get savedTenantId =>
    tenantId ??
    html.window.localStorage['pilot.tenant_id'] ??
    html.window.localStorage['apex_tenant_id'];
```

Pilot first (canonical), legacy second (pre-pilot fallback).

---

## Tests

`apex_finance/test/pilot/session_legacy_migration_test.dart` —
**8 source-grep tests** across two groups (widget tests blocked by
G-T1.1; source-grep pins the contract):

### `PilotSession setter / clear contract` (5 tests)
1. `test_setter_writes_both_keys` — pins `_set(_tenantKey, v)` AND
   `_set(_legacyTenantKey, v)` inside the setter.
2. `test_clear_wipes_both_keys` — pins all 5 key constants in the
   `clear()` body.
3. `test_drift_migration_on_load` — pins drift detection (`legacy != pilot`),
   sync direction (`legacy ← pilot`), and the console-warn marker.
4. `test_legacy_only_migration` — pins the legacy-only migrate-up branch
   and the `_legacyMigrated` idempotency guard.
5. `test_lazy_migration_on_first_read` — pins the `migrateLegacyKey()`
   call inside the `tenantId` getter and the `_legacyMigrated` guard.

### `S.clear / setActiveScope contract` (3 tests)
6. `test_logout_clears_pilot_session` — pins `PilotSession.clear()`
   call inside `S.clear()`.
7. `test_set_active_scope_routes_through_pilot_session` — pins both
   `PilotSession.tenantId = tenant` and `PilotSession.entityId = entity`
   inside `setActiveScope`.
8. `test_saved_tenant_id_falls_back_to_pilot_key` — pins both keys
   in the fallback chain AND that `pilot.tenant_id` comes first.

**8/8 pass.** Full regression sweep
(these 8 + provider auth + ERP-unification + financial statements +
TB + v5_routing + auth_guard + err_1): **85/85 pass**.

---

## Manual UAT path (6 steps)

1. **Open InPrivate / Incognito window.** Verify Local Storage is
   empty (`pilot.tenant_id` and `apex_tenant_id` both absent).
2. **Register a new user.** DevTools → Application → Local Storage.
   Expected: BOTH `pilot.tenant_id` AND `apex_tenant_id` present
   with the SAME UUID value.
3. **Logout via the user menu.** Local Storage → both keys gone.
4. **Register a second user (or switch tabs and login as B).**
   Expected: BOTH keys hold user B's tenantId. Neither carries any
   stale value from user A.
5. **Manually corrupt the legacy key:** in DevTools Local Storage,
   change `apex_tenant_id` to a bogus value (e.g.
   `00000000-0000-0000-0000-000000000000`).
6. **Reload the page.** Expected: console shows
   `[APEX][G-LEGACY-KEY-AUDIT] tenant_id drift detected (pilot=…, legacy=…). Synced legacy → pilot.`
   Local Storage shows both keys back in agreement, holding the
   correct (pilot) value. The wizard / ERP-unification banner /
   pilot routes all see the right tenantId.

If step 2 shows only one key: a writer in the auth chain is
bypassing `PilotSession.tenantId`'s setter — grep for direct
`localStorage[…]` writes touching either tenant key.

If step 6 shows no console-warn: the `migrateLegacyKey()` helper
isn't being invoked. Check that the `tenantId` getter still calls
`if (!_legacyMigrated) migrateLegacyKey();`.

---

## What we did NOT do (and why)

- **Did not touch the 20+ screens reading `S.tenantId` /
  `S.savedTenantId`.** The reader change in `savedTenantId`'s
  fallback chain handles them all transparently. Refactoring 20+
  screens to read `PilotSession.tenantId` directly is a separate
  ticket; this PR fixes the drift without reshaping reader
  architecture.
- **Did not delete the `apex_tenant_id` legacy key.** It's still
  read by code paths in `S.savedTenantId` for backward compatibility.
  Both keys stay in sync via `PilotSession.tenantId`'s setter; the
  legacy key is no longer a source of truth, just a mirror.
- **Did not eager-init the migration helper in `main.dart`.** Lazy
  on first read decouples session.dart from main.dart and runs at
  exactly the moment correctness matters. See "Why a lazy + idempotent
  helper" above.
- **Did not change the backend.** Zero changes. The drift is purely
  a frontend localStorage hygiene issue.

---

## References

- ERR-2 Phase 3 (PR #169) — backend auto-tenant + JWT claim.
- G-LEGACY-TENANT-MIGRATION (PR #170) — re-issued tokens for legacy
  users.
- G-PILOT-TENANT-AUDIT-FINAL (PR #176) — strict tenant isolation on
  every pilot route.
- G-WIZARD-TENANT-FIX (PR #180) — wizard's `hasTenant` branch.
- G-ERP-UNIFICATION (PR #181) — migration banner.
- **G-AUTH-TENANT-PERSIST (PR #182)** — persists `user.tenant_id`
  to `PilotSession` after login/register. The previous PR in this
  chain.
- `docs/AUTH_TENANT_PERSIST_2026-05-09.md` — the layer above this fix.
- `docs/PILOT_TENANT_GUARD_PATTERN.md` — canonical isolation pattern.
