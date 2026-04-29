"""
APEX Platform — Slack Webhook Backend
=====================================
Sends notifications to a Slack channel via Incoming Webhook.

Configuration via environment variables:
- SLACK_WEBHOOK_URL: Slack Incoming Webhook URL (https://hooks.slack.com/services/...)
                    If unset, console fallback in dev / no-op in prod.
- SLACK_DEFAULT_CHANNEL: Optional override channel (e.g. "#alerts").

Usage from notification_service:
    from app.core.slack_backend import send_slack_notification
    send_slack_notification(title="New invoice", body="Invoice #123 created", url="https://...")

Pattern mirrors app.core.sms_backend / app.core.email_service for consistency.
References: Wave 6 Multi-Channel Notifications (architecture/diagrams/02-target-state.md §7).
"""

from __future__ import annotations

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────

SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "").strip()
SLACK_DEFAULT_CHANNEL = os.environ.get("SLACK_DEFAULT_CHANNEL", "").strip()

# In dev, allow console fallback. In prod, missing webhook silently skips.
_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def is_configured() -> bool:
    """True if Slack is configured to actually send."""
    return bool(SLACK_WEBHOOK_URL)


def send_slack_notification(
    title: str,
    body: Optional[str] = None,
    url: Optional[str] = None,
    *,
    severity: str = "info",  # info | success | warning | error
    channel: Optional[str] = None,
    fields: Optional[dict] = None,
) -> dict:
    """Send a notification to Slack.

    Returns a dict with `success` (bool) and either `backend` or `error`.
    Uses Slack's Block Kit for a richer formatted message.

    Severity colors:
        info     -> #3b82f6 (blue)
        success  -> #10b981 (green)
        warning  -> #f59e0b (amber)
        error    -> #ef4444 (red)
    """
    if not SLACK_WEBHOOK_URL:
        if _IS_PRODUCTION:
            # Silent skip in prod when not configured — caller handles fallback.
            return {"success": False, "error": "slack_not_configured", "backend": "noop"}
        # Dev fallback: log to console.
        logger.info("Slack [console] %s | %s | %s", severity, title, body or "")
        return {"success": True, "backend": "console"}

    try:
        import requests
    except ImportError:
        logger.error("requests library not installed — Slack backend disabled")
        return {"success": False, "error": "requests_missing"}

    color_map = {
        "info": "#3b82f6",
        "success": "#10b981",
        "warning": "#f59e0b",
        "error": "#ef4444",
    }
    color = color_map.get(severity, color_map["info"])

    blocks: list[dict] = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*{title}*"},
        },
    ]
    if body:
        blocks.append(
            {"type": "section", "text": {"type": "mrkdwn", "text": body}},
        )
    if fields:
        # Two-column key/value list (mrkdwn formatting).
        chunks = []
        for k, v in fields.items():
            chunks.append({"type": "mrkdwn", "text": f"*{k}:*\n{v}"})
        if chunks:
            blocks.append({"type": "section", "fields": chunks[:10]})  # Slack limit: 10
    if url:
        blocks.append(
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "افتح في APEX"},
                        "url": url,
                    }
                ],
            }
        )

    payload: dict = {
        "text": title,  # plain-text fallback for clients that don't render blocks
        "attachments": [
            {
                "color": color,
                "blocks": blocks,
            }
        ],
    }
    target_channel = channel or SLACK_DEFAULT_CHANNEL
    if target_channel:
        payload["channel"] = target_channel

    try:
        resp = requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=10)
        if resp.status_code == 200 and resp.text == "ok":
            return {"success": True, "backend": "slack"}
        logger.error(
            "Slack webhook returned %s: %s", resp.status_code, resp.text[:200]
        )
        return {
            "success": False,
            "error": f"slack_http_{resp.status_code}",
            "backend": "slack",
        }
    except Exception as e:  # noqa: BLE001 — broad on purpose; never crash caller
        logger.error("Slack send failed: %s", e)
        return {"success": False, "error": str(e), "backend": "slack"}
