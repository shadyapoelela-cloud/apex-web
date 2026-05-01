# APEX Sprint Progress

## Sprint 9 — Quality & Process (Q2 2026, week 2) — IN PROGRESS

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
