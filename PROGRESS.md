# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2)

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart` (PR open)
- [x] **G-A2 (partial)**: Deprecate V4 router.
  - Branch: `sprint-7/g-a2-deprecate-v4-router` (PR open)
  - Follow-up: **G-A2.1** (Sprint 8) — migrate 6 V4-only screens.
- [x] **G-A3 (partial)**: Alembic baseline.
  - Branch: `sprint-7/g-a3-alembic-baseline` (PR open)
  - Discovery: 7 migrations cover only 25/108 tables (drift = 2097 lines).
  - Lifespan untouched (would have deployed prod with 83 missing tables).
  - Follow-up: **G-A3.1** (Sprint 8, DBA-reviewed).
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12` (PR open)
  - 7 new tests + 21 existing auth tests passing.
- [x] **G-T1 (partial)**: Flutter widget test foundation.
  - Branch: `sprint-7/g-t1-flutter-tests` (PR open)
  - 5 widget tests passing (`apex_output_chips_test.dart`).
  - Blocker: `package:web` 1.1.1 vs Flutter 3.27.4 — see G-T1.1.
- [x] **G-Z1**: ZATCA private key encryption — closure + docs.
  - Branch: `sprint-7/g-z1-zatca-encryption` (PR open)
  - Discovery: Fernet-at-rest implemented in Wave 11 (31 tests passing).
  - Sprint 7 contribution: documented 3 missing Fernet keys in `.env.example`.
- [x] **G-B1**: OAuth (Google + Apple) — closure + docs.
  - Branch: `sprint-7/g-b1-oauth-real`
  - Discovery: full token verification implemented in Wave 1 PR#2/PR#3
    (`google-auth.verify_oauth2_token()` + `PyJWT` against Apple JWKS,
    26 passing tests).
  - Sprint 7 contribution:
    - Added `GOOGLE_OAUTH_CLIENT_ID` + `APPLE_CLIENT_ID` to `.env.example`.
    - **Fixed `CLAUDE.md` line 74** — was actively misleading any reader to
      think the tokens were stubbed; would have led to redundant or breaking
      re-implementation.
  - Side effect: opened **G-DOCS-1** evidence count to 6 misses.
- [ ] G-B2: Real SMS via Twilio + Unifonic (next)

---

## Cross-cutting follow-ups (Sprint 8)

- **G-A2.1** — Migrate 6 V4-only screens to V5
- **G-A3.1** — Alembic catch-up + lifespan integration (DBA-reviewed)
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests
- **G-DOCS-1** — Blueprint accuracy audit (run BEFORE any P0/P1)

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
