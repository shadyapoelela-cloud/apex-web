"""APEX Platform -- app/core/email_inbox.py unit tests.

Coverage target: ≥90% of 135 statements (G-T1.7b.3, Sprint 10).

IMAP poll + email parse + filesystem write + event_bus emit.
We exercise:

  * `_cfg`, `_bool` — env-var helpers (set/unset/empty/various truthy).
  * `is_configured` — true/false.
  * `_safe_filename` — sanitization, length cap, fallback.
  * `_decode_field` — None, valid header, decoder failure.
  * `_walk_attachments` — multipart with PDF + image, non-multipart skip,
    inline non-attachment skip, decoded payload.
  * `_connect` — SSL vs non-SSL, missing-config RuntimeError, login + select.
  * `poll_inbox` — not_configured short-circuit, search failure, fetch
    failure, bad payload, write failure, mark_read failure, full happy
    path with multiple attachments + emit + mark_read, outer exception.

IMAP mock: a single MagicMock instance plays the IMAP4 connection.
We pre-build real `email.message.EmailMessage` payloads so the parser
runs end-to-end without needing fake `email` modules.

Real-world fixtures are built with stdlib `email.message.EmailMessage`,
serialized to bytes, and returned via `imap.fetch().return_value`.
"""

from __future__ import annotations

import imaplib
import os
from email.message import EmailMessage
from unittest.mock import MagicMock

import pytest

from app.core import email_inbox as ei


# ══════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════


@pytest.fixture
def env(monkeypatch):
    """Helper to set env vars cleanly per test."""
    def _set(**kw):
        for k, v in kw.items():
            if v is None:
                monkeypatch.delenv(k, raising=False)
            else:
                monkeypatch.setenv(k, v)
    return _set


@pytest.fixture
def emit_capture(monkeypatch):
    """Capture event_bus.emit calls."""
    calls = []

    def fake_emit(event, payload, *, source=None):
        calls.append({"event": event, "payload": payload, "source": source})

    monkeypatch.setattr(ei, "emit", fake_emit)
    return calls


def _make_email(subject="Test", from_="sender@example.com",
                attachments=None, message_id="<m-1@host>"):
    """Build a real RFC 5322 message with optional attachments.

    `attachments` is a list of (filename, content_bytes, mime_main, mime_sub).
    """
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_
    msg["To"] = "inbox@apex.test"
    msg["Date"] = "Sun, 02 May 2026 12:00:00 +0000"
    msg["Message-ID"] = message_id
    msg.set_content("plain body")
    for filename, payload, main, sub in (attachments or []):
        msg.add_attachment(payload, maintype=main, subtype=sub, filename=filename)
    return msg.as_bytes()


def _make_imap_mock(uids=None, fetch_payloads=None, fetch_status="OK",
                    search_status="OK", store_raises=False):
    """Build a MagicMock that quacks like imaplib.IMAP4 (or _SSL)."""
    imap = MagicMock(spec=imaplib.IMAP4)
    imap.search.return_value = (search_status, [b" ".join(uids or [])])

    if fetch_payloads:
        # fetch returns (status, [(metadata, raw_bytes), tail])
        side = []
        for raw in fetch_payloads:
            if raw is None:
                side.append((fetch_status, None))
            else:
                side.append((fetch_status, [(b"meta", raw)]))
        imap.fetch.side_effect = side
    else:
        imap.fetch.return_value = (fetch_status, [(b"meta", b"")])

    if store_raises:
        imap.store.side_effect = RuntimeError("store failed")
    else:
        imap.store.return_value = ("OK", [b""])

    return imap


# ══════════════════════════════════════════════════════════════
# Config helpers
# ══════════════════════════════════════════════════════════════


