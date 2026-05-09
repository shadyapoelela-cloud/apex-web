# Wizard Stale State Hardening

**Status:** in force as of 2026-05-09 (G-WIZARD-STALE-STATE).
**Closes:** stale-state pollution & null-bang risk in the unified
onboarding wizard at `/app/erp/finance/onboarding`.

---

## TL;DR

The unified onboarding wizard had three gaps that survived
G-LEGACY-KEY-AUDIT (PR #183) because that PR fixed the localStorage
*drift* but didn't audit the wizard's *initialization*:

1. **No `initState()`** — `migrateLegacyKey()` ran transitively via
   the `PilotSession.hasTenant` getter on line 1086, but only at
   step 1's first read. Future code that bypassed the getter could
   leave drift unreconciled.
2. **`_tenantId` not hydrated from `PilotSession`** — the in-memory
   `String?` started null. A reload on step ≥ 2 wiped it; every
   `_tenantId!` bang in steps 3-8 then exploded with
   `Null check operator used on a null value` instead of gracefully
   re-reading the persisted tenant.
3. **No cleanup of orphan `entity_id`/`branch_id`** — by design every
   user has a tenant (ERR-2 Phase 3, PR #169). An entity_id without
   a tenant is pre-pilot residue; left in place it polluted other
   screens reading `PilotSession` during wizard use.

Plus four sub-bombs in the step bodies:
- `_doStep3` line `_createdEntityIds[b['_entity_code']]!` bombed
  on a reload.
- `_doStep4` line `_createdBranchIds[b['code']]!` same shape.
- `_doStep5` `_tenantId!` in `createCurrency` no upstream check.
- `_doStep6`/`_doStep7` silently no-op'd on empty entity map and
  the user thought CoA / fiscal periods had been seeded.

---

## The hardening — three lines + four guards

### 1. `initState()` — defensive init (3 lines that matter)

```dart
@override
void initState() {
  super.initState();

  // Explicit drift reconciliation — defensive even though the
  // tenantId getter calls this lazily.
  PilotSession.migrateLegacyKey();

  // Hydrate _tenantId from PilotSession so reload-on-step-≥2
  // doesn't null-bang on the next step.
  _tenantId = PilotSession.tenantId;

  // Cleanup orphan: entity without tenant is pre-pilot residue.
  if (!PilotSession.hasTenant && PilotSession.hasEntity) {
    PilotSession.clearEntityAndBranch();
  }
}
```

### 2. Null-safety guards in steps 3-7

```dart
// _doStep3 (branches)
if (_tenantId == null) throw 'المستأجر غير محدد — ارجع للخطوة 1';
if (_createdEntityIds.isEmpty) {
  throw 'أنشئ الكيانات أولاً (الخطوة 2) — تم فقد الحالة بعد إعادة التحميل';
}
// ... and the bang `_createdEntityIds[b['_entity_code']]!` becomes
// an explicit null-check throw with a translated, actionable message.

// _doStep4 (warehouses)
if (_tenantId == null) throw 'المستأجر غير محدد — ارجع للخطوة 1';
if (_createdBranchIds.isEmpty) {
  throw 'أنشئ الفروع أولاً (الخطوة 3) — تم فقد الحالة بعد إعادة التحميل';
}
// ... and the bang `_createdBranchIds[b['code']]!` becomes
// an explicit null-check throw.

// _doStep5 (currencies) — guards _tenantId before _tenantId! bang
if (_tenantId == null) throw 'المستأجر غير محدد — ارجع للخطوة 1';

// _doStep6 (CoA) — surfaces silent no-op as clear error
if (_createdEntityIds.isEmpty) {
  throw 'لا توجد كيانات لبذر شجرة الحسابات — أعد الخطوة 2';
}

// _doStep7 (fiscal periods) — same shape
if (_createdEntityIds.isEmpty) {
  throw 'لا توجد كيانات لبذر الفترات المحاسبية — أعد الخطوة 2';
}
```

---

## Audit table — initState callers of PilotSession.tenantId/entityId

The brief asked for a sweep of `getEntity()`/`getTenant()` callers
emitted from `initState`. There are no such methods — the wizard
codebase reads `PilotSession.tenantId` / `PilotSession.entityId`
getters directly. Sweep results:

| File | Caller in initState? | Risk |
|---|---|---|
| `lib/pilot/screens/setup/pilot_onboarding_wizard.dart` | ✅ NEW post-fix | drift reconciled + tenantId hydrated |
| `lib/pilot/services/entity_resolver.dart` | static helper, not called in initState | n/a |
| `lib/pilot/screens/setup/coa_editor_screen.dart` | reads in `initState` | unchanged — getter triggers `migrateLegacyKey` lazily, OK |
| `lib/pilot/screens/setup/products_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/je_builder_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/purchasing_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/stock_movements_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/members_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/financial_reports_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/company_settings_screen.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/advanced_settings_view.dart` | reads in `initState` | same |
| `lib/pilot/screens/setup/je_builder_live_v52.dart` | reads in `initState` | same |
| `lib/pilot/widgets/attachments_panel.dart` | reads in `initState` | same |

**All other initState callers are correct by transitivity** — the
`PilotSession.tenantId` getter (post-G-LEGACY-KEY-AUDIT) calls
`migrateLegacyKey()` lazily on first read. Any drift gets fixed
the moment the screen reads. The wizard is the only one that
makes a state-changing API call (PATCH/POST) on its first user
action — that's why it gets the explicit `migrateLegacyKey()` +
hydration + cleanup, while the rest stay on the lazy guarantee.

---

## Tests

`apex_finance/test/pilot/screens/setup/wizard_stale_state_test.dart`
— **8 source-grep tests** across three groups (widget tests blocked
by G-T1.1; source-grep pins each defensive shape):

### `initState contract` (3)
- `test_init_state_exists_and_calls_migrate_legacy_key`
- `test_init_state_hydrates_tenant_id_from_pilot_session`
- `test_init_state_clears_orphan_entity_id`

### `null-safety guards` (4)
- `test_step3_guards_tenant_id_and_empty_entity_map` — also pins
  the absence of the `_createdEntityIds[..]!` bang.
- `test_step4_guards_tenant_id_and_empty_branch_map` — same shape.
- `test_step5_guards_tenant_id`
- `test_step6_step7_surface_empty_entity_map`

### `institutional memory` (1)
- `test_marker_comment_preserved_for_future_archaeology` — pins
  ≥5 occurrences of `G-WIZARD-STALE-STATE` in the wizard so a
  future "simplification" trips on the markers and reads the why
  before deleting the what.

**8/8 pass.** Full regression sweep: **93/93 pass.** Build:
`flutter build web --release --no-tree-shake-icons` ~94s, clean.

---

## Manual UAT (steps 1-9 from a clean state)

1. **Open InPrivate / Incognito window.** Verify Local Storage empty
   via `Object.entries(localStorage).filter(([k])=>!k.includes('token'))`.
2. **Register a new user.** Verify Local Storage now has BOTH
   `pilot.tenant_id` AND `apex_tenant_id` (from G-LEGACY-KEY-AUDIT).
   No `pilot.entity_id` or `pilot.branch_id`.
3. **Navigate to `/app/erp/finance/onboarding`.** No console errors.
   `[APEX][G-LEGACY-KEY-AUDIT]` warn does NOT fire (keys agree).
4. **Step 1 — Tenant.** Fill the form → Continue. Network tab shows
   `PATCH /pilot/tenants/{tid}` (NOT POST). 200.
5. **Step 2 — Entities.** Add SA → Continue.
   `POST /pilot/tenants/{tid}/entities` 201. Local Storage now has
   `pilot.entity_id`.
6. **Step 3 — Branches.** Add a branch → Continue.
   `POST /pilot/entities/{eid}/branches` 201.
7. **Step 4 — Warehouses.** Continue (auto-creates).
8. **Step 5 — Currencies.** Continue. Tolerates 409.
9. **Steps 6-7 — CoA + periods.** Continue.

### Reload-mid-wizard probe (the new defensive layer)

Repeat from step 5 onwards with an F5 between each step:

- Reload on step 5 → return to wizard at step 1, but `_tenantId`
  hydrates from `PilotSession.tenantId` (initState) so the data
  bindings are stable. `_createdEntityIds` is empty in-memory.
- Click Continue past step 1 → step 2 errors with "أضف كياناً
  واحداً على الأقل" (existing message — `_entitiesToCreate` is
  empty in memory, expected).

The old null-bang failures (`Null check operator used on a null
value` from steps 3, 4, 5) no longer occur — instead users see
actionable Arabic messages pointing them back to the right step.

### Orphan-cleanup probe

1. Set up a tenant + entity normally (step 1-2).
2. Open DevTools Console. Run:
   `localStorage.removeItem('pilot.tenant_id'); localStorage.removeItem('apex_tenant_id');`
   (Leave `pilot.entity_id` set.)
3. Reload `/app/erp/finance/onboarding`.
4. Verify `pilot.entity_id` is gone (initState's
   `clearEntityAndBranch()` ran because `!hasTenant && hasEntity`
   was true).

---

## What we did NOT do (and why)

- **Did not hydrate `_createdEntityIds` from the backend on init.**
  That would let a user reload mid-wizard and continue from where
  they left off (e.g., step 4 still sees the entities created in
  step 2). Worth doing, but it's a feature, not a hotfix —
  separate ticket.
- **Did not enable widget tests.** G-T1.1 (`session.dart →
  dart:html → package:web 1.1.1` SDK mismatch) blocks the wizard
  from loading in a Dart-VM test runner. Source-grep tests pin
  the contract. Same approach as PR #182 / PR #183.
- **Did not change the backend.** Zero changes. The fix is purely
  frontend defensive hardening.
- **Did not refactor the duplicated `_loading = true` /
  `setState` boilerplate.** Each step deliberately scopes its own
  loader for clarity. Refactor is a separate ticket.

---

## References

- ERR-2 Phase 3 (PR #169) — backend auto-tenant + JWT claim.
- G-WIZARD-TENANT-FIX (PR #180) — wizard's `hasTenant` branch.
- G-AUTH-TENANT-PERSIST (PR #182) — persists `user.tenant_id`
  to PilotSession on login/register.
- **G-LEGACY-KEY-AUDIT (PR #183)** — closes the legacy/pilot
  localStorage key drift. The migration helper this PR explicitly
  invokes lives there.
- `docs/LEGACY_KEY_AUDIT_2026-05-09.md` — the layer below this fix.
- `docs/AUTH_TENANT_PERSIST_2026-05-09.md` — the layer above
  G-LEGACY-KEY-AUDIT.
- `docs/WIZARD_TENANT_FIX_2026-05-09.md` — the original wizard
  hotfix that this PR hardens.
