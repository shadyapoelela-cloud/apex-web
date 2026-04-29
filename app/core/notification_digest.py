"""
APEX — Notification Digest Service
===================================
Aggregates a user's unread notifications over a window (daily or weekly)
and sends a single summary email instead of per-event spam.

Why a digest instead of just per-event email:
- Wave 6 SaaS UX 2026 best practice: digests prevent notification fatigue
- Reduces email send volume (lower SendGrid/SMTP costs)
- Improves perceived signal-to-noise ratio for end users

Scheduling: this module exposes:
- `build_digest_for_user(user_id, since)` — preview the digest (returns dict)
- `send_digest_for_user(user_id, frequency)` — build + send via email
- `process_all_due_digests(frequency)` — iterate users; admin/cron entry point

Hook the cron job (Render / Heroku Scheduler / system cron):
    # daily 09:00 server-time
    0 9 * * *  curl -X POST -H "X-Admin-Secret: $SECRET" \\
                    https://apex-api.example/admin/digest/run?frequency=daily
    # weekly Monday 09:00 (in addition to daily, or as standalone)
    0 9 * * 1  curl -X POST -H "X-Admin-Secret: $SECRET" \\
                    https://apex-api.example/admin/digest/run?frequency=weekly

Threshold: a user with < MIN_DIGEST_ITEMS unread notifications gets nothing
(skipped silently) so we don't email people just to say "nothing happened".

References: architecture/diagrams/02-target-state.md §7 + research-findings §6.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.phase1.models.platform_models import SessionLocal, User
from app.phase10.models.phase10_models import NotificationV2, NotificationPreference

logger = logging.getLogger(__name__)

# Skip sending a digest if the user has fewer than this many unread items.
MIN_DIGEST_ITEMS = int(os.environ.get("DIGEST_MIN_ITEMS", "3"))

# Cap how many items we list inline in the digest body (rest shown as count).
MAX_DIGEST_INLINE = int(os.environ.get("DIGEST_MAX_INLINE", "20"))


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _window_start(frequency: str) -> datetime:
    """Return the lower-bound timestamp for a digest window."""
    now = _utcnow()
    if frequency == "weekly":
        return now - timedelta(days=7)
    # Default daily.
    return now - timedelta(days=1)


def build_digest_for_user(
    user_id: str,
    since: Optional[datetime] = None,
    frequency: str = "daily",
) -> dict:
    """Build a digest payload for a single user.

    Returns:
        {
            "count": int,                  # total unread in window
            "items": [ {title, body, ...}, ...up to MAX_DIGEST_INLINE ],
            "more": int,                   # count - len(items)
            "subject": str,                # email subject
            "text": str,                   # plain-text body
            "html": str,                   # html body
        }
    Returns count=0 dict when nothing to send.
    """
    if since is None:
        since = _window_start(frequency)

    db = SessionLocal()
    try:
        q = (
            db.query(NotificationV2)
            .filter(NotificationV2.user_id == user_id)
            .filter(NotificationV2.is_read == False)  # noqa: E712
            .filter(NotificationV2.created_at >= since)
            .order_by(NotificationV2.created_at.desc())
        )
        count = q.count()
        items = q.limit(MAX_DIGEST_INLINE).all()
    finally:
        db.close()

    if count == 0:
        return {"count": 0, "items": [], "more": 0, "subject": "", "text": "", "html": ""}

    period_label = "أسبوعك في APEX" if frequency == "weekly" else "يومك في APEX"
    subject = f"📬 {period_label} — {count} تنبيه جديد"

    # Plain-text body
    lines = [f"{period_label}", "", f"عندك {count} تنبيه جديد:", ""]
    for n in items:
        ts = n.created_at.strftime("%Y-%m-%d %H:%M") if n.created_at else ""
        lines.append(f"• [{ts}] {n.title_ar or n.title_en or ''} — {n.body_ar or n.body_en or ''}")
    more = count - len(items)
    if more > 0:
        lines.extend(["", f"و {more} تنبيه إضافي. افتح APEX لعرض الكل."])
    text_body = "\n".join(lines)

    # HTML body
    html_items = "".join(
        f'<li style="margin:6px 0;"><strong>{(n.title_ar or n.title_en or "")}</strong>'
        f' — {(n.body_ar or n.body_en or "")}'
        f' <span style="color:#94a3b8;font-size:11px;">'
        f'{(n.created_at.strftime("%Y-%m-%d %H:%M") if n.created_at else "")}</span></li>'
        for n in items
    )
    html_body = (
        f'<div style="font-family:system-ui,sans-serif;direction:rtl;'
        f'background:#0f172a;color:#e2e8f0;padding:24px;border-radius:12px;">'
        f'<h2 style="color:#fbbf24;margin:0 0 8px 0;">{period_label}</h2>'
        f'<p style="color:#94a3b8;margin:0 0 16px 0;">عندك <strong>{count}</strong> تنبيه جديد</p>'
        f'<ul style="list-style:none;padding:0;margin:0;">{html_items}</ul>'
        + (f'<p style="color:#94a3b8;margin-top:12px;">و {more} إضافي…</p>' if more > 0 else "")
        + f'</div>'
    )

    return {
        "count": count,
        "items": [
            {
                "id": n.id,
                "title": n.title_ar or n.title_en,
                "body": n.body_ar or n.body_en,
                "type": n.notification_type,
                "created_at": n.created_at.isoformat() if n.created_at else None,
            }
            for n in items
        ],
        "more": more,
        "subject": subject,
        "text": text_body,
        "html": html_body,
    }


def send_digest_for_user(user_id: str, frequency: str = "daily") -> dict:
    """Build and send a digest email to a single user.

    Returns: {sent, count, error?}
    """
    if frequency not in ("daily", "weekly"):
        return {"sent": False, "error": "invalid_frequency"}

    digest = build_digest_for_user(user_id, frequency=frequency)
    if digest["count"] < MIN_DIGEST_ITEMS:
        return {"sent": False, "skipped": True, "count": digest["count"]}

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.email:
            return {"sent": False, "error": "no_email", "count": digest["count"]}
        email = user.email
    finally:
        db.close()

    try:
        from app.core.email_service import send_email
    except Exception as e:
        logger.error("email_service unavailable for digest: %s", e)
        return {"sent": False, "error": "email_service_unavailable"}

    res = send_email(
        to=email,
        subject=digest["subject"],
        body_html=digest["html"],
        body_text=digest["text"],
    )
    if res.get("success"):
        logger.info(
            "Digest sent: user=%s freq=%s items=%s", user_id, frequency, digest["count"]
        )
        return {"sent": True, "count": digest["count"], "to": email}
    return {"sent": False, "error": res.get("error", "send_failed"), "count": digest["count"]}


def process_all_due_digests(frequency: str = "daily") -> dict:
    """Iterate every user with email-channel enabled and send digests where due.

    Returns: {processed, sent, skipped, errors}
    """
    if frequency not in ("daily", "weekly"):
        return {"processed": 0, "error": "invalid_frequency"}

    db = SessionLocal()
    try:
        # Pick distinct user_ids who have channel_email=True for any notification type.
        # Any user without any preference row defaults to email enabled (per
        # notification_service.py:95), so we also iterate all users to be safe.
        user_ids = {row[0] for row in db.query(User.id).all()}
        # Optionally filter out users who have explicitly disabled email globally:
        # (skip if any preference exists with channel_email=False — light heuristic)
        opted_out = {
            row[0]
            for row in db.query(NotificationPreference.user_id)
            .filter(NotificationPreference.channel_email == False)  # noqa: E712
            .distinct()
            .all()
        }
        # Heuristic: only opt out users where ALL their pref rows say no email.
        # Safer: just use the union; fancy filtering can come later.
        candidates = user_ids - opted_out
    finally:
        db.close()

    processed = 0
    sent = 0
    skipped = 0
    errors: list[dict] = []
    for uid in candidates:
        processed += 1
        try:
            result = send_digest_for_user(uid, frequency=frequency)
            if result.get("sent"):
                sent += 1
            else:
                skipped += 1
                if result.get("error") and result.get("error") not in (
                    "no_email",
                    "send_failed",
                ):
                    errors.append({"user_id": uid, **result})
        except Exception as e:  # noqa: BLE001
            errors.append({"user_id": uid, "error": str(e)})

    logger.info(
        "Digest run done: freq=%s processed=%s sent=%s skipped=%s errors=%s",
        frequency,
        processed,
        sent,
        skipped,
        len(errors),
    )
    return {
        "processed": processed,
        "sent": sent,
        "skipped": skipped,
        "errors": errors[:20],  # cap
        "frequency": frequency,
        "ran_at": _utcnow().isoformat(),
    }
