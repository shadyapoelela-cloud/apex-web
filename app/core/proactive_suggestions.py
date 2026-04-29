"""
APEX — Proactive Suggestions Engine
====================================
Watches events on the bus and surfaces suggestions when patterns
indicate the admin/user could benefit from automation, configuration,
or attention.

Examples:
- "I notice you have 5 overdue invoices in the last 7 days. Want me to
   install the `overdue-invoice-slack` workflow template?"
- "ZATCA rejected 3 invoices today. Install zatca-rejected-alert template?"
- "You haven't enabled bank reconciliation for the last 30 days. Want a
   workflow rule to remind you weekly?"

Design:
- Detector functions register at module import. Each detector inspects
  a sliding window of the in-memory event buffer + emits
  `suggestion.proposed` when a pattern matches. Idempotent: a
  detector won't fire the same suggestion twice without dismissal.
- Suggestion store: JSON file. Each Suggestion has id, code, severity,
  title, body, action ("install template" / "review" / "configure"),
  target (template_id or route), tenant_id, status (proposed |
  dismissed | applied), created_at.
- Users see open suggestions in their inbox (`/api/v1/suggestions`),
  apply or dismiss them. Workflow rules can listen for
  `suggestion.proposed` and route via Slack/Teams.

Reference: Layer 7.11 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from collections import defaultdict
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Callable, Optional

from app.core.event_bus import emit, recent_events, register_listener

logger = logging.getLogger(__name__)


# ── Storage ──────────────────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get("SUGGESTIONS_PATH", os.path.join(_DATA_DIR, "suggestions.json"))

_LOCK = threading.RLock()


# ── Models ───────────────────────────────────────────────────────


@dataclass
class Suggestion:
    id: str
    code: str  # detector signature, e.g. "overdue_invoices_5_in_7d"
    severity: str  # info | warning | high
    title_ar: str
    body_ar: Optional[str]
    action: str  # "install_template" | "review" | "configure" | "info"
    action_target: Optional[str] = None  # template id or route
    tenant_id: Optional[str] = None
    status: str = "proposed"  # proposed | dismissed | applied
    detected_count: int = 1
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


_STORE: dict[str, Suggestion] = {}


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
            _STORE = {s["id"]: Suggestion(**s) for s in raw.get("suggestions", [])}
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load suggestions: %s", e)
            _STORE = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "suggestions": [asdict(s) for s in _STORE.values()],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── Suggest helper ───────────────────────────────────────────────


def _propose(
    *,
    code: str,
    severity: str,
    title_ar: str,
    body_ar: Optional[str] = None,
    action: str = "info",
    action_target: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> Optional[Suggestion]:
    """Idempotent: if an open suggestion with the same (code, tenant_id)
    already exists, increment detected_count instead of creating a new row.
    """
    with _LOCK:
        for s in _STORE.values():
            if (
                s.code == code
                and s.tenant_id == tenant_id
                and s.status == "proposed"
            ):
                s.detected_count += 1
                s.updated_at = datetime.now(timezone.utc).isoformat()
                _save()
                return None  # already proposed; we just bumped counter

        s = Suggestion(
            id=str(uuid.uuid4()),
            code=code,
            severity=severity,
            title_ar=title_ar,
            body_ar=body_ar,
            action=action,
            action_target=action_target,
            tenant_id=tenant_id,
        )
        _STORE[s.id] = s
        _save()

    emit(
        "suggestion.proposed",
        {
            "suggestion_id": s.id,
            "code": s.code,
            "severity": s.severity,
            "title_ar": s.title_ar,
            "action": s.action,
            "action_target": s.action_target,
            "tenant_id": s.tenant_id,
        },
        source="proactive_suggestions",
    )
    return s


# ── Detectors ────────────────────────────────────────────────────


def _count_recent(name: str, *, since_min: int = 1440, tenant_id: Optional[str] = None) -> int:
    """Count events in the recent-events buffer matching (name, tenant_id)
    within the last `since_min` minutes."""
    cutoff = datetime.now(timezone.utc).timestamp() - since_min * 60
    count = 0
    for e in recent_events(limit=200):
        if e.get("name") != name:
            continue
        if tenant_id and e.get("payload", {}).get("tenant_id") != tenant_id:
            continue
        ts_str = e.get("ts")
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp()
        except Exception:  # noqa: BLE001
            continue
        if ts >= cutoff:
            count += 1
    return count


# ─ Registered detectors ─


@register_listener("invoice.overdue")
def _detect_overdue_cluster(event_name: str, payload: dict) -> None:
    tenant = payload.get("tenant_id")
    n = _count_recent("invoice.overdue", since_min=7 * 24 * 60, tenant_id=tenant)
    if n >= 5:
        _propose(
            code="overdue_invoices_5_in_7d",
            severity="high",
            title_ar=f"⚠️ {n} فواتير متأخرة في آخر 7 أيام",
            body_ar=(
                "نقترح تثبيت قاعدة workflow `overdue-invoice-slack` لإرسال "
                "تنبيه فوري لفريق المتابعة عند تأخر أي فاتورة جديدة."
            ),
            action="install_template",
            action_target="overdue-invoice-slack",
            tenant_id=tenant,
        )


@register_listener("zatca.rejected")
def _detect_zatca_failures(event_name: str, payload: dict) -> None:
    tenant = payload.get("tenant_id")
    n = _count_recent("zatca.rejected", since_min=24 * 60, tenant_id=tenant)
    if n >= 3:
        _propose(
            code="zatca_rejected_3_in_24h",
            severity="high",
            title_ar=f"❌ {n} فواتير ZATCA مرفوضة اليوم",
            body_ar=(
                "ZATCA رفضت عدة فواتير. ثبّت قاعدة `zatca-rejected-alert` "
                "ليُخطَر فريق الامتثال فوراً عند أي رفض جديد."
            ),
            action="install_template",
            action_target="zatca-rejected-alert",
            tenant_id=tenant,
        )


@register_listener("anomaly.detected")
def _detect_anomaly_cluster(event_name: str, payload: dict) -> None:
    severity = payload.get("severity", "low")
    if severity not in ("high", "critical"):
        return
    tenant = payload.get("tenant_id")
    n = _count_recent("anomaly.detected", since_min=24 * 60, tenant_id=tenant)
    if n >= 2:
        _propose(
            code="anomaly_high_2_in_24h",
            severity="high",
            title_ar=f"🚨 {n} حالات شذوذ مالي عالية الخطورة اليوم",
            body_ar=(
                "ثبّت قاعدة `anomaly-high-teams` لإخطار فريق التدقيق على "
                "Teams فوراً عند أي شذوذ مالي عالي الخطورة."
            ),
            action="install_template",
            action_target="anomaly-high-teams",
            tenant_id=tenant,
        )


@register_listener("module.disabled")
def _detect_critical_module_disabled(event_name: str, payload: dict) -> None:
    """If a tenant disables a critical module, propose review."""
    mid = payload.get("module_id")
    tenant = payload.get("tenant_id")
    critical_modules = {
        "core.gl",
        "core.identity",
        "compliance.zatca",
    }
    if mid in critical_modules:
        _propose(
            code=f"critical_module_disabled_{mid}",
            severity="high",
            title_ar=f"⚠️ تم تعطيل وحدة حرجة: {mid}",
            body_ar=(
                "تعطيل هذه الوحدة قد يكسر أجزاء أخرى من المنصة. "
                "راجع قرار التعطيل أو أعد تفعيل الوحدة."
            ),
            action="review",
            action_target="/admin/modules",
            tenant_id=tenant,
        )


@register_listener("user.suspended")
def _detect_user_suspension_pattern(event_name: str, payload: dict) -> None:
    n = _count_recent("user.suspended", since_min=24 * 60)
    if n >= 3:
        _propose(
            code="user_suspensions_3_in_24h",
            severity="warning",
            title_ar=f"👤 {n} حسابات مستخدمين عُلِّقت اليوم",
            body_ar=(
                "تكرّر تعليق حسابات بشكل غير معتاد. راجع سجل التدقيق "
                "للتأكد من عدم وجود نشاط ضار."
            ),
            action="review",
            action_target="/admin/audit",
            tenant_id=None,
        )


# ── Public API ───────────────────────────────────────────────────


def list_suggestions(
    *,
    tenant_id: Optional[str] = None,
    status: Optional[str] = None,
) -> list[Suggestion]:
    with _LOCK:
        rows = list(_STORE.values())
    if tenant_id is not None:
        rows = [s for s in rows if s.tenant_id is None or s.tenant_id == tenant_id]
    if status is not None:
        rows = [s for s in rows if s.status == status]
    rows.sort(key=lambda s: s.created_at, reverse=True)
    return rows


def get_suggestion(suggestion_id: str) -> Optional[Suggestion]:
    with _LOCK:
        return _STORE.get(suggestion_id)


def update_status(suggestion_id: str, new_status: str) -> Optional[Suggestion]:
    if new_status not in ("proposed", "dismissed", "applied"):
        raise ValueError(f"invalid status: {new_status}")
    with _LOCK:
        s = _STORE.get(suggestion_id)
        if not s:
            return None
        s.status = new_status
        s.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
    emit(
        f"suggestion.{new_status}",
        {"suggestion_id": s.id, "code": s.code, "tenant_id": s.tenant_id},
        source="proactive_suggestions",
    )
    return s


def stats() -> dict:
    with _LOCK:
        by_status: dict[str, int] = defaultdict(int)
        by_code: dict[str, int] = defaultdict(int)
        for s in _STORE.values():
            by_status[s.status] += 1
            by_code[s.code] += 1
        return {
            "suggestions_total": len(_STORE),
            "by_status": dict(by_status),
            "by_code": dict(by_code),
            "storage_path": _PATH,
        }


# Initial load.
_load()
