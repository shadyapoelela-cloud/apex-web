"""APEX Platform -- app/core/slack_backend.py unit tests.

Coverage target: ≥95% of 47 statements (G-T1.7b.4, Sprint 10).

HTTP webhook sender (Block Kit format). Mirrors teams_backend.
We exercise:

  * `is_configured` — true/false based on `SLACK_WEBHOOK_URL`.
  * `send_slack_notification` — no-config dev-console fallback,
    no-config prod no-op, requests-missing fallback, color mapping
    (info / success / warning / error / unknown), Block Kit construction
    (with/without body, fields capped at 10, url action button),
    channel override (param vs default), success vs non-200, exception.

Mock strategy: `sys.modules['requests']` stub. Module constants
monkeypatched directly.
"""

from __future__ import annotations

import sys
import types

import pytest

from app.core import slack_backend as sb


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def configured(monkeypatch):
    monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "https://hooks.slack.test/x")
    monkeypatch.setattr(sb, "SLACK_DEFAULT_CHANNEL", "")
    monkeypatch.setattr(sb, "_IS_PRODUCTION", False)


@pytest.fixture
def requests_stub(monkeypatch):
    """Install a stub `requests` module that records POSTs and
    returns 200/'ok' by default."""
    stub = types.ModuleType("requests")
    calls = []

    class _Resp:
        def __init__(self, status_code=200, text="ok"):
            self.status_code = status_code
            self.text = text

    def _post(url, json=None, timeout=None):
        calls.append({"url": url, "json": json, "timeout": timeout})
        if "/fail" in url:
            return _Resp(500, "boom")
        if "/wrongtext" in url:
            # 200 but body != "ok" — Slack contract says BOTH must match.
            return _Resp(200, "not-ok")
        return _Resp(200, "ok")

    stub.post = _post
    stub._calls = calls
    monkeypatch.setitem(sys.modules, "requests", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# is_configured
# ══════════════════════════════════════════════════════════════


class TestIsConfigured:
    def test_returns_true_when_url_set(self, monkeypatch):
        monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "https://hooks.slack.test/x")
        assert sb.is_configured() is True

    def test_returns_false_when_url_blank(self, monkeypatch):
        monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "")
        assert sb.is_configured() is False


# ══════════════════════════════════════════════════════════════
# Not-configured paths
# ══════════════════════════════════════════════════════════════


class TestNotConfigured:
    def test_dev_console_fallback(self, monkeypatch):
        monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "")
        monkeypatch.setattr(sb, "_IS_PRODUCTION", False)
        out = sb.send_slack_notification("Hello", body="World")
        assert out == {"success": True, "backend": "console"}

    def test_prod_noop(self, monkeypatch):
        monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "")
        monkeypatch.setattr(sb, "_IS_PRODUCTION", True)
        out = sb.send_slack_notification("Hello")
        assert out == {
            "success": False,
            "error": "slack_not_configured",
            "backend": "noop",
        }


# ══════════════════════════════════════════════════════════════
# requests-missing fallback
# ══════════════════════════════════════════════════════════════


class TestRequestsMissing:
    def test_returns_requests_missing_error(self, configured, monkeypatch):
        monkeypatch.setitem(sys.modules, "requests", None)
        out = sb.send_slack_notification("T")
        assert out == {"success": False, "error": "requests_missing"}


# ══════════════════════════════════════════════════════════════
# Send happy + error paths + payload shape
# ══════════════════════════════════════════════════════════════


