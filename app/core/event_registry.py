"""
APEX — Event Registry
======================
Centralized catalog of all domain events that can fire in the platform.
Foundation for the Workflow Rules Engine (`app/core/workflow_engine.py`):
  events  →  rules listen  →  actions execute  →  audit log

Why a registry instead of strings scattered everywhere:
- Discoverability: `GET /admin/events/list` shows everything that can trigger
  a workflow rule, with payload schema and example.
- Type safety: rule authors get autocomplete/validation against a known set.
- Documentation: each event has Arabic + English label + category.
- Versioning: payload schema can evolve with version bumps.

Reference: Wave 3 Workflow Engine target (architecture/diagrams/02-target-state.md §6).
"""

from __future__ import annotations

import enum
from dataclasses import dataclass, field
from typing import Any, Optional


class EventCategory(str, enum.Enum):
    """High-level grouping for the event picker UI."""

    sales = "sales"
    purchase = "purchase"
    accounting = "accounting"
    operations = "operations"
    compliance = "compliance"
    hr = "hr"
    user = "user"
    system = "system"
    marketplace = "marketplace"


@dataclass(frozen=True)
class EventDefinition:
    """One row in the event catalog.

    `payload_schema` is informational only (string description per field).
    The Workflow Rules Engine will accept any dict at runtime and let rule
    authors reference fields by dotted path (`payload.amount`,
    `payload.client.name_ar`, etc.).
    """

    name: str  # canonical id, e.g. "invoice.created"
    label_ar: str
    label_en: str
    category: EventCategory
    payload_schema: dict[str, str] = field(default_factory=dict)
    example_payload: dict[str, Any] = field(default_factory=dict)
    description_ar: Optional[str] = None


# ── Event Catalog ────────────────────────────────────────────────────
# Add new events here. Keep names dotted: `<entity>.<action>` (lowercase).

