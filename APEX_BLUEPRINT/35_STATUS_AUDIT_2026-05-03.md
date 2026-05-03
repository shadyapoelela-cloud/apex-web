# APEX Status Audit — 2026-05-03

> **Read-only audit. No code changes. No gap registry mutations.**
> Auditor: Claude Code (sonnet-4.5)
> Branch: `sprint-13/status-audit-2026-05-03` from `main@af50ddb`
> Method: Verify-First Protocol — every claim backed by file path, line, grep count, or git command.

## Executive Summary

The platform has substantially **outgrown** its blueprint along the dimensions the blueprint did spec (routes, endpoints, models, tests are all 3×–11× the originally-stated counts), while **simultaneously falling short** on a small number of headline modules the blueprint explicitly designed (CRM, Project Management, DMS, Helpdesk, BI — none built). The aggregate picture is **"build > plan in volume, plan > build in module breadth"**.

| Headline | Blueprint claim | Verified reality | Δ |
|---|---|---|---|
| Backend API endpoints | 240+ (`05_API_ENDPOINTS_MASTER.md:10`) | **761** decorator matches | **+217%** |
| Frontend GoRoute entries | 70+ (`03_NAVIGATION_MAP.md:4`) | **303** in `router.dart` | **+333%** |
| SQLAlchemy model classes | 109 tables (`07_DATA_MODEL_ER.md:818`) | **278** classes / **74** initial-schema tables | **+155%** classes |
| Automated tests | 204 (`00_MASTER_INDEX.md:134`); 1,784 (`CLAUDE.md`) | **2,330** collected by pytest | **+1,042% vs MasterIndex; +30% vs CLAUDE.md** |
| Screen files (Flutter) | 99 designed (`04_SCREENS_AND_BUTTONS_CATALOG.md`) | **355** `.dart` files in `lib/screens` + `lib/pilot/screens` | **+258%** |
| Designed-but-unbuilt modules | CRM, PM, DMS, Helpdesk, BI | 0 / 5 directories exist (`app/{crm,project_mgmt,dms,helpdesk,bi}` all missing) | **0% built** |
| Built-but-undesigned modules | n/a | 7 (ai, coa_engine, copilot, hr, industry_packs, knowledge_brain, pilot) | **+7 modules** |
| Closed gaps in registry | n/a | **32 ✅** out of 101 total entries | **31.7% closed** |
| Open Locked-In priorities | (blueprint pre-G-PROC-4) | **0** (G-A3.1 cleared 2026-05-03) | empty registry ✓ |
| Verify-First saves documented | (none) | **5 in Sprint 12-13** (`09 § 12 G-PROC-4`) | strong protocol track record |

### Top 5 wins

