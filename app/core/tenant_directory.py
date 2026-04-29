"""APEX — Tenant Directory.

A minimal registry of onboarded tenants. APEX uses tenant_id as an
opaque string in queries — it doesn't need to be "created" anywhere
specific. But for admin tools (listing "all tenants the platform
knows about", power-user search, the onboarding wizard's review step,
etc.) we need a single source of truth.

Storage: $APEX_DATA_DIR/tenant_directory.json — same JSON-as-DB pattern
as suggestions / approvals / industry_pack_assignments. Atomic temp+
replace + RLock guards.

Idempotency: register() is idempotent on tenant_id — re-registering
updates display_name / industry_pack_id / status without creating a
duplicate.

Events:
    tenant.registered     — first time a tenant_id is added
    tenant.updated        — display_name or metadata changed
    tenant.deactivated    — admin suspends the tenant

Wave 1N Phase TT.
"""

from __future__ import annotations

import json
import logging
import os
import threading
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "TENANT_DIRECTORY_PATH",
    os.path.join(_DATA_DIR, "tenant_directory.json"),
)
_LOCK = threading.RLock()


@dataclass
class TenantRecord:
    tenant_id: str
    display_name: str
    industry_pack_id: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    created_by: Optional[str] = None
    status: str = "active"  # active | inactive
    notes: Optional[str] = None
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


_STORE: dict[str, TenantRecord] = {}


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
                t["tenant_id"]: TenantRecord(**t)
                for t in raw.get("tenants", [])
            }
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load tenant directory: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "tenants": [asdict(t) for t in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


_load()


# ── Public API ──────────────────────────────────────────────────


def register(
    tenant_id: str,
    display_name: str,
    *,
    industry_pack_id: Optional[str] = None,
    created_by: Optional[str] = None,
    notes: Optional[str] = None,
) -> dict:
    """Idempotent register: creates or updates the tenant record.

    Emits `tenant.registered` on first add, `tenant.updated` on subsequent.
    """
    if not tenant_id or not tenant_id.strip():
        raise ValueError("tenant_id required")
    if not display_name or not display_name.strip():
        raise ValueError("display_name required")
    tenant_id = tenant_id.strip()
    display_name = display_name.strip()
    is_new = False
    with _LOCK:
        existing = _STORE.get(tenant_id)
        if existing:
            existing.display_name = display_name
            if industry_pack_id is not None:
                existing.industry_pack_id = industry_pack_id
            if notes is not None:
                existing.notes = notes
            existing.updated_at = datetime.now(timezone.utc).isoformat()
            rec = existing
        else:
            rec = TenantRecord(
                tenant_id=tenant_id,
                display_name=display_name,
                industry_pack_id=industry_pack_id,
                created_by=created_by,
                notes=notes,
            )
            _STORE[tenant_id] = rec
            is_new = True
        _save()
    emit(
        "tenant.registered" if is_new else "tenant.updated",
        {
            "tenant_id": tenant_id,
            "display_name": display_name,
            "industry_pack_id": industry_pack_id,
            "created_by": created_by,
        },
        source="tenant_directory",
    )
    return asdict(rec)


def get(tenant_id: str) -> Optional[dict]:
    with _LOCK:
        rec = _STORE.get(tenant_id)
        return asdict(rec) if rec else None


def list_tenants(*, status: Optional[str] = None) -> list[dict]:
    with _LOCK:
        rows = list(_STORE.values())
    if status:
        rows = [r for r in rows if r.status == status]
    rows.sort(key=lambda r: r.created_at, reverse=True)
    return [asdict(r) for r in rows]


def deactivate(tenant_id: str, *, reason: Optional[str] = None) -> bool:
    with _LOCK:
        rec = _STORE.get(tenant_id)
        if not rec or rec.status == "inactive":
            return False
        rec.status = "inactive"
        rec.updated_at = datetime.now(timezone.utc).isoformat()
        if reason:
            rec.notes = (rec.notes or "") + f" [deactivated: {reason}]"
        _save()
    emit(
        "tenant.deactivated",
        {"tenant_id": tenant_id, "reason": reason},
        source="tenant_directory",
    )
    return True


def reactivate(tenant_id: str) -> bool:
    with _LOCK:
        rec = _STORE.get(tenant_id)
        if not rec or rec.status == "active":
            return False
        rec.status = "active"
        rec.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
    emit(
        "tenant.updated",
        {"tenant_id": tenant_id, "status": "active"},
        source="tenant_directory",
    )
    return True


def delete(tenant_id: str) -> bool:
    """Hard-delete from the directory. Other stores keep their data."""
    with _LOCK:
        if tenant_id not in _STORE:
            return False
        _STORE.pop(tenant_id)
        _save()
    return True


def stats() -> dict:
    with _LOCK:
        rows = list(_STORE.values())
    by_pack: dict[str, int] = {}
    by_status: dict[str, int] = {}
    for r in rows:
        if r.industry_pack_id:
            by_pack[r.industry_pack_id] = by_pack.get(r.industry_pack_id, 0) + 1
        by_status[r.status] = by_status.get(r.status, 0) + 1
    return {
        "total": len(rows),
        "by_pack": by_pack,
        "by_status": by_status,
    }
