"""Industry-pack registry. Each pack declares COA accounts + dashboards."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class CoaAccount:
    """One account in the pack's Chart of Accounts template."""

    code: str
    name_ar: str
    name_en: str
    account_type: str        # 'asset' | 'liability' | 'equity' | 'revenue' | 'expense'
    parent_code: Optional[str] = None


@dataclass(frozen=True)
class DashboardWidget:
    """A widget pre-configured for this industry's home dashboard."""

    id: str
    title_ar: str
    kind: str                # 'kpi' | 'chart' | 'table' | 'list'
    metric: str              # metric id the widget displays


@dataclass(frozen=True)
class IndustryPack:
    id: str
    name_ar: str
    name_en: str
    description: str
    coa_accounts: list[CoaAccount]
    dashboard_widgets: list[DashboardWidget]
    workflows: list[str] = field(default_factory=list)


# ── F&B / Retail ─────────────────────────────────────────────

_FNB_COA = [
    CoaAccount("1100", "الصندوق الرئيسي", "Main Cash", "asset"),
    CoaAccount("1110", "نقدية Mada", "Mada Pending Settlement", "asset"),
    CoaAccount("1200", "مخزون أطعمة", "Food Inventory", "asset"),
    CoaAccount("1210", "مخزون مشروبات", "Beverage Inventory", "asset"),
    CoaAccount("4100", "مبيعات طعام", "Food Sales", "revenue"),
    CoaAccount("4200", "مبيعات مشروبات", "Beverage Sales", "revenue"),
    CoaAccount("4300", "خدمة التوصيل", "Delivery Revenue", "revenue"),
    CoaAccount("5100", "تكلفة الأطعمة المباعة", "Food COGS", "expense"),
    CoaAccount("5200", "تكلفة المشروبات", "Beverage COGS", "expense"),
    CoaAccount("5300", "عمولة منصات التوصيل", "Delivery Platform Fees", "expense"),
    CoaAccount("5400", "رواتب المطبخ", "Kitchen Payroll", "expense"),
    CoaAccount("2300", "الإكراميات المستحقة", "Tip Pool Payable", "liability"),
]

_FNB_WIDGETS = [
    DashboardWidget("fnb_sales_today", "مبيعات اليوم", "kpi", "sales_today"),
    DashboardWidget("fnb_top_items", "أفضل الأصناف مبيعاً", "table", "top_items_30d"),
    DashboardWidget("fnb_food_cost_pct", "نسبة تكلفة الطعام", "kpi", "food_cost_pct"),
    DashboardWidget("fnb_tip_pool", "رصيد الإكراميات", "kpi", "tip_pool_balance"),
    DashboardWidget("fnb_delivery_split", "توزيع المنصات", "chart", "delivery_platform_split"),
]


# ── Construction / Contracting ──────────────────────────────

_CONSTRUCTION_COA = [
    CoaAccount("1250", "أعمال تحت التنفيذ", "Work In Progress", "asset"),
    CoaAccount("1260", "محتجزات العملاء", "Customer Retention Receivable", "asset"),
    CoaAccount("2250", "محتجزات الموردين", "Vendor Retention Payable", "liability"),
    CoaAccount("4500", "إيرادات العقود", "Contract Revenue", "revenue"),
    CoaAccount("4510", "أوامر التغيير", "Change Orders", "revenue"),
    CoaAccount("5500", "تكلفة المواد", "Materials Cost", "expense"),
    CoaAccount("5510", "تكلفة العمالة", "Labor Cost", "expense"),
    CoaAccount("5520", "تكلفة المقاولين من الباطن", "Subcontractors", "expense"),
    CoaAccount("5530", "تكلفة المعدات", "Equipment Rental", "expense"),
]

_CONSTRUCTION_WIDGETS = [
    DashboardWidget("c_active_projects", "المشاريع النشطة", "kpi", "active_projects"),
    DashboardWidget("c_wip_summary", "ملخص WIP", "table", "wip_per_project"),
    DashboardWidget("c_retention_bal", "محتجزات معلقة", "kpi", "retention_balance"),
    DashboardWidget("c_margin_per_project", "هامش كل مشروع", "chart", "project_margin"),
]


# ── Medical ─────────────────────────────────────────────────

_MEDICAL_COA = [
    CoaAccount("1300", "ذمم تأمين طبي", "Insurance Receivable", "asset"),
    CoaAccount("1310", "مطالبات معلقة", "Pending Claims", "asset"),
    CoaAccount("4600", "إيرادات الاستشارات", "Consultation Revenue", "revenue"),
    CoaAccount("4610", "إيرادات العمليات", "Procedures Revenue", "revenue"),
    CoaAccount("4620", "إيرادات الأدوية", "Pharmacy Revenue", "revenue"),
    CoaAccount("4630", "إيرادات المختبر", "Lab Revenue", "revenue"),
    CoaAccount("5600", "مستلزمات طبية", "Medical Supplies", "expense"),
    CoaAccount("5610", "رواتب الأطباء", "Doctors Payroll", "expense"),
    CoaAccount("5620", "رواتب التمريض", "Nursing Payroll", "expense"),
]

