# Sprint 7 — Final Report (Q1 2026)

**Period:** 2026-04-30 (single multi-task session)
**Tasks closed:** 8 of 8 (5 ✅ DONE · 3 ⚠️ PARTIAL — by design)
**Branches pushed to `origin`:** 8
**Follow-up gaps opened for Sprint 8:** 4

---

## Tasks Summary

| # | ID | Title | Status | Branch |
|---|-----|-------|--------|--------|
| 1 | G-A1 | Split `apex_finance/lib/main.dart` 2146→21 lines | ✅ DONE | `sprint-7/g-a1-split-main-dart` |
| 2 | G-A2 | Deprecate V4 router | ⚠️ PARTIAL | `sprint-7/g-a2-deprecate-v4-router` |
| 3 | G-A3 | Alembic baseline / lifespan integration | ⚠️ PARTIAL | `sprint-7/g-a3-alembic-baseline` |
| 4 | G-S1 | bcrypt rounds=12 explicit + opportunistic rehash | ✅ DONE | `sprint-7/g-s1-bcrypt-12` |
| 5 | G-T1 | Flutter widget test foundation | ⚠️ PARTIAL | `sprint-7/g-t1-flutter-tests` |
| 6 | G-Z1 | ZATCA private-key encryption (closure + docs) | ✅ DONE | `sprint-7/g-z1-zatca-encryption` |
| 7 | G-B1 | OAuth verification (closure + docs) | ✅ DONE | `sprint-7/g-b1-oauth-real` |
| 8 | G-B2 | SMS verification (closure + docs) | ✅ DONE | `sprint-7/g-b2-sms-real` |

---

## Code Changes

| File / area | Before | After | Δ |
|---|---:|---:|---|
| `apex_finance/lib/main.dart` | 2146 lines | **21 lines** | **−99%** |
| Extracted Flutter files | 0 | 14 | auth/widgets/screens/tabs |
| `app/phase1/services/auth_service.py` | implicit bcrypt | explicit `BCRYPT_ROUNDS=12` + `password_needs_rehash()` + login rotation | security |
| `app/core/totp_service.py` | implicit bcrypt | imports `BCRYPT_ROUNDS` for recovery codes | consistency |
| `apex_finance/lib/core/v4/v4_routes.dart` | exists | deleted (resolves `/app` conflict with V5) | router cleanup |
| 11 remaining V4 files | undocumented | `@deprecated` headers | follow-up tracked |

## Documentation Changes

| File | What changed |
|---|---|
| `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md` | 8 gaps marked DONE/PARTIAL with file maps; **4 new gaps opened** (G-A2.1, G-A3.1, G-T1.1, G-DOCS-1) |
| `CLAUDE.md` | Two highest-risk "Common Pitfalls" lines fixed: line 74 (OAuth) + line 75 (SMS) |
| `.env.example` | **13+ env vars added**: 3 Fernet keys, 2 OAuth IDs, 8 SMS/OTP settings |
| `PROGRESS.md` | Created — sprint-level status tracker |
| `docs/MIGRATION_DEPLOY_NOTE.md` | (referenced from G-A3 partial — see branch for content) |
| `APEX_BLUEPRINT/_archive/2026-04-30_alembic_drift.txt` | 2097-line drift diff archived for G-A3.1 |

## Tests

| Suite | Before | After | Δ |
|---|---:|---:|---|
| Backend `pytest` | 204 baseline | **211** | +7 (`test_password_rotation.py`) |
| Flutter widget | 0 working | **5** | +5 (`apex_output_chips_test.dart`) |
| Confirmed-passing pre-existing suites re-run for no-regression | — | 31 (ZATCA CSID), 26 (social auth), 10 (SMS OTP), 21 (auth/refresh) | 88 verified |

---

## 🎯 Critical Discovery — The Blueprint Drift Pattern

**7 of 8 Sprint 7 gaps had blueprint claims that contradicted the code.** The platform is significantly more mature than the blueprint suggests. The biggest deliverable of this sprint is surfacing the disconnect via **G-DOCS-1**.