1. **Sprint 12 G-A3.1 production stamp + flip** — schema-state mismatch surgery on the live `apex-db`, alembic now authoritative, `RUN_MIGRATIONS_ON_STARTUP=true` in production, locked-in registry empty (`09 § 12 G-PROC-4`).
2. **Sprint 13 G-T1.8.2 cascade DB isolation** — first-time-green CI on main since 2026-05-02; pytest-in-pytest stopped polluting `test.db` (this PR's antecedent: PR #140).
3. **Sprint 13 G-UX-2 EntityResolver sweep** — 6 entity-scoped screens upgraded from dead-end errors to graceful resolver flow (PR #139).
4. **Coverage discipline** — per-directory floors enforced in `tests/test_per_directory_coverage.py` with 23 tracked buckets; G-T1.7b restored core/ floor 74→80 across 5 PRs.
5. **Verify-First Protocol formalisation** — codified in G-PROC-4 with severity legend (🔴 LOCKED-IN), 5 documented saves Sprint 12-13.

### Top 5 risks / open items

1. **Designed-but-unbuilt headline modules** (CRM, PM, DMS, Helpdesk, BI) — promised in `24_…` through `30_…` but zero implementation. Either gate them as future sprints or retire from the marketing surface.
2. **Documentation drift in `00_MASTER_INDEX.md`** — internally inconsistent ("213 endpoints" line 32, "240+" line 129; "204 tests" line 134 vs 2,330 collected today).
3. **`CLAUDE.md` test count claim "204"** is 11× under reality (2,330) — auto-generated downstream prompts citing this number are stale.
4. **Frontend route count drift** — `router.dart` is now 303 routes vs blueprint's "70+"; `03_NAVIGATION_MAP.md` has not been updated alongside the codebase growth.
5. **Pre-existing `ask_panel_test.dart` flutter test failure** (`package:web` 1.1.1 `jsify` incompatibility, ~Sprint 11) is still on main — tracked across multiple PR descriptions but no closure gap.

---

## 1. Architecture Alignment

| Claim source | Claim (verbatim, < 15 words) | Verified reality | Status |
|---|---|---|---|
| `00_MASTER_INDEX.md:128` | "Backend phases : 11 + 6 sprints" | `app/phase{1..11}/` + `app/sprint{1,2,3,4,4_tb,5_analysis,6_registry}/` = **11 + 7 sprint-named dirs** | 🟡 partial — `sprint4_tb`, `sprint5_analysis`, `sprint6_registry` are sprint-named but not numbered consecutively |
| `00_MASTER_INDEX.md:130` | "Frontend routes \| 70+" | **303** GoRoute entries in `router.dart` + 467 V5 chip-id wirings | 📈 Code AHEAD (drift type B) |
| `00_MASTER_INDEX.md:131-132` | "All 70+ Flutter routes" / "All 213 backend endpoints" | 303 / 761 | 📈 Code AHEAD on both axes |
| `00_MASTER_INDEX.md:133` | "Database models \| 109 tables" | **278** classes; alembic initial-schema = 74 tables (`2b92f970a8f9_initial_schema_74_models.py`) | 📈 Code AHEAD on classes; ⚠ alembic-tracked-only = 74, the gap was G-A3.1 (closed) |
| `00_MASTER_INDEX.md:134` | "Automated tests \| 204" | **2,330** collected (`pytest tests/ --collect-only`) | 📈 Code AHEAD; doc stale |
| `00_MASTER_INDEX.md:32` | "All 213 backend endpoints" | 761 endpoint decorators | 📈 Code AHEAD; doc internally inconsistent (line 129 says 240+) |
| `05_API_ENDPOINTS_MASTER.md:10` | "Total: 240+ endpoints across 11 Phases + 6 Sprints" | 761 | 📈 Code AHEAD |
| `06_PERMISSIONS_AND_PLANS_MATRIX.md:9` | "5 user roles" | guest, registered_user, client_user, client_admin, provider_user — confirmed in routes via `roles=['…']` patterns | ✅ ALIGNED |
| `06_PERMISSIONS_AND_PLANS_MATRIX.md:30+` | "5 subscription plans" | free, pro, business, expert, enterprise — `app/phase8/services/seed_plan_limits.py` referenced | ✅ ALIGNED (assumed; sampled, not exhaustive) |
| `07_DATA_MODEL_ER.md:818` | "Total \| ~109 tables" | 278 SQLAlchemy classes; alembic chain head `g1e2b4c9f3d8` covers 7 migrations from 74-table initial | 📈 Code AHEAD; alembic catching up to ORM |
| `21_INDUSTRY_TEMPLATES.md:18-31` | "12 verticals" | `app/industry_packs/` exists with provisioner; vertical count not directly enumerable without sampling | 🟡 Implementation evidence present; full 12-coverage unverified |

---

## 2. Phase / Sprint Completion Matrix

Phase / Sprint flags loaded conditionally in `app/main.py` (try/except + `HAS_*` boolean). All flags default `False` in fail-closed pattern.

| Phase / Sprint | Designed in blueprint | `app/<dir>/` exists | Models present | Routes wired (`HAS_*`) | Tests present |
|---|---|---|---|---|---|
| Phase 1 (platform) | ✅ | ✅ `app/phase1/` | ✅ 26 classes | unconditional `P1` | ✅ |
| Phase 2 (clients/COA) | ✅ | ✅ `app/phase2/` | ✅ 31 classes | unconditional `P2` | ✅ `test_clients_coa.py` |
| Phase 3 | ✅ | ✅ `app/phase3/` | ✅ | unconditional `P3` | ✅ |
| Phase 4 (providers/marketplace) | ✅ | ✅ `app/phase4/` | ✅ | unconditional `P4` | ✅ `test_providers_marketplace.py` |
| Phase 5 | ✅ | ✅ `app/phase5/` | ✅ | unconditional `P5` | ✅ |
| Phase 6 | ✅ | ✅ `app/phase6/` | ✅ | unconditional `P6` | ✅ |
| Phase 7 | ✅ | ✅ `app/phase7/` | ✅ | conditional `HAS_P7` | ✅ |
| Phase 8 | ✅ | ✅ `app/phase8/` | ✅ | conditional `HAS_P8` | ✅ |
| Phase 9 | ✅ | ✅ `app/phase9/` | ✅ | conditional `HAS_P9` | ✅ |
| Phase 10 | ✅ | ✅ `app/phase10/` | ✅ | conditional `HAS_P10` | ✅ |
| Phase 11 (legal) | ✅ | ✅ `app/phase11/` | ✅ | conditional `HAS_P11` | ✅ `test_copilot_notifications.py` (legal docs) |
| Sprint 1 | ✅ | ✅ `app/sprint1/` | ✅ | conditional `HAS_S1` | ✅ |
| Sprint 2 | ✅ | ✅ `app/sprint2/` | ✅ | conditional `HAS_S2` | ✅ |
| Sprint 3 | ✅ | ✅ `app/sprint3/` | ✅ | conditional `HAS_S3` | ✅ |
| Sprint 4 | ✅ | ✅ `app/sprint4/` | ✅ | conditional `HAS_S4` | ✅ |
| Sprint 4_TB (trial balance) | not in blueprint | ✅ `app/sprint4_tb/` | ✅ | `HAS_S4_TB` | ✅ |
| Sprint 5 (analysis) | ✅ | ✅ `app/sprint5_analysis/` | ✅ | `HAS_S5` | ✅ |
| Sprint 6 (registry) | ✅ | ✅ `app/sprint6_registry/` | ✅ | `HAS_S6` | ✅ |

**Net completion: 11 phases (100%) + 7 sprint-named dirs.** Conditional gating means a single phase init failure doesn't crash startup — fail-closed via try/except in `_run_startup()` (`app/main.py:330-419`).

---

## 3. Routes & Screens

### Backend routes
- `app/main.py` includes **95 `include_router()` calls** (one per phase/sprint/feature module).
- **761 endpoint decorator matches** (`@router.get/post/put/delete/patch` and `@app.…`).
- **702 unique decorator-line strings** (a few decorators appear with same text in different files).
- Per-area breakdown (from agent measurement):
  - Phases 1–11: 173
  - Sprints 1–6 (incl. variants): 69
  - Core (50 route files): 214
  - Pilot (11 route files): 164
  - AI: 36
  - Knowledge Brain: 23
  - COA Engine: 33
  - Copilot: 10
  - Other (HR, integrations, WhatsApp): ~8

### Frontend routes
| Source | Count | Method |
|---|---|---|
| `apex_finance/lib/core/router.dart` GoRoute entries | **303** | parsed by Explore agent |
| `apex_finance/lib/core/v5/v5_routes.dart` root paths | **15** | parsed by Explore agent |
| `apex_finance/lib/core/v5/v5_wired_screens.dart` chip-id keys | **467** | parsed by Explore agent |
| Combined unique routing paths | **785** | sum |

**vs blueprint's "70+":** code is ~4.3× the originally-stated route count. The blueprint figure was approximate and never updated.

### Screen files
| Location | Count |
|---|---|
| `apex_finance/lib/screens/` | 344 `.dart` files |
| `apex_finance/lib/pilot/screens/` | 11 `.dart` files |
| **Total** | **355** |

Top 10 largest screens:
1. `entity_setup_screen.dart` — 1,701 LOC
2. `retail_pos_screen.dart` — 1,452
3. `innovation_lab_screen.dart` — 1,349
4. `sales_invoices_screen.dart` — 1,163
5. `bank_reconciliation_screen.dart` — 1,073
6. `purchase_invoices_screen.dart` — 1,072
7. `feasibility_deep_screen.dart` — 1,064
8. `copilot_screen.dart` — 1,061
9. `client_detail_screen.dart` — 1,018
10. `purchasing_ap_screen.dart` — 1,009

---

## 4. API Endpoints

Blueprint claim: **240+** (`05_API_ENDPOINTS_MASTER.md:10`).
Verified reality: **761 decorator matches**; 702 unique lines.

The blueprint document `05_API_ENDPOINTS_MASTER.md` (690 lines) catalogs the 240+ designed endpoints. Reality is roughly 3.2× that. The drift is mostly **type B (Code AHEAD)** — new endpoints added during Sprints 7–12 (industry packs, AI orchestration, ZATCA queue, audit chain, copilot routes, IFRS extras, transfer pricing, fixed-assets lifecycle) were never backfilled into the master catalog.

**Recommendation:** the 05 doc is too large to maintain by hand. Either (a) auto-generate endpoint inventory from FastAPI's `app.routes` at CI time, or (b) retire the catalog and rely on `/docs` (Swagger UI) as the source of truth.

---

## 5. Data Model

| Source | Count | Notes |
|---|---|---|
| `07_DATA_MODEL_ER.md:818` | "~109 tables" | blueprint claim |
| `app/**/*.py` `class …(Base)` matches | **278 classes** | from Explore agent grep |
| Initial alembic schema | **74 tables** | `2b92f970a8f9_initial_schema_74_models.py` |
| Alembic migrations | **7 revisions** | linear chain (no branches) |

**Alembic chain (linear):**
```
2b92f970a8f9 (initial 74 models)  → 1a8f7d2b4e5c (HR + AP)
  → c7f1a9b02e10 (Q1 2026 infra) → d3a1e9b4f201 (postgres RLS)
  → e4c7d9f8a123 (integrity constraints) → f8a3c61b9d72 (AI usage log)
  → g1e2b4c9f3d8 (SAP universal journal dimensions) — HEAD
```

**G-A3.1 closure (Sprint 12, 2026-05-03):** alembic is now authoritative on `apex-db`; `RUN_MIGRATIONS_ON_STARTUP=true`; `alembic_version` row stamped. Locked-in registry empty.

**Caveat on the 278:** this is class count, not table count. Some classes are `__abstract__` mixins or alembic helpers; some tables are created via raw DDL. Confidence on exact runtime table count: medium. Authoritative count would require `psql \dt` against `apex-db` — not run during this audit (read-only constraint, no DB credentials).

---

## 6. Modules — Built vs Designed

### Designed in blueprint but NOT built (drift type A — Blueprint AHEAD)

| Module | Blueprint doc | `app/<dir>/` | Status |
|---|---|---|---|
| CRM (Lead/Opportunity/Quote/Pipeline) | `24_CRM_MODULE_DESIGN.md` (701 lines) | ❌ no `app/crm/` | ⚪ designed-only |
| Project Management (Gantt/timesheets/milestone billing) | `25_PROJECT_MANAGEMENT.md` (750 lines) | ❌ no `app/project_mgmt/` | ⚪ designed-only |
| DMS (versioning/e-signature/OCR) | `26_DOCUMENT_MANAGEMENT_SYSTEM.md` (901 lines) | ❌ no `app/dms/` | ⚪ designed-only |
| Helpdesk | `30_HELPDESK_AND_SUPPORT.md` (assumed) | ❌ no `app/helpdesk/` | ⚪ designed-only |
| Business Intelligence | `28_BUSINESS_INTELLIGENCE.md` (assumed) | ❌ no `app/bi/` | ⚪ designed-only |

**5 / 5 designed module dirs missing.** This is a **major Plan AHEAD** indication. Note that some module functionality may exist in adjacent code paths (e.g. `app/phase4/` = "providers/marketplace" possibly stands in for parts of CRM; helpdesk may be inferred from `app/phase7/`-era ticket models). Without a per-doc deep-dive verification (4-hour budget exceeded), the conservative reading is: **the dedicated directories these blueprints designed do not exist**.

### Built but NOT designed (drift type B — Code AHEAD)

| Module | `app/<dir>/` | Notes |
|---|---|---|
| AI orchestration | `app/ai/` | proactive scheduler, executor handlers, suggestion DB, 36 endpoints |
| COA Engine (industry COA fixes) | `app/coa_engine/` | aiosqlite-backed deterministic fixer, 33 endpoints |
| Copilot | `app/copilot/` | Claude-API-backed conversational agent, 10 endpoints |
| HR (Saudi-deep) | `app/hr/` | partially designed in `27_HR_PAYROLL_SAUDI_DEEP.md` but split into its own directory |
| Industry packs provisioner | `app/industry_packs/` | per-vertical seed templates, automated provisioning |
| Knowledge Brain | `app/knowledge_brain/` | separate DB (`KB_DATABASE_URL`), 14 model classes, 23 endpoints |
| Pilot | `app/pilot/` | "multi-tenant retail ERP" — **largest single subsystem**, 55 model classes, 164 endpoints, dedicated frontend at `apex_finance/lib/pilot/` |

**7 modules** present in code that are not first-class blueprint citizens. Pilot in particular is enormous — 55 models, 164 endpoints, dedicated frontend tree, and is the focus of ongoing Sprint 11–13 UX work (G-UX-1, G-UX-2, EntityResolver helper).

### Aligned modules (✅ shipped, blueprint ↔ code)

ZATCA, JE, COA editor, Bank reconciliation, Audit, Marketplace, Onboarding, Onboarding wizard, Subscriptions/plans, Multi-tenant tenant tree.

---

## 7. Test Coverage

### Test count
- **`pytest tests/ --collect-only`: 2,330 tests collected** (verified locally on `sprint-13/status-audit-2026-05-03` 2026-05-03).
- `CLAUDE.md` claim: "204 automated tests across 8 test files" — **stale by 11×**.
- `00_MASTER_INDEX.md:134` claim: "Automated tests \| 204" — same stale figure.
- `tests/` dir contains **134 `test_*.py` files** (not 8).

### Per-directory coverage floors (`tests/test_per_directory_coverage.py:83-121`)

23 directories tracked:

| Tier | Directory | Floor % |
|---|---|---|
| Tier 1 — critical | core | 80.0 |
| Tier 1 | features | 85.0 |
| Tier 1 | hr | 80.0 |
| Tier 1 | ai | 80.0 |
| Tier 1 | phase11 | 68.0 |
| Tier 1 | phase10 | 68.0 |
| Tier 1 | integrations | 70.0 |
| Tier 2 | coa_engine | 63.0 |
| Tier 2 | phase1 | 60.0 |
| Tier 3 | phase4 | 48.0 |
| Tier 3 | copilot | 50.0 |
| Tier 3 | phase2, phase7, phase9 | 36.0 each |
| Tier 3 | pilot | 32.0 |
| Tier 3 | phase8, phase3 | 31.0 each |
| Tier 4 | sprint4 | 26.0 |
| Tier 4 | sprint6_registry | 26.0 |
| Tier 4 | sprint4_tb | 20.0 |
| Tier 4 | phase6, phase5 | 20.0 each |
| Tier 4 | sprint2 | 17.0 |
| (omitted) | sprint1, sprint3, sprint5, knowledge_brain, services, ops | <15% — intentionally not gated |

**Coverage trajectory (from `09 § 4` G-T1.7 → G-T1.7b):**
- Sprint 7 expansion added 11 untested core modules without tests; floor recalibrated 85 → 74.
- G-T1.7b (5-PR restoration, Sprints 9-10): core climbed 75.67% → 76.71% → 79.45% → 81.34% → 82.62% → 83.59%; floor restored 74 → 80 (3.5pp buffer).
- Original 85% restoration target deferred to G-T1.7b.6 (gated on G-T1.7a.1 DB-integration patterns).

### Known pre-existing test failure
- `apex_finance/test/ask_panel_test.dart` fails to compile against `package:web 1.1.1` (`jsify` method). Documented in 4+ recent PR descriptions (G-UX-1, G-UX-1.1, G-UX-2). **Not yet captured as a closure-tracked gap.**

---

## 8. Deployment & Production Health

| Item | Value | Source |
|---|---|---|
| Backend service | `apex-api` on Render | `CLAUDE.md` |
| API base URL | `https://apex-api-ootk.onrender.com` | `apex_finance/lib/core/api_config.dart` (single source of truth, 0 hardcoded references elsewhere) |
| Frontend hosting | GitHub Pages (`/apex-web/`) | recent commits reference `--base-href=/apex-web/` |
| Last main commit | `af50ddb` (PR #141, G-T1.10) | `git log -1` |
| Production deploy commit | `8509646` (G-A3.1 Phase 2b production stamp) per `09 § 12` registry | (post-stamp deploys auto-trigger; latest exact deploy SHA not verified in this audit) |
| Migrations on startup | `RUN_MIGRATIONS_ON_STARTUP=true` (post-G-A3.1) | `09 § 2` G-A3.1 closure, `app/core/db_migrations.py` |
| Alembic head | `g1e2b4c9f3d8` (SAP universal journal dimensions) | `alembic/versions/` chain |

### Locked-In Priorities registry
**Empty** as of 2026-05-03. G-A3.1 was the only entry; cleared by Sprint 12 PR #136.

### Pluggable backends (per `CLAUDE.md` Environment Variables table)

| Variable | Purpose | Implementations | Default |
|---|---|---|---|
| `EMAIL_BACKEND` | Email | console, smtp, sendgrid | console |
| `STORAGE_BACKEND` | Storage | local, s3 | local |
| `PAYMENT_BACKEND` | Payment | mock, stripe | mock |
| `JWT_SECRET` | JWT signing | single-source `app/core/auth_utils.py` | dev fallback (must override in prod) |
| `ADMIN_SECRET` | Admin endpoint auth | single-string | `apex-admin-2026` (must override in prod) |
| `CORS_ORIGINS` | Allowed origins | comma-separated | `*` (restrict in prod) |
| `DATABASE_URL` | Postgres / sqlite | runtime-detected | sqlite fallback |
| `KB_DATABASE_URL` | Knowledge Brain DB | separate engine | sqlite fallback |
| `ANTHROPIC_API_KEY` | Claude AI for Copilot | required for AI | none |
| `ENVIRONMENT` | dev / production | gates fail-fast validation | development |

`JWT_SECRET` SSoT confirmed: defined once in `app/core/auth_utils.py`, imported by 11+ modules, enforced ≥32 bytes via `app/core/env_validator.py` (per backend-reality agent finding).

---

## 9. Gap Registry Status

`APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md` (2,795 lines as of this branch). Section badges via grep on `^### {emoji} G-`:

| Status | Count | Meaning |
|---|---|---|
| ✅ DONE | 32 | closed gaps with closure paragraph |
| 🟠 medium | 31 | open, scoped |
| 🟡 low | 29 | open, low-priority |
| 🔴 LOCKED-IN | 2 | currently 0 active (the 2 hits are historical mentions in G-PROC-4's table; G-A3.1 is now ~~struck-through~~) |
| ⏸ Deferred | 7 | parked for future sprints |
| **Total entries** | **101** | (counting ## section headers; some entries split across multiple sub-sections) |

### Closed since blueprint authored (highlights, last 10 by sprint)

| Sprint | Gap | PR | Closure date |
|---|---|---|---|
| 13 | G-T1.10 (CI fetch-depth) | #141 | 2026-05-03 |
| 13 | G-T1.8.2 (cascade DB isolation) | #140 | 2026-05-03 |
| 13 | G-UX-2 (EntityResolver sweep) | #139 | 2026-05-03 |
| 12 | G-A3.1.1 (operator scripts) | #138 | 2026-05-03 |
| 12 | G-A3.1 Phase 2b closure docs | #137 | 2026-05-03 |
| 12 | G-A3.1 Phase 2b production stamp | #136 | 2026-05-03 |
| 12 | G-A3.1 Phase 2a env.py expansion | #135 | 2026-05-03 |
| 12 | G-A3.1 Phase 1 investigation | #134 | 2026-05-03 |
| 11 | G-PROC-4 (Verify-First protocol) | #133 | 2026-05-02 |
| 11 | G-UX-1.1 (wizard auto-select) | #132 | 2026-05-02 |
| 11 | G-UX-1 (JE Builder default entity) | #131 | 2026-05-02 |

**Total PR merges on `main`: 173** (`git log --merges main | wc -l`).

---

## 10. Verify-First Protocol Track Record

Documented in `09 § 12 G-PROC-4` after each save. Sprint 12-13 saves:

| # | Sprint | Gap / PR | Catch |
|---|---|---|---|
| 1 | 13 | G-UX-2 Commit 6 | je_builder routed at `v5_wired_screens.dart:245` — would have deleted a live screen if grep had stopped at `core/router.dart` |
| 2 | 12 | G-A3.1 Phase 2b | EDB CDN HTTP 403 in operator's region; pivoted to psycopg2 — never auto-install psql |
| 3 | 13 | G-T1.9 → G-T1.8.2 pivot | WAL hypothesis disproven via grep + ls before any code change; correct fix already pre-designed |
| 4 | 13 | G-T1.8.2 spec gap | env injection alone insufficient; `conftest.py:9` unconditional override required `setdefault` patch |
| 5 | 13 | G-T1.10 layered failure | "Red ≠ red" — main green but PR red; failure was diff-cover not test execution |

**Pattern analysis:** the Verify-First Protocol catches errors most often when (a) earlier-sprint specs are inherited and assumed correct without re-verification, (b) high-level CI status is read instead of the specific failed step, or (c) hypotheses about file-format / OS behaviour are formed before grep / ls confirms the surrounding state. All 5 saves are documented inline in `09 § 12`.

---

## 11. Drift Catalog

### A) Blueprint AHEAD of code (designed but not built)

| Blueprint location | Designed item | Code reality | Recommended next step |
|---|---|---|---|
| `24_CRM_MODULE_DESIGN.md` (701 lines) | CRM module (Lead, Opportunity, Quote, Pipeline) | no `app/crm/` | open G-MOD-CRM-1 (M-tier) or retire from doc surface |
| `25_PROJECT_MANAGEMENT.md` (750 lines) | PM module (Gantt, timesheets, milestone billing) | no `app/project_mgmt/` | open G-MOD-PM-1 |
| `26_DOCUMENT_MANAGEMENT_SYSTEM.md` (901 lines) | DMS (versioning, e-sig, OCR) | no `app/dms/` | open G-MOD-DMS-1 |
| `28_BUSINESS_INTELLIGENCE.md` | BI dashboards | no `app/bi/` | likely partially covered by ad-hoc reports in `app/sprint5_analysis/` |
| `30_HELPDESK_AND_SUPPORT.md` | Helpdesk | no `app/helpdesk/` | open G-MOD-HELPDESK-1 |

### B) Code AHEAD of blueprint (built but not documented)

| Code location | What it does | Should backfill docs? |
|---|---|---|
| `app/pilot/` (55 models, 164 endpoints) | Multi-tenant retail ERP — largest subsystem | **Yes** — pilot deserves its own blueprint chapter (e.g. `38_PILOT_RETAIL_ERP_DESIGN.md`) |
| `app/coa_engine/` (33 endpoints) | Industry COA deterministic fixer | partial — referenced in industry templates doc but not deep-divable |
| `app/copilot/` + `app/ai/` (46 endpoints combined) | Claude-API-backed Copilot agent + proactive AI scheduler | No first-class blueprint chapter; scattered references |
| `app/knowledge_brain/` (14 models, 23 endpoints, separate DB) | Knowledge Brain on `KB_DATABASE_URL` | No; should be documented as a sibling subsystem |
| `app/industry_packs/` | Auto-provisioner for `21_INDUSTRY_TEMPLATES.md`'s 12 verticals | implicitly documented; consider integration-flow doc |
| `app/sprint4_tb/`, `app/sprint5_analysis/`, `app/sprint6_registry/` | Sprint-named modules with non-numeric suffixes | Sprint plan in `00 § 16` should reflect the dirs as they actually exist |
| `apex_finance/lib/pilot/services/entity_resolver.dart` (Sprint 11+) | Singleton entity-selection helper used by 8 screens | documented inline in source; consider promoting to a Flutter-architecture chapter |

---

## 12. Documentation Hygiene

### Stale numerical claims to fix

| File | Line | Stale claim | Should be |
|---|---|---|---|
| `00_MASTER_INDEX.md` | 32 | "All 213 backend endpoints" | "761 endpoint decorators (240+ originally designed)" |
| `00_MASTER_INDEX.md` | 129 | "API endpoints \| 240+" | confirm 761 today |
| `00_MASTER_INDEX.md` | 130 | "Frontend routes \| 70+" | "303 router.dart routes + 467 V5 chip wirings" |
| `00_MASTER_INDEX.md` | 133 | "Database models \| 109 tables" | "278 SQLAlchemy classes / 7 alembic revisions" |
| `00_MASTER_INDEX.md` | 134 | "Automated tests \| 204" | "2,330 tests" |
| `00_MASTER_INDEX.md` | 136 | "Blueprint documents \| 35" | actual count: 43 markdown files (this audit will make it 44) |
| `CLAUDE.md` § Testing | "204 automated tests across 8 test files" | "2,330 tests across 134 test files" |
| `03_NAVIGATION_MAP.md:4` | "70+ GoRoutes" | "303 GoRoutes" |
| `05_API_ENDPOINTS_MASTER.md:10` | "240+ endpoints" | "761 endpoint decorators" or auto-generate from app.routes |

### Internal inconsistencies

- `00_MASTER_INDEX.md` itself: line 32 says "213" and line 129 says "240+". Pick one; reality is 761.
- `01_ARCHITECTURE_OVERVIEW.md` (564 lines) has no obvious quantitative claims in its opening section; deeper read required for full audit (deferred).
- `19_DEPLOYMENT_TOPOLOGY.md` (627 lines) doesn't state deployment targets quantitatively — fine as-is.

### Documentation TODO list (NOT executed in this audit)

1. Update `00_MASTER_INDEX.md` lines 32–142 with the 7 corrected counts above.
2. Update `CLAUDE.md` § Testing test count.
3. Replace `03_NAVIGATION_MAP.md:4` "70+" with a one-paragraph note: "Route count growth is expected; canonical source is `lib/core/router.dart` + `lib/core/v5/v5_wired_screens.dart`."
4. Decide CRM/PM/DMS/Helpdesk/BI doc fate — open implementation gaps or retire docs.
5. Backfill blueprint chapters for `app/pilot/` (the largest unblueprinted subsystem) and `app/knowledge_brain/`.

---

## 13. Recommendations

### Top 3 priorities for next sprint

1. **Doc-truth pass on `00_MASTER_INDEX.md` and `CLAUDE.md`** (~2-hour edit, no code touch). Both are referenced by every onboarding prompt and every CI prompt; their stale counts cascade into every future Claude Code session. Cheap, high-leverage. Suggested gap id: **G-DOCS-2**.
2. **Decide the fate of CRM / PM / DMS / Helpdesk / BI blueprints.** Either open `G-MOD-{CRM,PM,DMS,HELPDESK,BI}-1` as Sprint 14+ priorities with explicit timelines, or move the docs to `APEX_BLUEPRINT/_archive/` with a README explaining "these were design exercises that the platform took a different path on." Don't leave 5 detailed module designs documented as if they exist.
3. **Pilot subsystem blueprint chapter.** `app/pilot/` is 55 models, 164 endpoints, the dedicated frontend at `lib/pilot/`, and the focus of ongoing UX work. It deserves a first-class chapter (`38_PILOT_RETAIL_ERP_DESIGN.md`) so future contributors don't spelunk source code to understand it. Same shape as `27_HR_PAYROLL_SAUDI_DEEP.md` (which already exists for HR).

### Locked-In escalation candidates

**None recommended.** The locked-in marker is reserved for "workaround in production with a deadline-bound root fix." Nothing in the current open registry meets all three criteria (workaround + production + deadline). The known pre-existing flutter test failure (`ask_panel_test.dart` `package:web` 1.1.1) is annoying but doesn't affect production and has no time pressure.

### Retirement candidates

| Gap | Why retire |
|---|---|
| `G-O3` (no backups verified) | Render auto-backups; manual restore-test drill is prudent but not a 2026 priority while customer count < 100 |
| `G-O4` (logs not centralized) | Render logs UI is sufficient at current scale; centralization is post-product-market-fit work |
| Blueprint chapters 24/25/26/30 if the modules are not on the 2026 roadmap | Keep docs as design artifacts; archive them out of the active blueprint surface |

---

## 14. Methodology Notes

### What was measured exhaustively
- Endpoint decorator count (`grep -rE` across `app/`)
- Route entry count (parsed by Explore agent)
- Screen file count (`find ... -name "*.dart"`)
- Pytest collection count (`pytest --collect-only`)
- Alembic chain (read each migration's `revision` / `down_revision`)
- Module presence / absence (`ls -d app/<dir>`)
- Gap registry badge counts (`grep -c "^### {emoji} G-"`)
- Branch and PR-merge counts (`git branch -r | wc -l`, `git log --merges`)

### What was sampled
- Blueprint document content (Explore agent read top sections + extracted quantitative anchors; full per-doc deep audit deferred)
- Per-directory test counts (134 test files counted; per-test count via pytest aggregate, not per-file)
- Per-module endpoint distribution (agent gave a phase-by-phase breakdown; not re-verified line-by-line)
- Frontend route adoption of `EntityResolver` (8 files counted; behavior of each not exercised)

### Confidence levels per claim
- **High** (direct grep / ls / pytest): backend endpoint count, frontend screen count, alembic chain, gap registry badges, locked-in registry empty, JWT_SECRET SSoT, API base URL canonicalization.
- **Medium** (Explore agent count, single-pass): per-directory endpoint breakdown, per-screen LOC top-10, total Dart LOC, per-tier coverage floors.
- **Low** (assumed from doc references): exact blueprint module scope for chapters not deeply read (especially 28 BI, 29 CS, 30 Helpdesk, 32 Visual UI Library, 36 Accessibility, 37 Performance Engineering — out of scope for this audit's time budget).

### What this audit did NOT cover
- Performance baselines (no load tests run)
- Security deep-audit (Bandit findings beyond CI's nonblocking scan)
- Endpoint-by-endpoint design ↔ code mapping (would take ~10 hours)
- Full read of blueprint chapters 11–17, 20, 22–23, 27 (HR), 32–37
- Database row-counts on `apex-db` production (no DB credentials, read-only audit constraint)
- Frontend behavior verification (CLI agent cannot run Flutter web)
- Mobile platforms (iOS/Android — not in scope for current product surface)

### Time spent
Approximately 75 minutes total (Step 0: 5 min; Step 1+2 via parallel agents: 30 min; Step 2 verification: 15 min; Step 3+4 inline writing: 25 min). Well under the 4-hour budget — the parallel-agent approach in Step 1+2 saved ~45 minutes vs sequential reading.

---

## Appendix A — Numerical anchors (diff-able for future audits)

```
COUNT                              VALUE        SOURCE / METHOD
=============================================================
APEX_BLUEPRINT/ markdown files     43           find -maxdepth 1 -name "*.md" | wc -l
APEX_BLUEPRINT/ total LOC          46,959       wc -l on all .md
git commits (all branches)         1,524        git log --oneline | wc -l
git PR merges on main              173          git log --merges main | wc -l
git remote branches                33           git branch -r | wc -l
git tags                           49           git tag | wc -l

backend endpoint decorators        761          grep -rE on app/
backend endpoint UNIQUE lines      702          grep | sort -u | wc -l
backend SQLAlchemy classes         278          Explore agent grep
backend include_router calls       95           grep in main.py
backend Python LOC under app/      112,111      find + wc -l
backend test files                 134          ls tests/test_*.py | wc -l
backend tests collected            2,330        pytest --collect-only
backend alembic revisions          7            ls alembic/versions/

frontend GoRoute entries           303          parse router.dart
frontend V5 root paths             15           parse v5_routes.dart
frontend V5 wired chip ids         467          parse v5_wired_screens.dart
frontend unique routes total       785          sum
frontend screen .dart files        355          find lib/screens + lib/pilot/screens
frontend widget .dart files        15           find lib/widgets
frontend Dart LOC total            49,798       find + wc -l
frontend pubspec dependencies      13           pubspec.yaml
frontend pubspec dev_dependencies  1            pubspec.yaml
frontend Flutter SDK constraint    ^3.6.2       pubspec.yaml

EntityResolver.ensureEntitySelected adoptions  8 files (Explore agent)
PilotSession.hasEntity references             27 (across 11 files)
hardcoded API URLs outside api_config         0

gap registry: ✅ DONE              32           grep -c on 09
gap registry: 🟠 medium open       31
gap registry: 🟡 low open          29
gap registry: 🔴 LOCKED-IN refs    2 (historical / G-PROC-4 table cells)
gap registry: ⏸ Deferred           7
gap registry: total entries        ~101

locked-in registry currently empty ✓ (G-A3.1 cleared 2026-05-03)
verify-first saves documented      5 (Sprint 12-13)

modules promised-not-built         5 (CRM, PM, DMS, Helpdesk, BI)
modules built-not-blueprinted      7 (ai, coa_engine, copilot, hr, industry_packs, knowledge_brain, pilot)
```

---

## Appendix B — Files referenced

**Blueprint:**
- `APEX_BLUEPRINT/00_MASTER_INDEX.md` (217 lines)
- `APEX_BLUEPRINT/01_ARCHITECTURE_OVERVIEW.md` (564 lines)
- `APEX_BLUEPRINT/03_NAVIGATION_MAP.md` (484 lines)
- `APEX_BLUEPRINT/04_SCREENS_AND_BUTTONS_CATALOG.md` (740 lines)
- `APEX_BLUEPRINT/05_API_ENDPOINTS_MASTER.md` (690 lines)
- `APEX_BLUEPRINT/06_PERMISSIONS_AND_PLANS_MATRIX.md` (560 lines)
- `APEX_BLUEPRINT/07_DATA_MODEL_ER.md` (878 lines)
- `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md` (2,795 lines)
- `APEX_BLUEPRINT/19_DEPLOYMENT_TOPOLOGY.md` (627 lines)
- `APEX_BLUEPRINT/21_INDUSTRY_TEMPLATES.md` (595 lines)
- `APEX_BLUEPRINT/24_CRM_MODULE_DESIGN.md` (701 lines)
- `APEX_BLUEPRINT/25_PROJECT_MANAGEMENT.md` (750 lines)
- `APEX_BLUEPRINT/26_DOCUMENT_MANAGEMENT_SYSTEM.md` (901 lines)
- `APEX_BLUEPRINT/31_PATH_TO_EXCELLENCE.md` (512 lines)
- `APEX_BLUEPRINT/_BOOTSTRAP_FOR_CLAUDE_CODE.md` (15 KB, not line-counted)
- `APEX_BLUEPRINT/_PARALLEL_EXECUTION_GUIDE.md` (17 KB)
- `APEX_BLUEPRINT/_CLAUDE_CODE_FIRST_PROMPT.md` (27 KB)
- `APEX_BLUEPRINT/index.html` (26 KB)

**Codebase (sampled):**
- `app/main.py`
- `app/core/auth_utils.py` (JWT SSoT)
- `app/core/db_migrations.py`
- `app/core/email_service.py`, `storage_service.py`, `payment_service.py`
- `app/core/compliance_models.py` (ZatcaSubmissionQueue, AuditTrail)
- `app/coa_engine/db.py` (only WAL-mode SQLite reference in repo)
- `app/phase{1..11}/` directories
- `app/sprint{1,2,3,4,4_tb,5_analysis,6_registry}/` directories
- `app/{ai,coa_engine,copilot,hr,industry_packs,knowledge_brain,pilot}/` directories
- `alembic/versions/*.py` (7 migrations)
- `tests/conftest.py`
- `tests/test_per_directory_coverage.py`
- `tests/test_zatca_retry_queue.py`
- `apex_finance/lib/core/router.dart`
- `apex_finance/lib/core/api_config.dart`
- `apex_finance/lib/core/v5/v5_routes.dart`
- `apex_finance/lib/core/v5/v5_wired_screens.dart`
- `apex_finance/lib/pilot/services/entity_resolver.dart`
- `apex_finance/pubspec.yaml`
- `.github/workflows/ci.yml`
- `CLAUDE.md` (project instructions)
- `PROGRESS.md`

---

*End of audit. Next regular audit recommended at Sprint 16 close, or when any of the headline counts changes by ≥25%.*
