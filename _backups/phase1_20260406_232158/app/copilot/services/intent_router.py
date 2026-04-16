import re
from typing import Optional

INTENT_MAP = {
    'financial_analysis': [
        'تحليل مالي', 'نسب مالية', 'ربحية', 'سيولة', 'هامش', 'إيرادات',
        'financial analysis', 'ratios', 'profitability', 'liquidity', 'revenue'
    ],
    'coa_workflow': [
        'شجرة حسابات', 'رفع شجرة', 'COA', 'chart of accounts', 'حسابات',
        'تبويب', 'تصنيف حسابات', 'classification'
    ],
    'tb_binding': [
        'ميزان مراجعة', 'trial balance', 'ربط الميزان', 'TB', 'binding'
    ],
    'funding_readiness': [
        'تمويل', 'جاهزية تمويل', 'قرض', 'funding', 'readiness', 'loan',
        'بنك', 'استثمار', 'investment'
    ],
    'compliance': [
        'ضريبة', 'زكاة', 'ZATCA', 'امتثال', 'tax', 'zakat', 'compliance',
        'فاتورة', 'إقرار', 'VAT'
    ],
    'audit_review': [
        'مراجعة', 'تدقيق', 'audit', 'review', 'عينات', 'أوراق عمل',
        'workpapers', 'findings', 'ملاحظات المراجعة'
    ],
    'knowledge_lookup': [
        'معيار', 'SOCPA', 'IFRS', 'نظام', 'لائحة', 'قانون',
        'standard', 'regulation', 'rule', 'معرفة', 'knowledge'
    ],
    'service_request': [
        'خدمة', 'طلب خدمة', 'service', 'request', 'مزود', 'provider',
        'سوق الخدمات', 'marketplace'
    ],
    'explain_result': [
        'اشرح', 'لماذا', 'فسر', 'سبب', 'explain', 'why', 'reason',
        'تفسير', 'تفصيل', 'details'
    ],
    'account_management': [
        'حسابي', 'اشتراك', 'خطة', 'ترقية', 'account', 'subscription',
        'plan', 'upgrade', 'profile', 'إعدادات'
    ]
}

def detect_intent(text: str) -> dict:
    text_lower = text.lower().strip()
    scores = {}
    for intent, keywords in INTENT_MAP.items():
        score = sum(1 for kw in keywords if kw.lower() in text_lower)
        if score > 0:
            scores[intent] = score
    if not scores:
        return {'intent': 'general', 'confidence': 0.3, 'all_scores': {}}
    best = max(scores, key=scores.get)
    max_score = scores[best]
    confidence = min(0.95, 0.4 + (max_score * 0.15))
    return {'intent': best, 'confidence': round(confidence, 2), 'all_scores': scores}

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