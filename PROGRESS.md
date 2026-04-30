# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2)

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart` (merged)
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12` (merged)
- [x] **G-Z1**: ZATCA private key encryption — closure + docs.
  - Branch: `sprint-7/g-z1-zatca-encryption` (merged)
- [x] **G-B1**: OAuth (Google + Apple) — closure + docs.
  - Branch: `sprint-7/g-b1-oauth-real` (merged)
  - Discovery: full verification in Wave 1 PR#2/PR#3 (26 tests passing).
  - Fixed `CLAUDE.md` line 74 — was misleading any reader to re-implement Wave 1.
- [x] **G-A2 (partial)**: Deprecate V4 router.
  - Branch: `sprint-7/g-a2-deprecate-v4-router` (merged)
  - Deleted: `apex_finance/lib/core/v4/v4_routes.dart` (resolved /app conflict).
  - `@deprecated` headers on 11 remaining V4 files.
  - Follow-up: **G-A2.1** opened to migrate 6 V4-only screens (Sprint 8).
- [x] **G-A3 (partial)**: Alembic baseline.
  - Branch: `sprint-7/g-a3-alembic-baseline`
  - **Discovery:** 7 migrations exist but cover only 25/108 tables (drift = 2097 lines).
  - **Decision:** lifespan **NOT** modified. `create_all()` remains canonical.
    Replacing it would deploy production with 83 missing tables.
  - **Follow-up:** **G-A3.1** opened — full alembic catch-up + DBA-reviewed cutover (Sprint 8).
  - Drift archived: `APEX_BLUEPRINT/_archive/2026-04-30_alembic_drift.txt`.
- [ ] G-T1 (partial): Flutter widget tests
- [ ] G-B2: SMS (docs)

---

## Blockers

(none active — G-A3.1 deferred to Sprint 8 by design)