_CATALOG: list[EventDefinition] = [
    # ─ Sales / AR ─
    EventDefinition(
        name="invoice.created",
        label_ar="فاتورة جديدة أُنشئت",
        label_en="Invoice created",
        category=EventCategory.sales,
        payload_schema={
            "invoice_id": "uuid",
            "tenant_id": "uuid",
            "customer_id": "uuid",
            "total_amount": "decimal",
            "currency": "string (ISO 4217)",
            "issued_at": "datetime ISO",
        },
        example_payload={
            "invoice_id": "01HXY...",
            "customer_id": "01HCU...",
            "total_amount": 1250.00,
            "currency": "SAR",
        },
        description_ar="يطلَق فور إنشاء فاتورة بيع — قبل ZATCA submission.",
    ),
    EventDefinition(
        name="invoice.posted",
        label_ar="فاتورة تم ترحيلها",
        label_en="Invoice posted to GL",
        category=EventCategory.sales,
        payload_schema={"invoice_id": "uuid", "je_id": "uuid"},
    ),
    EventDefinition(
        name="invoice.paid",
        label_ar="فاتورة سُدِّدت",
        label_en="Invoice paid in full",
        category=EventCategory.sales,
        payload_schema={"invoice_id": "uuid", "amount": "decimal"},
    ),
    EventDefinition(
        name="invoice.overdue",
        label_ar="فاتورة متأخرة السداد",
        label_en="Invoice overdue",
        category=EventCategory.sales,
        payload_schema={"invoice_id": "uuid", "days_overdue": "int"},
    ),
    EventDefinition(
        name="payment.received",
        label_ar="استلام دفعة",
        label_en="Payment received",
        category=EventCategory.sales,
        payload_schema={"payment_id": "uuid", "amount": "decimal", "method": "string"},
    ),
    # ─ Purchase / AP ─
    EventDefinition(
        name="bill.created",
        label_ar="فاتورة شراء جديدة",
        label_en="Bill created",
        category=EventCategory.purchase,
        payload_schema={"bill_id": "uuid", "vendor_id": "uuid", "amount": "decimal"},
    ),
    EventDefinition(
        name="bill.approved",
        label_ar="فاتورة شراء معتمدة",
        label_en="Bill approved",
        category=EventCategory.purchase,
    ),
    EventDefinition(
        name="bill.paid",
        label_ar="فاتورة شراء سُدِّدت",
        label_en="Bill paid",
        category=EventCategory.purchase,
    ),
    EventDefinition(
        name="purchase_order.created",
        label_ar="أمر شراء جديد",
        label_en="Purchase order created",
        category=EventCategory.purchase,
    ),
    # ─ Accounting / GL ─
    EventDefinition(
        name="je.posted",
        label_ar="قيد يومية تم ترحيله",
        label_en="Journal entry posted",
        category=EventCategory.accounting,
        payload_schema={"je_id": "uuid", "fiscal_period_id": "uuid", "total": "decimal"},
    ),
    EventDefinition(
        name="je.reversed",
        label_ar="قيد يومية تم إلغاؤه",
        label_en="Journal entry reversed",
        category=EventCategory.accounting,
    ),
    EventDefinition(
        name="period.closed",
        label_ar="فترة مالية أُقفلت",
        label_en="Fiscal period closed",
        category=EventCategory.accounting,
        payload_schema={"period_id": "uuid", "code": "string"},
    ),
    EventDefinition(
        name="period.locked",
        label_ar="فترة مالية أُقفلت نهائياً",
        label_en="Fiscal period locked",
        category=EventCategory.accounting,
    ),
    EventDefinition(
        name="coa.account_added",
        label_ar="حساب جديد في شجرة الحسابات",
        label_en="COA account added",
        category=EventCategory.accounting,
    ),
    EventDefinition(
        name="bank_reconciliation.completed",
        label_ar="تسوية بنكية اكتملت",
        label_en="Bank reconciliation completed",
        category=EventCategory.accounting,
    ),
    # ─ Operations / Inventory ─
    EventDefinition(
        name="inventory.low_stock",
        label_ar="مخزون منخفض",
        label_en="Inventory low-stock alert",
        category=EventCategory.operations,
        payload_schema={"item_id": "uuid", "current_qty": "decimal", "reorder_point": "decimal"},
    ),
    EventDefinition(
        name="receipt.captured",
        label_ar="إيصال جديد التُقط (OCR)",
        label_en="Receipt captured via OCR",
        category=EventCategory.operations,
    ),
    # ─ Compliance ─
    EventDefinition(
        name="zatca.submitted",
        label_ar="تم إرسال فاتورة لـ ZATCA",
        label_en="ZATCA invoice submitted",
        category=EventCategory.compliance,
    ),
    EventDefinition(
        name="zatca.cleared",
        label_ar="ZATCA قبلت الفاتورة",
        label_en="ZATCA cleared invoice",
        category=EventCategory.compliance,
    ),
    EventDefinition(
        name="zatca.rejected",
        label_ar="ZATCA رفضت الفاتورة",
        label_en="ZATCA rejected invoice",
        category=EventCategory.compliance,
    ),
    EventDefinition(
        name="anomaly.detected",
        label_ar="تم اكتشاف معاملة غير اعتيادية",
        label_en="Anomaly detected",
        category=EventCategory.compliance,
        payload_schema={"object_type": "string", "object_id": "uuid", "score": "float"},
    ),
    # ─ HR ─
    EventDefinition(
        name="payroll.run_completed",
        label_ar="تشغيل الرواتب اكتمل",
        label_en="Payroll run completed",
        category=EventCategory.hr,
    ),
    EventDefinition(
        name="employee.hired",
        label_ar="موظف جديد",
        label_en="Employee hired",
        category=EventCategory.hr,
    ),
    EventDefinition(
        name="employee.terminated",
        label_ar="نهاية خدمة موظف",
        label_en="Employee terminated",
        category=EventCategory.hr,
    ),
    # ─ User / Auth ─
    EventDefinition(
        name="user.registered",
        label_ar="تسجيل مستخدم جديد",
        label_en="User registered",
        category=EventCategory.user,
    ),
    EventDefinition(
        name="user.email_verified",
        label_ar="مستخدم تحقق من البريد",
        label_en="User verified email",
        category=EventCategory.user,
    ),
    EventDefinition(
        name="user.suspended",
        label_ar="حساب مستخدم تم تعليقه",
        label_en="User account suspended",
        category=EventCategory.user,
    ),
    # ─ Universal Comments + Mentions ─
    EventDefinition(
        name="comment.added",
        label_ar="تعليق جديد",
        label_en="Comment added",
        category=EventCategory.system,
        payload_schema={
            "comment_id": "uuid",
            "object_type": "string",
            "object_id": "string",
            "author_user_id": "user_id",
            "mention_count": "int",
        },
    ),
    EventDefinition(
        name="comment.edited",
        label_ar="تم تعديل تعليق",
        label_en="Comment edited",
        category=EventCategory.system,
    ),
    EventDefinition(
        name="comment.deleted",
        label_ar="تم حذف تعليق",
        label_en="Comment deleted",
        category=EventCategory.system,
    ),
    EventDefinition(
        name="mention.received",
        label_ar="تمّت الإشارة لك في تعليق",
        label_en="You were mentioned",
        category=EventCategory.system,
        payload_schema={
            "comment_id": "uuid",
            "mentioned_user_id": "user_id",
            "by_user_id": "user_id",
            "object_type": "string",
            "object_id": "string",
        },
        description_ar=(
            "يطلَق لكل @mention في تعليق. اربطه بقاعدة workflow ترسل إشعار "
            "للمستخدم المذكور (Slack DM، email، إلخ)."
        ),
    ),

    # ─ Email Intake ─
    EventDefinition(
        name="email.received",
        label_ar="بريد جديد بمرفقات",
        label_en="Email received with attachments",
        category=EventCategory.system,
        payload_schema={
            "message_id": "string",
            "from": "string",
            "subject": "string",
            "attachments": "list of {filename, content_type, saved_path, size_bytes}",
            "attachment_count": "int",
        },
        description_ar=(
            "يُطلَق عند سحب رسالة جديدة من البريد عبر IMAP poller. "
            "يُمكن للقواعد إنشاء فاتورة مسودة عبر استخراج Claude Vision."
        ),
    ),

    # ─ Approvals (multi-stage chains) ─
    EventDefinition(
        name="approval.requested",
        label_ar="طلب موافقة جديد",
        label_en="Approval requested",
        category=EventCategory.system,
        payload_schema={
            "approval_id": "uuid",
            "object_type": "string",
            "object_id": "string",
            "current_approver": "user_id",
            "total_stages": "int",
        },
    ),
    EventDefinition(
        name="approval.approved",
        label_ar="موافقة اكتملت",
        label_en="Approval fully approved",
        category=EventCategory.system,
    ),
    EventDefinition(
        name="approval.rejected",
        label_ar="موافقة رُفضت",
        label_en="Approval rejected",
        category=EventCategory.system,
    ),
    EventDefinition(
        name="approval.partial",
        label_ar="مرحلة موافقة مكتملة",
        label_en="Approval stage advanced",
        category=EventCategory.system,
    ),

    # ─ Marketplace ─
    EventDefinition(
        name="service_request.created",
        label_ar="طلب خدمة جديد",
        label_en="Service request created",
        category=EventCategory.marketplace,
    ),
    EventDefinition(
        name="service_bid.submitted",
        label_ar="تم تقديم عرض خدمة",
        label_en="Service bid submitted",
        category=EventCategory.marketplace,
    ),
    # ─ System ─
    EventDefinition(
        name="system.daily_close",
        label_ar="إقفال يومي تلقائي",
        label_en="Daily auto-close",
        category=EventCategory.system,
    ),
    EventDefinition(
        name="system.report_generated",
        label_ar="تقرير اكتمل توليده",
        label_en="Report generated",
        category=EventCategory.system,
    ),
]

