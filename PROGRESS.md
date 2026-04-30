# APEX Sprint Progress

## Sprint 7 — Foundation (Q1 2026, week 1-2)

- [x] **G-A1**: Split `apex_finance/lib/main.dart` (2146 → 21 lines).
  - Branch: `sprint-7/g-a1-split-main-dart`
  - Commits: 5 (auth · shell · forms · tabs-1 · tabs-2)
  - Result: `flutter analyze` 0 errors · `flutter build web --no-tree-shake-icons` ✓
  - Notable decision: extracted `_card`/`_kv`/`_badge` helpers renamed to
    `compactCard`/`compactKv`/`compactBadge` to avoid collision with the
    visually different `apexCard`/`apexBadge` already present in
    `core/theme.dart`. Future task: unify into one design system.
  - Pre-existing tree-shake-icons warning (dynamic IconData usage elsewhere
    in the codebase) is unrelated to G-A1; build completes with the standard
    workaround flag.
- [ ] G-A2: Deprecate V4 router
- [ ] G-A3: Alembic baseline migration
- [ ] G-S1: bcrypt rounds 10 → 12
- [ ] G-B1: Real Google + Apple OAuth
- [ ] G-B2: Real SMS via Twilio + Unifonic
- [ ] G-Z1: Encrypt ZATCA private keys
- [ ] G-T1: First Flutter widget tests

---

## Blockers

(none for G-A1)
