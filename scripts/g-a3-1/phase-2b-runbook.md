# G-A3.1 Phase 2b — Production Runbook

> **Status:** 🟡 **DRAFT — requires explicit user "go" per step.** Do not
> execute Steps 3-6 until a human operator has confirmed the pre-flight
> checklist and given a clear "go" in chat. Steps 1-2 (verify-first +
> draft this runbook) are already complete — they live on the same branch.

| Field | Value |
|---|---|
| Sprint | 12 |
| Gap | G-A3.1 (🔴 LOCKED-IN) |
| Phase | 2b — production stamp + re-enable migrations |
| Branch | `sprint-12/g-a3-1-phase-2b-production-stamp` |
| Single head id to stamp | **`g1e2b4c9f3d8`** |
| Pre-Phase-2b workaround | `RUN_MIGRATIONS_ON_STARTUP=false` (Render apex-api env, applied 2026-05-02) |
| Investigation report | `APEX_BLUEPRINT/G-A3-1-investigation.md` § E |
| Maintenance window | TBD — ~30 min Sunday low-traffic recommended |
| Operator | Shadi (the user) — runs all production-affecting commands |
| Agent role | drafts + verifies; **never runs production commands without explicit "go" per step** |

---

## 1. Pre-flight checklist

Before starting Step 3, confirm every line below is ✅ in chat.

- [ ] Maintenance window agreed with stakeholder (Shadi).
- [ ] Render dashboard tab open on **apex-api → Environment** (for Step 5).
- [ ] Render dashboard tab open on **apex-db → Backups** (for Step 3).
- [ ] `psql --version` returns successfully on the operator's machine.
- [ ] `alembic --version` returns successfully (CLI usable from `C:\apex_app`).
- [ ] Production `DATABASE_URL` retrieved from Render dashboard (the
      External Database URL field). **NOT** copied into this runbook.
      **NOT** committed to any file.
- [ ] Current time recorded (for the PR description timeline).
- [ ] Deploy id of the last successful production deploy recorded
      (Render dashboard → apex-api → Events).
- [ ] `git status` is clean on `sprint-12/g-a3-1-phase-2b-production-stamp`
      (no uncommitted production-affecting drafts).
- [ ] Verification report from Step 1 acknowledged — single head
      `g1e2b4c9f3d8`, autogenerate empty diff, env-var gate intact.

If any line is not yet ✅, **stop here**. Resolve before requesting "go".

---

## 2. Production state assumed

| Surface | State |
|---|---|
| `apex-db` schema | 198 tables, built via `Base.metadata.create_all()` since Sprint 2-7 |
| `apex-db.alembic_version` row | empty / NULL / stale (last touched before the workaround) |
| `apex-api` env `RUN_MIGRATIONS_ON_STARTUP` | `false` |
| `app/main.py` startup path | calls `run_migrations_on_startup()` → short-circuits on `false` |
| Recent deploys | succeeding (workaround active) |

These assumptions are inherited from the Phase 1 investigation report.
If any has changed since Phase 1 closed, **stop and re-investigate**.

---

## 3. Step 3 — Production schema backup

🔴 **Production-affecting. Requires explicit "go on Step 3" in chat.**

### Method A — preferred (Render dashboard)

1. Open **Render dashboard → apex-db → Backups** tab.
2. Click **"Take manual backup"**.
3. Wait for the row to show status **Completed**.
4. **Record** the backup id and timestamp in chat for the PR description.

Pros: managed, restore is one-click via Render UI, no local file to handle.
Cons: timing depends on Render free-tier scheduling.

### Method B — fallback only (pg_dump)

Use only if Method A is unavailable for any reason.

```powershell
# PowerShell — run from C:\apex_app
$env:DATABASE_URL = "<production External URL — paste manually, never commit>"
pg_dump --schema-only --no-owner --no-acl --file=scripts/g-a3-1/pre-phase-2b-schema.sql
Remove-Item Env:DATABASE_URL
```

```bash
# Bash equivalent
DATABASE_URL="<production External URL — paste manually>" \
  pg_dump --schema-only --no-owner --no-acl \
  --file=scripts/g-a3-1/pre-phase-2b-schema.sql
unset DATABASE_URL
```

**Critical:**
- The `.sql` output is **gitignored** (`.gitignore` was updated in this PR
  with `scripts/g-a3-1/pre-phase-2b-schema.sql` and `scripts/g-a3-1/*.sql`).
  **Do not `git add` it. Do not commit it.**
