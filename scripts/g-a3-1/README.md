# scripts/g-a3-1/

Operator hygiene scripts for **locked-in production priorities** —
captured from the lessons of G-A3.1 Phase 2b (2026-05-03) so the next
locked-in priority that touches alembic state on production has a
ready toolbelt instead of ad-hoc SQL composed under maintenance-window
pressure.

> 🟡 **Production-affecting tools live here. Read this README before
> running anything against `apex-db`.** Each script has its own safety
> gates (typed confirmations, `--prod` flags, fail-fast preflight); the
> scripts encode discipline, not replace it.

## When to use these scripts

Use this directory when **all** of the following hold:

1. A locked-in priority (per `09 § 12 G-PROC-4`) requires a
   schema-state mutation on production (e.g., another `alembic stamp`,
   an `alembic_version` row repair, a manual smoke-test sweep).
2. The change has been investigated + designed (Phase 1) and any
   `env.py:_MODEL_MODULES` or autogenerate-correctness work is done
   (Phase 2a) — same shape as G-A3.1's three-phase split.
3. A maintenance window is scheduled and a backup plan exists (per
   `phase-2b-runbook.md` § 1 pre-flight checklist).

For everyday schema changes (new model + `alembic revision
--autogenerate -m "..."`), use the alembic CLI directly — these
scripts are for the *production state-mutation* corner case, not
routine migrations.

## Order of execution

```
1. install_prereqs.{ps1,sh}    once per operator machine
2. preflight.py                immediately before any prod action
3. stamp_head.py               the actual production state mutation
4. smoke_tests.py              immediately after Render redeploy
```

