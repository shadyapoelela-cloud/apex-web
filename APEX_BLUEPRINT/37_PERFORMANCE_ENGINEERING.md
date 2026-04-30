# 37. Performance Engineering & Reliability for APEX

**Document Version:** 1.0  
**Last Updated:** April 2026  
**Status:** Recommended for Implementation  
**Audience:** Engineering, DevOps, Product Leadership

---

## Executive Summary

APEX is a complex B2B SaaS platform serving financial professionals with invoice generation, ZATCA clearance integration, journal entry posting, and AI-powered copilot assistance. Production reliability directly impacts customer trust, contractual SLAs, and revenue. This document establishes a **Performance Engineering discipline** grounded in Google SRE principles, SLI/SLO/SLA frameworks, and industry best practices for 2025-2026.

**Recommendation:** This should be a dedicated, permanent document referenced by all teams during design, development, testing, and operations. A 1-page ops runbook companion is also recommended.

---

## Part 1: The Reliability Hierarchy (Google SRE Pyramid)

Google's SRE philosophy structures reliability as a pyramid of interconnected practices, each building on the others:

```
                    PRODUCT
              (better/faster features)
              
         DEVELOPMENT (design for reliability)
         
    CAPACITY PLANNING (headroom, forecasting)
    
  TESTING (chaos, load, integration)
  
POSTMORTEM (blameless, RCA, action items)

INCIDENT RESPONSE (severity matrix, runbooks)

MONITORING (metrics, logs, traces, alerts)
```

### Layer 1: Monitoring (Foundation)

**Principle:** You can only optimize what you measure.

**For APEX:**
- **Metrics**: Response latency (p50, p95, p99), error rates (5xx, 4xx, timeouts), throughput (req/s), CPU/memory/disk usage, database connection pool utilization
- **Logs**: Structured JSON logs (timestamp, trace_id, service, level, message); log aggregation (CloudWatch, Loki, Datadog)
- **Traces**: Distributed tracing via OpenTelemetry (FastAPI instrumentation, database queries, external API calls)
- **Errors**: Sentry for exception tracking; automatic alerts for new error signatures
- **Uptime**: Synthetic monitoring (UptimeRobot, Pingdom) for smoke tests from multiple regions

**Implementation:** Render.com free tier deploys with stdout logging; add structured JSON via `logging.getLogger()` in FastAPI, parse via CloudWatch Insights or ELK stack.

---

### Layer 2: Incident Response (Detection & Mitigation)

**Principle:** Bugs happen. Fast response minimizes user impact.

**Severity Matrix:**

| Severity | Definition | Response | Duration | Escalation |
|----------|-----------|----------|----------|-----------|
| P0 (Critical) | Complete service down OR core feature broken (auth, JE posting, ZATCA) | Immediate (< 5 min) | < 1 hour | CTO + on-call |
| P1 (High) | Feature partially degraded OR 5min+ of errors | < 15 min | < 4 hours | Engineering lead |
| P2 (Medium) | Feature slow (p95 > 2s) OR intermittent errors < 0.5% | < 1 hour | < 24 hours | On-call engineer |
| P3 (Low) | Cosmetic OR feature working but slow (p95 < 2s) | < 4 hours | < 1 week | Backlog item |

**On-Call Rotation:**
- 1-week rotations; pager escalation after 5 min no ack
- Handoff: outgoing on-call briefs incoming on-call on P2+ issues

**Incident Runbooks** (per critical path):
- **Auth outage**: Check JWT_SECRET env var, database reachability, Redis connection
- **Invoice creation timeout**: Check ZATCA queue depth, API latency, database transaction lock contention
- **JE posting failure**: Check GL account validations, multi-currency rates, audit trail write
- **Copilot latency spike**: Check Anthropic API rate limits, cache hit rate, token budget

**Escalation Path:**
1. On-call page (Slack, SMS)
2. 15 min: declare incident, open war room (Slack channel)
3. 30 min: communicate to status page (customer facing)
4. Resolution: update every 15 min

---

### Layer 3: Postmortem (Learning)

**Principle:** Every incident is a gift—an opportunity to prevent the next one.

**Postmortem Template** (within 48 hours of resolution):

```
## [P0/P1] Incident Name (Date HH:MM UTC)

### Timeline
- HH:MM: Alert fired (what triggered detection)
- HH:MM: On-call acked
- HH:MM: Root cause identified
- HH:MM: Mitigation applied
- HH:MM: Resolved

### Impact
- Duration: X minutes
- Affected users: X%
- Data loss: Yes/No (if yes, recovery plan)

### Root Cause
- Technical cause (not "human error")
- Contributing factors (monitoring gap? deployment process? unfamiliar code?)

### Resolution
- Immediate fix applied
- Why that fix works

### Action Items
1. [OWNER] Implement X by [DATE] (prevents recurrence)
2. [OWNER] Add monitoring alert for Y by [DATE]
3. [OWNER] Update runbook for Z by [DATE]

### Blameless Principle
- No individual blame; focus on systemic failure
- "Why wasn't this caught earlier?" not "Who made this mistake?"
```

**Storage:** Link postmortems in Slack #incidents channel with GitHub PR for action items.

---

### Layer 4: Testing (Prevention)

**Unit + Integration Testing** (204 tests in pytest; run on every commit)
- **Target:** >= 80% line coverage on critical paths (auth, JE posting, ZATCA)
- **Existing:** `tests/test_integration_v10.py` (93 tests), `test_clients_coa.py` (26 tests), etc.

**Load Testing** (k6, run weekly + before release):
- **Scenario 1:** Login flood—1000 concurrent users authenticating
- **Scenario 2:** Invoice burst—500 users creating invoices simultaneously
- **Scenario 3:** Report generation—100 users running income statements
- **Scenario 4:** ZATCA queue—100 invoices submitted for clearance in rapid succession