- **Verify** the dump is non-empty: `(Get-Item scripts/g-a3-1/pre-phase-2b-schema.sql).Length` (PowerShell) or `wc -c scripts/g-a3-1/pre-phase-2b-schema.sql` (bash). Expect > 100 KB for a 198-table schema dump.
- **Verify** restore-ability on staging if available before proceeding (out of scope here unless staging is set up; otherwise rely on Method A which is restore-tested by Render).

### Post-Step-3 chat reply (operator)

Reply with one of:

- ✅ "Backup A done — id `<id>`, timestamp `<ts>`" — proceed to "go on Step 4".
- ✅ "Backup B done — file size `<bytes>` at `scripts/g-a3-1/pre-phase-2b-schema.sql`" — proceed.
- ❌ "Backup failed — `<reason>`" — **stop**, do not proceed to Step 4.

---

## 4. Step 4 — `alembic stamp head` on production

🔴 **Production-affecting. Requires explicit "go on Step 4" in chat.**

### Pre-check (read-only)

```powershell
# PowerShell
$env:DATABASE_URL = "<production External URL — paste manually, never commit>"
psql "$env:DATABASE_URL" -c "SELECT version_num FROM alembic_version;"
```

```bash
# Bash
DATABASE_URL="<production External URL — paste manually>" \
  psql "$DATABASE_URL" -c "SELECT version_num FROM alembic_version;"
```

**Record** the current value. Expected:
- `(0 rows)` — alembic_version row absent (most likely)
- a stale revision id (e.g. one of the 7 in the chain)

This is read-only. No harm if the table doesn't exist (psql returns an error message).

### Stamp command

```powershell
# PowerShell — from C:\apex_app
cd C:\apex_app
$env:DATABASE_URL = "<production External URL — paste manually, never commit>"
alembic stamp head
```

```bash
# Bash equivalent
cd /c/apex_app
DATABASE_URL="<production External URL — paste manually>" alembic stamp head
```

### Expected output

```
INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
INFO  [alembic.runtime.migration] Will assume transactional DDL.
INFO  [alembic.runtime.migration] Running stamp_revision  -> g1e2b4c9f3d8
```

**No DDL.** **No data changes.** Single `INSERT INTO alembic_version` (or
`UPDATE` if a stale row existed).

### Post-check

```powershell
psql "$env:DATABASE_URL" -c "SELECT version_num FROM alembic_version;"
Remove-Item Env:DATABASE_URL
```

Expected:

```
 version_num
--------------
 g1e2b4c9f3d8
(1 row)
```

If the value is anything other than `g1e2b4c9f3d8`, **stop and rollback**:

```powershell
psql "$env:DATABASE_URL" -c "DELETE FROM alembic_version;"
```

(Then troubleshoot — likely the stamp command targeted the wrong DB.)

### Post-Step-4 chat reply (operator)

Reply with one of:

- ✅ "Stamp head done — version_num=`g1e2b4c9f3d8`, no DDL" — proceed to "go on Step 5".
- ❌ "Stamp head failed — `<error>`" — **stop**, do not proceed to Step 5.

---

## 5. Step 5 — Flip `RUN_MIGRATIONS_ON_STARTUP` env var

🔴 **Production-affecting. Requires explicit "go on Step 5" in chat.**

This step is a Render dashboard action — there is no CLI command.

### Procedure

1. Open **Render dashboard → apex-api → Environment** tab.
2. Find the entry `RUN_MIGRATIONS_ON_STARTUP` (currently `false`).
3. Click the edit pencil → change value from `false` to `true`.
4. Click **Save changes**.

Saving the env var **automatically triggers a redeploy** of `apex-api`.

### What to watch

- The Render UI shows a new deploy entry under apex-api → Events.
- **Record the new deploy id** — it goes in the PR description.

### Post-Step-5 chat reply (operator)

Reply with one of:

- ✅ "Env var flipped — new deploy id `<id>` building" — proceed to "go on Step 6".
- ❌ "Save failed — `<error>`" — **stop**, do not proceed to Step 6.

---

## 6. Step 6 — Deploy verification + smoke tests

🔴 **Production verification. Requires explicit "go on Step 6" in chat.**

The deploy from Step 5 finishes in ~1-2 minutes typically (Render free
tier may be slower). While it's building, prep the smoke-test commands.

### 6a. Deploy log — required success strings

Watch **Render dashboard → apex-api → Logs** for the new deploy. **All of**
the following strings must appear:

- `[ALEMBIC]` block header (or equivalent log line indicating migrations ran).
- `INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.`
- Either:
  - **No `Running upgrade` lines** (means alembic was already at head — the stamp from Step 4 made `upgrade head` a no-op, ✅), OR
  - Exactly one `INFO  [alembic.runtime.migration] Running upgrade  -> g1e2b4c9f3d8` line (acceptable if alembic interpreted stamp as "version recorded but upgrade still walks" — semantically equivalent to no-op since DB is already at head).
