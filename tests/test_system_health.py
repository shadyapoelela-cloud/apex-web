"""Tests for the /api/v1/system/health endpoint."""

from __future__ import annotations


def test_health_returns_all_subsystems(client):
    r = client.get("/api/v1/system/health")
    assert r.status_code == 200
    data = r.json()["data"]
    assert "overall" in data
    assert data["overall"] in ("ok", "degraded")
    checks = data["checks"]
    for key in (
        "database",
        "dialect",
        "activity_log",
        "ai_scheduler",
        "websocket_hub",
        "zatca_retry_queue",
    ):
        assert key in checks, f"{key} missing from health checks"
        assert "status" in checks[key]


def test_database_check_is_ok_in_test_env(client):
    r = client.get("/api/v1/system/health")
    data = r.json()["data"]
    assert data["checks"]["database"]["status"] == "ok"


def test_dialect_check_reports_sqlite_in_tests(client):
    r = client.get("/api/v1/system/health")
    dialect = r.json()["data"]["checks"]["dialect"]
    assert dialect["status"] == "ok"
    # Tests use SQLite in-memory by default
    assert dialect["dialect"] in ("sqlite", "postgresql", "mysql")
    assert dialect["rls_applicable"] == (dialect["dialect"] == "postgresql")


def test_scheduler_check_reports_disabled_by_default(client, monkeypatch):
    monkeypatch.delenv("PROACTIVE_AI_ENABLED", raising=False)
    r = client.get("/api/v1/system/health")
    sched = r.json()["data"]["checks"]["ai_scheduler"]
    assert sched["status"] == "ok"
    assert sched["enabled"] is False


def test_zatca_retry_queue_counts_are_non_negative(client):
    r = client.get("/api/v1/system/health")
    q = r.json()["data"]["checks"]["zatca_retry_queue"]
    assert q["status"] == "ok"
    assert q["total"] >= 0
    assert q["pending_retry"] >= 0
    assert q["dead"] >= 0


def test_activity_log_count_is_integer(client):
    r = client.get("/api/v1/system/health")
    act = r.json()["data"]["checks"]["activity_log"]
    assert act["status"] == "ok"
    assert isinstance(act["count_last_24h"], int)
    assert act["count_last_24h"] >= 0


def test_timestamp_present_in_response(client):
    r = client.get("/api/v1/system/health")
    ts = r.json()["data"]["timestamp"]
    assert isinstance(ts, str)
    assert "T" in ts  # ISO-8601


def test_overall_is_ok_when_every_check_ok(client):
    r = client.get("/api/v1/system/health")
    data = r.json()["data"]
    if all(c.get("status") == "ok" for c in data["checks"].values()):
        assert data["overall"] == "ok"
