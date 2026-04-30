# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2)

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart` (PR open)
  - 5 refactor + 1 docs commit.
- [x] **G-A2 (partial)**: Deprecate V4 router.
  - Branch: `sprint-7/g-a2-deprecate-v4-router` (PR open)
  - Deleted `v4_routes.dart`; `@deprecated` headers on 11 remaining V4 files.
  - Audit surprise: 6 V4-only screens with no V5 equivalent → **G-A2.1** opened (Sprint 8).
- [x] **G-A3 (partial)**: Alembic baseline.
  - Branch: `sprint-7/g-a3-alembic-baseline` (PR open)
  - **Discovery:** 7 migrations exist but cover only 25/108 tables (drift = 2097 lines).
  - Decision: lifespan **NOT** modified. `create_all()` remains canonical.
  - Follow-up: **G-A3.1** opened — full alembic catch-up (Sprint 8, DBA-reviewed).
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12` (PR open)
  - Audit finding: bcrypt 5.0.0 already defaults to 12; old code was implicit.
  - 7 new tests pass; 21 existing auth tests still pass.
- [x] **G-T1 (partial)**: Flutter widget test foundation.
  - Branch: `sprint-7/g-t1-flutter-tests` (PR open)
  - Added `apex_output_chips_test.dart` (5/5 passing).
  - Blocker: `package:web` 1.1.1 vs Flutter 3.27.4 prevents api-touching screen tests.
  - Follow-up: **G-T1.1** opened (Sprint 8).
- [x] **G-Z1**: ZATCA private key encryption — closure + docs.
  - Branch: `sprint-7/g-z1-zatca-encryption`
  - **Discovery:** Encryption fully implemented in Wave 11 (Fernet at rest +
    `ZATCA_CERT_ENCRYPTION_KEY` + env_validator gate + 31 passing tests).
  - **Sprint 7 contribution:** docs-only fix to `.env.example` adding the 3
    missing Fernet keys (`ZATCA_CERT_ENCRYPTION_KEY`, `TOTP_ENCRYPTION_KEY`,
    `BANK_FEEDS_ENCRYPTION_KEY`) + generation instructions.
  - Side effect: opened **G-DOCS-1** for a full blueprint accuracy audit
    (5 wrong claims found in Sprint 7).
- [ ] G-B1: Real Google + Apple OAuth (next)
- [ ] G-B2: Real SMS via Twilio + Unifonic

---

## Cross-cutting follow-ups (Sprint 8)

- **G-A2.1** — Migrate 6 V4-only screens to V5
- **G-A3.1** — Alembic catch-up + lifespan integration (DBA-reviewed)
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests
- **G-DOCS-1** — Blueprint accuracy audit (run BEFORE any P0/P1 in Sprint 8)

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
