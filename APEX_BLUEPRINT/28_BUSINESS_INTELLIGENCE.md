# APEX Business Intelligence & Data Warehouse Architecture
## Modern Analytics for Multi-Tenant Financial SaaS

**Status:** Strategic Blueprint v1.0  
**Date:** 2026-04-30  
**Target:** FastAPI + PostgreSQL + Flutter Web  
**Scale:** 10–1000 tenants  

---

## Executive Summary

APEX's current analytics approach—computing reports on-demand from the OLTP PostgreSQL database—will catastrophically fail at scale. A typical audit or financial dashboard query touches 50k+ transaction rows, causing:

- **Database lock contention** (OLTP writers blocked by analytical SELECTs)
- **Tenant isolation violations** (slow queries leak data to other tenants)
- **Render failures** (30s+ report load times → user abandonment)
- **Cost explosion** (10× compute at 100 tenants)

**Solution:** Decouple analytics (OLAP) from operations (OLTP) via a modern data architecture.

This blueprint recommends:
- **MVP (3 months):** PostgreSQL materialized views + Apache Superset embedded
- **Scale phase (year 1–2):** ClickHouse OLAP + Cube.dev semantic layer
- **Enterprise phase (year 3+):** Multi-region distributed OLAP + ML forecasting

---

## 1. The Problem: Why APEX's Current Analytics Architecture Breaks

### 1.1 Current State
```
Flask/FastAPI Request → PostgreSQL OLTP → Direct Table Scans → JSON → React/Flutter
```

**Issues:**

| Issue | Impact | Scale Point |
|-------|--------|------------|
| **No materialization** | Every report = full table scan | 10k rows → OK; 1M rows → 10s |
| **No indexing strategy** | Dimension queries slow (list all GL accounts for 5 years) | 50k GL entries @ 8 orgs = O(n²) |
| **Tenant context bleeding** | Slow org queries can timeout other orgs' requests | 30 tenants = 10% failure rate |
| **No aggregation** | Dashboard needs 100 SQL queries (one per widget) | 20 dashboards × 30 users = 60k queries/hour |
| **Concurrent lock wait** | Auditor runs massive COA report → blocks invoice posting | Chain reaction failure |
| **No time-series optimization** | "Revenue last 24 months" = 12 full table scans | High variance in latency |

### 1.2 Why Traditional RDBMS Can't Scale

**PostgreSQL is optimized for:**
- Row-oriented storage (write-heavy, normalized OLTP)
- Transaction consistency (ACID)
- Small-to-medium result sets

**PostgreSQL is terrible at:**
- Scanning 1M rows to sum 10 columns
- Ad-hoc analytics on denormalized fact tables
- Concurrent analysis (lock contention with OLTP)

**The math:**
- OLTP: 1,000 writes/sec, 10 reads/sec → PostgreSQL shines
- OLAP: 10 reads/sec but each reads 10M rows → PostgreSQL chokes

---

## 2. Modern Data Architecture for B2B SaaS

### 2.1 The Standard Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│  DATA FLOW: OLTP → OLAP → Semantics → UI                            │
└─────────────────────────────────────────────────────────────────────┘

[OLTP Layer]
  ↓ (CDC or Batch Replication)
[Data Integration Layer]
  ↓
[OLAP Data Warehouse]
  ↓ (Cube/Metric Definition)
[Semantic Layer]
  ↓ (API or Embedded)
[BI Frontend / Embedded Analytics]
  ↓
[End User Dashboards, Reports, Alerts]
```

### 2.2 Layer-by-Layer Breakdown

#### **Layer 1: OLTP (Operational Database)**
- **Current:** PostgreSQL (`apex_prod`)
- **Role:** Transactional system-of-record
- **What lives here:** Invoices, GL entries, audit logs, user sessions
- **Constraint:** Cannot be modified for analytics (ACID compliance)
- **Read pattern:** Point lookups + row updates
- **Data residence:** Real-time (every commit visible immediately)

#### **Layer 2: Data Integration (Change Data Capture)**
- **Purpose:** Stream OLTP changes to warehouse
- **Three approaches:**

  1. **CDC (Debezium + Kafka)**
     - Logical replication from PostgreSQL
     - Real-time event stream
     - Decouples OLTP from warehouse
     - Cost: ~$500/month (self-hosted) or $2k+/month (managed)
     - Best for: Real-time dashboards (sales today, cash position)

  2. **Logical Replication (Native PostgreSQL)**
     - Built-in to PostgreSQL
     - Simpler than Kafka
     - Slower (5–10 sec latency)
     - Cost: Free (infrastructure only)
     - Best for: Small data volumes, batch overnight

  3. **Outbox Pattern (Application-Level)**
     - Application writes events to `outbox` table
     - Separate job polls outbox → warehouse
     - Most reliable (2-phase commit)
     - Cost: ~50 lines of Python code
     - Best for: Critical data (audit trail, invoices)

  **APEX Recommendation:** Hybrid
  - **Outbox pattern** for critical (invoices, GL)
  - **Logical replication** for dimensional (customers, COA)
  - **Scheduled batch** for low-frequency (annual forecasts, historical rollups)

#### **Layer 3: OLAP Data Warehouse**
- **Purpose:** Fast analytical queries on historical + current data
- **Schema:** Star schema (fact + dimensions)
- **Technologies:**

  | Technology | Cost | Latency | Multi-tenant | Columnar | Best For |
  |------------|------|---------|--------------|----------|----------|
  | **ClickHouse** | $50/mo | <1s | Native | Yes | Large-scale OLAP |
  | **DuckDB** | Free | <100ms | Via schema | Yes | Local/embedded |
  | **BigQuery** | $1–10/month | 1–5s | Via dataset | Yes | Serverless/managed |
  | **Snowflake** | $500/mo | 1–10s | Via schema | Yes | Enterprise |
  | **Redshift** | $200/mo | 1–10s | Via schema | Yes | AWS-native |
  | **Postgres Views** | Free | 10–30s | Via views | No | MVP only |

  **APEX Selection by Phase:**
  - **MVP:** PostgreSQL materialized views (free, proven)
  - **Scale:** ClickHouse (cost/performance ratio best for MENA region)
  - **Enterprise:** Snowflake (multi-region, auto-scaling)

#### **Layer 4: Semantic Layer (Metrics as Code)**
- **Purpose:** Define metrics once, use everywhere
- **Example:** `revenue = SUM(invoice.amount) WHERE status='paid'`
- **Benefits:**
  - Single source of truth (DRY principle for analytics)
  - Role-based access control
  - Metric lineage (where did this number come from?)
  - Auto-generated REST APIs

- **Technologies:**

  | Tool | Best For | Cost | Multi-tenant |
  |------|----------|------|--------------|
  | **Cube.dev** | SaaS, custom dashboards | $0–200/mo | Native (RLS) |
  | **LookML (Looker)** | Enterprise, drag-drop | $5k/mo | Native |
  | **dbt** | Data modeling, CI/CD | Free | Via schema |
  | **Materialize** | Real-time metrics | $500/mo | Experimental |

  **APEX Recommendation:**
  - **MVP:** Custom Python metrics class (2–3 weeks dev)
  - **Scale:** Cube.dev (instant ROI, RLS built-in)
  - **Enterprise:** dbt + Cube.dev (repeatability + governance)

#### **Layer 5: BI Frontend & Embedded Analytics**
- **Purpose:** Deliver analytics to end users (in-app or standalone)
- **Approaches:**

  1. **Embedded Iframe (Metabase, Superset)**
     - Pros: One query language, single source of truth
     - Cons: White-labeling hard, latency 2–5s
     - Best for: Internal dashboards

  2. **REST API (Cube.dev)**
     - Pros: Full control over UI, <100ms latency, white-label friendly
     - Cons: Requires custom frontend
     - Best for: Customer-facing, white-labeled

  3. **SQL Query Engine (DuckDB, Presto)**
     - Pros: Highest performance (in-memory)
     - Cons: Complex, requires schema knowledge
     - Best for: Power users

  **APEX Recommendation:** REST API (Cube.dev) + Flutter custom dashboards
  - Native Arabic RTL support
  - Sub-100ms latency for key metrics
  - White-label customer analytics

---

## 3. Technology Choices for APEX

### 3.1 OLAP Database Selection

#### **Candidate: ClickHouse**

**Why ClickHouse for APEX:**

```yaml
Characteristics:
  - Architecture: Columnar OLAP database
  - Compression: 100:1 typical (1TB → 10GB on disk)
  - Latency: <1s for billion-row queries
  - Throughput: 10M rows/sec ingestion
  - Cost: $50–200/month (self-hosted on Render)
  - Scaling: Horizontal (cluster mode available)
  