class TestSendNotification:
    def test_success_basic_payload(self, configured, requests_stub):
        out = sb.send_slack_notification("Title", body="Body")
        assert out == {"success": True, "backend": "slack"}
        call = requests_stub._calls[0]
        assert call["url"] == "https://hooks.slack.test/x"
        assert call["timeout"] == 10
        payload = call["json"]
        assert payload["text"] == "Title"  # plain-text fallback
        assert "attachments" in payload
        assert payload["attachments"][0]["color"] == "#3b82f6"  # info default

    @pytest.mark.parametrize("severity,color", [
        ("info", "#3b82f6"),
        ("success", "#10b981"),
        ("warning", "#f59e0b"),
        ("error", "#ef4444"),
        ("unknown", "#3b82f6"),
    ])
    def test_severity_color_mapping(
        self, configured, requests_stub, severity, color
    ):
        sb.send_slack_notification("T", severity=severity)
        assert requests_stub._calls[-1]["json"]["attachments"][0]["color"] == color

    def test_blocks_have_title_and_optional_body(self, configured, requests_stub):
        # With body → 2 sections (title + body).
        sb.send_slack_notification("Title", body="Body text")
        blocks = requests_stub._calls[-1]["json"]["attachments"][0]["blocks"]
        assert len(blocks) >= 2
        # Without body → just the title block.
        sb.send_slack_notification("T")
        blocks2 = requests_stub._calls[-1]["json"]["attachments"][0]["blocks"]
        assert len(blocks2) == 1

    def test_fields_become_section_chunks_capped_at_10(
        self, configured, requests_stub
    ):
        fields = {f"k{i}": f"v{i}" for i in range(15)}
        sb.send_slack_notification("T", fields=fields)
        blocks = requests_stub._calls[-1]["json"]["attachments"][0]["blocks"]
        # Find the fields section.
        fields_section = next(b for b in blocks if "fields" in b)
        assert len(fields_section["fields"]) == 10  # capped

    def test_url_creates_action_block(self, configured, requests_stub):
        sb.send_slack_notification("T", url="https://app.apex.test/x")
        blocks = requests_stub._calls[-1]["json"]["attachments"][0]["blocks"]
        actions_block = next(b for b in blocks if b["type"] == "actions")
        button = actions_block["elements"][0]
        assert button["url"] == "https://app.apex.test/x"

    def test_explicit_channel_overrides_default(self, configured, requests_stub):
        sb.send_slack_notification("T", channel="#alerts")
        assert requests_stub._calls[-1]["json"]["channel"] == "#alerts"

    def test_default_channel_used_when_no_explicit(
        self, configured, requests_stub, monkeypatch
    ):
        monkeypatch.setattr(sb, "SLACK_DEFAULT_CHANNEL", "#general")
        sb.send_slack_notification("T")
        assert requests_stub._calls[-1]["json"]["channel"] == "#general"

    def test_no_channel_at_all_no_channel_key(self, configured, requests_stub):
        sb.send_slack_notification("T")
        assert "channel" not in requests_stub._calls[-1]["json"]

    def test_non_200_returns_http_error(self, configured, requests_stub, monkeypatch):
        monkeypatch.setattr(sb, "SLACK_WEBHOOK_URL", "https://hooks.slack.test/fail")
        out = sb.send_slack_notification("T")
        assert out["success"] is False
        assert out["error"] == "slack_http_500"
        assert out["backend"] == "slack"

    def test_200_but_text_not_ok_returns_error(
        self, configured, requests_stub, monkeypatch
    ):
        """Slack contract: status_code == 200 AND resp.text == "ok".
        If text != "ok", treat as failure."""
        monkeypatch.setattr(
            sb, "SLACK_WEBHOOK_URL", "https://hooks.slack.test/wrongtext"
        )
        out = sb.send_slack_notification("T")
        assert out["success"] is False
        assert out["error"] == "slack_http_200"

    def test_request_exception_caught(self, configured, monkeypatch):
        stub = types.ModuleType("requests")

        def _post(*a, **kw):
            raise RuntimeError("network down")

        stub.post = _post
        monkeypatch.setitem(sys.modules, "requests", stub)
        out = sb.send_slack_notification("T")
        assert out["success"] is False
        assert "network down" in out["error"]
        assert out["backend"] == "slack"
