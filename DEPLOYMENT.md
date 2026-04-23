# APEX — Deployment & Operations Runbook

_Last updated: 2026-04-23_

This document is the single source of truth for how APEX is deployed,
monitored, backed up, and rolled back. It covers **production** and
**staging** environments on Render + GitHub Pages.

---

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│  GitHub repo  shadyapoelela-cloud/apex-web                      │
│  Branches:                                                       │
│    main      → prod                                             │
│    staging   → staging (new)                                    │
├────────────────────────────────────────────────────────────────┤
│ On push to main  → triggers Render auto-deploy (apex-api) +     │
│                    GitHub Pages rebuild (docs/ → apex-web.*)     │
│ On push to staging → triggers Render staging deploy              │
└────────────────────────────────────────────────────────────────┘
                       │                        │
                       ▼                        ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│  PRODUCTION                  │   │  STAGING                     │
│  apex-api.onrender.com       │   │  apex-api-staging.onrender   │
│  Postgres: apex-db           │   │  Postgres: apex-db-staging   │
│  Pages:    /apex-web/        │   │  (same Pages; base-href      │
│            (base=/apex-web/) │   │   = /apex-web/, feature-     │
│                              │   │   flagged by commit)         │
└──────────────────────────────┘   └──────────────────────────────┘
                │
                ▼ (03:00 UTC nightly)
┌──────────────────────────────┐
│  apex-api-backup (cron)       │
│  pg_dump | gzip | S3 upload  │
│  30-day retention in S3      │
└──────────────────────────────┘
```

---

## 2. Environments

### 2.1 Production

| Key | Value |
|---|---|
| Branch | `main` |
| API URL | https://apex-api-ootk.onrender.com |
| Web URL | https://shadyapoelela-cloud.github.io/apex-web/ |
| DB | `apex-db` (free tier, 1 GB) |
| Auto-deploy | ✅ on push to `main` |
| Sentry env | `production` |
| Traces sample rate | 5 % |

### 2.2 Staging

| Key | Value |
|---|---|
| Branch | `staging` |
| API URL | https://apex-api-staging.onrender.com |
| Web URL | same as prod (base-href shared) |
| DB | `apex-db-staging` (isolated from prod) |
| Auto-deploy | ✅ on push to `staging` |
| Sentry env | `staging` |
| Traces sample rate | 100 % (full tracing for debugging) |

### 2.3 Local development

```bash
# Copy .env.example → .env and fill in the values you need.
cp .env.example .env

# Backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend
cd apex_finance
flutter pub get
flutter run -d chrome --web-port=5000
```

---

## 3. One-time setup tasks (Render dashboard)

These cannot be automated from a PR; a human with dashboard access
must do them once per environment.

### 3.1 Create the staging service

1. Render Dashboard → **New +** → **Blueprint**
2. Point it at the repo root (`render.yaml` defines everything).
3. Render parses the blueprint and offers to create:
   - `apex-api` (prod web) — already exists, skip
   - `apex-api-staging` (new web) — click **Create**
   - `apex-api-backup` (new cron) — click **Create**
   - `apex-db-staging` (new Postgres) — click **Create**
4. Create a `staging` branch in GitHub:
   ```bash
   git checkout -b staging main
   git push -u origin staging
   ```
5. Render picks up the new branch on the next push.

### 3.2 Sentry DSN

1. Sign up / log in at https://sentry.io
2. Create projects:
   - `apex-backend` (Python → FastAPI)
   - `apex-frontend` (Flutter)
3. Copy the DSN of each.
4. Render Dashboard → `apex-api` → **Environment** →
   add `SENTRY_DSN` (mark **Secret** / sync false).
5. Repeat for `apex-api-staging`.
6. Redeploy; check logs for
   `Sentry observability initialized` at startup.

### 3.3 S3 bucket for backups

1. Create an S3 bucket (or compatible — DigitalOcean Spaces, Wasabi,
   MinIO). Suggested name: `apex-backups-prod`.
2. Enable **Versioning** (extra safety net).
3. Create an IAM user with `s3:PutObject`, `s3:GetObject`,
   `s3:DeleteObject`, `s3:ListBucket` on that bucket only.
4. Render Dashboard → `apex-api-backup` → **Environment** → add:
   - `BACKUP_S3_BUCKET` = bucket name
   - `BACKUP_S3_REGION` = e.g. `me-south-1`
   - `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` (both as Secret)
5. Next cron run at 03:00 UTC will upload automatically; log line:
   `Uploaded to s3://apex-backups-prod/apex/YYYY/MM/DD/…`.

### 3.4 Enable CSRF in production (after frontend cookie migration is verified)