Multi-tenancy:
  - Tenant isolation via schema (database per tenant or shared with filters)
  - Row-level security via filters
  - Cost attribution (separate tables per tenant)
  
MENA Context:
  - Strong adoption in Middle East (payment processors, fintech)
  - Arabic documentation community
  - Open source (no licensing friction in regions with compliance scrutiny)

Sample Query Performance:
  SELECT 
    invoice_date,
    SUM(amount) as total_revenue,
    COUNT(DISTINCT customer_id) as unique_customers
  FROM invoices
  WHERE org_id = 123 AND invoice_date >= '2026-01-01'
  GROUP BY invoice_date
  
  ClickHouse: 50M rows → 200ms
  PostgreSQL: 50M rows → 30s
  
Integration with APEX:
  - Kafka/Outbox → ClickHouse ReplacingMergeTree
  - Native JSON support (store audit logs verbatim)
  - Built-in time-series (for sales forecasting)
```

**Downsides:**
- Complex query language (slightly different SQL dialect)
- Manual sharding at massive scale
- Operations complexity (require sysadmin)

#### **Candidate: DuckDB**

**Best for:** Embedded analytics (no separate server)

```yaml
Characteristics:
  - Single-file database (SQLite-like)
  - Columnar + OLAP optimized
  - 10–100x faster than SQLite on analytics
  - Free, open source
  - Can query Parquet files directly
  
Use case:
  - Customer runs "export analytics to CSV"
  - Backend: DuckDB on CSV → query → return results
  - No external database dependency
  
Integration with APEX:
  - Copy Parquet snapshots from ClickHouse → DuckDB
  - Customer can download and analyze locally
  - Privacy: no cloud analytics required
```

#### **Candidate: BigQuery**

**Best for:** Zero-ops, pay-per-query

```yaml
Cost Model: $6.25 per TB scanned
  Example: 1M invoices × 100 columns × 8 bytes = 800MB per query
  Cost: $0.005 per query (negligible)
  But: 1000 dashboards × 2 refreshes/day × 30 days = 60k queries = $300/month
  
Multi-tenancy:
  - Shared dataset (tenant_id column for filtering)
  - BigQuery RLS (fine-grained access via IAM)
  
Latency: 2–5s typical (cold cache), <500ms (warm cache)
Scaling: Automatic (no ops)

Downsides:
  - Vendor lock-in (Google Cloud)
  - MENA region: Data residency concerns (hosted in limited regions)
  - Not ideal for real-time (<1s) analytics
```

#### **Candidate: PostgreSQL Materialized Views**

**Best for:** MVP (0 additional services)

```yaml
Approach:
  CREATE MATERIALIZED VIEW mv_daily_revenue AS
  SELECT 
    org_id, 
    DATE(created_at) as day,
    SUM(amount) as total
  FROM invoices
  GROUP BY org_id, DATE(created_at);
  
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_revenue;
  
Performance:
  - 100k rows → 500ms (after refresh)
  - Refresh cost: 5–30s (depends on base table size)
  - Scaling: Not beyond 10–50 dashboards
  
Cost: Free (use existing Postgres)

Downsides:
  - Cannot scale beyond MVP
  - Refresh blocks queries (non-concurrent refresh slower)
  - No compression (1TB OLTP = 800MB MV)
```

### 3.2 APEX Recommendation: ClickHouse (Scale Phase)

**Why:**
1. **Cost-performance:** $50/month for 1TB data, <1s queries (vs. $500/month Snowflake)
2. **Multi-tenancy:** Native row-level filtering (`WHERE org_id = ?`)
3. **MENA fit:** Open source, strong regional adoption
4. **Operational:** Self-hosted on Render's compute tier (same infra as FastAPI)
5. **Integration:** Kafka/Outbox pattern well-established

**Architecture:**

```
PostgreSQL (OLTP) [Render]
    ↓ (Logical Replication → JSON)
Python Worker (Outbox Poller) [Render]
    ↓ (Batch + Stream)
ClickHouse [Render Container, $50/mo]
    ↓ (REST API + JDBC)
Cube.dev Semantic Layer
    ↓ (Generated REST API)
Flutter Web Dashboards + Embedded Analytics
```

---

## 4. Multi-Tenant Analytics Architecture

### 4.1 Per-Tenant Data Isolation

**Challenge:** 100 tenants × 1M invoices each = 100M rows in one table. How to prevent org A from querying org B's data?

#### **Approach 1: Separate Schema Per Tenant**

```sql
-- Physical isolation
CREATE SCHEMA org_001;
CREATE TABLE org_001.invoices (id, amount, created_at);

CREATE SCHEMA org_002;
CREATE TABLE org_002.invoices (id, amount, created_at);

-- Pro: Maximum isolation, easy GDPR deletion
-- Con: Schema management overhead, expensive backup/restore
-- Best for: Small # of tenants (<20), high compliance needs
```

#### **Approach 2: Shared Table + Row-Level Security**

```sql
-- Logical isolation
CREATE TABLE invoices (
  org_id INT,
  id BIGINT,
  amount DECIMAL,
  created_at TIMESTAMP
);

-- ClickHouse native filtering (no true RLS, but same effect)
SELECT SUM(amount) FROM invoices 
WHERE org_id = 123 AND created_at >= now() - interval 7 day;

-- Pro: Simpler operations, better compression across tenants
-- Con: Accidental bug exposes all orgs, requires app-level enforcement
-- Best for: 50+ tenants, trusted application layer
```

#### **Approach 3: Cube.dev Multi-Tenancy**

```javascript
// Cube.dev pre-aggregations with tenant filter

cube(`Invoices`, {
  sql: `SELECT * FROM invoices`,
  
  preAggregations: {
    mainAggregate: {
      measures: [CUBE.total],
      timeDimension: CUBE.created_at,
      granularity: `day`,
      
      // Filter applied automatically by Cube
      refreshKey: {
        every: `1 hour`,
        incremental: true,
        updateWindow: `1 month`
      }
    }
  },
  
  // Cube's RLS: embed tenant in JWT
  dataSource: `default`
});
```

**Cube.dev injects tenant ID from JWT → SQL WHERE clause automatically.**

### 4.2 APEX Recommendation: Shared Table + App Enforcement

**Why:**
- Simpler operations (single ClickHouse cluster)
- Better compression (aggregate across tenants)
- Faster onboarding (no schema migration per org)

**Implementation:**

```python
# FastAPI + Cube.dev

