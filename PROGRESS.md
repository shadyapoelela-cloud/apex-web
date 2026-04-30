# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2) — COMPLETE

8/8 tasks closed (5 DONE + 3 PARTIAL). 8 branches pushed. 4 follow-up gaps opened.

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart`
- [x] **G-A2 (partial)**: Deprecate V4 router.
  - Branch: `sprint-7/g-a2-deprecate-v4-router`
  - Follow-up: **G-A2.1** — migrate 6 V4-only screens (Sprint 8).
- [x] **G-A3 (partial)**: Alembic baseline.
  - Branch: `sprint-7/g-a3-alembic-baseline`
  - Discovery: 7 migrations cover only 25/108 tables. Lifespan untouched.
  - Follow-up: **G-A3.1** — full alembic catch-up (Sprint 8, DBA-reviewed).
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12`
- [x] **G-T1 (partial)**: Flutter widget test foundation.
  - Branch: `sprint-7/g-t1-flutter-tests`
  - Blocker: `package:web` 1.1.1 vs Flutter 3.27.4.
  - Follow-up: **G-T1.1** — fix infra + ship login/register/onboarding tests.
- [x] **G-Z1**: ZATCA private key encryption — closure + docs.
  - Branch: `sprint-7/g-z1-zatca-encryption`
  - Discovery: full Fernet-at-rest in Wave 11. Docs added.
- [x] **G-B1**: OAuth (Google + Apple) — closure + docs.
  - Branch: `sprint-7/g-b1-oauth-real`
  - Discovery: full verification in Wave 1 PR#2/PR#3. Docs added + CLAUDE.md fix.
- [x] **G-B2**: SMS verification — closure + docs.
  - Branch: `sprint-7/g-b2-sms-real`
  - Discovery: full Unifonic+Twilio+Console + OTP store implementation already
    shipped (10 tests passing). Docs added + CLAUDE.md fix.

---

## Cross-cutting follow-ups (Sprint 8)

- **G-DOCS-1** ⭐ Blueprint accuracy audit — **MUST be the first item**
  (7 contradictions documented in Sprint 7).
- **G-A2.1** — Migrate 6 V4-only screens to V5.
- **G-A3.1** — Alembic catch-up + lifespan integration (DBA-reviewed).
- **G-T1.1** — Fix Flutter test infra; ship login/register/onboarding tests.

---

## Critical Discovery — The Blueprint Drift Pattern

7 of 8 Sprint 7 gaps had blueprint claims that contradicted code reality. APEX
is significantly more mature than the blueprint suggests. The biggest
deliverable of Sprint 7 is surfacing this disconnect (G-DOCS-1) — without it,
Sprint 8 risks repeating the same wasted scoping work.

| # | Gap | Blueprint claimed | Actual reality |
|---|-----|------------------|----------------|
| 1 | G-A1 | 3500 lines | 2146 lines |
| 2 | G-A2 | "no V4-only screens expected" | 6 V4-only screens active |
| 3 | G-A3 | "no migration files yet" | 7 migrations exist (head g1e2b4c9f3d8) |
| 4 | G-S1 | "rounds=10" | bcrypt 5.0 default=12 |
| 5 | G-Z1 | "ZATCA keys plaintext" | Wave 11 Fernet-at-rest done |
| 6 | G-B1 | "Social auth stubs" | Wave 1 google-auth + PyJWT + 26 tests |
| 7 | G-B2 | "SMS stubs return success" | Unifonic+Twilio+OTP store + 10 tests |

---

## Blockers

(none active — all follow-ups deferred to Sprint 8 by design)