```bash
# Example k6 script (scenarios.js)
import http from 'k6/http';
import { check, group } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },   // ramp up
    { duration: '5m', target: 100 },   // hold
    { duration: '2m', target: 0 },     // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95th percentile < 2s
    http_req_failed: ['rate<0.01'],     // < 1% error rate
  },
};

export default function () {
  group('Login', () => {
    let res = http.post('http://apex.local/auth/login', {...});
    check(res, { 'login 2xx': (r) => r.status >= 200 && r.status < 300 });
  });
}
```

**Chaos Engineering** (Gremlin, quarterly drills):
- **Network latency injection:** Add 500ms latency to ZATCA API calls; verify fallback behavior
- **Database failover:** Kill primary Postgres replica; confirm read-only mode, no data loss
- **Pod termination:** Kill random FastAPI pod; verify auto-restart, no cascade failure
- **Region failure:** Simulate region-wide outage; test failover to secondary region (if multi-region)

**CI Integration:**
- Lighthouse CI on every PR (performance budgets for frontend)
- k6 smoke test on staging (quick 1-min load test)
- Slow query detection (database query analyzer threshold)

---

### Layer 5: Capacity Planning (Growth)

**Principle:** 50% headroom prevents crisis during growth spike.

**Tracking:**
- Weekly metrics dashboard: DAU, invoices/day, peak concurrent users, data size (GB)
- Monthly review: project growth rate, identify upcoming bottlenecks
- Quarterly capacity review: do we have 50% headroom?

**Current Targets (Q2 2026):**
- 1000 concurrent users (Render.com free tier supports ~200 with current setup)
- 10GB data (PostgreSQL free tier = 512MB limit; need migration plan)
- 100k invoices/month
- 1000 copilot chats/day

**Scaling Trigger Points:**
- **CPU > 70%:** Add FastAPI workers (Gunicorn workers config)
- **Database connections > 80%:** Implement pgBouncer connection pooling
- **Disk > 80%:** Implement table partitioning (audit_events, journal_lines)
- **API p95 latency > 2s:** Implement Redis caching layer

---

### Layer 6: Development (Design for Reliability)

**Principle:** It's cheaper to avoid bugs than to find and fix them in production.

**Code Practices:**
- **Circuit breakers** for external APIs (ZATCA, Anthropic):
  ```python
  from requests.adapters import HTTPAdapter
  from urllib3.util.retry import Retry
  
  session = requests.Session()
  retry = Retry(total=3, backoff_factor=0.5)
  adapter = HTTPAdapter(max_retries=retry)
  session.mount('https://', adapter)
  ```
- **Timeout enforcement:** All external calls must have explicit timeout (e.g., ZATCA = 5s)
- **Idempotency keys:** Invoice creation, JE posting must use idempotency keys (prevent duplicates on retry)
- **Graceful degradation:** If ZATCA timeout, queue for retry; don't block invoice creation
- **Database transactions:** All multi-step operations use explicit transactions with rollback
- **Rate limiting:** FastAPI rate limiter per endpoint (e.g., login = 10 req/min, copilot = 100 req/hour)

**Deployment:**
- Blue-green deployments (keep old version running during rollout)
- Canary releases (route 5% of traffic to new version; monitor error rates before 100% cutover)
- Feature flags (kill switch for new features if errors spike)

---

### Layer 7: Product (Better/Faster/Safer)

**Principle:** The best reliability is a feature users don't notice.

**Product Decisions that Help SRE:**
- **Async operations:** Long-running jobs (ZATCA submission, report generation) run async; return job_id immediately; user polls for results
- **Rate limiting messaging:** "You've reached 100 invoices/hour; try again in 2 minutes"
- **Offline-first UI:** Flutter web caches recent invoices/journal entries; works during brief API outages
- **Progress indication:** ZATCA clearance shows "Submitted → Processing → Cleared" stages (not spinning wheel)

---

## Part 2: SLI/SLO/SLA Framework for APEX

### Definitions

**SLI (Service Level Indicator):** Measurement of actual behavior
- Example: "99.9% of login requests completed in < 1s last month"

**SLO (Service Level Objective):** Internal target
- Example: "We commit to 99.9% uptime with < 1s login latency"

**SLA (Service Level Agreement):** Customer-facing contract with penalties
- Example: "99.9% uptime guaranteed; if we miss, 10% service credit"

### SLI Definitions Per Endpoint

| Endpoint | SLO | Measurement | Rationale |
|----------|-----|-------------|-----------|
| GET /users/me | 99.9% < 200ms | Session validation, cached user profile | Foundation; called on every page load |
| POST /auth/login | 99.5% < 1s | JWT signing + DB lookup; may retry | User-facing; lower SLO acceptable during spike |
| GET /companies/{id} | 99.8% < 500ms | DB lookup + normalization | High-frequency read |
| POST /api/v1/invoices | 99% < 2s | Validation + DB insert + ZATCA queue | Includes I/O; user can wait |
| POST /zatca/invoice/build | 95% < 5s | XML build + validation + network call | External API; longer timeout acceptable |
| GET /api/v1/journal-entries | 99% < 1s | DB query + pagination | Batch read; no external deps |
| POST /api/v1/journal-entries | 99% < 2s | Validation + multi-table inserts + audit trail | Transaction heavy |
| POST /copilot/chat | 90% < 8s | Anthropic API call (2-5s) + processing | LLM latency dominates; lower SLO |
| GET /reports/income-statement | 95% < 3s | Aggregate query + multi-table join | Acceptable to be slower |
| GET /api/v1/audit-trail | 99% < 500ms | Indexed query; pagination enforced | Compliance-critical; fast |