@app.get("/api/dashboards/revenue")
async def get_revenue_dashboard(current_user: User):
    """
    Request includes JWT with org_id claim.
    Cube.dev extracts org_id → injects in all SQL.
    """
    response = cube_client.api.query({
        "measures": ["Invoices.totalRevenue"],
        "dimensions": ["Invoices.date"],
        "filters": [{
            "member": "Invoices.org_id",
            "operator": "equals",
            "value": current_user.org_id
        }]
    })
    return response
```

**Enforcement layers:**
1. **JWT claim:** `{"org_id": 123, ...}`
2. **Cube.dev:** RLS filters org_id automatically
3. **ClickHouse:** Row-level WHERE clause
4. **Database:** No app-level fallback (trust, but verify)

**Audit trail:**
```sql
-- ClickHouse system table logs all queries
SELECT user, query_id, org_id, read_rows, query_duration_ms
FROM system.query_log
WHERE event_date = today()
ORDER BY query_duration_ms DESC;
```

### 4.3 Cost Attribution Per Tenant

**Goal:** Calculate cost per org for chargebacks or unit economics.

```sql
-- ClickHouse: track query costs

CREATE TABLE query_costs (
  org_id Int64,
  query_date Date,
  rows_scanned Int64,
  bytes_scanned Int64,
  duration_ms Float32,
  query_type String  -- 'dashboard', 'export', 'alert'
) ENGINE = MergeTree()
ORDER BY (org_id, query_date);

-- Cost calculation (example: $0.01 per billion rows scanned)
SELECT 
  org_id,
  toDate(query_date) as date,
  COUNT() as query_count,
  SUM(rows_scanned) / 1e9 * 0.01 as cost_usd
FROM query_costs
GROUP BY org_id, date
ORDER BY date DESC;
```

**Billing model:**
- **Starter:** $50/month → $5 of analytics included
- **Professional:** $200/month → $50 of analytics included
- **Enterprise:** $1000/month → $500 of analytics included

---

## 5. Real-Time vs. Batch Analytics

### 5.1 Which APEX Metrics MUST Be Real-Time (<1s)?

**Real-time (Sub-Second):**
- **Cash position** (CFO dashboard: "What is our balance NOW?")
- **Sales today** (Sales manager: "Revenue so far this week?")
- **Pending approvals** (Audit manager: "Invoices awaiting sign-off")
- **System health** (Infra: "DB connection pool, API error rate")

**Near-real-time (5–30s):**
- **Customer balance** (AR aging, payment status)
- **Inventory position** (stock on hand, pending receipts)
- **Payroll accrual** (YTD gross, taxes withheld)

**Batch (Hourly–Daily):**
- **Period close reports** (Month-end financials: posted after close)
- **Audit schedules** (External audit findings, risk assessment)
- **Forecast vs. actual** (Compare YTD to annual budget)
- **Compliance reports** (Tax, regulatory: generated 1x/month)

### 5.2 Architecture for Mixed Latencies

```
REAL-TIME PATH (sub-1s):
  OLTP PostgreSQL (primary key lookup)
    → FastAPI cache layer (Redis, 1-min TTL)
    → Flutter widget refreshes every 5s

NEAR-REAL-TIME (5–30s):
  OLAP ClickHouse (pre-aggregated views)
    → Cube.dev REST API (10-min materialization)
    → Dashboard refresh every 30s

BATCH (Hourly–Daily):
  OLAP ClickHouse (full historical data)
    → dbt transformations (run 1x/day at midnight UTC+3)
    → Email reports, PDF exports
```

### 5.3 APEX Recommendation: Hybrid Approach

**Real-time metrics:**
```python
# app/phaseN/services/cash_flow_service.py

import redis

cache = redis.Redis(host='localhost', port=6379)

def get_cash_position(org_id: int) -> dict:
    # Try cache first (1-min TTL)
    cached = cache.get(f"cash:{org_id}")
    if cached:
        return json.loads(cached)
    
    # Fall back to OLTP
    balance = db.query(
        "SELECT SUM(amount) FROM gl_postings "
        "WHERE org_id = ? AND account IN (select id from accounts where type='cash')",
        (org_id,)
    ).scalar()
    
    # Cache for 60 seconds
    cache.setex(f"cash:{org_id}", 60, json.dumps({"balance": balance}))
    return {"balance": balance}
```

**Batch aggregations (daily close):**
```python
# app/sprintN/scheduled_tasks.py

@scheduler.scheduled_task("0 2 * * *")  # 2 AM daily (UTC+3)
async def refresh_analytics_warehouse():
    """
    1. Export daily GL snapshot from OLTP
    2. Load into ClickHouse (ReplacingMergeTree deduplication)
    3. Run dbt models for dimensional tables
    4. Materialize Cube.dev pre-aggregations
    5. Email daily reports
    """
    # Pseudo-code
    gl_snapshot = db.query("SELECT * FROM gl_postings WHERE date = today()")
    
    clickhouse.insert_table("gl_daily", gl_snapshot)
    
    dbt.run(models=["dim_accounts", "fact_daily_balances"])
    
    cube.refresh_materializations(models=["revenue_by_department"])
    
    send_email_reports()
```

---

## 6. AI on Top of Analytics

### 6.1 Natural Language → SQL (Claude Copilot)

**Goal:** Enable finance users to ask: "What was our revenue last quarter?" and get instant SQL + answer.

**Architecture:**

```
User Question: "Which invoices are older than 90 days and unpaid?"
    ↓
Claude API (with schema context)
    ↓ (Few-shot prompt)
Generated SQL: 
  SELECT id, customer, amount, invoice_date 
  FROM invoices 
  WHERE status='unpaid' 
    AND invoice_date < now() - interval '90 days'
    AND org_id = 123
    ↓
Validation (LLM check SQL doesn't access forbidden orgs)
    ↓
Execute on ClickHouse / PostgreSQL
    ↓
Format result (markdown table or Excel)
    ↓
Display in Flutter dashboard
```

**Implementation (FastAPI):**

```python
# app/phaseN/services/copilot_service.py

import anthropic

client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

def query_copilot(question: str, org_id: int, schema: str) -> dict:
    """
    question: "Which GL accounts have no transactions in 2026?"
    schema: Database schema (tables, columns, foreign keys)
    """
    
    prompt = f"""
    You are a financial SQL expert for an ERP system. 
    
    Database schema:
    {schema}
    
    User's organization ID: {org_id}
    
    CRITICAL: Always filter by org_id = {org_id} to prevent data leakage.
    
    User question: {question}
    
    Generate exactly one SQL query (no explanation, no markdown).
    Query must:
    - Filter by org_id = {org_id}
    - Use column names exactly as defined in schema
    - Return results in <5 seconds on ClickHouse
    """
    
    response = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}]
    )
    
    sql_query = response.content[0].text.strip()
    
    # Validate: ensure org_id filter present
    if f"org_id = {org_id}" not in sql_query:
        raise ValueError("Generated SQL missing org_id filter!")
    
    # Execute on ClickHouse
    result = clickhouse.execute(sql_query)
    
    return {
        "question": question,
        "sql": sql_query,
        "result": result,
        "execution_time_ms": result.execution_time
    }
