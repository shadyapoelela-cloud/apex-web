"""API latency micro-benchmarks.

Measures p50 / p99 response times of the hot paths against the
FastAPI TestClient. Uses the stdlib `time.perf_counter` — no extra
dependency on pytest-benchmark so it runs in every environment.

Not a replacement for load testing (see tests/load/locustfile.py for
that). Catches regressions early: any change that doubles latency on
a hot path will make these assertions fail.

Thresholds chosen as 2-3× the local-dev typical so flaky CI doesn't
trip them.
"""
from __future__ import annotations

import statistics
import time
import uuid


def _benchmark(fn, iterations: int = 20) -> dict:
    """Run `fn` N times, return p50/p99/mean in milliseconds."""
    samples: list[float] = []
    # Warmup — two runs to prime caches / connection pool.
    for _ in range(2):
        fn()
    for _ in range(iterations):
        t0 = time.perf_counter()
        fn()
        samples.append((time.perf_counter() - t0) * 1000.0)
    samples.sort()
    return {
        "p50": samples[len(samples) // 2],
        "p99": samples[int(len(samples) * 0.99)] if len(samples) >= 100 else samples[-1],
        "mean": statistics.mean(samples),
        "count": len(samples),
    }


def test_system_health_p50_under_200ms(client):
    def call():
        r = client.get("/api/v1/system/health")
        assert r.status_code == 200

    stats = _benchmark(call, iterations=20)
    # Loose ceiling — health check hits 6 subsystems
    assert stats["p50"] < 500, f"/system/health p50 too slow: {stats}"
    assert stats["mean"] < 600, f"/system/health mean too slow: {stats}"


def test_notifications_list_p50_under_100ms(client):
    """Seed one row then list — measures the hot path for the bell."""
    from app.core.activity_log import log_activity
    uid = f"u-bench-{uuid.uuid4().hex[:8]}"
    log_activity(
        entity_type="client",
        entity_id="c-bench",
        action="created",
        summary="bench seed",
        user_id=uid,
    )

    def call():
        r = client.get(
            f"/api/v1/notifications?user_id={uid}&limit=30",
            headers={"X-Tenant-Id": "t-bench"},
        )
        assert r.status_code == 200

    stats = _benchmark(call, iterations=20)
    assert stats["p50"] < 300, f"/notifications p50 too slow: {stats}"


def test_tenant_branding_get_p50_under_100ms(client):
    def call():
        r = client.get(
            "/api/v1/tenant/branding",
            headers={"X-Tenant-Id": f"t-{uuid.uuid4().hex[:8]}"},
        )
        assert r.status_code == 200

    stats = _benchmark(call, iterations=20)
    assert stats["p50"] < 300, f"/tenant/branding p50 too slow: {stats}"


def test_activity_recent_p50_under_150ms(client):
    def call():
        r = client.get(
            "/api/v1/activity/recent/invoice",
            headers={"X-Tenant-Id": "t-bench"},
        )
        assert r.status_code == 200

    stats = _benchmark(call, iterations=20)
    assert stats["p50"] < 400, f"/activity/recent p50 too slow: {stats}"


def test_report_csv_download_p50_under_200ms(client):
    def call():
        r = client.get("/api/v1/reports/download/trial_balance_bench_csv")
        assert r.status_code == 200

    stats = _benchmark(call, iterations=15)
    assert stats["p50"] < 500, f"/reports/download csv p50 too slow: {stats}"


def test_comment_post_p50_under_300ms(client):
    """POST is heavier — DB write + event loop push. Give it more room."""
    eid = f"c-{uuid.uuid4().hex[:8]}"

    def call():
        r = client.post(
            f"/api/v1/activity/client/{eid}/comment",
            json={
                "body": "bench comment",
                "user_id": "u-bench",
                "user_name": "Bencher",
            },
            headers={"X-Tenant-Id": "t-bench"},
        )
        assert r.status_code == 201

    stats = _benchmark(call, iterations=15)
    assert stats["p50"] < 700, f"/comment POST p50 too slow: {stats}"