- `Application startup complete.` (uvicorn ready signal) OR equivalent.

### 6b. Deploy log — failure strings (any of these → ABORT + ROLLBACK)

If you see any of these in the deploy log, **immediately go to § 7 Rollback**:

- `DuplicateTable`
- `relation "..." already exists` (especially `hr_employees`, `pilot_*`, `knowledge_*`)
- `Can't locate revision identified by`
- `MultipleHeads`
- Any Python traceback in or after the alembic block.
- Application fails to bind to port (check `uvicorn` log lines).

### 6c. HTTP smoke tests

After the deploy shows **Live**:

```bash
# 1. Health check
curl -i https://apex-api-ootk.onrender.com/health
# Expected: HTTP/1.1 200 OK + JSON body

# 2. Authenticated /me
# (use a JWT from a known test user; do NOT paste real tokens into PR/runbook)
curl -i -H "Authorization: Bearer <test-token>" \
  https://apex-api-ootk.onrender.com/api/v1/auth/me
# Expected: HTTP/1.1 200 OK
```

### 6d. Database smoke queries

```powershell
$env:DATABASE_URL = "<production External URL — paste manually>"

# 1. Existing data preserved
psql "$env:DATABASE_URL" -c "SELECT COUNT(*) FROM hr_employees;"
# Expected: existing count, no error

# 2. alembic stamp persisted
psql "$env:DATABASE_URL" -c "SELECT version_num FROM alembic_version;"
# Expected: g1e2b4c9f3d8 (still — restart didn't change it)

Remove-Item Env:DATABASE_URL
```

### Post-Step-6 chat reply (operator)

Reply with one of:

- ✅ "Deploy verified — all success strings present, smoke tests 200 OK, alembic_version still `g1e2b4c9f3d8`" — proceed to "Phase 2b done, proceed to docs".
- ⚠️ "Deploy verified BUT `<oddity>`" — describe; agent will investigate before docs closure.
- ❌ "Failure detected — `<which failure string>`" — **invoke § 7 Rollback immediately**.

---

## 7. Rollback procedure

If **any** failure is detected after Step 5 saves (deploy log shows a
failure string, OR `/health` returns non-200, OR `/auth/me` fails, OR
the DB smoke queries show unexpected results):

1. **Render dashboard → apex-api → Environment**.
2. Edit `RUN_MIGRATIONS_ON_STARTUP` back from `true` → `false`.
3. **Save changes** — this triggers another redeploy.
4. Wait for the redeploy to reach **Live** status.
5. Re-run the HTTP smoke tests in § 6c — production is back to the
   pre-Phase-2b workaround state.

**The `alembic_version` row remains stamped** with `g1e2b4c9f3d8` after
rollback. This is **harmless**: `create_all()` ignores `alembic_version`,
and the row simply records the recovery point for the next attempt.

After rollback:

- Open an incident note in `09 § 12 G-PROC-4` documenting:
  - What failure was observed.
  - Which step (3 / 4 / 5 / 6).
  - Root cause if known.
  - Plan to retry or escalate.
- Notify Shadi.
- **Do not** retry Phase 2b until the root cause is understood and a
  new runbook iteration addresses it.

---

## 8. Security notes

- **Never** commit a real `DATABASE_URL` value into this runbook or any
  other repo file. Always use the placeholder
  `<production External URL — paste manually, never commit>`.
- The `pg_dump` `.sql` output (Method B fallback) is **gitignored**.
  See `.gitignore`'s `scripts/g-a3-1/pre-phase-2b-schema.sql` and
  `scripts/g-a3-1/*.sql` patterns added by this PR.
- The PR description for Phase 2b will **redact** any URL/credentials
  before paste — only timestamps, deploy ids, and version_num values
  go into the public PR.
- Test JWT tokens used for smoke tests must be **revoked or rotated**
  after the verification, per standard test-credential hygiene.
- Render's "Take manual backup" (Method A) does not produce a local
  artifact — the backup lives in Render's managed storage and is
  referenced by id only. This is the reason Method A is preferred.

---

## 9. Post-closure checklist (Step 7 — local docs after Phase 2b confirmed live)

After the operator confirms "Phase 2b done, proceed to docs", the agent
updates four locations on this same branch:

1. **`APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md`** — § 2 G-A3.1 entry
   - Header marker 🔴 → ✅, "**LOCKED-IN — Sprint 12 Priority #1
     (Mandatory)**" → "**FULLY DONE 2026-05-XX**".
   - Append closure note: *"Phase 2b shipped on 2026-05-XX (deploy
     id `<id>`, backup id `<id>`). Production now runs on alembic.
     `RUN_MIGRATIONS_ON_STARTUP=true`. Locked-in priority cleared."*