```

**Safety considerations:**
1. Always inject org_id in prompt (prevents prompt injection)
2. Validate generated SQL before execution
3. Log all copilot queries (audit trail)
4. Use read-only database user (no INSERT/UPDATE/DELETE)
5. Add query timeout (5-second max)

### 6.2 Anomaly Detection on Time Series

**Goal:** Alert finance team when something looks wrong (e.g., "Revenue suddenly dropped 50%").

**Implementation (Python + scikit-learn):**

```python
# app/sprintN/services/anomaly_detection.py

import numpy as np
from sklearn.ensemble import IsolationForest

def detect_revenue_anomalies(org_id: int, days: int = 90) -> list:
    """
    1. Fetch daily revenue for last N days
    2. Train Isolation Forest on time series
    3. Flag anomalies (revenue 2+ std deviations from trend)
    4. Return alerts
    """
    
    # Get time series
    daily_revenue = db.query(
        """SELECT DATE(created_at) as day, SUM(amount) as revenue
           FROM invoices 
           WHERE org_id = ? AND created_at >= now() - interval ? day
           GROUP BY DATE(created_at)
           ORDER BY day""",
        (org_id, days)
    )
    
    # Prepare data
    X = np.array([[i, revenue] for i, (day, revenue) in enumerate(daily_revenue)])
    
    # Train anomaly detector
    iso_forest = IsolationForest(contamination=0.1, random_state=42)
    anomalies = iso_forest.fit_predict(X)  # -1 = anomaly, 1 = normal
    
    # Build alerts
    alerts = []
    for i, (day, revenue) in enumerate(daily_revenue):
        if anomalies[i] == -1:
            alerts.append({
                "date": day,
                "revenue": revenue,
                "severity": "high" if revenue < X.mean(axis=0)[1] * 0.5 else "medium",
                "message": f"Revenue on {day} was ${revenue:,.0f} (unusual for this org)"
            })
    
    return alerts
```

**Integrated into dashboard:**
```dart
// Flutter widget shows anomaly ribbon

class AnomalyBanner extends StatelessWidget {
  final List<Anomaly> anomalies;
  
  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) return SizedBox.shrink();
    
    return Container(
      color: Colors.red.shade50,
      child: Column(
        children: anomalies.map((a) => 
          ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text(a.message, style: TextStyle(fontSize: 12)),
          )
        ).toList(),
      ),
    );
  }
}
```

### 6.3 Forecasting (Prophet + Time Series)

**Goal:** Predict next month's revenue based on YTD trends.

```python
# app/sprintN/services/forecasting.py

from prophet import Prophet
import pandas as pd

def forecast_revenue(org_id: int, periods: int = 30) -> dict:
    """
    periods: Days to forecast (default 30)
    """
    
    # Get historical daily revenue (last 2 years)
    history = db.query(
        """SELECT DATE(created_at) as ds, SUM(amount) as y
           FROM invoices 
           WHERE org_id = ?
           GROUP BY DATE(created_at)
           ORDER BY ds""",
        (org_id,)
    )
    
    df = pd.DataFrame(history, columns=['ds', 'y'])
    df['ds'] = pd.to_datetime(df['ds'])
    
    # Train Prophet
    model = Prophet(yearly_seasonality=True, weekly_seasonality=True)
    model.fit(df)
    
    # Forecast
    future = model.make_future_dataframe(periods=periods)
    forecast = model.predict(future)
    
    # Extract next 30 days
    forecast_data = forecast[forecast['ds'] > pd.Timestamp.today()][
        ['ds', 'yhat', 'yhat_lower', 'yhat_upper']
    ].head(periods)
    
    return {
        "forecast": forecast_data.to_dict('records'),
        "model_mae": model.mae,  # Mean Absolute Error on training data
        "confidence_interval": "95%"
    }
```

**Flutter widget (chart):**
```dart
// Show forecast as overlay on historical chart

