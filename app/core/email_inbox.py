"""
APEX — Email Inbox Listener (Email-to-Invoice intake)
=======================================================
Polls a configured IMAP mailbox, downloads any attachments from unread
messages, and emits `email.received` events on the bus so workflow
rules / the ai_extraction service can turn them into draft invoices.

Why this lives in core/ not phase10/:
- It's an *intake* path, not a notification dispatcher
- Pairs naturally with the Event Bus + Workflow Engine (Wave 1A)
- AI extraction (Claude Vision) already lives in `pilot/services/ai_extraction.py`

Configuration (env vars; all optional — module no-ops without them):
    EMAIL_INBOX_HOST            IMAP host (e.g. "imap.gmail.com")
    EMAIL_INBOX_PORT            default 993 (SSL)
    EMAIL_INBOX_USER            login
    EMAIL_INBOX_PASSWORD        password / app-password
    EMAIL_INBOX_USE_SSL         "1" (default) / "0"
    EMAIL_INBOX_FOLDER          default "INBOX"
    EMAIL_INBOX_ATTACHMENTS_DIR where to save attachments (default ./email_attachments)
    EMAIL_INBOX_MARK_READ       "1" (default) — mark fetched as read
    EMAIL_INBOX_MAX_PER_RUN     default 25 — cap polled messages per call

Cron hookup:
    */5 * * * *  curl -XPOST -H "X-Admin-Secret: $S" \\
                       https://apex-api.example/admin/email-inbox/poll

Reference: Layer 5.6 of architecture/FUTURE_ROADMAP.md (Email-to-Invoice).
"""

from __future__ import annotations

import imaplib
import logging
import os
import re
from datetime import datetime, timezone
from email import message_from_bytes
from email.header import decode_header, make_header
from email.message import Message
from typing import Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


# ── Config helpers ────────────────────────────────────────────────