`stamp_head.py` and `smoke_tests.py` are decoupled — each can run
independently if only one phase is needed (e.g. "Render env-var flip
already happened; just smoke-test").

## File index

| File | Purpose | Production-affecting? |
|---|---|---|
| `phase-2b-runbook.md` | Canonical Phase 2b runbook (G-A3.1 closure). Reference, not script. | No — docs only |
| `pre-phase-2b-schema.sql` | Output dir for `pg_dump` Method B fallback (gitignored — never committed). | Operator-only |
| `README.md` | This file. | No |
| `install_prereqs.ps1` | Windows: detect Python, install `psycopg2-binary` (user scope), report psql. | No (local install only) |
| `install_prereqs.sh` | Linux / Render shell: same as the .ps1, bash flavor. | No (local install only) |
| `preflight.py` | Pre-execution sanity check (Python ≥ 3.10, psycopg2, DATABASE_URL valid + connects, alembic head matches, git clean on `sprint-*` branch). Read-only. | **Read-only** (touches DB only with `SELECT 1`) |
| `stamp_head.py` | psycopg2-based `alembic stamp head` equivalent. Refuses to run without `--prod` flag. Requires operator to type `STAMP` to confirm. Idempotent via `ON CONFLICT DO NOTHING`. | **YES** — writes `alembic_version` row |
| `smoke_tests.py` | Post-deploy verification: HTTP `/health`, `alembic_version` query, `hr_employees` count query. Read-only. | **Read-only** |

## Security notes

- **`DATABASE_URL` is never committed.** All scripts read it from the
  environment. The runbook (`phase-2b-runbook.md`) instructs operators
  to paste the production URL manually only in their shell session and
  `Remove-Item Env:DATABASE_URL` (or `unset DATABASE_URL`) when done.
- **`pg_dump` output is gitignored.** `.gitignore` includes
  `scripts/g-a3-1/pre-phase-2b-schema.sql` and `scripts/g-a3-1/*.sql`
  patterns. If Method B fallback is used, the `.sql` file stays local.
- **No backup `.sql` is ever committed.** Use Method A (Render
  dashboard manual backup) when possible — Render holds the artifact
  and references it by id, no local file to handle.
- **PR descriptions redact secrets.** When pasting `stamp_head.py`'s
  PR-paste-ready output into a PR, the host is shown redacted (no
  username, no password).
- **Password rotation** after a maintenance window is a separate
  operator task on Render — these scripts neither rotate nor read
  passwords.

## Why no automatic psql install

During G-A3.1 Phase 2b on 2026-05-03, the operator's machine could not
install PostgreSQL CLI via `winget install PostgreSQL.PostgreSQL.{17,16}`.
Both retries died at exactly 134 MB / ~350 MB with **HTTP 403
Forbidden** against the EnterpriseDB CDN — the operator was in Saudi
Arabia and EDB's CDN appears to block that region.

The maintenance window stretched from a planned 30 min to ~90 min as
the operator pivoted to composing alembic-stamp-head SQL via psycopg2
inline (see `APEX_BLUEPRINT/09 § 2 G-A3.1` closure paragraph for the
exact statements run).

`install_prereqs.{ps1,sh}` therefore intentionally **never tries to
install psql automatically**. It reports whether psql is present
(informational) but stops there. `psycopg2-binary` covers every DB op
the runbook needs and comes from PyPI (no CDN regional 403s observed).
A future operator hit by the same regional block won't waste the
maintenance window retrying a known-failing install path.

If a future operator wants psql:

- **Best path:** install via the operator's distro package manager
  (`apt`, `dnf`, `brew`) which uses different CDN paths.
- **Render shell:** psql is not pre-installed; use psycopg2 there too.
- **Fallback Windows:** download the `.zip` archive from
  https://www.enterprisedb.com/download-postgresql-binaries directly
  via a different network path (e.g. mobile hotspot) — this is what
  the Phase 2b operator did *after* the maintenance window closed,
  for unrelated future use.

## Cross-references

- **`scripts/g-a3-1/phase-2b-runbook.md`** — canonical 454-line
  runbook for the kind of work these scripts support. The runbook
  is **the** spec; these scripts encode pieces of it.
- **`APEX_BLUEPRINT/G-A3-1-investigation.md`** — Phase 1
  investigation report. § E lays out the Phase 2 plan; these scripts
  are tooling for the same shape of work in any future locked-in.
- **`APEX_BLUEPRINT/09 § 2 G-A3.1`** — closure paragraph including
  the operator-divergence note about the EDB 403 block and the exact
  psycopg2 SQL run on production 2026-05-03.
- **`APEX_BLUEPRINT/09 § 12 G-PROC-4`** — workaround discipline
  pattern + locked-in priorities registry. The `🔴 LOCKED-IN`
  marker is what triggers consideration of these scripts.

## Tested how?

Each script was tested locally against:

- `install_prereqs.{ps1,sh}` — operator's own machine (Python 3.14,
  psycopg2 2.9.12 already installed; idempotent re-run leaves state
  unchanged).
- `preflight.py` — sqlite URL passes connection check; git status
  + branch checks honored on `sprint-12/g-a3-1-1-operator-scripts`.
- `stamp_head.py` — sqlite (`sqlite:///tmp_test.db`) end-to-end:
  refuses without `--prod`, requires confirmation, stamps a fake
  revision id, post-check verifies the row, idempotent re-run
  preserves the row.
- `smoke_tests.py` — sqlite + stdlib `http.server` stub serving a
  `/health` JSON response; all three checks pass against the test
  fixtures.

**No script has been or will be run against `apex-db`** as part of
this PR. Production use happens during a future locked-in priority's
maintenance window, with operator-typed confirmations gating each
mutation.

## When to NOT use these scripts

- **Routine schema changes.** Use `alembic revision --autogenerate
  -m "..."` directly. These scripts are for state-mutation corner
  cases, not the daily migration flow.
- **Knowledge Brain DB changes.** KB runs on a separate database
  (`KB_DATABASE_URL`) with its own `Base`; alembic targets only
  `PhaseBase.metadata` (see `alembic/env.py` header comment). KB
  schema is `create_all()`-managed; these scripts don't help.
- **Local dev setup.** Local dev sets `RUN_MIGRATIONS_ON_STARTUP=false`
  by default and runs `create_all()` from `app/main.py`'s lifespan.
  No stamp/smoke needed for local work.
