"""Dashboard performance smoke (DASH-1 Phase 6).

Spec: `/data/batch` for 10 widgets ≤ 500ms p95 on local dev DB.

Run:
    pytest tests/perf/test_dashboard_perf.py -v

Marked @pytest.mark.perf so the regular suite skips it (CI runs perf
on a separate job — see GH Actions). Local dev runs them directly.

Methodology:
  - Seed widgets + 1 user-scope layout to keep DB queries warm.
  - Warm-up call to populate cache.
  - 30 timed calls to /data/batch with the 10 KPI/chart/list widgets.
  - Assert p95 < 500ms.
"""

from __future__ import annotations

import os
import statistics
import time
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.dashboard.seeds import seed_dashboard
from app.phase1.models.platform_models import SessionLocal


pytestmark = pytest.mark.perf


JWT_SECRET = os.environ["JWT_SECRET"]


def _token(*, perms: list[str]) -> str:
    payload = {
        "sub": "perf-user",
        "user_id": "perf-user",
        "username": "perf-user",
        "role": "cfo",
        "permissions": perms,
        "tenant_id": "t-perf",
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def test_batch_p95_under_500ms(client):
    db = SessionLocal()
    try:
        seed_dashboard(db)
    finally:
        db.close()

    cfo_perms = [
        "read:dashboard", "read:reports", "read:invoices", "read:bills",
        "read:customers", "read:approvals", "read:zatca", "read:forecast",
        "write:invoices",
    ]
    tok = _token(perms=cfo_perms)
    headers = {"Authorization": f"Bearer {tok}"}

    body = {
        "entity_id": "e-perf",
        "as_of_date": "2026-05-06",
        "widgets": [
            "kpi.cash_balance",
            "kpi.net_income_mtd",
            "kpi.ar_outstanding",
            "kpi.ap_due_7d",
            "chart.revenue_30d",
            "chart.cash_flow_90d",
            "list.top_customers",
            "list.pending_approvals",
            "list.recent_invoices",
            "widget.compliance_health",
        ],
    }

    # Warm-up — primes the cache + module imports.
    client.post("/api/v1/dashboard/data/batch", json=body, headers=headers)

    timings_ms: list[float] = []
    for _ in range(30):
        t0 = time.perf_counter()
        r = client.post("/api/v1/dashboard/data/batch", json=body, headers=headers)
        elapsed = (time.perf_counter() - t0) * 1000
        assert r.status_code == 200
        timings_ms.append(elapsed)

    timings_sorted = sorted(timings_ms)
    p50 = timings_sorted[len(timings_sorted) // 2]
    p95 = timings_sorted[int(len(timings_sorted) * 0.95)]
    p99 = timings_sorted[int(len(timings_sorted) * 0.99) - 1]
    mean = statistics.mean(timings_ms)

    print(
        f"\n[perf] batch x10 widgets — n={len(timings_ms)}  "
        f"mean={mean:.1f}ms  p50={p50:.1f}ms  p95={p95:.1f}ms  p99={p99:.1f}ms"
    )

    assert p95 < 500, f"p95={p95:.1f}ms exceeds 500ms budget"