1. Verify the frontend sets `credentials: 'include'` on all
   state-changing fetches (already scaffolded in `api_service.dart`).
2. Render Dashboard → `apex-api` → **Environment** → change
   `CSRF_ENABLED=false` → `CSRF_ENABLED=true`.
3. Redeploy.
4. Smoke-test: issue a POST WITHOUT the `X-CSRF-Token` header →
   expect HTTP 403 with `{error: CSRF_TOKEN_INVALID}`.

---

## 4. Daily operations

### 4.1 Deploy a change

```bash
# feature work
git checkout -b feature/thing main
# … edits …
git push -u origin feature/thing

# merge to staging first (never straight to main)
git checkout staging
git pull
git merge feature/thing
git push             # → auto-deploys to staging

# verify on https://apex-api-staging.onrender.com
# then promote
git checkout main
git pull
git merge staging
git push             # → auto-deploys to prod + Pages
```

### 4.2 Rollback

**Backend:**

```bash
# Find the last good commit sha
git log --oneline -10

# Hard-reset main (use with care — destructive)
git checkout main
git reset --hard <good_sha>
git push --force-with-lease

# Render picks up the force-push and redeploys the old code.
```

If the rollback involves a schema change, also roll back the migration:

```bash
# Render Shell (Dashboard → apex-api → Shell)
alembic downgrade -1
```

**Frontend (Pages):**

The `docs/` folder in the repo IS the live site. `git revert` that
commit and push → Pages redeploys.

### 4.3 Restore from backup

```bash
# List available backups
aws s3 ls s3://apex-backups-prod/apex/ --recursive

# Download the one you want
aws s3 cp s3://apex-backups-prod/apex/2026/04/22/apex_backup_…sql.gz .

# Restore (into a fresh or cleared DB)
gunzip -c apex_backup_*.sql.gz | psql $DATABASE_URL
```

### 4.4 Warm-up (Render free-tier cold starts)

Render free spins down after 15 min of idle. First request after spin-
down takes 10–15 s. Mitigations:

- A simple cron (e.g. cron-job.org) that GETs `/health` every 10 min.
- Or upgrade to a paid plan ($7/mo) — no spin-down.

---

## 5. Observability

### 5.1 Sentry

- **Issues** — https://sentry.io/organizations/…/issues/?project=apex-backend
- **Performance** — same project, Performance tab; filter by env.
- Release tagging: set `SENTRY_RELEASE` to the git sha in CI (TODO).

### 5.2 Logs

- Render → service → **Logs** tab (JSON-formatted when
  `LOG_FORMAT=json`).
- Each request carries `request_id` (from middleware) so grep-friendly.

### 5.3 Health probes

```bash
# Backend
curl https://apex-api-ootk.onrender.com/health

# Expected:
# {"status":"ok", "version":"12.0.0", "database":true,
#  "phases":{"p1":true, ..., "p11":true}, ...}
```

---

## 6. Security flags currently active

| Flag | State | Location |
|---|---|---|
| JWT secret length enforced (≥ 32 B) | ✅ | `app/core/auth_utils.py` |
| HS256 (symmetric) | ✅ | same |
| Password hash: bcrypt cost 12 | ✅ | `app/phase1/services/auth_service.py` |
| Login rate limit (5 fails → 15 min lockout) | ✅ | same |
| CORS explicit allowlist in prod | ✅ | `app/main.py` |
| Rate limiting middleware | ✅ | `app/main.py` line 849 |
| Audit log middleware | ✅ | `app/main.py` |
| Tenant context + guard | ✅ | `app/main.py` |
| Postgres Row-Level Security | ✅ | `app/core/rls_session.py` |
| Sentry observability | ⚠ code ready | set `SENTRY_DSN` to activate |
| **HttpOnly cookie auth** | ⚠ code ready | login sets cookie; frontend migration pending |
| **CSRF middleware (double-submit)** | ⚠ code ready | set `CSRF_ENABLED=true` |
| Email verification | ✅ | `/auth/email/*` endpoints live |
| TOTP / MFA | ✅ | `/auth/totp/*` + `/account/mfa` UI |
| DB CHECK constraints (JE balance, VAT unique) | ✅ | alembic migration `e4c7d9f8a123` |

---

## 7. Pending dashboard actions (TODO)

- [ ] Create `staging` branch + apex-api-staging service (§3.1)
- [ ] Register Sentry project + set SENTRY_DSN (§3.2)
- [ ] Provision S3 backup bucket + set backup env vars (§3.3)
- [ ] Flip CSRF_ENABLED=true after frontend cookie migration verified (§3.4)
