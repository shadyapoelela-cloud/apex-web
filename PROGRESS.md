# APEX Sprint Progress

## Sprint 8 — Quality & Compliance (Q2 2026, week 1) — IN PROGRESS

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
  - Branch: `sprint-8/g-t1-6-obviated-docs` (docs-only PR, no code change).
  - Verify-first post-G-T1.4-merge re-ran the cascade and got
    `2 failed, 21 passed in 300.82s` — half the previously measured
    603s, no timeout breach. The 603s in G-T1.4-era data was time
    the inner subprocess spent on the failing tax_timeline test +
    its `-x` abort cleanup; with G-T1.4 fixed the suite is genuinely
    ~50% leaner. The 600s ceiling has comfortable headroom now.
  - **Two real coverage-floor failures unmasked** — `app/ai/` below
    80% floor, `app/core/` below 85% floor. Tracked as new **G-T1.7**
    (verify-first scoping in a separate session).
  - Added **G-DOCS-1 evidence #12**: cascade was the **fourth**
    verify-first save in five PRs. Pattern: prompts based on
    snapshot timing data may misread one-off measurements as
    steady-state. Always re-measure post-fix before scoping the
    "next" gap built on it.
  - Cascade fully unblocked — first time since Sprint 7 — by
    G-T1.4 alone.

- [ ] **G-T1.7** (next): real coverage-floor failures in `app/ai/`
  (< 80%) and `app/core/` (< 85%). Verify-first scoping required
  before any code change — measure the actual Δ and decide between
  single PR / split PRs / Sprint-9 budget.

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
- ✅ **G-T1.6** Cascade timeout bump — OBVIATED 2026-05-01 (cascade fully unblocked by G-T1.4 alone)
- ⏭ **G-T1.7** Coverage floors for `app/ai/` (<80%) + `app/core/` (<85%) — NEXT (verify-first scoping required)
- **G-A2.1** — Migrate 6 V4-only screens to V5
- **G-A3.1** — Alembic catch-up (25/198 → 198/198) + lifespan integration (DBA-reviewed)
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests
- **G-T1.3** — Test infra flake + coverage thresholds (4-6 hours)
- **G-T1.5** — Sweep `tests/` for hard-coded date literals (deferred, Sprint 9 candidate)
- **G-S8** — JWT secret rotation (deferred, was G-S2 before 2026-05-01)

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
