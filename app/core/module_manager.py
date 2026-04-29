"""
APEX — Module Manager
=====================
Per-tenant enable/disable of platform modules. Lets a tenant turn on
just the parts of APEX they need (Odoo-style).

Module catalog: a curated list of major modules with metadata (id, name,
category, default_enabled, requires[], min_plan). The manager stores
*overrides* per tenant — only differences from the defaults — so the
JSON file stays small.

Resolution: `effective_modules(tenant_id)` returns the union of
defaults + tenant overrides, with auto-pruning of modules whose
required dependencies aren't enabled.

Events:
    module.enabled  — tenant turned on a module
    module.disabled — tenant turned off a module

Why this lives in core/:
- It's a cross-cutting capability used by every feature gate
- The module catalog is shared across tenants; only overrides are
  per-tenant

Reference: Layer 8 of architecture/FUTURE_ROADMAP.md.
"""

from __future__ import annotations

import json
import logging
import os
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

from app.core.event_bus import emit

logger = logging.getLogger(__name__)


# ── Catalog ──────────────────────────────────────────────────────


@dataclass(frozen=True)
class ModuleDef:
    id: str
    name_ar: str
    name_en: str
    category: str  # core | finance | ops | hr | compliance | analytics | ai | platform
    description_ar: str
    icon: str  # material icon hint
    default_enabled: bool = False
    requires: tuple[str, ...] = ()
    min_plan: str = "free"  # free | pro | business | enterprise


