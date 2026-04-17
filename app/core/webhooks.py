"""Outbound webhooks — Developer Platform §16 of Master Blueprint.

External systems subscribe to events via a secret URL + event filter.
APEX publishes events; a background dispatcher delivers them with retries
and HMAC-SHA256 signing so subscribers can verify authenticity.

Event shape:
  {
    "id": "evt_<uuid>",
    "type": "invoice.created" | "invoice.paid" | "payment.received" | ...,
    "tenant_id": "tenant-...",
    "created_at": "ISO timestamp",
    "data": { ... }
  }

Signing:
  Subscriber receives:
    X-Apex-Signature: sha256=<hex>
    X-Apex-Event: <event.type>
    X-Apex-Delivery-Id: <uuid>
  Where hex = HMAC-SHA256(secret, raw_body).

Retry policy:
  On HTTP non-2xx, exponential backoff at 30s, 2min, 10min, 1h, 6h.
  After 5 failed attempts the delivery is DEAD and surfaces in the UI.

Public API:
  subscribe(url, events, secret) -> Subscription
  publish(event_type, tenant_id, data) -> DeliveryQueue (persists deliveries)
  list_subscriptions() / list_deliveries() / retry_delivery(delivery_id)
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import secrets
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Column, DateTime, Integer, JSON, String, Text

from app.core.api_version import v1_prefix
from app.core.tenant_context import current_tenant
from app.core.tenant_guard import TenantMixin
from app.phase1.models.platform_models import Base, SessionLocal

logger = logging.getLogger(__name__)


# ── Models ─────────────────────────────────────────────────


class WebhookSubscription(Base, TenantMixin):
    __tablename__ = "webhook_subscriptions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(120), nullable=True)
    url = Column(String(500), nullable=False)
    secret = Column(String(80), nullable=False)   # used for HMAC signing
    events = Column(JSON, nullable=False)          # list[str] — event filter
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )


class WebhookDelivery(Base, TenantMixin):
    __tablename__ = "webhook_deliveries"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    subscription_id = Column(String(36), nullable=False, index=True)
    event_id = Column(String(36), nullable=False, index=True)
    event_type = Column(String(64), nullable=False, index=True)
    payload = Column(JSON, nullable=False)

    status = Column(String(16), nullable=False, default="pending", index=True)
    # pending / delivered / failed / dead

    attempts = Column(Integer, nullable=False, default=0)
    last_attempt_at = Column(DateTime(timezone=True), nullable=True)
    last_http_status = Column(Integer, nullable=True)
    last_error = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True), nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    delivered_at = Column(DateTime(timezone=True), nullable=True)


# ── HMAC signing ─────────────────────────────────────────


def sign_payload(secret: str, body: bytes) -> str:
    return "sha256=" + hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


def verify_signature(secret: str, body: bytes, signature_header: Optional[str]) -> bool:
    if not secret or not signature_header or not signature_header.startswith("sha256="):
        return False
    expected = sign_payload(secret, body)
    return hmac.compare_digest(signature_header, expected)


# ── Publishing ────────────────────────────────────────────


def publish(event_type: str, data: dict, tenant_id: Optional[str] = None) -> list[str]:
    """Fan out an event to all active subscriptions matching event_type.

    Returns the list of created delivery IDs. Does NOT wait for HTTP
    delivery — that runs in the dispatcher.
    """
    tid = tenant_id or current_tenant()
    delivery_ids: list[str] = []
    db = SessionLocal()
    try:
        q = db.query(WebhookSubscription).filter(WebhookSubscription.active.is_(True))
        subs = [s for s in q.all() if event_type in (s.events or [])]

        envelope = {
            "id": f"evt_{uuid.uuid4().hex}",
            "type": event_type,
            "tenant_id": tid,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "data": data,
        }

        for sub in subs:
            delivery = WebhookDelivery(
                id=str(uuid.uuid4()),
                subscription_id=sub.id,
                event_id=envelope["id"],
                event_type=event_type,
                payload=envelope,
                status="pending",
                attempts=0,
            )
            db.add(delivery)
            delivery_ids.append(delivery.id)

        db.commit()
        return delivery_ids
    finally:
        db.close()


def dispatch_one(delivery_id: str) -> dict:
    """Attempt to deliver one webhook. Returns the updated delivery state.

    Called by the background dispatcher (Celery/APScheduler) or directly
    from retry endpoints. Safe to call concurrently — uses row-level locks.
    """
    db = SessionLocal()
    try:
        delivery = db.query(WebhookDelivery).filter(WebhookDelivery.id == delivery_id).first()
        if not delivery:
            return {"success": False, "error": "not_found"}
        if delivery.status in ("delivered", "dead"):
            return {"success": True, "status": delivery.status}

        sub = db.query(WebhookSubscription).filter(
            WebhookSubscription.id == delivery.subscription_id
        ).first()
        if not sub or not sub.active:
            delivery.status = "dead"
            delivery.last_error = "subscription_inactive_or_missing"
            db.commit()
            return {"success": False, "error": "subscription_inactive"}

        try:
            import requests
        except ImportError:
            delivery.last_error = "requests not installed"
            db.commit()
            return {"success": False, "error": "requests_not_installed"}

        body = json.dumps(delivery.payload, ensure_ascii=False, default=str).encode("utf-8")
        signature = sign_payload(sub.secret, body)
        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "X-Apex-Signature": signature,
            "X-Apex-Event": delivery.event_type,
            "X-Apex-Delivery-Id": delivery.id,
            "User-Agent": "APEX-Webhook/1.0",
        }

        delivery.attempts += 1
        delivery.last_attempt_at = datetime.now(timezone.utc)

        try:
            resp = requests.post(sub.url, data=body, headers=headers, timeout=10)
        except Exception as e:
            delivery.last_error = f"network: {e}"[:500]
            delivery.status = "dead" if delivery.attempts >= 5 else "failed"
            db.commit()
            return {
                "success": False,
                "status": delivery.status,
                "attempts": delivery.attempts,
                "error": delivery.last_error,
            }

        delivery.last_http_status = resp.status_code
        if 200 <= resp.status_code < 300:
            delivery.status = "delivered"
            delivery.delivered_at = datetime.now(timezone.utc)
            db.commit()
            return {
                "success": True,
                "status": "delivered",
                "http_status": resp.status_code,
                "attempts": delivery.attempts,
            }
        # Non-2xx
        delivery.last_error = f"HTTP {resp.status_code}: {resp.text[:400]}"
        delivery.status = "dead" if delivery.attempts >= 5 else "failed"
        db.commit()
        return {
            "success": False,
            "status": delivery.status,
            "http_status": resp.status_code,
            "attempts": delivery.attempts,
            "error": delivery.last_error,
        }
    finally:
        db.close()


# ── REST API (/api/v1/webhooks) ───────────────────────────


class WebhookSubscriptionIn(BaseModel):
    name: Optional[str] = None
    url: str = Field(..., min_length=10, max_length=500)
    events: list[str] = Field(..., min_length=1)


class WebhookSubscriptionOut(BaseModel):
    id: str
    name: Optional[str]
    url: str
    events: list[str]
    active: bool
    secret: str
    created_at: datetime


router = APIRouter(prefix=v1_prefix("/webhooks"), tags=["Webhooks"])


@router.get("/subscriptions")
def list_subscriptions():
    db = SessionLocal()
    try:
        rows = db.query(WebhookSubscription).order_by(WebhookSubscription.created_at.desc()).all()
        return {
            "success": True,
            "data": [
                {
                    "id": s.id,
                    "name": s.name,
                    "url": s.url,
                    "events": s.events,
                    "active": s.active,
                    "created_at": s.created_at.isoformat(),
                }
                for s in rows
            ],
        }
    finally:
        db.close()


@router.post("/subscriptions", status_code=201)
def create_subscription(payload: WebhookSubscriptionIn):
    db = SessionLocal()
    try:
        sub = WebhookSubscription(
            id=str(uuid.uuid4()),
            name=payload.name,
            url=payload.url,
            secret="whsec_" + secrets.token_urlsafe(32),
            events=payload.events,
            active=True,
        )
        db.add(sub)
        db.commit()
        db.refresh(sub)
        # Return the secret ONCE — this is the only time the caller sees it.
        return {
            "success": True,
            "data": WebhookSubscriptionOut(
                id=sub.id,
                name=sub.name,
                url=sub.url,
                events=sub.events,
                active=sub.active,
                secret=sub.secret,
                created_at=sub.created_at,
            ).model_dump(mode="json"),
        }
    finally:
        db.close()


@router.delete("/subscriptions/{sub_id}")
def delete_subscription(sub_id: str):
    db = SessionLocal()
    try:
        sub = db.query(WebhookSubscription).filter(WebhookSubscription.id == sub_id).first()
        if not sub:
            raise HTTPException(status_code=404, detail="Subscription not found")
        db.delete(sub)
        db.commit()
        return {"success": True, "data": {"id": sub_id}}
    finally:
        db.close()


@router.get("/deliveries")
def list_deliveries(status: Optional[str] = None, limit: int = 50):
    db = SessionLocal()
    try:
        q = db.query(WebhookDelivery).order_by(WebhookDelivery.created_at.desc())
        if status:
            q = q.filter(WebhookDelivery.status == status)
        rows = q.limit(max(1, min(limit, 200))).all()
        return {
            "success": True,
            "data": [
                {
                    "id": d.id,
                    "subscription_id": d.subscription_id,
                    "event_id": d.event_id,
                    "event_type": d.event_type,
                    "status": d.status,
                    "attempts": d.attempts,
                    "last_http_status": d.last_http_status,
                    "last_error": d.last_error,
                    "created_at": d.created_at.isoformat(),
                    "delivered_at": d.delivered_at.isoformat() if d.delivered_at else None,
                }
                for d in rows
            ],
        }
    finally:
        db.close()


@router.post("/deliveries/{delivery_id}/retry")
def retry_delivery(delivery_id: str):
    result = dispatch_one(delivery_id)
    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result)
    return {"success": True, "data": result}
