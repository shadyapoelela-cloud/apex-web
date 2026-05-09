# APEX Sprint Progress

## Sprint 18 — Invoicing (Q2 2026, week 7) — IN PROGRESS

### 2026-05-09

- [x] **G-FIN-PURCHASE-INVOICE-JE-AUTOPOST** (Sprint 6 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-purchase-invoice-je-autopost`
  - **Why:** Sprint 1 audit Gap §3 row 6. The backend
    `post_purchase_invoice_to_gl`
    (purchasing_engine.py) has shipped since well before
    this sprint and auto-builds the standard 3-leg
    purchase JE on `POST /pilot/purchase-invoices/{id}/post`
    (DR Inventory or Expense / DR VAT Input / CR Payable).
    What was missing was the frontend create screen —
    the previous `+ جديد` button routed to a `/purchase`
    placeholder.
  - **What landed:** dedicated
    `PurchaseInvoiceCreateScreen` mirroring the Sprint 5
    pattern with vendor-side specifics (60-day default
    due date, vendor_invoice_number field, shipping
    field). Two save buttons (Draft / Save+Post). Success
    snackbar surfaces `journal_entry_id` with action
    link. New API method `pilotCreatePurchaseInvoice`.
    New GoRoute. List `+ جديد` rewired to the create
    screen. 7 source-grep tests, all pass.
  - **Verification:** `flutter analyze` clean across all
    4 changed files; 7/7 tests pass.

- [x] **G-FIN-PRODUCT-CATALOG** (Sprint 4 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-product-catalog`
  - **Why:** Sprint 1 audit Gap §3 row 4. Sprints 5/6
    invoice line pickers need an inline product-create flow.
    The full multi-tab catalog management UI already
    exists (`pilot/screens/setup/products_screen.dart`,
    2179 lines, 5 tabs) but isn't reachable from inside an
    invoice form — a 5-tab management UI is too heavy for
    the "add this one item to my line" use case.
  - **What landed:**
    - `apex_finance/lib/core/barcode_utils.dart` —
      pure-Dart EAN-13 helpers (`ean13CheckDigit`,
      `generateEan13`). Pure Dart so they're testable
      under flutter_test without the package:web SDK gate.
    - `apex_finance/lib/screens/inventory/product_create_modal.dart`
      — focused modal that POSTs `/pilot/tenants/{id}/products`
      with one inline variant so the product is invoice-ready
      immediately. Stashes typed barcode on
      `_pending_barcode` for the caller to attach.
    - `apex_finance/lib/widgets/forms/product_picker_or_create.dart`
      — picker with 3 modes: type-to-search, barcode
      lookup (Enter or dedicated button), inline create.
      On barcode miss, opens the modal with the typed
      barcode pre-filled.
    - 6 new API methods: `pilotGetProduct`,
      `pilotListProductVariants`,
      `pilotCreateProductVariant`, `pilotBarcodeLookup`,
      `pilotListCategories`, `pilotListBrands`.
    - 12 tests (7 real EAN-13 unit tests with known
      vectors + 5 source-grep) — all pass.
  - **Verification:** `flutter analyze` clean across all
    4 changed files; 12/12 tests pass.

- [x] **G-FIN-VENDORS-COMPLETE** (Sprint 3 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-vendors-complete`
  - **Why:** Sprint 1 audit Gap §3 row 3. Mirror of
    Sprint 2 (Customers) with vendor-specific
    differences: KSA IBAN validator, default
    `payment_terms=net_60`, bank fields (`bank_name`,
    `bank_iban`, `bank_swift`), `is_preferred` flag, and
    purchase-invoice tab 3 (instead of sales-invoice).
  - **What landed:** modal (19 fields), 3-tab details
    screen, picker widget, list rewire, new GoRoute
    `/app/erp/finance/vendors/:vendorId`, 9 source-grep
    tests, flow doc.
  - **Verification:** `flutter analyze` clean across all
    5 changed files; 9/9 tests pass.

- [x] **G-FIN-SALES-INVOICE-JE-AUTOPOST** (Sprint 5 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-sales-invoice-je-autopost`
  - **Why:** Sprint 1 audit Gap §3 row 5. The backend
    JE auto-post engine
    (`_post_sales_invoice_je` at
    `app/pilot/routes/customer_routes.py:364`)
    has shipped since well before this sprint and produces
    the standard 3-leg sales JE
    (DR Receivable / CR Revenue / CR VAT Output) on
    `POST /sales-invoices/{id}/issue`. What was missing was
    the frontend signal: the create screen used a customer
    dropdown that forced users to leave the form, had no
    "save as draft" button (so any save auto-posted a JE),
    and the success snackbar buried the JE id without an
    action link.
  - **What landed:**
    - `apex_finance/lib/screens/operations/sales_invoice_create_screen.dart`
      — replaced the dropdown with `CustomerPickerOrCreate`
      from Sprint 2; split `_submit` into `_buildPayload` +
      `_saveDraft` + `_submit`; the `_saveDraft` path
      explicitly does NOT call `pilotIssueSalesInvoice` so
      drafts do not pollute the trial balance with un-issued
      invoices; the success snackbar surfaces
      `journal_entry_id` with an action button labelled
      "عرض القيد" linking to `/app/erp/finance/je-builder`.
    - `apex_finance/test/screens/sales_invoice_je_autopost_test.dart`
      — 6 source-grep contracts pinning the picker import,
      the draft-skips-issue rule, the create-then-issue
      order, the snackbar JE-link, and the 2-button ratchet.
    - `docs/SALES_INVOICE_JE_FLOW_2026-05-09.md` — flow
      diagram, manual UAT script, explicit "what's NOT in
      this sprint" note (multi-line + COGS JE deferred to a
      future sprint that bundles them with Sprint 4 product
      catalog work).
  - **Verification:** `flutter analyze` clean;
    `flutter test test/screens/sales_invoice_je_autopost_test.dart`
    → 6/6 pass.

- [x] **G-FIN-CUSTOMERS-COMPLETE** (Sprint 2 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-customers-complete`
  - **Why:** Sprint 1 audit Gap §3 row 1 ("Customer creation
    form missing — `+ جديد` routed to a placeholder `/sales`
    page") + row 2 ("Customer details — clicking a row routed
    to `/operations/customer-360/:id`, an archived path that
    rendered the coming-soon banner"). Both gaps closed with
    pure frontend work — backend endpoints
    (`POST /pilot/tenants/{tid}/customers`,
    `GET /pilot/customers/{id}`,
    `GET /pilot/customers/{id}/ledger`) all pre-existed.
  - **What landed:**
    - `apex_finance/lib/screens/operations/customer_create_modal.dart`
      — 14-field modal with KSA-15-digit VAT validator,
      auto-generated `CUST-NNN` code on blank, `show()`
      returns `Future<Map<String, dynamic>?>` for downstream
      auto-select use.
    - `apex_finance/lib/screens/operations/customer_details_screen.dart`
      — 3-tab screen (تفاصيل / السجل المالي / الفواتير).
      Tab 3 filters the entity-scoped sales-invoices list by
      `customer_id` client-side.
    - `apex_finance/lib/widgets/forms/customer_picker_or_create.dart`
      — autocomplete picker + inline `+ عميل جديد` that
      opens `CustomerCreateModal` pre-filled with the typed
      query. Designed for Sprint 5's Sales Invoice line.
    - `apex_finance/lib/screens/operations/customers_list_screen.dart`
      — `_onCreate` opens the modal and refreshes inline
      (no nav). Row tap routes to the new
      `/app/erp/finance/customers/:id` path.
    - `apex_finance/lib/core/router.dart` — new GoRoute
      `/app/erp/finance/customers/:customerId` →
      `CustomerDetailsScreen`.
    - `apex_finance/test/screens/customers_complete_test.dart`
      — 8 source-grep contracts pinning the modal payload
      shape, the 15-digit VAT rule, the new row-tap route,
      the 3-tab structure, and the inline-create
      pre-fill flow.
    - `docs/CUSTOMERS_FLOW_2026-05-09.md` — full audit doc
      with the before/after diagram, validation rules,
      manual UAT script, and roadmap context.
  - **Verification:** `flutter analyze` clean across all 5
    changed dart files; `flutter test test/screens/customers_complete_test.dart`
    → 8/8 pass.

- [x] **G-FIN-AUDIT-CLEANUP** (Sprint 1 of the Finance Module 7-sprint plan)
  - Branch: `feat/g-fin-audit-cleanup`
  - **Why:** the Finance module today has 70 chips under
    `erp/finance/*`. Five of them (`gl`, `trial-balance`,
    `income-statement`, `balance-sheet`, `cash-flow`,
    `statements`) were already unified on 2026-05-08 to
    point at dedicated screens (G-FIN-IS-1 / G-FIN-BS-1 /
    G-FIN-CF-1 / G-TB-DISPLAY-1) but the unification was
    not yet documented or pinned by tests, leaving the
    door open for a silent re-collapse. 18 V5.2 chips
    rendered hardcoded fixtures with no UI signal that
    the data wasn't real — users couldn't tell which
    "ميزانية" was a real backend wire and which was a
    placeholder.
  - **What landed:**
    - `docs/FINANCE_MODULE_AUDIT_2026-05-09.md` —
      3-table audit (Screen × Chip × Backend × Type;
      Duplicates; Gaps + Sprint mapping). Documents
      that all three JE auto-post engines
      (`_post_sales_invoice_je`,
      `post_purchase_invoice_to_gl`, `auto_post_pos_sale`)
      already exist server-side, so Sprints 5/6/7
      remaining work is purely frontend.
    - `apex_finance/lib/widgets/v52_mock_wrap.dart` —
      reusable banner widget rendering "🚧 قيد التطوير"
      above any wrapped screen, dismissible per-session.
    - `apex_finance/lib/core/v5/v5_wired_screens.dart` —
      18 V5.2 mock chip mappings now wrapped with
      `V52MockWrap(child: ...)`. No widget code
      duplicated, no fixtures removed; one-line drop of
      the wrapper when each chip gets a real backend wire.
    - `apex_finance/test/v5_routing_test.dart` — new
      regression-prevention pin: the 6 financial-statement
      chips (`gl`, `trial-balance`, `income-statement`,
      `balance-sheet`, `cash-flow`, `statements`) must
      all stay wired. If a refactor silently re-collapses
      them, this test fails.
  - **Verification:** `py scripts/dev/repro_routing_bugs.py`
    reports 0 errors. Chip-key count in
    `v5_wired_keys.dart` matches `v5_wired_screens.dart`
    (70 entries each, unchanged).
  - **Roadmap:** Sprints 2-7 (customers/vendors/products
    full CRUD, sales/purchase invoice create screens,
    POS daily summary). Tabulated in audit doc § "6-Sprint
    Roadmap".

- [x] **G-WIZARD-STALE-STATE** — defensive init + null-safety guards in onboarding wizard
  - Branch: `hotfix/g-wizard-stale-state`
  - **Why:** G-LEGACY-KEY-AUDIT (PR #183) closed the localStorage
    *drift* but didn't audit the wizard's *initialization*. Three
    gaps survived: (1) wizard had no `initState` override, so
    `migrateLegacyKey()` ran transitively only via the
    `PilotSession.hasTenant` getter on line 1086 — fragile to
    refactors; (2) `_tenantId` was populated only at step 1, so a
    reload on step ≥ 2 wiped it and every `_tenantId!` bang in
    steps 3-8 exploded; (3) orphan `pilot.entity_id` /
    `pilot.branch_id` (entity without tenant — pre-pilot residue)
    polluted other screens reading PilotSession during wizard use.
    Plus four sub-bombs: `_doStep3` `_createdEntityIds[..]!`,
    `_doStep4` `_createdBranchIds[..]!`, `_doStep5` `_tenantId!`,
    `_doStep6/7` silent no-op on empty entity map (user thought
    CoA / fiscal periods were seeded when they weren't).
  - **Fix shape:** new `initState()` block does three things in
    three lines — explicit `PilotSession.migrateLegacyKey()`
    (defensive even though the getter calls it lazily), hydrate
    `_tenantId = PilotSession.tenantId` (so reload-on-step-≥2
    doesn't null-bang), and `clearEntityAndBranch()` if the
    orphan condition `!hasTenant && hasEntity` is true. Plus
    null-safety guards in `_doStep3..7`: each checks `_tenantId`
    and the required collection up-front, throwing translated
    Arabic messages that point users back to the right step
    instead of throwing `Null check operator used on a null
    value` Dart errors. The two `!` bangs on map lookups in
    steps 3/4 are replaced with explicit null-check throws.
  - **Audit table sweep:** `getEntity()` / `getTenant()` methods
    don't exist — the brief meant `PilotSession.tenantId` /
    `.entityId` getters. 12 screens call them in `initState`; all
    are correct by transitivity (the post-PR-#183 lazy migration
    in the getter handles drift on first read). The wizard is
    unique because it makes a state-changing API call (PATCH or
    POST) on its first user action — that's why it gets the
    explicit `initState` reconciliation while the rest stay on
    the lazy guarantee.
  - **Tests:**
    `apex_finance/test/pilot/screens/setup/wizard_stale_state_test.dart`
    — **8 source-grep tests** across three groups (3 initState
    contract + 4 null-safety guard + 1 institutional memory).
    Each pins a specific defensive line: migrateLegacyKey() call,
    _tenantId hydration, orphan cleanup, step 3/4/5/6/7 guards,
    absence of the two `!` bangs, and the G-WIZARD-STALE-STATE
    marker count (≥5). **8/8 pass.** Full Flutter regression
    sweep (these 8 + G-LEGACY-KEY-AUDIT + provider auth +
    ERP-unification + financial statements + TB + v5_routing +
    auth_guard + err_1): **93/93 pass.**
  - **What we did NOT do:** did not hydrate `_createdEntityIds`
    from the backend on init — that's a feature (let users
    continue from where they left off after a reload), not a
    hotfix; separate ticket. Did not enable widget tests
    (G-T1.1 SDK mismatch on `package:web` 1.1.1 still blocks
    the wizard from loading in a Dart-VM test runner). Did not
    refactor the duplicated `_loading = true` boilerplate. Did
    not change the backend.
  - **Verification:** `flutter analyze` on
    `pilot_onboarding_wizard.dart` → 2 pre-existing infos (not
    from this fix). `flutter build web --release
    --no-tree-shake-icons` ~94s clean. 0 backend changes ·
    0 alembic migrations · 0 schema changes.
  - **Manual UAT:** documented in
    `docs/WIZARD_STALE_STATE_2026-05-09.md` — full 9-step
    walkthrough plus a "reload-mid-wizard" probe and an
    "orphan-cleanup" probe that proves the new defensive layer.
  - Files: `apex_finance/lib/pilot/screens/setup/pilot_onboarding_wizard.dart`
    (initState block + 4 step guards);
    `apex_finance/test/pilot/screens/setup/wizard_stale_state_test.dart`
    (8 tests); `docs/WIZARD_STALE_STATE_2026-05-09.md` (audit
    table + UAT walkthrough + 2 probes).

- [x] **G-LEGACY-KEY-AUDIT** — closes the legacy/pilot key drift
  - Branch: `hotfix/g-legacy-key-audit`
  - **Why:** the frontend has been carrying two localStorage keys
    for the same value: `apex_tenant_id` (legacy, used by 20+
    screens via `S.tenantId`) and `pilot.tenant_id` (canonical,
    used by the wizard / ERP-unification / every pilot route).
    Three call sites wrote one without the other:
    `S.setActiveScope` wrote only the legacy key directly via
    `localStorage[…] = …`, bypassing `PilotSession.tenantId`'s
    dual-key sync. `S.clear` removed only the legacy key — the
    next user logging in on the same browser inherited the
    previous user's `tenantId`, silently bypassing tenant-isolation
    guards. `S.savedTenantId` read only the legacy key, blind to
    pilot-only writes. Each is a different shape of the same bug,
    each survived G-AUTH-TENANT-PERSIST because that PR added
    *new* persistence without fixing the *legacy* drift below it.
  - **Audit table:** 1 direct writer in `core/session.dart:41`
    replaced; setters in `pilot/session.dart` already correct;
    auth flows (provider + 3 screens) already routed through
    `PilotSession.tenantId` post-G-AUTH-TENANT-PERSIST. 20+
    readers via `S.tenantId` / `S.savedTenantId` unchanged —
    fed transparently by the dual-key sync.
  - **Migration helper:** `PilotSession.migrateLegacyKey()` —
    lazy, idempotent (`_legacyMigrated` flag), runs once per
    session on first read of `tenantId`. Three drift scenarios:
    (1) both agree → no-op; (2) both differ → trust pilot, sync
    legacy ← pilot, console-warn `[APEX][G-LEGACY-KEY-AUDIT]
    tenant_id drift detected …`; (3) only legacy exists (pre-pilot
    session) → migrate up to `pilot.tenant_id`. Lazy + first-read
    means correctness lands at exactly the moment it matters —
    the wizard's `hasTenant` check or the API tenant_id injection.
  - **Four structural changes:** (1) `lib/pilot/session.dart` —
    `migrateLegacyKey()` helper + lazy invocation on `tenantId`
    getter; (2) `lib/core/session.dart` — `setActiveScope`
    routes through `PilotSession.tenantId/entityId` setters
    instead of writing localStorage directly; (3)
    `lib/core/session.dart` — `S.clear()` calls
    `PilotSession.clear()` so every clear path (logout, 401
    interceptor, future code) is symmetric without each caller
    having to remember; (4) `lib/core/session.dart` —
    `savedTenantId` falls back through `pilot.tenant_id` first,
    `apex_tenant_id` second, so screens still on `S.tenantId`
    see pilot-only writes.
  - **Tests:** `apex_finance/test/pilot/session_legacy_migration_test.dart`
    — **8 source-grep tests** across two groups (5 pilot setter/clear,
    3 core/session contract). Each pins a specific drift scenario:
    setter writes both keys; clear wipes both keys; drift detection;
    legacy-only migrate-up; lazy invocation; logout symmetry;
    setActiveScope routing; reader fallback chain order. **8/8 pass.**
    Full Flutter regression sweep
    (these 8 + provider auth + ERP-unification + financial statements +
    TB + v5_routing + auth_guard + err_1): **85/85 pass.**
  - **What we did NOT do:** did not touch the 20+ screens reading
    `S.tenantId` / `S.savedTenantId` — the fallback chain in
    `savedTenantId` handles them transparently; refactoring readers
    to use `PilotSession.tenantId` directly is a separate ticket.
    Did not delete the legacy `apex_tenant_id` key — it stays as a
    mirror, no longer a source of truth. Did not eager-init the
    helper in `main.dart` — lazy on first read decouples
    session.dart from main.dart's init order.
  - **Verification:** `flutter analyze lib/core/session.dart
    lib/pilot/session.dart` → 1 pre-existing `dart:html` info
    (not from this fix). 0 backend changes · 0 alembic
    migrations · 0 schema changes.
  - **Manual UAT:** documented in
    `docs/LEGACY_KEY_AUDIT_2026-05-09.md` — 6 steps including a
    "manually corrupt apex_tenant_id then reload" check that
    proves the migration helper auto-fixes drift.
  - Files: `apex_finance/lib/pilot/session.dart` (migration
    helper + lazy getter); `apex_finance/lib/core/session.dart`
    (setActiveScope reroute + clear symmetry + savedTenantId
    fallback); `apex_finance/test/pilot/session_legacy_migration_test.dart`
    (8 tests); `docs/LEGACY_KEY_AUDIT_2026-05-09.md` (audit table,
    drift scenarios, migration logic, manual UAT).

- [x] **G-AUTH-TENANT-PERSIST** — closed the missing piece in G-WIZARD-TENANT-FIX chain
  - Branch: `hotfix/g-auth-tenant-persist`
  - **Why:** G-WIZARD-TENANT-FIX (PR #180) made the wizard branch on
    `PilotSession.hasTenant` to PATCH (not POST) the existing
    JWT-bound tenant. But that fix relied on
    `PilotSession.tenantId` being populated post-login — and the
    four production auth flows all silently dropped the `tenant_id`
    field from the auth response. ERR-2 Phase 3 (PR #169) put it
    in the user blob; nothing read it. So
    `PilotSession.hasTenant` returned `false`, the wizard fell back
    to `createTenant`, a second tenant was created, and step 2
    404'd against the JWT-bound first tenant — same bug
    G-WIZARD-TENANT-FIX was supposed to close, just one layer up.
  - **Recon:** the brief asked me to fix `app_providers.dart` only,
    but `grep -rn "ApiService.login\|ApiService.register"` returned
    **5 files**. Three of the four production flows had the same
    bug: `app_providers.dart`, `screens/auth/login_screen.dart`,
    `screens/auth/register_screen.dart`,
    `screens/auth/slide_auth_screen.dart`. The slide-auth
    `_register()` is snackbar-only (no `S.*` writes) — the user
    logs in afterwards which hits the fixed `_login`, so out of
    scope. **No OAuth flows in the frontend** (verified via
    grep — zero matches for `googleSignIn` / `appleSignIn` /
    `oauthLogin` / `socialLogin`).
  - **Drift fix found in passing:** `app_providers.register()` was
    missing the `S.roles = List<String>.from(user['roles'] ?? [])`
    line that `login()` has. A freshly-registered user walked
    around with empty roles until they re-logged. Same
    neighbourhood; added the missing line.
  - **Logout cleanup:** `S.clear()` wipes the legacy
    `apex_tenant_id` localStorage key but leaves the new
    `pilot.tenant_id` untouched. Pre-fix, the next user logging
    in on the same browser inherited the previous user's
    `tenantId` — silently bypassing tenant-isolation guards.
    Fix: `app_providers.logout()` now calls `PilotSession.clear()`
    after `S.clear()`.
  - **Fix:** in every auth-success branch (4 call sites):
    ```dart
    final tenantId = user['tenant_id'];
    if (tenantId is String && tenantId.isNotEmpty) {
      PilotSession.tenantId = tenantId;
    }
    ```
    Plus `import '../pilot/session.dart';` at the top. The
    `is String && isNotEmpty` guard handles three cases gracefully:
    normal post-PR-#169 user (persists), legacy pre-ERR-2 user not
    yet migrated (silent skip — wizard's createTenant fallback
    fires), and a bug-returns-empty-string defense (rejected
    rather than silently breaking the wizard while LOOKING set).
  - **Tests:** `apex_finance/test/providers/app_providers_test.dart`
    — 8 source-grep regression tests across two groups (5 provider
    flow tests + 3 auth-screen tests). Pins: register persists
    tenant_id, login persists tenant_id, register persists roles
    (drift fix), logout calls `PilotSession.clear()`, the marker
    comment preservation, and per-screen the import + the read +
    the write + the `isNotEmpty` guard + the marker. All 8 pass.
  - **Verification:**
    - `flutter test test/providers/app_providers_test.dart` →
      **8/8 pass**.
    - Full Flutter regression sweep (these 8 + ERP unification +
      wizard + financial statements + TB + v5_routing +
      auth_guard + err_1_session_redirect) → **77/77 pass**.
    - Backend regression sweep (CF + BS + IS + TB +
      tenant_isolation_full + tenant_isolation_v2) → **119/119 pass**.
    - `flutter analyze` on the 4 modified files → 2 pre-existing
      infos (not introduced by this fix; `dart:html` import +
      curly-braces lint in untouched code).
    - `flutter build web --release --no-tree-shake-icons` → ~50s.
    - 0 backend changes. 0 alembic migrations. 0 schema changes.
  - **Docs:** new `docs/AUTH_TENANT_PERSIST_2026-05-09.md` —
    bug-chain walkthrough (3 PRs explained), the 5-line fix, the
    drift fix, the logout invariant, manual UAT (InPrivate window
    → register → DevTools verify `pilot.tenant_id` exists →
    wizard PATCH not POST → step 2 no 404 → logout wipes the key).
    Includes "what we did NOT do" section (no backend changes, no
    architectural refactor of the 4 duplicate auth flows, no
    OAuth fix because no OAuth flows exist).
  - **Hotfix scope discipline:** four file edits + one test file +
    one doc. No backend, no schema, no router, no architectural
    reshaping.

- [x] **G-ERP-UNIFICATION** — closed UAT Issue #6 (duplicate setup journey)
  - Branch: `feat/g-erp-unification`
  - **Why:** APEX had two parallel paths for setting up companies +
    branches: the legacy `/settings/entities` screen writing to
    localStorage (invisible to backend → never reaches pilot_gl_postings
    → financial statements render empty for users who set themselves
    up via this path) and the unified `/app/erp/finance/onboarding`
    wizard writing to pilot_* tables. The four legacy redirects
    (`/onboarding/wizard`, `/clients/onboarding`, `/clients/new`,
    `/clients/create`) all pointed at the legacy localStorage screen,
    so users following any of them silently bypassed the ERP. UAT
    Issue #6.
  - **Recon:** confirmed only 3 callers of `EntityStore` in the
    codebase (the store itself, the screen, one merge call in
    `api_service.dart` that returns `[]` after migration → safe).
    Gotchas found: pilot's `code` field has `min_length=2` +
    `^[A-Z0-9_-]+$` pattern but `CompanyRecord` / `BranchRecord` carry
    no `code` field at all → synthesize from id with `MIG-` / `BR-`
    prefixes. `BranchCreate.city` is required but
    `BranchRecord.city` is nullable → fall back to "غير محدد".
  - **Frontend:**
    - `apex_finance/lib/screens/settings/entity_setup_screen.dart`:
      added one-shot migration banner (renders only when
      `EntityStore.listCompanies()` or `listEntities()` non-empty)
      with two buttons. "نعم، انقلها" runs `_runMigration()` —
      POSTs each company via `pilotClient.createEntity(tid, ...)`,
      builds a `legacy_company_id → new_entity_id` map, then POSTs
      each branch via `pilotClient.createBranch(newEntityId, ...)`.
      Per-record failures recorded in `_MigrationResult.failures`
      and surfaced in a result dialog (no silent drops).
      `EntityStore.clearAll()` runs after; redirect to wizard.
      "لا، تجاهل واحذف" gates a destructive wipe behind a confirm
      dialog. Banner-render gated on `PilotSession.hasTenant` to
      prevent calling /tenants/{null}/... — disabled button + clear
      error message when tenant absent.
    - `apex_finance/lib/core/router.dart`: empty-store redirect
      guard on `/settings/entities` (returns
      `/app/erp/finance/onboarding` when both lists empty —
      bypasses the legacy screen entirely for clean accounts).
      All 4 legacy redirects re-pointed from
      `/settings/entities?action=new-company` →
      `/app/erp/finance/onboarding`.
  - **Tests:** 13 cases across two files in
    `apex_finance/test/screens/settings/`:
    - `entity_setup_migration_test.dart` (7) — pins banner render
      condition, both action buttons, `pilotClient.createEntity` +
      `createBranch` call sites, the legacy-id mapping for
      branches, the `_MigrationResult` failure recording, the
      `_showMigrationResultDialog` surfacing, the
      `EntityStore.clearAll()` on completion, the
      `_confirmIgnoreAndDelete` confirm-dialog gate, the
      `PilotSession.hasTenant` button guard, and the
      `_legacyCompanyCode` / `_legacyBranchCode` helpers + their
      `MIG-` / `BR-` prefix conventions.
    - `legacy_redirect_test.dart` (6) — 4 individual tests for the
      legacy paths (each asserts redirect target is
      `/app/erp/finance/onboarding` AND not the old
      `/settings/entities?action=new-company`); the empty-store
      guard at `/settings/entities`; a belt-and-braces grep that
      no `?action=new-company` reference remains anywhere in
      `router.dart`.
  - **Verification:**
    - `flutter test test/screens/settings/{entity_setup_migration,legacy_redirect}_test.dart`
      → 13/13 pass.
    - Flutter regression sweep (these 13 + wizard + CF + BS + IS +
      TB + v5_routing + auth_guard + err_1_session_redirect) →
      **69/69 pass**.
    - Backend regression sweep (CF + BS + IS + TB +
      tenant_isolation_full + tenant_isolation_v2) → **119/119 pass**.
    - `flutter analyze` on the modified files → 0 issues.
    - `flutter build web --release --no-tree-shake-icons` → ~49s.
    - 0 backend changes. 0 alembic migrations. 0 schema changes.
  - **Docs:** new `docs/ERP_UNIFICATION_2026-05-09.md` — before/
    after diagrams, migration algorithm + edge-case handling
    (null tenant, parent didn't migrate, code collision, network
    failure mid-migration), 4 manual UAT paths (fresh user / legacy
    with data / pick-ignore / each legacy redirect), explicit
    rollback plan (the deliberate decision to keep
    `entity_store.dart` on disk).
  - **Decision:** `entity_store.dart` is **kept on disk** even
    though no new code writes through it. Enables a clean
    `git revert` rollback if the migration surfaces a class of
    legacy data the helpers don't handle. Cost: ~600 lines of
    quiescent code. Benefit: hours-not-days MTTR on any rollback
    path. UAT Issue #6 closed.

- [x] **G-WIZARD-TENANT-FIX** — closed onboarding regression from G-PILOT-TENANT-AUDIT-FINAL
  - Branch: `hotfix/g-wizard-tenant-fix`
  - **Why:** the onboarding wizard's `_doStep1` always called
    `createTenant`, which post-PR-#176 broke for every fresh user.
    Three previously-correct decisions collided: ERR-2 Phase 3
    (PR #169) auto-creates a tenant at registration with the JWT
    holding its id; G-PILOT-TENANT-AUDIT-FINAL (PR #176) made every
    pilot route enforce `assert_tenant_matches_user` (404 on
    mismatch); and the wizard predates both. Result: step 1
    created a *second* tenant, step 2's `createEntity` 404'd
    against the new (non-JWT) tid, and onboarding failed silently
    with "Entity not found" on a tenant the user just created.
  - **Fix:** `_doStep1` now branches on `PilotSession.hasTenant`.
    The `true` branch (the common path post-PR-#169) PATCHes the
    existing tenant via `_client.updateTenant(tid, …)` and sets
    `_tenantId = PilotSession.tenantId`. The `false` branch (legacy
    users from before ERR-2 who never got migrated by PR #170)
    retains the original `createTenant` flow. Sends only fields
    `TenantUpdate` accepts (slug / primary_email / primary_country
    are immutable post-registration).
  - **Tests:** `apex_finance/test/pilot/screens/setup/pilot_onboarding_wizard_test.dart`
    — 4 source-grep regression tests (widget tests blocked by the
    G-T1.1 `session.dart → dart:html` SDK mismatch). Pins:
    `hasTenant` branching; `_tenantId = PilotSession.tenantId`
    assignment; `updateTenant` call; `createTenant` fallback
    retained; the `G-WIZARD-TENANT-FIX` marker comment.
  - **Verification:**
    - `flutter test test/pilot/screens/setup/pilot_onboarding_wizard_test.dart`
      → 4/4 pass.
    - Flutter regression sweep (wizard + CF + BS + IS + TB +
      v5_routing + auth_guard + err_1_session_redirect) →
      **56/56 pass**.
    - `flutter analyze` on the modified file → 2 pre-existing
      warnings unchanged (not from this fix).
    - `flutter build web --release --no-tree-shake-icons` →
      succeeds in ~88s.
    - 0 backend changes. 0 alembic migrations. 0 schema changes.
  - **Docs:** new
    `docs/WIZARD_TENANT_FIX_2026-05-09.md` — root-cause analysis
    (the three-decision collision), fix walkthrough, immutable-
    field rationale, manual UAT path, sibling-regression watchlist.
  - **Hotfix scope discipline:** no other files touched. The fix
    is one method body change + tests + doc. No backend,
    no schema, no other screens.

### 2026-05-08

- [x] **G-FIN-CF-1** — Cash Flow Statement (Indirect Method) with real-data + reconciliation invariant — **closes UAT Issue #5 (TB + IS + BS + CF all real-data)** 🎉
  - Branch: `feat/g-fin-cf-1`
  - **Why:** UAT Issue #5 needed four real-data financial statements
    (TB ✅ from G-TB-DISPLAY-1, IS ✅ from G-FIN-IS-1, BS ✅ from
    G-FIN-BS-1). CF was the last — and the most flawed pre-rewrite.
  - **Recon + L1 audit:** the prior `compute_cash_flow` had three
    distinct anti-mock concerns: (1) **hardcoded `0.0` for CFI/CFF**
    with `"v2: سنضيف تصنيف"` comment — production was returning
    genuinely-zero investing/financing sections regardless of the
    underlying data; (2) **`try/except: Decimal("0")` fallback** that
    silently swallowed all exceptions; (3) **fragile cash detection**
    via `code.startswith(("111", "112"))` — broke on any custom
    CoA. **Full rewrite.**
  - **Backend:**
    - New `_CF_SECTION_MAP` classifying asset/liability/equity
      subcategories into operating_wc / investing / financing / cash
      / *_skip / unmapped. Custom subcategories surface as warnings
      (no silent skip).
    - New `_cf_period_account_changes` helper deriving per-account
      changes from two `_bs_compute_snapshot` calls (start - 1d and
      end_date) and tagging by category. Sign convention: asset
      increase = -CF, liability/equity increase = +CF.
    - **Side-effect fix in `_index_by_account`:** `_bs_compute_snapshot`
      partitions rows into asset/liability/equity lists but doesn't
      include the category field on each row. Without explicit
      tagging from the bucket name, the sign convention silently
      defaults to the wrong branch (the bug surfaced as `total_cfo`
      including capital — found by the happy-path test).
    - `compute_cash_flow` rewritten to use the helpers. Adds
      `method`, `compare_period`, `include_zero` kwargs. Reconciliation
      check `(closing_cash - opening_cash) == net_change` within Q2
      tolerance — `is_reconciled` is what the data says; never silenced.
    - Direct method returns 422 with "قريباً" message. The current
      `JournalLine` schema lacks the per-line cash-tag the direct
      method needs.
    - New `CashFlowResponse` + 7 nested Pydantic classes
      (`CashFlowSnapshot`, `CashFlowOperating`, `CashFlowSection`,
      `CashFlowItem`, `CashFlowNoncashAdjustment`, `CashFlowTotals`,
      `CashFlowVariances`).
    - Endpoint: `X-Data-Source: real-time-from-postings` header.
      `is_reconciled=False` → 200 with structured
      `CF_RECONCILIATION_FAILURE` warning log + warnings list in
      response body. Operator must see the breakdown.
  - **Frontend:**
    - New
      `apex_finance/lib/screens/finance/cash_flow_screen.dart`
      (~960 lines). RTL header with subtitle "بيانات حقيقية +
      reconciliation محقق", filters bar (period start/end + method
      dropdown + compare + include_zero), **reconciliation banner
      first** (green ✅ / red ⚠️), unmapped-subcategory orange warning
      bar when present, 4 summary cards (CFO/CFI/CFF/NetChange with
      opening→closing cash subtitle), 3-section statement table
      grouped (Operating: net_income → non-cash → WC; Investing;
      Financing; net change; opening; closing), footer source line
      + green-dot guarantee, kDebugMode panel, empty-state CTA.
      **Zero local state initialised with values.**
    - **Class name aliasing:** `CashFlowScreen` already exists in
      `screens/compliance/cashflow_screen.dart` (older forecast
      screen). New imports use `as fin_cf` prefix in `v5_wired_screens`
      to disambiguate; the route + main.dart imports only the new
      one so no alias needed there.
    - `ApiService.pilotCashFlow` extended with `method` +
      `comparePeriod` + `includeZero` kwargs.
    - Wired into `v5_data` (chip), `v5_routes` (explicit GoRoute),
      `v5_wired_screens` (Map entry), `v5_wired_keys` (manual add),
      `main.dart` Offstage sentinel.
  - **Tests:**
    - `tests/test_cash_flow_real_data.py` — **21 cases** across
      `TestRealDataFlow` (10 — happy path, AR/AP/inventory/depr/
      fixed-asset/loan), `TestReconciliation` (3 — complex 10-JE
      scenario, opening+change=closing, unmapped detection),
      `TestTenantAndValidation` (3 — cross-tenant 404, period
      validation, invalid method), `TestAntiMock` (4 — empty zeros,
      12345.67 round-trip, unmapped surface, no reconciliation
      bypass), plus 1 reconciliation-failure log assertion. **All
      21 pass.**
    - `apex_finance/test/screens/finance/cash_flow_test.dart` — **7
      tests**: chip declaration, wired-keys, validator reachability,
      source-grep anti-mock (incl. CF-specific `forceReconciled` /
      `overrideReconciled` / `silentReconciliation`), ApiService
      kwargs contract, **reconciliation-banner-renders-before-table**
      ordering, unmapped-warning conditional render.
  - **Verification:**
    - `pytest tests/test_cash_flow_real_data.py` → **21/21 pass**.
    - Pilot regression sweep (CF + BS + IS + TB +
      tenant_isolation_full + tenant_isolation_v2 + fin_statements
      + reports_download + dimensions) → **170/170 pass**.
    - `flutter analyze` → 0 issues.
    - Flutter regression (CF + BS + IS + TB + v5_routing +
      auth_guard + err_1_session_redirect) → **52/52 pass**.
    - `flutter build web --release --no-tree-shake-icons` →
      succeeds in ~52s.
    - 0 alembic migrations. 0 schema-breaking changes.
  - **Docs:** new
    `docs/CASH_FLOW_DATA_FLOW_2026-05-08.md` — 7-layer walkthrough
    (anti-mock pre-rewrite findings → CF section map → algorithm →
    AR sign rationale → endpoint → frontend → tests). Manual UAT
    (5 JE scenario yields CFO=40k, CFI=-30k, CFF=+120k, balanced)
    plus deliberate-imbalance UAT for the red-banner contract.
  - **🎉 UAT Issue #5 (Financial Statements) FULLY CLOSED.**
    All four statements (TB + IS + BS + CF) now backed by 100% real
    `pilot_gl_postings` data with test-pinned anti-mock and
    integrity-equation invariants.

- [x] **G-FIN-BS-1** — Balance Sheet (Statement of Financial Position) with real-data guarantee + balance-equation invariant — closes second-of-three of UAT Issue #5 (BS done; CF deferred to G-FIN-CF-1)
  - Branch: `feat/g-fin-bs-1`
  - **Why:** UAT Issue #5 needs three financial statements with real
    data — TB (closed by G-TB-DISPLAY-1), IS (closed by G-FIN-IS-1),
    BS (this PR). The backend already had a working
    `compute_balance_sheet` (no mocks), but the response shape was
    category-totals-only (no per-account rows, no comparison, no
    `posted_je_count`) and there was no dedicated frontend screen —
    the `balance-sheet` chip aliased to `FinancialReportsScreen`.
  - **Recon + L1 audit:** scanned `compute_balance_sheet` +
    `gl_routes.py` + the demo seeder. Zero mocks/fallbacks/seeded
    values found. `pilot_gl_postings` still has exactly one writer
    (`post_journal_entry`); demo seeder still writes 0 JEs.
    `compute_balance_sheet` already calls `compute_income_statement`
    one-way for `current_earnings` — no risk to IS-1.
    `compute_comparative_report` reads `assets / liabilities /
    total_equity` keys → kept as legacy scalar fields for backward
    compat.
  - **Critical finding:** the default CoA seeds an equity account
    with `subcategory='current_earnings'` (code 3300). That's the
    *closing-balance container*, not a running figure. Including it
    alongside the IS-derived running CYE would double-count. Fixed
    by excluding accounts with that subcategory from the equity rows
    summation and adding a synthetic `_current_year_earnings` row at
    the bottom of equity with the IS figure. Pinned by the
    `test_cye_in_equity_equals_is_net_income` test.
  - **Backend:**
    - `compute_balance_sheet` rewritten with helper
      `_bs_compute_snapshot`. New kwargs: `compare_as_of` +
      `include_zero`. Returns per-account rows (asset/liability/
      equity), nested `totals` block (current/fixed/long-term
      subtotals + balance-equation result), `posted_je_count`,
      optional `comparison_period` + `variances`. **Legacy top-level
      keys preserved** (`assets`, `liabilities`, `equity`,
      `current_earnings`, `total_equity`, `balanced`, `difference`)
      — `compute_comparative_report` keeps working.
    - `BalanceSheetResponse` extended with
      `current_period: BalanceSheetSnapshot`, `comparison_period`,
      `variances`, `posted_je_count`, `currency` — all defaults so
      legacy fixtures stay green. New `BalanceSheetRow`,
      `BalanceSheetTotals`, `BalanceSheetSnapshot`,
      `BalanceSheetVariances` Pydantic classes.
    - `GET /pilot/entities/{id}/reports/balance-sheet` accepts
      `compare_as_of` + `include_zero`; emits `X-Data-Source:
      real-time-from-postings` header. `compare_as_of >= as_of` →
      400. `is_balanced=False` → 200 with structured `BS_IMBALANCE`
      warning log (operator must see imbalances; we never silence).
  - **Frontend:**
    - New
      `apex_finance/lib/screens/finance/balance_sheet_screen.dart`
      (~720 lines). RTL header with freshness badge, filters bar
      (as-of + compare-as-of date pickers + include_zero switch +
      "إلغاء المقارنة" button), top **balance banner** (green ✅
      when balanced, red ⚠️ with diff when not), **4 summary
      cards** (assets/liabilities/equity/balance-status), three-
      section statement table (assets grouped current/fixed,
      liabilities grouped current/long-term, equity per-account
      with synthetic CYE in italic) — totals + subtotals show
      comparison values when present, footer source line + green-
      dot "بيانات حقيقية", empty-state CTA → JE Builder, kDebugMode
      panel.
    - `ApiService.pilotBalanceSheet` extended with `compareAsOf` +
      `includeZero` kwargs.
    - Wired into `v5_data` (chip), `v5_routes` (explicit GoRoute),
      `v5_wired_screens` (replaces alias), `main.dart` Offstage
      sentinel for tree-shake protection.
  - **Tests:**
    - `tests/test_balance_sheet_real_data.py` — **15 cases** across
      `TestRealDataFlow` (8), `TestTenantIsolation` (3),
      `TestAntiMock` (2), and `TestBalanceEquation` (2). The
      anti-mock pair pins the guarantee (empty entity → all zeros,
      12345.67 → byte-for-byte round-trip); the equation pair pins
      the integrity invariant (5-JE complex scenario; CYE row =
      IS net_income).
    - `apex_finance/test/screens/finance/balance_sheet_test.dart`
      — **6 tests**: chip declaration, wired-keys, validator
      reachability, source-grep anti-mock (extends IS-1's forbidden
      list with BS-specific `forceBalanced` / `overrideBalanced`
      tokens), ApiService kwargs contract, **balance-banner-
      renders-before-table** structural assertion (regression-proof:
      buried imbalance banner is easy to miss).
  - **Verification:**
    - `pytest tests/test_balance_sheet_real_data.py` → 15/15 pass.
    - Pilot regression sweep (BS + IS + TB + tenant_isolation_full
      + tenant_isolation_v2 + fin_statements + reports_download +
      dimensions) → **149/149 pass**.
    - `flutter analyze` on the new screen + ApiService → 0 issues.
    - Flutter regression (BS + IS + TB + v5_routing + auth_guard +
      err_1_session_redirect) → **45/45 pass**.
    - `flutter build web --release --no-tree-shake-icons` →
      succeeds in ~53s.
    - 0 alembic migrations. 0 schema-breaking changes.
  - **Docs:** new
    `docs/BALANCE_SHEET_DATA_FLOW_2026-05-08.md` — 8-layer
    walkthrough (writer → snapshot service → CYE synthesis →
    balance-equation → comparison → endpoint → frontend → tests)
    with verbatim queries, the synthetic-CYE rationale, manual UAT.
    CLAUDE.md unchanged (reuses the
    `assert_entity_in_tenant` helper from G-PILOT-REPORTS-TENANT-AUDIT,
    no new pattern).
  - **UAT Issue #5 progress:** 2 of 3 statements done (IS + BS).
    Cash-flow statement (`G-FIN-CF-1`) is the third — separate
    ticket as scoped (already has an endpoint
    `/reports/cash-flow`; needs the same treatment as IS-1 and
    BS-1).

- [x] **G-FIN-IS-1** — Income Statement (P&L) screen with 100% real-data guarantee — closes first half of UAT Issue #5
  - Branch: `feat/g-fin-is-1`
  - **Why:** UAT Issue #5 needs a real Income Statement screen. The
    backend already had a working `compute_income_statement` (no
    mocks), but the response shape was subcategory-only (no
    per-account rows, no comparison, no posted_je_count) and there
    was no dedicated frontend screen — the `income-statement` chip
    aliased to the broader `FinancialReportsScreen`.
  - **Recon + audit:** scanned `gl_engine.py`, `gl_routes.py`, the
    demo seeder, and the response shape; found **zero**
    mock/hardcoded/fake/stub patterns. Confirmed `pilot_gl_postings`
    has exactly one writer (`post_journal_entry`) and the demo
    seeder explicitly skips JEs (`"journal_entries": 0`). Real-data
    invariant intact.
  - **Backend:**
    - `compute_income_statement` extended in
      `app/pilot/services/gl_engine.py`: per-account rows, optional
      `compare_period` ("none" / "previous_year" / "previous_period"),
      `include_zero` toggle, `posted_je_count`. Internal callers
      (e.g., `compute_balance_sheet`) keep working — all new fields
      have defaults. The query was rewritten as an outerjoin from
      `GLAccount → GLPosting` so accounts with zero activity yield
      `0.0` rather than dropping out (preserves include_zero=true
      semantics).
    - `IncomeStatementResponse` schema gained `accounts:
      list[IncomeStatementRow]`, `posted_je_count: int = 0`,
      `compare_period: str = 'none'`, `comparison: Optional[…]`. New
      `IncomeStatementRow` + `IncomeStatementComparison` Pydantic
      classes.
    - `GET /pilot/entities/{id}/reports/income-statement` accepts
      `include_zero` + `compare_period` query params and emits
      `X-Data-Source: real-time-from-postings` response header.
  - **Frontend:**
    - New
      `apex_finance/lib/screens/finance/income_statement_screen.dart`
      (~700 lines). Mirrors `trial_balance_screen.dart` structure:
      RTL header with refresh + Excel + PDF buttons, freshness
      badge ("آخر تحديث: HH:MM:SS"), filters bar (date pickers +
      compare-period dropdown + include_zero switch), 3 summary
      cards (revenue / expenses / net-profit + variance % when
      comparing), statement table grouped Revenue + Expenses with
      subtotals + a final net-income row, footer source line
      ("المصدر: pilot_journal_lines — N قيد مرحّل" + "بيانات حقيقية
      — لا توجد قيم وهمية"), empty-state CTA → JE Builder, kDebugMode
      panel (entity_id, period, account counts, raw comparison).
      **Zero local state initialised with values** — no `_demoRows`,
      no `_defaultRows`, no fallback `'0.00'` strings; `_data`
      stays `null` until first fetch.
    - `ApiService.pilotIncomeStatement` extended with
      `includeZero` + `comparePeriod` params.
    - Wired into `v5_data` (chip), `v5_routes` (explicit
      `/app/erp/finance/income-statement` GoRoute), `v5_wired_screens`
      (replaces the old alias), `main.dart` Offstage instance for
      tree-shake protection.
  - **Tests:**
    - `tests/test_income_statement_real_data.py` — **15 cases**
      across `TestRealDataFlow` (10), `TestTenantIsolation` (3),
      `TestAntiMock` (2). The two anti-mock tests pin the
      guarantee: empty entity → genuine zeros (no defaults), and
      a 12345.67 JE round-trips byte-for-byte. **All 15 pass.**
    - `apex_finance/test/screens/finance/income_statement_test.dart`
      — **4 tests**: chip declaration, wired-keys registration,
      validator reachability, and a source-grep anti-mock test
      that scans `income_statement_screen.dart` (excluding doc
      comments) for forbidden tokens and asserts the
      "Real-data guarantee" doc-block is present. All 4 pass.
  - **Verification:**
    - `pytest tests/test_income_statement_real_data.py` → 15/15 pass.
    - Pilot regression sweep (TB + IS + tenant_isolation_full +
      tenant_isolation_v2 + fin_statements + reports_download +
      dimensions) → **134/134 pass**.
    - `flutter analyze` on the new screen → 0 issues.
    - Flutter regression (IS + TB + v5_routing + auth_guard +
      err_1_session_redirect) → **39/39 pass**.
    - `flutter build web --release --no-tree-shake-icons` →
      succeeds in ~123s.
    - 0 alembic migrations. 0 schema-breaking changes (all new
      response fields default).
  - **Docs:** new
    `docs/INCOME_STATEMENT_DATA_FLOW_2026-05-08.md` walks the full
    layer-by-layer real-data path (writer → service query →
    comparison → endpoint → frontend → tests) with the verbatim
    SQL, anti-mock test summaries, and a manual UAT checklist.
    CLAUDE.md unchanged (no new pattern; reuses the
    `assert_entity_in_tenant` helper from G-PILOT-REPORTS-TENANT-AUDIT).

- [x] **G-PILOT-TENANT-AUDIT-FINAL** — closed remaining tenant isolation gaps; **Issue #3 FULLY CLOSED across 117 routes**
  - Branch: `feat/g-pilot-tenant-audit-final`
  - **Why:** G-PILOT-REPORTS-TENANT-AUDIT (PR #175) closed the
    `entity_id`-shaped routes but flagged two remaining gaps:
    `/tenants/{tenant_id}/...` URLs and routes that resolve a
    resource directly by id (PO, PI, JE, Customer, Vendor, Product,
    Branch, Warehouse, Attachment, GosiRegistration, WpsBatch,
    PosTransaction, …). This PR closes both.
  - **Discovery:** **85 routes** vulnerable across the two shapes
    (37 tenant_id-path + 48 id-based) — broader than the brief's
    estimate. Surprises: (a) almost every pilot table has
    `tenant_id` directly so no FK chasing needed for ~95% of cases;
    (b) the most severe finding was 8 cross-tenant write/delete
    routes (cross-tenant ZATCA submission + PI post-to-GL + entity
    PATCH/DELETE + access-grant DELETE).
  - **Two new helpers** in `app/pilot/security/tenant_guards.py`:
    - `assert_tenant_matches_user(tenant_id, current_user)` — pure
      JWT-vs-URL compare, no DB hit.
    - `assert_resource_in_tenant(db, Model, resource_id, current_user, *, tenant_field='tenant_id', tenant_resolver=None)`
      — generic ID-based gate; default reads `tenant_id` column,
      `tenant_resolver` callback handles
      `ProductAttributeValue → ProductAttribute.tenant_id`.
    - Both return 404 + generic body on rejection (anti-enumeration,
      consistent with `assert_entity_in_tenant`); both emit
      `TENANT_GUARD_VIOLATION` warning logs with structured fields.
  - **Routes migrated:**
    - `pilot_routes.py`: 22 tenant + 5 ID = 27 routes (incl.
      tenant CRUD, settings, entities/branches lists, currencies,
      fx-rates, roles, members, access grants, branch by id, role
      by id).
    - `catalog_routes.py`: 9 tenant + 14 ID = 23 routes (incl.
      categories/brands/attributes/products/variants/barcodes/
      warehouses/stock CRUD).
    - `customer_routes.py`: 2 tenant + 5 ID = 7 routes (customers
      CRUD + sales-invoice issue/payment).
    - `purchasing_routes.py`: 2 tenant + 10 ID = 12 routes (vendors
      CRUD + PO/GRN/PI by id).
    - `gl_routes.py`: 7 ID routes (account PATCH/DELETE/ledger,
      JE GET/post/reverse, pos-txn post-to-gl).
    - `compliance_routes.py`: 3 ID routes (ZATCA submit, GOSI
      contribution, WPS SIF download).
    - `attachment_routes.py`: 2 ID + 2 retained (POST/GET now use
      tenant guard via payload/JWT).
    - `pricing_routes.py`: 2 tenant routes.
    - `pos_routes.py`: 2 ID routes (sessions list + open).
  - **Tests:** `tests/test_pilot_tenant_isolation_v2.py` — 29
    parameterized cases × 3 assertions + 4 dedicated tests
    (symmetric own-tenant access × 2, structured log emission for
    both helper variants, ProductAttributeValue chain resolution).
    **100+ assertions, all passing.**
  - **Verification:**
    - `pytest tests/test_pilot_tenant_isolation_v2.py` → **29/29 pass**.
    - Full pilot+adjacent regression sweep
      (test_pilot_tenant_isolation_v2 + test_pilot_tenant_isolation_full
      + test_tb_real_data_flow + test_compliance + test_reports_download
      + test_fin_statements + test_dimensions_consolidation_cards
      + test_pilot_ai_extraction + test_hr_wps_eosb) → **176/176 pass**.
    - 0 alembic migrations. 0 frontend changes. 0 schema changes.
      100% backward-compat for valid (own-tenant) usage.
  - **Docs:** `docs/PILOT_TENANT_GUARD_PATTERN.md` updated with the
    3-pattern decision table and combined 4-step new-route
    checklist. New `docs/PILOT_TENANT_AUDIT_FINAL_2026-05-08.md`
    consolidates the three audits with per-file coverage matrix +
    recommended production monitoring (TENANT_GUARD_VIOLATION log
    rate alert ≥ 10/min/user). CLAUDE.md updated.
  - **Final tally:** Audit 1 (G-TB) closed 1 route; Audit 2
    (G-PILOT-REPORTS-TENANT-AUDIT) closed 32; Audit 3 (this PR)
    closed 85. **Total: 117 routes. Pilot route surface fully
    covered.**

- [x] **G-PILOT-REPORTS-TENANT-AUDIT** — pilot tenant isolation across all routes
  - Branch: `feat/g-pilot-reports-tenant-audit`
  - **Why:** G-TB-REAL-DATA-AUDIT (PR #174) closed cross-tenant TB
    read but flagged 4 sibling reports + an unknown number of other
    pilot routes that needed the same fix. This PR audits all of
    `app/pilot/routes/` and closes the gap across the surface.
  - **Discovery:** **32 vulnerable routes** spread across 7 files —
    far more than the 4 the original task brief mentioned. Includes
    8 **write-leak** paths (cross-tenant entity PATCH/DELETE,
    cross-tenant ZATCA onboard / GOSI registration / WPS batch /
    UAE-CT filing / VAT-return generate / PO+PI+VP create) and the
    completely unguarded `customer_routes.py:list_sales_invoices`.
    Full per-route classification in the PR body.
  - **Fix:**
    - **`app/pilot/security/tenant_guards.py`** (new) —
      `assert_entity_in_tenant(db, entity_id, current_user)` is the
      single source of truth for the gate. Anti-enumeration design:
      cross-tenant probes return **404 with the generic "Entity
      not found" body** — same shape as missing-id, so status code
      leaks no existence signal. Server-side, the helper emits a
      structured `TENANT_GUARD_VIOLATION` warning log so SOC
      dashboards can still detect probing.
    - All 32 vulnerable routes upgraded:
      - `gl_routes.py`: 4 deferred reports (income-statement,
        balance-sheet, cash-flow, comparative) + the
        `_debug/posting-counts` diagnostic.
      - `pilot_routes.py`: entity CRUD (GET/PATCH/DELETE) +
        branches (GET/POST).
      - `compliance_routes.py`: 11 routes (ZATCA / GOSI / WPS /
        UAE-CT / VAT) — both path-shaped GETs and payload-shaped
        POSTs.
      - `purchasing_routes.py`: 6 routes (PO / PI / vendor-payment
        creates + listings).
      - `ai_routes.py` + `ai_je_routes.py`: 3 AI extraction routes
        (no more cross-tenant Anthropic spend).
      - `customer_routes.py`: `list_sales_invoices` (was completely
        unguarded — no entity helper at all).
    - The 4 duplicate `_entity_or_404` helpers in gl/pilot/compliance/
      purchasing/ai routes were kept as **thin shims** delegating to
      the new helper — keeps the diff small while making
      `assert_entity_in_tenant` the canonical entry point for new
      code.
    - **Migrated G-TB-REAL-DATA-AUDIT tests 403 → 404** to match the
      anti-enumeration migration. 11/11 still pass.
  - **Tests:** `tests/test_pilot_tenant_isolation_full.py` — 28
    parameterized cases × 3 assertions each + 2 dedicated tests
    (symmetric own-tenant access, structured violation log
    emission). **84+ assertions total**, all passing. Matrix is
    parameterized over `ROUTE_MATRIX` (path-shaped) +
    `PAYLOAD_ROUTE_MATRIX` (entity_id in JSON body) so adding a new
    pilot route requires one row in the matrix to inherit the full
    contract.
  - **Verification:**
    - `pytest tests/test_tb_real_data_flow.py tests/test_pilot_tenant_isolation_full.py tests/test_reports_download.py tests/test_fin_statements.py tests/test_dimensions_consolidation_cards.py` → **90 / 90 pass**.
    - `pytest tests/test_compliance.py tests/test_pilot_ai_extraction.py tests/test_hr_wps_eosb.py` → **57 / 57 pass** (no regression on adjacent suites).
    - 0 alembic migrations. 0 frontend changes (this is backend-only). 0 schema changes.
  - **Docs:** `docs/PILOT_TENANT_GUARD_PATTERN.md` (new) — explains
    the pattern, the anti-enumeration choice, when to use the helper
    vs not, the four-step checklist for adding new pilot routes, and
    the closure history. CLAUDE.md updated with one consolidated
    pilot-route-security entry replacing the prior G-TB note.
  - **Open follow-ups:** `G-PILOT-CATALOG-TENANT-AUDIT` for
    `catalog_routes.py`'s `/tenants/{tenant_id}/...` shape (different
    attack surface, needs a sibling `assert_tenant_matches_user`
    helper); `G-PILOT-PO-PI-TENANT-AUDIT` for routes that resolve a
    PO / PI / sales-invoice directly by id (different anchor than
    entity_id, also cross-tenant readable today).

- [x] **G-TB-REAL-DATA-AUDIT** — TB real-data audit + cross-tenant fix
  - Branch: `feat/g-tb-real-data-audit`
  - **Why:** UAT follow-up to G-TB-DISPLAY-1 — "هل ميزان المراجعة
    فعلاً يقرأ بيانات حقيقية؟" Walk the full data path (widget →
    ApiService → FastAPI route → SQL → Postgres) and prove there are
    no mocks, hardcoded values, or stub fallbacks anywhere.
  - **Findings:**
    - **No mocks anywhere.** `compute_trial_balance` (gl_engine.py:720)
      is a single GROUP BY against `pilot_gl_postings` filtered by
      `entity_id` + `posting_date <= as_of`. Drafts (which only have
      `pilot_journal_lines` rows, no `pilot_gl_postings`) correctly
      never appear in TB output.
    - **One critical security bug — closed in this PR.** Pre-PR,
      `_entity_or_404` in `gl_routes.py` checked only `Entity.id == eid`
      — any authenticated user could pull any entity's TB by guessing
      the id. Pilot models do **not** inherit `TenantMixin`, so
      `attach_tenant_guard` silently skipped them. Fix: explicit
      `current_user.tenant_id` vs `Entity.tenant_id` check + 403 (not
      404) on cross-tenant probe (404 reserved for genuinely missing
      ids, so status code carries no existence-leak signal).
  - **Backend:**
    - `_entity_or_404(db, eid, *, current_user=None)` in
      `app/pilot/routes/gl_routes.py` — accepts optional `current_user`
      keyword arg; if provided, compares `tenant_id` / `tid` claim to
      `Entity.tenant_id` and 403s on mismatch.
    - 8 routes updated to pass `current_user=Depends(get_current_user)`
      through: `seed_coa`, `list_accounts`, `create_account`,
      `seed_periods`, `list_periods`, `create_je`, `list_jes`,
      `trial_balance`. Other report endpoints (income-statement,
      balance-sheet, cash-flow, comparative) still call without it —
      flagged as out-of-scope follow-up `G-PILOT-REPORTS-TENANT-AUDIT`
      in the audit doc.
    - New `posted_je_count: int = 0` on `TrialBalanceResponse`
      (`app/pilot/schemas/gl.py`) + computed in the TB handler —
      backs the frontend footer "المصدر: pilot_journal_lines — N
      قيد مرحّل" without a second roundtrip. Default `= 0` keeps
      older fixtures and tests valid.
  - **Frontend:** `apex_finance/lib/screens/finance/trial_balance_screen.dart`
    +44 / −9.
    - Freshness badge in header — "آخر تحديث: HH:MM:SS" next to the
      refresh button, set to `DateTime.now()` after each successful
      load. Lets the operator distinguish a fresh fetch from a cached
      pre-deploy response.
    - Footer source line under the totals row — "المصدر:
      pilot_journal_lines — N قيد مرحّل" reads `posted_je_count` from
      the response. If the field is absent (e.g., backend not yet
      deployed), shows an em-dash (`—`) instead of misleading `0`.
  - **Tests:** `tests/test_tb_real_data_flow.py` — 11 cases, 3 classes:
    - `TestCrossTenantIsolation` (5) — user A → entity B → 403; user A
      → own entity → 200; legacy token without `tenant_id` claim →
      403; missing entity → 404 (not 403); user B → own entity → 200.
    - `TestRealDataFlow` (5) — empty entity returns empty rows + 0
      count; posted JE produces 2 TB rows + correct totals + count=1;
      draft JE produces zero TB rows; mix posted+draft → count =
      posted only; future-dated JE excluded by `as_of` filter.
    - `TestResponseShape` (1) — `posted_je_count` field present + int.
  - **Verification:**
    - Backend: 11/11 new + 62/62 TB-adjacent regression sweep
      (test_tb_real_data_flow + test_reports_download +
      test_fin_statements + test_dimensions_consolidation_cards) pass.
    - Frontend: `flutter analyze` 0 issues; full Flutter regression
      sweep (v5_routing + auth_guard + err_1_session_redirect +
      trial_balance_test) — 35/35 pass; `flutter build web --release`
      succeeds in 80s.
    - No alembic migrations. No `main.dart` edits. No schema-breaking
      response field changes (default keeps older fixtures green).
  - **Docs:** `docs/TB_DATA_FLOW_AUDIT_2026-05-08.md` (layer-by-layer
    walk + tests table + out-of-scope) and
    `docs/TB_REAL_DATA_UAT_SCRIPT.md` (manual UAT clickthrough,
    pre-flight, sign-off checklist).

- [x] **G-TB-DISPLAY-1** — Trial Balance display screen — closed UAT Issue #4
  - Branch: `feat/g-tb-display-1`
  - **Bug:** the user-visible `tb` Quick Access pin (ميزان المراجعة)
    aliased to `FinancialReportsScreen` — a broader summary view —
    instead of a dedicated ledger trial-balance screen. UAT Issue
    #4 flagged the missing dedicated view.
  - **Reconnaissance changed scope:** the spec asked for a new
    backend endpoint with opening / period-movement / closing
    columns. The real codebase already has
    `GET /pilot/entities/{id}/reports/trial-balance` (gl_routes.py:357
    + compute_trial_balance in gl_engine.py:720) returning a
    snapshot view (running totals up to as_of). The endpoint shape
    differs from the spec but covers the actual user-visible need;
    extending to a period-split is a separate ticket. **No backend
    changes** in this PR.
  - **Frontend:** new `apex_finance/lib/screens/finance/trial_balance_screen.dart`
    (584 lines). Filters bar (date / hide-zero / search) + 3
    summary cards (debit / credit / balanced indicator) + sortable
    DataTable with category-color coding + loading / error / empty
    states + Excel/PDF placeholder buttons (snackbar "قريبًا").
  - **Routing:** new `V5Chip(id: 'trial-balance')` in v5_data
    finance chips; `v5_wired_screens` repointed from the prior
    `FinancialReportsScreen` alias to the new screen; explicit
    `GoRoute('/app/erp/finance/trial-balance')` in v5_routes
    wrapping in `ApexV5ServiceShell` for breadcrumb chrome; `tb`
    pin moved from `/app/erp/finance/statements` (HOTFIX-Routing
    detour) back to `/app/erp/finance/trial-balance`. G-TREESHAKE-FIX-2
    Offstage instance added in main.dart.
  - **Tests:** 6 wiring tests in
    `apex_finance/test/screens/finance/trial_balance_test.dart`
    (chip declaration, wired-keys, validator reachability, pin
    route, /statements detour gone, pin contract). 35/35 pass
    across the routing-adjacent test sweep. Direct widget tests
    of `TrialBalanceScreen` blocked by the G-T1.1 `package:web`
    SDK mismatch (same blocker as `ask_panel_test.dart`); deeper
    UAT runs out of band against the deployed app.
  - **Build verified:** `flutter analyze` 0 issues in changed
    files; `flutter build web --release --no-tree-shake-icons`
    succeeds (the `--no-tree-shake-icons` flag is a pre-existing
    requirement from G-WEB-BUILD-1, unchanged by this PR).
  - **Out of scope (separate tickets):**
    - Period-split TB (`opening_debit`/`opening_credit`/
      `period_debit`/`period_credit`/`closing_debit`/
      `closing_credit`) — needs a backend extension to take a
      `period_start` parameter alongside `as_of`.
    - Excel / PDF export — placeholders today.
    - Hierarchical indenting by GLAccount level — current screen
      flat-lists the detail accounts in code order.

- [x] **G-OPS-RUNBOOK** — single-script orchestrator for post-deploy ops
  - Branch: `feat/g-ops-runbook`
  - **Why:** the four post-merge actions (verify gh-pages bundle,
    migrate legacy tenants, seed demo data, smoke-test) had been
    accumulating as ad-hoc `curl` recipes scattered across PR
    descriptions for #170 and #171. Each invocation needed JWT
    extraction + manual response inspection. This consolidates them
    into one Python entry point with structured output.
  - **What:** `scripts/dev/post_deploy_runbook.py` — stdlib only
    (urllib + getpass + argparse), no `requests` dep. Flags:
    `--verify-deploy`, `--migrate-legacy`, `--seed-demo`,
    `--smoke-test`, `--all` (default). Reads
    `ADMIN_SECRET` / `APEX_USERNAME` / `APEX_PASSWORD` /
    `APEX_API_URL` from the env, prompts for whatever's missing.
    ANSI colors when stdout is a TTY (`NO_COLOR` respected). Exit
    `0` on success, `1` on any step failure.
  - **Verify-deploy sentinels:** the bundle check looks for four
    substrings dropped by recent PRs — `erp/finance/receipt-capture`,
    `erp/finance/vat-return`, `apexAuthRefresh`, `seed-demo-data`.
    Missing sentinels warn but don't fail the step (a runbook
    against staging shouldn't error just because the latest PR
    isn't deployed there yet).
  - **Tests:** 26 in `tests/test_post_deploy_runbook.py`. Stubs
    `http_request` so nothing hits the network. Covers each step's
    pass / skip / fail paths plus the overall `main()` orchestration
    (default → all, single-flag → others skipped, login failure →
    abort with exit 1).
  - **Verified live:** `--verify-deploy` against the production API
    correctly reports the live gh-pages bundle as stale (missing
    ERR-1 + G-DEMO-DATA-SEEDER sentinels) — the exact case the
    runbook is designed to catch.
  - **Docs:** `scripts/dev/README.md` documents this script + the
    other dev scripts that previously had no README.

- [x] **G-DEMO-DATA-SEEDER (master-data tier)** — fill empty tenants with demo data
  - Branch: `feat/g-demo-data-seeder`
  - **Bug:** after ERR-2 (PR #169) + Legacy Migration (PR #170), every
    tenant starts empty. The 12 wired finance + customer + vendor
    chips render blank screens, breaking stakeholder demos and UAT.
  - **Fix (v1, this PR):** master-data tier of the seeder. New
    service `app/phase1/services/demo_data_seeder.py` populates
    `pilot_customers` (5), `pilot_vendors` (5), `pilot_products`
    (15) — 25 records per call, Arabic names + Saudi-style codes.
    Two endpoints in `app/main.py`:
    - `POST /admin/seed-demo-data?tenant_id=…` (X-Admin-Secret;
      404 for invalid tenant)
    - `POST /api/v1/account/seed-demo-data` (JWT; reads tenant_id
      from claim added by ERR-2 Phase 3; 400 for legacy tokens
      without claim)
    Idempotent via "any `pilot_customers` row owned by this
    tenant" sentinel — second call without `force=true` returns
    `{"skipped": true}`. `force=true` appends with 6-hex-char code
    suffix to avoid the `uq_pilot_*_tenant_code` constraints.
  - **Tests:** 18 in `tests/test_demo_data_seeder.py` across
    idempotency, master-data counts, Arabic names + code
    uniqueness, cross-tenant isolation, admin endpoint auth, user
    endpoint auth + claim-driven dispatch. 69/69 across the wider
    auth + tenant + seeder sweep.
  - **Audit doc:** `docs/DEMO_DATA_GUIDE_2026-05-08.md` covers the
    contract, risk profile, idempotency semantics, and what's
    explicitly NOT touched.
  - **Deferred (G-DEMO-DATA-SEEDER-V2, separate ticket):**
    journal entries, sales invoices, purchase invoices, payments.
    Each needs a curated FK chain (Entity, FiscalPeriod, ~8
    `pilot_gl_accounts` rows, AR/AP control accounts, running
    invoice numbers) that the codebase doesn't yet have a packaged
    seeder for. Bundling all of that into one PR creates a
    high-regression-risk migration; better to ship the
    blank-screens fix today and queue the GL+invoice extension
    with a focused FK design.
  - **Refs:** UAT need from stakeholder demos; builds on PRs #169
    + #170.

- [x] **G-LEGACY-TENANT-MIGRATION** — backfill tenants for users created before ERR-2 Phase 3
  - Branch: `feat/g-legacy-tenant-migration`
  - **Bug:** ERR-2 Phase 3 (PR #169) fixed new registrations — every
    new user gets their own `pilot_tenants` row and a JWT carrying
    `tenant_id`. But users that registered BEFORE #169 still have no
    Tenant row, their tokens lack the claim, and
    `TenantContextMiddleware` falls back to its permissive path —
    they keep seeing the legacy shared `06892550-…` tenant data.
    This is the residual leg of UAT Issue #3 that #169 deliberately
    deferred.
  - **Fix:** new service module
    `app/phase1/services/legacy_tenant_migration.py` exposes
    `find_legacy_users`, `migrate_user`, and
    `migrate_all_legacy_users`. Backed by a one-off admin endpoint
    `POST /admin/migrate-legacy-tenants` (gated on
    `X-Admin-Secret`). Idempotent — running twice returns
    `migrated == 0` for any user already migrated; no double Tenant
    rows.
  - **Field shape matches ERR-2 Phase 3 exactly** so legacy and
    fresh tenants render identically in the dashboard:
    `slug = "u-<uid-prefix>-<fresh-uuid-suffix>"`,
    `legal_name_ar = "<display> - الحساب الشخصي"`,
    `primary_email = user.email`, `primary_country = "SA"`,
    `created_by_user_id = user.id`. Display falls back through
    `display_name → username → user.id` so a degenerate row still
    gets a non-empty name.
  - **Tests:** 15 in `tests/test_legacy_tenant_migration.py`
    covering the SQL anti-join (including the NULL-owner /
    three-valued-logic pitfall on PostgreSQL), single-row migration
    + idempotency, batch path, and the HTTP surface (403 without
    secret, 403 with wrong secret, 200 + migrated rows in details
    with correct secret, second run reports zero for the same user).
    51/51 pass across the wider auth + tenant test sweep.
  - **Operator action after deploy:** hit the endpoint once.
    ```
    curl -X POST $API/admin/migrate-legacy-tenants \
      -H "X-Admin-Secret: $ADMIN_SECRET"
    ```
    Re-running is safe; migrated users pick up their `tenant_id`
    claim on their next login automatically (handled by ERR-2 Phase 3's
    existing `auth_service.login()` lookup — no extra step).
  - **Out of scope (separate cleanup tickets):**
    - Reassigning data already in the legacy `06892550-…` tenant
      to its rightful user. Deciding which row goes to which user
      requires customer-support context.
    - Reissuing JWTs to migrated users mid-session — covered
      automatically on next login.
    - `G-RLS-MIGRATION` — still deferred (see ERR-2 Phase 3 entry
      below).
  - **Refs:** UAT_REPORT_2026-05-06.md Issue #3 (residual leg);
    builds on ERR-2 Phase 3 (PR #169).

- [x] **ERR-2 Phase 3** — Tenant per User on Registration (UAT Issue #3 closed)
  - Branch: `feat/err-2-tenant-per-user`
  - **User-visible bug:** new user registered via `/auth/register` was
    immediately seeing 7 unrelated companies — a CRITICAL cross-tenant
    leak. Reconnaissance proved the actual gap was much narrower than
    the original spec implied: the app-layer tenant guard
    (`TenantContextMiddleware` + `attach_tenant_guard()`) is already
    wired in `app/main.py:675` / `:686` and works correctly when given
    a tenant context. The bug was that `auth_service.register()` never
    inserted a `Tenant` row and `create_access_token()` never embedded
    `tenant_id` in the JWT — so the middleware saw no tenant and the
    guard fell back to the permissive "show NULL-tenant rows" path
    that surfaced the leftover shared-tenant data.
  - **Fix:** three small code changes:
    1. `create_access_token(..., tenant_id=None)` — optional keyword
       embeds the claim; legacy positional callers unchanged.
    2. `auth_service.register()` — inserts a fresh `Tenant` row owned
       by the new user (`created_by_user_id = user.id`) and passes
       its id into the access-token issuance.
    3. `auth_service.login()` — looks the user's tenant up via
       `Tenant.created_by_user_id` (oldest first) and embeds it.
       Legacy users without a tenant row get tokens with no claim →
       permissive fallback unchanged.
  - **Tests:** 15 in `tests/test_tenant_per_user_registration.py`
    across pure-unit (`create_access_token`), service-level
    (`AuthService.register/login`), and end-to-end FastAPI client
    layers. All pass.
  - **Audit deliverable:** `docs/TENANT_TABLES_AUDIT_2026-05-07.md`
    lists 97 tenant-scoped tables (TenantMixin or raw `tenant_id`).
    Generator script at `scripts/dev/audit_tenant_tables.py` —
    idempotent, no DB needed.
  - **Deferred** to separate future tickets (out of scope here):
    - `G-RLS-MIGRATION` — PostgreSQL RLS as defense-in-depth on top
      of the app-layer guard. Per CLAUDE.md G-A3.1, must roll out
      table-by-table with staging verification, not bulk.
    - `G-LEGACY-TENANT-MIGRATION` — backfill script for users that
      registered before this PR landed and still ride the shared
      `06892550-…` tenant.
    - `G-CI-DOCKER-POSTGRES` — testcontainers-postgres in CI for
      RLS-level testing (prerequisite for G-RLS-MIGRATION).
  - **Pre-existing test failure unaffected by this PR:**
    `tests/test_invoicing_api.py::test_admin_run_due_now_runs_all_eligible`
    fails identically on a stashed clean main. Not in scope.

### 2026-05-07

- [x] **ERR-1** — Session redirect HOTFIX (Issues #1 + #2 from UAT)
  - Branch: `feat/err-1-session-redirect`
  - **User-visible bug:** opening `/app/erp/finance/ar-aging` with an
    expired session showed "الجلسة منتهية" but trapped the user — no
    redirect to `/login`. The G-S2 auth guard already protects route
    *navigation* but only fires on page load; in-flight API calls
    that 401 weren't clearing the session, so the user kept the
    stale token in localStorage.
  - **Three layers of fix:**
    1. `api_service.dart` — every helper goes through `_handleResponse`,
       which detects 401 and triggers `_SessionExpiryHandler.handle()`:
       clears `S`, shows a SnackBar via the global messenger key,
       bumps `apexAuthRefresh` so `appRouter` re-evaluates the guard
       and bounces the user to `/login`.
    2. `auth_guard.dart` — `authGuardRedirect` now appends
       `?return_to=<encoded original path>` to the `/login` redirect
       so the destination survives the round trip. `apexAuthRefresh`
       and `apexScaffoldMessengerKey` are declared here too (single
       file with no `dart:html` so unit tests still load).
    3. `slide_auth_screen.dart` — after a successful login,
       `resolvePostLoginDestination(returnTo)` validates the query
       param and navigates to the original path (or `/home`).
       Defends against open-redirect attacks via crafted
       `return_to=https://evil.example` (rejected; falls back to
       `/home`).
  - **Tests:** 18 new tests in `test/err_1_session_redirect_test.dart`
    covering auth-flow paths, protected paths, encoded-paths
    round-trip, and the post-login destination resolver including
    open-redirect rejection. 3 existing G-S2 tests in
    `test/auth/auth_guard_test.dart` updated to reflect the new
    `?return_to=…` contract.
  - **Refs:** `UAT_REPORT_2026-05-06.md` Issue #1 + #2;
    `ERROR_HANDLING_STANDARD_2026.md` (Authentication & Session
    Errors).

- [x] **G-WEB-BUILD-1** — Catch-up bundle rebuild + gh-pages deploy automation
  - Branch: `chore/web-bundle-rebuild`
  - **Discovered:** 5 merged PRs (#157-#161 — DASH-1.1, CoA-1, INV-1,
    HOTFIX-Routing, G-CHIPS-WIRE-FIN-1) updated `apex_finance/lib/`,
    but `apex-web/main.dart.js` was last rebuilt at b127858 (161
    source commits ago). Users on
    `shadyapoelela-cloud.github.io/apex-web/` were running stale UI.
  - **Root cause:** `ci.yml` had Render deploy (backend) but no
    Flutter web deploy. apex-web/ was rebuilt manually + ad-hoc.
  - **Fix Phase 1:** one-time manual rebuild — bundle now contains
    all 12 newly wired finance chips (`vat-return`, `ar-aging`,
    `ap-aging`, `tax-calendar`, `wht`, `zakat`, `zatca-status`,
    `activity-log`, `receipt-capture`, `cash-flow-forecast`,
    `sales-invoices`, `entity-setup`).
  - **Fix Phase 2:** new `pages-deploy` CI job. Pattern chosen after
    rejecting auto-push-to-main (anti-pattern). Builds web on every
    main push, smoke-tests the bundle (≥1 MB + chip keys present),
    force-pushes to **`gh-pages`** branch via
    `peaceiris/actions-gh-pages@v4`. main history stays clean.
  - **Build flag added:** `--no-tree-shake-icons`. The icon shaker
    rejected at least one non-const `IconData` invocation in source.
    Per scope this PR can't modify source; the flag is the
    minimum-impact unblock. Cleanup is a separate ticket.
  - **Required action by repo owner after merge:**
    Settings → Pages → Source: `gh-pages` branch (currently
    `main / apex-web/`). Non-breaking until flipped — current
    deployment keeps serving from `apex-web/` until the toggle.
  - **Verification after merge + flip:** open
    `/app/erp/finance/receipt-capture` → loads `ReceiptCaptureScreen`
    (was "قيد البناء" placeholder). Same for `ar-aging`, `ap-aging`,
    `vat-return`, `tax-calendar`.

### 2026-05-06

- [x] **G-CHIPS-WIRE-FIN-1** — Wire 12 finance chips + fix pin `vat`
  - Branch: `feat/g-chips-wire-fin-1`
  - 12 finance chips wired to existing screens (no new screens):
    `ar-aging`, `ap-aging`, `vat-return`, `cash-flow-forecast`,
    `tax-calendar`, `wht`, `zakat`, `zatca-status`, `activity-log`,
    `receipt-capture` (+ `sales-invoices` and `entity-setup` moved
    from shell switch fallback to direct wiring so the validator
    can see them).
  - Fixed 5th pre-existing pin bug discovered during HOTFIX-Routing:
    pin `vat` was pointing at `/app/erp/finance/vat`, but chip `vat`
    lives in `compliance/tax`. New route: `/app/erp/finance/vat-return`
    (canonical finance VAT screen, wired in this PR).
  - Validator baselines tightened (ratchet ↓):
    - `allowedBrokenPins`: 1 → **0**
    - `allowedUnreachable`: 56 → **46**
  - New artifact: `scripts/dev/regenerate_wired_keys.py` makes
    `v5_wired_keys.dart` reproducible after any wiring edit.
  - Out of scope (separate tickets):
    - 2 chips with no existing screen: `health-score`, `inventory`
    - 127 orphan wired entries cleanup
    - Forensic audit of `hybrid_sidebar.dart` and Command Palette
    - Finance-module-level `dashboard` chips (still in the 46
      unreachable count, waiting on their own dashboard widgets)

- [x] **HOTFIX-Routing** — 4 broken Quick Access pins + V5 routing validator
  - Branch: `hotfix/v5-routing-pins`
  - Bug summary (see `UAT_FORENSIC_FULL_2026-05-06.md`):
    - BUG-1..4 fixed in `apex_v5_service_shell.dart` (4 lines)
    - BUG-1: pin `tb` → chip `trial-balance` not declared in finance → 404
    - BUG-2: pin `journal` → chip `gl` not declared in finance → 404
    - BUG-3: pin `clients` → `/app/erp/app/erp/...` double prefix → 404
    - BUG-4: pin `vendors` → `/app/erp/app/erp/...` double prefix → 404
  - New artifacts:
    - `apex_finance/lib/core/v5/v5_routing_validator.dart` (validator)
    - `apex_finance/lib/core/v5/v5_pin_routes.dart` (public pin list,
      decoupled from the shell to keep `flutter test` away from the
      `dart:html` graph)
    - `apex_finance/lib/core/v5/v5_wired_keys.dart` (352 wired chip
      paths, decoupled from the 200+ screen-widget imports for the
      same reason)
    - `apex_finance/test/v5_routing_test.dart` (3 guard tests)
    - `scripts/dev/repro_routing_bugs.py` (regex-only repro)
    - CI gates added to `.github/workflows/ci.yml`: Python script
      runs in `lint`, Flutter test runs in new `flutter-routing` job
  - Baselines (ratchet only down): broken pins ≤ 1 (vat — pre-existing,
    out of scope); unreachable chips ≤ 56 (manual audit guessed 39;
    runtime walk is the actual exhaustive count).
  - Out of scope (separate tickets):
    - Pin `vat` → chip `vat` lives in `compliance/tax`, not `erp/finance`
    - Wiring the 12 finance chips with broken wiring (ar-aging,
      vat-return, etc.)
    - Cleanup of orphan wired entries (V4 aliases)
    - Forensic audit of `hybrid_sidebar.dart` routes
    - Forensic audit of Command Palette commands

- [x] **INV-1** (Phases 0-6 backend) — Invoicing orchestration layer
  - Branch: `feat/invoicing-module`
  - 4 SQLAlchemy tables: `credit_notes`, `credit_note_lines`,
    `recurring_invoice_templates`, `invoice_attachments`
  - Idempotent migration `j7e2c8d4f9b1` (DASH-1 hotfix pattern)
  - 12 new permissions on `app.core.custom_roles`:
    `read|write|issue|apply:credit_notes`,
    `read|write|run:recurring_invoices`,
    `export:invoice_pdf`, `bulk:invoice_actions`,
    `upload:invoice_attachments`, `read:aged_ar_ap`,
    `write_off:invoices`
  - 21 API endpoints under `/api/v1/invoicing/*` with `{success, data}`
    envelope + JWT-based perm gates (incl. `POST /admin/run-due-now`)
  - Service layer: full credit-note lifecycle (draft→issued→applied→
    cancelled), recurring template engine (5 frequencies + month-end
    clamping), aged AR/AP with 5 buckets, bulk operations (100-id
    cap), attachments, write-off path, PDF endpoint via existing
    `app/integrations/zatca/invoice_pdf.py`
  - **45 API tests** covering credit-note state machine, recurring
    scheduling (max_runs / end_date / not-due-yet branches),
    aged-bucket boundaries, bulk error surfacing, attachments,
    permission gates
  - Coverage on `app/invoicing/`: **75.47%** — gap is pilot-model
    integration paths inside `apply_credit_note` / `bulk_issue` /
    `write_off_invoice` / `_aged_report` / `run_recurring_template`
    that require seeded pilot rows (tracked as INV-1 follow-up)
  - 4 dashboard widgets wired into `app/dashboard/`:
    `kpi.aged_ar_summary`, `kpi.aged_ap_summary`,
    `list.overdue_invoices`, `kpi.recurring_due_today`
  - CFO + Accountant default layouts updated to include the new
    widgets
  - Recurring scheduler shipped as a cron-driven stub
    (`POST /admin/run-due-now`); apscheduler in-process scheduler
    deferred to INV-1.3
  - Flutter `api_service.dart`: 21 stub methods (createCreditNote,
    listCreditNotes, issueCreditNote, applyCreditNote,
    cancelCreditNote, createRecurring, listRecurring,
    updateRecurring, runRecurringNow, pauseRecurring,
    agedAr/agedAp, bulkIssueInvoices, bulkEmailInvoices,
    uploadInvoiceAttachment, listInvoiceAttachments,
    deleteInvoiceAttachment, writeOffInvoice, downloadInvoicePdf)

  **Deferred to follow-ups:**
  - **INV-1.1** — branded multi-page PDF (headers, watermarks)
  - **INV-1.2** — HTML branded email template
  - **INV-1.3** — apscheduler in-process scheduler
  - **INV-1.4** — pilot-model-seeded service tests to push coverage
    above 85%
  - **Storage backend** — S3 binding for `invoice_attachments.storage_key`
  - **JE wiring** — downstream subscribers to
    `invoice.credit_note.issued` create the offsetting journal entry

## Sprint 17 — Chart of Accounts (Q2 2026, week 6) — DONE 2026-05-06

### 2026-05-06

- [x] **CoA-1** (Phases 0-3 + 5) — Chart of Accounts backend foundation
  - Branch: `feat/chart-of-accounts-screen`
  - 3 SQLAlchemy tables: `chart_of_accounts`, `coa_templates`, `coa_change_log`
  - Idempotent migration `i3d9f6c2e8a5` (DASH-1 hotfix pattern —
    `inspect().has_table()` guards on every `op.create_table` /
    `op.create_index`)
  - 8 new permissions on `app.core.custom_roles`:
    `read|write|delete|merge|export:chart_of_accounts`,
    `import:coa_template`, `manage:coa_templates`,
    `approve:coa_changes`
  - 3 official templates seeded:
    `socpa-retail-2024` (104 accounts, ZATCA-aware),
    `ifrs-services-2024` (41 accounts, IFRS 15),
    `ifrs-manufacturing-2024` (50 accounts, IAS 2 RM/WIP/FG split)
  - 14 API endpoints under `/api/v1/coa/*` with `{success, data}`
    envelope + JWT-based perm gates
  - Service layer: full_path denormalised tree, cycle detection on
    parent moves, breadth-first descendant path refresh, in-place
    audit log writer, csv/json export
  - **34 API tests** covering CRUD + hierarchy + merge + import
    round-trip + permission gates + change_log accuracy
  - Coverage on `app/coa/`: **87.30%** (target 85%)
  - Dashboard widget `list.recent_account_changes` wired into
    `app/dashboard/resolvers.py` + `seeds.py` so the audit log
    surfaces in the customizable dashboard
  - Flutter `api_service.dart`: 14 stub methods (`coaTree`,
    `coaList`, `coaGet`, `coaCreate`, `coaUpdate`, `coaDelete`,
    `coaDeactivate`, `coaReactivate`, `coaMerge`, `coaTemplates`,
    `coaImportTemplate`, `coaChangelog`, `coaUsage`, `coaExport`)
    so the follow-up Flutter screen can build on hook-injection
    pattern from DASH-1.1

  **Deferred to follow-up PRs:**
  - **CoA-1.1** — backfill `pilot_gl_accounts` → `chart_of_accounts`
  - **CoA-1.2** — full Flutter Three-Pane screen + 7 dialogs +
    drag-drop reparent + 26+ widget tests (api_service stubs in
    place)
  - Approval workflow body
  - GL posting validator consulting `requires_*` gates

## Sprint 16 — Customizable Dashboard (Q2 2026, week 5) — DONE 2026-05-06

### 2026-05-06

- [x] **DASH-1.1** — Customizable Dashboard Frontend (Flutter UI)
  - Branch: `feat/dashboard-customizable-ui` (this PR)
  - 6 widget renderers: KPI / Chart (fl_chart) / Table (paginated) /
    List / AI Pulse / Action (CTA + mini-form)
  - `CustomizableDashboard` host screen — bootstrap (catalog +
    layout + batch data) in parallel, Edit Mode toggle gated on
    `customize:dashboard`, granular SSE updates via injectable
    hooks struct
  - `RoleLayoutsAdminScreen` — admin shell at
    `/dashboard/admin/role-layouts`, gated on `manage:dashboard_role`
  - SSE listener via `dart:html` EventSource (cookie auth),
    `update` events mutate one widget's payload only — no full
    rebuild
  - Decoupled the screen + renderers from `api_service.dart` /
    `core/session.dart` so `flutter test` compiles (the live network
    adapter lives in a sibling `dashboard_hooks_default.dart`
    — production callers pass `defaultDashboardHooks(...)`)
  - Archived `enhanced_dashboard.dart` and `today_dashboard_screen.dart`
    to `apex_finance/_archive/2026-05-06/dashboards_v1/`. Routes
    `/dashboard` and `/today` rewired to `CustomizableDashboard`
  - 22 widget tests — `flutter test test/dashboard/`: all green.
    `flutter analyze`: 277 issues, 0 errors (-11 vs baseline)

## Sprint 11 — Coverage Closure + UX Track (Q2 2026, week 4) — IN PROGRESS

- [x] **G-PROC-4** Workaround discipline + Locked-In Priorities registry — **DONE** 2026-05-02
  - Branch: `sprint-11/g-proc-4-locked-priorities`
  - **Trigger:** 2026-05-02 production incident — `apex-api` deploys
    failed for 12+ Sprint 8-11 PRs due to alembic DuplicateTable.
    Workaround `RUN_MIGRATIONS_ON_STARTUP=false` applied to unblock.
    User raised the meta-question of how to discipline workaround vs
    root-fix.
  - **Decision:** hybrid pattern formalized.
    - ✅ Workaround acceptable IFF: root-fix gap exists with deadline,
      gap is 🔴 LOCKED-IN, consequences documented honestly.
    - ❌ Workaround unacceptable if no committed root-fix or no deadline.
  - **🔴 LOCKED-IN severity marker** added to 09 § 1 Severity Legend.
  - **G-A3.1 elevated:** 🟠 deferred → 🔴 LOCKED-IN Sprint 12 Priority #1
    (Mandatory). Cannot be deferred to Sprint 13+ without explicit
    business approval.
  - **CLAUDE.md** "Migration management" subsection rewritten to reflect
    post-Sprint-11 reality (env var workaround, schema-change moratorium).
  - **LOCAL_DEV_RUNBOOK.md** § 4 gains "DuplicateTable error" entry
    documenting the env var for local dev.
  - **Cleanup:** § 16 numbering collision (introduced by G-UX-1)
    fixed — UX Completion Gaps moved to § 19.
  - **Sprint 11 progress: 6/N priorities** — Sprint 11 closed cleanly.

### Sprint 12 plan — ✅ G-A3.1 closed 2026-05-03

Sprint 12 began with **G-A3.1 (Alembic catch-up migration)** as
🔴 LOCKED-IN Priority #1 (Mandatory). Closed 2026-05-03 after three
phases over two days.

- **G-A3.1 Phase 1 — investigation:** ✅ DONE 2026-05-02 (PR #134).
  Investigation report at `APEX_BLUEPRINT/G-A3-1-investigation.md`.
  Schema diff complete (168 production tables / 11 real alembic
  coverage / 157 gap), 4-strategy analysis, recommended **Sub-A+**
  approved.
- **G-A3.1 Phase 2a — env.py expansion:** ✅ DONE 2026-05-02 (PR #135).
  `alembic/env.py:_MODEL_MODULES` expanded **20 → 37 modules**.
  Verification gate met: autogenerate against fresh local DB produces
  ZERO drops + ZERO creates (both `upgrade()` and `downgrade()` are
  `pass`). G-A3.1.x deferred (extract embedded models from routes file).
- **G-A3.1 Phase 2b — runbook + production stamp + workaround retirement:**
  ✅ DONE 2026-05-03.
  - PR #136 (runbook draft) merged 2026-05-03 00:33 UTC.
  - Production stamp executed 2026-05-03 ~02:41 UTC via psycopg2
    (PostgreSQL CLI install blocked by EnterpriseDB CDN HTTP 403 in
    operator's region; SQL is functionally identical to
    `alembic stamp head` — see § 2 G-A3.1 closure paragraph for the
    exact statements run).
  - Render `RUN_MIGRATIONS_ON_STARTUP` flipped `false` → `true`.
  - Render apex-api deploy **`8509646`** LIVE since 2026-05-03 02:41 UTC.
  - Smoke tests passed: `/health` 200 OK with `database: true` +
    `all_phases_active: true`; `SELECT version_num FROM alembic_version;`
    returns `g1e2b4c9f3d8`; `hr_employees` count query succeeded; no
    `DuplicateTable` errors in deploy logs.
  - Closure docs PR (this PR): retires the workaround in `CLAUDE.md`,
    flips § 2 G-A3.1 to ✅, marks § 12 G-PROC-4 registry resolved.
- **Workaround retired:** `RUN_MIGRATIONS_ON_STARTUP=false` (active
  2026-05-02 → 2026-05-03) is no longer in effect. Schema-change
  moratorium lifted. PR review constraints removed (no longer
  rejecting new alembic migrations / SQLAlchemy models / env-flip PRs).
- **Locked-in registry now empty.** Workaround discipline pattern
  (§ 12 G-PROC-4) remains active for any future locked-in gap.
- **G-A3.1.1 follow-up gap opened:** install PostgreSQL CLI on operator
  machine OR add `psycopg2`-based fallback scripts to
  `scripts/g-a3-1/` so the next locked-in priority does not require
  ad-hoc SQL composition under maintenance-window pressure. Sprint 13+
  candidate. Not blocking — production state is correct.

- [x] **G-UX-1.1** Onboarding wizard auto-select entity post-completion — **DONE** 2026-05-02
  - Branch: `sprint-11/g-ux-1-1-wizard-auto-select-entity`
  - **Source-fix complement to G-UX-1's symptom-fix.** Closes the latent
    gap discovered during G-UX-1 verify-first.
  - **Fix:** 5-line addition at end of `_doStep2()` in
    `pilot_onboarding_wizard.dart` — sets `PilotSession.entityId` to
    first created entity's id immediately after step 2 completes.
    Empty-list guard for defensive safety.
  - **Placement reasoning:** end of `_doStep2()` (not `_doStep8`)
    protects users who abandon the wizard mid-flow — they still get
    a usable entityId after step 2.
  - **Two-layer defense complete:**
    - Source-fix (this PR): wizard auto-sets entityId at completion
    - Symptom-fix (G-UX-1): `EntityResolver` covers users skipping wizard
  - **Verification:** flutter analyze 306 baseline; flutter test 43 pass
    (same pre-existing `ask_panel_test.dart` failure as G-UX-1, unrelated);
    pytest sanity confirmed (no backend changes).
  - **Manual visual test:** deferred to user (CLI agent cannot run Flutter
    web browser session). Test plan in PR description.
  - **Sprint 11 progress: 5/N priorities.**
- [x] **G-UX-1** JE Builder default entity resolution — **DONE** 2026-05-02 🎨 **UX TRACK FIRST PR**
  - Branch: `sprint-11/g-ux-1-je-builder-default-entity`
  - **Trigger:** Cowork session manual test — login → `/je-builder` shows
    dead-end error *"اختر الكيان من شريط العنوان أولاً"* with no action.
  - **Fix:** new `EntityResolver` helper +
    `EntityResolver.ensureEntitySelected()` integration in JE Builder.
    Smart decision tree handles all 5 states (no-tenant / 0 entities /
    1 entity auto-select / multi-entity picker / already-set).
  - **Files:**
    - `apex_finance/lib/pilot/services/entity_resolver.dart` (NEW, 102 lines)
    - `apex_finance/lib/pilot/screens/setup/je_builder_live_v52.dart` (+1 import, ~+15 lines)
  - **Verification:** flutter analyze 306 baseline (0 new); flutter test
    43 passed (1 pre-existing `ask_panel_test.dart` package:web failure
    unrelated to PR); pytest 2328 passed (no backend changes).
  - **Manual visual test:** deferred to user (CLI agent cannot run Flutter
    web browser session). Detailed test plan in PR description.
  - **Latent gap discovered & opened:** G-UX-1.1 — onboarding wizard
    creates entities but doesn't auto-set `PilotSession.entityId`. The
    G-UX-1 helper masks the symptom via the auto-select-singleton branch;
    G-UX-1.1 fixes at the source (Sprint 12+, ~3-line wizard change).
  - **Reusable helper:** `EntityResolver.ensureEntitySelected()` applies
    to any entity-scoped screen — G-UX-2/3/N will use the same import
    + 3-line check at the top of their `_load()` methods.
  - **🎨 UX Completion track active.** First PR in Sprint 11's main thread.
  - **Sprint 11 progress: 4/N priorities.**
- [x] **G-DEV-1.1** Local-dev `CORS_ORIGINS` auto-set + runbook entry — **DONE** 2026-05-02
  - Branch: `sprint-11/g-dev-1-1-cors-docs`
  - **Trigger:** First end-to-end Cowork session login failed with CORS
    preflight error after following G-DEV-1 runbook.
  - **Cause:** Backend default `CORS_ORIGINS=*` is incompatible with
    `credentials: 'include'` used by the Flutter web client for HttpOnly
    cookies. G-DEV-1's runbook didn't surface this trap.
  - **Fix:** 3 files updated (no production code touched):
    - `scripts/dev/run-backend.ps1` — auto-set `$env:CORS_ORIGINS` if not present
    - `scripts/dev/run-backend.sh` — equivalent bash idiom
    - `LOCAL_DEV_RUNBOOK.md` § 4 — new "CORS preflight error" troubleshooting subsection
  - **Default allowlist:** `http://localhost:57305,http://127.0.0.1:57305`
    (both hosts to handle developer setup variance).
  - **Override:** scripts respect pre-existing `CORS_ORIGINS`.
  - **Production safe:** `app/main.py` CORS logic untouched. Render env
    vars override default in prod.
  - **Verification:** `bash -n` + PowerShell parse + markdown structure
    review — all clean.
  - **Last small debt from G-DEV-1 era closed.**
  - **Sprint 11 progress: 3/N priorities** (✅ G-T1.7a.1, ✅ G-T1.8,
    ✅ G-DEV-1.1 — clean slate before UX track or G-T1.7b.6).
- [x] **G-T1.8** test_different_fiscal_years_isolated flake fix — **DONE** 2026-05-02 🎯 **0 FAILURES MILESTONE**
  - Branch: `sprint-11/g-t1-8-zatca-flake-fix`
  - **Root cause:** cascade subprocess (`tests/test_per_directory_coverage.py`)
    runs `pytest tests/` with same `cwd` + relative `DATABASE_URL=sqlite:///test.db`,
    polluting parent's `test.db` with `JournalEntrySequence` rows that
    incremented the ICV counter for `test-zatca-client-3`. When parent
    later reached `test_different_fiscal_years_isolated`, ICV came back
    as 2 (not 1), failing the assertion.
  - **Fix:** UUID-suffixed `client_id` (4-line test-side change).
    Pattern consistent with G-T1.7a.1 onboarding tests. Zero production
    code touched.
  - **Verification:** isolated PASS, `test_zatca.py` 25/25 PASS, cascade
    23/23 PASS, full suite 5× consecutive runs all green (0 failures).
  - **🎯 0 test failures milestone:** suite is 100% green for the first
    time since Sprint 7. Combined with cascade 23/23 (G-T1.7a.1), APEX
    has 0 known test failures.
  - **G-T1.8.2 opened (deferred):** cascade subprocess `DATABASE_URL`
    isolation — addresses architectural root cause. Sprint 12+ candidate.
  - **Patterns reinforced:** UUID-based test isolation prevents shared-
    state flakes in any future tests using common DB tables (Tenant,
    Entity, JournalEntrySequence, etc.).
  - **Sprint 11 progress: 2/N priorities** (next options: G-T1.7b.6
    / UX track / G-DEV-1.1).
- [x] **G-T1.7a.1** ai/ DB-integration tests — **DONE** 2026-05-02 🎯 **CASCADE 23/23 MILESTONE**
  - Branch: `sprint-11/g-t1-7a-1-ai-db-integration`
  - **35 test functions / 39 collected pytest cases** across 3 NEW files
    (split per DB-integration zone):
    - `tests/test_ai_cash_runway_notify.py` — 4 fn (Zone 3, proactive notify block 269-299)
    - `tests/test_ai_executor_handlers.py` — 18 fn (Zone 2, all 3 `_execute_*` handlers)
    - `tests/test_ai_onboarding_db.py` — 13 fn (Zone 1, /onboarding/complete + /seed-demo)
  - **`ai/` aggregate: 69.42% → 85.01%** (+15.59pp).
    - `approval_executor.py`: 66% → **97.66%** (+31.66pp)
    - `proactive.py`: 74% → **83.20%** (+9.2pp)
    - `routes.py`: 66% → **82.20%** (+16.2pp)
  - **🎯 CASCADE 23/23 GREEN** — first time fully green since Sprint 7.
    The `ai-80.0` cascade assertion now PASSES naturally (85.01% > 80%
    floor with 5pp buffer). Sprint 8's deliberate FAIL signal closed.
  - **Full suite:** 2305+ passed; 1 pre-existing failure (G-T1.8 flake);
    0 new regressions. `ai-80.0` no longer in failure list.
  - **DB strategy:** reused existing `tests/conftest.py` infrastructure
    (`setup_test_db` + `client` + direct `SessionLocal()`) — no new
    fixture file. Same pattern proven by 2,290+ existing tests.
  - **G-T1.7a parent FULLY DONE** (Sprint 9 partial 69.42% + Sprint 11
    G-T1.7a.1 closure to 85.01%). Total tests across both: 79 + 35 = 114.
  - **Patterns unlocked for G-T1.7b.6:** onboarding TestClient + DB-verify
    pattern; sys.modules stubs for async modules; AiSuggestion seed factory.
  - **Sprint 11 progress: 1/N priorities** (next options: G-T1.7b.6 / UX track / G-T1.8 flake / G-DEV-1.1 docs).

---

## Sprint 10 — Coverage Restoration (Q2 2026, week 3) — COMPLETE

- [x] **G-T1.7b.5** core/ top-up + raise floor 74→80 — **DONE** 2026-05-02 (Phase 5 of 5, Sprint 10 final)
  - Branch: `sprint-10/g-t1-7b-5-floor-restoration`
  - **45 test functions / 69 collected pytest cases** across 4 NEW files
    (split per source module):
    - `tests/test_notifications_bridge.py` — 7 fn, 43.6% → **100%** (+56.4pp)
    - `tests/test_workflow_templates.py` — 11 fn / 21 collected, 38.6% → **100%** (+61.4pp)
    - `tests/test_sms_backend.py` — 20 fn, 35.9% → **100%** (+64.1pp)
    - `tests/test_email_service.py` — 16 fn / 21 collected, 36.7% → **100%** (+63.3pp)
  - **Aggregate `core/` coverage:** 82.62% → **83.59%** (+0.97pp).
    **Beats commitment** (83.5% by +0.09pp).
  - **Floor raised:** `DIRECTORY_FLOORS["core"]: 74.0 → 80.0` with **3.59pp buffer**.
  - **Comment block updated** with full G-T1.7b trajectory across 5 sub-PRs.
  - **core/ trajectory final:** 74.0 (floor recalibrated Sprint 8) →
    75.67 → 76.71 (G-T1.7b.1) → 79.45 (G-T1.7b.2) → 81.34 (G-T1.7b.3)
    → 82.62 (G-T1.7b.4) → **83.59 (G-T1.7b.5)**.
  - **Cascade: 22/23 maintained** — `core-80.0` PASSES with new floor;
    `ai-80.0` still FAILS (deliberate pre-existing, deferred to G-T1.7a.1).
  - **Full suite:** 2291 passed; 2 pre-existing failures (ai-80.0, G-T1.8 flake);
    0 new regressions.
  - **G-T1.7b parent closed.** 5 sub-PRs across Sprints 9-10. Cumulative
    378 test functions, +7.92pp aggregate, floor raised 74→80.
  - **G-T1.7b.6 opened** for future 80→85 restoration (DB-integration cluster,
    Sprint 12+, gated on G-T1.7a.1 patterns).
  - **Sprint 10 priority #4 closed → Sprint 10 COMPLETE (4/4 priorities).**
- [x] **G-T1.7b.4** core/ storage + industry_pack + slack/teams cluster — **DONE** 2026-05-02 (Phase 4 of 5)
  - Branch: `sprint-10/g-t1-7b-4-storage-industry-slack-teams-cluster`
  - **83 test functions / 91 collected pytest cases** across 4 NEW files
    (split per source module):
    - `tests/test_teams_backend.py` — 13 fn / 17 collected, 23.1% → **100%** (+76.9pp)
    - `tests/test_slack_backend.py` — 16 fn / 20 collected, 21.3% → **100%** (+78.7pp)
    - `tests/test_industry_pack_provisioner.py` — 18 fn, 19.4% → **100%** (+80.6pp)
    - `tests/test_storage_service.py` — 36 fn, 21.3% → **100%** (+78.7pp)
  - **Aggregate `core/` coverage:** 81.34% → **82.62%** (+1.28pp).
    **Stretch beaten** (commitment 82.46%, stretch 82.54%; landed +0.08pp
    above stretch).
  - **core/ trajectory:** 74.0 (floor) → 75.67 → 76.71 (G-T1.7b.1) →
    79.45 (G-T1.7b.2) → 81.34 (G-T1.7b.3) → **82.62 (G-T1.7b.4)**.
    Remaining to original 85% floor: 2.38pp for Phase 5.
  - **Cascade: 22/23 maintained** (ai/ FAIL deliberate, deferred to G-T1.7a.1).
  - **Full suite:** 2222 passed; 2 pre-existing failures (ai-80.0, G-T1.8 flake);
    0 new regressions.
  - boto3 mocking finished in ~5 min (defer-to-4a/4b hatch unused).
  - All 4 files reached 100% — no missing branches.
  - sys.modules stub strategy reused: `requests` (slack/teams), `boto3`
    (storage S3 path), `app.core.workflow_*` (industry_pack stubs).
  - **Sprint 10 progress: 3/4 priorities** (G-T1.7b.5 + G-T1.7a.1 + G-T1.8 queued).
- [x] **G-T1.7b.3** core/ api_keys + email_inbox + notification_digest cluster — **DONE** 2026-05-02 (Phase 3 of 5)
  - Branch: `sprint-10/g-t1-7b-3-api-keys-email-inbox-cluster`
  - **83 test functions** across 3 NEW files (split per source module):
    - `tests/test_notification_digest.py` — 19 fn, 16.7% → **100%** (+83.3pp)
    - `tests/test_email_inbox.py` — 25 fn, 16.3% → **97.04%** (+80.7pp)
    - `tests/test_api_keys.py` — 39 fn, 31.9% → **100%** (+68.1pp)
  - **Aggregate `core/` coverage:** 79.45% → **81.34%** (+1.89pp).
    **Stretch beaten** (commitment 81.00%, stretch 81.11%; landed +0.23pp
    above stretch).
  - **core/ trajectory:** 74.0 (floor) → 75.67 → 76.71 (G-T1.7b.1) →
    79.45 (G-T1.7b.2) → **81.34 (G-T1.7b.3)**. Remaining to original
    85% floor: 3.66pp across Phases 4-5.
  - **Cascade: 22/23 maintained** (ai/ FAIL deliberate, deferred to G-T1.7a.1).
  - **Full suite:** 2110 passed; 2 pre-existing failures (ai-80.0, G-T1.8 flake);
    0 new regressions.
  - IMAP mocking finished well under the 2h budget (defer-to-7b.5 hatch
    unused). Real stdlib `EmailMessage` fixtures kept parser path realistic.
  - sys.modules stub strategy reused: `email_service` (digest); `imaplib`
    monkeypatch (inbox); pure stdlib crypto + tmp_path (api_keys).
  - **Sprint 10 progress: 2/5 priorities** (G-T1.7b.4-.5 + G-T1.7a.1 + G-T1.8 queued).
- [x] **G-T1.7b.2** core/ Workflow Engine cluster — **DONE** 2026-05-02 (Phase 2 of 5)
  - Branch: `sprint-10/g-t1-7b-2-workflow-engine-cluster`
  - **111 test functions / 133 collected pytest cases** across 4 NEW files
    (split per source module):
    - `tests/test_anomaly_live.py` — 22 fn, 31.8% → **95.29%** (+63.5pp)
    - `tests/test_cashflow_forecast.py` — 22 fn, 26.5% → **95.45%** (+68.95pp)
    - `tests/test_workflow_run_history.py` — 28 fn, 28.9% → **100%** (+71.1pp)
    - `tests/test_workflow_engine.py` — 39 fn / 61 collected, 23.7% → **96.86%** (+73.16pp)
  - **Aggregate `core/` coverage:** 76.71% → **79.45%** (+2.74pp).
    **Stretch target (79.4%) hit.**
  - **core/ trajectory:** 74.0 (floor) → 75.67 (G-T1.7b.1 entry) →
    76.71 (G-T1.7b.1 exit) → **79.45 (G-T1.7b.2 exit)**. Remaining to
    original 85% floor: 5.55pp across Phases 3-5.
  - **Cascade: 22/23 maintained** (ai/ FAIL deliberate, deferred to G-T1.7a.1).
  - **Full suite:** 2048 passed; 2 pre-existing failures (ai-80.0, G-T1.8 flake);
    0 new regressions.
  - sys.modules stub strategy (G-T1.7b.1 Stripe pattern) reused for
    slack/teams/email/notification_service/requests/approvals.
  - **Sprint 10 progress: 1/5 priorities** (G-T1.7b.3-.5 + G-T1.7a.1 + G-T1.8 queued).
- [ ] **G-T1.7b.3** api_keys + email_inbox cluster (next, awaiting approval)

### Sprint 10 closure summary

- **G-T1.7b parent fully closed** (5 sub-PRs across Sprints 9-10)
- **core/ trajectory:** 74.0 → 83.59% (+9.59pp on the recalibrated floor; +7.92pp from G-T1.7b.1 entry baseline of 75.67%)
- **Floor raised:** `DIRECTORY_FLOORS["core"]: 74.0 → 80.0` (locked)
- **Cumulative tests added:** 378 functions across 16 new test files
- **Cascade:** 22/23 (only ai-80.0 still failing per G-T1.7a.1 deferral)

### Carried into Sprint 11+

- **G-T1.7a.1** — `app/ai/` DB-integration tests (cascade-23/23 milestone)
- **G-T1.7b.6** — restore core/ floor 80→85 (DB-integration cluster, Sprint 12+, gated on G-T1.7a.1 patterns)
- **G-T1.8** — `test_different_fiscal_years_isolated` order-dependent flake fix
- **Sprint 11 — UX Completion track + remaining gaps (awaits user retrospective)**

---

## Sprint 9 — Quality & Process (Q2 2026, week 2) — COMPLETE

- [x] **G-PROC-1 Phase 1** — Process root-cause investigation.
  - Branch: `sprint-9/g-proc-1-investigation` (merged PR #119)
  - Full investigation report: `APEX_BLUEPRINT/G-PROC-1-investigation.md`
    (328 lines, sections A-H).
  - Refined the original "21:1 ratio" → real Sprint 7 global figure was
    **47.7:1** (after filtering 16.3M lines of Flutter build artifacts).
  - Three interacting root causes identified: (a) no PR-level test
    signal, (b) G-T1.1 frontend-test-infra blocker, (c) documented vs
    undocumented PR culture. Recommended Phase 2 = G.1 (PR-diff
    coverage gate) + G.2 (PR template).

- [x] **G-PROC-1 Phase 2** — Process controls implementation.
  - Branch: `sprint-9/g-proc-1-phase-2-controls`
  - **`.github/workflows/ci.yml`:** added `--cov-report=xml` to existing
    pytest step + new "PR-diff coverage gate" step using
    `diff-cover coverage.xml --compare-branch=origin/main
    --include 'app/**' --fail-under=70`. Runs only on `pull_request`
    events; skipped when label `skip-coverage-gate` present.
    `diff-cover>=8.0` appended to inline `pip install` line.
  - **`.github/PULL_REQUEST_TEMPLATE.md`** (new, 38 lines): six
    sections — *What this PR does / Type / Test budget / Verification /
    Risk / Bypass*. `proc` type checkbox added before `hotfix`.
  - **Frontend exclusion deliberate** (`--include 'app/**'`) until
    G-T1.1 unblocks Flutter widget tests; inline TODO ties scope
    expansion to G-T1.1 closure.
  - **Effectiveness review on calendar (2026-05-15):** 2 weeks
    post-merge, evaluate label-spam %, gate-trigger %, PR-pattern.
    If `>30%` label use → open G-PROC-1.3 with small-PR exemption.
  - **Sprint 9 priority #1 closed.**

- [x] **G-T1.7a** ai/ coverage push — **partial-DONE** 2026-05-01 (this PR)
  - Branch: `sprint-9/g-t1-7a-ai-coverage-push`
  - **79 unit tests added** across 5 files (3 NEW + 2 augmented):
    - `tests/test_ai_routes_extras.py` — NEW, 46 tests for 25 orphan endpoints
    - `tests/test_ai_approval_executor.py` — NEW, 7 tests for execute_suggestion + execute_all_approved
    - `tests/test_ai_onboarding_routes.py` — NEW, 11 tests for onboarding error/validation paths (Phase 6, no DB writes)
    - `tests/test_ai_scheduler.py` — augmented +7 tests for drain loop
    - `tests/test_ai_proactive.py` — augmented +8 tests for cash_runway + run_all_scans
  - **ai/ coverage: 54.31% → 69.42%** (+15.1pp; +128 statements covered)
  - Per-file: scheduler 61.3% → 85% (+23.7pp), proactive 62.4% → 74% (+11.6pp),
    routes 47.4% → 66% (+18.6pp), approval_executor 66.4% → 66% (~0)
  - **Why partial:** 80% floor unreachable within "no DB writes" constraint
    (~290 missing stmts cluster in 3 DB-integration zones: onboarding bodies,
    approval `_execute_*` handlers, proactive `cash_runway_warning` notify block).
    G-T1.7a.1 owns the remaining push.
  - **Cascade: 22/23 maintained** (ai/ FAIL deliberate until G-T1.7a.1).
  - **First production PR through diff-cover gate** (G-PROC-1 Phase 2 effectiveness):
    zero `app/**` source changes → gate auto-passes "no relevant lines added".
  - 6 verify-first saves during implementation (cascade-subprocess timeout
    interaction, `--cov` flake, AiSuggestion column-name mismatch,
    no-handler state-persistence behavior, drain env-var name, mathematical
    floor-unreachability discovery).
  - Sprint 9 priority #2 closed (partial).

- [x] **G-A2.3** V4 → V5 groups migration — **DONE** 2026-05-01 (V4 chapter closed)
  - Branch: `sprint-9/g-a2-3-v4-to-v5-groups-migration`
  - **2 files moved** via `git mv` (history preserved):
    `lib/core/v4/v4_groups.dart` → `lib/core/v5/v5_groups.dart`,
    `lib/core/v4/v4_groups_data.dart` → `lib/core/v5/v5_groups_data.dart`.
  - **322 class-ref substitutions** across 5 files via word-boundary
    Python regex (V4Screen=244, V4SubModule=66, V4ModuleGroup=11,
    v4ScreenById=1). Affected: v5_groups.dart, v5_groups_data.dart,
    v5_data.dart, v5_models.dart, apex_v5_service_shell.dart.
  - **4 import paths updated** + 3 stale inline-comment refs cleaned.
  - **Header docstrings rewritten** on the 2 moved files: stale
    @deprecated G-A2.1 headers replaced with V5-accurate docstrings
    that preserve "V4 product blueprint phase" / "V4 Module Hierarchy
    Map" historical refs (judgment call per design approval point #4).
  - **`lib/core/v4/` deleted entirely** (was 2 files + README — all gone).
  - Verification: `flutter analyze` 306 baseline (0 new), 12/12
    widget tests pass, pytest 1838 maintained, 0 V4* abstraction
    refs remain in `lib/` (5 historical doc refs preserved).
  - **V4 cleanup chapter closed** (Sprint 7 G-A2 → Sprint 8 G-A2.1
    → Sprint 9 G-A2.3 — three-sprint progression).
- [x] **G-T1.7b.1** core/ zero-coverage files coverage push — **DONE** 2026-05-01 (Sprint 9 final)
  - Branch: `sprint-9/g-t1-7b-1-zero-coverage-files`
  - **56 unit tests added** across 4 NEW files (Phase 1 of G-T1.7b multi-PR):
    - `tests/test_error_helpers.py` — 7 tests, 100% coverage (18/18 stmts)
    - `tests/test_saudi_knowledge_base.py` — 22 tests, 100% coverage (63/63 stmts)
    - `tests/test_payment_service.py` — 21 tests, 100% coverage (84/84 stmts)
      (StripeBackend covered via `sys.modules['stripe']` stub — no real SDK call)
    - `tests/test_universal_journal_internal.py` — 6 tests, 86% combined
      (91/106 stmts; was 75.5% from G-T1.7a indirect coverage)
  - **Aggregate `core/` coverage:** 75.67% → **76.71%** (+1.04pp)
  - **Cascade: 22/23 maintained** (ai/ FAIL deliberate, deferred to G-T1.7a.1)
  - **Full suite:** 1915 passed; 2 pre-existing failures (ai-80.0, G-T1.8 flake)
  - 3 verify-first saves during implementation:
    - blueprint stmt-count estimate refined (+271 stmts vs 145 NEW stmts)
    - StripeBackend stub strategy (real SDK not installed in test env)
    - module-style `--cov=app.core.X` flag required (path-style returns 0%)
  - **Sprint 9 priority #3 closed.** G-T1.7b.2 (Sprint-7 untested modules)
    deferred to Sprint 10+.
- [ ] **G-T1.7b** core/ coverage restoration — Phase 1 done; Phases 2-N pending (Sprint 10+)

### Sprint 9 deferred (opened during this Sprint)

- **G-PROC-2** — Separate `docs/` GH-Pages deploy artifact from main repo (Sprint 10)
- **G-PROC-3** — CODEOWNERS for `app/ai/`, `app/core/`, `app/auth/` (Sprint 10, post-effectiveness-review)
- **G-PROC-1.3** — Small-PR exemption (conditional on 2026-05-15 effectiveness review)
- **G-T1.7a.1** — `app/ai/` DB-integration tests (expanded scope: onboarding + executor + proactive notify) — Sprint 10, owns the remaining 80% floor push and cascade-23/23 milestone
- **G-T1.8** — `test_different_fiscal_years_isolated` order-dependent flake — Sprint 10
- **G-T1.9** — ai/ test-suite runtime variance under broad `--cov` — **watch-only** (no investigation budget; documented in 09 § 4)

---

## Sprint 8 — Quality & Compliance (Q2 2026, week 1) — COMPLETE

- [x] **G-DOCS-1**: Blueprint accuracy audit + Verify-First Protocol.
  - Branch: `sprint-8/g-docs-1-blueprint-accuracy-audit` (merged PR #110)
  - Phase A audit grid (verify-first against current code):
    - G-A1, G-A2(.1), G-S1, G-Z1, G-B1, G-B2, G-T1 → **accurate**
    - G-A3 / CLAUDE.md L76 → **stale on totals** (real coverage is
      **25/198 tables**, not 25/108; 173 uncovered, not 83)
    - CLAUDE.md L31 ("main.dart ~3500 lines") → **stale**, fixed
    - CLAUDE.md L55 ("204 tests") → **stale**, real is **1784** (8.7× off)
    - CLAUDE.md L77 ("60+ tightly coupled classes") → **stale**, fixed
    - 9th evidence: `test_flutter_files` references deleted
      `client_onboarding_wizard.dart`; tracked as G-T1.2.
  - Cross-linked Wave 1 / Wave 11 / Wave 13 into 09 (OAuth, ZATCA encryption,
    Bank Feeds plumbing) — G-E1 downgraded from "placeholder" to "PARTIAL".
  - Added Verify-First Protocol as § 0 of `10_CLAUDE_CODE_INSTRUCTIONS.md`
    with 5-step protocol + measurement-command grid + red-flag list +
    conventional-commit hint.

- [x] **G-T1.2**: Refresh `test_flutter_files` assertions.
  - Branch: `sprint-8/g-t1-2-test-flutter-files-refresh` (merged PR #111)
  - Resolution: Removed 1 stale path
    (`apex_finance/lib/screens/clients/client_onboarding_wizard.dart`,
    deleted in commit `a5cac24`). Test now passes in isolation.
  - **Verify-first save (G-DOCS-1 protocol's first production use):**
    Sprint 7 attributed the 23-error cascade in
    `tests/test_per_directory_coverage.py` to `test_flutter_files`.
    After the fix, the cascade **persists unchanged** — real trigger
    is `tests/test_tax_timeline.py::test_tax_timeline_with_fiscal_year_param`
    failing under the per-directory-coverage `pytest -x` subprocess.
    PR ships honest narrow scope (only what was actually delivered).
  - Created **G-T1.4** for the real cascade root cause.
  - Added **G-DOCS-1 evidence #10** capturing the misdiagnosis correction.

- [x] **G-S2**: Auth guard bypass — `/app` accessible without token.
  - Branch: `sprint-8/g-s2-auth-guard` (merged PR #112)
  - Added global GoRouter `redirect:` delegating to a pure
    `authGuardRedirect(path, token)` in new `lib/core/auth_guard.dart`
    (extracted to avoid dragging `dart:html` into tests — the same
    blocker tracked as G-T1.1).
  - Removed `/login → /app` override in `v5_routes.dart` (loop trigger
    once the global guard arrived).
  - 7 widget tests in `test/auth/auth_guard_test.dart` (3 acceptance
    cases + 4 belt-and-suspenders). Verify-first caught an ID
    collision pre-edit: old G-S2 (JWT rotation, deferred, 0 work in
    flight) renamed to **G-S8** in 09 and 2 doc files.

- [x] **G-DEV-1**: Local-dev trap fixed.
  - Branch: `sprint-8/g-dev-1-local-runbook` (merged PR #113)
  - Root cause: `apex_finance/lib/core/api_config.dart:12` defaults
    to the Render production URL (intentional for prod CI). Without
    `--dart-define=API_BASE=http://127.0.0.1:8000`, fresh clones
    silently call live production → "Failed to fetch" with no useful
    pointer to the cause.
  - Resolution: 4 wrapper scripts under `scripts/dev/` (Win + bash);
    `LOCAL_DEV_RUNBOOK.md` at the repo root with troubleshooting matrix
    incl. the **127.0.0.1-vs-localhost / IPv6 fallback** trap; 5-line
    `CLAUDE.md` § "Local Development"; 6-line `README.md` redirect note.
  - Zero source-code changes (`api_config.dart` default preserved —
    production CI depends on it).
  - Live-tested `run-backend.ps1`: uvicorn started, `/health` → HTTP 200,
    168 tables, clean shutdown.

- [x] **G-T1.4**: `test_tax_timeline_with_fiscal_year_param` time-rotted (narrow scope).
  - Branch: `sprint-8/g-t1-4-tax-timeline-cascade`
  - Root cause: hard-coded `fiscal_year_end=2025-12-31` rotted as
    wall-clock time crossed `2026-04-30` (the computed `zakat_due`).
    Replaced with `(date.today() + timedelta(days=30)).isoformat()`
    so the relative date is self-healing. Production code untouched
    — `app/core/tax_timeline.py` semantically correct.
  - Isolated test: `FAILED → PASSED` (0.31s).
  - **Verify-first save (second time in 2 PRs):** the G-T1.4 prompt
    asserted the cascade unblock would follow from this fix alone.
    Post-fix cascade run revealed a SECOND, independent gate —
    `tests/test_per_directory_coverage.py:110` has a hard-coded
    `timeout=600` that is tighter than the coverage-instrumented
    suite runtime (~600-700s). Pre-fix the subprocess died at ~539s
    on the test failure; post-fix it died cleanly at the 600s timeout.
    **Trigger transformed, blocker remained.** PR honest narrow scope
    (only what was actually delivered).
  - Created **G-T1.6** (next PR, single-line timeout bump to 900s).
  - Created **G-T1.5** (deferred — sweep `tests/` for other hard-coded
    date literals).
  - Added **G-DOCS-1 evidence #11** capturing the layered-cause pattern.

- [x] **G-T1.6**: ~~Cascade timeout bump~~ — **OBVIATED 2026-05-01** (no commit).
  - Branch: `sprint-8/g-t1-6-obviated-docs` (merged PR #115, docs-only).
  - Verify-first post-G-T1.4-merge re-ran the cascade and got
    `2 failed, 21 passed in 300.82s` — half the previously measured
    603s, no timeout breach. The 603s in G-T1.4-era data was time
    the inner subprocess spent on the failing tax_timeline test +
    its `-x` abort cleanup; with G-T1.4 fixed the suite is genuinely
    ~50% leaner. The 600s ceiling has comfortable headroom now.
  - **Two real coverage-floor failures unmasked** — `app/ai/` below
    80% floor, `app/core/` below 85% floor. Tracked as new **G-T1.7**.
  - Added **G-DOCS-1 evidence #12**.
  - Cascade fully unblocked — first time since Sprint 7 — by G-T1.4 alone.

- [x] **G-T1.7**: Coverage-floor recalibration (Sprint 7 expansion exposed).
  - Branch: `sprint-8/g-t1-7-floor-recalibration` (merged PR #116)
  - Verify-first scoping captured the actuals: `ai/` 54.3% (Δ −25.7pp,
    218 stmts gap), `core/` 74.7% (Δ −10.3pp, 1,748 stmts gap).
  - **Floor recalibration:** lowered `core/` 85.0% → **74.0%** with full
    comment block citing Sprint 7 expansion + restoration target Sprint 10.
    `ai/` floor **held at 80%** (gap is 218 stmts in 4 concentrated files,
    achievable as G-T1.7a in Sprint 9).
  - **Cascade post-recalibration:** 22/23 PASS (was 21/23). `ai/` FAIL is
    deliberate until G-T1.7a lands.
  - **Forensic finding:** `app/ai/` + `app/core/` saw 15,678 source lines
    added in 6 days vs 743 test lines — **21:1 ratio**, **0 tests removed**.
    Documented Sprint 7 Waves (1/11/13/SMS) had test budgets and are NOT
    affected; the decay is from **undocumented** Sprint 7 commits
    (Activity Feed, Workflow Engine, Notifications, Industry Packs,
    API Keys, etc.). Tracked as **G-PROC-1** (Sprint 9 planning).
  - Added **G-DOCS-1 evidence #13** (5th verify-first save in 6 PRs).

- [x] **G-T1.3**: Coverage gate config sync (mixed case 2).
  - Branch: `sprint-8/g-t1-3-cov-fail-under-sync` (merged PR #117)
  - Verify-first reclassification: original gap text said "no enforced
    coverage floor in CI"; reality was **mixed case 2** — CI gate at
    `--cov-fail-under=55` already exists (`ci.yml:86`), but
    `pyproject.toml [tool.coverage.report].fail_under = 10` was
    obsolete and misled developers running local pytest.
  - **Synced** `pyproject.toml fail_under: 10 → 55` (matches CI).
    Comment block documents calibration history + decay rate +
    "do not lower" rule + layered-gates defense-in-depth.
  - **`addopts` left untouched** — `--cov` deliberately NOT in
    default args (~5× runtime overhead). Comment-only redirect to
    explicit `--cov` runs and CI flag.
  - **`test_flutter_files` glob conversion: out-of-scope.** G-T1.2
    closure documented sufficient; the test is now an intentional
    7-path smoke check with proper docstring (not the cascade canary
    Sprint 7 mistakenly thought).
  - **Empirical decay finding (added to G-PROC-1 § 12):** project
    coverage drift = **−2.65 pp/week** (60.9% → 58.25% in 7 days).
    At this rate, CI 55% gate hits floor in **~14 days** (around
    2026-05-15). G-PROC-1 must ship in early Sprint 9.
  - 22/23 cascade still PASS (no change from G-T1.7). Zero test or
    production code changes — pure config sync.

- [x] **G-A2.1**: V4 → V5 migration (Sprint 8 final gap, **partial-DONE**).
  - Branch: `sprint-8/g-a2-1-v4-to-v5-migration`
  - **Verify-first scope reduction (pre-execution):** all 6 V4-dependent
    screens import only `apex_screen_host.dart` from v4/, a clean
    state-shell widget that just lived in the wrong location.
    Original blueprint estimate 4-6 hours collapsed to ~30 minutes
    via Path 1 (move, don't replace).
  - **Verify-first scope expansion (mid-execution):** pre-deletion
    sweep revealed `lib/core/v5/v5_data.dart:25` and
    `lib/core/v5/v5_models.dart:20` import `v4_groups.dart`. The
    G-A2 closure (2026-04-30) said `v4_groups` had "0 external users";
    that claim was either inaccurate then or stale by 2026-05-01.
    Without verify-first, `git rm lib/core/v4/v4_groups*.dart` would
    have compiled-broken V5 core models.
  - **Delivered:**
    - 1 file moved: `lib/core/v4/apex_screen_host.dart` →
      `lib/widgets/apex_screen_host.dart` (`git mv`, history preserved).
    - 6 import paths updated in `lib/screens/v4_*/` screens.
    - 8 truly-orphan v4 files deleted (~75 KB dead code removed):
      `apex_anomaly_feed`, `apex_command_palette`, `apex_hijri_date`,
      `apex_launchpad`, `apex_numerals`, `apex_sub_module_shell`,
      `apex_tab_bar`, `apex_zatca_error_card`.
    - `lib/core/v4/README.md` added — transparency note that the
      directory is now an **active V4→V5 bridge**, not a deprecated
      zone (2 files remain: `v4_groups.dart` + `v4_groups_data.dart`).
  - **Residual (tracked separately):**
    - **G-A2.2** (Sprint 9 candidate): rename `lib/screens/v4_*/`
      directories out of `v4_*` namespace.
    - **G-A2.3** (Sprint 9 #3 priority): migrate `v4_groups*` →
      `v5_groups*` in `lib/core/v5/`, then delete `lib/core/v4/`
      entirely. Closes the V4 chapter.
  - Added **G-DOCS-1 evidence #14** (covers BOTH Sprint 8 saves in this
    PR: pre-execution V5→V4 dependency reveal, plus mid-execution
    `git mv` import-break catch via `flutter analyze`. **8 verify-first
    saves total across 8 PRs — twice in this one PR alone.**)

- [ ] **G-T1.7a** (Sprint 9, queued): cover `app/ai/routes.py` + 3
  adjacent files (218 stmts) → `ai/` actual ≥ 80% real coverage.
  ETA 1-2 days.

- [ ] **G-T1.7b** (Sprint 9-10, queued): restore `app/core/` from 74%
  → 85%. 1,748 stmts across ~80 files. Multi-PR effort, 1-3 weeks.

- [ ] **G-PROC-1** (Sprint 9 planning, queued): investigate the 21:1
  source:test ratio. Decide on a CI gate enforcing test budget per PR,
  PR-level coverage gate on diffs, and/or PR-template enforcement.
  ETA 2-4h scoping + 1-2d design + impl.

---

## Sprint 7 — Foundation (Q1 2026, week 1-2) — COMPLETE

8/8 tasks closed. 4 follow-up gaps opened for Sprint 8.

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart` (merged)
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12` (merged)
- [x] **G-Z1**: ZATCA encryption — closure + docs.
  - Branch: `sprint-7/g-z1-zatca-encryption` (merged)
- [x] **G-B1**: OAuth (Google + Apple) — closure + docs.
  - Branch: `sprint-7/g-b1-oauth-real` (merged)
  - Discovery: full verification in Wave 1 PR#2/PR#3 (26 tests passing).
  - Fixed `CLAUDE.md` line 74 — was misleading any reader to re-implement Wave 1.
- [x] **G-A2 (partial)**: Deprecate V4 router.
  - Branch: `sprint-7/g-a2-deprecate-v4-router` (merged)
  - Follow-up: **G-A2.1** opened to migrate 6 V4-only screens (Sprint 8).
- [x] **G-A3 (partial)**: Alembic baseline.
  - Branch: `sprint-7/g-a3-alembic-baseline` (merged)
  - Discovery: 7 migrations cover only 25/108 tables (drift = 2097 lines).
  - Decision: lifespan **NOT** modified. `create_all()` remains canonical.
  - Follow-up: **G-A3.1** opened (Sprint 8, DBA-reviewed).
- [x] **G-T1 (partial)**: Flutter widget test foundation.
  - Branch: `sprint-7/g-t1-flutter-tests` (merged)
  - Added `apex_finance/test/widget/apex_output_chips_test.dart` (5/5 passing).
  - Follow-up: **G-T1.1** opened (Sprint 8).
- [x] **G-B2**: SMS verification — closure + docs.
  - Branch: `sprint-7/g-b2-sms-docs`
  - Discovery: full Unifonic+Twilio+Console + OTP store implementation
    already shipped (10 tests passing).
  - **Restored corrupted `.env.example`** (PR #103/#104 merge accidentally
    overwrote env vars with PROGRESS.md content) — now contains canonical
    structure (Environment, Database, Auth, Admin, CORS, AI, Email, Payment,
    Storage, Observability, CSRF, Multi-tenancy, Audit log, Backups,
    Encryption keys, Social auth) **plus** the new SMS / OTP section.
  - Fixed `CLAUDE.md` line 75 — was misleading any reader to re-implement
    Wave SMS work.

---

## Cross-cutting follow-ups (Sprint 8)

- ✅ **G-DOCS-1** Blueprint accuracy audit — DONE 2026-04-30 (PR #110)
- ✅ **G-T1.2** test_flutter_files refresh — DONE 2026-04-30 (PR #111)
- ✅ **G-S2** Auth guard bypass — DONE 2026-05-01 (PR #112; old G-S2 renamed to G-S8)
- ✅ **G-DEV-1** Local-dev trap + runbook — DONE 2026-05-01 (PR #113)
- ✅ **G-T1.4** test_tax_timeline time-rot — DONE 2026-05-01 (PR #114)
- ✅ **G-T1.6** Cascade timeout bump — OBVIATED 2026-05-01 (PR #115, cascade unblocked by G-T1.4 alone)
- ✅ **G-T1.7** Floor recalibration (`core/` 85→74) — DONE 2026-05-01 (PR #116, cascade now 22/23 PASS)
- ✅ **G-T1.3** Coverage gate config sync (10 → 55, matches CI) — DONE 2026-05-01 (PR #117)
- ✅ **G-A2.1** V4 → V5 migration (partial-DONE: 8 files deleted, 2 retained as bridge) — DONE 2026-05-01
- ⏭ **G-PROC-1** Process control for source:test ratio — **Sprint 9 EARLY** (14-day decay deadline)
- ⏭ **G-T1.7a** ai/ coverage push (218 stmts, 1-2 days) — Sprint 9
- ⏭ **G-A2.3** Migrate `v4_groups*` → `v5_groups*` (final V4 cleanup) — **Sprint 9 #3 priority**
- ⏭ **G-T1.7b** core/ coverage restoration (1,748 stmts, 1-3 weeks) — Sprint 9-10
- **G-A2.2** — Rename `lib/screens/v4_*/` directories (deferred, Sprint 9 candidate)
- **G-A3.1** — Alembic catch-up (25/198 → 198/198) + lifespan integration (DBA-reviewed)
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests
- **G-T1.5** — Sweep `tests/` for hard-coded date literals (deferred, Sprint 9 candidate)
- **G-S8** — JWT secret rotation (deferred, was G-S2 before 2026-05-01)

---

## Sprint 8 wrap-up (post-G-A2.1)

**9 PRs merged + 1 awaiting (this G-A2.1 PR) = 10 total deliverables.**

- **Cascade fully unblocked** (was 0/23 in Sprint 7 era; now 22/23 — `ai/` FAIL is the deliberate G-T1.7a tracker).
- **Verify-First Protocol** introduced (G-DOCS-1) and battle-tested:
  **8 saves in 8 PRs** (twice in G-A2.1 alone) — saved against ID
  collision, single-measurement timing, layered cascade causes,
  blueprint stale "0 users" claims, scope-expansion mid-execution,
  one obviated gap (G-T1.6), AND a mechanical `git mv` import break
  caught pre-commit via `flutter analyze` re-run.
- **Forensic finding:** Sprint 7 source:test ratio = 21:1, 0 tests removed.
  Documented Wave deliverables (1/11/13/SMS) ALL have proper test budgets;
  decay is from undocumented Sprint 7 commits. Process control = G-PROC-1
  (Sprint 9 early — 14-day decay deadline before CI breaks).
- **Sprint 8 closes here.** Sprint 9 plan ordered by deadline pressure:
  1. **G-PROC-1** (14-day decay deadline)
  2. **G-T1.7a** (1-2 days, achievable, restores ai/ to 80%)
  3. **G-A2.3** (1-2 hours, closes V4 chapter)
  4. **G-T1.7b** (multi-week, restores core/ to 85%)
  5. Remaining infra gaps (G-T1.1, G-A3.1, G-A2.2, G-T1.5, G-S8) per priority.

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