_MEDICAL_WIDGETS = [
    DashboardWidget("m_patient_count", "عدد المرضى اليوم", "kpi", "patients_today"),
    DashboardWidget("m_claims_pending", "مطالبات معلقة", "kpi", "pending_claims_total"),
    DashboardWidget("m_insurance_aging", "تقادم ذمم التأمين", "chart", "insurance_aging"),
    DashboardWidget("m_revenue_mix", "مزيج الإيرادات", "chart", "revenue_mix_medical"),
]


# ── Logistics ───────────────────────────────────────────────

_LOGISTICS_COA = [
    CoaAccount("1400", "مركبات أسطول", "Fleet Vehicles", "asset"),
    CoaAccount("1410", "بطاقات الوقود", "Fuel Cards", "asset"),
    CoaAccount("2400", "ذمم السائقين", "Driver Settlements Payable", "liability"),
    CoaAccount("4700", "إيرادات نقل البضائع", "Freight Revenue", "revenue"),
    CoaAccount("4710", "إيرادات الخدمات اللوجستية", "Logistics Services", "revenue"),
    CoaAccount("5700", "وقود وزيوت", "Fuel & Lubricants", "expense"),
    CoaAccount("5710", "صيانة الأسطول", "Fleet Maintenance", "expense"),
    CoaAccount("5720", "رسوم الطرق", "Road & Toll Fees", "expense"),
    CoaAccount("5730", "رواتب السائقين", "Drivers Payroll", "expense"),
]

_LOGISTICS_WIDGETS = [
    DashboardWidget("l_active_fleet", "الأسطول النشط", "kpi", "active_vehicles"),
    DashboardWidget("l_fuel_spend", "إنفاق الوقود الشهر", "kpi", "fuel_this_month"),
    DashboardWidget("l_driver_settlements", "ذمم السائقين", "table", "driver_settlements"),
    DashboardWidget("l_utilization", "استغلال الأسطول", "chart", "fleet_utilization"),
]


# ── Services (default) ──────────────────────────────────────

_SERVICES_COA = [
    CoaAccount("4800", "إيرادات استشارات", "Consulting Revenue", "revenue"),
    CoaAccount("4810", "إيرادات اشتراكات", "Subscription Revenue (MRR)", "revenue"),
    CoaAccount("4820", "إيرادات المشاريع", "Project-based Revenue", "revenue"),
    CoaAccount("5800", "رواتب فريق المنتج", "Product Team Payroll", "expense"),
    CoaAccount("5810", "رواتب المبيعات", "Sales & BD Payroll", "expense"),
    CoaAccount("5820", "أدوات SaaS", "SaaS Tools", "expense"),
]

_SERVICES_WIDGETS = [
    DashboardWidget("s_mrr", "الإيراد الشهري المتكرر", "kpi", "mrr"),
    DashboardWidget("s_burn", "معدل الحرق الشهري", "kpi", "burn_rate"),
    DashboardWidget("s_runway", "المدى (أشهر)", "kpi", "runway_months"),
    DashboardWidget("s_active_clients", "عملاء نشطون", "kpi", "active_clients"),
]


_PACKS: dict[str, IndustryPack] = {
    "fnb_retail": IndustryPack(
        id="fnb_retail",
        name_ar="المطاعم والتجزئة",
        name_en="F&B and Retail",
        description="POS-integrated COA with tip pooling and delivery platform fees.",
        coa_accounts=_FNB_COA,
        dashboard_widgets=_FNB_WIDGETS,
        workflows=["pos_daily_close", "tip_pool_distribution", "delivery_recon"],
    ),
    "construction": IndustryPack(
        id="construction",
        name_ar="المقاولات",
        name_en="Construction & Contracting",
        description="Project-based accounting with WIP, retention, and progress billing.",
        coa_accounts=_CONSTRUCTION_COA,
        dashboard_widgets=_CONSTRUCTION_WIDGETS,
        workflows=["progress_billing", "wip_revaluation", "retention_release"],
    ),
    "medical": IndustryPack(
        id="medical",
        name_ar="العيادات والمستشفيات",
        name_en="Medical & Clinics",
        description="Patient billing with insurance claim tracking and medical inventory.",
        coa_accounts=_MEDICAL_COA,
        dashboard_widgets=_MEDICAL_WIDGETS,
        workflows=["claim_submission", "claim_adjudication", "patient_billing"],
    ),
    "logistics": IndustryPack(
        id="logistics",
        name_ar="النقل واللوجستيات",
        name_en="Logistics",
        description="Fleet cost tracking, driver settlements, and fuel-card reconciliation.",
        coa_accounts=_LOGISTICS_COA,
        dashboard_widgets=_LOGISTICS_WIDGETS,
        workflows=["driver_settlement", "fuel_card_recon", "vehicle_maintenance"],
    ),
    "services": IndustryPack(
        id="services",
        name_ar="الخدمات والاستشارات",
        name_en="Services / SaaS",
        description="Professional services + SaaS metrics (MRR / burn / runway).",
        coa_accounts=_SERVICES_COA,
        dashboard_widgets=_SERVICES_WIDGETS,
        workflows=["subscription_billing", "project_time_tracking"],
    ),
}


def list_packs() -> list[IndustryPack]:
    return list(_PACKS.values())


def get_pack(pack_id: str) -> Optional[IndustryPack]:
    from typing import Optional
    return _PACKS.get(pack_id)
