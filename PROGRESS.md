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
  - **Decision:** lifespan **NOT** modified. `create_all()` remains canonical.
  - **Follow-up:** **G-A3.1** opened — full alembic catch-up (Sprint 8, DBA-reviewed).
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12`
  - **Audit finding:** bcrypt 5.0.0 already defaults to 12; old code was implicit.
  - Made `BCRYPT_ROUNDS = 12` explicit in `auth_service.py`.
  - Added `password_needs_rehash()` helper.
  - Wired rehash into `AuthService.login()` and TOTP recovery codes.
  - 7 new tests pass; 21 existing auth tests still pass.
- [ ] G-B1: Real Google + Apple OAuth
- [ ] G-B2: Real SMS via Twilio + Unifonic
- [ ] G-Z1: Encrypt ZATCA private keys
- [ ] G-T1: First Flutter widget tests

---

## Blockers

(none active — G-A2.1 and G-A3.1 deferred to Sprint 8 by design)
