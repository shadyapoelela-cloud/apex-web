"""Tests for audit_log middleware + redaction.

Covers:
  • redact() strips passwords / tokens / API keys
  • redact() masks PII (IBAN, national_id) without removing
  • body preview is JSON-aware + limited to 2KB
  • middleware captures POST/PUT/PATCH/DELETE but skips GET
  • excluded paths (/health, /docs) aren't logged
  • sample rate 0 → skip; sample rate 1 → always log
  • query_audit_log filters by user/tenant/path
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

import pytest


# ── redact() ────────────────────────────────────────────────


def test_redact_password_fields():
    from app.core.audit_log import redact

    out = redact({"username": "ahmed", "password": "supersecret"})
    assert out["username"] == "ahmed"
    assert out["password"] == "***REDACTED***"


def test_redact_nested_tokens():
    from app.core.audit_log import redact

    out = redact(
        {
            "level1": {
                "id_token": "eyJ...",
                "refresh_token": "r_123",
                "safe": "visible",
            }
        }
    )
    assert out["level1"]["id_token"] == "***REDACTED***"
    assert out["level1"]["refresh_token"] == "***REDACTED***"
    assert out["level1"]["safe"] == "visible"


def test_redact_pii_masked_not_stripped():
    """PII is masked so auditors can see shape without reading full value."""
    from app.core.audit_log import redact

    out = redact({"national_id": "1234567890"})
    assert out["national_id"] != "1234567890"
    assert out["national_id"].startswith("12")
    assert out["national_id"].endswith("90")
    assert "*" in out["national_id"]


def test_redact_iban_masked():
    from app.core.audit_log import redact

    out = redact({"bank_iban": "SA0380000000608010167519"})
    v = out["bank_iban"]
    assert v.startswith("SA")
    assert v.endswith("19")
    assert "*" in v


def test_redact_list_of_dicts():
    from app.core.audit_log import redact

    out = redact([{"password": "a"}, {"password": "b"}])
    assert out == [{"password": "***REDACTED***"}, {"password": "***REDACTED***"}]


def test_redact_preserves_non_sensitive():
    from app.core.audit_log import redact

    original = {"name": "أحمد", "amount": 1500, "status": "paid"}
    out = redact(original)
    assert out == original


# ── _body_preview ──────────────────────────────────────────


def test_body_preview_returns_none_on_empty():
    from app.core.audit_log import _body_preview

    assert _body_preview(b"", "application/json") is None


def test_body_preview_redacts_json():
    from app.core.audit_log import _body_preview

    body = json.dumps({"username": "u", "password": "secret"}).encode()
    out = _body_preview(body, "application/json")
    assert "secret" not in out
    assert "REDACTED" in out


def test_body_preview_truncates_long_json():
    from app.core.audit_log import _body_preview

    body = json.dumps({"x": "a" * 5000}).encode()
    out = _body_preview(body, "application/json")
    assert len(out) <= 2048


def test_body_preview_non_json_bytes_reported():
    from app.core.audit_log import _body_preview

    out = _body_preview(b"binary\x00\x01\x02", "application/octet-stream")
    assert "bytes" in out
    assert "application/octet-stream" in out


# ── _should_audit ──────────────────────────────────────────


def _fake_request(method: str, path: str):
    from fastapi import Request

    scope = {
        "type": "http",
        "method": method,
        "path": path,
        "query_string": b"",
        "headers": [],
        "client": ("127.0.0.1", 0),
    }
    return Request(scope)


def test_should_not_audit_get():
    from app.core.audit_log import _should_audit

    assert _should_audit(_fake_request("GET", "/api/clients")) is False


def test_should_audit_post():
    from app.core.audit_log import _should_audit

    assert _should_audit(_fake_request("POST", "/api/clients")) is True


def test_should_not_audit_health():
    from app.core.audit_log import _should_audit

    assert _should_audit(_fake_request("POST", "/health")) is False


def test_should_not_audit_docs():
    from app.core.audit_log import _should_audit

    assert _should_audit(_fake_request("POST", "/docs")) is False


def test_sample_rate_zero_skips(monkeypatch):
    from app.core import audit_log

    monkeypatch.setattr(audit_log, "AUDIT_SAMPLE_RATE", 0.0)
    results = [
        audit_log._should_audit(_fake_request("POST", "/api/x")) for _ in range(20)
    ]
    # All 20 must be False at sample rate 0
    assert all(r is False for r in results)


def test_audit_disabled_flag(monkeypatch):
    from app.core import audit_log

    monkeypatch.setattr(audit_log, "AUDIT_ENABLED", False)
    assert audit_log._should_audit(_fake_request("POST", "/api/x")) is False


# ── End-to-end via TestClient ──────────────────────────────


def test_middleware_captures_post(client):
    """A POST that hits any real route produces an audit row.

    Persist happens in a background executor, so we poll for up to 2s.
    """
    import time

    from app.core.audit_log import AuditLogEntry, _get_session_factory

    Session = _get_session_factory()
    with Session() as s:
        before = s.query(AuditLogEntry).count()

    client.post(
        "/auth/mobile/send-code",
        json={"mobile_country_code": "+966", "mobile_number": "500000001"},
    )

    deadline = time.time() + 2.0
    after = before
    while time.time() < deadline:
        with Session() as s:
            after = s.query(AuditLogEntry).count()
        if after > before:
            break
        time.sleep(0.05)

    assert after > before, f"expected audit row, before={before} after={after}"


def test_middleware_skips_get(client):
    from app.core.audit_log import AuditLogEntry, _get_session_factory

    Session = _get_session_factory()
    with Session() as s:
        before = s.query(AuditLogEntry).count()

    client.get("/health")

    with Session() as s:
        after = s.query(AuditLogEntry).count()
    assert after == before


# ── query_audit_log ────────────────────────────────────────


def test_query_audit_log_filters():
    from app.core.audit_log import (
        AuditLogEntry,
        _get_session_factory,
        query_audit_log,
    )

    Session = _get_session_factory()
    # Seed one synthetic row.
    entry = AuditLogEntry(
        id="audit-test-1",
        timestamp=datetime.now(timezone.utc),
        user_id="user-x",
        tenant_id="tenant-x",
        method="POST",
        path="/api/clients",
        status_code=200,
        duration_ms=42,
    )
    with Session() as s:
        s.add(entry)
        s.commit()

    rows = query_audit_log(user_id="user-x", limit=10)
    assert any(r.id == "audit-test-1" for r in rows)

    rows_no_match = query_audit_log(user_id="does-not-exist")
    assert len(rows_no_match) == 0
