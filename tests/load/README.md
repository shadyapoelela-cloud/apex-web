# APEX Load Testing

Two complementary tools:

1. **`tests/test_api_latency_bench.py`** — fast, in-process micro-benchmark that runs
   with every `pytest` invocation. Catches regressions where a
   hot-path endpoint suddenly takes 3× longer. No external deps.

2. **`tests/load/locustfile.py`** — full traffic-shape simulation
   against a running server. Requires `pip install locust`.

---

## Running

### Micro-benchmark (seconds, always-on)
```bash
pytest tests/test_api_latency_bench.py -v
```
Six hot endpoints exercised, each asserts its p50 stays under the
ceiling documented in the test.

### Full load run (minutes, opt-in)
Prerequisite once:
```bash
pip install locust
```

Against a local dev server:
```bash
# Interactive UI at http://localhost:8089
locust -f tests/load/locustfile.py --host=http://localhost:8000

# Headless smoke — 10 users, 30 seconds
locust -f tests/load/locustfile.py --headless \
  --host=http://localhost:8000 \
  --users=10 --spawn-rate=2 --run-time=30s

# CI-style report to HTML + CSV
locust -f tests/load/locustfile.py --headless \
  --host=http://localhost:8000 \
  --users=50 --spawn-rate=5 --run-time=2m \
  --html=load-report.html --csv=load-report
```

### Traffic mix (matches production-expected distribution)

| User class | Weight | What it does |
|------------|-------:|--------------|
| `FastPathUser`     | 80% | GET notifications / activity / branding / system-health |
| `WriteUser`        | 15% | POST comments, trigger AI scans, CSV downloads |
| `ZatcaSubmitter`   |  5% | Full submit-e2e → poll → PDF download |

Each user gets a unique `tenant_id` on `on_start`, so RLS is
exercised realistically (many tenants, each seeing only their own
rows).

---

## What to look for

### Good baseline on local dev (SQLite + single worker):
| Endpoint | p50 target | p99 target |
|----------|-----------:|-----------:|
| `/system/health` | < 200 ms | < 500 ms |
| `/notifications` | < 100 ms | < 300 ms |
| `/activity/recent` | < 150 ms | < 400 ms |
| `/tenant/branding` | < 100 ms | < 300 ms |
| `/reports/download csv` | < 200 ms | < 800 ms |
| `/activity/.../comment` POST | < 300 ms | < 800 ms |
| `/zatca/submit-e2e` | < 1 s | < 3 s |

### Red flags

- p99 > 5× p50 on any endpoint → tail-latency problem (GC, cold DB pool)
- `/system/health` degrading → one of the 6 subsystem checks is slow;
  add logging inside `_check_*` to find the culprit
- `/zatca/submit-e2e` > 3s p99 → Fatoora API timeout; retry queue
  should be absorbing this but check `dead` count after the run
- `/notifications` p50 rising with row count → activity_log missing an
  index on (tenant_id, created_at); see alembic migration c7f1a9b02e10

---

## Against PostgreSQL with RLS

To test the real production shape:
```bash
DATABASE_URL=postgresql://apex:apex@localhost:5432/apex_test \
RUN_MIGRATIONS_ON_STARTUP=true \
  python -m uvicorn app.main:app --port 8000

# In another shell
locust -f tests/load/locustfile.py --host=http://localhost:8000 \
  --headless --users=50 --spawn-rate=5 --run-time=5m
```

The RLS policies (d3a1e9b4f201_postgres_rls_policies) add ≤5ms
overhead per query. If p50 jumps by more than that when moving from
SQLite → Postgres, investigate index coverage first — RLS only
performs well when the queries it wraps are already fast.
