# G-A3.1 Phase 1 — Alembic Catch-Up Investigation Report

**Sprint:** 12 · **Status:** Phase 1 DONE — pending strategy approval before Phase 2.
**Branch:** `sprint-12/g-a3-1-phase-1-investigation` · **Date:** 2026-05-02.

> **Scope of this PR:** investigation + analysis only. **No code execution
> against production. No alembic commands run on `apex-db` or
> `apex-db-2`. No new migration files committed.** A draft autogenerate
> output was generated locally for analysis and deleted before push.

---

## TL;DR (read this first)

- Alembic chain claims **25 tables**; only **11 are real** for the main DB
  (the 14 `knowledge_*` tables are **legacy ghost migrations** — they
  apply to a separate Knowledge Brain DB that has been switched to
  `create_all()` since Wave 10 of `alembic/env.py`).
- Production main DB has **168 tables** built via `Base.metadata.create_all()`.
  Real gap: **157 tables** in models that alembic doesn't know about.
- **`alembic upgrade head` against the live schema reproduces the
  Sprint 11 production failure** locally (`hr_employees already exists`).
  The workaround `RUN_MIGRATIONS_ON_STARTUP=false` is the correct
  short-term fix.
- **`alembic stamp head` works cleanly** locally — followed by `alembic
  upgrade head` which becomes a no-op.
- **`alembic revision --autogenerate` is unsafe today:** it produces a
  3,629-line migration with **104 `op.create_table` AND 104
  `op.drop_table`** statements. The drops target real production tables
  (`pilot_*`, `knowledge_*`, `copilot_*`) because `alembic/env.py:_MODEL_MODULES`
  doesn't import the pilot/knowledge model modules — alembic sees those
  tables as "extra in DB, not in metadata" and proposes to drop them.
- **Recommended strategy: A — `alembic stamp head`** + close out the
  legacy ghost migrations + document the new contract. **B (full
  autogenerate catch-up) is not viable** until `env.py` is fixed AND
  DBA-reviewed. **C (reset migrations) is too destructive.** **D
  (hybrid stamp + selective)** is what we get for free under A — once
  stamped, future changes generate clean migrations against an updated
  metadata target.

---

## Section A — Current State

### A.1 Alembic chain (linear)

7 migration files, single chain ending at `g1e2b4c9f3d8`:

| Order | Revision | Description | `op.create_table` count |
|--:|---|---|--:|
| 1 | `2b92f970a8f9` | `initial_schema_74_models` | 14 |
| 2 | `1a8f7d2b4e5c` | `add HR + AP Agent tables` | 6 |
| 3 | `c7f1a9b02e10` | `q1_2026_infra_tables` | 4 |
| 4 | `d3a1e9b4f201` | `postgres_rls_policies` | 0 |
| 5 | `e4c7d9f8a123` | `integrity_constraints_vat_unique_je_balance_membership_audit` | 0 |
| 6 | `f8a3c61b9d72` | `ai_usage_log` | 1 |
| 7 | `g1e2b4c9f3d8` | `sap_universal_journal_dimensions` | 0 |

**Total tables created across the chain: 25.**

### A.2 Tables tracked by alembic

```
ai_usage_log              ap_invoices               ap_line_items
activity_log              hr_employees              hr_leave_requests
hr_payroll_runs           hr_payslips               sync_operations
tenant_branding           zatca_submissions         knowledge_audit_log
knowledge_authorities     knowledge_cases           knowledge_domains
knowledge_entries         knowledge_patterns        knowledge_playbooks
knowledge_review_queue    knowledge_rule_versions   knowledge_rules
knowledge_sector_mappings knowledge_sectors         knowledge_sources
knowledge_updates
```

### A.3 The two-`Base` architecture

`alembic/env.py` (Wave 10 rewrite) confirms:

- `app.phase1.models.platform_models.Base` (alias `PhaseBase`) — the
  **main production DB**. Alembic targets `PhaseBase.metadata`.
- `app.knowledge_brain.models.db_models.Base` — a **separate database**
  configured via `KB_DATABASE_URL`. **Not migrated by alembic.** Maintained
  by `create_all()` in startup.

**Implication for the alembic chain:** the 14 `knowledge_*` tables in
`2b92f970a8f9_initial_schema_74_models` are **legacy ghost migrations**
from before the Wave 10 fix. They were committed to alembic's chain
when someone briefly mistook the KB Base for the main Base. They
apply to nothing today — alembic runs them against the main DB where
those tables don't exist (and don't need to exist).

