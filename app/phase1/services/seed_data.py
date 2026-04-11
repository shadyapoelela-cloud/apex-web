"""
APEX Platform — Seed Data
═══════════════════════════════════════════════════════════════
Initial data: roles, permissions, plans, features, legal documents.
Per execution document sections 3, 4, 5, 10, 13, 15.
"""

import logging
from app.phase1.models.platform_models import (
    Role,
    Permission,
    RolePermission,
    Plan,
    PlanFeature,
    PolicyDocument,
    PolicyType,
    SessionLocal,
    gen_uuid,
)


def seed_all():
    """Seed all initial data. Safe to call multiple times."""
    db = SessionLocal()
    try:
        created = {}
        created["roles"] = _seed_roles(db)
        created["permissions"] = _seed_permissions(db)
        created["role_permissions"] = _seed_role_permissions(db)
        created["plans"] = _seed_plans(db)
        created["plan_features"] = _seed_plan_features(db)
        created["policies"] = _seed_policies(db)
        db.commit()
        return {"success": True, "created": created}
    except Exception:
        db.rollback()
        logging.error("Operation failed", exc_info=True)
        return {"success": False, "error": "Internal server error"}
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════════
# Roles — 10 roles per execution document
# ═══════════════════════════════════════════════════════════════

ROLES = [
    ("guest", "زائر", "Guest"),
    ("registered_user", "مستخدم مسجل", "Registered User"),
    ("client_user", "مستخدم عميل", "Client User"),
    ("client_admin", "مدير عميل", "Client Admin"),
    ("provider_user", "مقدم خدمة", "Provider User"),
    ("provider_admin", "مدير مقدم خدمة", "Provider Admin"),
    ("reviewer", "مراجع", "Reviewer"),
    ("knowledge_reviewer", "مراجع معرفي", "Knowledge Reviewer"),
    ("platform_admin", "مدير المنصة", "Platform Admin"),
    ("super_admin", "المدير العام", "Super Admin"),
]


def _seed_roles(db) -> int:
    count = 0
    for code, name_ar, name_en in ROLES:
        if not db.query(Role).filter(Role.code == code).first():
            db.add(Role(id=gen_uuid(), code=code, name_ar=name_ar, name_en=name_en, is_system=True))
            count += 1
    return count


# ═══════════════════════════════════════════════════════════════
# Permissions — per execution document section 13
# ═══════════════════════════════════════════════════════════════

PERMISSIONS = [
    # COA & Analysis
    ("coa_upload", "رفع شجرة الحسابات", "Upload COA", "coa", "upload"),
    ("coa_view", "عرض شجرة الحسابات", "View COA", "coa", "view"),
    ("analysis_run", "تشغيل التحليل", "Run Analysis", "analysis", "run"),
    ("result_view", "عرض النتائج", "View Results", "result", "view"),
    ("result_details_view", "عرض تفاصيل النتائج", "View Result Details", "result", "view_details"),
    ("result_export", "تصدير النتائج", "Export Results", "result", "export"),
    # Knowledge
    ("knowledge_feedback_submit", "إرسال ملاحظة معرفية", "Submit Knowledge Feedback", "knowledge", "submit"),
    ("knowledge_feedback_review", "مراجعة الملاحظات المعرفية", "Review Knowledge Feedback", "knowledge", "review"),
    ("knowledge_rules_manage", "إدارة القواعد المعرفية", "Manage Knowledge Rules", "knowledge", "manage"),
    # Clients
    ("client_create", "إنشاء عميل", "Create Client", "client", "create"),
    ("client_view_own", "عرض بيانات العميل", "View Own Client", "client", "view_own"),
    ("client_view_all", "عرض كل العملاء", "View All Clients", "client", "view_all"),
    ("client_manage", "إدارة العملاء", "Manage Clients", "client", "manage"),
    # Marketplace
    ("service_request_create", "إنشاء طلب خدمة", "Create Service Request", "marketplace", "create_request"),
    ("service_request_manage", "إدارة طلبات الخدمة", "Manage Service Requests", "marketplace", "manage_request"),
    ("service_task_accept", "قبول مهمة", "Accept Task", "marketplace", "accept_task"),
    ("service_task_manage", "إدارة المهام", "Manage Tasks", "marketplace", "manage_task"),
    # Provider
    ("provider_register", "تسجيل مقدم خدمة", "Register Provider", "provider", "register"),
    ("provider_review", "مراجعة مقدمي الخدمات", "Review Providers", "provider", "review"),
    ("provider_suspend", "تعليق مقدم خدمة", "Suspend Provider", "provider", "suspend"),
    # Admin
    ("plans_manage", "إدارة الخطط", "Manage Plans", "admin", "manage_plans"),
    ("users_manage", "إدارة المستخدمين", "Manage Users", "admin", "manage_users"),
    ("policies_manage", "إدارة السياسات", "Manage Policies", "admin", "manage_policies"),
    ("platform_settings", "إعدادات المنصة", "Platform Settings", "admin", "settings"),
]