### Global SLOs

| Metric | Target | Threshold | Error Budget |
|--------|--------|-----------|--------------|
| **Availability** | 99.9% uptime | 43 min downtime/month | 25.6 min |
| **Latency (p95)** | < 500ms | Avg across all endpoints | — |
| **Latency (p99)** | < 2s | Worst-case response | — |
| **Error Rate** | < 0.1% | 5xx errors / total requests | 0.1% of quota |
| **Throughput** | 1000 concurrent users | Peak load sustained | — |
| **Correctness** | 99.99% | Transactions posted correctly (no duplicates, GL balanced) | 0.01% |

### Error Budget Management

**Concept:** If SLO is 99.9%, you have a budget of 0.1% of monthly requests to "spend" on failures. Once spent, SLA is at risk.

**Example (April 2026):**
- 10 million API requests in month
- Error budget = 10,000 failed requests
- Actual failures: 8,000 → 2,000 budget remaining (can afford 1 more incident)
- Decision: **pause risky deployments; enter freeze mode until month ends**

**Tracking:** Add dashboard in Grafana showing budget depletion over time. Automated warning at 50% and 80% spent.

---

## Part 3: Performance Budgets

Performance budgets prevent regression by enforcing upper limits on metrics.

### Frontend Budgets (Flutter Web)

| Metric | Budget | Measurement Tool |
|--------|--------|------------------|
| **First Contentful Paint (FCP)** | < 1.8s | Lighthouse, web-vitals.js |
| **Largest Contentful Paint (LCP)** | < 2.5s | Core Web Vital (p75 over 28 days) |
| **Interaction to Next Paint (INP)** | < 200ms | Core Web Vital (p75) |
| **Cumulative Layout Shift (CLS)** | < 0.1 | Visual stability |
| **Main JS bundle size** | < 500KB gzipped | bundle-analyzer webpack plugin |
| **CSS bundle size** | < 100KB gzipped | — |
| **Total page size** | < 2MB | Network tab in DevTools |
| **Image size** | 0 unoptimized images | WebP required; lazy load required |

**Enforcement:**
- Lighthouse CI on every PR; fail PR if LCP > 2.5s
- GitHub Actions workflow:
  ```yaml
  - name: Run Lighthouse CI
    uses: treosh/lighthouse-ci-action@v10
    with:
      configPath: './lighthouserc.json'
      uploadArtifacts: true
  ```

### API Budgets (Backend)

| Metric | Budget | Endpoint Examples |
|--------|--------|------------------|
| **Response body size** | < 200KB typical | Most endpoints < 50KB |
| **Query string params** | < 100 chars | Indexable by browsers/CDN |
| **Database query time** | < 100ms p95 | SELECT with proper indexes |
| **External API latency** | < 5s (ZATCA), < 2s (Anthropic fallback) | Timeout handling required |
| **Concurrent DB connections** | < 100 (free tier limit) | pgBouncer pool size = 20 |

---

## Part 4: Database Performance Patterns

### Indexing Strategy

**By Table:**

| Table | Key Columns | Index Type | Rationale |
|-------|-------------|-----------|-----------|
| `users` | `email`, `company_id`, `status` | B-tree | Auth lookup, multi-tenant filter |
| `invoices` | `company_id`, `created_at`, `status` | B-tree (composite) | Time-range queries |
| `invoices` | `zatca_uuid` | B-tree | ZATCA status checks |
| `journal_entries` | `company_id`, `account_id`, `period` | B-tree (composite) | GL queries, period filtering |
| `audit_events` | `entity_type`, `created_at`, `user_id` | B-tree (composite) | Compliance queries |
| `audit_events` | `created_at` | B-tree | Partition pruning on time-based table |

**Implementation:**
```sql
-- Composite index (most common pattern for APEX)
CREATE INDEX idx_invoices_company_created 
  ON invoices(company_id, created_at DESC);

-- Covering index (includes SELECT columns, no table lookup)
CREATE INDEX idx_invoices_status_covering 
  ON invoices(status, company_id) 
  INCLUDE (currency, total_amount);

-- Partial index (status = active only)
CREATE INDEX idx_invoices_active 
  ON invoices(company_id, created_at) 
  WHERE status = 'draft';
```

### N+1 Query Prevention

**Anti-pattern (N+1):**
```python
# BAD: 1 query for users + N queries for their invoices
users = db.query(User).filter(User.company_id == company_id).all()
for user in users:
    invoices = db.query(Invoice).filter(Invoice.user_id == user.id).all()  # N queries
```

**Pattern (eager load with join):**
```python
# GOOD: 1 query with join
from sqlalchemy.orm import joinedload
users = db.query(User)\
    .options(joinedload(User.invoices))\
    .filter(User.company_id == company_id)\
    .all()
```

**Verification:**
```bash
# Enable SQL logging in FastAPI (app.py)
import logging
logging.basicConfig()
logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)

# Review logs for duplicate SELECT statements
```

### Connection Pooling (pgBouncer)

**Setup:**
```ini
# pgbouncer.ini
[databases]
apex_db = host=db.render.com port=5432 dbname=apex user=apex password=$DB_PASSWORD

[pgbouncer]
pool_mode = transaction  # reset conn after each transaction
max_client_conn = 1000
default_pool_size = 20   # connections per user per DB
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100 # total conns to DB
```

**Benefit:** Reduces memory overhead (each PostgreSQL process = ~10MB); allows 1000 app connections to share 20 DB connections.

### Query Performance Monitoring