### A.4 Production schema (`Base.metadata` after `app.main` import)

| Metric | Count |
|---|--:|
| Tables in `PhaseBase.metadata` | **168** |
| Tables in alembic chain | 25 |
| Covered (in both — real overlap) | **11** |
| Gap (in models only — alembic doesn't know about them) | **157** |
| Stale (in alembic only — main DB doesn't have them) | **14** (the KB ghosts) |

### A.5 Real overlap (11 tables — the only meaningful alembic coverage)

```
ai_usage_log     ap_invoices       ap_line_items
activity_log     hr_employees      hr_leave_requests
hr_payroll_runs  hr_payslips       sync_operations
tenant_branding  zatca_submissions
```

These are the tables alembic genuinely knows about today. Everything
else either lives in a different Base (KB) or was added to the model
graph after alembic was last updated.

### A.6 Gap distribution by subsystem (157 tables)

A simple prefix-bucket sweep of the 157 gap tables:

| Bucket | Count | Examples |
|---|--:|---|
| `pilot_*` (retail ERP scope) | ~60 | `pilot_customers`, `pilot_journal_entries`, `pilot_pos_transactions`, `pilot_warehouses`, `pilot_zatca_*` |
| `audit_*` / `archive_*` / `compliance_*` | ~10 | `audit_events`, `audit_findings`, `archive_items`, `compliance_actions` |
| `client_*` | ~8 | `clients`, `client_documents`, `client_chart_of_accounts` |
| `service_*` (marketplace) | ~8 | `service_providers`, `service_requests`, `service_catalog` |
| `notification*` | ~4 | `notifications`, `notifications_v2`, `notification_preferences` |
| `copilot_*` | ~6 | `copilot_sessions`, `copilot_messages`, `copilot_memory_*` |
| Platform core | ~10 | `users`, `tenants`, `permissions`, `roles`, `user_sessions`, `password_resets` |
| Bank feeds | 2 | `bank_feed_connection`, `bank_feed_transaction` |
| Subscriptions / plans | 4 | `plans`, `plan_features`, `plan_limits`, `subscription_entitlements` |
| Other (50+) | ~45 | `journal_entry_sequence`, `dimension_defs`, `webhook_subscriptions`, `api_keys`, etc. |

The `pilot_*` cluster (~60 tables) is the largest single block. Many
of these were registered through `app/pilot/models.py` via
`Base.metadata.create_all()` paths that **don't go through `env.py`'s
`_MODEL_MODULES` list**. This is the root cause of the autogenerate
DROP-TABLE problem (Section B Strategy B).

---

## Section B — Strategy Analysis

### Strategy A — `alembic stamp head` only (recommended)

**Description:** mark production's `alembic_version` row at
`g1e2b4c9f3d8` (current head) without running any migrations. The DB
already has every table the head needs, plus 157 more that alembic
isn't aware of. After stamping, future migrations begin from a
known-but-incomplete starting point.

**Effort:** **30 minutes** (single `alembic stamp head` command in a
maintenance window + verification).

**Risk:** **LOW** — no schema change. The stamp is metadata-only,
writes a single row to `alembic_version`.

**Drawback:** alembic state remains permanently "incomplete" (it
thinks 25 tables are tracked when really 168 exist). New migrations
will still be diffed against `PhaseBase.metadata`, which today
includes the 157 gap tables — meaning `alembic revision --autogenerate`
**after stamping** would still propose creating them.

**This is the same problem as Strategy B unless we also fix
`env.py:_MODEL_MODULES` to include every model module — see
**Sub-strategy A+** below.

**Future migrations:** work normally for any change that happens to a
table alembic already knows about (the 11 real-overlap tables). For
new tables / tables in the 157 gap, manual migration writing is
required (autogenerate would still try to create + sometimes drop).

### Sub-strategy A+ — stamp head + fix `env.py:_MODEL_MODULES`

**Description:** Strategy A, plus expand `_MODEL_MODULES` to import
the pilot models (`app.pilot.models`), client models, service models,
and any other module that registers tables on `PhaseBase`. After the
fix, `target_metadata = PhaseBase.metadata` accurately reflects all
168 production tables. Then `alembic stamp head` says "alembic now
knows about all 168 tables, and the DB is at head."

**Effort:** **1-2 hours** (audit `app/` for every module that adds to
`PhaseBase`, add to `_MODEL_MODULES`, verify with a clean autogenerate
that proposes ZERO `op.create_table` and ZERO `op.drop_table` against
a freshly-built local DB).

**Risk:** **LOW-MEDIUM** — adding to `_MODEL_MODULES` is reversible.
The risk is missing a module and discovering it later when
autogenerate proposes a drop. Mitigated by the post-fix verification:
autogenerate-against-fresh-DB output should be empty. **If it isn't
empty, we found another gap and add it before proceeding.**

**Drawback:** alembic chain still has the 14 KB ghost migrations.
They're harmless (target a DB that doesn't see them) but cosmetically
unclean. Optionally squash later.

**Future migrations:** work cleanly. New table → `alembic revision
--autogenerate` produces a clean `op.create_table` only. ALTER → clean
ALTER. The `_MODEL_MODULES` list becomes the single source of truth
for "what does alembic see".

### Strategy B — Full autogenerate catch-up + apply

**Description:** generate a single migration via `alembic revision
--autogenerate` that creates all 157 missing tables. Apply on
production after staging verification.

**Effort:** **2-3 days** (DBA review of the 3,629-line autogenerated
migration + staging test + production cutover).

**Risk:** **HIGH** — empirical evidence from this investigation:

- Autogenerate today produces **104 `op.create_table` AND 104
  `op.drop_table`** statements.
- The drops target real production tables (`pilot_uae_ct_filings`,
  `knowledge_*`, `copilot_sessions`, `pilot_pos_payments`, ...).
- Running this migration on production would **drop ~104 tables**
  including the entire pilot retail-ERP scope.
- Root cause: `env.py:_MODEL_MODULES` doesn't import pilot/knowledge
  modules, so alembic sees their tables in the DB but not in metadata,
  and proposes drops.

**Mitigation:** Strategy B is **gated on Sub-strategy A+ first** (fix
`_MODEL_MODULES`). Even after that, a manual migration-by-migration
review is required because autogenerate has known limitations:
ENUM types, server-default mismatches, index-name normalization,
CHECK constraints, and PostgreSQL-specific types not always round-tripping.

**Drawback:** the migration would be ~3,000+ lines after fix. Reviewing
it line-by-line is the entire DBA cost. And it provides no operational
benefit over A+ — both leave alembic up-to-date going forward.

**Benefit (only in theory):** alembic chain accurately reflects every
table's CREATE history. In practice, this history is already reflected
in git via the model declarations — alembic chain reflection is
duplication.

### Strategy C — Reset migrations + autogenerate one comprehensive baseline

**Description:** delete all 7 existing migration files, run `alembic
revision --autogenerate` to create a single new initial migration
covering all 168 tables, `alembic stamp` production at the new head.

**Effort:** **1-2 days**.

**Risk:** **VERY HIGH** — production has already had migrations 1-7
applied (against the 11 real-overlap tables). Deleting them and
introducing a new initial breaks alembic's contract: production's
`alembic_version` would point at a revision that doesn't exist in the
chain. Recovery requires manual `alembic_version` row surgery.

**Drawback:** loses the migration history that DOES exist. Any
DDL that landed via the existing 7 migrations (RLS policies,
CHECK constraints, dimension columns) would need re-derivation from
the model graph — which doesn't preserve every constraint detail.

**Benefit (debatable):** clean slate. But the same clean slate is
achievable by squashing the existing 7 into one *after* A+.

### Strategy D — Hybrid stamp + selective catch-up per future change

**Description:** stamp head now. Document the gap (157 tables alembic
doesn't know about). When future changes touch a gap table, write a
*manual* migration for that one table only, expanding alembic's
coverage incrementally.

**Effort:** ~1 day initial + ad-hoc per change.

**Risk:** **MEDIUM** — schema drift compounds over time as new tables
are added to models without alembic catching up. Without `env.py`
fixes, autogenerate stays unusable indefinitely.

**Drawback:** ongoing per-PR cost. Every schema-touching change
becomes "is this a gap table? do we write the migration manually?"
PR review burden grows.

**Benefit:** lowest risk in absolute terms. Doesn't block anything.

---

## Section C — Recommendation

### Recommendation: Sub-strategy A+ (stamp head + fix `env.py:_MODEL_MODULES`)

**Reasoning:**

1. **Lowest risk that actually fixes the problem.** Pure A is too
   passive (autogenerate stays broken). A+ adds the one-line-per-module
   fix that makes alembic genuinely know the schema going forward.
2. **Strategy B is empirically dangerous today.** This investigation
   produced concrete evidence (104 DROP TABLE for pilot/knowledge/copilot
   tables). Even after A+, the 3,629-line catch-up migration is a
   review cost we don't need to pay — A+ achieves the same end state
   (alembic in sync with models for future migrations) without the
   line-by-line audit.
3. **Strategy C breaks production's `alembic_version` row.** Recovery
   is risky. No upside over A+.
4. **Strategy D is "do nothing, accept drift forever."** Compounds
   debt. Doesn't unblock the schema-change moratorium that G-A3.1
   is supposed to lift.
5. **A+ unblocks the moratorium.** After A+ ships, new alembic
   migrations can be written + reviewed normally. The 157 gap tables
   stay un-migration-tracked, but they're stable production tables —
   their absence from alembic history is cosmetic, not functional.

### Phase 2 plan under A+

| Step | Action | Risk |
|--:|---|---|
| 1 | Audit `app/` for every module that registers tables on `PhaseBase`. | none |
| 2 | Update `alembic/env.py:_MODEL_MODULES` to include them. | low |
| 3 | Local: clean `test.db`, build via `create_all`, run `alembic stamp head`, then `alembic revision --autogenerate -m "verify_clean"` — output must be empty (no create/drop/alter). | none |
| 4 | If output is non-empty: identify the missing module(s), add to `_MODEL_MODULES`, repeat step 3. | low |
| 5 | Once verified empty, apply `alembic stamp head` to staging (clone of prod schema). | none |
| 6 | Verify staging `alembic current` reports `g1e2b4c9f3d8 (head)`. | none |
| 7 | Schedule production maintenance window (~30 min). Take DB snapshot. | low |
| 8 | Apply `alembic stamp head` to production. | low |
| 9 | Re-enable `RUN_MIGRATIONS_ON_STARTUP=true` in Render env. | low |
| 10 | Restart `apex-api`. Verify deploy succeeds. | low |
| 11 | Smoke test: a trivial follow-up migration (e.g., a CHECK constraint on an existing column) — verify it applies cleanly. | low |
| 12 | Update `09 § 2 G-A3.1` → ✅ DONE; update `CLAUDE.md` "Migration management" to remove the moratorium. | none |

**Total Phase 2 effort:** half a day (under 4 hours of focused work
plus a 30-min maintenance window).

---

## Section D — Risk Assessment + Rollback Plan

### Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `_MODEL_MODULES` audit misses a module | Medium | Low | Step 3-4 verification loop catches it; revert is just `git revert`. |
| `alembic stamp head` accidentally runs migrations | Very Low | High | `stamp` is a separate command from `upgrade`. Verified empirically in this investigation. |
| Production DB snapshot fails | Low | High | Use `pg_dump --schema-only` before any alembic command; verify the dump is restorable on staging. |
| Re-enabling `RUN_MIGRATIONS_ON_STARTUP=true` causes unexpected `upgrade head` | Low | High | Phase 2 step 11 smoke test catches this in staging; production deploy uses `apex-api` cold restart with full log capture. |
| 14 KB ghost migrations cause alembic to retry them | None | None | Empirically verified: `alembic stamp head` skips them (they're behind head). |

### Rollback plan

- **If `_MODEL_MODULES` change breaks autogenerate verification:**
  `git revert` the `env.py` commit. No production touched.
- **If staging stamp produces unexpected `alembic current`:**
  reset staging DB from snapshot. Investigate before going to prod.
- **If production stamp succeeds but a follow-up smoke-test migration
  fails:** rollback by setting `RUN_MIGRATIONS_ON_STARTUP=false` again
  + `alembic downgrade -1` if the migration partially applied. The DB
  itself is untouched by stamp; only `alembic_version` row needs
  reverting (one UPDATE).
- **Worst case (production schema corruption):** restore from
  pre-Phase-2 `pg_dump` snapshot. RTO ~30 min on Render.

### Backup strategy
`pg_dump --schema-only --no-owner --no-acl > pre-g-a3-1.sql` against the
production read replica before maintenance window opens. Restore-test
on staging before proceeding.

### Maintenance window
**~30 minutes** for stamp + Render env-var flip + `apex-api` restart +
smoke test. Render free-tier cold-start adds ~30s to the restart, so
plan for ~5 min of read-only / 503 window.

### Monitoring during cutover
- `apex-api` startup logs (look for `Migrations: ran=False, reason=disabled_by_env`
  → after Phase 2 should be `Migrations: ran=True, applied=0` since stamp
  put us at head).
- Render health-check probe (`GET /health`) — should respond 200 within 30s
  of restart.
- A canary `POST /auth/login` to verify the DB connection survived stamp.

---

## Section E — Phase 2 Implementation Plan (timeline)

**Single-day execution. Two-phase split if conservatism is preferred.**

### Day 1, morning (1.5h)
- Audit `app/` for `Base` registrations (`grep -rn "Base.metadata.create_all\|Table(.*PhaseBase\|metadata=PhaseBase"` etc.).
- Update `alembic/env.py:_MODEL_MODULES`.
- Local verify loop (steps 3-4 above).

### Day 1, afternoon (1h)
- Spin up staging environment from production snapshot.
- Apply `alembic stamp head` to staging.
- Verify staging acceptance: `alembic current`, smoke test.

### Day 1, evening (30 min maintenance window)
- Production snapshot.
- `alembic stamp head` on production.
- Re-enable `RUN_MIGRATIONS_ON_STARTUP=true` in Render env.
- Restart `apex-api`. Verify deploy.
- Smoke test follow-up migration (a no-op CHECK constraint).

### Day 2 (cleanup)
- Update `09 § 2 G-A3.1` → ✅ DONE.
- Update `CLAUDE.md` "Migration management" to remove moratorium.
- Update `LOCAL_DEV_RUNBOOK.md` § 4 entry.
- Notify team: schema-change moratorium lifted.

---

## Section F — Open Questions

| Question | Required for Phase 2? | Owner |
|---|---|---|
| Does production already have a staging environment? | Yes | infra/devops |
| Who is the DBA reviewer for the `_MODEL_MODULES` audit? | Yes (low-touch review, 30 min) | TBD |
| Maintenance window scheduling — Sunday low-traffic slot? | Yes | product/ops |
| Should we also squash the 14 KB ghost migrations as part of A+? | No (cosmetic; can defer) | optional |
| Is there a way to fully exclude KB from alembic chain output? | Optional | future cleanup |
| Does Render have `pg_dump`-compatible backup tooling that we trust? | Yes | infra |

### Known unknowns

- Are there any tables in production that **aren't** in `PhaseBase.metadata`
  even after `_MODEL_MODULES` is fully populated? (E.g. tables created by
  raw `op.create_table` in older migrations and never modeled in Python.)
  Strategy A+ handles this gracefully — they stay un-managed by alembic
  but un-touched. Risk only manifests if we later try to drop them via
  autogenerate; mitigation is the post-fix verification loop.

---

## Verification footprint of this Phase 1 PR

- **Production database:** **NOT TOUCHED.**
- **Production `alembic_version` row:** **NOT TOUCHED.**
- **Render env variables:** **NOT TOUCHED.**
- **Alembic versions/ directory:** unchanged (draft autogenerated migration
  was generated locally, analyzed, and **deleted before this commit**).
- **Local files:** `extract_schema.py`, `extract_output.txt`, `test_a31.db`
  used during analysis — all deleted before commit.
- **Files added by this PR:** this report only.

## Cross-references

- `APEX_BLUEPRINT/09 § 2 G-A3.1` — the locked-in commitment.
- `APEX_BLUEPRINT/09 § 12 G-PROC-4` — workaround discipline pattern.
- `CLAUDE.md` "Migration management" — current production state.
- `LOCAL_DEV_RUNBOOK.md` § 4 "DuplicateTable error" — local dev troubleshooting.
- `alembic/env.py` — the multi-Base architecture documentation.
- `app/core/db_migrations.py` — the env-var honoring code.

---

## Decision requested before Phase 2

Approve **Sub-strategy A+** (stamp head + fix `env.py:_MODEL_MODULES`)
and the timeline above? Reply with "Approved: A+, schedule Phase 2"
to proceed.

If preferring a different option, indicate which (A pure / B full
catch-up / C reset / D hybrid) and the reasoning. Phase 2 will not
start without explicit approval per G-A3.1's locked-in protocol.