# Index by name for O(1) lookup.
_BY_NAME: dict[str, EventDefinition] = {e.name: e for e in _CATALOG}


def list_events(category: Optional[EventCategory] = None) -> list[EventDefinition]:
    """Return all registered events, optionally filtered by category."""
    if category is None:
        return list(_CATALOG)
    return [e for e in _CATALOG if e.category == category]


def get_event(name: str) -> Optional[EventDefinition]:
    """Lookup an event definition by canonical name. Returns None if unknown."""
    return _BY_NAME.get(name)


def is_known_event(name: str) -> bool:
    """True if the name matches a registered event."""
    return name in _BY_NAME


def categories() -> list[dict]:
    """Return [{value, label_ar, label_en, count}] for the picker UI."""
    counts: dict[str, int] = {}
    for e in _CATALOG:
        counts[e.category.value] = counts.get(e.category.value, 0) + 1
    return [
        {
            "value": c.value,
            "label_ar": _CATEGORY_LABELS_AR[c],
            "label_en": c.value.replace("_", " ").title(),
            "count": counts.get(c.value, 0),
        }
        for c in EventCategory
    ]


_CATEGORY_LABELS_AR = {
    EventCategory.sales: "المبيعات",
    EventCategory.purchase: "المشتريات",
    EventCategory.accounting: "المحاسبة",
    EventCategory.operations: "العمليات",
    EventCategory.compliance: "الامتثال",
    EventCategory.hr: "الموارد البشرية",
    EventCategory.user: "المستخدمون",
    EventCategory.system: "النظام",
    EventCategory.marketplace: "السوق",
}