def _cfg(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    if v is None or v == "":
        return default
    return v


def _bool(name: str, default: bool) -> bool:
    v = os.environ.get(name)
    if v is None:
        return default
    return v.strip() in ("1", "true", "yes", "on")


def is_configured() -> bool:
    return bool(
        _cfg("EMAIL_INBOX_HOST")
        and _cfg("EMAIL_INBOX_USER")
        and _cfg("EMAIL_INBOX_PASSWORD")
    )


# ── Helpers ───────────────────────────────────────────────────────

# File types we want to forward as invoice candidates.
_INVOICE_MEDIA_PREFIXES = ("application/pdf", "image/")

# Sanitize a filename so it's safe to write to disk on Windows + Linux.
_SAFE_NAME_RE = re.compile(r"[^a-zA-Z0-9._؀-ۿ\- ]")


def _safe_filename(name: str, fallback: str = "attachment") -> str:
    name = (name or fallback).strip()
    # Trim trailing dots/spaces (Windows quirk)
    name = name.rstrip(". ")
    name = _SAFE_NAME_RE.sub("_", name)
    return name[:200] or fallback


def _decode_field(raw: Optional[str]) -> str:
    if not raw:
        return ""
    try:
        return str(make_header(decode_header(raw)))
    except Exception:  # noqa: BLE001
        return raw


def _walk_attachments(msg: Message):
    """Yield (filename, payload_bytes, content_type) for each attachment."""
    if msg.is_multipart():
        for part in msg.walk():
            if part.is_multipart():
                continue
            disp = (part.get("Content-Disposition") or "").lower()
            content_type = (part.get_content_type() or "").lower()
            if "attachment" in disp or content_type.startswith(
                ("application/", "image/")
            ):
                payload = part.get_payload(decode=True)
                if not payload:
                    continue
                fn = _decode_field(part.get_filename() or "")
                yield fn, payload, content_type


# ── IMAP connection ──────────────────────────────────────────────


def _connect() -> imaplib.IMAP4:
    host = _cfg("EMAIL_INBOX_HOST", "")
    port = int(_cfg("EMAIL_INBOX_PORT", "993") or "993")
    use_ssl = _bool("EMAIL_INBOX_USE_SSL", True)
    user = _cfg("EMAIL_INBOX_USER", "")
    pwd = _cfg("EMAIL_INBOX_PASSWORD", "")
    folder = _cfg("EMAIL_INBOX_FOLDER", "INBOX") or "INBOX"

    if not (host and user and pwd):
        raise RuntimeError("Email inbox not configured")

    if use_ssl:
        imap = imaplib.IMAP4_SSL(host, port)
    else:
        imap = imaplib.IMAP4(host, port)
    imap.login(user, pwd)
    imap.select(folder)
    return imap


# ── Main poll ────────────────────────────────────────────────────


def poll_inbox(*, max_messages: Optional[int] = None) -> dict:
    """Fetch unread messages, save attachments, emit `email.received` events.

    Returns a summary:
        {
            ok, processed, attachments_saved, emitted,
            errors: [...], folder, started_at, finished_at
        }

    Always tries to mark messages as read (so we don't reprocess) unless
    EMAIL_INBOX_MARK_READ=0.
    """
    if not is_configured():
        return {
            "ok": False,
            "error": "email_inbox_not_configured",
            "hint": "Set EMAIL_INBOX_HOST/USER/PASSWORD to enable.",
        }

    cap = max_messages or int(_cfg("EMAIL_INBOX_MAX_PER_RUN", "25") or "25")
    mark_read = _bool("EMAIL_INBOX_MARK_READ", True)
    attach_dir = _cfg(
        "EMAIL_INBOX_ATTACHMENTS_DIR",
        os.path.join(os.environ.get("APEX_DATA_DIR", os.getcwd()), "email_attachments"),
    )
    os.makedirs(attach_dir, exist_ok=True)

    started = datetime.now(timezone.utc)
    processed = 0
    attachments_saved = 0
    emitted = 0
    errors: list[dict] = []

    imap: Optional[imaplib.IMAP4] = None
    try:
        imap = _connect()
        typ, data = imap.search(None, "UNSEEN")
        if typ != "OK":
            return {"ok": False, "error": f"imap_search_failed:{typ}"}
        uids = (data[0] or b"").split()
        if cap > 0:
            uids = uids[:cap]

        for uid in uids:
            try:
                typ, payload = imap.fetch(uid, "(RFC822)")
                if typ != "OK" or not payload or not payload[0]:
                    errors.append({"uid": uid.decode(errors="ignore"), "error": "fetch_failed"})
                    continue
                raw = payload[0][1]
                if not isinstance(raw, (bytes, bytearray)):
                    errors.append({"uid": uid.decode(errors="ignore"), "error": "bad_payload"})
                    continue
                msg = message_from_bytes(raw)

                subject = _decode_field(msg.get("Subject"))
                from_addr = _decode_field(msg.get("From"))
                date_hdr = _decode_field(msg.get("Date"))
                msg_id = msg.get("Message-ID") or f"uid-{uid.decode()}"

                attachments_meta: list[dict] = []
                for fn, payload_bytes, ct in _walk_attachments(msg):
                    if not any(ct.startswith(p) for p in _INVOICE_MEDIA_PREFIXES):
                        # Skip non-PDF, non-image attachments
                        continue
                    safe = _safe_filename(fn, fallback=f"{msg_id.strip('<>')}.bin")
                    out_path = os.path.join(
                        attach_dir,
                        f"{started.strftime('%Y%m%d')}_{uid.decode(errors='ignore')}_{safe}",
                    )
                    try:
                        with open(out_path, "wb") as f:
                            f.write(payload_bytes)
                        attachments_saved += 1
                        attachments_meta.append(
                            {
                                "filename": fn,
                                "content_type": ct,
                                "saved_path": out_path,
                                "size_bytes": len(payload_bytes),
                            }
                        )
                    except OSError as e:
                        errors.append({"uid": uid.decode(errors="ignore"), "error": f"write_failed:{e}"})

                # Emit event so rules / extraction services can react.
                emit(
                    "email.received",
                    {
                        "message_id": msg_id,
                        "from": from_addr,
                        "subject": subject,
                        "date": date_hdr,
                        "attachments": attachments_meta,
                        "attachment_count": len(attachments_meta),
                    },
                    source="email_inbox",
                )
                emitted += 1
                processed += 1

                if mark_read:
                    try:
                        imap.store(uid, "+FLAGS", "\\Seen")
                    except Exception as e:  # noqa: BLE001
                        errors.append(
                            {"uid": uid.decode(errors="ignore"), "error": f"mark_read_failed:{e}"}
                        )
            except Exception as e:  # noqa: BLE001
                logger.exception("Failed to process IMAP message %s: %s", uid, e)
                errors.append({"uid": uid.decode(errors="ignore"), "error": str(e)})

    except Exception as e:  # noqa: BLE001
        logger.exception("IMAP poll failed: %s", e)
        return {
            "ok": False,
            "error": str(e),
            "started_at": started.isoformat(),
        }
    finally:
        if imap is not None:
            try:
                imap.close()
                imap.logout()
            except Exception:  # noqa: BLE001
                pass

    return {
        "ok": True,
        "processed": processed,
        "attachments_saved": attachments_saved,
        "emitted": emitted,
        "errors": errors[:50],
        "folder": _cfg("EMAIL_INBOX_FOLDER", "INBOX"),
        "started_at": started.isoformat(),
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "attachments_dir": attach_dir,
    }
