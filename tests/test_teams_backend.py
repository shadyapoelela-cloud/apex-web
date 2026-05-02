"""APEX Platform -- app/core/teams_backend.py unit tests.

Coverage target: ≥95% of 39 statements (G-T1.7b.4, Sprint 10).

HTTP webhook sender (Adaptive Card format). We exercise:

  * `is_configured` — true/false based on `TEAMS_WEBHOOK_URL`.
  * `send_teams_notification` — no-config dev-console fallback,
    no-config prod no-op, requests-missing fallback, color mapping
    (info / success / warning / error / unknown), facts construction
    (with/without fields, capped at 10), actions construction
    (with/without url), success status 200, non-200 status, request
    raising.

Mock strategy: `sys.modules['requests']` stub (G-T1.7b.1 Stripe pattern).
Module-level constants (`TEAMS_WEBHOOK_URL`, `_IS_PRODUCTION`)
monkeypatched directly so we don't need to reload the module.
"""

from __future__ import annotations

import sys
import types

import pytest

from app.core import teams_backend as tb


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def configured(monkeypatch):
    """Set a webhook URL so the function takes the send path."""
    monkeypatch.setattr(tb, "TEAMS_WEBHOOK_URL", "https://teams.test/webhook")
    monkeypatch.setattr(tb, "_IS_PRODUCTION", False)


@pytest.fixture
def requests_stub(monkeypatch):
    """Install a stub `requests` module that records POSTs."""
    stub = types.ModuleType("requests")
    calls = []

    class _Resp:
        def __init__(self, status_code=200, text="1"):
            self.status_code = status_code
            self.text = text

    def _post(url, json=None, timeout=None):
        calls.append({"url": url, "json": json, "timeout": timeout})
        # Trigger 500 if URL contains "/fail"
        if "/fail" in url:
            return _Resp(500, "error body")
        return _Resp(200, "1")

    stub.post = _post
    stub._calls = calls
    monkeypatch.setitem(sys.modules, "requests", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# is_configured
# ══════════════════════════════════════════════════════════════


class TestIsConfigured:
    def test_returns_true_when_url_set(self, monkeypatch):
        monkeypatch.setattr(tb, "TEAMS_WEBHOOK_URL", "https://teams.test/x")
        assert tb.is_configured() is True

    def test_returns_false_when_url_blank(self, monkeypatch):
        monkeypatch.setattr(tb, "TEAMS_WEBHOOK_URL", "")
        assert tb.is_configured() is False


# ══════════════════════════════════════════════════════════════
# Not-configured paths
# ══════════════════════════════════════════════════════════════


class TestNotConfigured:
    def test_dev_console_fallback(self, monkeypatch):
        monkeypatch.setattr(tb, "TEAMS_WEBHOOK_URL", "")
        monkeypatch.setattr(tb, "_IS_PRODUCTION", False)
        out = tb.send_teams_notification("Hello", body="World")
        assert out == {"success": True, "backend": "console"}

    def test_prod_noop(self, monkeypatch):
        monkeypatch.setattr(tb, "TEAMS_WEBHOOK_URL", "")
        monkeypatch.setattr(tb, "_IS_PRODUCTION", True)
        out = tb.send_teams_notification("Hello", body="World")
        assert out == {
            "success": False,
            "error": "teams_not_configured",
            "backend": "noop",
        }


# ══════════════════════════════════════════════════════════════
# requests-missing fallback
# ══════════════════════════════════════════════════════════════


class TestRequestsMissing:
    def test_returns_requests_missing_error(self, configured, monkeypatch):
        # Force the inner `import requests` to fail.
        monkeypatch.setitem(sys.modules, "requests", None)
        out = tb.send_teams_notification("T")
        assert out == {"success": False, "error": "requests_missing"}


# ══════════════════════════════════════════════════════════════
# Send happy + error paths + payload shape
# ══════════════════════════════════════════════════════════════


class TestSendNotification:
    def test_success_basic_payload(self, configured, requests_stub):
        out = tb.send_teams_notification("Title", body="Body")
        assert out == {"success": True, "backend": "teams"}
        # Verify POST shape.
        assert len(requests_stub._calls) == 1
        call = requests_stub._calls[0]
        assert call["url"] == "https://teams.test/webhook"
        assert call["timeout"] == 10
        payload = call["json"]
        assert payload["@type"] == "MessageCard"
        assert payload["title"] == "Title"
        assert payload["summary"] == "Title"
        # Default severity "info" → blue.
        assert payload["themeColor"] == "3b82f6"

    @pytest.mark.parametrize("severity,color", [
        ("info", "3b82f6"),
        ("success", "10b981"),
        ("warning", "f59e0b"),
        ("error", "ef4444"),
        ("unknown_severity", "3b82f6"),  # fallback to info
    ])
    def test_severity_color_mapping(
        self, configured, requests_stub, severity, color
    ):
        tb.send_teams_notification("T", severity=severity)
        assert requests_stub._calls[-1]["json"]["themeColor"] == color

    def test_fields_become_facts_capped_at_10(self, configured, requests_stub):
        # 12 fields → only 10 facts in payload.
        fields = {f"key_{i}": f"val_{i}" for i in range(12)}
        tb.send_teams_notification("T", fields=fields)
        payload = requests_stub._calls[-1]["json"]
        section = payload["sections"][0]
        assert "facts" in section
        assert len(section["facts"]) == 10

    def test_no_fields_no_facts_key(self, configured, requests_stub):
        tb.send_teams_notification("T", body="b")
        section = requests_stub._calls[-1]["json"]["sections"][0]
        # facts key absent when no fields supplied.
        assert "facts" not in section

    def test_url_creates_action_button(self, configured, requests_stub):
        tb.send_teams_notification("T", url="https://app.apex.test/inv/1")
        payload = requests_stub._calls[-1]["json"]
        assert "potentialAction" in payload
        action = payload["potentialAction"][0]
        assert action["@type"] == "OpenUri"
        assert action["targets"][0]["uri"] == "https://app.apex.test/inv/1"

    def test_no_url_no_actions_key(self, configured, requests_stub):
        tb.send_teams_notification("T")
        payload = requests_stub._calls[-1]["json"]
        assert "potentialAction" not in payload

    def test_non_200_status_returns_error(self, configured, requests_stub):
        out = tb.send_teams_notification(
            "T",
        )
        # Default URL is /webhook — success. Now hit /fail variant.
        # Switch URL and re-send.
        out_fail = (
            lambda: None
        )

        # Re-monkey the URL to one that triggers stub's 500.
        # Since module-level constant — patch then call.
        from app.core import teams_backend as _tb
        import unittest.mock as _um
        with _um.patch.object(_tb, "TEAMS_WEBHOOK_URL", "https://teams.test/fail"):
            out2 = _tb.send_teams_notification("T")
        assert out2["success"] is False
        assert out2["error"] == "teams_http_500"
        assert out2["backend"] == "teams"

    def test_request_exception_caught(self, configured, monkeypatch):
        # Stub `requests.post` to raise.
        stub = types.ModuleType("requests")

        def _post(*a, **kw):
            raise RuntimeError("network down")

        stub.post = _post
        monkeypatch.setitem(sys.modules, "requests", stub)
        out = tb.send_teams_notification("T")
        assert out["success"] is False
        assert "network down" in out["error"]
        assert out["backend"] == "teams"
