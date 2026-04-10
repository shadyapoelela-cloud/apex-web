import re
from typing import Optional

# Keywords with weights: (keyword, weight)
# Higher weight = stronger signal for intent
INTENT_MAP = {
    'financial_analysis': [
        ('تحليل مالي', 3), ('نسب مالية', 3), ('ربحية', 2), ('سيولة', 2),
        ('هامش', 1), ('إيرادات', 1), ('مصروفات', 1), ('أرباح', 1),
        ('قوائم مالية', 3), ('ميزانية', 2), ('دخل', 1), ('خسائر', 1),
        ('financial analysis', 3), ('ratios', 2), ('profitability', 2),
        ('liquidity', 2), ('revenue', 1), ('balance sheet', 3),
        ('income statement', 3), ('cash flow', 2), ('ROA', 2), ('ROE', 2),
    ],
    'coa_workflow': [
        ('شجرة حسابات', 3), ('رفع شجرة', 3), ('COA', 3), ('chart of accounts', 3),
        ('حسابات', 1), ('تبويب', 2), ('تصنيف حسابات', 3), ('classification', 2),
        ('دليل الحسابات', 3), ('رمز الحساب', 2), ('account code', 2),
    ],
    'tb_binding': [
        ('ميزان مراجعة', 3), ('trial balance', 3), ('ربط الميزان', 3),
        ('TB', 2), ('binding', 2), ('مطابقة', 2), ('أرصدة', 1),
    ],
    'funding_readiness': [
        ('تمويل', 2), ('جاهزية تمويل', 3), ('قرض', 2), ('funding', 2),
        ('readiness', 2), ('loan', 2), ('بنك', 1), ('استثمار', 1),
        ('investment', 1), ('ضمان', 1), ('كفالة', 1), ('جاهزية', 2),
    ],
    'compliance': [
        ('ضريبة', 2), ('زكاة', 3), ('ZATCA', 3), ('امتثال', 3),
        ('tax', 2), ('zakat', 3), ('compliance', 3), ('فاتورة إلكترونية', 3),
        ('إقرار', 2), ('VAT', 3), ('ضريبة القيمة المضافة', 3),
        ('فاتورة', 1), ('إقرار ضريبي', 3), ('هيئة الزكاة', 3),
    ],
    'audit_review': [
        ('مراجعة', 2), ('تدقيق', 3), ('audit', 3), ('review', 1),
        ('عينات', 2), ('أوراق عمل', 3), ('workpapers', 3),
        ('findings', 2), ('ملاحظات المراجعة', 3), ('برنامج مراجعة', 3),
        ('مدقق', 2), ('auditor', 2), ('sampling', 2),
    ],
    'knowledge_lookup': [
        ('معيار', 2), ('SOCPA', 3), ('IFRS', 3), ('نظام', 1),
        ('لائحة', 2), ('قانون', 2), ('standard', 2), ('regulation', 2),
        ('rule', 1), ('معرفة', 1), ('knowledge', 1), ('ISA', 3),
        ('معيار محاسبة', 3), ('نظام الشركات', 3), ('معيار مراجعة', 3),
    ],
    'service_request': [
        ('خدمة', 1), ('طلب خدمة', 3), ('service', 1), ('request', 1),
        ('مزود', 2), ('provider', 2), ('سوق الخدمات', 3), ('marketplace', 2),
        ('مكتب محاسبة', 3), ('مكتب تدقيق', 3), ('استشاري', 2),
    ],
    'explain_result': [
        ('اشرح', 3), ('لماذا', 2), ('فسر', 3), ('سبب', 1),
        ('explain', 3), ('why', 2), ('reason', 1), ('تفسير', 3),
        ('تفصيل', 2), ('details', 1), ('كيف حسبت', 3), ('ما سبب', 2),
    ],
    'account_management': [
        ('حسابي', 2), ('اشتراك', 2), ('خطة', 1), ('ترقية', 2),
        ('account', 1), ('subscription', 2), ('plan', 1), ('upgrade', 2),
        ('profile', 2), ('إعدادات', 2), ('كلمة المرور', 3), ('password', 3),
        ('بياناتي', 2), ('ملفي الشخصي', 3),
    ]
}

# Greeting patterns - detect and respond without confusion
GREETING_PATTERNS = [
    'مرحبا', 'السلام عليكم', 'اهلا', 'هلا', 'صباح الخير', 'مساء الخير',
    'hello', 'hi', 'hey', 'good morning', 'good evening', 'السلام',
]