_CATALOG: list[ModuleDef] = [
    # ─ Core (always enabled) ─
    ModuleDef("core.identity", "الهوية والمصادقة", "Identity & Auth", "core",
              "تسجيل الدخول، الأدوار، 2FA، الجلسات", "person", default_enabled=True),
    ModuleDef("core.coa", "شجرة الحسابات", "Chart of Accounts", "core",
              "بنية حسابات SOCPA/IFRS مع تصنيف ML", "account_tree", default_enabled=True),
    ModuleDef("core.gl", "السجل العام (GL)", "General Ledger", "core",
              "ترحيل القيود + ميزان المراجعة + إقفال الفترات", "book", default_enabled=True,
              requires=("core.coa",)),
    # ─ Finance ─
    ModuleDef("finance.sales_ar", "المبيعات + الذمم المدينة", "Sales + AR", "finance",
              "فواتير + عملاء + تحصيل + أعمار", "receipt_long", default_enabled=True,
              requires=("core.gl",)),
    ModuleDef("finance.purchase_ap", "المشتريات + الذمم الدائنة", "Purchase + AP", "finance",
              "فواتير موردين + ثلاثي المطابقة + سداد", "payments", default_enabled=True,
              requires=("core.gl",)),
    ModuleDef("finance.bank_rec", "التسوية البنكية", "Bank Reconciliation", "finance",
              "Yodlee/Plaid + AI matching", "account_balance",
              requires=("core.gl",), min_plan="pro"),
    ModuleDef("finance.cashflow_forecast", "توقع التدفق النقدي", "Cashflow Forecast", "finance",
              "خوارزمي + ML — راجع Wave 1B Phase I", "trending_up",
              requires=("core.gl",), min_plan="pro"),
    # ─ Ops ─
    ModuleDef("ops.inventory", "المخزون", "Inventory", "ops",
              "أصناف + دفعات + حركة المخازن", "inventory", min_plan="pro"),
    ModuleDef("ops.fixed_assets", "الأصول الثابتة", "Fixed Assets", "ops",
              "سجل + إهلاك تلقائي SL/DB/DDB", "domain", min_plan="pro"),
    ModuleDef("ops.pos", "نقاط البيع (POS)", "Point of Sale", "ops",
              "جلسات + معاملات + إقفال يومي", "point_of_sale",
              requires=("finance.sales_ar",), min_plan="pro"),
    ModuleDef("ops.consolidation", "توحيد المجموعة", "Consolidation", "ops",
              "كيانات متعددة + IFRS 10 + FX", "merge_type",
              requires=("core.gl",), min_plan="business"),
    # ─ HR ─
    ModuleDef("hr.employees", "الموظفون", "Employees", "hr",
              "بيانات + سعودة + حالات", "badge", min_plan="pro"),
    ModuleDef("hr.payroll", "الرواتب + GOSI/WPS", "Payroll", "hr",
              "تشغيل شهري + قيود + WPS file", "payments",
              requires=("hr.employees", "core.gl"), min_plan="pro"),
    ModuleDef("hr.gosi_calc", "حاسبة GOSI/GPSSA", "GOSI Calculator", "hr",
              "10/12% KSA + 5/12.5% UAE", "calculate", default_enabled=True),
    ModuleDef("hr.eosb_calc", "حاسبة EOSB", "EOSB Calculator", "hr",
              "نهاية خدمة KSA Art. 84-85 + UAE Art. 51-52", "logout", default_enabled=True),
    # ─ Compliance ─
    ModuleDef("compliance.zatca", "ZATCA", "ZATCA E-Invoice", "compliance",
              "Phase 2 + CSID + clearance + reporting", "verified_user",
              requires=("finance.sales_ar",), min_plan="pro"),
    ModuleDef("compliance.zakat", "الزكاة", "Zakat", "compliance",
              "حساب وعاء الزكاة + إقرار", "savings", min_plan="pro"),
    ModuleDef("compliance.vat", "ضريبة القيمة المضافة", "VAT Returns", "compliance",
              "إقرار + ربط ZATCA", "receipt", default_enabled=True),
    ModuleDef("compliance.wht", "ضريبة الاستقطاع (WHT)", "Withholding Tax", "compliance",
              "حسابات + إقرار شهري", "gavel", min_plan="pro"),
    ModuleDef("compliance.uae_ct", "ضريبة الشركات UAE", "UAE Corporate Tax", "compliance",
              "9% + SBR + QFZP", "account_balance", min_plan="pro"),
    # ─ Analytics ─
    ModuleDef("analytics.dashboards", "لوحات المؤشرات", "Dashboards", "analytics",
              "KPIs + Health Score + Drill-down", "dashboard", default_enabled=True),
    ModuleDef("analytics.reports", "بانِي التقارير", "Report Builder", "analytics",
              "Drag-drop + جدولة + تصدير PDF/Excel", "analytics", min_plan="pro"),
    ModuleDef("analytics.budgets", "الموازنات", "Budgets + Variance", "analytics",
              "بناء + تحليل انحرافات + تنبيه", "calculate",
              requires=("core.gl",), min_plan="pro"),
    # ─ AI ─
    ModuleDef("ai.copilot", "Copilot AI", "AI Copilot", "ai",
              "محادثة + Tool Use + RAG", "auto_awesome", default_enabled=True),
    ModuleDef("ai.workflow_engine", "محرّك الأتمتة", "Workflow Engine", "ai",
              "قواعد + قوالب + تشغيل تلقائي", "auto_awesome_motion", default_enabled=True),
    ModuleDef("ai.anomaly", "كاشف الشذوذ", "Anomaly Detection", "ai",
              "Live + Batch + workflow integration", "report_problem", min_plan="pro"),
    ModuleDef("ai.receipt_ocr", "OCR الإيصالات", "Receipt OCR", "ai",
              "Claude Vision + استخراج بنود", "document_scanner", default_enabled=True),
    ModuleDef("ai.email_intake", "تحويل البريد لفواتير", "Email-to-Invoice", "ai",
              "IMAP + Vision + workflow rule", "attach_email", min_plan="pro"),
    # ─ Platform ─
    ModuleDef("platform.approvals", "سلاسل الموافقات", "Approval Chains", "platform",
              "متعددة المراحل + audit trail", "task_alt", default_enabled=True),
    ModuleDef("platform.webhooks", "اشتراكات الـ Webhooks", "Webhook Subscriptions", "platform",
              "Push events لأنظمة خارجية + HMAC", "webhook", min_plan="business"),
    ModuleDef("platform.comments", "التعليقات + Mentions", "Comments + Mentions", "platform",
              "نقاش على أي entity + إشعارات", "forum", default_enabled=True),
    ModuleDef("platform.marketplace", "سوق الخدمات", "Service Marketplace", "platform",
              "مزودون + مناقصات + escrow", "storefront", min_plan="pro"),
    ModuleDef("platform.white_label", "العلامة البيضاء", "White-Label", "platform",
              "ثيم مخصص + شعار", "palette", min_plan="enterprise"),
]

_BY_ID: dict[str, ModuleDef] = {m.id: m for m in _CATALOG}


def list_modules(category: Optional[str] = None) -> list[ModuleDef]:
    if category is None:
        return list(_CATALOG)
    return [m for m in _CATALOG if m.category == category]


