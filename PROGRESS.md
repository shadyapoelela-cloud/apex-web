# APEX Sprint Progress

## Sprint 8 — Quality & Compliance (Q2 2026, week 1) — IN PROGRESS

- [x] **G-DOCS-1**: Blueprint accuracy audit + Verify-First Protocol.
  - Branch: `sprint-8/g-docs-1-blueprint-accuracy-audit`
  - Phase A audit grid (verify-first against current code):
    - G-A1, G-A2(.1), G-S1, G-Z1, G-B1, G-B2, G-T1 → **accurate**
    - G-A3 / CLAUDE.md L76 → **stale on totals** (real coverage is
      **25/198 tables**, not 25/108; 173 uncovered, not 83)
    - CLAUDE.md L31 ("main.dart ~3500 lines") → **stale**, fixed
    - CLAUDE.md L55 ("204 tests") → **stale**, real is **1784** (8.7× off)
    - CLAUDE.md L77 ("60+ tightly coupled classes") → **stale**, fixed
    - 9th evidence: `test_flutter_files` references deleted
      `client_onboarding_wizard.dart` — cascaded 23 unrelated test errors;
      tracked as G-T1.2.
  - Cross-linked Wave 1 / Wave 11 / Wave 13 into 09 (OAuth, ZATCA encryption,
    Bank Feeds plumbing) — G-E1 downgraded from "placeholder" to "PARTIAL".
  - Added Verify-First Protocol as § 0 of `10_CLAUDE_CODE_INSTRUCTIONS.md`
    with 5-step protocol + measurement-command grid + red-flag list +
    conventional-commit hint.

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

- ✅ **G-DOCS-1** Blueprint accuracy audit — DONE 2026-04-30
- **G-A2.1** — Migrate 6 V4-only screens to V5
- **G-A3.1** — Alembic catch-up (25/198 → 198/198) + lifespan integration (DBA-reviewed)
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests
- **G-T1.2** — Refresh `test_flutter_files` to current screen tree (30 min)
- **G-T1.3** — Test infra flake + coverage thresholds (4-6 hours)

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
