"""Seed data for the dashboard module.

Two collections:

  SYSTEM_WIDGETS    — 12 catalog entries shipped with the platform.
  DEFAULT_LAYOUTS   — 5 role-scope layouts (CFO, Accountant, Cashier,
                       Branch Manager, HR) used as fallbacks when a
                       user has no personal layout.

Both are idempotent: `seed_dashboard()` upserts by code/name so it's
safe to call on every startup or from `seed_runner.py`.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.dashboard.models import (
    DashboardLayout,
    DashboardWidget,
    LayoutScope,
    WidgetType,
)
from app.phase1.models.platform_models import SessionLocal

logger = logging.getLogger(__name__)


# ── 12 System Widgets ─────────────────────────────────────


SYSTEM_WIDGETS: list[dict[str, Any]] = [
    {
        "code": "kpi.cash_balance",
        "title_ar": "الرصيد النقدي",
        "title_en": "Cash Balance",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "bs.assets.cash",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["read:reports"],
        "refresh_secs": 60,
    },
    {
        "code": "kpi.net_income_mtd",
        "title_ar": "صافي الدخل (شهر حتى تاريخه)",
        "title_en": "Net Income (MTD)",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "is.net_income.mtd",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["read:reports"],
        "refresh_secs": 300,
    },
    {
        "code": "kpi.ar_outstanding",
        "title_ar": "الذمم المدينة المتبقية",
        "title_en": "AR Outstanding",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "ar.outstanding",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["read:invoices"],
        "refresh_secs": 60,
    },
    {
        "code": "kpi.ap_due_7d",
        "title_ar": "ذمم دائنة مستحقة خلال 7 أيام",
        "title_en": "AP Due Within 7 Days",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "ap.due_within_days?days=7",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["read:bills"],
        "refresh_secs": 300,
    },
    {
        "code": "chart.revenue_30d",
        "title_ar": "الإيرادات (آخر 30 يوماً)",
        "title_en": "Revenue (Last 30 Days)",
        "category": "analytics",
        "widget_type": WidgetType.CHART,
        "data_source": "revenue.daily?days=30",
        "default_span": 6, "min_span": 4, "max_span": 12,
        "required_perms": ["read:reports"],
        "refresh_secs": 600,
    },
    {
        "code": "chart.cash_flow_90d",
        "title_ar": "توقع التدفق النقدي (90 يوماً)",
        "title_en": "Cash Flow Forecast (90d)",
        "category": "analytics",
        "widget_type": WidgetType.CHART,
        "data_source": "cashflow.forecast?days=90",
        "default_span": 6, "min_span": 4, "max_span": 12,
        "required_perms": ["read:forecast"],
        "refresh_secs": 600,
    },
    {
        "code": "list.top_customers",
        "title_ar": "أكبر العملاء",
        "title_en": "Top Customers",
        "category": "sales",
        "widget_type": WidgetType.TABLE,
        "data_source": "customers.top?limit=10",
        "default_span": 6, "min_span": 4, "max_span": 12,
        "required_perms": ["read:customers"],
        "refresh_secs": 1800,
    },
    {
        "code": "list.pending_approvals",
        "title_ar": "الموافقات المعلّقة",
        "title_en": "Pending Approvals",
        "category": "platform",
        "widget_type": WidgetType.LIST,
        "data_source": "approvals.pending",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:approvals"],
        "refresh_secs": 30,
    },
    {
        "code": "list.recent_invoices",
        "title_ar": "أحدث الفواتير",
        "title_en": "Recent Invoices",
        "category": "sales",
        "widget_type": WidgetType.LIST,
        "data_source": "invoices.recent?limit=10",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:invoices"],
        "refresh_secs": 60,
    },
    {
        "code": "widget.compliance_health",
        "title_ar": "صحة الالتزام",
        "title_en": "Compliance Health",
        "category": "compliance",
        "widget_type": WidgetType.CUSTOM,
        "data_source": "compliance.health",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:zatca"],
        "refresh_secs": 300,
    },
    {
        "code": "widget.ai_pulse",
        "title_ar": "نبض الذكاء",
        "title_en": "AI Pulse",
        "category": "ai",
        "widget_type": WidgetType.AI,
        "data_source": "ai.pulse",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:dashboard"],
        "refresh_secs": 120,
    },
    {
        "code": "widget.express_invoice",
        "title_ar": "فاتورة سريعة",
        "title_en": "Express Invoice",
        "category": "actions",
        "widget_type": WidgetType.ACTION,
        "data_source": "invoices.express",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["write:invoices"],
        "refresh_secs": 0,
    },
    # CoA-1 Phase 5: dashboard window into the new audit log.
    {
        "code": "list.recent_account_changes",
        "title_ar": "آخر تعديلات شجرة الحسابات",
        "title_en": "Recent CoA Changes",
        "category": "finance",
        "widget_type": WidgetType.LIST,
        "data_source": "coa.changelog.recent?limit=5",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:chart_of_accounts"],
        "refresh_secs": 300,
    },
    # INV-1 Phase 4: invoicing widgets surfacing aged AR/AP, overdue,
    # and recurring-due-today on the dashboard.
    {
        "code": "kpi.aged_ar_summary",
        "title_ar": "أعمار الذمم المدينة",
        "title_en": "Aged AR Summary",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "invoicing.aged_ar.summary",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:aged_ar_ap"],
        "refresh_secs": 600,
    },
    {
        "code": "kpi.aged_ap_summary",
        "title_ar": "أعمار الذمم الدائنة",
        "title_en": "Aged AP Summary",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "invoicing.aged_ap.summary",
        "default_span": 4, "min_span": 3, "max_span": 6,
        "required_perms": ["read:aged_ar_ap"],
        "refresh_secs": 600,
    },
    {
        "code": "list.overdue_invoices",
        "title_ar": "فواتير متأخرة",
        "title_en": "Overdue Invoices",
        "category": "finance",
        "widget_type": WidgetType.LIST,
        "data_source": "invoicing.overdue?limit=10",
        "default_span": 6, "min_span": 4, "max_span": 12,
        "required_perms": ["read:invoices"],
        "refresh_secs": 300,
    },
    {
        "code": "kpi.recurring_due_today",
        "title_ar": "فواتير متكررة مستحقة اليوم",
        "title_en": "Recurring Due Today",
        "category": "finance",
        "widget_type": WidgetType.KPI,
        "data_source": "invoicing.recurring.due_today",
        "default_span": 3, "min_span": 2, "max_span": 4,
        "required_perms": ["read:recurring_invoices"],
        "refresh_secs": 1800,
    },
]


# ── 5 Default Role Layouts ────────────────────────────────


def _block(widget_code: str, *, x: int, y: int, span: int) -> dict[str, Any]:
    return {
        "id": f"blk-{widget_code}-{x}-{y}",
        "widget_code": widget_code,
        "span": span,
        "x": x,
        "y": y,
        "config": {},
    }


DEFAULT_LAYOUTS: list[dict[str, Any]] = [
    {
        "role_id": "cfo",
        "name": "default",
        "blocks": [
            _block("kpi.cash_balance",      x=0, y=0, span=3),
            _block("kpi.net_income_mtd",    x=3, y=0, span=3),
            _block("kpi.ar_outstanding",    x=6, y=0, span=3),
            _block("kpi.ap_due_7d",         x=9, y=0, span=3),
            _block("chart.revenue_30d",     x=0, y=1, span=6),
            _block("chart.cash_flow_90d",   x=6, y=1, span=6),
            # INV-1: aged AR/AP rollups + overdue list
            _block("kpi.aged_ar_summary",   x=0, y=2, span=4),
            _block("kpi.aged_ap_summary",   x=4, y=2, span=4),
            _block("kpi.recurring_due_today", x=8, y=2, span=4),
            _block("list.overdue_invoices", x=0, y=3, span=6),
            _block("list.top_customers",    x=6, y=3, span=6),
            _block("widget.compliance_health", x=0, y=4, span=6),
            _block("widget.ai_pulse",       x=6, y=4, span=6),
        ],
    },
    {
        "role_id": "accountant",
        "name": "default",
        "blocks": [
            _block("kpi.cash_balance",      x=0, y=0, span=3),
            _block("kpi.ar_outstanding",    x=3, y=0, span=3),
            _block("kpi.ap_due_7d",         x=6, y=0, span=3),
            _block("widget.express_invoice", x=9, y=0, span=3),
            # INV-1: overdue + recurring-due-today for daily AR/AP work
            _block("list.overdue_invoices", x=0, y=1, span=8),
            _block("kpi.recurring_due_today", x=8, y=1, span=4),
            _block("list.recent_invoices",  x=0, y=2, span=4),
            _block("list.pending_approvals", x=4, y=2, span=4),
            _block("chart.revenue_30d",     x=0, y=3, span=12),
        ],
    },
    {
        "role_id": "cashier",
        "name": "default",
        "blocks": [
            _block("kpi.cash_balance",      x=0, y=0, span=4),
            _block("widget.express_invoice", x=4, y=0, span=4),
            _block("list.recent_invoices",  x=0, y=1, span=8),
        ],
    },
    {
        "role_id": "branch_manager",
        "name": "default",
        "blocks": [
            _block("kpi.cash_balance",      x=0, y=0, span=3),
            _block("kpi.ar_outstanding",    x=3, y=0, span=3),
            _block("kpi.ap_due_7d",         x=6, y=0, span=3),
            _block("kpi.net_income_mtd",    x=9, y=0, span=3),
            _block("chart.revenue_30d",     x=0, y=1, span=8),
            _block("list.top_customers",    x=8, y=1, span=4),
        ],
    },
    {
        "role_id": "hr",
        "name": "default",
        "blocks": [
            _block("list.pending_approvals", x=0, y=0, span=6),
            _block("widget.ai_pulse",        x=6, y=0, span=6),
        ],
    },
]


# ── Idempotent seed ───────────────────────────────────────


def _upsert_widget(db: Session, w: dict[str, Any]) -> DashboardWidget:
    row = db.query(DashboardWidget).filter(
        DashboardWidget.code == w["code"],
        DashboardWidget.tenant_id.is_(None),
    ).first()
    if row is None:
        row = DashboardWidget(
            id=str(uuid.uuid4()),
            tenant_id=None,
            is_system=True,
            **{k: v for k, v in w.items() if k != "id"},
        )
        # Defaults for description fields not in seed dicts
        row.description_ar = w.get("description_ar")
        row.description_en = w.get("description_en")
        db.add(row)
    else:
        # Refresh editable fields without bumping id.
        for k, v in w.items():
            if k in ("title_ar", "title_en", "description_ar", "description_en",
                     "category", "widget_type", "data_source", "default_span",
                     "min_span", "max_span", "required_perms", "config_schema",
                     "refresh_secs"):
                setattr(row, k, v)
        row.is_system = True
        row.is_enabled = True
    return row


def _upsert_role_layout(db: Session, layout: dict[str, Any]) -> DashboardLayout:
    row = db.query(DashboardLayout).filter(
        DashboardLayout.scope == LayoutScope.ROLE,
        DashboardLayout.owner_id == layout["role_id"],
        DashboardLayout.name == layout["name"],
    ).first()
    if row is None:
        row = DashboardLayout(
            id=str(uuid.uuid4()),
            tenant_id=None,
            scope=LayoutScope.ROLE,
            owner_id=layout["role_id"],
            name=layout["name"],
            blocks=layout["blocks"],
            is_default=True,
        )
        db.add(row)
    else:
        row.blocks = layout["blocks"]
    return row


def _upsert_system_layout(db: Session) -> DashboardLayout:
    """A minimal "everyone falls back here" layout — KPI row only."""
    row = db.query(DashboardLayout).filter(
        DashboardLayout.scope == LayoutScope.SYSTEM,
        DashboardLayout.name == "default",
    ).first()
    blocks = [
        _block("kpi.cash_balance",   x=0, y=0, span=3),
        _block("kpi.ar_outstanding", x=3, y=0, span=3),
        _block("kpi.ap_due_7d",      x=6, y=0, span=3),
        _block("widget.ai_pulse",    x=9, y=0, span=3),
    ]
    if row is None:
        row = DashboardLayout(
            id=str(uuid.uuid4()),
            tenant_id=None,
            scope=LayoutScope.SYSTEM,
            owner_id=None,
            name="default",
            blocks=blocks,
            is_default=True,
        )
        db.add(row)
    else:
        row.blocks = blocks
    return row


def seed_dashboard(db: Session | None = None) -> dict[str, int]:
    """Idempotent seeder. Returns counts for the runner to log."""
    own_db = False
    if db is None:
        db = SessionLocal()
        own_db = True
    try:
        widget_count = 0
        for w in SYSTEM_WIDGETS:
            _upsert_widget(db, w)
            widget_count += 1
        layout_count = 0
        for layout in DEFAULT_LAYOUTS:
            _upsert_role_layout(db, layout)
            layout_count += 1
        _upsert_system_layout(db)
        layout_count += 1
        db.commit()
        logger.info(
            "Dashboard seed: %d widgets, %d layouts upserted",
            widget_count, layout_count,
        )
        return {"widgets": widget_count, "layouts": layout_count}
    finally:
        if own_db:
            db.close()


__all__ = ["SYSTEM_WIDGETS", "DEFAULT_LAYOUTS", "seed_dashboard"]