def _seed_permissions(db) -> int:
    count = 0
    for code, name_ar, name_en, resource, action in PERMISSIONS:
        if not db.query(Permission).filter(Permission.code == code).first():
            db.add(
                Permission(id=gen_uuid(), code=code, name_ar=name_ar, name_en=name_en, resource=resource, action=action)
            )
            count += 1
    return count


# ═══════════════════════════════════════════════════════════════
# Role ↔ Permission mapping — per document section 13
# ═══════════════════════════════════════════════════════════════

ROLE_PERM_MAP = {
    "registered_user": ["result_view"],
    "client_user": [
        "coa_upload",
        "coa_view",
        "analysis_run",
        "result_view",
        "result_details_view",
        "client_view_own",
        "service_request_create",
        "knowledge_feedback_submit",
    ],
    "client_admin": [
        "coa_upload",
        "coa_view",
        "analysis_run",
        "result_view",
        "result_details_view",
        "result_export",
        "client_create",
        "client_view_own",
        "client_manage",
        "service_request_create",
        "service_request_manage",
        "knowledge_feedback_submit",
    ],
    "provider_user": [
        "service_task_accept",
        "result_view",
    ],
    "provider_admin": [
        "service_task_accept",
        "service_task_manage",
        "result_view",
        "provider_register",
    ],
    "reviewer": [
        "result_view",
        "result_details_view",
        "knowledge_feedback_review",
        "provider_review",
    ],
    "knowledge_reviewer": [
        "result_view",
        "result_details_view",
        "knowledge_feedback_review",
        "knowledge_rules_manage",
    ],
    "platform_admin": [
        "coa_upload",
        "coa_view",
        "analysis_run",
        "result_view",
        "result_details_view",
        "result_export",
        "client_view_all",
        "client_manage",
        "service_request_manage",
        "service_task_manage",
        "knowledge_feedback_review",
        "knowledge_rules_manage",
        "provider_review",
        "provider_suspend",
        "plans_manage",
        "users_manage",
        "policies_manage",
    ],
    "super_admin": [p[0] for p in PERMISSIONS],  # All permissions
}


def _seed_role_permissions(db) -> int:
    count = 0
    for role_code, perm_codes in ROLE_PERM_MAP.items():
        role = db.query(Role).filter(Role.code == role_code).first()
        if not role:
            continue
        for perm_code in perm_codes:
            perm = db.query(Permission).filter(Permission.code == perm_code).first()
            if not perm:
                continue
            existing = (
                db.query(RolePermission)
                .filter(RolePermission.role_id == role.id, RolePermission.permission_id == perm.id)
                .first()
            )
            if not existing:
                db.add(RolePermission(id=gen_uuid(), role_id=role.id, permission_id=perm.id))
                count += 1
    return count


# ═══════════════════════════════════════════════════════════════
# Plans — 5 plans per execution document
# ═══════════════════════════════════════════════════════════════

PLANS = [
    {
        "code": "free",
        "name_ar": "مجاني",
        "name_en": "Free",
        "price_m": 0,
        "price_y": 0,
        "target_ar": "فرد أو جهة تريد التجربة",
        "target_en": "Individual or entity trying the platform",
        "sort": 0,
    },
    {
        "code": "pro",
        "name_ar": "احترافي",
        "name_en": "Pro",
        "price_m": 99,
        "price_y": 990,
        "target_ar": "محترف فردي",
        "target_en": "Individual professional",
        "sort": 1,
    },
    {
        "code": "business",
        "name_ar": "أعمال",
        "name_en": "Business",
        "price_m": 299,
        "price_y": 2990,
        "target_ar": "مكتب / شركة",
        "target_en": "Office / Company",
        "sort": 2,
    },
    {
        "code": "expert",
        "name_ar": "خبير",
        "name_en": "Expert",
        "price_m": 0,
        "price_y": 0,
        "target_ar": "مقدم خدمة معتمد",
        "target_en": "Verified service provider",
        "sort": 3,
    },
    {
        "code": "enterprise",
        "name_ar": "مؤسسي",
        "name_en": "Enterprise",
        "price_m": 0,
        "price_y": 0,
        "target_ar": "جهة كبيرة أو تنظيمية",
        "target_en": "Large or regulatory entity",
        "sort": 4,
    },
]