def get_module(module_id: str) -> Optional[ModuleDef]:
    return _BY_ID.get(module_id)


# ── Per-tenant overrides ─────────────────────────────────────────


_DATA_DIR = os.environ.get("APEX_DATA_DIR", os.getcwd())
_PATH = os.environ.get(
    "TENANT_MODULES_PATH", os.path.join(_DATA_DIR, "tenant_modules.json")
)
_LOCK = threading.RLock()

# tenant_id → {module_id → True/False}
_OVERRIDES: dict[str, dict[str, bool]] = {}
# tenant_id → updated_at
_META: dict[str, str] = {}


def _load() -> None:
    global _OVERRIDES, _META
    with _LOCK:
        if not os.path.exists(_PATH):
            _OVERRIDES = {}
            _META = {}
            return
        try:
            with open(_PATH, encoding="utf-8") as f:
                raw = json.load(f)
            _OVERRIDES = raw.get("overrides", {}) or {}
            _META = raw.get("meta", {}) or {}
            logger.info("Loaded module overrides for %d tenants", len(_OVERRIDES))
        except Exception as e:  # noqa: BLE001
            logger.error("Failed to load tenant_modules: %s", e)
            _OVERRIDES = {}
            _META = {}


def _save() -> None:
    with _LOCK:
        payload = {
            "version": 1,
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "overrides": _OVERRIDES,
            "meta": _META,
        }
        tmp = _PATH + ".tmp"
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _PATH)


def _is_enabled_default(m: ModuleDef) -> bool:
    return m.default_enabled


def effective_modules(tenant_id: str) -> dict[str, bool]:
    """Resolve every module's enabled state for a tenant.

    Auto-prunes: a module whose `requires` are not all enabled is forced off
    (so a tenant can't end up with a broken state by selectively disabling
    a parent module).
    """
    with _LOCK:
        overrides = dict(_OVERRIDES.get(tenant_id, {}))

    state: dict[str, bool] = {}
    # First pass: defaults + overrides
    for m in _CATALOG:
        state[m.id] = overrides.get(m.id, _is_enabled_default(m))

    # Second pass: prune by requires (single-pass is enough since requires
    # never form cycles in the catalog above).
    changed = True
    while changed:
        changed = False
        for m in _CATALOG:
            if state[m.id] and not all(state.get(r, False) for r in m.requires):
                state[m.id] = False
                changed = True
    return state


def is_module_enabled(tenant_id: str, module_id: str) -> bool:
    return effective_modules(tenant_id).get(module_id, False)


def set_module(tenant_id: str, module_id: str, enabled: bool) -> dict:
    """Override a module's enabled state for one tenant."""
    if module_id not in _BY_ID:
        raise ValueError(f"Unknown module: {module_id}")
    with _LOCK:
        bucket = _OVERRIDES.setdefault(tenant_id, {})
        bucket[module_id] = enabled
        _META[tenant_id] = datetime.now(timezone.utc).isoformat()
        _save()
    emit(
        "module.enabled" if enabled else "module.disabled",
        {
            "tenant_id": tenant_id,
            "module_id": module_id,
            "module_name_ar": _BY_ID[module_id].name_ar,
        },
        source="module_manager",
    )
    return {"success": True, "tenant_id": tenant_id, "module_id": module_id, "enabled": enabled}


def reset_tenant(tenant_id: str) -> dict:
    """Drop all overrides for a tenant — back to catalog defaults."""
    with _LOCK:
        if tenant_id in _OVERRIDES:
            del _OVERRIDES[tenant_id]
        _META[tenant_id] = datetime.now(timezone.utc).isoformat()
        _save()
    return {"success": True, "tenant_id": tenant_id}


# Initial load.
_load()


def stats() -> dict:
    """Cross-tenant stats: how popular is each module."""
    counts: dict[str, dict] = {m.id: {"enabled": 0, "disabled": 0} for m in _CATALOG}
    with _LOCK:
        tenants = list(_OVERRIDES.keys())
    for t in tenants:
        eff = effective_modules(t)
        for mid, on in eff.items():
            if mid in counts:
                counts[mid]["enabled" if on else "disabled"] += 1
    return {
        "tenants_with_overrides": len(tenants),
        "modules_total": len(_CATALOG),
        "module_adoption": counts,
    }