**PostgreSQL EXPLAIN ANALYZE:**
```sql
EXPLAIN ANALYZE
SELECT i.id, i.total_amount, u.email
FROM invoices i
JOIN users u ON i.user_id = u.id
WHERE i.company_id = 123
ORDER BY i.created_at DESC;

-- Output shows:
-- - Seq Scan vs. Index Scan
-- - Rows estimated vs. actual (if large diff, stale stats)
-- - Total cost (in IO units, not milliseconds)
```

**Slow Query Log** (PostgreSQL):
```sql
-- Enable logging of slow queries (> 500ms)
ALTER SYSTEM SET log_min_duration_statement = 500;
SELECT pg_reload_conf();

-- Review in logs; identify patterns
```

**Monitoring Tool:** Add slow query dashboard to Grafana, threshold = 100ms p95.

### Table Partitioning (for large tables)

**Use case:** `audit_events` and `journal_lines` grow unbounded.

```sql
-- Create partitioned table by time
CREATE TABLE audit_events (
    id BIGSERIAL,
    company_id UUID,
    entity_type VARCHAR,
    created_at TIMESTAMP,
    data JSONB,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (DATE_TRUNC('month', created_at));

-- Create monthly partitions
CREATE TABLE audit_events_2025_01 PARTITION OF audit_events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
    
-- Old partitions can be dropped/archived
DROP TABLE audit_events_2024_01;  -- no full table scan impact
```

**Benefit:** Faster queries, easier archival, reduced index size.

### VACUUM & AUTOVACUUM

**Concept:** PostgreSQL marks deleted rows; VACUUM reclaims space.

**Configuration:**
```sql
ALTER TABLE invoices SET (
    autovacuum_vacuum_scale_factor = 0.01,  -- vacuum at 1% rows deleted
    autovacuum_analyze_scale_factor = 0.005  -- analyze at 0.5% changed
);

-- View stats
SELECT schemaname, tablename, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000;  -- alert if high
```

---

## Part 5: Caching Strategy (3 Layers)

### Layer 1: CDN (Edge Caching)

**For:** Static assets (CSS, JS, images, fonts)
- **Provider:** Cloudflare, AWS CloudFront, Render.com built-in CDN
- **TTL:** 30 days for versioned assets (app.js?v=abc123)
- **Cache headers:**
  ```
  Cache-Control: public, max-age=2592000, immutable
  # immutable = browser never revalidates; safe for versioned assets
  ```

**Setup (Flutter Web + Render.com):**
```yaml
# render.yaml
services:
  - type: web
    name: apex-frontend
    buildCommand: flutter build web
    staticPublishPath: build/web
    headers:
      - path: "/**/*"
        name: "Cache-Control"
        value: "public, max-age=3600"  # 1 hour for HTML
      - path: "/assets/**/*"
        name: "Cache-Control"
        value: "public, max-age=2592000, immutable"  # 30 days for assets
```

### Layer 2: Redis (Application Cache)

**For:** API responses with stable data, session tokens, job queues

```python
# app/core/cache.py
from redis import Redis
import json

cache = Redis(host='redis.render.com', port=6379, db=0)

def get_cached_user(user_id: str) -> dict:
    key = f"user:{user_id}"
    cached = cache.get(key)
    if cached:
        return json.loads(cached)
    
    # Cache miss; fetch from DB
    user = db.query(User).filter(User.id == user_id).first()
    cache.setex(key, 300, json.dumps(user.dict()))  # 5 min TTL
    return user.dict()
```

**Cache Invalidation:** On write, delete the cache key:
```python
def update_user(user_id: str, data: dict):
    db.query(User).filter(User.id == user_id).update(data)
    db.commit()
    cache.delete(f"user:{user_id}")  # invalidate
```

**Typical TTLs:**
- User profile: 5 min
- Company settings: 10 min
- Invoice list (paginated): 1 min
- GL account list: 30 min
- Exchange rates: 1 hour

**Hit rate target:** >= 70% for read-heavy endpoints.

### Layer 3: Process Memory (Application Cache)

**For:** Hot keys with very short TTL (5s)

```python
from functools import lru_cache
from time import time

_cache = {}
_cache_ttl = {}

def memoize(ttl_seconds=5):
    def decorator(func):
        def wrapper(*args):
            key = f"{func.__name__}:{args}"
            now = time()
            if key in _cache and _cache_ttl[key] > now:
                return _cache[key]
            
            result = func(*args)
            _cache[key] = result
            _cache_ttl[key] = now + ttl_seconds
            return result
        return wrapper
    return decorator

@memoize(ttl_seconds=5)
def get_exchange_rate(from_curr: str, to_curr: str) -> float:
    # Called frequently; recompute every 5s
    return external_api.get_rate(from_curr, to_curr)
```

**Three-layer hit rate:** CDN (95% for static) + Redis (70% for API) + memory (80% for hot keys) = effective 99%+ for hot paths.

---

## Part 6: Load Testing Plan

### Tools

**Recommended: k6 (Grafana)**
- Pros: Go-based (lightweight), JavaScript tests, integrates with Grafana, free tier
- Tests written as JavaScript; easy to version in Git

**Alternative: Locust (Python)**
- Pros: Python-based, good for teams familiar with Python, visual UI
- Cons: Higher resource consumption, slower than k6

### Scenarios

**Scenario 1: Login Flood**
```javascript
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 100 },
    { duration: '2m', target: 100 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000'],
    'http_req_failed': ['rate<0.05'],
  },
};

export default function () {
  let res = http.post('https://apex.local/auth/login', {
    email: `user${__VU}@test.com`,
    password: 'test123',
  });
  check(res, { 'status 200': (r) => r.status === 200 });
}
```

**Scenario 2: Invoice Creation Burst** (500 users, 5 min)
- p95 latency < 2s
- error rate < 1%
- ZATCA queue fills but processes within 10 min

**Scenario 3: Report Generation** (100 users, 3 min)
- p95 latency < 3s
- database connections < 100
- disk I/O spike monitored

