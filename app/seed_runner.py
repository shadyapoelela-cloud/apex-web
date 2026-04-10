"""
APEX Platform - Master Seed Runner
Loads all reference data into database
Usage: python -m app.seed_runner
"""

import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.phase1.models.platform_models import Base, engine, SessionLocal, gen_uuid, utcnow
from app.phase2.models.onboarding_models import LegalEntityType, SectorMain, SectorSub, StageNote
from app.phase2.models.archive_models import ArchivePolicy
from app.phase2.models.service_catalog_models import ServiceCatalog, ServiceWorkflowStage, AuditProgramTemplate
from app.phase2.services.seed_onboarding import get_legal_entity_types, get_sector_main, get_sector_sub, get_stage_notes


def seed_all():
    print("Creating all tables...")
    Base.metadata.create_all(bind=engine, checkfirst=True)
    db = SessionLocal()
    try:
        # 1. Legal Entity Types
        existing = db.query(LegalEntityType).count()
        if existing == 0:
            for item in get_legal_entity_types():
                db.add(LegalEntityType(id=gen_uuid(), **item, is_active=True))
            db.commit()
            print(f"  Seeded {len(get_legal_entity_types())} legal entity types")
        else:
            print(f"  Legal entity types already exist ({existing})")

        # 2. Sectors Main
        existing = db.query(SectorMain).count()
        if existing == 0:
            for item in get_sector_main():
                db.add(SectorMain(id=gen_uuid(), **item, is_active=True))
            db.commit()
            print(f"  Seeded {len(get_sector_main())} main sectors")
        else:
            print(f"  Main sectors already exist ({existing})")

        # 3. Sectors Sub
        existing = db.query(SectorSub).count()
        if existing == 0:
            for item in get_sector_sub():
                db.add(SectorSub(id=gen_uuid(), **{k:v for k,v in item.items()}, is_active=True))
            db.commit()
            print(f"  Seeded {len(get_sector_sub())} sub sectors")
        else:
            print(f"  Sub sectors already exist ({existing})")

        # 4. Stage Notes
        existing = db.query(StageNote).count()
        if existing == 0:
            for item in get_stage_notes():
                db.add(StageNote(id=gen_uuid(), **item, is_active=True))
            db.commit()
            print(f"  Seeded {len(get_stage_notes())} stage notes")
        else:
            print(f"  Stage notes already exist ({existing})")

        # 5. Default Archive Policy
        existing = db.query(ArchivePolicy).count()
        if existing == 0:
            db.add(ArchivePolicy(id=gen_uuid(), scope_type="global", retention_days=30, allow_reuse=True, allow_download=True, is_active=True))
            db.commit()
            print("  Seeded default archive policy (30 days)")
        else:
            print(f"  Archive policies already exist ({existing})")

        # 6. Service Catalog
        existing = db.query(ServiceCatalog).count()
        if existing == 0:
            services = [
                {"service_code": "financial_analysis", "title_ar": "التحليل المالي", "title_en": "Financial Analysis", "category": "financial", "requires_coa": True, "requires_tb": True, "min_plan": "pro", "sort_order": 1},
                {"service_code": "funding_readiness", "title_ar": "الجاهزية التمويلية", "title_en": "Funding Readiness", "category": "readiness", "requires_coa": True, "requires_tb": True, "min_plan": "business", "sort_order": 2},
                {"service_code": "accounting_audit", "title_ar": "المراجعة المحاسبية", "title_en": "Accounting Audit", "category": "audit", "requires_coa": True, "requires_tb": True, "min_plan": "business", "sort_order": 3},
                {"service_code": "tax_zakat", "title_ar": "الخدمات الضريبية والزكوية", "title_en": "Tax & Zakat", "category": "compliance", "requires_coa": True, "min_plan": "pro", "sort_order": 4},
                {"service_code": "support_readiness", "title_ar": "جاهزية الدعم والبرامج", "title_en": "Support Readiness", "category": "readiness", "min_plan": "pro", "sort_order": 5},
                {"service_code": "license_readiness", "title_ar": "جاهزية التراخيص", "title_en": "License Readiness", "category": "readiness", "min_plan": "business", "sort_order": 6},
            ]
            for s in services:
                db.add(ServiceCatalog(id=gen_uuid(), **s, is_active=True))
            db.commit()
            print(f"  Seeded {len(services)} services")

            # Audit service stages
            audit_svc = db.query(ServiceCatalog).filter(ServiceCatalog.service_code == "accounting_audit").first()
            if audit_svc:
                stages = [
                    {"stage_code": "coa_setup", "stage_order": 1, "title_ar": "تعريف شجرة الحسابات", "is_mandatory": True},
                    {"stage_code": "tb_upload", "stage_order": 2, "title_ar": "رفع ميزان المراجعة", "is_mandatory": True},
                    {"stage_code": "audit_program", "stage_order": 3, "title_ar": "بناء برنامج المراجعة", "is_mandatory": True},
                    {"stage_code": "sampling", "stage_order": 4, "title_ar": "اختيار العينات", "is_mandatory": True},
                    {"stage_code": "execution", "stage_order": 5, "title_ar": "تنفيذ الإجراءات", "is_mandatory": True},
                    {"stage_code": "findings", "stage_order": 6, "title_ar": "التجميع والتقييم", "is_mandatory": True},
                    {"stage_code": "report", "stage_order": 7, "title_ar": "المخرجات النهائية", "is_mandatory": True},
                ]
                for st in stages:
                    db.add(ServiceWorkflowStage(id=gen_uuid(), service_id=audit_svc.id, **st))
                db.commit()
                print(f"  Seeded {len(stages)} audit stages")
        else:
            print(f"  Service catalog already exist ({existing})")

        # 7. Audit Program Templates
        existing = db.query(AuditProgramTemplate).count()
        if existing == 0:
            templates = [
                {"procedure_code": "CASH-01", "area": "cash", "title_ar": "فحص الأرصدة النقدية", "risk_level": "medium", "local_std_ref": "SA-200", "international_ref": "ISA 500"},
                {"procedure_code": "CASH-02", "area": "cash", "title_ar": "مطابقة كشوف البنك", "risk_level": "high", "local_std_ref": "SA-505", "international_ref": "ISA 505"},
                {"procedure_code": "REC-01", "area": "receivables", "title_ar": "فحص أرصدة المدينين", "risk_level": "high", "local_std_ref": "SA-505", "international_ref": "ISA 505"},
                {"procedure_code": "REC-02", "area": "receivables", "title_ar": "مصادقات المدينين", "risk_level": "high", "local_std_ref": "SA-505", "international_ref": "ISA 505"},
                {"procedure_code": "INV-01", "area": "inventory", "title_ar": "جرد المخزون", "risk_level": "high", "local_std_ref": "SA-501", "international_ref": "ISA 501"},
                {"procedure_code": "PAY-01", "area": "payables", "title_ar": "فحص أرصدة الدائنين", "risk_level": "medium", "local_std_ref": "SA-500", "international_ref": "ISA 500"},
                {"procedure_code": "REV-01", "area": "revenue", "title_ar": "فحص الإيرادات وعقود العملاء", "risk_level": "high", "local_std_ref": "SA-315", "international_ref": "ISA 315"},
                {"procedure_code": "EXP-01", "area": "expenses", "title_ar": "فحص المصروفات التشغيلية", "risk_level": "medium", "local_std_ref": "SA-500", "international_ref": "ISA 500"},
                {"procedure_code": "FA-01", "area": "fixed_assets", "title_ar": "فحص الأصول الثابتة والاستهلاك", "risk_level": "medium", "local_std_ref": "SA-500", "international_ref": "ISA 500"},
                {"procedure_code": "EQ-01", "area": "equity", "title_ar": "فحص حقوق الملكية والتغيرات", "risk_level": "low", "local_std_ref": "SA-500", "international_ref": "ISA 500"},
            ]
            for t in templates:
                db.add(AuditProgramTemplate(id=gen_uuid(), **t, is_active=True))
            db.commit()
            print(f"  Seeded {len(templates)} audit templates")
        else:
            print(f"  Audit templates already exist ({existing})")

        print("\nSeed completed successfully!")

    except Exception as e:
        db.rollback()
        import logging
        logging.error("Seed runner failed", exc_info=True)
        print(f"ERROR: Seed runner failed. Check logs for details.")
    finally:
        db.close()


if __name__ == "__main__":
    seed_all()

