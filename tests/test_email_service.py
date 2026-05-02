"""APEX Platform -- app/core/email_service.py unit tests.

Coverage target: ≥95% of 90 statements (G-T1.7b.5, Sprint 10 final).

Multi-backend email sender: SMTP, SendGrid, Console (dev). We exercise:

  * `_send_via_console` — dev fallback, always success.
  * `_send_via_smtp` — not-configured, success path (with starttls for
    non-25 ports), success path with port=25 (no starttls), SMTPException,
    generic exception.
  * `_send_via_sendgrid` — not-configured, requests-missing, success
    (200/201/202), HTTP error, RequestException, content with body_text,
    content without body_text.
  * `send_email` — backend dispatch, unknown-backend fallback to console,
    exception passthrough.
  * `send_verification_email`, `send_password_reset_email`,
    `send_notification_email` — Arabic body construction.

Mock strategy: monkeypatch `smtplib.SMTP` to a context-manager MagicMock;
`sys.modules['requests']` stub for SendGrid (G-T1.7b.4 pattern). Module
constants monkeypatched directly.
"""

from __future__ import annotations

import sys
import types
from unittest.mock import MagicMock

import pytest

from app.core import email_service as es


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def smtp_stub(monkeypatch):
    """Replace smtplib.SMTP with a context-manager-friendly MagicMock."""
    server = MagicMock()
    server.ehlo = MagicMock()
    server.starttls = MagicMock()
    server.login = MagicMock()
    server.sendmail = MagicMock()

    # SMTP() is used as a context manager via `with smtplib.SMTP(...)`.
    SMTP_cls = MagicMock()
    instance = MagicMock()
    instance.__enter__ = MagicMock(return_value=server)
    instance.__exit__ = MagicMock(return_value=False)
    SMTP_cls.return_value = instance

    monkeypatch.setattr(es.smtplib, "SMTP", SMTP_cls)
    return types.SimpleNamespace(
        cls=SMTP_cls, server=server, instance=instance,
    )


@pytest.fixture
def requests_stub(monkeypatch):
    stub = types.ModuleType("requests")

    class RequestException(Exception):
        pass

    stub.RequestException = RequestException

    class _Resp:
        def __init__(self, status_code=202, text=""):
            self.status_code = status_code
            self.text = text

    stub._Resp = _Resp

    def _post(url, json=None, headers=None, timeout=None):
        # Allow tests to override behavior via `_next`.
        if hasattr(stub, "_next"):
            r = stub._next
            if isinstance(r, Exception):
                raise r
            return r
        return _Resp(202)

    stub.post = _post
    monkeypatch.setitem(sys.modules, "requests", stub)
    return stub


# ══════════════════════════════════════════════════════════════
# _send_via_console
# ══════════════════════════════════════════════════════════════


class TestConsoleBackend:
    def test_returns_success(self):
        out = es._send_via_console("a@b.com", "subj", "<p>html</p>", "text")
        assert out == {"success": True, "backend": "console"}

    def test_works_without_text_body(self):
        out = es._send_via_console("a@b.com", "subj", "<p>html</p>")
        assert out["success"] is True


# ══════════════════════════════════════════════════════════════
# _send_via_smtp
# ══════════════════════════════════════════════════════════════


class TestSmtpBackend:
    def test_not_configured(self, monkeypatch):
        monkeypatch.setattr(es, "SMTP_USER", "")
        monkeypatch.setattr(es, "SMTP_PASSWORD", "")
        out = es._send_via_smtp("a@b.com", "s", "<p>x</p>")
        assert out == {"success": False, "error": "SMTP not configured"}

    def test_success_with_starttls_on_587(self, monkeypatch, smtp_stub):
        monkeypatch.setattr(es, "SMTP_USER", "u@x.com")
        monkeypatch.setattr(es, "SMTP_PASSWORD", "p")
        monkeypatch.setattr(es, "SMTP_PORT", 587)
        out = es._send_via_smtp("a@b.com", "s", "<p>x</p>", body_text="text")
        assert out == {"success": True, "backend": "smtp"}
        smtp_stub.server.starttls.assert_called_once()
        smtp_stub.server.login.assert_called_once_with("u@x.com", "p")
        smtp_stub.server.sendmail.assert_called_once()

    def test_success_skips_starttls_on_port_25(self, monkeypatch, smtp_stub):
        monkeypatch.setattr(es, "SMTP_USER", "u@x.com")
        monkeypatch.setattr(es, "SMTP_PASSWORD", "p")
        monkeypatch.setattr(es, "SMTP_PORT", 25)
        out = es._send_via_smtp("a@b.com", "s", "<p>x</p>")
        assert out["success"] is True
        smtp_stub.server.starttls.assert_not_called()

    def test_smtp_exception_returns_error(self, monkeypatch, smtp_stub):
        import smtplib
        monkeypatch.setattr(es, "SMTP_USER", "u@x.com")
        monkeypatch.setattr(es, "SMTP_PASSWORD", "p")
        smtp_stub.server.sendmail.side_effect = smtplib.SMTPException("bad recipient")
        out = es._send_via_smtp("a@b.com", "s", "<p>x</p>")
        assert out["success"] is False
        assert "bad recipient" in out["error"]

    def test_generic_exception_returns_generic_error(self, monkeypatch, smtp_stub):
        monkeypatch.setattr(es, "SMTP_USER", "u@x.com")
        monkeypatch.setattr(es, "SMTP_PASSWORD", "p")
        smtp_stub.server.sendmail.side_effect = RuntimeError("kaboom")
        out = es._send_via_smtp("a@b.com", "s", "<p>x</p>")
        assert out == {"success": False, "error": "SMTP send failed"}


# ══════════════════════════════════════════════════════════════
# _send_via_sendgrid
# ══════════════════════════════════════════════════════════════


