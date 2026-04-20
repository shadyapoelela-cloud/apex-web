"""Seed service — populates system-wide master data (permissions).

Permissions are tenant-agnostic (shared across all tenants).
Run once after Alembic migration creates tables.

Usage:
  from app.pilot.services.seed import seed_permissions
  seed_permissions(db)
"""

from sqlalchemy.orm import Session
from app.pilot.models import Permission


# Master list of (resource, action, name_ar, name_en, category, risk) tuples.
# Total: ~180 permissions across 12 categories.
PERMISSIONS = [
    # ─── Tenant & Admin ────────────────────────────────────────
    ("tenant_settings", "view", "عرض إعدادات الشركة", "View Company Settings", "admin", "normal"),
    ("tenant_settings", "edit", "تعديل إعدادات الشركة", "Edit Company Settings", "admin", "sensitive"),
    ("tenant_billing", "view", "عرض الفواتير والاشتراك", "View Billing", "admin", "sensitive"),
    ("tenant_billing", "manage", "إدارة الاشتراك", "Manage Subscription", "admin", "critical"),

    # ─── Entity & Branch ────────────────────────────────────────
    ("entity", "view", "عرض الكيانات", "View Entities", "structure", "normal"),
    ("entity", "create", "إنشاء كيان", "Create Entity", "structure", "sensitive"),
    ("entity", "edit", "تعديل كيان", "Edit Entity", "structure", "sensitive"),
    ("entity", "delete", "حذف كيان", "Delete Entity", "structure", "critical"),
    ("branch", "view", "عرض الفروع", "View Branches", "structure", "normal"),
    ("branch", "create", "إنشاء فرع", "Create Branch", "structure", "sensitive"),
    ("branch", "edit", "تعديل فرع", "Edit Branch", "structure", "normal"),
    ("branch", "delete", "حذف فرع", "Delete Branch", "structure", "sensitive"),

    # ─── User & RBAC ────────────────────────────────────────
    ("user", "view", "عرض المستخدمين", "View Users", "security", "normal"),
    ("user", "create", "إنشاء مستخدم", "Create User", "security", "sensitive"),
    ("user", "invite", "دعوة مستخدم", "Invite User", "security", "sensitive"),
    ("user", "edit", "تعديل بيانات مستخدم", "Edit User", "security", "sensitive"),
    ("user", "suspend", "تعليق مستخدم", "Suspend User", "security", "sensitive"),
    ("user", "delete", "حذف مستخدم", "Delete User", "security", "critical"),
    ("role", "view", "عرض الأدوار", "View Roles", "security", "normal"),
    ("role", "create", "إنشاء دور", "Create Role", "security", "sensitive"),
    ("role", "edit", "تعديل دور", "Edit Role", "security", "sensitive"),
    ("role", "delete", "حذف دور", "Delete Role", "security", "critical"),
    ("role", "assign", "تعيين دور لمستخدم", "Assign Role", "security", "sensitive"),

    # ─── Currency & FX ────────────────────────────────────────
    ("currency", "view", "عرض العُمَلات", "View Currencies", "finance", "normal"),
    ("currency", "create", "إضافة عملة", "Add Currency", "finance", "sensitive"),
    ("currency", "edit", "تعديل عملة", "Edit Currency", "finance", "sensitive"),
    ("fx_rate", "view", "عرض أسعار الصرف", "View FX Rates", "finance", "normal"),
    ("fx_rate", "create", "إدخال سعر صرف", "Create FX Rate", "finance", "sensitive"),
    ("fx_rate", "edit", "تعديل سعر صرف", "Edit FX Rate", "finance", "sensitive"),

    # ─── Chart of Accounts + Cost/Profit Centers + Dimensions ──────────
    ("chart_of_accounts", "view", "عرض دليل الحسابات", "View CoA", "finance", "normal"),
    ("chart_of_accounts", "create", "إضافة حساب", "Create Account", "finance", "sensitive"),
    ("chart_of_accounts", "edit", "تعديل حساب", "Edit Account", "finance", "sensitive"),
    ("chart_of_accounts", "delete", "حذف حساب", "Delete Account", "finance", "critical"),
    ("cost_center", "view", "عرض مراكز التكلفة", "View Cost Centers", "finance", "normal"),
    ("cost_center", "create", "إضافة مركز تكلفة", "Create Cost Center", "finance", "normal"),
    ("cost_center", "edit", "تعديل مركز تكلفة", "Edit Cost Center", "finance", "normal"),
    ("profit_center", "view", "عرض مراكز الربحية", "View Profit Centers", "finance", "normal"),
    ("profit_center", "create", "إضافة مركز ربحية", "Create Profit Center", "finance", "normal"),
    ("profit_center", "edit", "تعديل مركز ربحية", "Edit Profit Center", "finance", "normal"),
    ("dimension", "view", "عرض الأبعاد المحاسبية", "View Dimensions", "finance", "normal"),
    ("dimension", "manage", "إدارة الأبعاد", "Manage Dimensions", "finance", "normal"),

    # ─── Journal Entries ────────────────────────────────────────
    ("journal_entry", "view", "عرض قيود اليومية", "View Journal Entries", "finance", "normal"),
    ("journal_entry", "create", "إنشاء قيد", "Create JE", "finance", "normal"),
    ("journal_entry", "edit", "تعديل قيد (مسودة)", "Edit JE Draft", "finance", "normal"),
    ("journal_entry", "delete", "حذف قيد (مسودة)", "Delete JE Draft", "finance", "sensitive"),
    ("journal_entry", "submit", "إرسال قيد للاعتماد", "Submit JE for Approval", "finance", "normal"),
    ("journal_entry", "approve", "اعتماد قيد", "Approve JE", "finance", "sensitive"),
    ("journal_entry", "reject", "رفض قيد", "Reject JE", "finance", "sensitive"),
    ("journal_entry", "post", "ترحيل قيد", "Post JE", "finance", "sensitive"),
    ("journal_entry", "reverse", "عكس قيد", "Reverse JE", "finance", "critical"),

    # ─── Product & Inventory ────────────────────────────────────
    ("product", "view", "عرض الأصناف", "View Products", "inventory", "normal"),
    ("product", "create", "إضافة صنف", "Create Product", "inventory", "normal"),
    ("product", "edit", "تعديل صنف", "Edit Product", "inventory", "normal"),
    ("product", "delete", "حذف صنف", "Delete Product", "inventory", "sensitive"),
    ("variant", "view", "عرض المتغيّرات", "View Variants", "inventory", "normal"),
    ("variant", "create", "إضافة متغيّر", "Create Variant", "inventory", "normal"),
    ("variant", "edit", "تعديل متغيّر", "Edit Variant", "inventory", "normal"),
    ("warehouse", "view", "عرض المستودعات", "View Warehouses", "inventory", "normal"),
    ("warehouse", "create", "إضافة مستودع", "Create Warehouse", "inventory", "sensitive"),
    ("warehouse", "edit", "تعديل مستودع", "Edit Warehouse", "inventory", "sensitive"),
    ("stock", "view", "عرض المخزون", "View Stock", "inventory", "normal"),
    ("stock", "adjust", "تسوية مخزون", "Stock Adjustment", "inventory", "sensitive"),
    ("stock", "transfer", "نقل مخزون بين الفروع", "Transfer Stock", "inventory", "sensitive"),
    ("stock", "count", "جرد مخزون", "Stock Count", "inventory", "sensitive"),
    ("barcode", "view", "عرض الباركود", "View Barcodes", "inventory", "normal"),
    ("barcode", "generate", "توليد باركود", "Generate Barcode", "inventory", "normal"),
    ("barcode", "print", "طباعة ملصقات باركود", "Print Barcodes", "inventory", "normal"),

    # ─── Pricing ────────────────────────────────────────
    ("price_list", "view", "عرض قوائم الأسعار", "View Price Lists", "sales", "normal"),
    ("price_list", "create", "إنشاء قائمة أسعار", "Create Price List", "sales", "sensitive"),
    ("price_list", "edit", "تعديل قائمة أسعار", "Edit Price List", "sales", "sensitive"),
    ("price_list", "publish", "نشر قائمة أسعار", "Publish Price List", "sales", "sensitive"),

    # ─── POS ────────────────────────────────────────
    ("pos_session", "view", "عرض جلسات نقاط البيع", "View POS Sessions", "pos", "normal"),
    ("pos_session", "open", "فتح جلسة", "Open POS Session", "pos", "normal"),
    ("pos_session", "close", "إقفال جلسة", "Close POS Session", "pos", "normal"),
    ("pos_transaction", "view", "عرض فواتير البيع", "View POS Transactions", "pos", "normal"),
    ("pos_transaction", "create", "إصدار فاتورة بيع", "Create POS Sale", "pos", "normal"),
    ("pos_transaction", "refund", "استرجاع", "Refund Sale", "pos", "sensitive"),
    ("pos_transaction", "void", "إلغاء معاملة", "Void Transaction", "pos", "sensitive"),
    ("pos_transaction", "apply_discount", "تطبيق خصم", "Apply Discount", "pos", "sensitive"),
    ("pos_cash_drawer", "open", "فتح الدرج", "Open Cash Drawer", "pos", "sensitive"),

    # ─── Sales ────────────────────────────────────────
    ("sale_invoice", "view", "عرض فواتير المبيعات", "View Sale Invoices", "sales", "normal"),
    ("sale_invoice", "create", "إنشاء فاتورة مبيعات", "Create Sale Invoice", "sales", "normal"),
    ("sale_invoice", "edit", "تعديل فاتورة", "Edit Invoice", "sales", "normal"),
    ("sale_invoice", "submit", "إرسال للاعتماد", "Submit Invoice", "sales", "normal"),
    ("sale_invoice", "approve", "اعتماد فاتورة", "Approve Invoice", "sales", "sensitive"),
    ("sale_invoice", "post", "ترحيل فاتورة", "Post Invoice", "sales", "sensitive"),
    ("sale_invoice", "cancel", "إلغاء فاتورة", "Cancel Invoice", "sales", "sensitive"),
    ("credit_note", "view", "عرض إشعارات الدائن", "View Credit Notes", "sales", "normal"),
    ("credit_note", "create", "إنشاء إشعار دائن", "Create Credit Note", "sales", "sensitive"),
    ("customer", "view", "عرض العملاء", "View Customers", "sales", "normal"),
    ("customer", "create", "إضافة عميل", "Create Customer", "sales", "normal"),
    ("customer", "edit", "تعديل عميل", "Edit Customer", "sales", "normal"),
    ("customer", "manage_credit", "إدارة حدود ائتمان", "Manage Credit Limits", "sales", "sensitive"),

    # ─── Purchasing ────────────────────────────────────
    ("purchase_order", "view", "عرض أوامر الشراء", "View POs", "purchasing", "normal"),
    ("purchase_order", "create", "إنشاء أمر شراء", "Create PO", "purchasing", "normal"),
    ("purchase_order", "edit", "تعديل أمر شراء", "Edit PO", "purchasing", "normal"),
    ("purchase_order", "submit", "إرسال للاعتماد", "Submit PO", "purchasing", "normal"),
    ("purchase_order", "approve", "اعتماد أمر شراء", "Approve PO", "purchasing", "sensitive"),
    ("purchase_order", "receive", "استلام بضاعة", "Receive Goods", "purchasing", "normal"),
    ("purchase_order", "close", "إقفال أمر شراء", "Close PO", "purchasing", "normal"),
    ("purchase_invoice", "view", "عرض فواتير الموردين", "View Vendor Bills", "purchasing", "normal"),
    ("purchase_invoice", "create", "إنشاء فاتورة مورد", "Create Vendor Bill", "purchasing", "normal"),
    ("purchase_invoice", "approve", "اعتماد فاتورة مورد", "Approve Vendor Bill", "purchasing", "sensitive"),
    ("purchase_invoice", "pay", "دفع فاتورة مورد", "Pay Vendor Bill", "purchasing", "sensitive"),
    ("vendor", "view", "عرض الموردين", "View Vendors", "purchasing", "normal"),
    ("vendor", "create", "إضافة مورد", "Create Vendor", "purchasing", "normal"),
    ("vendor", "edit", "تعديل مورد", "Edit Vendor", "purchasing", "normal"),

    # ─── HR & Payroll ────────────────────────────────────
    ("employee", "view", "عرض الموظفين", "View Employees", "hr", "normal"),
    ("employee", "create", "إضافة موظف", "Create Employee", "hr", "sensitive"),
    ("employee", "edit", "تعديل موظف", "Edit Employee", "hr", "sensitive"),
    ("employee", "view_salary", "عرض الرواتب", "View Salaries", "hr", "sensitive"),
    ("employee", "edit_salary", "تعديل راتب", "Edit Salary", "hr", "critical"),
    ("payroll", "view", "عرض الرواتب", "View Payroll", "hr", "sensitive"),
    ("payroll", "run", "تشغيل الرواتب", "Run Payroll", "hr", "critical"),
    ("payroll", "submit", "إرسال الرواتب للاعتماد", "Submit Payroll", "hr", "critical"),
    ("payroll", "approve", "اعتماد الرواتب", "Approve Payroll", "hr", "critical"),
    ("payroll", "disburse", "صرف الرواتب", "Disburse Payroll", "hr", "critical"),
    ("leave", "view", "عرض الإجازات", "View Leaves", "hr", "normal"),
    ("leave", "approve", "اعتماد إجازة", "Approve Leave", "hr", "normal"),

    # ─── Payments ────────────────────────────────────
    ("payment", "view", "عرض المدفوعات", "View Payments", "finance", "normal"),
    ("payment", "create", "إنشاء مدفوعة", "Create Payment", "finance", "sensitive"),
    ("payment", "approve", "اعتماد مدفوعة", "Approve Payment", "finance", "critical"),
    ("bank_reconciliation", "view", "عرض المطابقة البنكية", "View Bank Recon", "finance", "normal"),
    ("bank_reconciliation", "match", "مطابقة معاملات", "Match Transactions", "finance", "sensitive"),

    # ─── Period Close ────────────────────────────────────
    ("period_close", "view", "عرض إقفال الفترة", "View Period Close", "finance", "normal"),
    ("period_close", "initiate", "بدء إقفال الفترة", "Initiate Close", "finance", "sensitive"),
    ("period_close", "approve", "اعتماد إقفال", "Approve Close", "finance", "critical"),
    ("period_close", "rollback", "تراجع عن إقفال", "Rollback Close", "finance", "critical"),

    # ─── Reports & Dashboards ────────────────────────────
    ("report", "view", "عرض التقارير", "View Reports", "reports", "normal"),
    ("report", "export", "تصدير تقارير", "Export Reports", "reports", "normal"),
    ("dashboard", "view", "عرض لوحات المعلومات", "View Dashboards", "reports", "normal"),
    ("dashboard", "customize", "تخصيص لوحة معلومات", "Customize Dashboard", "reports", "normal"),
    ("financial_statements", "view", "عرض القوائم المالية", "View Financial Statements", "reports", "sensitive"),
    ("financial_statements", "generate", "توليد قوائم مالية", "Generate Financials", "reports", "sensitive"),

    # ─── Documents ────────────────────────────────────
    ("document", "view", "عرض الوثائق", "View Documents", "docs", "normal"),
    ("document", "upload", "رفع وثيقة", "Upload Document", "docs", "normal"),
    ("document", "download", "تحميل وثيقة", "Download Document", "docs", "normal"),
    ("document", "delete", "حذف وثيقة", "Delete Document", "docs", "sensitive"),

    # ─── Compliance: ZATCA / GOSI / WPS / Tax ────────────
    ("zatca", "view", "عرض حالة ZATCA", "View ZATCA Status", "compliance", "normal"),
    ("zatca", "submit", "إرسال فاتورة لـ ZATCA", "Submit to ZATCA", "compliance", "sensitive"),
    ("zatca", "retry", "إعادة إرسال", "Retry ZATCA", "compliance", "sensitive"),
    ("zatca", "manage_csid", "إدارة شهادة CSID", "Manage CSID", "compliance", "critical"),
    ("gosi", "view", "عرض تقرير GOSI", "View GOSI", "compliance", "sensitive"),
    ("gosi", "submit", "إرسال GOSI", "Submit GOSI", "compliance", "critical"),
    ("wps", "view", "عرض WPS", "View WPS", "compliance", "sensitive"),
    ("wps", "submit", "إرسال ملف SIF", "Submit WPS SIF", "compliance", "critical"),
    ("vat_return", "view", "عرض إقرارات VAT", "View VAT Returns", "compliance", "sensitive"),
    ("vat_return", "prepare", "إعداد إقرار VAT", "Prepare VAT Return", "compliance", "sensitive"),
    ("vat_return", "submit", "إرسال إقرار VAT", "Submit VAT Return", "compliance", "critical"),
    ("zakat", "view", "عرض الزكاة", "View Zakat", "compliance", "sensitive"),
    ("zakat", "calculate", "احتساب الزكاة", "Calculate Zakat", "compliance", "sensitive"),
    ("uae_ct", "view", "عرض ضريبة الشركات الإماراتية", "View UAE CT", "compliance", "sensitive"),
    ("uae_ct", "submit", "إرسال ضريبة الشركات الإماراتية", "Submit UAE CT", "compliance", "critical"),

    # ─── Audit trail ────────────────────────────────────
    ("audit_log", "view", "عرض سجل التدقيق", "View Audit Log", "audit", "sensitive"),
    ("audit_log", "export", "تصدير سجل التدقيق", "Export Audit Log", "audit", "sensitive"),

    # ─── AI features ────────────────────────────────────
    ("ai_copilot", "use", "استخدام المساعد الذكي", "Use AI Copilot", "ai", "normal"),
    ("ai_anomalies", "view", "عرض كشف الشذوذ", "View AI Anomalies", "ai", "normal"),
    ("ai_reconciliation", "use", "المطابقات الذكية", "Use AI Reconciliation", "ai", "normal"),
    ("ai_analyst", "use", "استخدام المحلل المالي", "Use AI Analyst", "ai", "normal"),
]


def seed_permissions(db):
    """Upsert all permissions. Safe to run multiple times."""
    from app.pilot.models.rbac import PilotPermission

    existing = {(p.resource, p.action): p for p in db.query(PilotPermission).all()}
    added = 0
    for resource, action, name_ar, name_en, category, risk in PERMISSIONS:
        key = (resource, action)
        if key in existing:
            p = existing[key]
            p.name_ar = name_ar
            p.name_en = name_en
            p.category = category
            p.risk_level = risk
        else:
            p = PilotPermission(
                resource=resource,
                action=action,
                name_ar=name_ar,
                name_en=name_en,
                category=category,
                risk_level=risk,
            )
            db.add(p)
            added += 1
    db.commit()
    return {"total_permissions": len(PERMISSIONS), "added": added, "existing": len(existing)}