2. **`APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md`** — § 12 G-PROC-4 registry
   - Mark the G-A3.1 row as **resolved** with the closure date.
   - If the registry is now empty: add a one-line note *"Registry
     currently empty — workaround discipline pattern remains active
     for any future locked-in gap."*

3. **`CLAUDE.md`** — "Common Pitfalls" → "Migration management" subsection
   - Remove the "Render production env: `RUN_MIGRATIONS_ON_STARTUP=false`"
     line.
   - Remove the "Schema changes via alembic BLOCKED" notice.
   - Replace with: *"Schema changes managed via alembic
     (`alembic revision --autogenerate -m "..."`). G-A3.1 closed
     Sprint 12 — alembic + `create_all()` coexist; alembic is
     authoritative on production."*
   - Keep the "173 currently-untracked tables" historical note but
     mark it **resolved**.

4. **`PROGRESS.md`** — Sprint 12 plan
   - Mark Phase 2b ✅ DONE with the closure date and PR link.
   - Lift the "PR review constraints active" block (the moratorium).

---

## 10. PR description template (Step 8 — after docs closure)

The PR opened from this branch must include:

- **What changed on production:**
  - Backup id / timestamp from Step 3.
  - Stamp command output excerpt (with redacted URL).
  - Pre-stamp `alembic_version` value (likely empty / NULL).
  - Post-stamp `alembic_version` value (`g1e2b4c9f3d8`).
  - Render env var change: `RUN_MIGRATIONS_ON_STARTUP` `false` → `true`.
  - New deploy id from Step 5.
- **Verification evidence:**
  - Deploy log excerpt with success strings (URL/token redacted).
  - HTTP smoke test responses (status codes only).
  - DB smoke query results (counts only, no data leakage).
- **Rollback procedure:** copy of § 7 above.
- **Locked-in registry change:** G-A3.1 cleared from § 12 G-PROC-4.
- **Files changed (this PR):**
  - `scripts/g-a3-1/phase-2b-runbook.md` (this file — drafted in Step 2).
  - `.gitignore` (Phase 2b dump patterns).
  - `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md` (§ 2 + § 12 closure).
  - `CLAUDE.md` (Migration management rewrite).
  - `PROGRESS.md` (Sprint 12 closure).

PR title:
```
Sprint 12: G-A3.1 Phase 2b — production stamp head, lift moratorium
```

---

## Appendix A — recovery scenarios beyond § 7

These are deeper-failure cases that § 7's "set env back to false" does
not cover. None should occur if Steps 3-6 are followed in order, but
documenting them ensures the operator knows where to escalate.

| Scenario | Symptom | Recovery |
|---|---|---|
| Stamp targeted wrong DB | `version_num` doesn't appear in apex-db post-stamp | Re-run stamp with the correct `DATABASE_URL`; if stamped on wrong DB, `DELETE FROM alembic_version;` on that DB. |
| `alembic stamp head` modified DDL unexpectedly | Schema mismatch in smoke queries | This should be impossible — stamp is metadata-only. If observed, restore from Method A backup. |
| Smoke test `/health` 200 but `/auth/me` 500 | App started but routing broke | Likely unrelated to Phase 2b; investigate via app logs. Rollback env var if uncertain. |
| `hr_employees` count is `0` post-deploy (was non-zero pre-Phase-2b) | Data loss | Restore from Method A backup immediately; escalate to incident. |

## Appendix B — verification commands quick-reference

For the operator to copy-paste during execution. **All require
production `DATABASE_URL` set in env first.**

```powershell
# Pre-stamp check
psql "$env:DATABASE_URL" -c "SELECT version_num FROM alembic_version;"

# Post-stamp check
psql "$env:DATABASE_URL" -c "SELECT version_num FROM alembic_version;"
# Expected: g1e2b4c9f3d8

# Smoke query — data preserved
psql "$env:DATABASE_URL" -c "SELECT COUNT(*) FROM hr_employees;"

# Smoke query — ICV sequence (the one that broke locally per Phase 1)
psql "$env:DATABASE_URL" -c "SELECT COUNT(*) FROM journal_entry_sequence;"

# Smoke query — listing all tables
psql "$env:DATABASE_URL" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"
# Expected: ~198

# Always clear the env var when done
Remove-Item Env:DATABASE_URL
```

---

**End of runbook draft.** Awaiting operator's "go on Step 3" — first
production-affecting action.