def _seed_plans(db) -> int:
    count = 0
    for p in PLANS:
        if not db.query(Plan).filter(Plan.code == p["code"]).first():
            db.add(
                Plan(
                    id=gen_uuid(),
                    code=p["code"],
                    name_ar=p["name_ar"],
                    name_en=p["name_en"],
                    price_monthly_sar=p["price_m"],
                    price_yearly_sar=p["price_y"],
                    target_user_ar=p["target_ar"],
                    target_user_en=p["target_en"],
                    sort_order=p["sort"],
                )
            )
            count += 1
    return count


# ═══════════════════════════════════════════════════════════════
# Plan Features — entitlement matrix per document section 5/10
# ═══════════════════════════════════════════════════════════════

# feature_code: (name_ar, value_type)
FEATURE_DEFS = {
    "coa_uploads_limit": ("حد رفع شجرة الحسابات شهرياً", "integer"),
    "analysis_runs_limit": ("حد التحليلات شهرياً", "integer"),
    "result_details_access": ("الوصول لتفاصيل النتائج", "boolean"),
    "result_export": ("تصدير النتائج", "boolean"),
    "knowledge_mode_access": ("الوصول لوضع المعرفة", "boolean"),
    "knowledge_feedback": ("إرسال ملاحظات معرفية", "boolean"),
    "marketplace_access": ("الوصول لسوق الخدمات", "string"),  # none, view, request, manage
    "provider_registration_access": ("تسجيل كمقدم خدمة", "boolean"),
    "team_members_limit": ("حد أعضاء الفريق", "integer"),
    "priority_support": ("دعم أولوية", "boolean"),
    "api_access": ("الوصول لـ API", "boolean"),
    "enterprise_controls": ("أدوات التحكم المؤسسي", "boolean"),
}

# plan_code: {feature_code: value}
PLAN_FEATURES = {
    "free": {
        "coa_uploads_limit": "2",
        "analysis_runs_limit": "2",
        "result_details_access": "false",
        "result_export": "false",
        "knowledge_mode_access": "false",
        "knowledge_feedback": "false",
        "marketplace_access": "view",
        "provider_registration_access": "false",
        "team_members_limit": "0",
        "priority_support": "false",
        "api_access": "false",
        "enterprise_controls": "false",
    },
    "pro": {
        "coa_uploads_limit": "20",
        "analysis_runs_limit": "20",
        "result_details_access": "true",
        "result_export": "true",
        "knowledge_mode_access": "false",
        "knowledge_feedback": "true",
        "marketplace_access": "request",
        "provider_registration_access": "false",
        "team_members_limit": "2",
        "priority_support": "false",
        "api_access": "false",
        "enterprise_controls": "false",
    },
    "business": {
        "coa_uploads_limit": "100",
        "analysis_runs_limit": "100",
        "result_details_access": "true",
        "result_export": "true",
        "knowledge_mode_access": "true",
        "knowledge_feedback": "true",
        "marketplace_access": "manage",
        "provider_registration_access": "false",
        "team_members_limit": "10",
        "priority_support": "true",
        "api_access": "false",
        "enterprise_controls": "false",
    },
    "expert": {
        "coa_uploads_limit": "0",
        "analysis_runs_limit": "0",
        "result_details_access": "true",
        "result_export": "false",
        "knowledge_mode_access": "false",
        "knowledge_feedback": "false",
        "marketplace_access": "provide",
        "provider_registration_access": "true",
        "team_members_limit": "0",
        "priority_support": "false",
        "api_access": "false",
        "enterprise_controls": "false",
    },
    "enterprise": {
        "coa_uploads_limit": "unlimited",
        "analysis_runs_limit": "unlimited",
        "result_details_access": "true",
        "result_export": "true",
        "knowledge_mode_access": "true",
        "knowledge_feedback": "true",
        "marketplace_access": "manage",
        "provider_registration_access": "false",
        "team_members_limit": "unlimited",
        "priority_support": "true",
        "api_access": "true",
        "enterprise_controls": "true",
    },
}


