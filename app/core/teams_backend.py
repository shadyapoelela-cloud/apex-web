"""
APEX Platform — Microsoft Teams Webhook Backend
================================================
Sends notifications to a Teams channel via Incoming Webhook (Adaptive Card format).

Configuration via environment variables:
- TEAMS_WEBHOOK_URL: Teams Incoming Webhook URL.
                    If unset, console fallback in dev / no-op in prod.

Usage:
    from app.core.teams_backend import send_teams_notification
    send_teams_notification(title="New invoice", body="...", url="...")

Pattern mirrors app.core.slack_backend.
References: Wave 6 Multi-Channel Notifications (architecture/diagrams/02-target-state.md §7).
"""

from __future__ import annotations

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────

TEAMS_WEBHOOK_URL = os.environ.get("TEAMS_WEBHOOK_URL", "").strip()

_IS_PRODUCTION = os.environ.get("ENVIRONMENT", "development").lower() in ("production", "prod")


def is_configured() -> bool:
    """True if Teams is configured to actually send."""
    return bool(TEAMS_WEBHOOK_URL)


def send_teams_notification(
    title: str,
    body: Optional[str] = None,
    url: Optional[str] = None,
    *,
    severity: str = "info",
    fields: Optional[dict] = None,
) -> dict:
    """Send an Adaptive Card notification to a Teams channel via webhook.

    Severity colors map to Teams "themeColor" RRGGBB hex:
        info     -> 3b82f6 (blue)
        success  -> 10b981 (green)
        warning  -> f59e0b (amber)
        error    -> ef4444 (red)
    """
    if not TEAMS_WEBHOOK_URL:
        if _IS_PRODUCTION:
            return {"success": False, "error": "teams_not_configured", "backend": "noop"}
        logger.info("Teams [console] %s | %s | %s", severity, title, body or "")
        return {"success": True, "backend": "console"}

    try:
        import requests
    except ImportError:
        logger.error("requests library not installed — Teams backend disabled")
        return {"success": False, "error": "requests_missing"}

    color_map = {
        "info": "3b82f6",
        "success": "10b981",
        "warning": "f59e0b",
        "error": "ef4444",
    }
    theme_color = color_map.get(severity, color_map["info"])

    facts: list[dict] = []
    if fields:
        for k, v in list(fields.items())[:10]:
            facts.append({"name": str(k), "value": str(v)})

    actions: list[dict] = []
    if url:
        actions.append(
            {
                "@type": "OpenUri",
                "name": "افتح في APEX",
                "targets": [{"os": "default", "uri": url}],
            }
        )

    payload = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": title,
        "themeColor": theme_color,
        "title": title,
        "sections": [
            {
                "activityTitle": title,
                "text": body or "",
                **({"facts": facts} if facts else {}),
            }
        ],
        **({"potentialAction": actions} if actions else {}),
    }

    try:
        resp = requests.post(TEAMS_WEBHOOK_URL, json=payload, timeout=10)
        # Teams returns "1" on success.
        if resp.status_code == 200:
            return {"success": True, "backend": "teams"}
        logger.error(
            "Teams webhook returned %s: %s", resp.status_code, resp.text[:200]
        )
        return {
            "success": False,
            "error": f"teams_http_{resp.status_code}",
            "backend": "teams",
        }
    except Exception as e:  # noqa: BLE001
        logger.error("Teams send failed: %s", e)
        return {"success": False, "error": str(e), "backend": "teams"}
