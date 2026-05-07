# Dev / Ops Scripts

Small, mostly-stdlib Python tools that live outside the FastAPI app
itself — used by humans during development and ops work.

## post_deploy_runbook.py

Single-shot operations script for the four common post-merge actions.
Replaces the ad-hoc `curl` recipes that used to live in PR
descriptions for #170 (legacy-tenant migration) and #171 (demo data
seeder).

### Quick start

```bash
# Set credentials once per shell:
export ADMIN_SECRET="…"
export APEX_USERNAME="…"
export APEX_PASSWORD="…"

# Run everything (recommended after every merge to main):
python3 scripts/dev/post_deploy_runbook.py --all
```

If env vars aren't set the script prompts (the password prompt is
silent — never echoed or logged).

### What each step does

| Flag                | Action                                                                              | Required env / arg                                  |
|---------------------|-------------------------------------------------------------------------------------|-----------------------------------------------------|
| `--verify-deploy`   | GETs the gh-pages `main.dart.js`, checks size + key sentinel substrings.            | (none)                                              |
| `--migrate-legacy`  | POST `/admin/migrate-legacy-tenants` — one-shot backfill from PR #170.              | `ADMIN_SECRET` (skips cleanly if absent)            |
| `--seed-demo`       | POST `/api/v1/account/seed-demo-data` — seed the caller's own tenant (PR #171).     | `APEX_USERNAME`, `APEX_PASSWORD`                    |
| `--smoke-test`      | Hits `/health`, `/`, and the authed `/api/v1/account/profile` + `/dashboard/widgets`. | `APEX_USERNAME`, `APEX_PASSWORD` (for authed half)  |
| `--all`             | All of the above. Implied if no specific flag is passed.                            | All vars above                                      |

`--force-seed` re-seeds the caller's tenant even if it already has
data — does NOT delete anything; appends a fresh batch with
6-hex-char-suffixed codes so the unique constraints don't fire.

### Custom API base

```bash
python3 scripts/dev/post_deploy_runbook.py --all \
    --api https://apex-api-staging.example.com
```

Or set `APEX_API_URL` in the env. Default is the production
Render-hosted API.

### Exit codes

- `0` — every selected step returned OK.
- `1` — any step returned a failure (network, 5xx, auth rejection,
  unexpected response shape). The summary table at the end of the
  run identifies which one.

### Sentinel checks (`--verify-deploy`)

The deploy verifier scans the gh-pages bundle for substrings that
recent PRs are known to drop:

| Substring                         | Source ticket            |
|-----------------------------------|--------------------------|
| `erp/finance/receipt-capture`     | G-CHIPS-WIRE-FIN-1       |
| `erp/finance/vat-return`          | G-CHIPS-WIRE-FIN-1       |
| `apexAuthRefresh`                 | ERR-1                    |
| `seed-demo-data`                  | G-DEMO-DATA-SEEDER       |

Missing sentinels surface as `[MISS]` in the per-line output and a
single warning line at the end. The step still returns success — a
runbook against staging or a custom build shouldn't fail just because
the latest PR isn't deployed there yet. (When you DO want a sentinel
miss to be a hard failure, wrap the runbook invocation: `python3
scripts/dev/post_deploy_runbook.py --verify-deploy 2>&1 | tee log;
grep -q '0 sentinel' log` or similar.)

### Tests

`tests/test_post_deploy_runbook.py` — 26 unit tests, all stub the
HTTP layer so they never hit the network. Run them like any other
pytest module:

```bash
python3 -m pytest tests/test_post_deploy_runbook.py -v
```

---

## Other scripts in this directory

| File                              | Purpose                                                                                |
|-----------------------------------|----------------------------------------------------------------------------------------|
| `audit_tenant_tables.py`          | Regenerates `docs/TENANT_TABLES_AUDIT_<date>.md` from `__tablename__` declarations.    |
| `chip_wiring_audit.md`            | Reconnaissance audit from G-CHIPS-WIRE-FIN-1 (PR #161). Frozen in time.                |
| `regenerate_wired_keys.py`        | Regenerates `apex_finance/lib/core/v5/v5_wired_keys.dart` from `v5_wired_screens.dart`. |
| `repro_routing_bugs.py`           | Idempotent regression check for the V5 routing pin bugs HOTFIX-Routing closed.         |
| `run-backend.{ps1,sh}`            | Local dev wrappers: print + run the underlying `uvicorn` command.                       |
| `run-frontend.{ps1,sh}`           | Local dev wrappers: print + run the underlying `flutter run` command.                   |
