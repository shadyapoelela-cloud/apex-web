"""Pre-approved WhatsApp template definitions for APEX.

Each template must be registered with Meta's Business Manager before use in
production. The strings here are the SOURCE OF TRUTH for the registered
bodies — keep them in sync when updating templates in Meta's dashboard.

Template naming convention: `apex_<feature>_<variant>` (snake_case, ≤ 32 chars).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class WhatsAppTemplate:
    name: str
    language: str
    body: str            # Human reference — {{1}}, {{2}}, … are placeholders.
    description: str
    category: str        # UTILITY | MARKETING | AUTHENTICATION


# ── Invoice lifecycle ─────────────────────────────────────────

INVOICE_ISSUED_AR = WhatsAppTemplate(
    name="apex_invoice_issued_ar",
    language="ar",
    body=(
        "مرحباً {{1}}،\n"
        "تم إصدار فاتورة جديدة بقيمة {{2}} ريال.\n"
        "رقم الفاتورة: {{3}}\n"
        "تاريخ الاستحقاق: {{4}}\n"
        "يمكنك الاطلاع على الفاتورة ودفعها عبر الرابط المرفق."
    ),
    description="Sent when an invoice is issued to a client.",
    category="UTILITY",
)

PAYMENT_REMINDER_AR = WhatsAppTemplate(
    name="apex_payment_reminder_ar",
    language="ar",
    body=(
        "تذكير ودّي من {{1}}: فاتورتك رقم {{2}} بقيمة {{3}} ريال "
        "مستحقة خلال {{4}} أيام. شكراً لتعاونك."
    ),
    description="Payment reminder 3 days before due date.",
    category="UTILITY",
)

PAYMENT_OVERDUE_AR = WhatsAppTemplate(
    name="apex_payment_overdue_ar",
    language="ar",
    body=(
        "عزيزي {{1}}، فاتورتك رقم {{2}} بقيمة {{3}} ريال متأخرة عن "
        "السداد بـ {{4}} يوماً. نرجو المبادرة بالدفع أو التواصل معنا."
    ),
    description="Payment overdue — escalation after due date.",
    category="UTILITY",
)

PAYMENT_RECEIVED_AR = WhatsAppTemplate(
    name="apex_payment_received_ar",
    language="ar",
    body=(
        "شكراً لك {{1}}! تم استلام دفعة بمبلغ {{2}} ريال "
        "لفاتورة رقم {{3}} بتاريخ {{4}}."
    ),
    description="Payment receipt confirmation.",
    category="UTILITY",
)

# ── Employee / approvals ──────────────────────────────────────

EXPENSE_APPROVAL_AR = WhatsAppTemplate(
    name="apex_expense_approval_ar",
    language="ar",
    body=(
        "طلب اعتماد مصروف:\n"
        "الموظف: {{1}}\n"
        "المبلغ: {{2}} ريال\n"
        "الفئة: {{3}}\n"
        "الرجاء الرد بـ 'موافق' أو 'رفض'."
    ),
    description="Expense approval request to manager.",
    category="UTILITY",
)

PAYSLIP_NOTICE_AR = WhatsAppTemplate(
    name="apex_payslip_notice_ar",
    language="ar",
    body=(
        "تم إصدار كشف راتبك لشهر {{1}}.\n"
        "صافي الراتب: {{2}} ريال\n"
        "يمكنك تحميل الكشف من بوابة الموظف."
    ),
    description="Monthly payslip notification.",
    category="UTILITY",
)

# ── KPI alerts ────────────────────────────────────────────────

BUDGET_ALERT_AR = WhatsAppTemplate(
    name="apex_budget_alert_ar",
    language="ar",
    body=(
        "تنبيه: بند الميزانية '{{1}}' تجاوز {{2}}% من المخصص "
        "({{3}} ريال من أصل {{4}} ريال).\n"
        "الفترة: {{5}}"
    ),
    description="Budget overrun alert to CFO/manager.",
    category="UTILITY",
)


ALL_TEMPLATES = [
    INVOICE_ISSUED_AR,
    PAYMENT_REMINDER_AR,
    PAYMENT_OVERDUE_AR,
    PAYMENT_RECEIVED_AR,
    EXPENSE_APPROVAL_AR,
    PAYSLIP_NOTICE_AR,
    BUDGET_ALERT_AR,
]


def get_template(name: str) -> Optional[WhatsAppTemplate]:
    for t in ALL_TEMPLATES:
        if t.name == name:
            return t
    return None


def build_body_components(values: list[str]) -> list[dict]:
    """Wrap a list of string values as Meta's template body component."""
    return [
        {
            "type": "body",
            "parameters": [{"type": "text", "text": v} for v in values],
        }
    ]