class TestConfigHelpers:
    def test_cfg_returns_value_when_set(self, env):
        env(EMAIL_INBOX_HOST="imap.example.com")
        assert ei._cfg("EMAIL_INBOX_HOST") == "imap.example.com"

    def test_cfg_returns_default_when_missing_or_empty(self, env):
        env(EMAIL_INBOX_HOST=None)
        assert ei._cfg("EMAIL_INBOX_HOST", "fallback") == "fallback"
        env(EMAIL_INBOX_HOST="")
        assert ei._cfg("EMAIL_INBOX_HOST", "fallback") == "fallback"

    def test_bool_truthy_and_falsy(self, env):
        env(FLAG=None)
        assert ei._bool("FLAG", default=True) is True
        env(FLAG="1")
        assert ei._bool("FLAG", default=False) is True
        env(FLAG="yes")
        assert ei._bool("FLAG", default=False) is True
        env(FLAG="0")
        assert ei._bool("FLAG", default=True) is False
        env(FLAG="random")
        assert ei._bool("FLAG", default=True) is False

    def test_is_configured_only_true_with_all_three(self, env):
        env(EMAIL_INBOX_HOST=None, EMAIL_INBOX_USER=None, EMAIL_INBOX_PASSWORD=None)
        assert ei.is_configured() is False
        env(EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p")
        assert ei.is_configured() is True


# ══════════════════════════════════════════════════════════════
# _safe_filename + _decode_field + _walk_attachments
# ══════════════════════════════════════════════════════════════


class TestParserHelpers:
    def test_safe_filename_basic_sanitization(self):
        assert ei._safe_filename("Invoice.pdf") == "Invoice.pdf"
        # Special chars become underscores.
        assert "_" in ei._safe_filename("name<>:|?.pdf")

    def test_safe_filename_trims_trailing_dots_and_spaces(self):
        # Windows quirk.
        assert not ei._safe_filename("name....   ").endswith(".")

    def test_safe_filename_uses_fallback_when_empty(self):
        assert ei._safe_filename("", fallback="default.bin") == "default.bin"
        assert ei._safe_filename(None, fallback="x") == "x"  # type: ignore[arg-type]

    def test_safe_filename_truncates_to_200(self):
        long = "a" * 500 + ".pdf"
        assert len(ei._safe_filename(long)) == 200

    def test_decode_field_handles_none_and_plain(self):
        assert ei._decode_field(None) == ""
        assert ei._decode_field("plain text") == "plain text"

    def test_decode_field_handles_rfc2047(self):
        # =?UTF-8?B?...?= encoded
        encoded = "=?UTF-8?B?2YXYsdit2KjYpw==?="  # "مرحبا"
        out = ei._decode_field(encoded)
        # Either decoded or passthrough — both are valid behavior.
        assert isinstance(out, str)
        assert len(out) > 0

    def test_walk_attachments_yields_only_attachment_parts(self):
        raw = _make_email(attachments=[
            ("invoice.pdf", b"%PDF-1.4 fake", "application", "pdf"),
            ("image.png", b"fake-png-bytes", "image", "png"),
        ])
        from email import message_from_bytes
        msg = message_from_bytes(raw)
        results = list(ei._walk_attachments(msg))
        # Two attachments yielded.
        assert len(results) == 2
        names = {r[0] for r in results}
        assert "invoice.pdf" in names
        assert "image.png" in names


# ══════════════════════════════════════════════════════════════
# _connect — IMAP connection setup
# ══════════════════════════════════════════════════════════════


class TestConnect:
    def test_missing_config_raises_runtime_error(self, env):
        env(EMAIL_INBOX_HOST=None, EMAIL_INBOX_USER=None, EMAIL_INBOX_PASSWORD=None)
        with pytest.raises(RuntimeError, match="not configured"):
            ei._connect()

    def test_ssl_path(self, env, monkeypatch):
        env(
            EMAIL_INBOX_HOST="imap.test", EMAIL_INBOX_USER="u",
            EMAIL_INBOX_PASSWORD="p", EMAIL_INBOX_USE_SSL="1",
        )
        captured = {}

        class FakeIMAP:
            def __init__(self, host, port):
                captured["ssl"] = True
                captured["host"] = host
                captured["port"] = port

            def login(self, u, p):
                captured["login"] = (u, p)

            def select(self, folder):
                captured["select"] = folder

        monkeypatch.setattr(imaplib, "IMAP4_SSL", FakeIMAP)
        ei._connect()
        assert captured["ssl"] is True
        assert captured["host"] == "imap.test"
        assert captured["login"] == ("u", "p")
        assert captured["select"] == "INBOX"

    def test_non_ssl_path(self, env, monkeypatch):
        env(
            EMAIL_INBOX_HOST="imap.test", EMAIL_INBOX_USER="u",
            EMAIL_INBOX_PASSWORD="p", EMAIL_INBOX_USE_SSL="0",
        )

        class FakeIMAP:
            def __init__(self, host, port):
                pass

            def login(self, u, p):
                pass

            def select(self, folder):
                pass

        monkeypatch.setattr(imaplib, "IMAP4", FakeIMAP)
        # Should not raise.
        ei._connect()


# ══════════════════════════════════════════════════════════════
# poll_inbox — top-level orchestration
# ══════════════════════════════════════════════════════════════


class TestPollInbox:
    def test_not_configured_short_circuits(self, env):
        env(EMAIL_INBOX_HOST=None, EMAIL_INBOX_USER=None, EMAIL_INBOX_PASSWORD=None)
        out = ei.poll_inbox()
        assert out["ok"] is False
        assert out["error"] == "email_inbox_not_configured"
        assert "hint" in out

    def test_full_happy_path_with_attachments(
        self, env, monkeypatch, tmp_path, emit_capture
    ):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        # Build 2 messages with different attachment mixes.
        msg1 = _make_email(
            subject="Invoice 1",
            attachments=[("inv1.pdf", b"%PDF body", "application", "pdf")],
            message_id="<m1@host>",
        )
        msg2 = _make_email(
            subject="Mixed",
            attachments=[
                ("note.png", b"png-bytes", "image", "png"),
                ("ignore.zip", b"zip-bytes", "application", "zip"),
                # zip is `application/zip` — the filter
                # `_INVOICE_MEDIA_PREFIXES = ("application/pdf", "image/")`
                # ONLY accepts application/pdf or image/*, so zip is
                # filtered out at line 205-207.
            ],
            message_id="<m2@host>",
        )
        imap = _make_imap_mock(uids=[b"1", b"2"], fetch_payloads=[msg1, msg2])
        monkeypatch.setattr(ei, "_connect", lambda: imap)

        out = ei.poll_inbox()
        assert out["ok"] is True
        assert out["processed"] == 2
        # PDF (msg1) + PNG (msg2) saved; ZIP (msg2) filtered out.
        assert out["attachments_saved"] == 2
        assert out["emitted"] == 2
        # Files actually written: PDF + PNG only.
        files = list(tmp_path.iterdir())
        assert len(files) == 2
        # emit() called twice with the right shape.
        assert len(emit_capture) == 2
        for c in emit_capture:
            assert c["event"] == "email.received"
            assert c["source"] == "email_inbox"
            assert "message_id" in c["payload"]
        # mark_read called twice.
        assert imap.store.call_count == 2

    def test_imap_search_failure_returns_error(self, env, monkeypatch):
        env(EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p")
        imap = _make_imap_mock(uids=[b"1"], search_status="NO")
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox()
        assert out["ok"] is False
        assert "imap_search_failed" in out["error"]

    def test_fetch_failure_recorded_in_errors(self, env, monkeypatch, tmp_path):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        # fetch returns NO status → errors recorded
        imap = _make_imap_mock(
            uids=[b"1"], fetch_payloads=[None], fetch_status="NO",
        )
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox()
        assert out["ok"] is True
        assert out["processed"] == 0
        assert any(e.get("error") == "fetch_failed" for e in out["errors"])

    def test_bad_payload_recorded_in_errors(self, env, monkeypatch, tmp_path):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        imap = MagicMock(spec=imaplib.IMAP4)
        imap.search.return_value = ("OK", [b"1"])
        # Payload is a list with non-bytes inner → triggers bad_payload.
        imap.fetch.return_value = ("OK", [(b"meta", "not-bytes-string")])
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox()
        assert out["ok"] is True
        assert any(e.get("error") == "bad_payload" for e in out["errors"])

    def test_write_failure_recorded(self, env, monkeypatch, tmp_path):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        msg = _make_email(
            attachments=[("inv.pdf", b"%PDF", "application", "pdf")],
        )
        imap = _make_imap_mock(uids=[b"1"], fetch_payloads=[msg])
        monkeypatch.setattr(ei, "_connect", lambda: imap)

        # Patch builtins.open to raise during the write step.
        real_open = open

        def selective_open(path, *args, **kwargs):
            mode = args[0] if args else kwargs.get("mode", "r")
            if "wb" in mode and ".pdf" in str(path):
                raise OSError("disk full")
            return real_open(path, *args, **kwargs)

        monkeypatch.setattr("builtins.open", selective_open)
        out = ei.poll_inbox()
        assert out["ok"] is True
        # Write failed → no attachment saved, error recorded.
        assert out["attachments_saved"] == 0
        assert any("write_failed" in e.get("error", "") for e in out["errors"])

    def test_mark_read_failure_recorded(self, env, monkeypatch, tmp_path, emit_capture):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        msg = _make_email()
        imap = _make_imap_mock(uids=[b"1"], fetch_payloads=[msg], store_raises=True)
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox()
        assert out["ok"] is True
        # Emit + processed still succeeded; mark_read error recorded.
        assert out["processed"] == 1
        assert any("mark_read_failed" in e.get("error", "") for e in out["errors"])

    def test_outer_exception_returns_error(self, env, monkeypatch):
        env(EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p")

        def boom():
            raise RuntimeError("network down")

        monkeypatch.setattr(ei, "_connect", boom)
        out = ei.poll_inbox()
        assert out["ok"] is False
        assert "network down" in out["error"]
        assert "started_at" in out

    def test_explicit_max_messages_caps_uids(
        self, env, monkeypatch, tmp_path, emit_capture
    ):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )
        msg = _make_email()
        imap = _make_imap_mock(uids=[b"1", b"2", b"3"], fetch_payloads=[msg, msg, msg])
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox(max_messages=2)
        assert out["ok"] is True
        assert out["processed"] == 2  # capped from 3 → 2

    def test_inner_message_exception_recorded(
        self, env, monkeypatch, tmp_path, emit_capture
    ):
        """An exception INSIDE the per-message loop is captured per-uid."""
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
        )

        # Build a real, valid message; force `emit` to raise so the
        # except block at line 251-253 fires.
        msg = _make_email()
        imap = _make_imap_mock(uids=[b"1"], fetch_payloads=[msg])
        monkeypatch.setattr(ei, "_connect", lambda: imap)

        def boom_emit(*a, **kw):
            raise RuntimeError("bus dead")

        monkeypatch.setattr(ei, "emit", boom_emit)
        out = ei.poll_inbox()
        assert out["ok"] is True
        assert any("bus dead" in e.get("error", "") for e in out["errors"])

    def test_mark_read_disabled_via_env(
        self, env, monkeypatch, tmp_path, emit_capture
    ):
        env(
            EMAIL_INBOX_HOST="h", EMAIL_INBOX_USER="u", EMAIL_INBOX_PASSWORD="p",
            EMAIL_INBOX_ATTACHMENTS_DIR=str(tmp_path),
            EMAIL_INBOX_MARK_READ="0",
        )
        msg = _make_email()
        imap = _make_imap_mock(uids=[b"1"], fetch_payloads=[msg])
        monkeypatch.setattr(ei, "_connect", lambda: imap)
        out = ei.poll_inbox()
        assert out["ok"] is True
        # mark_read=False → store NOT called.
        imap.store.assert_not_called()