**Scenario 4: ZATCA Rapid Submission** (100 invoices/min for 10 min)
- Queue depth < 1000 at peak
- Clearance time < 5s from submission (incl. network)
- No duplicate submissions on retry

### Test Frequency

- **Weekly smoke test:** 10 min k6 run on staging (quick check for regressions)
- **Pre-release:** Full load test (1 hour per scenario) 48 hours before production deploy
- **Quarterly:** Sustained load test (8 hours at peak load) to identify memory leaks, connection drift

### Reporting

```
Load Test Report: Invoice Creation (Date)
===========================================
Scenario: 500 users creating invoices over 5 minutes

Latency:
  p50:  250ms
  p95:  1200ms  ✓ (SLO: < 2000ms)
  p99:  1950ms

Error Rate:
  4xx:  0.1% (validation errors)
  5xx:  0.05%  ✓ (SLO: < 0.1%)

Resource Usage:
  Peak CPU:      65%  ✓
  Peak Memory:   2.1GB  ✓
  DB Connections: 45/100  ✓
  Redis Hit Rate: 68%

Conclusion: PASS - ready for production
```

---

## Part 7: Chaos Engineering Practices

### Network Chaos

**Tool:** ToxiProxy (open-source proxy that injects faults)

```bash
# Add 500ms latency to ZATCA API calls
toxiproxy-cli toxic add \
  -t latency \
  -a "500" \
  -n "zatca_latency" \
  "zatca_proxy"

# Watch system for:
# - Timeout handling (fallback queue)
# - Retry logic (exponential backoff)
# - User messaging ("Clearance delayed; retrying...")
```

### Database Chaos

**Testing:** Kill primary Postgres replica; verify failover

```bash
# On Render.com: manually failover replica in dashboard
# Monitor for:
# - Write timeout (should fail-fast, not hang)
# - Read-only mode detection
# - Error message to user
# - Recovery time < 2 min

# Expected: no data loss, users notified, system online in 1-2 min
```

### Pod/Container Chaos

**Test:** Kill random FastAPI container; verify auto-restart

```bash
# On Render.com: manually restart a worker
# k6 test running simultaneously to measure impact

# Expected: 1-2 requests timeout (killed pod), but system recovers; 
#           no cascading failures, other pods continue serving
```

### Disaster Recovery Drill (Quarterly)

- **Scenario:** Database corruption in production; must restore from backup
- **Process:**
  1. Announce drill to team (no surprise)
  2. Take backup from 24 hours ago
  3. Restore to staging environment
  4. Verify data integrity
  5. Document recovery time (RTO) and data loss window (RPO)
  6. Update runbook if steps changed

---

## Part 8: Observability Stack

### Metrics (Prometheus + Grafana)

**Instrument FastAPI:**
```python
from prometheus_client import Counter, Histogram, generate_latest

request_count = Counter(
    'apex_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'apex_http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['endpoint']
)

@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    
    request_count.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    request_duration.labels(endpoint=request.url.path).observe(duration)
    
    return response

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type="text/plain")
```

**Scrape config (Prometheus):**
```yaml
scrape_configs:
  - job_name: 'apex-api'
    static_configs:
      - targets: ['apex.render.com/metrics']
    scrape_interval: 15s
```

**Grafana Dashboards:**
1. **System Overview:** CPU, memory, disk, network
2. **API Performance:** Request rate, latency (p50/p95/p99), error rate
3. **Database:** Connections, query time, table sizes
4. **ZATCA Queue:** Submissions/min, clearance time, failure rate
5. **Copilot:** Token usage, latency, cache hit rate
6. **Error Budget:** Remaining quota for month

### Logs (Loki / CloudWatch)

**Structured JSON logging:**
```python
import json
from datetime import datetime

def log_invoice_created(invoice_id: str, company_id: str, amount: float):
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "level": "INFO",
        "service": "apex-api",
        "event": "invoice_created",
        "invoice_id": invoice_id,
        "company_id": company_id,
        "amount": amount,
        "trace_id": request.headers.get("X-Trace-ID"),
    }
    print(json.dumps(log_entry))  # Render.com captures stdout
```

**Query example (CloudWatch Insights):**
```
fields timestamp, invoice_id, amount
| filter event = "invoice_created"
| stats sum(amount) as total by company_id
```

### Traces (OpenTelemetry + Jaeger)

**Instrument FastAPI:**
```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger.render.com",
    agent_port=6831,
)
trace_provider = TracerProvider()
trace_provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))

FastAPIInstrumentor.instrument_app(app)
SQLAlchemyInstrumentor().instrument(engine=engine)
```

**View traces in Jaeger UI:** Follow request through FastAPI → database → external API, see latency at each step.

### Errors (Sentry)

**Setup:**
```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

sentry_sdk.init(
    dsn="https://xxx@sentry.io/123456",
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1,  # 10% of requests get traced
    environment="production",
)
```

**Alerts:** Slack notification when new error signature appears or error rate > 0.5%.

### Uptime (UptimeRobot)

**Monitors:**
1. GET /health → expect 200
2. POST /auth/login (test account) → expect 200 + JWT token
3. GET /api/v1/invoices → expect 200
4. POST /zatca/invoice/build (test data) → expect 200

**Frequency:** Every 5 min from 3 geographies (global coverage). Slack alert on failure.

---

## Part 9: Incident Response Runbooks

### Runbook: Authentication Outage

**Symptoms:**
- Login endpoint returns 401 or 500
- /health endpoint fails

**Diagnosis (< 2 min):**
1. Check JWT_SECRET env var in Render.com settings
2. Check PostgreSQL connectivity: `SELECT 1` from any endpoint
3. Check Redis connectivity (if in use)
4. Review error logs for tracebacks

