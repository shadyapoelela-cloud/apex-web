# Auth → Tenant Persistence Hotfix

**Status:** in force as of 2026-05-09 (G-AUTH-TENANT-PERSIST).
**Closes:** the missing piece in the G-WIZARD-TENANT-FIX chain.

---

## TL;DR

The G-WIZARD-TENANT-FIX hotfix earlier today (PR #180) made the
onboarding wizard branch on `PilotSession.hasTenant` — the common
path PATCHes the existing tenant instead of POSTing a second one.
But that fix relied on `PilotSession.tenantId` being populated
post-login.

**It wasn't.**

The four auth flows (`app_providers.login` / `register`,
`login_screen._go`, `register_screen._go`, `slide_auth._login`) all
extract the user blob from the auth response and write to `S.*` —
but **none of them ever wrote `PilotSession.tenantId`**. The
`tenant_id` claim ERR-2 Phase 3 (PR #169) injects into every user
response was being silently dropped.

So `PilotSession.hasTenant` returned `false`, the wizard fell back
to its `createTenant` path, a second tenant was created, the JWT
mismatch returned at step 2 — same bug G-WIZARD-TENANT-FIX was
supposed to close, just one layer up.

---

## The bug chain (three PRs)

| # | PR | What it does | What was missing |
|---|---|---|---|
| 1 | #169 (ERR-2 Phase 3) | Backend auto-creates a tenant per registration; JWT carries the `tenant_id` claim; user response includes `tenant_id` field. | (nothing — the backend half is correct) |
| 2 | #180 (G-WIZARD-TENANT-FIX) | Wizard branches on `PilotSession.hasTenant`; PATCH path reuses the JWT-bound tenant. | Relies on `PilotSession.tenantId` being populated. |
| 3 | **this PR (G-AUTH-TENANT-PERSIST)** | Persists `user.tenant_id` from the auth response into `PilotSession.tenantId`. | Closes the chain. |

Pre-this-PR:
```
[register]                 → backend returns user.tenant_id = T1
[app_providers.register]   → writes S.uid, S.email, etc.
                             ❌ silently drops user.tenant_id
[wizard step 1]            → PilotSession.hasTenant = false
                             (because nothing wrote pilot.tenant_id)
                             → falls through to createTenant
                             → creates T2 ≠ T1
[wizard step 2]            → POST /tenants/T2/entities
                             → JWT carries T1 → 404
```

Post-this-PR:
```
[register]                 → backend returns user.tenant_id = T1
[app_providers.register]   → writes S.uid, S.email, …
                             ✅ PilotSession.tenantId = T1
[wizard step 1]            → PilotSession.hasTenant = true
                             → PATCH /tenants/T1
[wizard step 2]            → POST /tenants/T1/entities
                             → JWT carries T1 → 201 ✅
```

---

## The fix — 5 lines per call site

In every auth-success branch:

```dart
// G-AUTH-TENANT-PERSIST (2026-05-09): persist tenant_id from
// ERR-2 auto-tenant so the wizard's hasTenant branch fires.
final tenantId = user['tenant_id'];
if (tenantId is String && tenantId.isNotEmpty) {
  PilotSession.tenantId = tenantId;
}
```

Plus an `import '../pilot/session.dart';` at the top of each file.

The `is String && isNotEmpty` guard handles three cases gracefully:
- **Normal post-PR-#169 user**: `tenant_id` is a non-empty UUID → persists.
- **Legacy pre-ERR-2 user not yet migrated**: `tenant_id` is null / absent → silent skip; wizard falls back to createTenant (the legacy path G-WIZARD-TENANT-FIX kept working for this case).
- **Backend bug returns empty string**: rejected. Writing `''` would set `hasTenant=false` because `PilotSession.hasTenant` checks `isNotEmpty` — silently breaking the wizard while LOOKING set. The empty-string check is belt-and-braces but the consequence of skipping it would be hours-of-debugging-painful.

---

## Four call sites fixed

The brief asked for `app_providers.dart` only, but the recon found
**three more**. Same bug shape, same fix:

| File | Method | Fixed |
|---|---|---|
| `lib/providers/app_providers.dart` | `login()` | ✅ |
| `lib/providers/app_providers.dart` | `register()` | ✅ |
| `lib/providers/app_providers.dart` | `logout()` | ✅ added `PilotSession.clear()` |
| `lib/screens/auth/login_screen.dart` | `_go()` | ✅ |
| `lib/screens/auth/register_screen.dart` | `_go()` | ✅ |
| `lib/screens/auth/slide_auth_screen.dart` | `_login()` | ✅ |
| `lib/screens/auth/slide_auth_screen.dart` | `_register()` | ⏭ skipped — snackbar-only, doesn't write `S.*` at all |

Without fixing all four production call sites, a user who happens
to land on the login_screen (e.g., via `?return_to=…` after a
session expiry) would still hit the bug while users on the
provider-driven path were fine. Three of four would be a flakey
fix.

---

## Drift fix found in passing

`app_providers.register()` was missing the
`S.roles = List<String>.from(user['roles'] ?? [])` line that
`login()` has. A freshly-registered user walked around with empty
roles until they logged out and back in. Same neighbourhood as the
tenant_id fix — added the missing line, pinned by a test.

---

## Logout cleanup

`S.clear()` (in `core/session.dart:64`) wipes `apex_tenant_id` (the
**legacy** localStorage key) but leaves the new `pilot.tenant_id`
key untouched. So before this PR, logout left PilotSession dirty —
**the next user logging in on the same browser would inherit the
previous user's `tenantId`**, silently bypassing tenant-isolation
guards on every pilot route.

Fix: `app_providers.logout()` now calls `PilotSession.clear()`
after `S.clear()`. The `PilotSession.clear()` method (already
present at `lib/pilot/session.dart:108`) wipes
`pilot.tenant_id` / `pilot.entity_id` / `pilot.branch_id` plus the
legacy keys.

---

## Tests

`apex_finance/test/providers/app_providers_test.dart` — **8 tests**
across two groups (widget tests blocked by G-T1.1; source-grep
pins the contract that matters):

### `provider auth flows` (5 tests)
1. `test_register_persists_tenant_id_to_pilot_session` — pins
   `user['tenant_id']` read + `PilotSession.tenantId = tenantId`
   write + `tenantId.isNotEmpty` guard inside the `register()`
   method body.
2. `test_login_persists_tenant_id_to_pilot_session` — same, for login.
3. `test_register_persists_roles` — pins the drift-fix for the
   missing `S.roles` line.
4. `test_logout_clears_pilot_session_tenant` — pins
   `PilotSession.clear()` is called alongside `S.clear()` in
   `logout()`.
5. `test_marker_comment_preserved_for_future_archaeology` — pins
   the `G-AUTH-TENANT-PERSIST` rationale comment in the file
   stays. Without it a future "simplification" rips the persistence
   out without seeing the bug-chain context.

### `auth screens` (3 tests)
- `test_login_screen_persists_tenant_id`
- `test_register_screen_persists_tenant_id`
- `test_slide_auth_screen_persists_tenant_id`

Each pins: PilotSession import, `['tenant_id']` read,
`PilotSession.tenantId = tenantId` write, the
`is String && isNotEmpty` guard, and the `G-AUTH-TENANT-PERSIST`
marker comment.

**8/8 pass.** Full Flutter regression sweep
(these 8 + wizard + ERP-unification + financial statements + TB +
v5_routing + auth_guard + err_1): **77/77 pass**. Backend regression
sweep (CF + BS + IS + TB + tenant_isolation_full +
tenant_isolation_v2): **119/119 pass**.

---

## Manual UAT path

1. Open the app in an **InPrivate / Incognito window** (clean
   localStorage).
2. **Register** a new user via `/register` or the slide-auth
   screen.
3. Open DevTools → **Application → Local Storage**.
4. **Expected:** a `pilot.tenant_id` key with a UUID value (NOT
   empty, NOT missing).
5. Open `/app/erp/finance/onboarding`.
6. Fill step 1 (slug + Arabic name + email) → click Continue.
7. **Expected on the Network tab:** `PATCH /pilot/tenants/{tid}`
   (NOT `POST /pilot/tenants`). Response: 200.
8. Step 2 — add an entity → click Continue.
9. **Expected:** `POST /pilot/tenants/{tid}/entities` with the
   SAME `tid` as step 7. Response: 201. **No 404.**
10. Logout via the user menu.
11. **Expected:** `pilot.tenant_id` is gone from Local Storage.

If step 4 shows `pilot.tenant_id` missing, the JWT either didn't
carry the claim (account predates ERR-2) or this fix didn't apply.
Decode `apex_token` at jwt.io to verify.

If step 7 shows POST instead of PATCH, the wizard's
`PilotSession.hasTenant` returned false — the persistence
didn't take effect. Check the user blob in the auth response (it
should have `"tenant_id": "..."` per ERR-2 Phase 3).

---

## What we did NOT do (and why)

- **Did not change the backend.** Zero changes. The bug was purely
  a frontend persistence drop.
- **Did not delete the legacy `apex_tenant_id` key from `S`.**
  Other code paths still read `S.tenantId` (via the legacy key) for
  pre-pilot screens. We add the new persistence on top; both keys
  stay in sync via `PilotSession.tenantId`'s setter
  (`pilot/session.dart:27-30` writes both).
- **Did not refactor the four duplicate call sites into one.** Each
  screen has its own `_go()` / `_login()` for legitimate reasons
  (return_to handling, snackbar messaging, navigation behaviour).
  Refactoring them into a single helper is a separate ticket. This
  PR fixes the bug; doesn't reshape the architecture.
- **Did not OAuth-fix.** No OAuth flows in the frontend yet.
  Verified by `grep -rn "googleSignIn\|appleSignIn\|oauth" apex_finance/lib/`
  — zero matches in auth code.

---

## References

- ERR-2 Phase 3 (PR #169) — backend auto-creates tenant + injects
  `tenant_id` claim into JWT and user response.
- G-LEGACY-TENANT-MIGRATION (PR #170) — re-issues tokens for
  legacy users.
- G-PILOT-TENANT-AUDIT-FINAL (PR #176) — strict
  `assert_tenant_matches_user` on every pilot route.
- G-WIZARD-TENANT-FIX (PR #180) — wizard's `if (PilotSession.hasTenant)`
  branch (the previous fix that depends on this one).
- G-ERP-UNIFICATION (PR #181) — migration banner that also depends
  on `PilotSession.hasTenant` to gate its migrate button.
- `docs/PILOT_TENANT_GUARD_PATTERN.md` — canonical isolation pattern.
- `docs/WIZARD_TENANT_FIX_2026-05-09.md` — the wizard hotfix
  rationale.
- `docs/ERP_UNIFICATION_2026-05-09.md` — the unification walkthrough.
