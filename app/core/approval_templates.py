"""APEX — Approval Chain Templates.

Wave 1B shipped a single-stage approval primitive (one title + N
parallel approvers). Real-world finance approvals are multi-stage:
Manager → Finance Director → CFO. Wave 1V Phase CCC adds reusable
templates so admins instantiate common chains in one click instead
of hand-crafting each request.

Template anatomy:
    id, name_ar, name_en, category, description_ar, icon
    object_type (default "invoice"|"bill"|"je"|...),
    auto_trigger (optional dict — describes when to auto-create from
                  a workflow rule)
    stages: list[Stage]
        - sequence (int)
        - kind: "all_required" | "any_one" | "majority"
        - title_ar (per-stage label)
        - approver_user_ids (resolved at instantiation time —
            placeholders like "{cfo}" expand from a parameter map)

Pre-seeded library: 7 common patterns (CFO sign-off, vendor
onboarding, material change, period close, budget variance, high-risk
txn, document amendment).

Storage: JSON-as-DB at $APEX_DATA_DIR/approval_templates.json. Atomic
temp+replace + RLock guards.

Wave 1V Phase CCC.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "APPROVAL_TEMPLATES_PATH",
    os.path.join(_DATA_DIR, "approval_templates.json"),
)
_LOCK = threading.RLock()


# ── Models ─────────────────────────────────────────────────────


@dataclass
class Stage:
    sequence: int
    kind: str  # "all_required" | "any_one" | "majority"
    title_ar: str
    approver_user_ids: list[str] = field(default_factory=list)
    notes_ar: Optional[str] = None


@dataclass
class ApprovalTemplate:
    id: str
    name_ar: str
    name_en: str
    category: str  # finance | procurement | hr | compliance | ops
    description_ar: str
    icon: str = "task_alt"
    object_type: Optional[str] = None
    auto_trigger: Optional[dict[str, Any]] = None
    stages: list[Stage] = field(default_factory=list)
    is_builtin: bool = False
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    use_count: int = 0


_TEMPLATES: dict[str, ApprovalTemplate] = {}


# ── Pre-seeded library (7 templates) ────────────────────────────


_BUILTIN_LIBRARY: list[dict[str, Any]] = [
    {
        "id": "cfo-signoff-100k",
        "name_ar": "اعتماد المدير المالي للمعاملات > 100 ألف",
        "name_en": "CFO sign-off (>100K)",
        "category": "finance",
        "description_ar": (
            "أيّ معاملة تتجاوز 100,000 ر.س. تتطلّب اعتماد مدير القسم ثم المدير المالي."
        ),
        "icon": "account_balance",
        "object_type": "invoice",
        "auto_trigger": {"event": "invoice.posted", "field": "total_amount", "op": "gte", "value": 100000},
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "اعتماد مدير القسم",
             "approver_user_ids": ["{department_head}"]},
            {"sequence": 2, "kind": "all_required", "title_ar": "اعتماد المدير المالي",
             "approver_user_ids": ["{cfo}"]},
        ],
    },
    {
        "id": "new-vendor-onboarding",
        "name_ar": "استقبال مورّد جديد",
        "name_en": "New vendor onboarding",
        "category": "procurement",
        "description_ar": (
            "ربط مورّد جديد يتطلّب فحص الامتثال + اعتماد المشتريات + اعتماد المالية."
        ),
        "icon": "business_center",
        "object_type": "vendor",
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "فحص الامتثال (ZATCA + AML)",
             "approver_user_ids": ["{compliance_officer}"]},
            {"sequence": 2, "kind": "any_one", "title_ar": "اعتماد المشتريات",
             "approver_user_ids": ["{procurement_manager}", "{ops_director}"]},
            {"sequence": 3, "kind": "all_required", "title_ar": "اعتماد المالية",
             "approver_user_ids": ["{cfo}"]},
        ],
    },
    {
        "id": "material-change",
        "name_ar": "تعديل جوهري على قيد مُرحَّل",
        "name_en": "Material change to posted entry",
        "category": "compliance",
        "description_ar": (
            "تعديل قيد بعد ترحيله يتطلّب موافقة المراجع الداخلي والمدير المالي."
        ),
        "icon": "edit_note",
        "object_type": "je",
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "مراجعة المدقّق الداخلي",
             "approver_user_ids": ["{internal_auditor}"]},
            {"sequence": 2, "kind": "all_required", "title_ar": "اعتماد المدير المالي",
             "approver_user_ids": ["{cfo}"]},
        ],
    },
    {
        "id": "period-close-signoff",
        "name_ar": "اعتماد إقفال الفترة",
        "name_en": "Period close sign-off",
        "category": "finance",
        "description_ar": (
            "اعتماد رسمي لإقفال الفترة المحاسبية بعد اكتمال جميع مهام checklist الإقفال."
        ),
        "icon": "event_note",
        "object_type": "period_close",
        "auto_trigger": {"event": "period_close.tasks_completed"},
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "مراجعة المحاسب الرئيسي",
             "approver_user_ids": ["{chief_accountant}"]},
            {"sequence": 2, "kind": "all_required", "title_ar": "اعتماد المدير المالي",
             "approver_user_ids": ["{cfo}"]},
            {"sequence": 3, "kind": "all_required", "title_ar": "توقيع الرئيس التنفيذي",
             "approver_user_ids": ["{ceo}"]},
        ],
    },
    {
        "id": "budget-variance-review",
        "name_ar": "مراجعة انحراف الموازنة",
        "name_en": "Budget variance review",
        "category": "finance",
        "description_ar": (
            "أيّ بند يتجاوز الموازنة بنسبة 10% يتطلّب مراجعة من رئيس القسم."
        ),
        "icon": "trending_up",
        "object_type": "budget_line",
        "stages": [
            {"sequence": 1, "kind": "any_one", "title_ar": "مراجعة رئيس القسم أو نائبه",
             "approver_user_ids": ["{department_head}", "{deputy_head}"]},
            {"sequence": 2, "kind": "all_required", "title_ar": "اعتماد مدير الموازنات",
             "approver_user_ids": ["{budget_director}"]},
        ],
    },
    {
        "id": "high-risk-txn",
        "name_ar": "معاملة عالية الخطورة",
        "name_en": "High-risk transaction",
        "category": "compliance",
        "description_ar": (
            "معاملة مع طرف ذي خطورة (PEP / sanctions hit / high-risk country)."
        ),
        "icon": "warning",
        "object_type": "payment",
        "auto_trigger": {"event": "anomaly.detected", "field": "severity", "op": "in", "value": ["high", "critical"]},
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "تقييم مدير الامتثال",
             "approver_user_ids": ["{compliance_officer}"]},
            {"sequence": 2, "kind": "all_required", "title_ar": "اعتماد المدير المالي",
             "approver_user_ids": ["{cfo}"]},
            {"sequence": 3, "kind": "all_required", "title_ar": "توقيع الرئيس التنفيذي",
             "approver_user_ids": ["{ceo}"]},
        ],
    },
    {
        "id": "document-amendment",
        "name_ar": "تعديل مستند رسمي",
        "name_en": "Official document amendment",
        "category": "ops",
        "description_ar": (
            "تعديل عقد أو وثيقة موقّعة يتطلّب تأكيد طرفين قبل التطبيق."
        ),
        "icon": "description",
        "object_type": "document",
        "stages": [
            {"sequence": 1, "kind": "all_required", "title_ar": "اعتماد طالب التعديل",
             "approver_user_ids": ["{requester}"]},
            {"sequence": 2, "kind": "majority", "title_ar": "اعتماد الأطراف المعنيّة",
             "approver_user_ids": ["{stakeholder_1}", "{stakeholder_2}", "{stakeholder_3}"]},
            {"sequence": 3, "kind": "all_required", "title_ar": "اعتماد القانوني",
             "approver_user_ids": ["{legal}"]},
        ],
    },
]


# ── Persistence ────────────────────────────────────────────────


def _load() -> None:
    global _TEMPLATES
    with _LOCK:
        if not os.path.exists(_PATH):
            _TEMPLATES = {}
        else:
            try:
                with open(_PATH, encoding="utf-8") as f:
                    raw = json.load(f)
                _TEMPLATES = {
                    t["id"]: ApprovalTemplate(
                        **{**t, "stages": [Stage(**s) for s in t.get("stages", [])]}
                    )
                    for t in raw.get("templates", [])
                }
            except Exception as e:  # noqa: BLE001
                logger.error("Failed to load approval templates: %s", e)
                _TEMPLATES = {}
        # Ensure builtins are present (idempotent).
        for spec in _BUILTIN_LIBRARY:
            if spec["id"] in _TEMPLATES:
                continue
            t = ApprovalTemplate(
                **{
                    **spec,
                    "stages": [Stage(**s) for s in spec["stages"]],
                    "is_builtin": True,
                }
            )
            _TEMPLATES[t.id] = t
        _save_unlocked()


def _save_unlocked() -> None:
    payload = {
        "version": 1,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "templates": [_serialize(t) for t in _TEMPLATES.values()],
    }
    tmp = _PATH + ".tmp"
    os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)
    except Exception as e:  # noqa: BLE001
        logger.error("Failed to save approval templates: %s", e)


def _save() -> None:
    with _LOCK:
        _save_unlocked()


def _serialize(t: ApprovalTemplate) -> dict:
    out = asdict(t)
    return out


_load()


# ── CRUD ───────────────────────────────────────────────────────


def list_templates(*, category: Optional[str] = None) -> list[dict]:
    with _LOCK:
        rows = list(_TEMPLATES.values())
    if category:
        rows = [r for r in rows if r.category == category]
    rows.sort(key=lambda r: (not r.is_builtin, r.category, r.name_ar))
    return [_serialize(r) for r in rows]


def get_template(template_id: str) -> Optional[dict]:
    with _LOCK:
        t = _TEMPLATES.get(template_id)
        return _serialize(t) if t else None


def create_template(
    *,
    name_ar: str,
    name_en: str,
    category: str,
    description_ar: str,
    stages: list[dict],
    object_type: Optional[str] = None,
    icon: str = "task_alt",
    auto_trigger: Optional[dict] = None,
) -> dict:
    if not stages:
        raise ValueError("at least one stage is required")
    t = ApprovalTemplate(
        id=str(uuid.uuid4()),
        name_ar=name_ar,
        name_en=name_en,
        category=category,
        description_ar=description_ar,
        icon=icon,
        object_type=object_type,
        auto_trigger=auto_trigger,
        stages=[Stage(**s) for s in stages],
        is_builtin=False,
    )
    with _LOCK:
        _TEMPLATES[t.id] = t
        _save_unlocked()
    emit(
        "approval_template.created",
        {"id": t.id, "name_ar": t.name_ar, "category": t.category},
        source="approval_templates",
    )
    return _serialize(t)


def delete_template(template_id: str) -> bool:
    with _LOCK:
        t = _TEMPLATES.get(template_id)
        if t is None:
            return False
        if t.is_builtin:
            raise ValueError("built-in templates cannot be deleted")
        del _TEMPLATES[template_id]
        _save_unlocked()
    emit(
        "approval_template.deleted",
        {"id": template_id},
        source="approval_templates",
    )
    return True


# ── Apply template ─────────────────────────────────────────────


def apply_template(
    template_id: str,
    *,
    title_ar: str,
    body: Optional[str] = None,
    object_id: Optional[str] = None,
    parameters: Optional[dict[str, str]] = None,
    requested_by: Optional[str] = None,
    tenant_id: Optional[str] = None,
) -> dict:
    """Materialize a template into actual approval records.

    Each stage becomes an approval. Stages run sequentially: stage N+1
    is created only after stage N is completed (we represent this by
    emitting follow-up approvals tied to the upstream events). For the
    initial implementation we create only the first stage; the
    workflow engine + listeners can chain the rest by listening for
    `approval.approved` and triggering the next stage.

    Returns:
        {
            "template_id": str,
            "first_stage_approval_id": str,
            "stages_total": int,
        }
    """
    with _LOCK:
        t = _TEMPLATES.get(template_id)
        if t is None:
            raise ValueError("template not found")
    if not t.stages:
        raise ValueError("template has no stages")
    parameters = parameters or {}

    # Resolve placeholders in approver_user_ids.
    def resolve(uid: str) -> str:
        if uid.startswith("{") and uid.endswith("}"):
            key = uid[1:-1]
            return parameters.get(key, uid)  # leave placeholder if not provided
        return uid

    first_stage = sorted(t.stages, key=lambda s: s.sequence)[0]
    resolved_approvers = [resolve(u) for u in first_stage.approver_user_ids]
    # Drop unresolved placeholders to avoid blocking the chain.
    resolved_approvers = [u for u in resolved_approvers if not (u.startswith("{") and u.endswith("}"))]
    if not resolved_approvers:
        raise ValueError(
            "first stage has no resolvable approvers — supply parameters dict "
            "with values for placeholders like {cfo}"
        )

    try:
        from app.core.approvals import create_approval
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(f"approvals service unavailable: {e}")

    approval = create_approval(
        title_ar=title_ar,
        body=body,
        object_type=t.object_type,
        object_id=object_id,
        approver_user_ids=resolved_approvers,
        requested_by=requested_by,
        tenant_id=tenant_id,
        meta={
            "template_id": t.id,
            "template_name_ar": t.name_ar,
            "stage_sequence": first_stage.sequence,
            "stage_kind": first_stage.kind,
            "stages_total": len(t.stages),
            "remaining_stages": [
                {
                    "sequence": s.sequence,
                    "kind": s.kind,
                    "title_ar": s.title_ar,
                    "approver_user_ids": [resolve(u) for u in s.approver_user_ids],
                }
                for s in sorted(t.stages, key=lambda x: x.sequence)
                if s.sequence > first_stage.sequence
            ],
        },
    )
    # Increment use count.
    with _LOCK:
        if template_id in _TEMPLATES:
            _TEMPLATES[template_id].use_count += 1
            _save_unlocked()
    emit(
        "approval_template.applied",
        {
            "template_id": t.id,
            "approval_id": getattr(approval, "id", None) or (approval.get("id") if isinstance(approval, dict) else None),
            "title_ar": title_ar,
            "tenant_id": tenant_id,
            "stages_total": len(t.stages),
        },
        source="approval_templates",
    )
    from dataclasses import asdict as _ad
    return {
        "template_id": t.id,
        "approval": _ad(approval) if hasattr(approval, "__dataclass_fields__") else approval,
        "stages_total": len(t.stages),
    }


def stats() -> dict:
    with _LOCK:
        rows = list(_TEMPLATES.values())
    by_cat: dict[str, int] = {}
    for r in rows:
        by_cat[r.category] = by_cat.get(r.category, 0) + 1
    builtin = sum(1 for r in rows if r.is_builtin)
    custom = sum(1 for r in rows if not r.is_builtin)
    total_use = sum(r.use_count for r in rows)
    most_used = sorted(rows, key=lambda x: -x.use_count)[:5]
    return {
        "total": len(rows),
        "builtin": builtin,
        "custom": custom,
        "total_uses": total_use,
        "by_category": by_cat,
        "most_used": [
            {"id": r.id, "name_ar": r.name_ar, "use_count": r.use_count}
            for r in most_used
        ],
    }
