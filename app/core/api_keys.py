"""
APEX — Public API Keys
=======================
First-class programmatic access to APEX. Companies generate keys for
their internal automations / 3rd-party tools without sharing user
credentials.

Design:
- Each ApiKey has: id, name, prefix (visible), hashed_secret (stored),
  raw_secret (returned ONCE on create), scopes[], tenant_id, owner_user_id,
  enabled, expires_at, allowed_ips[], rate_limit_per_minute, audit fields.
- Format: `apex_<prefix-8>_<secret-32>` — `prefix` is what's shown in
  the UI (last 4 of full key) so admins can identify which key without
  exposing it.
- Storage: bcrypt-style hash of the secret; the raw_secret is returned
  only at creation time and never stored. Use compare_digest at lookup.
- Scopes: list of dotted permissions like `read:invoices`, `write:journal`,
  `admin:approvals`. The ApiKey middleware (or Depends) checks the
  required scope per route.

API:
    create_key(name, scopes, tenant_id, owner_user_id, expires_at?)
    list_keys(tenant_id, owner_user_id?)
    revoke_key(key_id)
    verify_key(raw)  → (ApiKey | None, was_recognized: bool)

Reference: Layer 11.5 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import secrets
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


# ── Storage ──────────────────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get("API_KEYS_PATH", os.path.join(_DATA_DIR, "api_keys.json"))

_LOCK = threading.RLock()


# ── Models ───────────────────────────────────────────────────────


@dataclass
class ApiKey:
    id: str
    name: str
    prefix: str  # public-visible identifier (e.g. last 4 chars)
    hashed_secret: str  # SHA-256 hex of the raw secret
    scopes: list[str] = field(default_factory=list)
    tenant_id: Optional[str] = None
    owner_user_id: Optional[str] = None
    description: Optional[str] = None
    enabled: bool = True
    expires_at: Optional[str] = None  # ISO string; None = never expires
    allowed_ips: list[str] = field(default_factory=list)  # empty = any IP
    rate_limit_per_minute: int = 60

    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    last_used_at: Optional[str] = None
    use_count: int = 0
    revoked_at: Optional[str] = None
    revoked_reason: Optional[str] = None


_STORE: dict[str, ApiKey] = {}


# ── Persistence ──────────────────────────────────────────────────


def _load() -> None:
    global _STORE
    with _LOCK:
        if not os.path.exists(_PATH):
            _STORE = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _STORE = {k["id"]: ApiKey(**k) for k in raw.get("keys", [])}
            logger.info("Loaded %d API keys from %s", len(_STORE), _PATH)
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load API keys: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "keys": [asdict(k) for k in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── Hashing ──────────────────────────────────────────────────────


def _hash_secret(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _generate_key() -> tuple[str, str, str]:
    """Generate (raw_secret, prefix, hashed)."""
    secret_part = secrets.token_urlsafe(24)  # ~32 chars URL-safe
    raw = f"apex_{secrets.token_urlsafe(8)}_{secret_part}"
    prefix = raw[:13]  # "apex_xxxxxxxx" — recognizable head
    hashed = _hash_secret(raw)
    return raw, prefix, hashed


# ── CRUD ─────────────────────────────────────────────────────────


def create_key(
    *,
    name: str,
    scopes: Optional[list[str]] = None,
    tenant_id: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    description: Optional[str] = None,
    expires_at: Optional[str] = None,
    allowed_ips: Optional[list[str]] = None,
    rate_limit_per_minute: int = 60,
) -> tuple[ApiKey, str]:
    """Generate a new key. Returns (record, raw_secret).

    The raw_secret is shown to the caller exactly once — it is NOT
    stored or returnable later.
    """
    if not name.strip():
        raise ValueError("name is required")
    if rate_limit_per_minute < 1 or rate_limit_per_minute > 6000:
        raise ValueError("rate_limit_per_minute must be 1..6000")

    raw, prefix, hashed = _generate_key()
    key = ApiKey(
        id=str(uuid.uuid4()),
        name=name.strip(),
        prefix=prefix,
        hashed_secret=hashed,
        scopes=list(scopes or []),
        tenant_id=tenant_id,
        owner_user_id=owner_user_id,
        description=description,
        expires_at=expires_at,
        allowed_ips=list(allowed_ips or []),
        rate_limit_per_minute=rate_limit_per_minute,
    )
    with _LOCK:
        _STORE[key.id] = key
        _save()
    return key, raw


def list_keys(
    *,
    tenant_id: Optional[str] = None,
    owner_user_id: Optional[str] = None,
    include_revoked: bool = False,
) -> list[ApiKey]:
    with _LOCK:
        rows = list(_STORE.values())
    if tenant_id is not None:
        rows = [k for k in rows if k.tenant_id == tenant_id]
    if owner_user_id is not None:
        rows = [k for k in rows if k.owner_user_id == owner_user_id]
    if not include_revoked:
        rows = [k for k in rows if not k.revoked_at]
    rows.sort(key=lambda k: k.created_at, reverse=True)
    return rows


def get_key(key_id: str) -> Optional[ApiKey]:
    with _LOCK:
        return _STORE.get(key_id)


def revoke_key(key_id: str, *, reason: Optional[str] = None) -> bool:
    with _LOCK:
        k = _STORE.get(key_id)
        if not k or k.revoked_at:
            return False
        k.enabled = False
        k.revoked_at = datetime.now(timezone.utc).isoformat()
        k.revoked_reason = reason
        _save()
    return True


def update_key_meta(
    key_id: str,
    *,
    name: Optional[str] = None,
    description: Optional[str] = None,
    scopes: Optional[list[str]] = None,
    enabled: Optional[bool] = None,
    expires_at: Optional[str] = None,
    allowed_ips: Optional[list[str]] = None,
    rate_limit_per_minute: Optional[int] = None,
) -> Optional[ApiKey]:
    with _LOCK:
        k = _STORE.get(key_id)
        if not k:
            return None
        if name is not None:
            k.name = name
        if description is not None:
            k.description = description
        if scopes is not None:
            k.scopes = scopes
        if enabled is not None:
            # Don't undo a revocation by setting enabled=True
            if k.revoked_at and enabled:
                pass  # silently ignore
            else:
                k.enabled = enabled
        if expires_at is not None:
            k.expires_at = expires_at
        if allowed_ips is not None:
            k.allowed_ips = allowed_ips
        if rate_limit_per_minute is not None:
            if 1 <= rate_limit_per_minute <= 6000:
                k.rate_limit_per_minute = rate_limit_per_minute
        _save()
        return k


# ── Verify (used by middleware / Depends) ───────────────────────


def verify_key(raw: str, *, request_ip: Optional[str] = None) -> tuple[Optional[ApiKey], str]:
    """Verify a raw API key string. Returns (record, reason).

    On success: (key, "ok"). On failure: (None, reason) where reason is
    one of: "not_found", "revoked", "expired", "ip_not_allowed", "disabled".
    Always uses constant-time comparison to mitigate timing attacks.
    """
    if not raw or not raw.startswith("apex_"):
        return None, "not_found"
    hashed = _hash_secret(raw)

    with _LOCK:
        match: Optional[ApiKey] = None
        for k in _STORE.values():
            if hmac.compare_digest(k.hashed_secret, hashed):
                match = k
                break
        if not match:
            return None, "not_found"

        if match.revoked_at:
            return None, "revoked"
        if not match.enabled:
            return None, "disabled"
        if match.expires_at:
            try:
                exp = datetime.fromisoformat(match.expires_at.replace("Z", "+00:00"))
                if datetime.now(timezone.utc) > exp:
                    return None, "expired"
            except Exception:  # noqa: BLE001
                pass
        if match.allowed_ips and request_ip and request_ip not in match.allowed_ips:
            return None, "ip_not_allowed"

        # Bump audit
        match.last_used_at = datetime.now(timezone.utc).isoformat()
        match.use_count += 1
        _save()

        return match, "ok"


def has_scope(key: ApiKey, required: str) -> bool:
    """True if `key` has either the exact `required` scope or an `*` super-scope.

    Scope hierarchy:
        "*"                — superuser key (all scopes)
        "admin:*"          — wildcards within a namespace
        "read:invoices"    — exact match
    """
    if not key.scopes:
        return False
    if "*" in key.scopes or required in key.scopes:
        return True
    namespace = required.split(":")[0]
    if f"{namespace}:*" in key.scopes:
        return True
    return False


# Initial load.
_load()


def stats() -> dict:
    with _LOCK:
        active = sum(1 for k in _STORE.values() if k.enabled and not k.revoked_at)
        revoked = sum(1 for k in _STORE.values() if k.revoked_at)
        return {
            "keys_total": len(_STORE),
            "keys_active": active,
            "keys_revoked": revoked,
            "keys_disabled": len(_STORE) - active - revoked,
            "storage_path": _PATH,
        }