def detect_intent(text: str) -> dict:
    text_lower = text.lower().strip()

    # Check for greetings first
    if any(g in text_lower for g in GREETING_PATTERNS) and len(text_lower) < 50:
        return {'intent': 'general', 'confidence': 0.95, 'all_scores': {}, 'is_greeting': True}

    scores = {}
    for intent, keywords in INTENT_MAP.items():
        weighted_score = 0
        match_count = 0
        for kw, weight in keywords:
            if kw.lower() in text_lower:
                weighted_score += weight
                match_count += 1
        if weighted_score > 0:
            scores[intent] = weighted_score

    if not scores:
        return {'intent': 'general', 'confidence': 0.3, 'all_scores': scores}

    best = max(scores, key=scores.get)
    max_score = scores[best]

    # Better confidence calculation based on weighted scores
    # Single weak match (score 1-2) = low confidence
    # Strong match (score 3+) or multiple matches = higher confidence
    if max_score >= 6:
        confidence = 0.92
    elif max_score >= 4:
        confidence = 0.82
    elif max_score >= 3:
        confidence = 0.7
    elif max_score >= 2:
        confidence = 0.55
    else:
        confidence = 0.4

    # Ambiguity penalty: if second-best is close to best, reduce confidence
    sorted_scores = sorted(scores.values(), reverse=True)
    if len(sorted_scores) >= 2 and sorted_scores[1] >= max_score * 0.7:
        confidence *= 0.85  # 15% penalty for ambiguity

    confidence = min(0.95, round(confidence, 2))
    return {'intent': best, 'confidence': confidence, 'all_scores': scores}

def build_context(user_id: str, client_id: Optional[str], intent: str) -> dict:
    return {
        'user_id': user_id,
        'client_id': client_id,
        'intent': intent,
        'requires_file': intent in ['coa_workflow', 'tb_binding', 'financial_analysis'],
        'requires_client': intent in ['financial_analysis', 'coa_workflow', 'tb_binding', 'funding_readiness', 'audit_review', 'compliance'],
        'may_escalate': intent in ['compliance', 'audit_review', 'funding_readiness'],
        'knowledge_domains': _get_domains(intent)
    }

def _get_domains(intent: str) -> list:
    domain_map = {
        'financial_analysis': ['accounting', 'finance'],
        'compliance': ['tax_zakat', 'compliance', 'regulatory'],
        'audit_review': ['audit', 'accounting'],
        'funding_readiness': ['finance', 'funding'],
        'knowledge_lookup': ['all'],
        'coa_workflow': ['accounting'],
        'tb_binding': ['accounting'],
    }
    return domain_map.get(intent, ['general'])

def suggest_next_actions(intent: str, context: dict) -> list:
    actions = {
        'financial_analysis': [
            {'action': 'upload_tb', 'label': 'رفع ميزان المراجعة', 'icon': 'upload_file'},
            {'action': 'view_ratios', 'label': 'عرض النسب المالية', 'icon': 'analytics'},
            {'action': 'view_statements', 'label': 'عرض القوائم المالية', 'icon': 'receipt_long'}
        ],
        'coa_workflow': [
            {'action': 'upload_coa', 'label': 'رفع شجرة الحسابات', 'icon': 'upload_file'},
            {'action': 'view_mapping', 'label': 'معاينة التبويب', 'icon': 'map'},
            {'action': 'quality_report', 'label': 'تقرير الجودة', 'icon': 'assessment'}
        ],
        'compliance': [
            {'action': 'check_zatca', 'label': 'فحص التزام ZATCA', 'icon': 'verified'},
            {'action': 'tax_review', 'label': 'مراجعة ضريبية', 'icon': 'gavel'},
            {'action': 'request_service', 'label': 'طلب خدمة ضريبية', 'icon': 'support_agent'}
        ],
        'audit_review': [
            {'action': 'start_audit', 'label': 'بدء مراجعة جديدة', 'icon': 'checklist'},
            {'action': 'view_stages', 'label': 'عرض مراحل المراجعة', 'icon': 'timeline'},
            {'action': 'view_findings', 'label': 'عرض الملاحظات', 'icon': 'find_in_page'}
        ],
        'funding_readiness': [
            {'action': 'check_readiness', 'label': 'فحص الجاهزية التمويلية', 'icon': 'account_balance'},
            {'action': 'view_gaps', 'label': 'عرض الفجوات', 'icon': 'warning'},
            {'action': 'prepare_docs', 'label': 'تجهيز المستندات', 'icon': 'folder_open'}
        ],
        'explain_result': [
            {'action': 'show_evidence', 'label': 'عرض الأدلة', 'icon': 'source'},
            {'action': 'show_rules', 'label': 'عرض القواعد المطبقة', 'icon': 'rule'},
            {'action': 'escalate', 'label': 'طلب مراجعة بشرية', 'icon': 'person'}
        ],
    }
    return actions.get(intent, [
        {'action': 'ask_copilot', 'label': 'اسأل المساعد الذكي', 'icon': 'smart_toy'},
        {'action': 'browse_services', 'label': 'تصفح الخدمات', 'icon': 'store'},
        {'action': 'view_dashboard', 'label': 'لوحة القيادة', 'icon': 'dashboard'}
    ])