class TestSendgridBackend:
    def test_not_configured(self, monkeypatch):
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "")
        monkeypatch.setattr(es, "SENDGRID_FROM", "")
        out = es._send_via_sendgrid("a@b.com", "s", "<p>x</p>")
        assert out == {"success": False, "error": "SendGrid not configured"}

    def test_requests_missing(self, monkeypatch):
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "sk-1")
        monkeypatch.setattr(es, "SENDGRID_FROM", "from@example.com")
        monkeypatch.setitem(sys.modules, "requests", None)
        out = es._send_via_sendgrid("a@b.com", "s", "<p>x</p>")
        assert out == {"success": False, "error": "requests library not available"}

    @pytest.mark.parametrize("status", [200, 201, 202])
    def test_success_status_codes(self, monkeypatch, requests_stub, status):
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "sk-1")
        monkeypatch.setattr(es, "SENDGRID_FROM", "from@example.com")
        requests_stub._next = requests_stub._Resp(status)
        out = es._send_via_sendgrid("a@b.com", "s", "<p>x</p>")
        assert out == {"success": True, "backend": "sendgrid"}

    def test_http_error_returns_error(self, monkeypatch, requests_stub):
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "sk-1")
        monkeypatch.setattr(es, "SENDGRID_FROM", "from@example.com")
        requests_stub._next = requests_stub._Resp(400, text="bad request")
        out = es._send_via_sendgrid("a@b.com", "s", "<p>x</p>")
        assert "SendGrid API 400" in out["error"]

    def test_request_exception(self, monkeypatch, requests_stub):
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "sk-1")
        monkeypatch.setattr(es, "SENDGRID_FROM", "from@example.com")
        requests_stub._next = requests_stub.RequestException("network down")
        out = es._send_via_sendgrid("a@b.com", "s", "<p>x</p>")
        assert out["success"] is False
        assert "network down" in out["error"]

    def test_body_text_added_to_content_array(self, monkeypatch, requests_stub):
        """When body_text is supplied, both text/plain and text/html
        appear in content (text/plain inserted at position 0)."""
        monkeypatch.setattr(es, "SENDGRID_API_KEY", "sk-1")
        monkeypatch.setattr(es, "SENDGRID_FROM", "from@example.com")
        # Capture the post payload.
        captured = {}

        def fake_post(url, json=None, headers=None, timeout=None):
            captured["json"] = json
            return requests_stub._Resp(202)

        monkeypatch.setattr(requests_stub, "post", fake_post)
        es._send_via_sendgrid("a@b.com", "s", "<p>html</p>", body_text="plain text")
        content = captured["json"]["content"]
        assert len(content) == 2
        assert content[0]["type"] == "text/plain"
        assert content[1]["type"] == "text/html"


# ══════════════════════════════════════════════════════════════
# send_email — public API
# ══════════════════════════════════════════════════════════════


class TestSendEmail:
    def test_dispatches_to_console_by_default(self, monkeypatch):
        monkeypatch.setattr(es, "EMAIL_BACKEND", "console")
        out = es.send_email("a@b.com", "subj", "<p>x</p>")
        assert out["backend"] == "console"

    def test_unknown_backend_falls_back_to_console(self, monkeypatch):
        monkeypatch.setattr(es, "EMAIL_BACKEND", "no-such-backend")
        out = es.send_email("a@b.com", "s", "<p>x</p>")
        assert out["backend"] == "console"

    def test_backend_exception_caught(self, monkeypatch):
        monkeypatch.setattr(es, "EMAIL_BACKEND", "console")
        monkeypatch.setitem(
            es._BACKENDS, "console",
            lambda *a, **kw: (_ for _ in ()).throw(RuntimeError("boom")),
        )
        out = es.send_email("a@b.com", "s", "<p>x</p>")
        assert out == {"success": False, "error": "Email delivery failed"}


# ══════════════════════════════════════════════════════════════
# Helper email constructors
# ══════════════════════════════════════════════════════════════


class TestHelperEmails:
    def test_send_verification_email_includes_code(self, monkeypatch):
        captured = {}

        def fake_send(to, subject, body_html, body_text=None):
            captured.update(
                to=to, subject=subject, body_html=body_html, body_text=body_text,
            )
            return {"success": True}

        monkeypatch.setattr(es, "send_email", fake_send)
        es.send_verification_email("a@b.com", "123456")
        assert captured["to"] == "a@b.com"
        assert "123456" in captured["body_html"]
        assert "123456" in captured["body_text"]
        assert "تأكيد" in captured["subject"]

    def test_send_password_reset_email_includes_token_url(self, monkeypatch):
        captured = {}

        def fake_send(to, subject, body_html, body_text=None):
            captured.update(body_html=body_html, body_text=body_text)
            return {"success": True}

        monkeypatch.setattr(es, "send_email", fake_send)
        monkeypatch.setattr(es, "PLATFORM_URL", "https://app.test")
        es.send_password_reset_email("a@b.com", "tok-xyz")
        assert "tok-xyz" in captured["body_html"]
        assert "https://app.test/reset-password?token=tok-xyz" in captured["body_html"]

    def test_send_notification_email_uses_title_and_body(self, monkeypatch):
        captured = {}

        def fake_send(to, subject, body_html, body_text=None):
            captured.update(subject=subject, body_html=body_html, body_text=body_text)
            return {"success": True}

        monkeypatch.setattr(es, "send_email", fake_send)
        es.send_notification_email("a@b.com", "MyTitle", "MyBody")
        assert "MyTitle" in captured["subject"]
        assert "MyTitle" in captured["body_html"]
        assert "MyBody" in captured["body_html"]
        assert captured["body_text"] == "MyTitle\n\nMyBody"
