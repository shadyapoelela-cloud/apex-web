# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2)

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart` (merged)
  - 5 refactor + 1 docs commit.
  - Notable decision: extracted helpers renamed to `compactCard`/`compactKv`/`compactBadge`
    to avoid collision with `core/theme.dart`'s visually different
    `apexCard`/`apexBadge`. Future task: unify into one design system.
- [x] **G-S1**: bcrypt rounds → 12 explicit + opportunistic rehash.
  - Branch: `sprint-7/g-s1-bcrypt-12`
  - Audit finding: bcrypt 5.0.0 already defaults to 12; old code was implicit.
  - Made `BCRYPT_ROUNDS = 12` explicit in `auth_service.py`.
  - Added `password_needs_rehash()` helper.
  - Wired rehash into `AuthService.login()` and TOTP recovery codes.
  - 7 new tests pass; 21 existing auth tests still pass.
- [ ] G-A2 (partial): Deprecate V4 router
- [ ] G-A3 (partial): Alembic baseline
- [ ] G-T1 (partial): Flutter widget tests
- [ ] G-Z1: ZATCA encryption (docs)
- [ ] G-B1: OAuth (docs)
- [ ] G-B2: SMS (docs)

---

## Blockers

(none active)