**Remediation:**
- **Env var missing:** Restore from backup config; redeploy
- **DB down:** Wait 1-2 min for Render.com auto-recovery; if persists, failover to replica
- **Code bug:** Roll back last deploy via Render.com

**Communication:**
- Post to #incidents: "Auth outage detected; diagnosing"
- Update status page: "Investigating login issues"
- After resolution: "Login restored; investigating root cause"

---

### Runbook: ZATCA Queue Backlog Spike

**Symptoms:**
- ZATCA clearance time > 5 min
- Queue depth > 500 invoices
- Users seeing "Clearance delayed" messages

**Diagnosis:**
1. Check Anthropic API status page (if using AI for routing)
2. Check ZATCA service status (if external call failing)
3. Review recent deploys (code change broke ZATCA integration?)

**Remediation:**
- **ZATCA service slow:** Increase retry backoff; queue will eventually clear
- **Code regression:** Roll back; redeploy known-good version
- **Rate limit hit:** Implement request batching; contact ZATCA support for higher limit

---

### Runbook: Database Slow Query

**Symptoms:**
- API latency spike (p95 > 3s)
- Prometheus: database query time > 500ms
- Postgres logs showing slow queries

**Diagnosis:**
```sql
-- Find slow queries
SELECT query, calls, mean_time, max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 5;

-- Run EXPLAIN ANALYZE on top query
EXPLAIN ANALYZE <query>;
```

**Remediation:**
- **Missing index:** Add index; deploy; monitor improvement
- **N+1 query:** Fix code to use JOIN; redeploy
- **Stale statistics:** Run `ANALYZE` on table; no redeploy needed
- **Table bloat:** Run `VACUUM FULL`; may need maintenance window

---

## Part 10: Capacity Planning

### Metrics to Track

**Weekly Dashboard:**
- DAU (daily active users)
- Invoices created (total, by status)
- Peak concurrent users (during business hours)
- Copilot chats (daily)
- Data size (PostgreSQL, Redis)

**Monthly Review:**
- Growth rate (% increase week-over-week)
- Projected peak load (if trend continues)
- Current headroom (how much capacity remains before 70% threshold)

**Quarterly Planning:**
- Do we have 50% headroom for next quarter?
- Identify bottleneck (CPU? Disk? Connections?)
- Plan scaling action (add workers? Upgrade DB? Implement caching?)

### Example Capacity Plan (Q3 2026)

**Current (Q2 2026):**
- 500 DAU, 5k invoices/month, 100 concurrent peak
- Render.com free tier: 200m free dyno hours = 1 worker running 24/7
- PostgreSQL: 512MB free tier

**Projected (Q3 2026, 25% growth):**
- 625 DAU, 6.25k invoices/month, 125 concurrent peak
- **Action:** Upgrade to paid dyno (2 workers); PostgreSQL to 1GB

**Projected (Q4 2026, 50% growth):**
- 750 DAU, 7.5k invoices/month, 150 concurrent peak
- **Action:** Add pgBouncer connection pooling; Redis cache layer

**Decision gate:** If growth exceeds projections by 2x, trigger emergency scaling review.

---

## Part 11: APEX-Specific Performance Concerns

### 1. ZATCA Integration Timeout Handling

**Problem:** ZATCA clearance API may take 2-5s or timeout. Users expect < 2s response.

**Solution:** Async job queue
```python
# Immediate response: return job_id
@app.post("/api/v1/invoices")
async def create_invoice(req: InvoiceCreate):
    invoice = Invoice(**req.dict())
    db.add(invoice)
    db.commit()
    
    # Queue ZATCA clearance as async job
    job_id = queue_zadja_clearance(invoice.id)
    
    return {
        "success": True,
        "data": {
            "invoice_id": invoice.id,
            "zatca_job_id": job_id,
            "status": "pending_clearance"
        }
    }

# User polls for status
@app.get("/api/v1/invoices/{id}/zatca-status")
async def get_zatca_status(id: str):
    job = db.query(ZATCAJob).filter(ZATCAJob.invoice_id == id).first()
    return {"status": job.status, "cleared_at": job.cleared_at}
```

### 2. LLM API Rate Limits (Anthropic Claude)

**Problem:** Anthropic API has rate limits (e.g., Tier 2 = 40k tokens/min input).

**Solution:** Token budget tracking + fallback
```python
from datetime import datetime, timedelta

TOKEN_BUDGET_PER_MINUTE = 1000  # APEX's budget
last_reset = datetime.now()
tokens_used = 0

@app.post("/copilot/chat")
async def copilot_chat(req: ChatRequest):
    global tokens_used, last_reset
    
    # Reset budget every minute
    if (datetime.now() - last_reset).total_seconds() > 60:
        tokens_used = 0
        last_reset = datetime.now()
    
    # Estimate tokens (rough: 1 token per 4 chars)
    est_tokens = len(req.message) // 4
    
    if tokens_used + est_tokens > TOKEN_BUDGET_PER_MINUTE:
        # Fallback response (no API call)
        return {
            "success": True,
            "data": {
                "message": "System is busy; try again in a moment",
                "is_fallback": True
            }
        }
    
    # Call Claude API
    response = anthropic.messages.create(...)
    tokens_used += response.usage.input_tokens + response.usage.output_tokens
    
    return {"success": True, "data": {"message": response.content[0].text}}
```

### 3. Database Lock Contention on JE Posting

**Problem:** Multiple users posting journal entries to same GL account in rapid succession → locks.

