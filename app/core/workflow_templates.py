"""
APEX — Workflow Templates Library
==================================
Pre-built workflow rules that an admin can install with one click.
Each template is a recipe (event_pattern + conditions + actions) that
solves a common business need without the admin authoring it from scratch.

Why templates:
- Most customers want the same 10–15 rules: "alert me on big invoices",
  "notify CFO on bill approvals", "thank customer after payment", etc.
- Authoring rules from scratch requires understanding event payloads
- Templates are vetted, tested, and documented Arabic+English

Categories:
- approvals      — sign-off chains (big invoices, bills, payroll)
- alerts         — Slack/Teams/email warnings (overdue, anomalies, ZATCA)
- automations    — auto-actions (welcome emails, thank-you receipts)
- compliance     — ZATCA, Zakat, period-close reminders
- ops            — inventory, period close, AR/AP

Endpoint:
    GET  /admin/workflow/templates              — list catalog
    POST /admin/workflow/templates/{id}/install — instantiate (with admin's
                                                  approver_user_ids etc.)

Reference: Layer 3.8 of architecture/FUTURE_ROADMAP.md ("Workflow Templates: 50 ready-made").
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class WorkflowTemplate:
    """One row in the templates catalog."""

    id: str  # stable id, e.g. "big-invoice-approval"
    name_ar: str
    name_en: str
    category: str  # approvals | alerts | automations | compliance | ops
    description_ar: str
    icon: str  # material icon name for the picker UI
    event_pattern: str
    conditions: list[dict] = field(default_factory=list)
    actions: list[dict] = field(default_factory=list)
    parameters: list[dict] = field(default_factory=list)
    """List of placeholder parameters the admin must fill in.

    Each parameter:
        {"name": "approver_user_ids", "label_ar": "...", "type": "user_list",
         "path": "actions[0].params.approver_user_ids"}

    The install endpoint substitutes the admin-supplied values into the
    template before calling create_rule().
    """


# ── Catalog ────────────────────────────────────────────────────


_CATALOG: list[WorkflowTemplate] = [
    # ─ Approvals ─
    WorkflowTemplate(
        id="big-invoice-approval",
        name_ar="موافقة على الفواتير الكبيرة",
        name_en="Big invoice approval",
        category="approvals",
        description_ar=(
            "عند إنشاء فاتورة بمبلغ يتجاوز الحد الذي تحدده، يطلب توقيع المدير المالي قبل الترحيل."
        ),
        icon="receipt_long",
        event_pattern="invoice.created",
        conditions=[{"field": "total_amount", "operator": "gte", "value": 100000}],
        actions=[
            {
                "type": "approval",
                "params": {
                    "approver_user_ids": ["{cfo_user_id}"],
                    "title_ar": "موافقة فاتورة #{payload.invoice_id}",
                    "body": "العميل {payload.customer_id} — المبلغ {payload.total_amount} {payload.currency}",
                    "object_type": "invoice",
                    "object_id_field": "invoice_id",
                },
            }
        ],
        parameters=[
            {
                "name": "threshold",
                "label_ar": "الحد الأدنى للمبلغ",
                "type": "number",
                "default": 100000,
                "path": "conditions[0].value",
            },
            {
                "name": "cfo_user_id",
                "label_ar": "معرّف المدير المالي",
                "type": "user_id",
                "path": "actions[0].params.approver_user_ids[0]",
            },
        ],
    ),
    WorkflowTemplate(
        id="big-bill-approval",
        name_ar="موافقة على فواتير الموردين الكبيرة",
        name_en="Big bill approval",
        category="approvals",
        description_ar="نفس فكرة فاتورة المبيعات الكبيرة، لكن لجانب المشتريات.",
        icon="payments",
        event_pattern="bill.created",
        conditions=[{"field": "amount", "operator": "gte", "value": 50000}],
        actions=[
            {
                "type": "approval",
                "params": {
                    "approver_user_ids": ["{cfo_user_id}"],
                    "title_ar": "موافقة فاتورة شراء #{payload.bill_id}",
                    "body": "المورد {payload.vendor_id} — {payload.amount}",
                    "object_type": "bill",
                    "object_id_field": "bill_id",
                },
            }
        ],
        parameters=[
            {
                "name": "threshold",
                "label_ar": "الحد الأدنى للمبلغ",
                "type": "number",
                "default": 50000,
                "path": "conditions[0].value",
            },
            {
                "name": "cfo_user_id",
                "label_ar": "معرّف المدير المالي",
                "type": "user_id",
                "path": "actions[0].params.approver_user_ids[0]",
            },
        ],
    ),
    # ─ Alerts ─
    WorkflowTemplate(
        id="overdue-invoice-slack",
        name_ar="تنبيه Slack عند تأخّر فاتورة",
        name_en="Slack alert on overdue invoice",
        category="alerts",
        description_ar="ينشر تنبيهاً في قناة Slack عند مرور موعد سداد فاتورة بدون دفع.",
        icon="alarm",
        event_pattern="invoice.overdue",
        conditions=[],
        actions=[
            {
                "type": "slack",
                "params": {
                    "title": "📅 فاتورة متأخّرة #{payload.invoice_id}",
                    "body": "العميل {payload.customer_id} متأخّر {payload.days_overdue} يوم. تابع معه.",
                    "severity": "warning",
                },
            }
        ],
        parameters=[],
    ),
    WorkflowTemplate(
        id="anomaly-high-teams",
        name_ar="تنبيه Teams عند اكتشاف تذبذب عالي",
        name_en="Teams alert on high-severity anomaly",
        category="alerts",
        description_ar="يخطر فريق التدقيق عبر Teams عند أي anomaly بدرجة high أو critical.",
        icon="report_problem",
        event_pattern="anomaly.detected",
        conditions=[{"field": "severity", "operator": "in", "value": ["high", "critical"]}],
        actions=[
            {
                "type": "teams",
                "params": {
                    "title": "🚨 تذبذب مالي: {payload.type}",
                    "body": "{payload.message_ar}",
                    "severity": "error",
                },
            }
        ],
        parameters=[],
    ),
    WorkflowTemplate(
        id="zatca-rejected-alert",
        name_ar="تنبيه فوري عند رفض ZATCA لفاتورة",
        name_en="Instant alert on ZATCA rejection",
        category="alerts",
        description_ar=(
            "ينشر تنبيه عاجل في Slack وTeams عند رفض ZATCA لفاتورة، حتى يصلحها فريق الامتثال فوراً."
        ),
        icon="error",
        event_pattern="zatca.rejected",
        conditions=[],
        actions=[
            {
                "type": "slack",
                "params": {
                    "title": "❌ ZATCA رفضت فاتورة",
                    "body": "افحص /compliance/zatca-status لمعرفة السبب",
                    "severity": "error",
                },
            },
            {
                "type": "teams",
                "params": {
                    "title": "❌ ZATCA رفضت فاتورة",
                    "body": "افحص /compliance/zatca-status لمعرفة السبب",
                    "severity": "error",
                },
            },
        ],
        parameters=[],
    ),
    WorkflowTemplate(
        id="low-stock-slack",
        name_ar="تنبيه عند انخفاض المخزون",
        name_en="Low-stock Slack alert",
        category="alerts",
        description_ar="ينبّه فريق العمليات عبر Slack حين يصل صنف لنقطة إعادة الطلب.",
        icon="inventory",
        event_pattern="inventory.low_stock",
        conditions=[],
        actions=[
            {
                "type": "slack",
                "params": {
                    "title": "📉 مخزون منخفض",
                    "body": "صنف {payload.item_id} — الكمية الحالية {payload.current_qty} (نقطة الطلب {payload.reorder_point})",
                    "severity": "warning",
                },
            }
        ],
        parameters=[],
    ),
    # ─ Automations ─
    WorkflowTemplate(
        id="payment-thanks-email",
        name_ar="رسالة شكر للعميل بعد السداد",
        name_en="Thank-you email on payment",
        category="automations",
        description_ar="رسالة بريد إلكتروني تلقائية لشكر العميل فور استلام الدفعة.",
        icon="favorite",
        event_pattern="payment.received",
        conditions=[],
        actions=[
            {
                "type": "email",
                "params": {
                    "to": "{payload.customer_email}",
                    "subject": "شكراً لسدادك",
                    "body_html": (
                        "<p>عميلنا العزيز،</p>"
                        "<p>تم استلام دفعتك بمبلغ {payload.amount} {payload.currency} بنجاح. شكراً لك.</p>"
                    ),
                },
            }
        ],
        parameters=[],
    ),
    WorkflowTemplate(
        id="welcome-new-user",
        name_ar="ترحيب بمستخدم جديد",
        name_en="Welcome new user",
        category="automations",
        description_ar="رسالة ترحيب تُرسَل تلقائياً عند تسجيل أي مستخدم جديد.",
        icon="celebration",
        event_pattern="user.registered",
        conditions=[],
        actions=[
            {
                "type": "notify",
                "params": {
                    "user_id": "{payload.user_id}",
                    "notification_type": "registration",
                    "body_ar": "أهلاً بك في APEX. ابدأ بإنشاء أول فاتورة من /sales/invoices/new.",
                    "action_url": "/app",
                },
            }
        ],
        parameters=[],
    ),
    WorkflowTemplate(
        id="email-attachment-extract",
        name_ar="تحويل مرفقات البريد لمسودة فاتورة",
        name_en="Auto-extract email attachments",
        category="automations",
        description_ar=(
            "عند وصول بريد بمرفق PDF/صورة، يطلق webhook لاستخراج بيانات الفاتورة عبر Claude Vision."
        ),
        icon="attach_email",
        event_pattern="email.received",
        conditions=[{"field": "attachment_count", "operator": "gte", "value": 1}],
        actions=[
            {
                "type": "webhook",
                "params": {
                    "url": "{extraction_webhook_url}",
                    "timeout": 60,
                },
            }
        ],
        parameters=[
            {
                "name": "extraction_webhook_url",
                "label_ar": "رابط خدمة الاستخراج",
                "type": "url",
                "default": "http://localhost:8000/api/v1/extract-from-email",
                "path": "actions[0].params.url",
            }
        ],
    ),
    # ─ Compliance ─
    WorkflowTemplate(
        id="period-close-reminder",
        name_ar="تذكير بالإقفال الشهري",
        name_en="Monthly close reminder",
        category="compliance",
        description_ar="عند بدء فترة الإقفال (period.closed event)، إشعار محاسبي الفريق.",
        icon="event",
        event_pattern="period.closed",
        conditions=[],
        actions=[
            {
                "type": "slack",
                "params": {
                    "title": "📒 الفترة {payload.code} أُقفلت",
                    "body": "ابدأوا في توليد القوائم المالية + التوحيد.",
                    "severity": "info",
                },
            }
        ],
        parameters=[],
    ),
    # ─ Ops ─
    WorkflowTemplate(
        id="payroll-completed-notify",
        name_ar="إشعار اكتمال تشغيل الرواتب",
        name_en="Payroll run completed notification",
        category="ops",
        description_ar="إشعار CFO عند اكتمال تشغيل الرواتب الشهري.",
        icon="badge",
        event_pattern="payroll.run_completed",
        conditions=[],
        actions=[
            {
                "type": "notify",
                "params": {
                    "user_id": "{cfo_user_id}",
                    "notification_type": "task_assigned",
                    "body_ar": "تشغيل الرواتب اكتمل — راجع القيود قبل الترحيل.",
                    "action_url": "/hr/payroll-run",
                },
            },
            {
                "type": "slack",
                "params": {
                    "title": "💼 تشغيل الرواتب اكتمل",
                    "severity": "success",
                },
            },
        ],
        parameters=[
            {
                "name": "cfo_user_id",
                "label_ar": "معرّف المدير المالي",
                "type": "user_id",
                "path": "actions[0].params.user_id",
            }
        ],
    ),
    WorkflowTemplate(
        id="bill-paid-audit-log",
        name_ar="تسجيل سداد الموردين في Audit",
        name_en="Log bill payments to audit",
        category="ops",
        description_ar="تسجيل كل دفعة مورد في سجل التدقيق Slack ليكون لدى الفريق نسخة فورية.",
        icon="history",
        event_pattern="bill.paid",
        conditions=[],
        actions=[
            {
                "type": "log",
                "params": {
                    "message": "Bill paid: {payload.bill_id} amount={payload.amount}",
                },
            }
        ],
        parameters=[],
    ),
]


# ── Public API ────────────────────────────────────────────────


def list_templates(category: str | None = None) -> list[WorkflowTemplate]:
    if category is None:
        return list(_CATALOG)
    return [t for t in _CATALOG if t.category == category]


def get_template(template_id: str) -> WorkflowTemplate | None:
    for t in _CATALOG:
        if t.id == template_id:
            return t
    return None


def materialize(template: WorkflowTemplate, parameter_values: dict[str, Any]) -> dict:
    """Substitute parameters into the template and return a rule dict ready
    for `create_rule()`.

    Substitution is done by walking each parameter's `path` (a tiny notation
    supporting `actions[0].params.foo` and `conditions[0].value`).
    """

    import copy

    rule = {
        "name": template.name_ar,
        "description_ar": template.description_ar,
        "event_pattern": template.event_pattern,
        "conditions": copy.deepcopy(template.conditions),
        "actions": copy.deepcopy(template.actions),
    }

    for p in template.parameters:
        path = p.get("path")
        name = p.get("name")
        if not path or not name:
            continue
        value = parameter_values.get(name, p.get("default"))
        if value is None:
            continue
        _set_path(rule, path, value)

    return rule


# Tiny path-setter supporting `field.sub`, `arr[0]`, mix.
_PATH_RE = __import__("re").compile(r"([a-zA-Z_][a-zA-Z0-9_]*)|\[(\d+)\]")


def _set_path(obj: Any, path: str, value: Any) -> None:
    parts = _PATH_RE.findall(path)
    cur = obj
    for i, (k, idx) in enumerate(parts):
        is_last = i == len(parts) - 1
        if k:
            if is_last:
                if isinstance(cur, dict):
                    cur[k] = value
            else:
                cur = cur[k] if isinstance(cur, dict) else getattr(cur, k)
        elif idx:
            j = int(idx)
            if is_last:
                if isinstance(cur, list):
                    if 0 <= j < len(cur):
                        cur[j] = value
            else:
                cur = cur[j]