| # | Gap | Blueprint claimed | Reality |
|---|-----|-------------------|---------|
| 1 | G-A1 | "3500 lines" | 2146 lines (out by 35%) |
| 2 | G-A2 | "no V4-only screens expected" | 6 V4-only screens active; `v4_groups` deletion plan would have broken 4 widgets |
| 3 | G-A3 | "no migration files yet" | 7 migrations exist (chain head `g1e2b4c9f3d8`) — but covering only 25/108 tables (separate gap G-A3.1) |
| 4 | G-S1 | "bcrypt rounds = 10" | bcrypt 5.0.0 default has been 12 since lib v4.0 |
| 5 | G-Z1 | "ZATCA keys plaintext" | Wave 11 implemented Fernet-at-rest with `ZATCA_CERT_ENCRYPTION_KEY` + 31 passing tests |
| 6 | G-B1 | "Social auth tokens NOT validated -- stubs only" | Wave 1 PR#2/PR#3 implemented `google-auth.verify_oauth2_token()` + PyJWT against Apple's JWKS + 26 passing tests |
| 7 | G-B2 | "SMS verification endpoints are stubs -- always return success" | `sms_backend.py` (Unifonic + Twilio + Console) + `otp_store.py` (TTL/attempts/hash-at-rest) + 10 passing tests |

### What this would have cost without verify-first

- **G-A3 naive execution** would have replaced `Base.metadata.create_all()` (creates 108 tables) with `alembic upgrade head` (creates only 25). Next deploy on a fresh DB → production with **83 missing tables**.
- **G-B1 / G-B2 naive execution** would have collided with working Wave 1 / Wave code, almost certainly breaking auth flows that already had 26 + 10 passing tests.

### Recommended remediation

**Sprint 8 must START with G-DOCS-1.** Estimate: 4-6 hours. Without it Sprint 8 risks repeating Sprint 7's pattern of "fix something already fixed." The audit should:
1. Mark every P0/P1 gap as `accurate` / `stale` / `done-but-undocumented`.
2. Re-audit `CLAUDE.md` "Common Pitfalls" end-to-end (more stale lines suspected — line 31 "main.dart 3500 lines" + line 76 "Alembic empty" + the 204-test count).
3. Cross-link Wave 1 / Wave 11 / Wave 13 deliverables back into 09 so completed work is visible in the gap tracker.
4. Add a verify-first protocol to `10_CLAUDE_CODE_INSTRUCTIONS.md`: *"Code is truth; blueprint may lag. Always grep-and-read the cited files before drafting a fix plan."*

---

## Backlog Created (Sprint 8+)

| Gap | Title | Why deferred | Estimate |
|---|---|---|---|
| **G-DOCS-1** ⭐ | Blueprint accuracy audit | Must precede any P0/P1 work | 4-6 h |
| G-A2.1 | Migrate 6 V4-only screens to V5 | Unreachable from any URL; need V5 wrapper migration | 4-6 h |
| G-A3.1 | Alembic catch-up + lifespan integration | DBA review + maintenance window required | 1-2 weeks |
| G-T1.1 | Flutter test infra fix (`package:web` 1.1.1 vs Flutter 3.27.4) | Blocks any widget test that pulls `api_service.dart` | 2-3 days |

---

## PRs Open

`gh` CLI is not authenticated locally, so PRs need to be created manually. URLs:

```
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-a1-split-main-dart
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-a2-deprecate-v4-router
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-a3-alembic-baseline
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-s1-bcrypt-12
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-t1-flutter-tests
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-z1-zatca-encryption
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-b1-oauth-real
https://github.com/shadyapoelela-cloud/apex-web/pull/new/sprint-7/g-b2-sms-real
```

### Suggested merge order

1. **G-A1** (largest refactor, base for follow-ups touching extracted screens)
2. **G-S1** (smallest code change, fully self-contained security improvement)
3. **G-Z1** → **G-B1** → **G-B2** (all docs-only; minimal review burden)
4. **G-A2** (router cleanup; V4 screens still reachable via direct routes)
5. **G-A3** (docs-only; lifespan untouched, production safe)
6. **G-T1** (test foundation; doesn't block anything)

After all 8 merged, kick off Sprint 8 with **G-DOCS-1** as item #1.

---

## Manual Steps for User

1. Authenticate `gh` locally (or open the 8 URLs above in a browser).
2. Review PRs in the suggested order; G-A1 is the only one with non-trivial refactor diff.
3. Resolve any conflicts on `09_GAPS_AND_REWORK_PLAN.md` / `PROGRESS.md` / `.env.example` — multiple branches edit these; keep additive content from each.
4. After all merge, kick off **Sprint 8 with G-DOCS-1** before any new P0/P1 work.

---

— Sprint 7 closed 2026-04-30