**Solution:** Optimistic locking + lock-free reads
```python
class GLAccount(Base):
    __tablename__ = "gl_accounts"
    id = Column(UUID, primary_key=True)
    balance = Column(Numeric)
    version = Column(Integer, default=0)  # optimistic lock version

@app.post("/api/v1/journal-entries")
async def post_journal_entry(req: JECreate):
    gl_account = db.query(GLAccount).filter(
        GLAccount.id == req.account_id
    ).with_for_update().first()  # lock row
    
    # Bump balance
    gl_account.balance += req.amount
    gl_account.version += 1
    
    db.commit()  # release lock
    
    # No locks on reads (users can see balance during posting)
    return {"success": True, "data": {...}}
```

### 4. Multi-Tenant Isolation

**Problem:** Company A's high load must not affect Company B's performance.

**Solution:** Per-tenant SLOs + rate limiting by tenant
```python
@app.get("/api/v1/invoices", dependencies=[Depends(verify_token)])
async def list_invoices(skip: int = 0, limit: int = 100, current_user: User = Depends()):
    # Rate limit per company (not per user)
    company_id = current_user.company_id
    bucket_key = f"rate_limit:{company_id}"
    
    # Redis: allow 100 requests per minute per company
    if cache.incr(bucket_key) > 100:
        cache.expire(bucket_key, 60)
        raise HTTPException(429, "Rate limit exceeded for your company")
    
    # Filter to company's invoices only
    invoices = db.query(Invoice).filter(
        Invoice.company_id == company_id
    ).offset(skip).limit(limit).all()
    
    return {"success": True, "data": invoices}
```

---

## Part 12: Performance Testing in CI

### Lighthouse CI (Every PR)

**Config (`lighthouserc.json`):**
```json
{
  "ci": {
    "collect": {
      "url": ["https://staging.apex.local"],
      "numberOfRuns": 3,
      "settings": {
        "configPath": "./lighthouse-config.js"
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    },
    "assert": {
      "preset": "lighthouse:recommended",
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.9 }],
        "categories:accessibility": ["warn", { "minScore": 0.8 }],
        "categories:best-practices": ["warn", { "minScore": 0.8 }]
      }
    }
  }
}
```

**GitHub Actions:**
```yaml
- name: Run Lighthouse CI
  uses: treosh/lighthouse-ci-action@v10
  with:
    configPath: './lighthouserc.json'
    uploadArtifacts: true
    temporaryPublicStorage: true
```

### k6 Smoke Test (Staging)

**Run on every PR to staging:**
```bash
k6 run --vus 10 --duration 1m scenarios/smoke-test.js
```

### Database Query Analyzer

**Detect slow queries automatically:**
```yaml
- name: Check slow queries
  run: |
    psql $DATABASE_URL -c "
      SELECT query, calls, mean_time
      FROM pg_stat_statements
      WHERE mean_time > 100
      ORDER BY mean_time DESC
    " > slow-queries.txt
  
- name: Comment on PR
  if: hashFiles('slow-queries.txt') != ''
  uses: actions/github-script@v6
  with:
    script: |
      const fs = require('fs');
      const slowQueries = fs.readFileSync('slow-queries.txt', 'utf8');
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `⚠️ Slow queries detected:\n\`\`\`\n${slowQueries}\n\`\`\``
      });
```

---

## Part 13: Rollout & Deployment Safety

### Blue-Green Deployment

**Process:**
1. Deploy new version to "green" environment (parallel to production "blue")
2. Run smoke tests on green (same k6 scenarios)
3. Route 5% of traffic to green (canary phase); monitor error rates for 5 min
4. If error rate < SLO, route 100% to green; old blue stays ready for rollback
5. If error rate > SLO, route back to blue; investigate green

### Feature Flags

**Tool:** LaunchDarkly or Unleash (open-source)

```python
from unleash import Unleash

unleash = Unleash(
    url="https://unleash.render.com",
    app_name="apex-api"
)

@app.post("/copilot/chat")
async def copilot_chat(req: ChatRequest, current_user: User = Depends()):
    if unleash.is_enabled("new_copilot_model", {"user_id": current_user.id}):
        # Use new Claude model (only for subset of users)
        response = anthropic.messages.create(model="claude-opus-4.6", ...)
    else:
        # Fall back to old model
        response = anthropic.messages.create(model="claude-sonnet", ...)
    
    return {"success": True, "data": {"message": response.content[0].text}}
