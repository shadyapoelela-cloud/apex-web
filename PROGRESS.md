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
  - Branch: `sprint-7/g-a2-deprecate-v4-router`
  - Deleted: `apex_finance/lib/core/v4/v4_routes.dart` (resolved /app conflict).
  - Updated: `apex_finance/lib/core/router.dart` (removed import + spread).
  - Added `@deprecated` header to all 11 remaining V4 files.
  - `flutter analyze`: 0 errors. `flutter build web --no-tree-shake-icons`: ✓.
  - Deviation from plan: kept `v4_groups.dart`/`v4_groups_data.dart` because
    deleting them would break 4 widgets the user explicitly listed as keep.
  - Audit surprise: 6 V4-only screens with no V5 equivalent (now unreachable).
  - Follow-up: **G-A2.1** opened to migrate the 6 screens to V5 in Sprint 8.
- [ ] G-A3 (partial): Alembic baseline
- [ ] G-T1 (partial): Flutter widget tests
- [ ] G-B2: SMS (docs)

---

## Blockers

(none active)
