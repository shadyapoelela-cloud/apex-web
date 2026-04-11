"""
APEX Phase 7 — Seed Data for Task Types & Document Requirements
Per Execution Master §8
"""

from app.phase1.models.platform_models import SessionLocal, gen_uuid, utcnow

TASK_TYPES_DATA = [
    {
        "code": "bookkeeping",
        "name_ar": "مسك الدفاتر والقيود المحاسبية",
        "name_en": "Bookkeeping",
        "inputs": [
            ("مصادر القيود", "Journal entry sources", True),
            ("كشف حساب بنكي", "Bank statement", True),
            ("فواتير المبيعات والمشتريات", "Sales & purchase invoices", True),
            ("شجرة الحسابات", "Chart of accounts", False),
        ],
        "outputs": [
            ("ملف قيود منظم", "Organized journal entries file", True),
            ("ملاحظات التسوية", "Reconciliation notes", True),
            ("تقرير ملخص", "Summary report", False),
        ],
    },
    {
        "code": "financial_statement_preparation",
        "name_ar": "إعداد القوائم المالية",
        "name_en": "Financial Statement Preparation",
        "inputs": [
            ("ميزان المراجعة", "Trial balance", True),
            ("السياسات المحاسبية", "Accounting policies", True),
            ("أرصدة افتتاحية", "Opening balances", True),
        ],
        "outputs": [
            ("القوائم المالية الكاملة", "Complete financial statements", True),
            ("الإيضاحات", "Notes to financial statements", True),
            ("ملخص تنفيذي", "Executive summary", False),
        ],
    },
    {
        "code": "review_vat",
        "name_ar": "مراجعة ضريبة القيمة المضافة",
        "name_en": "VAT Review",
        "inputs": [
            ("ملفات ضريبية", "Tax files", True),
            ("فواتير", "Invoices", True),
            ("إقرارات سابقة", "Previous declarations", True),
        ],
        "outputs": [
            ("مذكرة المراجعة", "Review memo", True),
            ("قائمة الملاحظات", "Findings list", True),
            ("خطة الإجراءات", "Action plan", True),
        ],
    },
    {
        "code": "review_policy_hr",
        "name_ar": "مراجعة سياسات الموارد البشرية",
        "name_en": "HR Policy Review",
        "inputs": [
            ("السياسات الحالية", "Current policies", True),
            ("الهيكل التنظيمي", "Organization structure", True),
            ("العقود", "Contracts", False),
        ],
        "outputs": [
            ("تقرير مراجعة السياسات", "Policy review report", True),
            ("قائمة الفجوات", "Gap list", True),
        ],
    },
    {
        "code": "tax_filing",
        "name_ar": "تقديم الإقرارات الضريبية",
        "name_en": "Tax Filing",
        "inputs": [
            ("القوائم المالية", "Financial statements", True),
            ("بيانات الضريبة", "Tax data", True),
            ("إقرارات سابقة", "Previous filings", False),
        ],
        "outputs": [
            ("الإقرار الضريبي المكتمل", "Completed tax return", True),
            ("حسابات الضريبة", "Tax calculations", True),
        ],
    },
    {
        "code": "zakat_calculation",
        "name_ar": "حساب الزكاة",
        "name_en": "Zakat Calculation",
        "inputs": [
            ("الميزانية العمومية", "Balance sheet", True),
            ("بيانات الأصول", "Asset data", True),
        ],
        "outputs": [
            ("حساب وعاء الزكاة", "Zakat base calculation", True),
            ("تقرير الزكاة", "Zakat report", True),
        ],
    },
    {
        "code": "audit_support",
        "name_ar": "دعم التدقيق",
        "name_en": "Audit Support",
        "inputs": [
            ("القوائم المالية", "Financial statements", True),
            ("دفتر الأستاذ", "General ledger", True),
            ("المستندات المؤيدة", "Supporting documents", True),
        ],
        "outputs": [
            ("ملف التدقيق", "Audit file", True),
            ("جدول التعديلات", "Adjustments schedule", True),
            ("خطاب التمثيل", "Representation letter", False),
        ],
    },
    {
        "code": "payroll_processing",
        "name_ar": "معالجة الرواتب",
        "name_en": "Payroll Processing",
        "inputs": [
            ("بيانات الموظفين", "Employee data", True),
            ("سجل الحضور", "Attendance records", True),
            ("جدول البدلات", "Allowances schedule", False),
        ],
        "outputs": [
            ("كشف الرواتب", "Payroll sheet", True),
            ("ملف حماية الأجور", "Wage protection file", True),
            ("قيود الرواتب", "Payroll journal entries", True),
        ],
    },
    {
        "code": "financial_analysis",
        "name_ar": "التحليل المالي",
        "name_en": "Financial Analysis",
        "inputs": [
            ("القوائم المالية", "Financial statements", True),
            ("بيانات القطاع", "Sector data", False),
        ],
        "outputs": [
            ("تقرير التحليل المالي", "Financial analysis report", True),
            ("النسب والمؤشرات", "Ratios and indicators", True),
            ("التوصيات", "Recommendations", True),
        ],
    },
    {
        "code": "compliance_review",
        "name_ar": "مراجعة الامتثال",
        "name_en": "Compliance Review",
        "inputs": [
            ("السياسات والإجراءات", "Policies and procedures", True),
            ("المتطلبات التنظيمية", "Regulatory requirements", True),
        ],
        "outputs": [
            ("تقرير الامتثال", "Compliance report", True),
            ("خطة المعالجة", "Remediation plan", True),
        ],
    },
]


def seed_task_types():
    """Seed task types and their document requirements"""
    db = SessionLocal()
    try:
        from app.phase7.models.phase7_models import TaskType, TaskDocumentRequirement, DocRequirementType

        count = 0
        for tt_data in TASK_TYPES_DATA:
            existing = db.query(TaskType).filter(TaskType.code == tt_data["code"]).first()
            if existing:
                continue

            tt = TaskType(id=gen_uuid(), code=tt_data["code"], name_ar=tt_data["name_ar"], name_en=tt_data["name_en"])
            db.add(tt)
            db.flush()

            for i, (name_ar, name_en, mandatory) in enumerate(tt_data.get("inputs", [])):
                db.add(
                    TaskDocumentRequirement(
                        id=gen_uuid(),
                        task_type_id=tt.id,
                        requirement_type=DocRequirementType.input_required,
                        document_name_ar=name_ar,
                        document_name_en=name_en,
                        is_mandatory=mandatory,
                        sort_order=i,
                    )
                )

            for i, (name_ar, name_en, mandatory) in enumerate(tt_data.get("outputs", [])):
                db.add(
                    TaskDocumentRequirement(
                        id=gen_uuid(),
                        task_type_id=tt.id,
                        requirement_type=DocRequirementType.output_required,
                        document_name_ar=name_ar,
                        document_name_en=name_en,
                        is_mandatory=mandatory,
                        sort_order=i,
                    )
                )

            count += 1

        db.commit()
        return f"Seeded {count} task types with requirements"
    except Exception as e:
        db.rollback()
        return f"Seed error: {e}"
    finally:
        db.close()