```

**If new copilot model causes error spike:**
```python
unleash.disable("new_copilot_model")  # instant killswitch; no deploy needed
```

---

## Part 14: Recommended Metrics Dashboard (Grafana)

**Row 1: Availability**
- Uptime % (SLO: 99.9%)
- Error budget remaining (%)
- Last incident (timestamp, severity)

**Row 2: Latency**
- API response time (p50, p95, p99)
- ZATCA clearance time (p95, p99)
- Copilot response time (p95, p99)
- Database query time (p95, p99)

**Row 3: Resources**
- CPU usage (%)
- Memory usage (%)
- Disk usage (%)
- Database connections (active, pooled)

**Row 4: Application**
- Requests per second (by endpoint)
- Error rate by endpoint (%)
- ZATCA queue depth (items)
- Copilot token usage (% of budget)

**Row 5: Cache**
- Redis hit rate (%)
- CDN hit ratio (%)
- Cache invalidations (per min)

---

## Part 15: Conclusion & Recommendation

### Summary

APEX's growing complexity (multi-tenant, ZATCA integration, AI copilot, multi-table financial ledger) demands a **dedicated performance engineering discipline**. This document provides:

1. **Reliability pyramid** (monitoring → incident response → testing → capacity planning)
2. **SLI/SLO/SLA targets** per endpoint
3. **Performance budgets** (frontend, API, database)
4. **Caching strategy** (CDN, Redis, in-memory)
5. **Load testing plan** (k6, Locust, quarterly drills)
6. **Chaos engineering practices** (network, database, pod failover)
7. **Observability stack** (Prometheus, Loki, OpenTelemetry, Sentry)
8. **Incident response runbooks** (authentication, ZATCA, database)
9. **Capacity planning framework** (quarterly reviews, headroom target)
10. **CI integration** (Lighthouse, k6, slow query detection)

### Next Steps

**Immediate (This Sprint):**
1. Set up Lighthouse CI in GitHub Actions
2. Implement structured JSON logging in FastAPI
3. Create Grafana dashboard for key metrics
4. Write 3 critical runbooks (auth, ZATCA, database)

**Short-term (Next Month):**
1. Deploy k6 smoke test to staging
2. Run first load test (invoice creation scenario)
3. Implement Redis caching layer
4. Set up Sentry error tracking

**Medium-term (Q3 2026):**
1. Implement pgBouncer connection pooling
2. Run quarterly chaos engineering drills
3. Establish on-call rotation + pager
4. Deploy OpenTelemetry for tracing

**Long-term (Q4 2026+):**
1. Multi-region setup with failover
2. Materialized views for reports
3. Advanced observability (LLM model cost tracking)
4. SLO-driven engineering culture

### Decision: Permanent or Temporary?

**Recommendation:** **This should be a permanent, living document**, updated quarterly as the platform evolves. Assign ownership to the DevOps/SRE lead (or CTO if role not yet created). Schedule quarterly reviews to adjust SLOs, update runbooks, and capture lessons from incidents.

---

## References

### Google SRE Books & Resources
- [Google SRE Books](https://sre.google/books/) — Free guides on SLI/SLO/SLA, incident response, monitoring
- [Google SRE: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) — Foundational SLO definitions

### Performance & Monitoring
- [web.dev: Web Vitals](https://web.dev/articles/vitals) — Core Web Vitals (LCP, CLS, INP)
- [Google Search Central: Core Web Vitals](https://developers.google.com/search/docs/appearance/core-web-vitals)
- [Grafana Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) — Automated performance testing in CI
- [web.dev: Lighthouse CI](https://web.dev/articles/lighthouse-ci)

### Load Testing & Chaos Engineering
- [Grafana k6](https://k6.io/) — Modern load testing tool
- [k6 Documentation](https://grafana.com/docs/k6/latest/)
- [Gremlin: Chaos Engineering](https://www.gremlin.com/chaos-engineering)
- [Gremlin: Chaos Monkey Guide](https://www.gremlin.com/chaos-monkey)

### Database Performance
- [PostgreSQL: Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
- [PostgreSQL: Examining Index Usage](https://www.postgresql.org/docs/current/indexes-examine.html)
- [Percona: PgBouncer for PostgreSQL](https://www.percona.com/blog/pgbouncer-for-postgresql-how-connection-pooling-solves-enterprise-slowdowns)
- [Scale Grid: PostgreSQL Connection Pooling](https://scalegrid.io/blog/postgresql-connection-pooling-part-2-pgbouncer/)

### Caching & CDN
- [Redis: Cache Optimization Strategies](https://redis.io/blog/guide-to-cache-optimization-strategies/)
- [Calmops: Caching Strategies](https://calmops.com/devops/caching-strategies-redis-cdn-application-cache/)

### API Rate Limiting & Resilience
- [Baeldung: Resilience4j](https://www.baeldung.com/resilience4j) — Circuit breaker, rate limiter patterns
- [Resilience4j Documentation](https://resilience4j.readme.io/docs/getting-started)

### Observability
- [Grafana: OpenTelemetry Documentation](https://grafana.com/docs/opentelemetry/)
- [OpenTelemetry + Prometheus + Grafana](https://medium.com/@raghurajs212/building-a-complete-observability-monitoring-stack-opentelemetry-prometheus-grafana-loki-d988827ec1cc)
- [Grafana: SLI/SLO Monitoring with Prometheus](https://medium.com/@aman.kumar7562/building-an-observability-stack-with-prometheus-grafana-and-promql-for-real-time-sli-slo-3b6f011fc023)

### SLI/SLO/SLA Frameworks
- [incident.io: SLO/SLA/SLI Guide](https://incident.io/blog/slo-sla-sli)
- [Young Upstarts: SLA vs SLO vs SLI in 2025](https://www.youngupstarts.com/2025/08/22/sla-vs-slo-vs-sli-in-2025-what-they-mean-how-they-connect-and-where-theyre-headed/)
- [Uptrace: SLA/SLO Monitoring Requirements 2025](https://uptrace.dev/blog/sla-slo-monitoring-requirements)
- [Routine: SLOs vs SLAs vs SLIs for B2B SaaS](https://routine.co/blog/posts/slos-slas-slis-saas-metrics)

### Apdex Score
- [IBM: What is Apdex Score](https://www.ibm.com/think/topics/apdex)
- [Coralogix: Apdex Score Guide](https://coralogix.com/guides/real-user-monitoring/apdex-score/)
- [New Relic: Apdex Documentation](https://docs.newrelic.com/docs/apm/new-relic-apm/apdex/apdex-measure-user-satisfaction/)

### Claude API Performance (Anthropic)
- [Claude API: Rate Limits Documentation](https://platform.claude.com/docs/en/api/rate-limits)
- [TechCrunch: Claude Rate Limits 2025](https://techcrunch.com/2025/07/28/anthropic-unveils-new-rate-limits-to-curb-claude-code-power-users/)
- [Portkey: Claude Code Rate Limits Guide](https://portkey.ai/blog/claude-code-limits/)

---

**Document Owner:** [Assign CTO or DevOps Lead]  
**Review Cycle:** Quarterly (Jan, Apr, Jul, Oct)  
**Last Reviewed:** April 30, 2026
