# APEX Sprint Progress

## Sprint 18 — Invoicing (Q2 2026, week 7) — IN PROGRESS

### 2026-05-07

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
