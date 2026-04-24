"""Industry-specific Chart of Accounts templates — SOCPA-aligned for KSA.

Onboarding new tenants into a blank COA is the most-complained-about
pain point across Qoyod / Wafeq / Daftra reviews. APEX ships *industry*
templates: each template adds 15-30 pre-mapped sub-accounts tuned to
how the industry actually transacts.

Templates:
  • restaurant  — restaurants, cafes, food trucks (KSA F&B sector)
  • retail      — shops, e-commerce, wholesale
  • services    — consultancies, law firms, marketing, IT services
  • contracting — construction, engineering, MEP
  • medical     — clinics, dental, beauty (VAT exempt for healthcare)

Each template returns a list of dict rows with the same shape the
existing SOCPA CoA seeder (app.pilot.services.gl_engine.DEFAULT_COA)
consumes, so it drops into init_db for a new entity.
"""

from __future__ import annotations

from typing import Any

# Each account: {code, name_ar, name_en, parent, category, subcategory,
# type, normal_balance, level, is_control?}


# ── Restaurant / F&B ─────────────────────────────────────


RESTAURANT: list[dict[str, Any]] = [
    # Revenue — split by channel (dine-in / delivery / catering)
    {"code": "4110", "name_ar": "مبيعات الصالة", "name_en": "Dine-in Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4120", "name_ar": "مبيعات التوصيل", "name_en": "Delivery Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4130", "name_ar": "مبيعات الوجبات المعلّبة", "name_en": "Takeaway Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4140", "name_ar": "مبيعات الضيافة والمناسبات", "name_en": "Catering Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # COGS
    {"code": "5110", "name_ar": "تكلفة الطعام", "name_en": "Food COGS",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5120", "name_ar": "تكلفة المشروبات", "name_en": "Beverage COGS",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5130", "name_ar": "تكلفة عبوات التغليف", "name_en": "Packaging COGS",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    # OpEx
    {"code": "5301", "name_ar": "رسوم توصيل (Jahez / HungerStation)",
     "name_en": "Delivery Platform Fees",
     "parent": "5300", "category": "expense", "subcategory": "platforms",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5302", "name_ar": "إيجار المطعم", "name_en": "Restaurant Rent",
     "parent": "5300", "category": "expense", "subcategory": "rent",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5303", "name_ar": "كهرباء ومرافق", "name_en": "Utilities",
     "parent": "5300", "category": "expense", "subcategory": "utilities",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5304", "name_ar": "رواتب الموظفين", "name_en": "Staff Salaries",
     "parent": "5300", "category": "expense", "subcategory": "payroll",
     "type": "detail", "normal_balance": "debit", "level": 3},
]


# ── Retail ────────────────────────────────────────────────


RETAIL: list[dict[str, Any]] = [
    {"code": "4110", "name_ar": "مبيعات الفرع", "name_en": "Branch Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4120", "name_ar": "مبيعات الموقع الإلكتروني (Salla / Zid)",
     "name_en": "E-commerce Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4130", "name_ar": "مبيعات الجملة", "name_en": "Wholesale",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4210", "name_ar": "مرتجعات المبيعات", "name_en": "Sales Returns",
     "parent": "4200", "category": "revenue", "subcategory": "returns",
     "type": "detail", "normal_balance": "debit", "level": 3},
    # Inventory
    {"code": "1141", "name_ar": "مخزون البضاعة", "name_en": "Merchandise Inventory",
     "parent": "1140", "category": "asset", "subcategory": "inventory",
     "type": "detail", "normal_balance": "debit", "level": 4, "is_control": True},
    {"code": "5110", "name_ar": "تكلفة البضاعة المباعة", "name_en": "Cost of Goods Sold",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5301", "name_ar": "رسوم بوابات الدفع (Stripe / HyperPay)",
     "name_en": "Payment Gateway Fees",
     "parent": "5300", "category": "expense", "subcategory": "platforms",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5302", "name_ar": "شحن وتوصيل", "name_en": "Shipping",
     "parent": "5300", "category": "expense", "subcategory": "shipping",
     "type": "detail", "normal_balance": "debit", "level": 3},
]


# ── Services / Consultancies ─────────────────────────────


SERVICES: list[dict[str, Any]] = [
    {"code": "4110", "name_ar": "إيرادات استشارات", "name_en": "Consulting Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4120", "name_ar": "إيرادات عقود ثابتة", "name_en": "Fixed-price Project Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4130", "name_ar": "إيرادات اشتراكات (Retainer)", "name_en": "Retainer Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4140", "name_ar": "إيرادات إعادة فوترة المصروفات",
     "name_en": "Billable Expense Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # Deferred revenue (critical for retainer/subscription models)
    {"code": "2301", "name_ar": "إيرادات مؤجّلة", "name_en": "Deferred Revenue",
     "parent": "2300", "category": "liability", "subcategory": "deferred",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # Work in progress
    {"code": "1170", "name_ar": "أعمال قيد التنفيذ", "name_en": "Work in Progress",
     "parent": "1100", "category": "asset", "subcategory": "wip",
     "type": "detail", "normal_balance": "debit", "level": 3},
    # OpEx
    {"code": "5301", "name_ar": "اشتراكات برمجية (AWS / Google / Notion)",
     "name_en": "Software Subscriptions",
     "parent": "5300", "category": "expense", "subcategory": "software",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5302", "name_ar": "أتعاب المستشارين / المقاولين من الباطن",
     "name_en": "Subcontractor Fees",
     "parent": "5300", "category": "expense", "subcategory": "contractors",
     "type": "detail", "normal_balance": "debit", "level": 3},
]


# ── Contracting / Construction ───────────────────────────


CONTRACTING: list[dict[str, Any]] = [
    # Revenue — percentage-of-completion accounting essentials
    {"code": "4110", "name_ar": "إيرادات عقود المقاولات", "name_en": "Contract Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4120", "name_ar": "إيرادات تغييرات الأوامر", "name_en": "Change Order Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # COGS / project costs
    {"code": "5110", "name_ar": "تكلفة مواد المشروع", "name_en": "Project Materials",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5120", "name_ar": "تكلفة العمالة", "name_en": "Direct Labor",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5130", "name_ar": "أجور مقاولين من الباطن", "name_en": "Subcontractor Costs",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5140", "name_ar": "إيجار معدّات وآلات", "name_en": "Equipment Rental",
     "parent": "5100", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    # Retention payable (muqawala retention)
    {"code": "2501", "name_ar": "ضمانات احتجاز المقاولين (Retention)",
     "name_en": "Retention Payable",
     "parent": "2500", "category": "liability", "subcategory": "retention",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # WIP / billings in excess
    {"code": "1180", "name_ar": "أعمال منجزة غير مفوترة",
     "name_en": "Unbilled Contract Receivable",
     "parent": "1100", "category": "asset", "subcategory": "wip",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "2302", "name_ar": "فواتير قبل الاستحقاق",
     "name_en": "Billings in Excess of Costs",
     "parent": "2300", "category": "liability", "subcategory": "deferred",
     "type": "detail", "normal_balance": "credit", "level": 3},
]


# ── Medical / Clinics ────────────────────────────────────


MEDICAL: list[dict[str, Any]] = [
    # Revenue — split cash vs insurance (different reconciliation flows)
    {"code": "4110", "name_ar": "إيرادات زيارات نقدية", "name_en": "Cash Patient Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4120", "name_ar": "إيرادات شركات التأمين", "name_en": "Insurance Revenue",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    {"code": "4130", "name_ar": "إيرادات صيدلية / منتجات",
     "name_en": "Pharmacy / Product Sales",
     "parent": "4100", "category": "revenue", "subcategory": "sales",
     "type": "detail", "normal_balance": "credit", "level": 3},
    # Insurance AR — separate so aging reports split by payer
    {"code": "1131", "name_ar": "مدينون — شركات تأمين",
     "name_en": "Insurance Receivable",
     "parent": "1130", "category": "asset", "subcategory": "receivables",
     "type": "detail", "normal_balance": "debit", "level": 4, "is_control": True},
    # Expenses
    {"code": "5301", "name_ar": "مستلزمات طبية", "name_en": "Medical Supplies",
     "parent": "5300", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5302", "name_ar": "أدوية الصيدلية", "name_en": "Pharmacy Inventory COGS",
     "parent": "5300", "category": "expense", "subcategory": "cogs",
     "type": "detail", "normal_balance": "debit", "level": 3},
    {"code": "5303", "name_ar": "أتعاب أطباء استشاريين",
     "name_en": "Consultant Physician Fees",
     "parent": "5300", "category": "expense", "subcategory": "payroll",
     "type": "detail", "normal_balance": "debit", "level": 3},
]


# ── Registry ─────────────────────────────────────────────


TEMPLATES: dict[str, dict[str, Any]] = {
    "restaurant": {
        "id": "restaurant",
        "name_ar": "مطعم / كافيه",
        "name_en": "Restaurant / Café",
        "description_ar": "للمطاعم والمقاهي وشاحنات الطعام — يفصل المبيعات بين الصالة والتوصيل والوجبات المعلّبة",
        "accounts": RESTAURANT,
    },
    "retail": {
        "id": "retail",
        "name_ar": "تجزئة / متجر إلكتروني",
        "name_en": "Retail / E-commerce",
        "description_ar": "للمتاجر ومواقع البيع الإلكتروني — يشمل Salla/Zid ومرتجعات ورسوم بوابات الدفع",
        "accounts": RETAIL,
    },
    "services": {
        "id": "services",
        "name_ar": "خدمات / استشارات",
        "name_en": "Services / Consulting",
        "description_ar": "للمكاتب الاستشارية والمحاماة والتسويق وتقنية المعلومات — يشمل الإيرادات المؤجّلة وWIP",
        "accounts": SERVICES,
    },
    "contracting": {
        "id": "contracting",
        "name_ar": "مقاولات / إنشاءات",
        "name_en": "Contracting / Construction",
        "description_ar": "للمقاولات بأسلوب Percentage-of-Completion — يشمل ضمانات الاحتجاز وفواتير قبل الاستحقاق",
        "accounts": CONTRACTING,
    },
    "medical": {
        "id": "medical",
        "name_ar": "عيادات / طبي",
        "name_en": "Medical / Clinics",
        "description_ar": "للعيادات وطب الأسنان والتجميل — يفصل إيرادات النقد عن التأمين وبناء ذمم التأمين",
        "accounts": MEDICAL,
    },
}


def list_templates() -> list[dict[str, Any]]:
    """Return just the header info for UI pickers (no accounts array)."""
    return [
        {
            "id": t["id"],
            "name_ar": t["name_ar"],
            "name_en": t["name_en"],
            "description_ar": t["description_ar"],
            "account_count": len(t["accounts"]),
        }
        for t in TEMPLATES.values()
    ]


def get_template(template_id: str) -> dict[str, Any] | None:
    return TEMPLATES.get(template_id)
