"""
APEX Platform — Phase 2 Seed Data
═══════════════════════════════════════════════════════════════
Client types per execution document section 5.
"""

from app.phase1.models.platform_models import SessionLocal, gen_uuid
from app.phase2.models.phase2_models import ClientTypeRef, KNOWLEDGE_MODE_ELIGIBLE_TYPES


CLIENT_TYPES = [
    {
        "code": "standard_business",
        "name_ar": "منشأة تجارية عادية",
        "name_en": "Standard Business",
        "description_ar": "شركة أو مؤسسة تجارية تستفيد من التحليل المالي وطلب الخدمات",
        "knowledge_features_ar": None,
    },
    {
        "code": "financial_entity",
        "name_ar": "جهة مالية",
        "name_en": "Financial Entity",
        "description_ar": "بنك أو مؤسسة مالية أو شركة تمويل مرخصة",
        "knowledge_features_ar": "مساهمات قطاعية وتحليلية",
    },
    {
        "code": "financing_entity",
        "name_ar": "جهة تمويلية",
        "name_en": "Financing Entity",
        "description_ar": "شركة تمويل أو منصة تمويل جماعي مرخصة",
        "knowledge_features_ar": None,
    },
    {
        "code": "accounting_firm",
        "name_ar": "مكتب محاسبة",
        "name_en": "Accounting Firm",
        "description_ar": "مكتب محاسبة أو مراجعة مرخص",
        "knowledge_features_ar": "إرسال feedback مهني ومنظم",
    },
    {
        "code": "audit_firm",
        "name_ar": "مكتب مراجعة",
        "name_en": "Audit Firm",
        "description_ar": "مكتب مراجعة حسابات مرخص من SOCPA",
        "knowledge_features_ar": "إرسال feedback مهني ومنظم",
    },
    {
        "code": "investment_entity",
        "name_ar": "جهة استثمارية",
        "name_en": "Investment Entity",
        "description_ar": "صندوق استثماري أو شركة رأس مال جريء أو إدارة أصول",
        "knowledge_features_ar": "مساهمات قطاعية وتحليلية",
    },
    {
        "code": "sector_consulting_entity",
        "name_ar": "جهة استشارية قطاعية",
        "name_en": "Sector Consulting Entity",
        "description_ar": "شركة استشارات مالية أو إدارية أو قطاعية",
        "knowledge_features_ar": None,
    },
    {
        "code": "government_entity",
        "name_ar": "جهة حكومية",
        "name_en": "Government Entity",
        "description_ar": "وزارة أو هيئة حكومية أو جهة تنظيمية",
        "knowledge_features_ar": "تنبيهات تنظيمية ومساهمات مقيدة",
    },
    {
        "code": "legal_regulatory_entity",
        "name_ar": "جهة قانونية/تنظيمية",
        "name_en": "Legal/Regulatory Entity",
        "description_ar": "مكتب محاماة أو جهة تنظيمية أو رقابية",
        "knowledge_features_ar": "ملاحظات قانونية/تنظيمية عالية الأثر",
    },
]


def seed_client_types():
    """Seed client types. Safe to call multiple times."""
    db = SessionLocal()
    try:
        count = 0
        for i, ct in enumerate(CLIENT_TYPES):
            existing = db.query(ClientTypeRef).filter(ClientTypeRef.code == ct["code"]).first()
            if not existing:
                db.add(ClientTypeRef(
                    id=gen_uuid(),
                    code=ct["code"],
                    name_ar=ct["name_ar"],
                    name_en=ct["name_en"],
                    description_ar=ct["description_ar"],
                    knowledge_mode_eligible=ct["code"] in KNOWLEDGE_MODE_ELIGIBLE_TYPES,
                    knowledge_mode_features_ar=ct.get("knowledge_features_ar"),
                    sort_order=i,
                ))
                count += 1
        db.commit()
        return count
    except Exception as e:
        db.rollback()
        return 0
    finally:
        db.close()
