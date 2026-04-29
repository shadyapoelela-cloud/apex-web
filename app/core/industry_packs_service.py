"""APEX — Industry Pack assignment service.

The pure-data registry at `app/industry_packs/registry.py` defines five
sector packs (F&B, Construction, Medical, Logistics, Services), each
containing a curated COA chart + dashboard widget set + recommended
workflow ids. This module wires that registry to per-tenant state:

    apply_pack(tenant_id, pack_id) → records assignment, emits
                                     `industry_pack.applied` event
    get_assignment(tenant_id)      → which pack the tenant has, when,
                                     by whom
    list_assignments()             → admin overview of every assignment

Storage: `industry_pack_assignments.json` at $APEX_DATA_DIR — same
JSON-as-DB pattern as suggestions / workflow rules / approvals. Atomic
temp+replace writes, RLock-guarded.

A workflow rule listening for `industry_pack.applied` can chain further
provisioning (e.g. seed COA accounts via Phase 4 service, register
dashboard widgets, etc.) without coupling those services to this module.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Optional

from app.core.event_bus import emit
from app.industry_packs.registry import IndustryPack, get_pack, list_packs

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "INDUSTRY_PACK_ASSIGNMENTS_PATH",
    os.path.join(_DATA_DIR, "industry_pack_assignments.json"),
)
_LOCK = threading.RLock()


@dataclass
class PackAssignment:
    id: str
    tenant_id: str
    pack_id: str
    applied_by: Optional[str] = None
    applied_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    coa_seeded: bool = False
    widgets_provisioned: bool = False
    notes: Optional[str] = None


# tenant_id → PackAssignment (one active assignment per tenant)
_STORE: dict[str, PackAssignment] = {}


def _load() -> None:
    global _STORE
    with _LOCK:
        if not os.path.exists(_PATH):
            _STORE = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _STORE = {a["tenant_id"]: PackAssignment(**a) for a in raw.get("assignments", [])}
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load industry pack assignments: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "assignments": [asdict(a) for a in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


_load()


# ── Pack catalog (proxy to the pure-data registry) ──────────────


def serialize_pack(p: IndustryPack, *, include_coa: bool = False) -> dict:
    out = {
        "id": p.id,
        "name_ar": p.name_ar,
        "name_en": p.name_en,
        "description": p.description,
        "coa_account_count": len(p.coa_accounts),
        "dashboard_widget_count": len(p.dashboard_widgets),
        "workflow_count": len(p.workflows),
        "workflows": list(p.workflows),
    }
    if include_coa:
        out["coa_accounts"] = [
            {
                "code": a.code,
                "name_ar": a.name_ar,
                "name_en": a.name_en,
                "account_type": a.account_type,
                "parent_code": a.parent_code,
            }
            for a in p.coa_accounts
        ]
        out["dashboard_widgets"] = [
            {
                "id": w.id,
                "title_ar": w.title_ar,
                "kind": w.kind,
                "metric": w.metric,
            }
            for w in p.dashboard_widgets
        ]
    return out


def list_pack_summaries() -> list[dict]:
    return [serialize_pack(p) for p in list_packs()]


def get_pack_detail(pack_id: str) -> Optional[dict]:
    p = get_pack(pack_id)
    return serialize_pack(p, include_coa=True) if p else None


# ── Assignment API ──────────────────────────────────────────────


def apply_pack(
    tenant_id: str,
    pack_id: str,
    *,
    applied_by: Optional[str] = None,
    notes: Optional[str] = None,
) -> PackAssignment:
    """Record that `tenant_id` is now using `pack_id`.

    Idempotent on (tenant_id, pack_id): re-applying the same pack
    refreshes the timestamp but doesn't duplicate. Switching packs
    overwrites the previous assignment.
    """
    if get_pack(pack_id) is None:
        raise ValueError(f"unknown pack: {pack_id}")
    with _LOCK:
        existing = _STORE.get(tenant_id)
        if existing and existing.pack_id == pack_id:
            existing.applied_at = datetime.now(timezone.utc).isoformat()
            if notes is not None:
                existing.notes = notes
            _save()
            assignment = existing
            emitted = "industry_pack.refreshed"
        else:
            assignment = PackAssignment(
                id=str(uuid.uuid4()),
                tenant_id=tenant_id,
                pack_id=pack_id,
                applied_by=applied_by,
                notes=notes,
            )
            _STORE[tenant_id] = assignment
            _save()
            emitted = "industry_pack.applied"
    p = get_pack(pack_id)
    emit(
        emitted,
        {
            "tenant_id": tenant_id,
            "pack_id": pack_id,
            "pack_name_ar": p.name_ar if p else pack_id,
            "applied_by": applied_by,
            "coa_account_count": len(p.coa_accounts) if p else 0,
            "widget_count": len(p.dashboard_widgets) if p else 0,
        },
        source="industry_packs",
    )
    return assignment


def remove_assignment(tenant_id: str) -> bool:
    with _LOCK:
        if tenant_id not in _STORE:
            return False
        prev = _STORE.pop(tenant_id)
        _save()
    emit(
        "industry_pack.removed",
        {"tenant_id": tenant_id, "pack_id": prev.pack_id},
        source="industry_packs",
    )
    return True


def get_assignment(tenant_id: str) -> Optional[dict]:
    with _LOCK:
        a = _STORE.get(tenant_id)
        if not a:
            return None
        out = asdict(a)
    p = get_pack(a.pack_id)
    if p:
        out["pack_name_ar"] = p.name_ar
        out["pack_name_en"] = p.name_en
    return out


def list_assignments() -> list[dict]:
    with _LOCK:
        rows = [asdict(a) for a in _STORE.values()]
    for r in rows:
        p = get_pack(r["pack_id"])
        if p:
            r["pack_name_ar"] = p.name_ar
            r["pack_name_en"] = p.name_en
    return rows


def stats() -> dict:
    with _LOCK:
        rows = list(_STORE.values())
    by_pack: dict[str, int] = {}
    for r in rows:
        by_pack[r.pack_id] = by_pack.get(r.pack_id, 0) + 1
    return {
        "tenants_assigned": len(rows),
        "packs_total": len(list_packs()),
        "by_pack": by_pack,
    }


def mark_provisioned(tenant_id: str, *, coa: bool = False, widgets: bool = False) -> bool:
    with _LOCK:
        a = _STORE.get(tenant_id)
        if not a:
            return False
        if coa:
            a.coa_seeded = True
        if widgets:
            a.widgets_provisioned = True
        _save()
    return True
