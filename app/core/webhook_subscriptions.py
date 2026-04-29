"""
APEX — Webhook Subscriptions
=============================
Lets external systems (customer integrations, third-party apps,
internal microservices) subscribe to APEX events and receive HTTP
POSTs whenever a matching event fires on the bus.

Design:
- Each subscription has: event_pattern (e.g. `invoice.*`, `*`),
  target_url, optional shared secret for HMAC signing, enabled flag,
  retry limit, owner_user_id, tenant_id (scope), tags.
- Module registers a global event_bus listener on import. Every event
  → fan out to all enabled subscriptions whose pattern matches and
  whose tenant scope matches the event payload.
- Delivery is synchronous best-effort with bounded retry (default 3
  attempts, exponential backoff). A failure increments fail_count and
  records the last_status; subscriptions with too many consecutive
  failures auto-pause.
- Storage: JSON file at $WEBHOOK_SUBS_PATH (default webhook_subs.json),
  same pattern as workflow rules + approvals.
- HMAC: when secret is set, X-Apex-Signature header carries
  `sha256=<hex>` of the request body for receiver verification.

Why this pattern:
- Lets customers plug their own systems into APEX without us building
  integrations one-by-one
- Composes with the Event Registry (so subscribers can browse what's
  available) and Workflow Rules (rules can use action=webhook for
  one-off; subscriptions are the durable fan-out)
- Symmetric with the design of Stripe / GitHub / Slack webhooks

Reference: Layer 11.6 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import threading
import time
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import register_listener

logger = logging.getLogger(__name__)


# ── Storage ──────────────────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "WEBHOOK_SUBS_PATH", os.path.join(_DATA_DIR, "webhook_subs.json")
)

_LOCK = threading.RLock()

# Auto-pause after N consecutive failures (caller-tunable per subscription).
_DEFAULT_MAX_CONSECUTIVE_FAILS = int(
    os.environ.get("WEBHOOK_MAX_CONSECUTIVE_FAILS", "5") or "5"
)
_DEFAULT_TIMEOUT_SECONDS = int(
    os.environ.get("WEBHOOK_TIMEOUT_SECONDS", "10") or "10"
)
_DEFAULT_MAX_RETRIES = int(os.environ.get("WEBHOOK_MAX_RETRIES", "3") or "3")


# ── Models ───────────────────────────────────────────────────────


@dataclass
class WebhookSubscription:
    id: str
    event_pattern: str
    target_url: str
    secret: Optional[str] = None  # for HMAC signing; never returned by APIs
    enabled: bool = True
    owner_user_id: Optional[str] = None
    tenant_id: Optional[str] = None
    description: Optional[str] = None
    tags: list[str] = field(default_factory=list)

    timeout_seconds: int = _DEFAULT_TIMEOUT_SECONDS
    max_retries: int = _DEFAULT_MAX_RETRIES
    max_consecutive_fails: int = _DEFAULT_MAX_CONSECUTIVE_FAILS

    # Audit
    created_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updated_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    last_delivered_at: Optional[str] = None
    last_status: Optional[int] = None
    last_error: Optional[str] = None
    deliveries_total: int = 0
    deliveries_failed: int = 0
    consecutive_failures: int = 0


# ── Persistence ──────────────────────────────────────────────────


_STORE: dict[str, WebhookSubscription] = {}


def _load() -> None:
    global _STORE
    with _LOCK:
        if not os.path.exists(_PATH):
            _STORE = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _STORE = {
                s["id"]: WebhookSubscription(**s)
                for s in raw.get("subscriptions", [])
            }
            logger.info("Loaded %d webhook subs from %s", len(_STORE), _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load webhook subs: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "subscriptions": [asdict(s) for s in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── CRUD ─────────────────────────────────────────────────────────


def create_subscription(
    *,
    event_pattern: str,
    target_url: str,
    secret: Optional[str] = None,
    description: Optional[str] = None,
    tenant_id: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    tags: Optional[list[str]] = None,
    timeout_seconds: int = _DEFAULT_TIMEOUT_SECONDS,
    max_retries: int = _DEFAULT_MAX_RETRIES,
    enabled: bool = True,
) -> WebhookSubscription:
    if not target_url.startswith(("http://", "https://")):
        raise ValueError("target_url must start with http:// or https://")
    sub = WebhookSubscription(
        id=str(uuid.uuid4()),
        event_pattern=event_pattern.strip(),
        target_url=target_url.strip(),
        secret=secret,
        description=description,
        tenant_id=tenant_id,
        owner_user_id=owner_user_id,
        tags=tags or [],
        timeout_seconds=max(1, min(timeout_seconds, 60)),
        max_retries=max(0, min(max_retries, 5)),
        enabled=enabled,
    )
    with _LOCK:
        _STORE[sub.id] = sub
        _save()
    return sub


def list_subscriptions(
    *,
    tenant_id: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    enabled: Optional[bool] = None,
) -> list[WebhookSubscription]:
    with _LOCK:
        rows = list(_STORE.values())
    if tenant_id is not None:
        rows = [r for r in rows if r.tenant_id is None or r.tenant_id == tenant_id]
    if owner_user_id is not None:
        rows = [r for r in rows if r.owner_user_id == owner_user_id]
    if enabled is not None:
        rows = [r for r in rows if r.enabled == enabled]
    return rows


def get_subscription(sub_id: str) -> Optional[WebhookSubscription]:
    with _LOCK:
        return _STORE.get(sub_id)


def update_subscription(sub_id: str, **changes) -> Optional[WebhookSubscription]:
    with _LOCK:
        s = _STORE.get(sub_id)
        if not s:
            return None
        # Whitelist fields the API can change.
        allowed = {
            "event_pattern",
            "target_url",
            "secret",
            "description",
            "tags",
            "enabled",
            "timeout_seconds",
            "max_retries",
            "max_consecutive_fails",
        }
        for k, v in changes.items():
            if k in allowed and hasattr(s, k):
                setattr(s, k, v)
        s.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
        return s


def delete_subscription(sub_id: str) -> bool:
    with _LOCK:
        if sub_id not in _STORE:
            return False
        del _STORE[sub_id]
        _save()
        return True


def reset_failure_state(sub_id: str) -> bool:
    """Manually clear consecutive_failures + re-enable a paused sub."""
    with _LOCK:
        s = _STORE.get(sub_id)
        if not s:
            return False
        s.consecutive_failures = 0
        s.last_error = None
        s.enabled = True
        s.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
        return True


# ── Pattern matching (same semantics as event_bus) ───────────────


def _matches(pattern: str, name: str) -> bool:
    if pattern == "*":
        return True
    if pattern == name:
        return True
    if pattern.endswith(".*"):
        return name.startswith(pattern[:-2] + ".")
    return False


# ── Delivery ─────────────────────────────────────────────────────


def _hmac_signature(secret: str, body: bytes) -> str:
    mac = hmac.new(secret.encode("utf-8"), body, hashlib.sha256)
    return f"sha256={mac.hexdigest()}"


def _deliver_once(sub: WebhookSubscription, event_name: str, payload: dict) -> dict:
    try:
        import requests
    except ImportError:
        return {"ok": False, "error": "requests_missing"}

    body = json.dumps(
        {
            "event": event_name,
            "payload": payload,
            "subscription_id": sub.id,
            "delivered_at": datetime.now(timezone.utc).isoformat(),
        },
        ensure_ascii=False,
    ).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "APEX-Webhooks/1.0",
        "X-Apex-Event": event_name,
        "X-Apex-Subscription-Id": sub.id,
    }
    if sub.secret:
        headers["X-Apex-Signature"] = _hmac_signature(sub.secret, body)

    try:
        resp = requests.post(
            sub.target_url, data=body, headers=headers, timeout=sub.timeout_seconds
        )
        ok = 200 <= resp.status_code < 300
        return {
            "ok": ok,
            "status": resp.status_code,
            "body_excerpt": (resp.text[:200] if not ok else None),
        }
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)}


def _deliver(sub: WebhookSubscription, event_name: str, payload: dict) -> None:
    """Deliver one event to one subscription with bounded retry.

    Retries use exponential backoff: 0.5s, 1s, 2s. Retries only on
    transient (5xx, network) failures — 4xx is treated as final.
    """
    last: dict = {}
    for attempt in range(sub.max_retries + 1):
        last = _deliver_once(sub, event_name, payload)
        if last.get("ok"):
            break
        # 4xx → no retry. 5xx / network errors → retry.
        status = last.get("status")
        is_transient = (status is None) or (status >= 500)
        if not is_transient or attempt == sub.max_retries:
            break
        time.sleep(0.5 * (2 ** attempt))

    with _LOCK:
        sub.deliveries_total += 1
        sub.last_delivered_at = datetime.now(timezone.utc).isoformat()
        if last.get("ok"):
            sub.last_status = last.get("status")
            sub.last_error = None
            sub.consecutive_failures = 0
        else:
            sub.deliveries_failed += 1
            sub.consecutive_failures += 1
            sub.last_status = last.get("status")
            sub.last_error = last.get("error") or last.get("body_excerpt") or "failed"
            if sub.consecutive_failures >= sub.max_consecutive_fails:
                sub.enabled = False
                logger.warning(
                    "Webhook %s auto-paused after %d consecutive failures",
                    sub.id,
                    sub.consecutive_failures,
                )
        _save()


# ── Bus listener ────────────────────────────────────────────────


@register_listener("*")
def _listener(event_name: str, payload: dict) -> None:
    """Fan out one event to every matching enabled subscription."""
    with _LOCK:
        subs = [s for s in _STORE.values() if s.enabled and _matches(s.event_pattern, event_name)]

    # Tenant scope filter — only deliver if event payload's tenant_id
    # matches the subscription's tenant_id (or sub has no tenant_id).
    payload_tenant = payload.get("tenant_id")
    for sub in subs:
        if sub.tenant_id and payload_tenant and sub.tenant_id != payload_tenant:
            continue
        try:
            _deliver(sub, event_name, payload)
        except Exception as e:  # noqa: BLE001
            logger.exception("Webhook delivery error: %s", e)


# Initial load on import.
_load()


# ── Stats ────────────────────────────────────────────────────────


def stats() -> dict:
    with _LOCK:
        active = sum(1 for s in _STORE.values() if s.enabled)
        total_delivered = sum(s.deliveries_total for s in _STORE.values())
        total_failed = sum(s.deliveries_failed for s in _STORE.values())
        return {
            "subscriptions_total": len(_STORE),
            "subscriptions_enabled": active,
            "subscriptions_paused": len(_STORE) - active,
            "deliveries_total": total_delivered,
            "deliveries_failed": total_failed,
            "storage_path": _PATH,
        }
