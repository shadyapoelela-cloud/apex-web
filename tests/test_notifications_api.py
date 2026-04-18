"""Tests for the notifications list API.

Verifies that GET /api/v1/notifications returns the bell history
derived from activity_log, ordered newest-first, with severity + title
mapped correctly.
"""

from __future__ import annotations

import uuid


def _tenant_headers(tid: str) -> dict:
    return {"X-Tenant-Id": tid}


def test_list_returns_recent_activity(client):
    """Seed 3 activity rows then list — newest first, count=3."""
    from app.core.activity_log import log_activity
    tid = f"t-{uuid.uuid4().hex[:8]}"
    # Use a unique user so this test doesn't collide with others.
    uid = f"u-{uuid.uuid4().hex[:8]}"
    for i, (action, summary) in enumerate([
        ("created", "تم إنشاء العميل"),
        ("commented", "تعليق اختباري"),
        ("status_changed", "pending → confirmed"),
    ]):
        log_activity(
            entity_type="client",
            entity_id="c-1",
            action=action,
            summary=summary,
            user_id=uid,
            user_name="Tester",
        )

    resp = client.get(f"/api/v1/notifications?user_id={uid}",
                      headers=_tenant_headers(tid))
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data) == 3
    # Newest first
    assert data[0]["action"] == "status_changed"
    assert data[-1]["action"] == "created"


def test_severity_mapping_for_known_actions(client):
    from app.core.activity_log import log_activity
    uid = f"u-sev-{uuid.uuid4().hex[:8]}"
    tid = f"t-{uuid.uuid4().hex[:8]}"
    cases = [
        ("proactive.dead_zatca_submissions", "ZATCA dead", "error"),
        ("paid", "تم الدفع", "success"),
        ("proactive.overdue_receivables", "فاتورة متأخرة", "error"),
        ("created", "إنشاء جديد", "info"),
    ]
    for action, summary, _exp in cases:
        log_activity(
            entity_type="invoice",
            entity_id="i-x",
            action=action,
            summary=summary,
            user_id=uid,
        )
    resp = client.get(f"/api/v1/notifications?user_id={uid}",
                      headers=_tenant_headers(tid))
    assert resp.status_code == 200
    out = {r["action"]: r["severity"] for r in resp.json()["data"]}
    for action, _s, expected in cases:
        assert out.get(action) == expected, f"{action} → expected {expected}, got {out.get(action)}"


def test_title_mapping_translates_action_to_arabic(client):
    from app.core.activity_log import log_activity
    uid = f"u-title-{uuid.uuid4().hex[:8]}"
    tid = f"t-{uuid.uuid4().hex[:8]}"
    log_activity(
        entity_type="client",
        entity_id="c-a",
        action="commented",
        summary="body",
        user_id=uid,
    )
    log_activity(
        entity_type="client",
        entity_id="c-a",
        action="status_changed",
        summary="body",
        user_id=uid,
    )
    rows = client.get(f"/api/v1/notifications?user_id={uid}",
                      headers=_tenant_headers(tid)).json()["data"]
    by_action = {r["action"]: r["title"] for r in rows}
    assert by_action["commented"] == "تعليق جديد"
    assert by_action["status_changed"] == "تغيّر الحالة"


def test_limit_is_honoured(client):
    """Insert 10, request limit=3, get 3."""
    from app.core.activity_log import log_activity
    uid = f"u-lim-{uuid.uuid4().hex[:8]}"
    tid = f"t-{uuid.uuid4().hex[:8]}"
    for i in range(10):
        log_activity(
            entity_type="invoice",
            entity_id=f"i-{i}",
            action="created",
            summary=f"row {i}",
            user_id=uid,
        )
    r = client.get(f"/api/v1/notifications?user_id={uid}&limit=3",
                   headers=_tenant_headers(tid))
    assert r.status_code == 200
    assert r.json()["limit"] == 3
    assert r.json()["count"] == 3
    assert len(r.json()["data"]) == 3


def test_since_filter(client):
    """Only rows strictly newer than `since` come back."""
    import time
    from datetime import datetime, timezone
    from urllib.parse import quote
    from app.core.activity_log import log_activity

    uid = f"u-since-{uuid.uuid4().hex[:8]}"
    tid = f"t-{uuid.uuid4().hex[:8]}"
    log_activity(
        entity_type="client",
        entity_id="c-1",
        action="created",
        summary="first",
        user_id=uid,
    )
    time.sleep(0.05)
    # Use Z suffix so the `+` in `+00:00` doesn't get URL-decoded to
    # a space by the query-string parser.
    cutoff_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    cutoff = quote(cutoff_iso, safe="")
    time.sleep(0.05)
    log_activity(
        entity_type="client",
        entity_id="c-2",
        action="created",
        summary="second",
        user_id=uid,
    )

    r = client.get(
        f"/api/v1/notifications?user_id={uid}&since={cutoff}",
        headers=_tenant_headers(tid),
    )
    assert r.status_code == 200
    data = r.json()["data"]
    assert len(data) == 1
    assert data[0]["body"] == "second"


def test_bad_since_returns_422(client):
    r = client.get(
        "/api/v1/notifications?since=not-a-date",
        headers=_tenant_headers("t-x"),
    )
    assert r.status_code == 422


def test_mark_read_404_on_unknown(client):
    r = client.post(
        "/api/v1/notifications/does-not-exist/read",
        headers=_tenant_headers("t-x"),
    )
    assert r.status_code == 404


def test_mark_read_acknowledges_existing(client):
    from app.core.activity_log import log_activity
    tid = f"t-{uuid.uuid4().hex[:8]}"
    aid = log_activity(
        entity_type="client",
        entity_id="c-ack",
        action="created",
        summary="ack me",
    )
    r = client.post(
        f"/api/v1/notifications/{aid}/read",
        headers=_tenant_headers(tid),
    )
    assert r.status_code == 200
    assert r.json()["data"]["acknowledged"] is True


def test_mark_all_read_returns_count(client):
    from app.core.activity_log import log_activity
    tid = f"t-{uuid.uuid4().hex[:8]}"
    uid = f"u-all-{uuid.uuid4().hex[:8]}"
    for i in range(3):
        log_activity(
            entity_type="invoice",
            entity_id=f"i-{i}",
            action="created",
            summary=f"row {i}",
            user_id=uid,
        )
    r = client.post(
        f"/api/v1/notifications/read-all?user_id={uid}",
        headers=_tenant_headers(tid),
    )
    assert r.status_code == 200
    assert r.json()["data"]["acknowledged"] is True
    assert r.json()["data"]["count"] >= 3