def _seed_plan_features(db) -> int:
    count = 0
    for plan_code, features in PLAN_FEATURES.items():
        plan = db.query(Plan).filter(Plan.code == plan_code).first()
        if not plan:
            continue
        for feat_code, value in features.items():
            existing = (
                db.query(PlanFeature)
                .filter(PlanFeature.plan_id == plan.id, PlanFeature.feature_code == feat_code)
                .first()
            )
            if not existing:
                feat_def = FEATURE_DEFS.get(feat_code, ("", "string"))
                db.add(
                    PlanFeature(
                        id=gen_uuid(),
                        plan_id=plan.id,
                        feature_code=feat_code,
                        feature_name_ar=feat_def[0],
                        value_type=feat_def[1] if value not in ("unlimited",) else "string",
                        value=value,
                    )
                )
                count += 1
    return count


# ═══════════════════════════════════════════════════════════════
# Legal Policies — per document section 15
# ═══════════════════════════════════════════════════════════════


def _seed_policies(db) -> int:
    count = 0
    policies = [
        {
            "type": PolicyType.terms_of_service.value,
            "version": "1.0",
            "title_ar": "شروط وأحكام الاستخدام",
            "title_en": "Terms of Service",
            "content_ar": """شروط استخدام منصة أبكس للتحليل المالي والخدمات المهنية.
بالتسجيل في المنصة، يوافق المستخدم على:
1. صحة البيانات المقدمة.
2. الاستخدام المشروع للمنصة.
3. عدم رفع محتوى غير مصرح به.
4. سداد المدفوعات المستحقة.
5. عدم التحايل على أنظمة المنصة.
6. احترام طبيعة النتائج التحليلية وعدم اعتبارها نصيحة مالية ملزمة.
تحتفظ المنصة بحق تعليق أو إنهاء أي حساب يخالف هذه الشروط.""",
        },
        {
            "type": PolicyType.privacy_policy.value,
            "version": "1.0",
            "title_ar": "سياسة الخصوصية",
            "title_en": "Privacy Policy",
            "content_ar": """سياسة خصوصية منصة أبكس.
نلتزم بحماية بيانات المستخدمين وفقاً لنظام حماية البيانات الشخصية (PDPL).
البيانات المجمعة تستخدم فقط لتقديم الخدمات وتحسينها.
لا يتم مشاركة البيانات مع أطراف ثالثة إلا بموافقة صريحة أو بموجب القانون.""",
        },
        {
            "type": PolicyType.provider_policy.value,
            "version": "1.0",
            "title_ar": "سياسة مقدمي الخدمات",
            "title_en": "Service Provider Policy",
            "content_ar": """سياسة مقدمي الخدمات في منصة أبكس.
يلتزم مقدم الخدمة بـ:
1. صحة المستندات والشهادات المقدمة.
2. العمل ضمن النطاق المعتمد فقط.
3. السرية التامة لبيانات العملاء.
4. رفع مستندات المدخلات المطلوبة لكل مهمة.
5. رفع المخرجات النهائية المطلوبة في الوقت المحدد.
6. التعاون في المراجعة والتقييم.
7. قبول نسبة العمولة وسياسات المنصة.
عدم الالتزام برفع المستندات والمخرجات المطلوبة يؤدي لتعليق الحساب ومنع الفرص الجديدة.""",
        },
        {
            "type": PolicyType.acceptable_use.value,
            "version": "1.0",
            "title_ar": "سياسة الاستخدام المقبول",
            "title_en": "Acceptable Use Policy",
            "content_ar": """سياسة الاستخدام المقبول لمنصة أبكس.
يُحظر استخدام المنصة لأي غرض غير قانوني أو احتيالي.
يُحظر محاولة الوصول غير المصرح به لبيانات الآخرين.
يُحظر رفع ملفات تحتوي على برمجيات ضارة.""",
        },
        {
            "type": PolicyType.knowledge_contributor_policy.value,
            "version": "1.0",
            "title_ar": "سياسة المساهمين في المعرفة",
            "title_en": "Knowledge Contributor Policy",
            "content_ar": """سياسة المساهمة في العقل المعرفي لمنصة أبكس.
يلتزم المساهم بـ:
1. عدم محاولة تغيير النتائج مباشرة.
2. قبول أن الملاحظات تخضع للمراجعة.
3. عدم إساءة استخدام نظام الملاحظات.""",
        },
    ]

    for p in policies:
        existing = (
            db.query(PolicyDocument)
            .filter(
                PolicyDocument.policy_type == p["type"],
                PolicyDocument.version == p["version"],
            )
            .first()
        )
        if not existing:
            db.add(
                PolicyDocument(
                    id=gen_uuid(),
                    policy_type=p["type"],
                    version=p["version"],
                    title_ar=p["title_ar"],
                    title_en=p["title_en"],
                    content_ar=p["content_ar"],
                    content_en=p.get("content_en", ""),
                    is_current=True,
                )
            )
            count += 1

    return count
