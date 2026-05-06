"""
APEX — Custom Role Builder
===========================
Lets tenants define their own roles beyond the built-in 10
(guest, registered_user, client_user, ..., super_admin). E.g., a tenant
might want a "Junior Bookkeeper" role with read-only access to most
modules + write access only to journal entries.

Design:
- Permission catalog: a curated list of atomic permissions like
  `read:invoices`, `write:journal_entry`, `admin:approvals`.
  Same convention as API key scopes (Wave 1F Phase X) — one vocabulary
  across both human users (custom roles) and machines (API keys).
- CustomRole: id, name_ar, name_en, description, permissions[], tenant_id,
  created_by, audit fields. Tenant-scoped (each tenant's custom roles
  are isolated).
- Assignment: user_role_assignments map (user_id × tenant_id → role_id[]).
  A user can have built-in roles + multiple custom roles concurrently.

API:
    list_permissions(category)
    create_role(tenant_id, name_ar, ...)
    update_role / delete_role
    assign_role(user_id, role_id)
    revoke_role(user_id, role_id)
    effective_permissions(user_id, tenant_id)  → set of permission strings

Reference: Layer 9.5 of architecture/FUTURE_ROADMAP.md.
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

logger = logging.getLogger(__name__)


# ── Permission Catalog ────────────────────────────────────────────


@dataclass(frozen=True)
class Permission:
    id: str  # e.g. "read:invoices"
    label_ar: str
    label_en: str
    category: str  # finance | hr | compliance | analytics | platform | admin


_PERMISSIONS: list[Permission] = [
    # ─ Finance / Sales ─
    Permission("read:invoices", "عرض الفواتير", "Read invoices", "finance"),
    Permission("write:invoices", "إنشاء/تعديل فواتير", "Write invoices", "finance"),
    Permission("post:invoices", "ترحيل فواتير", "Post invoices", "finance"),
    Permission("read:customers", "عرض العملاء", "Read customers", "finance"),
    Permission("write:customers", "تعديل العملاء", "Write customers", "finance"),
    Permission("read:bills", "عرض فواتير الموردين", "Read bills", "finance"),
    Permission("write:bills", "إنشاء فواتير شراء", "Write bills", "finance"),
    Permission("post:bills", "ترحيل فواتير الشراء", "Post bills", "finance"),
    Permission("read:vendors", "عرض الموردين", "Read vendors", "finance"),
    Permission("write:vendors", "تعديل الموردين", "Write vendors", "finance"),
    Permission("read:payments", "عرض الدفعات", "Read payments", "finance"),
    Permission("write:payments", "إنشاء دفعات", "Write payments", "finance"),
    # ─ Accounting ─
    Permission("read:coa", "عرض شجرة الحسابات", "Read COA", "finance"),
    Permission("write:coa", "تعديل شجرة الحسابات", "Write COA", "finance"),
    Permission("read:journal_entries", "عرض القيود", "Read journal entries", "finance"),
    Permission("write:journal_entries", "إنشاء قيود", "Write journal entries", "finance"),
    Permission("post:journal_entries", "ترحيل القيود", "Post journal entries", "finance"),
    Permission("reverse:journal_entries", "عكس القيود", "Reverse journal entries", "finance"),
    Permission("close:periods", "إقفال الفترات", "Close fiscal periods", "finance"),
    # ─ HR ─
    Permission("read:employees", "عرض الموظفين", "Read employees", "hr"),
    Permission("write:employees", "تعديل الموظفين", "Write employees", "hr"),
    Permission("read:payroll", "عرض الرواتب", "Read payroll", "hr"),
    Permission("run:payroll", "تشغيل الرواتب", "Run payroll", "hr"),
    Permission("read:expense_reports", "عرض تقارير المصاريف", "Read expense reports", "hr"),
    Permission("approve:expense_reports", "اعتماد المصاريف", "Approve expenses", "hr"),
    # ─ Compliance ─
    Permission("read:zatca", "عرض ZATCA", "Read ZATCA", "compliance"),
    Permission("submit:zatca", "إرسال لـ ZATCA", "Submit to ZATCA", "compliance"),
    Permission("read:vat_returns", "عرض إقرارات VAT", "Read VAT returns", "compliance"),
    Permission("file:vat_returns", "تقديم إقرارات VAT", "File VAT returns", "compliance"),
    Permission("read:audit_log", "عرض سجل التدقيق", "Read audit log", "compliance"),
    # ─ Analytics ─
    Permission("read:reports", "عرض التقارير", "Read reports", "analytics"),
    Permission("export:reports", "تصدير التقارير", "Export reports", "analytics"),
    Permission("read:budgets", "عرض الموازنات", "Read budgets", "analytics"),
    Permission("write:budgets", "تعديل الموازنات", "Write budgets", "analytics"),
    Permission("read:forecast", "عرض التوقعات", "Read forecasts", "analytics"),
    # ─ Platform ─
    Permission("read:approvals", "عرض الموافقات", "Read approvals", "platform"),
    Permission("decide:approvals", "اتخاذ قرار في الموافقات", "Decide approvals", "platform"),
    Permission("read:comments", "عرض التعليقات", "Read comments", "platform"),
    Permission("write:comments", "كتابة تعليقات", "Write comments", "platform"),
    Permission("read:notifications", "عرض الإشعارات", "Read notifications", "platform"),
    Permission("write:notifications", "إنشاء إشعارات", "Write notifications", "platform"),
    # ─ Admin ─
    Permission("admin:users", "إدارة المستخدمين", "Manage users", "admin"),
    Permission("admin:roles", "إدارة الأدوار", "Manage roles", "admin"),
    Permission("admin:approvals", "إعدادات الموافقات", "Manage approvals", "admin"),
    Permission("admin:workflow", "إدارة محرّك الأتمتة", "Manage workflow engine", "admin"),
    Permission("admin:webhooks", "إدارة الـ Webhooks", "Manage webhooks", "admin"),
    Permission("admin:api_keys", "إدارة مفاتيح الـ API", "Manage API keys", "admin"),
    Permission("admin:modules", "إدارة الوحدات", "Manage modules", "admin"),
    Permission("admin:tenant_settings", "إعدادات المستأجر", "Manage tenant settings", "admin"),
    Permission("admin:billing", "الفواتير والاشتراكات", "Billing & subscriptions", "admin"),
    # ─ Dashboard (DASH-1, Sprint 16) ─
    Permission("read:dashboard", "عرض الداشبورد", "View dashboard", "platform"),
    Permission("customize:dashboard", "تخصيص داشبوردي", "Customize own dashboard", "platform"),
    Permission("manage:dashboard_role", "إدارة داشبورد الأدوار", "Manage role dashboards", "admin"),
    Permission("lock:dashboard", "قفل تخطيط الداشبورد", "Lock dashboard layout", "admin"),
]

_PERM_BY_ID = {p.id: p for p in _PERMISSIONS}


def list_permissions(category: Optional[str] = None) -> list[Permission]:
    if category is None:
        return list(_PERMISSIONS)
    return [p for p in _PERMISSIONS if p.category == category]


def is_known_permission(p: str) -> bool:
    return p in _PERM_BY_ID or p == "*"


# ── CustomRole + Assignments ─────────────────────────────────────


@dataclass
class CustomRole:
    id: str
    tenant_id: str
    name_ar: str
    name_en: Optional[str]
    description: Optional[str]
    permissions: list[str] = field(default_factory=list)
    enabled: bool = True
    created_by: Optional[str] = None  # user_id
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


@dataclass
class Assignment:
    user_id: str
    tenant_id: str
    role_id: str
    assigned_by: Optional[str]
    assigned_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


# ── Storage ──────────────────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get("CUSTOM_ROLES_PATH", os.path.join(_DATA_DIR, "custom_roles.json"))

_LOCK = threading.RLock()
_ROLES: dict[str, CustomRole] = {}
_ASSIGNMENTS: list[Assignment] = []


def _load() -> None:
    global _ROLES, _ASSIGNMENTS
    with _LOCK:
        if not os.path.exists(_PATH):
            _ROLES = {}
            _ASSIGNMENTS = []
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _ROLES = {r["id"]: CustomRole(**r) for r in raw.get("roles", [])}
            _ASSIGNMENTS = [Assignment(**a) for a in raw.get("assignments", [])]
            logger.info(
                "Loaded %d custom roles, %d assignments",
                len(_ROLES),
                len(_ASSIGNMENTS),
            )
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load custom_roles: %s", e)
            _ROLES = {}
            _ASSIGNMENTS = []


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "roles": [asdict(r) for r in _ROLES.values()],
            "assignments": [asdict(a) for a in _ASSIGNMENTS],
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


# ── Roles CRUD ────────────────────────────────────────────────


def create_role(
    *,
    tenant_id: str,
    name_ar: str,
    name_en: Optional[str] = None,
    description: Optional[str] = None,
    permissions: Optional[list[str]] = None,
    created_by: Optional[str] = None,
) -> CustomRole:
    if not name_ar.strip():
        raise ValueError("name_ar is required")
    perms = list(permissions or [])
    unknown = [p for p in perms if not is_known_permission(p)]
    if unknown:
        raise ValueError(f"Unknown permissions: {', '.join(unknown)}")

    r = CustomRole(
        id=str(uuid.uuid4()),
        tenant_id=tenant_id,
        name_ar=name_ar.strip(),
        name_en=(name_en or "").strip() or None,
        description=description,
        permissions=perms,
        created_by=created_by,
    )
    with _LOCK:
        _ROLES[r.id] = r
        _save()

    emit(
        "role.created",
        {
            "role_id": r.id,
            "tenant_id": tenant_id,
            "name_ar": r.name_ar,
            "permission_count": len(perms),
        },
        source="custom_roles",
    )
    return r


def list_roles(tenant_id: str) -> list[CustomRole]:
    with _LOCK:
        return sorted(
            [r for r in _ROLES.values() if r.tenant_id == tenant_id],
            key=lambda r: r.created_at,
        )


def get_role(role_id: str) -> Optional[CustomRole]:
    with _LOCK:
        return _ROLES.get(role_id)


def update_role(
    role_id: str,
    *,
    name_ar: Optional[str] = None,
    name_en: Optional[str] = None,
    description: Optional[str] = None,
    permissions: Optional[list[str]] = None,
    enabled: Optional[bool] = None,
) -> Optional[CustomRole]:
    with _LOCK:
        r = _ROLES.get(role_id)
        if not r:
            return None
        if name_ar is not None:
            r.name_ar = name_ar
        if name_en is not None:
            r.name_en = name_en or None
        if description is not None:
            r.description = description
        if permissions is not None:
            unknown = [p for p in permissions if not is_known_permission(p)]
            if unknown:
                raise ValueError(f"Unknown permissions: {', '.join(unknown)}")
            r.permissions = list(permissions)
        if enabled is not None:
            r.enabled = enabled
        r.updated_at = datetime.now(timezone.utc).isoformat()
        _save()
        return r


def delete_role(role_id: str) -> bool:
    with _LOCK:
        if role_id not in _ROLES:
            return False
        del _ROLES[role_id]
        # Clean up assignments
        _ASSIGNMENTS[:] = [a for a in _ASSIGNMENTS if a.role_id != role_id]
        _save()
    emit(
        "role.deleted",
        {"role_id": role_id},
        source="custom_roles",
    )
    return True


# ── Assignments ───────────────────────────────────────────────


def assign_role(user_id: str, role_id: str, *, assigned_by: Optional[str] = None) -> bool:
    with _LOCK:
        r = _ROLES.get(role_id)
        if not r:
            return False
        # Idempotent: don't add a duplicate.
        for a in _ASSIGNMENTS:
            if a.user_id == user_id and a.role_id == role_id and a.tenant_id == r.tenant_id:
                return True
        _ASSIGNMENTS.append(
            Assignment(
                user_id=user_id,
                tenant_id=r.tenant_id,
                role_id=role_id,
                assigned_by=assigned_by,
            )
        )
        _save()
    emit(
        "role.assigned",
        {
            "user_id": user_id,
            "role_id": role_id,
            "tenant_id": r.tenant_id,
            "assigned_by": assigned_by,
        },
        source="custom_roles",
    )
    return True


def revoke_role(user_id: str, role_id: str) -> bool:
    with _LOCK:
        before = len(_ASSIGNMENTS)
        _ASSIGNMENTS[:] = [
            a for a in _ASSIGNMENTS if not (a.user_id == user_id and a.role_id == role_id)
        ]
        if len(_ASSIGNMENTS) == before:
            return False
        _save()
    emit(
        "role.revoked",
        {"user_id": user_id, "role_id": role_id},
        source="custom_roles",
    )
    return True


def list_user_roles(user_id: str, tenant_id: str) -> list[CustomRole]:
    with _LOCK:
        ids = {
            a.role_id
            for a in _ASSIGNMENTS
            if a.user_id == user_id and a.tenant_id == tenant_id
        }
        return [_ROLES[rid] for rid in ids if rid in _ROLES and _ROLES[rid].enabled]


def effective_permissions(user_id: str, tenant_id: str) -> set[str]:
    """Resolve every permission the user has via custom roles (union)."""
    out: set[str] = set()
    for r in list_user_roles(user_id, tenant_id):
        for p in r.permissions:
            out.add(p)
    return out


def has_permission(user_id: str, tenant_id: str, required: str) -> bool:
    """Check if the user (via custom roles) has `required` permission.

    Same wildcard semantics as API key scopes:
        "*" superuser → always True
        "namespace:*" matches any "namespace:foo"
        exact match
    """
    perms = effective_permissions(user_id, tenant_id)
    if "*" in perms or required in perms:
        return True
    namespace = required.split(":")[0]
    if f"{namespace}:*" in perms:
        return True
    return False


# Initial load.
_load()


def stats() -> dict:
    with _LOCK:
        return {
            "permissions_total": len(_PERMISSIONS),
            "roles_total": len(_ROLES),
            "assignments_total": len(_ASSIGNMENTS),
            "tenants_with_custom_roles": len({r.tenant_id for r in _ROLES.values()}),
            "storage_path": _PATH,
        }