class RevenueWithForecast extends StatelessWidget {
  final List<DailyRevenue> historical;
  final List<ForecastPoint> forecast;
  
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          // Historical data
          LineChartBarData(
            spots: historical.map((h) => FlSpot(h.day.toDouble(), h.amount)).toList(),
            color: Colors.blue,
          ),
          // Forecast (dashed line)
          LineChartBarData(
            spots: forecast.map((f) => FlSpot(f.day.toDouble(), f.yhat)).toList(),
            color: Colors.orange,
            dashArray: [5, 5],
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withOpacity(0.1),
              spotsLine: SpotsLine(
                showXDotLine: false,
                showBottomLine: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 7. Embedded Analytics in Flutter Web

### 7.1 Architecture: API vs. Iframe

#### **Option 1: Iframe (Metabase / Superset)**

```html
<!-- Simple but limited -->
<iframe
  src="https://metabase.company.com/embed/dashboard/uuid?key=sso_key"
  width="100%"
  height="800"
/>
```

**Pros:**
- Zero frontend code
- WYSIWYG dashboard builder in Metabase UI
- Instant analytics for non-technical users

**Cons:**
- No Arabic RTL support (Metabase default is LTR)
- White-labeling difficult (iframe shows Metabase UI chrome)
- Latency: 2–5s per chart
- No drill-down (chart click → new tab, breaks UX flow)

#### **Option 2: REST API (Cube.dev)**

```dart
// Flutter example: custom dashboard consuming Cube.dev API

class CubeDashboard extends StatefulWidget {
  @override
  State<CubeDashboard> createState() => _CubeDashboardState();
}

class _CubeDashboardState extends State<CubeDashboard> {
  final cubeApi = CubeApi(
    baseUrl: "https://cube.company.com/api/v1",
    token: accessToken  // JWT with org_id
  );
  
  @override
  void initState() {
    super.initState();
    loadDashboard();
  }
  
  Future<void> loadDashboard() async {
    final revenue = await cubeApi.query({
      "measures": ["Invoices.totalRevenue"],
      "dimensions": ["Invoices.month"],
      "filters": [{"member": "Invoices.status", "operator": "equals", "value": "paid"}]
    });
    
    setState(() {
      revenueSeries = revenue.data;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      series: [
        LineSeries<RevenuePoint, String>(
          dataSource: revenueSeries,
          xValueMapper: (point, _) => point.month,
          yValueMapper: (point, _) => point.revenue,
          color: AC.primary,
        )
      ],
    );
  }
}
```

**Pros:**
- Full control over UI (Arabic RTL native)
- Fast (<100ms with materialization)
- Drill-down, drill-through built-in
- Custom branding
- Mobile-friendly

**Cons:**
- Requires Flutter expertise
- More code (2–3 weeks per dashboard)
- Metric schema must be pre-defined (no ad-hoc)

### 7.2 APEX Recommendation: Hybrid

**Approach:**
1. **Pre-built dashboards** (REST API + Flutter custom widgets)
   - Revenue, AR aging, GL balance, period close
   - 10 strategic dashboards designed for APEX use cases
   - Built in-house, white-labeled

2. **Ad-hoc exploration** (Metabase embedded, limited)
   - For power users (CFOs, auditors)
   - Limited to pre-approved views (no full schema access)
   - Separate Metabase instance (no white-labeling)

3. **Exported reports** (Cube.dev → PDF/Excel)
   - Scheduled daily/weekly reports emailed to users
   - Exportable from dashboard (single-click)

### 7.3 Arabic RTL Support

**Challenge:** APEX is Arabic-first (UI language), but most BI tools (Metabase, Superset) are English-first.

**Solution:** Custom Flutter dashboard widgets

```dart
// core/theme.dart

final AC = AppColors(
  // ... existing colors ...
  chartBackgroundArabic: Color(0xFFF5F5F5),
);

// Component: RTL-aware chart legend

class ArabicChartLegend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;
  
  @override
  Widget build(BuildContext context) {
    final isArabic = Intl.getCurrentLocale().startsWith('ar');
    
    return Row(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                labels[i],
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          SizedBox(width: 20),
        ]
      ],
    );
  }
}
```

---

## 8. Cost Model for Analytics Infrastructure

### 8.1 MVP Phase (Months 1–3)

**Setup:**
- PostgreSQL materialized views (existing)
- Apache Superset (self-hosted on Render)
- Daily batch refresh (5 GB data)

**Costs:**

| Component | Cost | Notes |
|-----------|------|-------|
| PostgreSQL compute | Included | Existing instance |
| Superset (Render) | $7–50/month | Basic tier |
| Developer time | $30k | 1 engineer, 3 months |
| **Total** | **$30k–30.5k** | |

**Throughput:**
- Up to 50 dashboards
- Sub-10s load times (materialization helps)
- 10 concurrent users max

### 8.2 Scale Phase (Year 1–2)

**Setup:**
- ClickHouse OLAP (Render or self-hosted)
- Cube.dev semantic layer
- Custom Flutter dashboards
- Airbyte for ELT

**Cost breakdown (100 tenants):**

| Component | Cost | Per-Tenant | Notes |
|-----------|------|-----------|-------|
| **Infrastructure** | | | |
| ClickHouse (Render XL) | $200/mo | $2/tenant | 1TB capacity, <1s queries |
| Cube.dev (Pro) | $200/mo | $2/tenant | Semantic layer, RLS, APIs |
| Airbyte (cloud) | $300/mo | $3/tenant | ELT tool, 20 connectors |
| Redis (cache) | $50/mo | $0.5/tenant | Real-time metrics |
| **Development** | | | |
| Engineer (1 FTE) | $120k/year | $1.2k/tenant | Analytics engineering |
| Data analyst (0.5 FTE) | $40k/year | $400/tenant | Cube models, dbt |
| **Analytics** | | | |
| Anthropic API (Copilot) | $500/mo | $5/tenant | 100k tokens/day × 100 tenants |
| **Totals** | **$161k/year** | **$1.6k/tenant/year** | |

**Per-tenant monthly: ~$135**

### 8.3 Enterprise Phase (Year 3+)

**Setup:**
- Multi-region ClickHouse (HA)
- Cube.dev Enterprise
- dbt Cloud (version control)
- Looker (advanced permissioning)
- ML forecasting (custom)

**Cost breakdown (1000 tenants):**

| Component | Cost | Per-Tenant | Notes |
|-----------|------|-----------|-------|
| **Infrastructure** | | | |
| ClickHouse Multi-region | $2000/mo | $2/tenant | HA, replication, backups |
| Cube.dev Enterprise | $1500/mo | $1.5/tenant | SLA, priority support |
| Airbyte (self-hosted) | $500/mo | $0.5/tenant | Cost savings (scale) |
| Redis Cluster | $200/mo | $0.2/tenant | Distributed cache |
| S3 Data Lake | $500/mo | $0.5/tenant | Long-term archival |
| **Development** | | | |
| Data Platform team | $400k/year | $400/tenant | 4 engineers |
| Analytics team | $200k/year | $200/tenant | 2 analysts |
| DevOps (analytics) | $100k/year | $100/tenant | ClickHouse operations |
| **Analytics** | | | |
| Anthropic API | $3k/mo | $3/tenant | Scaled copilot usage |
| Looker Enterprise | $5k/mo | $5/tenant | Advanced dashboard builder |
| dbt Cloud (team) | $1k/mo | $1/tenant | Data orchestration |
| **Totals** | **$743k/year** | **$743/tenant/year** | |

**Per-tenant monthly: ~$62** (economies of scale)

---

## 9. Strategic Recommendation for APEX

### 9.1 MVP (Months 1–3): "Quick Wins"

**Goal:** Ship analytics without building infrastructure.

**Tech Stack:**
- PostgreSQL materialized views (refresh nightly)
- Apache Superset (free, self-hosted)
- FastAPI + Jinja templates (custom reports)

**Deliverables:**
1. **Dashboard module** (`/app/phase8/analytics/`)
   - Revenue by month
   - AR aging bucket (0–30, 30–60, 60–90, 90+)
   - GL balance detail
   - Invoice status (draft, posted, paid, overdue)

2. **Scheduled reports**
   - Daily cash position (email)
   - Weekly revenue summary
   - Monthly close checklist

3. **Export functionality**
   - Dashboard → PDF
   - Report → Excel

**Effort:** 1 engineer, 12 weeks

**ROI:**
- Customers can see reports (key feature gap vs. competitors)
- Internal team unblocked for month-end close
- Data for decision-making

### 9.2 Scale Phase (Year 1–2): "Real Analytics"

**Trigger:** 30+ tenants, <100ms latency requirement, reports timing out

**Tech Stack:**
- ClickHouse (columnar OLAP, $50/mo)
- Cube.dev (semantic layer)
- Custom Flutter dashboards
- dbt (data modeling)

**Milestones:**

| Month | Deliverable | Effort |
|-------|-------------|--------|
| 1–2 | ClickHouse setup + CDC pipeline | 2 engineers, 4 weeks |
| 3–4 | Cube.dev semantic models (50 metrics) | 1 analyst, 4 weeks |
| 5–8 | Flutter dashboard suite (10 dashboards) | 2 engineers + 1 designer, 8 weeks |
| 9–12 | Copilot + anomaly detection | 1 engineer, 4 weeks |

**ROI:**
- <1s dashboard load (vs. 10s materialized views)
- Sub-second KPI lookups (cash position, pending approvals)
- AI copilot (natural language queries)
- Multi-tenant cost tracking

### 9.3 Enterprise Phase (Year 3+): "Scale Beyond APEX"

**Trigger:** 100+ tenants, customer requests for white-labeled analytics, regulatory reporting

**Tech Stack:**
- Multi-region ClickHouse (high availability)
- dbt Cloud (CI/CD for data models)
- Looker or Superset (customer-facing)
- ML forecasting (in-house)
- Data governance (data lineage, quality checks)

**Initiatives:**
1. **Analytics SaaS product** (separate from APEX)
   - White-label reporting
   - Industry templates (manufacturing, retail, services)
   - Custom metrics API

2. **Compliance & audit automation**
   - Continuous audit trails (who queried what, when)
   - Regulatory reports (SOX 404, IFRS)
   - Data residency enforcement (GDPR, Saudi Arabia data laws)

3. **Advanced ML**
   - Budget variance prediction
   - Fraud detection
   - Cash flow forecasting

---

## 10. Detailed Feature Design: "Embedded Analytics" Module

### 10.1 Data Model

```python
# app/phase8/analytics/models.py

class Dashboard(Base):
    __tablename__ = "dashboards"
    
    id = Column(Integer, primary_key=True)
    org_id = Column(Integer, ForeignKey("organizations.id"))
    name = Column(String(255), nullable=False)
    description = Column(Text)
    
    # Ownership & access control
    created_by = Column(Integer, ForeignKey("users.id"))
    owner_role = Column(String(50))  # 'finance_manager', 'auditor', 'cfo'
    is_public_in_org = Column(Boolean, default=False)
    
    # Layout & styling
    layout_type = Column(String(50), default="grid")  # 'grid', 'freeform'
    grid_width = Column(Integer, default=12)
    background_color = Column(String(10), default="#ffffff")
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_viewed_at = Column(DateTime)
    view_count = Column(Integer, default=0)
    
    # Relations
    widgets = relationship("DashboardWidget", back_populates="dashboard", cascade="all, delete-orphan")
    scheduled_exports = relationship("ScheduledReport", back_populates="dashboard")

class DashboardWidget(Base):
    __tablename__ = "dashboard_widgets"
    
    id = Column(Integer, primary_key=True)
    dashboard_id = Column(Integer, ForeignKey("dashboards.id"))
    
    # Widget configuration
    widget_type = Column(String(50))  # 'kpi', 'line_chart', 'bar_chart', 'table', 'heatmap'
    title = Column(String(255))
    metric = Column(String(255))  # 'revenue_ytd', 'ar_aging_90plus', etc.
    
    # Query configuration
    query_json = Column(JSON)  # Cube.dev query definition
    filters = Column(JSON)  # Date range, org, region, etc.
    
    # Layout
    position = Column(Integer)  # Left-to-right, top-to-bottom
    grid_column = Column(Integer)  # 0–11 (12-column grid)
    grid_row = Column(Integer)
    grid_width = Column(Integer, default=3)  # 1–12 columns
    grid_height = Column(Integer, default=2)  # 1–6 rows
    
    # Refresh & caching
    refresh_interval = Column(Integer, default=300)  # Seconds
    last_refreshed_at = Column(DateTime)
    cache_ttl = Column(Integer, default=60)  # Cache for N seconds
    
    # Drill-down & interactivity
    drilldown_enabled = Column(Boolean, default=True)
    drilldown_target = Column(String(255))  # 'detail_report', 'transaction_list'
    
    dashboard = relationship("Dashboard", back_populates="widgets")

class ScheduledReport(Base):
    __tablename__ = "scheduled_reports"
    
    id = Column(Integer, primary_key=True)
    dashboard_id = Column(Integer, ForeignKey("dashboards.id"))
    org_id = Column(Integer, ForeignKey("organizations.id"))
    
    # Schedule
    name = Column(String(255))
    cron_expression = Column(String(100))  # '0 9 * * 1' = Monday 9 AM
    timezone = Column(String(50), default="Asia/Riyadh")
    
    # Recipients & format
    recipient_emails = Column(JSON)  # ["cfo@org.com", "audit@org.com"]
    export_format = Column(String(20))  # 'pdf', 'excel', 'html'
    include_commentary = Column(Boolean, default=False)
    
    # Metadata
    is_active = Column(Boolean, default=True)
    last_sent_at = Column(DateTime)
    
    dashboard = relationship("Dashboard", back_populates="scheduled_exports")

class AnalyticsQuery(Base):
    __tablename__ = "analytics_queries"
    
    id = Column(Integer, primary_key=True)
    org_id = Column(Integer, ForeignKey("organizations.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Query metadata
    query_text = Column(Text)  # Natural language question
    generated_sql = Column(Text)  # Generated SQL (for audit)
    query_type = Column(String(50))  # 'copilot', 'saved', 'export'
    
    # Execution
    executed_at = Column(DateTime, default=datetime.utcnow)
    execution_time_ms = Column(Integer)
    rows_returned = Column(Integer)
    status = Column(String(20))  # 'success', 'error', 'timeout'
    error_message = Column(Text)
    
    # Cost tracking
    bytes_scanned = Column(BigInteger)
    estimated_cost_usd = Column(Numeric(10, 4))
```

### 10.2 Pre-Built KPI Library

```python
# app/phase8/analytics/kpi_definitions.py

KPI_LIBRARY = {
    "revenue_mtd": {
        "name": "Revenue (MTD)",
        "description": "Total invoiced revenue for current month",
        "cube_measure": "Invoices.totalRevenue",
        "cube_filters": [
            {"member": "Invoices.status", "operator": "equals", "value": "posted"}
        ],
        "dimension": "Invoices.month",
        "format": "currency",
        "icon": "trending_up",
    },
    "revenue_ytd": {
        "name": "Revenue (YTD)",
        "description": "Total invoiced revenue for current year",
        "cube_measure": "Invoices.totalRevenue",
        "cube_filters": [
            {"member": "Invoices.status", "operator": "equals", "value": "posted"},
            {"member": "Invoices.year", "operator": "equals", "value": "current_year"}
        ],
        "format": "currency",
    },
    "ar_aging_90plus": {
        "name": "AR > 90 Days",
        "description": "Invoices outstanding >90 days",
        "cube_measure": "Invoices.count",
        "cube_filters": [
            {"member": "Invoices.days_outstanding", "operator": "gt", "value": 90}
        ],
        "format": "integer",
        "color": "red",  # Alert color
    },
    "cash_position": {
        "name": "Cash Balance",
        "description": "Current bank balance",
        "cube_measure": "GlPostings.cashBalance",
        "cube_filters": [
            {"member": "GlPostings.account_type", "operator": "equals", "value": "cash"}
        ],
        "format": "currency",
        "refresh_interval": 60,  # Real-time
        "source": "oltp",  # Query OLTP, not OLAP
    },
    "expense_ratio": {
        "name": "Expense Ratio",
        "description": "Operating expenses / revenue",
        "formula": "Invoices.totalExpenses / Invoices.totalRevenue",
        "format": "percent",
    },
    ...  # 50+ more KPIs
}
```

### 10.3 Custom Query Builder (Power Users)

```dart
// frontend/lib/screens/analytics/custom_query_builder.dart

class CustomQueryBuilder extends StatefulWidget {
  @override
  State<CustomQueryBuilder> createState() => _CustomQueryBuilderState();
}

class _CustomQueryBuilderState extends State<CustomQueryBuilder> {
  List<String> selectedMeasures = [];
  List<String> selectedDimensions = [];
  List<Map<String, dynamic>> filters = [];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Custom Query"),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: () => executeQuery(),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () => saveAsReport(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Measures (metrics to calculate)
              Text("Measures", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                children: AVAILABLE_MEASURES.map((measure) =>
                  FilterChip(
                    label: Text(measure),
                    selected: selectedMeasures.contains(measure),
                    onSelected: (selected) => setState(() {
                      if (selected)
                        selectedMeasures.add(measure);
                      else
                        selectedMeasures.remove(measure);
                    }),
                  )
                ).toList(),
              ),
              SizedBox(height: 20),
              
              // Dimensions (grouping)
              Text("Group By", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                children: AVAILABLE_DIMENSIONS.map((dimension) =>
                  FilterChip(
                    label: Text(dimension),
                    selected: selectedDimensions.contains(dimension),
                    onSelected: (selected) => setState(() {
                      if (selected)
                        selectedDimensions.add(dimension);
                      else
                        selectedDimensions.remove(dimension);
                    }),
                  )
                ).toList(),
              ),
              SizedBox(height: 20),
              
              // Filters
              Text("Filters", style: TextStyle(fontWeight: FontWeight.bold)),
              for (var filter in filters)
                Row(
                  children: [
                    Expanded(child: Text(filter['display'])),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => setState(() => filters.remove(filter)),
                    ),
                  ],
                ),
              ElevatedButton(
                onPressed: () => addFilter(),
                child: Text("Add Filter"),
              ),
              SizedBox(height: 20),
              
              // SQL Preview (read-only)
              Text("Generated SQL", style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  buildSQL(),
                  style: TextStyle(fontFamily: 'Courier', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String buildSQL() {
    String sql = "SELECT ";
    sql += [...selectedMeasures, ...selectedDimensions].join(", ");
    sql += " FROM fact_table WHERE org_id = ?";
    for (var filter in filters) {
      sql += " AND ${filter['sql']}";
    }
    sql += " GROUP BY ${selectedDimensions.join(", ")}";
    return sql;
  }
  
  Future<void> executeQuery() async {
    // Call Cube.dev REST API
    final response = await cubeApi.query({
      "measures": selectedMeasures,
      "dimensions": selectedDimensions,
      "filters": filters.map((f) => f['cube_filter']).toList(),
    });
    
    // Navigate to results view
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QueryResults(data: response.data),
    ));
  }
}
```

### 10.4 Scheduled Reports & Exports

```python
# app/phase8/analytics/services/report_scheduler.py

class ReportScheduler:
    def __init__(self, cube_client, smtp_client, storage):
        self.cube = cube_client
        self.smtp = smtp_client
        self.storage = storage
    
    async def send_scheduled_report(self, report_id: int):
        """Execute a scheduled report and email to recipients."""
        
        report = db.query(ScheduledReport).filter_by(id=report_id).first()
        dashboard = report.dashboard
        
        # 1. Execute all widgets' queries
        widget_results = {}
        for widget in dashboard.widgets:
            result = await self.cube.query(widget.query_json)
            widget_results[widget.id] = result.data
        
        # 2. Generate PDF
        pdf_bytes = await self._render_pdf(dashboard, widget_results)
        
        # 3. Upload to S3 (or local storage)
        pdf_url = await self.storage.upload(
            f"reports/{report.org_id}/{report_id}.pdf",
            pdf_bytes
        )
        
        # 4. Send email
        email_body = f"""
        <h2>{dashboard.name}</h2>
        <p>Generated at {datetime.utcnow().isoformat()}</p>
        <p><a href="{pdf_url}">Download PDF</a></p>
        
        {await self._render_html_summary(widget_results)}
        """
        
        await self.smtp.send_email(
            to=report.recipient_emails,
            subject=f"{dashboard.name} - {date.today().isoformat()}",
            html_body=email_body,
            attachment=pdf_bytes if report.export_format == "pdf" else None
        )
        
        # 5. Update metadata
        report.last_sent_at = datetime.utcnow()
        db.commit()
    
    async def _render_pdf(self, dashboard: Dashboard, results: dict) -> bytes:
        """Use weasyprint or reportlab to generate PDF."""
        from weasyprint import HTML, CSS
        
        html_content = f"""
        <html dir="rtl">
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: "Arabic Typesetting", Arial; direction: rtl; }}
                .widget {{ page-break-inside: avoid; margin: 20px; border: 1px solid #ccc; padding: 10px; }}
                .kpi {{ font-size: 32px; font-weight: bold; }}
            </style>
        </head>
        <body>
            <h1>{dashboard.name}</h1>
            <p>تاريخ: {datetime.utcnow().strftime('%Y-%m-%d')}</p>
        """
        
        for widget in dashboard.widgets:
            data = results[widget.id]
            html_content += f"""
            <div class="widget">
                <h3>{widget.title}</h3>
                {self._render_widget_html(widget.widget_type, data)}
            </div>
            """
        
        html_content += "</body></html>"
        
        pdf = HTML(string=html_content).render().write_pdf()
        return pdf
    
    async def export_dashboard(self, dashboard_id: int, format: str, org_id: int):
        """
        format: 'pdf', 'excel', 'html'
        """
        dashboard = db.query(Dashboard).filter_by(
            id=dashboard_id, org_id=org_id
        ).first()
        
        if format == "excel":
            return await self._render_excel(dashboard)
        elif format == "pdf":
            return await self._render_pdf(dashboard, {})
        elif format == "html":
            return await self._render_html(dashboard, {})

# Celery task for nightly execution
@celery_app.task(bind=True)
def run_scheduled_reports():
    """Run all active scheduled reports at their scheduled times."""
    
    scheduler = ReportScheduler(cube, smtp, storage)
    
    now = datetime.utcnow()
    
    # Find reports due to run
    due_reports = db.query(ScheduledReport).filter(
        ScheduledReport.is_active == True
    ).all()
    
    for report in due_reports:
        if is_report_due(report, now):
            asyncio.run(scheduler.send_scheduled_report(report.id))
```

### 10.5 Drill-Down & Data Lineage

```dart
// frontend/lib/widgets/analytics/drill_down_chart.dart

class DrillDownChart extends StatefulWidget {
  final String metric;
  final List<dynamic> data;
  final String drilldownTarget;
  
  @override
  State<DrillDownChart> createState() => _DrillDownChartState();
}

class _DrillDownChartState extends State<DrillDownChart> {
  late LineChart chart;
  List<String> breadcrumbs = [];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Breadcrumb navigation
        if (breadcrumbs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => breadcrumbs.clear()),
                  child: Text("All", style: TextStyle(color: Colors.blue)),
                ),
                for (var crumb in breadcrumbs) ...[
                  Text(" > "),
                  GestureDetector(
                    onTap: () {
                      final idx = breadcrumbs.indexOf(crumb);
                      setState(() => breadcrumbs = breadcrumbs.sublist(0, idx + 1));
                    },
                    child: Text(crumb, style: TextStyle(color: Colors.blue)),
                  ),
                ]
              ],
            ),
          ),
        
        // Chart (clickable)
        GestureDetector(
          onTapDown: (details) async {
            // Detect which bar/point was tapped
            final tapIndex = detectTappedBar(details.localPosition, chart);
            if (tapIndex != null && widget.drilldownTarget != null) {
              // Fetch drill-down data
              final dimension = widget.data[tapIndex]['dimension'];
              breadcrumbs.add(dimension);
              
              // Re-query with filter
              final drilldownData = await cubeApi.query({
                ...widget.data[tapIndex]['query'],
                "filters": [
                  ...(widget.data[tapIndex]['query']['filters'] ?? []),
                  {"member": widget.drilldownTarget, "operator": "equals", "value": dimension}
                ]
              });
              
              setState(() {
                // Update chart with drill-down data
              });
            }
          },
          child: Container(
            height: 300,
            child: LineChart(...),
          ),
        ),
        
        // Data lineage (where did this data come from?)
        ExpansionTile(
          title: Text("Data Lineage"),
          children: [
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: SelectableText(
                "Metric: ${widget.metric}\n"
                "Source: ClickHouse (olap_invoices)\n"
                "Refresh: Daily at 2 AM UTC+3\n"
                "Last Updated: ${dateFormat(lastRefresh)}\n"
                "Data Age: 0–24 hours\n"
                "Governance: Finance team reviews monthly\n"
                "Calculation: SUM(amount) WHERE status='posted'",
                style: TextStyle(fontFamily: 'Courier', fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## 11. Competitive Analysis

### 11.1 APEX vs. Competitors' Analytics

| Feature | APEX (Proposed) | SAP Analytics | NetSuite SuiteAnalytics | Odoo Studio | Daftra |
|---------|-----------------|------------------|------------------------|-----------|--------|
| **Real-time dashboards** | Yes (Cube.dev) | Yes | Yes | Limited | Limited |
| **Embedded in product** | Yes (Flutter) | Yes | Yes (SuiteNav) | Yes | Yes |
| **Arabic UI** | Native RTL | Limited | Limited | Limited | Native |
| **Cost per tenant** | $50–200/mo | $5k+/mo | $3k+/mo | $500/mo | $100/mo |
| **Multi-tenancy** | Native | Limited | Limited | Native | Native |
| **AI/Copilot** | Yes (Claude) | Yes (SAP AI) | No | No | No |
| **White-labeling** | Full (REST API) | Limited | Limited | Full | Full |
| **Custom metrics** | Yes (Cube.dev) | Limited | Limited | Yes | Yes |
| **Export to Excel** | Yes | Yes | Yes | Yes | Yes |
| **Scheduled reports** | Yes | Yes | Yes | Yes | Yes |
| **Ad-hoc queries** | Yes (power users) | Yes | Yes (SuiteQL) | Limited | Limited |
| **Drill-down** | Yes | Yes | Yes | Limited | Limited |
| **Mobile charts** | Yes (Flutter) | Limited | Limited | Limited | Limited |
| **Learning curve** | Medium (custom) | High (complex) | Medium | Low | Low |

**APEX Advantages:**
1. **Cost:** 10x cheaper than SAP/NetSuite
2. **Customization:** Cube.dev semantic layer → unlimited metrics
3. **Arabic-first:** Native RTL for MENA market
4. **AI:** Built-in copilot (natural language queries)
5. **Multi-tenant:** Cost model scales sub-linearly

### 11.2 Why APEX Beats Alternatives in MENA

**SAP BI (BI Tools) / NetSuite:**
- Prohibitively expensive ($5k+/mo)
- Assumes English-speaking finance teams
- Enterprise complexity (3–6 month implementation)
- Tied to SAP/Oracle ecosystem

**Odoo:**
- Weak analytics (only dashboards, no semantic layer)
- Limited to Odoo modules (can't query external data sources)
- Poor real-time performance

**Daftra (Local MENA competitor):**
- Simple accounting SaaS
- No OLAP layer (queries OLTP directly)
- Will fail at scale (same issue as APEX has now)

**APEX Solution:**
- Modern data architecture (separate OLAP)
- Multi-tenant from day 1 (Cube.dev RLS)
- AI copilot (competitive moat vs. traditional BI)
- Open source foundations (dbt, ClickHouse) → no licensing friction in MENA

---

## 12. Implementation Roadmap

### Phase 1: MVP (Months 1–3)

**Week 1–2:** Foundation
- PostgreSQL schema design for analytics tables
- Materialized view framework

**Week 3–6:** Dashboards
- Revenue dashboard
- AR aging dashboard
- GL balance dashboard
- Period close checklist

**Week 7–10:** Exports & Scheduling
- PDF export (weasyprint)
- Excel export (openpyxl)
- Scheduled email reports (Celery)

**Week 11–12:** Polish & docs
- Flutter integration
- Dark mode support
- Accessibility (WCAG)

### Phase 2: Scale (Months 4–12)

**Month 4–5:** ClickHouse
- Cluster setup on Render
- Logical replication → ClickHouse
- Schema migration (star schema design)

**Month 6–7:** Cube.dev
- Metric definitions (50+ KPIs)
- Row-level security (org filtering)
- REST API endpoints

**Month 8–9:** Flutter Dashboards
- Custom chart widgets (SfCharts)
- Arabic RTL support
- Drill-down functionality

**Month 10–12:** AI & Anomalies
- Copilot (Claude API)
- Anomaly detection (Isolation Forest)
- Forecast (Prophet)

### Phase 3: Enterprise (Year 2+)

**Q1:** Multi-region ClickHouse, dbt Cloud
**Q2:** Looker/Superset customer-facing
**Q3:** Advanced ML (ML forecasting, attribution modeling)
**Q4:** Analytics SaaS product launch

---

## 13. Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **ClickHouse complexity** | Ops overhead, increased bugs | Managed ClickHouse (Aiven, Instaclustr) in year 2 |
| **Cube.dev learning curve** | Delayed semantic layer | Hire external Cube expert for 2 weeks (onboarding) |
| **Data latency** | Reports show stale data | Hybrid real-time (Redis) + batch (ClickHouse) |
| **GDPR/Data residency** | Legal risk (MENA orgs = local data) | ClickHouse on Render (US region) + S3 in EU (future) |
| **Accidental data leakage** | Tenant A sees Tenant B's data | Quarterly audit of SQL queries, automated RLS tests |
| **Query timeouts** | Users get 504 errors | ClickHouse query_log monitoring + alerts |
| **Cost explosion** | Unexpected bill shocks | ClickHouse INSERT quotas + Cube.dev usage limits |

---

## 14. Conclusion & Next Steps

APEX's analytics transformation requires moving from on-demand OLTP queries to a true OLAP architecture. The proposed three-phase approach balances speed-to-market (MVP in 3 months) with scalability (ClickHouse for 100+ tenants).

**Immediate actions (this week):**
1. Estimate data volumes: # invoices, GL entries, audit logs per tenant
2. Design star schema (fact tables: invoices, GL postings; dimensions: customers, COA)
3. Prototype PostgreSQL materialized views
4. Evaluate Apache Superset (self-hosted) vs. Grafana

**By end of Month 1:**
- MVP analytics module deployed to production
- Internal team using dashboards for month-end close

**By end of Year 1:**
- ClickHouse + Cube.dev in production
- 50 pre-built KPI metrics
- Flutter custom dashboards (revenue, AR, GL)
- Copilot answering natural language questions

---

## References & Further Reading

### Core Technologies

- **ClickHouse Official Docs:** https://clickhouse.com/docs (columnar OLAP architecture)
- **Cube.dev Semantic Layer:** https://cube.dev/docs (multi-tenant metrics, RLS)
- **Apache Superset:** https://superset.apache.org/docs (open-source BI tool)
- **Metabase:** https://metabase.com/docs (embedded analytics, iframe)
- **dbt:** https://docs.getdbt.com/ (data transformation, CI/CD)

### Data Architecture

- **Modern Data Stack 2025:** Fivetran, dbt, Cube.dev (ELT + Semantics + BI)
- **Change Data Capture:** Debezium (https://debezium.io/), Postgres Logical Replication
- **Materialized Views:** PostgreSQL CONCURRENTLY refresh (prevents locks)

### MENA-Specific

- **Arabic RTL in Analytics:** Flutter's Directionality, custom chart widgets
- **Data Residency:** AWS Middle East (Bahrain), Azure UAE, Google Cloud (limited)
- **Compliance:** GDPR Article 32 (data security), Saudi Arabia digital governance

### AI & ML

- **Anthropic Claude API:** https://docs.anthropic.com/ (natural language → SQL)
- **Anomaly Detection:** scikit-learn's IsolationForest (time-series outliers)
- **Forecasting:** Facebook Prophet (seasonal time series)

### Cost Benchmarks

- **ClickHouse:** $50–200/month (self-hosted) vs. Snowflake ($500+)
- **Cube.dev:** $0–200/month (free tier to Pro)
- **Airbyte Cloud:** $300/month (100+ connectors)
- **Analytics Engineer:** $80k–120k/year (salary)

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-30  
**Author:** Analytics Architecture Team  
**Status:** Ready for Phase 1 implementation
